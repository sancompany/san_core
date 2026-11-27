-- Reproduz, num Postgres puro, o mínimo do ambiente Supabase de que as migrations
-- dependem: os papéis anon/authenticated/service_role, o schema auth com auth.uid()
-- e os privilégios padrão que o Supabase concede em public. Só para teste.

create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;

create schema auth;
create table auth.users (
  id                  uuid primary key,
  email               text,
  raw_user_meta_data  jsonb default '{}'
);

create function auth.uid() returns uuid language sql stable as $$
  -- igual ao do Supabase: sessão sem JWT (string vazia ou ausente) devolve null
  select nullif(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub', '')::uuid;
$$;

grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;

-- O Supabase concede tudo por padrão; as migrations precisam retirar o que não querem.
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant execute on functions to anon, authenticated, service_role;
