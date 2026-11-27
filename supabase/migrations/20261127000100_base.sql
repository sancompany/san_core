-- San & Co. Core — v1: Gratuito vs. Membro.
-- Spec: docs/specs/2026-11-27-plataforma-passes.md
--
-- Toda tabela nova em migration futura: o Supabase concede tudo a anon/authenticated
-- por padrão. Ligar RLS e revogar o que o cliente não deve ter, como abaixo.
--
-- Fonte da verdade do saldo é o passes_ledger (imutável). profiles.total_passes e
-- profiles.nivel_atual são cache recalculado por trigger na mesma transação do
-- lançamento — a aplicação nunca escreve neles.

-- ---------------------------------------------------------------------------
-- Papéis de equipe (N:N). Ser Gratuito ou Membro NÃO é papel: é nível, derivado
-- do saldo. Aqui só ficam funções operacionais, para o handoff humano ser uma linha.
-- ---------------------------------------------------------------------------
create type public.papel as enum ('ai_agent', 'editor', 'moderator', 'support', 'admin');

create table public.niveis_config (
  nivel_id       smallint primary key,
  nome           text not null unique,
  passes_minimos integer not null unique check (passes_minimos >= 0),
  permissoes     jsonb not null default '{}'
);

insert into public.niveis_config (nivel_id, nome, passes_minimos, permissoes) values
  (0, 'Gratuito', 0, '{"vitrine_publicar": false}'),
  (1, 'Membro',   1, '{"vitrine_publicar": true}');

create table public.profiles (
  id            uuid primary key references auth.users (id) on delete restrict,
  nome          text check (char_length(nome) <= 120),
  total_passes  integer not null default 0 check (total_passes >= 0),
  nivel_atual   smallint not null default 0 references public.niveis_config,
  created_at    timestamptz not null default now()
);

create table public.user_roles (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  role        public.papel not null,
  granted_by  uuid references public.profiles (id),
  granted_at  timestamptz not null default now(),
  primary key (user_id, role)
);

-- Passe avulso, quantidade livre entre o mínimo e o máximo por pedido.
-- Um preço ativo por vez; trocar o preço é desativar a linha e criar outra,
-- para que pedidos antigos continuem apontando para o preço que pagaram.
create table public.precos_passe (
  id                 uuid primary key default gen_random_uuid(),
  preco_unitario     numeric(10,2) not null check (preco_unitario > 0),
  minimo_por_pedido  integer not null check (minimo_por_pedido >= 1),
  maximo_por_pedido  integer not null,
  -- a taxa do Checkout é isentada (isentarTaxa): o comprador paga o preço anunciado
  isentar_taxa       boolean not null default true,
  ativo              boolean not null default true,
  created_at         timestamptz not null default now(),
  check (maximo_por_pedido >= minimo_por_pedido),
  -- o menor pedido possível precisa passar do piso da Asaas (API.md §9.1)
  check (not isentar_taxa or preco_unitario * minimo_por_pedido >= 5.00)
);
create unique index precos_passe_um_ativo on public.precos_passe ((true)) where ativo;

insert into public.precos_passe (preco_unitario, minimo_por_pedido, maximo_por_pedido)
  values (2.90, 2, 500);

-- O id vai no link do Checkout: UUID, nunca sequencial (skill checkout, regra 1).
-- valor e passes são congelados no pedido: mudar o preço depois não muda pedido aberto.
create table public.pedidos (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete restrict,
  preco_id    uuid not null references public.precos_passe,
  passes      integer not null check (passes > 0),
  valor       numeric(10,2) not null check (valor >= 5.00),   -- piso da Asaas
  isentar_taxa boolean not null,
  status      text not null default 'pendente'
              check (status in ('pendente', 'pago', 'cancelado', 'estornado')),
  charge_id   text,
  created_at  timestamptz not null default now(),
  pago_em     timestamptz
);
create index pedidos_user_idx on public.pedidos (user_id);
create index pedidos_pendentes_idx on public.pedidos (created_at) where status = 'pendente';

