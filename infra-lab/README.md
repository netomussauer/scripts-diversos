# infra-lab — scripts

Scripts especificos do home-lab K3s (`C:\Users\jose.mussauer\Documents\projetos\infra-lab`).

## Cluster K3s v1.29.3 — 5 nos

| Hostname K8s | IP | Label | Hardware |
| --- | --- | --- | --- |
| `k3s-server` | 192.168.1.30 | control-plane | VM Proxmox (VMID 200) |
| `k3s-worker-cicd` | 192.168.1.31 | workload=cicd | VM Proxmox (VMID 201) |
| `ci-runner` | 192.168.1.32 | workload=runner | VM Proxmox (VMID 202) |
| `ubuntu-neto` | 192.168.1.65 | workload=monitoring | Notebook i5 bare-metal |
| `raspneto` | 192.168.1.110 | workload=edge, arch=arm | Raspberry Pi ARMv7 |

Proxmox roda no node `virt` (192.168.1.20). Template das VMs do cluster: VMID 9000 (storage `SeagateNAS`).

## Subpastas

- [`proxmox-vms/`](proxmox-vms/) — Provisionamento e diagnostico das VMs 200/201/202 via Proxmox REST API.
- [`baremetal-ssh/`](baremetal-ssh/) — Diagnostico de SSH nos dois nos bare-metal (notebook-i5 e raspberry-pi).
- [`k8s/`](k8s/) — Helpers para operar o cluster K3s (wrappers WSL, bootstrap).

## Linha do tempo dos scripts de fix

Os scripts de `proxmox-vms/fix-*.ps1` foram criados em sequencia durante o bootstrap do cluster. Cada um resolveu um problema diferente:

1. `fix-scsihw.ps1` — primeira tentativa de setar `scsihw=virtio-scsi-pci`. Falhou (PowerShell descartou body).
2. `fix-scsihw2.ps1` — versao com `HttpWebRequest` manual. **Funcionou**.
3. `fix-machine-type.ps1` — forcou `machine=pc` (i440fx) nas VMs que estavam com q35.
4. `fix-boot.ps1` — reanexou disco como `virtio0` apos `scsi0` ter sido deletado.
5. `fix-disks.ps1` — reset completo (destroi + clona + redimensiona + configura). E o "big hammer".

Mantidos todos no repo porque cada um documenta um sintoma diferente que pode reaparecer.
