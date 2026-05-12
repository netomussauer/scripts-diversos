# =============================================================================
# Script:    fix-machine-type.ps1
# Projeto:   infra-lab (home-lab K3s da Stone)
# Atividade: Forcar machine=pc (i440fx) nas VMs 201 e 202 e iniciar.
# Contexto:  Usado quando o clone do template 9000 deixou as VMs com machine
#            type q35 e o boot falhou no Sandy Bridge bare-metal. i440fx
#            tem compatibilidade maior com hardware mais antigo.
# Pre-req:   - PowerShell com TLS 1.2 (script forca)
#            - Variavel de ambiente PVE_TOKEN definida
# Uso:       $env:PVE_TOKEN = 'PVEAPIToken=root@pam!<user>=<uuid>'
#            .\fix-machine-type.ps1
# =============================================================================

if (-not $env:PVE_TOKEN) {
    Write-Error "Defina `$env:PVE_TOKEN antes de rodar."
    exit 1
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustFix3 : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint sp, X509Certificate cert, WebRequest req, int problem) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustFix3

$token = $env:PVE_TOKEN
$h     = @{ 'Authorization' = $token }
$base  = 'https://192.168.1.20:8006/api2/json/nodes/virt/qemu'

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
    return $out
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

# Aplicar machine=pc nas VMs 201 e 202
foreach ($vmid in @(201, 202)) {
    Write-Host "Alterando VM ${vmid}: machine=pc (i440fx)..." -ForegroundColor Yellow
    try {
        Invoke-PvePut "$base/$vmid/config" "machine=pc" | Out-Null
        Write-Host "  OK" -ForegroundColor Green
    } catch {
        Write-Host "  Erro: $($_.Exception.Message)" -ForegroundColor Red
    }
    $cfg = Invoke-RestMethod -Uri "$base/$vmid/config" -Headers $h
    Write-Host "  machine = '$($cfg.data.machine)'"
}

# Iniciar VMs 201 e 202
Write-Host "`nIniciando VMs 201 e 202..." -ForegroundColor Cyan
foreach ($vmid in @(201, 202)) {
    try {
        Invoke-PvePost "$base/$vmid/status/start" $null | Out-Null
        Write-Host "  VM ${vmid} start enviado" -ForegroundColor Green
    } catch {
        Write-Host "  VM ${vmid} erro: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "Aguardando 30s..." -ForegroundColor Gray
Start-Sleep -Seconds 30

# Status final das 3 VMs
Write-Host "`nStatus final:" -ForegroundColor Cyan
$vms = Invoke-RestMethod -Uri $base -Headers $h
$vms.data | Where-Object { $_.vmid -in @(200,201,202) } | Select-Object vmid, name, status, uptime | Format-Table -AutoSize
