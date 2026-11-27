# Plataforma de Cotas de Acesso — proposta de escopo

**Estado: RASCUNHO, aguardando validação do dono.** Nada daqui foi aplicado
em produção. Não existe banco, migration nem integração ainda. Este arquivo
só vira "escopo validado" (Lei 10) depois das decisões da seção 7.

Origem: diretriz "Atualização de arquitetura e diretrizes operacionais —
San & Co.", recebida em 27/11/2026.

---

## 1. O que muda

`sancocore.com.br` deixa de ser só a vitrine institucional e passa a ser uma
plataforma de comunidade e educação. O membro compra **pacotes de Cotas de
Acesso**. As cotas se acumulam no perfil, definem o nível (patente) e
desbloqueiam conteúdo, ferramentas comerciais e áreas da comunidade.

**A regra de comunicação está em `CONSTRAINTS.md` §1.** Resumo: a cota vale
acesso, status e ferramenta. Não vale dinheiro, não rende e não dá parte da
empresa.

## 2. Auditoria: o que existe hoje (medido em 27/11/2026)

| Peça | Estado | Evidência |
|---|---|---|
| Site estático (3 páginas + `/admin`) | No ar pelo Cloudflare. O `index.html` servido é idêntico ao do repositório | `curl https://sancocore.com.br` comparado com `index.html` |
| `www.sancocore.com.br` | **Quebrado: HTTP 522** (o Cloudflare não alcança a origem) | `curl -I https://www.sancocore.com.br` |
| Autenticação | Não existe. `js/admin.js` só mostra um `alert` | `js/admin.js:1-10` |
| `/admin/` | Público, **sem Cloudflare Access** (responde 200 direto) | `curl -I https://sancocore.com.br/admin/` |
| Formulário de contato | **Descarta a mensagem e mostra "enviado"**: o visitante acha que falou com a empresa | `js/contato.js:7-15` |
| Banco de dados | Não existe. A organização Supabase só tem `MostrAi` e `San_Checkout` | `list_projects` do Supabase |
| Checkout | O San Checkout existe e está em produção (estrutura). Este projeto ainda não está cadastrado como contratante | `sancompany/san_checkout/API.md` |
| `CLAUDE.md`, `CONSTRAINTS.md`, CI, `.gitignore`, `.env.example` | Não existiam (criados agora, exceto CI e `.env.example`) | este commit |
| Termos de Uso e Política de Privacidade do site | Não existem | — |

**Aproveitável:** layout, tokens visuais (`css/variables.css`), identidade e
a tela de login (só visual). **Precisa ser criado:** todo o resto da seção 4.

## 3. Fronteiras (skill `classificar`)

- **Projeto, não estrutura.** Tem público próprio (os membros). Consome a
  estrutura que já existe: Checkout, domínio e DNS no Cloudflare, Access,
  e-mail Workspace.
- **Banco próprio:** um projeto Supabase novo, `san_core`, em `sa-east-1`,
  como os outros dois. Nunca dentro do banco do Checkout ou do MostrAi.
- **Pagamento:** consome o San Checkout pelo modelo pull. Nenhuma cobrança
  própria.
- **Hospedagem:** o front-end continua estático no Cloudflare. O back-end
  fica no Supabase (Auth, Postgres com RLS, Storage, Edge Functions,
  `pg_cron`). Não precisa de servidor próprio.

## 4. Modelo de dados proposto

O ledger é a fonte da verdade. `profiles.total_cotas` e
`profiles.nivel_atual` são cache, recalculados por função no banco dentro da
mesma transação do lançamento. Nunca são escritos pela aplicação.

