-- ============================================================================
-- RVK Frivillig – point følger med, når en opgaves værdi ændres
--
-- Før: hver tilmelding huskede det pointtal, opgaven havde DA man meldte sig.
-- Rettede en admin bagefter opgaven fra 10 til 20 point, beholdt de allerede
-- tilmeldte deres 10. Det var bevidst — men det betød, at to personer kunne
-- få forskelligt betalt for nøjagtig samme tjans, uden at nogen kunne se
-- hvorfor.
--
-- Efter: pointtallet på en opgave er ét tal, og alle på opgaven følger det.
--
--   signed_up   points_awarded opdateres. Intet er udbetalt endnu, så
--               medlemmet ser bare et nyt tal under "afventer bekræftelse".
--   completed   points_awarded opdateres OG summen justeres med forskellen.
--               Medlemmet får besked, for deres point ændrer sig.
--   no_show     points_awarded opdateres for ordens skyld. Ingen point i spil.
--
-- Kør i Supabase Dashboard → SQL Editor → Run. Kan køres flere gange.
-- Kør EFTER de foregående migrationer.
-- ============================================================================

create or replace function public.task_points_changed()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_delta int;
begin
  if new.points is not distinct from old.points then
    return new;
  end if;

  v_delta := new.points - old.points;

  -- 1. Justér summen for dem, der allerede har fået pointene udbetalt.
  --    Gøres før points_awarded opdateres, så forskellen regnes på det
  --    beløb, de faktisk fik.
  update public.profiles p
     set points = greatest(0, p.points + v_delta)
    from public.task_claims c
   where c.user_id = p.id
     and c.task_id = new.id
     and c.status  = 'completed';

  -- 2. Alle tilmeldinger på opgaven får det nye pointtal.
  update public.task_claims
     set points_awarded = new.points
   where task_id = new.id;

  -- 3. Besked til dem, hvis sum faktisk ændrede sig.
  insert into public.notifications (user_id, type, title, body, action_task_id)
  select c.user_id, 'points_adjusted',
         case when v_delta > 0
              then 'En tjans er blevet mere værd'
              else 'Pointene for en tjans er sat ned' end,
         '"' || new.title || '" er rettet fra ' || old.points || ' til '
           || new.points || ' point, og din sum er justeret.',
         new.id
    from public.task_claims c
   where c.task_id = new.id
     and c.status  = 'completed'
     and c.user_id is distinct from auth.uid();

  return new;
end;
$$;

drop trigger if exists on_task_points_changed on public.tasks;
create trigger on_task_points_changed
  after update on public.tasks
  for each row execute procedure public.task_points_changed();


-- ============================================================================
-- Hvor mange bliver berørt, hvis en opgaves point ændres?
-- Bruges til at advare admin, inden ændringen gemmes.
-- ============================================================================

create or replace function public.task_claim_counts(p_task uuid)
returns table (
  signed_up int,
  completed int,
  no_show   int
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select count(*) filter (where status = 'signed_up')::int,
         count(*) filter (where status = 'completed')::int,
         count(*) filter (where status = 'no_show')::int
    from public.task_claims
   where task_id = p_task;
$$;

grant execute on function public.task_claim_counts(uuid) to authenticated;


-- ============================================================================
-- Ret eventuel skævhed fra før denne migration: sæt points_awarded til
-- opgavens nuværende værdi, og genberegn summerne derefter.
-- ============================================================================

update public.task_claims c
   set points_awarded = t.points
  from public.tasks t
 where t.id = c.task_id
   and c.points_awarded is distinct from t.points;

update public.profiles p
   set points     = greatest(0, coalesce(c.pts, 0) + p.bonus_points),
       tasks_done = coalesce(c.cnt, 0)
  from (
        select user_id,
               sum(coalesce(points_awarded, 0))::int as pts,
               count(*)::int                          as cnt
          from public.task_claims
         where status = 'completed'
         group by user_id
       ) c
 where c.user_id = p.id;

update public.profiles p
   set points     = greatest(0, p.bonus_points),
       tasks_done = 0
 where not exists (
        select 1 from public.task_claims tc
         where tc.user_id = p.id and tc.status = 'completed'
       );
