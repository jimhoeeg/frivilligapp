-- ============================================================================
-- HJÆLPERE
--
-- En forælder, en kæreste, en nabo — nogen, der ikke er medlem, men gerne
-- tager en tjans for et medlem. Klubben vil have dem ind i appen, og deres
-- arbejde skal tælle for medlemmet.
--
-- ---------------------------------------------------------------------------
-- DET HER ER IKKE POINTOVERFØRSEL. Og det er hele pointen.
--
-- I samme øjeblik appen kan flytte point fra én konto til en anden, findes
-- maskineriet — og så bliver det brugt mellem to medlemmer, "bare lige denne
-- ene gang", af en admin der vil nogen det godt. Derfor flytter ingenting
-- her. Point bliver liggende, hvor de blev tjent.
--
-- I stedet skrives det på selve tilmeldingen, HVEM tjansen tæller for
-- (task_claims.credited_to). Det står der for altid, også hvis koblingen
-- senere ændres, og det kan ses i en opgørelse et år efter.
--
-- ---------------------------------------------------------------------------
-- TO TAL, DER BETYDER HVER SIN TING
--
--   profiles.points      hvad man SELV har lavet.   → ranglisten
--   bidrag_point(id)     medlemmets egne + hjælpernes. → frivilligbidraget
--
-- Ranglisten er anerkendelse: en hjælper står der med sit eget navn og sine
-- egne point, for det var hende, der mødte op. Bidragsordningen er penge:
-- dér tæller det, husstanden har leveret.
--
-- Derfor rører denne migration IKKE de triggere, der lægger point til og
-- trækker fra. Det er appens mest ømtålelige kode, og den behøver ikke at
-- vide, at hjælpere findes.
-- ============================================================================


-- ------------------------------------------------------------ KOBLINGEN ---

create table if not exists public.helper_links (
  helper_id  uuid        not null references public.profiles(id) on delete cascade,
  member_id  uuid        not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  created_by uuid        references public.profiles(id) on delete set null,
  primary key (helper_id, member_id),
  constraint helper_ikke_sig_selv check (helper_id <> member_id)
);

comment on table public.helper_links is
  'Hvem hjælper hvem. En hjælper kan have flere medlemmer (fx to børn).';

create index if not exists helper_links_member_idx on public.helper_links (member_id);

alter table public.helper_links enable row level security;

-- Alle indloggede må se koblingerne: appen skal kunne skrive "hjælper for
-- Anna" på en tjans, og medlemmet skal kunne se, hvem der hjælper dem.
-- Der står ingen personoplysninger i tabellen — kun to id'er.
drop policy if exists helper_links_select on public.helper_links;
create policy helper_links_select on public.helper_links
  for select to authenticated using (true);

revoke all on public.helper_links from public, anon;
grant select on public.helper_links to authenticated;
-- Ingen skriver direkte. Det gør admin_set_helper() nedenfor.


-- ---------------------------------------------------------- ØNSKET VED ---
--
-- En hjælper kan ikke se medlemslisten, før hun er lukket ind — og skal
-- heller ikke kunne det. Derfor skriver hun ved oprettelsen bare navnet på
-- den, hun hjælper, i fri tekst. Admin læser det på godkendelseskortet og
-- vælger det rigtige medlem fra listen. Så er det ét menneske, der afgør
-- koblingen, og ikke en stavemåde.

alter table public.profiles
  add column if not exists helper_request text;

comment on column public.profiles.helper_request is
  'Fri tekst fra oprettelsen: "jeg hjælper Anna Berg". Ryddes, når admin har lavet koblingen.';


-- Navnet skal med fra oprettelsen ind i profilen. Resten af funktionen er
-- uændret; den skrives om i sin helhed, fordi det er sådan, en funktion
-- rettes i Postgres.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_is_bootstrap boolean;
begin
  v_is_bootstrap := new.email in ('formand@randersVK.dk', 'admin@randersVK.dk');

  insert into public.profiles (id, name, email, phone, team, role, approved, reviewed_at,
                               helper_request)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.email,
    nullif(new.raw_user_meta_data->>'phone', ''),
    coalesce(new.raw_user_meta_data->>'team', ''),
    case when v_is_bootstrap then 'super_admin' else 'user' end,
    v_is_bootstrap,
    case when v_is_bootstrap then now() else null end,
    -- Teksten er skrevet af en fremmed. 120 tegn er rigeligt til et navn,
    -- og sætter et loft over, hvad der kan lægges i databasen herfra.
    nullif(left(trim(coalesce(new.raw_user_meta_data->>'helper_for', '')), 120), '')
  )
  on conflict (id) do nothing;

  return new;
