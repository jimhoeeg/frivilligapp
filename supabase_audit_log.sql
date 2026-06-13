-- ============================================================
-- Audit log tabel
-- Kør dette i Supabase Dashboard → SQL Editor → Run
-- ============================================================

create table if not exists public.audit_log (
  id         uuid        primary key default gen_random_uuid(),
  type       text        not null,        -- 'role_change' | 'task' | 'member' | 'settings'
  action     text        not null,
  actor_name text,
  actor_id   uuid        references auth.users(id) on delete set null,
  created_at timestamptz default now()
);

alter table public.audit_log enable row level security;

drop policy if exists "audit_select" on public.audit_log;
drop policy if exists "audit_insert" on public.audit_log;

-- Kun admins og super_admins kan læse loggen
create policy "audit_select" on public.audit_log for select using (
  exists (select 1 from public.profiles where id = auth.uid() and role in ('admin', 'super_admin'))
);

-- Alle autentificerede brugere kan indsætte (skrivning sker fra klient-koden)
create policy "audit_insert" on public.audit_log for insert with check (
  auth.uid() is not null
);
