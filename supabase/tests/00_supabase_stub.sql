-- Minimal efterligning af det, Supabase leverer, så migrationen kan afprøves lokalt.

do $$ begin
  if not exists (select 1 from pg_roles where rolname='anon')          then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname='service_role')  then create role service_role nologin; end if;
end $$;

grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;

create schema if not exists auth;

create table auth.users (
  id                 uuid primary key default gen_random_uuid(),
  email              text unique,
  raw_user_meta_data jsonb default '{}'::jsonb,
  created_at         timestamptz default now()
);

-- I Supabase læses bruger-id'et ud af JWT'en. Her sætter testene det direkte.
create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid;
$$;

grant usage on schema auth to anon, authenticated, service_role;
grant select on auth.users to authenticated, service_role;


-- ---------------------------------------------------------------------------
-- Vault og pg_net findes kun hos Supabase. Her er en attrap, så udbakken og
-- dens job kan afprøves lokalt: kaldene skrives ned i stedet for at gå ud.
-- ---------------------------------------------------------------------------

create schema if not exists vault;

create table if not exists vault.decrypted_secrets (
  name             text primary key,
  decrypted_secret text
);

create schema if not exists net;

create table if not exists net.kald (
  id      bigserial primary key,
  url     text,
  headers jsonb,
  body    jsonb,
  tid     timestamptz default now()
);

create or replace function net.http_post(url text, headers jsonb default '{}'::jsonb, body jsonb default '{}'::jsonb)
returns bigint
language sql as $$
  insert into net.kald (url, headers, body) values (url, headers, body) returning id;
$$;