end;
$$;


-- ------------------------------------------------- HVEM TÆLLER TJANSEN FOR ---

alter table public.task_claims
  add column if not exists credited_to uuid references public.profiles(id) on delete set null;

comment on column public.task_claims.credited_to is
  'Hvilket medlem tjansen tæller for i bidragsordningen. NULL = den, der tog den.';

create index if not exists task_claims_credited_idx
  on public.task_claims (credited_to) where credited_to is not null;

-- Et medlem må vælge modtager for sin egen tilmelding — men kun et medlem,
-- man rent faktisk er koblet til. Ellers ville "vælg modtager" være præcis
-- den pointoverførsel, vi ikke bygger.
create or replace function public.tc_check_credited_to()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.credited_to is null or new.credited_to = new.user_id then
    return new;
  end if;

  if not exists (
    select 1 from public.helper_links hl
     where hl.helper_id = new.user_id and hl.member_id = new.credited_to
  ) then
    raise exception 'Tjansen kan kun tælle for et medlem, du er hjælper for';
  end if;

  return new;
end;
$$;

drop trigger if exists tc_credited_to_check on public.task_claims;
create trigger tc_credited_to_check
  before insert or update of credited_to on public.task_claims
  for each row execute function public.tc_check_credited_to();


-- ------------------------------------------------------- BIDRAGSTALLET ---

create or replace function public.bidrag_point(p_user uuid)
returns int
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select greatest(0,
    coalesce((
      select sum(coalesce(tc.points_awarded, 0))::int
        from public.task_claims tc
       where tc.status = 'completed'
         and coalesce(tc.credited_to, tc.user_id) = p_user
    ), 0)
    + coalesce((select bonus_points from public.profiles where id = p_user), 0)
  );
$$;

comment on function public.bidrag_point(uuid) is
  'Point der tæller mod frivilligbidraget: egne tjanser + hjælpernes + bonus. Ranglisten bruger profiles.points i stedet.';


-- --------------------------------------------------- ER MAN HJÆLPER? ---

