\set ON_ERROR_STOP on
\pset pager off

-- ---------------------------------------------------------------- opsætning
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'anna@rvk.dk',   '{"name":"Anna Berg","team":"Damer 2","phone":"+4520000001"}'),
  ('22222222-2222-2222-2222-222222222222', 'bo@rvk.dk',     '{"name":"Bo Dahl","team":"Herrer 1"}'),
  ('33333333-3333-3333-3333-333333333333', 'cita@rvk.dk',   '{"name":"Cita Ek","team":"Damer 2"}'),
  ('44444444-4444-4444-4444-444444444444', 'formand@randersVK.dk', '{"name":"Frida Mand"}');

\echo '=== 1. Ny bruger oprettes IKKE godkendt, bootstrap-admin gør ==='
select name, role, approved, phone is not null as har_telefon
  from public.profiles order by name;

-- Gør Anna og Bo til godkendte medlemmer, Frida er admin.
select public.admin_set_approval('11111111-1111-1111-1111-111111111111', true) from (select set_config('test.uid','44444444-4444-4444-4444-444444444444',false)) _;
select public.admin_set_approval('22222222-2222-2222-2222-222222222222', true);

insert into public.tasks (id, title, category, date, time, location, points, spots_total, spots_left)
values ('aaaaaaaa-0000-0000-0000-000000000001', 'Dommerbord U15', 'Kampafvikling', '4. okt', '10:00 – 12:00', 'Bane 1', 15, 1, 1),
       ('aaaaaaaa-0000-0000-0000-000000000002', 'Kagebagning',    'Hygge',         '5. okt', '09:00 – 11:00', 'Cafeen', 10, 2, 2);

\echo ''
\echo '=== 2. Ikke-godkendt medlem kan ikke tage en tjans ==='
select set_config('test.uid','33333333-3333-3333-3333-333333333333',false);
do $$ begin
  insert into public.task_claims (task_id, user_id)
  values ('aaaaaaaa-0000-0000-0000-000000000001','33333333-3333-3333-3333-333333333333');
  raise notice 'FEJL: tilmelding blev accepteret';
exception when others then raise notice 'OK  – afvist: %', sqlerrm;
end $$;

\echo ''
\echo '=== 3. Point og pladser tælles én gang ==='
select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
insert into public.task_claims (task_id, user_id)
values ('aaaaaaaa-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111');

select p.name, p.points, p.tasks_done, t.spots_left
  from public.profiles p, public.tasks t
 where p.id='11111111-1111-1111-1111-111111111111'
   and t.id='aaaaaaaa-0000-0000-0000-000000000001';

\echo ''
\echo '=== 4. Fuld opgave kan ikke tages (punkt 6) ==='
select set_config('test.uid','22222222-2222-2222-2222-222222222222',false);
do $$ begin
  insert into public.task_claims (task_id, user_id)
  values ('aaaaaaaa-0000-0000-0000-000000000001','22222222-2222-2222-2222-222222222222');
  raise notice 'FEJL: tilmelding til fuld opgave blev accepteret';
exception when others then raise notice 'OK  – afvist: %', sqlerrm;
end $$;

\echo ''
\echo '=== 5. Afmelding ruller point OG plads tilbage ==='
select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
delete from public.task_claims
 where task_id='aaaaaaaa-0000-0000-0000-000000000001'
   and user_id='11111111-1111-1111-1111-111111111111';
select p.points, p.tasks_done, t.spots_left
  from public.profiles p, public.tasks t
 where p.id='11111111-1111-1111-1111-111111111111'
   and t.id='aaaaaaaa-0000-0000-0000-000000000001';

\echo ''
\echo '=== 6. Bytte: tilmelding OG point flytter, tilbuddet lukkes (punkt 5) ==='
insert into public.task_claims (task_id, user_id)
values ('aaaaaaaa-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111');
insert into public.swap_offers (id, from_user_id, offering_task_id, message, status)
values ('bbbbbbbb-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111',
        'aaaaaaaa-0000-0000-0000-000000000001','Jeg er blevet syg','available');

