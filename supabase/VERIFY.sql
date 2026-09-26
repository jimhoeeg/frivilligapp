-- ============================================================================
-- RVK Frivillig – eftersyn efter migrationerne
--
-- Kør HELE filen i Supabase Dashboard → SQL Editor → Run.
-- Læser kun; ændrer ingenting.
--
-- Hver linje siger OK eller FEJL. Alt skal stå OK, på nær linjer mærket
-- INFO, som bare oplyser noget.
-- ============================================================================

select * from (

-- ---------------------------------------------------------------- SKEMA ----
select 1::numeric as nr, 'Alle 14 tabeller findes' as tjek,
  case when (select count(*) from pg_tables
              where schemaname='public'
                and tablename in ('profiles','teams','tasks','task_steps','task_claims',
                                  'swap_offers','notifications','audit_log','settings',
                                  'client_errors','season_results','task_templates','member_badges',
                                  'email_outbox')) = 14
       then 'OK' else 'FEJL' end as resultat,
  (select string_agg(tablename, ', ' order by tablename) from pg_tables
    where schemaname='public'
      and tablename in ('profiles','teams','tasks','task_steps','task_claims',
                        'swap_offers','notifications','audit_log','settings','client_errors','season_results','task_templates','member_badges','email_outbox')
  ) as detalje

union all
select 2, 'Row level security slået til overalt',
  case when (select count(*) from pg_tables t
              where t.schemaname='public'
                and t.tablename in ('profiles','teams','tasks','task_steps','task_claims',
                                    'swap_offers','notifications','audit_log','settings','client_errors','season_results','task_templates')
                and not exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
                                 where n.nspname='public' and c.relname=t.tablename and c.relrowsecurity)) = 0
       then 'OK' else 'FEJL' end,
  coalesce((select string_agg(t.tablename, ', ') from pg_tables t
             where t.schemaname='public'
               and t.tablename in ('profiles','teams','tasks','task_steps','task_claims',
                                   'swap_offers','notifications','audit_log','settings','client_errors','season_results','task_templates')
               and not exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
                                where n.nspname='public' and c.relname=t.tablename and c.relrowsecurity)),
           'alle har RLS')

union all
select 3, 'Ingen tabel står uden politikker',
  case when (select count(*) from pg_class c
              join pg_namespace n on n.oid=c.relnamespace
              where n.nspname='public' and c.relkind='r' and c.relrowsecurity
                and not exists (select 1 from pg_policy p where p.polrelid=c.oid)) = 0
       then 'OK' else 'FEJL' end,
  coalesce((select string_agg(c.relname, ', ') from pg_class c
             join pg_namespace n on n.oid=c.relnamespace
             where n.nspname='public' and c.relkind='r' and c.relrowsecurity
               and not exists (select 1 from pg_policy p where p.polrelid=c.oid)),
           'alle er dækket')

-- ------------------------------------------------------------- TRIGGERE ----
union all
select 4, 'De fem rigtige triggere på tilmeldinger',
  case when (select count(*) from pg_trigger
              where tgrelid='public.task_claims'::regclass and not tgisinternal
                and tgname in ('tc_before_insert','tc_after_insert','tc_before_delete',
                               'tc_after_delete','tc_after_update')) = 5
       then 'OK' else 'FEJL' end,
  (select string_agg(tgname, ', ' order by tgname) from pg_trigger
    where tgrelid='public.task_claims'::regclass and not tgisinternal)

union all
select 5, 'Den gamle pointtrigger er væk',
  case when not exists (select 1 from pg_trigger
                         where tgrelid='public.task_claims'::regclass
                           and not tgisinternal and tgname='on_task_claimed')
       then 'OK' else 'FEJL' end,
  'on_task_claimed må ikke findes – den ville give dobbelt point'

union all
select 6, 'Den konkurrerende pointmotor er ryddet væk',
  case when (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='public'
                and p.proname in ('claim_task','unclaim_task','handle_task_claim')) = 0
       then 'OK' else 'FEJL' end,
  coalesce((select string_agg(p.proname, ', ') from pg_proc p
             join pg_namespace n on n.oid=p.pronamespace
             where n.nspname='public'
               and p.proname in ('claim_task','unclaim_task','handle_task_claim')),
           'ingen rester')

