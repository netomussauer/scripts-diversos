# =============================================================================
# Script:    config-vms.ps1
# Projeto:   infra-lab (home-lab K3s da Stone)
# Atividade: Aplicar sshkey nas VMs 200/201/202 via Proxmox API e dar boot.
# Contexto:  Etapa final do bootstrap do cluster K3s — depois que as VMs
#            ja foram clonadas do template 9000 e ja tem disco + cloud-init.
# Pre-req:   - PowerShell com TLS 1.2 (script forca)
#            - Variavel de ambiente PVE_TOKEN definida
# Uso:       $env:PVE_TOKEN = 'PVEAPIToken=root@pam!<user>=<uuid>'
#            .\config-vms.ps1
# =============================================================================

if (-not $env:PVE_TOKEN) {
    Write-Error "Defina `$env:PVE_TOKEN antes de rodar. Ex: `$env:PVE_TOKEN = 'PVEAPIToken=root@pam!root=<uuid>'"
    exit 1
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustCfg2 : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint sp, X509Certificate cert, WebRequest req, int problem) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustCfg2

$token  = $env:PVE_TOKEN
$h      = @{ 'Authorization' = $token }
$base   = 'https://192.168.1.20:8006/api2/json/nodes/virt'
$sshKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP54q9f+UsFYgVWnBqbgMwd/nceECQMY/RF6KjWCJl6v lab-key'

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
    $reader.ReadToEnd() | Out-Null
    $resp.Close()
}

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

# Proxmox armazena sshkeys como URL-encoded no arquivo de config.
# Para enviar via form body, precisa de double-encode:
# "body" e form-decoded pelo HTTP -> resulta em "%20" ainda presente -> Proxmox valida como URL-encoded
$encoded1    = [System.Uri]::EscapeDataString($sshKey)        # ssh-ed25519%20AAAA...
$doubleEncoded = [System.Uri]::EscapeDataString($encoded1)    # ssh-ed25519%2520AAAA...

$vmDefs = @(
    @{ id=200; ip='192.168.1.30/24' },
    @{ id=201; ip='192.168.1.31/24' },
    @{ id=202; ip='192.168.1.32/24' }
)

Write-Host "=== Aplicando sshkeys nas VMs ===" -ForegroundColor Cyan
foreach ($vm in $vmDefs) {
    Write-Host "  VM $($vm.id) sshkeys..." -NoNewline
    try {
        Invoke-PvePut "$base/qemu/$($vm.id)/config" "sshkeys=$doubleEncoded"
        Write-Host " OK" -ForegroundColor Green
    } catch {
        Write-Host " ERRO: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Verificar
Write-Host "`n=== Verificando sshkeys ===" -ForegroundColor Cyan
foreach ($vmid in @(200,201,202)) {
    $r = Invoke-RestMethod -Uri "$base/qemu/$vmid/config" -Headers $h
    Write-Host "  VM $vmid sshkeys = $($r.data.sshkeys)"
}

# Iniciar VMs
Write-Host "`n=== Iniciando VMs ===" -ForegroundColor Green
foreach ($vmid in @(200,201,202)) {
    try {
        Invoke-PvePost "$base/qemu/$vmid/status/start" $null | Out-Null
        Write-Host "  VM $vmid start enviado" -ForegroundColor Green
    } catch {
        Write-Host "  VM $vmid erro start: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nAguardando 30s..." -ForegroundColor Gray
Start-Sleep -Seconds 30

# Status final
Write-Host "`n=== Status final ===" -ForegroundColor Cyan
$vms = Invoke-RestMethod -Uri "$base/qemu" -Headers $h
$vms.data | Where-Object { $_.vmid -in @(200,201,202) } |
    Select-Object vmid, name, status, uptime | Format-Table -AutoSize
