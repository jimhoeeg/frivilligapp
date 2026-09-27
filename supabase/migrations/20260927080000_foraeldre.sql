-- ============================================================================
-- FORÆLDRE: ET MEDLEM, DER OGSÅ GIVER POINT VIDERE
--
-- Hjælperne var det lette tilfælde: en far, der ikke selv spiller, og som
-- derfor ikke har noget mål at nå. Nu skal en forælder, der SELV er medlem,
-- kunne give point videre til sine børn.
--
-- ---------------------------------------------------------------------------
-- HVORFOR DET NU ER FORSVARLIGT — OG HVORFOR DET ALTID VAR DEN SAMME REGEL
--
-- Reglen "en konto med point kan ikke blive hjælper" lukkede døren mellem to
-- medlemmer. Den var grov. Det, der i virkeligheden beskytter ordningen, er
-- regnestykket:
--
--   EN TJANS TÆLLER FOR ÉN PERSON. ALDRIG TO.
--
-- Giver en forælder en tjans på 100 point videre til sit barn, falder
-- forælderens eget bidragstal med præcis 100. Intet bliver kopieret. Derfor
-- kan "deling" aldrig dække flere opgørelser, end der er lavet arbejde til:
-- 400 point dækker to mål på 200, fordi det ER 400 points arbejde.
--
-- Det, der ville være snyd — at forælderen beholder sine 400 OG barnet får
-- 200 — er umuligt, ikke forbudt. coalesce(credited_to, user_id) kan kun
-- pege på én person ad gangen.
--
-- ---------------------------------------------------------------------------
-- TO SLAGS KOBLING, FORDI DE BETYDER TO FORSKELLIGE TING
--
--   'helper'  spiller ikke selv. Har intet mål. Står IKKE på bidragslisten.
--   'parent'  er medlem med sit eget mål, og giver noget af det videre.
--
-- Forskellen kan ikke regnes ud af databasen — et barn er blot et andet
-- medlem. Det er et menneske, der ved, om kontoen også spiller selv, og
-- derfor er det admin, der siger det, når koblingen laves.
--
-- Den ENE ting, der stadig er spærret, er ringen: giver A videre til B, kan
-- B ikke give videre til A. To medlemmer, der sender point rundt i en rundkreds,
-- er ikke en familie — og selv om regnestykket holder, skal ordningen kunne
-- forklares på et bestyrelsesmøde.
-- ============================================================================


-- ------------------------------------------------------- SLAGS PÅ KOBLINGEN ---

alter table public.helper_links
  add column if not exists kind text not null default 'helper';

do $$
begin
  alter table public.helper_links
    add constraint helper_links_kind_check check (kind in ('helper', 'parent'));
exception when duplicate_object then null;
end $$;

