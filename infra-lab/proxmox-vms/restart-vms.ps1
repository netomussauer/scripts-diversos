# =============================================================================
# Script:    restart-vms.ps1
# Projeto:   infra-lab (home-lab K3s da Stone)
# Atividade: Stop forcado + start das VMs 200/201/202 via Proxmox API.
# Contexto:  Usado para reiniciar o cluster apos mudanca de configuracao
#            (cloud-init, machine type, scsihw). Tambem lista discos
#            cloud-init no local-lvm antes do restart.
# Pre-req:   - PowerShell com TLS 1.2 (script forca)
#            - Variavel de ambiente PVE_TOKEN definida
# Uso:       $env:PVE_TOKEN = 'PVEAPIToken=root@pam!<user>=<uuid>'
#            .\restart-vms.ps1
# =============================================================================

if (-not $env:PVE_TOKEN) {
    Write-Error "Defina `$env:PVE_TOKEN antes de rodar."
    exit 1
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustRestart : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint sp, X509Certificate cert, WebRequest req, int problem) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustRestart

$h    = @{ 'Authorization' = $env:PVE_TOKEN }
$base = 'https://192.168.1.20:8006/api2/json/nodes/virt'

# Verificar se cloud-init disk existe no local-lvm
Write-Host "=== Discos cloud-init no local-lvm ===" -ForegroundColor Cyan
try {
    $s = Invoke-RestMethod -Uri "$base/storage/local-lvm/content" -Headers $h
    $s.data | Where-Object { $_.volid -match 'cloudinit' } | Select-Object volid, size | Format-Table -AutoSize
} catch {
    Write-Host "Erro: $_" -ForegroundColor Red
}

# Stop forcado
Write-Host "`nParando VMs (force stop)..." -ForegroundColor Yellow
foreach ($vmid in @(200, 201, 202)) {
    try {
        $req = [System.Net.HttpWebRequest]::Create("$base/qemu/$vmid/status/stop")
        $req.Method = 'POST'
        $req.Headers.Add('Authorization', $h.Authorization)
        $req.ContentType = 'application/x-www-form-urlencoded'
        $body = [System.Text.Encoding]::UTF8.GetBytes('forceStop=1')
        $req.ContentLength = $body.Length
        $stream = $req.GetRequestStream()
        $stream.Write($body, 0, $body.Length)
        $stream.Close()
        $resp = $req.GetResponse()
        $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
        Write-Host "  VM $vmid stop: $($reader.ReadToEnd().Substring(0,50))" -ForegroundColor Yellow
        $resp.Close()
    } catch {
        Write-Host "  VM $vmid stop erro: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Aguardar VMs pararem
Write-Host "`nAguardando 10s para VMs pararem..." -ForegroundColor Gray
Start-Sleep -Seconds 10

# Verificar status
$vms = Invoke-RestMethod -Uri "$base/qemu" -Headers $h
$vms.data | Where-Object { $_.vmid -in @(200,201,202) } | Select-Object vmid, name, status | Format-Table -AutoSize

# Iniciar
Write-Host "Iniciando VMs..." -ForegroundColor Green
foreach ($vmid in @(200, 201, 202)) {
    $r = Invoke-RestMethod -Uri "$base/qemu/$vmid/status/start" -Headers $h -Method POST
    Write-Host "  VM $vmid start: $($r.data)" -ForegroundColor Green
}
