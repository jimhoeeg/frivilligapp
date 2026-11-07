-- Månedens frivillige. Kør efter 00_supabase_stub.sql og alle migrationer.

\set ON_ERROR_STOP on
\pset pager off

-- ---------------------------------------------------------------- opsætning
insert into auth.users (id, email, raw_user_meta_data) values
  ('f1111111-1111-1111-1111-111111111111','sidse@rvk.dk',   '{"name":"Sidse Sommer","team":"Damer 2"}'),
  ('f2222222-2222-2222-2222-222222222222','nicolas@rvk.dk', '{"name":"Nicolas Frandsen","team":"Herrer 1"}'),
  ('f3333333-3333-3333-3333-333333333333','sanne@rvk.dk',   '{"name":"Sanne Mor"}'),
  ('f4444444-4444-4444-4444-444444444444','formand@randersVK.dk','{"name":"Frida Mand"}'),
  ('f5555555-5555-5555-5555-555555555555','sara@rvk.dk',    '{"name":"Sara Datter","team":"Teen"}');

select set_config('test.uid','f4444444-4444-4444-4444-444444444444',false);
select public.admin_set_approval('f1111111-1111-1111-1111-111111111111', true);
select public.admin_set_approval('f2222222-2222-2222-2222-222222222222', true);
select public.admin_set_approval('f3333333-3333-3333-3333-333333333333', true);
select public.admin_set_approval('f5555555-5555-5555-5555-555555555555', true);

-- Sanne er hjælper for Sara: hun møder op, Sara får pointene.
select public.admin_set_helper('f3333333-3333-3333-3333-333333333333',
                               'f5555555-5555-5555-5555-555555555555', true, 'helper');

-- Oktober 2026: tre enkeltdags-tjanser, en halvsæson-rolle og en i november.
insert into public.tasks (id, title, category, date, date_full, duration_type, time, location, points, spots_total, spots_left) values
  ('f0000000-0000-0000-0000-00000000000a','Sekretærbord 1','Kampafvikling','Lør 3. okt','2026-10-03','single','16:00','Arena',30,3,3),
  ('f0000000-0000-0000-0000-00000000000b','Sekretærbord 2','Kampafvikling','Lør 10. okt','2026-10-10','single','16:00','Arena',30,3,3),
  ('f0000000-0000-0000-0000-00000000000c','Bage kage','Hygge','Man 12. okt','2026-10-12','single','–','Hjemme',10,3,3),
  ('f0000000-0000-0000-0000-00000000000d','Bestyrelsespost','Klubadministration','okt. 2026 – apr. 2027','2026-10-01','half_season','–','Klubhuset',150,3,3),
  ('f0000000-0000-0000-0000-00000000000e','Boldlanger','Kampafvikling','Søn 8. nov','2026-11-08','single','14:00','Arena',20,3,3);

-- Sidse tager de to sekretærbordsvagter (60 point, 2 tjanser).
select set_config('test.uid','f1111111-1111-1111-1111-111111111111',false);
insert into public.task_claims (task_id, user_id) values
  ('f0000000-0000-0000-0000-00000000000a','f1111111-1111-1111-1111-111111111111'),
  ('f0000000-0000-0000-0000-00000000000b','f1111111-1111-1111-1111-111111111111');

-- Nicolas tager KUN sæsonrollen (150 point, men den løber et halvt år).
select set_config('test.uid','f2222222-2222-2222-2222-222222222222',false);
insert into public.task_claims (task_id, user_id) values
  ('f0000000-0000-0000-0000-00000000000d','f2222222-2222-2222-2222-222222222222');

-- Sanne bager kage i oktober — pointene går til Sara.
select set_config('test.uid','f3333333-3333-3333-3333-333333333333',false);
insert into public.task_claims (task_id, user_id, credited_to) values
  ('f0000000-0000-0000-0000-00000000000c','f3333333-3333-3333-3333-333333333333','f5555555-5555-5555-5555-555555555555');

-- Og Sidse tager en i november, så månederne kan holdes fra hinanden.
select set_config('test.uid','f1111111-1111-1111-1111-111111111111',false);
insert into public.task_claims (task_id, user_id) values
  ('f0000000-0000-0000-0000-00000000000e','f1111111-1111-1111-1111-111111111111');

-- Alt gøres op af klubben.
select set_config('test.uid','f4444444-4444-4444-4444-444444444444',false);
select public.admin_confirm_task(id) from public.tasks;

