-- ============================================================================
-- RVK Frivillig – grundskema
--
-- Dette er udgangspunktet: tabeller, kolonner og indekser. Intet andet.
--
-- Der er med vilje INGEN politikker, funktioner eller triggere her. De kommer
-- fra migrationerne efter denne. Grunden er, at de gamle løse SQL-filer i
-- supabase/legacy/ blandede skema og adgangsregler sammen — og den blanding
-- betød, at en genkørsel af "opsætningsfilen" gendannede politikken
-- "profiles ... for select using (true)", altså den der gjorde hele
-- medlemslisten læsbar uden login. Den slags må ikke kunne ske ved et uheld.
--
-- Rækkefølgen er derfor: dette skema først, derefter migrationerne i
-- navnerækkefølge. Kører man KUN denne fil, er databasen låst (RLS slået til
-- uden politikker) — ubrugelig, men sikker. Det er den rigtige vej at fejle.
--
-- Filen kan køres flere gange uden at gøre skade.
-- ============================================================================


-- ============================================================================
-- MEDLEMMER
-- ============================================================================

create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  name         text not null,
  initials     text generated always as (
                 upper(left(split_part(name, ' ', 1), 1) || left(split_part(name, ' ', 2), 1))
               ) stored,
  email        text,
  phone        text,
  team         text,
  role         text not null default 'user' check (role in ('user', 'admin', 'super_admin')),
  points       int  not null default 0,
  tasks_done   int  not null default 0,
  member_since text default to_char(now(), 'Month YYYY'),
  created_at   timestamptz default now()
);


-- ============================================================================
-- HOLD
-- ============================================================================

create table if not exists public.teams (
  id         uuid primary key default gen_random_uuid(),
  name       text unique not null,
  created_at timestamptz default now()
);


-- ============================================================================
-- OPGAVER
-- ============================================================================

create table if not exists public.tasks (
  id            uuid primary key default gen_random_uuid(),
  title         text not null,
  category      text not null,
  icon          text not null default 'setup',
  date          text not null,
  date_full     text,
  date_end      text,
  duration_type text default 'single',
  time          text not null,
  location      text not null,
  points        int  not null default 10,
  difficulty    text not null default 'Let' check (difficulty in ('Let', 'Medium', 'Hård')),
  urgent        boolean not null default false,
  spots_total   int not null default 2,
  spots_left    int not null default 2,
  created_by    uuid references public.profiles(id),
  created_at    timestamptz default now()
);

create table if not exists public.task_steps (
  id         uuid primary key default gen_random_uuid(),
  task_id    uuid references public.tasks(id) on delete cascade,
  step_order int  not null,
  text       text not null
);


-- ============================================================================
-- TILMELDINGER
-- ============================================================================

create table if not exists public.task_claims (
  id         uuid primary key default gen_random_uuid(),
  task_id    uuid references public.tasks(id) on delete cascade,
  user_id    uuid references public.profiles(id) on delete cascade,
  claimed_at timestamptz default now(),
  unique (task_id, user_id)
);


-- ============================================================================
-- BYTTE
-- ============================================================================

create table if not exists public.swap_offers (
  id               uuid primary key default gen_random_uuid(),
  from_user_id     uuid references public.profiles(id) on delete cascade,
  offering_task_id uuid references public.tasks(id) on delete cascade,
  wants_task_id    uuid references public.tasks(id),
  message          text,
  status           text not null default 'available'
                     check (status in ('available', 'incoming', 'outgoing', 'accepted', 'declined')),
  created_at       timestamptz default now()
);


-- ============================================================================
-- BESKEDER
-- ============================================================================

create table if not exists public.notifications (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid references public.profiles(id) on delete cascade,
  type           text not null,
  title          text not null,
  body           text,
  read           boolean not null default false,
  action_task_id uuid references public.tasks(id) on delete set null,
  created_at     timestamptz default now()
);


-- ============================================================================
-- LOG OG INDSTILLINGER
-- ============================================================================

create table if not exists public.audit_log (
  id         uuid primary key default gen_random_uuid(),
  type       text not null,
  action     text not null,
  actor_id   uuid references public.profiles(id) on delete set null,
  actor_name text,
  created_at timestamptz default now()
);

create table if not exists public.settings (
  key        text primary key,
  value      text not null,
  updated_at timestamptz default now()
);


-- ============================================================================
-- RLS SLÅS TIL PÅ ALT
--
-- Uden politikker betyder det "ingen adgang". Politikkerne kommer i
-- 20260910120000_launch_hardening.sql og senere.
-- ============================================================================

alter table public.profiles      enable row level security;
alter table public.teams         enable row level security;
alter table public.tasks         enable row level security;
alter table public.task_steps    enable row level security;
alter table public.task_claims   enable row level security;
alter table public.swap_offers   enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_log     enable row level security;
alter table public.settings      enable row level security;


-- ============================================================================
-- INDEKSER
-- ============================================================================

create index if not exists task_claims_user_id_idx     on public.task_claims (user_id);
create index if not exists task_claims_task_id_idx     on public.task_claims (task_id);
create index if not exists task_steps_task_id_idx      on public.task_steps (task_id);
create index if not exists notifications_user_read_idx on public.notifications (user_id, created_at desc);
create index if not exists swap_offers_status_idx      on public.swap_offers (status);
create index if not exists audit_log_created_idx       on public.audit_log (created_at desc);


-- ============================================================================
-- FILER: bucket til profilbilleder
--
-- Politikkerne på bucket'en sættes i migrationerne. Springes over, hvis
-- storage-udvidelsen ikke er slået til (fx i en lokal testdatabase).
-- ============================================================================

do $$ begin
  insert into storage.buckets (id, name, public)
  values ('avatars', 'avatars', true)
  on conflict (id) do nothing;
exception when others then
  raise notice 'storage ikke tilgængelig (%) – springer avatars-bucket over.', sqlerrm;
end $$;
