# infra-lab / proxmox-vms

Scripts que operam diretamente na API REST do Proxmox (`https://192.168.1.20:8006/api2/json`) para provisionar, diagnosticar e corrigir as VMs do cluster K3s (200, 201, 202).

## Pre-requisitos (vale para todos)

Todos os scripts exigem a variavel de ambiente `PVE_TOKEN`:

```powershell
$env:PVE_TOKEN = 'PVEAPIToken=root@pam!root=<uuid-do-token>'
```

Se nao definida, o script aborta com mensagem clara antes de fazer qualquer chamada HTTP.

Os scripts ja forcam TLS 1.2 e desabilitam validacao de certificado (necessario porque o Proxmox do lab usa cert self-signed).

## Scripts

| Script | O que faz | Quando usar |
| --- | --- | --- |
| `config-vms.ps1` | Aplica sshkey nas VMs 200/201/202 e da boot | Apos clone das VMs, ja com discos configurados |
| `restart-vms.ps1` | Force stop + start das VMs | Apos mudanca de cloud-init, machine type, scsihw |
| `check-vms.ps1` | Mostra config da VM 200, discos no SeagateNAS, status | Inspecao rapida pre/pos mudanca |
| `diag-vms.ps1` | Diagnostico ampliado: storage, cloud-init, tasks, config | Primeira parada quando algo nao boota |
| `fix-boot.ps1` | Reanexa virtio0 e ajusta boot order | Quando scsi0 foi deletado e disco precisa ser re-anexado |
| `fix-disks.ps1` | Reset completo (destroi + clona + configura) | Quando o clone original deu errado de algum jeito grave |
| `fix-machine-type.ps1` | Forca `machine=pc` (i440fx) nas VMs 201/202 | VMs criadas com q35 que nao bootaram |
| `fix-scsihw.ps1` | Seta `scsihw=virtio-scsi-pci` — versao 1 (falha) | NAO usar, mantida como historico |
| `fix-scsihw2.ps1` | Seta `scsihw=virtio-scsi-pci` — versao 2 (OK) | A versao que funcionou |

## Mapeamento VMID -> ambiente

| VMID | Hostname | IP | Perfil |
| --- | --- | --- | --- |
| 200 | k3s-server | 192.168.1.30/24 | 2 cores / 4 GB / 40 GB |
| 201 | k3s-worker-cicd | 192.168.1.31/24 | 4 cores / 6 GB / 60 GB |
| 202 | ci-runner | 192.168.1.32/24 | 2 cores / 4 GB / 40 GB |
| 9000 | template | — | Template usado para clone |
