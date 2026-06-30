-- ============================================================
-- Bytte/overtagelse: atomisk accept_swap RPC
-- Kør i Supabase Dashboard → SQL Editor → Run (efter supabase_setup.sql)
--
-- Modellen er en "overtag tjans"-handover: en frivillig tilbyder sin egen
-- tjans, og en anden frivillig kan overtage den. Overtagelsen flytter
-- claim'et + pointene fra tilbudsgiver til modtager og holder antallet af
-- ledige pladser uændret (én går, én kommer til).
-- ============================================================

create or replace function public.accept_swap(p_offer_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_taker  uuid := auth.uid();
  v_offer  record;
  v_points int;
  v_title  text;
  v_removed int;
begin
  if v_taker is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  -- Lås tilbuddet, så to personer ikke kan overtage den samme tjans
  select * into v_offer from public.swap_offers where id = p_offer_id for update;
  if v_offer is null then
    raise exception 'SWAP_NOT_FOUND';
  end if;
  if v_offer.status <> 'available' then
    raise exception 'SWAP_UNAVAILABLE';
  end if;
  if v_offer.from_user_id = v_taker then
    raise exception 'CANNOT_ACCEPT_OWN';
  end if;

  -- Lås opgaven og hent point/titel
  select points, title into v_points, v_title
    from public.tasks where id = v_offer.offering_task_id for update;
  if v_points is null then
    raise exception 'TASK_NOT_FOUND';
  end if;

  if exists (
    select 1 from public.task_claims
    where task_id = v_offer.offering_task_id and user_id = v_taker
  ) then
    raise exception 'ALREADY_CLAIMED';
  end if;

  -- Fjern tilbudsgiverens claim, rul deres point tilbage og frigør pladsen
  delete from public.task_claims
    where task_id = v_offer.offering_task_id and user_id = v_offer.from_user_id;
  get diagnostics v_removed = row_count;
  if v_removed > 0 then
    update public.profiles
      set points = greatest(0, points - coalesce(v_points, 0)),
          tasks_done = greatest(0, tasks_done - 1)
      where id = v_offer.from_user_id;
    update public.tasks
      set spots_left = spots_left + 1
      where id = v_offer.offering_task_id;
  end if;

  -- Giv tjansen til modtageren (on_task_claimed-triggeren giver point og
  -- tæller pladsen ned igen → netto uændret antal ledige pladser)
  insert into public.task_claims (task_id, user_id)
    values (v_offer.offering_task_id, v_taker);

  -- Markér tilbuddet som overtaget
  update public.swap_offers set status = 'accepted' where id = p_offer_id;

  -- Notificér tilbudsgiveren
  insert into public.notifications (user_id, type, title, body, action_task_id)
  values (
    v_offer.from_user_id,
    'swap_accepted',
    'Dit bytte blev overtaget',
    'En anden frivillig har overtaget "' || coalesce(v_title, 'din tjans') || '".',
    v_offer.offering_task_id
  );
end;
$$;

-- Kun indloggede brugere må kalde RPC'en
revoke all on function public.accept_swap(uuid) from public, anon;
grant execute on function public.accept_swap(uuid) to authenticated;
