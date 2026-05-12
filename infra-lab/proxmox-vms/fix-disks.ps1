# =============================================================================
# Script:    fix-disks.ps1
# Projeto:   infra-lab (home-lab K3s da Stone)
# Atividade: Recriacao completa das VMs 200/201/202: destroi as VMs atuais,
#            clona o template 9000 com full=1 (copia real dos dados),
#            redimensiona o disco para o tamanho de cada perfil e aplica
#            configuracao base (machine, scsihw, boot, cloud-init, rede,
#            sshkey, dns, tags, agent, serial console).
# Contexto:  Reset de bootstrap. Roteiro mais agressivo — DESTROI as VMs
#            antes de reclonar. Use quando algo no clone original deu errado
#            (discos vazios, snapshot quebrado, config corrompida).
# Pre-req:   - PowerShell com TLS 1.2 (script forca)
#            - Variavel de ambiente PVE_TOKEN definida
#            - Template 9000 existente em SeagateNAS
# Uso:       $env:PVE_TOKEN = 'PVEAPIToken=root@pam!<user>=<uuid>'
#            .\fix-disks.ps1
# =============================================================================

if (-not $env:PVE_TOKEN) {
    Write-Error "Defina `$env:PVE_TOKEN antes de rodar."
    exit 1
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustFixDisks : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint sp, X509Certificate cert, WebRequest req, int problem) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustFixDisks

$token  = $env:PVE_TOKEN
$h      = @{ 'Authorization' = $token }
$base   = 'https://192.168.1.20:8006/api2/json/nodes/virt'
$sshKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP54q9f+UsFYgVWnBqbgMwd/nceECQMY/RF6KjWCJl6v lab-key'

$vmDefs = @(
    @{ id=200; name='k3s-server';      memory=4096; cores=2; size='40G'; ip='192.168.1.30/24' },
    @{ id=201; name='k3s-worker-cicd'; memory=6144; cores=4; size='60G'; ip='192.168.1.31/24' },
    @{ id=202; name='ci-runner';       memory=4096; cores=2; size='40G'; ip='192.168.1.32/24' }
)

function Invoke-PvePost($url, $bodyStr) {
    $req = [System.Net.HttpWebRequest]::Create($url)
    $req.Method = 'POST'
    $req.Headers.Add('Authorization', $token)
    $req.ContentType = 'application/x-www-form-urlencoded'
    if ($bodyStr) {
        $b = [System.Text.Encoding]::UTF8.GetBytes($bodyStr)
        $req.ContentLength = $b.Length
        $s = $req.GetRequestStream(); $s.Write($b, 0, $b.Length); $s.Close()
    } else {
        $req.ContentLength = 0
    }
    $resp = $req.GetResponse()
    $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
    $out = $reader.ReadToEnd()
    $resp.Close()
    return $out | ConvertFrom-Json
}

function Invoke-PvePut($url, $bodyStr) {
    $req = [System.Net.HttpWebRequest]::Create($url)
    $req.Method = 'PUT'
    $req.Headers.Add('Authorization', $token)
    $req.ContentType = 'application/x-www-form-urlencoded'
    $b = [System.Text.Encoding]::UTF8.GetBytes($bodyStr)
    $req.ContentLength = $b.Length
    $s = $req.GetRequestStream(); $s.Write($b, 0, $b.Length); $s.Close()
    $resp = $req.GetResponse()
    $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
    $out = $reader.ReadToEnd()
    $resp.Close()
    return $out | ConvertFrom-Json
}

function Invoke-PveDelete($url) {
    $req = [System.Net.HttpWebRequest]::Create($url)
    $req.Method = 'DELETE'
    $req.Headers.Add('Authorization', $token)
    $req.ContentLength = 0
    $resp = $req.GetResponse()
    $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
    $out = $reader.ReadToEnd()
    $resp.Close()
    return $out | ConvertFrom-Json
}

