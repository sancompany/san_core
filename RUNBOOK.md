# RUNBOOK — San & Co. Core

Iniciado em 27/11/2026. Cresce a cada etapa e só descreve o que já existe.

## Reverter o site

O Cloudflare Pages guarda cada deploy. No painel, abra Workers & Pages →
`san-core` → Deployments, escolha o deploy anterior e clique em
**Rollback**. Para deixar o repositório no mesmo estado, faça
`git revert <commit>` na `main`.

## Banco

- Migrations só para frente. Migration aplicada não se edita: a correção é
  uma migration nova (Lei 6).
- **O `passes_ledger` não aceita UPDATE, DELETE nem TRUNCATE.** Para
  corrigir um saldo, faça um lançamento `ajuste` com `motivo` e `criado_por`.
- Backup e restauração: pendente até o projeto Supabase existir.
- Toda tabela nova: ligar RLS e revogar os privilégios padrão que o Supabase dá a
  `anon`/`authenticated` (o topo da migration base explica).
