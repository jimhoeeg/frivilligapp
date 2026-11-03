-- ============================================================================
-- RVK Frivillig – alle migrationer samlet i én fil
--
-- Genereret fra supabase/migrations/. Indholdet er præcis det samme, blot
-- sat efter hinanden i kørselsrækkefølge, så det kan indsættes på én gang.
--
-- SÅDAN:
--   Supabase Dashboard → SQL Editor → New query → indsæt HELE filen → Run.
--
-- Filen kan køres flere gange uden at gøre skade. Fejler noget undervejs,
-- ruller Supabase det hele tilbage, og fejlbeskeden peger på det afsnit,
-- der gik galt — afsnittene er markeret tydeligt nedenfor.
--
-- To ting den gør, som du skal vide FØR du trykker Run:
--
--   1. Den genberegner alle point fra bunden. Bonuspoint, der er givet i
--      hånden, går tabt i den proces.
--   2. Point gives fremover først, når en tjans er bekræftet som gennemført.
--      Alle eksisterende tilmeldinger står derfor som "afventer bekræftelse",
--      indtil en admin gør dem op under Admin → Bekræft. Vil du i stedet
--      godkende hele historikken på én gang, står linjen til det i bunden
--      af afsnit 3.
--
-- Bagefter: kør supabase/seed.sql (ret holdene først), og rul
-- sletningsfunktionen ud med: supabase functions deploy delete-member
-- ============================================================================




-- ############################################################################
-- ## AFSNIT 1 af 21: 20260101000000_baseline.sql
-- ############################################################################

-- ============================================================================
-- RVK Frivillig – grundskema
--
-- Dette er udgangspunktet: tabeller, kolonner og indekser. Intet andet.
--
-- Der er med vilje INGEN politikker, funktioner eller triggere her. De kommer
-- fra migrationerne efter denne. Grunden er, at de gamle løse SQL-filer i
-- supabase/legacy/ blandede skema og adgangsregler sammen — og den blanding
-- betød, at en genkørsel af "opsætningsfilen" gendannede politikken
-- "profiles ... for select using (true)", altså den der gjorde hele
-- medlemslisten læsbar uden login. Den slags må ikke kunne ske ved et uheld.
--
-- Rækkefølgen er derfor: dette skema først, derefter migrationerne i
-- navnerækkefølge. Kører man KUN denne fil, er databasen låst (RLS slået til
-- uden politikker) — ubrugelig, men sikker. Det er den rigtige vej at fejle.
--
-- Filen kan køres flere gange uden at gøre skade.
-- ============================================================================


-- ============================================================================
-- MEDLEMMER
-- ============================================================================

create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  name         text not null,
  initials     text generated always as (
                 upper(left(split_part(name, ' ', 1), 1) || left(split_part(name, ' ', 2), 1))
               ) stored,
  email        text,
  phone        text,
  team         text,
  role         text not null default 'user' check (role in ('user', 'admin', 'super_admin')),
  points       int  not null default 0,
  tasks_done   int  not null default 0,
  member_since text default to_char(now(), 'Month YYYY'),
  created_at   timestamptz default now()
);


-- ============================================================================
-- HOLD
-- ============================================================================

create table if not exists public.teams (
  id         uuid primary key default gen_random_uuid(),
  name       text unique not null,
  created_at timestamptz default now()
);


-- ============================================================================
-- OPGAVER
-- ============================================================================

create table if not exists public.tasks (
  id            uuid primary key default gen_random_uuid(),
  title         text not null,
  category      text not null,
  icon          text not null default 'setup',
  date          text not null,
  date_full     text,
  date_end      text,
  duration_type text default 'single',
  time          text not null,
  location      text not null,
  points        int  not null default 10,
  difficulty    text not null default 'Let' check (difficulty in ('Let', 'Medium', 'Hård')),
  urgent        boolean not null default false,
  spots_total   int not null default 2,
  spots_left    int not null default 2,
  created_by    uuid references public.profiles(id),
  created_at    timestamptz default now()
);

create table if not exists public.task_steps (
  id         uuid primary key default gen_random_uuid(),
  task_id    uuid references public.tasks(id) on delete cascade,
  step_order int  not null,
  text       text not null
);


-- ============================================================================
-- TILMELDINGER
-- ============================================================================

create table if not exists public.task_claims (
  id         uuid primary key default gen_random_uuid(),
  task_id    uuid references public.tasks(id) on delete cascade,
  user_id    uuid references public.profiles(id) on delete cascade,
  claimed_at timestamptz default now(),
  unique (task_id, user_id)
);


-- ============================================================================
-- BYTTE
-- ============================================================================

create table if not exists public.swap_offers (
  id               uuid primary key default gen_random_uuid(),
  from_user_id     uuid references public.profiles(id) on delete cascade,
  offering_task_id uuid references public.tasks(id) on delete cascade,
  wants_task_id    uuid references public.tasks(id),
  message          text,
  status           text not null default 'available'
                     check (status in ('available', 'incoming', 'outgoing', 'accepted', 'declined')),
  created_at       timestamptz default now()
);


-- ============================================================================
-- BESKEDER
-- ============================================================================

create table if not exists public.notifications (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid references public.profiles(id) on delete cascade,
  type           text not null,
  title          text not null,
  body           text,
  read           boolean not null default false,
  action_task_id uuid references public.tasks(id) on delete set null,
  created_at     timestamptz default now()
);


-- ============================================================================
-- LOG OG INDSTILLINGER
-- ============================================================================

create table if not exists public.audit_log (
  id         uuid primary key default gen_random_uuid(),
  type       text not null,
  action     text not null,
  actor_id   uuid references public.profiles(id) on delete set null,
  actor_name text,
  created_at timestamptz default now()
);

create table if not exists public.settings (
  key        text primary key,
  value      text not null,
  updated_at timestamptz default now()
);


-- ============================================================================
-- RLS SLÅS TIL PÅ ALT
--
-- Uden politikker betyder det "ingen adgang". Politikkerne kommer i
-- 20260910120000_launch_hardening.sql og senere.
-- ============================================================================

alter table public.profiles      enable row level security;
alter table public.teams         enable row level security;
alter table public.tasks         enable row level security;
alter table public.task_steps    enable row level security;
alter table public.task_claims   enable row level security;
alter table public.swap_offers   enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_log     enable row level security;
alter table public.settings      enable row level security;


-- ============================================================================
-- INDEKSER
-- ============================================================================

create index if not exists task_claims_user_id_idx     on public.task_claims (user_id);
create index if not exists task_claims_task_id_idx     on public.task_claims (task_id);
create index if not exists task_steps_task_id_idx      on public.task_steps (task_id);
create index if not exists notifications_user_read_idx on public.notifications (user_id, created_at desc);
create index if not exists swap_offers_status_idx      on public.swap_offers (status);
create index if not exists audit_log_created_idx       on public.audit_log (created_at desc);


-- ============================================================================
-- FILER: bucket til profilbilleder
--
-- Politikkerne på bucket'en sættes i migrationerne. Springes over, hvis
-- storage-udvidelsen ikke er slået til (fx i en lokal testdatabase).
-- ============================================================================

do $$ begin
  insert into storage.buckets (id, name, public)
  values ('avatars', 'avatars', true)
  on conflict (id) do nothing;
exception when others then
  raise notice 'storage ikke tilgængelig (%) – springer avatars-bucket over.', sqlerrm;
end $$;



-- ############################################################################
-- ## AFSNIT 2 af 21: 20260910120000_launch_hardening.sql
-- ############################################################################

-- ============================================================================
-- RVK Frivillig – lanceringsklargøring
--
-- Denne fil samler rettelserne til punkt 1–10 i lanceringstjekket og er
-- skrevet, så den kan køres flere gange uden at gøre skade (idempotent).
--
-- Kør den i Supabase Dashboard → SQL Editor → Run.
-- Kør den ÉN GANG, og læs afsnit 3 igennem først – der er ét valg at træffe.
--
-- Rækkefølgen i filen er bevidst:
--   1. Adgang til medlemsdata (GDPR)
--   2. Godkendelse af nye medlemmer
--   3. Pointregnskabet – ét sted, én sandhed
--   4. Tilmeldinger: pladskontrol og kapløb
--   5. Bytte af tjanser
--   6. Notifikationer
--   7. Oprydning i gamle politikker
-- ============================================================================


-- ============================================================================
-- 0. HJÆLPEFUNKTION
-- ============================================================================

-- Henter den aktuelle brugers rolle uden at udløse rekursion i RLS-politikker.
create or replace function public.get_my_role()
returns text
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select role from public.profiles where id = auth.uid();
$$;

grant execute on function public.get_my_role() to authenticated;


-- Alle nye kolonner oprettes samlet her, så rettighederne længere nede
-- kan nå at omfatte dem.
alter table public.profiles
  add column if not exists approved     boolean not null default false,
  add column if not exists reviewed_at  timestamptz,
  add column if not exists reviewed_by  uuid references public.profiles(id) on delete set null,
  add column if not exists bonus_points int not null default 0,
  add column if not exists avatar_url   text,
  add column if not exists admin_requested    boolean not null default false,
  add column if not exists admin_requested_at timestamptz;

alter table public.task_claims
  add column if not exists points_awarded int;

alter table public.swap_offers
  add column if not exists accepted_by uuid references public.profiles(id) on delete set null,
  add column if not exists accepted_at timestamptz;


-- ============================================================================
-- 1. ADGANG TIL MEDLEMSDATA  (punkt 1)
--
-- Før: "profiles_select ... using (true)" betød, at hvem som helst kunne hente
-- hele medlemslisten ud – inklusive e-mail og telefon – uden at være logget
-- ind, fordi den offentlige nøgle ligger i appens JavaScript.
--
-- Efter: kun indloggede brugere kan læse medlemmer, og e-mail/telefon er
-- helt utilgængelige via tabellen. De hentes i stedet gennem funktioner,
-- der selv kontrollerer, hvem der spørger.
-- ============================================================================

drop policy if exists "profiles_select"               on public.profiles;
drop policy if exists "profiles_select_authenticated" on public.profiles;
drop policy if exists "Public profiles are viewable by everyone." on public.profiles;

create policy "profiles_select_authenticated"
  on public.profiles for select
  using (auth.uid() is not null);

-- Anonyme klienter har intet at gøre i medlemstabellen overhovedet.
revoke select on public.profiles from anon;

-- Kolonne-niveau: ingen almindelig klient må læse kontaktoplysninger direkte.
-- Bemærk: en tabel-bred SELECT-rettighed dækker ALLE kolonner, så den skal
-- trækkes tilbage først – ellers har det ingen effekt at fjerne enkeltkolonner.
revoke select on public.profiles from authenticated;

grant select (
  id, name, initials, team, role, points, bonus_points, tasks_done,
  member_since, created_at, avatar_url, approved, reviewed_at, reviewed_by,
  admin_requested, admin_requested_at
) on public.profiles to authenticated;


-- Egen profil – erstatter "select * from profiles where id = auth.uid()".
create or replace function public.my_profile()
returns public.profiles
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select * from public.profiles where id = auth.uid();
$$;

grant execute on function public.my_profile() to authenticated;


-- ----------------------------------------------------------------------------
-- Rettighedseskalering: et medlem må kun rette sine EGNE oplysninger,
-- ikke sin rolle, sine point eller sin godkendelse.
--
-- Politikken "profiles_update_own" tillader opdatering af egen række – men
-- RLS arbejder på rækker, ikke kolonner, så den gav i praksis ethvert medlem
-- lov til at sætte sin egen role = 'super_admin' eller points = 99999.
-- Det lukkes med kolonnerettigheder; alt andet går gennem funktioner,
-- der selv tjekker, hvem der kalder.
-- ----------------------------------------------------------------------------

revoke update on public.profiles from anon, authenticated;

grant update (name, phone, team, avatar_url) on public.profiles to authenticated;

-- Genopbyg opdateringspolitikkerne, så de er de samme uanset hvilke af de
-- gamle løse SQL-filer, der tidligere er kørt på databasen.
drop policy if exists "profiles_update"            on public.profiles;
drop policy if exists "profiles_update_own"        on public.profiles;
drop policy if exists "profiles_admin_update"      on public.profiles;
drop policy if exists "admins_update_any_profile"  on public.profiles;
drop policy if exists "Users can update own profile." on public.profiles;

create policy "profiles_update_own" on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid());

-- Admins kan rette andres navn/hold (fx når et hold omdøbes). Rolle, point
-- og godkendelse er ikke længere mulige herfra – de går gennem funktionerne.
create policy "admins_update_any_profile" on public.profiles for update
  using (public.get_my_role() in ('admin', 'super_admin'));


