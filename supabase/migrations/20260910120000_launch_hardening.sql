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
   set points     = coalesce(c.pts, 0) + p.bonus_points,
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
   set points     = p.bonus_points,
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
