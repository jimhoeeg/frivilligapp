-- Afprøver hjælpere. Kør efter 00_supabase_stub.sql og alle migrationer.

\set ON_ERROR_STOP on
\pset pager off

insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111','anna@rvk.dk','{"name":"Anna Berg"}'),
  ('22222222-2222-2222-2222-222222222222','bo@rvk.dk',  '{"name":"Bo Berg"}'),
  ('33333333-3333-3333-3333-333333333333','far@rvk.dk', '{"name":"Finn Berg"}'),
  ('55555555-5555-5555-5555-555555555555','cita@rvk.dk','{"name":"Cita Ek"}'),
  ('44444444-4444-4444-4444-444444444444','formand@randersVK.dk','{"name":"Frida Mand"}');

select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
select public.admin_set_approval('11111111-1111-1111-1111-111111111111', true);
select public.admin_set_approval('22222222-2222-2222-2222-222222222222', true);
select public.admin_set_approval('33333333-3333-3333-3333-333333333333', true);
select public.admin_set_approval('55555555-5555-5555-5555-555555555555', true);

insert into public.tasks (id,title,category,date,date_full,time,location,points,spots_total,spots_left) values
 ('b0000000-0000-0000-0000-000000000001','Kiosk 1','Hygge og Socialt','1. okt','2026-10-01','10:00','Hallen',20,3,3),
 ('b0000000-0000-0000-0000-000000000002','Kiosk 2','Hygge og Socialt','2. okt','2026-10-02','10:00','Hallen',30,3,3),
 ('b0000000-0000-0000-0000-000000000003','Kiosk 3','Hygge og Socialt','3. okt','2026-10-03','10:00','Hallen',40,3,3);

\echo ''
\echo '=== 1. Far kobles som hjælper for BEGGE sine børn ==='
select public.admin_set_helper('33333333-3333-3333-3333-333333333333','11111111-1111-1111-1111-111111111111');
select public.admin_set_helper('33333333-3333-3333-3333-333333333333','22222222-2222-2222-2222-222222222222');
select count(*) as koblinger from public.helper_links;
select public.er_hjaelper('33333333-3333-3333-3333-333333333333') as far_er_hjaelper,
       public.er_hjaelper('11111111-1111-1111-1111-111111111111') as anna_er_hjaelper;
\echo '    forventet: 2 koblinger, t | f'

\echo ''
\echo '=== 2. Et medlem MED point kan ikke gøres til hjælper ==='
insert into public.task_claims (task_id,user_id)
values ('b0000000-0000-0000-0000-000000000003','55555555-5555-5555-5555-555555555555');
select public.admin_set_claim_status('b0000000-0000-0000-0000-000000000003','55555555-5555-5555-5555-555555555555','completed');
do $$ begin
  perform public.admin_set_helper('55555555-5555-5555-5555-555555555555','11111111-1111-1111-1111-111111111111');
  raise notice 'FEJL: et medlem med point blev hjælper';
exception when others then raise notice 'OK  – afvist: %', sqlerrm; end $$;

\echo ''
\echo '=== 3. Ingen kæder: den man hjælper må ikke selv være hjælper ==='
do $$ begin
  perform public.admin_set_helper('55555555-5555-5555-5555-555555555555','33333333-3333-3333-3333-333333333333');
  raise notice 'FEJL: kæde tilladt';
exception when others then raise notice 'OK  – afvist'; end $$;

\echo ''
\echo '=== 4. Et MEDLEM må ikke selv koble hjælpere ==='
select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
do $$ begin
  perform public.admin_set_helper('33333333-3333-3333-3333-333333333333','11111111-1111-1111-1111-111111111111');
  raise notice 'FEJL: medlem kunne koble';
exception when others then raise notice 'OK  – afvist'; end $$;

