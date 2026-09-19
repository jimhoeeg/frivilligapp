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
