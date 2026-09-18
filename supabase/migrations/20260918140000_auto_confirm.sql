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