-- ------------------------------------------------------------ FUNKTIONER ---
union all
select 7, 'Alle funktioner appen kalder findes',
  case when (select count(*) from (values
        ('my_profile'),('admin_list_members'),('admin_set_approval'),('admin_set_role'),
        ('request_admin_access'),('admin_dismiss_request'),('admin_adjust_points'),
        ('accept_swap'),('decline_swap'),('admin_set_claim_status'),('admin_confirm_task'),
        ('admin_pending_confirmations'),('admin_task_signups'),('auto_confirm_due_claims'),
        ('auto_confirm_preview'),('task_claim_counts'),('log_client_error'),
        ('get_my_role'),('is_approved'),('admin_reset_season'),
        ('admin_season_reset_preview'),('admin_season_list'),('admin_season_rows'),('task_signups'),
        ('my_badges')
      ) as f(navn)
      where not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                         where n.nspname='public' and p.proname=f.navn)) = 0
       then 'OK' else 'FEJL' end,
  coalesce((select string_agg(f.navn, ', ') from (values
        ('my_profile'),('admin_list_members'),('admin_set_approval'),('admin_set_role'),
        ('request_admin_access'),('admin_dismiss_request'),('admin_adjust_points'),
        ('accept_swap'),('decline_swap'),('admin_set_claim_status'),('admin_confirm_task'),
        ('admin_pending_confirmations'),('admin_task_signups'),('auto_confirm_due_claims'),
        ('auto_confirm_preview'),('task_claim_counts'),('log_client_error'),
        ('get_my_role'),('is_approved'),('admin_reset_season'),
        ('admin_season_reset_preview'),('admin_season_list'),('admin_season_rows'),('task_signups')
      ) as f(navn)
      where not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                         where n.nspname='public' and p.proname=f.navn)),
      'alle 24 findes')

-- ---------------------------------------------------------- RETTIGHEDER ----
union all
select 8, 'Anonyme kan IKKE læse medlemstabellen',
  case when not has_table_privilege('anon','public.profiles','select')
       then 'OK' else 'FEJL' end,
  'dette var GDPR-hullet: hele medlemslisten kunne hentes uden login'

union all
select 9, 'E-mail og telefon er ikke læsbare for almindelige klienter',
  case when not has_column_privilege('authenticated','public.profiles','email','select')
        and not has_column_privilege('authenticated','public.profiles','phone','select')
       then 'OK' else 'FEJL' end,
  'email: ' || has_column_privilege('authenticated','public.profiles','email','select')::text ||
  ', phone: ' || has_column_privilege('authenticated','public.profiles','phone','select')::text

union all
select 10, 'Navn og point kan stadig læses',
  case when has_column_privilege('authenticated','public.profiles','name','select')
        and has_column_privilege('authenticated','public.profiles','points','select')
       then 'OK' else 'FEJL' end,
  'ellers virker ranglisten ikke'

union all
select 11, 'Et medlem kan ikke ændre sin egen rolle eller sine point',
  case when not has_column_privilege('authenticated','public.profiles','role','update')
        and not has_column_privilege('authenticated','public.profiles','points','update')
        and not has_column_privilege('authenticated','public.profiles','approved','update')
       then 'OK' else 'FEJL' end,
  'role: ' || has_column_privilege('authenticated','public.profiles','role','update')::text ||
  ', points: ' || has_column_privilege('authenticated','public.profiles','points','update')::text ||
  ', approved: ' || has_column_privilege('authenticated','public.profiles','approved','update')::text

union all
select 12, 'Et medlem kan stadig rette sit eget navn og telefon',
  case when has_column_privilege('authenticated','public.profiles','name','update')
        and has_column_privilege('authenticated','public.profiles','phone','update')
        and has_column_privilege('authenticated','public.profiles','team','update')
       then 'OK' else 'FEJL' end,
  'ellers kan ingen rette sin profil'

-- ------------------------------------------------------------ DATA ---------
union all
select 13, 'Pointsummerne stemmer med tilmeldingerne',
  case when (select count(*) from public.profiles p
              where p.points is distinct from greatest(0,
                coalesce((select sum(coalesce(c.points_awarded,0))::int from public.task_claims c
                           where c.user_id=p.id and c.status='completed'), 0) + p.bonus_points)) = 0
       then 'OK' else 'FEJL' end,
  coalesce((select string_agg(p.name || ' (står til ' || p.points::text || ')', ', ')
     from public.profiles p
    where p.points is distinct from greatest(0,
      coalesce((select sum(coalesce(c.points_awarded,0))::int from public.task_claims c
                 where c.user_id=p.id and c.status='completed'), 0) + p.bonus_points)),
    'alle stemmer')

