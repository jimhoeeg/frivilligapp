-- Afprøver at point følger med, når en opgaves værdi ændres.
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

insert into public.tasks (id, title, category, date, date_full, time, location, points, spots_total, spots_left)
values ('a0000000-0000-0000-0000-00000000000a', 'Dommerbord', 'Kamp', '4. okt', '2026-10-04', '10:00', 'Bane 1', 10, 3, 3);

-- Tre personer med hver sin tilstand.
select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
insert into public.task_claims (task_id,user_id) values ('a0000000-0000-0000-0000-00000000000a','11111111-1111-1111-1111-111111111111');
select set_config('test.uid','22222222-2222-2222-2222-222222222222',false);
insert into public.task_claims (task_id,user_id) values ('a0000000-0000-0000-0000-00000000000a','22222222-2222-2222-2222-222222222222');
select set_config('test.uid','33333333-3333-3333-3333-333333333333',false);
insert into public.task_claims (task_id,user_id) values ('a0000000-0000-0000-0000-00000000000a','33333333-3333-3333-3333-333333333333');

select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
select public.admin_set_claim_status('a0000000-0000-0000-0000-00000000000a','22222222-2222-2222-2222-222222222222','completed');
select public.admin_set_claim_status('a0000000-0000-0000-0000-00000000000a','33333333-3333-3333-3333-333333333333','no_show');

\echo ''
\echo '=== 1. Udgangspunkt: opgaven giver 10 point ==='
select p.name, c.status, c.points_awarded, p.points from public.task_claims c
  join public.profiles p on p.id = c.user_id order by p.name;

\echo ''
\echo '=== 2. Admin kan se hvem der bliver berørt ==='
select signed_up, completed, no_show from public.task_claim_counts('a0000000-0000-0000-0000-00000000000a');

\echo ''
\echo '=== 3. Opgaven sættes op til 25 point ==='
update public.tasks set points = 25 where id='a0000000-0000-0000-0000-00000000000a';
select p.name, c.status, c.points_awarded, p.points from public.task_claims c
  join public.profiles p on p.id = c.user_id order by p.name;
\echo '    forventet: alle points_awarded = 25; kun Bo (completed) fik summen ændret 10 -> 25'

\echo ''
\echo '=== 4. Og ned igen til 5 point ==='
update public.tasks set points = 5 where id='a0000000-0000-0000-0000-00000000000a';
select p.name, c.status, c.points_awarded, p.points from public.task_claims c
  join public.profiles p on p.id = c.user_id order by p.name;
\echo '    forventet: Bo 25 -> 5; Anna og Cita stadig 0'

\echo ''
\echo '=== 5. Bo har fået besked begge gange ==='
select n.title, n.body from public.notifications n
 where n.type='points_adjusted' order by n.created_at;

\echo ''
\echo '=== 6. Bekræftelse EFTER ændringen bruger den nye værdi ==='
select public.admin_set_claim_status('a0000000-0000-0000-0000-00000000000a','11111111-1111-1111-1111-111111111111','completed');
select name, points from public.profiles where id='11111111-1111-1111-1111-111111111111';
\echo '    forventet: Anna får 5, ikke de 10 opgaven havde da hun meldte sig'

\echo ''
\echo '=== 7. Ændring der IKKE rører point udløser ingen justering ==='
select 'før' as hvornaar, points from public.profiles where id='22222222-2222-2222-2222-222222222222';
update public.tasks set location = 'Bane 2' where id='a0000000-0000-0000-0000-00000000000a';
select 'efter' as hvornaar, points from public.profiles where id='22222222-2222-2222-2222-222222222222';

\echo ''
\echo '=== 8. Summen kan ikke gå under nul ==='
select public.admin_adjust_points('22222222-2222-2222-2222-222222222222', -3);
select 'før' as hvornaar, points, bonus_points from public.profiles where id='22222222-2222-2222-2222-222222222222';
update public.tasks set points = 0 where id='a0000000-0000-0000-0000-00000000000a';
select 'efter' as hvornaar, points from public.profiles where id='22222222-2222-2222-2222-222222222222';

\echo ''
\echo '=== 9. Sletning af opgaven rydder stadig op bagefter ==='
update public.tasks set points = 12 where id='a0000000-0000-0000-0000-00000000000a';
select p.name, p.points from public.profiles p
 where p.id in ('11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222') order by p.name;
delete from public.tasks where id='a0000000-0000-0000-0000-00000000000a';
select p.name, p.points, p.tasks_done from public.profiles p
 where p.id in ('11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222') order by p.name;
\echo '    forventet: begge tilbage på deres bonus_points, tasks_done = 0'
