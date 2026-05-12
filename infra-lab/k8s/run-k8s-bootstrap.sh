#!/usr/bin/env bash
# =============================================================================
# Script:    run-k8s-bootstrap.sh
# Projeto:   infra-lab (home-lab K3s da Stone)
# Atividade: Wrapper WSL para executar o k8s-bootstrap.sh dentro do repo
#            infra-lab, com PATH corrigido (evita parenteses do PATH do
#            Windows) e KUBECONFIG apontando para o cluster.
# Contexto:  Padrao obrigatorio para chamadas WSL no infra-lab — ver
#            CLAUDE.md global. Argumentos sao repassados via "$@".
# Pre-req:   - Repo infra-lab clonado em
#              /mnt/c/Users/jose.mussauer/Documents/projetos/infra-lab
#            - Kubeconfig em ~/.kube/infra-lab.yaml
#            - Binarios kubectl/helm em /usr/local/bin ou ~/.local/bin
# Uso:       wsl -d Ubuntu -- bash run-k8s-bootstrap.sh [args...]
# =============================================================================

export PATH=/home/netomussauer/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export KUBECONFIG=~/.kube/infra-lab.yaml

exec bash /mnt/c/Users/jose.mussauer/Documents/projetos/infra-lab/scripts/k8s-bootstrap.sh "$@"
