-- ============================================================================
-- MÅNEDENS FRIVILLIGE
--
-- Klubben vil hædre én om måneden. Systemet peger, bestyrelsen vælger, og
-- valget gemmes.
--
-- ---------------------------------------------------------------------------
-- HVORFOR IKKE EN AUTOMATISK VINDER
--
-- Ranglisten siger selv til medlemmerne, at den er "et skulderklap, ikke en
-- konkurrence". I samme sekund appen uddeler en pris efter point, er det en
-- konkurrence. Og tallene kan ikke se det, man faktisk vil hædre: hun der
-- sprang til dagen før, ham der kørte klokken seks, moren der vaskede trøjer
-- hele måneden uden at skrive sig på noget.
--
-- Appens opgave er at lægge de rigtige navne på bordet, så ingen bliver
-- glemt, fordi ingen kiggede efter dem. Valget er menneskets.
--
-- ---------------------------------------------------------------------------
-- VALGET FRYSES. KANDIDATERNE REGNES UD.
--
-- Det her er den vigtigste linje i filen. Kandidatlisten regnes ud, hver gang
-- nogen ser på den — men BESLUTNINGEN skrives ned. Hvis ranglisten regnede
-- "månedens frivillige" ud live, kunne oktobers hædrede skifte i november,
-- fordi en gammel tjans blev godkendt, et pointtal rettet eller en opgave
-- slettet. En hædring, der kan laves om bagefter, er ingen hædring.
--
-- Det er samme princip som mærkerne: de gemmes med et tidspunkt, netop så de
-- ikke forsvinder igen, hvis klubben ændrer en regel.
-- ============================================================================


-- ----------------------------------------------------------------- TABELLEN

create table if not exists public.maanedens_frivillige (
  -- Måneden er nøglen. Så kan der ikke vælges to i samme måned, og det er
  -- databasen der holder fast i det — ikke appen.
  maaned       date        primary key,
  user_id      uuid        references public.profiles(id) on delete set null,
  -- Navnet som det var den dag. Slettes medlemmet om to år, skal æreslisten
  -- ikke få et hul. Derfor et øjebliksbillede og ikke kun en henvisning.
  navn_dengang text        not null,
  begrundelse  text,
  valgt_af     uuid        references public.profiles(id) on delete set null,
  valgt_at     timestamptz not null default now()
);

do $$ begin
  alter table public.maanedens_frivillige
    add constraint maanedens_frivillige_foerste_i_maaneden
    check (maaned = date_trunc('month', maaned)::date);
exception when duplicate_object then null;
end $$;

comment on table public.maanedens_frivillige is
  'Hvem klubben har hædret, måned for måned. Skrives kun af admin_vaelg_maanedens(). Navnet gemmes med, så listen overlever et slettet medlem.';

alter table public.maanedens_frivillige enable row level security;

-- Alle medlemmer må se den. Det er en hædring — den skal kunne ses.
drop policy if exists maanedens_frivillige_select on public.maanedens_frivillige;
create policy maanedens_frivillige_select on public.maanedens_frivillige
  for select to authenticated
  using (true);

-- Ingen skriver direkte. Det gør funktionerne nedenfor.
revoke all on public.maanedens_frivillige from anon;
revoke insert, update, delete on public.maanedens_frivillige from authenticated;


-- --------------------------------------------------------------- KANDIDATERNE
--
-- Fire regler, og de kommer alle fra klubbens egne tal:
--
--   1. Kun tjanser, der er GJORT OP. En tilmelding er ikke en indsats. Samme
--      regel som mærkerne bruger.
--
--   2. Målt på hvornår arbejdet skete — tjansens dato, ikke hvornår en admin
--      fik den godkendt. Ellers afhænger hædringen af, hvor hurtige vi er til
--      at gøre op, og en decembervagt godkendt i januar tæller i den forkerte
--      måned.
--
--   3. SÆSONROLLER HOLDES UDE. Den vigtigste. I juni 2026 blev fem
--      bestyrelsesposter gjort op med 150 point hver; måler man måneden på
--      point, er juni-vinderen en post, der løber et halvt år, og som ikke
--      gjorde noget særligt i juni. I oktober ville en halvsæson-rolle på 60
--      point slå tre rigtige tjanser på 70. Sæsonrollerne har deres hædring:
--      de ligger øverst på sæsonranglisten hele året.
--
--   4. Æren følger DEN DER MØDTE OP — ikke den, pointene gik til. En hjælper
--      giver sine point videre til sit barn; måler man på point, er mødrene
--      usynlige, og det er lige netop dem, en hædring som denne er til for.
--      Derfor user_id og ikke credited_to.
--
-- Listen sorteres efter point, men det er en LISTE og ikke en rangering af,
-- hvem der fortjener det. Antallet af tjanser står ved siden af, fordi de to
-- ikke altid peger samme vej: to tjanser til 10 point er to gange at møde op.

