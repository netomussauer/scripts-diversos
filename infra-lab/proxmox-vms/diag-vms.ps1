# =============================================================================
# Script:    diag-vms.ps1
# Projeto:   infra-lab (home-lab K3s da Stone)
# Atividade: Diagnostico ampliado: tipo de storage SeagateNAS, discos do
#            template 9000 e das VMs 200/201/202, cloud-init no local-lvm,
#            ultimas 20 tasks do node virt e config completa da VM 200.
# Contexto:  Primeira parada quando algo nao boota — concentra todas as
#            informacoes que costumam ser necessarias para entender o estado
#            atual do cluster.
# Pre-req:   - PowerShell com TLS 1.2 (script forca)
#            - Variavel de ambiente PVE_TOKEN definida
# Uso:       $env:PVE_TOKEN = 'PVEAPIToken=root@pam!<user>=<uuid>'
#            .\diag-vms.ps1
# =============================================================================

if (-not $env:PVE_TOKEN) {
    Write-Error "Defina `$env:PVE_TOKEN antes de rodar."
    exit 1
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustDiag2 : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint sp, X509Certificate cert, WebRequest req, int problem) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustDiag2

$h    = @{ 'Authorization' = $env:PVE_TOKEN }
$node = 'https://192.168.1.20:8006/api2/json/nodes/virt'

# --- Tipo do storage SeagateNAS ---
Write-Host "=== Storage SeagateNAS ===" -ForegroundColor Cyan
try {
    $s = Invoke-RestMethod -Uri "$node/storage" -Headers $h
    $s.data | Where-Object { $_.storage -eq 'SeagateNAS' } | Format-List
} catch { Write-Host "Erro: $_" -ForegroundColor Red }

# --- Discos do template e VMs no SeagateNAS ---
Write-Host "=== Discos no SeagateNAS (vmid 9000/200/201/202) ===" -ForegroundColor Cyan
try {
    $c = Invoke-RestMethod -Uri "$node/storage/SeagateNAS/content?content=images" -Headers $h
    $c.data | Where-Object { $_.vmid -in @(9000,200,201,202) } |
        Select-Object vmid, volid, size, format, used | Format-Table -AutoSize
} catch { Write-Host "Erro: $_" -ForegroundColor Red }

# --- Discos cloud-init no local-lvm ---
Write-Host "=== Cloud-init no local-lvm ===" -ForegroundColor Cyan
try {
    $cl = Invoke-RestMethod -Uri "$node/storage/local-lvm/content" -Headers $h
    $cl.data | Where-Object { $_.vmid -in @(200,201,202) } |
        Select-Object vmid, volid, size, format | Format-Table -AutoSize
} catch { Write-Host "Erro: $_" -ForegroundColor Red }

# --- Tasks recentes (erros de boot) ---
Write-Host "=== Ultimas 20 tasks do node ===" -ForegroundColor Cyan
try {
    $t = Invoke-RestMethod -Uri "$node/tasks?limit=20" -Headers $h
    $t.data | Select-Object upid, type, status, starttime | Format-Table -AutoSize
} catch { Write-Host "Erro: $_" -ForegroundColor Red }

# --- Config completa da VM 200 ---
Write-Host "=== Config completa VM 200 ===" -ForegroundColor Cyan
try {
    $r = Invoke-RestMethod -Uri "$node/qemu/200/config" -Headers $h
    $r.data | Format-List
} catch { Write-Host "Erro: $_" -ForegroundColor Red }
