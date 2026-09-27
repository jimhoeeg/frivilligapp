-- Forældre: et medlem, der også giver point videre til sine børn.
-- Kør efter 00_supabase_stub.sql og alle migrationer.

\set ON_ERROR_STOP on
\pset pager off

insert into auth.users (id, email, raw_user_meta_data) values
  ('a1111111-1111-1111-1111-111111111111','mor@rvk.dk',  '{"name":"Mona Berg"}'),
  ('a2222222-2222-2222-2222-222222222222','barn1@rvk.dk','{"name":"Anna Berg"}'),
  ('a3333333-3333-3333-3333-333333333333','barn2@rvk.dk','{"name":"Bo Berg"}'),
  ('a5555555-5555-5555-5555-555555555555','cita@rvk.dk', '{"name":"Cita Ek"}'),
  ('a4444444-4444-4444-4444-444444444444','formand@randersVK.dk','{"name":"Frida Mand"}');

select set_config('test.uid','a4444444-4444-4444-4444-444444444444',false);
select public.admin_set_approval('a1111111-1111-1111-1111-111111111111', true);
select public.admin_set_approval('a2222222-2222-2222-2222-222222222222', true);
select public.admin_set_approval('a3333333-3333-3333-3333-333333333333', true);
select public.admin_set_approval('a5555555-5555-5555-5555-555555555555', true);

insert into public.tasks (id,title,category,date,date_full,time,location,points,spots_total,spots_left) values
 ('c0000000-0000-0000-0000-000000000001','Kiosk 1','Hygge og Socialt','1. okt','2026-10-01','10:00','Hallen',100,3,3),
 ('c0000000-0000-0000-0000-000000000002','Kiosk 2','Hygge og Socialt','2. okt','2026-10-02','10:00','Hallen',100,3,3),
 ('c0000000-0000-0000-0000-000000000003','Kiosk 3','Hygge og Socialt','3. okt','2026-10-03','10:00','Hallen',100,3,3),
 ('c0000000-0000-0000-0000-000000000004','Kiosk 4','Hygge og Socialt','4. okt','2026-10-04','10:00','Hallen',100,3,3);

\echo ''
\echo '=== 1. Mor tager fire tjanser og bliver bekraeftet: 400 point ==='
select set_config('test.uid','a1111111-1111-1111-1111-111111111111',false);
insert into public.task_claims (task_id,user_id) values
  ('c0000000-0000-0000-0000-000000000001','a1111111-1111-1111-1111-111111111111'),
  ('c0000000-0000-0000-0000-000000000002','a1111111-1111-1111-1111-111111111111'),
  ('c0000000-0000-0000-0000-000000000003','a1111111-1111-1111-1111-111111111111'),
  ('c0000000-0000-0000-0000-000000000004','a1111111-1111-1111-1111-111111111111');
select set_config('test.uid','a4444444-4444-4444-4444-444444444444',false);
select public.admin_set_claim_status(t, 'a1111111-1111-1111-1111-111111111111', 'completed')
  from (values ('c0000000-0000-0000-0000-000000000001'::uuid),('c0000000-0000-0000-0000-000000000002'::uuid),
               ('c0000000-0000-0000-0000-000000000003'::uuid),('c0000000-0000-0000-0000-000000000004'::uuid)) as v(t);
select points as mors_point, public.bidrag_point(id) as mors_bidrag
  from public.profiles where id='a1111111-1111-1111-1111-111111111111';
\echo '    forventet: 400 | 400'

\echo ''
\echo '=== 2. Hun kan IKKE kobles som ren hjaelper – hun spiller selv ==='
do $$ begin
  perform public.admin_set_helper('a1111111-1111-1111-1111-111111111111',
                                  'a2222222-2222-2222-2222-222222222222', true, 'helper');
  raise notice 'FEJL: et medlem med point blev ren hjaelper';
exception when others then raise notice 'OK  – afvist: %', sqlerrm; end $$;

\echo ''
\echo '=== 3. Men som FORAELDER for begge sine boern ==='
select public.admin_set_helper('a1111111-1111-1111-1111-111111111111','a2222222-2222-2222-2222-222222222222', true, 'parent');
select public.admin_set_helper('a1111111-1111-1111-1111-111111111111','a3333333-3333-3333-3333-333333333333', true, 'parent');
select public.er_hjaelper('a1111111-1111-1111-1111-111111111111')  as giver_videre,
       public.kun_hjaelper('a1111111-1111-1111-1111-111111111111') as kun_hjaelper;
\echo '    forventet: t | f  (hun er medlem, ikke ren hjaelper)'

\echo ''
\echo '=== 4. Hun giver to af de fire tjanser videre – én til hvert barn ==='
select set_config('test.uid','a1111111-1111-1111-1111-111111111111',false);
select public.set_claim_credit(
  (select id from public.task_claims where task_id='c0000000-0000-0000-0000-000000000001'),
  'a2222222-2222-2222-2222-222222222222');
select public.set_claim_credit(
  (select id from public.task_claims where task_id='c0000000-0000-0000-0000-000000000002'),
  'a3333333-3333-3333-3333-333333333333');

select p.name,
       p.points                  as rangliste,
       public.bidrag_point(p.id) as bidrag
  from public.profiles p
 where p.id in ('a1111111-1111-1111-1111-111111111111','a2222222-2222-2222-2222-222222222222','a3333333-3333-3333-3333-333333333333')
 order by p.name;
