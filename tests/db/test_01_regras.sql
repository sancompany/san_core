-- Regras de saldo, nível e permissão da v1 (Gratuito vs. Membro).
-- Cada bloco roda numa transação desfeita no fim; uma asserção falsa aborta o arquivo.

\set A    '''aaaaaaaa-0000-0000-0000-000000000001'''
\set B    '''bbbbbbbb-0000-0000-0000-000000000002'''
\set ED   '''eeeeeeee-0000-0000-0000-000000000003'''
\set MOD  '''dddddddd-0000-0000-0000-000000000004'''
\set ADM  '''ffffffff-0000-0000-0000-000000000005'''

-- Auxiliares: espera_erro roda um comando e falha se ele NÃO der erro.
create schema teste;
grant usage on schema teste to anon, authenticated;
create function teste.espera_erro(cmd text, contem text default null) returns void
language plpgsql as $$
begin
  begin
    execute cmd;
  exception when others then
    if contem is not null and position(contem in sqlerrm) = 0 then
      raise exception 'erro diferente do esperado em [%]: %', cmd, sqlerrm;
    end if;
    return;
  end;
  raise exception 'deveria ter falhado: %', cmd;
end;
$$;
grant execute on function teste.espera_erro(text, text) to anon, authenticated;

create function teste.como(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid)::text, true);
$$;
grant execute on function teste.como(text) to anon, authenticated;

-- Dados-base (como superusuário): cinco contas, equipe com papéis, um conteúdo de cada nível.
insert into auth.users (id, email, raw_user_meta_data) values
  (:A,   'a@teste', '{"nome":"Ana"}'),
  (:B,   'b@teste', '{}'),
  (:ED,  'e@teste', '{}'),
  (:MOD, 'm@teste', '{}'),
  (:ADM, 'x@teste', '{}');
insert into public.user_roles (user_id, role) values
  (:ED, 'editor'), (:MOD, 'moderator'), (:ADM, 'admin');

insert into public.conteudos (id, tipo, titulo, resumo, nivel_minimo_exigido, status, author_type, publicado_em) values
  ('c0000000-0000-0000-0000-000000000000', 'post',  'Aberto',   'r', 0, 'publicado', 'ai_agent', now()),
  ('c1000000-0000-0000-0000-000000000000', 'ebook', 'Fechado',  'r', 1, 'publicado', 'human',    now()),
  ('c2000000-0000-0000-0000-000000000000', 'ebook', 'Rascunho', 'r', 1, 'rascunho',  'human',    null);
insert into public.conteudos_corpo (conteudo_id, corpo) values
  ('c0000000-0000-0000-0000-000000000000', 'corpo aberto'),
  ('c1000000-0000-0000-0000-000000000000', 'corpo fechado'),
  ('c2000000-0000-0000-0000-000000000000', 'corpo rascunho');

-- B vira Membro comprando o mínimo: 2 passes a R$ 2,90.
insert into public.pedidos (id, user_id, preco_id, passes, valor, isentar_taxa, status)
  select '90000000-0000-0000-0000-000000000001', :B, id, 2, 2 * preco_unitario, isentar_taxa, 'pago'
    from public.precos_passe where ativo;
insert into public.passes_ledger (user_id, pedido_id, quantidade, tipo, referencia_pagamento)
  values (:B, '90000000-0000-0000-0000-000000000001', 2, 'compra', 'pay_teste');

-- 1. Perfil nasce com a conta, Gratuito, com o nome do cadastro.
do $$ begin
  assert (select nivel_atual from public.profiles where id = 'aaaaaaaa-0000-0000-0000-000000000001') = 0, 'A deveria ser Gratuito';
  assert (select nome from public.profiles where id = 'aaaaaaaa-0000-0000-0000-000000000001') = 'Ana', 'nome do cadastro';
  assert (select nivel_atual from public.profiles where id = 'bbbbbbbb-0000-0000-0000-000000000002') = 1, 'B deveria ser Membro';
  assert (select total_passes from public.profiles where id = 'bbbbbbbb-0000-0000-0000-000000000002') = 2, 'B deveria ter 2 passes';
