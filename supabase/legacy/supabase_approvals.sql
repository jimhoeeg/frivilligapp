-- ============================================================
-- Tilføj reviewed_at til profiles (sporér godkendte/afviste)
-- Kør i Supabase Dashboard → SQL Editor → Run
-- ============================================================

alter table public.profiles
  add column if not exists reviewed_at timestamptz;

-- Markér alle eksisterende brugere som allerede reviewede
-- (de er jo allerede aktive — vi vil kun se NYE fra nu af)
update public.profiles
  set reviewed_at = now()
  where reviewed_at is null;
