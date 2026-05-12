# =============================================================================
# Script:    listip.ps1
# Projeto:   generic (utilitario de rede, sem projeto especifico)
# Atividade: Varrer um range de uma sub-rede IPv4 com ping e mostrar quais
#            IPs estao livres (sem resposta) vs em uso (com resposta).
# Contexto:  Util quando precisa alocar um IP estatico em um lab/segmento
#            sem servidor DHCP autoritativo. Roda apenas no Windows
#            (depende de Test-Connection).
# Pre-req:   - PowerShell
# Uso:       .\listip.ps1
#              Subnet: 192.168.1
#              First Ip: 100
#              Last IP: 1
# =============================================================================

$subnet = Read-Host -Prompt "Subnet"
$fristIP = [int](Read-Host -Prompt "First Ip")
$lastIP = [int](Read-Host -Prompt "Last IP")

for ($i = $fristIP; $i -ge $lastIP; $i--) {
    $ip = "$subnet.$i"
    $ping = Test-Connection $ip -count 1 -quiet
    if ($ping -eq $False) {
        Write-Host -ForegroundColor Green "[$ip] # IP Address free for use #"
        # $availableips += "$ip,Available"
    } else {
        write-host -f red "[$ip] # IP Address alredy in use #"
    }
}