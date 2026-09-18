-- Afprøver automatisk bekræftelse efter X dage.
-- Kør efter 00_supabase_stub.sql, basisskemaet og alle migrationer.

\set ON_ERROR_STOP on
\pset pager off

insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'anna@rvk.dk', '{"name":"Anna Berg"}'),
  ('44444444-4444-4444-4444-444444444444', 'formand@randersVK.dk', '{"name":"Frida Mand"}');

select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
select public.admin_set_approval('11111111-1111-1111-1111-111111111111', true);

-- Fem opgaver der rammer hver sin gren af reglen.
insert into public.tasks (id, title, category, date, date_full, date_end, duration_type, time, location, points, spots_total, spots_left)
values
  ('a0000000-0000-0000-0000-000000000001', 'Forfalden (8 dage siden)',  'Hygge', 'gammel',
     (current_date - 8)::text,  null, 'single', '10:00', 'Hallen', 15, 1, 1),
  ('a0000000-0000-0000-0000-000000000002', 'For frisk (3 dage siden)',  'Hygge', 'nyere',
     (current_date - 3)::text,  null, 'single', '10:00', 'Hallen', 10, 1, 1),
  ('a0000000-0000-0000-0000-000000000003', 'Udeblev (8 dage siden)',    'Hygge', 'gammel',
     (current_date - 8)::text,  null, 'single', '10:00', 'Hallen', 12, 1, 1),
  ('a0000000-0000-0000-0000-000000000004', 'Kun dansk dato',            'Hygge', '3. aug',
     null,                      null, 'single', '10:00', 'Hallen', 20, 1, 1),
  ('a0000000-0000-0000-0000-000000000005', 'Sæsonopgave',               'Hygge', 'Sæson 25/26',
     (current_date - 200)::text, (current_date - 9)::text, 'year', '', 'Hallen', 25, 1, 1);

select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
insert into public.task_claims (task_id, user_id)
select id, '11111111-1111-1111-1111-111111111111' from public.tasks order by title;

-- Én af dem har admin allerede markeret som udeblevet.
select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
select public.admin_set_claim_status('a0000000-0000-0000-0000-000000000003',
       '11111111-1111-1111-1111-111111111111', 'no_show');

\echo ''
\echo '=== 1. Før kørsel: intet er bekræftet af sig selv ==='
select t.title, c.status from public.task_claims c
  join public.tasks t on t.id = c.task_id order by t.title;
select name, points from public.profiles where id='11111111-1111-1111-1111-111111111111';

\echo ''
\echo '=== 2. Admin kan se hvad der venter ==='
select days_setting, due_now, due_next_24h, unparseable from public.auto_confirm_preview();

\echo ''
\echo '=== 3. Kørsel: kun de forfaldne med sikker dato ==='
select public.auto_confirm_due_claims(true) as antal_bekraeftede;
select t.title, c.status from public.task_claims c
  join public.tasks t on t.id = c.task_id order by t.title;

\echo ''
\echo '=== 4. Point tilføjet: 15 (forfalden) + 25 (sæson) = 40 ==='
select name, points, tasks_done from public.profiles
 where id='11111111-1111-1111-1111-111111111111';

\echo ''
\echo '=== 5. Beskeden fortæller at det skete automatisk ==='
select title, body from public.notifications
 where type='task_completed' order by created_at limit 1;

\echo ''
\echo '=== 6. Spærretid: nyt kald uden force gør ingenting ==='
-- "For frisk" rykkes 30 dage tilbage, så den nu ER forfalden.
update public.tasks set date_full = (current_date - 30)::text
 where id='a0000000-0000-0000-0000-000000000002';
select public.auto_confirm_due_claims() as uden_force_forventet_0;
select public.auto_confirm_due_claims(true) as med_force;

\echo ''
\echo '=== 7. Slået fra: 0 dage rører intet ==='
update public.settings set value='0' where key='auto_confirm_days';
insert into public.tasks (id,title,category,date,date_full,time,location,points,spots_total,spots_left)
values ('a0000000-0000-0000-0000-000000000006','Efter slukning','Hygge','gammel',
        (current_date - 40)::text,'10:00','Hallen',5,1,1);
insert into public.task_claims (task_id,user_id)
values ('a0000000-0000-0000-0000-000000000006','11111111-1111-1111-1111-111111111111');
select public.auto_confirm_due_claims(true) as slaaet_fra_forventet_0;
select status from public.task_claims where task_id='a0000000-0000-0000-0000-000000000006';

\echo ''
\echo '=== 8. Slået til igen med 30 dage – den nye opgave er stadig for frisk ==='
update public.settings set value='30' where key='auto_confirm_days';
update public.tasks set date_full=(current_date - 20)::text
 where id='a0000000-0000-0000-0000-000000000006';
select public.auto_confirm_due_claims(true) as forventet_0;
update public.tasks set date_full=(current_date - 31)::text
 where id='a0000000-0000-0000-0000-000000000006';
select public.auto_confirm_due_claims(true) as forventet_1;
select status from public.task_claims where task_id='a0000000-0000-0000-0000-000000000006';

\echo ''
\echo '=== 9. Et almindeligt medlem må gerne kalde den (men ikke se oversigten) ==='
update public.settings set value='7' where key='auto_confirm_days';
select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
do $$ begin
  perform public.auto_confirm_due_claims(true);
  raise notice 'OK  – medlem må køre opgørelsen';
exception when others then raise notice 'FEJL: %', sqlerrm;
end $$;
do $$ begin
  perform public.auto_confirm_preview();
  raise notice 'FEJL: medlem så admin-oversigten';
exception when others then raise notice 'OK  – oversigt afvist: %', sqlerrm;
end $$;

\echo ''
\echo '=== 10. En automatisk godkendelse kan fortrydes som enhver anden ==='
select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
select 'FØR' as hvornaar, points from public.profiles where id='11111111-1111-1111-1111-111111111111';
select public.admin_set_claim_status('a0000000-0000-0000-0000-000000000001',
       '11111111-1111-1111-1111-111111111111', 'no_show');
-- Opgaven gav 15 point, så summen skal falde med præcis 15.
select 'EFTER' as hvornaar, points from public.profiles where id='11111111-1111-1111-1111-111111111111';

\echo ''
\echo '=== 11. Og den bliver ikke godkendt igen ved næste kørsel ==='
select public.auto_confirm_due_claims(true) as forventet_0;
select status from public.task_claims where task_id='a0000000-0000-0000-0000-000000000001';
