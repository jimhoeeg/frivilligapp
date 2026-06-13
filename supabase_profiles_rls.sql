-- ============================================================
-- RLS-fix til profiles-tabellen
-- Kør dette i Supabase Dashboard → SQL Editor → Run
-- ============================================================

-- Hjælpefunktion der henter den aktuelle brugers rolle
-- (security definer undgår rekursion i RLS-politikker)
create or replace function public.get_my_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

-- Ryd eksisterende opdaterings- og sletningstilladelser
drop policy if exists "profiles_update_own"            on public.profiles;
drop policy if exists "admins_update_any_profile"      on public.profiles;
drop policy if exists "super_admins_delete_profile"    on public.profiles;
drop policy if exists "Users can update own profile."  on public.profiles;

-- Brugere kan opdatere deres eget profil
create policy "profiles_update_own"
  on public.profiles for update
  using  (id = auth.uid())
  with check (id = auth.uid());

-- Admins og super_admins kan opdatere alle profiler
-- (bruges til: rolleændringer, bonuspoint, admin_requested)
create policy "admins_update_any_profile"
  on public.profiles for update
  using  (public.get_my_role() in ('admin', 'super_admin'));

-- Super_admins kan slette profiler (GDPR + afvisning af nye)
create policy "super_admins_delete_profile"
  on public.profiles for delete
  using  (public.get_my_role() = 'super_admin');

-- Admins kan også slette ved afvisning af nye brugere
create policy "admins_delete_profile"
  on public.profiles for delete
  using  (public.get_my_role() in ('admin', 'super_admin'));

-- Sørg for at admin_requested kolonnen eksisterer
alter table public.profiles
  add column if not exists admin_requested    boolean   default false,
  add column if not exists admin_requested_at timestamptz;
