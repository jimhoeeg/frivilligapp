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
**`supabase/RUN_ALL.sql`** → Run. Det er de seksten migrationer sat efter
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
| `20260925220000_badges.sql` | 30 skjulte mærker: `member_badges` og `my_badges()`. |
| `20260926060000_email_outbox.sql` | Mail ud af appen: udbakke, påmindelser og cron. |
| `20260926070000_slet_medlem_med_tjans.sql` | Et medlem med en åben tjans kunne ikke slettes. |
| `20260926090000_tidligt_i_maal.sql` | Mærket "Tidligt i mål" følger nu halvdelen af målet. |

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

**5. Teksterne**

Vilkår og privatlivspolitik i `src/App.jsx` (`LEGAL_DOCS`) er **godkendt af
bestyrelsen den 25. september 2026**. Datoen står nederst på begge dokumenter
i appen (`LEGAL_UPDATED`) — retter nogen i teksten, skal den med.

`LEGAL_CONTACT` er den adresse, medlemmerne henvises til, når de vil have
deres oplysninger rettet eller slettet. Den skal være en adresse, nogen
faktisk læser.

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
src/App.jsx                    # medlemmernes app
src/admin.jsx                  # admin-panelet – hentes først når det åbnes
src/shared.jsx                 # det, begge bruger (tema, ikoner, hjælpere)
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

### Admin-panelet hentes først, når det åbnes

Hele appen lå i én fil, så enhver telefon hentede admin-panelet ved hvert
besøg — også de mange medlemmer, der aldrig åbner det. Koden er nu delt i
tre:

| Fil | Hvad | Hvem henter den |
|---|---|---|
| `src/App.jsx` | Medlemmernes app | alle |
| `src/admin.jsx` | Hele admin-panelet | kun den, der åbner panelet |
| `src/shared.jsx` | Det, begge bruger | alle |

`shared.jsx` findes, fordi to filer ikke kan importere hinanden uden at løbe
i ring. Der ligger `theme`, `CategoryIcon` og ikonkataloget, `ScrollRow`,
`parseTaskDate`, `RoleBadge`, `logAction` og et par andre — resten bliver,
hvor det hører hjemme.

`App.jsx` henter admin med `lazy(() => import("./admin.jsx"))` og viser
appens egen indlæsningsskærm imens. Det sker én gang, første gang panelet
åbnes.

| | Før | Efter |
|---|---|---|
| Medlem henter | 171 kB | **145 kB** |
| Admin henter (ved åbning af panelet) | 171 kB | 145 + 29 kB |

26 kB mindre for alle, der ikke er admins — 15 % af hele downloaden.

Flytningen er mekanisk og derfor farlig: et navn, der ikke kom med over,
bliver først til en fejl, når nogen åbner netop den skærm. Derfor er
ESLints `no-undef` regel den vigtigste kontrol her — den fanger præcis det
— og hele testsættet kører på de tre filer bagefter.

Prøv efter: `node chunk-check.js` (6 checks — henter et medlem admin-filen?)
og `node admin-smoke.js`, der åbner alle ni admin-faner og ser efter
JS-fejl på hver enkelt.


### Den huskede profil

Et gensyn med appen skal ikke føles som en ny installation. Navnet, holdet og
pointene lå allerede på telefonen sidst, så de vises med det samme, mens den
rigtige profil hentes i baggrunden. Er der sket noget — flere point, ny rolle
— retter det sig selv et øjeblik senere.

Målt med en server, der er sat til at svare på tre sekunder:

| | Første gang | Gensyn |
|---|---|---|
| Appen er fremme | 3.130 ms | **72 ms** |

Fire forbehold, som koden holder fast i:

- **Det er en genvej til visningen, ikke en adgangsbillet.** Alt, hvad appen
  laver, går gennem databasens egne regler med medlemmets egen nøgle. En
  forgyldt profil i telefonen giver ikke adgang til noget.
