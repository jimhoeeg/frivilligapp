import React, { useState, useMemo, useEffect } from "react";
import { supabase } from "./supabaseClient";
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

  const [teams, setTeams] = useState([]);

  useEffect(() => {
    supabase.from("teams").select("name").order("name").then(({ data }) => {
      if (data) setTeams(data.map((t) => t.name));
    });
  }, []);

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

  const handleSubmit = async () => {
    if (!validate()) return;
    setLoading(true);
    try {
      if (mode === "login") {
        const { data, error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) { setErrors({ email: error.message }); setLoading(false); return; }
        onAuthenticated({ email: data.user.email, isNew: false });
      } else {
        const { data, error } = await supabase.auth.signUp({
          email, password,
          options: { data: { name, team } },
        });
        if (error) { setErrors({ email: error.message }); setLoading(false); return; }
        onAuthenticated({ email: data.user?.email || email, name, team, phone, isNew: true });
      }
    } catch (err) {
      setErrors({ email: "Noget gik galt – prøv igen" });
    }
    setLoading(false);
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

const Dashboard = ({ claimedTasks, currentUser }) => {
  const earned = (currentUser?.pointsEarned || 0) + claimedTasks.reduce((s, t) => s + t.points, 0);
  const goal = 75;
  const pct = Math.min(100, Math.round((earned / goal) * 100));
  const remaining = Math.max(0, goal - earned);

  return (
    <div className="pb-24">
      <div className="px-5 pt-12 pb-6 text-white relative overflow-hidden" style={{ background: `linear-gradient(135deg, ${theme.greenDark} 0%, ${theme.greenMid} 100%)` }}>
        <div className="relative">
          <div className="text-[11px] uppercase tracking-widest font-bold text-emerald-200 mb-1">Mit Dashboard</div>
          <h1 className="text-2xl font-bold mb-5">Hej, {currentUser?.name?.split(" ")[0] || "frivillig"} 👋</h1>

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
        <div className="bg-white rounded-xl p-3 border border-stone-100 shadow-sm"><div className="text-xl font-black text-stone-900">{claimedTasks.length}</div><div className="text-[10px] uppercase tracking-wider text-stone-500 font-bold">Kommende</div></div>
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

const ScoreboardScreen = ({ currentUserId }) => {
  const [filter, setFilter] = useState("Alle hold");
  const [members, setMembers] = useState([]);

  useEffect(() => {
    supabase.from("profiles").select("id,name,initials,team,points,tasks_done,role").order("points", { ascending: false }).then(({ data }) => {
      if (data && data.length > 0) {
        setMembers(data.map((p) => ({
          id: p.id,
          name: p.name,
          initials: p.initials || p.name.split(" ").map((n) => n[0]).slice(0, 2).join("").toUpperCase(),
          team: p.team || "",
          points: p.points || 0,
          tasksDone: p.tasks_done || 0,
          badges: 0,
          streak: 0,
          isCurrentUser: p.id === currentUserId,
          role: p.role,
        })));
      }
    });
  }, [currentUserId]);

  const teams = ["Alle hold", ...Array.from(new Set(members.map((m) => m.team).filter(Boolean))).sort()];
  const filteredMembers = filter === "Alle hold" ? [...members] : members.filter((m) => m.team === filter);
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

// ============ KALENDER ============

const CalendarScreen = ({ tasks, claimedTasks, onTaskClick, onBack }) => {
  const [viewMode, setViewMode] = useState("month");
  const [current, setCurrent] = useState(new Date(2026, 3)); // April 2026

  const monthNames = ["januar","februar","marts","april","maj","juni","juli","august","september","oktober","november","december"];
  const dayNames = ["Man","Tir","Ons","Tor","Fre","Lør","Søn"];

  const year = current.getFullYear();
  const month = current.getMonth();
  const firstDay = new Date(year, month, 1);
  const lastDay = new Date(year, month + 1, 0);
  const startPad = (firstDay.getDay() + 6) % 7;

  const days = [];
  for (let i = startPad - 1; i >= 0; i--) days.push({ d: new Date(year, month, -i), cur: false });
  for (let i = 1; i <= lastDay.getDate(); i++) days.push({ d: new Date(year, month, i), cur: true });
  const rem = 7 - (days.length % 7);
  if (rem < 7) for (let i = 1; i <= rem; i++) days.push({ d: new Date(year, month + 1, i), cur: false });

  // Map tasks to day-of-month within current month
  const tasksByDay = {};
  tasks.forEach((t) => {
    const m = t.date.match(/(\d+)\.\s*(\w+)/);
    if (!m) return;
    const day = parseInt(m[1]);
    const mo = { apr: 3, maj: 4, jun: 5, jul: 6, aug: 7, sep: 8 }[m[2]];
    if (mo === month) {
      if (!tasksByDay[day]) tasksByDay[day] = [];
      tasksByDay[day].push(t);
    }
  });

  const allByDate = [...tasks, ...claimedTasks];

  return (
    <div className="pb-24 bg-stone-50 min-h-screen">
      <div className="px-5 pt-12 pb-5 text-white relative overflow-hidden" style={{ background: `linear-gradient(135deg, ${theme.greenDark} 0%, ${theme.greenMid} 100%)` }}>
        <div className="absolute inset-0 opacity-20 pointer-events-none"><div className="absolute -top-16 -right-8 w-48 h-48 rounded-full blur-3xl" style={{ background: theme.pink }} /></div>
        <div className="relative">
          <button onClick={onBack} className="inline-flex items-center gap-1.5 text-white/90 text-[12px] mb-3"><ArrowLeft className="w-4 h-4" />Tilbage</button>
          <div className="text-[11px] uppercase tracking-widest font-bold text-emerald-200">Opgave-kalender</div>
          <div className="flex items-center justify-between mt-1 mb-3">
            <h1 className="text-2xl font-bold capitalize">{monthNames[month]} {year}</h1>
            <div className="flex gap-1">
              <button onClick={() => setCurrent(new Date(year, month - 1))} className="p-2 rounded-lg bg-white/10 border border-white/20 hover:bg-white/20"><ChevronLeft className="w-4 h-4" /></button>
              <button onClick={() => setCurrent(new Date(year, month + 1))} className="p-2 rounded-lg bg-white/10 border border-white/20 hover:bg-white/20"><ChevronRight className="w-4 h-4" /></button>
            </div>
          </div>
          <div className="bg-white/10 rounded-xl p-1 flex border border-white/10">
            <button onClick={() => setViewMode("month")} className={`flex-1 py-1.5 rounded-lg text-[12px] font-bold inline-flex items-center justify-center gap-1.5 ${viewMode === "month" ? "bg-white text-emerald-900 shadow-sm" : "text-white/80"}`}><Grid3x3 className="w-3.5 h-3.5" />Måned</button>
            <button onClick={() => setViewMode("list")} className={`flex-1 py-1.5 rounded-lg text-[12px] font-bold inline-flex items-center justify-center gap-1.5 ${viewMode === "list" ? "bg-white text-emerald-900 shadow-sm" : "text-white/80"}`}><List className="w-3.5 h-3.5" />Liste</button>
          </div>
        </div>
      </div>

      <div className="px-5 mt-4">
        {viewMode === "month" ? (
          <div className="bg-white rounded-2xl border border-stone-100 shadow-sm overflow-hidden">
            <div className="grid grid-cols-7 bg-stone-50 border-b border-stone-100">
              {dayNames.map((d) => <div key={d} className="text-center py-2 text-[11px] font-bold text-stone-500 uppercase">{d}</div>)}
            </div>
            <div className="grid grid-cols-7">
              {days.map(({ d, cur }, i) => {
                const dayTasks = cur ? (tasksByDay[d.getDate()] || []) : [];
                const hasClaimed = dayTasks.some((t) => claimedTasks.some((ct) => ct.id === t.id));
                const today = d.toDateString() === new Date().toDateString();
                return (
                  <button key={i} onClick={() => dayTasks.length > 0 && onTaskClick(dayTasks[0])} disabled={!dayTasks.length} className={`aspect-square border-b border-r border-stone-100 p-1 flex flex-col items-center hover:bg-emerald-50 transition-colors ${!cur ? "bg-stone-50/50" : ""} ${!dayTasks.length ? "cursor-default" : ""}`}>
                    <div className={`text-[11px] font-semibold w-5 h-5 flex items-center justify-center rounded-full ${today ? "text-white" : cur ? "text-stone-800" : "text-stone-300"}`} style={today ? { background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` } : {}}>{d.getDate()}</div>
                    {dayTasks.length > 0 && (
                      <div className="flex gap-0.5 mt-0.5 flex-wrap justify-center">
                        {dayTasks.slice(0, 3).map((_, idx) => <div key={idx} className="w-1.5 h-1.5 rounded-full" style={{ background: hasClaimed ? theme.greenMid : theme.purple }} />)}
                      </div>
                    )}
                  </button>
                );
              })}
            </div>
          </div>
        ) : (
          <div className="space-y-2.5">
            {tasks.sort((a, b) => {
              const ad = parseInt((a.date.match(/(\d+)/) || [])[1] || 0);
              const bd = parseInt((b.date.match(/(\d+)/) || [])[1] || 0);
              return ad - bd;
            }).map((t) => (
              <button key={t.id} onClick={() => onTaskClick(t)} className="w-full text-left bg-white rounded-xl p-3.5 border border-stone-100 shadow-sm hover:border-emerald-300 flex items-center gap-3 active:scale-[0.99] transition-all">
                <div className="w-10 h-10 rounded-lg flex items-center justify-center text-white shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}><CategoryIcon type={t.icon} className="w-5 h-5" /></div>
                <div className="flex-1 min-w-0">
                  <div className="font-bold text-[14px] text-stone-900 truncate">{t.title}</div>
                  <div className="text-[11px] text-stone-500 mt-0.5 flex items-center gap-1.5"><Calendar className="w-3 h-3" />{t.date}<span>·</span><Clock className="w-3 h-3" />{t.time}</div>
                </div>
                <div className="px-2 py-1 rounded-full text-white text-[11px] font-black shrink-0" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>+{t.points}</div>
              </button>
            ))}
          </div>
        )}
        <div className="mt-4 bg-violet-50 border border-violet-200 rounded-xl p-3 flex gap-2.5">
          <Info className="w-4 h-4 text-violet-600 shrink-0 mt-0.5" />
          <p className="text-[11px] text-violet-900 leading-relaxed">Prikker under datoer viser opgaver. Klik på en dato for at se detaljer om opgaven.</p>
        </div>
      </div>
    </div>
  );
};

// ============ BYTTE-MARKED ============

const SwapScreen = ({ onBack, claimedTasks }) => {
  const [tab, setTab] = useState("available");
  const [offers, setOffers] = useState([]);
  const [showNewOffer, setShowNewOffer] = useState(false);
  const [selected, setSelected] = useState(null);

  const incoming  = offers.filter((o) => o.status === "incoming");
  const available = offers.filter((o) => o.status === "available");
  const outgoing  = offers.filter((o) => o.status === "outgoing");

  const remove = (id) => setOffers((prev) => prev.filter((o) => o.id !== id));

  return (
    <div className="pb-24 bg-stone-50 min-h-screen">
      <div className="px-5 pt-12 pb-5 text-white relative overflow-hidden" style={{ background: `linear-gradient(135deg, ${theme.greenDark} 0%, ${theme.greenMid} 60%, ${theme.purple} 100%)` }}>
        <div className="absolute inset-0 opacity-20 pointer-events-none"><div className="absolute -top-16 -right-8 w-48 h-48 rounded-full blur-3xl" style={{ background: theme.pink }} /></div>
        <div className="relative">
          <button onClick={onBack} className="inline-flex items-center gap-1.5 text-white/90 text-[12px] mb-3"><ArrowLeft className="w-4 h-4" />Tilbage</button>
          <div className="text-[11px] uppercase tracking-widest font-bold text-emerald-200">Bytte-markedet</div>
          <h1 className="text-2xl font-bold mt-0.5 mb-4 flex items-center gap-2"><ArrowLeftRight className="w-6 h-6" />Byt tjanser</h1>
          <div className="bg-white/10 rounded-xl p-1 flex border border-white/10">
            {[
              { id: "available", label: `Tilgængelige (${available.length})` },
              { id: "incoming",  label: `Til mig`, badge: incoming.length },
              { id: "outgoing",  label: `Mine (${outgoing.length})` },
            ].map((t) => (
              <button key={t.id} onClick={() => setTab(t.id)} className={`flex-1 py-1.5 rounded-lg text-[12px] font-bold inline-flex items-center justify-center gap-1 ${tab === t.id ? "bg-white text-emerald-900 shadow-sm" : "text-white/80"}`}>
                {t.label}
                {t.badge > 0 && <span className="w-4 h-4 rounded-full text-[9px] font-black text-white flex items-center justify-center" style={{ background: theme.pink }}>{t.badge}</span>}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="px-5 mt-4 space-y-3">
        {tab === "available" && (
          <>
            <button onClick={() => setShowNewOffer(true)} className="w-full rounded-2xl p-3.5 text-white flex items-center gap-3 shadow-lg active:scale-[0.99] transition-transform" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
              <div className="w-10 h-10 rounded-xl bg-white/20 flex items-center justify-center shrink-0"><Plus className="w-5 h-5" /></div>
              <div className="flex-1 text-left"><div className="font-bold text-[14px]">Tilbyd en af dine tjanser</div><div className="text-[11px] text-white/80 mt-0.5">Find en der kan overtage</div></div>
              <ChevronRight className="w-4 h-4 opacity-70" />
            </button>
            {available.length === 0
              ? <div className="bg-white rounded-2xl border border-dashed border-stone-200 p-8 text-center"><ArrowLeftRight className="w-10 h-10 mx-auto mb-2 text-stone-300" /><p className="text-[12px] text-stone-500">Ingen tilgængelige bytter</p></div>
              : available.map((o) => <SwapCard key={o.id} offer={o} onClick={() => setSelected(o)} />)
            }
          </>
        )}

        {tab === "incoming" && (
          <>
            <div className="bg-violet-50 border border-violet-200 rounded-xl p-3 flex gap-2.5"><Info className="w-4 h-4 text-violet-600 shrink-0 mt-0.5" /><p className="text-[11px] text-violet-900">Accepter eller afslå bytte-tilbud herunder.</p></div>
            {incoming.length === 0
              ? <div className="bg-white rounded-2xl border border-dashed border-stone-200 p-8 text-center"><ArrowLeftRight className="w-10 h-10 mx-auto mb-2 text-stone-300" /><p className="text-[12px] text-stone-500">Ingen indkommende tilbud</p></div>
              : incoming.map((o) => (
                  <IncomingSwapCard key={o.id} offer={o}
                    onAccept={() => remove(o.id)}
                    onDecline={() => remove(o.id)}
                  />
                ))
            }
          </>
        )}

        {tab === "outgoing" && (
          outgoing.length === 0
            ? <><div className="bg-white rounded-2xl border border-dashed border-stone-200 p-8 text-center"><ArrowLeftRight className="w-10 h-10 mx-auto mb-2 text-stone-300" /><p className="text-[12px] text-stone-500">Du har ingen aktive tilbud</p></div>
                <button onClick={() => setShowNewOffer(true)} className="w-full py-3 rounded-xl text-white font-bold mt-2" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>Tilbyd en tjans</button></>
            : outgoing.map((o) => <SwapCard key={o.id} offer={o} onClick={() => setSelected(o)} />)
        )}
      </div>

      {showNewOffer && (
        <NewSwapModal claimedTasks={claimedTasks} onClose={() => setShowNewOffer(false)} />
      )}

      {selected && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 backdrop-blur-sm" onClick={() => setSelected(null)}>
          <div className="bg-white rounded-t-3xl w-full max-w-md p-5 pb-8 animate-slideup" onClick={(e) => e.stopPropagation()}>
            <div className="w-12 h-1 bg-stone-200 rounded-full mx-auto mb-4" />
            <div className="flex items-start gap-3 mb-4">
              <div className="w-12 h-12 rounded-xl flex items-center justify-center text-white shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}><CategoryIcon type={selected.offering.icon} className="w-6 h-6" /></div>
              <div><h3 className="text-lg font-bold text-stone-900">{selected.offering.title}</h3><div className="text-[12px] text-stone-500 mt-0.5 flex items-center gap-1.5"><Calendar className="w-3 h-3" />{selected.offering.date} · {selected.offering.time}</div></div>
            </div>
            <div className="bg-stone-50 rounded-xl p-3 mb-4 flex items-center gap-3">
              <div className="w-10 h-10 rounded-full flex items-center justify-center text-white font-bold text-[11px]" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>{selected.from.initials}</div>
              <div><div className="text-[13px] font-semibold">{selected.from.name}</div><div className="text-[11px] text-stone-500">{selected.from.team}</div></div>
              <div className="ml-auto px-2 py-1 rounded-full text-white text-[11px] font-black" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>+{selected.offering.points}</div>
            </div>
            {selected.message && <div className="mb-4 bg-violet-50 border border-violet-200 rounded-xl p-3"><p className="text-[13px] text-stone-700 italic">"{selected.message}"</p></div>}
            <div className="flex gap-2">
              <button onClick={() => setSelected(null)} className="flex-1 py-3 rounded-xl bg-stone-100 text-stone-700 font-semibold">Luk</button>
              <button onClick={() => setSelected(null)} className="flex-[2] py-3 rounded-xl text-white font-bold shadow-md" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>Overtag tjansen (+{selected.offering.points} pt)</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

const SwapCard = ({ offer, onClick }) => (
  <button onClick={onClick} className="w-full text-left bg-white rounded-2xl p-3.5 border border-stone-100 shadow-sm hover:border-emerald-200 active:scale-[0.99] transition-all relative overflow-hidden">
    {offer.urgent && <div className="absolute top-0 right-0 text-white text-[10px] font-bold px-2.5 py-0.5 rounded-bl-xl flex items-center gap-1" style={{ background: `linear-gradient(135deg, ${theme.pink}, ${theme.purple})` }}><Flame className="w-2.5 h-2.5" />HASTER</div>}
    <div className="flex items-start gap-3">
      <div className="w-11 h-11 rounded-xl flex items-center justify-center text-white shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}><CategoryIcon type={offer.offering.icon} className="w-5 h-5" /></div>
      <div className="flex-1 min-w-0">
        <div className="font-bold text-[14px] text-stone-900 truncate">{offer.offering.title}</div>
        <div className="text-[11px] text-stone-500 mt-0.5 flex items-center gap-1.5 flex-wrap"><Calendar className="w-3 h-3" />{offer.offering.date}<span>·</span><Clock className="w-3 h-3" />{offer.offering.time}</div>
        <div className="flex items-center gap-2 mt-2">
          <div className="w-6 h-6 rounded-full flex items-center justify-center text-[9px] font-bold text-white" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>{offer.from.initials}</div>
          <span className="text-[11px] text-stone-600">Tilbudt af <strong>{offer.from.name}</strong></span>
        </div>
      </div>
      <div className="px-2 py-1 rounded-full text-white text-[11px] font-black shrink-0" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>+{offer.offering.points}</div>
    </div>
  </button>
);

const IncomingSwapCard = ({ offer, onAccept, onDecline }) => (
  <div className="bg-white rounded-2xl border border-violet-200 shadow-md overflow-hidden">
    <div className="px-4 py-2.5 text-white flex items-center gap-2" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
      <ArrowLeftRight className="w-4 h-4" />
      <span className="text-[12px] font-bold">Bytte-tilbud fra {offer.from.name}</span>
    </div>
    <div className="p-4">
      <div className="flex items-stretch gap-2 mb-3">
        <div className="flex-1 bg-emerald-50 border border-emerald-200 rounded-xl p-3">
          <div className="text-[9px] uppercase tracking-wider font-bold text-emerald-700 mb-1.5 flex items-center gap-1"><ArrowRight className="w-2.5 h-2.5" />De tager</div>
          <div className="font-bold text-[12px] text-stone-900 leading-tight">{offer.offering.title}</div>
          <div className="text-[10px] text-stone-600 mt-1">{offer.offering.date}</div>
        </div>
        <div className="flex items-center">
          <div className="w-8 h-8 rounded-full flex items-center justify-center text-white shadow-md" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}><ArrowLeftRight className="w-4 h-4" /></div>
        </div>
        <div className="flex-1 bg-pink-50 border border-pink-200 rounded-xl p-3">
          <div className="text-[9px] uppercase tracking-wider font-bold text-pink-700 mb-1.5 flex items-center gap-1"><ArrowLeft className="w-2.5 h-2.5" />Du giver</div>
          <div className="font-bold text-[12px] text-stone-900 leading-tight">{offer.wants.title}</div>
          <div className="text-[10px] text-stone-600 mt-1">{offer.wants.date}</div>
        </div>
      </div>
      {offer.message && <div className="mb-3 bg-stone-50 rounded-xl p-2.5 border border-stone-100"><p className="text-[12px] text-stone-700 italic">"{offer.message}"</p></div>}
      <div className="flex gap-2">
        <button onClick={onDecline} className="flex-1 py-2.5 rounded-xl bg-white border border-stone-200 text-[12px] font-semibold text-stone-700">Afslå</button>
        <button onClick={onAccept} className="flex-[2] py-2.5 rounded-xl text-white text-[12px] font-bold shadow-md flex items-center justify-center gap-1.5" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}><Check className="w-3.5 h-3.5" />Accepter bytte</button>
      </div>
    </div>
  </div>
);

const NewSwapModal = ({ claimedTasks, onClose }) => {
  const [selected, setSelected] = useState(null);
  const [message, setMessage] = useState("");
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 backdrop-blur-sm" onClick={onClose}>
      <div className="bg-white rounded-t-3xl w-full max-w-md max-h-[85vh] overflow-y-auto animate-slideup" onClick={(e) => e.stopPropagation()}>
        <div className="sticky top-0 bg-white border-b border-stone-100 px-5 pt-3 pb-3 flex items-center justify-between">
          <div className="w-12 h-1 bg-stone-200 rounded-full absolute top-2 left-1/2 -translate-x-1/2" />
          <h3 className="text-lg font-bold mt-2">Tilbyd tjans til bytte</h3>
          <button onClick={onClose} className="p-1.5 hover:bg-stone-100 rounded-lg mt-2"><X className="w-5 h-5" /></button>
        </div>
        <div className="p-5 space-y-4">
          <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-2">Vælg hvilken tjans du vil give væk</label>
          {claimedTasks.length === 0
            ? <div className="bg-stone-50 border border-dashed border-stone-200 rounded-xl p-5 text-center"><ListChecks className="w-8 h-8 mx-auto mb-1.5 text-stone-300" /><p className="text-[12px] text-stone-500">Du har ingen tjanser. Tag en opgave først.</p></div>
            : <div className="space-y-2">
                {claimedTasks.map((t) => (
                  <button key={t.id} onClick={() => setSelected(t.id)} className={`w-full text-left flex items-center gap-3 p-3 rounded-xl border transition-all ${selected === t.id ? "border-violet-400 bg-violet-50" : "border-stone-200 bg-white"}`}>
                    <div className="w-10 h-10 rounded-lg flex items-center justify-center text-white shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}><CategoryIcon type={t.icon} className="w-5 h-5" /></div>
                    <div className="flex-1 min-w-0"><div className="font-semibold text-[13px] text-stone-900 truncate">{t.title}</div><div className="text-[11px] text-stone-500 mt-0.5">{t.date} · {t.time}</div></div>
                    {selected === t.id && <div className="w-5 h-5 rounded-full flex items-center justify-center text-white" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}><Check className="w-3 h-3" strokeWidth={3} /></div>}
                  </button>
                ))}
              </div>
          }
          <div>
            <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-1.5">Besked (valgfri)</label>
            <textarea value={message} onChange={(e) => setMessage(e.target.value)} rows={3} placeholder="F.eks. Jeg er blevet syg..." className="w-full px-3 py-2.5 text-sm bg-stone-50 rounded-xl border border-stone-200 focus:border-emerald-500 outline-none resize-none" />
          </div>
          <div className="bg-violet-50 border border-violet-200 rounded-xl p-3 flex gap-2.5"><Info className="w-4 h-4 text-violet-600 shrink-0 mt-0.5" /><p className="text-[11px] text-violet-900">Tjansen vises på bytte-markedet til alle klubbens medlemmer.</p></div>
        </div>
        <div className="sticky bottom-0 bg-white border-t border-stone-100 p-4 flex gap-2">
          <button onClick={onClose} className="flex-1 py-3 rounded-xl bg-stone-100 text-stone-700 font-semibold">Annullér</button>
          <button onClick={onClose} disabled={!selected} className="flex-[2] py-3 rounded-xl text-white font-bold shadow-md disabled:opacity-50" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>Tilbyd til bytte</button>
        </div>
      </div>
    </div>
  );
};

// ============ ADMIN CENTER ============

// Bootstrap: disse e-mails får automatisk super_admin
const SUPER_ADMIN_EMAILS = ["formand@randersVK.dk", "admin@randersVK.dk"];

const AdminInput = ({ label, type = "text", placeholder, icon, textarea, value, onChange }) => (
  <div>
    {label && <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-1.5">{label}</label>}
    <div className="relative">
      {icon && <div className="absolute left-3 top-3 text-stone-400 pointer-events-none">{icon}</div>}
      {textarea
        ? <textarea rows={3} placeholder={placeholder} value={value} onChange={onChange} className="w-full px-3 py-2.5 text-sm bg-stone-50 rounded-xl border border-stone-200 focus:border-emerald-500 focus:bg-white outline-none resize-none" />
        : <input type={type} placeholder={placeholder} value={value} onChange={onChange} className={`w-full ${icon ? "pl-10" : "pl-3"} pr-3 py-2.5 text-sm bg-stone-50 rounded-xl border border-stone-200 focus:border-emerald-500 focus:bg-white outline-none`} />
      }
    </div>
  </div>
);

const MenuButton = ({ icon, label, danger, onClick }) => (
  <button onClick={onClick} className={`w-full flex items-center gap-2 px-3 py-2 text-[12px] font-medium hover:bg-stone-50 text-left ${danger ? "text-pink-700" : "text-stone-700"}`}>
    {icon}{label}
  </button>
);

// ---- ADMIN SHELL ----
const AdminDashboard = ({ currentUserRole, onBack, tasks, setTasks }) => {
  const [section, setSection] = useState("overview");
  const isSuperAdmin = currentUserRole === "super_admin";

  const sections = [
    { id: "overview",  label: "Oversigt",      icon: Activity,    superOnly: false },
    { id: "approvals", label: "Godkendelser",   icon: UserCheck,   superOnly: false, badge: 0 },
    { id: "tasks",     label: "Opgaver",        icon: ListChecks,  superOnly: false },
    { id: "members",   label: "Medlemmer",      icon: Users,       superOnly: false },
    { id: "teams",     label: "Hold",           icon: Users,       superOnly: true  },
    { id: "roles",     label: "Roller",         icon: ShieldCheck, superOnly: true  },
    { id: "settings",  label: "Indstillinger",  icon: DollarSign,  superOnly: true  },
    { id: "audit",     label: "Audit log",      icon: FileText,    superOnly: true  },
  ];

  return (
    <div className="pb-24 bg-stone-50 min-h-screen">
      {/* Header */}
      <div className="px-5 pt-12 pb-5 text-white relative overflow-hidden" style={{ background: `linear-gradient(135deg, ${theme.greenDark} 0%, ${theme.greenMid} 60%, ${theme.purple} 100%)` }}>
        <div className="absolute inset-0 opacity-20 pointer-events-none">
          <div className="absolute -top-16 -right-16 w-56 h-56 rounded-full blur-3xl" style={{ background: theme.pink }} />
        </div>
        <div className="relative">
          <button onClick={onBack} className="inline-flex items-center gap-1.5 text-white/90 text-[12px] mb-3"><ArrowLeft className="w-4 h-4" />Tilbage til appen</button>
          <div className="flex items-center justify-between mb-4">
            <div>
              <div className="text-[11px] uppercase tracking-widest font-bold text-emerald-200">Admin-panel</div>
              <h1 className="text-2xl font-bold mt-0.5">Kontrolcenter</h1>
            </div>
            <RoleBadge role={currentUserRole} large />
          </div>
          {/* Section tabs */}
          <div className="flex gap-2 overflow-x-auto -mx-5 px-5 pb-1 scrollbar-hide">
            {sections.map((s) => {
              const Icon = s.icon;
              const disabled = s.superOnly && !isSuperAdmin;
              const active = section === s.id;
              return (
                <button key={s.id} disabled={disabled} onClick={() => !disabled && setSection(s.id)}
                  className={`shrink-0 relative inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-[12px] font-bold transition-all ${active ? "bg-white text-emerald-900 shadow-md" : disabled ? "bg-white/5 text-white/30 border border-white/10 cursor-not-allowed" : "bg-white/10 text-white border border-white/20 hover:bg-white/20"}`}
                >
                  <Icon className="w-3.5 h-3.5" />
                  {s.label}
                  {s.badge > 0 && <span className="inline-flex items-center justify-center min-w-[18px] h-[18px] px-1 rounded-full text-[10px] font-black text-white" style={{ background: `linear-gradient(135deg, ${theme.pink}, ${theme.purple})` }}>{s.badge}</span>}
                  {disabled && <Lock className="w-3 h-3 opacity-60" />}
                </button>
              );
            })}
          </div>
        </div>
      </div>

      <div className="px-5 mt-5">
        {section === "overview"  && <AdminOverview onNavigate={setSection} tasks={tasks} />}
        {section === "approvals" && <AdminApprovals />}
        {section === "tasks"     && <AdminTasks tasks={tasks} setTasks={setTasks} />}
        {section === "members"   && <AdminMembers currentUserRole={currentUserRole} />}
        {section === "teams"     && isSuperAdmin && <AdminTeams />}
        {section === "roles"     && isSuperAdmin && <AdminRoles />}
        {section === "settings"  && isSuperAdmin && <AdminSettings />}
        {section === "audit"     && isSuperAdmin && <AdminAuditLog />}
      </div>
    </div>
  );
};

// ---- OVERSIGT ----
const AdminOverview = ({ onNavigate, tasks }) => {
  const [stats, setStats] = useState({ total: 0, goalReached: 0, behind: 0, avg: 0 });

  useEffect(() => {
    supabase.from("profiles").select("points").then(({ data }) => {
      if (data && data.length > 0) {
        const total = data.length;
        const goalReached = data.filter((m) => m.points >= 75).length;
        const behind = data.filter((m) => m.points < 30).length;
        const avg = Math.round(data.reduce((s, m) => s + m.points, 0) / total);
        setStats({ total, goalReached, behind, avg });
      }
    });
  }, []);

  const openSpots = tasks.reduce((s, t) => s + t.spotsLeft, 0);

  return (
    <div className="space-y-5">

      {/* Stats grid */}
      <div className="grid grid-cols-2 gap-3">
        {[
          { label: "Aktive medlemmer", value: totalMembers,          icon: <Users className="w-4 h-4" />,        accent: "#ECFDF5", color: theme.greenDark },
          { label: "Nået sæsonmål",    value: `${stats.goalReached}/${stats.total}`, icon: <CheckCircle2 className="w-4 h-4" />, accent: "#FCE7F3", color: "#BE185D" },
          { label: "Gns. point",       value: `${stats.avg} pt`,     icon: <TrendingUp className="w-4 h-4" />,   accent: "#EDE9FE", color: theme.purpleDark },
          { label: "Ledige pladser",   value: openSpots,             icon: <ListChecks className="w-4 h-4" />,  accent: "#ECFDF5", color: theme.greenDark },
        ].map((s, i) => (
          <div key={i} className="bg-white rounded-2xl p-4 border border-stone-100 shadow-sm">
            <div className="w-8 h-8 rounded-lg flex items-center justify-center mb-2.5" style={{ background: s.accent, color: s.color }}>{s.icon}</div>
            <div className="text-2xl font-black text-stone-900">{s.value}</div>
            <div className="text-[11px] text-stone-500 font-medium mt-0.5">{s.label}</div>
          </div>
        ))}
      </div>

      {/* Frivillighedsbidrag */}
      <div className="bg-white rounded-2xl p-4 border border-stone-100 shadow-sm">
        <div className="flex items-center justify-between mb-3">
          <div><div className="text-[11px] uppercase tracking-widest font-bold text-stone-500">Frivillighedsbidrag</div><div className="font-bold text-stone-900 mt-0.5">Sæsonens status</div></div>
          <AlertTriangle className="w-5 h-5 text-pink-500" />
        </div>
        {[
          { label: "🎉 Har nået målet", count: stats.goalReached,                                         color: theme.greenMid },
          { label: "🟣 På vej (30–74 pt)", count: stats.total - stats.goalReached - stats.behind,       color: theme.purple },
          { label: "⚠️ Bagud (under 30 pt)", count: stats.behind,                                       color: theme.pink },
        ].map((row, i) => {
          const pct = stats.total > 0 ? Math.round((row.count / stats.total) * 100) : 0;
          return (
            <div key={i} className="mb-2.5">
              <div className="flex justify-between text-[12px] mb-1"><span className="text-stone-700">{row.label}</span><span className="font-bold">{row.count}</span></div>
              <div className="h-2 bg-stone-100 rounded-full overflow-hidden"><div className="h-full rounded-full" style={{ width: `${pct}%`, background: row.color }} /></div>
            </div>
          );
        })}
        <button className="w-full mt-3 py-2.5 rounded-xl text-[12px] font-bold text-white flex items-center justify-center gap-1.5" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
          <Download className="w-3.5 h-3.5" />Eksportér bidragsliste
        </button>
      </div>

      {/* Seneste audit */}
      <AuditPreview />
    </div>
  );
};

const AuditPreview = () => {
  const [logs, setLogs] = useState([]);
  useEffect(() => {
    supabase.from("audit_log").select("*").order("created_at", { ascending: false }).limit(3).then(({ data }) => {
      if (data) setLogs(data);
    });
  }, []);
  if (logs.length === 0) return null;
  return (
    <div className="bg-white rounded-2xl p-4 border border-stone-100 shadow-sm">
      <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500 mb-3">Seneste aktivitet</div>
      <div className="space-y-2.5">
        {logs.map((log) => (
          <div key={log.id} className="flex gap-3 items-start">
            <div className="w-8 h-8 rounded-lg flex items-center justify-center shrink-0" style={{ background: theme.greenPale, color: theme.greenDark }}><Activity className="w-4 h-4" /></div>
            <div><div className="text-[13px] text-stone-900">{log.action}</div><div className="text-[11px] text-stone-500 mt-0.5">{log.actor_name} · {new Date(log.created_at).toLocaleDateString("da-DK")}</div></div>
          </div>
        ))}
      </div>
    </div>
  );
};

// ---- GODKENDELSER ----
const AdminApprovals = () => {
  const [pending, setPending] = useState([]);
  const [done, setDone]       = useState([]);
  const [expanded, setExpanded] = useState(null);
  const [rejecting, setRejecting] = useState(null);
  const [reason, setReason]    = useState("");

  const approve = (a) => { setPending((p) => p.filter((x) => x.id !== a.id)); setDone((d) => [{ ...a, action: "approved" }, ...d]); setExpanded(null); };
  const reject  = (a) => { setPending((p) => p.filter((x) => x.id !== a.id)); setDone((d) => [{ ...a, action: "rejected", reason }, ...d]); setRejecting(null); setReason(""); };

  return (
    <div className="space-y-4">
      <div className="bg-violet-50 border border-violet-200 rounded-xl p-3 flex gap-2.5">
        <Info className="w-4 h-4 text-violet-600 shrink-0 mt-0.5" />
        <p className="text-[11px] text-violet-900 leading-relaxed">Nye medlemmer får adgang til appen når du godkender dem. De modtager automatisk e-mail med resultatet.</p>
      </div>

      <div className="flex items-center justify-between">
        <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500">Afventer ({pending.length})</div>
        {pending.length > 1 && <button onClick={() => { pending.forEach(approve); }} className="text-[11px] font-bold text-emerald-700">Godkend alle</button>}
      </div>

      {pending.length === 0 ? (
        <div className="bg-emerald-50 border border-emerald-200 rounded-2xl p-6 text-center"><CheckCircle2 className="w-10 h-10 mx-auto mb-2 text-emerald-500" /><p className="text-[13px] font-semibold text-emerald-900">Alle ansøgninger behandlet!</p></div>
      ) : (
        pending.map((a) => (
          <div key={a.id} className="bg-white rounded-2xl border border-stone-100 shadow-sm overflow-hidden">
            <button onClick={() => setExpanded(expanded === a.id ? null : a.id)} className="w-full px-4 py-3 flex items-center gap-3 text-left hover:bg-stone-50">
              <div className="w-11 h-11 rounded-full flex items-center justify-center font-bold text-white text-sm shrink-0" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>{a.initials}</div>
              <div className="flex-1 min-w-0"><div className="font-bold text-[14px] text-stone-900">{a.name}</div><div className="text-[11px] text-stone-500">{a.team} · {a.appliedOn}</div></div>
              <ChevronDown className={`w-4 h-4 text-stone-400 transition-transform ${expanded === a.id ? "rotate-180" : ""}`} />
            </button>
            {expanded === a.id && (
              <div className="px-4 pb-4 border-t border-stone-100 bg-stone-50/50 pt-3 space-y-3">
                <div className="grid grid-cols-2 gap-2">
                  <div className="bg-white border border-stone-200 rounded-xl p-2"><div className="text-[9px] uppercase tracking-wider font-bold text-stone-400 flex items-center gap-1 mb-0.5"><Mail className="w-3 h-3" />E-mail</div><div className="text-[11px] font-semibold text-stone-700 truncate">{a.email}</div></div>
                  <div className="bg-white border border-stone-200 rounded-xl p-2"><div className="text-[9px] uppercase tracking-wider font-bold text-stone-400 flex items-center gap-1 mb-0.5"><Phone className="w-3 h-3" />Telefon</div><div className="text-[11px] font-semibold text-stone-700">{a.phone}</div></div>
                </div>
                <div className="bg-white border border-stone-200 rounded-xl p-2.5 text-[12px] text-stone-700">"{a.motivation}"</div>
                {a.referredBy && <div className="flex items-center gap-2 text-[12px] text-violet-800 bg-violet-50 border border-violet-200 rounded-lg px-3 py-2"><ThumbsUp className="w-3.5 h-3.5 shrink-0" />Anbefalet af <strong>{a.referredBy}</strong></div>}

                {rejecting === a.id ? (
                  <div className="bg-pink-50 border border-pink-200 rounded-xl p-3 space-y-2">
                    <label className="text-[11px] font-bold text-pink-900 uppercase tracking-wider block">Begrundelse</label>
                    <textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={2} placeholder="Fx: Hold-tilknytning kunne ikke verificeres…" className="w-full bg-white border border-pink-200 rounded-lg px-2.5 py-1.5 text-[12px] outline-none resize-none focus:border-pink-400" />
                    <div className="flex gap-2">
                      <button onClick={() => setRejecting(null)} className="flex-1 py-2 rounded-lg bg-white border border-stone-200 text-[12px] font-semibold">Fortryd</button>
                      <button onClick={() => reject(a)} disabled={!reason.trim()} className="flex-1 py-2 rounded-lg bg-pink-600 text-white text-[12px] font-bold disabled:opacity-50">Bekræft afvisning</button>
                    </div>
                  </div>
                ) : (
                  <div className="flex gap-2">
                    <button onClick={() => setRejecting(a.id)} className="flex-1 py-2.5 rounded-xl bg-white border border-stone-200 text-[13px] font-semibold text-stone-700 flex items-center justify-center gap-1.5"><UserX className="w-3.5 h-3.5" />Afvis</button>
                    <button onClick={() => approve(a)} className="flex-[2] py-2.5 rounded-xl text-white text-[13px] font-bold shadow-md flex items-center justify-center gap-1.5 active:scale-[0.98]" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}><UserCheck className="w-3.5 h-3.5" />Godkend</button>
                  </div>
                )}
              </div>
            )}
          </div>
        ))
      )}

      {done.length > 0 && (
        <div className="bg-white rounded-2xl border border-stone-100 divide-y divide-stone-100 shadow-sm overflow-hidden">
          {done.map((p) => (
            <div key={p.id} className="flex items-center gap-3 px-4 py-3">
              <div className={`w-9 h-9 rounded-full flex items-center justify-center shrink-0 ${p.action === "approved" ? "bg-emerald-100 text-emerald-700" : "bg-pink-100 text-pink-700"}`}>
                {p.action === "approved" ? <UserCheck className="w-4 h-4" /> : <UserX className="w-4 h-4" />}
              </div>
              <div className="flex-1 min-w-0"><div className="text-[13px] font-semibold text-stone-900">{p.name}</div><div className="text-[11px] text-stone-500">{p.action === "approved" ? "Godkendt" : "Afvist"} · Lige nu</div></div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

// ---- OPGAVESTYRING ----
const AdminTasks = ({ tasks, setTasks }) => {
  const [showNew, setShowNew]     = useState(false);
  const [editTask, setEditTask]   = useState(null);
  const [menuOpen, setMenuOpen]   = useState(null);

  const deleteTask = async (id) => {
    setTasks((prev) => prev.filter((t) => t.id !== id));
    setMenuOpen(null);
    await supabase.from("tasks").delete().eq("id", id);
  };

  const duplicateTask = async (t) => {
    const copy = { ...t, id: undefined, title: `${t.title} (kopi)`, spotsLeft: t.spotsTotal };
    setMenuOpen(null);
    const { data } = await supabase.from("tasks").insert({
      title: copy.title, category: copy.category, icon: copy.icon, date: copy.date,
      date_full: copy.dateFull, time: copy.time, location: copy.location,
      points: copy.points, difficulty: copy.difficulty, urgent: copy.urgent,
      spots_total: copy.spotsTotal, spots_left: copy.spotsTotal,
    }).select().single();
    if (data) {
      setTasks((prev) => [...prev, { ...copy, id: data.id }]);
    }
  };

  const saveTask = async (data) => {
    const steps = data.description.split("\n").filter(Boolean);
    if (editTask) {
      await supabase.from("tasks").update({
        title: data.title, category: data.category, icon: data.icon, date: data.date,
        date_full: data.dateFull, time: data.time, location: data.location,
        points: parseInt(data.points), difficulty: data.difficulty, urgent: data.urgent,
        spots_total: parseInt(data.spots), spots_left: parseInt(data.spots),
      }).eq("id", editTask.id);
      await supabase.from("task_steps").delete().eq("task_id", editTask.id);
      if (steps.length > 0) {
        await supabase.from("task_steps").insert(steps.map((text, i) => ({ task_id: editTask.id, step_order: i + 1, text })));
      }
      setTasks((prev) => prev.map((t) => t.id === editTask.id ? { ...t, ...data, description: steps, spotsLeft: parseInt(data.spots), spotsTotal: parseInt(data.spots) } : t));
    } else {
      const { data: row } = await supabase.from("tasks").insert({
        title: data.title, category: data.category, icon: data.icon, date: data.date,
        date_full: data.dateFull, time: data.time, location: data.location,
        points: parseInt(data.points), difficulty: data.difficulty, urgent: data.urgent,
        spots_total: parseInt(data.spots), spots_left: parseInt(data.spots),
      }).select().single();
      if (row && steps.length > 0) {
        await supabase.from("task_steps").insert(steps.map((text, i) => ({ task_id: row.id, step_order: i + 1, text })));
      }
      if (row) {
        setTasks((prev) => [...prev, { id: row.id, ...data, description: steps, spotsLeft: parseInt(data.spots), spotsTotal: parseInt(data.spots) }]);
      }
    }
    setShowNew(false); setEditTask(null);
  };

  return (
    <div className="space-y-4">
      <button onClick={() => setShowNew(true)} className="w-full py-2.5 rounded-xl text-[13px] font-bold text-white flex items-center justify-center gap-1.5 shadow-md active:scale-[0.98]" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
        <Plus className="w-4 h-4" />Opret ny opgave
      </button>

      <div className="space-y-2.5">
        {tasks.map((t) => {
          const filled = t.spotsTotal - t.spotsLeft;
          const pct    = Math.round((filled / t.spotsTotal) * 100);
          return (
            <div key={t.id} className="bg-white rounded-xl p-3.5 border border-stone-100 shadow-sm">
              <div className="flex items-start gap-3">
                <div className="w-10 h-10 rounded-lg flex items-center justify-center text-white shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}><CategoryIcon type={t.icon} className="w-5 h-5" /></div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-start justify-between gap-2">
                    <div><div className="font-bold text-[14px] text-stone-900">{t.title}</div><div className="text-[11px] text-stone-500 mt-0.5">{t.date} · {t.time}</div></div>
                    <div className="relative">
                      <button onClick={() => setMenuOpen(menuOpen === t.id ? null : t.id)} className="p-1 hover:bg-stone-100 rounded-lg"><MoreVertical className="w-4 h-4 text-stone-500" /></button>
                      {menuOpen === t.id && (
                        <div className="absolute top-full right-0 mt-1 bg-white rounded-xl shadow-xl border border-stone-100 py-1 w-44 z-30">
                          <MenuButton icon={<Pencil className="w-3.5 h-3.5" />} label="Rediger" onClick={() => { setEditTask(t); setMenuOpen(null); }} />
                          <MenuButton icon={<Copy className="w-3.5 h-3.5" />} label="Duplikér" onClick={() => duplicateTask(t)} />
                          <div className="h-px bg-stone-100 my-1" />
                          <MenuButton icon={<Trash2 className="w-3.5 h-3.5" />} label="Slet opgave" danger onClick={() => deleteTask(t.id)} />
                        </div>
                      )}
                    </div>
                  </div>
                  <div className="flex items-center gap-2 mt-2">
                    <div className="flex-1 h-1.5 bg-stone-100 rounded-full overflow-hidden"><div className="h-full rounded-full" style={{ width: `${pct}%`, background: pct === 100 ? `linear-gradient(90deg, ${theme.greenMid}, ${theme.greenLight})` : `linear-gradient(90deg, ${theme.purple}, ${theme.pink})` }} /></div>
                    <span className="text-[10px] font-bold text-stone-600">{filled}/{t.spotsTotal}</span>
                    <span className="px-1.5 py-0.5 rounded-md text-white text-[10px] font-black" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>+{t.points}</span>
                  </div>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {(showNew || editTask) && <TaskFormModal task={editTask} onClose={() => { setShowNew(false); setEditTask(null); }} onSave={saveTask} />}
    </div>
  );
};

const TaskFormModal = ({ task, onClose, onSave }) => {
  const [title, setTitle]       = useState(task?.title || "");
  const [category, setCategory] = useState(task?.category || "Dommerbord");
  const [icon, setIcon]         = useState(task?.icon || "whistle");
  const [date, setDate]         = useState(task?.date || "");
  const [time, setTime]         = useState(task?.time || "");
  const [location, setLocation] = useState(task?.location || "");
  const [points, setPoints]     = useState(task?.points || 15);
  const [spots, setSpots]       = useState(task?.spotsTotal || 2);
  const [difficulty, setDiff]   = useState(task?.difficulty || "Let");
  const [urgent, setUrgent]     = useState(task?.urgent || false);
  const [description, setDesc]  = useState(task?.description?.join("\n") || "");

  const iconOptions = [
    { id: "whistle", label: "Dommerbord" },
    { id: "coffee",  label: "Kiosk" },
    { id: "setup",   label: "Opsætning" },
    { id: "cake",    label: "Bagning" },
  ];

  const handleSave = () => {
    if (!title.trim() || !date.trim()) return;
    onSave({ title, category, icon, date, dateFull: date, time, location, points: parseInt(points), spots: parseInt(spots), difficulty, urgent, description });
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 backdrop-blur-sm" onClick={onClose}>
      <div className="bg-white rounded-t-3xl w-full max-w-md max-h-[92vh] overflow-y-auto animate-slideup" onClick={(e) => e.stopPropagation()}>
        <div className="sticky top-0 bg-white border-b border-stone-100 px-5 pt-3 pb-3 flex items-center justify-between z-10">
          <div className="w-12 h-1 bg-stone-200 rounded-full absolute top-2 left-1/2 -translate-x-1/2" />
          <h3 className="text-lg font-bold mt-2">{task ? "Rediger opgave" : "Ny opgave"}</h3>
          <button onClick={onClose} className="p-1.5 hover:bg-stone-100 rounded-lg mt-2"><X className="w-5 h-5" /></button>
        </div>

        <div className="p-5 space-y-4 pb-28">
          <AdminInput label="Titel" placeholder="F.eks. Dommerbord – U15 kamp" value={title} onChange={(e) => setTitle(e.target.value)} />

          {/* Kategori + ikon */}
          <div>
            <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-2">Kategori</label>
            <div className="grid grid-cols-4 gap-2">
              {iconOptions.map((o) => (
                <button key={o.id} onClick={() => { setIcon(o.id); setCategory(o.label); }}
                  className={`py-3 rounded-xl border flex flex-col items-center gap-1 text-[10px] font-semibold transition-all ${icon === o.id ? "border-violet-400 bg-violet-50 text-violet-700" : "border-stone-200 text-stone-600 hover:border-stone-300"}`}>
                  <CategoryIcon type={o.id} className="w-5 h-5" />{o.label}
                </button>
              ))}
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <AdminInput label="Dato" placeholder="Lør 26. apr" value={date} onChange={(e) => setDate(e.target.value)} />
            <AdminInput label="Tidsrum" placeholder="10:00 – 12:00" value={time} onChange={(e) => setTime(e.target.value)} />
          </div>

          <AdminInput label="Lokation" placeholder="Bane 1, Arena Randers" icon={<MapPin className="w-4 h-4" />} value={location} onChange={(e) => setLocation(e.target.value)} />

          <div className="grid grid-cols-2 gap-3">
            <AdminInput label="Point" type="number" placeholder="15" icon={<Zap className="w-4 h-4" />} value={points} onChange={(e) => setPoints(e.target.value)} />
            <AdminInput label="Pladser" type="number" placeholder="2" icon={<Users className="w-4 h-4" />} value={spots} onChange={(e) => setSpots(e.target.value)} />
          </div>

          {/* Sværhedsgrad */}
          <div>
            <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-1.5">Sværhedsgrad</label>
            <div className="flex gap-2">
              {["Let","Medium","Hård"].map((d) => (
                <button key={d} onClick={() => setDiff(d)} className={`flex-1 py-2 rounded-lg text-[12px] font-semibold transition-all border ${difficulty === d ? "border-violet-400 bg-violet-50 text-violet-700" : "border-stone-200 text-stone-600 hover:border-stone-300"}`}>{d}</button>
              ))}
            </div>
          </div>

          {/* Haster toggle */}
          <div className="flex items-center justify-between bg-pink-50 border border-pink-200 rounded-xl px-4 py-3">
            <div className="flex items-center gap-2"><Flame className="w-4 h-4 text-pink-600" /><div><div className="text-[13px] font-bold text-pink-900">Haster-opgave</div><div className="text-[11px] text-pink-700">Vises med rød markering</div></div></div>
            <button onClick={() => setUrgent(!urgent)} className={`w-11 h-6 rounded-full relative transition-colors ${urgent ? "" : "bg-stone-300"}`} style={urgent ? { background: `linear-gradient(90deg, ${theme.pink}, ${theme.purple})` } : {}}>
              <span className={`absolute top-0.5 w-5 h-5 bg-white rounded-full shadow-md transition-transform ${urgent ? "translate-x-5" : "translate-x-0.5"}`} />
            </button>
          </div>

          <AdminInput label="Vejledning (ét trin pr. linje)" placeholder={"Mød op 15 min før...\nTjek udstyr...\nAflever skema..."} textarea value={description} onChange={(e) => setDesc(e.target.value)} />
        </div>

        <div className="sticky bottom-0 bg-white border-t border-stone-100 p-4 flex gap-2">
          <button onClick={onClose} className="flex-1 py-3 rounded-xl bg-stone-100 text-stone-700 font-semibold">Annullér</button>
          <button onClick={handleSave} disabled={!title.trim()} className="flex-[2] py-3 rounded-xl text-white font-bold shadow-lg disabled:opacity-50 flex items-center justify-center gap-2" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
            <Save className="w-4 h-4" />{task ? "Gem ændringer" : "Opret opgave"}
          </button>
        </div>
      </div>
    </div>
  );
};

// ---- MEDLEMMER ----
const AdminMembers = ({ currentUserRole }) => {
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState("all");
  const [menuOpen, setMenuOpen] = useState(null);
  const [allMembers, setAllMembers] = useState([]);
  const isSuperAdmin = currentUserRole === "super_admin";

  useEffect(() => {
    supabase.from("profiles").select("id,name,initials,team,points,tasks_done,role").order("points", { ascending: false }).then(({ data }) => {
      if (data && data.length > 0) {
        setAllMembers(data.map((p) => ({
          id: p.id, name: p.name,
          initials: p.initials || p.name.split(" ").map((n) => n[0]).slice(0, 2).join("").toUpperCase(),
          team: p.team || "", points: p.points || 0, tasksDone: p.tasks_done || 0, role: p.role,
        })));
      }
    });
  }, []);

  const filtered = allMembers.filter((m) => {
    if (query && !m.name.toLowerCase().includes(query.toLowerCase())) return false;
    if (filter === "behind"  && m.points >= 30)  return false;
    if (filter === "reached" && m.points < 75)   return false;
    return true;
  });

  return (
    <div className="space-y-3">
      <div className="flex items-center gap-2 bg-white rounded-xl px-3 py-2.5 border border-stone-200 shadow-sm">
        <Search className="w-4 h-4 text-stone-400" />
        <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Søg medlem..." className="flex-1 bg-transparent outline-none text-sm" />
      </div>
      <div className="flex gap-2 overflow-x-auto -mx-5 px-5 pb-1 scrollbar-hide">
        {[["all","Alle"],["reached","Nået mål"],["behind","Bagud"]].map(([id,label]) => (
          <button key={id} onClick={() => setFilter(id)} className={`shrink-0 px-3 py-1.5 rounded-full text-[12px] font-semibold transition-all ${filter === id ? "text-white" : "bg-white text-stone-700 border border-stone-200"}`} style={filter === id ? { background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` } : {}}>{label}</button>
        ))}
      </div>
      <div className="bg-white rounded-2xl border border-stone-100 divide-y divide-stone-100 shadow-sm overflow-hidden">
        {filtered.map((m) => {
          const reached = m.points >= 75;
          const behind  = m.points < 30;
          return (
            <div key={m.id} className="flex items-center gap-3 px-4 py-3 relative">
              <div className="w-10 h-10 rounded-full flex items-center justify-center font-bold text-white text-xs shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>{m.initials}</div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-1.5"><div className="font-semibold text-[14px] text-stone-900 truncate">{m.name}</div><RoleBadge role={m.role} /></div>
                <div className="text-[11px] text-stone-500 truncate">{m.team} · {m.tasksDone} opgaver</div>
              </div>
              <div className={`text-[14px] font-black mr-1 ${reached ? "text-emerald-600" : behind ? "text-pink-600" : "text-stone-900"}`}>{m.points}<div className="text-[9px] text-stone-400 uppercase font-bold">/ 75</div></div>
              <div className="relative">
                <button onClick={() => setMenuOpen(menuOpen === m.id ? null : m.id)} className="p-1 hover:bg-stone-100 rounded-lg"><MoreVertical className="w-4 h-4 text-stone-500" /></button>
                {menuOpen === m.id && (
                  <div className="absolute top-full right-0 mt-0 bg-white rounded-xl shadow-xl border border-stone-100 py-1 w-48 z-30">
                    <MenuButton icon={<Mail className="w-3.5 h-3.5" />} label="Send besked" onClick={() => setMenuOpen(null)} />
                    <MenuButton icon={<Plus className="w-3.5 h-3.5" />} label="Tildel ekstra point" onClick={() => setMenuOpen(null)} />
                    {isSuperAdmin && m.role === "user" && <><div className="h-px bg-stone-100 my-1" /><MenuButton icon={<ShieldCheck className="w-3.5 h-3.5" />} label="Gør til Admin" onClick={() => setMenuOpen(null)} /></>}
                    {isSuperAdmin && <><div className="h-px bg-stone-100 my-1" /><MenuButton icon={<Trash2 className="w-3.5 h-3.5" />} label="Slet (GDPR)" danger onClick={() => setMenuOpen(null)} /></>}
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

// ---- HOLD (kun Super Admin) ----
const AdminTeams = () => {
  const [teams, setTeams] = useState([]);
  const [newName, setNewName] = useState("");
  const [editing, setEditing] = useState(null);
  const [editValue, setEditValue] = useState("");

  const reload = () => {
    supabase.from("teams").select("*").order("name").then(({ data }) => {
      if (data) setTeams(data);
    });
  };

  useEffect(() => { reload(); }, []);

  const addTeam = async () => {
    const name = newName.trim();
    if (!name) return;
    const { error } = await supabase.from("teams").insert({ name });
    if (!error) { setNewName(""); reload(); }
  };

  const saveEdit = async (id, oldName) => {
    const name = editValue.trim();
    if (!name || name === oldName) { setEditing(null); return; }
    await supabase.from("teams").update({ name }).eq("id", id);
    // Opdater også alle profiler der bruger det gamle navn
    await supabase.from("profiles").update({ team: name }).eq("team", oldName);
    setEditing(null);
    reload();
  };

  const deleteTeam = async (id) => {
    if (!confirm("Er du sikker? Hold kan ikke gendannes.")) return;
    await supabase.from("teams").delete().eq("id", id);
    reload();
  };

  return (
    <div className="space-y-4">
      <div className="rounded-2xl p-4 text-white" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>
        <div className="flex items-start gap-3">
          <Users className="w-5 h-5 shrink-0 mt-0.5" />
          <div>
            <div className="font-bold text-[14px]">Administrér hold</div>
            <p className="text-[12px] text-white/90 mt-0.5 leading-relaxed">Tilføj nye hold eller omdøb eksisterende. Ændringer reflekteres automatisk på alle medlemmer.</p>
          </div>
        </div>
      </div>

      {/* Tilføj nyt hold */}
      <div className="bg-white rounded-2xl p-4 border border-stone-100 shadow-sm">
        <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500 mb-2">Tilføj nyt hold</div>
        <div className="flex gap-2">
          <input
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && addTeam()}
            placeholder="F.eks. Damer 4"
            className="flex-1 bg-stone-50 border border-stone-200 rounded-xl px-3 py-2.5 text-sm outline-none focus:border-emerald-500 focus:bg-white"
          />
          <button onClick={addTeam} disabled={!newName.trim()} className="px-4 rounded-xl text-white text-sm font-bold disabled:opacity-50" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
            <Plus className="w-4 h-4 inline mr-1" />Tilføj
          </button>
        </div>
      </div>

      {/* Liste over hold */}
      <div>
        <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500 mb-2">Alle hold ({teams.length})</div>
        <div className="bg-white rounded-2xl border border-stone-100 divide-y divide-stone-100 shadow-sm overflow-hidden">
          {teams.length === 0 ? (
            <div className="px-4 py-8 text-center text-stone-400 text-sm">Ingen hold endnu</div>
          ) : teams.map((t) => (
            <div key={t.id} className="flex items-center gap-3 px-4 py-3">
              <div className="w-9 h-9 rounded-lg flex items-center justify-center text-white shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>
                <Users className="w-4 h-4" />
              </div>
              {editing === t.id ? (
                <>
                  <input
                    value={editValue}
                    onChange={(e) => setEditValue(e.target.value)}
                    onKeyDown={(e) => e.key === "Enter" && saveEdit(t.id, t.name)}
                    autoFocus
                    className="flex-1 bg-stone-50 border border-emerald-300 rounded-lg px-2 py-1 text-sm outline-none"
                  />
                  <button onClick={() => saveEdit(t.id, t.name)} className="text-[11px] font-bold text-white px-2.5 py-1 rounded-lg" style={{ background: theme.greenMid }}>Gem</button>
                  <button onClick={() => setEditing(null)} className="text-[11px] font-bold text-stone-600 px-2 py-1">Fortryd</button>
                </>
              ) : (
                <>
                  <div className="flex-1 font-semibold text-[14px] text-stone-900">{t.name}</div>
                  <button onClick={() => { setEditing(t.id); setEditValue(t.name); }} className="p-1.5 hover:bg-stone-100 rounded-lg">
                    <Pencil className="w-4 h-4 text-stone-500" />
                  </button>
                  <button onClick={() => deleteTeam(t.id)} className="p-1.5 hover:bg-pink-50 rounded-lg">
                    <Trash2 className="w-4 h-4 text-pink-500" />
                  </button>
                </>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

// ---- ROLLER (kun Super Admin) ----
const AdminRoles = () => {
  const [members, setMembers] = useState([]);

  const reload = () => {
    supabase.from("profiles").select("id,name,initials,team,role,admin_requested,admin_requested_at,email").order("points", { ascending: false }).then(({ data }) => {
      if (data && data.length > 0) {
        setMembers(data.map((p) => ({
          id: p.id, name: p.name,
          initials: p.initials || p.name.split(" ").map((n) => n[0]).slice(0, 2).join("").toUpperCase(),
          team: p.team || "", role: p.role, email: p.email,
          adminRequested: p.admin_requested, adminRequestedAt: p.admin_requested_at,
        })));
      }
    });
  };

  useEffect(() => { reload(); }, []);

  const superAdmins = members.filter((m) => m.role === "super_admin");
  const admins      = members.filter((m) => m.role === "admin");
  const users       = members.filter((m) => m.role === "user" && !m.adminRequested);
  const pending     = members.filter((m) => m.role === "user" && m.adminRequested);

  const promote = async (id, role) => {
    setMembers((prev) => prev.map((m) => m.id === id ? { ...m, role, adminRequested: false } : m));
    await supabase.from("profiles").update({ role, admin_requested: false }).eq("id", id);
  };
  const demote = async (id) => {
    setMembers((prev) => prev.map((m) => m.id === id ? { ...m, role: "user" } : m));
    await supabase.from("profiles").update({ role: "user" }).eq("id", id);
  };
  const rejectRequest = async (id) => {
    setMembers((prev) => prev.map((m) => m.id === id ? { ...m, adminRequested: false } : m));
    await supabase.from("profiles").update({ admin_requested: false }).eq("id", id);
  };

  return (
    <div className="space-y-4">
      <div className="rounded-2xl p-4 text-white" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
        <div className="flex items-start gap-3">
          <Crown className="w-5 h-5 shrink-0 mt-0.5" fill="white" />
          <div><div className="font-bold text-[14px]">Du er Super Admin</div><p className="text-[12px] text-white/90 mt-0.5 leading-relaxed">Udnæv og fjern Admins. Alle ændringer logges permanent i audit-loggen.</p></div>
        </div>
      </div>

      {/* Pending admin requests */}
      {pending.length > 0 && (
        <div>
          <div className="text-[11px] uppercase tracking-widest font-bold text-pink-600 mb-2 flex items-center gap-1.5">
            <BellRing className="w-3.5 h-3.5" />
            Anmodninger om admin ({pending.length})
          </div>
          <div className="bg-white rounded-2xl border-2 border-pink-200 divide-y divide-stone-100 shadow-sm overflow-hidden">
            {pending.map((m) => (
              <div key={m.id} className="px-4 py-3">
                <div className="flex items-center gap-3 mb-2">
                  <div className="w-10 h-10 rounded-full flex items-center justify-center font-bold text-white text-xs shrink-0" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>{m.initials}</div>
                  <div className="flex-1 min-w-0">
                    <div className="font-semibold text-[14px] text-stone-900">{m.name}</div>
                    <div className="text-[11px] text-stone-500">{m.team} · {m.email}</div>
                  </div>
                </div>
                <div className="flex gap-2">
                  <button onClick={() => promote(m.id, "admin")} className="flex-1 text-[12px] font-bold text-white py-2 rounded-lg" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>
                    ✓ Godkend
                  </button>
                  <button onClick={() => rejectRequest(m.id)} className="flex-1 text-[12px] font-bold text-pink-600 bg-pink-50 border border-pink-200 py-2 rounded-lg">
                    ✗ Afvis
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Super Admins */}
      <div>
        <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500 mb-2">Super Admins ({superAdmins.length})</div>
        <div className="bg-white rounded-2xl border border-stone-100 divide-y divide-stone-100 shadow-sm overflow-hidden">
          {superAdmins.map((m) => (
            <div key={m.id} className="flex items-center gap-3 px-4 py-3">
              <div className="w-10 h-10 rounded-full flex items-center justify-center font-bold text-white text-xs shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>{m.initials}</div>
              <div className="flex-1 min-w-0"><div className="font-semibold text-[14px] text-stone-900">{m.name}</div><div className="text-[11px] text-stone-500">Siden {m.roleSince}</div></div>
              <RoleBadge role="super_admin" />
              {superAdmins.length > 1 && !m.isCurrentUser && <button onClick={() => demote(m.id)} className="text-[11px] text-pink-600 font-semibold px-2 py-1 rounded-lg hover:bg-pink-50 ml-1">Fjern</button>}
            </div>
          ))}
        </div>
      </div>

      {/* Admins */}
      <div>
        <div className="flex items-center justify-between mb-2">
          <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500">Admins ({admins.length})</div>
        </div>
        <div className="bg-white rounded-2xl border border-stone-100 divide-y divide-stone-100 shadow-sm overflow-hidden">
          {admins.map((m) => (
            <div key={m.id} className="flex items-center gap-3 px-4 py-3">
              <div className="w-10 h-10 rounded-full flex items-center justify-center font-bold text-white text-xs shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>{m.initials}</div>
              <div className="flex-1 min-w-0"><div className="font-semibold text-[14px] text-stone-900">{m.name}</div><div className="text-[11px] text-stone-500">Siden {m.roleSince || "—"}</div></div>
              <RoleBadge role="admin" />
              <button onClick={() => demote(m.id)} className="text-[11px] text-pink-600 font-semibold px-2 py-1 rounded-lg hover:bg-pink-50 ml-1">Fjern</button>
            </div>
          ))}
        </div>
      </div>

      {/* Promover admin til super admin */}
      {admins.length > 0 && (
        <div>
          <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500 mb-2">Gør Admin til Super Admin</div>
          <div className="bg-white rounded-2xl border border-stone-100 divide-y divide-stone-100 shadow-sm overflow-hidden">
            {admins.map((m) => (
              <div key={m.id} className="flex items-center gap-3 px-4 py-3">
                <div className="w-10 h-10 rounded-full flex items-center justify-center font-bold text-white text-xs shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>{m.initials}</div>
                <div className="flex-1 min-w-0"><div className="font-semibold text-[14px] text-stone-900 truncate">{m.name}</div><div className="text-[11px] text-stone-500">{m.team}</div></div>
                <button onClick={() => promote(m.id, "super_admin")} className="text-[11px] font-bold text-white px-3 py-1.5 rounded-lg shrink-0" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>👑 Gør til Super Admin</button>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Promover bruger direkte */}
      <div>
        <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500 mb-2">Direkte promovering</div>
        <div className="bg-white rounded-2xl border border-stone-100 divide-y divide-stone-100 shadow-sm overflow-hidden">
          {users.slice(0, 10).map((m) => (
            <div key={m.id} className="flex items-center gap-3 px-4 py-3">
              <div className="w-10 h-10 rounded-full flex items-center justify-center font-bold text-white text-xs shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>{m.initials}</div>
              <div className="flex-1 min-w-0"><div className="font-semibold text-[14px] text-stone-900 truncate">{m.name}</div><div className="text-[11px] text-stone-500">{m.team}</div></div>
              <button onClick={() => promote(m.id, "admin")} className="text-[11px] font-bold text-white px-3 py-1.5 rounded-lg shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>Gør til Admin</button>
            </div>
          ))}
        </div>
      </div>

      <div className="bg-stone-100 rounded-xl p-3 text-[11px] text-stone-600 space-y-1 leading-relaxed">
        <div className="font-bold text-stone-700 flex items-center gap-1 mb-1"><Info className="w-3.5 h-3.5" />Best practices</div>
        <div>• Minimum 2 Super Admins – forhindrer lockout</div>
        <div>• Bootstrap-admin tildeles automatisk via e-mail: <code className="bg-white px-1 rounded text-[10px]">formand@randersVK.dk</code></div>
        <div>• Alle rolle-ændringer gemmes permanent i audit-loggen</div>
        <div>• Admin-rollen bør fornys hvert år ved generalforsamling</div>
      </div>
    </div>
  );
};

// ---- INDSTILLINGER (kun Super Admin) ----
const AdminSettings = () => {
  const [pointGoal, setPointGoal]     = useState("75");
  const [contribution, setContrib]    = useState("1500");
  const [seasonStart, setStart]       = useState("2025-08-01");
  const [seasonEnd, setEnd]           = useState("2026-06-30");
  const [saved, setSaved]             = useState(false);

  const save = () => { setSaved(true); setTimeout(() => setSaved(false), 2500); };

  return (
    <div className="space-y-4">
      {saved && <div className="bg-emerald-50 border border-emerald-200 rounded-xl p-3 flex items-center gap-2.5"><CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" /><p className="text-[13px] text-emerald-900 font-semibold">Indstillinger gemt!</p></div>}

      <div className="bg-white rounded-2xl p-4 border border-stone-100 shadow-sm space-y-4">
        <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500">Pointsystem</div>
        <AdminInput label="Sæsonens pointmål" type="number" placeholder="75" icon={<Zap className="w-4 h-4" />} value={pointGoal} onChange={(e) => setPointGoal(e.target.value)} />
        <AdminInput label="Frivillighedsbidrag (kr)" type="number" placeholder="1500" icon={<DollarSign className="w-4 h-4" />} value={contribution} onChange={(e) => setContrib(e.target.value)} />
        <div>
          <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-1.5">Sæsonperiode</label>
          <div className="grid grid-cols-2 gap-2">
            <AdminInput type="date" value={seasonStart} onChange={(e) => setStart(e.target.value)} />
            <AdminInput type="date" value={seasonEnd} onChange={(e) => setEnd(e.target.value)} />
          </div>
        </div>
        <button onClick={save} className="w-full py-2.5 rounded-xl text-white font-bold text-[13px] flex items-center justify-center gap-2" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}><Save className="w-4 h-4" />Gem indstillinger</button>
      </div>

      <div className="bg-white rounded-2xl p-4 border border-stone-100 shadow-sm space-y-3">
        <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500">Klubdata</div>
        <button className="w-full flex items-center justify-between px-4 py-3 bg-stone-50 hover:bg-stone-100 rounded-xl text-left"><span className="text-[13px] font-semibold">Eksportér alle klubdata (CSV)</span><Download className="w-4 h-4 text-stone-500" /></button>
        <button className="w-full flex items-center justify-between px-4 py-3 bg-pink-50 hover:bg-pink-100 rounded-xl text-left"><span className="text-[13px] font-semibold text-pink-700">Nulstil ny sæson (slet alle point)</span><AlertTriangle className="w-4 h-4 text-pink-500" /></button>
      </div>
    </div>
  );
};

// ---- AUDIT LOG (kun Super Admin) ----
const AdminAuditLog = () => {
  const [logs, setLogs] = useState([]);
  useEffect(() => {
    supabase.from("audit_log").select("*").order("created_at", { ascending: false }).then(({ data }) => {
      if (data) setLogs(data);
    });
  }, []);
  return (
  <div className="space-y-3">
    <div className="bg-violet-50 border border-violet-200 rounded-xl p-3 flex gap-2.5">
      <Info className="w-4 h-4 text-violet-600 shrink-0 mt-0.5" />
      <p className="text-[11px] text-violet-900">Alle ændringer foretaget af Admins logges her. Loggen kan ikke slettes og opbevares i 5 år.</p>
    </div>
    {logs.length === 0 ? (
      <div className="text-center py-8 text-stone-400 text-sm">Ingen aktivitet endnu</div>
    ) : (
    <div className="bg-white rounded-2xl border border-stone-100 divide-y divide-stone-100 shadow-sm overflow-hidden">
      {logs.map((log) => (
        <div key={log.id} className="flex gap-3 items-start px-4 py-3">
          <div className="w-8 h-8 rounded-lg flex items-center justify-center shrink-0" style={{ background: theme.greenPale, color: theme.greenDark }}>
            {log.type === "role_change" && <ShieldCheck className="w-4 h-4" />}
            {log.type === "task"        && <ListChecks className="w-4 h-4" />}
            {log.type === "member"      && <UserPlus className="w-4 h-4" />}
            {log.type === "settings"    && <DollarSign className="w-4 h-4" />}
            {!["role_change","task","member","settings"].includes(log.type) && <Activity className="w-4 h-4" />}
          </div>
          <div><div className="text-[13px] text-stone-900">{log.action}</div><div className="text-[11px] text-stone-500 mt-0.5">{log.actor_name} · {new Date(log.created_at).toLocaleDateString("da-DK")}</div></div>
        </div>
      ))}
    </div>
    )}
  </div>
  );
};

const ProfileAvatar = ({ currentUser, setCurrentUser, setToast }) => {
  const [uploading, setUploading] = useState(false);

  const handleUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (file.size > 5 * 1024 * 1024) {
      setToast("Billedet er for stort (max 5 MB)");
      setTimeout(() => setToast(null), 2500);
      return;
    }
    setUploading(true);
    const ext = file.name.split(".").pop();
    const path = `${currentUser.id}/${Date.now()}.${ext}`;
    const { error: upErr } = await supabase.storage.from("avatars").upload(path, file, { cacheControl: "3600", upsert: true });
    if (upErr) {
      setToast("Upload fejlede: " + upErr.message);
      setTimeout(() => setToast(null), 3000);
      setUploading(false);
      return;
    }
    const { data: { publicUrl } } = supabase.storage.from("avatars").getPublicUrl(path);
    await supabase.from("profiles").update({ avatar_url: publicUrl }).eq("id", currentUser.id);
    setCurrentUser((u) => ({ ...u, avatarUrl: publicUrl }));
    setToast("✨ Profilbillede opdateret");
    setTimeout(() => setToast(null), 2000);
    setUploading(false);
  };

  return (
    <div className="flex flex-col items-center">
      <label className="relative cursor-pointer group">
        {currentUser?.avatarUrl ? (
          <img src={currentUser.avatarUrl} alt={currentUser.name} className="w-24 h-24 rounded-full object-cover border-4 border-white/30 shadow-xl" />
        ) : (
          <div className="w-24 h-24 rounded-full flex items-center justify-center font-black text-3xl text-white border-4 border-white/30 shadow-xl" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
            {currentUser?.initials}
          </div>
        )}
        <div className="absolute bottom-0 right-0 w-8 h-8 rounded-full bg-white text-stone-700 flex items-center justify-center shadow-lg border-2 border-white">
          {uploading ? <div className="w-4 h-4 border-2 border-stone-300 border-t-stone-700 rounded-full animate-spin" /> : <Camera className="w-4 h-4" />}
        </div>
        <input type="file" accept="image/*" className="hidden" onChange={handleUpload} disabled={uploading} />
      </label>
      <div className="text-xl font-bold mt-3">{currentUser?.name}</div>
      <div className="text-[11px] text-emerald-200 mt-1">{currentUser?.team}</div>
    </div>
  );
};

const RequestAdminButton = ({ currentUser, setToast }) => {
  const [requested, setRequested] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    supabase.from("profiles").select("admin_requested").eq("id", currentUser.id).single().then(({ data }) => {
      if (data?.admin_requested) setRequested(true);
    });
  }, [currentUser.id]);

  const handleRequest = async () => {
    setLoading(true);
    const { error } = await supabase.from("profiles").update({
      admin_requested: true,
      admin_requested_at: new Date().toISOString(),
    }).eq("id", currentUser.id);
    setLoading(false);
    if (!error) {
      setRequested(true);
      setToast("📨 Din anmodning er sendt til Super Admin");
      setTimeout(() => setToast(null), 3000);
    }
  };

  if (requested) {
    return (
      <div className="w-full bg-violet-50 border border-violet-200 rounded-xl py-3 px-4 text-[12px] text-violet-800 flex items-center justify-center gap-2">
        <Clock className="w-4 h-4" />
        Din anmodning om admin-rettigheder afventer godkendelse
      </div>
    );
  }

  return (
    <button onClick={handleRequest} disabled={loading} className="w-full bg-white border border-stone-200 rounded-xl py-3 text-[13px] font-semibold text-stone-700 flex items-center justify-center gap-2 hover:bg-stone-50 disabled:opacity-60">
      <ShieldCheck className="w-4 h-4" />
      {loading ? "Sender..." : "Anmod om admin-rettigheder"}
    </button>
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
  const [authLoading, setAuthLoading] = useState(true);
  const [currentUser, setCurrentUser] = useState(null);
  const [tab, setTab] = useState("tasks");
  const [claimedIds, setClaimedIds] = useState(new Set());
  const [toast, setToast] = useState(null);
  const [welcomeToast, setWelcomeToast] = useState(null);
  const [showCalendar, setShowCalendar] = useState(false);
  const [showSwaps, setShowSwaps] = useState(false);
  const [showAdmin, setShowAdmin] = useState(false);
  const [selectedTask, setSelectedTask] = useState(null);
  const [tasks, setTasks] = useState([]);

  const claimedTasks = useMemo(
    () => tasks.filter((t) => claimedIds.has(t.id)),
    [claimedIds, tasks]
  );

  // Load profile from Supabase and update currentUser
  const loadProfile = async (userId) => {
    const { data } = await supabase.from("profiles").select("*").eq("id", userId).single();
    if (data) {
      setCurrentUser({
        id: data.id,
        name: data.name,
        email: data.email,
        phone: data.phone || "",
        team: data.team || "",
        initials: data.initials || data.name.split(" ").map((n) => n[0]).slice(0, 2).join("").toUpperCase(),
        role: data.role || "user",
        pointsEarned: data.points || 0,
        tasksCompleted: data.tasks_done || 0,
        avatarUrl: data.avatar_url || null,
      });
    }
    setIsAuthenticated(true);
    setAuthLoading(false);
  };

  // Listen for Supabase auth state changes (handles page reload, token refresh)
  useEffect(() => {
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (session?.user) {
        await loadProfile(session.user.id);
      } else {
        setIsAuthenticated(false);
        setAuthLoading(false);
      }
    });
    return () => subscription.unsubscribe();
  }, []);

  // Load tasks from Supabase (with steps)
  useEffect(() => {
    const loadTasks = async () => {
      const { data: taskRows } = await supabase.from("tasks").select("*, task_steps(step_order, text)").order("created_at", { ascending: true });
      if (taskRows && taskRows.length > 0) {
        const mapped = taskRows.map((t) => ({
          id: t.id,
          title: t.title,
          category: t.category,
          icon: t.icon || "setup",
          date: t.date,
          dateFull: t.date_full || t.date,
          time: t.time,
          location: t.location,
          points: t.points,
          difficulty: t.difficulty,
          urgent: t.urgent,
          spotsLeft: t.spots_left,
          spotsTotal: t.spots_total,
          description: (t.task_steps || []).sort((a, b) => a.step_order - b.step_order).map((s) => s.text),
        }));
        setTasks(mapped);
      }
    };
    loadTasks();
  }, []);

  const handleAuth = (authData) => {
    // Supabase auth is done — onAuthStateChange will set the user profile.
    // Just show the welcome toast here.
    const first = authData.name ? authData.name.split(" ")[0] : "";
    setWelcomeToast(authData.isNew ? `Velkommen til RVK, ${first}! 🎉` : `Velkommen tilbage, ${first}!`);
    setTimeout(() => setWelcomeToast(null), 3000);
    setTab("tasks");
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
    setIsAuthenticated(false);
    setTab("tasks");
    setClaimedIds(new Set());
    setShowCalendar(false);
    setShowSwaps(false);
    setShowAdmin(false);
    setSelectedTask(null);
  };

  const handleClaim = async (taskId) => {
    const next = new Set(claimedIds);
    next.add(taskId);
    setClaimedIds(next);
    const task = tasks.find((t) => t.id === taskId);
    setToast(`🎉 Tjansen er din! +${task?.points ?? 0} point`);
    setTimeout(() => setToast(null), 2500);
    setTimeout(() => setTab("dashboard"), 900);
    // Persist to Supabase (trigger auto-updates points + spots_left)
    if (currentUser?.id) {
      await supabase.from("task_claims").insert({ task_id: taskId, user_id: currentUser.id });
      // Refresh spots on the claimed task
      const { data: updated } = await supabase.from("tasks").select("spots_left").eq("id", taskId).single();
      if (updated) {
        setTasks((prev) => prev.map((t) => t.id === taskId ? { ...t, spotsLeft: updated.spots_left } : t));
      }
    }
  };

  if (authLoading) {
    return (
      <div className="min-h-screen bg-stone-50 flex items-center justify-center font-sans">
        <div className="flex flex-col items-center gap-3">
          <div className="w-10 h-10 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin" />
          <div className="text-sm text-stone-500 font-medium">Indlæser...</div>
        </div>
      </div>
    );
  }

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

        {showAdmin ? (
          <AdminDashboard currentUserRole={currentUser.role} onBack={() => setShowAdmin(false)} tasks={tasks} setTasks={setTasks} />
        ) : showCalendar ? (
          <CalendarScreen tasks={tasks} claimedTasks={claimedTasks} onTaskClick={(task) => { setSelectedTask(task); setShowCalendar(false); }} onBack={() => setShowCalendar(false)} />
        ) : showSwaps ? (
          <SwapScreen onBack={() => setShowSwaps(false)} claimedTasks={claimedTasks} />
        ) : selectedTask ? (
          <div className="pb-24">
            <div className="px-5 pt-12 pb-8 text-white relative overflow-hidden" style={{ background: `linear-gradient(135deg, ${theme.greenDark} 0%, ${theme.greenMid} 100%)` }}>
              <button onClick={() => setSelectedTask(null)} className="inline-flex items-center gap-1.5 text-white/90 text-sm mb-5"><ArrowLeft className="w-4 h-4" />Tilbage til opgaver</button>
              <div className="flex items-center gap-2 mb-2"><span className="text-[11px] uppercase tracking-widest font-bold text-emerald-200">{selectedTask.category}</span>{selectedTask.urgent && <span className="inline-flex items-center gap-1 bg-pink-500/90 text-white text-[10px] font-bold px-2 py-0.5 rounded-full"><Flame className="w-3 h-3" />HASTER</span>}</div>
              <h1 className="text-2xl font-bold mb-4">{selectedTask.title}</h1>
              <div className="grid grid-cols-2 gap-3">
                <div className="bg-white/10 rounded-xl p-3 border border-white/10"><div className="text-[10px] uppercase tracking-wider text-emerald-200 font-semibold mb-1">Dato</div><div className="text-sm font-semibold">{selectedTask.dateFull}</div></div>
                <div className="bg-white/10 rounded-xl p-3 border border-white/10"><div className="text-[10px] uppercase tracking-wider text-emerald-200 font-semibold mb-1">Tidsrum</div><div className="text-sm font-semibold">{selectedTask.time}</div></div>
                <div className="bg-white/10 rounded-xl p-3 border border-white/10 col-span-2"><div className="text-[10px] uppercase tracking-wider text-emerald-200 font-semibold mb-1">Lokation</div><div className="text-sm font-semibold flex items-center gap-1.5"><MapPin className="w-4 h-4" />{selectedTask.location}</div></div>
              </div>
            </div>
            <div className="px-5 -mt-5 relative z-10 mb-4">
              <div className="rounded-2xl p-4 flex items-center justify-between text-white shadow-lg" style={{ background: `linear-gradient(135deg, ${theme.purple} 0%, ${theme.pink} 100%)` }}>
                <div><div className="text-[11px] uppercase tracking-widest font-bold text-white/80">Du optjener</div><div className="text-2xl font-black flex items-center gap-1"><Zap className="w-6 h-6" fill="white" />{selectedTask.points} point</div></div>
                <DifficultyPill level={selectedTask.difficulty} />
              </div>
            </div>
            <div className="px-5">
              <h2 className="text-[11px] uppercase tracking-widest font-bold text-stone-500 mb-3">Sådan løser du opgaven</h2>
              <ol className="space-y-3">{selectedTask.description.map((step, i) => <li key={i} className="flex gap-3"><div className="shrink-0 w-7 h-7 rounded-full flex items-center justify-center text-white text-xs font-bold" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>{i + 1}</div><p className="text-[14px] text-stone-700 leading-relaxed pt-0.5">{step}</p></li>)}</ol>
            </div>
            <div className="fixed bottom-16 left-0 right-0 p-4 bg-gradient-to-t from-white via-white to-white/80 border-t border-stone-100 max-w-md mx-auto">
              {claimedIds.has(selectedTask.id)
                ? <div className="w-full py-3.5 rounded-xl font-bold text-white flex items-center justify-center gap-2" style={{ background: `linear-gradient(135deg, ${theme.greenMid}, ${theme.greenDark})` }}><Check className="w-5 h-5" />Du har taget tjansen!</div>
                : <button onClick={() => handleClaim(selectedTask.id)} className="w-full py-3.5 rounded-xl font-bold text-white shadow-lg flex items-center justify-center gap-2" style={{ background: `linear-gradient(135deg, ${theme.purple} 0%, ${theme.pink} 100%)` }}><Zap className="w-5 h-5" fill="white" />Tag tjansen ( +{selectedTask.points} point )</button>
              }
            </div>
          </div>
        ) : (
          <>
            {tab === "tasks" && <TasksScreen tasks={tasks} onTaskClick={setSelectedTask} claimedIds={claimedIds} onOpenNotifications={() => {}} onOpenSwaps={() => setShowSwaps(true)} onOpenCalendar={() => setShowCalendar(true)} unreadCount={0} />}
            {tab === "dashboard" && <Dashboard claimedTasks={claimedTasks} currentUser={currentUser} />}
            {tab === "scoreboard" && <ScoreboardScreen currentUserId={currentUser?.id} />}
            {tab === "profile" && (
              <div className="pb-24">
                <div className="px-5 pt-12 pb-8 text-white relative overflow-hidden" style={{ background: `linear-gradient(135deg, ${theme.greenDark} 0%, ${theme.greenMid} 100%)` }}>
                  <h1 className="text-2xl font-bold mb-6">Min profil</h1>
                  <ProfileAvatar currentUser={currentUser} setCurrentUser={setCurrentUser} setToast={setToast} />
                </div>
                <div className="px-5 mt-5 grid grid-cols-3 gap-2.5">
                  <div className="bg-white rounded-xl p-3 border border-stone-100 shadow-sm text-center"><div className="text-xl font-black text-stone-900">{currentUser?.pointsEarned ?? 0}</div><div className="text-[10px] uppercase tracking-wider text-stone-500 font-bold">Point</div></div>
                  <div className="bg-white rounded-xl p-3 border border-stone-100 shadow-sm text-center"><div className="text-xl font-black text-stone-900">{currentUser?.tasksCompleted ?? 0}</div><div className="text-[10px] uppercase tracking-wider text-stone-500 font-bold">Opgaver</div></div>
                  <div className="bg-white rounded-xl p-3 border border-stone-100 shadow-sm text-center"><div className="text-xl font-black text-stone-900">{currentUser?.team || "–"}</div><div className="text-[10px] uppercase tracking-wider text-stone-500 font-bold">Hold</div></div>
                </div>
                <div className="px-5 mt-6 space-y-2">
                  {currentUser?.email && <button className="w-full bg-white border border-stone-200 rounded-xl py-3 text-[13px] font-semibold text-stone-700 flex items-center justify-center gap-2"><Mail className="w-4 h-4" />{currentUser.email}</button>}
                  {currentUser?.phone && <button className="w-full bg-white border border-stone-200 rounded-xl py-3 text-[13px] font-semibold text-stone-700 flex items-center justify-center gap-2"><Phone className="w-4 h-4" />{currentUser.phone}</button>}
                  {(currentUser?.role === "admin" || currentUser?.role === "super_admin") && (
                    <button onClick={() => setShowAdmin(true)} className="w-full rounded-2xl p-4 text-white text-left relative overflow-hidden active:scale-[0.99] transition-transform shadow-lg" style={{ background: `linear-gradient(135deg, ${theme.greenDark} 0%, ${theme.purple} 100%)` }}>
                      <div className="flex items-center gap-3">
                        <div className="w-11 h-11 rounded-xl flex items-center justify-center shrink-0" style={{ background: `linear-gradient(135deg, ${theme.pink}, ${theme.purple})` }}>{currentUser.role === "super_admin" ? <Crown className="w-5 h-5" fill="white" /> : <ShieldCheck className="w-5 h-5" />}</div>
                        <div className="flex-1"><div className="font-bold text-[15px]">Åbn admin-panel</div><div className="text-[11px] text-white/80 mt-0.5">{currentUser.role === "super_admin" ? "Fuld kontrol over klubben" : "Administrér opgaver og medlemmer"}</div></div>
                        <ChevronRight className="w-5 h-5 opacity-70" />
                      </div>
                    </button>
                  )}
                  {currentUser?.role === "user" && <RequestAdminButton currentUser={currentUser} setToast={setToast} />}
                  <button onClick={handleLogout} className="w-full bg-stone-100 border border-stone-200 rounded-xl py-3 text-[13px] font-semibold text-stone-700 flex items-center justify-center gap-2 hover:bg-stone-50"><LogOut className="w-4 h-4" />Log ud</button>
                </div>
              </div>
            )}
          </>
        )}

        {toast && <div className="fixed bottom-24 left-1/2 -translate-x-1/2 px-4 py-2.5 rounded-xl text-white text-sm font-semibold shadow-lg z-50" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>{toast}</div>}

        {!showCalendar && !showSwaps && !showAdmin && !selectedTask && <BottomNav active={tab} onChange={setTab} />}
      </div>
    </div>
  );
}
