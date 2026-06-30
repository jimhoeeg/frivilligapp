-- ============================================================
-- Profilbilleder + Hold-håndtering
-- Kør dette i Supabase Dashboard → SQL Editor → Run
-- ============================================================

-- 1. AVATAR_URL kolonne på profiles
alter table public.profiles
  add column if not exists avatar_url text;

-- 2. TEAMS tabel
create table if not exists public.teams (
  id          uuid primary key default gen_random_uuid(),
  name        text unique not null,
  created_at  timestamptz default now()
);

alter table public.teams enable row level security;

drop policy if exists "teams_select" on public.teams;
drop policy if exists "teams_insert" on public.teams;
drop policy if exists "teams_update" on public.teams;
drop policy if exists "teams_delete" on public.teams;

create policy "teams_select" on public.teams for select using (true);
create policy "teams_insert" on public.teams for insert with check (
  exists (select 1 from public.profiles where id = auth.uid() and role = 'super_admin')
);
create policy "teams_update" on public.teams for update using (
  exists (select 1 from public.profiles where id = auth.uid() and role = 'super_admin')
);
create policy "teams_delete" on public.teams for delete using (
  exists (select 1 from public.profiles where id = auth.uid() and role = 'super_admin')
);

-- 3. SEED standard hold
insert into public.teams (name) values
  ('Damer Elite'), ('Damer 2'), ('Damer 3'),
  ('Herrer 1'), ('Herrer 2'),
  ('U17 Piger'), ('U17 Drenge'),
  ('U15 Piger'), ('U15 Drenge'),
  ('Mini-volley')
on conflict (name) do nothing;

-- ============================================================
-- 4. STORAGE BUCKET til avatars
-- ============================================================

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Storage policies
drop policy if exists "Avatars publicly readable" on storage.objects;
drop policy if exists "Users can upload own avatar" on storage.objects;
drop policy if exists "Users can update own avatar" on storage.objects;
drop policy if exists "Users can delete own avatar" on storage.objects;

-- Bevidst INGEN bred SELECT-policy: bucket'en er public, så billeder vises
-- via getPublicUrl (/object/public/...) uden en SELECT-policy. En bred
-- "select using (bucket_id='avatars')" ville kun give mulighed for at LISTE
-- alle filer i bucket'en (flaget af Supabase security-advisor).

create policy "Users can upload own avatar" on storage.objects for insert
  with check (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);

create policy "Users can update own avatar" on storage.objects for update
  using (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);

create policy "Users can delete own avatar" on storage.objects for delete
  using (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);