- Et medlem, der **ikke er godkendt**, lukkes aldrig ind på en gemt kopi —
  dér venter appen på serveren.
- Den huskede profil **slettes ved log ud**, og hvis serveren siger, at
  profilen ikke findes. Næste, der logger ind på telefonen, er måske en anden.
- Efter **en uge** bruges den ikke. Så er tallene gamle nok til, at et kort
  øjeblik med en spinner er bedre end at vise noget forkert.

Fejler hentningen, mens den gemte profil er fremme, bliver medlemmet stående
i appen med en lille besked i stedet for en fejlskærm. Man står måske midt i
hallen og er ved at tage en tjans.

Prøv efter: `node cache-check.js` (10 checks).

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

### Nulstilling af adgangskode

Linket i mailen går til Supabase, som tjekker det og sender medlemmet videre
til appen med svaret i adressens **hash**. To ting gik galt der, og begge er
rettet:

**Kapløbet om hash'en.** `supabase-js` rydder adressen, i samme sekund
biblioteket starter — og det sker, før React renderer. Appen læste hash'en
fra `window.location.hash` og tabte kapløbet, hver gang appen var hurtig.
Resultatet var, at man landede på login-skærmen i stedet for på "vælg ny
adgangskode". Nu gemmer et lille script i `index.html` adressen i
`window.__rvkStartHash`, før noget andet bliver hentet, og appen læser dér.

**Et link, der ikke virker, sagde ingenting.** Et nulstillingslink holder én
time og kan bruges én gang. Klikker man i en gammel mail — hvilket folk gør —
sender Supabase en fejl tilbage i hash'en, og appen viste bare login-skærmen.
Nu står der, hvad der skete, og hvad man gør: *"Linket er allerede brugt.
Tryk Glemt adgangskode, så sender vi et nyt."*

To ting i Supabase skal passe, ellers rammer linket ved siden af:

| Indstilling | Værdi |
|---|---|
| Site URL | `https://frivilligapp.vercel.app` |
| Redirect URLs | `https://frivilligapp.vercel.app/**` |

Står de forkert, bytter Supabase **selv** adressen ud med Site URL'en — uden
at fejle. Det var sådan, den første prøve endte på et domæne, der ikke fandtes
længere: appen bad om den rigtige adresse, og Supabase svarede med en anden.
Det kan kun ses ved at læse linket i den mail, der faktisk blev sendt.

Prøv efter: `node nulstil-check.js` (11 checks — gyldigt link, udløbet link,
brugt link, og et almindeligt besøg uden advarsler).

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

### Vilkår og privatlivspolitik

Teksterne står i `LEGAL_DOCS` i `src/App.jsx` og blev godkendt af
bestyrelsen den **25. september 2026**. Datoen vises nederst på begge
dokumenter som "Godkendt af bestyrelsen", så et medlem kan se, hvad de
har sagt ja til — og hvornår.

Retter nogen i teksten, skal `LEGAL_UPDATED` med. Ellers står der en dato,
bestyrelsen ikke har set.

Medlemmerne møder dem to steder: som links i samtykketeksten ved oprettelse,
og nederst på profilsiden.

Prøv efter: `node jura-check.js` (8 checks).

### Mails til medlemmerne

Skabelonerne til Supabases mails ligger i `supabase/email/` — nulstilling af
adgangskode, bekræftelse af e-mail og skift af adresse, alle på dansk og i
klubbens farver. `supabase/email/README.md` siger, hvor de skal sættes ind,
og hvilken af dem der faktisk sendes i dag.

Afsenderen bliver `frivillig@randersvk.dk` gennem Resend. Alle tre mails
siger, at man ikke kan svare, og henviser til `randersvolleyball@gmail.com`.

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

Medlemmerne henvises til `LEGAL_CONTACT` i `src/App.jsx`, i dag
`randersvolleyball@gmail.com`. Det er den adresse, en anmodning om indsigt,
rettelse eller sletning lander på. Aftal hvem der læser den.

