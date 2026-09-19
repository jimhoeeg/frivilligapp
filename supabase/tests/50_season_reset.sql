-- Afprøver nulstilling af sæson.
-- Kør efter 00_supabase_stub.sql, basisskemaet og alle migrationer.

\set ON_ERROR_STOP on
\pset pager off

insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'anna@rvk.dk', '{"name":"Anna Berg"}'),
  ('22222222-2222-2222-2222-222222222222', 'bo@rvk.dk',   '{"name":"Bo Dahl"}'),
  ('33333333-3333-3333-3333-333333333333', 'cita@rvk.dk', '{"name":"Cita Ek"}'),
  ('44444444-4444-4444-4444-444444444444', 'formand@randersVK.dk', '{"name":"Frida Mand"}');

select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
select public.admin_set_approval('11111111-1111-1111-1111-111111111111', true);
select public.admin_set_approval('22222222-2222-2222-2222-222222222222', true);
select public.admin_set_approval('33333333-3333-3333-3333-333333333333', true);
select public.admin_set_role('33333333-3333-3333-3333-333333333333', 'admin');

insert into public.tasks (id,title,category,date,date_full,time,location,points,spots_total,spots_left)
values ('a0000000-0000-0000-0000-0000000000c1','Dommerbord','Kamp','4. okt','2026-10-04','10:00','Bane 1',10,3,3),
       ('a0000000-0000-0000-0000-0000000000c2','Kiosk','Hygge','5. okt','2026-10-05','12:00','Hallen',20,2,2);

-- Anna: én bekræftet (10) + én der afventer. Bo: én bekræftet (20) + bonus.
insert into public.task_claims (task_id,user_id) values
  ('a0000000-0000-0000-0000-0000000000c1','11111111-1111-1111-1111-111111111111'),
  ('a0000000-0000-0000-0000-0000000000c2','11111111-1111-1111-1111-111111111111'),
  ('a0000000-0000-0000-0000-0000000000c1','22222222-2222-2222-2222-222222222222');

select public.admin_set_claim_status('a0000000-0000-0000-0000-0000000000c1','11111111-1111-1111-1111-111111111111','completed');
select public.admin_set_claim_status('a0000000-0000-0000-0000-0000000000c1','22222222-2222-2222-2222-222222222222','completed');
select public.admin_adjust_points('22222222-2222-2222-2222-222222222222', 15);

-- Et åbent byttetilbud, der skal lukkes med.
insert into public.swap_offers (from_user_id, offering_task_id, status)
values ('11111111-1111-1111-1111-111111111111','a0000000-0000-0000-0000-0000000000c2','available');

\echo ''
\echo '=== 1. Udgangspunkt ==='
select name, points, bonus_points, tasks_done from public.profiles order by name;
select title, spots_total, spots_left from public.tasks order by title;

\echo ''
\echo '=== 2. Forhåndsvisning (super admin) ==='
select members, total_points, claims_total, claims_pending, claims_completed, open_swaps
  from public.admin_season_reset_preview();

\echo ''
\echo '=== 3. En almindelig ADMIN må ikke nulstille ==='
select set_config('test.uid','33333333-3333-3333-3333-333333333333',false);
do $$ begin
  perform public.admin_reset_season('NULSTIL','Forsøg');
  raise notice 'FEJL: admin kunne nulstille sæsonen';
exception when others then raise notice 'OK  – afvist: %', sqlerrm; end $$;
do $$ begin
  perform public.admin_season_reset_preview();
  raise notice 'FEJL: admin så forhåndsvisningen';
exception when others then raise notice 'OK  – forhåndsvisning afvist'; end $$;

\echo ''
\echo '=== 4. Et MEDLEM må slet ingenting ==='
select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
do $$ begin
  perform public.admin_reset_season('NULSTIL','Forsøg');
  raise notice 'FEJL: medlem kunne nulstille sæsonen';
