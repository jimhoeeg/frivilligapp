-- ============================================================================
-- ÉN LISTE SKABELONER, SOM KLUBBEN EJER
--
-- Der var to slags, og kun den ene kunne klubben røre:
--
--   Appens forslag   40 stykker, hårdkodet i admin.jsx. Uændrede for evigt,
--                    eller rettere: indtil nogen retter i koden.
--   Klubbens egne    i databasen. Kunne oprettes og slettes.
--
-- Det var ikke to slags data. Det var ét datasæt, hvor halvdelen lå det
-- forkerte sted. En klub, der har brugt appen et halvt år, ved bedre end
-- koden, hvad der står i deres kioskvagt.
--
-- Nu ligger de 40 i databasen som almindelige rækker. Alt kan rettes,
-- omdøbes og slettes — og hentes tilbage igen med seed_task_templates(),
-- som kun lægger det ind, der mangler. Derfor kan den køres igen uden at
-- lave dubletter, og uden at skrive hen over noget, klubben selv har rettet.
--
-- Rækkerne herunder er IKKE skrevet af i hånden. De er lavet af et script,
-- der læser de samme lister, appen selv bruger — også ikonforslaget, så en
-- skabelon får præcis det ikon, den fik før.
-- ============================================================================


-- ------------------------------------------------------------ HVEM RETTEDE ---
--
-- Når en liste kan ændres af flere, er "hvem rettede den, og hvornår" det
-- første spørgsmål, der bliver stillet.

alter table public.task_templates
  add column if not exists updated_at timestamptz,
  add column if not exists updated_by uuid references public.profiles(id) on delete set null;

create or replace function public.tt_stamp()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end;
$$;

drop trigger if exists task_templates_stamp on public.task_templates;
create trigger task_templates_stamp
  before update on public.task_templates
  for each row execute function public.tt_stamp();


-- ------------------------------------------------------- APPENS FORSLAG ---
--
-- Funktionen bærer originalerne. Står de kun i en migration, kan de ikke
-- hentes frem igen den dag, nogen har slettet for meget — og så er en
-- "gendan"-knap et løfte, appen ikke kan holde.

