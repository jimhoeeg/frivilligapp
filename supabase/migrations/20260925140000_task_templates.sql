-- ============================================================================
-- RVK Frivillig – klubbens egne skabeloner
--
-- Appen kommer med en fast liste af skabeloner i koden. Den kan klubben ikke
-- rette i, og hver gang en admin har opbygget en god opgave — med den rigtige
-- vejledning, de rigtige point og det rigtige antal pladser — går arbejdet
-- tabt, næste gang den samme tjans skal oprettes.
--
-- Her kan admins gemme en udfyldt opgave som skabelon i en af de eksisterende
-- kategorier. De står side om side med appens egne i skabelonvælgeren.
--
-- Skabeloner er ikke personoplysninger og ikke følsomme: det er klubbens
-- beskrivelse af en tjans. Alle indloggede kan læse dem, så en admin ikke
-- møder en tom liste af den forkerte grund. Kun admins kan oprette og slette.
--
-- Kan køres flere gange uden at gøre skade.
-- ============================================================================

create table if not exists public.task_templates (
  id          uuid primary key default gen_random_uuid(),
  category    text not null,
  title       text not null,
  points      int  not null default 10,
  difficulty  text not null default 'Let' check (difficulty in ('Let', 'Medium', 'Hård')),
  spots_total int  not null default 2,
  duration_type text default 'single',
  time        text,
  location    text,
  icon        text not null default 'setup',
  description text,
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  -- Samme titel to gange i samme kategori er altid en fejl: enten en dublet
  -- eller et forsøg på at rette en, der allerede findes.
  unique (category, title)
);

create index if not exists task_templates_category_idx on public.task_templates (category, title);

alter table public.task_templates enable row level security;

drop policy if exists "templates_select" on public.task_templates;
drop policy if exists "templates_insert" on public.task_templates;
drop policy if exists "templates_update" on public.task_templates;
drop policy if exists "templates_delete" on public.task_templates;

create policy "templates_select" on public.task_templates for select
  using (auth.uid() is not null);

create policy "templates_insert" on public.task_templates for insert
  with check (public.get_my_role() in ('admin', 'super_admin'));

create policy "templates_update" on public.task_templates for update
  using (public.get_my_role() in ('admin', 'super_admin'));

create policy "templates_delete" on public.task_templates for delete
  using (public.get_my_role() in ('admin', 'super_admin'));


-- ============================================================================
-- HVEM STÅR PÅ EN OPGAVE?
--
-- Et medlem skal kunne se, hvem der allerede har taget tjansen, før de selv
-- melder sig. Tabellen kan de godt læse, men den indeholder kun user_id —
-- og navnet ligger i profiles, som kun udleverer udvalgte kolonner.
--
-- Funktionen giver navn, initialer og hold. Ikke e-mail og ikke telefon: at
-- vide hvem man står på vagt med er ikke det samme som at få deres
-- kontaktoplysninger.
-- ============================================================================

create or replace function public.task_signups(p_task uuid)
returns table (
  user_id  uuid,
  name     text,
  initials text,
  team     text,
  status   text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'Du skal være logget ind';
  end if;

  return query
    select p.id, p.name, p.initials, p.team, c.status
      from public.task_claims c
      join public.profiles p on p.id = c.user_id
     where c.task_id = p_task
     order by c.claimed_at;
end;
$$;

revoke execute on function public.task_signups(uuid) from public, anon;
grant  execute on function public.task_signups(uuid) to authenticated;


-- ============================================================================
-- EFTERSYN
--
--   select count(*) from public.task_templates;
--   select * from public.task_signups('<opgave-id>');
-- ============================================================================
