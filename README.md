# RVK Frivillig - Task Coordinator App

Volunteer task coordination web app for Randers Volleyballklub (RVK).

## Features

- 🔐 **Login og oprettelse** — med holdvalg og admin-godkendelse af nye medlemmer
- 📋 **Opgaver** — søg, filtrér og tag tjanser
- ✅ **Bekræftelse** — point gives først når tjansen er godkendt som gennemført, manuelt eller automatisk efter 7 dage
- 📊 **Point** — beregnes i databasen ud fra bekræftede tjanser plus admins bonuspoint
- 🏆 **Rangliste** — medlemmer og hold
- 🔄 **Byt tjanser** — tilmelding og point flytter samlet i én databasefunktion
- 🔔 **Notifikationer** — ved godkendelse, tildeling, bekræftelse, ændret eller aflyst opgave
- 🛡️ **Admin-panel** — opgaver, medlemmer, roller, godkendelser og audit-log
- 📱 **Mobile-first** — bygget til telefonen, kan lægges på hjemmeskærmen

## Tech Stack

- **React 19** — UI framework
- **Vite** — Build tool & dev server
- **Tailwind CSS v3** — Styling
- **Lucide React** — Icons
- **Supabase** — database, login og filer (Postgres med row level security)

## Getting Started

### Local Development

```bash
npm install
npm run dev
```

App runs on `http://localhost:5173/`

### Build for Production

```bash
npm run build
npm run preview
```

## Udrulning

> **Kør dette FØR appen sendes ud til medlemmerne.** Halvdelen af rettelserne
> ligger i databasen, ikke i appen. Uden trin 1 og 2 kalder appen funktioner,
> der ikke findes.

**1. Kør migrationerne**

Nemmest: Supabase Dashboard → SQL Editor → New query → indsæt hele
**`supabase/RUN_ALL.sql`** → Run. Det er de tolv migrationer sat efter
hinanden i rigtig rækkefølge, og Supabase kører hele bufferen i én
transaktion — enten lykkes det hele, eller også ruller det hele tilbage.

Vil du hellere læse dem enkeltvis, så kør filerne i `supabase/migrations/`
i navnerækkefølge. Resultatet er det samme. De kan alle køres flere gange
uden at gøre skade, og de er tilsammen nok — rør ikke noget i
`supabase/legacy/`.

> `RUN_ALL.sql` er genereret fra `supabase/migrations/`. Tilføjer du en
> migration, så kør `./supabase/build_run_all.sh` — ellers kommer filen
> bagud, uden at nogen opdager det.

| Fil | Hvad den gør |
|---|---|
| `20260101000000_baseline.sql` | Tabeller og indekser. Intet andet. |
| `20260910120000_launch_hardening.sql` | Adgang til medlemsdata, godkendelse, pointregnskab, bytte, beskeder. **Genberegner alle point fra bunden** — bonuspoint givet i hånden før nu går tabt. |
| `20260918100000_task_completion.sql` | Point først når en tjans er bekræftet. Nulstiller pointtallene: alt står som "afventer bekræftelse", til en admin gør det op. Vil I godkende hele historikken på én gang, står linjen i bunden af filen. |
| `20260918140000_auto_confirm.sql` | Automatisk bekræftelse efter 7 dage. Opretter et `pg_cron`-job hvis muligt; ellers klarer appen det selv. |
| `20260918160000_cleanup_orphans.sql` | Fjerner efterladte pointfunktioner fra en gren, der aldrig blev merget. |
| `20260919080000_policies_from_legacy.sql` | Adgangsregler, der før kun lå i de løse filer. |
| `20260919090000_points_follow_task.sql` | Point følger med, når en opgaves værdi ændres. |
| `20260919110000_client_errors.sql` | Fejl fra medlemmernes telefoner. |
| `20260919140000_lock_function_execute.sql` | Kun indloggede må kalde databasens funktioner, og kun dem appen bruger. |
| `20260919160000_season_reset.sql` | Nulstil sæsonen — med arkiv af stillingen og en lås, så det ikke sker ved et uheld. |
| `20260922180000_teams_readable_at_signup.sql` | Holdlisten skal kunne læses uden login — oprettelsesskærmen henter den, før der findes en session. |
| `20260925140000_task_templates.sql` | Klubbens egne skabeloner, og hvem der står på en opgave. |

