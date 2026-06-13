-- ============================================================
-- RLS til task_claims + admin-adgang
-- Kør i Supabase Dashboard → SQL Editor → Run
-- ============================================================

alter table public.task_claims enable row level security;

-- Brugere kan se egne claims
drop policy if exists "claims_select_own"   on public.task_claims;
drop policy if exists "claims_insert_own"   on public.task_claims;
drop policy if exists "claims_delete_own"   on public.task_claims;
drop policy if exists "admins_select_claims" on public.task_claims;
drop policy if exists "admins_manage_claims" on public.task_claims;

create policy "claims_select_own" on public.task_claims for select
  using (user_id = auth.uid());

create policy "claims_insert_own" on public.task_claims for insert
  with check (user_id = auth.uid());

create policy "claims_delete_own" on public.task_claims for delete
  using (user_id = auth.uid());

-- Admins kan se alle claims (til tilmeldte-oversigt)
create policy "admins_select_claims" on public.task_claims for select
  using (public.get_my_role() in ('admin', 'super_admin'));

-- Admins kan indsætte og slette alle claims (tildel/fjern)
create policy "admins_manage_claims" on public.task_claims for insert
  with check (public.get_my_role() in ('admin', 'super_admin'));

create policy "admins_delete_claims" on public.task_claims for delete
  using (public.get_my_role() in ('admin', 'super_admin'));
