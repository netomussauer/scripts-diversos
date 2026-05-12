# generic / azure

Scripts antigos de provisionamento Azure. Mantidos como referencia historica.

| Script | Status | O que faz |
| --- | --- | --- |
| `create-webapp.ps1` | Legado | Cria App Service Plan + Web App PHP via `az` CLI, com naming `<Tenant>-<Env>-<Servico>-...`. Sintaxe e bash com extensao .ps1 (heranca de quando foi escrito) |

## Origem

Script importado de trabalhos antigos no contexto Mundipagg/Stone. A subscription, naming convention e configuracoes (PHP 7.1, 32-bit worker) refletem o ambiente daquele periodo — nao roda mais sem ajustes.

## Padroes uteis

Mesmo nao sendo executavel hoje, o script documenta:

- Naming convention: `<Tenant>-<Env>-<Servico>-<Recurso>-<Location>-<Index>`
- Idempotencia: `if [[ -z $(az ... show) ]]; then az ... create; fi`
- Aplicacao de AppSettings em loop apos a criacao do recurso
