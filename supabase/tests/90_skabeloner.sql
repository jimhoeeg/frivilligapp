-- Skabelonerne: én liste, klubben ejer. Kør efter 00_supabase_stub.sql og
-- alle migrationer.

\set ON_ERROR_STOP on
\pset pager off

insert into auth.users (id, email, raw_user_meta_data) values
  ('d1111111-1111-1111-1111-111111111111','medlem@rvk.dk','{"name":"Mette Medlem"}'),
  ('d4444444-4444-4444-4444-444444444444','formand@randersVK.dk','{"name":"Frida Mand"}');

select set_config('test.uid','d4444444-4444-4444-4444-444444444444',false);
select public.admin_set_approval('d1111111-1111-1111-1111-111111111111', true);

\echo ''
\echo '=== 1. Appens 40 forslag ligger i databasen efter migrationen ==='
select count(*) as skabeloner, count(distinct category) as kategorier
  from public.task_templates;
\echo '    forventet: 40 | 7'

\echo ''
\echo '=== 2. Hver skabelon har fået et ikon — ingen står tilbage som "setup" uden grund ==='
select count(*) filter (where icon is null or icon = '') as uden_ikon,
       count(distinct icon)                              as forskellige_ikoner
  from public.task_templates;
\echo '    forventet: 0 uden ikon, mange forskellige'

\echo ''
\echo '=== 3. Den kan køres igen uden at lave dubletter ==='
select public.seed_task_templates() as nye_anden_gang;
select count(*) as i_alt from public.task_templates;
\echo '    forventet: 0 | 40'

\echo ''
\echo '=== 4. Admin kan rette en skabelon, og det bliver skrevet hvem og hvornår ==='
update public.task_templates
   set points = 99, description = 'Rettet af klubben'
 where title = 'Kioskvagt til alm. hjemmekamp (ca. 2-3 timer)';
select title, points, description,
       updated_by = 'd4444444-4444-4444-4444-444444444444' as rettet_af_frida,
       updated_at is not null                              as har_tidspunkt
  from public.task_templates where title = 'Kioskvagt til alm. hjemmekamp (ca. 2-3 timer)';
\echo '    forventet: 99 | Rettet af klubben | t | t'

\echo ''
\echo '=== 5. "Gendan appens forslag" skriver IKKE hen over klubbens rettelse ==='
select public.seed_task_templates() as nye;
select points, description from public.task_templates
 where title = 'Kioskvagt til alm. hjemmekamp (ca. 2-3 timer)';
\echo '    forventet: 0 nye, og de 99 point står der endnu'

\echo ''
\echo '=== 6. Slettes en skabelon, kan den hentes tilbage — og kun den ==='
delete from public.task_templates where title = 'Bage kage / lave madpakker til et hold';
select count(*) as efter_sletning from public.task_templates;
select public.seed_task_templates() as hentet_tilbage;
select count(*) as efter_gendan from public.task_templates;
select points from public.task_templates where title = 'Kioskvagt til alm. hjemmekamp (ca. 2-3 timer)';
\echo '    forventet: 39 | 1 | 40 — og kiosken har stadig klubbens 99 point'

\echo ''
\echo '=== 7. To skabeloner må ikke hedde det samme i samme kategori ==='
do $$ begin
  update public.task_templates
     set title = 'Bage kage / lave madpakker til et hold'
   where title = 'Kioskvagt til alm. hjemmekamp (ca. 2-3 timer)';
  raise notice 'FEJL: dublet tilladt';
exception when unique_violation then raise notice 'OK  – afvist som dublet';
          when others then raise notice 'OK  – afvist: %', sqlerrm; end $$;

\echo ''
\echo '=== 8. Et almindeligt medlem må se dem, men ikke røre dem ==='
select set_config('test.uid','d1111111-1111-1111-1111-111111111111',false);
select count(*) > 0 as medlem_kan_se from public.task_templates;
do $$ begin
  perform public.seed_task_templates();
  raise notice 'FEJL: medlem kunne hente forslag';
exception when others then raise notice 'OK  – afvist: %', sqlerrm; end $$;

\echo ''
\echo '=== 9. Rettigheder: kun admins skriver ==='
select has_table_privilege('anon','public.task_templates','select')                  as anon_laese,
       has_function_privilege('anon','public.seed_task_templates()','execute')        as anon_seed,
       has_function_privilege('authenticated','public.seed_task_templates()','execute') as medlem_seed;
\echo '    forventet: f | f | t  (medlemmet stoppes inde i funktionen, ikke af rettigheden)'

\echo ''
\echo '=== 10. Politikkerne på tabellen ==='
select policyname, cmd from pg_policies
 where schemaname = 'public' and tablename = 'task_templates'
 order by policyname;
\echo '    forventet: select for alle indloggede, insert/update/delete kun admin'