\echo ''
\echo '=== 1. Kun bekræftede tjanser tæller — uden godkendelse er listen tom ==='
-- Vi laver en ny tjans, som INGEN gør op.
insert into public.tasks (id, title, category, date, date_full, duration_type, time, location, points, spots_total, spots_left)
values ('f0000000-0000-0000-0000-00000000000f','Ikke gjort op','Hygge','Tir 20. okt','2026-10-20','single','–','Hjemme',50,2,2);
select set_config('test.uid','f2222222-2222-2222-2222-222222222222',false);
insert into public.task_claims (task_id, user_id) values ('f0000000-0000-0000-0000-00000000000f','f2222222-2222-2222-2222-222222222222');
select set_config('test.uid','f4444444-4444-4444-4444-444444444444',false);
select navn, tjanser, point from public.maanedens_kandidater('2026-10-01')
 where navn = 'Nicolas Frandsen';
\echo '    forventet: ingen rækker — Nicolas har kun en sæsonrolle og en utilmeldt-opgjort tjans'

\echo ''
\echo '=== 2. Oktobers kandidater: sæsonrollen holdes ude, hjælperen står med ==='
select navn, tjanser, point, kun_hjaelper
  from public.maanedens_kandidater('2026-10-01');
\echo '    forventet: Sidse 2/60, Sanne Mor 1/10 (kun_hjaelper = t). Nicolas er IKKE med.'

\echo ''
\echo '=== 3. Æren følger den der mødte op — ikke den der fik pointene ==='
select (select count(*) from public.maanedens_kandidater('2026-10-01') where navn = 'Sanne Mor')   as sanne_med,
       (select count(*) from public.maanedens_kandidater('2026-10-01') where navn = 'Sara Datter') as sara_med,
       (select points from public.profiles where id='f5555555-5555-5555-5555-555555555555')        as saras_point,
       (select points from public.profiles where id='f3333333-3333-3333-3333-333333333333')        as sannes_point;
\echo '    forventet: 1 | 0 | 10 | 0 — Sara har pointene, Sanne har æren'

\echo ''
\echo '=== 4. November er sin egen måned ==='
select navn, tjanser, point from public.maanedens_kandidater('2026-11-01');
\echo '    forventet: kun Sidse 1/20'

\echo ''
\echo '=== 5. En måned uden noget i giver en tom liste — ikke en fejl ==='
select count(*) as kandidater from public.maanedens_kandidater('2026-07-01');
\echo '    forventet: 0'

\echo ''
\echo '=== 6. Datoen i måneden er ligegyldig — kun måneden tæller ==='
select count(*) as fra_den_17 from public.maanedens_kandidater('2026-10-17');
\echo '    forventet: 2 — samme svar som den 1.'

\echo ''
\echo '=== 7. Klubben vælger, og valget gemmes med navnet ==='
select public.admin_vaelg_maanedens('2026-10-01', 'f1111111-1111-1111-1111-111111111111',
                                    'Tog to sekretærbordsvagter på to uger');
select maaned, navn_dengang, begrundelse,
       valgt_af = 'f4444444-4444-4444-4444-444444444444' as valgt_af_frida,
       valgt_at is not null as har_tidspunkt
  from public.maanedens_frivillige;
\echo '    forventet: 2026-10-01 | Sidse Sommer | Tog to sekretærbordsvagter... | t | t'

\echo ''
\echo '=== 8. Den hædrede får besked OG en mail i udbakken ==='
select n.type, n.title, n.body like '%oktober 2026%' as naevner_maaneden,
       n.body like '%sekretærbordsvagter%'            as naevner_begrundelsen
  from public.notifications n
 where n.user_id = 'f1111111-1111-1111-1111-111111111111' and n.type = 'maanedens_frivillige';
select kind, subject, to_email from public.email_outbox where kind = 'maanedens_frivillige';
\echo '    forventet: besked med måned og begrundelse + én mail til sidse@rvk.dk'

\echo ''
\echo '=== 9. Der kan kun være én pr. måned — et nyt valg erstatter det gamle ==='
select public.admin_vaelg_maanedens('2026-10-01', 'f3333333-3333-3333-3333-333333333333',
                                    'Bagte kage uden at blive spurgt');
select count(*) as raekker_for_oktober from public.maanedens_frivillige where maaned = '2026-10-01';
select navn_dengang, begrundelse from public.maanedens_frivillige where maaned = '2026-10-01';
\echo '    forventet: 1 række | Sanne Mor | Bagte kage uden at blive spurgt'

\echo ''
\echo '=== 10. Valget er FROSSET: en senere rettelse flytter ikke hædringen ==='
-- Sidse får 500 point for oktober bagefter. Hædringen skal stå, hvor den står.
update public.tasks set points = 500 where id = 'f0000000-0000-0000-0000-00000000000a';
select navn_dengang from public.maanedens_frivillige where maaned = '2026-10-01';
select navn, point from public.maanedens_kandidater('2026-10-01') order by point desc limit 1;
\echo '    forventet: hædringen står på Sanne Mor, mens kandidatlisten nu har Sidse øverst'

