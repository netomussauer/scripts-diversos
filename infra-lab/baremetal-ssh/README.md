# infra-lab / baremetal-ssh

Scripts de diagnostico de SSH nos dois nos bare-metal do cluster — notebook-i5 (`192.168.1.65`, hostname K8s `ubuntu-neto`) e raspberry-pi (`192.168.1.110`, hostname K8s `raspneto`).

Diferente dos scripts em `proxmox-vms/`, estes nao mexem em nada — sao puramente de leitura/observacao. Servem para responder: "por que eu nao consigo entrar?" ou "qual chave + usuario funciona?".

## Pre-requisitos

- Bash (Linux ou WSL)
- Chaves SSH em `~/.ssh/`: `lab_id_rsa`, `id_ed25519`, `id_ed25519_jump`

## Scripts

| Script | O que faz | Quando usar |
| --- | --- | --- |
| `probe-baremetal.sh` | Scan rapido de portas comuns + tentativas de chave x usuario nos dois nos | Diagnostico de primeira leva, sem dependencias |
| `diagnose-i5.sh` | Focado no notebook-i5: portas, fingerprint, banner, cross-tentativas e auth methods anunciados | Quando ja sabe que o i5 esta com problema |
| `fix-labadmin.sh` | Conecta como `netomussauer` no i5 e verifica usuario `labadmin`, authorized_keys, sudoers, sshd_config | Quando cloud-init/Ansible nao terminou de provisionar labadmin |

## Mapeamento inventario Ansible -> hostname K8s

| Inventario | Hostname real | IP |
| --- | --- | --- |
| `notebook-i5` | `ubuntu-neto` | 192.168.1.65 |
| `raspberry-pi` | `raspneto` | 192.168.1.110 |

> Note esse descasamento — o nome no inventario do Ansible nao bate com o hostname efetivo do node no K8s.
