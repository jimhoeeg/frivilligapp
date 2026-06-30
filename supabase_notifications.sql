-- ============================================================
-- Notifikationer: genereres af SECURITY DEFINER-triggers
-- Kør i Supabase Dashboard → SQL Editor → Run
-- Kør EFTER supabase_setup.sql
--
-- Triggerne nedenfor kører som SECURITY DEFINER og kan derfor indsætte
-- notifikationer til en hvilken som helst bruger uden en INSERT-policy.
-- Admin-policyen tilføjes så admins også kan sende notifikationer manuelt
-- (fx en fremtidig broadcast-funktion).
-- ============================================================

-- Admins kan indsætte notifikationer til alle
drop policy if exists "notif_insert_admin" on public.notifications;
create policy "notif_insert_admin" on public.notifications for insert with check (
  exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','super_admin'))
);

-- ------------------------------------------------------------
-- Velkomst-notifikation når en ny profil oprettes ved signup
-- (udvider den eksisterende handle_new_user)
-- ------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name, email, team, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)),
    new.email,
    coalesce(new.raw_user_meta_data->>'team', ''),
    case
      when new.email in ('formand@randersVK.dk','admin@randersVK.dk')
      then 'super_admin'
      else 'user'
    end
  );

  insert into public.notifications (user_id, type, title, body)
  values (
    new.id,
    'welcome',
    'Velkommen til RVK Frivillig! 🎉',
    'Find en opgave, tag den, og optjen point. Tak fordi du hjælper klubben.'
  );

  return new;
end;
$$;

-- ------------------------------------------------------------
-- Point/pladser ved claim + notifikation når en ADMIN tildeler
-- en opgave til en anden bruger (udvider den eksisterende
-- handle_task_claim). Ved selv-tilmelding (auth.uid() = modtager)
-- sendes ingen notifikation.
-- ------------------------------------------------------------
create or replace function public.handle_task_claim()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  task_points int;
  task_title  text;
  v_actor uuid := auth.uid();
begin
  select points, title into task_points, task_title from public.tasks where id = new.task_id;

  update public.profiles
    set points = points + coalesce(task_points, 0),
        tasks_done = tasks_done + 1
    where id = new.user_id;

  update public.tasks
    set spots_left = spots_left - 1
    where id = new.task_id and spots_left > 0;

  if v_actor is not null and v_actor <> new.user_id then
    insert into public.notifications (user_id, type, title, body, action_task_id)
    values (
      new.user_id,
      'task_assigned',
      'Du er blevet tildelt en opgave',
      'Du er tilmeldt "' || coalesce(task_title, 'en opgave') || '".',
      new.task_id
    );
  end if;

  return new;
end;
$$;

-- Trigger-funktioner skal aldrig kunne kaldes via REST API
revoke all on function public.handle_new_user()   from public, anon, authenticated;
revoke all on function public.handle_task_claim() from public, anon, authenticated;