**1b. Kontrollér bagefter med `supabase/VERIFY.sql`**

Samme sted: SQL Editor → New query → indsæt hele **`supabase/VERIFY.sql`** → Run.
Den læser kun og ændrer ingenting. Resultatet er 20 linjer, der hver siger
`OK`, `FEJL` eller `INFO`:

| Linje | Hvad den fanger |
|---|---|
| 1–3 | Tabeller, row level security, ingen tabel uden adgangsregler |
| 4–6 | De rigtige triggere — og at den gamle pointtrigger og den konkurrerende pointmotor er væk |
| 7 | At alle 19 funktioner, appen kalder, findes |
| 8–12 | GDPR-hullet lukket, e-mail og telefon skjult, og at ingen kan hæve sin egen rolle eller sine egne point |
| 13–16 | At pointsummer, tilstande, ledige pladser og indstillinger stemmer |
| 17–18 | At hold og mindst to super admins er oprettet (trin 3) |
| 18.5–18.6 | At ingen funktion står åben for anonyme, og at kun appens 24 egne er åbne for indloggede |
| 19–20 | INFO: hvor mange venter på godkendelse og bekræftelse |

**Alt skal stå `OK`, på nær `INFO`-linjerne.** Linje 17 og 18 står som `FEJL`,
indtil `seed.sql` er kørt — det er ventet. Står noget andet som `FEJL`, siger
`detalje`-kolonnen hvem eller hvad det drejer sig om.

Nederst kommer en NOTICE om `pg_cron`. Er den ikke slået til på projektet, er
det ikke en fejl — appen kalder selv opgørelsen, når nogen er logget ind.

> **Hold skal kunne læses uden login.** Oprettelsesskærmen henter holdlisten,
> før brugeren har en session, og feltet er påkrævet. Læsereglen på `teams` er
> derfor `using (true)` — holdnavne er ikke personoplysninger. Strammer man den
> til `auth.uid() is not null`, får nye medlemmer en tom liste og kan ikke
> oprette sig. Skrivning er stadig kun for super admins.

**2. Rul sletnings-funktionen ud**

```bash
supabase functions deploy delete-member
```

Uden den kan admins hverken slette eller afvise medlemmer — sletning kræver
service-nøglen, som aldrig må ligge i browseren.

**3. Kør `supabase/seed.sql` — ret filen først**

Hold og super admins. Holdlisten er standardnavne, ikke jeres, og medlemmer
vælger hold når de opretter sig; er tabellen tom, kan ingen oprette sig
ordentligt. Sørg for **mindst to** super admins.

**4. Sæt miljøvariabler i Vercel**

`VITE_SUPABASE_URL` og `VITE_SUPABASE_ANON_KEY` under Settings →
Environment Variables.

**5. Godkend teksterne**

Vilkår og privatlivspolitik i `src/App.jsx` (`LEGAL_DOCS`) er **et udkast**.
Bestyrelsen skal læse dem igennem, og `LEGAL_CONTACT` skal rettes til klubbens
rigtige adresse, før appen sendes ud.

**6. Prøvekør med 3–5 personer**

På deres egne telefoner: opret profil, godkend, tag en tjans, meld fra, byt,
bekræft som gennemført, slet en testbruger.

### Ældre SQL-filer

De oprindelige løsblade ligger i `supabase/legacy/` med en forklaring.
**Kør dem ikke.** `supabase_setup.sql` gendanner blandt andet politikken, der
gjorde hele medlemslisten læsbar uden login.

### Test af databasen

`supabase/tests/` kan køre migrationen igennem mod en lokal Postgres:

```bash
createdb rvk
psql -d rvk -f supabase/tests/00_supabase_stub.sql     # efterligner Supabase
for m in supabase/migrations/*.sql; do psql -d rvk -f "$m"; done
psql -d rvk -f supabase/tests/10_behaviour.sql          # 15 tjek
psql -d rvk -f supabase/tests/20_completion.sql         # 14 tjek af bekræftelser
psql -d rvk -f supabase/tests/30_auto_confirm.sql       # 11 tjek af automatikken
psql -d rvk -f supabase/tests/40_points_follow_task.sql # 9 tjek af pointændringer
psql -d rvk -f supabase/tests/50_season_reset.sql       # 14 tjek af sæsonnulstilling
```

