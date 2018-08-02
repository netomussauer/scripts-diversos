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