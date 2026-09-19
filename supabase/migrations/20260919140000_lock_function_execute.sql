-- ============================================================================
-- RVK Frivillig – luk funktionerne for dem der ikke er logget ind
--
-- I Postgres må ALLE kalde en funktion, med mindre man udtrykkeligt siger
-- fra. Standardrettigheden hedder PUBLIC og gives automatisk ved create
-- function. Supabase lægger oven i købet en eksplicit rettighed til `anon`
-- via alter default privileges.
--
-- De foregående migrationer skriver "grant execute ... to authenticated" og
-- tror dermed, at sagen er klaret. Det er den ikke: en rettighed GIVET til
-- authenticated fjerner ikke den, alle har i forvejen. Resultatet er, at en
-- ikke-indlogget kan kalde samtlige funktioner via /rest/v1/rpc/.
--
-- For de fleste af dem er det uden betydning – de tjekker selv kalderens
-- rolle og fejler for anonyme. Tre gjorde ikke:
--
--   task_claim_counts()        kunne tælle tilmeldte pr. opgave
--   prune_client_errors()      kunne slette fejllog ældre end 90 dage
--   auto_confirm_due_claims()  kunne fremtvinge opgørelsen uden for tid
--
-- Ingen af dem lækker personoplysninger, og ingen af dem kan give point til
-- nogen, der ikke har optjent dem. Men der er ingen grund til at lade dem
-- stå åbne.
--
-- Filen vender princippet om: INGEN må kalde noget, og derefter får de
-- indloggede udtrykkeligt lov til præcis det, appen bruger.
--
-- Kan køres flere gange uden at gøre skade.
-- ============================================================================


-- ============================================================================
-- 1. TAG STANDARDRETTIGHEDEN FRA ALLE
--
-- Både PUBLIC (alle) og anon. service_role røres ikke: den nøgle ligger kun
-- på serveren, bag edge-funktionen, og skal kunne det hele.
-- ============================================================================

revoke execute on all functions in schema public from public;
revoke execute on all functions in schema public from anon;

-- Også authenticated. Supabase giver de indloggede en EGEN rettighed til
-- alt i public via alter default privileges, så uden denne linje ville
-- listen i afsnit 2 være pynt: hvert medlem ville stadig kunne kalde fx
-- prune_client_errors(). Rettighederne gives tilbage nedenfor, én for én.
revoke execute on all functions in schema public from authenticated;

-- Fjern også Supabases egne standardrettigheder til anon og authenticated,
-- så de ikke bliver givet igen til næste funktion.
alter default privileges in schema public revoke execute on functions from anon;
alter default privileges in schema public revoke execute on functions from authenticated;

-- BEMÆRK: PUBLIC kan IKKE lukkes på denne måde.
--
--   alter default privileges ... revoke execute on functions from public;
--
-- ser ud til at virke, men gør ingenting. Den kan kun trække tilbage, hvad
-- alter default privileges selv har uddelt – ikke Postgres' indbyggede
-- rettighed, som enhver ny funktion får. Afprøvet: en funktion oprettet
-- bagefter står stadig med "=X/postgres", altså åben for alle.
--
-- Derfor gælder følgende regel for alle fremtidige migrationer:
--
--   EN MIGRATION, DER OPRETTER EN FUNKTION, SKAL SELV LUKKE DEN:
--
--     revoke execute on function public.min_funktion(...) from public, anon;
--     grant  execute on function public.min_funktion(...) to authenticated;
--
-- Glemmer man det, fanger linje 18.5 i supabase/VERIFY.sql det.


-- ============================================================================
-- 2. RETTIGHEDER TILBAGE TIL DE INDLOGGEDE
--
-- Listen er præcis de 17 funktioner, appen kalder med .rpc(), plus de to
-- som RLS-politikkerne selv bruger. Bruger du en ny funktion i appen, skal
-- den tilføjes her – ellers får medlemmerne "permission denied".
-- ============================================================================

-- --- Politikkernes egne hjælpere -------------------------------------------
-- 19 politikker kalder get_my_role(), og claims/swaps kalder is_approved().
-- Politikudtryk evalueres som den kaldende rolle, så uden disse to virker
-- adgangsreglerne ikke – appen ville ikke kunne læse en eneste opgave.
grant execute on function public.get_my_role()          to authenticated;
grant execute on function public.is_approved(uuid)      to authenticated;