union all
select 14, 'Alle tilmeldinger har en gyldig tilstand',
  case when (select count(*) from public.task_claims
              where status not in ('signed_up','completed','no_show')) = 0
       then 'OK' else 'FEJL' end,
  (select coalesce(string_agg(status || ': ' || n::text, ', '), 'ingen tilmeldinger endnu')
     from (select status, count(*) n from public.task_claims group by status) x)

union all
select 15, 'Ledige pladser stemmer med antal tilmeldte',
  case when (select count(*) from public.tasks t
              where t.spots_left is distinct from greatest(0, t.spots_total -
                (select count(*) from public.task_claims c where c.task_id=t.id))) = 0
       then 'OK' else 'FEJL' end,
  coalesce((select string_agg(t.title, ', ') from public.tasks t
    where t.spots_left is distinct from greatest(0, t.spots_total -
      (select count(*) from public.task_claims c where c.task_id=t.id))),
    'alle stemmer')

union all
select 16, 'Klubbens indstillinger findes',
  case when (select count(*) from public.settings
              where key in ('point_goal','contribution_kr','season_start',
                            'season_end','auto_confirm_days')) = 5
       then 'OK' else 'FEJL' end,
  (select string_agg(key || '=' || value, ', ' order by key) from public.settings
    where key in ('point_goal','contribution_kr','auto_confirm_days'))

-- ------------------------------------------------------------- INFO --------
union all
select 17, 'Hold oprettet',
  case when (select count(*) from public.teams) > 0 then 'OK' else 'FEJL' end,
  (select count(*)::text || ' hold: ' ||
          coalesce(string_agg(name, ', ' order by name), 'INGEN – kør supabase/seed.sql')
     from public.teams)

union all
select 18, 'Super admins',
  case when (select count(*) from public.profiles where role='super_admin') >= 2
       then 'OK'
       when (select count(*) from public.profiles where role='super_admin') = 1
       then 'FEJL'
       else 'FEJL' end,
  (select count(*)::text || ' super admin(s) – der bør være mindst 2'
     from public.profiles where role='super_admin')

union all
select 18.5, 'Ingen funktioner staar aabne for anonyme',
  case when (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='public' and has_function_privilege('anon', p.oid, 'execute')) = 0
       then 'OK' else 'FEJL' end,
  coalesce((select string_agg(p.proname, ', ') from pg_proc p
             join pg_namespace n on n.oid=p.pronamespace
             where n.nspname='public' and has_function_privilege('anon', p.oid, 'execute')),
           'ingen – kun indloggede kan kalde noget')

union all
select 18.6, 'Kun appens egne funktioner er aabne for indloggede',
  case when (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='public'
                and has_function_privilege('authenticated', p.oid, 'execute')) = 25
       then 'OK' else 'FEJL' end,
  (select count(*) filter (where has_function_privilege('authenticated', p.oid, 'execute'))::text
          || ' af ' || count(*)::text || ' – forventet 25'
     from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')

union all
select 19, 'Medlemmer der afventer godkendelse',
  'INFO',
  (select count(*)::text || ' af ' || (select count(*) from public.profiles)::text
          || ' medlemmer er ikke godkendt endnu'
     from public.profiles where approved = false)

union all
select 20, 'Tilmeldinger der afventer bekræftelse',
  'INFO',
  (select count(*)::text || ' afventer – gøres op under Admin → Bekræft'
     from public.task_claims where status='signed_up')

) x order by nr;


-- ============================================================================
-- Kører den daglige automatik inde i databasen?
--
-- Vises som en NOTICE nederst. Er pg_cron ikke slået til, er det ikke en
-- fejl — appen kalder selv funktionen, når nogen er logget ind.
-- ============================================================================

do $$
declare
  v_jobs text;
begin
  execute 'select string_agg(jobname || '' ('' || schedule || '')'', '', '') from cron.job where jobname like ''rvk_%'''
    into v_jobs;
  if v_jobs is null then
    raise notice 'pg_cron: ingen rvk-jobs fundet. Appen klarer opgørelsen selv, når nogen er logget ind.';
  else
    raise notice 'pg_cron kører: %', v_jobs;
  end if;
exception when others then
  raise notice 'pg_cron er ikke slået til på projektet (%). Appen klarer opgørelsen selv.', sqlerrm;
end $$;