function Wait-PveTask($upid) {
    # UPID contem o node — extrair para montar a URL correta
    $enc = [System.Uri]::EscapeDataString($upid)
    $url = "$base/tasks/$enc/status"
    Write-Host "    Aguardando task..." -ForegroundColor Gray -NoNewline
    do {
        Start-Sleep -Seconds 4
        $r = Invoke-RestMethod -Uri $url -Headers $h
        Write-Host "." -NoNewline -ForegroundColor Gray
    } while ($r.data.status -eq 'running')
    Write-Host " $($r.data.status)" -ForegroundColor $(if ($r.data.exitstatus -eq 'OK') { 'Green' } else { 'Red' })
    return $r.data
}

# -----------------------------------------------------------------------------
# 1. Garantir que as VMs estao paradas
# -----------------------------------------------------------------------------
Write-Host "=== Verificando/parando VMs ===" -ForegroundColor Yellow
$vms = Invoke-RestMethod -Uri "$base/qemu" -Headers $h
foreach ($vm in $vmDefs) {
    $entry = $vms.data | Where-Object { $_.vmid -eq $vm.id }
    if ($entry -and $entry.status -ne 'stopped') {
        Write-Host "  Parando VM $($vm.id)..." -ForegroundColor Yellow
        try { Invoke-PvePost "$base/qemu/$($vm.id)/status/stop" $null | Out-Null } catch {}
        Start-Sleep -Seconds 8
    } else {
        Write-Host "  VM $($vm.id): ja parada" -ForegroundColor Gray
    }
}