create table public.passes_ledger (
  id                    bigint generated always as identity primary key,
  user_id               uuid not null references public.profiles (id) on delete restrict,
  pedido_id             uuid references public.pedidos,
  quantidade            integer not null check (quantidade <> 0),
  tipo                  text not null check (tipo in ('compra', 'estorno', 'ajuste', 'bonus')),
  referencia_pagamento  text,
  criado_por            uuid references public.profiles (id),
  motivo                text,
  created_at            timestamptz not null default now(),
  -- um pedido credita uma vez e estorna uma vez: webhook repetido não duplica saldo
  unique (pedido_id, tipo),
  check (tipo not in ('compra', 'estorno') or pedido_id is not null),
  check (tipo <> 'compra'  or quantidade > 0),
  check (tipo <> 'bonus'   or quantidade > 0),
  check (tipo <> 'estorno' or quantidade < 0),
  check (tipo not in ('ajuste', 'bonus') or (motivo is not null and criado_por is not null))
);
create index passes_ledger_user_idx on public.passes_ledger (user_id);

create table public.webhook_eventos (
  evento_id      uuid primary key,          -- eventoId do Checkout (API.md §4.3)
  payload        jsonb not null,
  recebido_em    timestamptz not null default now(),
  processado_em  timestamptz
);

-- Vitrine do conteúdo: o que todo mundo vê, inclusive o que está trancado.
create table public.conteudos (
  id                    uuid primary key default gen_random_uuid(),
  tipo                  text not null check (tipo in ('ebook', 'post', 'guia', 'video')),
  titulo                text not null,
  resumo                text,               -- o "preview com cadeado"
  nivel_minimo_exigido  smallint not null default 0 references public.niveis_config,
  status                text not null default 'rascunho'
                        check (status in ('rascunho', 'publicado', 'arquivado')),
  author_id             uuid references public.profiles (id),
  author_type           text not null check (author_type in ('human', 'ai_agent')),
  publicado_em          timestamptz,
  created_at            timestamptz not null default now(),
  check (status <> 'publicado' or publicado_em is not null)
);
create index conteudos_publicados_idx on public.conteudos (publicado_em desc) where status = 'publicado';

-- O que é liberado por nível. Tabela separada para o RLS decidir por linha.
create table public.conteudos_corpo (
  conteudo_id   uuid primary key references public.conteudos (id) on delete cascade,
  corpo         text,
  arquivo_path  text                        -- bucket privado; URL assinada na Etapa 3
);

