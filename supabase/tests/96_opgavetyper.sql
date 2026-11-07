-- Opgavetyperne: Volleyball · Sæsonopgaver · Events.
-- Kør efter 00_supabase_stub.sql og alle migrationer.

\set ON_ERROR_STOP on
\pset pager off

-- ---------------------------------------------------------------- opsætning
insert into auth.users (id, email, raw_user_meta_data) values
  ('e1111111-1111-1111-1111-111111111111','medlem@rvk.dk','{"name":"Mette Medlem","team":"Damer 2"}'),
  ('e4444444-4444-4444-4444-444444444444','formand@randersVK.dk','{"name":"Frida Mand"}');

select set_config('test.uid','e4444444-4444-4444-4444-444444444444',false);
select public.admin_set_approval('e1111111-1111-1111-1111-111111111111', true);

-- Et udsnit, der ligner klubbens egne tjanser: en kampdag, et stævne, to
-- sæsonroller og to ting under FairPlay Cup — hvoraf den ene er en sæsonrolle.
insert into public.tasks (id, title, category, date, date_full, duration_type, time, location, points, spots_total, spots_left, event_navn) values
  ('e0000000-0000-0000-0000-000000000001','Sekretærbordet – Dame 1','Kampafvikling & Sekretærbord','Lør 7. nov','2026-11-07','single','16:00 – 19:00','Arena Randers',30,2,2,null),
  ('e0000000-0000-0000-0000-000000000002','Stævnebord - U17 stævne','Kampafvikling & Sekretærbord','Lør 13. mar','2027-03-13','single','09:00 – 15:00','Arena Randers',30,1,1,null),
  ('e0000000-0000-0000-0000-000000000003','Bage kage','Hygge og Socialt','Man 9. nov','2026-11-09','single','–','Hjemme',10,6,6,null),
  ('e0000000-0000-0000-0000-000000000004','Bestyrelsesmedlem','Klubadministration','jun. 2026 – dec. 2026','2026-06-13','half_season','–','Klubhuset',150,5,5,null),
  ('e0000000-0000-0000-0000-000000000005','Hovedansvarlig for SoMe (Sæson)','Kommunikation & PR','Sæson 2026/27','2026-09-30','year','–','Hjemme',150,2,2,null),
  ('e0000000-0000-0000-0000-000000000006','Medlem af stævneudvalg (planlægning) FairPlayCup','Stævneplanlægning og Afholdelse','Sæson 2026/27','2026-09-30','year','–','Klubhuset',100,6,6,'FairPlay Cup'),
  ('e0000000-0000-0000-0000-000000000007','Kioskvagt ved FairPlay Cup (vagt á 3 timer)','Stævneplanlægning og Afholdelse','Lør 6. feb','2027-02-06','single','10:00 – 13:00','Arena Randers',30,4,4,'FairPlay Cup');

\echo ''
\echo '=== 1. Reglen: event vinder over varighed, varighed over almindelig ==='
select public.opgave_type(null,        'single')      as alm_enkelt,
       public.opgave_type(null,        'half_season') as alm_sæson,
       public.opgave_type(null,        'year')        as alm_år,
       public.opgave_type('FairPlay Cup','single')    as event_enkelt,
       public.opgave_type('FairPlay Cup','year')      as event_sæson;
\echo '    forventet: volleyball | saeson | saeson | event | event'

\echo ''
\echo '=== 2. Tomt og blankt eventnavn er ikke et event ==='
select public.opgave_type('',    'single') as tom,
       public.opgave_type('   ', 'single') as mellemrum,
       public.opgave_type(null,  null)     as alt_tomt;
\echo '    forventet: volleyball | volleyball | volleyball'

\echo ''
\echo '=== 3. De syv tjanser fordeler sig som ventet på de tre faner ==='
select public.opgave_type(event_navn, duration_type) as fane,
       count(*) as antal, sum(points) as point
  from public.tasks
 group by 1 order by 1;
\echo '    forventet: event 2 / 130 | saeson 2 / 300 | volleyball 3 / 70'

\echo ''
\echo '=== 4. Sæsonrollen under cuppen står i Events og IKKE i Sæsonopgaver ==='
select title, duration_type,
       public.opgave_type(event_navn, duration_type) as fane
  from public.tasks
 where id = 'e0000000-0000-0000-0000-000000000006';
\echo '    forventet: year, men fane = event'

\echo ''
\echo '=== 5. Mellemrum i enden af et eventnavn giver ikke to events ==='
update public.tasks set event_navn = '  FairPlay Cup  '
 where id = 'e0000000-0000-0000-0000-000000000007';
select count(distinct event_navn) as forskellige_events,
       count(*) filter (where event_navn = 'FairPlay Cup') as paa_cuppen
  from public.tasks where event_navn is not null;