select set_config('test.uid','22222222-2222-2222-2222-222222222222',false);
select public.accept_swap('bbbbbbbb-0000-0000-0000-000000000001');

select p.name, p.points, p.tasks_done from public.profiles p
 where p.id in ('11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222')
 order by p.name;
select 'tilmeldte på opgaven' as hvad, count(*) from public.task_claims
 where task_id='aaaaaaaa-0000-0000-0000-000000000001';
select status, accepted_by is not null as har_modtager from public.swap_offers
 where id='bbbbbbbb-0000-0000-0000-000000000001';
select 'ledige pladser' as hvad, spots_left from public.tasks
 where id='aaaaaaaa-0000-0000-0000-000000000001';

\echo ''
\echo '=== 7. Man kan ikke overtage sin egen tjans / et lukket tilbud ==='
select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
do $$ begin
  perform public.accept_swap('bbbbbbbb-0000-0000-0000-000000000001');
  raise notice 'FEJL: lukket tilbud blev accepteret igen';
exception when others then raise notice 'OK  – afvist: %', sqlerrm;
end $$;

\echo ''
\echo '=== 8. Notifikationer bliver faktisk oprettet (punkt 10a) ==='
select p.name as modtager, n.type, n.title
  from public.notifications n join public.profiles p on p.id = n.user_id
 order by n.created_at, n.title;

\echo ''
\echo '=== 9. Ændret opgave giver de tilmeldte besked ==='
select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
update public.tasks set date = '11. okt' where id='aaaaaaaa-0000-0000-0000-000000000001';
select p.name as modtager, n.title, n.body from public.notifications n
  join public.profiles p on p.id = n.user_id
 where n.type='task_changed';

\echo ''
\echo '=== 10. Slettet opgave: besked + point trukket tilbage, ingen FK-fejl ==='
delete from public.tasks where id='aaaaaaaa-0000-0000-0000-000000000001';
select p.name, p.points, p.tasks_done from public.profiles p
 where p.id='22222222-2222-2222-2222-222222222222';
select n.type, n.title, n.action_task_id is null as opgave_ref_ryddet
  from public.notifications n where n.type='task_cancelled';

\echo ''
\echo '=== 11. Bonuspoint holdes adskilt (punkt 2) ==='
select public.admin_adjust_points('11111111-1111-1111-1111-111111111111', 25);
select name, points, bonus_points, tasks_done from public.profiles
 where id='11111111-1111-1111-1111-111111111111';

\echo ''
\echo '=== 12. Almindeligt medlem kan ikke regulere point eller se kontaktdata ==='
select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
do $$ begin
  perform public.admin_adjust_points('22222222-2222-2222-2222-222222222222', 500);
  raise notice 'FEJL: medlem kunne give sig selv point';
exception when others then raise notice 'OK  – afvist: %', sqlerrm;
end $$;
do $$ begin
  perform public.admin_list_members();
  raise notice 'FEJL: medlem kunne hente kontaktoplysninger';
exception when others then raise notice 'OK  – afvist: %', sqlerrm;
end $$;

\echo ''
\echo '=== 13. Egen profil kan stadig hentes med e-mail og telefon ==='
select (public.my_profile()).name, (public.my_profile()).email, (public.my_profile()).phone;

\echo ''
\echo '=== 14. Kolonnerettigheder: authenticated må ikke læse email/phone ==='
select
  has_column_privilege('authenticated','public.profiles','email','select') as email_laesbar,
  has_column_privilege('authenticated','public.profiles','phone','select') as phone_laesbar,
  has_column_privilege('authenticated','public.profiles','name','select')  as name_laesbar,
  has_table_privilege ('anon','public.profiles','select')                  as anon_laesbar;

\echo ''
\echo '=== 15. Triggere på task_claims – der må kun være vores tre ==='
select tgname from pg_trigger
 where tgrelid='public.task_claims'::regclass and not tgisinternal order by tgname;
