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