```sql
-- Papéis: tabela N:N em vez de uma coluna `role`, para que uma pessoa
-- possa ser editor e suporte ao mesmo tempo, e o handoff seja só uma linha.
create type papel as enum ('member','ai_agent','editor','moderator','support','admin');

create table niveis_config (
  nivel_id       smallint primary key,
  nome           text not null,
  cotas_minimas  integer not null unique check (cotas_minimas >= 0),
  permissoes     jsonb not null default '{}'   -- ex.: {"vender": true, "areas": ["mesa"]}
);

create table profiles (
  id            uuid primary key references auth.users on delete cascade,
  nome          text,
  total_cotas   integer not null default 0,   -- cache do ledger
  nivel_atual   smallint not null default 1 references niveis_config,
  created_at    timestamptz not null default now()
);

create table user_roles (
  user_id     uuid references profiles on delete cascade,
  role        papel not null,
  granted_by  uuid references profiles,
  granted_at  timestamptz not null default now(),
  primary key (user_id, role)
);

create table pacotes_cotas (
  id                 uuid primary key default gen_random_uuid(),
  nome               text not null,
  quantidade_cotas   integer not null check (quantidade_cotas > 0),
  preco              numeric(10,2) not null check (preco >= 5.00),  -- piso da Asaas (API.md §9.1)
  beneficios         text[] not null default '{}',
  ativo              boolean not null default true
);

-- O id do pedido é o que vai no link do Checkout: UUID, nunca sequencial.
create table pedidos (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles,
  pacote_id   uuid not null references pacotes_cotas,
  valor       numeric(10,2) not null,          -- congelado no momento do pedido
  cotas       integer not null,                -- congelado no momento do pedido
  status      text not null default 'pendente'
              check (status in ('pendente','pago','cancelado','estornado')),
  charge_id   text,
  created_at  timestamptz not null default now(),
  pago_em     timestamptz
);

-- Imutável: sem UPDATE e sem DELETE (trigger bloqueia; RLS sem política de escrita).
-- Estorno é um lançamento negativo, nunca a remoção do positivo.
create table cotas_ledger (
  id                    bigint generated always as identity primary key,
  user_id               uuid not null references profiles,
  pacote_id             uuid references pacotes_cotas,
  pedido_id             uuid references pedidos,
  quantidade            integer not null check (quantidade <> 0),
  tipo                  text not null check (tipo in ('compra','estorno','ajuste','bonus')),
  referencia_pagamento  text,          -- chargeId do Checkout
  criado_por            uuid references profiles,   -- quem fez ajuste/bônus
  motivo                text,          -- obrigatório em ajuste/bônus
  created_at            timestamptz not null default now(),
  unique (pedido_id, tipo)             -- um pedido credita uma vez e estorna uma vez
);

create table webhook_eventos (         -- deduplicação pelo eventoId (API.md §4.3)
  evento_id      uuid primary key,
  payload        jsonb not null,
  recebido_em    timestamptz not null default now(),
  processado_em  timestamptz
);

create table conteudos (
  id                    uuid primary key default gen_random_uuid(),
  tipo                  text not null check (tipo in ('ebook','post','guia','video')),
  titulo                text not null,
  corpo                 text,
  arquivo_path          text,          -- bucket privado; URL assinada só após checar nível
  nivel_minimo_exigido  smallint not null references niveis_config,
  status                text not null default 'rascunho' check (status in ('rascunho','publicado','arquivado')),
  author_id             uuid references profiles,
  author_type           text not null check (author_type in ('human','ai_agent')),
  publicado_em          timestamptz
);

create table produtos_comunidade (
  id            uuid primary key default gen_random_uuid(),
  membro_id     uuid not null references profiles,
  titulo        text not null,
  descricao     text,
  preco_exibido numeric(10,2),
  link_externo  text,                  -- v1: a venda acontece fora da plataforma (§7, decisão 3)
  status        text not null default 'em_revisao' check (status in ('em_revisao','publicado','removido')),
  revisado_por  uuid references profiles,
  created_at    timestamptz not null default now()
);

create table escalonamentos (          -- a fila "needs_human"
  id             uuid primary key default gen_random_uuid(),
  motivo         text not null check (motivo in ('pagamento','reembolso','conflito','bug','outro')),
  origem_tabela  text,
  origem_id      text,
  user_id        uuid references profiles,
  fila           papel not null,       -- support, moderator, admin...
  status         text not null default 'aberto' check (status in ('aberto','em_atendimento','resolvido')),
  atribuido_a    uuid references profiles,
  resumo         text not null,
  created_at     timestamptz not null default now()
);

create table agent_logs (              -- append-only, como o ledger
  id           bigint generated always as identity primary key,
  acao         text not null,          -- 'onboarding','publicar','responder','escalonar'...
  alvo_tabela  text,
  alvo_id      text,
  entrada      jsonb,
  saida        jsonb,
  modelo       text,
  created_at   timestamptz not null default now()
);
```

O suporte (tickets e mensagens com `author_type`) entra na Etapa 4, quando
o canal estiver definido.

**Regra de nível:** `nivel_atual = max(nivel_id) where cotas_minimas <= total_cotas`.
Roda numa função `security definer` chamada só pelo webhook, pelo estorno e
pelo ajuste de admin.

**RLS, em uma frase por tabela:** o membro lê o próprio perfil, o próprio
extrato e os próprios pedidos. Lê `conteudos` publicados com
`nivel_minimo_exigido <= nivel_atual`. Escreve só os próprios
`produtos_comunidade`, e só se o nível permitir vender. Ninguém escreve no
ledger pela API: só as funções do servidor.

## 5. Faixas propostas (números para você validar)

