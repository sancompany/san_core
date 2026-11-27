# Plataforma de Passes de Acesso — escopo da v1

**Estado: VALIDADO pelo dono em 27/11/2026 (v1 enxuta).** Origem: a diretriz
"Atualização de arquitetura e diretrizes operacionais", recebida em
27/11/2026, e a simplificação para "Gratuito vs. Membro" feita no mesmo dia.

## 1. O que é

`sancocore.com.br` continua apresentando a San & Co. e passa a vender
**pacotes de Passes de Acesso**. Comprar qualquer pacote transforma a conta
em **Membro**. O coração do produto é a página `/community`.

Regra de comunicação: `CONSTRAINTS.md` §1.

## 2. Páginas

| Rota | Quem vê | O que tem |
|---|---|---|
| `/` | Todos | A apresentação da San & Co. e a oferta dos pacotes |
| `/community` | Todos | Visitante e Gratuito veem a vitrine do acervo, com cadeado e chamada para virar Membro no que é fechado. O Membro vê tudo |

## 3. Níveis: dois estados

| Nível | Regra | Libera |
|---|---|---|
| 0 — Gratuito | Conta criada, 0 passes | Conteúdo aberto, posts abertos do Cláudio, preview (título e resumo) do que é fechado |
| 1 — Membro | ≥ 1 passe | Acervo completo (e-books, ensinamentos, futuras videoaulas) e publicação na vitrine, só como divulgação com link externo |

- O visitante sem login vê apenas a vitrine com cadeado. Para ler até o
  conteúdo aberto, ele cria a conta Gratuita, que é livre. Essa regra foi
  escolhida na implementação e é fácil de inverter.
- O saldo exato de passes fica no ledger para expansões futuras. A
  permissão da v1 só pergunta se o nível é 0 ou 1. A tabela `niveis_config`
  já aceita mais faixas sem mudar o esquema.
- O estorno de todos os passes devolve a conta para Gratuito.

## 4. Pacotes

| Pacote | Passes | Preço |
|---|---|---|
| Inicial | 10 | R$ 19,90 |
| Padrão | 30 | R$ 49,90 |
| Apoiador | 100 | R$ 129,90 |

Os passes são **intransferíveis e não expiram**. Qualquer pacote dá acesso
imediato ao nível Membro.

Duas consequências a conhecer:
- **O acesso de Membro é vitalício** a partir da primeira compra, porque na
  v1 nada consome nem expira passes.
- **No cartão, o piso da Asaas é de R$ 5,00 por parcela** (API.md §9.1). O
  pacote Inicial aceita no máximo 3 parcelas, já contando a taxa do
  Checkout por cima.

## 5. Arquitetura (aprovada)

- **Projeto Supabase próprio** `san_core` em `sa-east-1`, com Auth,
  Postgres com RLS, Storage, Edge Functions e `pg_cron`. O front continua
  estático no Cloudflare Pages.
- **Pagamento pelo San Checkout** no modelo pull. O id do pedido é UUID.
- **Papéis de equipe em `user_roles`** (N:N): `ai_agent`, `editor`,
  `moderator`, `support` e `admin`. Ser Gratuito ou Membro não é papel: é
  nível, derivado do saldo.
- **As rotinas do Cláudio** rodam como Edge Functions com Cron, chamando a
  API da Claude. Elas registram tudo em `agent_logs`, mandam o que foge do
  padrão para `escalonamentos` e nunca mexem em dinheiro nem em saldo.

O schema completo é a migration
`supabase/migrations/20261127000100_base.sql`. As regras de saldo, nível e
permissão estão testadas em `tests/db/test_01_regras.sql`.

## 6. Etapas

| Etapa | Conteúdo | Fecha quando |
|---|---|---|
| 1 — Banco | Migration, RLS, seed de níveis e pacotes, testes | Migration aplicada no projeto Supabase, advisors de segurança limpos, CI verde |
| 2 — Checkout | `criar_pedido`, Edge Functions `GET /pedido/{id}` e `POST /webhook`, conciliação diária, botão de arrependimento de 7 dias | Os seis passos do API.md com pagamento real, incluindo estorno e rebaixamento |
| 3 — Área de membros | Login, `/community`, acervo com URL assinada, extrato, exportar e excluir a conta | Fluxo completo no ar, do cadastro ao download |
| 4 — Cláudio | Onboarding, publicação, suporte de primeira linha, fila humana | Cada rotina rodou no ar com log; um pedido de reembolso caiu na fila humana |
| 5 — Vitrine | Tela de cadastro e moderação dos produtos | Produto de Membro publicado após revisão |

Depois vêm a Prontidão e o Lançamento: Termos de Uso e Política publicados
antes de qualquer divulgação.

## 7. Fora da v1

A escada de quatro níveis e as videoaulas estão em
`docs/proximas-versoes.md`. Intermediar pagamento na vitrine e transferir
passes estão vetados no `CONSTRAINTS.md` §2.
