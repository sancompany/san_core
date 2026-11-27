# San & Co. Core

O site `sancocore.com.br`: apresentação da San & Co. e a plataforma de
Passes de Acesso. O escopo está em `docs/specs/2026-11-27-plataforma-passes.md`.

## Como roda

- **Site:** HTML, CSS e JS estáticos na raiz, publicados pelo Cloudflare
  Pages (projeto `san-core`) a cada push. Push na `main` publica em
  produção; cada branch ganha um preview em `*.san-core.pages.dev`.
  `_redirects` impede que os documentos internos sejam servidos.
- **Banco:** Supabase. O schema está em `supabase/migrations/`.

## Testes

```bash
tests/db/run.sh
```

Esse comando sobe um Postgres descartável, aplica `tests/db/supabase_stub.sql`
(o mínimo do ambiente Supabase) e todas as migrations, e roda os
`tests/db/test_*.sql`. Ele precisa de `initdb`/`pg_ctl` locais, ou de
`PGURL` apontando para um banco vazio, que é como o CI roda.

## Variáveis

Nenhuma ainda. Nascem na Etapa 2 (chave do Checkout, só como segredo de
servidor) e ficam listadas em `.env.example`.