### Efterladt SQL i den rigtige database

Grenen `claude/app-domain-usage-lsz87f` blev aldrig merget, men dens SQL blev
kørt på Supabase-projektet. Den lavede sin egen vej til at uddele point
(`claim_task`, `unclaim_task`, `handle_task_claim`). Appen kalder dem ikke
længere, men så længe de ligger i databasen, findes der to måder at ændre en
persons point på. `20260918160000_cleanup_orphans.sql` fjerner dem. Eftersynet
i bunden af den fil viser, om der er flere rester.

## Deployment

Kører på **Vercel** i projektet **`frivilligappen`**, som auto-deployer ved
push til `main`.

Live: `https://frivilligappen-jimhoeeg-5138s-projects.vercel.app`

> **Kun ét Vercel-projekt må være koblet til dette repo.** Der lå tidligere to
> (`frivilligapp` og `frivilligappen`), og de udløste hver deres build ved
> samme push. På Hobby-planen er der én byggeplads, så det ene build døde
> konsekvent med `BUILD_FAILED — "Resource provisioning failed"` efter et
> halvt sekund og uden logs. Opret ikke et projekt nummer to.

Inden linket sendes til medlemmerne bør der peges et rigtigt domæne på
projektet (fx `frivillig.randersvk.dk`) under Settings → Domains.

## Project Structure

```
src/App.jsx                    # hele appen
supabase/RUN_ALL.sql           # alle migrationer samlet – ét indsæt
supabase/build_run_all.sh      # genskaber RUN_ALL.sql fra migrations/
supabase/VERIFY.sql            # eftersyn efter migrationerne – læser kun
supabase/migrations/           # databaseændringer – kilden til RUN_ALL.sql
supabase/functions/            # serverfunktioner (sletning af medlemmer)
supabase/tests/                # kan køre migrationerne igennem lokalt
supabase/seed.sql              # hold og super admins – ret før brug
supabase/legacy/               # historik. Kør dem ikke.
public/icon.svg                # klubbens ikon – PNG'erne er genereret herfra
```

Ikonerne (`icon-192.png`, `icon-512.png`, `apple-touch-icon.png`) er
rasteriseret fra `public/icon.svg`. Ændrer du SVG'en, skal PNG'erne
genskabes — ellers viser telefonerne det gamle ikon.

## Vandrette lister

Syv steder i appen er en række bredere end skærmen — kategorifiltre, badges,
holdene på scoreboardet, admin-fanerne. Admin-fanerne er 1109px i et 390px
vindue, så to tredjedele er skjult.

Alle bruger `<ScrollRow>`, som holder sig ude af syne til den er nødvendig:

- Indholdet tones blødt ud i den kant, hvor der er mere. Det er en
  `mask-image` på indholdet, ikke en gradient ovenpå — derfor virker det lige
  godt på den grønne header og på hvid baggrund.
- Musehjulet ruller sidelæns, når markøren er over rækken. Uden det kan en
  computerbruger kun komme videre ved at holde Shift nede, og det ved de færreste.
- Pile vises kun på enheder med mus, og kun når der er noget at rulle til.
- Den aktive knap rulles selv ind i billedet, også når fanen skiftes fra koden.

Klassen `scrollbar-hide` stod i markup'en længe uden at være defineret nogen
steder — hverken Tailwind eller et plugin leverer den. Den er nu i
`src/index.css`.

## Indlæsningstid

Appen var nogle gange meget længe om at komme frem. Målt i produktion over et
døgn var databasen ikke skyld i det: `my_profile()` kører på **1,97 ms** i
snit i Postgres, opgavelisten på 4,6 ms. Tiden gik fire andre steder.

**Låsen, der holdt appen fast.** supabase-js kalder `onAuthStateChange`,
mens biblioteket selv holder en lås på sessionen — og ethvert kald indefra
skal bruge den samme lås. Lytteren stod med `await loadProfile(...)` og
ventede derfor på en lås, der ventede på den. Låsen bliver revet fri efter
fem sekunder ad gangen, og derefter startede hentningen forfra.

Målt på den samme testopsætning, med en session gemt i telefonen:

| | Før | Efter |
|---|---|---|
| Skærmen er klar | **31,6 sekunder** | **0,7 sekunder** |
| `my_profile`-kald | 4 | 1 |

