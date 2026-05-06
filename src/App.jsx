import React, { useState, useMemo } from "react";
import {
  Home, ListChecks, Trophy, User, MapPin, Clock, Calendar, Zap, ChevronRight,
  Check, X, Filter, Search, Flame, Shield, Coffee, AlertCircle, ArrowLeft,
  Info, Crown, Medal, Users, TrendingUp, Eye, EyeOff, Camera, Mail, Phone,
  Award, Bell, LogOut, Trash2, ChevronDown, Lock, Briefcase, Edit3, Download,
  HelpCircle, Save, ArrowRight, CheckCircle2, AtSign, Plus, MoreVertical,
  ShieldCheck, UserPlus, Repeat, DollarSign, AlertTriangle, Activity, FileText,
  Pencil, Copy, MessageCircle, Send, UserCheck, UserX, ThumbsUp, BellRing,
  ArrowLeftRight, CalendarDays, List, Grid3x3, ChevronLeft, Dot
} from "lucide-react";

const theme = {
  greenDark: "#0F4C3A",
  greenMid: "#1B8A5A",
  greenLight: "#4ADE80",
  greenPale: "#ECFDF5",
  purple: "#8B5CF6",
  purpleDark: "#6D28D9",
  pink: "#EC4899",
  pinkLight: "#F9A8D4",
  ink: "#0A1F17",
  paper: "#FAFAF7",
  muted: "#6B7F77",
};

const mockUser = {
  id: "u_01",
  name: "Mette Sørensen",
  initials: "MS",
  email: "mette.sorensen@email.dk",
  phone: "+45 22 45 87 91",
  team: "Damer 2",
  memberSince: "August 2023",
  pointsEarned: 42,
  pointsGoal: 75,
  role: "user",
  upcomingTasks: 2,
  tasksCompleted: 3,
  seasonRank: 12,
  responsibilities: [
    { id: "r1", title: "Kioskansvarlig", team: "Damer 2", since: "Jan 2025", icon: "coffee", color: "pink" },
    { id: "r2", title: "Holdleder-assistent", team: "Damer 2", since: "Aug 2024", icon: "users", color: "purple" },
  ],
  earnedBadges: [
    { id: "b1", name: "Ildsjæl", desc: "5 opgaver i træk", icon: "flame", unlocked: true, earnedOn: "15. mar 2026" },
    { id: "b2", name: "Redningsmand", desc: "Tog opgave under 24t varsel", icon: "shield", unlocked: true, earnedOn: "2. feb 2026" },
    { id: "b3", name: "Morgen-duks", desc: "3 morgenvagter før kl 8", icon: "sun", unlocked: true, earnedOn: "10. jan 2026" },
    { id: "b4", name: "Kiosk-konge", desc: "10 vagter i kiosken", icon: "coffee", unlocked: false, progress: 6, total: 10 },
    { id: "b5", name: "Dommer-pro", desc: "15 dommerbord-vagter", icon: "whistle", unlocked: false, progress: 4, total: 15 },
    { id: "b6", name: "Stævne-helt", desc: "Deltaget i 5 stævner", icon: "trophy", unlocked: false, progress: 2, total: 5 },
  ],
};

const mockMembers = [
  { id: "m_01", name: "Sofie Lindgaard", initials: "SL", team: "Damer Elite", points: 128, tasksDone: 9, badges: 5, streak: 4, isCurrentUser: false, role: "super_admin", roleSince: "Aug 2024" },
  { id: "m_02", name: "Jonas Bruun", initials: "JB", team: "Herrer 1", points: 115, tasksDone: 8, badges: 4, streak: 2, isCurrentUser: false, role: "admin", roleSince: "Jan 2025" },
  { id: "m_03", name: "Anne Kærgaard", initials: "AK", team: "Damer Elite", points: 104, tasksDone: 7, badges: 4, streak: 3, isCurrentUser: false, role: "admin", roleSince: "Sep 2024" },
  { id: "m_04", name: "Martin Holm", initials: "MH", team: "Herrer 1", points: 98, tasksDone: 7, badges: 3, streak: 1, isCurrentUser: false, role: "user" },
  { id: "m_05", name: "Lise Brandt", initials: "LB", team: "U17 Piger", points: 92, tasksDone: 6, badges: 3, streak: 2, isCurrentUser: false, role: "user" },
  { id: "m_06", name: "Peter Johansen", initials: "PJ", team: "Herrer 2", points: 87, tasksDone: 6, badges: 3, streak: 0, isCurrentUser: false, role: "user" },
  { id: "m_07", name: "Camilla Vang", initials: "CV", team: "Damer 2", points: 81, tasksDone: 5, badges: 2, streak: 1, isCurrentUser: false, role: "user" },
  { id: "m_08", name: "Thomas Madsen", initials: "TM", team: "U17 Drenge", points: 76, tasksDone: 5, badges: 2, streak: 3, isCurrentUser: false, role: "user" },
  { id: "m_09", name: "Rikke Sandberg", initials: "RS", team: "Damer Elite", points: 71, tasksDone: 5, badges: 2, streak: 0, isCurrentUser: false, role: "user" },
  { id: "m_10", name: "Christian Østergaard", initials: "CØ", team: "Herrer 1", points: 65, tasksDone: 4, badges: 2, streak: 1, isCurrentUser: false, role: "user" },
  { id: "m_11", name: "Louise Frandsen", initials: "LF", team: "U15 Piger", points: 58, tasksDone: 4, badges: 1, streak: 0, isCurrentUser: false, role: "user" },
  { id: "m_12", name: "Mette Sørensen", initials: "MS", team: "Damer 2", points: 42, tasksDone: 3, badges: 3, streak: 2, isCurrentUser: true, role: "user" },
  { id: "m_13", name: "Anders Krogh", initials: "AK", team: "Herrer 2", points: 38, tasksDone: 3, badges: 1, streak: 0, isCurrentUser: false, role: "user" },
  { id: "m_14", name: "Sara Bjerregaard", initials: "SB", team: "U17 Piger", points: 35, tasksDone: 2, badges: 1, streak: 1, isCurrentUser: false, role: "user" },
  { id: "m_15", name: "Mikkel Thomsen", initials: "MT", team: "U15 Drenge", points: 31, tasksDone: 2, badges: 1, streak: 0, isCurrentUser: false, role: "user" },
  { id: "m_16", name: "Kirsten Dyhr", initials: "KD", team: "Damer Elite", points: 27, tasksDone: 2, badges: 1, streak: 0, isCurrentUser: false, role: "user" },
  { id: "m_17", name: "Henrik Blom", initials: "HB", team: "Herrer 1", points: 22, tasksDone: 2, badges: 0, streak: 0, isCurrentUser: false, role: "user" },
  { id: "m_18", name: "Ida Lerche", initials: "IL", team: "U17 Piger", points: 18, tasksDone: 1, badges: 0, streak: 0, isCurrentUser: false, role: "user" },
  { id: "m_19", name: "Frederik Nygaard", initials: "FN", team: "Herrer 2", points: 14, tasksDone: 1, badges: 0, streak: 0, isCurrentUser: false, role: "user" },
  { id: "m_20", name: "Trine Aagaard", initials: "TA", team: "Damer 2", points: 9, tasksDone: 1, badges: 0, streak: 0, isCurrentUser: false, role: "user" },
];

