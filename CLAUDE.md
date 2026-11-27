# San & Co. Core (sancocore.com.br)

Projeto da San & Co. Segue as leis do plugin `san-co`.

## Antes de propor ou escrever qualquer coisa, leia
- `CONSTRAINTS.md`: o que NÃO se faz, incluindo a regra de comunicação dos passes
- `docs/specs/2026-11-27-plataforma-passes.md`: escopo da v1 (Gratuito vs. Membro)
- `docs/pendencias.md`: o que falta e o que só o dono faz
- `docs/inventario-de-dados.md`: dados pessoais e subprocessadores
- `docs/proximas-versoes.md`: o que ficou para depois
- `RUNBOOK.md`: como reverter e operar
- `README.md`: como rodar e testar

## Classificação
Projeto, não estrutura. Consome o San Checkout, o Cloudflare (Pages, DNS e Access) e o Workspace.
Banco próprio (Supabase `san_core`). Rigor: topo da escala (dinheiro, dado de terceiro, vida longa).

## Estado na esteira
Estação atual: 4 (Contratos), Etapa 1 (Banco), aberta em 27/11/2026.
Fechadas:
- 1 Escopo: spec validada pelo dono em 27/11/2026 · evidência: `docs/specs/2026-11-27-plataforma-passes.md`
- 2 Fronteiras: classificação e hospedagem · evidência: spec §5
- 3 Fundação: aberta com exceção. Repositório, `.gitignore` e testes existem; o CI está pronto, mas falta o dono colar o workflow (`infra/ci/ci.yml`)
Falta para fechar a atual: ver "Etapa 1" em `docs/pendencias.md`.

## Mapa de caminhos
- Páginas: `index.html`, `empresas.html`, `contato.html`, `admin/index.html` · deploy: Cloudflare Pages; `_redirects` protege os docs
- Estilos: `css/variables.css` (tokens), `css/main.css`, `css/sections/` · scripts: `js/`
- Banco: `supabase/migrations/` · testes: `tests/db/` (`tests/db/run.sh`)
- CI (a colar): `infra/ci/ci.yml` → `.github/workflows/ci.yml`

## Conformidade
Uma violação segue o ciclo da skill `leis`: corrige ou vira exceção registrada no `CONSTRAINTS.md`.

## Pendências que bloqueiam a esteira
- Projeto Supabase não criado (plano Free no limite de 2 projetos)
- Workflow de CI não colado em `.github/workflows/`
