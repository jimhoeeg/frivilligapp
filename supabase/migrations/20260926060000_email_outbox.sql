-- ============================================================================
-- MAIL UD AF APPEN
--
-- Appen har hele tiden kunnet skrive til medlemmerne — men kun INDE i appen.
-- Beskederne lå og ventede på, at nogen åbnede den. Over halvdelen af alle
-- beskeder, der nogensinde er sendt, er "du er godkendt": den besked, et nyt
-- medlem har allermest brug for at få at vide, og den eneste de ikke kan se,
-- før de logger ind.
--
-- Fire slags mail sendes nu:
--
--   godkendt        du er lukket ind i klubbens app
--   tildelt         en admin har sat dig på en tjans
--   ændret/aflyst   tidspunktet eller stedet er flyttet
--   påmindelse      du står på en tjans om to dage
--
-- ---------------------------------------------------------------------------
-- HVORFOR EN UDBAKKE, OG IKKE BARE ET KALD?
--
-- Fordi mail er noget, der kan gå galt halvvejs. Sender man direkte fra en
-- trigger, sidder man med tre dårlige valg: at lade medlemmets handling
-- fejle, fordi en mailserver er nede; at tabe beskeden; eller at prøve igen
-- og sende den samme mail fire gange.
--
-- Her skrives beskeden ned FØRST, med en nøgle der siger præcis hvilken
-- hændelse den hører til. Et job tømmer udbakken bagefter. Går det galt,
-- ligger rækken der stadig og kan prøves igen — og den unikke nøgle sørger
-- for, at den samme påmindelse aldrig kan lægges i udbakken to gange.
-- ============================================================================

-- pg_net er Supabases udvidelse til at kalde ud af databasen. Findes den
-- ikke (fx i en lokal Postgres under test), skal migrationen ikke vælte —
-- udbakken fyldes stadig, den bliver bare ikke tømt.
do $outer$
begin
  create extension if not exists pg_net with schema extensions;
exception when others then
  raise notice 'pg_net ikke tilgaengelig (%). Udbakken fyldes, men tømmes ikke herfra.', sqlerrm;
end
$outer$;


-- ---------------------------------------------------------------- UDBAKKE ---

create table if not exists public.email_outbox (
  id          bigserial   primary key,
  kind        text        not null,
  user_id     uuid        references public.profiles(id) on delete cascade,
  to_email    text        not null,
  subject     text        not null,
  data        jsonb       not null default '{}'::jsonb,
  -- Nøglen til hændelsen. 'reminder:<claim-id>' kan kun ligge her én gang,
  -- uanset hvor mange gange jobbet kører.
  dedupe_key  text        not null unique,
  created_at  timestamptz not null default now(),
  sent_at     timestamptz,
  attempts    int         not null default 0,
  last_error  text
);

comment on table public.email_outbox is
  'Mail på vej ud. Skrives af triggere og cron, tømmes af send-mail-funktionen.';

create index if not exists email_outbox_venter_idx
  on public.email_outbox (created_at) where sent_at is null;

alter table public.email_outbox enable row level security;

-- Ingen politikker: hverken medlemmer eller admins læser den her fra appen.
-- Den indeholder e-mailadresser og beskedindhold, og kun serveren har brug
-- for den. service_role går uden om RLS.
revoke all on public.email_outbox from public, anon, authenticated;
revoke all on sequence public.email_outbox_id_seq from public, anon, authenticated;


-- ------------------------------------------------------- MEDLEMMETS VALG ---
--
-- Påmindelser er en venlighed, ikke en besked man SKAL have. Derfor kan de
-- slås fra. De tre andre er svar på noget, der lige er sket med ens egen
-- profil eller ens egen tjans — dem sender vi altid.

alter table public.profiles
  add column if not exists email_reminders boolean not null default true;

comment on column public.profiles.email_reminders is
  'Vil medlemmet have påmindelser på mail? Slås til og fra i appen under Profil.';

-- Rettigheder på profiles er sat KOLONNE for kolonne — et medlem kan rette
-- sit navn, men ikke sine point eller sin rolle. Den nye kolonne skal med i
-- den liste, ellers kan man ikke slå påmindelser fra i appen.
grant update (email_reminders) on public.profiles to authenticated;


-- ------------------------------------------------ FRA BESKED TIL UDBAKKE ---
--
-- Mailen skrives ud fra den besked, appen alligevel laver. Så kan de to ikke
-- komme til at sige hver sit.

create or replace function public.queue_email_from_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email  text;
  v_navn   text;
  v_opgave record;
begin
  if new.type not in ('approved', 'task_assigned', 'task_changed', 'task_cancelled') then
    return new;
  end if;

  select email, name into v_email, v_navn
  from public.profiles where id = new.user_id;

  -- Ingen adresse, ingen mail. Beskeden ligger stadig inde i appen.
  if v_email is null or v_email = '' then
    return new;
  end if;

  select title, date, time, location into v_opgave
  from public.tasks where id = new.action_task_id;

  insert into public.email_outbox (kind, user_id, to_email, subject, data, dedupe_key)
  values (
    new.type,
    new.user_id,
    v_email,
    new.title,
    jsonb_strip_nulls(jsonb_build_object(
      'navn',    split_part(coalesce(v_navn, ''), ' ', 1),
      'titel',   new.title,
      'tekst',   new.body,
      'opgave',  v_opgave.title,
      'dato',    v_opgave.date,
      'tid',     v_opgave.time,
      'sted',    v_opgave.location
    )),
    'notif:' || new.id::text
  )
  on conflict (dedupe_key) do nothing;

  return new;