const mockAuditLog = [
  { id: "a1", actor: "Sofie Lindgaard", action: "Gjorde Jonas Bruun til Admin", type: "role_change", date: "15. jan 2025", icon: "shield" },
  { id: "a2", actor: "Jonas Bruun", action: "Oprettede opgave: Kiosk – Lørdagsstævne", type: "task", date: "23. apr 2026", icon: "task" },
  { id: "a3", actor: "Anne Kærgaard", action: "Godkendte nyt medlem: Trine Aagaard", type: "member", date: "21. apr 2026", icon: "user" },
  { id: "a4", actor: "Sofie Lindgaard", action: "Ændrede sæsonens pointmål til 75", type: "settings", date: "1. aug 2025", icon: "settings" },
  { id: "a5", actor: "Jonas Bruun", action: "Slettede opgave: Oprydning (dublet)", type: "task", date: "18. apr 2026", icon: "task" },
];

const mockPendingMembers = [
  { id: "p_01", name: "Kasper Winther", initials: "KW", email: "kasper.winther@email.dk", phone: "+45 26 84 11 92", team: "Herrer 2", appliedOn: "I dag, 14:23", motivation: "Har netop meldt min søn ind på U15. Vil gerne bidrage med kiosk og kørsel.", referredBy: "Peter Johansen" },
  { id: "p_02", name: "Line Vestergaard", initials: "LV", email: "line.v@email.dk", phone: "+45 20 14 55 73", team: "Damer 3", appliedOn: "I går, 19:45", motivation: "Ny spiller på Damer 3 fra denne sæson.", referredBy: null },
  { id: "p_03", name: "Morten Dahl", initials: "MD", email: "morten.dahl@email.dk", phone: "+45 28 91 04 17", team: "Herrer 1", appliedOn: "2 dage siden", motivation: "Tidligere spiller, ønsker at komme tilbage som frivillig.", referredBy: "Jonas Bruun" },
];

const mockTaskComments = {
  t_001: [
    { id: "c1", author: "Jonas Bruun", authorInitials: "JB", authorRole: "admin", text: "Husk at hente nøglerne i kasse 4 inden kampen. Bip på min mobil hvis noget.", timestamp: "I går, 10:32", isOfficial: true },
    { id: "c2", author: "Anne Kærgaard", authorInitials: "AK", authorRole: "admin", text: "Jeg er til stede hele formiddagen, hvis I har spørgsmål til pointtavlen.", timestamp: "I dag, 08:15", isOfficial: true },
  ],
  t_002: [
    { id: "c3", author: "Jonas Bruun", authorInitials: "JB", authorRole: "admin", text: "OBS: Kaffemaskinen har været lunefuld – tjek at den er tændt 15 min før.", timestamp: "I dag, 09:01", isOfficial: true },
  ],
  t_003: [
    { id: "c4", author: "Thomas Madsen", authorInitials: "TM", authorRole: "user", text: "Jeg kommer 10 min senere – sidder i kø på motorvejen.", timestamp: "I dag, 07:15", isOfficial: false },
  ],
};

const mockNotifications = [
  { id: "n_01", type: "task_reminder", title: "Tjans i morgen kl. 10:00", body: "Dommerbord – U15 kamp på bane 1. Husk at møde 15 min før.", timestamp: "2 timer siden", read: false, icon: "clock", actionTaskId: "t_001" },
  { id: "n_02", type: "admin_message", title: "Ny besked fra Jonas Bruun", body: "OBS: Kaffemaskinen har været lunefuld – tjek at den er tændt 15 min før.", timestamp: "5 timer siden", read: false, icon: "message", actionTaskId: "t_002" },
  { id: "n_03", type: "badge_unlocked", title: "🎉 Ny badge låst op!", body: "Du har optjent 'Morgen-duks' for 3 morgenvagter før kl. 8.", timestamp: "I går", read: false, icon: "badge" },
  { id: "n_04", type: "swap_offer", title: "Camilla vil bytte tjans", body: "Camilla tilbyder 'Kiosk – Søndag' i bytte for din 'Kiosk – Lørdag'.", timestamp: "I går, 18:42", read: true, icon: "swap", actionSwapId: "s_01" },
  { id: "n_05", type: "new_task", title: "Ny haster-opgave", body: "Hal-opsætning lørdag morgen – kun 1 plads tilbage. +12 point.", timestamp: "2 dage siden", read: true, icon: "flame", actionTaskId: "t_003" },
  { id: "n_06", type: "points", title: "+15 point!", body: "Du har fuldført 'Dommerbord – Senior serie'. Du er nu på 42 point.", timestamp: "3 dage siden", read: true, icon: "zap" },
  { id: "n_07", type: "task_reminder", title: "Husk dit forkort til fredag", body: "Kagebagning – aflever inden 14:00 på fredag.", timestamp: "4 dage siden", read: true, icon: "clock", actionTaskId: "t_004" },
];

