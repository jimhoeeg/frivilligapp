-- ============================================================================
-- DOBBELTE POINT
--
-- Bestyrelsen vil gøre det mere attraktivt at være frivillig, og fordobler
-- derfor pointtallet på alt. En kioskvagt går fra 10 til 20, en
-- bestyrelsespost fra 75 til 150.
--
-- ---------------------------------------------------------------------------
-- HVAD DER SKER MED DEM, DER ALLEREDE HAR GJORT ARBEJDET
--
-- Triggeren task_points_changed() sørger for resten af sig selv: den
-- opdaterer points_awarded på alle tilmeldinger, justerer summen for dem,
-- hvis tjans allerede er gjort op, og giver dem besked. Det er med vilje —
-- den, der tog kioskvagten i september, skal ikke stå tilbage med det halve
-- af den, der tager den i oktober.
--
-- Derfor ét enkelt update. Ikke fordi det er smart, men fordi regnskabet
-- allerede ved, hvad det skal gøre, når en opgave skifter værdi.
--
-- ---------------------------------------------------------------------------
-- MÅLET ER IKKE ÆNDRET HER
--
-- point_goal står stadig på 200. Når alle tal fordobles og målet bliver
-- stående, er barren i praksis halveret: der skal fremover det halve
-- arbejde til for at slippe for frivilligbidraget. Det kan udmærket være
-- meningen — men det er en beslutning om penge, ikke om point, og den
-- træffes under Admin → Indstillinger, ikke her.
-- ============================================================================


-- ------------------------------------------------------------- OPGAVERNE ---

update public.tasks set points = points * 2;


-- ----------------------------------------------------------- SKABELONERNE ---
--
-- Ellers ville den næste kioskvagt, nogen opretter fra skabelonen, være
-- halvt så meget værd som den, der allerede står i listen.

update public.task_templates set points = points * 2;


-- ------------------------------------------------- OG APPENS EGNE FORSLAG ---
--
-- seed_task_templates() bærer originalerne, og "Gendan appens forslag"
-- henter dem derfra. Blev de stående på de gamle tal, ville en slettet og
-- gendannet skabelon stille og roligt være det halve værd — og ingen ville
-- opdage det før næste sæson. Funktionen skrives om med de nye tal.
--
-- Rækkerne er igen ikke skrevet af i hånden: de er de samme som i
-- 20260929090000_skabeloner.sql, med pointtallet ganget med to af et script.

