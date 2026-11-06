-- ============================================================================
-- UDRULNING: OPGAVETYPER + OPRYDNING I DUBLETTERNE
--
-- Indsæt HELE denne fil i Supabase → SQL Editor → New query → Run.
-- Den kan køres igen uden at lave skade, hvis noget går galt midtvejs.
--
-- Den gør fire ting:
--   1. tilføjer feltet event_navn til opgaverne
--   2. lægger reglen om de tre faner ind som opgave_type()
--   3. trimmer mellemrum i titler — UDEN at sende besked til de tilmeldte
--   4. slår de dobbelte stævne-tjanser sammen, hvor ingen står tilmeldt
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


-- ------------------------------------------------------------ 6. DUBLETTER
--
-- Tre steder står den samme tjans som to rækker med én plads hver i stedet
-- for én række med to pladser. De slås sammen: den ældste række beholdes og
-- får pladserne fra begge, resten slettes.
--
-- Betingelsen er, at INGEN af rækkerne i gruppen har tilmeldte. Derfor rører
-- den IKKE "Stævnebord - Kids stævne" den 15. november, hvor der står et
-- medlem på den ene — at flytte en tilmelding for at spare en linje på en
-- liste er ikke værd at gøre. Og den rører ikke "Teen stævne"/"Teenstævne"
-- den 3. oktober, som kun er stavet forskelligt og er to rigtige vagter.
--
-- Den er bundet til NETOP de tre par, der er aftalt — ikke til "alt, der
-- ligner en dublet". Er der kommet et nyt dubletpar til siden, bliver det
-- stående, til nogen har set på det. Et script, der rydder op af sig selv i
-- rækker, ingen har kigget på, er ikke oprydning.

do $$
declare
  g        record;
  v_behold uuid;
  v_samlet  int := 0;
begin
  for g in
    select btrim(title) as titel, date as dato,
           sum(spots_total) as pladser
      from public.tasks
     where (btrim(title), date) in (
             ('Stævnebord - U17 pokal stævne', 'Lør 12. dec'),
             ('Stævnebord - U17 stævne',       'Lør 13. mar'),
             ('Stævnebord - U15 stævne',       'Søn 17. jan')
           )
     group by btrim(title), date
    having count(*) > 1
       and sum((select count(*) from public.task_claims c where c.task_id = tasks.id)) = 0
  loop
    select id into v_behold
      from public.tasks
     where btrim(title) = g.titel and date = g.dato
     order by created_at nulls last, id
     limit 1;

    update public.tasks
       set spots_total = g.pladser,
           spots_left  = g.pladser
     where id = v_behold;

    delete from public.tasks
     where btrim(title) = g.titel and date = g.dato
       and id <> v_behold;

    v_samlet  := v_samlet + 1;
    raise notice 'Slog sammen: "%" (%) → 1 række med % pladser', g.titel, g.dato, g.pladser;
  end loop;

  raise notice 'Grupper slået sammen: %', v_samlet;
end $$;


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