create or replace function public.seed_task_templates()
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_antal int;
begin
  -- Ingen session betyder, at det er serveren selv (migrationen). Er der en
  -- session, skal den tilhøre en admin.
  if auth.uid() is not null
     and public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan hente appens forslag tilbage';
  end if;

  with nye as (
    insert into public.task_templates
      (category, title, points, difficulty, icon, description, spots_total, duration_type)
    select v.category, v.title, v.points, v.difficulty, v.icon, v.description, 2, 'single'
    from (values
    ('Kampafvikling & Sekretærbord', 'Dømme kampe som klubdommer (lokalrækker)', 15, 'Medium', 'whistle', 'Døm en kamp i lokalrækkerne som klubdommer.
Mød op 15 min. før kampstart.
Aflever kampskema til halsoveren efter kampen.'),
    ('Kampafvikling & Sekretærbord', 'Sekretærbordet – elektronisk holdkort/point', 10, 'Let', 'scorecard', 'Sid ved sekretærbordet og før elektronisk holdkort.
Vær på plads senest 20 min. før kampstart.
Kontakt kampansvarlig ved tvivl.'),
    ('Kampafvikling & Sekretærbord', 'Halspeaker til divisions-/hjemmekamp', 10, 'Let', 'speaker', 'Vær halspeaker ved hjemmekampe.
Annoncér hold, spillerskift og resultater.
Brug klubbens speaker-udstyr.'),
    ('Kampafvikling & Sekretærbord', 'Linjedommer til stor kamp', 10, 'Let', 'whistle', 'Vær linjedommer ved en større kamp.
Mød op 30 min. før kampstart til briefing.
Følg dommernes anvisninger under kampen.'),
    ('Kampafvikling & Sekretærbord', 'Opsætning/nedtagning af bane og net', 5, 'Let', 'net', 'Opsæt eller tag baner og net ned ved kampdag.
Tjek at net er i korrekt højde.
Læg alt udstyr tilbage på rette plads.'),
    ('Kampafvikling & Sekretærbord', 'Kampansvarlig/Halsover', 15, 'Medium', 'key', 'Mød op som den første og lås hallen op.
Sørg for at alt er klar til kampen.
Luk hallen og aflevér nøgler til rette vedkommende.'),
    ('Hygge og Socialt', 'Formand for festudvalget (Sæson)', 75, 'Hård', 'committee', 'Vær formand for festudvalget hele sæsonen.
Planlæg og koordinér alle sociale arrangementer.
Rapportér til bestyrelsen.'),
    ('Hygge og Socialt', 'Udvalgsmedlem i festudvalget (Sæson)', 40, 'Medium', 'committee', 'Deltag aktivt i festudvalgets arbejde hele sæsonen.
Hjælp med planlægning og praktisk afholdelse af arrangementer.'),
    ('Hygge og Socialt', 'Klargøring og madlavning til fællesspisning', 15, 'Let', 'food', 'Hjælp med at klargøre og lave mad til fællesspisning.
Mød op 1 time før arrangementet starter.
Ryd op bagefter.'),
    ('Hygge og Socialt', 'Kioskvagt til alm. hjemmekamp (ca. 2-3 timer)', 10, 'Let', 'kiosk', 'Bemand kiosken under en hjemmekamp.
Sørg for at varer er fyldt op.
Aflever kassen til kassereren efter kampen.'),
    ('Hygge og Socialt', 'Bage kage / lave madpakker til et hold', 5, 'Let', 'cake', 'Bag kage eller lav madpakker til et hold.
Aftaler omfang med holdleder.'),
    ('Hygge og Socialt', 'Oprydning/Rengøring efter klubfest', 15, 'Let', 'clean', 'Hjælp med oprydning og rengøring efter klubfest eller arrangement.
Bliv til alt er ryddet op og hallen er klar til næste brug.'),
    ('Hygge og Socialt', 'Indkøber til kiosken (Sæson)', 50, 'Medium', 'kiosk', 'Stå for indkøb til klubkiosken hele sæsonen.
Hold styr på lagerstatus og bestil varer.
Sørg for at priser er opdaterede.'),
    ('Holdleder & Transport', 'Fast holdleder for et ungdoms- eller seniorhold (Sæson)', 75, 'Hård', 'car', 'Vær fast holdleder for et hold hele sæsonen.
Kommunikér med forældre, spillere og trænere.
Sørg for tilmelding, kørsel og praktiske forhold.'),
    ('Holdleder & Transport', 'Kørsel til udekamp inkl. heppekor', 15, 'Let', 'car', 'Kør spillere til udekamp og hep holdet under kampen.
Aftaler mødested og tidspunkt med holdleder.
Sørg for at alle kommer sikkert hjem.'),
    ('Holdleder & Transport', 'Kørsel til udekamp – kun aflevering/afhentning', 5, 'Let', 'car', 'Kør spillere til eller fra udekamp.
Aftaler tidspunkt og sted med holdleder.'),
    ('Holdleder & Transport', 'Fast vaskemaskine – holdets trøjer hele sæsonen', 50, 'Medium', 'laundry', 'Vask holdets spillertøj efter samtlige kampe og stævner hele sæsonen.
Aftaler afhentning og aflevering med holdleder.'),
    ('Holdleder & Transport', 'Vask af spillertøj efter én kamp/stævne', 5, 'Let', 'laundry', 'Vask holdets spillertøj efter én kamp eller et stævne.
Aftaler afhentning og aflevering med holdleder.'),
    ('Stævneplanlægning og Afholdelse', 'Stævneleder/Hovedansvarlig for klubbens eget stævne', 75, 'Hård', 'trophy', 'Vær overordnet ansvarlig for afviklingen af et klubstævne.
Koordinér alle frivillige og leverandører.
Sørg for at stævneprogrammet følges.'),
    ('Stævneplanlægning og Afholdelse', 'Medlem af stævneudvalg (planlægning)', 40, 'Medium', 'committee', 'Deltag i planlægningen af klubbens stævne.
Mød til udvalgets møder og tag ansvar for aftalte opgaver.'),
    ('Stævneplanlægning og Afholdelse', 'Natvagt/Halsover ved overnatningsstævne', 30, 'Medium', 'tent', 'Vær halsover om natten ved overnatningsstævne (ca. kl. 23–07).
Sørg for ro og tryghed for de deltagende unge.'),
    ('Stævneplanlægning og Afholdelse', 'Stævnesekretariatet – registrér resultater (halvdags)', 20, 'Let', 'scorecard', 'Sid i stævnesekretariatet og registrér resultater og tider.
Styr kampuret og koordinér med dommerne.'),
    ('Stævneplanlægning og Afholdelse', 'Kioskvagt ved stort weekendstævne (vagt á 3 timer)', 15, 'Let', 'kiosk', 'Bemand kiosken i 3 timer under weekendstævnet.
Sørg for at varer er fyldt op løbende.'),
    ('Stævneplanlægning og Afholdelse', 'Opsætning fredag aften inden stævne / Hovedrengøring søndag', 15, 'Let', 'net', 'Hjælp med at sætte hallen op fredag aften eller stå for hovedrengøring søndag.
Følg stævnelederens anvisninger.'),
    ('Kommunikation & PR', 'Webmaster / Hovedansvarlig for SoMe (Sæson)', 75, 'Hård', 'megaphone', 'Vær ansvarlig for klubbens hjemmeside og sociale medier hele sæsonen.
Post regelmæssige opdateringer og resultater.
Koordinér indhold med bestyrelsen.'),
    ('Kommunikation & PR', 'Sponsorudvalg (Sæson – indhente sponsorer)', 75, 'Hård', 'committee', 'Vær en del af sponsorudvalget og indhent sponsorer til klubben hele sæsonen.
Kontakt lokale virksomheder og lav sponsoraftaler.'),
    ('Kommunikation & PR', 'Fotograf til kampdag/stævne inkl. redigering og deling', 15, 'Let', 'camera', 'Tag billeder ved en kampdag eller stævne.
Redigér udvalgte billeder og del med klubben.
Brug klubbens fotokanaler til deling.'),
    ('Kommunikation & PR', 'Skrive kampreferater / artikler til hjemmeside/Facebook', 10, 'Let', 'web', 'Skriv et kort kampreferat eller en artikel til hjemmeside eller Facebook.
Aflever tekst til SoMe-ansvarlig senest dagen efter kampen.'),
    ('Kommunikation & PR', 'Lave grafisk materiale (plakater, opslag, stævneprogram)', 10, 'Let', 'gear', 'Lav grafisk materiale til klubbens aktiviteter.
Brug klubbens farver og logo.
Aflever filer til SoMe-ansvarlig i aftalt format.'),
    ('Kommunikation & PR', 'Dele flyers / hænge plakater op i lokalområdet', 5, 'Let', 'flyer', 'Del flyers eller hæng plakater op i lokalområdet.
Få materiale udleveret af SoMe-ansvarlig.
Indmeld hvilke steder du har besøgt.'),
    ('Faciliteter & Materialer', 'Materialeansvarlig (Sæson)', 75, 'Hård', 'gear', 'Hold overblik over bolde, tøj, net og øvrigt udstyr hele sæsonen.
Registrér slitage og bestil nyt ved behov.
Rapportér til bestyrelsen.'),
    ('Faciliteter & Materialer', 'Klargøring af beachvolleyball-baner (arbejdsdag)', 20, 'Medium', 'net', 'Hjælp med at klargøre beachvolleyball-banerne til sæsonen.
Mød op til den aftalte arbejdsdag.
Medtag egnet fodtøj og arbejdstøj.'),
    ('Faciliteter & Materialer', 'Vedligehold af beach-baner (luge ukrudt, rive baner)', 10, 'Let', 'net', 'Vedligehold beachbanerne ved at luge ukrudt og rive sand.
Ca. 2 timers arbejde pr. gang.'),
    ('Faciliteter & Materialer', 'Hovedoprydning og organisering af boldrum', 15, 'Let', 'gear', 'Ryd op og organiser klubbens boldrum.
Sørg for at alt udstyr er på rette plads og mærket.'),
    ('Faciliteter & Materialer', 'Småreparationer (sy net, fikse boldvogne, pumpe bolde)', 10, 'Let', 'tools', 'Foretag småreparationer på klubbens udstyr.
Sy net, reparer boldvogne eller pump bolde.
Rapportér større skader til materialeansvarlig.'),
    ('Klubadministration', 'Bestyrelsesmedlem (Formand, Kasserer m.fl.)', 100, 'Hård', 'board', 'Sidder i klubbens bestyrelse hele sæsonen.
Deltager i bestyrelsesmøder og varetager bestyrelsespost.
Rapporterer til generalforsamlingen.'),
    ('Klubadministration', 'Revisor / Økonomisk hjælp (Sæson)', 40, 'Medium', 'money', 'Hjælp med revision eller økonomi hele sæsonen.
Gennemgå regnskab og bilag.
Rapportér til kassereren.'),
    ('Klubadministration', 'Børneattest-ansvarlig (Sæson)', 40, 'Medium', 'board', 'Indhent og tjek børneattester for alle relevante frivillige.
Hold register opdateret hele sæsonen.
Rapportér mangler til formanden.'),
    ('Klubadministration', 'Hjælp til medlemsregistrering og kontingentkørsel', 25, 'Let', 'car', 'Hjælp med at registrere nye medlemmer og køre kontingentopkrævning.
Aftaler opgaveomfang med kassereren.'),
    ('Klubadministration', 'Fonds-ansøger (skrive og sende fondansøgninger)', 25, 'Medium', 'board', 'Skriv og send ansøgninger til fonde og puljer på vegne af klubben.
Koordinér med bestyrelsen om behovsområder.
Rapportér svar og tildelinger.')
    ) as v(category, title, points, difficulty, icon, description)
    -- Rører ikke det, klubben selv har rettet eller oprettet.
    on conflict (category, title) do nothing
    returning 1
  )
  select count(*) into v_antal from nye;

  return v_antal;
end;
$$;

comment on function public.seed_task_templates() is
  'Lægger appens 40 oprindelige skabeloner ind. Kun dem der mangler — kan køres igen uden at lave dubletter eller overskrive klubbens rettelser.';

revoke all on function public.seed_task_templates() from public, anon;
grant execute on function public.seed_task_templates() to authenticated;
revoke all on function public.tt_stamp() from public, anon, authenticated;

-- Politikken kræver allerede en session, så anonyme får ingen rækker. Men
-- rettigheden på tabellen lå der stadig, og resten af appen har vænnet sig
-- til at trække den slags tilbage eksplicit: to spærrer, ikke én.
revoke all on public.task_templates from anon;


-- ------------------------------------------------------------ KØR DEN NU ---

do $$
declare v int;
begin
  select public.seed_task_templates() into v;
  raise notice 'skabeloner lagt ind: %', v;
end $$;