const mockSwapOffers = [
  { id: "s_01", status: "incoming", from: { name: "Camilla Vang", initials: "CV", team: "Damer 2" }, offering: { id: "t_off_01", title: "Kiosk – Søndag stævne", date: "Søn 27. apr", time: "13:00 – 17:00", location: "Kiosken, foyer", points: 20, icon: "coffee" }, wants: { id: "t_002", title: "Kiosk – Lørdagsstævne", date: "Lør 26. apr", time: "13:00 – 17:00", location: "Kiosken, foyer", points: 20, icon: "coffee" }, message: "Hej! Jeg kan ikke lørdag pga. barnedåb. Vil du bytte?", sentAt: "I går, 18:42" },
  { id: "s_02", status: "available", from: { name: "Thomas Madsen", initials: "TM", team: "U17 Drenge" }, offering: { id: "t_off_02", title: "Hal-opsætning søndag", date: "Søn 27. apr", time: "07:30 – 09:00", location: "Arena Randers", points: 12, icon: "setup" }, message: "Søger nogen der kan tage tidlig morgenvagt mod byttemulighed.", sentAt: "2 timer siden", openForOffers: true },
  { id: "s_03", status: "available", from: { name: "Louise Frandsen", initials: "LF", team: "U15 Piger" }, offering: { id: "t_off_03", title: "Dommerbord – U15", date: "Fre 2. maj", time: "18:00 – 20:00", location: "Bane 2", points: 15, icon: "whistle" }, message: "Uforudset – skal på arbejdsrejse. Hjælp søges!", sentAt: "5 timer siden", openForOffers: true, urgent: true },
];

const mockTasks = [
  { id: "t_001", title: "Dommerbord – U15 kamp", category: "Dommerbord", date: "Lør 26. apr", dateFull: "Lørdag 26. april 2026", time: "10:00 – 12:00", location: "Bane 1, Arena Randers", points: 15, difficulty: "Medium", urgent: false, spotsLeft: 1, spotsTotal: 2, description: ["Mød op 15 min før kampstart ved dommerbordet på bane 1.", "Tjek at elektronisk pointtavle og kampur er opsat.", "Registrer holdopstilling før kampstart (ark udleveres).", "Før point og time-outs løbende under kampen.", "Aflever udfyldt kampskema til turneringsleder efter kampen."], icon: "whistle" },
  { id: "t_002", title: "Kiosk – Lørdagsstævne", category: "Kiosk", date: "Lør 26. apr", dateFull: "Lørdag 26. april 2026", time: "13:00 – 17:00", location: "Kiosken, foyer", points: 20, difficulty: "Let", urgent: false, spotsLeft: 2, spotsTotal: 3, description: ["Mød ved kiosken kl. 12:45 – nøgle ligger i boks 4.", "Tænd kaffemaskine og opvarm pølser i rister.", "Tag imod betaling via MobilePay-boks 28481 eller kontant.", "Fyld varer op fra lager bag disken efter behov.", "Tæl kasse op og lås af ved vagtens slutning."], icon: "coffee" },
  { id: "t_003", title: "Hal-opsætning inden stævne", category: "Opsætning", date: "Lør 26. apr", dateFull: "Lørdag 26. april 2026", time: "07:30 – 09:00", location: "Arena Randers", points: 12, difficulty: "Let", urgent: true, spotsLeft: 1, spotsTotal: 4, description: ["Mød ved hovedindgang kl. 07:30 – Thomas låser op.", "Sæt 4 baner op iht. banevognsdiagram i redskabsrum.", "Spænd net til rette højde (damer/herrer – se skilt).", "Placer dommerstole og pointtavler ved hver bane.", "Stil tilskuerstole frem langs bane 1 og 2."], icon: "setup" },
  { id: "t_004", title: "Kagebagning til forældrekaffe", category: "Bagning", date: "Søn 27. apr", dateFull: "Søndag 27. april 2026", time: "Aflever inden 14:00", location: "Caféområdet", points: 8, difficulty: "Let", urgent: false, spotsLeft: 3, spotsTotal: 5, description: ["Bag en kage eller boller til ca. 12 personer.", "Undgå nødder (allergi blandt ungdomshold).", "Medbring gerne egen tallerken/fad – mærk med navn.", "Aflever i caféen senest kl. 14:00 søndag.", "Kontakt Lise på 22 33 44 55 hvis du bliver forsinket."], icon: "cake" },
  { id: "t_005", title: "Dommerbord – Senior serie", category: "Dommerbord", date: "Søn 27. apr", dateFull: "Søndag 27. april 2026", time: "15:00 – 17:00", location: "Bane 2, Arena Randers", points: 15, difficulty: "Medium", urgent: false, spotsLeft: 2, spotsTotal: 2, description: ["Mød op 15 min før kampstart ved dommerbordet på bane 2.", "Tjek at elektronisk pointtavle og kampur er opsat.", "Registrer holdopstilling før kampstart.", "Før point og time-outs løbende under kampen.", "Aflever udfyldt kampskema til turneringsleder."], icon: "whistle" },
  { id: "t_006", title: "Oprydning efter stævne", category: "Opsætning", date: "Søn 27. apr", dateFull: "Søndag 27. april 2026", time: "18:00 – 19:30", location: "Arena Randers", points: 10, difficulty: "Let", urgent: false, spotsLeft: 3, spotsTotal: 4, description: ["Mød ved hovedindgang kl. 18:00.", "Pak net og stolper ned iht. procedure i redskabsrum.", "Stil banevogne tilbage på plads.", "Fej og tør baner af hvis nødvendigt.", "Sluk lys og lås af med Thomas."], icon: "setup" },
];

const CategoryIcon = ({ type, className = "w-5 h-5" }) => {
  const icons = {
    whistle: <svg viewBox="0 0 24 24" fill="none" className={className} stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="9" cy="13" r="5" /><path d="M14 13h8" /><path d="M22 10v6" /><circle cx="9" cy="13" r="1" fill="currentColor" /></svg>,
    coffee: <Coffee className={className} />,
    setup: <svg viewBox="0 0 24 24" fill="none" className={className} stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 9l9-6 9 6" /><path d="M5 9v11h14V9" /><path d="M9 20v-6h6v6" /></svg>,
    cake: <svg viewBox="0 0 24 24" fill="none" className={className} stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M4 21h16v-7H4z" /><path d="M4 14v-3a2 2 0 012-2h12a2 2 0 012 2v3" /><path d="M8 9V6M12 9V4M16 9V6" /></svg>,
  };
  return icons[type] || icons.setup;
};

