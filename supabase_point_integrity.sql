-- ============================================================
-- Point- og pladsintegritet: atomiske claim/unclaim RPC'er
-- Kør i Supabase Dashboard → SQL Editor → Run
-- Kør EFTER supabase_setup.sql og supabase_task_claims_rls.sql
--
-- VIGTIGT: Frontend'en kalder claim_task / unclaim_task. Kør denne fil
-- FØR (eller samtidig med) at du deployer den tilhørende frontend, ellers
-- vil "tag tjans" / "frameld" fejle.
-- ============================================================

-- Tag en opgave: låser opgaverækken, sikrer at der er en ledig plads, og
-- indsætter claim'et. Triggeren on_task_claimed giver point og tæller pladser
-- ned — derfor rører denne funktion hverken points eller spots_left direkte.
-- Rækkelåsen (FOR UPDATE) serialiserer samtidige forsøg, så to brugere ikke
-- kan tage den samme sidste plads (ingen overbooking).
create or replace function public.claim_task(p_task_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_spots int;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select spots_left into v_spots from public.tasks where id = p_task_id for update;
  if v_spots is null then
    raise exception 'TASK_NOT_FOUND';
  end if;
  if v_spots <= 0 then
    raise exception 'NO_SPOTS_LEFT';
  end if;

  -- unique(task_id, user_id) forhindrer dobbelt-tilmelding for samme bruger
  insert into public.task_claims (task_id, user_id) values (p_task_id, v_uid);

  select spots_left into v_spots from public.tasks where id = p_task_id;
  return v_spots;
end;
$$;

-- Frameld en opgave: sletter claim'et og ruller point + plads tilbage atomisk.
-- Point trækkes fra databasens aktuelle værdi (ikke en evt. forældet klient-
-- værdi) og kan aldrig gå under 0.
create or replace function public.unclaim_task(p_task_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_points int;
  v_uid uuid := auth.uid();
  v_deleted int;
  v_spots int;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  delete from public.task_claims where task_id = p_task_id and user_id = v_uid;
  get diagnostics v_deleted = row_count;

  if v_deleted > 0 then
    select points into v_points from public.tasks where id = p_task_id;
    update public.profiles
      set points = greatest(0, points - coalesce(v_points, 0)),
          tasks_done = greatest(0, tasks_done - 1)
      where id = v_uid;
    update public.tasks
      set spots_left = spots_left + 1
      where id = p_task_id;
  end if;

  select spots_left into v_spots from public.tasks where id = p_task_id;
  return v_spots;
end;
$$;

-- Kun indloggede brugere må kalde RPC'erne (fjern anon/public default-grant)
revoke all on function public.claim_task(uuid)   from public, anon;
revoke all on function public.unclaim_task(uuid) from public, anon;
grant execute on function public.claim_task(uuid)   to authenticated;
grant execute on function public.unclaim_task(uuid) to authenticated;