\echo ''
\echo '=== 11. Navnet overlever, at medlemmet slettes ==='
select public.admin_vaelg_maanedens('2026-11-01', 'f1111111-1111-1111-1111-111111111111', 'November');
delete from public.profiles where id = 'f1111111-1111-1111-1111-111111111111';
select maaned, navn_dengang, user_id is null as medlem_slettet
  from public.maanedens_frivillige where maaned = '2026-11-01';
\echo '    forventet: 2026-11-01 | Sidse Sommer | t — æreslisten har ikke fået et hul'

\echo ''
\echo '=== 12. Et almindeligt medlem kan ikke hædre nogen ==='
select set_config('test.uid','f2222222-2222-2222-2222-222222222222',false);
do $$ begin
  perform public.admin_vaelg_maanedens('2026-09-01', 'f2222222-2222-2222-2222-222222222222', 'Mig selv');
  raise notice 'FEJL: et medlem kunne hædre sig selv';
exception when others then raise notice 'OK  – afvist: %', sqlerrm; end $$;

\echo ''
\echo '=== 13. En måned, der ikke er begyndt, kan ingen have fortjent ==='
select set_config('test.uid','f4444444-4444-4444-4444-444444444444',false);
do $$ begin
  perform public.admin_vaelg_maanedens((date_trunc('month', current_date) + interval '2 months')::date,
                                       'f3333333-3333-3333-3333-333333333333', 'Fremtiden');
  raise notice 'FEJL: en kommende måned blev accepteret';
exception when others then raise notice 'OK  – afvist: %', sqlerrm; end $$;

\echo ''
\echo '=== 14. Valget kan fortrydes ==='
select public.admin_fjern_maanedens('2026-11-01');
select count(*) as tilbage from public.maanedens_frivillige where maaned = '2026-11-01';
select count(*) as i_loggen from public.audit_log where action like '%månedens frivillige%';
\echo '    forventet: 0 tilbage | 4 linjer i loggen (3 valg + 1 fjernet)'

\echo ''
\echo '=== 15. Alle medlemmer må LÆSE hædringen, men ingen må skrive i den ==='
select has_table_privilege('authenticated','public.maanedens_frivillige','select') as maa_laese,
       has_table_privilege('authenticated','public.maanedens_frivillige','insert') as maa_skrive,
       has_table_privilege('authenticated','public.maanedens_frivillige','update') as maa_rette,
       has_table_privilege('anon','public.maanedens_frivillige','select')          as anon_laeser;
\echo '    forventet: t | f | f | f'

\echo ''
\echo '=== 16. Månedsnavnet står på dansk ==='
select public.dansk_maaned('2026-10-01') as okt, public.dansk_maaned('2027-05-14') as maj;
\echo '    forventet: oktober 2026 | maj 2027'

\echo ''
\echo '=== 17. Påmindelsen rammer kun administratorer ==='
delete from public.notifications where type = 'maanedens_paamindelse';
delete from public.maanedens_frivillige;
-- Sidste måned er oktober, og den HAR kandidater. Frida er den eneste admin.
select public.paamind_om_maanedens() as beskeder_sendt;
select p.name, n.title, n.body like '%oktober 2026%' as naevner_maaneden
  from public.notifications n join public.profiles p on p.id = n.user_id
 where n.type = 'maanedens_paamindelse';
\echo '    forventet: 1 besked, til Frida Mand, med "oktober 2026" i'

\echo ''
\echo '=== 18. Den kommer ikke to gange, hvis jobbet kører igen ==='
select public.paamind_om_maanedens() as anden_koersel;
select count(*) as beskeder_i_alt from public.notifications where type = 'maanedens_paamindelse';
\echo '    forventet: 0 | 1 — ingen dobbelt påmindelse'

\echo ''
\echo '=== 19. Er der valgt, mindes der ikke om noget ==='
delete from public.notifications where type = 'maanedens_paamindelse';
select public.admin_vaelg_maanedens((date_trunc('month', current_date) - interval '1 month')::date,
                                    'f3333333-3333-3333-3333-333333333333', 'Allerede valgt');
select public.paamind_om_maanedens() as efter_valg;
\echo '    forventet: 0'

\echo ''
\echo '=== 20. Et medlem får ikke administratorernes påmindelse ==='
select count(*) as til_nicolas from public.notifications
 where type = 'maanedens_paamindelse' and user_id = 'f2222222-2222-2222-2222-222222222222';
\echo '    forventet: 0'

\echo ''
\echo '=== FÆRDIG ==='