create or replace function public.maanedens_kandidater(p_maaned date)
returns table (
  user_id      uuid,
  navn         text,
  team         text,
  tjanser      bigint,
  point        bigint,
  kun_hjaelper boolean,
  sidst_valgt  date
)
language sql
security definer
set search_path = public, pg_temp
as $$
  with gjort as (
    select tc.user_id as uid, tc.points_awarded as pt
      from public.task_claims tc
      join public.tasks t on t.id = tc.task_id
     where tc.status = 'completed'
       -- regel 3: kun det, der foregik på én bestemt dag
       and coalesce(t.duration_type, 'single') = 'single'
       -- date_full er tekst i databasen. En række med noget andet end en
       -- ISO-dato må ikke vælte hele listen.
       and t.date_full ~ '^\d{4}-\d{2}-\d{2}'
       and date_trunc('month', t.date_full::date) = date_trunc('month', p_maaned)
  )
  select p.id,
         p.name,
         coalesce(p.team, ''),
         count(*),
         coalesce(sum(g.pt), 0),
         public.kun_hjaelper(p.id),
         (select max(m.maaned) from public.maanedens_frivillige m where m.user_id = p.id)
    from gjort g
    join public.profiles p on p.id = g.uid
   group by p.id, p.name, p.team
   order by coalesce(sum(g.pt), 0) desc, count(*) desc, p.name;
$$;

comment on function public.maanedens_kandidater(date) is
  'Kandidater til månedens frivillige: bekræftede enkeltdags-tjanser i måneden, målt på den der mødte op. Sæsonroller holdes ude.';


-- ------------------------------------------------------------ MÅNEDSNAVNET
--
-- Beskeden og mailen skal sige "oktober", ikke "2026-10-01". Månedsnavnene
-- står i appen i forvejen, men databasen skriver sine egne beskeder og kan
-- ikke spørge browseren.

create or replace function public.dansk_maaned(p_dato date)
returns text
language sql
immutable
set search_path = public, pg_temp
as $$
  select (array['januar','februar','marts','april','maj','juni',
                'juli','august','september','oktober','november','december'])
           [extract(month from p_dato)::int]
         || ' ' || extract(year from p_dato)::text;
$$;


-- ------------------------------------------------------------------- VALGET