create or replace function public.er_hjaelper(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (select 1 from public.helper_links where helper_id = p_user);
$$;


-- ------------------------------------------------- ADMIN SÆTTER KOBLINGEN ---
--
-- Fire spærrer, og de er der hver af sin grund:
--
--   1. Kun admins. En kobling flytter, hvem der slipper for at betale.
--   2. Et MEDLEM MED POINT kan ikke gøres til hjælper. Det er den regel, der
--      lukker døren mellem to medlemmer: kan man ikke blive hjælper efter at
--      have tjent point, kan man heller ikke begynde at sende dem videre.
--   3. Den, man hjælper, må ikke selv være hjælper. Ingen kæder.
--   4. Alt havner i audit-loggen.

create or replace function public.admin_set_helper(
  p_helper uuid,
  p_member uuid,
  p_on     boolean default true
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_helper record;
  v_member record;
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan koble en hjælper til et medlem';
  end if;

  select id, name, points, role into v_helper from public.profiles where id = p_helper;
  select id, name into v_member from public.profiles where id = p_member;

  if v_helper.id is null then raise exception 'Hjælperen findes ikke'; end if;
  if v_member.id is null then raise exception 'Medlemmet findes ikke'; end if;

  if not p_on then
    delete from public.helper_links where helper_id = p_helper and member_id = p_member;
    insert into public.audit_log (type, action, actor_name, actor_id)
    select 'member',
           format('Fjernede %s som hjælper for %s', v_helper.name, v_member.name),
           coalesce(p.name, 'Ukendt'), p.id
      from public.profiles p where p.id = auth.uid();
    return;
  end if;

  if p_helper = p_member then
    raise exception 'Man kan ikke være hjælper for sig selv';
  end if;

  -- Har man allerede tjent point som medlem, kan man ikke blive hjælper.
  if not public.er_hjaelper(p_helper) and coalesce(v_helper.points, 0) > 0 then
    raise exception 'Kontoen har allerede optjent point som medlem og kan ikke gøres til hjælper';
  end if;

  if public.er_hjaelper(p_member) then
    raise exception 'Den, man hjælper, må ikke selv være hjælper';
  end if;

  if exists (select 1 from public.helper_links where member_id = p_helper) then
    raise exception 'Kontoen har selv hjælpere og kan ikke være hjælper for andre';
  end if;

  insert into public.helper_links (helper_id, member_id, created_by)
  values (p_helper, p_member, auth.uid())
  on conflict do nothing;

  -- Ønsket fra tilmeldingen er efterkommet, og skal ikke blive stående og
  -- se ud som noget, der mangler at blive gjort.
  update public.profiles set helper_request = null
   where id = p_helper and helper_request is not null;

  insert into public.audit_log (type, action, actor_name, actor_id)
  select 'member',
         format('Koblede %s som hjælper for %s', v_helper.name, v_member.name),
         coalesce(p.name, 'Ukendt'), p.id
    from public.profiles p where p.id = auth.uid();
end;
$$;


-- ------------------------------------------- HVEM HJÆLPER JEG / MIG? ---

create or replace function public.my_helper_members()
returns table (member_id uuid, name text, initials text, team text, givet int)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.id, p.name, p.initials, p.team,
         coalesce((
           select sum(coalesce(tc.points_awarded, 0))::int
             from public.task_claims tc
            where tc.user_id = auth.uid()
              and tc.status = 'completed'
              and tc.credited_to = p.id
         ), 0)
    from public.helper_links hl
    join public.profiles p on p.id = hl.member_id
   where hl.helper_id = auth.uid()
   order by p.name;
$$;

comment on function public.my_helper_members() is
  'Hvem hjælperen hjælper, og hvor mange point hun har givet hver af dem.';

create or replace function public.my_helpers()
returns table (helper_id uuid, name text, initials text, point int)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select p.id, p.name, p.initials,
         coalesce((
           select sum(coalesce(tc.points_awarded, 0))::int
             from public.task_claims tc
            where tc.user_id = p.id
              and tc.status = 'completed'
              and tc.credited_to = auth.uid()
         ), 0)
    from public.helper_links hl
    join public.profiles p on p.id = hl.helper_id
   where hl.member_id = auth.uid()
   order by p.name;
$$;


revoke all on function public.admin_set_helper(uuid, uuid, boolean) from public, anon;
revoke all on function public.bidrag_point(uuid)      from public, anon;
revoke all on function public.er_hjaelper(uuid)       from public, anon;
revoke all on function public.my_helper_members()     from public, anon;
revoke all on function public.my_helpers()            from public, anon;
revoke all on function public.tc_check_credited_to()  from public, anon, authenticated;

grant execute on function public.admin_set_helper(uuid, uuid, boolean) to authenticated;
grant execute on function public.bidrag_point(uuid)  to authenticated;
grant execute on function public.er_hjaelper(uuid)   to authenticated;
grant execute on function public.my_helper_members() to authenticated;
grant execute on function public.my_helpers()        to authenticated;


-- ============================================================================
-- DET, APPEN SKAL KUNNE LÆSE
-- ============================================================================

-- ------------------------------------------------------- MEDLEMMETS TAL ---
--
-- Ét kald med hele billedet, så måleren i appen ikke skal regne noget ud
-- selv. Fem tal, fordi de fortæller fem forskellige ting:
--
--   egne           det jeg selv har lavet og beholdt        (også ranglisten)
--   fra_hjaelpere  det min far eller min kæreste har lavet for mig
--   bonus          det admin har lagt til i hånden
--   bidrag         summen — den, bidragsordningen gør op mod målet
--   givet          det JEG har lavet for andre (kun hjælpere har et tal her)

create or replace function public.my_bidrag()
returns table (
  bidrag        int,
  egne          int,
  fra_hjaelpere int,
  bonus         int,
  givet         int,
  er_hjaelper   boolean
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with uid as (select auth.uid() as id),
  mine as (
    select coalesce(sum(coalesce(tc.points_awarded, 0)), 0)::int as sum_pt
      from public.task_claims tc, uid
     where tc.status = 'completed'
       and tc.user_id = uid.id
       and coalesce(tc.credited_to, tc.user_id) = uid.id
  ),
  udefra as (
    select coalesce(sum(coalesce(tc.points_awarded, 0)), 0)::int as sum_pt
      from public.task_claims tc, uid
     where tc.status = 'completed'
       and tc.credited_to = uid.id
       and tc.user_id <> uid.id
  ),
  videre as (
    select coalesce(sum(coalesce(tc.points_awarded, 0)), 0)::int as sum_pt
      from public.task_claims tc, uid
     where tc.status = 'completed'
       and tc.user_id = uid.id
       and tc.credited_to is not null
       and tc.credited_to <> uid.id
  ),
  bon as (
    select coalesce(p.bonus_points, 0) as pt
      from public.profiles p, uid where p.id = uid.id
  )
  select greatest(0, mine.sum_pt + udefra.sum_pt + coalesce(bon.pt, 0)),
         mine.sum_pt,
         udefra.sum_pt,
         coalesce(bon.pt, 0),
         videre.sum_pt,
         public.er_hjaelper((select id from uid))
    from mine, udefra, videre left join bon on true;
$$;

comment on function public.my_bidrag() is
  'Medlemmets eget bidragsregnskab, delt op så appen kan skrive hvor pointene kommer fra.';


-- ------------------------------------------------- SKIFT MODTAGER BAGEFTER ---
--
-- Hjælperen vælger modtager, når hun melder sig til. Rammer hun det forkerte
-- barn, skal hun ikke skulle melde fra og til igen — så mister hun pladsen,
-- hvis en anden har taget den i mellemtiden.
--
-- Medlemmer har ingen UPDATE-ret på task_claims. Derfor går rettelsen gennem
-- den her funktion, og kun på ens egen tilmelding. Triggeren ovenfor tjekker
-- alligevel koblingen én gang mere; et sikkerhedsnet, der ikke koster noget.

create or replace function public.set_claim_credit(p_claim uuid, p_member uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_ejer uuid;
begin
  select user_id into v_ejer from public.task_claims where id = p_claim;

  if v_ejer is null then
    raise exception 'Tilmeldingen findes ikke';
  end if;

  if v_ejer <> auth.uid() then
    raise exception 'Man kan kun vælge modtager på sin egen tilmelding';
  end if;

  update public.task_claims
     set credited_to = case when p_member = v_ejer then null else p_member end
   where id = p_claim;
end;
$$;


-- --------------------------------------------------- ADMINS MEDLEMSLISTE ---
--
-- Listen får fire nye kolonner. Returtypen ændrer sig, og en funktion med
-- ændret returtype skal fjernes først — "create or replace" kan ikke.

drop function if exists public.admin_list_members();

create or replace function public.admin_list_members()
returns table (
  id                 uuid,
  name               text,
  initials           text,
  email              text,
  phone              text,
  team               text,
  role               text,
  points             int,
  tasks_done         int,
  approved           boolean,
  reviewed_at        timestamptz,
  admin_requested    boolean,
  admin_requested_at timestamptz,
  created_at         timestamptz,
  -- Nyt: bidragstallet, og hvem der hjælper hvem.
  bidrag             int,
  fra_hjaelpere      int,
  er_hjaelper        boolean,
  hjaelper_for       text,
  helper_request     text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan se medlemmernes kontaktoplysninger';
  end if;

  return query
    select p.id, p.name, p.initials, p.email, p.phone, p.team, p.role,
           p.points, p.tasks_done, p.approved, p.reviewed_at,
           p.admin_requested, p.admin_requested_at, p.created_at,
           public.bidrag_point(p.id),
           coalesce((
             select sum(coalesce(tc.points_awarded, 0))::int
               from public.task_claims tc
              where tc.status = 'completed'
                and tc.credited_to = p.id
                and tc.user_id <> p.id
           ), 0),
           exists (select 1 from public.helper_links h where h.helper_id = p.id),
           (select string_agg(m.name, ', ' order by m.name)
              from public.helper_links h
              join public.profiles m on m.id = h.member_id
             where h.helper_id = p.id),
           p.helper_request
    from public.profiles p
    order by p.points desc, p.name;
end;
$$;


revoke all on function public.my_bidrag()                    from public, anon;
revoke all on function public.set_claim_credit(uuid, uuid)    from public, anon;
revoke all on function public.admin_list_members()            from public, anon;

grant execute on function public.my_bidrag()                 to authenticated;
grant execute on function public.set_claim_credit(uuid, uuid) to authenticated;
grant execute on function public.admin_list_members()         to authenticated;