exception when others then raise notice 'OK  – afvist'; end $$;

\echo ''
\echo '=== 5. Super admin UDEN det rigtige ord: intet sker ==='
select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
do $$ begin
  perform public.admin_reset_season('ja','2025/2026');
  raise notice 'FEJL: nulstillede uden bekræftelse';
exception when others then raise notice 'OK  – afvist: %', sqlerrm; end $$;
do $$ begin
  perform public.admin_reset_season('nulstil','2025/2026');
  raise notice 'FEJL: små bogstaver blev accepteret';
exception when others then raise notice 'OK  – smaa bogstaver afvist'; end $$;
do $$ begin
  perform public.admin_reset_season(null,'2025/2026');
  raise notice 'FEJL: null blev accepteret';
exception when others then raise notice 'OK  – null afvist'; end $$;
\echo '    – og pointene står urørt:'
select name, points from public.profiles order by name;

\echo ''
\echo '=== 6. Uden sæsonnavn: afvist ==='
do $$ begin
  perform public.admin_reset_season('NULSTIL','   ');
  raise notice 'FEJL: tomt navn blev accepteret';
exception when others then raise notice 'OK  – tomt navn afvist'; end $$;

\echo ''
\echo '=== 7. Gennemfør ==='
select archived_members, deleted_claims, closed_swaps, freed_tasks
  from public.admin_reset_season('NULSTIL','2025/2026');
\echo '    forventet: 4 medlemmer, 3 tilmeldinger, 1 bytte, 2 opgaver frigivet'

\echo ''
\echo '=== 8. Alle står på nul, pladserne er fri ==='
select name, points, bonus_points, tasks_done from public.profiles order by name;
select title, spots_total, spots_left from public.tasks order by title;
select count(*) as tilmeldinger_tilbage from public.task_claims;
select status, count(*) from public.swap_offers group by status;

\echo ''
\echo '=== 9. Arkivet husker sidste sæson ==='
select season_label, members, total_points, reached_goal from public.admin_season_list();
select name, team, points, bonus_points, tasks_done from public.admin_season_rows('2025/2026');
\echo '    forventet: Bo 25 (10 for Dommerbord + 15 bonus), Anna 10, Cita 0, Frida 0'

\echo ''
\echo '=== 10. Ingen fik 3 beskeder om fjernede opgaver ==='
select type, count(*) from public.notifications
 where type in ('task_unassigned','season_reset') group by type order by type;
\echo '    forventet: season_reset 4, ingen task_unassigned'

\echo ''
\echo '=== 11. Det står i audit-loggen ==='
select type, action from public.audit_log where action like 'Nulstillede%';

\echo ''
\echo '=== 12. Samme sæsonnavn to gange: afvist ==='
do $$ begin
  perform public.admin_reset_season('NULSTIL','2025/2026');
  raise notice 'FEJL: overskrev et eksisterende arkiv';
exception when others then raise notice 'OK  – afvist: %', sqlerrm; end $$;

\echo ''
\echo '=== 13. En ny sæson kan nulstilles igen ==='
insert into public.task_claims (task_id,user_id)
values ('a0000000-0000-0000-0000-0000000000c1','11111111-1111-1111-1111-111111111111');
select public.admin_set_claim_status('a0000000-0000-0000-0000-0000000000c1','11111111-1111-1111-1111-111111111111','completed');
select name, points from public.profiles where name='Anna Berg';
select archived_members from public.admin_reset_season('NULSTIL','2026/2027');
select season_label, total_points from public.admin_season_list() order by season_label;

\echo ''
\echo '=== 14. Sletter man et medlem, følger arkivet med (GDPR) ==='
select count(*) as foer from public.season_results where name='Anna Berg';
delete from public.profiles where id='11111111-1111-1111-1111-111111111111';
select count(*) as efter from public.season_results where name='Anna Berg';
\echo '    forventet: foer 2, efter 0'
