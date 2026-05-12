# =============================================================================
# Script:    fix-scsihw.ps1
# Projeto:   infra-lab (home-lab K3s da Stone)
# Atividade: Setar scsihw=virtio-scsi-pci no template 9000 e nas VMs
#            200/201/202, depois iniciar as VMs.
# Contexto:  Primeira tentativa (Invoke-RestMethod direto via PUT). Em alguns
#            ambientes Windows o PowerShell descartou o body do PUT — ver
#            fix-scsihw2.ps1 (HttpWebRequest com stream manual) para a versao
#            que funcionou.
# Pre-req:   - Variavel de ambiente PVE_TOKEN definida
# Uso:       $env:PVE_TOKEN = 'PVEAPIToken=root@pam!<user>=<uuid>'
#            .\fix-scsihw.ps1
# =============================================================================

if (-not $env:PVE_TOKEN) {
    Write-Error "Defina `$env:PVE_TOKEN antes de rodar."
    exit 1
}

add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustPveFix : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint sp, X509Certificate cert, WebRequest req, int problem) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustPveFix

$h_put = @{
    'Authorization' = $env:PVE_TOKEN
    'Content-Type'  = 'application/x-www-form-urlencoded'
}
$h_get = @{ 'Authorization' = $env:PVE_TOKEN }
$base = 'https://192.168.1.20:8006/api2/json/nodes/virt/qemu'

# Setar scsihw=virtio-scsi-pci no template e nas 3 VMs
foreach ($vmid in @(9000, 200, 201, 202)) {
    try {
        Invoke-RestMethod -Uri "$base/$vmid/config" -Headers $h_put -Method PUT -Body 'scsihw=virtio-scsi-pci' | Out-Null
        $r = Invoke-RestMethod -Uri "$base/$vmid/config" -Headers $h_get
        Write-Host "VM $vmid scsihw: '$($r.data.scsihw)'" -ForegroundColor Green
    } catch {
        Write-Host "VM $vmid ERRO: $_" -ForegroundColor Red
    }
}

# Iniciar as 3 VMs
Write-Host "`nIniciando VMs..." -ForegroundColor Cyan
foreach ($vmid in @(200, 201, 202)) {
    try {
        $r = Invoke-RestMethod -Uri "$base/$vmid/status/start" -Headers $h_get -Method POST
        Write-Host "VM $vmid start task: $($r.data)" -ForegroundColor Green
    } catch {
        Write-Host "VM $vmid start ERRO: $_" -ForegroundColor Red
    }
}
