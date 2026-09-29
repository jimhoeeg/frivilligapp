-- Fordoblingen: virker mekanikken, den hviler på?
-- Kør efter 00_supabase_stub.sql og alle migrationer.

\set ON_ERROR_STOP on
\pset pager off

insert into auth.users (id, email, raw_user_meta_data) values
  ('f1111111-1111-1111-1111-111111111111','anna@rvk.dk','{"name":"Anna Berg"}'),
  ('f4444444-4444-4444-4444-444444444444','formand@randersVK.dk','{"name":"Frida Mand"}');
select set_config('test.uid','f4444444-4444-4444-4444-444444444444',false);
select public.admin_set_approval('f1111111-1111-1111-1111-111111111111', true);

insert into public.tasks (id,title,category,date,date_full,time,location,points,spots_total,spots_left) values
 ('e0000000-0000-0000-0000-000000000001','Kiosk','Hygge og Socialt','1. okt','2026-10-01','10:00','Hallen',20,3,3),
 ('e0000000-0000-0000-0000-000000000002','Net','Faciliteter & Materialer','2. okt','2026-10-02','09:00','Hallen',10,3,3);

\echo ''
\echo '=== 1. Anna tager begge og faar den ene bekraeftet ==='
select set_config('test.uid','f1111111-1111-1111-1111-111111111111',false);
insert into public.task_claims (task_id,user_id) values
  ('e0000000-0000-0000-0000-000000000001','f1111111-1111-1111-1111-111111111111'),
  ('e0000000-0000-0000-0000-000000000002','f1111111-1111-1111-1111-111111111111');
select set_config('test.uid','f4444444-4444-4444-4444-444444444444',false);
select public.admin_set_claim_status('e0000000-0000-0000-0000-000000000001','f1111111-1111-1111-1111-111111111111','completed');
select points as sum_foer from public.profiles where id='f1111111-1111-1111-1111-111111111111';
\echo '    forventet: 20 (kun den bekraeftede taeller)'

\echo ''
\echo '=== 2. Alt fordobles — som migrationen gør det ==='
update public.tasks set points = points * 2;

select title, points from public.tasks order by title;
\echo '    forventet: Kiosk 40, Net 20'

select points as sum_efter from public.profiles where id='f1111111-1111-1111-1111-111111111111';
\echo '    forventet: 40 — den, der gjorde arbejdet FØR, faar ogsaa det dobbelte'

select t.title, c.status, c.points_awarded
  from public.task_claims c join public.tasks t on t.id = c.task_id
 order by t.title;
\echo '    forventet: Kiosk completed 40, Net signed_up 20 — begge fulgte med'

\echo ''
\echo '=== 3. Besked kun til den, hvis SUM aendrede sig ==='
select count(*) as beskeder from public.notifications
 where user_id='f1111111-1111-1111-1111-111111111111' and type='points_adjusted';
\echo '    forventet: 1 — kun den bekraeftede tjans flyttede hendes sum.'
\echo '    Den, hun bare staar tilmeldt, er ikke udbetalt endnu, og et nyt tal'
\echo '    under "afventer bekraeftelse" er ikke en nyhed, der skal larme.'
select body from public.notifications
 where user_id='f1111111-1111-1111-1111-111111111111' and type='points_adjusted';
\echo '    forventet: beskeden siger baade det gamle og det nye tal'

\echo ''
\echo '=== 4. Ingen af dem bliver til en mail ==='
select count(*) as mails_i_koe from public.email_outbox
 where kind = 'points_adjusted';
\echo '    forventet: 0 — kun godkendelse, tildeling, aendring og aflysning sendes ud'

\echo ''
\echo '=== 5. Summen stemmer stadig med tilmeldingerne ==='
select p.points                                        as paa_profilen,
       coalesce(sum(c.points_awarded) filter (where c.status='completed'), 0) as fra_tilmeldinger
  from public.profiles p
  left join public.task_claims c on c.user_id = p.id
 where p.id='f1111111-1111-1111-1111-111111111111'
 group by p.points;
\echo '    forventet: de to tal er ens'