create or replace function public.seed_task_templates()
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_antal int;
begin
  if auth.uid() is not null
     and public.get_my_role() not in ('admin', 'super_admin') then
    raise exception 'Kun administratorer kan hente appens forslag tilbage';
  end if;

  with nye as (
    insert into public.task_templates
      (category, title, points, difficulty, icon, description, spots_total, duration_type)
    select v.category, v.title, v.points, v.difficulty, v.icon, v.description, 2, 'single'
    from (values
    ('Kampafvikling & Sekretærbord', 'Dømme kampe som klubdommer (lokalrækker)', 30, 'Medium', 'whistle', 'Døm en kamp i lokalrækkerne som klubdommer.
Mød op 15 min. før kampstart.
Aflever kampskema til halsoveren efter kampen.'),
    ('Kampafvikling & Sekretærbord', 'Sekretærbordet – elektronisk holdkort/point', 20, 'Let', 'scorecard', 'Sid ved sekretærbordet og før elektronisk holdkort.
Vær på plads senest 20 min. før kampstart.
Kontakt kampansvarlig ved tvivl.'),
    ('Kampafvikling & Sekretærbord', 'Halspeaker til divisions-/hjemmekamp', 20, 'Let', 'speaker', 'Vær halspeaker ved hjemmekampe.
Annoncér hold, spillerskift og resultater.
Brug klubbens speaker-udstyr.'),
    ('Kampafvikling & Sekretærbord', 'Linjedommer til stor kamp', 20, 'Let', 'whistle', 'Vær linjedommer ved en større kamp.
Mød op 30 min. før kampstart til briefing.
Følg dommernes anvisninger under kampen.'),
    ('Kampafvikling & Sekretærbord', 'Opsætning/nedtagning af bane og net', 10, 'Let', 'net', 'Opsæt eller tag baner og net ned ved kampdag.
Tjek at net er i korrekt højde.
Læg alt udstyr tilbage på rette plads.'),
    ('Kampafvikling & Sekretærbord', 'Kampansvarlig/Halsover', 30, 'Medium', 'key', 'Mød op som den første og lås hallen op.
Sørg for at alt er klar til kampen.
Luk hallen og aflevér nøgler til rette vedkommende.'),
    ('Hygge og Socialt', 'Formand for festudvalget (Sæson)', 150, 'Hård', 'committee', 'Vær formand for festudvalget hele sæsonen.
Planlæg og koordinér alle sociale arrangementer.
Rapportér til bestyrelsen.'),
    ('Hygge og Socialt', 'Udvalgsmedlem i festudvalget (Sæson)', 80, 'Medium', 'committee', 'Deltag aktivt i festudvalgets arbejde hele sæsonen.
Hjælp med planlægning og praktisk afholdelse af arrangementer.'),
    ('Hygge og Socialt', 'Klargøring og madlavning til fællesspisning', 30, 'Let', 'food', 'Hjælp med at klargøre og lave mad til fællesspisning.
Mød op 1 time før arrangementet starter.
Ryd op bagefter.'),
    ('Hygge og Socialt', 'Kioskvagt til alm. hjemmekamp (ca. 2-3 timer)', 20, 'Let', 'kiosk', 'Bemand kiosken under en hjemmekamp.
Sørg for at varer er fyldt op.
Aflever kassen til kassereren efter kampen.'),
    ('Hygge og Socialt', 'Bage kage / lave madpakker til et hold', 10, 'Let', 'cake', 'Bag kage eller lav madpakker til et hold.
Aftaler omfang med holdleder.'),
    ('Hygge og Socialt', 'Oprydning/Rengøring efter klubfest', 30, 'Let', 'clean', 'Hjælp med oprydning og rengøring efter klubfest eller arrangement.
Bliv til alt er ryddet op og hallen er klar til næste brug.'),
    ('Hygge og Socialt', 'Indkøber til kiosken (Sæson)', 100, 'Medium', 'kiosk', 'Stå for indkøb til klubkiosken hele sæsonen.
Hold styr på lagerstatus og bestil varer.
Sørg for at priser er opdaterede.'),
    ('Holdleder & Transport', 'Fast holdleder for et ungdoms- eller seniorhold (Sæson)', 150, 'Hård', 'car', 'Vær fast holdleder for et hold hele sæsonen.
Kommunikér med forældre, spillere og trænere.
Sørg for tilmelding, kørsel og praktiske forhold.'),
    ('Holdleder & Transport', 'Kørsel til udekamp inkl. heppekor', 30, 'Let', 'car', 'Kør spillere til udekamp og hep holdet under kampen.
Aftaler mødested og tidspunkt med holdleder.
Sørg for at alle kommer sikkert hjem.'),
    ('Holdleder & Transport', 'Kørsel til udekamp – kun aflevering/afhentning', 10, 'Let', 'car', 'Kør spillere til eller fra udekamp.
Aftaler tidspunkt og sted med holdleder.'),
    ('Holdleder & Transport', 'Fast vaskemaskine – holdets trøjer hele sæsonen', 100, 'Medium', 'laundry', 'Vask holdets spillertøj efter samtlige kampe og stævner hele sæsonen.
Aftaler afhentning og aflevering med holdleder.'),
    ('Holdleder & Transport', 'Vask af spillertøj efter én kamp/stævne', 10, 'Let', 'laundry', 'Vask holdets spillertøj efter én kamp eller et stævne.
Aftaler afhentning og aflevering med holdleder.'),
    ('Stævneplanlægning og Afholdelse', 'Stævneleder/Hovedansvarlig for klubbens eget stævne', 150, 'Hård', 'trophy', 'Vær overordnet ansvarlig for afviklingen af et klubstævne.
Koordinér alle frivillige og leverandører.
Sørg for at stævneprogrammet følges.'),
    ('Stævneplanlægning og Afholdelse', 'Medlem af stævneudvalg (planlægning)', 80, 'Medium', 'committee', 'Deltag i planlægningen af klubbens stævne.
Mød til udvalgets møder og tag ansvar for aftalte opgaver.'),
    ('Stævneplanlægning og Afholdelse', 'Natvagt/Halsover ved overnatningsstævne', 60, 'Medium', 'tent', 'Vær halsover om natten ved overnatningsstævne (ca. kl. 23–07).
Sørg for ro og tryghed for de deltagende unge.'),
    ('Stævneplanlægning og Afholdelse', 'Stævnesekretariatet – registrér resultater (halvdags)', 40, 'Let', 'scorecard', 'Sid i stævnesekretariatet og registrér resultater og tider.
Styr kampuret og koordinér med dommerne.'),
    ('Stævneplanlægning og Afholdelse', 'Kioskvagt ved stort weekendstævne (vagt á 3 timer)', 30, 'Let', 'kiosk', 'Bemand kiosken i 3 timer under weekendstævnet.
Sørg for at varer er fyldt op løbende.'),
    ('Stævneplanlægning og Afholdelse', 'Opsætning fredag aften inden stævne / Hovedrengøring søndag', 30, 'Let', 'net', 'Hjælp med at sætte hallen op fredag aften eller stå for hovedrengøring søndag.
Følg stævnelederens anvisninger.'),
    ('Kommunikation & PR', 'Webmaster / Hovedansvarlig for SoMe (Sæson)', 150, 'Hård', 'megaphone', 'Vær ansvarlig for klubbens hjemmeside og sociale medier hele sæsonen.
Post regelmæssige opdateringer og resultater.
Koordinér indhold med bestyrelsen.'),
    ('Kommunikation & PR', 'Sponsorudvalg (Sæson – indhente sponsorer)', 150, 'Hård', 'committee', 'Vær en del af sponsorudvalget og indhent sponsorer til klubben hele sæsonen.
Kontakt lokale virksomheder og lav sponsoraftaler.'),
    ('Kommunikation & PR', 'Fotograf til kampdag/stævne inkl. redigering og deling', 30, 'Let', 'camera', 'Tag billeder ved en kampdag eller stævne.
Redigér udvalgte billeder og del med klubben.
Brug klubbens fotokanaler til deling.'),
    ('Kommunikation & PR', 'Skrive kampreferater / artikler til hjemmeside/Facebook', 20, 'Let', 'web', 'Skriv et kort kampreferat eller en artikel til hjemmeside eller Facebook.
Aflever tekst til SoMe-ansvarlig senest dagen efter kampen.'),
    ('Kommunikation & PR', 'Lave grafisk materiale (plakater, opslag, stævneprogram)', 20, 'Let', 'gear', 'Lav grafisk materiale til klubbens aktiviteter.
Brug klubbens farver og logo.
Aflever filer til SoMe-ansvarlig i aftalt format.'),
    ('Kommunikation & PR', 'Dele flyers / hænge plakater op i lokalområdet', 10, 'Let', 'flyer', 'Del flyers eller hæng plakater op i lokalområdet.
Få materiale udleveret af SoMe-ansvarlig.
Indmeld hvilke steder du har besøgt.'),
    ('Faciliteter & Materialer', 'Materialeansvarlig (Sæson)', 150, 'Hård', 'gear', 'Hold overblik over bolde, tøj, net og øvrigt udstyr hele sæsonen.
Registrér slitage og bestil nyt ved behov.
Rapportér til bestyrelsen.'),
    ('Faciliteter & Materialer', 'Klargøring af beachvolleyball-baner (arbejdsdag)', 40, 'Medium', 'net', 'Hjælp med at klargøre beachvolleyball-banerne til sæsonen.
Mød op til den aftalte arbejdsdag.
Medtag egnet fodtøj og arbejdstøj.'),
    ('Faciliteter & Materialer', 'Vedligehold af beach-baner (luge ukrudt, rive baner)', 20, 'Let', 'net', 'Vedligehold beachbanerne ved at luge ukrudt og rive sand.
Ca. 2 timers arbejde pr. gang.'),
    ('Faciliteter & Materialer', 'Hovedoprydning og organisering af boldrum', 30, 'Let', 'gear', 'Ryd op og organiser klubbens boldrum.
Sørg for at alt udstyr er på rette plads og mærket.'),
    ('Faciliteter & Materialer', 'Småreparationer (sy net, fikse boldvogne, pumpe bolde)', 20, 'Let', 'tools', 'Foretag småreparationer på klubbens udstyr.
Sy net, reparer boldvogne eller pump bolde.
Rapportér større skader til materialeansvarlig.'),
    ('Klubadministration', 'Bestyrelsesmedlem (Formand, Kasserer m.fl.)', 200, 'Hård', 'board', 'Sidder i klubbens bestyrelse hele sæsonen.
Deltager i bestyrelsesmøder og varetager bestyrelsespost.
Rapporterer til generalforsamlingen.'),
    ('Klubadministration', 'Revisor / Økonomisk hjælp (Sæson)', 80, 'Medium', 'money', 'Hjælp med revision eller økonomi hele sæsonen.
Gennemgå regnskab og bilag.
Rapportér til kassereren.'),
    ('Klubadministration', 'Børneattest-ansvarlig (Sæson)', 80, 'Medium', 'board', 'Indhent og tjek børneattester for alle relevante frivillige.
Hold register opdateret hele sæsonen.
Rapportér mangler til formanden.'),
    ('Klubadministration', 'Hjælp til medlemsregistrering og kontingentkørsel', 50, 'Let', 'car', 'Hjælp med at registrere nye medlemmer og køre kontingentopkrævning.
Aftaler opgaveomfang med kassereren.'),
    ('Klubadministration', 'Fonds-ansøger (skrive og sende fondansøgninger)', 50, 'Medium', 'board', 'Skriv og send ansøgninger til fonde og puljer på vegne af klubben.
Koordinér med bestyrelsen om behovsområder.
Rapportér svar og tildelinger.')    ) as v(category, title, points, difficulty, icon, description)
    on conflict (category, title) do nothing
    returning 1
  )
  select count(*) into v_antal from nye;

  return v_antal;
end;
$$;

comment on function public.seed_task_templates() is
  'Lægger appens 40 oprindelige skabeloner ind, med de dobbelte point fra 29. september 2026. Kun dem der mangler.';
