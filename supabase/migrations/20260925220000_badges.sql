-- ============================================================================
-- MÆRKER (BADGES)
--
-- Appen havde seks mærker, regnet ud i browseren af to tal: point og antal
-- tjanser. De var alle sammen synlige, de ulåste bare nedtonet.
--
-- Her kommer tredive til, som er SKJULTE, til de bliver fundet. Et mål virker
-- kun, hvis man kan se det; en opdagelse virker kun, hvis man ikke kan. De
-- seks bliver, hvor de er, som mål — de tredive lægger sig ovenpå.
--
-- To ting er vigtige:
--
--   1. Kun BEKRÆFTEDE tjanser tæller. Ellers kunne et mærke samles ved at
--      melde sig til alt og ikke møde op, og så er det ingenting værd.
--
--   2. Et fundet mærke GEMMES med et tidspunkt. Så forsvinder det ikke igen,
--      hvis klubben senere ændrer en regel eller nulstiller sæsonen — og
--      appen kan sige "nyt mærke" præcis én gang.
-- ============================================================================

create table if not exists public.member_badges (
  user_id   uuid        not null references public.profiles(id) on delete cascade,
  badge_id  text        not null,
  earned_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);

comment on table public.member_badges is
  'Fundne mærker. Skrives kun af my_badges(); teksterne til dem står i appen.';

create index if not exists member_badges_user_idx on public.member_badges (user_id);

alter table public.member_badges enable row level security;

-- Man ser sine egne. Ingen skriver direkte — det gør funktionen nedenfor.
drop policy if exists member_badges_select_own on public.member_badges;
create policy member_badges_select_own on public.member_badges
  for select to authenticated
  using (user_id = auth.uid());

revoke all on public.member_badges from public, anon;
grant select on public.member_badges to authenticated;


-- ============================================================================
-- my_badges() — regner mærkerne ud, gemmer de nye, og giver dem alle tilbage
--
-- Regnestykket ligger her og ikke i browseren, af samme grund som pointene:
-- dér kan det ikke regnes forkert, og det kan ikke læses af andre.
-- ============================================================================

create or replace function public.my_badges()
returns table (badge_id text, earned_at timestamptz, er_ny boolean)
language plpgsql
security definer
set search_path = public
as $$
-- Funktionen giver en kolonne, der hedder badge_id, tilbage — og tabellen har
-- en kolonne af samme navn. Uden den her linje ved Postgres ikke, hvad
-- "on conflict (user_id, badge_id)" peger på, og nægter at oprette funktionen.
#variable_conflict use_column
declare
  v_uid  uuid := auth.uid();
  v_goal int;
