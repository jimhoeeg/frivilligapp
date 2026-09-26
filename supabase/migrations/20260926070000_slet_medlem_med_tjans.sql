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