## Ikoner

Appen havde fire ikoner: fløjte, kaffekop, hus og kage. De blev valgt ud fra
**kategorien**, så "Fotograf til kampdag" og "Dele flyers ud ved sprogcentret"
stod begge med en kaffekop, og bestyrelsen med et hus. Ikonet sagde altså
ikke noget om opgaven.

Nu er der et katalog på 31 ikoner i syv grupper — Kamp, Stævne, Mad og kiosk,
Transport, Faciliteter, Kommunikation, Klubben — hver med et dansk navn.
`IKON_KATALOG` i `App.jsx` er den ene liste, både vælgeren og opslaget bruger.
De fire gamle id'er (`whistle`, `coffee`, `setup`, `cake`) står der stadig, så
opgaver i databasen beholder deres ikon, og et ukendt id falder tilbage på
`setup`.

**Ikonet følger titlen, ikke kategorien.** `foreslaaIkon()` læser ordene:
"kiosk" → indkøbskurv, "kørsel" → bil, "nøgle" eller "halsover" → nøgle,
"foto" → kamera, "SoMe" → megafon, "bestyrelse" → mappe. Rækkefølgen i
`IKON_ORD` er ikke tilfældig — det mest bestemte ord vinder, så "stævnebord"
rammer bordet før "stævne" rammer pokalen, og "stævneudvalg" er et udvalg.
Siger titlen ingenting, bruges kategoriens ikon.

**Admin kan altid overtrumfe.** Ikonet står som en knap ved siden af
kategorien; tryk på det, og hele kataloget folder sig ud. Har admin først
valgt selv, rører appen det aldrig igen — heller ikke når titlen ændres.
"Lad appen vælge ud fra titlen" giver den tilbage. Samme princip som
pointforslaget: et forslag, ikke en pligt.

Skabeloner husker ikonet. Klubbens egne skabeloner tager det med tilbage;
appens indbyggede forslag har ikke noget eget ikon, for dér er titlen bedre.

Prøv efter: `node ikon-check.js` (11 checks).

## Mail ud af appen

Appen har hele tiden kunnet skrive til medlemmerne — men kun **inde i**
appen, hvor beskeden lå og ventede på, at nogen åbnede den. Over halvdelen
af alle beskeder, der nogensinde er sendt, er "du er godkendt": netop den,
et nyt medlem ikke kan se, før det logger ind.

Fire slags mail sendes nu af sig selv:

| Mail | Udløses af | Kan fravælges |
|---|---|---|
| Du er med | en admin godkender medlemmet | nej |
| Du er sat på en tjans | en admin tildeler en opgave | nej |
| En tjans er ændret / aflyst | opgaven rettes eller slettes | nej |
| Husk din tjans | cron, to dage før | **ja** |

De tre første er svar på noget, der lige er sket med ens egen profil eller
ens egen tjans. Påmindelsen er en venlighed, og den kan slås fra under
**Profil** i appen.

### Hvorfor en udbakke, og ikke bare et kald

Mail er noget, der kan gå galt halvvejs. Sender man direkte fra en trigger,
sidder man med tre dårlige valg: at lade medlemmets handling fejle, fordi en
mailserver er nede; at tabe beskeden; eller at prøve igen og sende den samme
mail fire gange.

Derfor skrives beskeden først ned i `email_outbox` med en **nøgle til
hændelsen** — `reminder:<tilmeldings-id>`, `notif:<besked-id>` — og nøglen er
unik. Kører påmindelsesjobbet to gange, sker der ingenting anden gang. Et
job tømmer udbakken bagefter, og en række, der fejler, bliver liggende og
kan prøves igen. Efter tre forsøg lader vi den ligge med fejlteksten i
`last_error`, så den kan ses i stedet for at køre i ring.

