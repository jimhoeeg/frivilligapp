# RVK Frivillig - Task Coordinator App

Volunteer task coordination web app for Randers Volleyballklub (RVK).

## Features

- 🔐 **Authentication** — Login/signup with team selection
- 📋 **Task Management** — Browse, search, and claim volunteer tasks
- 📊 **Points System** — Track seasonal contribution points
- 🏆 **Leaderboard** — See member rankings and team standings
- 💬 **Task Comments** — Communicate about tasks with admin notes
- 🔄 **Task Swaps** — Exchange shifts with other volunteers
- 📱 **Mobile-First** — Fully responsive design
- 🎨 **RVK Branding** — Green, purple, and pink theme

## Tech Stack

- **React 18** — UI framework
- **Vite** — Build tool & dev server
- **Tailwind CSS v3** — Styling
- **Lucide React** — Icons
- **Mock Data** — Ready for API integration

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
src/
├── App.jsx          # Main app component & screens
├── index.css        # Global styles (Tailwind)
└── main.jsx         # Entry point
```

## Features Roadmap

- [ ] Backend API integration (tasks, users, points)
- [ ] Real authentication
- [ ] Database (PostgreSQL/MongoDB)
- [ ] Email notifications
- [ ] Admin dashboard (roles, audit log)
- [ ] PWA support (offline mode)
- [ ] Dark mode

## Testing Accounts (Mock)

| Mode    | Email              | Password |
|---------|-------------------|----------|
| Login   | any@email.dk      | anypass  |
| Signup  | Create new user   | 6+ chars |

## License

MIT