\echo ''
\echo '=== 5. Far tager to tjanser – én til hvert barn ==='
select set_config('test.uid','33333333-3333-3333-3333-333333333333',false);
insert into public.task_claims (task_id,user_id,credited_to) values
  ('b0000000-0000-0000-0000-000000000001','33333333-3333-3333-3333-333333333333','11111111-1111-1111-1111-111111111111'),
  ('b0000000-0000-0000-0000-000000000002','33333333-3333-3333-3333-333333333333','22222222-2222-2222-2222-222222222222');
select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
select public.admin_set_claim_status('b0000000-0000-0000-0000-000000000001','33333333-3333-3333-3333-333333333333','completed');
select public.admin_set_claim_status('b0000000-0000-0000-0000-000000000002','33333333-3333-3333-3333-333333333333','completed');

select name, points as ranglistepoint from public.profiles
 where id in ('11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','33333333-3333-3333-3333-333333333333')
 order by name;
\echo '    forventet: fars 50 point står hos FAR (ranglisten), børnene har 0'

\echo ''
\echo '=== 6. Men bidraget følger børnene ==='
select p.name,
       p.points                     as rangliste,
       public.bidrag_point(p.id)    as bidrag
  from public.profiles p
 where p.id in ('11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','33333333-3333-3333-3333-333333333333')
 order by p.name;
\echo '    forventet: Anna 0/20, Bo 0/30, Finn 50/0'

\echo ''
\echo '=== 7. Far kan ikke give point til en, han ikke hjælper ==='
do $$ begin
  insert into public.task_claims (task_id,user_id,credited_to)
  values ('b0000000-0000-0000-0000-000000000003','33333333-3333-3333-3333-333333333333','55555555-5555-5555-5555-555555555555');
  raise notice 'FEJL: kunne give point til et fremmed medlem';
exception when others then raise notice 'OK  – afvist: %', sqlerrm; end $$;

\echo ''
\echo '=== 8. Et medlems egen tjans tæller for det selv ==='
insert into public.task_claims (task_id,user_id)
values ('b0000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111');
select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
select public.admin_set_claim_status('b0000000-0000-0000-0000-000000000003','11111111-1111-1111-1111-111111111111','completed');
select public.bidrag_point('11111111-1111-1111-1111-111111111111') as annas_bidrag,
       (select points from public.profiles where id='11111111-1111-1111-1111-111111111111') as annas_rangliste;
\echo '    forventet: bidrag 60 (20 fra far + 40 egen), rangliste 40'

\echo ''
\echo '=== 9. Anna kan se sine hjælpere, Finn kan se sine medlemmer ==='
select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
select name, point from public.my_helpers();
select set_config('test.uid','33333333-3333-3333-3333-333333333333',false);
select name from public.my_helper_members();
\echo '    forventet: Anna ser Finn med 20 point; Finn ser Anna og Bo'

\echo ''
\echo '=== 10. Koblingen kan fjernes igen, og pointene bliver hvor de er ==='
select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
select public.admin_set_helper('33333333-3333-3333-3333-333333333333','22222222-2222-2222-2222-222222222222', false);
select public.bidrag_point('22222222-2222-2222-2222-222222222222') as bos_bidrag_efter,
       (select count(*) from public.helper_links) as koblinger_tilbage;
\echo '    forventet: bidraget står stadig på 30 – tjansen husker selv hvem den talte for'

\echo ''
\echo '=== 11. Det står i audit-loggen ==='
select action from public.audit_log where action ilike '%hjælper%' order by created_at;

\echo ''
\echo '=== 12. Anon må ingenting ==='
select has_function_privilege('anon','public.admin_set_helper(uuid,uuid,boolean)','execute') as anon_koble,
       has_table_privilege('anon','public.helper_links','select')                            as anon_laese,
       has_function_privilege('authenticated','public.bidrag_point(uuid)','execute')         as medlem_bidrag;
\echo '    forventet: f | f | t'