const DifficultyPill = ({ level }) => {
  const map = {
    Let:    { bg: "bg-emerald-50",  text: "text-emerald-700",  dot: "bg-emerald-500" },
    Medium: { bg: "bg-violet-50",   text: "text-violet-700",   dot: "bg-violet-500" },
    Hård:   { bg: "bg-pink-50",     text: "text-pink-700",     dot: "bg-pink-500" },
  };
  const s = map[level] || map.Let;
  return (
    <span className={`inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-[11px] font-semibold ${s.bg} ${s.text}`}>
      <span className={`w-1.5 h-1.5 rounded-full ${s.dot}`} />
      {level}
    </span>
  );
};

const TaskCard = ({ task, onClick }) => {
  const isFull = task.spotsLeft === 0;
  return (
    <button
      onClick={() => onClick(task)}
      className="w-full text-left bg-white rounded-2xl p-4 border border-stone-200/70 hover:border-emerald-300 active:scale-[0.99] transition-all shadow-sm hover:shadow-md group relative overflow-hidden"
    >
      {task.urgent && (
        <div className="absolute top-0 right-0 bg-gradient-to-br from-pink-500 to-pink-600 text-white text-[10px] font-bold px-3 py-1 rounded-bl-xl tracking-wide flex items-center gap-1">
          <Flame className="w-3 h-3" />
          HASTER
        </div>
      )}
      <div className="flex items-start gap-3">
        <div className="shrink-0 w-12 h-12 rounded-xl flex items-center justify-center text-white shadow-sm" style={{ background: `linear-gradient(135deg, ${theme.greenDark} 0%, ${theme.greenMid} 100%)` }}>
          <CategoryIcon type={task.icon} className="w-6 h-6" />
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between gap-2 mb-1">
            <h3 className="font-semibold text-[15px] leading-tight text-stone-900 pr-4">{task.title}</h3>
          </div>
          <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-[12px] text-stone-600 mb-2.5">
            <span className="inline-flex items-center gap-1"><Calendar className="w-3.5 h-3.5" />{task.date}</span>
            <span className="inline-flex items-center gap-1"><Clock className="w-3.5 h-3.5" />{task.time}</span>
          </div>
          <div className="flex items-center gap-1.5 text-[12px] text-stone-500 mb-3">
            <MapPin className="w-3.5 h-3.5" />
            <span className="truncate">{task.location}</span>
          </div>
          <div className="flex items-center justify-between gap-2">
            <div className="flex items-center gap-2">
              <DifficultyPill level={task.difficulty} />
              <span className="text-[11px] text-stone-500 font-medium">{task.spotsLeft}/{task.spotsTotal} ledige</span>
            </div>
            <div className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-white text-[12px] font-bold shadow-sm" style={{ background: `linear-gradient(135deg, ${theme.purple} 0%, ${theme.pink} 100%)` }}>
              <Zap className="w-3.5 h-3.5" fill="white" />
              +{task.points}
            </div>
          </div>
        </div>
      </div>
      <div className="absolute bottom-0 left-0 right-0 h-0.5 opacity-0 group-hover:opacity-100 transition-opacity" style={{ background: `linear-gradient(90deg, ${theme.greenMid}, ${theme.purple}, ${theme.pink})` }} />
    </button>
  );
};

const AuthField = ({ icon, label, type = "text", value, onChange, placeholder, error, rightIcon }) => (
  <div>
    <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-1.5">{label}</label>
    <div className="relative">
      <div className="absolute left-3 top-1/2 -translate-y-1/2 text-stone-400 pointer-events-none">{icon}</div>
      <input
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className={`w-full pl-10 ${rightIcon ? "pr-10" : "pr-3"} py-3 text-sm bg-stone-50 rounded-xl border outline-none transition-colors ${error ? "border-pink-300 bg-pink-50" : "border-stone-200 focus:border-emerald-500 focus:bg-white"}`}
      />
      {rightIcon && <div className="absolute right-3 top-1/2 -translate-y-1/2">{rightIcon}</div>}
    </div>
    {error && <p className="text-[11px] text-pink-600 mt-1">{error}</p>}
  </div>
);

const RoleBadge = ({ role, large = false }) => {
  if (role === "super_admin") {
    return (
      <span className={`inline-flex items-center gap-1 font-bold text-white rounded-full ${large ? "px-3 py-1 text-[11px]" : "px-2 py-0.5 text-[10px]"}`} style={{ background: `linear-gradient(135deg, ${theme.pink}, ${theme.purple})` }}>
        <Crown className="w-3 h-3" fill="white" />
        SUPER ADMIN
      </span>
    );
  }
  if (role === "admin") {
    return (
      <span className={`inline-flex items-center gap-1 font-bold text-white rounded-full ${large ? "px-3 py-1 text-[11px]" : "px-2 py-0.5 text-[10px]"}`} style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>
        <ShieldCheck className="w-3 h-3" />
        ADMIN
      </span>
    );
  }
  return null;
};

