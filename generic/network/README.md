# generic / network

Scripts de rede sem vinculo com um projeto especifico.

| Script | Plataforma | O que faz |
| --- | --- | --- |
| `listip.ps1` | PowerShell (Windows) | Recebe subnet + range e mostra quais IPs respondem ao ping vs estao livres |
| `iptables.sh` | bash (Linux) | Template completo de firewall iptables. Mantido como referencia — NAO rodar diretamente em producao sem revisar |

## Uso

```powershell
.\listip.ps1
# Subnet: 192.168.1
# First Ip: 100
# Last IP: 1
```

```bash
# Apenas referencia — leia antes de rodar
less iptables.sh
```