create or replace function public.admin_set_role(p_user uuid, p_role text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor_role text := public.get_my_role();
begin
  if v_actor_role <> 'super_admin' then
    raise exception 'Kun en super admin kan ændre roller';
  end if;

  if p_role not in ('user', 'admin', 'super_admin') then
    raise exception 'Ukendt rolle: %', p_role;
  end if;

  if p_user = auth.uid() and p_role <> 'super_admin' then
    raise exception 'Du kan ikke fjerne din egen super admin-rolle';
  end if;

  -- Der skal altid være mindst én super admin tilbage.
  if p_role <> 'super_admin'
     and (select role from public.profiles where id = p_user) = 'super_admin'
     and (select count(*) from public.profiles where role = 'super_admin') <= 1 then
    raise exception 'Klubben skal have mindst én super admin';
  end if;

  update public.profiles
     set role            = p_role,
         admin_requested = false
   where id = p_user;

  insert into public.notifications (user_id, type, title, body)
  values (p_user, 'role_changed', 'Din rolle er ændret',
          case p_role
            when 'super_admin' then 'Du er nu super admin i RVK Frivillig.'
            when 'admin'       then 'Du er nu administrator og kan oprette opgaver.'
            else 'Du er nu almindeligt medlem.'
          end);
end;
$$;

grant execute on function public.admin_set_role(uuid, text) to authenticated;


-- Medlemmet beder selv om admin-adgang.
create or replace function public.request_admin_access()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'Du skal være logget ind';
  end if;

  update public.profiles
     set admin_requested    = true,
         admin_requested_at = now()
   where id = auth.uid()
     and role = 'user';
end;
$$;

grant execute on function public.request_admin_access() to authenticated;


create or replace function public.admin_dismiss_request(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public.get_my_role() <> 'super_admin' then
    raise exception 'Kun en super admin kan afvise anmodninger';
  end if;

  update public.profiles set admin_requested = false where id = p_user;
end;
$$;

grant execute on function public.admin_dismiss_request(uuid) to authenticated;


-- Medlemsliste med kontaktoplysninger – kun for admins.
create or replace function public.admin_list_members()
returns table (
  id                 uuid,
  name               text,
  initials           text,
  email              text,
  phone              text,
  team               text,
  role               text,
  points             int,
  tasks_done         int,
  approved           boolean,
  reviewed_at        timestamptz,
  admin_requested    boolean,
  admin_requested_at timestamptz,
  created_at         timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan se medlemmernes kontaktoplysninger';
  end if;

  return query
    select p.id, p.name, p.initials, p.email, p.phone, p.team, p.role,
           p.points, p.tasks_done, p.approved, p.reviewed_at,
           p.admin_requested, p.admin_requested_at, p.created_at
    from public.profiles p
    order by p.points desc, p.name;
end;
$$;

grant execute on function public.admin_list_members() to authenticated;


-- ============================================================================
-- 2. GODKENDELSE AF NYE MEDLEMMER  (punkt 10b)
--
-- Nye brugere kan oprette sig og logge ind, men kan ikke tage opgaver,
-- før en admin har godkendt dem.
-- ============================================================================

-- Alle, der allerede er i systemet, er godkendte. Ellers ville de blive
-- låst ude i det øjeblik denne fil køres.
update public.profiles
   set approved    = true,
       reviewed_at = coalesce(reviewed_at, now())
 where approved = false
   and created_at < now();

-- Admins må godkende. Det skal stå før RLS-reglerne på task_claims bruger det.
create or replace function public.is_approved(p_user uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce((select approved from public.profiles where id = p_user), false);
$$;

grant execute on function public.is_approved(uuid) to authenticated;


create or replace function public.admin_set_approval(p_user uuid, p_approved boolean)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan godkende medlemmer';
  end if;

  update public.profiles
     set approved    = p_approved,
         reviewed_at = now(),
         reviewed_by = auth.uid()
   where id = p_user;
end;
$$;

grant execute on function public.admin_set_approval(uuid, boolean) to authenticated;


-- Nye brugere oprettes som ikke-godkendte.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_is_bootstrap boolean;
begin
  v_is_bootstrap := new.email in ('formand@randersVK.dk', 'admin@randersVK.dk');

  insert into public.profiles (id, name, email, phone, team, role, approved, reviewed_at)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.email,
    nullif(new.raw_user_meta_data->>'phone', ''),
    coalesce(new.raw_user_meta_data->>'team', ''),
    case when v_is_bootstrap then 'super_admin' else 'user' end,
    v_is_bootstrap,
    case when v_is_bootstrap then now() else null end
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


-- ============================================================================
-- 3. POINTREGNSKABET  (punkt 2 og 3)
--
-- Før blev point lagt til tre forskellige steder: en databasetrigger,
-- admin-panelets egen kode, og dashboardets sammenlægning i browseren.
-- Derfor viste to skærme forskellige tal for den samme frivillige.
--
-- Efter: point beregnes KUN her i databasen.
--   profiles.points = summen af point fra egne tilmeldinger + bonus_points
--
-- Hver tilmelding husker selv, hvor mange point den gav (points_awarded).
-- Det gør regnskabet robust: ændrer en admin senere pointtallet på en opgave,
-- beholder de allerede tilmeldte det, de fik lovet.
-- ============================================================================

-- Historiske tilmeldinger får det pointtal, deres opgave har i dag.
update public.task_claims tc
   set points_awarded = t.points
  from public.tasks t
 where t.id = tc.task_id
   and tc.points_awarded is null;


-- --- Tilmelding oprettes -----------------------------------------------------
-- Låser opgaverækken, så to personer ikke kan tage den sidste plads samtidig,
-- og afviser tilmelding til en fuld opgave. (punkt 6)

create or replace function public.tc_before_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  t record;
begin
  select points, spots_left into t
    from public.tasks
   where id = new.task_id
   for update;

  if not found then
    raise exception 'Opgaven findes ikke længere';
  end if;

  if t.spots_left <= 0 then
    raise exception 'Opgaven er allerede fuldt besat';
  end if;

  if not public.is_approved(new.user_id) then
    raise exception 'Medlemmet er ikke godkendt endnu';
  end if;

  new.points_awarded := t.points;
  return new;
end;
$$;

drop trigger if exists tc_before_insert on public.task_claims;
create trigger tc_before_insert
  before insert on public.task_claims
  for each row execute procedure public.tc_before_insert();


create or replace function public.tc_after_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.tasks
     set spots_left = spots_left - 1
   where id = new.task_id
     and spots_left > 0;

  update public.profiles
     set points     = points + coalesce(new.points_awarded, 0),
         tasks_done = tasks_done + 1
   where id = new.user_id;

  -- Blev tilmeldingen lavet af en anden end medlemmet selv, er det en admin
  -- der har tildelt opgaven. Så skal medlemmet have besked. (punkt 10a)
  if auth.uid() is distinct from new.user_id
     and coalesce(current_setting('app.in_swap', true), '') <> 'on' then
    insert into public.notifications (user_id, type, title, body, action_task_id)
    select new.user_id, 'task_assigned',
           'Du er tildelt en opgave',
           t.title || ' · ' || t.date || coalesce(' · ' || nullif(t.time, ''), ''),
           t.id
      from public.tasks t where t.id = new.task_id;
  end if;

  return new;
end;
$$;

drop trigger if exists on_task_claimed on public.task_claims;
drop trigger if exists tc_after_insert on public.task_claims;
create trigger tc_after_insert
  after insert on public.task_claims
  for each row execute procedure public.tc_after_insert();


-- --- Tilmelding fjernes ------------------------------------------------------
-- Bruger points_awarded fra rækken selv, så det virker også når opgaven
-- slettes og tilmeldingerne ryger med i samme ombæring.

create or replace function public.tc_after_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.tasks
     set spots_left = least(spots_left + 1, spots_total)
   where id = old.task_id;

  update public.profiles
     set points     = greatest(0, points - coalesce(old.points_awarded, 0)),
         tasks_done = greatest(0, tasks_done - 1)
   where id = old.user_id;

  if auth.uid() is distinct from old.user_id
     and coalesce(current_setting('app.in_swap', true), '') <> 'on' then
    insert into public.notifications (user_id, type, title, body, action_task_id)
    select old.user_id, 'task_unassigned',
           'Du er fjernet fra en opgave',
           t.title || ' · ' || t.date,
           t.id
      from public.tasks t where t.id = old.task_id;
  end if;

  return old;
end;
$$;

drop trigger if exists tc_after_delete on public.task_claims;
create trigger tc_after_delete
  after delete on public.task_claims
  for each row execute procedure public.tc_after_delete();


-- --- Bonuspoint fra admin ----------------------------------------------------
-- Holdes adskilt fra tilmeldingspoint, så regnskabet kan genberegnes
-- uden at bonusser går tabt.

create or replace function public.admin_adjust_points(p_user uuid, p_delta int)
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_new_bonus int;
  v_total     int;
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan regulere point';
  end if;

  update public.profiles
     set bonus_points = bonus_points + p_delta,
         points       = greatest(0, points + p_delta)
   where id = p_user
  returning bonus_points, points into v_new_bonus, v_total;

  if not found then
    raise exception 'Medlemmet findes ikke';
  end if;

  insert into public.notifications (user_id, type, title, body)
  values (
    p_user, 'points_adjusted',
    case when p_delta >= 0 then 'Du har fået bonuspoint' else 'Dine point er reguleret' end,
    case when p_delta >= 0
         then 'En administrator har tildelt dig ' || p_delta || ' point.'
         else 'En administrator har fratrukket ' || abs(p_delta) || ' point.' end
  );

  return v_total;
end;
$$;

grant execute on function public.admin_adjust_points(uuid, int) to authenticated;


-- --- ENGANGS-GENBEREGNING ----------------------------------------------------
--
--   LÆS DETTE FØR DU KØRER FILEN.
--
-- Pointtallene i databasen kan være skæve i dag, fordi de blev talt op
-- flere steder. Linjerne herunder nulstiller regnskabet og bygger det op
-- igen fra de faktiske tilmeldinger.
--
-- Konsekvens: bonuspoint, der er givet manuelt FØR denne fil køres, kan
-- ikke skelnes fra fejltællinger og går derfor tabt. Er appen ikke lanceret
-- endnu, er det præcis det, du vil. Har I allerede uddelt bonuspoint, I vil
-- beholde, så udfyld bonus_points manuelt bagefter i admin-panelet.

update public.profiles p
   set points     = greatest(0, coalesce(c.pts, 0) + p.bonus_points),
       tasks_done = coalesce(c.cnt, 0)
  from (
        select user_id,
               sum(coalesce(points_awarded, 0))::int as pts,
               count(*)::int                          as cnt
          from public.task_claims
         group by user_id
       ) c
 where c.user_id = p.id;

update public.profiles p
   set points     = greatest(0, p.bonus_points),
       tasks_done = 0
 where not exists (select 1 from public.task_claims tc where tc.user_id = p.id);

-- Ledige pladser rettes tilsvarende op efter det faktiske antal tilmeldte.
update public.tasks t
   set spots_left = greatest(0, t.spots_total - coalesce(c.cnt, 0))
  from (
        select task_id, count(*)::int as cnt
          from public.task_claims
         group by task_id
       ) c
 where c.task_id = t.id;

update public.tasks t
   set spots_left = t.spots_total
 where not exists (select 1 from public.task_claims tc where tc.task_id = t.id);


-- ============================================================================
-- 4. TILMELDINGER – RETTIGHEDER  (punkt 6 og 10b)
-- ============================================================================

alter table public.task_claims enable row level security;

drop policy if exists "claims_select"       on public.task_claims;
drop policy if exists "claims_insert"       on public.task_claims;
drop policy if exists "claims_delete"       on public.task_claims;
drop policy if exists "claims_select_own"   on public.task_claims;
drop policy if exists "claims_insert_own"   on public.task_claims;
drop policy if exists "claims_delete_own"   on public.task_claims;
drop policy if exists "admins_select_claims" on public.task_claims;
drop policy if exists "admins_manage_claims" on public.task_claims;
drop policy if exists "admins_delete_claims" on public.task_claims;
drop policy if exists "claims_insert_admin"  on public.task_claims;
drop policy if exists "claims_delete_admin"  on public.task_claims;

-- Alle indloggede kan se, hvem der står på hvad. Det er meningen med
-- en frivilligtavle – og scoreboardet bygger på det.
create policy "claims_select" on public.task_claims for select
  using (auth.uid() is not null);

-- Man kan kun melde sig selv til, og kun hvis man er godkendt.
create policy "claims_insert_own" on public.task_claims for insert
  with check (user_id = auth.uid() and public.is_approved(auth.uid()));

create policy "claims_delete_own" on public.task_claims for delete
  using (user_id = auth.uid());

-- Admins kan tildele og fjerne på alles vegne.
create policy "claims_insert_admin" on public.task_claims for insert
  with check (public.get_my_role() in ('admin', 'super_admin'));

create policy "claims_delete_admin" on public.task_claims for delete
  using (public.get_my_role() in ('admin', 'super_admin'));


-- ============================================================================
-- 5. BYTTE AF TJANSER  (punkt 5)
--
-- Før: den, der overtog, blev tilmeldt, men den oprindelige tilmelding blev
-- aldrig fjernet – begge stod på opgaven – og pointene fulgte ikke med.
-- Statusopdateringen blev desuden blokeret af RLS, så tilbuddet hang fast.
--
-- Efter: hele byttet sker i én funktion, der enten gennemfører det hele
-- eller ingenting.
-- ============================================================================

drop policy if exists "swaps_select" on public.swap_offers;
drop policy if exists "swaps_insert" on public.swap_offers;
drop policy if exists "swaps_update" on public.swap_offers;
drop policy if exists "swaps_update_own" on public.swap_offers;

create policy "swaps_select" on public.swap_offers for select
  using (auth.uid() is not null);

create policy "swaps_insert" on public.swap_offers for insert
  with check (from_user_id = auth.uid() and public.is_approved(auth.uid()));

-- Kun ejeren kan ændre sit eget tilbud direkte. Alt andet går gennem
-- funktionerne herunder.
create policy "swaps_update_own" on public.swap_offers for update
  using (from_user_id = auth.uid());


create or replace function public.accept_swap(p_offer_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  o record;
  v_task record;
begin
  if not public.is_approved(auth.uid()) then
    raise exception 'Din profil er ikke godkendt endnu';
  end if;

  select * into o
    from public.swap_offers
   where id = p_offer_id
   for update;

  if not found then
    raise exception 'Byttetilbuddet findes ikke';
  end if;

  if o.status in ('accepted', 'declined') then
    raise exception 'Byttetilbuddet er allerede lukket';
  end if;

  if o.from_user_id = auth.uid() then
    raise exception 'Du kan ikke overtage din egen tjans';
  end if;

  if exists (select 1 from public.task_claims
              where task_id = o.offering_task_id and user_id = auth.uid()) then
    raise exception 'Du står allerede på den opgave';
  end if;

  select id, title, date into v_task from public.tasks where id = o.offering_task_id;
  if not found then
    raise exception 'Opgaven findes ikke længere';
  end if;

  -- Undertryk de automatiske "tildelt/fjernet"-beskeder; byttet sender
  -- sine egne, mere præcise beskeder nedenfor.
  perform set_config('app.in_swap', 'on', true);

  delete from public.task_claims
   where task_id = o.offering_task_id
     and user_id = o.from_user_id;

  insert into public.task_claims (task_id, user_id)
  values (o.offering_task_id, auth.uid());

  update public.swap_offers
     set status      = 'accepted',
         accepted_by = auth.uid(),
         accepted_at = now()
   where id = p_offer_id;

  perform set_config('app.in_swap', 'off', true);

  insert into public.notifications (user_id, type, title, body, action_task_id)
  values (
    o.from_user_id, 'swap_accepted',
    'Dit bytte er accepteret',
    (select name from public.profiles where id = auth.uid())
      || ' har overtaget "' || v_task.title || '" den ' || v_task.date || '.',
    v_task.id
  );
end;
$$;

grant execute on function public.accept_swap(uuid) to authenticated;


create or replace function public.decline_swap(p_offer_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  o record;
begin
  select * into o from public.swap_offers where id = p_offer_id for update;
  if not found then
    raise exception 'Byttetilbuddet findes ikke';
  end if;

  -- Enten er det dit eget tilbud, du trækker tilbage, eller også er det
  -- rettet mod en opgave, du selv står på.
  if o.from_user_id <> auth.uid()
     and not exists (select 1 from public.task_claims
                      where task_id = o.wants_task_id and user_id = auth.uid()) then
    raise exception 'Du kan ikke afvise dette bytte';
  end if;

  update public.swap_offers set status = 'declined' where id = p_offer_id;

  if o.from_user_id <> auth.uid() then
    insert into public.notifications (user_id, type, title, body)
    values (o.from_user_id, 'swap_declined', 'Dit bytte blev afvist',
            'Dit byttetilbud er afvist. Du står stadig på tjansen.');
  end if;
end;
$$;

grant execute on function public.decline_swap(uuid) to authenticated;


-- ============================================================================
-- 6. NOTIFIKATIONER  (punkt 10a)
--
-- Tabellen fandtes, men intet sted kunne skrive til den, så klokken var
-- altid tom. Beskederne oprettes nu af databasen selv.
-- ============================================================================

-- Slettes en opgave, skal beskeden om den kunne overleve.
alter table public.notifications
  drop constraint if exists notifications_action_task_id_fkey;

alter table public.notifications
  add constraint notifications_action_task_id_fkey
  foreign key (action_task_id) references public.tasks(id) on delete set null;

drop policy if exists "notif_select" on public.notifications;
drop policy if exists "notif_update" on public.notifications;
drop policy if exists "notif_insert" on public.notifications;
drop policy if exists "notif_delete" on public.notifications;
drop policy if exists "notif_insert_admin" on public.notifications;

create policy "notif_select" on public.notifications for select
  using (user_id = auth.uid());

create policy "notif_update" on public.notifications for update
  using (user_id = auth.uid());

create policy "notif_delete" on public.notifications for delete
  using (user_id = auth.uid());

-- Admins kan sende en besked til et medlem fra panelet.
create policy "notif_insert_admin" on public.notifications for insert
  with check (public.get_my_role() in ('admin', 'super_admin'));


-- Ændres eller aflyses en opgave, får de tilmeldte besked.
create or replace function public.task_changed_notify()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_changed text;
begin
  if tg_op = 'DELETE' then
    insert into public.notifications (user_id, type, title, body)
    select tc.user_id, 'task_cancelled',
           'En opgave er aflyst',
           '"' || old.title || '" den ' || old.date || ' er fjernet. '
             || 'Dine point for opgaven er trukket tilbage.'
      from public.task_claims tc
     where tc.task_id = old.id;
    return old;
  end if;

  if new.date     is distinct from old.date
  or new.time     is distinct from old.time
  or new.location is distinct from old.location
  or new.title    is distinct from old.title then

    v_changed := case
      when new.date is distinct from old.date         then 'Ny dato: ' || new.date
      when new.time is distinct from old.time         then 'Nyt tidsrum: ' || coalesce(new.time, '–')
      when new.location is distinct from old.location then 'Nyt sted: ' || new.location
      else 'Opgaven har fået ny titel: ' || new.title
    end;

    insert into public.notifications (user_id, type, title, body, action_task_id)
    select tc.user_id, 'task_changed',
           'En af dine opgaver er ændret',
           '"' || new.title || '" · ' || v_changed,
           new.id
      from public.task_claims tc
     where tc.task_id = new.id
       and tc.user_id is distinct from auth.uid();
  end if;

  return new;
end;
$$;

drop trigger if exists on_task_changed on public.tasks;
create trigger on_task_changed
  after update on public.tasks
  for each row execute procedure public.task_changed_notify();

drop trigger if exists on_task_deleted on public.tasks;
create trigger on_task_deleted
  before delete on public.tasks
  for each row execute procedure public.task_changed_notify();


-- Godkendelse giver besked.
create or replace function public.profile_approved_notify()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.approved = true and coalesce(old.approved, false) = false then
    insert into public.notifications (user_id, type, title, body)
    values (new.id, 'approved', 'Din profil er godkendt',
            'Velkommen! Du kan nu tage tjanser og optjene point.');
  end if;
  return new;
end;
$$;

drop trigger if exists on_profile_approved on public.profiles;
create trigger on_profile_approved
  after update on public.profiles
  for each row execute procedure public.profile_approved_notify();


-- ============================================================================
-- 7. OPRYDNING  (punkt 4 og 9 understøttes af appen selv)
-- ============================================================================

-- Audit-loggen: kun admins skriver, kun admins læser.
drop policy if exists "audit_insert" on public.audit_log;
create policy "audit_insert" on public.audit_log for insert
  with check (public.get_my_role() in ('admin', 'super_admin'));

-- Indeks der mangler til de opslag, appen laver hele tiden.
create index if not exists task_claims_user_id_idx     on public.task_claims (user_id);
create index if not exists task_claims_task_id_idx     on public.task_claims (task_id);
create index if not exists notifications_user_read_idx on public.notifications (user_id, created_at desc);
create index if not exists swap_offers_status_idx      on public.swap_offers (status);


-- ============================================================================
-- FÆRDIG
--
-- Tjek bagefter, at der ikke er efterladt en gammel trigger, som tæller
-- point med igen:
--
--   select tgname from pg_trigger
--    where tgrelid = 'public.task_claims'::regclass and not tgisinternal;
--
-- Der skal stå præcis to: tc_before_insert og tc_after_insert,
-- plus tc_after_delete. Står der on_task_claimed, er filen ikke kørt færdig.
-- ============================================================================



-- ############################################################################
-- ## AFSNIT 3 af 21: 20260918100000_task_completion.sql
-- ############################################################################

-- ============================================================================
-- RVK Frivillig – point for GENNEMFØRTE tjanser (punkt 13 i lanceringstjekket)
--
-- Før: point blev givet i det sekund, man trykkede "Tag tjansen". Én person
-- kunne tage tyve tjanser, aldrig møde op, og toppe ranglisten. Betyder point
-- noget for frivillighedsbidraget, holder det ikke.
--
-- Efter: en tilmelding har en tilstand.
--
--     signed_up   Meldt til. Optager en plads, men giver ingen point endnu.
--     completed   Bekræftet af en admin. Pointene tæller.
--     no_show     Registreret som ikke gennemført. Ingen point.
--
-- profiles.points = summen af point fra COMPLETED tilmeldinger + bonus_points
--
-- Kør i Supabase Dashboard → SQL Editor → Run. Kan køres flere gange.
-- Forudsætter, at 20260910120000_launch_hardening.sql er kørt først.
-- ============================================================================


-- ============================================================================
-- 1. TILSTAND PÅ TILMELDINGER
-- ============================================================================

alter table public.task_claims
  add column if not exists status       text not null default 'signed_up',
  add column if not exists confirmed_at timestamptz,
  add column if not exists confirmed_by uuid references public.profiles(id) on delete set null,
  add column if not exists admin_note   text;

do $$ begin
  alter table public.task_claims
    add constraint task_claims_status_check
    check (status in ('signed_up', 'completed', 'no_show'));
exception when duplicate_object then null;
end $$;

create index if not exists task_claims_status_idx on public.task_claims (status);


-- ============================================================================
-- 2. POINT GIVES VED BEKRÆFTELSE, IKKE VED TILMELDING
-- ============================================================================

-- --- Tilmelding oprettes ---------------------------------------------------
-- Tager en plads og sender besked ved admin-tildeling. Ingen point.

create or replace function public.tc_after_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.tasks
     set spots_left = spots_left - 1
   where id = new.task_id
     and spots_left > 0;

  -- Point først når en admin bekræfter, at tjansen er gennemført.

  if auth.uid() is distinct from new.user_id
     and coalesce(current_setting('app.in_swap', true), '') <> 'on' then
    insert into public.notifications (user_id, type, title, body, action_task_id)
    select new.user_id, 'task_assigned',
           'Du er tildelt en opgave',
           t.title || ' · ' || t.date || coalesce(' · ' || nullif(t.time, ''), ''),
           t.id
      from public.tasks t where t.id = new.task_id;
  end if;

  return new;
end;
$$;


-- --- Tilmelding fjernes ----------------------------------------------------
-- Ruller kun point tilbage, hvis tjansen var bekræftet.

create or replace function public.tc_after_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.tasks
     set spots_left = least(spots_left + 1, spots_total)
   where id = old.task_id;

  if old.status = 'completed' then
    update public.profiles
       set points     = greatest(0, points - coalesce(old.points_awarded, 0)),
           tasks_done = greatest(0, tasks_done - 1)
     where id = old.user_id;
  end if;

  if auth.uid() is distinct from old.user_id
     and coalesce(current_setting('app.in_swap', true), '') <> 'on' then
    insert into public.notifications (user_id, type, title, body, action_task_id)
    select old.user_id, 'task_unassigned',
           'Du er fjernet fra en opgave',
           t.title || ' · ' || t.date,
           t.id
      from public.tasks t where t.id = old.task_id;
  end if;

  return old;
end;
$$;


-- --- En bekræftet tjans kan ikke frameldes af medlemmet selv ---------------

create or replace function public.tc_before_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- auth.uid() er null når det sker på serveren (fx sletning af et medlem).
  if auth.uid() is null then
    return old;
  end if;

  if old.status <> 'signed_up'
     and public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Tjansen er allerede gjort op – kontakt klubben hvis det er en fejl';
  end if;

  return old;
end;
$$;

drop trigger if exists tc_before_delete on public.task_claims;
create trigger tc_before_delete
  before delete on public.task_claims
  for each row execute procedure public.tc_before_delete();


-- --- Tilstanden ændres -----------------------------------------------------
-- Her flytter pointene. Skrevet så den tåler enhver overgang mellem de tre
-- tilstande, også frem og tilbage.

create or replace function public.tc_after_update()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_was_counted boolean := old.status = 'completed';
  v_is_counted  boolean := new.status = 'completed';
  v_points      int     := coalesce(new.points_awarded, 0);
  v_task        record;
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  if v_is_counted and not v_was_counted then
    update public.profiles
       set points     = points + v_points,
           tasks_done = tasks_done + 1
     where id = new.user_id;

  elsif v_was_counted and not v_is_counted then
    update public.profiles
       set points     = greatest(0, points - coalesce(old.points_awarded, 0)),
           tasks_done = greatest(0, tasks_done - 1)
     where id = new.user_id;
  end if;

  select title, date into v_task from public.tasks where id = new.task_id;

  if new.status = 'completed' then
    insert into public.notifications (user_id, type, title, body, action_task_id)
    values (new.user_id, 'task_completed',
            'Tjansen er godkendt – ' || v_points || ' point',
            '"' || v_task.title || '" den ' || v_task.date || ' er registreret som gennemført. Tak for hjælpen!',
            new.task_id);

  elsif new.status = 'no_show' then
    insert into public.notifications (user_id, type, title, body, action_task_id)
    values (new.user_id, 'task_no_show',
            'Tjans registreret som ikke gennemført',
            '"' || v_task.title || '" den ' || v_task.date || ' er registreret som ikke gennemført, så den giver ingen point.'
              || coalesce(' Bemærkning: ' || nullif(new.admin_note, ''), '')
              || ' Er det en fejl, så kontakt klubben.',
            new.task_id);

  elsif v_was_counted then
    insert into public.notifications (user_id, type, title, body, action_task_id)
    values (new.user_id, 'task_reopened',
            'Godkendelsen af en tjans er trukket tilbage',
            '"' || v_task.title || '" afventer nu bekræftelse igen, og pointene er trukket tilbage.',
            new.task_id);
  end if;

  return new;
end;
$$;

drop trigger if exists tc_after_update on public.task_claims;
create trigger tc_after_update
  after update on public.task_claims
  for each row execute procedure public.tc_after_update();


-- ============================================================================
-- 3. ADMIN BEKRÆFTER
-- ============================================================================

-- Én person på én opgave.
create or replace function public.admin_set_claim_status(
  p_task   uuid,
  p_user   uuid,
  p_status text,
  p_note   text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan bekræfte tjanser';
  end if;

  if p_status not in ('signed_up', 'completed', 'no_show') then
    raise exception 'Ukendt tilstand: %', p_status;
  end if;

  update public.task_claims
     set status       = p_status,
         admin_note   = nullif(p_note, ''),
         confirmed_at = case when p_status = 'signed_up' then null else now() end,
         confirmed_by = case when p_status = 'signed_up' then null else auth.uid() end
   where task_id = p_task
     and user_id = p_user;

  if not found then
    raise exception 'Tilmeldingen findes ikke';
  end if;
end;
$$;

grant execute on function public.admin_set_claim_status(uuid, uuid, text, text) to authenticated;


-- Hele opgaven på én gang – det normale tilfælde, når alle mødte op.
-- Rører kun dem, der stadig afventer, så en enkelt udeblevet ikke bliver
-- godkendt ved et uheld.
create or replace function public.admin_confirm_task(p_task uuid, p_status text default 'completed')
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count int;
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan bekræfte tjanser';
  end if;

  if p_status not in ('completed', 'no_show') then
    raise exception 'Ukendt tilstand: %', p_status;
  end if;

  update public.task_claims
     set status       = p_status,
         confirmed_at = now(),
         confirmed_by = auth.uid()
   where task_id = p_task
     and status  = 'signed_up';

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.admin_confirm_task(uuid, text) to authenticated;


-- Listen over, hvad der mangler at blive gjort op.
create or replace function public.admin_pending_confirmations()
returns table (
  task_id     uuid,
  title       text,
  task_date   text,
  date_full   text,
  task_time   text,
  location    text,
  points      int,
  icon        text,
  pending     int,
  completed   int,
  no_show     int
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan se bekræftelser';
  end if;

  return query
    select t.id, t.title, t.date, t.date_full, t.time, t.location, t.points, t.icon,
           count(*) filter (where c.status = 'signed_up')::int,
           count(*) filter (where c.status = 'completed')::int,
           count(*) filter (where c.status = 'no_show')::int
      from public.tasks t
      join public.task_claims c on c.task_id = t.id
     group by t.id
    having count(*) filter (where c.status = 'signed_up') > 0;
end;
$$;

grant execute on function public.admin_pending_confirmations() to authenticated;


-- Hvem står på en given opgave, og hvordan er de gjort op.
create or replace function public.admin_task_signups(p_task uuid)
returns table (
  user_id      uuid,
  name         text,
  role         text,
  team         text,
  status       text,
  admin_note   text,
  confirmed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan se tilmeldte';
  end if;

  return query
    select p.id, p.name, p.role, p.team, c.status, c.admin_note, c.confirmed_at
      from public.task_claims c
      join public.profiles p on p.id = c.user_id
     where c.task_id = p_task
     order by p.name;
end;
$$;

grant execute on function public.admin_task_signups(uuid) to authenticated;


-- ============================================================================
-- 4. BYTTE AF TJANSER
--
-- Et bytte må kun handle om en tjans, der ikke er gjort op endnu. Er den
-- bekræftet, er der ikke noget at bytte.
-- ============================================================================

create or replace function public.accept_swap(p_offer_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  o record;
  v_task record;
  v_claim record;
begin
  if not public.is_approved(auth.uid()) then
    raise exception 'Din profil er ikke godkendt endnu';
  end if;

  select * into o from public.swap_offers where id = p_offer_id for update;
  if not found then
    raise exception 'Byttetilbuddet findes ikke';
  end if;

  if o.status in ('accepted', 'declined') then
    raise exception 'Byttetilbuddet er allerede lukket';
  end if;

  if o.from_user_id = auth.uid() then
    raise exception 'Du kan ikke overtage din egen tjans';
  end if;

  if exists (select 1 from public.task_claims
              where task_id = o.offering_task_id and user_id = auth.uid()) then
    raise exception 'Du står allerede på den opgave';
  end if;

  select * into v_claim from public.task_claims
   where task_id = o.offering_task_id and user_id = o.from_user_id;

  if not found then
    raise exception 'Tilbuddet er ikke længere gyldigt – tjansen er frameldt';
  end if;

  if v_claim.status <> 'signed_up' then
    raise exception 'Tjansen er allerede gjort op og kan ikke byttes';
  end if;

  select id, title, date into v_task from public.tasks where id = o.offering_task_id;
  if not found then
    raise exception 'Opgaven findes ikke længere';
  end if;

  perform set_config('app.in_swap', 'on', true);

  delete from public.task_claims
   where task_id = o.offering_task_id and user_id = o.from_user_id;

  insert into public.task_claims (task_id, user_id)
  values (o.offering_task_id, auth.uid());

  update public.swap_offers
     set status = 'accepted', accepted_by = auth.uid(), accepted_at = now()
   where id = p_offer_id;

  perform set_config('app.in_swap', 'off', true);

  insert into public.notifications (user_id, type, title, body, action_task_id)
  values (
    o.from_user_id, 'swap_accepted',
    'Dit bytte er accepteret',
    (select name from public.profiles where id = auth.uid())
      || ' har overtaget "' || v_task.title || '" den ' || v_task.date || '.',
    v_task.id
  );
end;
$$;

grant execute on function public.accept_swap(uuid) to authenticated;


-- ============================================================================
-- 5. GENBEREGNING
--
-- Point tælles nu KUN fra bekræftede tjanser. Alle eksisterende tilmeldinger
-- står som 'signed_up' (standardværdien), så pointene nulstilles her og bygges
-- op igen, efterhånden som admins bekræfter.
--
-- Er der tjanser, I ved er gennemført, kan de bekræftes samlet bagefter under
-- Admin → Bekræft tjanser. Alternativt kan hele historikken godkendes på én
-- gang med denne linje (kør den KUN hvis det passer):
--
--   update public.task_claims set status = 'completed', confirmed_at = now()
--    where status = 'signed_up';
--
-- ============================================================================

update public.profiles p
   set points     = greatest(0, coalesce(c.pts, 0) + p.bonus_points),
       tasks_done = coalesce(c.cnt, 0)
  from (
        select user_id,
               sum(coalesce(points_awarded, 0))::int as pts,
               count(*)::int                          as cnt
          from public.task_claims
         where status = 'completed'
         group by user_id
       ) c
 where c.user_id = p.id;

update public.profiles p
   set points     = greatest(0, p.bonus_points),
       tasks_done = 0
 where not exists (
        select 1 from public.task_claims tc
         where tc.user_id = p.id and tc.status = 'completed'
       );


-- ============================================================================
-- FÆRDIG
--
-- Kontrollér bagefter:
--
--   select status, count(*) from public.task_claims group by status;
--
--   select tgname from pg_trigger
--    where tgrelid = 'public.task_claims'::regclass and not tgisinternal;
--   -- forventet: tc_after_delete, tc_after_insert, tc_after_update,
--   --            tc_before_delete, tc_before_insert
-- ============================================================================



-- ############################################################################
-- ## AFSNIT 4 af 21: 20260918140000_auto_confirm.sql
-- ############################################################################

-- ============================================================================
-- RVK Frivillig – automatisk bekræftelse efter 7 dage
--
-- Punkt 13 gav admins arbejdet med at gøre hver eneste tjans op. Her lettes
-- byrden: er der gået 7 dage efter opgavens sidste dag, og har ingen admin
-- rørt tilmeldingen, godkendes den automatisk.
--
-- Reglen er bevidst forsigtig:
--   * Kun tilmeldinger der stadig står som 'signed_up'. Har en admin markeret
--     nogen som udeblevet, bliver det stående.
--   * Kun opgaver hvor slutdatoen kan læses med sikkerhed (ISO-format).
--     Gamle opgaver med kun en dansk datotekst røres ikke – de skal gøres op
--     i hånden, og admin-panelet siger det tydeligt.
--   * Antal dage sættes i admin-panelet. 0 slår funktionen helt fra.
--
-- Kør i Supabase Dashboard → SQL Editor → Run. Kan køres flere gange.
-- Forudsætter, at de to foregående migrationer er kørt.
-- ============================================================================


-- ============================================================================
-- 1. INDSTILLING
-- ============================================================================

insert into public.settings (key, value) values ('auto_confirm_days', '7')
on conflict (key) do nothing;


-- ============================================================================
-- 2. HVORNÅR ER EN OPGAVE SLUT?
--
-- date_full sættes af datovælgeren og er altid ISO. date_end bruges til
-- opgaver der strækker sig over en uge, en måned eller en sæson. Alt andet
-- giver null, og så rører automatikken ikke opgaven.
-- ============================================================================

create or replace function public.task_end_date(p_date_full text, p_date_end text)
returns date
language sql
immutable
as $$
  select case
    when p_date_end  ~ '^\d{4}-\d{2}-\d{2}' then substring(p_date_end,  1, 10)::date
    when p_date_full ~ '^\d{4}-\d{2}-\d{2}' then substring(p_date_full, 1, 10)::date
    else null
  end;
$$;

grant execute on function public.task_end_date(text, text) to authenticated;


-- ============================================================================
-- 3. SELVE OPGØRELSEN
--
-- Kan kaldes af hvem som helst der er logget ind. Den anvender kun en
-- deterministisk regel og kan ikke godkende noget, der ikke allerede er
-- forfaldent — derfor er der ingen rolletjek. En spærretid på en time
-- forhindrer, at den kører ved hvert eneste sideskift.
-- ============================================================================

create or replace function public.auto_confirm_due_claims(p_force boolean default false)
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_days     int;
  v_last     timestamptz;
  v_count    int := 0;
  v_cutoff   date;
begin
  select nullif(value, '')::int into v_days
    from public.settings where key = 'auto_confirm_days';

  if coalesce(v_days, 0) <= 0 then
    return 0;                                   -- slået fra
  end if;

  if not p_force then
    select nullif(value, '')::timestamptz into v_last
      from public.settings where key = 'auto_confirm_last_run';
    if v_last is not null and v_last > now() - interval '1 hour' then
      return 0;                                 -- kørt for nylig
    end if;
  end if;

  v_cutoff := (current_date - v_days);

  -- Fortæl triggeren at det er automatikken, så beskeden til medlemmet
  -- bliver formuleret derefter.
  perform set_config('app.auto_confirm', 'on', true);

  update public.task_claims c
     set status       = 'completed',
         confirmed_at = now(),
         confirmed_by = null
    from public.tasks t
   where t.id = c.task_id
     and c.status = 'signed_up'
     and public.task_end_date(t.date_full, t.date_end) is not null
     and public.task_end_date(t.date_full, t.date_end) <= v_cutoff;

  get diagnostics v_count = row_count;

  perform set_config('app.auto_confirm', 'off', true);

  insert into public.settings (key, value, updated_at)
  values ('auto_confirm_last_run', now()::text, now())
  on conflict (key) do update set value = excluded.value, updated_at = now();

  if v_count > 0 then
    insert into public.audit_log (type, action, actor_name)
    values ('task',
            'Bekræftede automatisk ' || v_count || ' tjanser efter ' || v_days || ' dage',
            'Automatik');
  end if;

  return v_count;
end;
$$;

grant execute on function public.auto_confirm_due_claims(boolean) to authenticated;


-- Hvad ville den gøre lige nu? Bruges til at vise en advarsel i admin-panelet,
-- så ingen bliver overrasket over at noget bliver godkendt af sig selv.
create or replace function public.auto_confirm_preview()
returns table (
  days_setting   int,
  due_now        int,
  due_next_24h   int,
  unparseable    int
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_days int;
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan se dette';
  end if;

  select coalesce(nullif(value, '')::int, 0) into v_days
    from public.settings where key = 'auto_confirm_days';
  v_days := coalesce(v_days, 0);

  return query
    select v_days,
           count(*) filter (
             where v_days > 0
               and public.task_end_date(t.date_full, t.date_end) <= current_date - v_days
           )::int,
           count(*) filter (
             where v_days > 0
               and public.task_end_date(t.date_full, t.date_end) = current_date - v_days + 1
           )::int,
           count(*) filter (
             where public.task_end_date(t.date_full, t.date_end) is null
           )::int
      from public.task_claims c
      join public.tasks t on t.id = c.task_id
     where c.status = 'signed_up';
end;
$$;

grant execute on function public.auto_confirm_preview() to authenticated;


-- ============================================================================
-- 4. BESKEDEN TIL MEDLEMMET
--
-- Samme trigger som før, men den skelner nu mellem en admins godkendelse og
-- automatikkens, så ingen tror at nogen sad og kiggede den igennem.
-- ============================================================================

create or replace function public.tc_after_update()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_was_counted boolean := old.status = 'completed';
  v_is_counted  boolean := new.status = 'completed';
  v_points      int     := coalesce(new.points_awarded, 0);
  v_auto        boolean := coalesce(current_setting('app.auto_confirm', true), '') = 'on';
  v_days        text;
  v_task        record;
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  if v_is_counted and not v_was_counted then
    update public.profiles
       set points     = points + v_points,
           tasks_done = tasks_done + 1
     where id = new.user_id;

  elsif v_was_counted and not v_is_counted then
    update public.profiles
       set points     = greatest(0, points - coalesce(old.points_awarded, 0)),
           tasks_done = greatest(0, tasks_done - 1)
     where id = new.user_id;
  end if;

  select title, date into v_task from public.tasks where id = new.task_id;

  if new.status = 'completed' then
    if v_auto then
      select value into v_days from public.settings where key = 'auto_confirm_days';
      insert into public.notifications (user_id, type, title, body, action_task_id)
      values (new.user_id, 'task_completed',
              'Tjansen er godkendt – ' || v_points || ' point',
              '"' || v_task.title || '" den ' || v_task.date || ' er godkendt automatisk, '
                || 'fordi der er gået ' || coalesce(v_days, '7') || ' dage. Tak for hjælpen!',
              new.task_id);
    else
      insert into public.notifications (user_id, type, title, body, action_task_id)
      values (new.user_id, 'task_completed',
              'Tjansen er godkendt – ' || v_points || ' point',
              '"' || v_task.title || '" den ' || v_task.date || ' er registreret som gennemført. Tak for hjælpen!',
              new.task_id);
    end if;

  elsif new.status = 'no_show' then
    insert into public.notifications (user_id, type, title, body, action_task_id)
    values (new.user_id, 'task_no_show',
            'Tjans registreret som ikke gennemført',
            '"' || v_task.title || '" den ' || v_task.date || ' er registreret som ikke gennemført, så den giver ingen point.'
              || coalesce(' Bemærkning: ' || nullif(new.admin_note, ''), '')
              || ' Er det en fejl, så kontakt klubben.',
            new.task_id);

  elsif v_was_counted then
    insert into public.notifications (user_id, type, title, body, action_task_id)
    values (new.user_id, 'task_reopened',
            'Godkendelsen af en tjans er trukket tilbage',
            '"' || v_task.title || '" afventer nu bekræftelse igen, og pointene er trukket tilbage.',
            new.task_id);
  end if;

  return new;
end;
$$;


-- ============================================================================
-- 5. DAGLIG KØRSEL
--
-- pg_cron gør arbejdet, hvis udvidelsen findes på projektet. Kan den ikke
-- slås til, er det ikke en fejl: appen kalder selv funktionen, når nogen
-- åbner den, og spærretiden ovenfor holder antallet af kald nede.
-- ============================================================================

do $outer$
begin
  create extension if not exists pg_cron;

  if exists (select 1 from cron.job where jobname = 'rvk_auto_confirm') then
    perform cron.unschedule('rvk_auto_confirm');
  end if;

  perform cron.schedule(
    'rvk_auto_confirm',
    '0 3 * * *',
    $job$ select public.auto_confirm_due_claims(true); $job$
  );

  raise notice 'pg_cron: dagligt job "rvk_auto_confirm" kører kl. 03:00 UTC';
exception when others then
  raise notice 'pg_cron ikke tilgængelig (%). Appen kalder selv auto_confirm_due_claims() – det virker også, men kun når nogen er inde i appen.', sqlerrm;
end
$outer$;


-- ============================================================================
-- FÆRDIG
--
-- Slå fra igen:      update public.settings set value = '0' where key = 'auto_confirm_days';
-- Kør med det samme: select public.auto_confirm_due_claims(true);
-- Se hvad der venter: select * from public.auto_confirm_preview();
-- ============================================================================



-- ############################################################################
-- ## AFSNIT 5 af 21: 20260918160000_cleanup_orphans.sql
-- ############################################################################

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



-- ############################################################################
-- ## AFSNIT 6 af 21: 20260919080000_policies_from_legacy.sql
-- ############################################################################

-- ============================================================================
-- RVK Frivillig – adgangsregler, der hidtil kun fandtes i de løse SQL-filer
--
-- De ni filer i roden (nu supabase/legacy/) indeholdt både skema OG
-- adgangsregler. Da skemaet flyttede til 20260101000000_baseline.sql, blev
-- reglerne hængende i filer, ingen skal køre længere. Det efterlod et hul:
-- en frisk opsætning fra migrationerne alene ville have RLS slået til på
-- tasks, teams og settings UDEN politikker — altså en app, der ikke kan
-- læse en eneste opgave.
--
-- Her samles de manglende regler, så migrationerne er nok i sig selv.
-- Reglerne er samtidig strammet ét sted: opgaver, hold og indstillinger
-- kunne før læses uden login ("using (true)"). Nu kræver alt en session,
-- på linje med medlemstabellen.
--
-- Kør i Supabase Dashboard → SQL Editor → Run. Kan køres flere gange.
-- ============================================================================


-- ============================================================================
-- OPGAVER
-- ============================================================================

drop policy if exists "tasks_select" on public.tasks;
drop policy if exists "tasks_insert" on public.tasks;
drop policy if exists "tasks_update" on public.tasks;
drop policy if exists "tasks_delete" on public.tasks;

create policy "tasks_select" on public.tasks for select
  using (auth.uid() is not null);

create policy "tasks_insert" on public.tasks for insert
  with check (public.get_my_role() in ('admin', 'super_admin'));

create policy "tasks_update" on public.tasks for update
  using (public.get_my_role() in ('admin', 'super_admin'));

create policy "tasks_delete" on public.tasks for delete
  using (public.get_my_role() in ('admin', 'super_admin'));


-- ============================================================================
-- VEJLEDNINGSTRIN
-- ============================================================================

drop policy if exists "task_steps_select" on public.task_steps;
drop policy if exists "task_steps_all"    on public.task_steps;
drop policy if exists "task_steps_write"  on public.task_steps;

create policy "task_steps_select" on public.task_steps for select
  using (auth.uid() is not null);

create policy "task_steps_write" on public.task_steps for all
  using      (public.get_my_role() in ('admin', 'super_admin'))
  with check (public.get_my_role() in ('admin', 'super_admin'));


-- ============================================================================
-- HOLD
-- ============================================================================

drop policy if exists "teams_select" on public.teams;
drop policy if exists "teams_insert" on public.teams;
drop policy if exists "teams_update" on public.teams;
drop policy if exists "teams_delete" on public.teams;

create policy "teams_select" on public.teams for select
  using (auth.uid() is not null);

create policy "teams_insert" on public.teams for insert
  with check (public.get_my_role() = 'super_admin');

create policy "teams_update" on public.teams for update
  using (public.get_my_role() = 'super_admin');

create policy "teams_delete" on public.teams for delete
  using (public.get_my_role() = 'super_admin');


-- ============================================================================
-- INDSTILLINGER
-- ============================================================================

drop policy if exists "settings_select" on public.settings;
drop policy if exists "settings_upsert" on public.settings;
drop policy if exists "settings_update" on public.settings;

create policy "settings_select" on public.settings for select
  using (auth.uid() is not null);

create policy "settings_upsert" on public.settings for insert
  with check (public.get_my_role() = 'super_admin');

create policy "settings_update" on public.settings for update
  using (public.get_my_role() = 'super_admin');


-- ============================================================================
-- AUDIT-LOG
--
-- Skrivereglen sættes i 20260910120000_launch_hardening.sql. Her mangler
-- kun læsereglen.
-- ============================================================================

drop policy if exists "audit_select" on public.audit_log;

create policy "audit_select" on public.audit_log for select
  using (public.get_my_role() in ('admin', 'super_admin'));


-- ============================================================================
-- MEDLEMMER: oprettelse
--
-- Profilen oprettes normalt af handle_new_user(), som er security definer og
-- derfor ikke berøres af RLS. Politikken er et sikkerhedsnet, hvis en profil
-- nogensinde skal oprettes fra klienten — og den tillader kun ens egen.
-- ============================================================================

drop policy if exists "profiles_insert" on public.profiles;

create policy "profiles_insert" on public.profiles for insert
  with check (id = auth.uid());


-- ============================================================================
-- STANDARDINDSTILLINGER
--
-- Kun hvis de mangler. Klubbens egne værdier sættes i admin-panelet.
-- ============================================================================

insert into public.settings (key, value) values
  ('point_goal',        '100'),
  -- Klubbens frivilligbidrag er 400 kr. Tallet stod på 1500 her, mens
  -- databasen har haft 400 siden juni; on conflict do nothing betyder, at
  -- det aldrig nåede at gøre skade i den kørende database — men et nyt
  -- opsæt ville have fået det forkerte tal.
  ('contribution_kr',   '400'),
  ('season_start',      '2025-08-01'),
  ('season_end',        '2026-06-30'),
  ('auto_confirm_days', '7')
on conflict (key) do nothing;


-- ============================================================================
-- PROFILBILLEDER
--
-- Bucket'en er public, så billederne vises via getPublicUrl uden en
-- læsepolitik. Der er derfor bevidst INGEN bred select-politik — den ville
-- kun give mulighed for at liste alle filer (flaget af Supabases
-- security-advisor, se 20260918160000_cleanup_orphans.sql).
--
-- Hver bruger må kun røre sin egen mappe.
-- ============================================================================

do $$ begin
  drop policy if exists "Users can upload own avatar" on storage.objects;
  drop policy if exists "Users can update own avatar" on storage.objects;
  drop policy if exists "Users can delete own avatar" on storage.objects;

  create policy "Users can upload own avatar" on storage.objects for insert
    with check (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);

  create policy "Users can update own avatar" on storage.objects for update
    using (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);

  create policy "Users can delete own avatar" on storage.objects for delete
    using (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);
exception when others then
  raise notice 'storage ikke tilgængelig (%) – springer avatar-politikker over.', sqlerrm;
end $$;



-- ############################################################################
-- ## AFSNIT 7 af 21: 20260919090000_points_follow_task.sql
-- ############################################################################

-- ============================================================================
-- RVK Frivillig – point følger med, når en opgaves værdi ændres
--
-- Før: hver tilmelding huskede det pointtal, opgaven havde DA man meldte sig.
-- Rettede en admin bagefter opgaven fra 10 til 20 point, beholdt de allerede
-- tilmeldte deres 10. Det var bevidst — men det betød, at to personer kunne
-- få forskelligt betalt for nøjagtig samme tjans, uden at nogen kunne se
-- hvorfor.
--
-- Efter: pointtallet på en opgave er ét tal, og alle på opgaven følger det.
--
--   signed_up   points_awarded opdateres. Intet er udbetalt endnu, så
--               medlemmet ser bare et nyt tal under "afventer bekræftelse".
--   completed   points_awarded opdateres OG summen justeres med forskellen.
--               Medlemmet får besked, for deres point ændrer sig.
--   no_show     points_awarded opdateres for ordens skyld. Ingen point i spil.
--
-- Kør i Supabase Dashboard → SQL Editor → Run. Kan køres flere gange.
-- Kør EFTER de foregående migrationer.
-- ============================================================================

create or replace function public.task_points_changed()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_delta int;
begin
  if new.points is not distinct from old.points then
    return new;
  end if;

  v_delta := new.points - old.points;

  -- 1. Justér summen for dem, der allerede har fået pointene udbetalt.
  --    Gøres før points_awarded opdateres, så forskellen regnes på det
  --    beløb, de faktisk fik.
  update public.profiles p
     set points = greatest(0, p.points + v_delta)
    from public.task_claims c
   where c.user_id = p.id
     and c.task_id = new.id
     and c.status  = 'completed';

  -- 2. Alle tilmeldinger på opgaven får det nye pointtal.
  update public.task_claims
     set points_awarded = new.points
   where task_id = new.id;

  -- 3. Besked til dem, hvis sum faktisk ændrede sig.
  insert into public.notifications (user_id, type, title, body, action_task_id)
  select c.user_id, 'points_adjusted',
         case when v_delta > 0
              then 'En tjans er blevet mere værd'
              else 'Pointene for en tjans er sat ned' end,
         '"' || new.title || '" er rettet fra ' || old.points || ' til '
           || new.points || ' point, og din sum er justeret.',
         new.id
    from public.task_claims c
   where c.task_id = new.id
     and c.status  = 'completed'
     and c.user_id is distinct from auth.uid();

  return new;
end;
$$;

drop trigger if exists on_task_points_changed on public.tasks;
create trigger on_task_points_changed
  after update on public.tasks
  for each row execute procedure public.task_points_changed();


-- ============================================================================
-- Hvor mange bliver berørt, hvis en opgaves point ændres?
-- Bruges til at advare admin, inden ændringen gemmes.
-- ============================================================================

create or replace function public.task_claim_counts(p_task uuid)
returns table (
  signed_up int,
  completed int,
  no_show   int
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select count(*) filter (where status = 'signed_up')::int,
         count(*) filter (where status = 'completed')::int,
         count(*) filter (where status = 'no_show')::int
    from public.task_claims
   where task_id = p_task;
$$;

grant execute on function public.task_claim_counts(uuid) to authenticated;


-- ============================================================================
-- Ret eventuel skævhed fra før denne migration: sæt points_awarded til
-- opgavens nuværende værdi, og genberegn summerne derefter.
-- ============================================================================

update public.task_claims c
   set points_awarded = t.points
  from public.tasks t
 where t.id = c.task_id
   and c.points_awarded is distinct from t.points;

update public.profiles p
   set points     = greatest(0, coalesce(c.pts, 0) + p.bonus_points),
       tasks_done = coalesce(c.cnt, 0)
  from (
        select user_id,
               sum(coalesce(points_awarded, 0))::int as pts,
               count(*)::int                          as cnt
          from public.task_claims
         where status = 'completed'
         group by user_id
       ) c
 where c.user_id = p.id;

update public.profiles p
   set points     = greatest(0, p.bonus_points),
       tasks_done = 0
 where not exists (
        select 1 from public.task_claims tc
         where tc.user_id = p.id and tc.status = 'completed'
       );



-- ############################################################################
-- ## AFSNIT 8 af 21: 20260919110000_client_errors.sql
-- ############################################################################

-- ============================================================================
-- RVK Frivillig – fejl fra medlemmernes telefoner
--
-- Før: gik noget i stykker hos et medlem, endte fejlen i browserens konsol,
-- hvor ingen nogensinde kigger. Klubben hørte først om det, hvis personen
-- selv sagde det — og de fleste siger det ikke, de holder bare op med at
-- bruge appen.
--
-- Efter: uventede fejl skrives hertil, og admins kan se dem i panelet.
--
-- Det er ikke en erstatning for et rigtigt overvågningsværktøj, men det
-- kræver ingen konto hos nogen, og det fanger det vigtigste: at noget er
-- gået galt, hvor, og for hvem.
--
-- Kør i Supabase Dashboard → SQL Editor → Run. Kan køres flere gange.
-- ============================================================================

create table if not exists public.client_errors (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references public.profiles(id) on delete set null,
  message    text not null,
  source     text,                      -- 'error' | 'unhandledrejection' | 'render'
  stack      text,
  url        text,
  user_agent text,
  created_at timestamptz default now()
);

create index if not exists client_errors_created_idx on public.client_errors (created_at desc);
create index if not exists client_errors_user_idx    on public.client_errors (user_id, created_at desc);

alter table public.client_errors enable row level security;

drop policy if exists "client_errors_select" on public.client_errors;
drop policy if exists "client_errors_insert" on public.client_errors;

-- Kun admins læser dem. Et medlem skal ikke kunne se andres fejl — en
-- stak-sporing kan indeholde hvad som helst.
create policy "client_errors_select" on public.client_errors for select
  using (public.get_my_role() in ('admin', 'super_admin'));


-- ============================================================================
-- Indrapportering
--
-- Går gennem en funktion i stedet for en insert-politik, så der kan sættes
-- en grænse: én bruger kan højst lægge 20 fejl ind i timen. Ellers ville en
-- fejl inde i en render-løkke kunne fylde tabellen på få sekunder.
-- ============================================================================

create or replace function public.log_client_error(
  p_message    text,
  p_source     text default null,
  p_stack      text default null,
  p_url        text default null,
  p_user_agent text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_recent int;
begin
  if auth.uid() is null then
    return;                                  -- ikke logget ind: drop den
  end if;

  select count(*) into v_recent
    from public.client_errors
   where user_id = auth.uid()
     and created_at > now() - interval '1 hour';

  if v_recent >= 20 then
    return;                                  -- nok for nu
  end if;

  insert into public.client_errors (user_id, message, source, stack, url, user_agent)
  values (
    auth.uid(),
    left(coalesce(nullif(p_message, ''), 'Ukendt fejl'), 500),
    left(p_source, 40),
    left(p_stack, 4000),
    left(p_url, 500),
    left(p_user_agent, 300)
  );
end;
$$;

grant execute on function public.log_client_error(text, text, text, text, text) to authenticated;


-- ============================================================================
-- Oprydning
--
-- Fejl ældre end 90 dage har ingen værdi og er personhenførbare, så de
-- slettes. Kører sammen med den daglige bekræftelse, hvis pg_cron er slået
-- til; ellers kan linjen køres i hånden en gang imellem.
-- ============================================================================

create or replace function public.prune_client_errors()
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count int;
begin
  delete from public.client_errors where created_at < now() - interval '90 days';
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

do $outer$
begin
  if exists (select 1 from cron.job where jobname = 'rvk_prune_errors') then
    perform cron.unschedule('rvk_prune_errors');
  end if;
  perform cron.schedule('rvk_prune_errors', '30 3 * * *',
                        $job$ select public.prune_client_errors(); $job$);
  raise notice 'pg_cron: fejl ældre end 90 dage ryddes kl. 03:30 UTC';
exception when others then
  raise notice 'pg_cron ikke tilgængelig (%). Kør select public.prune_client_errors(); i hånden en gang imellem.', sqlerrm;
end
$outer$;



-- ############################################################################
-- ## AFSNIT 9 af 21: 20260919140000_lock_function_execute.sql
-- ############################################################################

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



-- ############################################################################
-- ## AFSNIT 10 af 21: 20260919160000_season_reset.sql
-- ############################################################################

-- ============================================================================
-- RVK Frivillig – nulstil sæson
--
-- Knappen "Nulstil ny sæson (slet alle point)" har aldrig været forbundet til
-- noget. Den så ud til at virke, og den gjorde ingenting.
--
-- Her bygges den, men med to ting, der ikke var der før:
--
--   1. ARKIVET. Point afgør, om et medlem skal betale frivillighedsbidrag.
--      At slette en sæsons regnskab uden at gemme resultatet betyder, at
--      klubben ikke kan svare på "nåede jeg målet sidste sæson?" — og det
--      spørgsmål kommer, når nogen får en regning. Derfor arkiveres hvert
--      medlems stilling, FØR den nulstilles.
--
--   2. LÅSEN. Funktionen kræver, at man sender ordet NULSTIL med. Et kald
--      uden det gør ingenting. Det betyder, at hverken et fejlklik, en
--      gentaget netværksforespørgsel eller et forkert kald mod API'et kan
--      slette en sæson ved et uheld.
--
-- Kan køres flere gange uden at gøre skade.
-- ============================================================================


-- ============================================================================
-- 1. ARKIVET
--
-- Én række pr. medlem pr. nulstilling. Navn og hold kopieres med, så rækken
-- kan læses alene — ellers ville et omdøbt hold skrive historien om.
--
-- Fremmednøglen har ON DELETE CASCADE med vilje: privatlivspolitikken lover,
-- at et medlems oplysninger slettes, når de beder om det. Så skal arkivet
-- følge med. Det er en bevidst afvejning mod at kunne dokumentere gamle
-- sæsoner — løftet vejer tungest.
-- ============================================================================

create table if not exists public.season_results (
  id            uuid primary key default gen_random_uuid(),
  season_label  text not null,
  season_start  text,
  season_end    text,
  user_id       uuid references public.profiles(id) on delete cascade,
  name          text not null,
  team          text,
  points        int  not null default 0,
  bonus_points  int  not null default 0,
  tasks_done    int  not null default 0,
  point_goal    int,
  archived_at   timestamptz not null default now(),
  archived_by   uuid references public.profiles(id) on delete set null
);

create index if not exists season_results_label_idx on public.season_results (archived_at desc, season_label);
create index if not exists season_results_user_idx  on public.season_results (user_id);

alter table public.season_results enable row level security;

drop policy if exists "season_results_select" on public.season_results;

-- Kun admins. Et medlem ser sin egen historik gennem appen, ikke tabellen.
create policy "season_results_select" on public.season_results for select
  using (public.get_my_role() in ('admin', 'super_admin'));


-- ============================================================================
-- 2. TIE TRIGGEREN UNDER NULSTILLINGEN
--
-- tc_after_delete sender "Du er fjernet fra en opgave" til den, hvis
-- tilmelding forsvinder. Ved en sæsonnulstilling ville hvert medlem få én
-- besked pr. tjans, de nogensinde har taget. Samme mekanisme som ved bytte.
-- ============================================================================

create or replace function public.tc_after_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.tasks
     set spots_left = least(spots_left + 1, spots_total)
   where id = old.task_id;

  if old.status = 'completed' then
    update public.profiles
       set points     = greatest(0, points - coalesce(old.points_awarded, 0)),
           tasks_done = greatest(0, tasks_done - 1)
     where id = old.user_id;
  end if;

  if auth.uid() is distinct from old.user_id
     and coalesce(current_setting('app.in_swap', true), '') <> 'on'
     and coalesce(current_setting('app.season_reset', true), '') <> 'on' then
    insert into public.notifications (user_id, type, title, body, action_task_id)
    select old.user_id, 'task_unassigned',
           'Du er fjernet fra en opgave',
           t.title || ' · ' || t.date,
           t.id
      from public.tasks t where t.id = old.task_id;
  end if;

  return old;
end;
$$;


-- ============================================================================
-- 3. HVAD VILLE DER SKE?
--
-- Skal vises, FØR nogen trykker. Tallene skal komme fra databasen, ikke fra
-- hvad browseren tilfældigvis har hentet.
-- ============================================================================

create or replace function public.admin_season_reset_preview()
returns table (
  members            int,
  total_points       int,
  claims_total       int,
  claims_pending     int,
  claims_completed   int,
  open_swaps         int,
  season_start       text,
  season_end         text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if public.get_my_role() <> 'super_admin' then
    raise exception 'Kun en super admin kan nulstille sæsonen';
  end if;

  return query
    select
      (select count(*)::int from public.profiles),
      (select coalesce(sum(points), 0)::int from public.profiles),
      (select count(*)::int from public.task_claims),
      (select count(*)::int from public.task_claims where status = 'signed_up'),
      (select count(*)::int from public.task_claims where status = 'completed'),
      (select count(*)::int from public.swap_offers
        where status in ('available', 'incoming', 'outgoing')),
      (select value from public.settings where key = 'season_start'),
      (select value from public.settings where key = 'season_end');
end;
$$;

grant execute on function public.admin_season_reset_preview() to authenticated;


-- ============================================================================
-- 4. SELVE NULSTILLINGEN
--
-- p_confirm SKAL være ordet NULSTIL. Det er ikke pynt: det betyder, at
-- funktionen ikke kan udløses af et kald, der ikke er skrevet med vilje.
-- Appen beder brugeren skrive ordet; databasen tjekker det igen.
--
-- Alt sker i ét kald, altså i én transaktion. Går noget galt undervejs,
-- ruller hele nulstillingen tilbage, og sæsonen står som før.
-- ============================================================================

create or replace function public.admin_reset_season(
  p_confirm text,
  p_label   text
)
returns table (
  archived_members int,
  deleted_claims   int,
  closed_swaps     int,
  freed_tasks      int
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_actor  uuid := auth.uid();
  v_label  text := nullif(btrim(coalesce(p_label, '')), '');
  v_start  text;
  v_end    text;
  v_goal   int;
  v_members int;
  v_claims  int;
  v_swaps   int;
  v_tasks   int;
  v_points  int;
begin
  if public.get_my_role() <> 'super_admin' then
    raise exception 'Kun en super admin kan nulstille sæsonen';
  end if;

  -- Låsen. Uden det præcise ord sker der ingenting.
  if p_confirm is distinct from 'NULSTIL' then
    raise exception 'Nulstillingen blev ikke bekræftet. Skriv NULSTIL for at gennemføre.';
  end if;

  if v_label is null then
    raise exception 'Sæsonen skal have et navn, så arkivet kan findes igen';
  end if;

  if exists (select 1 from public.season_results where season_label = v_label) then
    raise exception 'Der findes allerede et arkiv med navnet "%". Vælg et andet navn.', v_label;
  end if;

  select value into v_start from public.settings where key = 'season_start';
  select value into v_end   from public.settings where key = 'season_end';
  select nullif(value, '')::int into v_goal from public.settings where key = 'point_goal';

  select coalesce(sum(points), 0)::int into v_points from public.profiles;

  -- Tælles FØR sletningen. Bagefter har tc_after_delete allerede givet
  -- pladserne fri, og en optælling ville vise 0 og se ud som om intet skete.
  select count(distinct task_id)::int into v_tasks from public.task_claims;

  -- --- 1. Arkivér, før noget slettes ---------------------------------------
  insert into public.season_results (
    season_label, season_start, season_end, user_id, name, team,
    points, bonus_points, tasks_done, point_goal, archived_by
  )
  select v_label, v_start, v_end, p.id, p.name, p.team,
         p.points, p.bonus_points, p.tasks_done, v_goal, v_actor
    from public.profiles p;

  get diagnostics v_members = row_count;

  -- --- 2. Ti triggerne, så ingen får 40 beskeder ---------------------------
  perform set_config('app.season_reset', 'on', true);

  -- --- 3. Luk byttetilbud, der peger på tilmeldinger der forsvinder --------
  update public.swap_offers
     set status = 'declined'
   where status in ('available', 'incoming', 'outgoing');
  get diagnostics v_swaps = row_count;

  -- --- 4. Slet tilmeldingerne ----------------------------------------------
  delete from public.task_claims;
  get diagnostics v_claims = row_count;

  -- --- 5. Nulstil medlemmerne ----------------------------------------------
  update public.profiles
     set points       = 0,
         bonus_points = 0,
         tasks_done   = 0;

  -- --- 6. Giv pladserne fri igen -------------------------------------------
  -- tc_after_delete har allerede talt hver plads op. Dette er et sikkerhedsnet
  -- mod skævheder fra før, ikke selve frigivelsen — derfor rammer det normalt
  -- ingen rækker, og v_tasks er talt ovenfor.
  update public.tasks set spots_left = spots_total
   where spots_left is distinct from spots_total;

  perform set_config('app.season_reset', 'off', true);

  -- --- 7. Skriv det i loggen ------------------------------------------------
  insert into public.audit_log (type, action, actor_id, actor_name)
  values ('settings',
          'Nulstillede sæsonen "' || v_label || '". Arkiverede ' || v_members
            || ' medlemmer med i alt ' || v_points || ' point, slettede '
            || v_claims || ' tilmeldinger.',
          v_actor,
          (select name from public.profiles where id = v_actor));

  -- --- 8. Fortæl medlemmerne hvorfor deres point er væk --------------------
  insert into public.notifications (user_id, type, title, body)
  select p.id, 'season_reset', 'Ny sæson er begyndt',
         'Sæsonen "' || v_label || '" er gjort op, og alle er startet forfra på 0 point. '
           || 'Din stilling fra sidste sæson er gemt i klubbens arkiv.'
    from public.profiles p;

  return query select v_members, v_claims, v_swaps, v_tasks;
end;
$$;

grant execute on function public.admin_reset_season(text, text) to authenticated;


-- ============================================================================
-- 5. LÆS ARKIVET
--
-- Et arkiv, ingen kan se, er ikke et arkiv.
-- ============================================================================

create or replace function public.admin_season_list()
returns table (
  season_label  text,
  season_start  text,
  season_end    text,
  archived_at   timestamptz,
  archived_by   text,
  members       int,
  total_points  int,
  reached_goal  int
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan se sæsonarkivet';
  end if;

  return query
    select r.season_label,
           min(r.season_start),
           min(r.season_end),
           max(r.archived_at),
           coalesce(max(p.name), 'ukendt'),
           count(*)::int,
           coalesce(sum(r.points), 0)::int,
           count(*) filter (where r.point_goal is not null
                              and r.points >= r.point_goal)::int
      from public.season_results r
      left join public.profiles p on p.id = r.archived_by
     group by r.season_label
     order by max(r.archived_at) desc;
end;
$$;

grant execute on function public.admin_season_list() to authenticated;


create or replace function public.admin_season_rows(p_label text)
returns table (
  name         text,
  team         text,
  points       int,
  bonus_points int,
  tasks_done   int,
  point_goal   int
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan se sæsonarkivet';
  end if;

  return query
    select r.name, r.team, r.points, r.bonus_points, r.tasks_done, r.point_goal
      from public.season_results r
     where r.season_label = p_label
     order by r.points desc, r.name;
end;
$$;

grant execute on function public.admin_season_rows(text) to authenticated;


-- ============================================================================
-- 6. LUK FUNKTIONERNE
--
-- Enhver ny funktion i Postgres er åben for alle (PUBLIC), og det kan ikke
-- sættes fra som standard — se forklaringen i
-- 20260919140000_lock_function_execute.sql. Derfor lukker denne migration
-- selv de fire funktioner, den lige har oprettet.
--
-- Uden disse linjer kunne en ikke-indlogget kalde admin_reset_season.
-- Ordet NULSTIL ville stadig stoppe et tilfældigt kald, men ikke en, der
-- havde læst med her.
-- ============================================================================

revoke execute on function public.admin_reset_season(text, text)   from public, anon;
revoke execute on function public.admin_season_reset_preview()     from public, anon;
revoke execute on function public.admin_season_list()              from public, anon;
revoke execute on function public.admin_season_rows(text)          from public, anon;

grant execute on function public.admin_reset_season(text, text)    to authenticated;
grant execute on function public.admin_season_reset_preview()      to authenticated;
grant execute on function public.admin_season_list()               to authenticated;
grant execute on function public.admin_season_rows(text)           to authenticated;


-- ============================================================================
-- FÆRDIG
--
-- Prøv den af uden at ændre noget:
--   select * from public.admin_season_reset_preview();
--
-- Gennemfør (kun super admin, og kun med ordet):
--   select * from public.admin_reset_season('NULSTIL', '2025/2026');
--
-- Se arkivet:
--   select * from public.admin_season_list();
--   select * from public.admin_season_rows('2025/2026');
-- ============================================================================



-- ############################################################################
-- ## AFSNIT 11 af 21: 20260922180000_teams_readable_at_signup.sql
-- ############################################################################

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



-- ############################################################################
-- ## AFSNIT 12 af 21: 20260925140000_task_templates.sql
-- ############################################################################

-- ============================================================================
-- RVK Frivillig – klubbens egne skabeloner
--
-- Appen kommer med en fast liste af skabeloner i koden. Den kan klubben ikke
-- rette i, og hver gang en admin har opbygget en god opgave — med den rigtige
-- vejledning, de rigtige point og det rigtige antal pladser — går arbejdet
-- tabt, næste gang den samme tjans skal oprettes.
--
-- Her kan admins gemme en udfyldt opgave som skabelon i en af de eksisterende
-- kategorier. De står side om side med appens egne i skabelonvælgeren.
--
-- Skabeloner er ikke personoplysninger og ikke følsomme: det er klubbens
-- beskrivelse af en tjans. Alle indloggede kan læse dem, så en admin ikke
-- møder en tom liste af den forkerte grund. Kun admins kan oprette og slette.
--
-- Kan køres flere gange uden at gøre skade.
-- ============================================================================

create table if not exists public.task_templates (
  id          uuid primary key default gen_random_uuid(),
  category    text not null,
  title       text not null,
  points      int  not null default 10,
  difficulty  text not null default 'Let' check (difficulty in ('Let', 'Medium', 'Hård')),
  spots_total int  not null default 2,
  duration_type text default 'single',
  time        text,
  location    text,
  icon        text not null default 'setup',
  description text,
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  -- Samme titel to gange i samme kategori er altid en fejl: enten en dublet
  -- eller et forsøg på at rette en, der allerede findes.
  unique (category, title)
);

create index if not exists task_templates_category_idx on public.task_templates (category, title);

alter table public.task_templates enable row level security;

drop policy if exists "templates_select" on public.task_templates;
drop policy if exists "templates_insert" on public.task_templates;
drop policy if exists "templates_update" on public.task_templates;
drop policy if exists "templates_delete" on public.task_templates;

create policy "templates_select" on public.task_templates for select
  using (auth.uid() is not null);

create policy "templates_insert" on public.task_templates for insert
  with check (public.get_my_role() in ('admin', 'super_admin'));

create policy "templates_update" on public.task_templates for update
  using (public.get_my_role() in ('admin', 'super_admin'));

create policy "templates_delete" on public.task_templates for delete
  using (public.get_my_role() in ('admin', 'super_admin'));


-- ============================================================================
-- HVEM STÅR PÅ EN OPGAVE?
--
-- Et medlem skal kunne se, hvem der allerede har taget tjansen, før de selv
-- melder sig. Tabellen kan de godt læse, men den indeholder kun user_id —
-- og navnet ligger i profiles, som kun udleverer udvalgte kolonner.
--
-- Funktionen giver navn, initialer og hold. Ikke e-mail og ikke telefon: at
-- vide hvem man står på vagt med er ikke det samme som at få deres
-- kontaktoplysninger.
-- ============================================================================

create or replace function public.task_signups(p_task uuid)
returns table (
  user_id  uuid,
  name     text,
  initials text,
  team     text,
  status   text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'Du skal være logget ind';
  end if;

  return query
    select p.id, p.name, p.initials, p.team, c.status
      from public.task_claims c
      join public.profiles p on p.id = c.user_id
     where c.task_id = p_task
     order by c.claimed_at;
end;
$$;

revoke execute on function public.task_signups(uuid) from public, anon;
grant  execute on function public.task_signups(uuid) to authenticated;


-- ============================================================================
-- EFTERSYN
--
--   select count(*) from public.task_templates;
--   select * from public.task_signups('<opgave-id>');
-- ============================================================================



-- ############################################################################
-- ## AFSNIT 13 af 21: 20260925220000_badges.sql
-- ############################################################################

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



-- ############################################################################
-- ## AFSNIT 14 af 21: 20260926060000_email_outbox.sql
-- ############################################################################

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



-- ############################################################################
-- ## AFSNIT 15 af 21: 20260926070000_slet_medlem_med_tjans.sql
-- ############################################################################

-- ============================================================================
-- ET MEDLEM MED EN TJANS KUNNE IKKE SLETTES
--
-- Fundet af testen til mailudbakken, og den har ingenting med mail at gøre.
--
-- Sletter man et medlem, falder rækkerne som dominobrikker: auth-brugeren
-- tager profilen, profilen tager tilmeldingerne. Og hver gang en tilmelding
-- forsvinder, skriver tc_after_delete en besked til medlemmet om, at det er
-- fjernet fra opgaven.
--
-- Men profilen er væk på det tidspunkt. Beskeden peger på et medlem, der
-- ikke findes længere, fremmednøglen siger fra, og HELE sletningen ruller
-- tilbage:
--
--   ERROR: insert or update on table "notifications" violates foreign key
--          constraint "notifications_user_id_fkey"
--
-- Det ramte præcis de medlemmer, der var aktive: fire af klubbens medlemmer
-- stod på en tjans og kunne derfor ikke slettes. Det er ikke en skønhedsfejl
-- — det er retten til at blive glemt, der ikke virkede.
--
-- Rettelsen er en linje: skriv kun beskeden, hvis medlemmet stadig er der.
-- Et medlem, der slettes, har ingen glæde af en besked om, at det er fjernet
-- fra en opgave.
-- ============================================================================

create or replace function public.tc_after_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.tasks
     set spots_left = least(spots_left + 1, spots_total)
   where id = old.task_id;

  if old.status = 'completed' then
    update public.profiles
       set points     = greatest(0, points - coalesce(old.points_awarded, 0)),
           tasks_done = greatest(0, tasks_done - 1)
     where id = old.user_id;
  end if;

  if auth.uid() is distinct from old.user_id
     and coalesce(current_setting('app.in_swap', true), '') <> 'on'
     and coalesce(current_setting('app.season_reset', true), '') <> 'on'
     -- Er profilen på vej ud ad døren, er der ingen at skrive til.
     and exists (select 1 from public.profiles where id = old.user_id) then
    insert into public.notifications (user_id, type, title, body, action_task_id)
    select old.user_id, 'task_unassigned',
           'Du er fjernet fra en opgave',
           t.title || ' · ' || t.date,
           t.id
      from public.tasks t where t.id = old.task_id;
  end if;

  return old;
end;
$$;



-- ############################################################################
-- ## AFSNIT 16 af 21: 20260926090000_tidligt_i_maal.sql
-- ############################################################################

-- ============================================================================
-- "TIDLIGT I MÅL" SKAL FØLGE MED, NÅR MÅLET ÆNDRER SIG
--
-- Klubben har besluttet, at frivilligbidraget gøres op mod ét mål pr.
-- opgørelse — 200 point i denne sæson. Mærket "Tidligt i mål" krævede hele
-- målet nået inden 1. december. Med 200 point på hele sæsonen er det ikke et
-- mærke længere, det er en umulighed.
--
-- Nu er reglen HALVDELEN af målet inden 1. december. Det er stadig noget,
-- man skal gøre sig umage for, og det er stadig sandt, når klubben skifter
-- målet igen.
--
-- Resten af funktionen er uændret; den skrives om i sin helhed, fordi det er
-- sådan, en funktion rettes i Postgres.
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
      -- Halvvejs inden 1. december. Foer stod der hele maalet, men maalet
      -- er nu det, der skal naas paa HELE opgoerelsen — og at have hele
      -- sæsonens point hjemme til december er ikke et maerke, det er en
      -- umulighed.
      (select coalesce(max(sum_pt), 0) >= v_goal / 2 from (
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



-- ############################################################################
-- ## AFSNIT 17 af 21: 20260926120000_hjaelpere.sql
-- ############################################################################

-- ============================================================================
-- HJÆLPERE
--
-- En forælder, en kæreste, en nabo — nogen, der ikke er medlem, men gerne
-- tager en tjans for et medlem. Klubben vil have dem ind i appen, og deres
-- arbejde skal tælle for medlemmet.
--
-- ---------------------------------------------------------------------------
-- DET HER ER IKKE POINTOVERFØRSEL. Og det er hele pointen.
--
-- I samme øjeblik appen kan flytte point fra én konto til en anden, findes
-- maskineriet — og så bliver det brugt mellem to medlemmer, "bare lige denne
-- ene gang", af en admin der vil nogen det godt. Derfor flytter ingenting
-- her. Point bliver liggende, hvor de blev tjent.
--
-- I stedet skrives det på selve tilmeldingen, HVEM tjansen tæller for
-- (task_claims.credited_to). Det står der for altid, også hvis koblingen
-- senere ændres, og det kan ses i en opgørelse et år efter.
--
-- ---------------------------------------------------------------------------
-- TO TAL, DER BETYDER HVER SIN TING
--
--   profiles.points      hvad man SELV har lavet.   → ranglisten
--   bidrag_point(id)     medlemmets egne + hjælpernes. → frivilligbidraget
--
-- Ranglisten er anerkendelse: en hjælper står der med sit eget navn og sine
-- egne point, for det var hende, der mødte op. Bidragsordningen er penge:
-- dér tæller det, husstanden har leveret.
--
-- Derfor rører denne migration IKKE de triggere, der lægger point til og
-- trækker fra. Det er appens mest ømtålelige kode, og den behøver ikke at
-- vide, at hjælpere findes.
-- ============================================================================


-- ------------------------------------------------------------ KOBLINGEN ---

create table if not exists public.helper_links (
  helper_id  uuid        not null references public.profiles(id) on delete cascade,
  member_id  uuid        not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  created_by uuid        references public.profiles(id) on delete set null,
  primary key (helper_id, member_id),
  constraint helper_ikke_sig_selv check (helper_id <> member_id)
);

comment on table public.helper_links is
  'Hvem hjælper hvem. En hjælper kan have flere medlemmer (fx to børn).';

create index if not exists helper_links_member_idx on public.helper_links (member_id);

alter table public.helper_links enable row level security;

-- Alle indloggede må se koblingerne: appen skal kunne skrive "hjælper for
-- Anna" på en tjans, og medlemmet skal kunne se, hvem der hjælper dem.
-- Der står ingen personoplysninger i tabellen — kun to id'er.
drop policy if exists helper_links_select on public.helper_links;
create policy helper_links_select on public.helper_links
  for select to authenticated using (true);

revoke all on public.helper_links from public, anon;
grant select on public.helper_links to authenticated;
-- Ingen skriver direkte. Det gør admin_set_helper() nedenfor.


-- ---------------------------------------------------------- ØNSKET VED ---
--
-- En hjælper kan ikke se medlemslisten, før hun er lukket ind — og skal
-- heller ikke kunne det. Derfor skriver hun ved oprettelsen bare navnet på
-- den, hun hjælper, i fri tekst. Admin læser det på godkendelseskortet og
-- vælger det rigtige medlem fra listen. Så er det ét menneske, der afgør
-- koblingen, og ikke en stavemåde.

alter table public.profiles
  add column if not exists helper_request text;

comment on column public.profiles.helper_request is
  'Fri tekst fra oprettelsen: "jeg hjælper Anna Berg". Ryddes, når admin har lavet koblingen.';


-- Navnet skal med fra oprettelsen ind i profilen. Resten af funktionen er
-- uændret; den skrives om i sin helhed, fordi det er sådan, en funktion
-- rettes i Postgres.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_is_bootstrap boolean;
begin
  v_is_bootstrap := new.email in ('formand@randersVK.dk', 'admin@randersVK.dk');

  insert into public.profiles (id, name, email, phone, team, role, approved, reviewed_at,
                               helper_request)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.email,
    nullif(new.raw_user_meta_data->>'phone', ''),
    coalesce(new.raw_user_meta_data->>'team', ''),
    case when v_is_bootstrap then 'super_admin' else 'user' end,
    v_is_bootstrap,
    case when v_is_bootstrap then now() else null end,
    -- Teksten er skrevet af en fremmed. 120 tegn er rigeligt til et navn,
    -- og sætter et loft over, hvad der kan lægges i databasen herfra.
    nullif(left(trim(coalesce(new.raw_user_meta_data->>'helper_for', '')), 120), '')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;


-- ------------------------------------------------- HVEM TÆLLER TJANSEN FOR ---

alter table public.task_claims
  add column if not exists credited_to uuid references public.profiles(id) on delete set null;

comment on column public.task_claims.credited_to is
  'Hvilket medlem tjansen tæller for i bidragsordningen. NULL = den, der tog den.';

create index if not exists task_claims_credited_idx
  on public.task_claims (credited_to) where credited_to is not null;

-- Et medlem må vælge modtager for sin egen tilmelding — men kun et medlem,
-- man rent faktisk er koblet til. Ellers ville "vælg modtager" være præcis
-- den pointoverførsel, vi ikke bygger.
create or replace function public.tc_check_credited_to()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.credited_to is null or new.credited_to = new.user_id then
    return new;
  end if;

  if not exists (
    select 1 from public.helper_links hl
     where hl.helper_id = new.user_id and hl.member_id = new.credited_to
  ) then
    raise exception 'Tjansen kan kun tælle for et medlem, du er hjælper for';
  end if;

  return new;
end;
$$;

drop trigger if exists tc_credited_to_check on public.task_claims;
create trigger tc_credited_to_check
  before insert or update of credited_to on public.task_claims
  for each row execute function public.tc_check_credited_to();


-- ------------------------------------------------------- BIDRAGSTALLET ---

create or replace function public.bidrag_point(p_user uuid)
returns int
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select greatest(0,
    coalesce((
      select sum(coalesce(tc.points_awarded, 0))::int
        from public.task_claims tc
       where tc.status = 'completed'
         and coalesce(tc.credited_to, tc.user_id) = p_user
    ), 0)
    + coalesce((select bonus_points from public.profiles where id = p_user), 0)
  );
$$;

comment on function public.bidrag_point(uuid) is
  'Point der tæller mod frivilligbidraget: egne tjanser + hjælpernes + bonus. Ranglisten bruger profiles.points i stedet.';


-- --------------------------------------------------- ER MAN HJÆLPER? ---

create or replace function public.er_hjaelper(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (select 1 from public.helper_links where helper_id = p_user);
$$;


-- ------------------------------------------------- ADMIN SÆTTER KOBLINGEN ---
--
-- Fire spærrer, og de er der hver af sin grund:
--
--   1. Kun admins. En kobling flytter, hvem der slipper for at betale.
--   2. Et MEDLEM MED POINT kan ikke gøres til hjælper. Det er den regel, der
--      lukker døren mellem to medlemmer: kan man ikke blive hjælper efter at
--      have tjent point, kan man heller ikke begynde at sende dem videre.
--   3. Den, man hjælper, må ikke selv være hjælper. Ingen kæder.
--   4. Alt havner i audit-loggen.

create or replace function public.admin_set_helper(
  p_helper uuid,
  p_member uuid,
  p_on     boolean default true
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_helper record;
  v_member record;
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan koble en hjælper til et medlem';
  end if;

  select id, name, points, role into v_helper from public.profiles where id = p_helper;
  select id, name into v_member from public.profiles where id = p_member;

  if v_helper.id is null then raise exception 'Hjælperen findes ikke'; end if;
  if v_member.id is null then raise exception 'Medlemmet findes ikke'; end if;

  if not p_on then
    delete from public.helper_links where helper_id = p_helper and member_id = p_member;
    insert into public.audit_log (type, action, actor_name, actor_id)
    select 'member',
           format('Fjernede %s som hjælper for %s', v_helper.name, v_member.name),
           coalesce(p.name, 'Ukendt'), p.id
      from public.profiles p where p.id = auth.uid();
    return;
  end if;

  if p_helper = p_member then
    raise exception 'Man kan ikke være hjælper for sig selv';
  end if;

  -- Har man allerede tjent point som medlem, kan man ikke blive hjælper.
  if not public.er_hjaelper(p_helper) and coalesce(v_helper.points, 0) > 0 then
    raise exception 'Kontoen har allerede optjent point som medlem og kan ikke gøres til hjælper';
  end if;

  if public.er_hjaelper(p_member) then
    raise exception 'Den, man hjælper, må ikke selv være hjælper';
  end if;

  if exists (select 1 from public.helper_links where member_id = p_helper) then
    raise exception 'Kontoen har selv hjælpere og kan ikke være hjælper for andre';
  end if;

  insert into public.helper_links (helper_id, member_id, created_by)
  values (p_helper, p_member, auth.uid())
  on conflict do nothing;

  -- Ønsket fra tilmeldingen er efterkommet, og skal ikke blive stående og
  -- se ud som noget, der mangler at blive gjort.
  update public.profiles set helper_request = null
   where id = p_helper and helper_request is not null;

  insert into public.audit_log (type, action, actor_name, actor_id)
  select 'member',
         format('Koblede %s som hjælper for %s', v_helper.name, v_member.name),
         coalesce(p.name, 'Ukendt'), p.id
    from public.profiles p where p.id = auth.uid();
end;
$$;


-- ------------------------------------------- HVEM HJÆLPER JEG / MIG? ---

create or replace function public.my_helper_members()
returns table (member_id uuid, name text, initials text, team text, givet int)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.id, p.name, p.initials, p.team,
         coalesce((
           select sum(coalesce(tc.points_awarded, 0))::int
             from public.task_claims tc
            where tc.user_id = auth.uid()
              and tc.status = 'completed'
              and tc.credited_to = p.id
         ), 0)
    from public.helper_links hl
    join public.profiles p on p.id = hl.member_id
   where hl.helper_id = auth.uid()
   order by p.name;
$$;

comment on function public.my_helper_members() is
  'Hvem hjælperen hjælper, og hvor mange point hun har givet hver af dem.';

create or replace function public.my_helpers()
returns table (helper_id uuid, name text, initials text, point int)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.id, p.name, p.initials,
         coalesce((
           select sum(coalesce(tc.points_awarded, 0))::int
             from public.task_claims tc
            where tc.user_id = p.id
              and tc.status = 'completed'
              and tc.credited_to = auth.uid()
         ), 0)
    from public.helper_links hl
    join public.profiles p on p.id = hl.helper_id
   where hl.member_id = auth.uid()
   order by p.name;
$$;


revoke all on function public.admin_set_helper(uuid, uuid, boolean) from public, anon;
revoke all on function public.bidrag_point(uuid)      from public, anon;
revoke all on function public.er_hjaelper(uuid)       from public, anon;
revoke all on function public.my_helper_members()     from public, anon;
revoke all on function public.my_helpers()            from public, anon;
revoke all on function public.tc_check_credited_to()  from public, anon, authenticated;

grant execute on function public.admin_set_helper(uuid, uuid, boolean) to authenticated;
grant execute on function public.bidrag_point(uuid)  to authenticated;
grant execute on function public.er_hjaelper(uuid)   to authenticated;
grant execute on function public.my_helper_members() to authenticated;
grant execute on function public.my_helpers()        to authenticated;


-- ============================================================================
-- DET, APPEN SKAL KUNNE LÆSE
-- ============================================================================

-- ------------------------------------------------------- MEDLEMMETS TAL ---
--
-- Ét kald med hele billedet, så måleren i appen ikke skal regne noget ud
-- selv. Fem tal, fordi de fortæller fem forskellige ting:
--
--   egne           det jeg selv har lavet og beholdt        (også ranglisten)
--   fra_hjaelpere  det min far eller min kæreste har lavet for mig
--   bonus          det admin har lagt til i hånden
--   bidrag         summen — den, bidragsordningen gør op mod målet
--   givet          det JEG har lavet for andre (kun hjælpere har et tal her)

create or replace function public.my_bidrag()
returns table (
  bidrag        int,
  egne          int,
  fra_hjaelpere int,
  bonus         int,
  givet         int,
  er_hjaelper   boolean
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with uid as (select auth.uid() as id),
  mine as (
    select coalesce(sum(coalesce(tc.points_awarded, 0)), 0)::int as sum_pt
      from public.task_claims tc, uid
     where tc.status = 'completed'
       and tc.user_id = uid.id
       and coalesce(tc.credited_to, tc.user_id) = uid.id
  ),
  udefra as (
    select coalesce(sum(coalesce(tc.points_awarded, 0)), 0)::int as sum_pt
      from public.task_claims tc, uid
     where tc.status = 'completed'
       and tc.credited_to = uid.id
       and tc.user_id <> uid.id
  ),
  videre as (
    select coalesce(sum(coalesce(tc.points_awarded, 0)), 0)::int as sum_pt
      from public.task_claims tc, uid
     where tc.status = 'completed'
       and tc.user_id = uid.id
       and tc.credited_to is not null
       and tc.credited_to <> uid.id
  ),
  bon as (
    select coalesce(p.bonus_points, 0) as pt
      from public.profiles p, uid where p.id = uid.id
  )
  select greatest(0, mine.sum_pt + udefra.sum_pt + coalesce(bon.pt, 0)),
         mine.sum_pt,
         udefra.sum_pt,
         coalesce(bon.pt, 0),
         videre.sum_pt,
         public.er_hjaelper((select id from uid))
    from mine, udefra, videre left join bon on true;
$$;

comment on function public.my_bidrag() is
  'Medlemmets eget bidragsregnskab, delt op så appen kan skrive hvor pointene kommer fra.';


-- ------------------------------------------------- SKIFT MODTAGER BAGEFTER ---
--
-- Hjælperen vælger modtager, når hun melder sig til. Rammer hun det forkerte
-- barn, skal hun ikke skulle melde fra og til igen — så mister hun pladsen,
-- hvis en anden har taget den i mellemtiden.
--
-- Medlemmer har ingen UPDATE-ret på task_claims. Derfor går rettelsen gennem
-- den her funktion, og kun på ens egen tilmelding. Triggeren ovenfor tjekker
-- alligevel koblingen én gang mere; et sikkerhedsnet, der ikke koster noget.

create or replace function public.set_claim_credit(p_claim uuid, p_member uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_ejer uuid;
begin
  select user_id into v_ejer from public.task_claims where id = p_claim;

  if v_ejer is null then
    raise exception 'Tilmeldingen findes ikke';
  end if;

  if v_ejer <> auth.uid() then
    raise exception 'Man kan kun vælge modtager på sin egen tilmelding';
  end if;

  update public.task_claims
     set credited_to = case when p_member = v_ejer then null else p_member end
   where id = p_claim;
end;
$$;


-- --------------------------------------------------- ADMINS MEDLEMSLISTE ---
--
-- Listen får fire nye kolonner. Returtypen ændrer sig, og en funktion med
-- ændret returtype skal fjernes først — "create or replace" kan ikke.

drop function if exists public.admin_list_members();

create or replace function public.admin_list_members()
returns table (
  id                 uuid,
  name               text,
  initials           text,
  email              text,
  phone              text,
  team               text,
  role               text,
  points             int,
  tasks_done         int,
  approved           boolean,
  reviewed_at        timestamptz,
  admin_requested    boolean,
  admin_requested_at timestamptz,
  created_at         timestamptz,
  -- Nyt: bidragstallet, og hvem der hjælper hvem.
  bidrag             int,
  fra_hjaelpere      int,
  er_hjaelper        boolean,
  hjaelper_for       text,
  helper_request     text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan se medlemmernes kontaktoplysninger';
  end if;

  return query
    select p.id, p.name, p.initials, p.email, p.phone, p.team, p.role,
           p.points, p.tasks_done, p.approved, p.reviewed_at,
           p.admin_requested, p.admin_requested_at, p.created_at,
           public.bidrag_point(p.id),
           coalesce((
             select sum(coalesce(tc.points_awarded, 0))::int
               from public.task_claims tc
              where tc.status = 'completed'
                and tc.credited_to = p.id
                and tc.user_id <> p.id
           ), 0),
           exists (select 1 from public.helper_links h where h.helper_id = p.id),
           (select string_agg(m.name, ', ' order by m.name)
              from public.helper_links h
              join public.profiles m on m.id = h.member_id
             where h.helper_id = p.id),
           p.helper_request
    from public.profiles p
    order by p.points desc, p.name;
end;
$$;


revoke all on function public.my_bidrag()                    from public, anon;
revoke all on function public.set_claim_credit(uuid, uuid)    from public, anon;
revoke all on function public.admin_list_members()            from public, anon;

grant execute on function public.my_bidrag()                 to authenticated;
grant execute on function public.set_claim_credit(uuid, uuid) to authenticated;
grant execute on function public.admin_list_members()         to authenticated;



-- ############################################################################
-- ## AFSNIT 18 af 21: 20260927080000_foraeldre.sql
-- ############################################################################

-- ============================================================================
-- FORÆLDRE: ET MEDLEM, DER OGSÅ GIVER POINT VIDERE
--
-- Hjælperne var det lette tilfælde: en far, der ikke selv spiller, og som
-- derfor ikke har noget mål at nå. Nu skal en forælder, der SELV er medlem,
-- kunne give point videre til sine børn.
--
-- ---------------------------------------------------------------------------
-- HVORFOR DET NU ER FORSVARLIGT — OG HVORFOR DET ALTID VAR DEN SAMME REGEL
--
-- Reglen "en konto med point kan ikke blive hjælper" lukkede døren mellem to
-- medlemmer. Den var grov. Det, der i virkeligheden beskytter ordningen, er
-- regnestykket:
--
--   EN TJANS TÆLLER FOR ÉN PERSON. ALDRIG TO.
--
-- Giver en forælder en tjans på 100 point videre til sit barn, falder
-- forælderens eget bidragstal med præcis 100. Intet bliver kopieret. Derfor
-- kan "deling" aldrig dække flere opgørelser, end der er lavet arbejde til:
-- 400 point dækker to mål på 200, fordi det ER 400 points arbejde.
--
-- Det, der ville være snyd — at forælderen beholder sine 400 OG barnet får
-- 200 — er umuligt, ikke forbudt. coalesce(credited_to, user_id) kan kun
-- pege på én person ad gangen.
--
-- ---------------------------------------------------------------------------
-- TO SLAGS KOBLING, FORDI DE BETYDER TO FORSKELLIGE TING
--
--   'helper'  spiller ikke selv. Har intet mål. Står IKKE på bidragslisten.
--   'parent'  er medlem med sit eget mål, og giver noget af det videre.
--
-- Forskellen kan ikke regnes ud af databasen — et barn er blot et andet
-- medlem. Det er et menneske, der ved, om kontoen også spiller selv, og
-- derfor er det admin, der siger det, når koblingen laves.
--
-- Den ENE ting, der stadig er spærret, er ringen: giver A videre til B, kan
-- B ikke give videre til A. To medlemmer, der sender point rundt i en rundkreds,
-- er ikke en familie — og selv om regnestykket holder, skal ordningen kunne
-- forklares på et bestyrelsesmøde.
-- ============================================================================


-- ------------------------------------------------------- SLAGS PÅ KOBLINGEN ---

alter table public.helper_links
  add column if not exists kind text not null default 'helper';

do $$
begin
  alter table public.helper_links
    add constraint helper_links_kind_check check (kind in ('helper', 'parent'));
exception when duplicate_object then null;
end $$;

comment on column public.helper_links.kind is
  '''helper'' = spiller ikke selv, har intet eget mål. ''parent'' = medlem med eget mål, der giver point videre.';


-- Har kontoen kun 'helper'-koblinger, har den intet eget mål og hører ikke på
-- bidragslisten. Har den bare én 'parent'-kobling, er den et medlem som alle
-- andre — der også giver noget videre.
create or replace function public.kun_hjaelper(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (select 1 from public.helper_links where helper_id = p_user)
     and not exists (select 1 from public.helper_links
                      where helper_id = p_user and kind = 'parent');
$$;

comment on function public.kun_hjaelper(uuid) is
  'Sandt for en ren hjælper: nogen der tager tjanser for andre og ikke selv har et mål at nå.';


-- ------------------------------------------------- ADMIN SÆTTER KOBLINGEN ---
--
-- Signaturen får et argument mere, og en funktion kan ikke skifte signatur.
-- Den gamle fjernes med vilje: stod den tilbage, kunne et kald med tre
-- argumenter gå forbi det nye og lave en kobling uden slags.

drop function if exists public.admin_set_helper(uuid, uuid, boolean);

create or replace function public.admin_set_helper(
  p_helper uuid,
  p_member uuid,
  p_on     boolean default true,
  p_kind   text    default 'helper'
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_helper record;
  v_member record;
  v_ord    text;
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan koble en hjælper til et medlem';
  end if;

  if p_kind not in ('helper', 'parent') then
    raise exception 'Koblingen skal være enten hjælper eller forælder';
  end if;

  select id, name, points into v_helper from public.profiles where id = p_helper;
  select id, name        into v_member from public.profiles where id = p_member;

  if v_helper.id is null then raise exception 'Hjælperen findes ikke'; end if;
  if v_member.id is null then raise exception 'Medlemmet findes ikke'; end if;

  v_ord := case when p_kind = 'parent' then 'forælder' else 'hjælper' end;

  if not p_on then
    delete from public.helper_links where helper_id = p_helper and member_id = p_member;
    insert into public.audit_log (type, action, actor_name, actor_id)
    select 'member',
           format('Fjernede %s som %s for %s', v_helper.name, v_ord, v_member.name),
           coalesce(p.name, 'Ukendt'), p.id
      from public.profiles p where p.id = auth.uid();
    return;
  end if;

  if p_helper = p_member then
    raise exception 'Man kan ikke give point videre til sig selv';
  end if;

  -- Kun den RENE hjælper skal være uden point. En forælder ER et medlem og
  -- har naturligvis point — det er hele grunden til, at hun kan give nogle
  -- af dem videre.
  if p_kind = 'helper'
     and not public.er_hjaelper(p_helper)
     and coalesce(v_helper.points, 0) > 0 then
    raise exception 'Kontoen har allerede optjent point som medlem. Kobl den som forælder, hvis personen selv spiller';
  end if;

  -- Ingen ringe. Kæder er i orden — mormor kan give videre til sin søn, der
  -- giver videre til sit barn — for en tjans peger altid på ÉN person, og
  -- point hopper ikke videre af sig selv. Men en rundkreds skal ikke kunne
  -- opstå: den ser ud som to medlemmer, der deler.
  if exists (
    with recursive videre as (
      select hl.member_id as knude
        from public.helper_links hl
       where hl.helper_id = p_member
      union
      select hl.member_id
        from public.helper_links hl
        join videre v on hl.helper_id = v.knude
    )
    select 1 from videre where knude = p_helper
  ) then
    raise exception '% giver allerede point videre til % — den kobling ville lave en ring',
      v_member.name, v_helper.name;
  end if;

  insert into public.helper_links (helper_id, member_id, created_by, kind)
  values (p_helper, p_member, auth.uid(), p_kind)
  on conflict (helper_id, member_id) do update set kind = excluded.kind;

  update public.profiles set helper_request = null
   where id = p_helper and helper_request is not null;

  insert into public.audit_log (type, action, actor_name, actor_id)
  select 'member',
         format('Koblede %s som %s for %s', v_helper.name, v_ord, v_member.name),
         coalesce(p.name, 'Ukendt'), p.id
    from public.profiles p where p.id = auth.uid();
end;
$$;


-- ------------------------------------------- HVEM GIVER JEG VIDERE TIL? ---

drop function if exists public.my_helper_members();

create or replace function public.my_helper_members()
returns table (member_id uuid, name text, initials text, team text, givet int, kind text)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.id, p.name, p.initials, p.team,
         coalesce((
           select sum(coalesce(tc.points_awarded, 0))::int
             from public.task_claims tc
            where tc.user_id = auth.uid()
              and tc.status = 'completed'
              and tc.credited_to = p.id
         ), 0),
         hl.kind
    from public.helper_links hl
    join public.profiles p on p.id = hl.member_id
   where hl.helper_id = auth.uid()
   order by p.name;
$$;

comment on function public.my_helper_members() is
  'Hvem man giver point videre til, hvor mange man har givet hver af dem, og om man selv er medlem (parent) eller kun hjælper.';


-- ------------------------------------------------------- MEDLEMMETS TAL ---
--
-- Ét nyt felt: kun_hjaelper. Uden det kan appen ikke se forskel på en far,
-- der ikke spiller, og en mor, der gør — og de skal have to forskellige
-- forsider, fordi den ene har et mål at nå og den anden ikke har.

drop function if exists public.my_bidrag();

create or replace function public.my_bidrag()
returns table (
  bidrag        int,
  egne          int,
  fra_hjaelpere int,
  bonus         int,
  givet         int,
  er_hjaelper   boolean,
  kun_hjaelper  boolean
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with uid as (select auth.uid() as id),
  mine as (
    select coalesce(sum(coalesce(tc.points_awarded, 0)), 0)::int as sum_pt
      from public.task_claims tc, uid
     where tc.status = 'completed'
       and tc.user_id = uid.id
       and coalesce(tc.credited_to, tc.user_id) = uid.id
  ),
  udefra as (
    select coalesce(sum(coalesce(tc.points_awarded, 0)), 0)::int as sum_pt
      from public.task_claims tc, uid
     where tc.status = 'completed'
       and tc.credited_to = uid.id
       and tc.user_id <> uid.id
  ),
  videre as (
    select coalesce(sum(coalesce(tc.points_awarded, 0)), 0)::int as sum_pt
      from public.task_claims tc, uid
     where tc.status = 'completed'
       and tc.user_id = uid.id
       and tc.credited_to is not null
       and tc.credited_to <> uid.id
  ),
  bon as (
    select coalesce(p.bonus_points, 0) as pt
      from public.profiles p, uid where p.id = uid.id
  )
  select greatest(0, mine.sum_pt + udefra.sum_pt + coalesce(bon.pt, 0)),
         mine.sum_pt,
         udefra.sum_pt,
         coalesce(bon.pt, 0),
         videre.sum_pt,
         public.er_hjaelper((select id from uid)),
         public.kun_hjaelper((select id from uid))
    from mine, udefra, videre left join bon on true;
$$;

comment on function public.my_bidrag() is
  'Medlemmets eget bidragsregnskab, delt op så appen kan skrive hvor pointene kommer fra, og hvor de er gået hen.';


-- ------------------------------------------------- FLYT EN TJANS BAGEFTER ---
--
-- En forælder har som regel allerede taget tjanserne, når hun opdager, at
-- barnet mangler point. Derfor skal en BEKRÆFTET tjans også kunne flyttes.
-- Pointene bliver hos forælderen på ranglisten — det var hende, der mødte op
-- — men de tæller fra nu af hos barnet i bidragsordningen.
--
-- Flytter man en tjans, der allerede er gjort op, står det i audit-loggen.
-- Det er penge, der flytter sig, og det skal kunne læses et år efter.

create or replace function public.set_claim_credit(p_claim uuid, p_member uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_krav   record;
  v_navn   text;
  v_opgave text;
begin
  select tc.user_id, tc.status, tc.points_awarded, tc.credited_to, t.title
    into v_krav
    from public.task_claims tc
    join public.tasks t on t.id = tc.task_id
   where tc.id = p_claim;

  if v_krav.user_id is null then
    raise exception 'Tilmeldingen findes ikke';
  end if;

  if v_krav.user_id <> auth.uid() then
    raise exception 'Man kan kun vælge modtager på sin egen tilmelding';
  end if;

  update public.task_claims
     set credited_to = case when p_member = v_krav.user_id then null else p_member end
   where id = p_claim;

  if v_krav.status = 'completed'
     and coalesce(v_krav.credited_to, v_krav.user_id) is distinct from p_member then
    select name into v_navn from public.profiles where id = p_member;
    insert into public.audit_log (type, action, actor_name, actor_id)
    select 'member',
           format('Flyttede %s point fra "%s" til %s',
                  coalesce(v_krav.points_awarded, 0), v_krav.title,
                  coalesce(v_navn, 'sig selv')),
           coalesce(p.name, 'Ukendt'), p.id
      from public.profiles p where p.id = auth.uid();
  end if;
end;
$$;


-- --------------------------------------------------- ADMINS MEDLEMSLISTE ---

drop function if exists public.admin_list_members();

create or replace function public.admin_list_members()
returns table (
  id                 uuid,
  name               text,
  initials           text,
  email              text,
  phone              text,
  team               text,
  role               text,
  points             int,
  tasks_done         int,
  approved           boolean,
  reviewed_at        timestamptz,
  admin_requested    boolean,
  admin_requested_at timestamptz,
  created_at         timestamptz,
  bidrag             int,
  fra_hjaelpere      int,
  er_hjaelper        boolean,
  kun_hjaelper       boolean,
  givet_videre       int,
  hjaelper_for       text,
  helper_request     text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan se medlemmernes kontaktoplysninger';
  end if;

  return query
    select p.id, p.name, p.initials, p.email, p.phone, p.team, p.role,
           p.points, p.tasks_done, p.approved, p.reviewed_at,
           p.admin_requested, p.admin_requested_at, p.created_at,
           public.bidrag_point(p.id),
           coalesce((
             select sum(coalesce(tc.points_awarded, 0))::int
               from public.task_claims tc
              where tc.status = 'completed'
                and tc.credited_to = p.id
                and tc.user_id <> p.id
           ), 0),
           public.er_hjaelper(p.id),
           public.kun_hjaelper(p.id),
           coalesce((
             select sum(coalesce(tc.points_awarded, 0))::int
               from public.task_claims tc
              where tc.status = 'completed'
                and tc.user_id = p.id
                and tc.credited_to is not null
                and tc.credited_to <> p.id
           ), 0),
           (select string_agg(m.name, ', ' order by m.name)
              from public.helper_links h
              join public.profiles m on m.id = h.member_id
             where h.helper_id = p.id),
           p.helper_request
    from public.profiles p
    order by p.points desc, p.name;
end;
$$;


revoke all on function public.kun_hjaelper(uuid)                            from public, anon;
revoke all on function public.admin_set_helper(uuid, uuid, boolean, text)   from public, anon;
revoke all on function public.my_helper_members()                           from public, anon;
revoke all on function public.my_bidrag()                                   from public, anon;
revoke all on function public.set_claim_credit(uuid, uuid)                  from public, anon;
revoke all on function public.admin_list_members()                          from public, anon;

grant execute on function public.kun_hjaelper(uuid)                          to authenticated;
grant execute on function public.admin_set_helper(uuid, uuid, boolean, text) to authenticated;
grant execute on function public.my_helper_members()                         to authenticated;
grant execute on function public.my_bidrag()                                 to authenticated;
grant execute on function public.set_claim_credit(uuid, uuid)                to authenticated;
grant execute on function public.admin_list_members()                        to authenticated;



-- ############################################################################
-- ## AFSNIT 19 af 21: 20260929090000_skabeloner.sql
-- ############################################################################

-- ============================================================================
-- ÉN LISTE SKABELONER, SOM KLUBBEN EJER
--
-- Der var to slags, og kun den ene kunne klubben røre:
--
--   Appens forslag   40 stykker, hårdkodet i admin.jsx. Uændrede for evigt,
--                    eller rettere: indtil nogen retter i koden.
--   Klubbens egne    i databasen. Kunne oprettes og slettes.
--
-- Det var ikke to slags data. Det var ét datasæt, hvor halvdelen lå det
-- forkerte sted. En klub, der har brugt appen et halvt år, ved bedre end
-- koden, hvad der står i deres kioskvagt.
--
-- Nu ligger de 40 i databasen som almindelige rækker. Alt kan rettes,
-- omdøbes og slettes — og hentes tilbage igen med seed_task_templates(),
-- som kun lægger det ind, der mangler. Derfor kan den køres igen uden at
-- lave dubletter, og uden at skrive hen over noget, klubben selv har rettet.
--
-- Rækkerne herunder er IKKE skrevet af i hånden. De er lavet af et script,
-- der læser de samme lister, appen selv bruger — også ikonforslaget, så en
-- skabelon får præcis det ikon, den fik før.
-- ============================================================================


-- ------------------------------------------------------------ HVEM RETTEDE ---
--
-- Når en liste kan ændres af flere, er "hvem rettede den, og hvornår" det
-- første spørgsmål, der bliver stillet.

alter table public.task_templates
  add column if not exists updated_at timestamptz,
  add column if not exists updated_by uuid references public.profiles(id) on delete set null;

create or replace function public.tt_stamp()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end;
$$;

drop trigger if exists task_templates_stamp on public.task_templates;
create trigger task_templates_stamp
  before update on public.task_templates
  for each row execute function public.tt_stamp();


-- ------------------------------------------------------- APPENS FORSLAG ---
--
-- Funktionen bærer originalerne. Står de kun i en migration, kan de ikke
-- hentes frem igen den dag, nogen har slettet for meget — og så er en
-- "gendan"-knap et løfte, appen ikke kan holde.

create or replace function public.seed_task_templates()
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_antal int;
begin
  -- Ingen session betyder, at det er serveren selv (migrationen). Er der en
  -- session, skal den tilhøre en admin.
  if auth.uid() is not null
     and public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan hente appens forslag tilbage';
  end if;

  with nye as (
    insert into public.task_templates
      (category, title, points, difficulty, icon, description, spots_total, duration_type)
    select v.category, v.title, v.points, v.difficulty, v.icon, v.description, 2, 'single'
    from (values
    ('Kampafvikling & Sekretærbord', 'Dømme kampe som klubdommer (lokalrækker)', 15, 'Medium', 'whistle', 'Døm en kamp i lokalrækkerne som klubdommer.
Mød op 15 min. før kampstart.
Aflever kampskema til halsoveren efter kampen.'),
    ('Kampafvikling & Sekretærbord', 'Sekretærbordet – elektronisk holdkort/point', 10, 'Let', 'scorecard', 'Sid ved sekretærbordet og før elektronisk holdkort.
Vær på plads senest 20 min. før kampstart.
Kontakt kampansvarlig ved tvivl.'),
    ('Kampafvikling & Sekretærbord', 'Halspeaker til divisions-/hjemmekamp', 10, 'Let', 'speaker', 'Vær halspeaker ved hjemmekampe.
Annoncér hold, spillerskift og resultater.
Brug klubbens speaker-udstyr.'),
    ('Kampafvikling & Sekretærbord', 'Linjedommer til stor kamp', 10, 'Let', 'whistle', 'Vær linjedommer ved en større kamp.
Mød op 30 min. før kampstart til briefing.
Følg dommernes anvisninger under kampen.'),
    ('Kampafvikling & Sekretærbord', 'Opsætning/nedtagning af bane og net', 5, 'Let', 'net', 'Opsæt eller tag baner og net ned ved kampdag.
Tjek at net er i korrekt højde.
Læg alt udstyr tilbage på rette plads.'),
    ('Kampafvikling & Sekretærbord', 'Kampansvarlig/Halsover', 15, 'Medium', 'key', 'Mød op som den første og lås hallen op.
Sørg for at alt er klar til kampen.
Luk hallen og aflevér nøgler til rette vedkommende.'),
    ('Hygge og Socialt', 'Formand for festudvalget (Sæson)', 75, 'Hård', 'committee', 'Vær formand for festudvalget hele sæsonen.
Planlæg og koordinér alle sociale arrangementer.
Rapportér til bestyrelsen.'),
    ('Hygge og Socialt', 'Udvalgsmedlem i festudvalget (Sæson)', 40, 'Medium', 'committee', 'Deltag aktivt i festudvalgets arbejde hele sæsonen.
Hjælp med planlægning og praktisk afholdelse af arrangementer.'),
    ('Hygge og Socialt', 'Klargøring og madlavning til fællesspisning', 15, 'Let', 'food', 'Hjælp med at klargøre og lave mad til fællesspisning.
Mød op 1 time før arrangementet starter.
Ryd op bagefter.'),
    ('Hygge og Socialt', 'Kioskvagt til alm. hjemmekamp (ca. 2-3 timer)', 10, 'Let', 'kiosk', 'Bemand kiosken under en hjemmekamp.
Sørg for at varer er fyldt op.
Aflever kassen til kassereren efter kampen.'),
    ('Hygge og Socialt', 'Bage kage / lave madpakker til et hold', 5, 'Let', 'cake', 'Bag kage eller lav madpakker til et hold.
Aftaler omfang med holdleder.'),
    ('Hygge og Socialt', 'Oprydning/Rengøring efter klubfest', 15, 'Let', 'clean', 'Hjælp med oprydning og rengøring efter klubfest eller arrangement.
Bliv til alt er ryddet op og hallen er klar til næste brug.'),
    ('Hygge og Socialt', 'Indkøber til kiosken (Sæson)', 50, 'Medium', 'kiosk', 'Stå for indkøb til klubkiosken hele sæsonen.
Hold styr på lagerstatus og bestil varer.
Sørg for at priser er opdaterede.'),
    ('Holdleder & Transport', 'Fast holdleder for et ungdoms- eller seniorhold (Sæson)', 75, 'Hård', 'car', 'Vær fast holdleder for et hold hele sæsonen.
Kommunikér med forældre, spillere og trænere.
Sørg for tilmelding, kørsel og praktiske forhold.'),
    ('Holdleder & Transport', 'Kørsel til udekamp inkl. heppekor', 15, 'Let', 'car', 'Kør spillere til udekamp og hep holdet under kampen.
Aftaler mødested og tidspunkt med holdleder.
Sørg for at alle kommer sikkert hjem.'),
    ('Holdleder & Transport', 'Kørsel til udekamp – kun aflevering/afhentning', 5, 'Let', 'car', 'Kør spillere til eller fra udekamp.
Aftaler tidspunkt og sted med holdleder.'),
    ('Holdleder & Transport', 'Fast vaskemaskine – holdets trøjer hele sæsonen', 50, 'Medium', 'laundry', 'Vask holdets spillertøj efter samtlige kampe og stævner hele sæsonen.
Aftaler afhentning og aflevering med holdleder.'),
    ('Holdleder & Transport', 'Vask af spillertøj efter én kamp/stævne', 5, 'Let', 'laundry', 'Vask holdets spillertøj efter én kamp eller et stævne.
Aftaler afhentning og aflevering med holdleder.'),
    ('Stævneplanlægning og Afholdelse', 'Stævneleder/Hovedansvarlig for klubbens eget stævne', 75, 'Hård', 'trophy', 'Vær overordnet ansvarlig for afviklingen af et klubstævne.
Koordinér alle frivillige og leverandører.
Sørg for at stævneprogrammet følges.'),
    ('Stævneplanlægning og Afholdelse', 'Medlem af stævneudvalg (planlægning)', 40, 'Medium', 'committee', 'Deltag i planlægningen af klubbens stævne.
Mød til udvalgets møder og tag ansvar for aftalte opgaver.'),
    ('Stævneplanlægning og Afholdelse', 'Natvagt/Halsover ved overnatningsstævne', 30, 'Medium', 'tent', 'Vær halsover om natten ved overnatningsstævne (ca. kl. 23–07).
Sørg for ro og tryghed for de deltagende unge.'),
    ('Stævneplanlægning og Afholdelse', 'Stævnesekretariatet – registrér resultater (halvdags)', 20, 'Let', 'scorecard', 'Sid i stævnesekretariatet og registrér resultater og tider.
Styr kampuret og koordinér med dommerne.'),
    ('Stævneplanlægning og Afholdelse', 'Kioskvagt ved stort weekendstævne (vagt á 3 timer)', 15, 'Let', 'kiosk', 'Bemand kiosken i 3 timer under weekendstævnet.
Sørg for at varer er fyldt op løbende.'),
    ('Stævneplanlægning og Afholdelse', 'Opsætning fredag aften inden stævne / Hovedrengøring søndag', 15, 'Let', 'net', 'Hjælp med at sætte hallen op fredag aften eller stå for hovedrengøring søndag.
Følg stævnelederens anvisninger.'),
    ('Kommunikation & PR', 'Webmaster / Hovedansvarlig for SoMe (Sæson)', 75, 'Hård', 'megaphone', 'Vær ansvarlig for klubbens hjemmeside og sociale medier hele sæsonen.
Post regelmæssige opdateringer og resultater.
Koordinér indhold med bestyrelsen.'),
    ('Kommunikation & PR', 'Sponsorudvalg (Sæson – indhente sponsorer)', 75, 'Hård', 'committee', 'Vær en del af sponsorudvalget og indhent sponsorer til klubben hele sæsonen.
Kontakt lokale virksomheder og lav sponsoraftaler.'),
    ('Kommunikation & PR', 'Fotograf til kampdag/stævne inkl. redigering og deling', 15, 'Let', 'camera', 'Tag billeder ved en kampdag eller stævne.
Redigér udvalgte billeder og del med klubben.
Brug klubbens fotokanaler til deling.'),
    ('Kommunikation & PR', 'Skrive kampreferater / artikler til hjemmeside/Facebook', 10, 'Let', 'web', 'Skriv et kort kampreferat eller en artikel til hjemmeside eller Facebook.
Aflever tekst til SoMe-ansvarlig senest dagen efter kampen.'),
    ('Kommunikation & PR', 'Lave grafisk materiale (plakater, opslag, stævneprogram)', 10, 'Let', 'gear', 'Lav grafisk materiale til klubbens aktiviteter.
Brug klubbens farver og logo.
Aflever filer til SoMe-ansvarlig i aftalt format.'),
    ('Kommunikation & PR', 'Dele flyers / hænge plakater op i lokalområdet', 5, 'Let', 'flyer', 'Del flyers eller hæng plakater op i lokalområdet.
Få materiale udleveret af SoMe-ansvarlig.
Indmeld hvilke steder du har besøgt.'),
    ('Faciliteter & Materialer', 'Materialeansvarlig (Sæson)', 75, 'Hård', 'gear', 'Hold overblik over bolde, tøj, net og øvrigt udstyr hele sæsonen.
Registrér slitage og bestil nyt ved behov.
Rapportér til bestyrelsen.'),
    ('Faciliteter & Materialer', 'Klargøring af beachvolleyball-baner (arbejdsdag)', 20, 'Medium', 'net', 'Hjælp med at klargøre beachvolleyball-banerne til sæsonen.
Mød op til den aftalte arbejdsdag.
Medtag egnet fodtøj og arbejdstøj.'),
    ('Faciliteter & Materialer', 'Vedligehold af beach-baner (luge ukrudt, rive baner)', 10, 'Let', 'net', 'Vedligehold beachbanerne ved at luge ukrudt og rive sand.
Ca. 2 timers arbejde pr. gang.'),
    ('Faciliteter & Materialer', 'Hovedoprydning og organisering af boldrum', 15, 'Let', 'gear', 'Ryd op og organiser klubbens boldrum.
Sørg for at alt udstyr er på rette plads og mærket.'),
    ('Faciliteter & Materialer', 'Småreparationer (sy net, fikse boldvogne, pumpe bolde)', 10, 'Let', 'tools', 'Foretag småreparationer på klubbens udstyr.
Sy net, reparer boldvogne eller pump bolde.
Rapportér større skader til materialeansvarlig.'),
    ('Klubadministration', 'Bestyrelsesmedlem (Formand, Kasserer m.fl.)', 100, 'Hård', 'board', 'Sidder i klubbens bestyrelse hele sæsonen.
Deltager i bestyrelsesmøder og varetager bestyrelsespost.
Rapporterer til generalforsamlingen.'),
    ('Klubadministration', 'Revisor / Økonomisk hjælp (Sæson)', 40, 'Medium', 'money', 'Hjælp med revision eller økonomi hele sæsonen.
Gennemgå regnskab og bilag.
Rapportér til kassereren.'),
    ('Klubadministration', 'Børneattest-ansvarlig (Sæson)', 40, 'Medium', 'board', 'Indhent og tjek børneattester for alle relevante frivillige.
Hold register opdateret hele sæsonen.
Rapportér mangler til formanden.'),
    ('Klubadministration', 'Hjælp til medlemsregistrering og kontingentkørsel', 25, 'Let', 'car', 'Hjælp med at registrere nye medlemmer og køre kontingentopkrævning.
Aftaler opgaveomfang med kassereren.'),
    ('Klubadministration', 'Fonds-ansøger (skrive og sende fondansøgninger)', 25, 'Medium', 'board', 'Skriv og send ansøgninger til fonde og puljer på vegne af klubben.
Koordinér med bestyrelsen om behovsområder.
Rapportér svar og tildelinger.')
    ) as v(category, title, points, difficulty, icon, description)
    -- Rører ikke det, klubben selv har rettet eller oprettet.
    on conflict (category, title) do nothing
    returning 1
  )
  select count(*) into v_antal from nye;

  return v_antal;
end;
$$;

comment on function public.seed_task_templates() is
  'Lægger appens 40 oprindelige skabeloner ind. Kun dem der mangler — kan køres igen uden at lave dubletter eller overskrive klubbens rettelser.';

revoke all on function public.seed_task_templates() from public, anon;
grant execute on function public.seed_task_templates() to authenticated;
revoke all on function public.tt_stamp() from public, anon, authenticated;

-- Politikken kræver allerede en session, så anonyme får ingen rækker. Men
-- rettigheden på tabellen lå der stadig, og resten af appen har vænnet sig
-- til at trække den slags tilbage eksplicit: to spærrer, ikke én.
revoke all on public.task_templates from anon;


-- ------------------------------------------------------------ KØR DEN NU ---

do $$
declare v int;
begin
  select public.seed_task_templates() into v;
  raise notice 'skabeloner lagt ind: %', v;
end $$;



-- ############################################################################
-- ## AFSNIT 20 af 21: 20260929100000_dobbelte_point.sql
-- ############################################################################

-- ============================================================================
-- DOBBELTE POINT
--
-- Bestyrelsen vil gøre det mere attraktivt at være frivillig, og fordobler
-- derfor pointtallet på alt. En kioskvagt går fra 10 til 20, en
-- bestyrelsespost fra 75 til 150.
--
-- ---------------------------------------------------------------------------
-- HVAD DER SKER MED DEM, DER ALLEREDE HAR GJORT ARBEJDET
--
-- Triggeren task_points_changed() sørger for resten af sig selv: den
-- opdaterer points_awarded på alle tilmeldinger, justerer summen for dem,
-- hvis tjans allerede er gjort op, og giver dem besked. Det er med vilje —
-- den, der tog kioskvagten i september, skal ikke stå tilbage med det halve
-- af den, der tager den i oktober.
--
-- Derfor ét enkelt update. Ikke fordi det er smart, men fordi regnskabet
-- allerede ved, hvad det skal gøre, når en opgave skifter værdi.
--
-- ---------------------------------------------------------------------------
-- MÅLET ER IKKE ÆNDRET HER
--
-- point_goal står stadig på 200. Når alle tal fordobles og målet bliver
-- stående, er barren i praksis halveret: der skal fremover det halve
-- arbejde til for at slippe for frivilligbidraget. Det kan udmærket være
-- meningen — men det er en beslutning om penge, ikke om point, og den
-- træffes under Admin → Indstillinger, ikke her.
-- ============================================================================


-- ------------------------------------------------------------- OPGAVERNE ---

update public.tasks set points = points * 2;


-- ----------------------------------------------------------- SKABELONERNE ---
--
-- Ellers ville den næste kioskvagt, nogen opretter fra skabelonen, være
-- halvt så meget værd som den, der allerede står i listen.

update public.task_templates set points = points * 2;


-- ------------------------------------------------- OG APPENS EGNE FORSLAG ---
--
-- seed_task_templates() bærer originalerne, og "Gendan appens forslag"
-- henter dem derfra. Blev de stående på de gamle tal, ville en slettet og
-- gendannet skabelon stille og roligt være det halve værd — og ingen ville
-- opdage det før næste sæson. Funktionen skrives om med de nye tal.
--
-- Rækkerne er igen ikke skrevet af i hånden: de er de samme som i
-- 20260929090000_skabeloner.sql, med pointtallet ganget med to af et script.

create or replace function public.seed_task_templates()
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_antal int;
begin
  if auth.uid() is not null
     and public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan hente appens forslag tilbage';
  end if;

  with nye as (
    insert into public.task_templates
      (category, title, points, difficulty, icon, description, spots_total, duration_type)
    select v.category, v.title, v.points, v.difficulty, v.icon, v.description, 2, 'single'
    from (values
    ('Kampafvikling & Sekretærbord', 'Dømme kampe som klubdommer (lokalrækker)', 30, 'Medium', 'whistle', 'Døm en kamp i lokalrækkerne som klubdommer.
Mød op 15 min. før kampstart.
Aflever kampskema til halsoveren efter kampen.'),
    ('Kampafvikling & Sekretærbord', 'Sekretærbordet – elektronisk holdkort/point', 20, 'Let', 'scorecard', 'Sid ved sekretærbordet og før elektronisk holdkort.
Vær på plads senest 20 min. før kampstart.
Kontakt kampansvarlig ved tvivl.'),
    ('Kampafvikling & Sekretærbord', 'Halspeaker til divisions-/hjemmekamp', 20, 'Let', 'speaker', 'Vær halspeaker ved hjemmekampe.
Annoncér hold, spillerskift og resultater.
Brug klubbens speaker-udstyr.'),
    ('Kampafvikling & Sekretærbord', 'Linjedommer til stor kamp', 20, 'Let', 'whistle', 'Vær linjedommer ved en større kamp.
Mød op 30 min. før kampstart til briefing.
Følg dommernes anvisninger under kampen.'),
    ('Kampafvikling & Sekretærbord', 'Opsætning/nedtagning af bane og net', 10, 'Let', 'net', 'Opsæt eller tag baner og net ned ved kampdag.
Tjek at net er i korrekt højde.
Læg alt udstyr tilbage på rette plads.'),
    ('Kampafvikling & Sekretærbord', 'Kampansvarlig/Halsover', 30, 'Medium', 'key', 'Mød op som den første og lås hallen op.
Sørg for at alt er klar til kampen.
Luk hallen og aflevér nøgler til rette vedkommende.'),
    ('Hygge og Socialt', 'Formand for festudvalget (Sæson)', 150, 'Hård', 'committee', 'Vær formand for festudvalget hele sæsonen.
Planlæg og koordinér alle sociale arrangementer.
Rapportér til bestyrelsen.'),
    ('Hygge og Socialt', 'Udvalgsmedlem i festudvalget (Sæson)', 80, 'Medium', 'committee', 'Deltag aktivt i festudvalgets arbejde hele sæsonen.
Hjælp med planlægning og praktisk afholdelse af arrangementer.'),
    ('Hygge og Socialt', 'Klargøring og madlavning til fællesspisning', 30, 'Let', 'food', 'Hjælp med at klargøre og lave mad til fællesspisning.
Mød op 1 time før arrangementet starter.
Ryd op bagefter.'),
    ('Hygge og Socialt', 'Kioskvagt til alm. hjemmekamp (ca. 2-3 timer)', 20, 'Let', 'kiosk', 'Bemand kiosken under en hjemmekamp.
Sørg for at varer er fyldt op.
Aflever kassen til kassereren efter kampen.'),
    ('Hygge og Socialt', 'Bage kage / lave madpakker til et hold', 10, 'Let', 'cake', 'Bag kage eller lav madpakker til et hold.
Aftaler omfang med holdleder.'),
    ('Hygge og Socialt', 'Oprydning/Rengøring efter klubfest', 30, 'Let', 'clean', 'Hjælp med oprydning og rengøring efter klubfest eller arrangement.
Bliv til alt er ryddet op og hallen er klar til næste brug.'),
    ('Hygge og Socialt', 'Indkøber til kiosken (Sæson)', 100, 'Medium', 'kiosk', 'Stå for indkøb til klubkiosken hele sæsonen.
Hold styr på lagerstatus og bestil varer.
Sørg for at priser er opdaterede.'),
    ('Holdleder & Transport', 'Fast holdleder for et ungdoms- eller seniorhold (Sæson)', 150, 'Hård', 'car', 'Vær fast holdleder for et hold hele sæsonen.
Kommunikér med forældre, spillere og trænere.
Sørg for tilmelding, kørsel og praktiske forhold.'),
    ('Holdleder & Transport', 'Kørsel til udekamp inkl. heppekor', 30, 'Let', 'car', 'Kør spillere til udekamp og hep holdet under kampen.
Aftaler mødested og tidspunkt med holdleder.
Sørg for at alle kommer sikkert hjem.'),
    ('Holdleder & Transport', 'Kørsel til udekamp – kun aflevering/afhentning', 10, 'Let', 'car', 'Kør spillere til eller fra udekamp.
Aftaler tidspunkt og sted med holdleder.'),
    ('Holdleder & Transport', 'Fast vaskemaskine – holdets trøjer hele sæsonen', 100, 'Medium', 'laundry', 'Vask holdets spillertøj efter samtlige kampe og stævner hele sæsonen.
Aftaler afhentning og aflevering med holdleder.'),
    ('Holdleder & Transport', 'Vask af spillertøj efter én kamp/stævne', 10, 'Let', 'laundry', 'Vask holdets spillertøj efter én kamp eller et stævne.
Aftaler afhentning og aflevering med holdleder.'),
    ('Stævneplanlægning og Afholdelse', 'Stævneleder/Hovedansvarlig for klubbens eget stævne', 150, 'Hård', 'trophy', 'Vær overordnet ansvarlig for afviklingen af et klubstævne.
Koordinér alle frivillige og leverandører.
Sørg for at stævneprogrammet følges.'),
    ('Stævneplanlægning og Afholdelse', 'Medlem af stævneudvalg (planlægning)', 80, 'Medium', 'committee', 'Deltag i planlægningen af klubbens stævne.
Mød til udvalgets møder og tag ansvar for aftalte opgaver.'),
    ('Stævneplanlægning og Afholdelse', 'Natvagt/Halsover ved overnatningsstævne', 60, 'Medium', 'tent', 'Vær halsover om natten ved overnatningsstævne (ca. kl. 23–07).
Sørg for ro og tryghed for de deltagende unge.'),
    ('Stævneplanlægning og Afholdelse', 'Stævnesekretariatet – registrér resultater (halvdags)', 40, 'Let', 'scorecard', 'Sid i stævnesekretariatet og registrér resultater og tider.
Styr kampuret og koordinér med dommerne.'),
    ('Stævneplanlægning og Afholdelse', 'Kioskvagt ved stort weekendstævne (vagt á 3 timer)', 30, 'Let', 'kiosk', 'Bemand kiosken i 3 timer under weekendstævnet.
Sørg for at varer er fyldt op løbende.'),
    ('Stævneplanlægning og Afholdelse', 'Opsætning fredag aften inden stævne / Hovedrengøring søndag', 30, 'Let', 'net', 'Hjælp med at sætte hallen op fredag aften eller stå for hovedrengøring søndag.
Følg stævnelederens anvisninger.'),
    ('Kommunikation & PR', 'Webmaster / Hovedansvarlig for SoMe (Sæson)', 150, 'Hård', 'megaphone', 'Vær ansvarlig for klubbens hjemmeside og sociale medier hele sæsonen.
Post regelmæssige opdateringer og resultater.
Koordinér indhold med bestyrelsen.'),
    ('Kommunikation & PR', 'Sponsorudvalg (Sæson – indhente sponsorer)', 150, 'Hård', 'committee', 'Vær en del af sponsorudvalget og indhent sponsorer til klubben hele sæsonen.
Kontakt lokale virksomheder og lav sponsoraftaler.'),
    ('Kommunikation & PR', 'Fotograf til kampdag/stævne inkl. redigering og deling', 30, 'Let', 'camera', 'Tag billeder ved en kampdag eller stævne.
Redigér udvalgte billeder og del med klubben.
Brug klubbens fotokanaler til deling.'),
    ('Kommunikation & PR', 'Skrive kampreferater / artikler til hjemmeside/Facebook', 20, 'Let', 'web', 'Skriv et kort kampreferat eller en artikel til hjemmeside eller Facebook.
Aflever tekst til SoMe-ansvarlig senest dagen efter kampen.'),
    ('Kommunikation & PR', 'Lave grafisk materiale (plakater, opslag, stævneprogram)', 20, 'Let', 'gear', 'Lav grafisk materiale til klubbens aktiviteter.
Brug klubbens farver og logo.
Aflever filer til SoMe-ansvarlig i aftalt format.'),
    ('Kommunikation & PR', 'Dele flyers / hænge plakater op i lokalområdet', 10, 'Let', 'flyer', 'Del flyers eller hæng plakater op i lokalområdet.
Få materiale udleveret af SoMe-ansvarlig.
Indmeld hvilke steder du har besøgt.'),
    ('Faciliteter & Materialer', 'Materialeansvarlig (Sæson)', 150, 'Hård', 'gear', 'Hold overblik over bolde, tøj, net og øvrigt udstyr hele sæsonen.
Registrér slitage og bestil nyt ved behov.
Rapportér til bestyrelsen.'),
    ('Faciliteter & Materialer', 'Klargøring af beachvolleyball-baner (arbejdsdag)', 40, 'Medium', 'net', 'Hjælp med at klargøre beachvolleyball-banerne til sæsonen.
Mød op til den aftalte arbejdsdag.
Medtag egnet fodtøj og arbejdstøj.'),
    ('Faciliteter & Materialer', 'Vedligehold af beach-baner (luge ukrudt, rive baner)', 20, 'Let', 'net', 'Vedligehold beachbanerne ved at luge ukrudt og rive sand.
Ca. 2 timers arbejde pr. gang.'),
    ('Faciliteter & Materialer', 'Hovedoprydning og organisering af boldrum', 30, 'Let', 'gear', 'Ryd op og organiser klubbens boldrum.
Sørg for at alt udstyr er på rette plads og mærket.'),
    ('Faciliteter & Materialer', 'Småreparationer (sy net, fikse boldvogne, pumpe bolde)', 20, 'Let', 'tools', 'Foretag småreparationer på klubbens udstyr.
Sy net, reparer boldvogne eller pump bolde.
Rapportér større skader til materialeansvarlig.'),
    ('Klubadministration', 'Bestyrelsesmedlem (Formand, Kasserer m.fl.)', 200, 'Hård', 'board', 'Sidder i klubbens bestyrelse hele sæsonen.
Deltager i bestyrelsesmøder og varetager bestyrelsespost.
Rapporterer til generalforsamlingen.'),
    ('Klubadministration', 'Revisor / Økonomisk hjælp (Sæson)', 80, 'Medium', 'money', 'Hjælp med revision eller økonomi hele sæsonen.
Gennemgå regnskab og bilag.
Rapportér til kassereren.'),
    ('Klubadministration', 'Børneattest-ansvarlig (Sæson)', 80, 'Medium', 'board', 'Indhent og tjek børneattester for alle relevante frivillige.
Hold register opdateret hele sæsonen.
Rapportér mangler til formanden.'),
    ('Klubadministration', 'Hjælp til medlemsregistrering og kontingentkørsel', 50, 'Let', 'car', 'Hjælp med at registrere nye medlemmer og køre kontingentopkrævning.
Aftaler opgaveomfang med kassereren.'),
    ('Klubadministration', 'Fonds-ansøger (skrive og sende fondansøgninger)', 50, 'Medium', 'board', 'Skriv og send ansøgninger til fonde og puljer på vegne af klubben.
Koordinér med bestyrelsen om behovsområder.
Rapportér svar og tildelinger.')    ) as v(category, title, points, difficulty, icon, description)
    on conflict (category, title) do nothing
    returning 1
  )
  select count(*) into v_antal from nye;

  return v_antal;
end;
$$;

comment on function public.seed_task_templates() is
  'Lægger appens 40 oprindelige skabeloner ind, med de dobbelte point fra 29. september 2026. Kun dem der mangler.';



-- ############################################################################
-- ## AFSNIT 21 af 21: 20261103090000_opgavetyper.sql
-- ############################################################################

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
