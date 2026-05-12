# infra-lab / k8s

Helpers para operar o cluster K3s a partir do Windows via WSL.

## Scripts

| Script | O que faz |
| --- | --- |
| `run-k8s-bootstrap.sh` | Wrapper que entra no WSL com PATH e KUBECONFIG corretos e invoca `infra-lab/scripts/k8s-bootstrap.sh "$@"` |

## Por que o wrapper existe

Quando o PowerShell chama o WSL via `wsl -d Ubuntu -- bash -c "..."`, o PATH herdado do Windows entra com parenteses (`C:\Program Files (x86)\...`) e quebra a interpretacao do shell. O wrapper resolve isso fixando o PATH e o KUBECONFIG antes de invocar o script real.

Padrao oficial documentado no CLAUDE.md global.

## Uso

```bash
wsl -d Ubuntu -- bash /mnt/c/Users/jose.mussauer/Documents/projetos/scripts-diversos/infra-lab/k8s/run-k8s-bootstrap.sh [args]
```

Ou via heredoc no PowerShell, como instrui o CLAUDE.md.
