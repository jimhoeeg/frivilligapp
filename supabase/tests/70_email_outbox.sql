-- Afprøver mailudbakken. Kør efter 00_supabase_stub.sql og alle migrationer.

\set ON_ERROR_STOP on
\pset pager off

insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'anna@rvk.dk', '{"name":"Anna Berg"}'),
  ('22222222-2222-2222-2222-222222222222', 'bo@rvk.dk',   '{"name":"Bo Dahl"}'),
  ('44444444-4444-4444-4444-444444444444', 'formand@randersVK.dk', '{"name":"Frida Mand"}');

select set_config('test.uid','44444444-4444-4444-4444-444444444444',false);

\echo ''
\echo '=== 1. "Du er godkendt" lander i udbakken ==='
select public.admin_set_approval('11111111-1111-1111-1111-111111111111', true);
select kind, to_email, subject, data->>'navn' as navn from public.email_outbox order by id;
\echo '    forventet: én række, approved, anna@rvk.dk'

\echo ''
\echo '=== 2. Kun de fire slags – en "point godkendt" giver ingen mail ==='
insert into public.notifications (user_id, type, title, body)
values ('11111111-1111-1111-1111-111111111111','task_completed','Point godkendt','10 point');
select count(*) as i_udbakken from public.email_outbox;
\echo '    forventet: stadig 1'

\echo ''
\echo '=== 3. Tildelt en tjans: opgavens dato og sted kommer med ==='
insert into public.tasks (id,title,category,date,date_full,time,location,points,spots_total,spots_left)
values ('a2000000-0000-0000-0000-000000000001','Kioskvagt','Hygge og Socialt','Lør 3. okt',
        (current_date + 2)::text,'10:00 – 12:00','Arena Randers',10,2,2);
insert into public.notifications (user_id, type, title, body, action_task_id)
values ('11111111-1111-1111-1111-111111111111','task_assigned','Du er sat på en tjans',
        'Kioskvagt lørdag','a2000000-0000-0000-0000-000000000001');
select kind, subject, data->>'opgave' as opgave, data->>'tid' as tid, data->>'sted' as sted
from public.email_outbox where kind='task_assigned';
\echo '    forventet: Kioskvagt · 10:00 – 12:00 · Arena Randers'

\echo ''
\echo '=== 4. Et medlem uden e-mail vælter ingenting ==='
update public.profiles set email = null where id='22222222-2222-2222-2222-222222222222';
select public.admin_set_approval('22222222-2222-2222-2222-222222222222', true);
select count(*) as i_udbakken from public.email_outbox;
\echo '    forventet: 2 – Bo fik sin besked i appen, men ingen mail'

\echo ''
\echo '=== 5. Påmindelser: to dage før, og kun til den tilmeldte ==='
insert into public.task_claims (task_id,user_id)
values ('a2000000-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111');
select public.queue_task_reminders(2) as lagt_i_udbakken;
select kind, subject, data->>'dato' as dato from public.email_outbox where kind='reminder';
\echo '    forventet: 1 lagt, "Husk: Kioskvagt"'

\echo ''
\echo '=== 6. Kører jobbet igen, sendes den IKKE to gange ==='
select public.queue_task_reminders(2) as lagt_anden_gang;
select count(*) as paamindelser from public.email_outbox where kind='reminder';
\echo '    forventet: 0 lagt, stadig 1 påmindelse'

\echo ''
\echo '=== 7. Har man slået påmindelser fra, får man ingen ==='
delete from public.email_outbox where kind='reminder';
update public.profiles set email_reminders = false where id='11111111-1111-1111-1111-111111111111';
select public.queue_task_reminders(2) as lagt_naar_slaaet_fra;
\echo '    forventet: 0'
update public.profiles set email_reminders = true where id='11111111-1111-1111-1111-111111111111';

\echo ''
\echo '=== 8. En bekræftet tjans påmindes ikke ==='
update public.task_claims set status='completed' where user_id='11111111-1111-1111-1111-111111111111';
select public.queue_task_reminders(2) as lagt_for_bekraeftet;
\echo '    forventet: 0'
update public.task_claims set status='signed_up' where user_id='11111111-1111-1111-1111-111111111111';

\echo ''
\echo '=== 9. Udbakken banker på, når der er noget at sende ==='
insert into vault.decrypted_secrets (name, decrypted_secret) values
  ('outbox_key','hemmelig'), ('outbox_url','https://projekt.supabase.co/functions/v1/send-mail');
select public.queue_task_reminders(2);
select public.drain_email_outbox() as resultat;
select url, headers->>'x-outbox-key' as noegle from net.kald order by id desc limit 1;
\echo '    forventet: bankede paa send-mail, med nøglen fra Vault'

\echo ''
\echo '=== 10. Er alt sendt, bankes der ikke på ==='
update public.email_outbox set sent_at = now();
select public.drain_email_outbox() as resultat;
\echo '    forventet: ingenting at sende'

\echo ''
\echo '=== 11. Mangler nøglen i Vault, larmer det ikke ==='
update public.email_outbox set sent_at = null;
delete from vault.decrypted_secrets where name='outbox_key';
select public.drain_email_outbox() as resultat;
\echo '    forventet: en pæn besked om at nøglen mangler'

\echo ''
\echo '=== 12. Ingen andre end serveren må røre udbakken ==='
select has_table_privilege('anon','public.email_outbox','select')          as anon_select,
       has_table_privilege('authenticated','public.email_outbox','select') as auth_select,
       has_function_privilege('authenticated','public.queue_task_reminders(int)','execute') as auth_execute;
\echo '    forventet: f | f | f'

\echo ''
\echo '=== 12b. Medlemmet må selv slå påmindelser fra – men intet andet ==='
select has_column_privilege('authenticated','public.profiles','email_reminders','update') as maa_slaa_fra,
       has_column_privilege('authenticated','public.profiles','points','update')          as maa_rette_point,
       has_column_privilege('authenticated','public.profiles','role','update')            as maa_rette_rolle;
\echo '    forventet: t | f | f'

\echo ''
\echo '=== 13. Slettes medlemmet, følger udbakken med (GDPR) ==='
delete from public.profiles where id='11111111-1111-1111-1111-111111111111';
select count(*) as tilbage from public.email_outbox
  where user_id='11111111-1111-1111-1111-111111111111';
\echo '    forventet: 0'