| Nível | Nome | Cotas mínimas | Libera |
|---|---|---|---|
| 1 | Iniciado | 1 | Feed básico, e-books introdutórios |
| 2 | Construtor | 30 | Guias práticos, comunidade completa |
| 3 | Estrategista | 100 | Acervo avançado, **vitrine de produtos própria** |
| 4 | Conselho | 300 | Tudo + área restrita e destaque na vitrine |

| Pacote | Cotas | Preço | R$/cota |
|---|---|---|---|
| Semente | 10 | R$ 47,00 | 4,70 |
| Base | 30 | R$ 127,00 | 4,23 |
| Avanço | 100 | R$ 397,00 | 3,97 |

Os números são exemplo de ponto de partida. A taxa do Checkout entra por
cima do preço (API.md §8).

## 6. Plano em etapas

Cada etapa fecha com evidência antes da próxima abrir (skill `leis`).

**Etapa 0 — Decisões e fundação**
Suas decisões da §7. Depois: criar o projeto Supabase `san_core`, colocar
`/admin` atrás do Cloudflare Access, consertar o `www` (522), tirar a falsa
confirmação do formulário de contato e configurar o CI.
*Fecha quando:* a spec está validada, o banco existe e o CI está verde.

**Etapa 1 — Banco e regras de nível**
Migrations da §4, RLS, seed das faixas e pacotes, Supabase Auth (e-mail e
link mágico).
*Testes:* o cálculo de nível nas bordas (29/30/31 cotas); o ledger recusa
UPDATE e DELETE; um membro não lê o extrato de outro; conteúdo acima do
nível não aparece.
*Fecha quando:* a migration está aplicada e os testes passam no CI.

**Etapa 2 — Checkout dos pacotes**
Edge Functions `GET /pedido/{id}` (confere a `X-Checkout-Key`) e
`POST /webhook` (HMAC, janela de 300 s, dedup por `eventoId`). Webhook
confirmado → ledger `compra` → recálculo de nível. Estorno → ledger
`estorno` negativo → recálculo, e o membro pode descer de nível.
Conciliação diária via `pg_cron`. Botão de arrependimento de 7 dias (CDC
art. 49) com estorno no mesmo fluxo.
*Fecha quando:* os seis passos do API.md rodam com pagamento real de valor
baixo, incluindo o estorno e o rebaixamento de nível.

**Etapa 3 — Área de membros e acervo**
Login, painel com nível, barra até o próximo nível e extrato. Acervo
filtrado pelo RLS. E-books em bucket privado com URL assinada de vida
curta. Exportar e excluir a conta (LGPD).
*Fecha quando:* o fluxo completo funciona no ar, do cadastro ao download
de um e-book liberado.

**Etapa 4 — Rotinas do agente (Cláudio)**
Edge Functions chamando a API da Claude, disparadas por evento no banco e
por `pg_cron`:
- **Onboarding:** quando um membro entra ou sobe de nível, recebe uma
  mensagem com o que foi liberado e quantas cotas faltam.
- **Publicação:** posts e pílulas segmentados por nível, com
  `author_type = 'ai_agent'`.
- **Suporte de primeira linha:** responde com base no estado real da conta.

Toda ação grava em `agent_logs`. Pagamento, reembolso, conflito e bug vão
para `escalonamentos` e **o agente nunca executa estorno nem ajuste de
cotas**. Antes de publicar, um filtro automático barra termos proibidos
pelo `CONSTRAINTS.md` §1.
*Fecha quando:* cada rotina rodou no ar com log, e um caso de reembolso
caiu na fila humana em vez de ser resolvido pelo agente.

**Etapa 5 — Vitrine de produtos dos membros**
Cadastro e moderação. Na v1 a venda acontece por link externo (§7,
decisão 3).

**Depois: Prontidão e Lançamento.** Ciclo de segurança no ar, Termos e
Política publicados e só então divulgação. Antes disso, nenhum cadastro
aberto a terceiros.

## 7. Decisões que só o dono toma

1. **Faixas e pacotes da §5:** aprovar ou trocar os números.
2. **Cotas são intransferíveis e não expiram?** Recomendo intransferíveis.
   Cota que um membro vende a outro cria mercado secundário com preço, e é
   isso que aproxima o produto de um valor mobiliário. Pela mesma razão,
   não deve haver bônus por indicar novos compradores.
3. **Vitrine dos membros: só divulgação (recomendado) ou a plataforma
   intermedeia o pagamento?** Intermediar faz a San & Co. receber dinheiro
   de terceiros e responder como marketplace (CDC, nota fiscal, repasse).
   Hoje também não há split, porque a conta Asaas é PF (API.md §2.0).
4. **Revisão jurídica antes de abrir cadastro.** Ver os riscos em
   `CONSTRAINTS.md` §1.
5. **Custos:** um projeto Supabase novo e uma chave da API da Claude para o
   agente rodar sozinho.
