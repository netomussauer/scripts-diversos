# =============================================================================
# Script:    check-vms.ps1
# Projeto:   infra-lab (home-lab K3s da Stone)
# Atividade: Inspecionar config da VM 200, listar discos das VMs 200/201/202
#            no storage SeagateNAS e mostrar status atual.
# Contexto:  Diagnostico rapido pre/pos qualquer mudanca via API
#            (clone, attach, resize, etc).
# Pre-req:   - PowerShell com TLS 1.2 (script forca)
#            - Variavel de ambiente PVE_TOKEN definida
# Uso:       $env:PVE_TOKEN = 'PVEAPIToken=root@pam!<user>=<uuid>'
#            .\check-vms.ps1
# =============================================================================

if (-not $env:PVE_TOKEN) {
    Write-Error "Defina `$env:PVE_TOKEN antes de rodar."
    exit 1
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustCheck : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint sp, X509Certificate cert, WebRequest req, int problem) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustCheck

$h    = @{ 'Authorization' = $env:PVE_TOKEN }
$base = 'https://192.168.1.20:8006/api2/json/nodes/virt'

# Config completa da VM 200
Write-Host "=== Config VM 200 ===" -ForegroundColor Cyan
$r = Invoke-RestMethod -Uri "$base/qemu/200/config" -Headers $h
$r.data | Format-List

# Listar conteudo do storage SeagateNAS para VMs 200/201/202
Write-Host "=== Discos no SeagateNAS ===" -ForegroundColor Cyan
try {
    $s = Invoke-RestMethod -Uri "$base/storage/SeagateNAS/content?content=images" -Headers $h
    $s.data | Select-Object volid, size, format | Sort-Object volid | Format-Table -AutoSize
} catch {
    Write-Host "Erro ao listar storage: $_" -ForegroundColor Red
}

# Status atual das VMs
Write-Host "=== Status VMs ===" -ForegroundColor Cyan
$vms = Invoke-RestMethod -Uri "$base/qemu" -Headers $h
$vms.data | Where-Object { $_.vmid -in @(200,201,202) } | Select-Object vmid, name, status | Format-Table -AutoSize
