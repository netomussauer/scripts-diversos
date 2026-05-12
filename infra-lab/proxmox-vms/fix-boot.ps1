# =============================================================================
# Script:    fix-boot.ps1
# Projeto:   infra-lab (home-lab K3s da Stone)
# Atividade: Reanexar disco virtio0 nas VMs 200/201/202 apos scsi0 ter sido
#            removido por engano, ajustando bootdisk/boot order. Tambem
#            confirma estado do template 9000 e da boot nas VMs.
# Contexto:  Usado quando o fix-disks.ps1 deixou as VMs sem disco anexado
#            ou quando virtio0 foi apagado mas a imagem ainda esta no
#            SeagateNAS. Subset funcional do fix-disks.ps1 — preserva
#            o disco existente, nao reclona.
# Pre-req:   - PowerShell com TLS 1.2 (script forca)
#            - Variavel de ambiente PVE_TOKEN definida
#            - Imagens vm-XXX-disk-0.raw presentes em SeagateNAS:XXX/
# Uso:       $env:PVE_TOKEN = 'PVEAPIToken=root@pam!<user>=<uuid>'
#            .\fix-boot.ps1
# =============================================================================

if (-not $env:PVE_TOKEN) {
    Write-Error "Defina `$env:PVE_TOKEN antes de rodar."
    exit 1
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustBoot : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint sp, X509Certificate cert, WebRequest req, int problem) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustBoot

$token = $env:PVE_TOKEN
$h     = @{ 'Authorization' = $token }
$base  = 'https://192.168.1.20:8006/api2/json/nodes/virt/qemu'

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
    return $out
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
    $resp.Close()
}

# --- 1. Parar VMs ---
Write-Host "=== Parando VMs ===" -ForegroundColor Yellow
foreach ($vmid in @(200, 201, 202)) {
    try {
        Invoke-PvePost "$base/$vmid/status/stop" $null | Out-Null
        Write-Host "  VM ${vmid}: stop enviado" -ForegroundColor Yellow
    } catch { Write-Host "  VM ${vmid} stop erro: $($_.Exception.Message)" -ForegroundColor Red }
}

Write-Host "Aguardando 15s..." -ForegroundColor Gray
Start-Sleep -Seconds 15

# Confirmar que pararam
$vms = Invoke-RestMethod -Uri "$base" -Headers $h
$vms.data | Where-Object { $_.vmid -in @(200,201,202) } | Select-Object vmid, status | Format-Table -AutoSize

# --- 2. Verificar estado atual dos discos ---
Write-Host "=== Estado atual das VMs ===" -ForegroundColor Cyan
foreach ($vmid in @(200, 201, 202)) {
    $cfg = Invoke-RestMethod -Uri "$base/$vmid/config" -Headers $h
    Write-Host "  VM ${vmid} scsi0    = '$($cfg.data.scsi0)'"
    Write-Host "  VM ${vmid} virtio0  = '$($cfg.data.virtio0)'"
    Write-Host "  VM ${vmid} bootdisk = '$($cfg.data.bootdisk)'"
    Write-Host "  VM ${vmid} boot     = '$($cfg.data.boot)'"
}

# --- 3. Anexar disco como virtio0 nas VMs (o scsi0 ja foi deletado na execucao anterior) ---
Write-Host "`n=== Anexando virtio0 nas VMs ===" -ForegroundColor Cyan

$diskMap = @{
    200 = 'SeagateNAS:200/vm-200-disk-0.raw'
    201 = 'SeagateNAS:201/vm-201-disk-0.raw'
    202 = 'SeagateNAS:202/vm-202-disk-0.raw'
}

foreach ($vmid in @(200, 201, 202)) {
    $cfg = Invoke-RestMethod -Uri "$base/$vmid/config" -Headers $h

    # Se scsi0 ainda existir, deletar primeiro
    if ($cfg.data.scsi0) {
        Write-Host "  VM ${vmid}: removendo scsi0 residual..." -ForegroundColor Yellow
        try { Invoke-PvePut "$base/$vmid/config" "delete=scsi0" } catch { Write-Host "  Erro delete scsi0: $($_.Exception.Message)" }
    }

    $path = $diskMap[$vmid]
    # virtio0 nao aceita ssd=1 (opcao exclusiva de scsi/ide)
    # flags validos para virtio: aio, backup, cache, discard, iothread, replicate
    $virtioVal = "${path},aio=io_uring,backup=1,cache=none,discard=on,iothread=0,replicate=1"
    $encoded   = [System.Uri]::EscapeDataString($virtioVal)
    $body      = "virtio0=${encoded}&bootdisk=virtio0&boot=order%3Dvirtio0"

    Write-Host "  VM ${vmid}: anexando como virtio0..." -ForegroundColor Cyan
    try {
        Invoke-PvePut "$base/$vmid/config" $body
        Write-Host "  VM ${vmid}: virtio0 OK" -ForegroundColor Green
    } catch {
        Write-Host "  VM ${vmid} erro attach: $($_.Exception.Message)" -ForegroundColor Red
    }

    # Verificar
    $cfg2 = Invoke-RestMethod -Uri "$base/$vmid/config" -Headers $h
    Write-Host "  VM ${vmid} virtio0  = $($cfg2.data.virtio0)" -ForegroundColor Green
    Write-Host "  VM ${vmid} bootdisk = $($cfg2.data.bootdisk)" -ForegroundColor Green
    Write-Host "  VM ${vmid} boot     = $($cfg2.data.boot)" -ForegroundColor Green
}

# --- 4. Atualizar template 9000 (se ainda tiver scsi0) ---
Write-Host "`n=== Verificando template 9000 ===" -ForegroundColor Cyan
$cfg9 = Invoke-RestMethod -Uri "$base/9000/config" -Headers $h
Write-Host "  Template virtio0  = '$($cfg9.data.virtio0)'"
Write-Host "  Template bootdisk = '$($cfg9.data.bootdisk)'"

# --- 5. Iniciar VMs ---
Write-Host "`n=== Iniciando VMs ===" -ForegroundColor Green
foreach ($vmid in @(200, 201, 202)) {
    try {
        $r = Invoke-PvePost "$base/$vmid/status/start" $null
        Write-Host "  VM ${vmid} start OK" -ForegroundColor Green
    } catch { Write-Host "  VM ${vmid} start erro: $($_.Exception.Message)" -ForegroundColor Red }
}

Write-Host "`nAguardando 20s para inicializacao..." -ForegroundColor Gray
Start-Sleep -Seconds 20

# Status final
Write-Host "`n=== Status final ===" -ForegroundColor Cyan
$vms = Invoke-RestMethod -Uri "$base" -Headers $h
$vms.data | Where-Object { $_.vmid -in @(200,201,202) } | Select-Object vmid, name, status | Format-Table -AutoSize
