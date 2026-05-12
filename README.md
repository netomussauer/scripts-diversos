# scripts-diversos

Repositorio centralizado de scripts utilitarios reaproveitaveis — automacao, diagnostico, provisionamento e operacoes pontuais que surgem nos projetos do dia-a-dia.

Cada script tem um cabecalho no topo declarando **Projeto**, **Atividade**, **Contexto**, **Pre-requisitos** e **Uso** — para que daqui a seis meses ainda seja obvio em qual situacao ele foi escrito e quando faz sentido rodar.

---

## Estrutura

```text
scripts-diversos/
├── generic/                       # Scripts genericos, reusaveis em qualquer projeto
│   ├── network/                   # Utilitarios de rede
│   │   ├── listip.ps1             # Lista IPs livres em um range
│   │   └── iptables.sh            # Template de firewall iptables (referencia)
│   └── azure/
│       └── create-webapp.ps1      # Provisionamento de Web App no Azure (legado)
│
└── infra-lab/                     # Scripts especificos do home-lab K3s
    ├── proxmox-vms/               # Operacoes em VMs do Proxmox via API
    │   ├── config-vms.ps1         # Aplica sshkey + start nas VMs k3s
    │   ├── restart-vms.ps1        # Force stop + start das VMs k3s
    │   ├── check-vms.ps1          # Inspeciona config/disco/status
    │   ├── diag-vms.ps1           # Diagnostico completo (storage, tasks, config)
    │   ├── fix-boot.ps1           # Reanexa virtio0 e ajusta boot order
    │   ├── fix-disks.ps1          # Destroi, clona e configura VMs do zero
    │   ├── fix-machine-type.ps1   # Forca machine=pc (i440fx)
    │   ├── fix-scsihw.ps1         # Seta scsihw (versao 1, falhou)
    │   └── fix-scsihw2.ps1        # Seta scsihw (versao 2, funcionou)
    ├── baremetal-ssh/             # Diagnostico SSH nos nos bare-metal
    │   ├── diagnose-i5.sh         # Probe completo do notebook-i5
    │   ├── fix-labadmin.sh        # Diagnosticar usuario labadmin
    │   └── probe-baremetal.sh     # Scan rapido i5 + raspberry-pi
    └── k8s/
        └── run-k8s-bootstrap.sh   # Wrapper WSL para k8s-bootstrap do infra-lab
```

---

## Convencoes

### Cabecalho dos scripts

Todo script novo deve carregar um cabecalho como este:

```text
# Script:    nome.ext
# Projeto:   <projeto a que pertence ou "generic">
# Atividade: <o que ele faz, em uma linha>
# Contexto:  <quando foi escrito / em que situacao roda>
# Pre-req:   <dependencias e env vars>
# Uso:       <comando para invocar>
```

### Segredos

Scripts **NUNCA** carregam credenciais em texto puro. O padrao e ler via variavel de ambiente e falhar cedo se a var nao estiver definida.

Exemplo para os scripts Proxmox:

```powershell
# Antes de rodar qualquer script de infra-lab/proxmox-vms/:
$env:PVE_TOKEN = 'PVEAPIToken=root@pam!root=<uuid>'
.\config-vms.ps1
```

Se voce esquecer de exportar, o script aborta com mensagem clara.

### Shell

- Scripts `.ps1` rodam em PowerShell (Windows).
- Scripts `.sh` rodam em bash — no Windows, via WSL (`wsl -d Ubuntu`).

### Renomeacoes

- `iptables.txt` foi renomeado para `iptables.sh` (era um script bash com extensao .txt).
- O par `fix-scsihw.ps1` / `fix-scsihw2.ps1` foi mantido intencionalmente: a v1 documenta a tentativa que nao funcionou (Invoke-RestMethod descarta body do PUT em algumas versoes do PowerShell); a v2 e a versao final (HttpWebRequest com stream manual).

---

## Indice por projeto

- **infra-lab** — home-lab K3s: 5 nos, stack Gitea/Tekton/Harbor/ArgoCD/kube-prometheus-stack/Loki/MetalLB/Traefik/NetBox. Ver [infra-lab/README.md](infra-lab/README.md).
- **generic** — sem projeto especifico. Ver [generic/network/README.md](generic/network/README.md) e [generic/azure/README.md](generic/azure/README.md).