Det stemmer med produktionsloggen: 80 af 173 app-åbninger sendte to eller
flere ens `my_profile`-kald inden for samme sekund, seksten sendte fire.
Lytteren venter ikke længere på noget — arbejdet lægges uden for låsen med
`setTimeout(..., 0)`. **Kald aldrig supabase med `await` inde i
`onAuthStateChange`.**

**Én hentning ad gangen.** Både `getSession` ved opstart og auth-lytteren
beder om profilen og opgavelisten ved en almindelig åbning (supabase-js
sender både `SIGNED_IN` og `INITIAL_SESSION` for den samme gemte session).
`loadProfile` og `loadTasks` deler nu ét svar, hvis der allerede er en
hentning undervejs, og lytteren springer `INITIAL_SESSION` og
`TOKEN_REFRESHED` over — en ny nøgle til den samme person er ikke en ny
profil.

**Ingen kald før sessionen er kendt.** Opgavelisten hentede før på egen hånd
ved mount, også når ingen var logget ind: 31 gange i døgnet svarede serveren
401 på `/tasks`, hvorefter appen fornyede nøglen (op til fem sekunder) og
prøvede igen. Nu venter begge hentninger på den ene `getSession()`, som selv
fornyer nøglen, hvis den er udløbet — og starter så **samtidig**.

**Skærmen er ikke hvid imens.** `index.html` har fået klubbens
indlæsningsskærm med samme farver og spinner som appens egen, så der ikke er
noget spring, når React tager over. Den toner først frem efter et kvart
sekund: går det hurtigt, ser man den aldrig. Samme fil har nu en `preconnect`
til Supabase, så forbindelsen til databasen åbnes, mens app-koden hentes —
200-500 ms på mobilnet.

Prøv efter: `node varm-check.js` og `node hurtig-check.js`.

**Tilbage at hente:** app-koden er 638 kB i én fil (166 kB pakket), og
medlemmerne downloader hele admin-panelet uden nogensinde at bruge det. Det
kræver, at `App.jsx` deles op i flere filer. Dertil kunne profilen huskes
lokalt og vises med det samme, mens den hentes forfra i baggrunden.

## Drift

### Fejl fra medlemmernes telefoner

Uventede fejl skrives til `client_errors` og kan ses under **Admin → Audit log
→ Fejl**. En fejlgrænse omkring appen sørger samtidig for, at et nedbrud under
rendering giver en forklaring i stedet for en hvid skærm.

Databasen sætter en grænse på 20 fejl pr. bruger i timen, og fejl ældre end
90 dage slettes automatisk (eller med `select public.prune_client_errors();`).

Det er ikke et rigtigt overvågningsværktøj — der er ingen alarmer. Ser I
samme fejl hos mange på én gang, er noget gået i stykker for alle.

### Tilbagemeldinger fra medlemmerne

**Profil → Noget der driller?** Medlemmet skriver kort, hvad der skete, og det
går samme vej som et nedbrud — `log_client_error` med `source = 'feedback'`.
Admins ser det under **Audit log → Fejl & beskeder**, hvor en besked skrevet
af et menneske vises anderledes end en stakspor, med hvem der skrev og hvornår.

Databasens grænse på 20 pr. bruger i timen gælder også her, og alt ældre end
90 dage slettes.

### Udløbet session

En telefon, der har ligget i lommen, vågner med et forældet token og sender
det af sted, før `supabase-js` når at forny det. Serveren svarer `401`. Det er
set i produktionen — tre gange den 23. september, fra en iPhone og en Android,
på `/rest/v1/tasks`.

Konsekvensen var forskellig og begge dele dårlige: profilen gav fuldskærmsfejl,
og opgavelisten gav **ingenting** — fejlen blev kastet væk, så medlemmet så en
tom skærm og troede, der ikke var nogen tjanser.

`medFornyetSession()` fornyer nu sessionen og prøver kaldet igen. Fornyelsen
har selv en grænse på 5 sekunder, så en halvdød forbindelse ikke kan låse
kaldet fast, og der prøves igen uanset om fornyelsen lykkedes — `supabase-js`
kan have fornyet i baggrunden imens. Er sessionen reelt død, ender man på
login-skærmen, hvilket er det rigtige svar.

Opgavelisten siger desuden fra i stedet for at vise en tom liste.

