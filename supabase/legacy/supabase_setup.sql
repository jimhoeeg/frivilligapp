-- ============================================================
-- RVK Frivillig App – Supabase Database Setup
-- Kør dette i Supabase Dashboard → SQL Editor → Run
-- ============================================================

-- 1. PROFILES (udvider auth.users)
create table if not exists public.profiles (
  id          uuid references auth.users(id) on delete cascade primary key,
  name        text not null,
  initials    text generated always as (
                upper(left(split_part(name,' ',1),1) || left(split_part(name,' ',2),1))
              ) stored,
  email       text,
  phone       text,
  team        text,
  role        text not null default 'user' check (role in ('user','admin','super_admin')),
  points      int not null default 0,
  tasks_done  int not null default 0,
  member_since text default to_char(now(),'Month YYYY'),
  created_at  timestamptz default now()
);

-- 2. TASKS
create table if not exists public.tasks (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  category    text not null,
  icon        text not null default 'setup',
  date        text not null,
  date_full   text,
  time        text not null,
  location    text not null,
  points      int not null default 10,
  difficulty  text not null default 'Let' check (difficulty in ('Let','Medium','Hård')),
  urgent      boolean not null default false,
  spots_total int not null default 2,
  spots_left  int not null default 2,
  created_by  uuid references public.profiles(id),
  created_at  timestamptz default now()
);

-- 3. TASK STEPS (vejledning trin)
create table if not exists public.task_steps (
  id          uuid primary key default gen_random_uuid(),
  task_id     uuid references public.tasks(id) on delete cascade,
  step_order  int not null,
  text        text not null
);

-- 4. TASK CLAIMS (hvem har taget en opgave)
create table if not exists public.task_claims (
  id          uuid primary key default gen_random_uuid(),
  task_id     uuid references public.tasks(id) on delete cascade,
  user_id     uuid references public.profiles(id) on delete cascade,
  claimed_at  timestamptz default now(),
  unique(task_id, user_id)
);

-- 5. SWAP OFFERS
create table if not exists public.swap_offers (
  id              uuid primary key default gen_random_uuid(),
  from_user_id    uuid references public.profiles(id) on delete cascade,
  offering_task_id uuid references public.tasks(id) on delete cascade,
  wants_task_id   uuid references public.tasks(id),
  message         text,
  status          text not null default 'available'
                    check (status in ('available','incoming','outgoing','accepted','declined')),
  created_at      timestamptz default now()
);

-- 6. NOTIFICATIONS
create table if not exists public.notifications (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid references public.profiles(id) on delete cascade,
  type            text not null,
  title           text not null,
  body            text,
  read            boolean not null default false,
  action_task_id  uuid references public.tasks(id),
  created_at      timestamptz default now()
);

-- 7. AUDIT LOG
create table if not exists public.audit_log (
  id          uuid primary key default gen_random_uuid(),
  actor_id    uuid references public.profiles(id),
  actor_name  text,
  action      text not null,
  type        text not null,
  created_at  timestamptz default now()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles     enable row level security;
alter table public.tasks        enable row level security;
alter table public.task_steps   enable row level security;
alter table public.task_claims  enable row level security;
alter table public.swap_offers  enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_log    enable row level security;

-- Profiles: alle kan læse, kun sig selv kan opdatere
create policy "profiles_select" on public.profiles for select using (true);
create policy "profiles_insert" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on public.profiles for update using (auth.uid() = id);

-- Tasks: alle kan læse, kun admin+ kan oprette/ændre/slette
create policy "tasks_select"    on public.tasks for select using (true);
create policy "tasks_insert"    on public.tasks for insert with check (
  exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','super_admin'))
);
create policy "tasks_update"    on public.tasks for update using (
  exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','super_admin'))
);
create policy "tasks_delete"    on public.tasks for delete using (
  exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','super_admin'))
);

-- Task steps: alle kan læse, admin+ kan ændre
create policy "task_steps_select" on public.task_steps for select using (true);
create policy "task_steps_all"    on public.task_steps for all using (
  exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','super_admin'))
);

-- Task claims: brugere kan se og oprette egne
create policy "claims_select" on public.task_claims for select using (true);
create policy "claims_insert" on public.task_claims for insert with check (auth.uid() = user_id);
create policy "claims_delete" on public.task_claims for delete using (auth.uid() = user_id);

-- Swap offers: alle kan læse, egne kan ændres
create policy "swaps_select" on public.swap_offers for select using (true);
create policy "swaps_insert" on public.swap_offers for insert with check (auth.uid() = from_user_id);
create policy "swaps_update" on public.swap_offers for update using (auth.uid() = from_user_id);

-- Notifications: kun egne
create policy "notif_select" on public.notifications for select using (auth.uid() = user_id);
create policy "notif_update" on public.notifications for update using (auth.uid() = user_id);

-- Audit log: kun admin+ kan se
create policy "audit_select" on public.audit_log for select using (
  exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','super_admin'))
);
create policy "audit_insert" on public.audit_log for insert with check (
  exists (select 1 from public.profiles where id = auth.uid() and role in ('admin','super_admin'))
);

-- ============================================================
-- BOOTSTRAP SUPER ADMIN
-- Kør dette EFTER du har oprettet din bruger via appen
-- Erstat e-mailen med din rigtige e-mail
-- ============================================================

-- update public.profiles
--   set role = 'super_admin'
--   where email = 'formand@randersVK.dk';

-- ============================================================
-- AUTO-OPRET PROFIL VED SIGNUP (trigger)
-- ============================================================

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, name, email, team, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)),
    new.email,
    coalesce(new.raw_user_meta_data->>'team', ''),
    case
      when new.email in ('formand@randersVK.dk','admin@randersVK.dk')
      then 'super_admin'
      else 'user'
    end
  );
  return new;
end;
$$;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- AUTO-OPDATER POINTS VED CLAIM (trigger)
-- ============================================================

create or replace function public.handle_task_claim()
returns trigger language plpgsql security definer as $$
declare
  task_points int;
begin
  select points into task_points from public.tasks where id = new.task_id;
  update public.profiles
    set points = points + task_points,
        tasks_done = tasks_done + 1
    where id = new.user_id;
  update public.tasks
    set spots_left = spots_left - 1
    where id = new.task_id and spots_left > 0;
  return new;
end;
$$;

create or replace trigger on_task_claimed
  after insert on public.task_claims
  for each row execute procedure public.handle_task_claim();
