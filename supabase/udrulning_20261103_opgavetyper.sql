-- ============================================================================
-- UDRULNING: OPGAVETYPER
--
-- Indsæt HELE denne fil i Supabase → SQL Editor → New query → Run.
-- Den kan køres igen uden at lave skade, hvis noget går galt midtvejs.
--
-- Den gør tre ting:
--   1. tilføjer feltet event_navn til opgaverne
--   2. lægger reglen om de tre faner ind som opgave_type()
--   3. trimmer mellemrum i titler — UDEN at sende besked til de tilmeldte
--
-- Til sidst skriver den et par linjer ud, du kan kopiere tilbage til mig.
--
-- VIGTIGT: kør denne fil FØR den nye udgave af appen rulles ud. Omvendt
-- spørger appen efter en kolonne, der ikke findes, og medlemmerne får en tom
-- opgaveliste i nogle minutter.
-- ============================================================================


-- ---------------------------------------------------------------- 1. FELTET

alter table public.tasks
  add column if not exists event_navn text;

comment on column public.tasks.event_navn is
  'Navnet på det event, tjansen hører til (i dag kun "FairPlay Cup"). Tom = almindelig tjans eller sæsonopgave.';


-- ------------------------------------------------------------- 2. MELLEMRUM
--
-- "FairPlay Cup " og "FairPlay Cup" ville blive to events, og ingen ville
-- kunne se forskellen på skærmen — kun at cuppen stod to gange. Navnet
-- trimmes derfor på vej ind, og tomt bliver null. Titlen trimmes af samme
-- grund: det er usynlige mellemrum, der gør to ens tjanser svære at se som ens.

create or replace function public.tasks_trim()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.event_navn := nullif(btrim(coalesce(new.event_navn, '')), '');
  new.title      := btrim(new.title);
  return new;
end;
$$;

drop trigger if exists tasks_trim_trg on public.tasks;
create trigger tasks_trim_trg
  before insert or update of title, event_navn on public.tasks
  for each row execute function public.tasks_trim();

revoke all on function public.tasks_trim() from public, anon, authenticated;


-- ----------------------------------------------------------------- 3. REGLEN
--
-- Rækkefølgen er det hele: FairPlay Cups planlægningsudvalg er en sæsonrolle
-- (duration_type = 'year'), og den skal stå under Events, ikke under
-- Sæsonopgaver. Event vinder derfor over varighed. Hver tjans får præcis én
-- type, så ingen kan lede efter en tjans i den fane, hvor den ikke er.

create or replace function public.opgave_type(p_event text, p_duration text)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select case
    when nullif(btrim(coalesce(p_event, '')), '') is not null then 'event'
    when coalesce(p_duration, 'single') <> 'single'           then 'saeson'
    else 'volleyball'
  end;
$$;

comment on function public.opgave_type(text, text) is
  'Hvilken af appens tre faner en tjans hører til: event > saeson > volleyball. Reglen står kun her.';

revoke all on function public.opgave_type(text, text) from public, anon;
grant execute on function public.opgave_type(text, text) to authenticated;


-- ------------------------------------------------- 4. DE BESTÅENDE TITLER
--
-- on_task_changed slås fra, mens titlerne trimmes, og kun til det. Den
-- trigger sender "Opgaven har fået ny titel" til alle, der står tilmeldt, og
-- flere af de tjanser, der ender på et mellemrum, har folk på. De skulle få
-- en besked om, at en tjans havde skiftet navn, hvor det eneste, der skete,
-- var at et usynligt mellemrum forsvandt. Det er værre end mellemrummet.

alter table public.tasks disable trigger on_task_changed;

update public.tasks
   set title = btrim(title)
 where title <> btrim(title);

alter table public.tasks enable trigger on_task_changed;


-- -------------------------------------------------------------- 5. CUPPEN
--
-- Ingen andre tjanser markeres. "Vask af spillertøj efter stævne" kan både
-- være en event-tjans og en almindelig vagt, og den slags gæt bliver til
-- forkerte data, som ingen får ryddet op bagefter. Resten sætter klubben selv
-- i admin, når cuppen planlægges.

update public.tasks
   set event_navn = 'FairPlay Cup'
 where event_navn is null
   and (title ilike '%fairplay%' or title ilike '%fair play%');


-- ---------------------------------------------- 6. DER VAR INGEN DUBLETTER
--
-- Her stod et afsnit, der slog "dobbelte" stævne-tjanser sammen: U17 pokal
-- 12. dec, U17 13. mar og U15 17. jan stod hver som to rækker med én plads.
--
-- Det var en fejl, og den var min. Jeg grupperede på titel og dato og så
-- aldrig på klokken. De to rækker er en FORMIDDAGSVAGT og en
-- EFTERMIDDAGSVAGT:
--
--   Stævnebord - U17 pokal stævne   lør 12. dec   9:30-12:30 og 13:00-16:30
--   Stævnebord - U17 stævne         lør 13. mar   9:30-12:30 og 12:30-16:30
--   Stævnebord - U15 stævne         søn 17. jan   9:30-12:30 og 12:30-16:30
--   Stævnebord - Kids stævne        søn 15. nov   9:30-12:30 og 13:00-16:30
--
-- Havde sammenlægningen kørt, havde den slettet en rigtig vagt og efterladt
-- én række med to pladser — og så ville den, der havde taget formiddagen,
-- stå tilmeldt en tjans, der sagde hele dagen. På Kids stævne den 15.
-- november ER formiddagsvagten taget, så dér var det gået ud over et medlem.
--
-- Afsnittet er fjernet. Grupperer man tjanser, skal tidsrummet med — to
-- vagter samme dag er to vagter.

-- -------------------------------------------------- 7. SKRIV MIGRATIONEN IND
--
-- Så Supabases egen migrationsliste passer med filerne i git.

-- Den tabel ser forskellig ud fra udgave til udgave, og det her er ren
-- bogføring. Fejler den, skal resten ikke rulles tilbage.

do $$
begin
  insert into supabase_migrations.schema_migrations (version, name)
  values ('20261103090000', 'opgavetyper')
  on conflict (version) do nothing;
exception when others then
  raise notice 'Kunne ikke skrive migrationen ind i Supabases liste (%). Det er kun bogføring — resten er kørt.', sqlerrm;
end $$;


-- ------------------------------------------------------------- 8. KONTROLLEN
--
-- Kopiér de to tabeller herunder tilbage til mig.

select 'opsætning' as hvad,
       (select count(*) from information_schema.columns
         where table_schema='public' and table_name='tasks' and column_name='event_navn') as feltet,
       (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public' and p.proname='opgave_type')                            as reglen,
       (select count(*) from pg_trigger where tgname='tasks_trim_trg')                    as trimtrigger,
       (select tgenabled from pg_trigger where tgname='on_task_changed')                  as task_changed,
       (select count(*) from public.tasks where title <> btrim(title))                    as med_mellemrum,
       (select count(*) from public.notifications where type='task_changed')              as titelbeskeder,
       (select count(*) from public.tasks)                                               as opgaver;

select public.opgave_type(event_navn, duration_type) as fane,
       count(*) as antal, sum(points) as point, sum(spots_left) as ledige_pladser
  from public.tasks
 group by 1
 order by 1;