create table public.produtos_comunidade (
  id             uuid primary key default gen_random_uuid(),
  membro_id      uuid not null references public.profiles (id) on delete cascade,
  titulo         text not null check (char_length(titulo) between 3 and 120),
  descricao      text check (char_length(descricao) <= 2000),
  preco_exibido  numeric(10,2) check (preco_exibido >= 0),
  link_externo   text not null check (link_externo ~ '^https://'),
  status         text not null default 'em_revisao'
                 check (status in ('em_revisao', 'publicado', 'removido')),
  revisado_por   uuid references public.profiles (id),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index produtos_membro_idx on public.produtos_comunidade (membro_id);

create table public.escalonamentos (
  id             uuid primary key default gen_random_uuid(),
  motivo         text not null check (motivo in ('pagamento', 'reembolso', 'conflito', 'bug', 'outro')),
  origem_tabela  text,
  origem_id      text,
  user_id        uuid references public.profiles (id),
  fila           public.papel not null,
  status         text not null default 'aberto' check (status in ('aberto', 'em_atendimento', 'resolvido')),
  atribuido_a    uuid references public.profiles (id),
  resumo         text not null,
  created_at     timestamptz not null default now()
);

create table public.agent_logs (
  id           bigint generated always as identity primary key,
  acao         text not null,
  alvo_tabela  text,
  alvo_id      text,
  entrada      jsonb,
  saida        jsonb,
  modelo       text,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Funções auxiliares (security definer: leem tabelas protegidas sem recursão de RLS)
-- ---------------------------------------------------------------------------
create function public.tem_papel(p public.papel)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.user_roles where user_id = auth.uid() and role = p);
$$;

-- -1 para visitante sem login: não alcança nem o nível 0.
create function public.nivel_do_usuario()
returns smallint language sql stable security definer set search_path = '' as $$
  select coalesce((select nivel_atual from public.profiles where id = auth.uid()), -1)::smallint;
$$;

-- ---------------------------------------------------------------------------
-- Ledger imutável + recálculo de saldo e nível
-- ---------------------------------------------------------------------------
create function public.ledger_imutavel()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'passes_ledger é imutável: corrija com um lançamento novo';
end;
$$;

create trigger passes_ledger_sem_update before update or delete on public.passes_ledger
  for each row execute function public.ledger_imutavel();
create trigger passes_ledger_sem_truncate before truncate on public.passes_ledger
  for each statement execute function public.ledger_imutavel();

create function public.recalcular_nivel()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_total integer;
begin
  -- trava a linha do perfil: dois webhooks simultâneos do mesmo usuário serializam aqui
  perform 1 from public.profiles where id = new.user_id for update;

  select coalesce(sum(quantidade), 0) into v_total
    from public.passes_ledger where user_id = new.user_id;

  if v_total < 0 then
    raise exception 'saldo de passes não pode ficar negativo (usuário %, saldo %)', new.user_id, v_total;
  end if;

  update public.profiles p
     set total_passes = v_total,
         nivel_atual  = (select max(n.nivel_id) from public.niveis_config n
                          where n.passes_minimos <= v_total)
   where p.id = new.user_id;
  return null;
end;
$$;

-- Compra e estorno têm de bater com o pedido: mesma conta, mesma quantidade.
-- Impede creditar 100 passes num pedido de 2 por erro de código no webhook.
create function public.lancamento_confere_pedido()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_pedido public.pedidos;
begin
  if new.tipo in ('compra', 'estorno') then
    select * into v_pedido from public.pedidos where id = new.pedido_id;
    if v_pedido.user_id <> new.user_id then
      raise exception 'lançamento de outra conta: pedido %', new.pedido_id;
    end if;
    if abs(new.quantidade) <> v_pedido.passes then
      raise exception 'quantidade % não bate com os % passes do pedido %',
        new.quantidade, v_pedido.passes, new.pedido_id;
    end if;
  end if;
  return new;
end;
$$;

create trigger passes_ledger_confere before insert on public.passes_ledger
  for each row execute function public.lancamento_confere_pedido();

create trigger passes_ledger_recalcula after insert on public.passes_ledger
  for each row execute function public.recalcular_nivel();

-- Perfil nasce junto com a conta do Supabase Auth.
create function public.criar_perfil()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, nome)
  values (new.id, nullif(new.raw_user_meta_data ->> 'nome', ''));
  return new;
end;
$$;

create trigger auth_users_cria_perfil after insert on auth.users
  for each row execute function public.criar_perfil();

-- Dono editando o produto devolve para revisão; só equipe muda status e revisor.
create function public.produto_editado()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  -- service_role (rotinas do agente) e equipe passam; o cliente comum, não.
  if current_user in ('anon', 'authenticated')
     and not (public.tem_papel('moderator') or public.tem_papel('admin')) then
    new.membro_id    := old.membro_id;
    new.revisado_por := old.revisado_por;
    new.status       := case when old.status = 'removido' then 'removido' else 'em_revisao' end;
  end if;
  return new;
end;
$$;

create trigger produtos_comunidade_editado before update on public.produtos_comunidade
  for each row execute function public.produto_editado();

-- ---------------------------------------------------------------------------
-- Privilégios. O Supabase concede tudo a anon/authenticated por padrão; aqui
-- se retira o que o cliente não deve fazer, e o RLS decide linha a linha.
-- ---------------------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.tem_papel(public.papel), public.nivel_do_usuario() to anon, authenticated;

grant select on public.niveis_config, public.precos_passe, public.conteudos,
               public.conteudos_corpo, public.produtos_comunidade to anon, authenticated;
grant select on public.profiles, public.user_roles, public.pedidos,
               public.passes_ledger, public.escalonamentos, public.agent_logs to authenticated;
grant update (nome) on public.profiles to authenticated;
grant insert, update, delete on public.conteudos, public.conteudos_corpo to authenticated;
grant insert (titulo, descricao, preco_exibido, link_externo, membro_id),
      update (titulo, descricao, preco_exibido, link_externo, status, revisado_por),
      delete on public.produtos_comunidade to authenticated;
grant insert, delete on public.user_roles to authenticated;
grant update (status, atribuido_a) on public.escalonamentos to authenticated;