\echo ''
\echo '=== 13. my_bidrag() deler tallet op, så appen kan skrive hvor det kommer fra ==='
select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
select bidrag, egne, fra_hjaelpere, bonus, givet, er_hjaelper from public.my_bidrag();
\echo '    forventet Anna: 60 | 40 | 20 | 0 | 0 | f'
select set_config('test.uid','33333333-3333-3333-3333-333333333333',false);
select bidrag, egne, fra_hjaelpere, bonus, givet, er_hjaelper from public.my_bidrag();
\echo '    forventet Finn: 0 | 0 | 0 | 0 | 50 | t  (alt er givet videre)'
select member_id, name, givet from public.my_helper_members();
\echo '    forventet: kun Anna tilbage, 20 point givet'

\echo ''
\echo '=== 14. Hjælperen kan flytte modtageren på sin egen tilmelding ==='
select set_config('test.uid','33333333-3333-3333-3333-333333333333',false);
select public.set_claim_credit(
  (select id from public.task_claims
    where task_id='b0000000-0000-0000-0000-000000000002'
      and user_id='33333333-3333-3333-3333-333333333333'),
  '11111111-1111-1111-1111-111111111111');
select public.bidrag_point('11111111-1111-1111-1111-111111111111') as anna_nu,
       public.bidrag_point('22222222-2222-2222-2222-222222222222') as bo_nu;
\echo '    forventet: Anna 90, Bo 0 – de 30 point flyttede med tjansen'

do $$ begin
  perform public.set_claim_credit(
    (select id from public.task_claims
      where task_id='b0000000-0000-0000-0000-000000000002'
        and user_id='33333333-3333-3333-3333-333333333333'),
    '55555555-5555-5555-5555-555555555555');
  raise notice 'FEJL: kunne pege på et fremmed medlem';
exception when others then raise notice 'OK  – afvist: %', sqlerrm; end $$;

select set_config('test.uid','11111111-1111-1111-1111-111111111111',false);
do $$ begin
  perform public.set_claim_credit(
    (select id from public.task_claims
      where task_id='b0000000-0000-0000-0000-000000000002'
        and user_id='33333333-3333-3333-3333-333333333333'),
    '11111111-1111-1111-1111-111111111111');
  raise notice 'FEJL: kunne rette en andens tilmelding';
exception when others then raise notice 'OK  – afvist'; end $$;

\echo ''
\echo '=== 15. Admins liste viser hjælperen som hjælper ==='
select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);
select name, points, bidrag, fra_hjaelpere, er_hjaelper, hjaelper_for
  from public.admin_list_members()
 where id in ('11111111-1111-1111-1111-111111111111','33333333-3333-3333-3333-333333333333')
 order by name;
\echo '    forventet: Anna 40/90/50/f, Finn 50/0/0/t hjælper for Anna Berg'

\echo ''
\echo '=== 16. Ønsket fra oprettelsen følger med ind, og ryddes ved koblingen ==='
insert into auth.users (id, email, raw_user_meta_data) values
  ('66666666-6666-6666-6666-666666666666','mor@rvk.dk',
   '{"name":"Mona Berg","helper_for":"  Anna Berg  "}');
select helper_request from public.profiles where id='66666666-6666-6666-6666-666666666666';
\echo '    forventet: Anna Berg (uden mellemrum i enderne)'
select public.admin_set_approval('66666666-6666-6666-6666-666666666666', true);
select public.admin_set_helper('66666666-6666-6666-6666-666666666666','11111111-1111-1111-1111-111111111111');
select coalesce(helper_request,'(ryddet)') as efter
  from public.profiles where id='66666666-6666-6666-6666-666666666666';
\echo '    forventet: (ryddet)'

\echo ''
\echo '=== 17. Anon må heller ikke de nye funktioner ==='
select has_function_privilege('anon','public.my_bidrag()','execute')                    as anon_bidrag,
       has_function_privilege('anon','public.set_claim_credit(uuid,uuid)','execute')    as anon_modtager,
       has_function_privilege('authenticated','public.my_bidrag()','execute')           as medlem_bidrag,
       has_function_privilege('authenticated','public.set_claim_credit(uuid,uuid)','execute') as medlem_modtager;
\echo '    forventet: f | f | t | t'
