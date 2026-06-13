-- ============================================================
-- Settings tabel til AdminSettings
-- Kør dette i Supabase Dashboard → SQL Editor → Run
-- ============================================================

create table if not exists public.settings (
  key        text primary key,
  value      text not null,
  updated_at timestamptz default now()
);

alter table public.settings enable row level security;

drop policy if exists "settings_select" on public.settings;
drop policy if exists "settings_upsert" on public.settings;

-- Alle kan læse indstillinger (bruges til at vise pointmål i UI)
create policy "settings_select" on public.settings for select using (true);

-- Kun super_admin kan ændre
create policy "settings_upsert" on public.settings for insert with check (
  exists (select 1 from public.profiles where id = auth.uid() and role = 'super_admin')
);
create policy "settings_update" on public.settings for update using (
  exists (select 1 from public.profiles where id = auth.uid() and role = 'super_admin')
);

-- Seed standard værdier
insert into public.settings (key, value) values
  ('point_goal',      '75'),
  ('contribution_kr', '1500'),
  ('season_start',    '2025-08-01'),
  ('season_end',      '2026-06-30')
on conflict (key) do nothing;
