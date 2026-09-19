-- ============================================================================
-- RVK Frivillig – oprydning efter en gren der aldrig blev merget
--
-- Grenen claude/app-domain-usage-lsz87f ligger stadig ude på origin med fem
-- commits, der ALDRIG kom med i main. Én af dem siger i sin commit-besked
-- "Matcher det der nu er anvendt i Supabase-projektet via MCP" — altså blev
-- dens SQL kørt på den rigtige database, selvom koden aldrig blev merget.
--
-- Den gren lavede sin egen vej til at uddele point:
--
--   claim_task(uuid)        RPC der opretter en tilmelding
--   unclaim_task(uuid)      RPC der fjerner den og trækker point tilbage
--   handle_task_claim()     triggerfunktion der lagde point til
--
-- Appen kalder dem ikke længere — point styres nu udelukkende af
-- tc_before_insert / tc_after_insert / tc_after_update / tc_after_delete.
-- Men så længe funktionerne ligger i databasen med EXECUTE-rettigheder, er
-- der to forskellige måder at ændre en persons point på, og kun den ene er
-- den, vi har testet. Derfor ryddes de væk her.
--
-- Filen er harmløs, hvis funktionerne aldrig har eksisteret.
--
-- Kør i Supabase Dashboard → SQL Editor → Run. Kan køres flere gange.
-- Kør EFTER de tre foregående migrationer.
-- ============================================================================


-- ============================================================================
-- 1. FJERN DEN GAMLE POINTVEJ
-- ============================================================================

-- Triggeren er allerede droppet i 20260910120000_launch_hardening.sql.
-- Her fjernes funktionen bagved, så den ikke kan hægtes på igen ved et uheld.
drop trigger  if exists on_task_claimed on public.task_claims;
drop function if exists public.handle_task_claim() cascade;

-- De to RPC'er skrev direkte i profiles.points. Ingen af dem kaldes af appen.
drop function if exists public.claim_task(uuid)   cascade;
drop function if exists public.unclaim_task(uuid) cascade;


-- ============================================================================
-- 2. AVATAR-BUCKET: FJERN DEN BREDE LÆSEPOLITIK
--
-- Fra samme gren, og værd at tage med: bucket'en er public, så billeder
-- vises via getPublicUrl uden en SELECT-politik. En bred
-- "select using (bucket_id = 'avatars')" giver derfor ingen ekstra adgang
-- til billederne — den giver kun mulighed for at LISTE alle filer i
-- bucket'en, altså se hvem der har uploadet hvad. Supabases egen
-- security-advisor flagede den.
-- ============================================================================

do $$ begin
  drop policy if exists "Avatars publicly readable" on storage.objects;
exception when others then
  raise notice 'Kunne ikke røre storage-politikker (%). Spring over hvis storage ikke er i brug.', sqlerrm;
end $$;


-- ============================================================================
-- 3. EFTERSYN
--
-- Kør denne bagefter og se efter, at der kun er ÉN vej til point.
-- Forventet resultat:
--
--   tc_after_delete, tc_after_insert, tc_after_update  (triggerfunktioner)
--   admin_adjust_points                                (admins bonuspoint)
--   auto_confirm_due_claims                            (sætter kun status)
--
-- Dukker der andre op — især noget der hedder claim/unclaim/handle_task —
-- er der en rest tilbage fra en gammel kørsel, og den skal væk.
-- ============================================================================

-- select p.proname, pg_get_function_identity_arguments(p.oid) as args
--   from pg_proc p
--   join pg_namespace n on n.oid = p.pronamespace
--  where n.nspname = 'public'
--    and pg_get_functiondef(p.oid) ilike '%profiles%points%'
--  order by 1;

-- select tgname from pg_trigger
--  where tgrelid = 'public.task_claims'::regclass and not tgisinternal
--  order by 1;