alter table public.niveis_config       enable row level security;
alter table public.profiles            enable row level security;
alter table public.user_roles          enable row level security;
alter table public.precos_passe        enable row level security;
alter table public.pedidos             enable row level security;
alter table public.passes_ledger       enable row level security;
alter table public.webhook_eventos     enable row level security;  -- sem política: só service_role
alter table public.conteudos           enable row level security;
alter table public.conteudos_corpo     enable row level security;
alter table public.produtos_comunidade enable row level security;
alter table public.escalonamentos      enable row level security;
alter table public.agent_logs          enable row level security;

create policy niveis_leitura on public.niveis_config for select using (true);
create policy precos_leitura on public.precos_passe for select using (ativo or public.tem_papel('admin'));

create policy perfil_proprio on public.profiles for select
  using (id = auth.uid() or public.tem_papel('support') or public.tem_papel('admin'));
create policy perfil_edita_nome on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid());

create policy papeis_leitura on public.user_roles for select
  using (user_id = auth.uid() or public.tem_papel('admin'));
create policy papeis_admin_insere on public.user_roles for insert
  with check (public.tem_papel('admin'));
create policy papeis_admin_remove on public.user_roles for delete
  using (public.tem_papel('admin'));

create policy pedidos_proprios on public.pedidos for select
  using (user_id = auth.uid() or public.tem_papel('support') or public.tem_papel('admin'));

create policy extrato_proprio on public.passes_ledger for select
  using (user_id = auth.uid() or public.tem_papel('support') or public.tem_papel('admin'));

create policy conteudo_vitrine on public.conteudos for select
  using (status = 'publicado' or public.tem_papel('editor') or public.tem_papel('admin'));
-- Pelo cliente, só se grava autoria humana e em nome próprio. Conteúdo do agente
-- (author_type = 'ai_agent') só entra pela rotina com service_role — é o que torna
-- a trilha de auditoria confiável.
create policy conteudo_equipe_insere on public.conteudos for insert
  with check ((public.tem_papel('editor') or public.tem_papel('admin'))
              and author_type = 'human' and author_id = auth.uid());
create policy conteudo_equipe_edita on public.conteudos for update
  using (public.tem_papel('editor') or public.tem_papel('admin'))
  with check (author_type = 'human' or author_type is not distinct from
              (select c.author_type from public.conteudos c where c.id = conteudos.id));
create policy conteudo_equipe_remove on public.conteudos for delete
  using (public.tem_papel('admin'));

create policy corpo_por_nivel on public.conteudos_corpo for select
  using (
    exists (select 1 from public.conteudos c
             where c.id = conteudo_id
               and c.status = 'publicado'
               and c.nivel_minimo_exigido <= public.nivel_do_usuario())
    or public.tem_papel('editor') or public.tem_papel('admin')
  );
create policy corpo_equipe_insere on public.conteudos_corpo for insert
  with check (public.tem_papel('editor') or public.tem_papel('admin'));
create policy corpo_equipe_edita on public.conteudos_corpo for update
  using (public.tem_papel('editor') or public.tem_papel('admin'));
create policy corpo_equipe_remove on public.conteudos_corpo for delete
  using (public.tem_papel('admin'));

create policy vitrine_leitura on public.produtos_comunidade for select
  using (status = 'publicado' or membro_id = auth.uid()
         or public.tem_papel('moderator') or public.tem_papel('admin'));
create policy vitrine_membro_publica on public.produtos_comunidade for insert
  with check (
    membro_id = auth.uid()
    and exists (select 1 from public.niveis_config n
                 where n.nivel_id = public.nivel_do_usuario()
                   and (n.permissoes ->> 'vitrine_publicar')::boolean)
  );
create policy vitrine_edita on public.produtos_comunidade for update
  using (membro_id = auth.uid() or public.tem_papel('moderator') or public.tem_papel('admin'));
create policy vitrine_remove on public.produtos_comunidade for delete
  using (membro_id = auth.uid() or public.tem_papel('admin'));

create policy fila_equipe on public.escalonamentos for select
  using (public.tem_papel(fila) or public.tem_papel('admin'));
create policy fila_atende on public.escalonamentos for update
  using (public.tem_papel(fila) or public.tem_papel('admin'));

create policy logs_admin on public.agent_logs for select using (public.tem_papel('admin'));