### Indlæsning af profilen

Tre ting styrer, hvad der sker mellem "logget ind" og "inde i appen". De har
alle tre været kilde til fejl, så de står her:

1. **`loadProfile` ejer indlæsningsskærmen alene.** `handleAuth` rørte den
   også, og det var en fælde: supabase-js kører auth-lytteren færdig, *før*
   `signInWithPassword` giver svar tilbage. På en langsom forbindelse nåede
   `loadProfile` derfor at blive færdig og slukke skærmen, hvorefter
   `handleAuth` tændte den igen — og så var der ingenting tilbage til at
   slukke den. Appen hang på "Indlæser..." for evigt.
2. **Profilen hentes én gang.** Både `handleAuth` og auth-lytteren kaldte
   `loadProfile`, og de to kald blev serialiseret. Det fordoblede ventetiden
   på en langsom forbindelse.
3. **Tidsgrænsen er 15 sekunder med ét ekstra forsøg.** Den var 8 sekunder
   uden forsøg, hvilket et medlem på mobilnet i en hal rammer uden at der er
   noget galt.

Sikkerhedsnettet, der forhindrer en evig indlæsningsskærm, fyrer ikke, mens
en hentning er undervejs — ellers river det skærmen væk midt i en langsom
indlæsning.

### Når profilen ikke kan hentes

Login kan lykkes i Supabase, uden at appen kan hente medlemsprofilen. Det sker
i tre tilfælde: profilen findes ikke, serveren svarer med en fejl, eller
kaldet nåede ikke igennem inden for 8 sekunder.

Før faldt alle tre igennem til login-skærmen. Set fra medlemmet: man skriver
sit kodeord, der sker ingenting, man skriver det igen. To konti i den rigtige
database stod præcis sådan.

Nu vises en skærm, der skelner:

En fejl i en **baggrundsopdatering** — når profilen hentes igen, mens appen
allerede er i gang — overtager aldrig skærmen. Medlemmet står måske midt i at
tage en tjans; så er en fuldskærmsfejl det forkerte svar. Der vises i stedet
en kort besked, og skærmen bliver stående.

- **Din profil mangler** — kontoen findes, men der er ingen medlemsprofil.
  Det kan medlemmet ikke rette selv, så skærmen henviser til `LEGAL_CONTACT`.
  Ingen "prøv igen"-knap; den ville ikke hjælpe.
- **Kunne ikke hente din profil** — serveren svarede ikke. Her er der en
  "prøv igen", som henter sessionen og forsøger på ny.

Begge skriver til `client_errors`, så det kan ses under **Admin → Audit log →
Fejl**. PostgREST svarer `PGRST116` på `.single()` ved nul rækker, og den kode
er det eneste, der skiller "ingen profil" fra "serverfejl".

### Backup

**Tjek hvilken Supabase-plan I er på.** På gratisplanen er der ingen
automatisk backup at rulle tilbage til, og projektet sættes på pause ved
inaktivitet. Med et rigtigt medlemsregister bør I enten opgradere eller lave
en fast eksport (Supabase Dashboard → Database → Backups).

### Tests

Databasen har en testsuite (se ovenfor) — den dækker pointregnskab,
adgangsregler, bekræftelser og automatik. **Appen har ingen automatiske
tests**; ændringer i `src/App.jsx` skal klikkes igennem i hånden. Det er et
bevidst valg: logikken der kan regne forkert ligger i databasen, og den er
dækket.

### Support

Medlemmerne henvises til `LEGAL_CONTACT` i `src/App.jsx` (nu
`kontakt@randersvk.dk` — ret den). Aftal hvem der læser den adresse, før
linket sendes ud.

## Pointmodel

En tilmelding har tre tilstande:

| Tilstand    | Betyder                                  | Point |
|-------------|------------------------------------------|-------|
| `signed_up` | Meldt til. Optager en plads.             | Nej   |
| `completed` | En admin har bekræftet den som gennemført | Ja   |
| `no_show`   | Registreret som ikke gennemført           | Nej   |

`profiles.points` = summen fra `completed`-tilmeldinger + `bonus_points`.
Tallet vedligeholdes af databasetriggere; appen skriver aldrig selv i det.
Medlemmet ser afventende point adskilt på sit dashboard.

