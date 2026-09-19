-- ============================================================================
-- RVK Frivillig – startindhold
--
-- RET DENNE FIL, FØR DU KØRER DEN. Den indeholder gæt, ikke klubbens data.
--
-- To ting skal på plads, før appen kan bruges af nogen:
--
--   1. Holdene. Medlemmer vælger hold, når de opretter sig, så listen skal
--      passe til RVK's rigtige hold. Er tabellen tom, kan man ikke oprette
--      sig ordentligt.
--
--   2. Mindst to super admins. Én er for sårbart — mister den ene adgangen,
--      er klubben låst ude af sit eget admin-panel.
--
-- Kør i Supabase Dashboard → SQL Editor → Run, EFTER migrationerne.
-- Filen kan køres flere gange: den tilføjer, men overskriver ikke.
-- ============================================================================


-- ============================================================================
-- 1. HOLD  ← RET LISTEN HER
--
-- Navnene herunder er standardnavne fra den oprindelige opsætning. De er
-- sandsynligvis ikke jeres. Skriv klubbens rigtige hold, i den rækkefølge
-- I gerne vil se dem.
-- ============================================================================

insert into public.teams (name) values
  ('Damer Elite'),
  ('Damer 2'),
  ('Damer 3'),
  ('Herrer 1'),
  ('Herrer 2'),
  ('U17 Piger'),
  ('U17 Drenge'),
  ('U15 Piger'),
  ('U15 Drenge'),
  ('Mini-volley'),
  ('Forælder / pårørende'),      -- til dem der hjælper uden selv at spille
  ('Bestyrelse')
on conflict (name) do nothing;


-- ============================================================================
-- 2. SUPER ADMINS  ← RET E-MAILERNE HER
--
-- Personerne skal have oprettet sig i appen FØRST. Denne linje finder dem
-- på e-mail og giver dem rollen.
--
-- Bemærk at de også sættes som godkendte — ellers ville de sidde fast på
-- ventesiden og ikke kunne godkende sig selv.
-- ============================================================================

update public.profiles
   set role        = 'super_admin',
       approved    = true,
       reviewed_at = coalesce(reviewed_at, now())
 where lower(email) in (
   'formand@randersvk.dk',       -- ← ret til en rigtig e-mail
   'kasserer@randersvk.dk'       -- ← og én mere
 );

-- Kontrollér at det virkede. Står der færre end to rækker, ramte e-mailerne
-- ikke nogen — så har personerne ikke oprettet sig endnu, eller adressen er
-- stavet anderledes i appen.
select name, email, role, approved
  from public.profiles
 where role = 'super_admin'
 order by name;


-- ============================================================================
-- 3. KLUBBENS INDSTILLINGER  ← TJEK TALLENE
--
-- Kan også sættes i admin-panelet under Indstillinger. Her for at have det
-- samlet ét sted ved en ny opsætning.
-- ============================================================================

insert into public.settings (key, value) values
  ('point_goal',        '100'),        -- point pr. halvsæson for at være bidragsfri
  ('contribution_kr',   '1500'),       -- frivillighedsbidrag i kroner
  ('season_start',      '2025-08-01'),
  ('season_end',        '2026-06-30'),
  ('auto_confirm_days', '7')           -- 0 slår automatisk bekræftelse fra
on conflict (key) do update set value = excluded.value, updated_at = now();


-- ============================================================================
-- 4. OPGAVER
--
-- Med vilje ingen her. En tom opgaveliste ved lancering er svær at komme
-- tilbage fra, men opgaverne skal være rigtige — de skal oprettes i
-- admin-panelet, hvor datovælgeren sørger for, at datoerne bliver gemt i et
-- format, resten af appen kan regne med.
--
-- Opret et rimeligt antal, før linket sendes ud. Har I en kampplan, er
-- dommerbord og cafévagter det oplagte sted at begynde.
-- ============================================================================


-- ============================================================================
-- EFTERSYN
-- ============================================================================

select 'hold'          as hvad, count(*)::text as antal from public.teams
union all
select 'super admins',  count(*)::text from public.profiles where role = 'super_admin'
union all
select 'medlemmer',     count(*)::text from public.profiles
union all
select 'opgaver',       count(*)::text from public.tasks
union all
select 'indstillinger', count(*)::text from public.settings;
