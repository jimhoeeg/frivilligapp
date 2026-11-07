-- ============================================================================
-- OPGAVETYPER: VOLLEYBALL · SÆSONOPGAVER · EVENTS
--
-- Klubben har fået flere slags tjanser, end forsiden kan bære i én liste. De
-- deles nu i tre, som medlemmet kan klikke mellem:
--
--   Volleyball     alt det løbende — kampe, stævnebord, boldlanger, kørsel
--   Sæsonopgaver   det man ER hen over en periode — bestyrelse, holdleder
--   Events         FairPlay Cup
--
-- ---------------------------------------------------------------------------
-- HVORFOR DER KUN KOMMER ÉT NYT FELT
--
-- To af de tre typer står allerede i data. Sæsonopgaver er dem, hvor
-- duration_type ikke er 'single' — det er præcis den gruppe, appen i dag
-- lægger i en sammenklappet sektion nederst på skærmen. Den skal bare op som
-- en fane, og det kræver ingen nye kolonner.
--
-- Events kan derimod ikke udledes. "Medlem af stævneudvalg (planlægning)
-- FairPlayCup" ligger i kategorien Stævneplanlægning sammen med klubbens
-- almindelige stævner, og de to skal IKKE samme sted hen: almindelige
-- stævner og kampe hører under Volleyball. Derfor ét felt: event_navn.
--
-- Det er et navn og ikke et ja/nej-flueben, selvom der i dag kun findes én
-- værdi. Det koster det samme at skrive, og den dag klubben også vil samle en
-- Volleyball Camp eller en klubfest under Events, er det et nyt navn i
-- rullelisten — ikke en ny migration.
--
-- Typen gemmes IKKE som en kolonne for sig. Så ville der være to kilder til
-- det samme — en sæsonrolle, der stod som "Volleyball", fordi nogen havde
-- rettet varigheden bagefter — og ingen ville opdage det. Typen udledes i
-- stedet af de to felter, og reglen står ét sted: opgave_type() nedenfor.
-- ============================================================================


-- ------------------------------------------------------------- FELTET ---

alter table public.tasks
  add column if not exists event_navn text;

comment on column public.tasks.event_navn is
  'Navnet på det event, tjansen hører til (i dag kun "FairPlay Cup"). Tom = almindelig tjans eller sæsonopgave.';


-- --------------------------------------------------------- MELLEMRUM ---
--
-- "FairPlay Cup " og "FairPlay Cup" ville blive to events, og ingen ville
-- kunne se forskellen på skærmen — kun at cuppen pludselig stod to gange.
-- Navnet trimmes derfor på vej ind, og tomt bliver null.
--
-- Titlen trimmes af samme grund. Der ligger i forvejen tjanser i databasen,
-- hvis titel ender på et mellemrum ("Stævnebord - U17 pokal stævne  "), og
-- det er dem, der gør to ens tjanser svære at se som ens.

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


-- ------------------------------------------------------------ REGLEN ---
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


-- -------------------------------------------------- DE BESTÅENDE RÆKKER ---
--
-- Mellemrummene først. Triggeren ovenfor tager kun de rækker, nogen rører
-- fremover; de 48, der ligger nu, skal rettes her. Kun titlen trimmes — ikke
-- noget, der har med point eller tilmeldinger at gøre.
--
-- on_task_changed slås fra, mens det sker, og kun til det. Den trigger sender
-- "Opgaven har fået ny titel" til alle, der står tilmeldt, hver gang titlen
-- ændrer sig — og flere af de tjanser, der ender på et mellemrum, har folk
-- på. De skulle få en besked om, at en tjans havde skiftet navn, hvor det
-- eneste, der skete, var at et usynligt mellemrum forsvandt. Det er værre end
-- mellemrummet.

alter table public.tasks disable trigger on_task_changed;

update public.tasks
   set title = btrim(title)
 where title <> btrim(title);

alter table public.tasks enable trigger on_task_changed;

-- Og så cuppen. Der findes præcis én FairPlay Cup-tjans i dag:
-- "Medlem af stævneudvalg (planlægning) FairPlayCup". Den sættes på eventet
-- her, så Events-fanen ikke står tom fra dag ét.
--
-- Ingen andre tjanser markeres. "Vask af spillertøj efter stævne" kan både
-- være en event-tjans og en almindelig vagt, og den slags gæt bliver til
-- forkerte data, som ingen får ryddet op bagefter. Resten sætter klubben selv
-- i admin, når cuppen planlægges.

update public.tasks
   set event_navn = 'FairPlay Cup'
 where event_navn is null
   and (title ilike '%fairplay%' or title ilike '%fair play%');
