# =============================================================================
# Script:    fix-scsihw2.ps1
# Projeto:   infra-lab (home-lab K3s da Stone)
# Atividade: Setar scsihw=virtio-scsi-pci no template 9000 e nas VMs
#            200/201/202 — versao que efetivamente funcionou.
# Contexto:  Substitui fix-scsihw.ps1: usa HttpWebRequest com stream manual
#            para garantir que o body do PUT chegue ao Proxmox. Forca TLS 1.2.
# Pre-req:   - PowerShell com TLS 1.2 (script forca)
#            - Variavel de ambiente PVE_TOKEN definida
# Uso:       $env:PVE_TOKEN = 'PVEAPIToken=root@pam!<user>=<uuid>'
#            .\fix-scsihw2.ps1
# =============================================================================

if (-not $env:PVE_TOKEN) {
    Write-Error "Defina `$env:PVE_TOKEN antes de rodar."
    exit 1
}

# Forcar TLS 1.2 para compatibilidade com Proxmox
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustPveFix2 : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint sp, X509Certificate cert, WebRequest req, int problem) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustPveFix2

$token = $env:PVE_TOKEN
$base  = 'https://192.168.1.20:8006/api2/json/nodes/virt/qemu'

foreach ($vmid in @(9000, 200, 201, 202)) {
    try {
        $req = [System.Net.HttpWebRequest]::Create("$base/$vmid/config")
        $req.Method = 'PUT'
        $req.Headers.Add('Authorization', $token)
        $req.ContentType = 'application/x-www-form-urlencoded'
        $body = [System.Text.Encoding]::UTF8.GetBytes('scsihw=virtio-scsi-pci')
        $req.ContentLength = $body.Length
        $stream = $req.GetRequestStream()
        $stream.Write($body, 0, $body.Length)
        $stream.Close()
        $resp = $req.GetResponse()
        $resp.Close()
        Write-Host "VM $vmid : scsihw setado OK" -ForegroundColor Green
    } catch {
        Write-Host "VM $vmid ERRO: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Verificar
Write-Host "`nVerificando configuracao:" -ForegroundColor Cyan
$h = @{ 'Authorization' = $token }
foreach ($vmid in @(9000, 200, 201, 202)) {
    $r = Invoke-RestMethod -Uri "$base/$vmid/config" -Headers $h
    $s = if ($r.data.scsihw) { $r.data.scsihw } else { '(vazio)' }
    Write-Host "  VM $vmid scsihw: '$s'"
}