end $$;

-- 1b. Preço da v1: R$ 2,90, mínimo 2, taxa isentada; um preço ativo por vez;
--     pedido abaixo do piso da Asaas não existe.
do $$ begin
  assert (select (preco_unitario, minimo_por_pedido, isentar_taxa) from public.precos_passe where ativo)
         = (2.90::numeric(10,2), 2, true), 'preço da v1';
end $$;
select teste.espera_erro($$insert into public.precos_passe (preco_unitario, minimo_por_pedido, maximo_por_pedido)
  values (3.00, 2, 10)$$, 'precos_passe_um_ativo');
select teste.espera_erro($$insert into public.precos_passe (preco_unitario, minimo_por_pedido, maximo_por_pedido, ativo)
  values (2.90, 1, 10, false)$$, 'check');
select teste.espera_erro($$insert into public.pedidos (user_id, preco_id, passes, valor, isentar_taxa)
  select 'aaaaaaaa-0000-0000-0000-000000000001', id, 1, 2.90, true from public.precos_passe where ativo$$, 'check');

-- 1c. Crédito tem de bater com o pedido: quantidade e conta.
begin;
insert into public.pedidos (id, user_id, preco_id, passes, valor, isentar_taxa, status)
  select '90000000-0000-0000-0000-000000000002', :A, id, 3, 8.70, true, 'pago' from public.precos_passe where ativo;
select teste.espera_erro($$insert into public.passes_ledger (user_id, pedido_id, quantidade, tipo)
  values ('aaaaaaaa-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000002', 100, 'compra')$$, 'não bate');
select teste.espera_erro($$insert into public.passes_ledger (user_id, pedido_id, quantidade, tipo)
  values ('bbbbbbbb-0000-0000-0000-000000000002', '90000000-0000-0000-0000-000000000002', 3, 'compra')$$, 'outra conta');
rollback;

-- 2. Webhook repetido não credita duas vezes.
select teste.espera_erro($$insert into public.passes_ledger (user_id, pedido_id, quantidade, tipo)
  values ('bbbbbbbb-0000-0000-0000-000000000002', '90000000-0000-0000-0000-000000000001', 2, 'compra')$$, 'unique');

-- 3. Estorno zera o saldo e rebaixa para Gratuito; o lançamento original continua lá.
begin;
insert into public.passes_ledger (user_id, pedido_id, quantidade, tipo)
  values (:B, '90000000-0000-0000-0000-000000000001', -2, 'estorno');
do $$ begin
  assert (select total_passes from public.profiles where id = 'bbbbbbbb-0000-0000-0000-000000000002') = 0, 'saldo após estorno';
  assert (select nivel_atual from public.profiles where id = 'bbbbbbbb-0000-0000-0000-000000000002') = 0, 'rebaixa após estorno';
  assert (select count(*) from public.passes_ledger where user_id = 'bbbbbbbb-0000-0000-0000-000000000002') = 2, 'ledger guarda os dois';
end $$;
rollback;

-- 4. Borda: 1 passe já é Membro.
begin;
insert into public.passes_ledger (user_id, quantidade, tipo, motivo, criado_por)
  values (:A, 1, 'bonus', 'teste de borda', :ADM);
do $$ begin
  assert (select nivel_atual from public.profiles where id = 'aaaaaaaa-0000-0000-0000-000000000001') = 1, '1 passe = Membro';
end $$;
rollback;

