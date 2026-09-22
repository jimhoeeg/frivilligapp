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
-- ## AFSNIT 1 af 11: 20260101000000_baseline.sql
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
-- ## AFSNIT 2 af 11: 20260910120000_launch_hardening.sql
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
-- ## AFSNIT 3 af 11: 20260918100000_task_completion.sql
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
-- ## AFSNIT 4 af 11: 20260918140000_auto_confirm.sql
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
-- ## AFSNIT 5 af 11: 20260918160000_cleanup_orphans.sql
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
-- ## AFSNIT 6 af 11: 20260919080000_policies_from_legacy.sql
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
  ('contribution_kr',   '1500'),
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
-- ## AFSNIT 7 af 11: 20260919090000_points_follow_task.sql
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
-- ## AFSNIT 8 af 11: 20260919110000_client_errors.sql
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
-- ## AFSNIT 9 af 11: 20260919140000_lock_function_execute.sql
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
-- ## AFSNIT 10 af 11: 20260919160000_season_reset.sql
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
-- ## AFSNIT 11 af 11: 20260922180000_teams_readable_at_signup.sql
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