\echo '    forventet: 1 | 2'

\echo ''
\echo '=== 6. Et eventnavn af bare mellemrum bliver tomt, ikke et event ==='
update public.tasks set event_navn = '   '
 where id = 'e0000000-0000-0000-0000-000000000007';
select event_navn is null as er_tom,
       public.opgave_type(event_navn, duration_type) as fane
  from public.tasks where id = 'e0000000-0000-0000-0000-000000000007';
\echo '    forventet: t | volleyball'

\echo ''
\echo '=== 7. Titler trimmes på vej ind, så to ens tjanser ikke ser forskellige ud ==='
insert into public.tasks (id, title, category, date, date_full, time, location, points, spots_total, spots_left)
values ('e0000000-0000-0000-0000-000000000008','  Stævnebord - U15 stævne  ','Kampafvikling & Sekretærbord','Søn 17. jan','2027-01-17','09:00','Arena Randers',30,1,1);
select '[' || title || ']' as titel from public.tasks where id = 'e0000000-0000-0000-0000-000000000008';
\echo '    forventet: [Stævnebord - U15 stævne]'

\echo ''
\echo '=== 8. At sætte en tjans på et event rører IKKE point, pladser eller tilmeldte ==='
select set_config('test.uid','e1111111-1111-1111-1111-111111111111',false);
insert into public.task_claims (task_id, user_id)
values ('e0000000-0000-0000-0000-000000000001','e1111111-1111-1111-1111-111111111111');
select set_config('test.uid','e4444444-4444-4444-4444-444444444444',false);
delete from public.notifications where user_id = 'e1111111-1111-1111-1111-111111111111';

update public.tasks set event_navn = 'FairPlay Cup'
 where id = 'e0000000-0000-0000-0000-000000000001';

select t.points, t.spots_left,
       (select count(*) from public.task_claims c where c.task_id = t.id)       as tilmeldte,
       (select points from public.profiles where id='e1111111-1111-1111-1111-111111111111') as mettes_point,
       (select count(*) from public.notifications n
         where n.user_id='e1111111-1111-1111-1111-111111111111')                as beskeder
  from public.tasks t where t.id = 'e0000000-0000-0000-0000-000000000001';
\echo '    forventet: 30 | 1 | 1 | 0 | 0 — intet flytter sig'
\echo '    (Mettes egne point er 0, fordi en tilmelding først tæller, når'
\echo '     tjansen er gjort op. Det er ikke eventet, der holder dem tilbage.)'

\echo ''
\echo '=== 9. Et mellemrum i titlen udløser ikke "ny titel"-besked til de tilmeldte ==='
update public.tasks set title = 'Sekretærbordet – Dame 1  '
 where id = 'e0000000-0000-0000-0000-000000000001';
select '[' || title || ']' as titel,
       (select count(*) from public.notifications
         where user_id='e1111111-1111-1111-1111-111111111111' and type='task_changed') as titelbeskeder
  from public.tasks where id = 'e0000000-0000-0000-0000-000000000001';
\echo '    forventet: [Sekretærbordet – Dame 1] | 0'

\echo ''
\echo '=== 10. En RIGTIG titelændring giver stadig besked ==='
update public.tasks set title = 'Sekretærbordet – Herre 1'
 where id = 'e0000000-0000-0000-0000-000000000001';
select count(*) as titelbeskeder from public.notifications
 where user_id='e1111111-1111-1111-1111-111111111111' and type='task_changed';
\echo '    forventet: 1'

\echo ''
\echo '=== 11. Feltet findes, er frit tekst og uden standardværdi ==='
select column_name, data_type, is_nullable, coalesce(column_default,'(ingen)') as standard
  from information_schema.columns
 where table_schema='public' and table_name='tasks' and column_name='event_navn';
\echo '    forventet: event_navn | text | YES | (ingen)'

\echo ''
\echo '=== 12. anon må ikke bruge reglen; medlemmer må ==='
select has_function_privilege('anon','public.opgave_type(text,text)','execute')          as anon,
       has_function_privilege('authenticated','public.opgave_type(text,text)','execute') as medlem,
       has_function_privilege('anon','public.tasks_trim()','execute')                    as anon_trim;
\echo '    forventet: f | t | f'

\echo ''
\echo '=== 13. En tjans kan flyttes af eventet igen og lander i den rigtige fane ==='
update public.tasks set event_navn = null
 where id = 'e0000000-0000-0000-0000-000000000001';
select public.opgave_type(event_navn, duration_type) as fane
  from public.tasks where id = 'e0000000-0000-0000-0000-000000000001';
\echo '    forventet: volleyball'

\echo ''
\echo '=== FÆRDIG ==='