# -----------------------------------------------------------------------------
# 2. Destruir VMs atuais (discos vazios incluidos)
# -----------------------------------------------------------------------------
Write-Host "`n=== Destruindo VMs (discos incluidos) ===" -ForegroundColor Red
foreach ($vm in $vmDefs) {
    Write-Host "  Destruindo VM $($vm.id)..." -ForegroundColor Red
    try {
        $r = Invoke-PveDelete "$base/qemu/$($vm.id)?destroy-unreferenced-disks=1&purge=1"
        if ($r.data) {
            Wait-PveTask $r.data | Out-Null
        }
        Write-Host "    VM $($vm.id) destruida" -ForegroundColor Green
    } catch {
        Write-Host "    Erro ao destruir VM $($vm.id): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Start-Sleep -Seconds 5

# -----------------------------------------------------------------------------
# 3. Clonar template 9000 -> VMs 200, 201, 202 com full=1 (copia real dos dados)
# -----------------------------------------------------------------------------
Write-Host "`n=== Clonando template 9000 (full clone, copia dados reais) ===" -ForegroundColor Cyan
foreach ($vm in $vmDefs) {
    Write-Host "  Clonando -> VM $($vm.id) ($($vm.name))..." -ForegroundColor Cyan
    $body = "newid=$($vm.id)&full=1&storage=SeagateNAS&name=$($vm.name)&target=virt&format=raw"
    try {
        $r = Invoke-PvePost "$base/qemu/9000/clone" $body
        if ($r.data) {
            $task = Wait-PveTask $r.data
            if ($task.exitstatus -eq 'OK') {
                Write-Host "    Clone VM $($vm.id) concluido" -ForegroundColor Green
            } else {
                Write-Host "    ERRO no clone VM $($vm.id): $($task.exitstatus)" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "    Erro clone VM $($vm.id): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Start-Sleep -Seconds 3

# -----------------------------------------------------------------------------
# 4. Verificar used dos discos clonados
# -----------------------------------------------------------------------------
Write-Host "`n=== Discos apos clone ===" -ForegroundColor Cyan
try {
    $c = Invoke-RestMethod -Uri "$base/storage/SeagateNAS/content?content=images" -Headers $h
    $c.data | Where-Object { $_.vmid -in @(200,201,202) } |
        Select-Object vmid, volid, size, used | Format-Table -AutoSize
} catch { Write-Host "Erro: $_" -ForegroundColor Red }

# -----------------------------------------------------------------------------
# 5. Redimensionar discos
# -----------------------------------------------------------------------------
Write-Host "=== Redimensionando discos ===" -ForegroundColor Cyan
foreach ($vm in $vmDefs) {
    Write-Host "  VM $($vm.id): disco -> $($vm.size)..." -ForegroundColor Cyan
    # Descobrir qual interface o disco usa apos o clone (template tem virtio0)
    $cfg = Invoke-RestMethod -Uri "$base/qemu/$($vm.id)/config" -Headers $h
    $iface = if ($cfg.data.virtio0) { 'virtio0' } elseif ($cfg.data.scsi0) { 'scsi0' } else { 'ide0' }
    try {
        Invoke-PvePut "$base/qemu/$($vm.id)/resize" "disk=${iface}&size=$($vm.size)" | Out-Null
        Write-Host "    resize $iface -> $($vm.size) OK" -ForegroundColor Green
    } catch {
        Write-Host "    Erro resize: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# -----------------------------------------------------------------------------
# 6. Configurar cada VM: machine, scsihw, boot, cloud-init, rede
# -----------------------------------------------------------------------------
Write-Host "`n=== Configurando VMs ===" -ForegroundColor Cyan

$vmIpMap = @{ 200='192.168.1.30/24'; 201='192.168.1.31/24'; 202='192.168.1.32/24' }
$encodedKey = [System.Uri]::EscapeDataString($sshKey)

foreach ($vm in $vmDefs) {
    Write-Host "  Configurando VM $($vm.id)..." -ForegroundColor Cyan
    $ip = $vmIpMap[$vm.id]

    # Detectar interface do disco
    $cfg = Invoke-RestMethod -Uri "$base/qemu/$($vm.id)/config" -Headers $h
    $iface = if ($cfg.data.virtio0) { 'virtio0' } elseif ($cfg.data.scsi0) { 'scsi0' } else { 'ide0' }

    # Config base: machine=pc, scsihw, boot, cloud-init, rede
    $cfgBody = "machine=pc" +
               "&memory=$($vm.memory)" +
               "&cores=$($vm.cores)" +
               "&scsihw=virtio-scsi-pci" +
               "&boot=order%3D${iface}" +
               "&bootdisk=${iface}" +
               "&ciuser=labadmin" +
               "&sshkeys=${encodedKey}" +
               "&ipconfig0=gw%3D192.168.1.254%2Cip%3D${([System.Uri]::EscapeDataString($ip))}" +
               "&nameserver=192.168.1.254%208.8.8.8" +
               "&searchdomain=lab.local" +
               "&tags=lab%3Bk3s%3Bhome-lab" +
               "&agent=enabled%3D1%2Ctype%3Dvirtio" +
               "&serial0=socket&vga=serial0"

    try {
        Invoke-PvePut "$base/qemu/$($vm.id)/config" $cfgBody | Out-Null
        Write-Host "    Config OK" -ForegroundColor Green
    } catch {
        Write-Host "    Erro config: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# -----------------------------------------------------------------------------
# 7. Verificar estado final
# -----------------------------------------------------------------------------
Write-Host "`n=== Config final das VMs ===" -ForegroundColor Cyan
foreach ($vm in $vmDefs) {
    $cfg = Invoke-RestMethod -Uri "$base/qemu/$($vm.id)/config" -Headers $h
    Write-Host "  VM $($vm.id):"
    Write-Host "    virtio0  = $($cfg.data.virtio0)"
    Write-Host "    boot     = $($cfg.data.boot)"
    Write-Host "    machine  = $($cfg.data.machine)"
    Write-Host "    ipconfig = $($cfg.data.ipconfig0)"
    Write-Host "    ciuser   = $($cfg.data.ciuser)"
}

Write-Host "`n=== Discos apos resize ===" -ForegroundColor Cyan
$c = Invoke-RestMethod -Uri "$base/storage/SeagateNAS/content?content=images" -Headers $h
$c.data | Where-Object { $_.vmid -in @(200,201,202) } |
    Select-Object vmid, volid, size, used | Format-Table -AutoSize

Write-Host "`nPronto! Execute o inicio das VMs quando quiser verificar o boot." -ForegroundColor Green
