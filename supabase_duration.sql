-- ============================================================
-- Tilføj varighed til opgaver
-- Kør i Supabase Dashboard → SQL Editor → Run
-- ============================================================

alter table public.tasks
  add column if not exists duration_type text default 'single',
  add column if not exists date_end text;
