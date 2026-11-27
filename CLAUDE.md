# San & Co. Core (sancocore.com.br)

Projeto da San & Co. Segue as leis do plugin `san-co`.

## Antes de propor ou escrever qualquer coisa, leia
- `CONSTRAINTS.md`: o que NÃO se faz, incluindo a regra de comunicação das cotas
- `docs/specs/2026-11-27-plataforma-cotas.md`: a plataforma de cotas (rascunho, aguardando validação)
- `docs/pendencias.md`: o que falta e o que só o dono faz

## Classificação
Projeto, não estrutura. Consome o San Checkout, o Cloudflare (DNS e Access) e o Workspace.
Rigor: topo da escala (dinheiro, dado de terceiro, vida longa).

## Estado na esteira
Hoje: site institucional estático no ar.
Nova versão (plataforma de cotas): Estação 1 (Escopo), aberta em 27/11/2026.
Falta para fechar: as decisões do dono na spec §7.
Próxima: Estação 2 (Fronteiras), Sonnet com esforço médio.

## Mapa de caminhos
- Páginas: `index.html`, `empresas.html`, `contato.html`, `admin/index.html`
- Estilos: `css/variables.css` (tokens), `css/main.css`, `css/sections/`
- Scripts: `js/`
- Banco, migrations e funções: ainda não existem
- Testes: ainda não existem

## Conformidade
Uma violação segue o ciclo da skill `leis`: corrige ou vira exceção registrada no `CONSTRAINTS.md`.

## Pendências que bloqueiam a esteira
- Spec da plataforma de cotas não validada (spec §7)
- Projeto Supabase não criado
