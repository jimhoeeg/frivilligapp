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
   set points     = coalesce(c.pts, 0) + p.bonus_points,
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
   set points     = p.bonus_points,
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