-- --- Egen profil og medlemsliste -------------------------------------------
grant execute on function public.my_profile()           to authenticated;
grant execute on function public.admin_list_members()   to authenticated;
grant execute on function public.request_admin_access() to authenticated;

-- --- Admin: roller, godkendelser, point ------------------------------------
grant execute on function public.admin_set_role(uuid, text)          to authenticated;
grant execute on function public.admin_set_approval(uuid, boolean)   to authenticated;
grant execute on function public.admin_dismiss_request(uuid)         to authenticated;
grant execute on function public.admin_adjust_points(uuid, int)      to authenticated;

-- --- Bytte ------------------------------------------------------------------
grant execute on function public.accept_swap(uuid)  to authenticated;
grant execute on function public.decline_swap(uuid) to authenticated;

-- --- Bekræftelse af gennemførte tjanser ------------------------------------
grant execute on function public.admin_set_claim_status(uuid, uuid, text, text) to authenticated;
grant execute on function public.admin_confirm_task(uuid, text)                 to authenticated;
grant execute on function public.admin_pending_confirmations()                  to authenticated;
grant execute on function public.admin_task_signups(uuid)                       to authenticated;
grant execute on function public.task_claim_counts(uuid)                        to authenticated;

-- --- Automatikken -----------------------------------------------------------
-- auto_confirm_due_claims har med vilje intet rolletjek: den anvender kun en
-- deterministisk regel og kan ikke godkende noget, der ikke allerede er
-- forfaldent. Men den skal ikke kunne kaldes af en fremmed.
grant execute on function public.auto_confirm_due_claims(boolean) to authenticated;
grant execute on function public.auto_confirm_preview()           to authenticated;

-- --- Fejlrapportering -------------------------------------------------------
grant execute on function public.log_client_error(text, text, text, text, text) to authenticated;

-- Bevidst IKKE givet til nogen:
--   prune_client_errors()   kaldes af pg_cron, som kører som databaseejeren
--   task_end_date()         kaldes kun inde fra security definer-funktioner
--   tc_*, *_notify()        triggerfunktioner; triggere kontrollerer ikke
--                           EXECUTE ved kørsel, kun når triggeren oprettes


-- ============================================================================
-- 3. task_claim_counts FÅR ET ROLLETJEK
--
-- Den fortæller, hvor mange der står på en opgave, og bruges til at advare
-- en admin, inden pointtallet ændres. Der er ingen grund til, at et
-- almindeligt medlem kan spørge om det – og slet ingen til at en fremmed
-- kan. Rettigheden ovenfor lukker de anonyme ude; det her lukker resten.
-- ============================================================================

create or replace function public.task_claim_counts(p_task uuid)
returns table (
  signed_up int,
  completed int,
  no_show   int
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan se dette';
  end if;

  return query
    select count(*) filter (where c.status = 'signed_up')::int,
           count(*) filter (where c.status = 'completed')::int,
           count(*) filter (where c.status = 'no_show')::int
      from public.task_claims c
     where c.task_id = p_task;
end;
$$;

grant execute on function public.task_claim_counts(uuid) to authenticated;


-- ============================================================================
-- 4. task_end_date FÅR EN LÅST search_path
--
-- Supabases sikkerhedsscanner flagede den som den eneste funktion uden.
-- Uden en fast search_path kan en kalder med rettigheder til at oprette et
-- skema flytte, hvad funktionen rammer. Den er ren og rører ingen tabeller,
-- så det er teoretisk – men det koster én linje at fjerne spørgsmålet.
-- ============================================================================

create or replace function public.task_end_date(p_date_full text, p_date_end text)
returns date
language sql
immutable
set search_path = pg_catalog, pg_temp
as $$
  select case
    when p_date_end  ~ '^\d{4}-\d{2}-\d{2}' then substring(p_date_end,  1, 10)::date
    when p_date_full ~ '^\d{4}-\d{2}-\d{2}' then substring(p_date_full, 1, 10)::date
    else null
  end;
$$;


-- ============================================================================
-- EFTERSYN
--
-- Ingen af disse må give rækker tilbage:
--
--   select p.proname from pg_proc p
--     join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public'
--      and has_function_privilege('anon', p.oid, 'execute');
--
-- Og appens egne skal alle stå der:
--
--   select p.proname from pg_proc p
--     join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public'
--      and has_function_privilege('authenticated', p.oid, 'execute')
--    order by 1;
-- ============================================================================