Admins gør tjanser op under **Admin → Bekræft**, enten samlet pr. opgave eller
person for person. En bekræftelse kan altid fortrydes — pointene følger med
tilbage.

### Automatisk bekræftelse

Er der gået 7 dage efter opgavens sidste dag, og står tilmeldingen stadig som
`signed_up`, godkendes den af sig selv. Antal dage sættes under **Admin →
Indstillinger**; 0 slår det fra. Reglen er bevidst forsigtig:

- Kun `signed_up`. Har en admin markeret nogen som udeblevet, bliver det stående.
- Kun opgaver hvor slutdatoen kan læses entydigt (`date_full` eller `date_end`
  i ISO-format). Ældre opgaver med kun en dansk datotekst røres ikke, og
  admin-panelet siger det tydeligt.
- Medlemmet får en besked, der fortæller at godkendelsen skete automatisk.
- En automatisk godkendelse kan fortrydes som enhver anden.

Kør den manuelt: `select public.auto_confirm_due_claims(true);`
Se hvad der venter: `select * from public.auto_confirm_preview();`

### Appens pointforslag

Når en admin opretter en opgave, foreslår appen et antal point. Forslaget
ændrer sig, når sværhedsgraden eller varigheden ændres:

| Sværhed | Enkelt dag | En uge | En måned | Halv sæson | Helt år |
|---------|-----------|--------|----------|------------|---------|
| Let     | 10        | 15     | 20       | 30         | 40      |
| Medium  | 15        | 25     | 40       | 50         | 50      |
| Hård    | 25        | 40     | 60       | 75         | 75      |

Tallene er ikke fundet på: de er læst ud af klubbens egne 40 skabeloner
(`TASK_TEMPLATES`). Medianen der er 10 for Let, 15 for Medium og 75 for Hård,
og seks af syv sæsonroller står på præcis 75. Derfor en tabel frem for en
formel — en formel ville ramme ved siden af de tal, klubben faktisk bruger.

Varigheden vejer tungest. "Formand for festudvalget (Sæson)" og
"Materialeansvarlig (Sæson)" er begge Hård og begge 75, mens "Dømme kampe"
er Medium og 15.

Det er et **forslag**, ikke en regel. Skriver en admin selv et tal, rører
appen det aldrig igen — så står forslaget som en linje under feltet med en
**Brug**-knap, man kan trykke på eller lade være. Redigerer man en
eksisterende opgave, er feltet dens eget tal fra første sekund.

## Skabeloner

Appen har en fast liste af skabeloner i koden (`TASK_TEMPLATES`). Den kan
klubben ikke rette i, så admins kan nu gemme deres egne.

Under **Admin → Opgaver → Ny opgave** fylder man formularen ud og trykker
**Gem som skabelon i "<kategori>"**. Den gemmes i `task_templates` og dukker op
øverst i skabelonvælgeren under *Klubbens egne*, med appens forslag nedenunder.

En skabelon husker titel, kategori, point, sværhed, **pladser, tidsrum og
sted** — men bevidst **ikke datoen**. Den er ny hver gang, og det er netop det,
der gør en skabelon nyttig.

Samme titel i samme kategori overskriver den gamle (`unique (category, title)`),
så man kan rette en skabelon ved at gemme den igen. Slet med skraldespanden i
vælgeren. Alle indloggede kan læse skabelonerne; kun admins kan gemme og slette.

## Hvem står på en opgave

På opgavesiden, lige over **Tag tjansen**, står hvem der allerede har taget
den — navn, initialer og hold, med et flueben ved dem, hvis tjans er godkendt.
Ens eget navn er fremhævet.

Det er den hyppigste grund til at sige ja: man tager en vagt, fordi man kan se,
hvem man kommer til at stå der med.

Navnene hentes med `task_signups()`. Den giver **ikke** e-mail eller telefon —
at vide hvem man står på vagt med er ikke det samme som at få deres
kontaktoplysninger. Antal tagne pladser regnes ud fra listen, ikke fra
opgavens `spots_left`, som kan være forældet på en åben detaljeside.

## Opgavelisten i admin

**Admin → Opgaver** sorterer efter **dato for udførsel**, nærmeste først.
Det er den rækkefølge, man arbejder i: det, der skal ske på lørdag, ligger
øverst. Opgaver uden læsbar dato ligger nederst frem for at støje foroven.

Rækkefølgen kan skiftes med knapperne over listen:

| Sortering      | Bruges til                                                |
|----------------|-----------------------------------------------------------|
| Dato           | Standard. Nærmeste udførsel først.                         |
| Mangler folk   | Ubesatte pladser øverst — hvem skal der rykkes for?        |
| Point          | Højeste point først.                                       |
| Titel          | Alfabetisk, når man leder efter en bestemt opgave.         |
| Nyeste         | Sidst oprettet først.                                      |

## Kalenderen

Kalenderen viste kun tjanser i september. Den grupperede opgaverne efter
dag-i-måneden alene og så hverken på måned eller år, så den 15. marts landede
under den 15. september, og listevisningen sorterede efter det samme tal.

Nu læses hele datoen (`parseTaskDate`), og en dag får kun en prik, hvis
opgavens år **og** måned passer. Listen sorteres på den rigtige dato.

Opgaver, der strækker sig over flere måneder — en sæsonrolle, en måned i
kiosken — står under **Løber hele \<måned\>** i hver måned, de dækker, og
tælles ikke med to gange i den måned, de begynder.

## Eksport af klubdata

**Admin → Indstillinger → Klubdata → Eksportér klubdata.** Kun super admins.

Tre filer: medlemsliste, opgaveliste og tilmeldinger. Arkiverede sæsoner
hentes hver for sig med download-ikonet i *Tidligere sæsoner*.

**Bidragslisten** ligger et andet sted: **Admin → Oversigt → Eksportér
bidragsliste**. Den viser hvert medlems point mod målet og hvem der efter den
opgørelse skal betale. Mål og beløb læses fra indstillingerne — de var
tidligere hårdkodet til 100 og 50 point på den skærm, så en ændring af
halvsmålet slog ikke igennem.

Filerne er skrevet til at åbne rigtigt ved dobbeltklik i **dansk** Excel:

- **Semikolon** som separator, ikke komma. Dansk Excel bruger semikolon som
  listeseparator, og med komma lander hele rækken i én kolonne.
- **UTF-8 BOM** forrest. Uden de tre bytes bliver æ, ø og å til volapyk.
- Felter med semikolon, citationstegn eller linjeskift sættes i anførselstegn,
  og citationstegn fordobles. En admin-bemærkning med et linjeskift i
  sprænger altså ikke filen.

Medlemslisten indeholder e-mail og telefon. Hver eksport skrives i
audit-loggen med navnet på den, der hentede den.

## Nulstilling af sæson

**Admin → Indstillinger → Klubdata → Nulstil ny sæson.** Kun super admins.

Alle medlemmer sættes til 0 point, alle tilmeldinger slettes, pladserne bliver
fri igen, og åbne byttetilbud lukkes. Det kan ikke fortrydes.

**Stillingen arkiveres først.** Hvert medlems point, bonuspoint og antal
tjanser gemmes i `season_results`, før de nulstilles — ellers kunne klubben
ikke svare på, hvem der nåede målet, når nogen får en regning for
frivillighedsbidraget. Arkivet kan læses samme sted under *Tidligere sæsoner*.

Sletter et medlem sin profil, forsvinder deres arkivrækker med. Det er en
bevidst afvejning: privatlivspolitikken lover sletning, og det løfte vejer
tungere end at kunne dokumentere en gammel sæson.

Fire ting skal være opfyldt, før knappen kan trykkes:

1. Man skal være super admin — databasen tjekker det, ikke kun appen
2. Sæsonen skal have et navn, så arkivet kan findes igen
3. Man skal skrive `NULSTIL` i hånden
4. Databasen kræver det samme ord igen, så et kald uden om appen gør ingenting

Dialogen henter tallene fra databasen, når den åbnes, og advarer særskilt,
hvis der stadig ligger tjanser, ingen har gjort op — de ville give 0 point.

Fra SQL:

```sql
select * from public.admin_season_reset_preview();          -- hvad ville ske
select * from public.admin_reset_season('NULSTIL', '2025/2026');
select * from public.admin_season_list();                   -- arkivet
```

## Køreplan

- [ ] E-mailnotifikationer (i dag kun beskeder inde i appen)
- [ ] Rigtigt domæne (fx `frivillig.randersvk.dk`) i stedet for Vercel-adressen
- [ ] Del `App.jsx` op i filer

## License

MIT
