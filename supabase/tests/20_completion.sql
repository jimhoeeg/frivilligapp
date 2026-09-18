-- Afprøver punkt 13: point gives først når en admin bekræfter tjansen.
-- Kør efter 00_supabase_stub.sql, basisskemaet og begge migrationer.

\set ON_ERROR_STOP on
\pset pager off

-- ---------------------------------------------------------------- opsætning
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'anna@rvk.dk', '{"name":"Anna Berg","team":"Damer 2"}'),
  ('22222222-2222-2222-2222-222222222222', 'bo@rvk.dk',   '{"name":"Bo Dahl","team":"Herrer 1"}'),
  ('44444444-4444-4444-4444-444444444444', 'formand@randersVK.dk', '{"name":"Frida Mand"}');

select set_config('test.uid', '44444444-4444-4444-4444-444444444444', false);
select public.admin_set_approval('11111111-1111-1111-1111-111111111111', true);
select public.admin_set_approval('22222222-2222-2222-2222-222222222222', true);

insert into public.tasks (id, title, category, date, date_full, time, location, points, spots_total, spots_left)
values ('aaaaaaaa-0000-0000-0000-000000000001', 'Dommerbord U15', 'Kampafvikling', '4. okt', '2026-10-04', '10:00 – 12:00', 'Bane 1', 15, 2, 2),
       ('aaaaaaaa-0000-0000-0000-000000000002', 'Cafévagt',       'Hygge',         '5. okt', '2026-10-05', '09:00 – 11:00', 'Cafeen', 10, 1, 1);

\echo ''
\echo '=== 1. Tilmelding giver INGEN point, men optager en plads ==='
select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
insert into public.task_claims (task_id, user_id)
values ('aaaaaaaa-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111');
select set_config('test.uid','22222222-2222-2222-2222-222222222222',false);
insert into public.task_claims (task_id, user_id)
values ('aaaaaaaa-0000-0000-0000-000000000001','22222222-2222-2222-2222-222222222222');

select p.name, p.points, p.tasks_done from public.profiles p
 where p.id in ('11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222')
 order by p.name;
select 'ledige pladser' as hvad, spots_left from public.tasks
 where id='aaaaaaaa-0000-0000-0000-000000000001';
select status, count(*) from public.task_claims group by status;

\echo ''
\echo '=== 2. Opgaven står på admins bekræftelsesliste ==='
select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
select title, pending, completed, no_show from public.admin_pending_confirmations();

\echo ''
\echo '=== 3. Admin bekræfter Anna – hun får point, Bo får ikke ==='
select public.admin_set_claim_status(
  'aaaaaaaa-0000-0000-0000-000000000001',
  '11111111-1111-1111-1111-111111111111', 'completed');

select p.name, p.points, p.tasks_done from public.profiles p
 where p.id in ('11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222')
 order by p.name;

\echo ''
\echo '=== 4. Bo registreres som udeblevet – stadig ingen point ==='
select public.admin_set_claim_status(
  'aaaaaaaa-0000-0000-0000-000000000001',
  '22222222-2222-2222-2222-222222222222', 'no_show', 'Meldte ikke afbud');

select p.name, p.points, p.tasks_done from public.profiles p
 where p.id='22222222-2222-2222-2222-222222222222';
select 'opgaven er væk fra listen' as hvad, count(*) from public.admin_pending_confirmations();

\echo ''
\echo '=== 5. Bekræftelse trækkes tilbage – pointene følger med ==='
select public.admin_set_claim_status(
  'aaaaaaaa-0000-0000-0000-000000000001',
  '11111111-1111-1111-1111-111111111111', 'signed_up');
select p.name, p.points, p.tasks_done from public.profiles p
 where p.id='11111111-1111-1111-1111-111111111111';

\echo ''
\echo '=== 6. Bekræft hele opgaven på én gang – kun dem der afventer ==='
select public.admin_confirm_task('aaaaaaaa-0000-0000-0000-000000000001') as antal_bekraeftede;
select p.name, p.points from public.profiles p
 where p.id in ('11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222')
 order by p.name;
select 'Bo er stadig no_show' as hvad, status from public.task_claims
 where user_id='22222222-2222-2222-2222-222222222222';

\echo ''
\echo '=== 7. Medlem kan ikke framelde en bekræftet tjans ==='
select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
do $$ begin
  delete from public.task_claims
   where task_id='aaaaaaaa-0000-0000-0000-000000000001'
     and user_id='11111111-1111-1111-1111-111111111111';
  raise notice 'FEJL: bekræftet tjans blev frameldt';
exception when others then raise notice 'OK  – afvist: %', sqlerrm;
end $$;

