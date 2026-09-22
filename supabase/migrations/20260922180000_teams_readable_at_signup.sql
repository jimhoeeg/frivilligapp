-- ============================================================================
-- RVK Frivillig – holdlisten skal kunne læses på oprettelsesskærmen
--
-- 20260919080000_policies_from_legacy.sql strammede læsereglen på teams fra
-- "using (true)" til "using (auth.uid() is not null)", i samme ombæring som
-- opgaver og indstillinger. Det var rigtigt for de to andre. For hold var det
-- forkert, og fejlen er min.
--
-- Oprettelsesskærmen henter holdene, FØR nogen er logget ind — det er hele
-- pointen: man vælger sit hold, mens man opretter sig. Med den stramme regel
-- fik en ny bruger 0 rækker, appen faldt tilbage til listen ["Ny"], og feltet
-- er påkrævet. Alle nye medlemmer ville altså ende på et opdigtet hold, der
-- hedder "Ny".
--
-- Holdnavne er ikke personoplysninger. "Dame 1" og "Herre 2" står på klubbens
-- hjemmeside og i enhver turneringsplan. Der er intet at beskytte, og
-- alternativet — at vælge hold efter oprettelsen — betyder, at admins skal
-- godkende folk uden at vide, hvem de er.
--
-- Skrivning er uændret: kun super admins kan oprette, omdøbe og slette hold.
--
-- Kan køres flere gange uden at gøre skade.
-- ============================================================================

drop policy if exists "teams_select" on public.teams;

create policy "teams_select" on public.teams for select
  using (true);


-- ============================================================================
-- EFTERSYN
--
-- Skal give 16 (eller hvor mange hold I nu har), ikke 0:
--
--   set local role anon;
--   select count(*) from public.teams;
--   reset role;
--
-- Og skrivning skal stadig være lukket for alle andre end super admins:
--
--   select polname, polcmd, pg_get_expr(polqual, polrelid)
--     from pg_policy where polrelid = 'public.teams'::regclass;
-- ============================================================================
