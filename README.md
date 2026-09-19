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
**`supabase/RUN_ALL.sql`** → Run. Det er de ti migrationer sat efter
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
| 18.5–18.6 | At ingen funktion står åben for anonyme, og at kun appens 23 egne er åbne for indloggede |
| 19–20 | INFO: hvor mange venter på godkendelse og bekræftelse |

**Alt skal stå `OK`, på nær `INFO`-linjerne.** Linje 17 og 18 står som `FEJL`,
indtil `seed.sql` er kørt — det er ventet. Står noget andet som `FEJL`, siger
`detalje`-kolonnen hvem eller hvad det drejer sig om.

Nederst kommer en NOTICE om `pg_cron`. Er den ikke slået til på projektet, er
det ikke en fejl — appen kalder selv opgørelsen, når nogen er logget ind.

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

## Drift

### Fejl fra medlemmernes telefoner

Uventede fejl skrives til `client_errors` og kan ses under **Admin → Audit log
→ Fejl**. En fejlgrænse omkring appen sørger samtidig for, at et nedbrud under
rendering giver en forklaring i stedet for en hvid skærm.

Databasen sætter en grænse på 20 fejl pr. bruger i timen, og fejl ældre end
90 dage slettes automatisk (eller med `select public.prune_client_errors();`).

Det er ikke et rigtigt overvågningsværktøj — der er ingen alarmer. Ser I
samme fejl hos mange på én gang, er noget gået i stykker for alle.

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