exception when others then
  -- En mail, der ikke kan lægges i udbakken, må ALDRIG vælte det, medlemmet
  -- var i gang med. Beskeden i appen er det vigtigste.
  raise warning 'kunne ikke lægge mail i udbakken: %', sqlerrm;
  return new;
end;
$$;

drop trigger if exists notifications_to_outbox on public.notifications;
create trigger notifications_to_outbox
  after insert on public.notifications
  for each row execute function public.queue_email_from_notification();


-- ------------------------------------------------------------ PÅMINDELSER ---
--
-- To dage før. Ikke dagen før (for sent til at finde en afløser) og ikke en
-- uge før (så har man glemt det igen).

create or replace function public.queue_task_reminders(p_days int default 2)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_antal int;
begin
  with kandidater as (
    select tc.id as claim_id,
           tc.user_id,
           p.email,
           split_part(coalesce(p.name, ''), ' ', 1) as fornavn,
           t.title, t.date, t.time, t.location
    from public.task_claims tc
    join public.profiles p on p.id = tc.user_id
    join public.tasks t    on t.id = tc.task_id
    where tc.status = 'signed_up'
      and p.email is not null and p.email <> ''
      and p.email_reminders
      and t.date_full ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
      and t.date_full::date = current_date + p_days
  ),
  lagt as (
    insert into public.email_outbox (kind, user_id, to_email, subject, data, dedupe_key)
    select 'reminder', k.user_id, k.email,
           'Husk: ' || k.title,
           jsonb_strip_nulls(jsonb_build_object(
             'navn', k.fornavn, 'opgave', k.title,
             'dato', k.date, 'tid', k.time, 'sted', k.location,
             'dage', p_days
           )),
           'reminder:' || k.claim_id::text
    from kandidater k
    on conflict (dedupe_key) do nothing
    returning 1
  )
  select count(*) into v_antal from lagt;

  return v_antal;
end;
$$;

comment on function public.queue_task_reminders(int) is
  'Lægger påmindelser i udbakken for tjanser om p_days dage. Kan køres igen uden at sende dobbelt.';


-- --------------------------------------------------------- TØM UDBAKKEN ---
--
-- Databasen sender ikke selv mail — den banker på send-mail-funktionen, som
-- har nøglen til Resend. Nøglen til at kalde funktionen ligger i Supabases
-- Vault under navnet 'outbox_key', så den hverken står her i filen eller i
-- et cron-job, nogen kan læse.

create or replace function public.drain_email_outbox()
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_key text;
  v_url text;
begin
  if not exists (select 1 from public.email_outbox where sent_at is null and attempts < 3) then
    return 'ingenting at sende';
  end if;

  select decrypted_secret into v_key
  from vault.decrypted_secrets where name = 'outbox_key';

  select decrypted_secret into v_url
  from vault.decrypted_secrets where name = 'outbox_url';

  if v_key is null or v_url is null then
    -- Ikke en fejl, der skal larme hver femte minut. Udbakken venter bare.
    return 'outbox_key eller outbox_url mangler i Vault – intet sendt';
  end if;

  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-outbox-key', v_key),
    body    := '{}'::jsonb
  );

  return 'bankede paa send-mail';
exception when others then
  -- Et job, der fejler hvert femte minut, fylder loggen og skjuler de
  -- fejl, der betyder noget. Udbakken venter til næste gang.
  return 'kunne ikke kalde send-mail: ' || sqlerrm;
end;
$$;

revoke all on function public.drain_email_outbox()        from public, anon, authenticated;
revoke all on function public.queue_task_reminders(int)   from public, anon, authenticated;
revoke all on function public.queue_email_from_notification() from public, anon, authenticated;


-- ------------------------------------------------------------------ CRON ---

do $outer$
begin
  create extension if not exists pg_cron;

  if exists (select 1 from cron.job where jobname = 'rvk_email_drain') then
    perform cron.unschedule('rvk_email_drain');
  end if;
  if exists (select 1 from cron.job where jobname = 'rvk_email_reminders') then
    perform cron.unschedule('rvk_email_reminders');
  end if;

  -- Hvert femte minut. Mail behøver ikke være øjeblikkelig, og et job, der
  -- kører sjældnere, er også et job, der larmer mindre, når noget er galt.
  perform cron.schedule('rvk_email_drain', '*/5 * * * *',
    $job$ select public.drain_email_outbox(); $job$);

  -- 15:05 UTC = 17:05 dansk sommertid, 16:05 om vinteren. Sen eftermiddag:
  -- folk har fri, og der er stadig to dage til at finde en afløser.
  perform cron.schedule('rvk_email_reminders', '5 15 * * *',
    $job$ select public.queue_task_reminders(2); $job$);

  raise notice 'pg_cron: rvk_email_drain hvert 5. minut, rvk_email_reminders 15:05 UTC';
exception when others then
  raise notice 'pg_cron ikke tilgaengelig (%). Udbakken fyldes stadig, men bliver ikke sendt.', sqlerrm;
end
$outer$;