-- 5. Ledger é imutável, até para o superusuário; saldo nunca fica negativo.
select teste.espera_erro($$update public.passes_ledger set quantidade = 99$$, 'imutável');
select teste.espera_erro($$delete from public.passes_ledger$$, 'imutável');
select teste.espera_erro($$truncate public.passes_ledger$$, 'imutável');
select teste.espera_erro($$insert into public.passes_ledger (user_id, quantidade, tipo, motivo, criado_por)
  values ('aaaaaaaa-0000-0000-0000-000000000001', -1, 'ajuste', 'x', 'ffffffff-0000-0000-0000-000000000005')$$, 'negativo');
select teste.espera_erro($$insert into public.passes_ledger (user_id, quantidade, tipo)
  values ('aaaaaaaa-0000-0000-0000-000000000001', 5, 'ajuste')$$, 'check');
select teste.espera_erro($$insert into public.passes_ledger (user_id, quantidade, tipo)
  values ('aaaaaaaa-0000-0000-0000-000000000001', 5, 'compra')$$, 'check');

-- 6. Conta não é apagada por fora: exclusão passa pelo fluxo de anonimização (Etapa 3).
select teste.espera_erro($$delete from auth.users where id = 'bbbbbbbb-0000-0000-0000-000000000002'$$);

-- 7. Membro comum (A, Gratuito) não lê o que é de outro nem mexe no próprio saldo.
begin;
select teste.como(:A);
set local role authenticated;
do $$ begin
  assert (select count(*) from public.passes_ledger) = 0, 'A não vê extrato de B';
  assert (select count(*) from public.pedidos) = 0, 'A não vê pedido de B';
  assert (select count(*) from public.profiles) = 1, 'A só vê o próprio perfil';
  assert (select count(*) from public.user_roles) = 0, 'A não vê papéis alheios';
end $$;
select teste.espera_erro($$update public.profiles set total_passes = 999$$, 'permission');
select teste.espera_erro($$update public.profiles set nivel_atual = 1$$, 'permission');
select teste.espera_erro($$insert into public.passes_ledger (user_id, quantidade, tipo, motivo, criado_por)
  values (auth.uid(), 100, 'bonus', 'x', auth.uid())$$, 'permission');
select teste.espera_erro($$insert into public.pedidos (user_id, preco_id, passes, valor, isentar_taxa)
  select auth.uid(), id, 100, 5, true from public.precos_passe limit 1$$, 'permission');
select teste.espera_erro($$insert into public.user_roles (user_id, role) values (auth.uid(), 'admin')$$, 'row-level security');
select teste.espera_erro($$select * from public.webhook_eventos$$, 'permission');
update public.profiles set nome = 'Ana Paula';
do $$ begin
  assert (select nome from public.profiles) = 'Ana Paula', 'A edita o próprio nome';
end $$;
rollback;

-- 8. Acervo: vitrine para todos, corpo por nível, rascunho só para a equipe.
begin;
set local role anon;
do $$ begin
  assert (select count(*) from public.conteudos) = 2, 'visitante vê a vitrine publicada';
  assert (select count(*) from public.conteudos_corpo) = 0, 'visitante não lê corpo nenhum';
end $$;
select teste.espera_erro($$select * from public.profiles$$, 'permission');
rollback;

begin;
select teste.como(:A);
set local role authenticated;
do $$ begin
  assert (select count(*) from public.conteudos) = 2, 'Gratuito vê os dois publicados (um com cadeado)';
  assert (select array_agg(corpo) from public.conteudos_corpo) = array['corpo aberto'], 'Gratuito só lê o aberto';
end $$;
select teste.espera_erro($$insert into public.conteudos (tipo, titulo, author_type) values ('post', 'x', 'human')$$, 'row-level security');
rollback;

begin;
select teste.como(:B);
set local role authenticated;
do $$ begin
  assert (select count(*) from public.conteudos_corpo) = 2, 'Membro lê aberto e fechado, não rascunho';
end $$;
rollback;

begin;
select teste.como(:ED);
set local role authenticated;
do $$ begin
  assert (select count(*) from public.conteudos) = 3, 'editor vê rascunho';