const AuthScreen = ({ onAuthenticated }) => {
  const [mode, setMode] = useState("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [team, setTeam] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [acceptTerms, setAcceptTerms] = useState(false);
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);

  const teams = ["Damer Elite", "Damer 2", "Damer 3", "Herrer 1", "Herrer 2", "U17 Piger", "U17 Drenge", "U15 Piger", "U15 Drenge", "Mini-volley"];

  const validate = () => {
    const e = {};
    if (!email) e.email = "E-mail er påkrævet";
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) e.email = "Ugyldig e-mail";
    if (!password) e.password = "Adgangskode er påkrævet";
    else if (password.length < 6) e.password = "Mindst 6 tegn";
    if (mode === "signup") {
      if (!name) e.name = "Navn er påkrævet";
      if (!team) e.team = "Vælg dit hold";
      if (!acceptTerms) e.terms = "Du skal acceptere vilkårene";
    }
    setErrors(e);
    return Object.keys(e).length === 0;
  };

  const handleSubmit = () => {
    if (!validate()) return;
    setLoading(true);
    setTimeout(() => {
      setLoading(false);
      onAuthenticated({
        email,
        name: name || "Mette Sørensen",
        team: team || "Damer 2",
        phone,
        isNew: mode === "signup",
      });
    }, 800);
  };

  return (
    <div className="min-h-screen relative overflow-hidden" style={{ background: `linear-gradient(160deg, ${theme.greenDark} 0%, ${theme.greenMid} 55%, ${theme.purple} 100%)` }}>
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-32 -right-20 w-80 h-80 rounded-full blur-3xl opacity-40" style={{ background: theme.pink }} />
      </div>

      <div className="relative max-w-md mx-auto min-h-screen flex flex-col px-6 py-10">
        <div className="flex flex-col items-center mb-8">
          <div className="w-16 h-16 rounded-2xl bg-white/15 backdrop-blur-sm border border-white/20 flex items-center justify-center mb-3 shadow-xl">
            <svg viewBox="0 0 100 100" className="w-10 h-10" fill="none" stroke="white" strokeWidth="3">
              <circle cx="50" cy="50" r="42" />
              <path d="M50 8 Q 22 50 50 92" />
              <path d="M50 8 Q 78 50 50 92" />
              <path d="M8 50 Q 50 22 92 50" />
              <path d="M8 50 Q 50 78 92 50" />
            </svg>
          </div>
          <div className="text-[10px] uppercase tracking-[0.25em] font-bold text-emerald-200">Randers Volleyballklub</div>
          <h1 className="text-2xl font-black text-white mt-1">RVK Frivillig</h1>
        </div>

        <div className="bg-white rounded-3xl shadow-2xl p-6 flex-1">
          <div className="bg-stone-100 rounded-xl p-1 flex mb-6">
            <button onClick={() => { setMode("login"); setErrors({}); }} className={`flex-1 py-2.5 rounded-lg text-sm font-bold transition-all ${mode === "login" ? "bg-white text-stone-900 shadow-sm" : "text-stone-500"}`}>Log ind</button>
            <button onClick={() => { setMode("signup"); setErrors({}); }} className={`flex-1 py-2.5 rounded-lg text-sm font-bold transition-all ${mode === "signup" ? "bg-white text-stone-900 shadow-sm" : "text-stone-500"}`}>Opret bruger</button>
          </div>

          <h2 className="text-xl font-bold text-stone-900 mb-1">{mode === "login" ? "Velkommen tilbage" : "Bliv frivillig"}</h2>
          <p className="text-[13px] text-stone-500 mb-5">{mode === "login" ? "Log ind for at se dine opgaver og point" : "Opret en profil og kom i gang med at samle point"}</p>

          <div className="space-y-3">
            {mode === "signup" && <AuthField icon={<User className="w-4 h-4" />} label="Fulde navn" value={name} onChange={setName} placeholder="F.eks. Mette Sørensen" error={errors.name} />}
            <AuthField icon={<AtSign className="w-4 h-4" />} label="E-mail" type="email" value={email} onChange={setEmail} placeholder="din@email.dk" error={errors.email} />
            <AuthField icon={<Lock className="w-4 h-4" />} label="Adgangskode" type={showPassword ? "text" : "password"} value={password} onChange={setPassword} placeholder={mode === "signup" ? "Mindst 6 tegn" : "••••••••"} error={errors.password} rightIcon={<button type="button" onClick={() => setShowPassword(!showPassword)} className="text-stone-400">{showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}</button>} />

            {mode === "signup" && <>
              <AuthField icon={<Phone className="w-4 h-4" />} label="Telefon (valgfri)" type="tel" value={phone} onChange={setPhone} placeholder="+45 ..." />
              <div>
                <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-1.5">Hold</label>
                <div className="relative">
                  <div className="absolute left-3 top-1/2 -translate-y-1/2 text-stone-400 pointer-events-none"><Users className="w-4 h-4" /></div>
                  <select value={team} onChange={(e) => setTeam(e.target.value)} className={`w-full pl-10 pr-10 py-3 text-sm bg-stone-50 rounded-xl border outline-none appearance-none transition-colors ${errors.team ? "border-pink-300 bg-pink-50" : "border-stone-200 focus:border-emerald-500"}`}>
                    <option value="">Vælg dit hold...</option>
                    {teams.map((t) => <option key={t} value={t}>{t}</option>)}
                  </select>
                  <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-stone-400 pointer-events-none" />
                </div>
                {errors.team && <p className="text-[11px] text-pink-600 mt-1">{errors.team}</p>}
              </div>
              <label className="flex items-start gap-2.5 pt-1 cursor-pointer">
                <input type="checkbox" checked={acceptTerms} onChange={(e) => setAcceptTerms(e.target.checked)} className="mt-0.5 w-4 h-4 accent-pink-500" />
                <span className="text-[12px] text-stone-600 leading-relaxed">Jeg accepterer klubbens <a className="text-emerald-700 font-semibold underline">vilkår</a> og <a className="text-emerald-700 font-semibold underline">privatlivspolitik (GDPR)</a></span>
              </label>
              {errors.terms && <p className="text-[11px] text-pink-600 -mt-2">{errors.terms}</p>}
            </>}

            <button onClick={handleSubmit} disabled={loading} className="w-full py-3.5 rounded-xl font-bold text-white shadow-lg active:scale-[0.98] transition-transform flex items-center justify-center gap-2 mt-2 disabled:opacity-60" style={{ background: `linear-gradient(135deg, ${theme.purple} 0%, ${theme.pink} 100%)`, boxShadow: "0 8px 24px -8px rgba(236, 72, 153, 0.5)" }}>
              {loading ? (
                <>
                  <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  {mode === "login" ? "Logger ind..." : "Opretter profil..."}
                </>
              ) : (
                <>
                  {mode === "login" ? "Log ind" : "Opret min profil"}
                  <ArrowRight className="w-4 h-4" />
                </>
              )}
            </button>
          </div>
        </div>

        <div className="text-center mt-5 text-[11px] text-white/70">© Randers Volleyballklub 2026</div>
      </div>
    </div>
  );
};