\echo '    forventet: Anna 0/100, Bo 0/100, Mona 400/200'
\echo '    ^ HELE pointen: mors bidrag faldt med praecis det, boernene fik.'
\echo '      400 points arbejde daekker to maal paa 200 – ikke fire.'

\echo ''
\echo '=== 5. Summen kan ikke vokse, uanset hvordan der flyttes ==='
select sum(public.bidrag_point(id)) as bidrag_i_alt,
       (select sum(coalesce(points_awarded,0)) from public.task_claims where status='completed') as arbejde_i_alt
  from public.profiles;
\echo '    forventet: de to tal er ens – intet bliver kopieret'

\echo ''
\echo '=== 6. my_bidrag() viser baade eget maal og det givne ==='
select bidrag, egne, fra_hjaelpere, givet, er_hjaelper, kun_hjaelper from public.my_bidrag();
\echo '    forventet Mona: 200 | 200 | 0 | 200 | t | f'
select member_id, name, givet, kind from public.my_helper_members();
\echo '    forventet: Anna 100 parent, Bo 100 parent'

\echo ''
\echo '=== 7. Barnet ser pointene komme ind ==='
select set_config('test.uid','a2222222-2222-2222-2222-222222222222',false);
select bidrag, egne, fra_hjaelpere, givet, kun_hjaelper from public.my_bidrag();
\echo '    forventet Anna: 100 | 0 | 100 | 0 | f'
select name, point from public.my_helpers();
\echo '    forventet: Mona Berg 100'

\echo ''
\echo '=== 8. Ingen ringe: barnet kan ikke give tilbage til mor ==='
select set_config('test.uid','a4444444-4444-4444-4444-444444444444',false);
do $$ begin
  perform public.admin_set_helper('a2222222-2222-2222-2222-222222222222',
                                  'a1111111-1111-1111-1111-111111111111', true, 'parent');
  raise notice 'FEJL: ringen blev tilladt';
exception when others then raise notice 'OK  – afvist: %', sqlerrm; end $$;

\echo ''
\echo '=== 9. Men kaeder er i orden: mormor -> mor -> barn ==='
select public.admin_set_helper('a5555555-5555-5555-5555-555555555555',
                               'a1111111-1111-1111-1111-111111111111', true, 'parent');
select count(*) as koblinger from public.helper_links;
\echo '    forventet: 3 – en tjans peger altid paa ÉN person, saa point hopper ikke videre'

\echo ''
\echo '=== 10. Den lange ring er ogsaa spaerret (barn -> mormor) ==='
do $$ begin
  perform public.admin_set_helper('a2222222-2222-2222-2222-222222222222',
                                  'a5555555-5555-5555-5555-555555555555', true, 'parent');
  raise notice 'FEJL: den lange ring blev tilladt';
exception when others then raise notice 'OK  – afvist: %', sqlerrm; end $$;

\echo ''
\echo '=== 11. Mor kan tage en tjans tilbage til sig selv ==='
select set_config('test.uid','a1111111-1111-1111-1111-111111111111',false);
select public.set_claim_credit(
  (select id from public.task_claims where task_id='c0000000-0000-0000-0000-000000000001'),
  'a1111111-1111-1111-1111-111111111111');
select public.bidrag_point('a1111111-1111-1111-1111-111111111111') as mor_nu,
       public.bidrag_point('a2222222-2222-2222-2222-222222222222') as anna_nu;
\echo '    forventet: Mona 300, Anna 0'

\echo ''
\echo '=== 12. Flytninger af gjorte-op tjanser staar i audit-loggen ==='
select action from public.audit_log where action ilike '%Flyttede%' order by created_at;
\echo '    forventet: tre linjer med point, opgave og modtager'

\echo ''
\echo '=== 13. Admins liste kender forskel paa foraelder og ren hjaelper ==='
select set_config('test.uid','a4444444-4444-4444-4444-444444444444',false);
select name, points, bidrag, givet_videre, er_hjaelper, kun_hjaelper, hjaelper_for
  from public.admin_list_members()
 where id in ('a1111111-1111-1111-1111-111111111111','a2222222-2222-2222-2222-222222222222')
 order by name;
\echo '    forventet: Mona 400/300/100/t/f, Anna 0/0/0/f/f'

\echo ''
\echo '=== 14. En ren hjaelper er stadig en ren hjaelper ==='
insert into auth.users (id, email, raw_user_meta_data) values
  ('a6666666-6666-6666-6666-666666666666','far@rvk.dk','{"name":"Finn Berg"}');
select public.admin_set_approval('a6666666-6666-6666-6666-666666666666', true);
select public.admin_set_helper('a6666666-6666-6666-6666-666666666666',
                               'a2222222-2222-2222-2222-222222222222', true, 'helper');
select public.kun_hjaelper('a6666666-6666-6666-6666-666666666666') as finn_kun_hjaelper,
       public.kun_hjaelper('a1111111-1111-1111-1111-111111111111') as mona_kun_hjaelper;
\echo '    forventet: t | f'

\echo ''
\echo '=== 15. Anon maa stadig ingenting ==='
select has_function_privilege('anon','public.kun_hjaelper(uuid)','execute')                    as anon_kun,
       has_function_privilege('anon','public.admin_set_helper(uuid,uuid,boolean,text)','execute') as anon_kobl,
       has_function_privilege('authenticated','public.kun_hjaelper(uuid)','execute')           as medlem_kun,
       has_function_privilege('authenticated','public.admin_set_helper(uuid,uuid,boolean,text)','execute') as admin_kobl;
\echo '    forventet: f | f | t | t'