```
notifications ──trigger──► email_outbox ◄──cron (2 dage før)── task_claims
                                │
                        cron hvert 5. min
                                ▼
                     drain_email_outbox()  ──pg_net──►  send-mail  ──►  Resend
```

Databasen sender ikke selv mail. Nøglen til Resend ligger ét sted: i
`send-mail`-funktionens miljøvariabler. Nøglen til at kalde funktionen
ligger i Supabases **Vault**, så den hverken står i en fil eller i et
cron-job, nogen kan læse.

### Det, der skal sættes op én gang

1. **Edge Functions → Secrets** på `send-mail`:
   `RESEND_API_KEY`, `OUTBOX_KEY` (en tilfældig streng, du selv vælger),
   `MAIL_FRA` = `RVK Frivillig <frivillig@randersvk.dk>`, `APP_URL`.
2. **Vault** (Project Settings → Vault), to hemmeligheder:
   `outbox_key` = samme streng som `OUTBOX_KEY`, og
   `outbox_url` = `https://<projekt>.supabase.co/functions/v1/send-mail`.

Mangler de, sker der ikke noget slemt: udbakken fyldes, jobbet svarer
"outbox_key eller outbox_url mangler i Vault", og mailen sendes, så snart
nøglerne er der.

Skabelonerne står i `supabase/functions/send-mail/skabeloner.js` — almindelig
JavaScript med vilje, så både Deno og en node-test kan læse den samme fil. En
skabelon, der kun kan afprøves ved at sende en rigtig mail, bliver aldrig
afprøvet.

Prøv efter: `node mail2-check.js` (gengiver alle fem mails fra den rigtige
kode) og `psql -f supabase/tests/70_email_outbox.sql` (14 afsnit).

### Kør i hånden

```sql
select public.queue_task_reminders(2);   -- læg morgendagens påmindelser nu
select public.drain_email_outbox();      -- bank på send-mail med det samme
select * from public.email_outbox where sent_at is null;   -- hvad hænger?
```

## Mærker

Appen havde seks mærker, regnet ud i browseren af to tal — point og antal
tjanser — og de var alle sammen synlige, de ulåste bare nedtonet. De bliver,
hvor de er, som **mål**. Ovenpå ligger nu **30 skjulte mærker**, der først
dukker op, når de er fundet.

Et mål virker kun, hvis man kan se det. En opdagelse virker kun, hvis man
ikke kan. Dashboardet viser derfor de fundne ved navn og resten som et tal:
*"27 venter på at blive fundet."*

| Gruppe | Mærker |
|---|---|
| Vedholdenhed | Kom godt i gang · Arbejdshesten · Klubbens rygrad · Uundværlig · Stimen · Trofast |
| Bredde | Alsidig · Altmuligmand · Hele klubben rundt · Fast ved dommerbordet · Kioskens ven · Chaufføren · Stævneholdet · Pedellen · Klubbens stemme |
| Timing | Først på pletten · Sidste udkald · Redningsmanden · Den oversete tjans · Dobbeltdag · Weekendkrigeren |
| Omfang | Modig · Jernvilje · Den lange bane · Måneden ud · Brandslukkeren |
| Fællesskab | Byttecentralen · Nye ansigter · Tidligt i mål · Sæson to |

**Reglerne ligger i databasen** (`my_badges()`), ikke i browseren — samme
grund som for pointene: dér kan de ikke regnes forkert, og de kan ikke læses
af andre. Teksterne (`MAERKER` i `App.jsx`) er kun navne og forklaringer.

Tre ting, der er bevidste:

- **Kun bekræftede tjanser tæller.** Ellers kunne et mærke samles ved at
  melde sig til alt og ikke møde op, og så er det ingenting værd.
- **Et fundet mærke gemmes** i `member_badges` med et tidspunkt. Så forsvinder
  det ikke igen, hvis klubben ændrer en regel eller nulstiller sæsonen — og
  appen kan sige "nyt mærke" præcis én gang.
