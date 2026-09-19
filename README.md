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

## Udrulning af lanceringsrettelserne

> **Kør dette FØR appen sendes ud til medlemmerne.** Rettelserne til
> pointregnskab, adgang til medlemsdata, godkendelse, bytte og notifikationer
> ligger halvt i databasen. Uden trin 1 og 2 herunder virker appen ikke.

**1. Kør databasemigrationen**

Åbn Supabase Dashboard → SQL Editor → indsæt hele indholdet af
`supabase/migrations/20260910120000_launch_hardening.sql` → Run.

Filen kan køres flere gange uden at gøre skade. Læs afsnit 3 i filen først —
den genberegner alle point fra bunden, og manuelt tildelte bonuspoint fra før
migrationen går tabt i den proces.

Tjek bagefter hvilke triggere der ligger på tilmeldinger:

```sql
select tgname from pg_trigger
 where tgrelid = 'public.task_claims'::regclass and not tgisinternal;
-- forventet efter BEGGE migrationer:
--   tc_after_delete, tc_after_insert, tc_after_update,
--   tc_before_delete, tc_before_insert
```

Kør derefter de øvrige migrationer i `supabase/migrations/` i navnerækkefølge.

`20260918100000_task_completion.sql` flytter point fra *tilmelding* til
*bekræftet gennemført*, og nulstiller derfor pointtallene: alle eksisterende
tilmeldinger står som "afventer bekræftelse", indtil en admin gør dem op
under **Admin → Bekræft**.
Vil I i stedet godkende hele den eksisterende historik på én gang, står linjen
til det i bunden af filen.

`20260918140000_auto_confirm.sql` slår automatisk bekræftelse til efter 7 dage.
Findes `pg_cron` på projektet, oprettes et dagligt job kl. 03:00 UTC. Kan
udvidelsen ikke slås til, skriver filen det som en NOTICE og fejler ikke —
appen kalder så selv funktionen, når nogen er logget ind. Tjek hvad der skete:

```sql
select jobname, schedule from cron.job where jobname = 'rvk_auto_confirm';
```

`20260918160000_cleanup_orphans.sql` rydder efterladte pointfunktioner fra en
gren, der aldrig blev merget — se "Efterladt SQL i den rigtige database".

**2. Rul sletnings-funktionen ud**

```bash
supabase functions deploy delete-member
```

Uden den kan admins ikke slette eller afvise medlemmer — sletning kræver
service-nøglen, som aldrig må ligge i browseren.

**3. Sæt miljøvariabler i Vercel**

`VITE_SUPABASE_URL` og `VITE_SUPABASE_ANON_KEY` under Settings →
Environment Variables.

**4. Udpeg mindst to super admins**

```sql
update public.profiles set role = 'super_admin', approved = true
 where email in ('formand@randersvk.dk', 'kasserer@randersvk.dk');
```

To personer, så klubben ikke er låst ude hvis én mister adgangen.

**5. Godkend teksterne**

Vilkår og privatlivspolitik i `src/App.jsx` (`LEGAL_DOCS`) er **et udkast**.
Bestyrelsen skal læse dem igennem, og `LEGAL_CONTACT` skal rettes til klubbens
rigtige adresse, før appen sendes ud.

### Ældre SQL-filer

`supabase_*.sql` i roden er de oprindelige løsblade. De er stadig historikken
for, hvordan databasen blev bygget, men migrationen ovenfor er den gældende
sandhed — den overskriver de politikker, de gamle filer satte op. Kør dem
ikke igen.

### Test af databasen

`supabase/tests/` kan køre migrationen igennem mod en lokal Postgres:

```bash
createdb rvk
psql -d rvk -f supabase/tests/00_supabase_stub.sql     # efterligner Supabase
psql -d rvk -f supabase_setup.sql                       # basisskemaet
for m in supabase/migrations/*.sql; do psql -d rvk -f "$m"; done
psql -d rvk -f supabase/tests/10_behaviour.sql          # 15 tjek
psql -d rvk -f supabase/tests/20_completion.sql         # 14 tjek af bekræftelser
psql -d rvk -f supabase/tests/30_auto_confirm.sql      # 11 tjek af automatikken
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
supabase/migrations/           # databaseændringer – kør i rækkefølge
supabase/functions/            # serverfunktioner (sletning af medlemmer)
supabase/tests/                # kan køre migrationen igennem lokalt
supabase_*.sql                 # historik, se "Ældre SQL-filer" ovenfor
public/icon.svg                # klubbens ikon – PNG'erne er genereret herfra
```

Ikonerne (`icon-192.png`, `icon-512.png`, `apple-touch-icon.png`) er
rasteriseret fra `public/icon.svg`. Ændrer du SVG'en, skal PNG'erne
genskabes — ellers viser telefonerne det gamle ikon.

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

## Køreplan

- [ ] E-mailnotifikationer (i dag kun beskeder inde i appen)
- [ ] Fejlovervågning og fast backup
- [ ] Del `App.jsx` op i filer

## License

MIT
