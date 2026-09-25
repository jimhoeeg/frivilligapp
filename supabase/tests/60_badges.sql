-- Afprøver mærkerne. Kør efter 00_supabase_stub.sql og alle migrationer.

\set ON_ERROR_STOP on
\pset pager off

insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'anna@rvk.dk', '{"name":"Anna Berg"}'),
  ('22222222-2222-2222-2222-222222222222', 'bo@rvk.dk',   '{"name":"Bo Dahl"}'),
  ('44444444-4444-4444-4444-444444444444', 'formand@randersVK.dk', '{"name":"Frida Mand"}');

select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
select public.admin_set_approval('11111111-1111-1111-1111-111111111111', true);
select public.admin_set_approval('22222222-2222-2222-2222-222222222222', true);

-- Opgaver nok til at ramme en håndfuld forskellige regler.
insert into public.tasks (id,title,category,date,date_full,time,location,points,spots_total,spots_left,difficulty,urgent,duration_type,created_at)
values
 ('a1000000-0000-0000-0000-000000000001','Dommerbord 1','Kampafvikling & Sekretærbord','3. okt','2026-10-03','10:00','Bane 1',10,2,2,'Let',false,'single',now() - interval '30 days'),
 ('a1000000-0000-0000-0000-000000000002','Dommerbord 2','Kampafvikling & Sekretærbord','4. okt','2026-10-04','10:00','Bane 1',10,1,1,'Let',false,'single',now() - interval '30 days'),
 ('a1000000-0000-0000-0000-000000000003','Dommerbord 3','Kampafvikling & Sekretærbord','10. okt','2026-10-10','10:00','Bane 1',10,1,1,'Let',false,'single',now() - interval '30 days'),
 ('a1000000-0000-0000-0000-000000000004','Kiosken','Hygge og Socialt','11. okt','2026-10-11','12:00','Hallen',10,1,1,'Let',true,'single',now() - interval '30 days'),
 ('a1000000-0000-0000-0000-000000000005','Kørsel','Holdleder & Transport','17. okt','2026-10-17','08:00','P-plads',10,1,1,'Let',true,'single',now() - interval '30 days'),
 ('a1000000-0000-0000-0000-000000000006','Stævnebord','Stævneplanlægning og Afholdelse','18. okt','2026-10-18','08:00','Hallen',10,1,1,'Hård',true,'single',now() - interval '30 days'),
 ('a1000000-0000-0000-0000-000000000007','Sæsonrolle','Klubadministration','Sæson','2026-10-24','—','Klubben',75,1,1,'Hård',false,'year',now() - interval '30 days'),
 ('a1000000-0000-0000-0000-000000000008','Samme dag','Faciliteter & Materialer','24. okt','2026-10-24','14:00','Hallen',10,1,1,'Let',false,'single',now() - interval '30 days'),
 ('a1000000-0000-0000-0000-000000000009','Den glemte','Faciliteter & Materialer','25. okt','2026-10-25','10:00','Depot',10,1,1,'Let',false,'single',now() - interval '40 days');

\echo ''
\echo '=== 1. Ingen tjanser, ingen mærker ==='
select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
select count(*) as maerker from public.my_badges();
\echo '    forventet: 0'

\echo ''
\echo '=== 2. To tilmeldinger, som IKKE er bekræftet, giver stadig nul ==='
insert into public.task_claims (task_id,user_id) values
  ('a1000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111'),
  ('a1000000-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111');
select count(*) as maerker from public.my_badges();
\echo '    forventet: 0 – kun bekræftede tjanser tæller'

\echo ''
\echo '=== 3. Anna gennemfører det hele ==='
insert into public.task_claims (task_id,user_id) values
  ('a1000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111'),
  ('a1000000-0000-0000-0000-000000000004','11111111-1111-1111-1111-111111111111'),
  ('a1000000-0000-0000-0000-000000000005','11111111-1111-1111-1111-111111111111'),
  ('a1000000-0000-0000-0000-000000000006','11111111-1111-1111-1111-111111111111'),
  ('a1000000-0000-0000-0000-000000000007','11111111-1111-1111-1111-111111111111'),
  ('a1000000-0000-0000-0000-000000000008','11111111-1111-1111-1111-111111111111'),
  ('a1000000-0000-0000-0000-000000000009','11111111-1111-1111-1111-111111111111');
-- "Den glemte" blev taget 14 dage efter, opgaven blev oprettet.
update public.task_claims set claimed_at = now() - interval '20 days'
  where task_id = 'a1000000-0000-0000-0000-000000000009';

select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
select public.admin_set_claim_status(t.id,'11111111-1111-1111-1111-111111111111','completed')
from public.tasks t where t.id::text like 'a1000000%';

select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
select badge_id, er_ny from public.my_badges() order by badge_id;
select count(*) as fundet, count(*) filter (where er_ny) as heraf_nye from public.my_badges();
\echo '    forventet: alle er nye FØRSTE gang — men kaldet ovenfor har lige gemt dem,'
\echo '    så her er heraf_nye 0. Se linjen over: er_ny var t hele vejen ned.'

\echo ''
\echo '=== 4. De forventede mærker ==='
select
  bool_or(badge_id='kom_godt_igang')  as kom_godt_igang,
  bool_or(badge_id='alsidig')         as alsidig_3_kategorier,
  bool_or(badge_id='altmuligmand')    as altmuligmand_5_kategorier,
  bool_or(badge_id='dommerbordet')    as dommerbordet_3,
  bool_or(badge_id='modig')           as modig_haard,
  bool_or(badge_id='brandslukkeren')  as brandslukkeren_3_haster,
  bool_or(badge_id='den_lange_bane')  as saesonrolle,
  bool_or(badge_id='dobbeltdag')      as to_samme_dag,
  bool_or(badge_id='den_oversete')    as ubesat_14_dage,
  bool_or(badge_id='arbejdshesten')   as ti_tjanser_endnu_ikke
from public.my_badges();
\echo '    forventet: alle sande undtagen den sidste'

\echo ''
\echo '=== 5. er_ny er kun sandt den ene gang ==='
select count(*) filter (where er_ny) as nye_anden_gang from public.my_badges();
\echo '    forventet: 0'

\echo ''
\echo '=== 6. Bo har sine egne (ingen) ==='
select set_config('test.uid','22222222-2222-2222-2222-222222222222',false);
select count(*) as bos_maerker from public.my_badges();
\echo '    forventet: 0'

\echo ''
\echo '=== 7. Mærkerne overlever en sæsonnulstilling ==='
select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
select archived_members from public.admin_reset_season('NULSTIL','2026/2027');
select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
select count(*) as maerker_efter_nulstilling from public.member_badges
  where user_id='11111111-1111-1111-1111-111111111111';
select points as point_efter_nulstilling from public.profiles
  where id='11111111-1111-1111-1111-111111111111';
\echo '    forventet: mærkerne står, pointene er nul'

\echo ''
\echo '=== 8. anon må ikke kalde funktionen eller læse tabellen ==='
select has_function_privilege('anon','public.my_badges()','execute') as anon_execute,
       has_table_privilege('anon','public.member_badges','select')   as anon_select,
       has_function_privilege('authenticated','public.my_badges()','execute') as auth_execute;
\echo '    forventet: f | f | t'

\echo ''
\echo '=== 9. Sletter man et medlem, følger mærkerne med (GDPR) ==='
delete from public.profiles where id='11111111-1111-1111-1111-111111111111';
select count(*) as maerker_efter_sletning from public.member_badges
  where user_id='11111111-1111-1111-1111-111111111111';
\echo '    forventet: 0'
