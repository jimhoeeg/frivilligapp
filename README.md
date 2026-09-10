# RVK Frivillig - Task Coordinator App

Volunteer task coordination web app for Randers Volleyballklub (RVK).

## Features

- 🔐 **Login og oprettelse** — med holdvalg og admin-godkendelse af nye medlemmer
- 📋 **Opgaver** — søg, filtrér og tag tjanser
- 📊 **Point** — beregnes i databasen ud fra tilmeldinger plus admins bonuspoint
- 🏆 **Rangliste** — medlemmer og hold
- 🔄 **Byt tjanser** — tilmelding og point flytter samlet i én databasefunktion
- 🔔 **Notifikationer** — ved godkendelse, tildeling, ændret eller aflyst opgave
- 🛡️ **Admin-panel** — opgaver, medlemmer, roller, godkendelser og audit-log
- 📱 **Mobile-first** — bygget til telefonen

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

Tjek bagefter at der kun er tre triggere på tilmeldinger:

```sql
select tgname from pg_trigger
 where tgrelid = 'public.task_claims'::regclass and not tgisinternal;
-- forventet: tc_after_delete, tc_after_insert, tc_before_insert
```

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
psql -d rvk -f supabase/migrations/20260910120000_launch_hardening.sql
psql -d rvk -f supabase/tests/10_behaviour.sql          # 15 tjek
```

## Deployment

Deployed on **Vercel** — auto-deploys on push to `main` branch.

Live: `https://frivilligapp.vercel.app`

### Deploy Manually

1. Go to [vercel.com](https://vercel.com)
2. Import GitHub repo: `jimhoeeg/frivilligapp`
3. Vercel auto-detects Vite config
4. Deploy! ✨

## Project Structure

```
src/App.jsx                    # hele appen
supabase/migrations/           # databaseændringer – kør i rækkefølge
supabase/functions/            # serverfunktioner (sletning af medlemmer)
supabase/tests/                # kan køre migrationen igennem lokalt
supabase_*.sql                 # historik, se "Ældre SQL-filer" ovenfor
```

## Køreplan

- [ ] E-mailnotifikationer (i dag kun beskeder inde i appen)
- [ ] Markering af gennemførte tjanser — point gives i dag ved tilmelding
- [ ] PWA: app-ikon og "Føj til hjemmeskærm"
- [ ] Fejlovervågning og fast backup
- [ ] Del `App.jsx` op i filer

## License

MIT