create or replace function public.admin_vaelg_maanedens(
  p_maaned      date,
  p_user        uuid,
  p_begrundelse text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_maaned date := date_trunc('month', p_maaned)::date;
  v_navn   text;
  v_maanednavn text;
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan vælge månedens frivillige';
  end if;

  -- En måned, der ikke er begyndt, kan ingen have fortjent noget i.
  if v_maaned > date_trunc('month', current_date)::date then
    raise exception 'Måneden er ikke begyndt endnu';
  end if;

  select name into v_navn from public.profiles where id = p_user;
  if v_navn is null then
    raise exception 'Medlemmet findes ikke';
  end if;

  insert into public.maanedens_frivillige (maaned, user_id, navn_dengang, begrundelse, valgt_af, valgt_at)
  values (v_maaned, p_user, v_navn, nullif(btrim(coalesce(p_begrundelse, '')), ''), auth.uid(), now())
  on conflict (maaned) do update
     set user_id      = excluded.user_id,
         navn_dengang = excluded.navn_dengang,
         begrundelse  = excluded.begrundelse,
         valgt_af     = excluded.valgt_af,
         valgt_at     = excluded.valgt_at;

  v_maanednavn := public.dansk_maaned(v_maaned);

  insert into public.audit_log (type, action, actor_name, actor_id)
  select 'member',
         format('Valgte %s som månedens frivillige for %s', v_navn, v_maanednavn),
         coalesce(p.name, 'Ukendt'), p.id
    from public.profiles p where p.id = auth.uid();

  -- Beskeden til den hædrede. Den udløser også mailen, fordi udbakken
  -- fyldes fra beskederne — så de to aldrig kan sige hver sit.
  --
  -- Vælger bestyrelsen om, får den nye besked. Den, der fik den første, kan
  -- vi ikke kalde tilbage; en mail er sendt, når den er sendt. Derfor skal
  -- der tænkes, FØR der trykkes, og det siger skærmen også.
  insert into public.notifications (user_id, type, title, body)
  values (p_user, 'maanedens_frivillige',
          'Du er månedens frivillige',
          'Klubben har valgt dig som månedens frivillige for ' || v_maanednavn || '. '
            || coalesce(nullif(btrim(coalesce(p_begrundelse, '')), '') || ' ', '')
            || 'Tak for det, du lægger i klubben.');
end;
$$;

comment on function public.admin_vaelg_maanedens(date, uuid, text) is
  'Hædrer et medlem for en måned. Gemmer valget, skriver i audit-loggen og giver personen besked og mail.';


create or replace function public.admin_fjern_maanedens(p_maaned date)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_maaned date := date_trunc('month', p_maaned)::date;
  v_navn   text;
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan fjerne månedens frivillige';
  end if;

  delete from public.maanedens_frivillige where maaned = v_maaned
  returning navn_dengang into v_navn;

  if v_navn is not null then
    insert into public.audit_log (type, action, actor_name, actor_id)
    select 'member',
           format('Fjernede %s som månedens frivillige for %s', v_navn, public.dansk_maaned(v_maaned)),
           coalesce(p.name, 'Ukendt'), p.id
      from public.profiles p where p.id = auth.uid();
  end if;
end;
$$;

comment on function public.admin_fjern_maanedens(date) is
  'Fortryder et valg. Beskeden og mailen kan ikke kaldes tilbage — kun hædringen i appen.';


-- -------------------------------------------------------------------- MAIL
--
-- Udbakken fyldes fra beskederne. Den nye slags skal med på listen, ellers
-- ligger hædringen kun inde i appen — og det er netop den besked, man gerne
-- vil have i indbakken.

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
  if new.type not in ('approved', 'task_assigned', 'task_changed', 'task_cancelled',
                      'maanedens_frivillige') then
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
  raise warning 'kunne ikke lægge mail i udbakken: %', sqlerrm;
  return new;
end;
$$;


-- -------------------------------------------------------------- PÅMINDELSEN
--
-- En hædring, der huskes i tre måneder og så glemmes, er værre end ingen
-- hædring — og det er sådan, den slags dør. Den 1. i måneden får
-- administratorerne en besked om at vælge for måneden, der lige er slut.
--
-- Den sendes kun, hvis der VAR noget at vælge imellem, og kun hvis der ikke
-- allerede er valgt. Ingen skal mindes om en tom måned.

create or replace function public.paamind_om_maanedens()
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_maaned date := (date_trunc('month', current_date) - interval '1 month')::date;
  v_kandidater int;
  v_antal int := 0;
begin
  if exists (select 1 from public.maanedens_frivillige where maaned = v_maaned) then
    return 0;
  end if;

  select count(*) into v_kandidater from public.maanedens_kandidater(v_maaned);
  if v_kandidater = 0 then
    return 0;
  end if;

  with nye as (
    insert into public.notifications (user_id, type, title, body)
    select p.id, 'maanedens_paamindelse',
           'Vælg månedens frivillige',
           public.dansk_maaned(v_maaned) || ' er slut. Der er '
             || v_kandidater || ' at vælge imellem under Admin → Oversigt.'
      from public.profiles p
     where p.role in ('admin', 'super_admin')
       -- Kører jobbet to gange, skal beskeden ikke komme to gange.
       and not exists (
         select 1 from public.notifications n
          where n.user_id = p.id
            and n.type = 'maanedens_paamindelse'
            and n.created_at > now() - interval '20 days'
       )
    returning 1
  )
  select count(*) into v_antal from nye;

  return v_antal;
end;
$$;

comment on function public.paamind_om_maanedens() is
  'Minder administratorerne om at vælge månedens frivillige for sidste måned. Kun hvis der var kandidater, og kun hvis der ikke allerede er valgt.';


-- ------------------------------------------------------------------- RETTER

revoke all on function public.maanedens_kandidater(date)                from public, anon;
revoke all on function public.admin_vaelg_maanedens(date, uuid, text)   from public, anon;
revoke all on function public.admin_fjern_maanedens(date)               from public, anon;
revoke all on function public.paamind_om_maanedens()                    from public, anon, authenticated;
revoke all on function public.queue_email_from_notification()           from public, anon, authenticated;
revoke all on function public.dansk_maaned(date)                        from public, anon;

grant execute on function public.maanedens_kandidater(date)              to authenticated;
grant execute on function public.admin_vaelg_maanedens(date, uuid, text) to authenticated;
grant execute on function public.admin_fjern_maanedens(date)             to authenticated;
grant execute on function public.dansk_maaned(date)                      to authenticated;


-- --------------------------------------------------------------------- CRON

do $outer$
begin
  create extension if not exists pg_cron;

  if exists (select 1 from cron.job where jobname = 'rvk_maanedens_paamindelse') then
    perform cron.unschedule('rvk_maanedens_paamindelse');
  end if;

  -- Den 1. kl. 07:07 UTC. Ikke på et rundt minut: de fleste job ligger på
  -- hele og halve timer, og der er ingen grund til at stå i kø med dem.
  perform cron.schedule('rvk_maanedens_paamindelse', '7 7 1 * *',
    $job$ select public.paamind_om_maanedens(); $job$);

  raise notice 'pg_cron: rvk_maanedens_paamindelse den 1. kl. 07:07 UTC';
exception when others then
  raise notice 'pg_cron ikke tilgaengelig (%). Påmindelsen skal så sættes i gang i hånden.', sqlerrm;
end
$outer$;