\echo ''
\echo '=== 8. En IKKE-bekræftet tjans kan stadig frameldes ==='
insert into public.task_claims (task_id, user_id)
values ('aaaaaaaa-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111');
do $$ begin
  delete from public.task_claims
   where task_id='aaaaaaaa-0000-0000-0000-000000000002'
     and user_id='11111111-1111-1111-1111-111111111111';
  raise notice 'OK  – frameldt';
exception when others then raise notice 'FEJL: %', sqlerrm;
end $$;
select 'plads frigivet igen' as hvad, spots_left from public.tasks
 where id='aaaaaaaa-0000-0000-0000-000000000002';

\echo ''
\echo '=== 9. Almindeligt medlem kan ikke bekræfte sig selv ==='
do $$ begin
  perform public.admin_set_claim_status(
    'aaaaaaaa-0000-0000-0000-000000000001',
    '11111111-1111-1111-1111-111111111111', 'completed');
  raise notice 'FEJL: medlem bekræftede sig selv';
exception when others then raise notice 'OK  – afvist: %', sqlerrm;
end $$;
do $$ begin
  perform public.admin_confirm_task('aaaaaaaa-0000-0000-0000-000000000001');
  raise notice 'FEJL: medlem bekræftede hele opgaven';
exception when others then raise notice 'OK  – afvist: %', sqlerrm;
end $$;
do $$ begin
  perform public.admin_pending_confirmations();
  raise notice 'FEJL: medlem så bekræftelseslisten';
exception when others then raise notice 'OK  – afvist: %', sqlerrm;
end $$;

\echo ''
\echo '=== 10. Et bytte kan ikke handle om en bekræftet tjans ==='
-- Cita står ikke selv på opgaven, så afvisningen kan kun komme fra
-- kontrollen af tilmeldingens tilstand.
insert into auth.users (id, email, raw_user_meta_data)
values ('33333333-3333-3333-3333-333333333333','cita@rvk.dk','{"name":"Cita Ek"}');
select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
select public.admin_set_approval('33333333-3333-3333-3333-333333333333', true);

select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
insert into public.swap_offers (id, from_user_id, offering_task_id, status)
values ('bbbbbbbb-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
        'aaaaaaaa-0000-0000-0000-000000000001','available');
select set_config('test.uid','33333333-3333-3333-3333-333333333333',false);
do $$ begin
  perform public.accept_swap('bbbbbbbb-0000-0000-0000-000000000001');
  raise notice 'FEJL: bekræftet tjans blev byttet væk';
exception when others then raise notice 'OK  – afvist: %', sqlerrm;
end $$;

\echo ''
\echo '=== 11. Et bytte af en IKKE-bekræftet tjans virker stadig ==='
select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
insert into public.task_claims (task_id, user_id)
values ('aaaaaaaa-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111');
insert into public.swap_offers (id, from_user_id, offering_task_id, status)
values ('bbbbbbbb-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111',
        'aaaaaaaa-0000-0000-0000-000000000002','available');
select set_config('test.uid','22222222-2222-2222-2222-222222222222',false);
do $$ begin
  perform public.accept_swap('bbbbbbbb-0000-0000-0000-000000000002');
  raise notice 'OK  – byttet gennemført';
exception when others then raise notice 'FEJL: %', sqlerrm;
end $$;
select p.name as staar_paa_cafevagt, c.status from public.task_claims c
  join public.profiles p on p.id = c.user_id
 where c.task_id='aaaaaaaa-0000-0000-0000-000000000002';

\echo ''
\echo '=== 12. Sletning af opgave rydder også bekræftede point ==='
select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
select p.name, p.points from public.profiles p
 where p.id='11111111-1111-1111-1111-111111111111';
delete from public.tasks where id='aaaaaaaa-0000-0000-0000-000000000001';
select p.name, p.points, p.tasks_done from public.profiles p
 where p.id='11111111-1111-1111-1111-111111111111';

\echo ''
\echo '=== 13. Beskeder ved bekræftelse og udeblivelse ==='
select p.name as modtager, n.type, n.title from public.notifications n
  join public.profiles p on p.id = n.user_id
 where n.type in ('task_completed','task_no_show','task_reopened')
 order by n.created_at;

\echo ''
\echo '=== 14. Bonuspoint overlever genberegningen ==='
select public.admin_adjust_points('22222222-2222-2222-2222-222222222222', 30);
update public.profiles p
   set points = coalesce(c.pts,0) + p.bonus_points, tasks_done = coalesce(c.cnt,0)
  from (select user_id, sum(coalesce(points_awarded,0))::int pts, count(*)::int cnt
          from public.task_claims where status='completed' group by user_id) c
 where c.user_id = p.id;
select name, points, bonus_points from public.profiles
 where id='22222222-2222-2222-2222-222222222222';