comment on column public.helper_links.kind is
  '''helper'' = spiller ikke selv, har intet eget mål. ''parent'' = medlem med eget mål, der giver point videre.';


-- Har kontoen kun 'helper'-koblinger, har den intet eget mål og hører ikke på
-- bidragslisten. Har den bare én 'parent'-kobling, er den et medlem som alle
-- andre — der også giver noget videre.
create or replace function public.kun_hjaelper(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (select 1 from public.helper_links where helper_id = p_user)
     and not exists (select 1 from public.helper_links
                      where helper_id = p_user and kind = 'parent');
$$;

comment on function public.kun_hjaelper(uuid) is
  'Sandt for en ren hjælper: nogen der tager tjanser for andre og ikke selv har et mål at nå.';


-- ------------------------------------------------- ADMIN SÆTTER KOBLINGEN ---
--
-- Signaturen får et argument mere, og en funktion kan ikke skifte signatur.
-- Den gamle fjernes med vilje: stod den tilbage, kunne et kald med tre
-- argumenter gå forbi det nye og lave en kobling uden slags.

drop function if exists public.admin_set_helper(uuid, uuid, boolean);

create or replace function public.admin_set_helper(
  p_helper uuid,
  p_member uuid,
  p_on     boolean default true,
  p_kind   text    default 'helper'
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_helper record;
  v_member record;
  v_ord    text;
begin
  if public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan koble en hjælper til et medlem';
  end if;

  if p_kind not in ('helper', 'parent') then
    raise exception 'Koblingen skal være enten hjælper eller forælder';
  end if;

  select id, name, points into v_helper from public.profiles where id = p_helper;
  select id, name        into v_member from public.profiles where id = p_member;

  if v_helper.id is null then raise exception 'Hjælperen findes ikke'; end if;
  if v_member.id is null then raise exception 'Medlemmet findes ikke'; end if;

  v_ord := case when p_kind = 'parent' then 'forælder' else 'hjælper' end;

  if not p_on then
    delete from public.helper_links where helper_id = p_helper and member_id = p_member;
    insert into public.audit_log (type, action, actor_name, actor_id)
    select 'member',
           format('Fjernede %s som %s for %s', v_helper.name, v_ord, v_member.name),
           coalesce(p.name, 'Ukendt'), p.id
      from public.profiles p where p.id = auth.uid();
    return;
  end if;

  if p_helper = p_member then
    raise exception 'Man kan ikke give point videre til sig selv';
  end if;

  -- Kun den RENE hjælper skal være uden point. En forælder ER et medlem og
  -- har naturligvis point — det er hele grunden til, at hun kan give nogle
  -- af dem videre.
  if p_kind = 'helper'
     and not public.er_hjaelper(p_helper)
     and coalesce(v_helper.points, 0) > 0 then
    raise exception 'Kontoen har allerede optjent point som medlem. Kobl den som forælder, hvis personen selv spiller';
  end if;

  -- Ingen ringe. Kæder er i orden — mormor kan give videre til sin søn, der
  -- giver videre til sit barn — for en tjans peger altid på ÉN person, og
  -- point hopper ikke videre af sig selv. Men en rundkreds skal ikke kunne
  -- opstå: den ser ud som to medlemmer, der deler.
  if exists (
    with recursive videre as (
      select hl.member_id as knude
        from public.helper_links hl
       where hl.helper_id = p_member
      union
      select hl.member_id
        from public.helper_links hl
        join videre v on hl.helper_id = v.knude
    )
    select 1 from videre where knude = p_helper
  ) then
    raise exception '% giver allerede point videre til % — den kobling ville lave en ring',
      v_member.name, v_helper.name;
  end if;

  insert into public.helper_links (helper_id, member_id, created_by, kind)
  values (p_helper, p_member, auth.uid(), p_kind)
  on conflict (helper_id, member_id) do update set kind = excluded.kind;

  update public.profiles set helper_request = null
   where id = p_helper and helper_request is not null;

  insert into public.audit_log (type, action, actor_name, actor_id)
  select 'member',
         format('Koblede %s som %s for %s', v_helper.name, v_ord, v_member.name),
         coalesce(p.name, 'Ukendt'), p.id
    from public.profiles p where p.id = auth.uid();
end;
$$;


-- ------------------------------------------- HVEM GIVER JEG VIDERE TIL? ---

drop function if exists public.my_helper_members();

create or replace function public.my_helper_members()
returns table (member_id uuid, name text, initials text, team text, givet int, kind text)
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
         ), 0),
         hl.kind
    from public.helper_links hl
    join public.profiles p on p.id = hl.member_id
   where hl.helper_id = auth.uid()
   order by p.name;
$$;

comment on function public.my_helper_members() is
  'Hvem man giver point videre til, hvor mange man har givet hver af dem, og om man selv er medlem (parent) eller kun hjælper.';


-- ------------------------------------------------------- MEDLEMMETS TAL ---
--
-- Ét nyt felt: kun_hjaelper. Uden det kan appen ikke se forskel på en far,
-- der ikke spiller, og en mor, der gør — og de skal have to forskellige
-- forsider, fordi den ene har et mål at nå og den anden ikke har.

drop function if exists public.my_bidrag();

create or replace function public.my_bidrag()
returns table (
  bidrag        int,
  egne          int,
  fra_hjaelpere int,
  bonus         int,
  givet         int,
  er_hjaelper   boolean,
  kun_hjaelper  boolean
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
         public.er_hjaelper((select id from uid)),
         public.kun_hjaelper((select id from uid))
    from mine, udefra, videre left join bon on true;
$$;

comment on function public.my_bidrag() is
  'Medlemmets eget bidragsregnskab, delt op så appen kan skrive hvor pointene kommer fra, og hvor de er gået hen.';


-- ------------------------------------------------- FLYT EN TJANS BAGEFTER ---
--
-- En forælder har som regel allerede taget tjanserne, når hun opdager, at
-- barnet mangler point. Derfor skal en BEKRÆFTET tjans også kunne flyttes.
-- Pointene bliver hos forælderen på ranglisten — det var hende, der mødte op
-- — men de tæller fra nu af hos barnet i bidragsordningen.
--
-- Flytter man en tjans, der allerede er gjort op, står det i audit-loggen.
-- Det er penge, der flytter sig, og det skal kunne læses et år efter.

create or replace function public.set_claim_credit(p_claim uuid, p_member uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_krav   record;
  v_navn   text;
  v_opgave text;
begin
  select tc.user_id, tc.status, tc.points_awarded, tc.credited_to, t.title
    into v_krav
    from public.task_claims tc
    join public.tasks t on t.id = tc.task_id
   where tc.id = p_claim;

  if v_krav.user_id is null then
    raise exception 'Tilmeldingen findes ikke';
  end if;

  if v_krav.user_id <> auth.uid() then
    raise exception 'Man kan kun vælge modtager på sin egen tilmelding';
  end if;

  update public.task_claims
     set credited_to = case when p_member = v_krav.user_id then null else p_member end
   where id = p_claim;

  if v_krav.status = 'completed'
     and coalesce(v_krav.credited_to, v_krav.user_id) is distinct from p_member then
    select name into v_navn from public.profiles where id = p_member;
    insert into public.audit_log (type, action, actor_name, actor_id)
    select 'member',
           format('Flyttede %s point fra "%s" til %s',
                  coalesce(v_krav.points_awarded, 0), v_krav.title,
                  coalesce(v_navn, 'sig selv')),
           coalesce(p.name, 'Ukendt'), p.id
      from public.profiles p where p.id = auth.uid();
  end if;
end;
$$;


-- --------------------------------------------------- ADMINS MEDLEMSLISTE ---

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
  bidrag             int,
  fra_hjaelpere      int,
  er_hjaelper        boolean,
  kun_hjaelper       boolean,
  givet_videre       int,
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
           public.er_hjaelper(p.id),
           public.kun_hjaelper(p.id),
           coalesce((
             select sum(coalesce(tc.points_awarded, 0))::int
               from public.task_claims tc
              where tc.status = 'completed'
                and tc.user_id = p.id
                and tc.credited_to is not null
                and tc.credited_to <> p.id
           ), 0),
           (select string_agg(m.name, ', ' order by m.name)
              from public.helper_links h
              join public.profiles m on m.id = h.member_id
             where h.helper_id = p.id),
           p.helper_request
    from public.profiles p
    order by p.points desc, p.name;
end;
$$;


revoke all on function public.kun_hjaelper(uuid)                            from public, anon;
revoke all on function public.admin_set_helper(uuid, uuid, boolean, text)   from public, anon;
revoke all on function public.my_helper_members()                           from public, anon;
revoke all on function public.my_bidrag()                                   from public, anon;
revoke all on function public.set_claim_credit(uuid, uuid)                  from public, anon;
revoke all on function public.admin_list_members()                          from public, anon;

grant execute on function public.kun_hjaelper(uuid)                          to authenticated;
grant execute on function public.admin_set_helper(uuid, uuid, boolean, text) to authenticated;
grant execute on function public.my_helper_members()                         to authenticated;
grant execute on function public.my_bidrag()                                 to authenticated;
grant execute on function public.set_claim_credit(uuid, uuid)                to authenticated;
grant execute on function public.admin_list_members()                        to authenticated;