begin
  if v_uid is null then
    raise exception 'my_badges(): ingen session';
  end if;

  select coalesce(nullif(value, '')::int, 100) into v_goal
  from public.settings where key = 'point_goal';
  v_goal := coalesce(v_goal, 100);

  return query
  with mine as (
    -- Kun bekræftede tjanser. Datoen læses kun, når den er en rigtig ISO-dato;
    -- ældre opgaver med dansk datotekst tæller ikke med i de datobaserede.
    select tc.claimed_at,
           tc.confirmed_at,
           tc.points_awarded,
           tc.task_id,
           t.category,
           t.difficulty,
           t.urgent,
           t.duration_type,
           t.created_at as opgave_oprettet,
           case when t.date_full ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
                then t.date_full::date end as dag
    from public.task_claims tc
    join public.tasks t on t.id = tc.task_id
    where tc.user_id = v_uid and tc.status = 'completed'
  ),
  uger as (
    select distinct date_trunc('week', dag)::date as u from mine where dag is not null
  ),
  stimer as (
    select u, (u - (row_number() over (order by u) * interval '7 day'))::date as g from uger
  ),
  stime as (
    select coalesce(max(antal), 0) as uger_i_traek
    from (select count(*) as antal from stimer group by g) s
  ),
  raekker as (
    -- Pladsens nummer på opgaven, og om det var den første, der meldte sig.
    select tc.user_id, tc.task_id, tc.claimed_at, t.spots_total, t.created_at as opgave_oprettet,
           row_number() over (partition by tc.task_id order by tc.claimed_at) as nr
    from public.task_claims tc
    join public.tasks t on t.id = tc.task_id
  ),
  saesoner as (
    select count(distinct season_label) as tidligere
    from public.season_results where user_id = v_uid
  ),
  tal as (
    select
      (select count(*) from mine)                                              as antal,
      (select count(distinct category) from mine)                              as kategorier,
      (select count(*) from mine where category ilike 'Kampafvikling%')        as kat_kamp,
      (select count(*) from mine where category ilike 'Hygge%')                as kat_hygge,
      (select count(*) from mine where category ilike 'Holdleder%')            as kat_transport,
      (select count(*) from mine where category ilike 'Stævne%')               as kat_staevne,
      (select count(*) from mine where category ilike 'Faciliteter%')          as kat_fac,
      (select count(*) from mine where category ilike 'Kommunikation%')        as kat_komm,
      (select count(distinct date_trunc('month', dag)) from mine
        where dag is not null)                                                 as maaneder,
      (select uger_i_traek from stime)                                         as uger_i_traek,
      (select count(*) from mine where dag is not null
        and extract(isodow from dag) in (6, 7))                                as weekend,
      (select exists (select 1 from mine where dag is not null
        group by dag having count(*) > 1))                                     as dobbeltdag,
      (select count(*) from mine where difficulty = 'Hård')                    as haarde,
      (select exists (select 1 from mine
        where duration_type in ('year', 'half_season')))                       as saesonrolle,
      (select exists (select 1 from mine where duration_type = 'month'))       as maanedsopgave,
      (select count(*) from mine where urgent)                                 as hastende,
      (select exists (select 1 from mine
        where claimed_at - opgave_oprettet <= interval '1 hour'))              as foerst_paa_pletten,
      (select exists (select 1 from mine where dag is not null
        and claimed_at >= (dag - 1)::timestamptz
        and claimed_at::date <= dag))                                          as sidste_udkald,
      (select exists (select 1 from raekker r join mine m on m.task_id = r.task_id
        where r.user_id = v_uid and r.spots_total > 0 and r.nr = r.spots_total)) as redningsmand,
      (select exists (select 1 from raekker r join mine m on m.task_id = r.task_id
        where r.user_id = v_uid and r.nr = 1
          and r.claimed_at - r.opgave_oprettet >= interval '14 days'))         as overset,
      (select count(*) from public.swap_offers
        where status = 'accepted'
          and (from_user_id = v_uid or accepted_by = v_uid))                   as bytter,
      (select count(distinct o.user_id) from public.task_claims o
        join mine m on m.task_id = o.task_id where o.user_id <> v_uid)         as nye_ansigter,
      (select coalesce(max(sum_pt), 0) >= v_goal from (
         select sum(points_awarded) as sum_pt from mine
         where confirmed_at is not null
           and extract(month from confirmed_at) between 8 and 11
         group by extract(year from confirmed_at)) s)                          as tidligt_i_maal,
      ((select tidligere from saesoner)
        + (select case when count(*) > 0 then 1 else 0 end from mine))         as saesoner,
      (select coalesce(points, 0) from public.profiles where id = v_uid)       as point
  ),
  regler as (
    select v.id, v.opnaaet from tal, lateral (values
      -- Vedholdenhed
      ('kom_godt_igang',  tal.antal >= 3),
      ('arbejdshesten',   tal.antal >= 10),
      ('rygraden',        tal.antal >= 20),
      ('uundvaerlig',     tal.antal >= 35),
      ('stimen',          tal.uger_i_traek >= 4),
      ('trofast',         tal.maaneder >= 3),
      -- Bredde
      ('alsidig',         tal.kategorier >= 3),
      ('altmuligmand',    tal.kategorier >= 5),
      ('hele_klubben',    tal.kategorier >= 7),
      ('dommerbordet',    tal.kat_kamp >= 3),
      ('kiosken',         tal.kat_hygge >= 3),
      ('chaufføren',      tal.kat_transport >= 3),
      ('staevneholdet',   tal.kat_staevne >= 3),
      ('pedellen',        tal.kat_fac >= 3),
      ('klubbens_stemme', tal.kat_komm >= 3),
      -- Timing
      ('foerst_paa_pletten', tal.foerst_paa_pletten),
      ('sidste_udkald',   tal.sidste_udkald),
      ('redningsmanden',  tal.redningsmand),
      ('den_oversete',    tal.overset),
      ('dobbeltdag',      tal.dobbeltdag),
      ('weekendkrigeren', tal.weekend >= 5),
      -- Omfang og sværhed
      ('modig',           tal.haarde >= 1),
      ('jernvilje',       tal.haarde >= 3),
      ('den_lange_bane',  tal.saesonrolle),
      ('maaneden_ud',     tal.maanedsopgave),
      ('brandslukkeren',  tal.hastende >= 3),
      -- Fællesskab og sæson
      ('byttecentralen',  tal.bytter >= 3),
      ('nye_ansigter',    tal.nye_ansigter >= 10),
      ('tidligt_i_maal',  tal.tidligt_i_maal),
      ('saeson_to',       tal.saesoner >= 2)
    ) as v(id, opnaaet)
  ),
  gamle as (
    -- Læses FØR indsættelsen nedenfor. En sætning ser tabellen, som den så ud,
    -- da sætningen begyndte, så de nye rækker er ikke med her — og det er
    -- netop dét, der gør forskellen på "fundet nu" og "fundet før".
    select mb.badge_id, mb.earned_at from public.member_badges mb where mb.user_id = v_uid
  ),
  nye as (
    insert into public.member_badges (user_id, badge_id)
    select v_uid, r.id from regler r where r.opnaaet
    on conflict (user_id, badge_id) do nothing
    returning member_badges.badge_id, member_badges.earned_at
  )
  select g.badge_id, g.earned_at, false from gamle g
  union all
  select n.badge_id, n.earned_at, true  from nye n
  order by 2, 1;
end;
$$;

comment on function public.my_badges() is
  'Regner medlemmets mærker ud, gemmer de nye, og giver dem alle tilbage. er_ny er sand netop den gang, mærket blev fundet.';

revoke all on function public.my_badges() from public, anon;
grant execute on function public.my_badges() to authenticated;