end $$;
insert into public.conteudos (tipo, titulo, author_type, author_id) values ('post', 'novo', 'human', auth.uid());
select teste.espera_erro($$insert into public.conteudos (tipo, titulo, author_type, author_id)
  values ('post', 'fingindo ser o agente', 'ai_agent', auth.uid())$$, 'row-level security');
select teste.espera_erro($$insert into public.conteudos (tipo, titulo, author_type, author_id)
  values ('post', 'em nome de outro', 'human', 'aaaaaaaa-0000-0000-0000-000000000001')$$, 'row-level security');
select teste.espera_erro($$update public.conteudos set author_type = 'ai_agent' where titulo = 'Fechado'$$, 'row-level security');
rollback;

-- 9. Vitrine: só Membro publica; dono não se autoaprova; moderador aprova.
begin;
select teste.como(:A);
set local role authenticated;
select teste.espera_erro($$insert into public.produtos_comunidade (membro_id, titulo, link_externo)
  values (auth.uid(), 'Produto A', 'https://a.example')$$, 'row-level security');
reset role;

select teste.como(:B);
set local role authenticated;
select teste.espera_erro($$insert into public.produtos_comunidade (membro_id, titulo, link_externo)
  values ('aaaaaaaa-0000-0000-0000-000000000001', 'Em nome de outro', 'https://b.example')$$, 'row-level security');
select teste.espera_erro($$insert into public.produtos_comunidade (membro_id, titulo, link_externo, status)
  values (auth.uid(), 'Já publicado', 'https://b.example', 'publicado')$$, 'permission');
select teste.espera_erro($$insert into public.produtos_comunidade (membro_id, titulo, link_externo)
  values (auth.uid(), 'Link inseguro', 'http://b.example')$$, 'check');
-- o cliente não escolhe o id (não está no grant de insert)
select teste.espera_erro($$insert into public.produtos_comunidade (id, membro_id, titulo, link_externo)
  values (gen_random_uuid(), auth.uid(), 'Com id', 'https://b.example')$$, 'permission');
insert into public.produtos_comunidade (membro_id, titulo, link_externo)
  values (auth.uid(), 'Produto B', 'https://b.example');
update public.produtos_comunidade set status = 'publicado' where titulo = 'Produto B';
do $$ begin
  assert (select status from public.produtos_comunidade) = 'em_revisao', 'dono não se autoaprova';
end $$;
reset role;

select teste.como(:MOD);
set local role authenticated;
update public.produtos_comunidade set status = 'publicado', revisado_por = auth.uid()
  where titulo = 'Produto B';
reset role;

set local role anon;
do $$ begin
  assert (select count(*) from public.produtos_comunidade where status = 'publicado') = 1, 'visitante vê o aprovado';
end $$;
reset role;

-- Dono edita depois de aprovado: volta para revisão.
select teste.como(:B);
set local role authenticated;
update public.produtos_comunidade set titulo = 'Produto B v2';
do $$ begin
  assert (select status from public.produtos_comunidade) = 'em_revisao', 'edição volta para revisão';
end $$;
rollback;

-- 10. Rotina do agente (service_role) aprova sem o trigger desfazer.
begin;
insert into public.produtos_comunidade (id, membro_id, titulo, link_externo)
  values ('a2000000-0000-0000-0000-000000000000', :B, 'Via agente', 'https://b.example');
set local role service_role;
update public.produtos_comunidade set status = 'publicado' where id = 'a2000000-0000-0000-0000-000000000000';
do $$ begin
  assert (select status from public.produtos_comunidade where id = 'a2000000-0000-0000-0000-000000000000') = 'publicado', 'agente aprova';
end $$;
rollback;

-- 11. Só admin concede papel.
begin;
select teste.como(:ADM);
set local role authenticated;
insert into public.user_roles (user_id, role, granted_by) values (:A, 'support', auth.uid());
rollback;

drop schema teste cascade;