- **Datobaserede mærker springer gamle opgaver over.** De læser kun datoen,
  når den er en rigtig ISO-dato; opgaver med kun en dansk datotekst tæller
  ikke med. Bedre at springe over end at gætte.

Den ene fælde undervejs var værd at skrive ned: en sætning ser tabellen, som
den så ud, da sætningen begyndte. Den første version indsatte de nye mærker
og læste tabellen i **samme** sætning — så kom de nye ikke med i svaret, og
`er_ny` var aldrig sand. Nu læses de gamle før indsættelsen, og de nye kommer
fra `returning`.

Prøv efter: `node maerke-check.js` (13 checks) og
`psql -f supabase/tests/60_badges.sql` (9 afsnit).

## Frivilligbidraget

Klubben opkræver et **frivilligbidrag på 400 kr.** af de medlemmer, der ikke
når målet inden en opgørelse. Der er to tal i `settings`, og de betyder
præcis det, de hedder:

| Nøgle | Værdi | Betyder |
|---|---|---|
| `point_goal` | 200 | Point, der skal nås inden opgørelsen |
| `contribution_kr` | 400 | Beløbet for dem under målet |

**Ét mål, ikke to.** Før regnede appen et "sæsonmål" ud som det dobbelte af
`point_goal` og viste *det* som det store tal på dashboardet — så medlemmet
så 200, mens regningen faldt ved 100. Nu er målet det eneste tal: bjælken går
til det, procenten regnes af det, og det er det, der afgør bidraget. Stregen
midt på bjælken er halvvejs, og der sker ingenting ved den.

### Sæsonen 2026/27

Efteråret er **gratis** — det er klubbens prøveperiode. Der gøres op **én
gang, til foråret**, og målet er 200 point *i alt* for hele sæsonen.
Efterårets point tæller altså med.

Det står i `settings.contribution_note`, som admins skriver i
**Admin → Indstillinger**, og som vises under pointbjælken på medlemmets
dashboard. Det er den eneste måde, et medlem kan vide, hvornår regningen
falder.

### Fra og med 2027/28

Bidraget gøres op **pr. halvsæson**: to opgørelser om året, hvert med sit mål
og sit bidrag. Det kræver ikke ny kode — det kræver, at klubben

1. sætter `point_goal` til halvsæsonens mål (fx 100),
2. eksporterer bidragslisten og kører **sæsonnulstillingen** to gange om året
   i stedet for én, og
3. retter `contribution_note`, så medlemmerne kan se, hvornår næste opgørelse
   falder.

Pointene nulstilles kun af nulstillingen. Der er ingen automatik på
kalenderen, og det er med vilje: en opgørelse, der koster medlemmerne penge,
skal et menneske trykke på.

### Sådan gøres der op

**Admin → Oversigt → Eksportér bidragsliste** giver én linje pr. medlem:

```
Navn · Hold · Point · Mål · Status · Bidrag (kr)
```

| Status | Point | Bidrag |
|---|---|---|
| 🎉 Nået målet | ≥ `point_goal` | 0 kr. |
| 🟣 På vej | halvdelen til målet | 400 kr. |
| ⚠️ Bagud | under halvdelen | 400 kr. |

Det er alt eller intet ved målet. 199 point koster det samme som 0 — der er
ikke noget forholdsmæssigt bidrag.

Prøv efter: `node maal-check.js` (12 checks).

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
- [ ] SMTP via Resend — uden et verificeret domæne når "glemt adgangskode"
      kun projektets egne adresser
- [ ] Rigtigt domæne (fx `frivillig.randersvk.dk`) i stedet for Vercel-adressen
- [x] Del `App.jsx` op i filer — `App.jsx`, `admin.jsx`, `shared.jsx`
- [x] Vilkår og privatlivspolitik godkendt af bestyrelsen (25. september 2026)

## License

MIT