const TasksScreen = ({ tasks, onTaskClick, claimedIds, onOpenNotifications, onOpenSwaps, onOpenCalendar, unreadCount }) => {
  const [filter, setFilter] = useState("Alle");
  const [query, setQuery] = useState("");

  const filters = ["Alle", "Haster", "Dommerbord", "Kiosk", "Opsætning", "Bagning"];

  const visible = useMemo(() => {
    return tasks.filter((t) => {
      if (claimedIds.has(t.id)) return false;
      if (filter === "Haster" && !t.urgent) return false;
      if (filter !== "Alle" && filter !== "Haster" && t.category !== filter) return false;
      if (query && !t.title.toLowerCase().includes(query.toLowerCase())) return false;
      return true;
    });
  }, [tasks, filter, query, claimedIds]);

  return (
    <div className="pb-24">
      <div className="px-5 pt-12 pb-20 text-white relative overflow-hidden" style={{ background: `linear-gradient(135deg, ${theme.greenDark} 0%, ${theme.greenMid} 100%)` }}>
        <div className="relative">
          <div className="flex items-center justify-between mb-5">
            <div>
              <div className="text-[11px] uppercase tracking-widest font-bold text-emerald-200">Randers Volleyballklub</div>
              <div className="text-xs text-white/70">Frivillig-feed</div>
            </div>
            <div className="flex items-center gap-2">
              <button onClick={onOpenCalendar} className="w-10 h-10 rounded-full bg-white/10 backdrop-blur-sm border border-white/20 flex items-center justify-center hover:bg-white/20"><CalendarDays className="w-4 h-4" /></button>
              <button onClick={onOpenSwaps} className="w-10 h-10 rounded-full bg-white/10 backdrop-blur-sm border border-white/20 flex items-center justify-center hover:bg-white/20"><ArrowLeftRight className="w-4 h-4" /></button>
              <button onClick={onOpenNotifications} className="w-10 h-10 rounded-full bg-white/10 backdrop-blur-sm border border-white/20 flex items-center justify-center hover:bg-white/20 relative"><BellRing className="w-4 h-4" />
                {unreadCount > 0 && <span className="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] px-1 rounded-full flex items-center justify-center text-[10px] font-black text-white" style={{ background: `linear-gradient(135deg, ${theme.pink}, ${theme.purple})` }}>{unreadCount}</span>}
              </button>
            </div>
          </div>

          <h1 className="text-3xl font-bold leading-tight mb-1">Ledige opgaver</h1>
          <p className="text-sm text-emerald-100/90">Tag en tjans og saml point til sæsonen</p>
        </div>
      </div>

      <div className="px-5 -mt-12 relative z-10">
        <div className="bg-white rounded-2xl shadow-lg border border-stone-100 p-3 mb-4">
          <div className="flex items-center gap-2 bg-stone-50 rounded-xl px-3 py-2.5 border border-stone-100">
            <Search className="w-4 h-4 text-stone-400" />
            <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Søg i opgaver..." className="flex-1 bg-transparent outline-none text-sm placeholder:text-stone-400" />
            {query && <button onClick={() => setQuery("")}><X className="w-4 h-4 text-stone-400" /></button>}
          </div>
        </div>

        <div className="flex gap-2 overflow-x-auto pb-2 -mx-5 px-5 scrollbar-hide">
          {filters.map((f) => {
            const active = filter === f;
            const isUrgent = f === "Haster";
            return (
              <button key={f} onClick={() => setFilter(f)} className={`shrink-0 px-4 py-2 rounded-full text-[13px] font-semibold transition-all ${active ? "text-white shadow-md" : "bg-white text-stone-700 border border-stone-200 hover:border-stone-300"}`} style={active ? { background: isUrgent ? `linear-gradient(135deg, ${theme.pink}, ${theme.purple})` : `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` } : {}}>
                {isUrgent && <Flame className="w-3.5 h-3.5 inline mr-1 -mt-0.5" />}
                {f}
              </button>
            );
          })}
        </div>
      </div>

      <div className="px-5 mt-2 space-y-3">
        {visible.length === 0 ? (
          <div className="text-center py-12 text-stone-500">
            <AlertCircle className="w-10 h-10 mx-auto mb-2 text-stone-300" />
            <p className="text-sm">Ingen opgaver matcher lige nu</p>
          </div>
        ) : (
          visible.map((t) => <TaskCard key={t.id} task={t} onClick={onTaskClick} />)
        )}
      </div>
    </div>
  );
};

