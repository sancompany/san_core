# Plataforma de Passes de Acesso — escopo da v1

**Estado: VALIDADO pelo dono em 27/11/2026 (v1 enxuta).** Origem: a diretriz
"Atualização de arquitetura e diretrizes operacionais", recebida em
27/11/2026, a simplificação para "Gratuito vs. Membro" e o preço por passe
avulso, definidos no mesmo dia.

## 1. O que é

`sancocore.com.br` continua apresentando a San & Co. e passa a vender
**Passes de Acesso** avulsos. O passe é a unidade do clube: acumula no
perfil e, no futuro, mais passes liberam mais níveis. Na v1, o primeiro
pedido já transforma a conta em **Membro**. O coração do produto é a
página `/community`. É um clube de acesso, não uma participação societária
(`CONSTRAINTS.md` §1).

Regra de comunicação: `CONSTRAINTS.md` §1.

## 2. Páginas

| Rota | Quem vê | O que tem |
|---|---|---|
| `/` | Todos | A apresentação da San & Co. e a venda dos passes |
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

## 4. Preço

| Regra | Valor |
|---|---|
| Preço do passe | **R$ 2,90** |
| Mínimo por pedido | **2 passes** (R$ 5,80) |
| Máximo por pedido | 500 passes (limite de risco, escolhido na implementação) |
| Taxa do Checkout | **Isentada** (`isentarTaxa: true`): o comprador paga exatamente o preço anunciado |

Os passes são **intransferíveis e não expiram**. Qualquer pedido pago dá
acesso imediato ao nível Membro.

Por que o mínimo é 2: com a taxa isentada, o valor cobrado é o próprio
preço, e a Asaas recusa cobrança abaixo de R$ 5,00 (API.md §9.1). Um passe
(R$ 2,90) não passaria; dois (R$ 5,80) passam. O banco garante isso: um
preço cujo pedido mínimo fique abaixo do piso não pode ser cadastrado, e
nenhum pedido abaixo de R$ 5,00 existe.

Consequências a conhecer:
- **A San & Co. absorve a taxa da Asaas.** No pedido mínimo, sobram cerca
  de R$ 3,81 no Pix (taxa de R$ 1,99) e R$ 5,14 no cartão à vista. Esses
  são valores de referência do API.md §8; o valor real vem no webhook.
- **No cartão, a parcela mínima é de R$ 5,00.** Pedidos de até 3 passes
  saem só à vista; 4 passes (R$ 11,60) já aceitam 2x.
- **O acesso de Membro é vitalício** a partir do primeiro pedido, porque
  na v1 nada consome nem expira passes. Enquanto só existir o nível
  Membro, comprar mais passes não libera nada além disso.

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
| 1 — Banco | Migration, RLS, seed de níveis e do preço, testes | Migration aplicada no projeto Supabase, advisors de segurança limpos, CI verde |
| 2 — Checkout | `criar_pedido(quantidade)` com mínimo e máximo, `isentarTaxa: true` no `GET /pedido`, Edge Functions `GET /pedido/{id}` e `POST /webhook`, conciliação diária, botão de arrependimento de 7 dias | Os seis passos do API.md com pagamento real, incluindo estorno e rebaixamento |
| 3 — Área de membros | Login, `/community`, acervo com URL assinada, extrato, exportar e excluir a conta | Fluxo completo no ar, do cadastro ao download |
| 4 — Cláudio | Onboarding, publicação, suporte de primeira linha, fila humana | Cada rotina rodou no ar com log; um pedido de reembolso caiu na fila humana |
| 5 — Vitrine | Tela de cadastro e moderação dos produtos | Produto de Membro publicado após revisão |

Depois vêm a Prontidão e o Lançamento: Termos de Uso e Política publicados
antes de qualquer divulgação.

## 7. Fora da v1

A escada de quatro níveis e as videoaulas estão em
`docs/proximas-versoes.md`. Intermediar pagamento na vitrine e transferir
passes estão vetados no `CONSTRAINTS.md` §2.
