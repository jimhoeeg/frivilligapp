-- ============================================================
-- Admin Request feature
-- Kør dette i Supabase Dashboard → SQL Editor → Run
-- ============================================================

-- Tilføj kolonne til at markere brugere der har anmodet om admin-rettigheder
alter table public.profiles
  add column if not exists admin_requested boolean not null default false,
  add column if not exists admin_requested_at timestamptz;

-- Politik: brugere kan opdatere deres egen admin_requested flag
-- (allerede dækket af eksisterende profiles_update policy)

-- Politik: super_admin kan opdatere alles role + admin_requested
drop policy if exists "profiles_admin_update" on public.profiles;
create policy "profiles_admin_update" on public.profiles for update using (
  exists (select 1 from public.profiles where id = auth.uid() and role = 'super_admin')
);