const Dashboard = ({ claimedTasks }) => {
  const earned = mockUser.pointsEarned + claimedTasks.reduce((s, t) => s + t.points, 0);
  const goal = mockUser.pointsGoal;
  const pct = Math.min(100, Math.round((earned / goal) * 100));
  const remaining = Math.max(0, goal - earned);

  return (
    <div className="pb-24">
      <div className="px-5 pt-12 pb-6 text-white relative overflow-hidden" style={{ background: `linear-gradient(135deg, ${theme.greenDark} 0%, ${theme.greenMid} 100%)` }}>
        <div className="relative">
          <div className="text-[11px] uppercase tracking-widest font-bold text-emerald-200 mb-1">Mit Dashboard</div>
          <h1 className="text-2xl font-bold mb-5">Hej, {mockUser.name.split(" ")[0]} 👋</h1>

          <div className="bg-white/10 backdrop-blur-md rounded-2xl p-5 border border-white/20">
            <div className="flex items-baseline justify-between mb-2">
              <div>
                <div className="text-[11px] uppercase tracking-wider font-bold text-emerald-200">Sæsonens point</div>
                <div className="flex items-baseline gap-1 mt-1">
                  <span className="text-4xl font-black">{earned}</span>
                  <span className="text-lg text-white/70">/ {goal}</span>
                </div>
              </div>
              <div className="px-3 py-1.5 rounded-full text-xs font-bold" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>{pct}%</div>
            </div>

            <div className="h-3 bg-white/15 rounded-full overflow-hidden mb-2 relative">
              <div className="h-full rounded-full transition-all duration-700 relative overflow-hidden" style={{ width: `${pct}%`, background: `linear-gradient(90deg, ${theme.pinkLight} 0%, ${theme.pink} 50%, ${theme.purple} 100%)`, boxShadow: `0 0 12px ${theme.pink}80` }} />
            </div>

            <div className="flex items-center justify-between text-xs text-white/80">
              {remaining > 0 ? <span><strong className="text-white">{remaining} point</strong> til du slipper for frivillighedsbidraget</span> : <span className="text-emerald-100 font-semibold">🎉 Du har nået sæsonens mål!</span>}
            </div>
          </div>
        </div>
      </div>

      <div className="px-5 mt-5 grid grid-cols-3 gap-2.5">
        <div className="bg-white rounded-xl p-3 border border-stone-100 shadow-sm"><div className="text-xl font-black text-stone-900">{claimedTasks.length + mockUser.upcomingTasks}</div><div className="text-[10px] uppercase tracking-wider text-stone-500 font-bold">Kommende</div></div>
        <div className="bg-white rounded-xl p-3 border border-stone-100 shadow-sm"><div className="text-xl font-black" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})`, WebkitBackgroundClip: "text", WebkitTextFillColor: "transparent" }}>3</div><div className="text-[10px] uppercase tracking-wider text-stone-500 font-bold">Badges</div></div>
        <div className="bg-white rounded-xl p-3 border border-stone-100 shadow-sm"><div className="text-xl font-black text-stone-900">#12</div><div className="text-[10px] uppercase tracking-wider text-stone-500 font-bold">Rangliste</div></div>
      </div>

      <div className="px-5 mt-6">
        <div className="flex items-center justify-between mb-3"><h2 className="text-sm font-bold text-stone-900">Mine kommende tjanser</h2><button className="text-xs font-semibold text-emerald-700">Se alle</button></div>
        {claimedTasks.length === 0 ? (
          <div className="bg-white rounded-xl p-5 border border-dashed border-stone-200 text-center">
            <ListChecks className="w-8 h-8 mx-auto mb-2 text-stone-300" />
            <p className="text-sm text-stone-500">Du har endnu ikke taget nogen tjanser.</p>
            <p className="text-xs text-stone-400 mt-1">Gå til <strong className="text-emerald-700">Opgaver</strong> for at komme i gang.</p>
          </div>
        ) : (
          <div className="space-y-2.5">
            {claimedTasks.map((t) => (
              <div key={t.id} className="bg-white rounded-xl p-3.5 border border-stone-100 shadow-sm flex items-center gap-3">
                <div className="w-10 h-10 rounded-lg flex items-center justify-center text-white shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}><CategoryIcon type={t.icon} className="w-5 h-5" /></div>
                <div className="flex-1 min-w-0">
                  <div className="font-semibold text-sm text-stone-900 truncate">{t.title}</div>
                  <div className="text-[11px] text-stone-500 flex items-center gap-2 mt-0.5"><span>{t.date}</span><span>•</span><span>{t.time}</span></div>
                </div>
                <div className="px-2 py-1 rounded-full text-white text-[11px] font-bold" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>+{t.points}</div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

const ScoreboardScreen = () => {
  const [filter, setFilter] = useState("Alle hold");
  const teams = ["Alle hold", ...Array.from(new Set(mockMembers.map((m) => m.team))).sort()];
  const filteredMembers = filter === "Alle hold" ? [...mockMembers] : mockMembers.filter((m) => m.team === filter);
  filteredMembers.sort((a, b) => b.points - a.points);
  const currentUserRank = filteredMembers.findIndex((m) => m.isCurrentUser) + 1;

  return (
    <div className="pb-24">
      <div className="px-5 pt-12 pb-6 text-white relative overflow-hidden" style={{ background: `linear-gradient(135deg, ${theme.greenDark} 0%, ${theme.greenMid} 100%)` }}>
        <div className="relative">
          <div className="flex items-center justify-between mb-3">
            <div><div className="text-[11px] uppercase tracking-widest font-bold text-emerald-200">Sæsonens rangliste</div><h1 className="text-2xl font-bold mt-0.5 flex items-center gap-2"><Trophy className="w-6 h-6" />Scoreboard 🏆</h1></div>
          </div>
        </div>
      </div>

      <div className="px-5 mt-4">
        <div className="flex gap-2 overflow-x-auto pb-2 -mx-5 px-5 scrollbar-hide">
          {teams.map((t) => {
            const active = filter === t;
            return (
              <button key={t} onClick={() => setFilter(t)} className={`shrink-0 px-3.5 py-1.5 rounded-full text-[12px] font-semibold transition-all ${active ? "text-white shadow-md" : "bg-white text-stone-700 border border-stone-200"}`} style={active ? { background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` } : {}}>
                {t}
              </button>
            );
          })}
        </div>
      </div>

      {currentUserRank > 0 && (
        <div className="px-5 mt-5">
          <div className="rounded-2xl p-4 flex items-center justify-between text-white shadow-lg" style={{ background: `linear-gradient(135deg, ${theme.purple} 0%, ${theme.pink} 100%)` }}>
            <div>
              <div className="text-[11px] uppercase tracking-widest font-bold text-white/80">Din placering</div>
              <div className="text-2xl font-black">#{currentUserRank}<span className="text-sm font-semibold text-white/70 ml-1.5">af {filteredMembers.length}</span></div>
            </div>
            <div className="text-right">
              <div className="text-[11px] uppercase tracking-widest font-bold text-white/80">Dine point</div>
              <div className="text-2xl font-black flex items-center gap-1 justify-end"><Zap className="w-5 h-5" fill="white" />{filteredMembers.find((m) => m.isCurrentUser)?.points ?? 0}</div>
            </div>
          </div>
        </div>
      )}

      <div className="px-5 mt-5">
        <div className="flex items-center justify-between mb-3"><h2 className="text-sm font-bold text-stone-900">Alle medlemmer</h2><span className="text-[11px] text-stone-500 font-semibold">{filteredMembers.length} frivillige</span></div>
        <div className="bg-white rounded-2xl border border-stone-100 shadow-sm overflow-hidden">
          {filteredMembers.map((m, i) => (
            <div key={m.id} className="flex items-center gap-3 px-4 py-3 border-b border-stone-100 last:border-b-0">
              <div className="text-sm font-black text-stone-400">{i + 1}</div>
              <div className="w-10 h-10 rounded-full flex items-center justify-center font-bold text-white text-xs shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>{m.initials}</div>
              <div className="flex-1 min-w-0">
                <div className="font-semibold text-[14px] text-stone-900">{m.name}</div>
                <div className="text-[11px] text-stone-500">{m.team} · {m.tasksDone} opgaver</div>
              </div>
              <div className="text-right shrink-0"><div className="font-black text-base text-stone-900">{m.points}</div><div className="text-[9px] text-stone-400 uppercase">point</div></div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

const BottomNav = ({ active, onChange }) => {
  const items = [
    { id: "tasks", label: "Opgaver", icon: ListChecks },
    { id: "dashboard", label: "Dashboard", icon: Home },
    { id: "scoreboard", label: "Rangliste", icon: Trophy },
    { id: "profile", label: "Profil", icon: User },
  ];
  return (
    <nav className="fixed bottom-0 left-0 right-0 max-w-md mx-auto bg-white/95 backdrop-blur-md border-t border-stone-200/80 px-2 py-1.5 z-40">
      <div className="flex items-center justify-around">
        {items.map((it) => {
          const Icon = it.icon;
          const isActive = active === it.id;
          return (
            <button key={it.id} onClick={() => onChange(it.id)} className="flex flex-col items-center gap-0.5 py-1.5 px-3 rounded-xl transition-all relative">
              {isActive && <div className="absolute -top-1.5 left-1/2 -translate-x-1/2 w-8 h-1 rounded-full" style={{ background: `linear-gradient(90deg, ${theme.purple}, ${theme.pink})` }} />}
              <Icon className="w-5 h-5" style={{ color: isActive ? theme.greenDark : "#9CA3AF" }} strokeWidth={isActive ? 2.5 : 2} />
              <span className="text-[10px] font-semibold" style={{ color: isActive ? theme.greenDark : "#9CA3AF" }}>{it.label}</span>
            </button>
          );
        })}
      </div>
    </nav>
  );
};

export default function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [currentUser, setCurrentUser] = useState({ ...mockUser, role: "user" });
  const [tab, setTab] = useState("tasks");
  const [claimedIds, setClaimedIds] = useState(new Set());
  const [toast, setToast] = useState(null);
  const [welcomeToast, setWelcomeToast] = useState(null);

  const claimedTasks = useMemo(
    () => mockTasks.filter((t) => claimedIds.has(t.id)),
    [claimedIds]
  );

  const handleAuth = (authData) => {
    const initials = authData.name.split(" ").map((n) => n[0]).slice(0, 2).join("").toUpperCase();
    setCurrentUser({
      ...mockUser,
      name: authData.name,
      email: authData.email,
      phone: authData.phone || mockUser.phone,
      team: authData.team,
      initials,
    });
    setIsAuthenticated(true);
    setTab("tasks");
    setWelcomeToast(authData.isNew ? `Velkommen til RVK, ${authData.name.split(" ")[0]}! 🎉` : `Velkommen tilbage, ${authData.name.split(" ")[0]}!`);
    setTimeout(() => setWelcomeToast(null), 3000);
  };

  const handleLogout = () => {
    setIsAuthenticated(false);
    setTab("tasks");
    setClaimedIds(new Set());
  };

  const handleClaim = (taskId) => {
    const next = new Set(claimedIds);
    next.add(taskId);
    setClaimedIds(next);
    const task = mockTasks.find((t) => t.id === taskId);
    setToast(`🎉 Tjansen er din! +${task.points} point`);
    setTimeout(() => setToast(null), 2500);
    setTimeout(() => setTab("dashboard"), 900);
  };

  if (!isAuthenticated) {
    return (
      <div className="min-h-screen bg-stone-50 font-sans antialiased">
        <style>{`@keyframes slideup { from { transform: translateY(100%); } to { transform: translateY(0); } } .animate-slideup { animation: slideup 0.3s cubic-bezier(0.16, 1, 0.3, 1); } .scrollbar-hide::-webkit-scrollbar { display: none; } .scrollbar-hide { -ms-overflow-style: none; scrollbar-width: none; }`}</style>
        <AuthScreen onAuthenticated={handleAuth} />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-stone-50 font-sans antialiased">
      <style>{`@keyframes slideup { from { transform: translateY(100%); } to { transform: translateY(0); } } .animate-slideup { animation: slideup 0.3s cubic-bezier(0.16, 1, 0.3, 1); } .scrollbar-hide::-webkit-scrollbar { display: none; } .scrollbar-hide { -ms-overflow-style: none; scrollbar-width: none; }`}</style>

      <div className="max-w-md mx-auto bg-white min-h-screen relative shadow-xl">
        {welcomeToast && <div className="fixed top-5 left-1/2 -translate-x-1/2 px-4 py-2.5 rounded-xl text-white text-sm font-semibold shadow-lg z-50 animate-slideup" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>{welcomeToast}</div>}

        {tab === "tasks" && <TasksScreen tasks={mockTasks} onTaskClick={(task) => { const next = new Set(claimedIds); next.add(task.id); setClaimedIds(next); handleClaim(task.id); }} claimedIds={claimedIds} onOpenNotifications={() => {}} onOpenSwaps={() => {}} onOpenCalendar={() => {}} unreadCount={0} />}
        {tab === "dashboard" && <Dashboard claimedTasks={claimedTasks} />}
        {tab === "scoreboard" && <ScoreboardScreen />}
        {tab === "profile" && <div className="pb-24"><div className="px-5 pt-12 pb-6 text-white relative overflow-hidden" style={{ background: `linear-gradient(135deg, ${theme.greenDark} 0%, ${theme.greenMid} 100%)` }}><h1 className="text-2xl font-bold mb-5">Min profil</h1><div className="relative flex flex-col items-center mb-6"><div className="w-24 h-24 rounded-full flex items-center justify-center font-black text-3xl text-white border-4 border-white/30 shadow-xl" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>{currentUser.initials}</div></div><div className="text-xl font-bold">{currentUser.name}</div></div><div className="px-5 mt-6"><button onClick={handleLogout} className="w-full bg-stone-100 border border-stone-200 rounded-xl py-3 text-[13px] font-semibold text-stone-700 inline-flex items-center justify-center gap-2 hover:bg-stone-50"><LogOut className="w-4 h-4" />Log ud</button></div></div>}

        {toast && <div className="fixed bottom-24 left-1/2 -translate-x-1/2 px-4 py-2.5 rounded-xl text-white text-sm font-semibold shadow-lg z-50" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>{toast}</div>}

        {!false && <BottomNav active={tab} onChange={setTab} />}
      </div>
    </div>
  );
}
