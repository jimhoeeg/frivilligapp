# RVK Frivillig – Task Coordinator App

Volunteer task coordination web app for Randers Volleyballklub (RVK).

## Features

- 🔐 **Authentication** — Login/signup med Supabase Auth og holdvalg
- 📋 **Task Management** — Browse, søg, filtrér og tag frivilligopgaver
- 📊 **Points System** — Optjen point automatisk når du tager en opgave
- 🏆 **Leaderboard** — Se medlems- og holdplaceringer
- 🔄 **Task Swaps** — Byt vagter med andre frivillige
- 🗓️ **Calendar** — Se opgaver i en månedskalender
- 🛠️ **Admin Center** — Opret/redigér opgaver, administrér medlemmer, godkend admin-anmodninger og se audit-log
- 📱 **Mobile-First** — Fuldt responsivt design (installérbart som PWA)
- 🎨 **RVK Branding** — Grøn, lilla og pink tema

## Tech Stack

- **React 19** — UI framework
- **Vite** — Build tool & dev server
- **Tailwind CSS v3** — Styling
- **Lucide React** — Icons
- **Supabase** — Auth, Postgres-database og Row Level Security

## Getting Started

### Local Development

```bash
npm install
npm run dev
```

App runs on `http://localhost:5173/`

### Miljøvariabler

Kopiér `.env.example` til `.env.local` og udfyld dit Supabase-projekt:

```bash
VITE_SUPABASE_URL=https://dit-projekt.supabase.co
VITE_SUPABASE_ANON_KEY=din-anon-public-key
```

De samme to variabler skal sættes i Vercel → Settings → Environment Variables.

### Database setup

Kør SQL-filerne i Supabase Dashboard → SQL Editor i denne rækkefølge:

1. `supabase_setup.sql` — tabeller, RLS, triggers (profiler, point ved claim)
2. `supabase_profiles_rls.sql`
3. `supabase_task_claims_rls.sql`
4. `supabase_avatars_teams.sql`
5. `supabase_duration.sql`
6. `supabase_settings.sql`
7. `supabase_approvals.sql`
8. `supabase_admin_requests.sql`
9. `supabase_audit_log.sql`
10. `supabase_point_integrity.sql` — atomiske `claim_task`/`unclaim_task` RPC'er (mod overbooking + sikkert point-fratræk)
11. `supabase_notifications.sql` — notifikationer via triggers (velkomst + opgavetildeling)

Gør derefter din egen bruger til super_admin (se bunden af `supabase_setup.sql`).

> **Bemærk:** Frontend'en kalder `claim_task`/`unclaim_task`. Kør
> `supabase_point_integrity.sql` før (eller samtidig med) deploy af frontend.

### Build for Production

```bash
npm run build
npm run preview
```

### Lint

```bash
npm run lint
```

## Deployment

Deployed on **Vercel** — auto-deploys on push to `main` branch.

Live: `https://frivilligapp.vercel.app`

### Deploy Manually

1. Go to [vercel.com](https://vercel.com)
2. Import GitHub repo: `jimhoeeg/frivilligapp`
3. Vercel auto-detects Vite config
4. Sæt `VITE_SUPABASE_URL` og `VITE_SUPABASE_ANON_KEY`
5. Deploy! ✨

## Project Structure

```
src/
├── App.jsx           # App, screens og komponenter
├── supabaseClient.js # Supabase-klient
├── index.css         # Global styles (Tailwind)
└── main.jsx          # Entry point

supabase_*.sql        # Database-migrationer
```

## Features Roadmap

- [x] Notifikationer ved signup + opgavetildeling (via DB-triggers)
- [ ] Flere notifikationstyper (påmindelser via pg_cron, byttebesked)
- [ ] Email-notifikationer
- [ ] PWA offline-mode
- [ ] Dark mode
- [ ] Code-splitting af `App.jsx`

## License

MIT
