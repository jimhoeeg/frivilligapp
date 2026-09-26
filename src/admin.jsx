// ============ ADMIN-PANELET ============
//
// Hele admin-panelet ligger her i sin egen fil, fordi App.jsx henter den
// FØRST når nogen åbner panelet (React.lazy). Langt de fleste medlemmer
// åbner det aldrig, og før hentede de det alligevel — omkring 39 kB pakket,
// hver gang appen blev åbnet på en telefon i en hal.
//
// Det, både medlemmerne og admins bruger, ligger i shared.jsx.
import {
  useState, useEffect, useMemo, useCallback
} from "react";
import { supabase } from "./supabaseClient";
import {
  ListChecks, MapPin, Clock, Zap, ChevronRight, Check, X, Search, Flame,
  ArrowLeft, Info, Crown, Users, TrendingUp, Mail, Phone, Trash2,
  ChevronDown, Lock, Download, Save, CheckCircle2, Plus, MoreVertical,
  ShieldCheck, UserPlus, DollarSign, AlertTriangle, Activity, Pencil, Copy,
  UserCheck, UserX, ThumbsUp, BellRing, ChevronLeft, MessageSquare, FileText
} from "lucide-react";
import {
  logAction, theme, ScrollRow, IKON_KATALOG, ikonNavn, CategoryIcon,
  KATEGORI_IKON, foreslaaIkon, RoleBadge, parseTaskDate, CLAIM_STATE,
  ClaimStatusPill, MemberTasksModal
} from "./shared.jsx";

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
const AdminDashboard = ({ currentUser, onBack, tasks, setTasks, onPointsChanged }) => {
  const [section, setSection] = useState("overview");
  const [pendingCount, setPendingCount] = useState(0);
  const [approvalCount, setApprovalCount] = useState(0);
  const [openSignups, setOpenSignups] = useState(null);
  const currentUserRole = currentUser?.role;
  const isSuperAdmin = currentUserRole === "super_admin";

  // Tællere på fanerne, så ingen glemmer at gøre tjanserne op — eller at
  // godkende et nyt medlem. Godkendelses-tallet stod hårdkodet til 0, så et
  // medlem kunne melde sig og vente i dagevis uden at nogen så det.
  const refreshPending = async () => {
    const [bekraeft, medlemmer] = await Promise.all([
      supabase.rpc("admin_pending_confirmations"),
      supabase.rpc("admin_list_members"),
    ]);
    setPendingCount((bekraeft.data || []).reduce((n, r) => n + r.pending, 0));
    setApprovalCount((medlemmer.data || []).filter((m) => !m.approved).length);
  };

  // Dataindlæsning ved visning. Reglen advarer mod setState i en effect,
  // men her sker det først efter et svar fra serveren — det er netop det,
  // effects er til: at synkronisere med noget uden for React.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => { refreshPending(); }, [section]);

  const sections = [
    { id: "overview",  label: "Oversigt",      icon: Activity,    superOnly: false },
    { id: "confirm",   label: "Bekræft",       icon: CheckCircle2, superOnly: false, badge: pendingCount },
    { id: "approvals", label: "Godkendelser",   icon: UserCheck,   superOnly: false, badge: approvalCount },
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
          <ScrollRow className="flex gap-2 overflow-x-auto -mx-5 px-5 pb-1 scrollbar-hide">
            {sections.map((s) => {
              const Icon = s.icon;
              const disabled = s.superOnly && !isSuperAdmin;
              const active = section === s.id;
              return (
                <button key={s.id} disabled={disabled} data-active={active} onClick={() => !disabled && setSection(s.id)}
                  className={`shrink-0 relative inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-[12px] font-bold transition-all ${active ? "bg-white text-emerald-900 shadow-md" : disabled ? "bg-white/5 text-white/30 border border-white/10 cursor-not-allowed" : "bg-white/10 text-white border border-white/20 hover:bg-white/20"}`}
                >
                  <Icon className="w-3.5 h-3.5" />
                  {s.label}
                  {s.badge > 0 && <span className="inline-flex items-center justify-center min-w-[18px] h-[18px] px-1 rounded-full text-[10px] font-black text-white" style={{ background: `linear-gradient(135deg, ${theme.pink}, ${theme.purple})` }}>{s.badge}</span>}
                  {disabled && <Lock className="w-3 h-3 opacity-60" />}
                </button>
              );
            })}
          </ScrollRow>
        </div>
      </div>

      <div className="px-5 mt-5">
        {section === "overview"  && <AdminOverview tasks={tasks} currentUser={currentUser} />}
        {section === "confirm"   && <AdminConfirmations currentUser={currentUser} onOpenTask={(id) => { setOpenSignups(id); setSection("tasks"); }} />}
        {section === "approvals" && <AdminApprovals onChanged={refreshPending} />}
        {section === "tasks"     && <AdminTasks tasks={tasks} setTasks={setTasks} currentUser={currentUser} openSignups={openSignups} onSignupsOpened={() => setOpenSignups(null)} onConfirmed={() => { refreshPending(); onPointsChanged?.(); }} />}
        {section === "members"   && <AdminMembers currentUserRole={currentUserRole} currentUser={currentUser} />}
        {section === "teams"     && isSuperAdmin && <AdminTeams />}
        {section === "roles"     && isSuperAdmin && <AdminRoles currentUser={currentUser} />}
        {section === "settings"  && isSuperAdmin && <AdminSettings currentUser={currentUser} />}
        {section === "audit"     && isSuperAdmin && <AdminAuditLog />}
      </div>
    </div>
  );
};

// ---- OVERSIGT ----
const AdminOverview = ({ tasks, currentUser }) => {
  const [stats, setStats] = useState({ total: 0, goalReached: 0, behind: 0, avg: 0, hjaelpere: 0 });
  const [goal, setGoal] = useState(100);
  const [contribution, setContribution] = useState(0);
  const [exporting, setExporting] = useState(false);

  useEffect(() => {
    // Målet og bidraget står i indstillingerne. Tallene var hårdkodet til 100
    // og 50 her, så ændrede en super admin halvsmålet, sagde denne skærm
    // stadig "≥100 pt" — og bidragslisten ville have udpeget de forkerte.
    //
    // Og det er BIDRAGSTALLET, der gøres op — ikke ranglistens. Læses points
    // i stedet, står en mor, hvis far har taget alle tjanserne, som bagud og
    // får en regning, klubben aldrig mente at sende. Hjælperne selv er ikke
    // med i opgørelsen: de er ikke medlemmer og betaler ikke bidrag.
    Promise.all([
      supabase.rpc("admin_list_members"),
      supabase.from("settings").select("key,value"),
    ]).then(([{ data }, { data: cfg }]) => {
      const map = Object.fromEntries((cfg || []).map((r) => [r.key, r.value]));
      const g = parseInt(map.point_goal) || 100;
      setGoal(g);
      setContribution(parseInt(map.contribution_kr) || 0);
      if (data && data.length > 0) {
        const hjaelpere = data.filter((m) => m.er_hjaelper).length;
        const rows  = data.filter((m) => !m.er_hjaelper);
        const total = rows.length;
        if (total === 0) { setStats({ total: 0, goalReached: 0, behind: 0, avg: 0, hjaelpere }); return; }
        const pt = (m) => m.bidrag ?? m.points ?? 0;
        const goalReached = rows.filter((m) => pt(m) >= g).length;
        const behind = rows.filter((m) => pt(m) < g / 2).length;
        const avg = Math.round(rows.reduce((s, m) => s + pt(m), 0) / total);
        setStats({ total, goalReached, behind, avg, hjaelpere });
      }
    });
  }, []);

  const exportContributions = async () => {
    setExporting(true);
    try {
      const { data, error } = await supabase.rpc("admin_list_members");
      if (error) throw error;
      // Hjælpere står ikke på listen. De er ikke medlemmer, de skal ikke
      // betale — og deres point er allerede talt med hos den, de hjalp.
      const rows = (data || [])
        .filter((m) => !m.er_hjaelper)
        .map((m) => ({ ...m, pt: m.bidrag ?? m.points ?? 0 }))
        .sort((a, b) => b.pt - a.pt || a.name.localeCompare(b.name, "da"))
        .map((m) => [
          m.name, m.team, m.pt, m.fra_hjaelpere ?? 0, m.hjaelper_for || "", goal,
          m.pt >= goal ? "Nået målet" : m.pt >= goal / 2 ? "På vej" : "Bagud",
          m.pt >= goal ? 0 : contribution,
        ]);
      if (!rows.length) { setExporting(false); return; }
      downloadCSV(
        `rvk-bidragsliste-${today()}.csv`,
        toCSV(["Navn", "Hold", "Bidragspoint", "Heraf fra hjaelpere", "Hjaelpere", "Maal", "Status", "Bidrag (kr)"], rows)
      );
      const skyldige = rows.filter((r) => r[7] > 0).length;
      await logAction("settings",
        `Eksporterede bidragsliste (${rows.length} medlemmer, ${skyldige} under målet)`, currentUser);
    } finally {
      setExporting(false);
    }
  };

  const openSpots = tasks.reduce((s, t) => s + t.spotsLeft, 0);

  return (
    <div className="space-y-5">

      {/* Stats grid */}
      <div className="grid grid-cols-2 gap-3">
        {[
          { label: "Aktive medlemmer", value: stats.total,            icon: <Users className="w-4 h-4" />,        accent: "#ECFDF5", color: theme.greenDark },
          { label: "Nået halvsmål",     value: `${stats.goalReached}/${stats.total}`, icon: <CheckCircle2 className="w-4 h-4" />, accent: "#FCE7F3", color: "#BE185D" },
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
          { label: `🎉 Nået halvsmål (≥${goal} pt)`,                      count: stats.goalReached,                              color: theme.greenMid },
          { label: `🟣 På vej (${goal / 2}–${goal - 1} pt)`,               count: stats.total - stats.goalReached - stats.behind,  color: theme.purple },
          { label: `⚠️ Bagud (under ${goal / 2} pt)`,                      count: stats.behind,                                   color: theme.pink },
        ].map((row, i) => {
          const pct = stats.total > 0 ? Math.round((row.count / stats.total) * 100) : 0;
          return (
            <div key={i} className="mb-2.5">
              <div className="flex justify-between text-[12px] mb-1"><span className="text-stone-700">{row.label}</span><span className="font-bold">{row.count}</span></div>
              <div className="h-2 bg-stone-100 rounded-full overflow-hidden"><div className="h-full rounded-full" style={{ width: `${pct}%`, background: row.color }} /></div>
            </div>
          );
        })}
        <button
          onClick={exportContributions}
          disabled={exporting || stats.total === 0}
          className="w-full mt-3 py-2.5 rounded-xl text-[12px] font-bold text-white flex items-center justify-center gap-1.5 disabled:opacity-50"
          style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}
        >
          <Download className="w-3.5 h-3.5" />
          {exporting ? "Henter..." : "Eksportér bidragsliste"}
        </button>
        {contribution > 0 && (
          <p className="text-[11px] text-stone-400 mt-2 leading-snug">
            Listen viser hvert medlems bidragspoint mod målet på {goal} pt, og hvem der efter den
            opgørelse skal betale {contribution} kr. Point fra hjælpere er lagt til hos medlemmet.
          </p>
        )}
        {stats.hjaelpere > 0 && (
          <p className="text-[11px] text-stone-400 mt-1.5 leading-snug">
            {stats.hjaelpere} hjælper{stats.hjaelpere > 1 ? "e" : ""} er ikke med i opgørelsen —
            de er ikke medlemmer og betaler ikke bidrag. Deres point er talt med hos dem, de hjælper.
          </p>
        )}
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
const AdminApprovals = ({ onChanged }) => {
  const [pending, setPending] = useState([]);
  const [done, setDone]       = useState([]);
  const [expanded, setExpanded] = useState(null);
  const [rejecting, setRejecting] = useState(null);
  const [reason, setReason]    = useState("");
  const [approvalError, setApprovalError] = useState(null);
  // Hjælperkoblingen laves i SAMME handling som godkendelsen. Ellers bliver
  // det et andet sted, en anden dag — og indtil da tæller forælderens tjanser
  // for forælderen selv, hvilket er præcis det, ingen ville have.
  const [medlemmer, setMedlemmer] = useState([]);
  const [valgte, setValgte]       = useState({});

  const load = async () => {
    // Kontaktoplysninger hentes gennem admin_list_members(), fordi selve
    // tabellen ikke længere udleverer e-mail og telefon til klienten.
    const { data, error } = await supabase.rpc("admin_list_members");
    if (error) { setApprovalError(`Kunne ikke hente medlemmer: ${error.message}`); return; }
    setPending((data || []).filter((m) => !m.approved).map((m) => ({
      id: m.id, name: m.name, initials: m.initials || "?",
      email: m.email || "–", phone: m.phone || "–", team: m.team || "–",
      appliedOn: new Date(m.created_at).toLocaleDateString("da-DK"), motivation: "", referredBy: null,
      helperRequest: m.helper_request || "",
    })));
    // Man kan kun hjælpe et godkendt medlem, der ikke selv er hjælper —
    // samme regel som databasen håndhæver. Listen viser kun det mulige.
    setMedlemmer((data || [])
      .filter((m) => m.approved && !m.er_hjaelper)
      .map((m) => ({ id: m.id, name: m.name, team: m.team || "" })));
  };

  const vaelg = (ansoegerId, medlemId) => {
    setValgte((v) => {
      const nu = v[ansoegerId] || [];
      return { ...v, [ansoegerId]: nu.includes(medlemId)
        ? nu.filter((x) => x !== medlemId)
        : [...nu, medlemId] };
    });
  };

  // Dataindlæsning ved visning. Reglen advarer mod setState i en effect,
  // men her sker det først efter et svar fra serveren — det er netop det,
  // effects er til: at synkronisere med noget uden for React.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => { load(); }, []);

  const approve = async (a) => {
    const { error } = await supabase.rpc("admin_set_approval", { p_user: a.id, p_approved: true });
    if (error) { setApprovalError(`Kunne ikke godkende: ${error.message}`); return; }

    // Godkendelsen er i hus. Koblingerne kommer bagefter — går én af dem galt,
    // skal det siges tydeligt, men medlemmet bliver ikke sat tilbage: det er
    // lettere at koble om end at godkende forfra.
    const kobl = valgte[a.id] || [];
    const fejl = [];
    for (const medlemId of kobl) {
      const { error: e } = await supabase.rpc("admin_set_helper", {
        p_helper: a.id, p_member: medlemId, p_on: true,
      });
      if (e) fejl.push(`${medlemmer.find((m) => m.id === medlemId)?.name || "medlem"}: ${e.message}`);
    }

    setPending((p) => p.filter((x) => x.id !== a.id));
    setDone((d) => [{ ...a, action: "approved", koblet: kobl.length - fejl.length }, ...d]);
    setExpanded(null);
    setValgte((v) => { const n = { ...v }; delete n[a.id]; return n; });
    setApprovalError(fejl.length ? `Godkendt, men koblingen fejlede — ${fejl.join(" · ")}` : null);
    onChanged?.();
  };

  const reject  = async (a) => {
    // Afvisning sletter både profilen og selve login'et, så personen ikke
    // efterlades med en konto uden profil.
    const { data, error } = await supabase.functions.invoke("delete-member", {
      body: { user_id: a.id, reason: reason || "Afvist ved godkendelse" },
    });
    if (error || data?.error) {
      setApprovalError(
        `Kunne ikke afvise: ${data?.error || error.message}. ` +
        "Er delete-member-funktionen rullet ud? (supabase functions deploy delete-member)"
      );
      return;
    }
    setPending((p) => p.filter((x) => x.id !== a.id));
    setDone((d) => [{ ...a, action: "rejected", reason }, ...d]);
    setRejecting(null); setReason("");
    setApprovalError(null);
    onChanged?.();
  };

  return (
    <div className="space-y-4">
      <div className="bg-violet-50 border border-violet-200 rounded-xl p-3 flex gap-2.5">
        <Info className="w-4 h-4 text-violet-600 shrink-0 mt-0.5" />
        <p className="text-[11px] text-violet-900 leading-relaxed">Nye medlemmer kan logge ind, men kan først tage tjanser når du godkender dem. Godkendte medlemmer får en besked i appen med det samme. Afviser du, slettes profilen og login'et helt.</p>
      </div>

      {approvalError && (
        <div className="bg-red-50 border border-red-200 rounded-xl p-3 flex items-start gap-2">
          <AlertTriangle className="w-4 h-4 text-red-600 shrink-0 mt-0.5" />
          <p className="text-[11px] text-red-900">{approvalError}</p>
        </div>
      )}

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

                {/* ----------------------------------------------------------
                    HJÆLPER? Står FØR godkend-knappen, fordi det er en del af
                    den beslutning — ikke noget, man kan huske at gøre senere.
                    ---------------------------------------------------------- */}
                <div className={`rounded-xl p-3 border ${a.helperRequest ? "bg-amber-50 border-amber-200" : "bg-white border-stone-200"}`}>
                  {a.helperRequest ? (
                    <div className="text-[12px] text-amber-900 leading-relaxed mb-2">
                      <strong>Har selv skrevet, at det er en hjælper.</strong><br />
                      Hjælper for: <span className="font-semibold">«{a.helperRequest}»</span>
                    </div>
                  ) : (
                    <div className="text-[12px] text-stone-600 leading-relaxed mb-2">
                      <strong className="text-stone-800">Er det en hjælper?</strong> Vælg medlemmet, hvis
                      personen tager tjanser for et medlem og ikke spiller selv.
                    </div>
                  )}

                  {medlemmer.length === 0 ? (
                    <p className="text-[11px] text-stone-500">Der er endnu ingen godkendte medlemmer at koble til.</p>
                  ) : (
                    <div className="flex flex-wrap gap-1.5">
                      {medlemmer.map((m) => {
                        const valgt = (valgte[a.id] || []).includes(m.id);
                        return (
                          <button key={m.id} type="button" onClick={() => vaelg(a.id, m.id)}
                            className={`px-2.5 py-1.5 rounded-lg text-[11px] font-bold border transition-all ${valgt ? "bg-emerald-600 text-white border-emerald-600" : "bg-white text-stone-600 border-stone-200"}`}>
                            {m.name}
                          </button>
                        );
                      })}
                    </div>
                  )}

                  {(valgte[a.id] || []).length > 0 && (
                    <p className="text-[11px] text-emerald-800 mt-2 leading-relaxed">
                      Bliver hjælper for {(valgte[a.id] || []).length} medlem
                      {(valgte[a.id] || []).length > 1 ? "mer" : ""}. Personen kommer med på ranglisten
                      med sine egne point — men pointene tæller mod frivilligbidraget hos medlemmet.
                    </p>
                  )}
                </div>

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
              <div className="flex-1 min-w-0"><div className="text-[13px] font-semibold text-stone-900">{p.name}</div><div className="text-[11px] text-stone-500">{p.action === "approved" ? "Godkendt" : "Afvist"}{p.koblet > 0 ? ` · koblet som hjælper` : ""} · Lige nu</div></div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

// ---- OPGAVETILMELDTE ----
const AdminTaskSignups = ({ task, onClose, setTasks, currentUser, onConfirmed }) => {
  const [signups,      setSignups]      = useState([]);
  const [allMembers,   setAllMembers]   = useState([]);
  const [loading,      setLoading]      = useState(true);
  const [assignSearch, setAssignSearch] = useState("");
  const [confirmRemove, setConfirmRemove] = useState(null);
  const [saving,       setSaving]       = useState(false);
  const [error,        setError]        = useState(null);
  const [spotsLeft,    setSpotsLeft]    = useState(task.spotsLeft ?? 0);

  useEffect(() => {
    (async () => {
      setLoading(true);
      const [{ data: claims }, { data: members }] = await Promise.all([
        supabase.rpc("admin_task_signups", { p_task: task.id }),
        supabase.from("profiles").select("id, name, role").order("name"),
      ]);
      setSignups(claims || []);
      setAllMembers(members || []);
      setLoading(false);
    })();
  }, [task.id]);

  const signedUpIds = new Set(signups.map((s) => s.user_id));

  // Bekræftelse af gennemførte tjanser. Point tilføjes først her.
  const setStatus = async (userId, status) => {
    setSaving(true); setError(null);
    const { error: err } = await supabase.rpc("admin_set_claim_status", {
      p_task: task.id, p_user: userId, p_status: status,
    });
    setSaving(false);
    if (err) { setError("Kunne ikke gemme: " + err.message); return; }
    setSignups((prev) => prev.map((s) => s.user_id === userId ? { ...s, status } : s));
    const who = signups.find((s) => s.user_id === userId)?.name || "medlem";
    logAction("task", status === "completed"
      ? `Bekræftede ${who} som gennemført på "${task.title}"`
      : status === "no_show"
        ? `Registrerede ${who} som udeblevet fra "${task.title}"`
        : `Genåbnede bekræftelsen for ${who} på "${task.title}"`, currentUser);
  };

  const confirmAll = async () => {
    setSaving(true); setError(null);
    const { error: err } = await supabase.rpc("admin_confirm_task", { p_task: task.id, p_status: "completed" });
    setSaving(false);
    if (err) { setError("Kunne ikke bekræfte: " + err.message); return; }
    setSignups((prev) => prev.map((s) => s.status === "signed_up" ? { ...s, status: "completed" } : s));
    onConfirmed?.();
    logAction("task", `Bekræftede alle tilmeldte på "${task.title}"`, currentUser);
  };

  const awaiting = signups.filter((s) => s.status === "signed_up").length;

  // Point og ledige pladser reguleres af databasen, ikke her. Tidligere lagde
  // admin-panelet selv point til OVENI databasens egen optælling, så en
  // tildelt opgave gav dobbelt point i forhold til en, medlemmet selv tog.
  const syncSpots = async () => {
    const { data } = await supabase.from("tasks").select("spots_left").eq("id", task.id).single();
    if (data) {
      setSpotsLeft(data.spots_left);
      setTasks((prev) => prev.map((t) => t.id === task.id ? { ...t, spotsLeft: data.spots_left } : t));
    }
  };

  const removeSignup = async (profile) => {
    setSaving(true); setError(null);
    const { error: e1 } = await supabase.from("task_claims").delete().eq("task_id", task.id).eq("user_id", profile.id);
    if (e1) { setError("Kunne ikke fjerne tilmelding: " + e1.message); setSaving(false); return; }

    await syncSpots();
    setSignups((prev) => prev.filter((s) => s.user_id !== profile.id));
    setConfirmRemove(null); setSaving(false);
    onConfirmed?.();
    logAction("task", `Fjernede ${profile.name} fra "${task.title}"`, currentUser);
  };

  const assignMember = async (member) => {
    setSaving(true); setError(null);
    const { error: e1 } = await supabase.from("task_claims").insert({ task_id: task.id, user_id: member.id });
    if (e1) {
      const msg = /fuldt besat/i.test(e1.message || "")
        ? "Opgaven er allerede fuldt besat"
        : /ikke godkendt/i.test(e1.message || "")
          ? `${member.name} er ikke godkendt endnu`
          : "Kunne ikke tildele: " + e1.message;
      setError(msg); setSaving(false); await syncSpots(); return;
    }

    await syncSpots();
    setSignups((prev) => [...prev, { user_id: member.id, name: member.name, role: member.role, status: "signed_up" }]);
    setAssignSearch(""); setSaving(false);
    logAction("task", `Tildelte "${task.title}" til ${member.name}`, currentUser);
  };

  const filteredMembers = allMembers.filter(
    (m) => !signedUpIds.has(m.id) && (m.name || "").toLowerCase().includes(assignSearch.toLowerCase())
  );

  const canAssign = spotsLeft > 0;

  return (
    <div className="flex flex-col gap-4">
      {/* Header */}
      <div className="flex items-center gap-3">
        <button onClick={onClose} className="p-1.5 hover:bg-stone-100 rounded-lg"><ArrowLeft className="w-4 h-4 text-stone-500" /></button>
        <div className="flex-1 min-w-0">
          <div className="font-bold text-[14px] text-stone-900 truncate">{task.title}</div>
          <div className="text-[11px] text-stone-500">{task.date} · {spotsLeft}/{task.spotsTotal} ledige pladser</div>
        </div>
      </div>

      {error && <div className="bg-red-50 border border-red-200 rounded-xl p-3 text-[13px] text-red-700">{error}</div>}

      {/* Tilmeldte */}
      <div>
        <div className="flex items-center justify-between mb-2 gap-2">
          <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500">
            Tilmeldte ({signups.length})
          </div>
          {awaiting > 0 && (
            <button disabled={saving} onClick={confirmAll}
              className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-[11px] font-bold text-white disabled:opacity-50 active:scale-95"
              style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>
              <CheckCircle2 className="w-3.5 h-3.5" />{awaiting === 1 ? "Markér gennemført" : `Alle ${awaiting} gennemførte`}
            </button>
          )}
        </div>
        {loading ? (
          <div className="text-center py-6 text-stone-400 text-sm">Indlæser...</div>
        ) : signups.length === 0 ? (
          <div className="bg-stone-50 rounded-xl p-4 text-center text-[13px] text-stone-400">Ingen tilmeldte endnu</div>
        ) : (
          <div className="space-y-2">
            {signups.map((s) => {
              const st = s.status || "signed_up";
              return (
                <div key={s.user_id} className="bg-white border border-stone-100 rounded-xl p-3 shadow-sm">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>
                      {(s.name || "?")[0].toUpperCase()}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="font-semibold text-[13px] text-stone-900 truncate">{s.name}</div>
                      <div className="text-[11px] text-stone-400 truncate">{s.team || s.role}</div>
                    </div>
                    <ClaimStatusPill status={st} />
                  </div>

                  <div className="flex gap-1.5 mt-2.5">
                    {st === "signed_up" ? (
                      <>
                        <button disabled={saving} onClick={() => setStatus(s.user_id, "completed")}
                          className="flex-1 inline-flex items-center justify-center gap-1 px-2 py-1.5 rounded-lg text-[12px] font-bold text-white disabled:opacity-50 active:scale-95"
                          style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>
                          <Check className="w-3.5 h-3.5" />Gennemført (+{task.points})
                        </button>
                        <button disabled={saving} onClick={() => setStatus(s.user_id, "no_show")}
                          className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[12px] font-semibold text-stone-600 bg-stone-100 hover:bg-stone-200 disabled:opacity-50 active:scale-95">
                          <UserX className="w-3.5 h-3.5" />Udeblev
                        </button>
                      </>
                    ) : (
                      <button disabled={saving} onClick={() => setStatus(s.user_id, "signed_up")}
                        className="flex-1 inline-flex items-center justify-center gap-1 px-2 py-1.5 rounded-lg text-[12px] font-semibold text-stone-600 bg-stone-100 hover:bg-stone-200 disabled:opacity-50 active:scale-95">
                        <ArrowLeft className="w-3.5 h-3.5" />Fortryd
                      </button>
                    )}
                    <button disabled={saving} onClick={() => setConfirmRemove(s)}
                      className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[12px] font-semibold text-red-600 bg-red-50 hover:bg-red-100 disabled:opacity-50 active:scale-95">
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Tildel */}
      <div>
        <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500 mb-2">
          Tildel opgave til medlem
        </div>
        {!canAssign && (
          <div className="bg-amber-50 border border-amber-200 rounded-xl p-3 text-[12px] text-amber-700 mb-2 flex items-center gap-2">
            <AlertTriangle className="w-3.5 h-3.5 shrink-0" />Alle pladser er optaget — tildel alligevel ved at søge nedenfor
          </div>
        )}
        <div className="relative mb-2">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-stone-400" />
          <input
            className="w-full pl-9 pr-4 py-2.5 rounded-xl border border-stone-200 text-[13px] bg-stone-50 focus:outline-none focus:ring-2 focus:ring-emerald-300"
            placeholder="Søg efter medlem..."
            value={assignSearch}
            onChange={(e) => setAssignSearch(e.target.value)}
          />
        </div>
        {assignSearch.length > 0 && (
          <div className="space-y-1.5 max-h-52 overflow-y-auto">
            {filteredMembers.length === 0 ? (
              <div className="text-center py-3 text-[12px] text-stone-400">Ingen match</div>
            ) : filteredMembers.map((m) => (
              <button
                key={m.id}
                disabled={saving}
                onClick={() => assignMember(m)}
                className="w-full flex items-center gap-3 bg-white border border-stone-100 rounded-xl p-3 shadow-sm hover:border-emerald-300 hover:bg-emerald-50 active:scale-[0.98] text-left"
              >
                <div className="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold shrink-0" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
                  {(m.name || "?")[0].toUpperCase()}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="font-semibold text-[13px] text-stone-900">{m.name}</div>
                  <div className="text-[11px] text-stone-400">{m.role}</div>
                </div>
                <div className="flex items-center gap-1 text-[11px] font-bold text-emerald-700 bg-emerald-50 px-2 py-1 rounded-lg">
                  <UserPlus className="w-3 h-3" />Tildel
                </div>
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Bekræft fjern */}
      {confirmRemove && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 backdrop-blur-sm p-4" onClick={() => setConfirmRemove(null)}>
          <div className="bg-white rounded-2xl p-5 w-full max-w-md shadow-2xl" onClick={(e) => e.stopPropagation()}>
            <div className="text-[15px] font-bold text-stone-900 mb-1">Fjern tilmelding?</div>
            <p className="text-[13px] text-stone-500 mb-4">
              <strong>{confirmRemove.name}</strong> fjernes fra opgaven, og pladsen bliver fri igen.
              {confirmRemove.status === "completed"
                ? <> Tjansen er bekræftet, så de <strong>{task.points} point</strong> trækkes tilbage.</>
                : <> Tjansen er ikke bekræftet, så der er ingen point at trække tilbage.</>}
            </p>
            <div className="flex gap-2">
              <button onClick={() => setConfirmRemove(null)} className="flex-1 py-2.5 rounded-xl border border-stone-200 text-[13px] font-semibold text-stone-600">Annuller</button>
              <button
                disabled={saving}
                onClick={() => removeSignup(confirmRemove)}
                className="flex-1 py-2.5 rounded-xl text-[13px] font-bold text-white bg-red-500 hover:bg-red-600 active:scale-[0.98]"
              >
                {saving ? "Gemmer..." : "Fjern"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

// ---- OPGAVESTYRING ----
// ---- BEKRÆFT GENNEMFØRTE TJANSER ----
// Point gives først her. Listen viser de opgaver, hvor nogen stadig afventer
// at blive gjort op — overståede først, for det er dem der haster.
const AdminConfirmations = ({ currentUser, onOpenTask }) => {
  const [rows, setRows]       = useState([]);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy]       = useState(null);
  const [error, setError]     = useState(null);
  const [auto, setAuto]       = useState(null);

  const load = async () => {
    setLoading(true);
    const [{ data, error: err }, { data: preview }] = await Promise.all([
      supabase.rpc("admin_pending_confirmations"),
      supabase.rpc("auto_confirm_preview"),
    ]);
    setLoading(false);
    if (err) { setError("Kunne ikke hente listen: " + err.message); return; }
    setError(null);
    setRows(data || []);
    setAuto(preview?.[0] || null);
  };

  // Dataindlæsning ved visning. Reglen advarer mod setState i en effect,
  // men her sker det først efter et svar fra serveren — det er netop det,
  // effects er til: at synkronisere med noget uden for React.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => { load(); }, []);

  const autoDays = auto?.days_setting || 0;

  const confirmAll = async (row) => {
    setBusy(row.task_id); setError(null);
    const { error: err } = await supabase.rpc("admin_confirm_task", { p_task: row.task_id, p_status: "completed" });
    setBusy(null);
    if (err) { setError("Kunne ikke bekræfte: " + err.message); return; }
    setRows((prev) => prev.filter((r) => r.task_id !== row.task_id));
    logAction("task", `Bekræftede alle ${row.pending} tilmeldte på "${row.title}"`, currentUser);
  };

  // Overståede opgaver øverst, ellers kronologisk. Samme datoforståelse som
  // opgavefeedet, så en dato skrevet "4. okt" også sorteres rigtigt.
  const sorted = useMemo(() => {
    const today = new Date();
    const cutoff = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    return [...rows]
      .map((r) => {
        const d = parseTaskDate({ date: r.task_date, dateFull: r.date_full });
        // Automatikken regner kun på datoer den kan læse med sikkerhed.
        const iso = /^\d{4}-\d{2}-\d{2}/.test(r.date_full || "");
        // parseTaskDate lander kl. 12, så begge sider skal skæres ned til
        // ren dato — ellers bliver nedtællingen én dag forkert.
        const dMid = d ? new Date(d.getFullYear(), d.getMonth(), d.getDate()) : null;
        const daysLeft = (iso && autoDays > 0 && dMid)
          ? autoDays - Math.round((cutoff - dMid) / 86400000)
          : null;
        return { ...r, when: d, isPast: d ? d < cutoff : false, autoIn: daysLeft, manualOnly: autoDays > 0 && !iso };
      })
      .sort((a, b) => {
        if (a.isPast !== b.isPast) return a.isPast ? -1 : 1;
        if (!a.when && !b.when) return 0;
        if (!a.when) return 1;
        if (!b.when) return -1;
        return a.isPast ? b.when - a.when : a.when - b.when;
      });
  }, [rows, autoDays]);

  const overdue = sorted.filter((r) => r.isPast);
  const upcoming = sorted.filter((r) => !r.isPast);
  const totalPending = rows.reduce((n, r) => n + r.pending, 0);

  const Row = ({ r }) => (
    <div className="bg-white border border-stone-100 rounded-xl p-3 shadow-sm">
      <div className="flex items-start gap-3">
        <div className="w-9 h-9 rounded-lg flex items-center justify-center text-white shrink-0" style={{ background: r.isPast ? `linear-gradient(135deg, ${theme.pink}, ${theme.purple})` : `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>
          <CategoryIcon type={r.icon} className="w-4 h-4" />
        </div>
        <div className="flex-1 min-w-0">
          <div className="font-semibold text-[13px] text-stone-900 truncate">{r.title}</div>
          <div className="text-[11px] text-stone-500 flex items-center gap-1.5 flex-wrap mt-0.5">
            <span>{r.task_date}</span>
            {r.task_time && <><span>·</span><span>{r.task_time}</span></>}
            {r.location && <><span>·</span><span className="truncate">{r.location}</span></>}
          </div>
          <div className="flex items-center gap-1.5 mt-1.5 flex-wrap">
            <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md border border-amber-200 bg-amber-50 text-amber-800 text-[10px] font-semibold">
              <Clock className="w-2.5 h-2.5" />{r.pending} afventer
            </span>
            {r.completed > 0 && <span className="text-[10px] text-emerald-700 font-semibold">{r.completed} godkendt</span>}
            {r.no_show > 0 && <span className="text-[10px] text-stone-400 font-semibold">{r.no_show} udeblev</span>}
            <span className="text-[10px] text-stone-400">· {r.points} pt pr. person</span>
          </div>
          {autoDays > 0 && (
            <div className="text-[10px] mt-1.5">
              {r.manualOnly ? (
                <span className="inline-flex items-center gap-1 text-stone-500">
                  <AlertTriangle className="w-2.5 h-2.5" />Datoen kan ikke læses automatisk — skal gøres op i hånden
                </span>
              ) : r.autoIn != null && r.autoIn <= 0 ? (
                <span className="inline-flex items-center gap-1 text-emerald-700 font-semibold">
                  <Clock className="w-2.5 h-2.5" />Godkendes automatisk ved næste kørsel
                </span>
              ) : r.autoIn != null ? (
                <span className="inline-flex items-center gap-1 text-stone-500">
                  <Clock className="w-2.5 h-2.5" />Godkendes automatisk om {r.autoIn} {r.autoIn === 1 ? "dag" : "dage"}
                </span>
              ) : null}
            </div>
          )}
        </div>
      </div>

      <div className="flex gap-1.5 mt-2.5">
        <button disabled={busy === r.task_id} onClick={() => confirmAll(r)}
          className="flex-1 inline-flex items-center justify-center gap-1 px-2 py-1.5 rounded-lg text-[12px] font-bold text-white disabled:opacity-50 active:scale-95"
          style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>
          <CheckCircle2 className="w-3.5 h-3.5" />
          {busy === r.task_id ? "Gemmer..." : r.pending === 1 ? "Markér gennemført" : `Alle ${r.pending} gennemførte`}
        </button>
        <button onClick={() => onOpenTask(r.task_id)}
          className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg text-[12px] font-semibold text-stone-600 bg-stone-100 hover:bg-stone-200 active:scale-95">
          Enkeltvis<ChevronRight className="w-3.5 h-3.5" />
        </button>
      </div>
    </div>
  );

  return (
    <div className="space-y-4">
      <div className="bg-violet-50 border border-violet-200 rounded-xl p-3 flex gap-2.5">
        <Info className="w-4 h-4 text-violet-600 shrink-0 mt-0.5" />
        <p className="text-[11px] text-violet-900 leading-relaxed">
          Medlemmer får først deres point, når tjansen er bekræftet som gennemført.
          Mødte alle op, kan du godkende hele opgaven med ét tryk.
          {autoDays > 0
            ? <> Det, du ikke når, godkendes automatisk {autoDays} dage efter opgavens sidste dag — så her skal du kun røre det, der <strong>ikke</strong> gik som planlagt.</>
            : <> Automatisk godkendelse er slået fra, så alt skal gøres op her.</>}
        </p>
      </div>

      {autoDays > 0 && auto?.unparseable > 0 && (
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-3 flex gap-2.5">
          <AlertTriangle className="w-4 h-4 text-amber-700 shrink-0 mt-0.5" />
          <p className="text-[11px] text-amber-900 leading-relaxed">
            <strong>{auto.unparseable}</strong> {auto.unparseable === 1 ? "tilmelding" : "tilmeldinger"} hører til opgaver uden en
            entydig slutdato. Dem rører automatikken ikke — de skal godkendes her.
          </p>
        </div>
      )}

      {error && (
        <div className="bg-red-50 border border-red-200 rounded-xl p-3 flex items-start gap-2">
          <AlertTriangle className="w-4 h-4 text-red-600 shrink-0 mt-0.5" />
          <p className="text-[12px] text-red-900 flex-1">{error}</p>
          <button onClick={() => setError(null)} className="text-red-400"><X className="w-4 h-4" /></button>
        </div>
      )}

      {loading ? (
        <div className="text-center py-8 text-stone-400 text-sm">Indlæser...</div>
      ) : rows.length === 0 ? (
        <div className="bg-white rounded-2xl border border-dashed border-stone-200 p-8 text-center">
          <CheckCircle2 className="w-10 h-10 mx-auto mb-2 text-emerald-300" />
          <p className="text-[13px] text-stone-600 font-semibold">Alt er gjort op</p>
          <p className="text-[12px] text-stone-400 mt-1">Der er ingen tjanser, der venter på bekræftelse.</p>
        </div>
      ) : (
        <>
          <div className="flex items-center justify-between">
            <div className="text-[12px] text-stone-500">
              <strong className="text-stone-800">{totalPending}</strong> tilmeldinger på <strong className="text-stone-800">{rows.length}</strong> opgaver afventer
            </div>
            <button onClick={load} className="text-[11px] text-stone-400 underline hover:text-stone-600">Opdatér</button>
          </div>

          {overdue.length > 0 && (
            <div>
              <div className="text-[11px] uppercase tracking-widest font-bold text-pink-700 mb-2">
                Overstået ({overdue.length})
              </div>
              <div className="space-y-2">{overdue.map((r) => <Row key={r.task_id} r={r} />)}</div>
            </div>
          )}

          {upcoming.length > 0 && (
            <div>
              <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500 mb-2">
                Endnu ikke afholdt ({upcoming.length})
              </div>
              <div className="space-y-2">{upcoming.map((r) => <Row key={r.task_id} r={r} />)}</div>
            </div>
          )}
        </>
      )}
    </div>
  );
};

const SORTERINGER = [
  { id: "dato",     label: "Dato" },
  { id: "mangler",  label: "Mangler folk" },
  { id: "point",    label: "Point" },
  { id: "titel",    label: "Titel" },
  { id: "oprettet", label: "Oprettet" },
];

const AdminTasks = ({ tasks, setTasks, currentUser, openSignups, onSignupsOpened, onConfirmed }) => {
  const [showNew, setShowNew]       = useState(false);
  const [editTask, setEditTask]     = useState(null);
  const [menuOpen, setMenuOpen]     = useState(null);
  const [sortering, setSortering]   = useState("dato");

  // Listen laa foer i den raekkefoelge, opgaverne var OPRETTET i. Det siger
  // ingenting om, hvad der er naeste gang nogen skal moede op. Standarden er
  // nu udfoerelsesdato, med de naermeste oeverst.
  //
  // tasks er props — kopiér foer sortering, ellers aendres foraelderens array.
  const sorterede = useMemo(() => {
    const kopi = [...tasks];
    const efterDato = (a, b) => {
      const ad = parseTaskDate(a), bd = parseTaskDate(b);
      if (!ad && !bd) return 0;
      if (!ad) return 1;            // opgaver uden laesbar dato nederst
      if (!bd) return -1;
      return ad - bd;
    };
    switch (sortering) {
      case "mangler":
        // Dem der mangler flest folk foerst – det er dem, der haster.
        return kopi.sort((a, b) => (b.spotsLeft - a.spotsLeft) || efterDato(a, b));
      case "point":
        return kopi.sort((a, b) => (b.points - a.points) || efterDato(a, b));
      case "titel":
        return kopi.sort((a, b) => a.title.localeCompare(b.title, "da"));
      case "oprettet":
        return kopi;                // rækkefølgen fra serveren er created_at
      default:
        return kopi.sort(efterDato);
    }
  }, [tasks, sortering]);
  // Kommer man hertil fra bekræftelseslisten, åbnes den valgte opgave direkte.
  // Komponenten monteres på ny, hver gang man skifter til Opgaver-fanen, så
  // prop'en kan læses i en initializer — det er hverken nødvendigt eller
  // korrekt at kopiere den ind med en effect.
  const [signupsTaskId, setSignupsTaskId] = useState(openSignups || null);
  const signupsTask = signupsTaskId ? tasks.find((t) => t.id === signupsTaskId) : null;
  const closeSignups = () => { setSignupsTaskId(null); onSignupsOpened?.(); };
  const [saveError, setSaveError]     = useState(null);

  const deleteTask = async (id) => {
    const task = tasks.find((t) => t.id === id);
    setMenuOpen(null);

    // Databasen trækker selv pointene tilbage fra alle tilmeldte og sender
    // dem besked om aflysningen, når opgaven slettes.
    const { error } = await supabase.from("tasks").delete().eq("id", id);
    if (error) { setSaveError("Kunne ikke slette opgaven: " + error.message); return; }

    setTasks((prev) => prev.filter((t) => t.id !== id));
    logAction("task", `Slettede opgave: "${task?.title || id}" – point fratrukket alle tilmeldte`, currentUser);
  };

  const duplicateTask = async (t) => {
    const copy = { ...t, id: undefined, title: `${t.title} (kopi)`, spotsLeft: t.spotsTotal };
    setMenuOpen(null);
    const { data } = await supabase.from("tasks").insert({
      title: copy.title, category: copy.category, icon: copy.icon, date: copy.date,
      date_full: copy.dateFull, date_end: copy.dateEnd || null, duration_type: copy.durationType || "single",
      time: copy.time, location: copy.location,
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
      // Ledige pladser må IKKE nulstilles ved redigering – så ville en rettet
      // titel få opgaven til at se fri ud, selvom folk allerede stod på den.
      // Ændrer admin antal pladser, flyttes det ledige antal med forskellen.
      const newTotal  = parseInt(data.spots);
      const oldTotal  = editTask.spotsTotal ?? newTotal;
      const taken     = Math.max(0, oldTotal - (editTask.spotsLeft ?? oldTotal));
      const newLeft   = Math.max(0, newTotal - taken);

      const { error: updErr } = await supabase.from("tasks").update({
        title: data.title, category: data.category, icon: data.icon, date: data.date,
        date_full: data.dateFull, date_end: data.dateEnd || null, duration_type: data.durationType || "single",
        time: data.time, location: data.location,
        points: parseInt(data.points), difficulty: data.difficulty, urgent: data.urgent,
        spots_total: newTotal, spots_left: newLeft,
      }).eq("id", editTask.id);

      if (updErr) { setSaveError("Kunne ikke gemme opgaven: " + updErr.message); return; }

      await supabase.from("task_steps").delete().eq("task_id", editTask.id);
      if (steps.length > 0) {
        await supabase.from("task_steps").insert(steps.map((text, i) => ({ task_id: editTask.id, step_order: i + 1, text })));
      }
      setTasks((prev) => prev.map((t) => t.id === editTask.id
        ? { ...t, ...data, description: steps, spotsLeft: newLeft, spotsTotal: newTotal }
        : t));
      logAction("task", `Redigerede opgave: "${data.title}"`, currentUser);
    } else {
      const { data: row, error: insErr } = await supabase.from("tasks").insert({
        title: data.title, category: data.category, icon: data.icon, date: data.date,
        date_full: data.dateFull, date_end: data.dateEnd || null, duration_type: data.durationType || "single",
        time: data.time, location: data.location,
        points: parseInt(data.points), difficulty: data.difficulty, urgent: data.urgent,
        spots_total: parseInt(data.spots), spots_left: parseInt(data.spots),
      }).select().single();
      if (insErr) { setSaveError("Kunne ikke oprette opgaven: " + insErr.message); return; }
      if (row && steps.length > 0) {
        await supabase.from("task_steps").insert(steps.map((text, i) => ({ task_id: row.id, step_order: i + 1, text })));
      }
      if (row) {
        setTasks((prev) => [...prev, { id: row.id, ...data, description: steps, spotsLeft: parseInt(data.spots), spotsTotal: parseInt(data.spots) }]);
        logAction("task", `Oprettede opgave: "${data.title}" (${data.points} pt)`, currentUser);
      }
    }
    setSaveError(null);
    setShowNew(false); setEditTask(null);
  };

  if (signupsTask) {
    return <AdminTaskSignups task={signupsTask} onClose={closeSignups} setTasks={setTasks} currentUser={currentUser} onConfirmed={onConfirmed} />;
  }


  return (
    <div className="space-y-4">
      <button onClick={() => setShowNew(true)} className="w-full py-2.5 rounded-xl text-[13px] font-bold text-white flex items-center justify-center gap-1.5 shadow-md active:scale-[0.98]" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
        <Plus className="w-4 h-4" />Opret ny opgave
      </button>

      <ScrollRow className="flex gap-1.5 overflow-x-auto -mx-5 px-5 pb-1 scrollbar-hide">
        <span className="shrink-0 self-center text-[11px] font-semibold text-stone-400 pr-1">Sortér:</span>
        {SORTERINGER.map((v) => (
          <button key={v.id} data-active={sortering === v.id} onClick={() => setSortering(v.id)}
            className={`shrink-0 px-3 py-1.5 rounded-full text-[11px] font-semibold transition-all whitespace-nowrap ${
              sortering === v.id ? "text-white shadow-sm" : "bg-stone-100 text-stone-600 hover:bg-stone-200"}`}
            style={sortering === v.id ? { background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` } : {}}>
            {v.label}
          </button>
        ))}
      </ScrollRow>

      {saveError && (
        <div className="bg-red-50 border border-red-200 rounded-xl p-3 flex items-start gap-2">
          <AlertTriangle className="w-4 h-4 text-red-600 shrink-0 mt-0.5" />
          <p className="text-[12px] text-red-900 flex-1">{saveError}</p>
          <button onClick={() => setSaveError(null)} className="text-red-400"><X className="w-4 h-4" /></button>
        </div>
      )}

      <div className="space-y-2.5">
        {sorterede.map((t) => {
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
                          <MenuButton icon={<Users className="w-3.5 h-3.5" />} label="Tilmeldte" onClick={() => { setSignupsTaskId(t.id); setMenuOpen(null); }} />
                          <div className="h-px bg-stone-100 my-1" />
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
                    <button
                      onClick={() => setSignupsTaskId(t.id)}
                      className="flex items-center gap-1 px-2 py-1 rounded-lg text-[10px] font-bold text-stone-600 bg-stone-100 hover:bg-stone-200 active:scale-95"
                    >
                      <Users className="w-3 h-3" />{filled}
                    </button>
                  </div>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {(showNew || editTask) && <TaskFormModal task={editTask} onClose={() => { setShowNew(false); setEditTask(null); }} onSave={saveTask} currentUser={currentUser} />}
    </div>
  );
};

// ---- DATO-VÆLGER TIL OPGAVEFORMULAR ----
const DA_MONTHS_SHORT = ["jan","feb","mar","apr","maj","jun","jul","aug","sep","okt","nov","dec"];
const DA_MONTHS_LONG  = ["Januar","Februar","Marts","April","Maj","Juni","Juli","August","September","Oktober","November","December"];
const DA_DAYS_SHORT   = ["Man","Tir","Ons","Tor","Fre","Lør","Søn"];
const DA_WEEKDAY      = ["søn","man","tir","ons","tor","fre","lør"];

const formatDateDanish = (d) => {
  const day  = DA_WEEKDAY[d.getDay()];
  const date = d.getDate();
  const mon  = DA_MONTHS_SHORT[d.getMonth()];
  return `${day.charAt(0).toUpperCase() + day.slice(1)} ${date}. ${mon}`;
};

// En dato som ÅÅÅÅ-MM-DD, laest af de LOKALE felter.
//
// Det fristende ".toISOString().slice(0, 10)" er forkert her: new Date(år,
// måned, dag) er lokal midnat, og toISOString regner om til UTC. I dansk
// sommertid er 5. oktober kl. 00:00 lig 4. oktober kl. 22:00 UTC — så
// kalenderen gemte dagen FØR den, man trykkede på, og man skulle vælge en
// dag for sent for at ramme rigtigt.
const isoLokal = (d) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

const TaskDatePicker = ({ value, onChange }) => {
  const today = new Date();
  const [current, setCurrent] = useState(() => {
    if (value) { const d = new Date(value); return new Date(d.getFullYear(), d.getMonth()); }
    return new Date(today.getFullYear(), today.getMonth());
  });

  const year  = current.getFullYear();
  const month = current.getMonth();

  const firstDay = new Date(year, month, 1);
  const lastDay  = new Date(year, month + 1, 0);
  const startPad = (firstDay.getDay() + 6) % 7;

  const days = [];
  for (let i = startPad - 1; i >= 0; i--) days.push({ d: new Date(year, month, -i), cur: false });
  for (let i = 1; i <= lastDay.getDate(); i++) days.push({ d: new Date(year, month, i), cur: true });
  const rem = 7 - (days.length % 7);
  if (rem < 7) for (let i = 1; i <= rem; i++) days.push({ d: new Date(year, month + 1, i), cur: false });

  const selectedISO = value || "";
  const todayISO    = isoLokal(today);

  const pick = (d) => {
    const iso = isoLokal(d);
    onChange(iso, formatDateDanish(d));
  };

  return (
    <div>
      <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-2">Dato</label>
      <div className="bg-stone-50 border border-stone-200 rounded-xl overflow-hidden">
        {/* Month navigation */}
        <div className="flex items-center justify-between px-3 py-2 border-b border-stone-200">
          <button type="button" onClick={() => setCurrent(new Date(year, month - 1))} className="p-1.5 rounded-lg hover:bg-stone-200 transition-colors"><ChevronLeft className="w-4 h-4 text-stone-600" /></button>
          <span className="text-[13px] font-bold text-stone-800">{DA_MONTHS_LONG[month]} {year}</span>
          <button type="button" onClick={() => setCurrent(new Date(year, month + 1))} className="p-1.5 rounded-lg hover:bg-stone-200 transition-colors"><ChevronRight className="w-4 h-4 text-stone-600" /></button>
        </div>
        {/* Day headers */}
        <div className="grid grid-cols-7 px-2 pt-2 pb-1">
          {DA_DAYS_SHORT.map((d) => (
            <div key={d} className="text-center text-[10px] font-bold text-stone-400 pb-1">{d}</div>
          ))}
        </div>
        {/* Day grid */}
        <div className="grid grid-cols-7 px-2 pb-2 gap-y-0.5">
          {days.map(({ d, cur }, i) => {
            const iso      = isoLokal(d);
            const selected = iso === selectedISO;
            const isToday  = iso === todayISO;
            const past     = iso < todayISO;
            return (
              <button
                key={i} type="button"
                onClick={() => cur && !past && pick(d)}
                disabled={!cur || past}
                className={`h-8 w-full rounded-lg text-[12px] font-semibold transition-all
                  ${selected ? "text-white shadow-sm" : ""}
                  ${!selected && cur && !past ? "hover:bg-emerald-100 hover:text-emerald-800" : ""}
                  ${!cur || past ? "opacity-30 cursor-default" : ""}
                  ${isToday && !selected ? "ring-1 ring-emerald-400 text-emerald-700" : ""}
                  ${!selected ? "text-stone-800" : ""}
                `}
                style={selected ? { background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` } : {}}
              >
                {d.getDate()}
              </button>
            );
          })}
        </div>
      </div>
      {selectedISO && (
        <div className="flex items-center justify-between mt-1.5 px-1">
          <span className="text-[12px] text-emerald-700 font-semibold">{formatDateDanish(new Date(selectedISO + "T12:00:00"))}</span>
          <button type="button" onClick={() => onChange("", "")} className="text-[11px] text-stone-400 hover:text-stone-600">Ryd</button>
        </div>
      )}
    </div>
  );
};

// ============ FORESLAAET POINTTAL ============
//
// Tallene er ikke fundet paa. De er laest ud af klubbens egne 40 skabeloner,
// saa et forslag ligner det, klubben allerede har besluttet:
//
//   Let      5-25 pt   (median 10)  - en enkelt vagt
//   Medium  15-50 pt   (median 40)  - 15 for en kraevende enkeltvagt,
//                                     40-50 for en saesonrolle
//   Hård    75-100 pt  (median 75)  - seks af syv saesonroller staar paa 75
//
// Varigheden er den staerkeste faktor, ikke svaerhedsgraden alene: "Formand
// for festudvalget (Sæson)" og "Materialeansvarlig (Sæson)" er begge Hård og
// begge 75, mens "Dømme kampe" er Medium og 15. Derfor en tabel frem for en
// formel — den rammer de tal, klubben faktisk bruger.
//
// Det er et FORSLAG. Skriver en admin selv et tal, roerer appen det ikke igen.
const POINT_FORSLAG = {
  Let:    { single: 10, week: 15, month: 20, half_season: 30, year: 40 },
  Medium: { single: 15, week: 25, month: 40, half_season: 50, year: 50 },
  "Hård": { single: 25, week: 40, month: 60, half_season: 75, year: 75 },
};

const foreslaaPoint = (difficulty, durationType) =>
  POINT_FORSLAG[difficulty]?.[durationType] ?? POINT_FORSLAG[difficulty]?.single ?? 10;

const DURATION_OPTIONS = [
  { id: "single",      label: "Enkelt dag",   desc: "Én bestemt dato" },
  { id: "week",        label: "En uge",       desc: "7 dage fra startdato" },
  { id: "month",       label: "En måned",     desc: "Hele startmåneden" },
  { id: "half_season", label: "Halvt sæson",  desc: "6 måneder fra startdato" },
  { id: "year",        label: "Helt år",      desc: "12 måneder (sæson)" },
];

const computeDateDisplay = (startISO, durationType) => {
  if (!startISO) return { date: "", dateEnd: "" };
  const s = new Date(startISO + "T12:00:00");
  switch (durationType) {
    case "week": {
      const e = new Date(s); e.setDate(e.getDate() + 6);
      return { date: `${formatDateDanish(s)} – ${formatDateDanish(e)}`, dateEnd: e.toISOString().slice(0, 10) };
    }
    case "month":
      return { date: `${DA_MONTHS_LONG[s.getMonth()]} ${s.getFullYear()}`, dateEnd: "" };
    case "half_season": {
      const e = new Date(s); e.setMonth(e.getMonth() + 6);
      return {
        date: `${DA_MONTHS_SHORT[s.getMonth()]}. ${s.getFullYear()} – ${DA_MONTHS_SHORT[e.getMonth()]}. ${e.getFullYear()}`,
        dateEnd: e.toISOString().slice(0, 10),
      };
    }
    case "year": {
      const e = new Date(s); e.setFullYear(e.getFullYear() + 1);
      return { date: `Sæson ${s.getFullYear()}/${String(e.getFullYear()).slice(2)}`, dateEnd: e.toISOString().slice(0, 10) };
    }
    default:
      return { date: formatDateDanish(s), dateEnd: "" };
  }
};


const TASK_TEMPLATES = [
  {
    label: "Kampafvikling & Sekretærbord", icon: "whistle",
    templates: [
      { title: "Dømme kampe som klubdommer (lokalrækker)", points: 15, difficulty: "Medium", description: "Døm en kamp i lokalrækkerne som klubdommer.\nMød op 15 min. før kampstart.\nAflever kampskema til halsoveren efter kampen." },
      { title: "Sekretærbordet – elektronisk holdkort/point", points: 10, difficulty: "Let", description: "Sid ved sekretærbordet og før elektronisk holdkort.\nVær på plads senest 20 min. før kampstart.\nKontakt kampansvarlig ved tvivl." },
      { title: "Halspeaker til divisions-/hjemmekamp", points: 10, difficulty: "Let", description: "Vær halspeaker ved hjemmekampe.\nAnnoncér hold, spillerskift og resultater.\nBrug klubbens speaker-udstyr." },
      { title: "Linjedommer til stor kamp", points: 10, difficulty: "Let", description: "Vær linjedommer ved en større kamp.\nMød op 30 min. før kampstart til briefing.\nFølg dommernes anvisninger under kampen." },
      { title: "Opsætning/nedtagning af bane og net", points: 5, difficulty: "Let", description: "Opsæt eller tag baner og net ned ved kampdag.\nTjek at net er i korrekt højde.\nLæg alt udstyr tilbage på rette plads." },
      { title: "Kampansvarlig/Halsover", points: 15, difficulty: "Medium", description: "Mød op som den første og lås hallen op.\nSørg for at alt er klar til kampen.\nLuk hallen og aflevér nøgler til rette vedkommende." },
    ],
  },
  {
    label: "Hygge og Socialt", icon: "cake",
    templates: [
      { title: "Formand for festudvalget (Sæson)", points: 75, difficulty: "Hård", description: "Vær formand for festudvalget hele sæsonen.\nPlanlæg og koordinér alle sociale arrangementer.\nRapportér til bestyrelsen." },
      { title: "Udvalgsmedlem i festudvalget (Sæson)", points: 40, difficulty: "Medium", description: "Deltag aktivt i festudvalgets arbejde hele sæsonen.\nHjælp med planlægning og praktisk afholdelse af arrangementer." },
      { title: "Klargøring og madlavning til fællesspisning", points: 15, difficulty: "Let", description: "Hjælp med at klargøre og lave mad til fællesspisning.\nMød op 1 time før arrangementet starter.\nRyd op bagefter." },
      { title: "Kioskvagt til alm. hjemmekamp (ca. 2-3 timer)", points: 10, difficulty: "Let", description: "Bemand kiosken under en hjemmekamp.\nSørg for at varer er fyldt op.\nAflever kassen til kassereren efter kampen." },
      { title: "Bage kage / lave madpakker til et hold", points: 5, difficulty: "Let", description: "Bag kage eller lav madpakker til et hold.\nAftaler omfang med holdleder." },
      { title: "Oprydning/Rengøring efter klubfest", points: 15, difficulty: "Let", description: "Hjælp med oprydning og rengøring efter klubfest eller arrangement.\nBliv til alt er ryddet op og hallen er klar til næste brug." },
      { title: "Indkøber til kiosken (Sæson)", points: 50, difficulty: "Medium", description: "Stå for indkøb til klubkiosken hele sæsonen.\nHold styr på lagerstatus og bestil varer.\nSørg for at priser er opdaterede." },
    ],
  },
  {
    label: "Holdleder & Transport", icon: "setup",
    templates: [
      { title: "Fast holdleder for et ungdoms- eller seniorhold (Sæson)", points: 75, difficulty: "Hård", description: "Vær fast holdleder for et hold hele sæsonen.\nKommunikér med forældre, spillere og trænere.\nSørg for tilmelding, kørsel og praktiske forhold." },
      { title: "Kørsel til udekamp inkl. heppekor", points: 15, difficulty: "Let", description: "Kør spillere til udekamp og hep holdet under kampen.\nAftaler mødested og tidspunkt med holdleder.\nSørg for at alle kommer sikkert hjem." },
      { title: "Kørsel til udekamp – kun aflevering/afhentning", points: 5, difficulty: "Let", description: "Kør spillere til eller fra udekamp.\nAftaler tidspunkt og sted med holdleder." },
      { title: "Fast vaskemaskine – holdets trøjer hele sæsonen", points: 50, difficulty: "Medium", description: "Vask holdets spillertøj efter samtlige kampe og stævner hele sæsonen.\nAftaler afhentning og aflevering med holdleder." },
      { title: "Vask af spillertøj efter én kamp/stævne", points: 5, difficulty: "Let", description: "Vask holdets spillertøj efter én kamp eller et stævne.\nAftaler afhentning og aflevering med holdleder." },
    ],
  },
  {
    label: "Stævneplanlægning og Afholdelse", icon: "whistle",
    templates: [
      { title: "Stævneleder/Hovedansvarlig for klubbens eget stævne", points: 75, difficulty: "Hård", description: "Vær overordnet ansvarlig for afviklingen af et klubstævne.\nKoordinér alle frivillige og leverandører.\nSørg for at stævneprogrammet følges." },
      { title: "Medlem af stævneudvalg (planlægning)", points: 40, difficulty: "Medium", description: "Deltag i planlægningen af klubbens stævne.\nMød til udvalgets møder og tag ansvar for aftalte opgaver." },
      { title: "Natvagt/Halsover ved overnatningsstævne", points: 30, difficulty: "Medium", description: "Vær halsover om natten ved overnatningsstævne (ca. kl. 23–07).\nSørg for ro og tryghed for de deltagende unge." },
      { title: "Stævnesekretariatet – registrér resultater (halvdags)", points: 20, difficulty: "Let", description: "Sid i stævnesekretariatet og registrér resultater og tider.\nStyr kampuret og koordinér med dommerne." },
      { title: "Kioskvagt ved stort weekendstævne (vagt á 3 timer)", points: 15, difficulty: "Let", description: "Bemand kiosken i 3 timer under weekendstævnet.\nSørg for at varer er fyldt op løbende." },
      { title: "Opsætning fredag aften inden stævne / Hovedrengøring søndag", points: 15, difficulty: "Let", description: "Hjælp med at sætte hallen op fredag aften eller stå for hovedrengøring søndag.\nFølg stævnelederens anvisninger." },
    ],
  },
  {
    label: "Kommunikation & PR", icon: "coffee",
    templates: [
      { title: "Webmaster / Hovedansvarlig for SoMe (Sæson)", points: 75, difficulty: "Hård", description: "Vær ansvarlig for klubbens hjemmeside og sociale medier hele sæsonen.\nPost regelmæssige opdateringer og resultater.\nKoordinér indhold med bestyrelsen." },
      { title: "Sponsorudvalg (Sæson – indhente sponsorer)", points: 75, difficulty: "Hård", description: "Vær en del af sponsorudvalget og indhent sponsorer til klubben hele sæsonen.\nKontakt lokale virksomheder og lav sponsoraftaler." },
      { title: "Fotograf til kampdag/stævne inkl. redigering og deling", points: 15, difficulty: "Let", description: "Tag billeder ved en kampdag eller stævne.\nRedigér udvalgte billeder og del med klubben.\nBrug klubbens fotokanaler til deling." },
      { title: "Skrive kampreferater / artikler til hjemmeside/Facebook", points: 10, difficulty: "Let", description: "Skriv et kort kampreferat eller en artikel til hjemmeside eller Facebook.\nAflever tekst til SoMe-ansvarlig senest dagen efter kampen." },
      { title: "Lave grafisk materiale (plakater, opslag, stævneprogram)", points: 10, difficulty: "Let", description: "Lav grafisk materiale til klubbens aktiviteter.\nBrug klubbens farver og logo.\nAflever filer til SoMe-ansvarlig i aftalt format." },
      { title: "Dele flyers / hænge plakater op i lokalområdet", points: 5, difficulty: "Let", description: "Del flyers eller hæng plakater op i lokalområdet.\nFå materiale udleveret af SoMe-ansvarlig.\nIndmeld hvilke steder du har besøgt." },
    ],
  },
  {
    label: "Faciliteter & Materialer", icon: "setup",
    templates: [
      { title: "Materialeansvarlig (Sæson)", points: 75, difficulty: "Hård", description: "Hold overblik over bolde, tøj, net og øvrigt udstyr hele sæsonen.\nRegistrér slitage og bestil nyt ved behov.\nRapportér til bestyrelsen." },
      { title: "Klargøring af beachvolleyball-baner (arbejdsdag)", points: 20, difficulty: "Medium", description: "Hjælp med at klargøre beachvolleyball-banerne til sæsonen.\nMød op til den aftalte arbejdsdag.\nMedtag egnet fodtøj og arbejdstøj." },
      { title: "Vedligehold af beach-baner (luge ukrudt, rive baner)", points: 10, difficulty: "Let", description: "Vedligehold beachbanerne ved at luge ukrudt og rive sand.\nCa. 2 timers arbejde pr. gang." },
      { title: "Hovedoprydning og organisering af boldrum", points: 15, difficulty: "Let", description: "Ryd op og organiser klubbens boldrum.\nSørg for at alt udstyr er på rette plads og mærket." },
      { title: "Småreparationer (sy net, fikse boldvogne, pumpe bolde)", points: 10, difficulty: "Let", description: "Foretag småreparationer på klubbens udstyr.\nSy net, reparer boldvogne eller pump bolde.\nRapportér større skader til materialeansvarlig." },
    ],
  },
  {
    label: "Klubadministration", icon: "setup",
    templates: [
      { title: "Bestyrelsesmedlem (Formand, Kasserer m.fl.)", points: 100, difficulty: "Hård", description: "Sidder i klubbens bestyrelse hele sæsonen.\nDeltager i bestyrelsesmøder og varetager bestyrelsespost.\nRapporterer til generalforsamlingen." },
      { title: "Revisor / Økonomisk hjælp (Sæson)", points: 40, difficulty: "Medium", description: "Hjælp med revision eller økonomi hele sæsonen.\nGennemgå regnskab og bilag.\nRapportér til kassereren." },
      { title: "Børneattest-ansvarlig (Sæson)", points: 40, difficulty: "Medium", description: "Indhent og tjek børneattester for alle relevante frivillige.\nHold register opdateret hele sæsonen.\nRapportér mangler til formanden." },
      { title: "Hjælp til medlemsregistrering og kontingentkørsel", points: 25, difficulty: "Let", description: "Hjælp med at registrere nye medlemmer og køre kontingentopkrævning.\nAftaler opgaveomfang med kassereren." },
      { title: "Fonds-ansøger (skrive og sende fondansøgninger)", points: 25, difficulty: "Medium", description: "Skriv og send ansøgninger til fonde og puljer på vegne af klubben.\nKoordinér med bestyrelsen om behovsområder.\nRapportér svar og tildelinger." },
    ],
  },
];

const TaskFormModal = ({ task, onClose, onSave, currentUser }) => {
  const isNew = !task;
  const [step, setStep]             = useState(isNew ? "pick" : "form");
  const [tplCat, setTplCat]         = useState(TASK_TEMPLATES[0].label);
  const [title, setTitle]           = useState(task?.title || "");
  const [category, setCategory]     = useState(task?.category || "Kampafvikling & Sekretærbord");
  const [icon, setIcon]             = useState(task?.icon || "whistle");
  // Har admin selv valgt et ikon? Samme regel som for pointtallet: en opgave,
  // der redigeres, har allerede et valgt ikon, og det roerer appen ikke.
  const [ikonRoert, setIkonRoert]   = useState(!!task);
  const [ikonAabent, setIkonAabent] = useState(false);
  const [date, setDate]             = useState(task?.date || "");
  const [dateISO, setDateISO]       = useState(task?.dateFull || "");
  const [durationType, setDuration] = useState(task?.durationType || "single");
  const [dateEnd, setDateEnd]       = useState(task?.dateEnd || "");
  const [time, setTime]             = useState(task?.time || "");
  const [location, setLocation]     = useState(task?.location || "");
  const [points, setPoints]     = useState(task?.points || 15);
  // Har admin selv skrevet et tal? Saa holder appen fingrene fra det.
  // En opgave, der redigeres, taeller som "roert": tallet er allerede valgt.
  const [pointRoert, setPointRoert] = useState(!!task);
  const [spots, setSpots]       = useState(task?.spotsTotal || 2);
  const [difficulty, setDiff]   = useState(task?.difficulty || "Let");
  const [urgent, setUrgent]     = useState(task?.urgent || false);
  const [description, setDesc]  = useState(task?.description?.join("\n") || "");

  // Ændrer en admin pointtallet på en opgave, hvor folk allerede står
  // tilmeldt, følger deres point med. Det skal man kunne se FØR man gemmer.
  const [claimCounts, setClaimCounts] = useState(null);
  useEffect(() => {
    if (isNew || !task?.id) return;
    let ignore = false;
    supabase.rpc("task_claim_counts", { p_task: task.id }).then(({ data }) => {
      if (!ignore && data?.[0]) setClaimCounts(data[0]);
    });
    return () => { ignore = true; };
  }, [isNew, task?.id]);

  // Foreslaaet tal ud fra svaerhedsgrad og varighed.
  const forslag = foreslaaPoint(difficulty, durationType);

  // Det tal, formularen arbejder med. Har admin ikke selv skrevet noget, ER
  // det forslaget — det gemmes ikke i state og synkroniseres ikke i en
  // effect, men udledes. Saa kan de to vaerdier aldrig komme ud af trit, og
  // vi undgaar en kaskade af renders.
  const visPoints = pointRoert ? points : forslag;

  // Ikonet udledes af titlen paa samme maade — ikke gemt i state, saa de to
  // aldrig kan komme ud af trit.
  const visIkon = ikonRoert ? icon : foreslaaIkon(title, category);

  const forslagAfviger = pointRoert && parseInt(visPoints) !== forslag;

  const pointsChanged = !isNew && parseInt(visPoints) !== (task?.points ?? null);
  const affected      = (claimCounts?.signed_up || 0) + (claimCounts?.completed || 0);

  const applyTemplate = (tpl, catLabel, ekstra) => {
    setTitle(tpl.title); setCategory(catLabel);
    // Klubbens egne skabeloner husker det ikon, admin valgte. Appens egne
    // forslag har ikke noget eget ikon — der er titlen bedre end kategorien.
    if (ekstra?.icon) { setIcon(ekstra.icon); setIkonRoert(true); }
    else { setIkonRoert(false); }
    setPoints(tpl.points); setDiff(tpl.difficulty); setDesc(tpl.description);
    // Skabelonens pointtal er et bevidst valg – det maa forslaget ikke
    // skrive hen over, naar svaerhedsgraden saettes lige ovenfor.
    setPointRoert(true);
    // Klubbens egne skabeloner husker ogsaa pladser, tidsrum og sted — det er
    // netop dét, der goer dem bedre end appens generiske forslag. Datoen
    // huskes med vilje IKKE: den er ny hver gang.
    if (ekstra) {
      if (ekstra.spots)        setSpots(ekstra.spots);
      if (ekstra.time)         setTime(ekstra.time);
      if (ekstra.location)     setLocation(ekstra.location);
      if (ekstra.durationType) setDuration(ekstra.durationType);
    }
    setStep("form");
  };

  // Kategorierne og deres reserveikon staar ét sted nu: KATEGORI_IKON.
  const categories = Object.keys(KATEGORI_IKON);

  const handleSave = () => {
    if (!title.trim() || !dateISO) return;
    onSave({ title, category, icon: visIkon, date, dateFull: dateISO, dateEnd, durationType, time, location, points: parseInt(visPoints), spots: parseInt(spots), difficulty, urgent, description });
  };

  // Klubbens egne skabeloner, gemt i databasen. De staar side om side med
  // appens indbyggede i vaelgeren.
  const [egne, setEgne] = useState([]);
  const [gemmerTpl, setGemmerTpl] = useState(false);
  const [tplBesked, setTplBesked] = useState(null);

  const hentEgne = useCallback(() => {
    supabase.from("task_templates").select("*").order("title").then(({ data }) => setEgne(data || []));
  }, []);
  useEffect(hentEgne, [hentEgne]);

  // Gem den udfyldte opgave som skabelon. Dato, tidspunkt og pladser er det,
  // der skifter fra gang til gang — titel, point, vejledning og kategori er
  // det, man ikke gider skrive igen.
  const gemSomSkabelon = async () => {
    if (!title.trim()) return;
    setGemmerTpl(true);
    setTplBesked(null);
    const { error } = await supabase.from("task_templates").upsert({
      category, title: title.trim(), points: parseInt(visPoints) || 10,
      difficulty, spots_total: parseInt(spots) || 2, duration_type: durationType,
      time: time || null, location: location || null, icon: visIkon,
      description: description || null,
      created_by: currentUser?.id || null,
    }, { onConflict: "category,title" });
    setGemmerTpl(false);
    if (error) {
      setTplBesked({ type: "fejl", text: `Kunne ikke gemme skabelonen: ${error.message}` });
      return;
    }
    setTplBesked({ type: "ok", text: `Gemt som skabelon under "${category}"` });
    hentEgne();
    setTimeout(() => setTplBesked(null), 4000);
  };

  const sletSkabelon = async (id) => {
    await supabase.from("task_templates").delete().eq("id", id);
    hentEgne();
  };

  const activeTplGroup = TASK_TEMPLATES.find((g) => g.label === tplCat) || TASK_TEMPLATES[0];

  // Klubbens egne i den valgte kategori
  const egneIKategori = egne.filter((t) => t.category === tplCat);

  if (step === "pick") {
    return (
      <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 backdrop-blur-sm" onClick={onClose}>
        <div className="bg-white rounded-t-3xl w-full max-w-md max-h-[92vh] flex flex-col animate-slideup" onClick={(e) => e.stopPropagation()}>
          {/* Header */}
          <div className="sticky top-0 bg-white border-b border-stone-100 px-5 pt-3 pb-3 flex items-center justify-between z-10 shrink-0">
            <div className="w-12 h-1 bg-stone-200 rounded-full absolute top-2 left-1/2 -translate-x-1/2" />
            <h3 className="text-lg font-bold mt-2">Vælg skabelon</h3>
            <button onClick={onClose} className="p-1.5 hover:bg-stone-100 rounded-lg mt-2"><X className="w-5 h-5" /></button>
          </div>
          {/* Category tabs */}
          <ScrollRow wrapperClassName="shrink-0" className="flex gap-2 overflow-x-auto px-4 py-3 scrollbar-hide border-b border-stone-100">
            {TASK_TEMPLATES.map((g) => (
              <button key={g.label} onClick={() => setTplCat(g.label)}
                className={`shrink-0 px-3 py-1.5 rounded-full text-[11px] font-semibold transition-all whitespace-nowrap ${tplCat === g.label ? "text-white" : "bg-stone-100 text-stone-700"}`}
                style={tplCat === g.label ? { background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` } : {}}>
                {g.label}
              </button>
            ))}
          </ScrollRow>
          {/* Template list */}
          <div className="overflow-y-auto flex-1 p-4 space-y-2 pb-24">
            {/* Klubbens egne foerst — det er dem, admin selv har bygget */}
            {egneIKategori.length > 0 && (
              <>
                <div className="text-[10px] uppercase tracking-widest font-bold text-emerald-700 pt-1">
                  Klubbens egne
                </div>
                {egneIKategori.map((tpl) => (
                  <div key={tpl.id} className="relative group">
                    <button
                      onClick={() => applyTemplate(
                        { title: tpl.title, points: tpl.points, difficulty: tpl.difficulty, description: tpl.description || "" },
                        tpl.category,
                        { spots: tpl.spots_total, time: tpl.time, location: tpl.location, durationType: tpl.duration_type, icon: tpl.icon }
                      )}
                      className="w-full text-left bg-emerald-50/60 hover:bg-emerald-50 border border-emerald-200 rounded-xl px-4 py-3 pr-11 transition-all"
                    >
                      <div className="flex items-start justify-between gap-2">
                        <span className="font-semibold text-[13px] text-stone-900 leading-snug">{tpl.title}</span>
                        <span className="shrink-0 text-[11px] font-black text-emerald-700 bg-emerald-100 px-2 py-0.5 rounded-full whitespace-nowrap">{tpl.points} pt</span>
                      </div>
                      <span className="inline-block mt-1 text-[10px] font-semibold px-1.5 py-0.5 rounded bg-stone-200 text-stone-600">{tpl.difficulty}</span>
                    </button>
                    <button
                      onClick={() => sletSkabelon(tpl.id)}
                      title="Slet skabelon"
                      className="absolute top-2.5 right-2.5 p-1.5 rounded-lg text-stone-400 hover:text-red-600 hover:bg-red-50"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                ))}
                <div className="text-[10px] uppercase tracking-widest font-bold text-stone-400 pt-3">
                  Appens forslag
                </div>
              </>
            )}

            {activeTplGroup.templates.map((tpl) => (
              <button key={tpl.title} onClick={() => applyTemplate(tpl, activeTplGroup.label)}
                className="w-full text-left bg-stone-50 hover:bg-emerald-50 border border-stone-200 hover:border-emerald-300 rounded-xl px-4 py-3 transition-all">
                <div className="flex items-start justify-between gap-2">
                  <span className="font-semibold text-[13px] text-stone-900 leading-snug">{tpl.title}</span>
                  <span className="shrink-0 text-[11px] font-black text-emerald-700 bg-emerald-100 px-2 py-0.5 rounded-full whitespace-nowrap">{tpl.points} pt</span>
                </div>
                <span className={`inline-block mt-1 text-[10px] font-semibold px-1.5 py-0.5 rounded ${tpl.difficulty === "Hård" ? "bg-pink-100 text-pink-700" : tpl.difficulty === "Medium" ? "bg-violet-100 text-violet-700" : "bg-stone-200 text-stone-600"}`}>{tpl.difficulty}</span>
              </button>
            ))}
          </div>
          {/* Footer: start from scratch */}
          <div className="sticky bottom-0 bg-white border-t border-stone-100 p-4 shrink-0">
            <button onClick={() => setStep("form")} className="w-full py-3 rounded-xl border border-stone-200 text-stone-700 font-semibold text-[14px] hover:bg-stone-50">
              Start fra bunden (ingen skabelon)
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 backdrop-blur-sm" onClick={onClose}>
      <div className="bg-white rounded-t-3xl w-full max-w-md max-h-[92vh] overflow-y-auto animate-slideup" onClick={(e) => e.stopPropagation()}>
        <div className="sticky top-0 bg-white border-b border-stone-100 px-5 pt-3 pb-3 flex items-center justify-between z-10">
          <div className="w-12 h-1 bg-stone-200 rounded-full absolute top-2 left-1/2 -translate-x-1/2" />
          <div className="flex items-center gap-2 mt-2">
            {isNew && <button onClick={() => setStep("pick")} className="p-1.5 hover:bg-stone-100 rounded-lg"><ChevronLeft className="w-5 h-5" /></button>}
            <h3 className="text-lg font-bold">{task ? "Rediger opgave" : "Ny opgave"}</h3>
          </div>
          <button onClick={onClose} className="p-1.5 hover:bg-stone-100 rounded-lg mt-2"><X className="w-5 h-5" /></button>
        </div>

        <div className="p-5 space-y-4 pb-28">
          <AdminInput label="Titel" placeholder="F.eks. Dommerbord – U15 kamp" value={title} onChange={(e) => setTitle(e.target.value)} />

          {/* Kategori + ikon */}
          <div>
            <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-2">Kategori og ikon</label>
            <div className="flex gap-2">
              <div className="relative flex-1 min-w-0">
                <select value={category} onChange={(e) => setCategory(e.target.value)}
                  className="w-full px-3 py-3 text-sm bg-stone-50 rounded-xl border border-stone-200 focus:border-emerald-500 outline-none appearance-none pr-8">
                  {categories.map((c) => <option key={c} value={c}>{c}</option>)}
                </select>
                <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-stone-400 pointer-events-none" />
              </div>
              {/* Ikonet foelger titlen af sig selv. Knappen er der for de
                  gange, hvor appen gaetter forkert — ikke som en pligt. */}
              <button
                type="button"
                onClick={() => setIkonAabent((v) => !v)}
                aria-label={`Ikon: ${ikonNavn(visIkon)}. Tryk for at vælge et andet`}
                className={`shrink-0 w-[52px] rounded-xl border flex flex-col items-center justify-center gap-0.5 transition-all ${ikonAabent ? "border-violet-400 bg-violet-50 text-violet-700" : "border-stone-200 bg-stone-50 text-stone-700 hover:border-stone-300"}`}
              >
                <CategoryIcon type={visIkon} className="w-5 h-5" />
                <span className="text-[8px] font-bold uppercase tracking-wide">Ikon</span>
              </button>
            </div>

            {!ikonAabent && (
              <p className="text-[11px] text-stone-400 mt-1.5 px-1">
                {ikonRoert
                  ? <>Ikon: <strong className="text-stone-600">{ikonNavn(visIkon)}</strong>. Tryk på det for at skifte.</>
                  : <>Appen vælger <strong className="text-stone-600">{ikonNavn(visIkon)}</strong> ud fra titlen. Tryk på ikonet for at vælge selv.</>}
              </p>
            )}

            {ikonAabent && (
              <div className="mt-2 border border-stone-200 rounded-xl p-3 bg-stone-50/60 max-h-64 overflow-y-auto">
                {!ikonRoert && (
                  <p className="text-[10px] text-stone-400 mb-2">
                    Appen har valgt <strong className="text-stone-600">{ikonNavn(visIkon)}</strong> ud fra titlen.
                  </p>
                )}
                {IKON_KATALOG.map((g) => (
                  <div key={g.gruppe} className="mb-3 last:mb-0">
                    <div className="text-[10px] uppercase tracking-widest font-bold text-stone-400 mb-1.5">{g.gruppe}</div>
                    <div className="grid grid-cols-4 gap-1.5">
                      {g.ikoner.map((ik) => {
                        const valgt = ik.id === visIkon;
                        return (
                          <button
                            key={ik.id}
                            type="button"
                            onClick={() => { setIcon(ik.id); setIkonRoert(true); setIkonAabent(false); }}
                            className={`flex flex-col items-center gap-1 py-2 px-1 rounded-lg border transition-all ${valgt ? "border-violet-400 bg-violet-50 text-violet-700" : "border-transparent bg-white text-stone-600 hover:border-stone-200"}`}
                          >
                            <CategoryIcon type={ik.id} className="w-5 h-5" />
                            <span className="text-[9px] font-semibold leading-tight text-center">{ik.navn}</span>
                          </button>
                        );
                      })}
                    </div>
                  </div>
                ))}
                {ikonRoert && (
                  <button
                    type="button"
                    onClick={() => { setIkonRoert(false); setIkonAabent(false); }}
                    className="w-full text-[11px] font-semibold text-stone-500 hover:text-stone-800 py-2"
                  >
                    Lad appen vælge ud fra titlen
                  </button>
                )}
              </div>
            )}
          </div>

          <TaskDatePicker value={dateISO} onChange={(iso) => {
            setDateISO(iso);
            const { date: d, dateEnd: de } = computeDateDisplay(iso, durationType);
            setDate(d); setDateEnd(de);
          }} />

          {/* Varighed */}
          {dateISO && (
            <div>
              <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-2">Varighed</label>
              <div className="grid grid-cols-2 gap-2">
                {DURATION_OPTIONS.map((opt) => (
                  <button key={opt.id} type="button"
                    onClick={() => {
                      setDuration(opt.id);
                      const { date: d, dateEnd: de } = computeDateDisplay(dateISO, opt.id);
                      setDate(d); setDateEnd(de);
                    }}
                    className={`px-3 py-2.5 rounded-xl border text-left transition-all ${durationType === opt.id ? "border-violet-400 bg-violet-50" : "border-stone-200 bg-stone-50 hover:border-stone-300"}`}>
                    <div className={`text-[12px] font-bold ${durationType === opt.id ? "text-violet-700" : "text-stone-800"}`}>{opt.label}</div>
                    <div className="text-[10px] text-stone-400 mt-0.5">{opt.desc}</div>
                  </button>
                ))}
              </div>
              {date && <p className="text-[11px] text-emerald-700 font-semibold mt-2 px-1">{date}</p>}
            </div>
          )}

          {durationType === "single" && <AdminInput label="Tidsrum" placeholder="10:00 – 12:00" value={time} onChange={(e) => setTime(e.target.value)} />}

          <AdminInput label="Lokation" placeholder="Bane 1, Arena Randers" icon={<MapPin className="w-4 h-4" />} value={location} onChange={(e) => setLocation(e.target.value)} />

          <div className="grid grid-cols-2 gap-3">
            <AdminInput label="Point" type="number" placeholder="15" icon={<Zap className="w-4 h-4" />} value={visPoints}
              onChange={(e) => { setPointRoert(true); setPoints(e.target.value); }} />
            <AdminInput label="Pladser" type="number" placeholder="2" icon={<Users className="w-4 h-4" />} value={spots} onChange={(e) => setSpots(e.target.value)} />
          </div>

          {/* Forslaget. Uden om vejen: har admin ikke roert tallet, staar det
              allerede paa forslaget, og saa er der ikke noget at sige. Har de
              skrevet noget andet, faar de forslaget at se — men vi retter
              ikke i deres tal uden at spoerge. */}
          {!pointRoert ? (
            <p className="text-[11px] text-stone-400 -mt-1 leading-relaxed">
              Foreslået ud fra <strong>{difficulty.toLowerCase()}</strong> og{" "}
              <strong>{(DURATION_OPTIONS.find((d) => d.id === durationType)?.label || "enkelt dag").toLowerCase()}</strong>.
              Skriv et andet tal, hvis opgaven fortjener det.
            </p>
          ) : forslagAfviger ? (
            <button
              type="button"
              onClick={() => setPoints(forslag)}
              className="w-full -mt-1 text-left bg-stone-50 hover:bg-stone-100 border border-stone-200 rounded-xl px-3 py-2 flex items-center gap-2"
            >
              <Zap className="w-3.5 h-3.5 text-stone-400 shrink-0" />
              <span className="text-[11px] text-stone-600 flex-1">
                Klubben plejer at give <strong className="text-stone-900">{forslag} point</strong> for{" "}
                {difficulty.toLowerCase()} · {(DURATION_OPTIONS.find((d) => d.id === durationType)?.label || "enkelt dag").toLowerCase()}
              </span>
              <span className="text-[11px] font-bold text-emerald-700 shrink-0">Brug</span>
            </button>
          ) : null}

          {pointsChanged && affected > 0 && (
            <div className="bg-amber-50 border border-amber-200 rounded-xl p-3 flex gap-2.5">
              <AlertTriangle className="w-4 h-4 text-amber-700 shrink-0 mt-0.5" />
              <p className="text-[11px] text-amber-900 leading-relaxed">
                <strong>{affected}</strong> {affected === 1 ? "person står" : "personer står"} allerede på opgaven.
                Ændrer du pointtallet fra {task.points} til {parseInt(visPoints) || 0}, følger deres point med
                {claimCounts.completed > 0 && <> — og {claimCounts.completed === 1 ? "den ene, der allerede er godkendt, får" : `de ${claimCounts.completed} der allerede er godkendt, får`} summen justeret og besked om det</>}.
              </p>
            </div>
          )}

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

        <div className="sticky bottom-0 bg-white border-t border-stone-100 p-4 space-y-2">
          {tplBesked && (
            <div className={`rounded-xl px-3 py-2 text-[12px] font-semibold ${
              tplBesked.type === "ok" ? "bg-emerald-50 text-emerald-800 border border-emerald-200"
                                      : "bg-red-50 text-red-800 border border-red-200"}`}>
              {tplBesked.text}
            </div>
          )}

          {/* Gem den udfyldte opgave til naeste gang. Kraever kun en titel —
              dato og tidspunkt er netop det, en skabelon IKKE skal huske. */}
          <button
            onClick={gemSomSkabelon}
            disabled={!title.trim() || gemmerTpl}
            className="w-full py-2.5 rounded-xl border border-stone-200 text-stone-700 font-semibold text-[13px] flex items-center justify-center gap-2 disabled:opacity-50 hover:bg-stone-50"
          >
            <Copy className="w-4 h-4 text-stone-500" />
            {gemmerTpl ? "Gemmer..." : `Gem som skabelon i "${category}"`}
          </button>

          <div className="flex gap-2">
            <button onClick={onClose} className="flex-1 py-3 rounded-xl bg-stone-100 text-stone-700 font-semibold">Annullér</button>
            <button onClick={handleSave} disabled={!title.trim() || !dateISO} className="flex-[2] py-3 rounded-xl text-white font-bold shadow-lg disabled:opacity-50 flex items-center justify-center gap-2" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
              <Save className="w-4 h-4" />{task ? "Gem ændringer" : "Opret opgave"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

// ---- MEDLEMMER ----
// ---- HJÆLPER-KOBLING ----
//
// En hjælper er en forælder, en kæreste, en nabo: nogen der tager tjanser for
// et medlem. Pointene flytter IKKE. De bliver liggende hos hjælperen på
// ranglisten — men tæller mod frivilligbidraget hos medlemmet.
//
// Databasen har reglerne, og de er hårde: kun admins kobler, en konto med
// point kan ikke gøres til hjælper, og der er ingen kæder. Skærmen her siger
// dem højt FØR man trykker, så man ikke render ind i en fejlbesked.
const HjaelperModal = ({ target, alle, currentUser, onClose, onChanged }) => {
  const [koblet, setKoblet]   = useState([]);
  const [busy, setBusy]       = useState(null);
  const [error, setError]     = useState(null);
  const [indlaest, setIndlaest] = useState(false);

  useEffect(() => {
    supabase.from("helper_links").select("member_id").eq("helper_id", target.id).then(({ data, error: e }) => {
      if (e) setError(`Kunne ikke hente koblinger: ${e.message}`);
      setKoblet((data || []).map((r) => r.member_id));
      setIndlaest(true);
    });
  }, [target.id]);

  // Spærren, der lukker døren mellem to medlemmer: har man selv tjent point,
  // kan man ikke blive hjælper — og så kan man heller ikke begynde at sende
  // point videre til en anden.
  const harPoint = !target.erHjaelper && (target.points || 0) > 0;

  const muligeMedlemmer = alle.filter((m) =>
    m.id !== target.id && m.approved && !m.erHjaelper);

  const slaaTil = async (medlem, til) => {
    setBusy(medlem.id); setError(null);
    const { error: e } = await supabase.rpc("admin_set_helper", {
      p_helper: target.id, p_member: medlem.id, p_on: til,
    });
    setBusy(null);
    if (e) { setError(e.message); return; }
    setKoblet((k) => til ? [...k, medlem.id] : k.filter((x) => x !== medlem.id));
    logAction("member",
      til ? `Koblede ${target.name} som hjælper for ${medlem.name}`
          : `Fjernede ${target.name} som hjælper for ${medlem.name}`, currentUser);
    onChanged?.();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 backdrop-blur-sm px-4 pb-8" onClick={onClose}>
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm overflow-hidden max-h-[85vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
        <div className="px-5 pt-5 pb-4">
          <div className="text-[15px] font-bold text-stone-900">Hjælper-kobling</div>
          <p className="text-[13px] text-stone-500 mt-0.5 mb-3">
            <span className="font-semibold text-stone-800">{target.name}</span> tager tjanser for …
          </p>

          {target.helperRequest && (
            <div className="bg-amber-50 border border-amber-200 rounded-xl p-3 mb-3">
              <div className="text-[12px] text-amber-900 leading-relaxed">
                Har selv skrevet ved oprettelsen: <strong>«{target.helperRequest}»</strong>
              </div>
            </div>
          )}

          {harPoint ? (
            <div className="bg-red-50 border border-red-200 rounded-xl p-3">
              <p className="text-[12px] text-red-900 leading-relaxed">
                <strong>{target.name} har allerede optjent {target.points} point som medlem</strong> og kan
                derfor ikke gøres til hjælper. Reglen er der for at point ikke kan deles mellem to
                medlemmer. Er det en fejl, skal pointene fratrækkes først.
              </p>
            </div>
          ) : !indlaest ? (
            <p className="text-[12px] text-stone-400">Henter…</p>
          ) : muligeMedlemmer.length === 0 ? (
            <p className="text-[12px] text-stone-500">Der er ingen godkendte medlemmer at koble til.</p>
          ) : (
            <div className="space-y-1.5">
              {muligeMedlemmer.map((m) => {
                const til = koblet.includes(m.id);
                return (
                  <button key={m.id} onClick={() => slaaTil(m, !til)} disabled={busy === m.id}
                    className={`w-full flex items-center justify-between px-3 py-2.5 rounded-xl border text-left transition-all disabled:opacity-50 ${til ? "bg-emerald-50 border-emerald-300" : "bg-white border-stone-200"}`}>
                    <div className="min-w-0">
                      <div className="text-[13px] font-semibold text-stone-900 truncate">{m.name}</div>
                      <div className="text-[11px] text-stone-500 truncate">{m.team || "uden hold"} · {m.bidrag} bidragspoint</div>
                    </div>
                    <span className={`shrink-0 text-[11px] font-bold ${til ? "text-emerald-700" : "text-stone-400"}`}>
                      {busy === m.id ? "…" : til ? "Koblet ✓" : "Kobl"}
                    </span>
                  </button>
                );
              })}
            </div>
          )}

          {error && (
            <div className="bg-red-50 border border-red-200 rounded-xl p-3 mt-3">
              <p className="text-[12px] text-red-800">{error}</p>
            </div>
          )}

          <p className="text-[11px] text-stone-400 mt-3 leading-relaxed">
            Hjælperen beholder sine egne point på ranglisten. Tjanserne tæller mod
            frivilligbidraget hos det medlem, hjælperen vælger ved hver tjans.
            Fjernes koblingen, bliver de point, der allerede er givet, hvor de er.
          </p>

          <button onClick={onClose} className="w-full mt-4 py-2.5 rounded-xl bg-stone-100 text-stone-700 text-[13px] font-bold">
            Luk
          </button>
        </div>
      </div>
    </div>
  );
};

const AdminMembers = ({ currentUserRole, currentUser }) => {
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState("all");
  const [menuOpen, setMenuOpen] = useState(null);
  const [allMembers, setAllMembers] = useState([]);
  const [memberTasksTarget, setMemberTasksTarget] = useState(null);
  const [hjaelperTarget, setHjaelperTarget] = useState(null);
  const isSuperAdmin = currentUserRole === "super_admin";

  // Delete flow
  const [deleteTarget, setDeleteTarget] = useState(null);
  const [deleteStep, setDeleteStep] = useState(1);
  const [deleteReason, setDeleteReason] = useState("");
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState(null);

  const openDelete = (member) => { setDeleteTarget(member); setDeleteStep(1); setDeleteReason(""); setDeleteError(null); setMenuOpen(null); };
  const closeDelete = () => { if (deleting) return; setDeleteTarget(null); setDeleteReason(""); setDeleteError(null); };

  const confirmDelete = async () => {
    if (!deleteTarget) return;
    setDeleting(true); setDeleteError(null);

    // Sletter BÅDE profilen og login'et. Før blev kun profilrækken fjernet,
    // så e-mailen blev liggende i Supabase Auth, og personen kunne hverken
    // bruge appen eller oprette sig igen.
    const { data, error } = await supabase.functions.invoke("delete-member", {
      body: { user_id: deleteTarget.id, reason: deleteReason },
    });
    setDeleting(false);

    if (error || data?.error) {
      setDeleteError(
        (data?.error || error.message) +
        " – er delete-member-funktionen rullet ud? (supabase functions deploy delete-member)"
      );
      return;
    }

    setAllMembers((prev) => prev.filter((m) => m.id !== deleteTarget.id));
    setDeleteTarget(null);
  };

  // Promote flow
  const [promoteTarget, setPromoteTarget] = useState(null);
  const [promoting, setPromoting] = useState(false);
  const [promoteError, setPromoteError] = useState(null);

  const openPromote = (member) => { setPromoteTarget(member); setMenuOpen(null); };
  const closePromote = () => { if (promoting) return; setPromoteTarget(null); };

  const confirmPromote = async () => {
    if (!promoteTarget) return;
    setPromoting(true); setPromoteError(null);
    const { error: err } = await supabase.rpc("admin_set_role", { p_user: promoteTarget.id, p_role: "admin" });
    setPromoting(false);
    if (err) { setPromoteError(err.message); return; }
    logAction("role_change", `Gav ${promoteTarget.name} admin-rolle`, currentUser);
    setAllMembers((prev) => prev.map((m) => m.id === promoteTarget.id ? { ...m, role: "admin" } : m));
    setPromoteTarget(null);
  };

  // Bonus/deduct points flow
  const [bonusTarget, setBonusTarget]   = useState(null);
  const [bonusMode,   setBonusMode]     = useState("add"); // "add" | "deduct"
  const [bonusPoints, setBonusPoints]   = useState("");
  const [bonusReason, setBonusReason]   = useState("");
  const [bonusSaving, setBonusSaving]   = useState(false);
  const [bonusError,  setBonusError]    = useState(null);

  const openBonus  = (m, mode = "add") => { setBonusTarget(m); setBonusMode(mode); setBonusPoints(""); setBonusReason(""); setBonusError(null); setMenuOpen(null); };
  const closeBonus = () => { if (bonusSaving) return; setBonusTarget(null); };

  const confirmBonus = async () => {
    const pts = parseInt(bonusPoints);
    if (!bonusTarget || isNaN(pts) || pts <= 0) return;
    setBonusSaving(true); setBonusError(null);
    // Bonuspoint holdes adskilt fra opgavepoint i databasen, så regnskabet
    // kan genberegnes fra tilmeldingerne uden at bonusser går tabt.
    const { data: newTotal, error: err } = await supabase.rpc("admin_adjust_points", {
      p_user: bonusTarget.id,
      p_delta: bonusMode === "add" ? pts : -pts,
    });
    setBonusSaving(false);
    if (err) { setBonusError("Fejl: " + err.message); return; }
    const actionText = bonusMode === "add"
      ? `Tildelte ${pts} bonuspoint til ${bonusTarget.name} – årsag: ${bonusReason}`
      : `Fratrakte ${pts} point fra ${bonusTarget.name} – årsag: ${bonusReason}`;
    logAction("member", actionText, currentUser);
    setAllMembers((prev) => prev.map((m) => m.id === bonusTarget.id ? { ...m, points: newTotal } : m));
    setBonusTarget(null);
  };

  // Målet stod hårdkodet til 100 her, mens klubben kører 200. Nu læses det,
  // og det er bidragstallet, der måles — ikke ranglistens point.
  const [goal, setGoal] = useState(200);

  const hentMedlemmer = () => {
    supabase.rpc("admin_list_members").then(({ data }) => {
      if (data && data.length > 0) {
        setAllMembers(data.map((p) => ({
          id: p.id, name: p.name, email: p.email || "",
          initials: p.initials || p.name.split(" ").map((n) => n[0]).slice(0, 2).join("").toUpperCase(),
          team: p.team || "", points: p.points || 0, tasksDone: p.tasks_done || 0, role: p.role,
          bidrag: p.bidrag ?? p.points ?? 0,
          fraHjaelpere: p.fra_hjaelpere ?? 0,
          erHjaelper: p.er_hjaelper === true,
          hjaelperFor: p.hjaelper_for || "",
          helperRequest: p.helper_request || "",
          approved: p.approved,
        })));
      }
    });
  };

  useEffect(() => {
    hentMedlemmer();
    supabase.from("settings").select("key,value").then(({ data }) => {
      const g = parseInt((data || []).find((r) => r.key === "point_goal")?.value, 10);
      if (Number.isFinite(g) && g > 0) setGoal(g);
    });
     
  }, []);

  const filtered = allMembers.filter((m) => {
    if (query && !m.name.toLowerCase().includes(query.toLowerCase())) return false;
    // Hjælpere har ikke noget mål og hører hverken under "bagud" eller "nået".
    if (filter === "helpers" && !m.erHjaelper) return false;
    if (filter === "behind"  && (m.erHjaelper || m.bidrag >= goal / 2)) return false;
    if (filter === "reached" && (m.erHjaelper || m.bidrag < goal))      return false;
    return true;
  });

  return (
    <div className="space-y-3">
      <div className="flex items-center gap-2 bg-white rounded-xl px-3 py-2.5 border border-stone-200 shadow-sm">
        <Search className="w-4 h-4 text-stone-400" />
        <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Søg medlem..." className="flex-1 bg-transparent outline-none text-sm" />
      </div>
      <ScrollRow className="flex gap-2 overflow-x-auto -mx-5 px-5 pb-1 scrollbar-hide">
        {[["all","Alle"],["reached","Nået mål"],["behind","Bagud"],["helpers","Hjælpere"]].map(([id,label]) => (
          <button key={id} onClick={() => setFilter(id)} className={`shrink-0 px-3 py-1.5 rounded-full text-[12px] font-semibold transition-all ${filter === id ? "text-white" : "bg-white text-stone-700 border border-stone-200"}`} style={filter === id ? { background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` } : {}}>{label}</button>
        ))}
      </ScrollRow>
      <div className="bg-white rounded-2xl border border-stone-100 divide-y divide-stone-100 shadow-sm">
        {filtered.map((m) => {
          const reached = !m.erHjaelper && m.bidrag >= goal;
          const behind  = !m.erHjaelper && m.bidrag < goal / 2;
          return (
            <div key={m.id} className="flex items-center gap-3 px-4 py-3 relative">
              <div className="w-10 h-10 rounded-full flex items-center justify-center font-bold text-white text-xs shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>{m.initials}</div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-1.5">
                  <div className="font-semibold text-[14px] text-stone-900 truncate">{m.name}</div>
                  <RoleBadge role={m.role} />
                  {m.erHjaelper && (
                    <span className="shrink-0 text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200">Hjælper</span>
                  )}
                  {!m.erHjaelper && m.helperRequest && (
                    <span className="shrink-0 text-[9px] font-bold uppercase tracking-wide px-1.5 py-0.5 rounded-full bg-amber-50 text-amber-800 border border-amber-200">Ønsker kobling</span>
                  )}
                </div>
                <div className="text-[11px] text-stone-500 truncate">
                  {m.erHjaelper
                    ? `Hjælper for ${m.hjaelperFor} · ${m.tasksDone} opgaver`
                    : `${m.team ? `${m.team} · ` : ""}${m.tasksDone} opgaver${m.fraHjaelpere > 0 ? ` · +${m.fraHjaelpere} pt fra hjælper` : ""}`}
                </div>
              </div>
              {m.erHjaelper ? (
                <div className="text-[14px] font-black mr-1 text-stone-500 text-right">{m.points}<div className="text-[9px] text-stone-400 uppercase font-bold">egne pt</div></div>
              ) : (
                <div className={`text-[14px] font-black mr-1 ${reached ? "text-emerald-600" : behind ? "text-pink-600" : "text-stone-900"}`}>{m.bidrag}<div className="text-[9px] text-stone-400 uppercase font-bold">/ {goal}</div></div>
              )}
              <div className="relative">
                <button onClick={() => setMenuOpen(menuOpen === m.id ? null : m.id)} className="p-1 hover:bg-stone-100 rounded-lg"><MoreVertical className="w-4 h-4 text-stone-500" /></button>
                {menuOpen === m.id && (
                  <div className="absolute top-full right-0 mt-0 bg-white rounded-xl shadow-xl border border-stone-100 py-1 w-48 z-30">
                    <MenuButton icon={<ListChecks className="w-3.5 h-3.5" />} label="Se opgaver" onClick={() => { setMemberTasksTarget(m); setMenuOpen(null); }} />
                    <MenuButton icon={<Mail className="w-3.5 h-3.5" />} label="Send besked" onClick={() => { setMenuOpen(null); if (m.email) window.location.href = `mailto:${m.email}?subject=RVK Frivillig`; }} />
                    <MenuButton icon={<Plus className="w-3.5 h-3.5" />} label="Tildel ekstra point" onClick={() => openBonus(m, "add")} />
                    <MenuButton icon={<X className="w-3.5 h-3.5" />} label="Fratræk point" onClick={() => openBonus(m, "deduct")} />
                    <div className="h-px bg-stone-100 my-1" />
                    <MenuButton icon={<Users className="w-3.5 h-3.5" />} label={m.erHjaelper ? "Ret hjælper-kobling" : "Gør til hjælper"} onClick={() => { setHjaelperTarget(m); setMenuOpen(null); }} />
                    {isSuperAdmin && m.role === "user" && <><div className="h-px bg-stone-100 my-1" /><MenuButton icon={<ShieldCheck className="w-3.5 h-3.5" />} label="Gør til Admin" onClick={() => openPromote(m)} /></>}
                    {isSuperAdmin && <><div className="h-px bg-stone-100 my-1" /><MenuButton icon={<Trash2 className="w-3.5 h-3.5" />} label="Slet (GDPR)" danger onClick={() => openDelete(m)} /></>}
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Bonus points modal */}
      {bonusTarget && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 backdrop-blur-sm px-4 pb-8" onClick={closeBonus}>
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm overflow-hidden" onClick={(e) => e.stopPropagation()}>
            <div className="px-5 pt-6 pb-4">
              {/* Add/Deduct toggle */}
              <div className="flex bg-stone-100 rounded-xl p-1 mb-4">
                <button onClick={() => setBonusMode("add")} className={`flex-1 py-1.5 rounded-lg text-[13px] font-bold transition-all flex items-center justify-center gap-1.5 ${bonusMode === "add" ? "bg-white shadow text-emerald-700" : "text-stone-500"}`}>
                  <Plus className="w-3.5 h-3.5" />Tildel
                </button>
                <button onClick={() => setBonusMode("deduct")} className={`flex-1 py-1.5 rounded-lg text-[13px] font-bold transition-all flex items-center justify-center gap-1.5 ${bonusMode === "deduct" ? "bg-white shadow text-red-600" : "text-stone-500"}`}>
                  <X className="w-3.5 h-3.5" />Fratræk
                </button>
              </div>

              <div className={`w-12 h-12 rounded-full flex items-center justify-center mx-auto mb-3 ${bonusMode === "add" ? "bg-emerald-100" : "bg-red-100"}`}>
                <Zap className={`w-6 h-6 ${bonusMode === "add" ? "text-emerald-600" : "text-red-500"}`} />
              </div>
              <h3 className="font-bold text-[16px] text-stone-900 mb-1 text-center">
                {bonusMode === "add" ? "Tildel ekstra point" : "Fratræk point"}
              </h3>
              <p className="text-[13px] text-stone-500 mb-4 text-center">
                {bonusMode === "add" ? "Til" : "Fra"} <span className="font-semibold text-stone-800">{bonusTarget.name}</span> (har {bonusTarget.points || 0} pt)
                {bonusMode === "deduct" && parseInt(bonusPoints) > 0 && (
                  <span className="block text-red-500 font-semibold mt-0.5">
                    → vil have {Math.max(0, (bonusTarget.points || 0) - parseInt(bonusPoints))} pt tilbage
                  </span>
                )}
              </p>
              <div className="space-y-3">
                <div>
                  <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-1.5">
                    {bonusMode === "add" ? "Antal bonuspoint" : "Antal point der fratrækkes"}
                  </label>
                  <input type="number" min="1" value={bonusPoints} onChange={(e) => setBonusPoints(e.target.value)}
                    placeholder="F.eks. 10" className="w-full px-3 py-2.5 text-sm bg-stone-50 rounded-xl border border-stone-200 focus:border-emerald-500 outline-none" />
                </div>
                <div>
                  <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-1.5">Årsag (påkrævet)</label>
                  <input value={bonusReason} onChange={(e) => setBonusReason(e.target.value)}
                    placeholder="F.eks. Ekstra hjælp til stævne" className="w-full px-3 py-2.5 text-sm bg-stone-50 rounded-xl border border-stone-200 focus:border-emerald-500 outline-none" />
                </div>
                {bonusError && <p className="text-[12px] text-red-600">{bonusError}</p>}
              </div>
            </div>
            <div className="px-5 pb-5 flex gap-2">
              <button onClick={closeBonus} disabled={bonusSaving} className="flex-1 py-2.5 rounded-xl border border-stone-200 text-[14px] font-semibold text-stone-700 disabled:opacity-50">Annuller</button>
              <button onClick={confirmBonus} disabled={bonusSaving || !bonusPoints || !bonusReason.trim()} className="flex-1 py-2.5 rounded-xl text-white text-[14px] font-semibold disabled:opacity-40" style={{ background: bonusMode === "add" ? `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` : "linear-gradient(135deg, #ef4444, #dc2626)" }}>
                {bonusSaving ? "Gemmer…" : bonusMode === "add" ? "Tildel point" : "Fratræk point"}
              </button>
            </div>
          </div>
        </div>
      )}

      {memberTasksTarget && <MemberTasksModal member={memberTasksTarget} onClose={() => setMemberTasksTarget(null)} />}

      {hjaelperTarget && (
        <HjaelperModal
          target={hjaelperTarget}
          alle={allMembers}
          currentUser={currentUser}
          onClose={() => setHjaelperTarget(null)}
          onChanged={hentMedlemmer}
        />
      )}

      {/* Promote to admin modal */}
      {promoteTarget && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 backdrop-blur-sm px-4 pb-8" onClick={closePromote}>
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm overflow-hidden" onClick={(e) => e.stopPropagation()}>
            <div className="px-5 pt-6 pb-4 text-center">
              <div className="w-12 h-12 rounded-full bg-violet-100 flex items-center justify-center mx-auto mb-3"><ShieldCheck className="w-6 h-6 text-violet-600" /></div>
              <h3 className="font-bold text-[16px] text-stone-900 mb-1">Gør til Admin?</h3>
              <p className="text-[13px] text-stone-500"><span className="font-semibold text-stone-800">{promoteTarget.name}</span> får adgang til admin-panelet og kan oprette/slette opgaver og godkende medlemmer.</p>
              {promoteError && <p className="text-[12px] text-red-600 mt-3 bg-red-50 border border-red-200 rounded-lg px-3 py-2">{promoteError}</p>}
            </div>
            <div className="px-5 pb-5 flex gap-2">
              <button onClick={closePromote} disabled={promoting} className="flex-1 py-2.5 rounded-xl border border-stone-200 text-[14px] font-semibold text-stone-700 disabled:opacity-50">Annuller</button>
              <button onClick={confirmPromote} disabled={promoting} className="flex-1 py-2.5 rounded-xl text-white text-[14px] font-semibold disabled:opacity-50" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
                {promoting ? "Gemmer…" : "Giv admin-adgang"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete confirmation modal */}
      {deleteTarget && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 backdrop-blur-sm px-4 pb-8" onClick={closeDelete}>
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm overflow-hidden" onClick={(e) => e.stopPropagation()}>
            {deleteStep === 1 ? (
              <>
                <div className="px-5 pt-6 pb-4 text-center">
                  <div className="w-12 h-12 rounded-full bg-red-100 flex items-center justify-center mx-auto mb-3"><Trash2 className="w-6 h-6 text-red-600" /></div>
                  <h3 className="font-bold text-[16px] text-stone-900 mb-1">Slet medlem?</h3>
                  <p className="text-[13px] text-stone-500">Du er ved at slette <span className="font-semibold text-stone-800">{deleteTarget.name}</span> permanent. Både profil, login, tilmeldinger og beskeder fjernes (GDPR).</p>
                </div>
                <div className="px-5 pb-5 flex gap-2">
                  <button onClick={closeDelete} className="flex-1 py-2.5 rounded-xl border border-stone-200 text-[14px] font-semibold text-stone-700">Annuller</button>
                  <button onClick={() => setDeleteStep(2)} className="flex-1 py-2.5 rounded-xl bg-red-600 text-white text-[14px] font-semibold">Ja, fortsæt</button>
                </div>
              </>
            ) : (
              <>
                <div className="px-5 pt-6 pb-4">
                  <div className="w-12 h-12 rounded-full bg-red-100 flex items-center justify-center mx-auto mb-3"><Trash2 className="w-6 h-6 text-red-600" /></div>
                  <h3 className="font-bold text-[16px] text-stone-900 mb-1 text-center">Bekræft sletning</h3>
                  <p className="text-[13px] text-stone-500 mb-4 text-center">Angiv årsag til sletning af <span className="font-semibold text-stone-800">{deleteTarget.name}</span>. Dette kan ikke fortrydes.</p>
                  <textarea
                    value={deleteReason}
                    onChange={(e) => setDeleteReason(e.target.value)}
                    placeholder="Årsag til sletning (påkrævet)..."
                    rows={3}
                    className="w-full border border-stone-200 rounded-xl px-3 py-2.5 text-[13px] outline-none focus:ring-2 focus:ring-red-300 resize-none"
                  />
                  {deleteError && <p className="text-[12px] text-red-600 mt-1">{deleteError}</p>}
                </div>
                <div className="px-5 pb-5 flex gap-2">
                  <button onClick={closeDelete} disabled={deleting} className="flex-1 py-2.5 rounded-xl border border-stone-200 text-[14px] font-semibold text-stone-700 disabled:opacity-50">Annuller</button>
                  <button onClick={confirmDelete} disabled={deleting || deleteReason.trim().length < 5} className="flex-1 py-2.5 rounded-xl bg-red-600 text-white text-[14px] font-semibold disabled:opacity-40">
                    {deleting ? "Sletter…" : "Slet permanent"}
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

// ---- HOLD (kun Super Admin) ----
const AdminTeams = () => {
  const [teams, setTeams] = useState([]);
  const [newName, setNewName] = useState("");
  const [editing, setEditing] = useState(null);
  const [editValue, setEditValue] = useState("");
  const [error, setError] = useState(null);
  const [adding, setAdding] = useState(false);

  const reload = () => {
    supabase.from("teams").select("*").order("name").then(({ data }) => {
      if (data) setTeams(data);
    });
  };

  useEffect(() => { reload(); }, []);

  const addTeam = async () => {
    const name = newName.trim();
    if (!name) return;
    setAdding(true);
    setError(null);
    const { error: err } = await supabase.from("teams").insert({ name });
    setAdding(false);
    if (err) { setError("Kunne ikke tilføje: " + err.message); return; }
    setNewName("");
    reload();
  };

  const saveEdit = async (id, oldName) => {
    const name = editValue.trim();
    if (!name || name === oldName) { setEditing(null); return; }
    const { error: err } = await supabase.from("teams").update({ name }).eq("id", id);
    if (err) { setError("Kunne ikke omdøbe: " + err.message); return; }
    await supabase.from("profiles").update({ team: name }).eq("team", oldName);
    setEditing(null);
    reload();
  };

  const deleteTeam = async (id) => {
    if (!confirm("Er du sikker? Hold kan ikke gendannes.")) return;
    const { error: err } = await supabase.from("teams").delete().eq("id", id);
    if (err) { setError("Kunne ikke slette: " + err.message); return; }
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
            onChange={(e) => { setNewName(e.target.value); setError(null); }}
            onKeyDown={(e) => e.key === "Enter" && addTeam()}
            placeholder="F.eks. Damer 4"
            className="flex-1 bg-stone-50 border border-stone-200 rounded-xl px-3 py-2.5 text-sm outline-none focus:border-emerald-500 focus:bg-white"
          />
          <button onClick={addTeam} disabled={!newName.trim() || adding} className="px-4 py-2.5 rounded-xl text-white text-sm font-bold disabled:opacity-50 flex items-center gap-1.5" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
            {adding ? <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" /> : <Plus className="w-4 h-4" />}Tilføj
          </button>
        </div>
        {error && <p className="text-[12px] text-pink-600 mt-2 font-medium">{error}</p>}
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
const AdminRoles = ({ currentUser }) => {
  const [members, setMembers] = useState([]);
  const [roleError, setRoleError] = useState(null);

  const reload = () => {
    supabase.rpc("admin_list_members").then(({ data }) => {
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

  // Rolleændringer går gennem admin_set_role(), der både tjekker at kalderen
  // er super admin, og at klubben aldrig ender uden én.
  const promote = async (id, role) => {
    const target = members.find((m) => m.id === id);
    const { error } = await supabase.rpc("admin_set_role", { p_user: id, p_role: role });
    if (error) { setRoleError(`Kunne ikke tildele rolle: ${error.message}`); return; }
    setMembers((prev) => prev.map((m) => m.id === id ? { ...m, role, adminRequested: false } : m));
    logAction("role_change", `Gav ${target?.name} rollen "${role}"`, currentUser);
    setRoleError(null);
  };
  const demote = async (id) => {
    const target = members.find((m) => m.id === id);
    const { error } = await supabase.rpc("admin_set_role", { p_user: id, p_role: "user" });
    if (error) { setRoleError(`Kunne ikke fjerne rolle: ${error.message}`); return; }
    setMembers((prev) => prev.map((m) => m.id === id ? { ...m, role: "user" } : m));
    logAction("role_change", `Fjernede admin-rolle fra ${target?.name}`, currentUser);
    setRoleError(null);
  };
  const rejectRequest = async (id) => {
    const target = members.find((m) => m.id === id);
    const { error } = await supabase.rpc("admin_dismiss_request", { p_user: id });
    if (error) { setRoleError(`Fejl: ${error.message}`); return; }
    setMembers((prev) => prev.map((m) => m.id === id ? { ...m, adminRequested: false } : m));
    logAction("role_change", `Afslog admin-anmodning fra ${target?.name}`, currentUser);
    setRoleError(null);
  };

  return (
    <div className="space-y-4">
      <div className="rounded-2xl p-4 text-white" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
        <div className="flex items-start gap-3">
          <Crown className="w-5 h-5 shrink-0 mt-0.5" fill="white" />
          <div><div className="font-bold text-[14px]">Du er Super Admin</div><p className="text-[12px] text-white/90 mt-0.5 leading-relaxed">Udnæv og fjern Admins. Alle ændringer logges permanent i audit-loggen.</p></div>
        </div>
      </div>

      {roleError && (
        <div className="bg-red-50 border border-red-200 rounded-xl p-3 flex items-start gap-2">
          <AlertTriangle className="w-4 h-4 text-red-600 shrink-0 mt-0.5" />
          <div>
            <p className="text-[12px] text-red-900 font-semibold">{roleError}</p>
            <p className="text-[11px] text-red-700 mt-0.5">Kør <strong>supabase_profiles_rls.sql</strong> i Supabase SQL Editor for at give admins rettigheder til at ændre profiler.</p>
          </div>
        </div>
      )}

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

// ---- CSV ----
//
// To ting går galt, hvis man skriver CSV naivt til danske brugere:
//
//   1. Åbner man en UTF-8-fil i Excel uden BOM, bliver æ, ø og å til volapyk.
//      De tre bytes forrest fortæller Excel, hvad den har med at gøre.
//   2. Dansk Excel bruger semikolon som listeseparator, ikke komma. Med komma
//      lander hele rækken i én kolonne, og så er filen ubrugelig uden
//      importguiden.
//
// Derfor: semikolon og BOM. Filen åbner korrekt ved dobbeltklik i dansk
// Excel, Numbers og Google Sheets.
const csvCell = (v) => {
  if (v === null || v === undefined) return "";
  if (typeof v === "boolean") return v ? "ja" : "nej";
  const s = String(v);
  return /[";\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

const toCSV = (headers, rows) =>
  [headers.map(csvCell).join(";"), ...rows.map((r) => r.map(csvCell).join(";"))].join("\r\n");

const downloadCSV = (filename, csv) => {
  const blob = new Blob(["\uFEFF" + csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  // Uden revoke bliver filen liggende i hukommelsen, til fanen lukkes.
  setTimeout(() => URL.revokeObjectURL(url), 1000);
};

const today = () => isoLokal(new Date());

// ---- EKSPORT AF KLUBDATA ----
//
// Kun super admins. Filerne indeholder medlemmernes kontaktoplysninger, så
// hver eksport skrives i audit-loggen: hvem hentede hvad, og hvornår.
const ExportItem = ({ id, busy, done, title, desc, onClick }) => (
  <button
    onClick={onClick}
    disabled={busy !== null}
    className="w-full flex items-center justify-between px-4 py-3 bg-stone-50 hover:bg-stone-100 rounded-xl text-left disabled:opacity-50"
  >
    <div className="min-w-0 pr-3">
      <div className="text-[13px] font-semibold text-stone-800">{title}</div>
      <div className="text-[11px] text-stone-500 leading-snug">{desc}</div>
    </div>
    {busy === id
      ? <div className="w-4 h-4 border-2 border-stone-300 border-t-stone-600 rounded-full animate-spin shrink-0" />
      : done.includes(id)
        ? <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
        : <Download className="w-4 h-4 text-stone-500 shrink-0" />}
  </button>
);

const ExportModal = ({ currentUser, onClose }) => {
  const [busy, setBusy]   = useState(null);
  const [error, setError] = useState(null);
  const [done, setDone]   = useState([]);

  const run = async (key, label, build) => {
    setBusy(key);
    setError(null);
    try {
      const { filename, headers, rows } = await build();
      if (!rows.length) { setError(`Der er ingen ${label.toLowerCase()} at eksportere endnu.`); return; }
      downloadCSV(filename, toCSV(headers, rows));
      await logAction("settings", `Eksporterede ${label.toLowerCase()} (${rows.length} rækker)`, currentUser);
      setDone((d) => [...d, key]);
    } catch (e) {
      setError(e.message || "Kunne ikke hente data");
    } finally {
      setBusy(null);
    }
  };

  const exportMembers = () => run("members", "Medlemsliste", async () => {
    const { data, error: e } = await supabase.rpc("admin_list_members");
    if (e) throw e;
    return {
      filename: `rvk-medlemmer-${today()}.csv`,
      headers: ["Navn", "Hold", "Rolle", "Egne point", "Bidragspoint", "Heraf fra hjaelpere",
                "Er hjaelper", "Hjaelper for", "Tjanser", "Godkendt", "E-mail", "Telefon", "Oprettet"],
      rows: (data || []).map((m) => [
        m.name, m.team, m.role, m.points, m.bidrag ?? m.points, m.fra_hjaelpere ?? 0,
        m.er_hjaelper ? "ja" : "", m.hjaelper_for || "",
        m.tasks_done, m.approved,
        m.email, m.phone, (m.created_at || "").slice(0, 10),
      ]),
    };
  });

  const exportTasks = () => run("tasks", "Opgaveliste", async () => {
    const { data, error: e } = await supabase
      .from("tasks")
      .select("title,category,date,date_full,date_end,time,location,points,difficulty,spots_total,spots_left,duration_type")
      .order("date_full", { ascending: true });
    if (e) throw e;
    return {
      filename: `rvk-opgaver-${today()}.csv`,
      headers: ["Titel", "Kategori", "Dato", "Startdato", "Slutdato", "Tidsrum", "Sted", "Point", "Sværhed", "Pladser", "Ledige", "Varighed"],
      rows: (data || []).map((t) => [
        t.title, t.category, t.date, t.date_full, t.date_end, t.time, t.location,
        t.points, t.difficulty, t.spots_total, t.spots_left, t.duration_type,
      ]),
    };
  });

  const exportClaims = () => run("claims", "Tilmeldinger", async () => {
    // Navnene på modtagerne hentes ved siden af og slås op. Det er billigere
    // end at gætte på, hvad fremmednøglen hedder i PostgREST — og listen skal
    // vi alligevel have, når en tjans kan tælle for en anden end den tilmeldte.
    const [{ data, error: e }, { data: folk }] = await Promise.all([
      supabase
        .from("task_claims")
        .select("status,points_awarded,claimed_at,confirmed_at,admin_note,credited_to,tasks(title,date,date_full,points),profiles(name,team)")
        .order("claimed_at", { ascending: false }),
      supabase.rpc("admin_list_members"),
    ]);
    if (e) throw e;
    const navn = new Map((folk || []).map((m) => [m.id, m.name]));
    return {
      filename: `rvk-tilmeldinger-${today()}.csv`,
      headers: ["Opgave", "Dato", "Navn", "Hold", "Taeller for", "Tilstand", "Point", "Tilmeldt", "Bekræftet", "Bemærkning"],
      rows: (data || []).map((c) => [
        c.tasks?.title, c.tasks?.date, c.profiles?.name, c.profiles?.team,
        c.credited_to ? (navn.get(c.credited_to) || "ukendt") : (c.profiles?.name || ""),
        CLAIM_STATE[c.status]?.label || c.status,
        c.status === "completed" ? c.points_awarded : 0,
        (c.claimed_at || "").slice(0, 10),
        (c.confirmed_at || "").slice(0, 10),
        c.admin_note,
      ]),
    };
  });

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 backdrop-blur-sm p-4" onClick={onClose}>
      <div className="bg-white rounded-2xl p-5 w-full max-w-md shadow-2xl max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
        <div className="text-[15px] font-bold text-stone-900 mb-0.5">Eksportér klubdata</div>
        <p className="text-[13px] text-stone-500 mb-4 leading-relaxed">
          Filerne åbner direkte i Excel og Numbers.
        </p>

        <div className="space-y-2">
          <ExportItem id="members" busy={busy} done={done} title="Medlemsliste"
                desc="Navn, hold, point, tjanser — og kontaktoplysninger"
                onClick={exportMembers} />
          <ExportItem id="tasks" busy={busy} done={done} title="Opgaveliste"
                desc="Alle opgaver med datoer, point og pladser"
                onClick={exportTasks} />
          <ExportItem id="claims" busy={busy} done={done} title="Tilmeldinger"
                desc="Hvem stod på hvad, og hvordan det blev gjort op"
                onClick={exportClaims} />
        </div>

        <div className="bg-amber-50 border border-amber-200 rounded-xl p-3 mt-4">
          <div className="text-[12px] font-bold text-amber-900 mb-0.5">Medlemslisten er personoplysninger</div>
          <p className="text-[12px] text-amber-800 leading-relaxed">
            Den indeholder e-mail og telefon. Gem den ikke i en delt mappe, og slet den når du er
            færdig. Hver eksport skrives i audit-loggen med dit navn.
          </p>
        </div>

        {error && (
          <div className="bg-red-50 border border-red-200 rounded-xl p-3 mt-3">
            <p className="text-[12px] text-red-800">{error}</p>
          </div>
        )}

        <button onClick={onClose} className="w-full mt-4 py-2.5 rounded-xl bg-stone-100 text-stone-700 text-[13px] font-bold">
          Luk
        </button>
      </div>
    </div>
  );
};

// ---- NULSTIL SÆSON ----
//
// Knappen sletter hele klubbens pointregnskab. Den skal derfor være svær at
// trykke på ved et uheld, og let at forstå før man gør det. Fire spærringer:
//
//   1. Tallene hentes fra databasen, når dialogen åbnes — ikke fra hvad
//      browseren tilfældigvis havde liggende. Man ser det, der faktisk sker.
//   2. Sæsonen skal have et navn, så arkivet kan findes igen bagefter.
//   3. Man skal skrive NULSTIL i hånden. Ingen "er du sikker?"-knap, man kan
//      nå at trykke på to gange.
//   4. Databasen kræver det samme ord igen. Selv et forkert kald mod API'et
//      uden om appen gør ingenting.
const SeasonResetModal = ({ currentUser, defaultLabel, onClose, onDone }) => {
  const [preview, setPreview] = useState(null);
  const [label, setLabel]     = useState(defaultLabel || "");
  const [typed, setTyped]     = useState("");
  const [busy, setBusy]       = useState(false);
  const [error, setError]     = useState(null);
  const [result, setResult]   = useState(null);

  useEffect(() => {
    supabase.rpc("admin_season_reset_preview").then(({ data, error: e }) => {
      if (e) { setError(e.message); return; }
      setPreview(data?.[0] || null);
    });
  }, []);

  const armed = typed === "NULSTIL" && label.trim().length > 0 && !busy;

  const run = async () => {
    if (!armed) return;
    setBusy(true);
    setError(null);
    const { data, error: e } = await supabase.rpc("admin_reset_season", {
      p_confirm: "NULSTIL",
      p_label: label.trim(),
    });
    setBusy(false);
    if (e) { setError(e.message); return; }
    setResult(data?.[0] || null);
    logAction("settings", `Nulstillede sæsonen "${label.trim()}"`, currentUser);
  };

  if (result) {
    return (
      <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 backdrop-blur-sm p-4">
        <div className="bg-white rounded-2xl p-5 w-full max-w-md shadow-2xl">
          <div className="flex items-center gap-2 mb-2">
            <CheckCircle2 className="w-5 h-5 text-emerald-600" />
            <div className="text-[15px] font-bold text-stone-900">Sæsonen er nulstillet</div>
          </div>
          <p className="text-[13px] text-stone-600 leading-relaxed mb-4">
            <strong>{result.archived_members}</strong> medlemmers stilling er gemt i arkivet under
            {" "}<strong>{label.trim()}</strong>. {result.deleted_claims} tilmeldinger er slettet,
            {" "}{result.freed_tasks} opgaver har fået pladserne fri igen
            {result.closed_swaps > 0 && <>, og {result.closed_swaps} åbne byttetilbud er lukket</>}.
            Alle er nu på 0 point, og de har fået besked om hvorfor.
          </p>
          <button onClick={onDone} className="w-full py-2.5 rounded-xl bg-stone-900 text-white text-[13px] font-bold">
            Luk
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 backdrop-blur-sm p-4" onClick={onClose}>
      <div className="bg-white rounded-2xl p-5 w-full max-w-md shadow-2xl max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center gap-2 mb-1">
          <AlertTriangle className="w-5 h-5 text-pink-500 shrink-0" />
          <div className="text-[15px] font-bold text-stone-900">Nulstil sæsonen</div>
        </div>
        <p className="text-[13px] text-stone-500 mb-4 leading-relaxed">
          Alle medlemmer startes forfra på 0 point. Det kan ikke fortrydes.
        </p>

        {!preview && !error && (
          <div className="text-[13px] text-stone-400 py-6 text-center">Henter tallene...</div>
        )}

        {preview && (
          <>
            <div className="bg-stone-50 rounded-xl p-3.5 space-y-2 mb-4">
              <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500">Det her sker</div>
              <Row label="Medlemmer der nulstilles" value={preview.members} />
              <Row label="Point der slettes" value={`${preview.total_points} pt`} />
              <Row label="Tilmeldinger der slettes" value={preview.claims_total} />
              {preview.open_swaps > 0 && <Row label="Åbne byttetilbud der lukkes" value={preview.open_swaps} />}
            </div>

            {preview.claims_pending > 0 && (
              <div className="bg-amber-50 border border-amber-200 rounded-xl p-3 mb-4">
                <div className="text-[12px] font-bold text-amber-900 mb-0.5">
                  {preview.claims_pending} {preview.claims_pending === 1 ? "tjans er" : "tjanser er"} ikke gjort op endnu
                </div>
                <p className="text-[12px] text-amber-800 leading-relaxed">
                  De giver 0 point, som det står nu. Er de gennemført, så bekræft dem under
                  {" "}<strong>Bekræft</strong> først — ellers mister de frivillige pointene.
                </p>
              </div>
            )}

            <div className="bg-emerald-50 border border-emerald-200 rounded-xl p-3 mb-4">
              <div className="text-[12px] font-bold text-emerald-900 mb-0.5">Stillingen gemmes</div>
              <p className="text-[12px] text-emerald-800 leading-relaxed">
                Hvert medlems point, bonuspoint og antal tjanser arkiveres, før de nulstilles.
                Så kan I stadig svare på, hvem der nåede målet, hvis nogen spørger til bidraget.
              </p>
            </div>

            <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-1.5">
              Navn på sæsonen der afsluttes
            </label>
            <input
              value={label}
              onChange={(e) => setLabel(e.target.value)}
              placeholder="fx 2025/2026"
              className="w-full px-3.5 py-2.5 rounded-xl border border-stone-200 text-[14px] mb-4 focus:outline-none focus:border-stone-400"
            />

            <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-1.5">
              Skriv <span className="font-mono text-pink-600">NULSTIL</span> for at bekræfte
            </label>
            <input
              value={typed}
              onChange={(e) => setTyped(e.target.value)}
              placeholder="NULSTIL"
              autoComplete="off"
              spellCheck={false}
              className="w-full px-3.5 py-2.5 rounded-xl border border-stone-200 text-[14px] font-mono tracking-widest mb-4 focus:outline-none focus:border-pink-400"
            />
          </>
        )}

        {error && (
          <div className="bg-red-50 border border-red-200 rounded-xl p-3 mb-4">
            <p className="text-[12px] text-red-800">{error}</p>
          </div>
        )}

        <div className="flex gap-2">
          <button onClick={onClose} className="flex-1 py-2.5 rounded-xl border border-stone-200 text-[13px] font-semibold text-stone-600">
            Annuller
          </button>
          <button
            onClick={run}
            disabled={!armed}
            className="flex-1 py-2.5 rounded-xl text-[13px] font-bold text-white bg-pink-600 hover:bg-pink-700 active:scale-[0.98] disabled:bg-stone-200 disabled:text-stone-400 disabled:active:scale-100"
          >
            {busy ? "Nulstiller..." : "Nulstil sæsonen"}
          </button>
        </div>
      </div>
    </div>
  );
};

const Row = ({ label, value }) => (
  <div className="flex items-center justify-between">
    <span className="text-[13px] text-stone-600">{label}</span>
    <span className="text-[13px] font-bold text-stone-900">{value}</span>
  </div>
);

// ---- ET ARKIVERET SÆSONRESULTAT ----
const SeasonArchiveModal = ({ label, onClose }) => {
  const [rows, setRows] = useState(null);

  useEffect(() => {
    supabase.rpc("admin_season_rows", { p_label: label }).then(({ data }) => setRows(data || []));
  }, [label]);

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 backdrop-blur-sm p-4" onClick={onClose}>
      <div className="bg-white rounded-2xl p-5 w-full max-w-md shadow-2xl max-h-[85vh] flex flex-col" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start justify-between gap-3 mb-0.5">
          <div className="min-w-0">
            <div className="text-[15px] font-bold text-stone-900">Sæson {label}</div>
            <p className="text-[12px] text-stone-500 mb-3">Stillingen som den så ud, da sæsonen blev gjort op.</p>
          </div>
          <button
            onClick={() => {
              if (!rows?.length) return;
              downloadCSV(
                `rvk-saeson-${label.replace(/[^\w-]+/g, "-")}.csv`,
                toCSV(
                  ["Navn", "Hold", "Point", "Bonuspoint", "Tjanser", "Maal", "Naaede maalet"],
                  rows.map((r) => [
                    r.name, r.team, r.points, r.bonus_points, r.tasks_done,
                    r.point_goal, r.point_goal != null ? r.points >= r.point_goal : "",
                  ])
                )
              );
            }}
            disabled={!rows?.length}
            title="Hent som CSV"
            className="shrink-0 p-2 rounded-lg bg-stone-100 hover:bg-stone-200 disabled:opacity-40"
          >
            <Download className="w-4 h-4 text-stone-600" />
          </button>
        </div>

        <div className="overflow-y-auto -mx-1 px-1">
          {rows === null && <div className="text-[13px] text-stone-400 py-6 text-center">Henter...</div>}
          {rows?.length === 0 && <div className="text-[13px] text-stone-400 py-6 text-center">Ingen rækker.</div>}
          {rows?.map((r, i) => (
            <div key={i} className="flex items-center justify-between py-2 border-b border-stone-100 last:border-0">
              <div className="min-w-0">
                <div className="text-[13px] font-semibold text-stone-800 truncate">{r.name}</div>
                <div className="text-[11px] text-stone-500">
                  {r.team || "uden hold"} · {r.tasks_done} {r.tasks_done === 1 ? "tjans" : "tjanser"}
                  {r.bonus_points !== 0 && <> · {r.bonus_points > 0 ? "+" : ""}{r.bonus_points} bonus</>}
                </div>
              </div>
              <div className="text-right shrink-0 pl-3">
                <div className="text-[14px] font-bold text-stone-900">{r.points} pt</div>
                {r.point_goal != null && (
                  <div className={`text-[10px] font-semibold ${r.points >= r.point_goal ? "text-emerald-600" : "text-stone-400"}`}>
                    {r.points >= r.point_goal ? "nåede målet" : `mål ${r.point_goal}`}
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>

        <button onClick={onClose} className="w-full mt-4 py-2.5 rounded-xl bg-stone-100 text-stone-700 text-[13px] font-bold shrink-0">
          Luk
        </button>
      </div>
    </div>
  );
};

// ---- INDSTILLINGER (kun Super Admin) ----
const AdminSettings = ({ currentUser }) => {
  const [pointGoal, setPointGoal]     = useState("200");
  const [contribution, setContrib]    = useState("400");
  const [seasonStart, setStart]       = useState("2026-08-01");
  const [seasonEnd, setEnd]           = useState("2027-06-30");
  const [note, setNote]               = useState("");
  const [autoDays, setAutoDays]       = useState("7");
  const [saved, setSaved]             = useState(false);
  const [saving, setSaving]           = useState(false);
  const [showReset, setShowReset]     = useState(false);
  const [showExport, setShowExport]   = useState(false);
  const [seasons, setSeasons]         = useState([]);
  const [openSeason, setOpenSeason]   = useState(null);

  // Foreslået navn til arkivet, fx "2025/2026". Bygges af sæsonperioden, så
  // admin ikke selv skal finde på noget under en handling der ikke kan fortrydes.
  const seasonLabel = useMemo(() => {
    const y1 = (seasonStart || "").slice(0, 4);
    const y2 = (seasonEnd   || "").slice(0, 4);
    if (y1 && y2) return y1 === y2 ? y1 : `${y1}/${y2}`;
    return String(new Date().getFullYear());
  }, [seasonStart, seasonEnd]);

  const loadSeasons = () => {
    supabase.rpc("admin_season_list").then(({ data }) => setSeasons(data || []));
  };
  useEffect(loadSeasons, []);

  useEffect(() => {
    supabase.from("settings").select("key,value").then(({ data }) => {
      if (!data) return;
      const map = Object.fromEntries(data.map((s) => [s.key, s.value]));
      if (map.point_goal)     setPointGoal(map.point_goal);
      if (map.contribution_kr) setContrib(map.contribution_kr);
      if (map.season_start)   setStart(map.season_start);
      if (map.season_end)     setEnd(map.season_end);
      if (map.auto_confirm_days != null) setAutoDays(map.auto_confirm_days);
      if (map.contribution_note != null) setNote(map.contribution_note);
    });
  }, []);

  const save = async () => {
    setSaving(true);
    await supabase.from("settings").upsert([
      { key: "point_goal",      value: pointGoal },
      { key: "contribution_kr", value: contribution },
      { key: "season_start",    value: seasonStart },
      { key: "season_end",      value: seasonEnd },
      { key: "auto_confirm_days", value: String(parseInt(autoDays) || 0) },
      { key: "contribution_note", value: note },
    ], { onConflict: "key" });
    setSaving(false);
    setSaved(true);
    setTimeout(() => setSaved(false), 2500);
    logAction("settings", `Opdaterede indstillinger: mål=${pointGoal} pt, bidrag=${contribution} kr, automatisk bekræftelse=${parseInt(autoDays) || 0} dage`, currentUser);
  };

  return (
    <div className="space-y-4">
      {saved && <div className="bg-emerald-50 border border-emerald-200 rounded-xl p-3 flex items-center gap-2.5"><CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" /><p className="text-[13px] text-emerald-900 font-semibold">Indstillinger gemt!</p></div>}

      <div className="bg-white rounded-2xl p-4 border border-stone-100 shadow-sm space-y-4">
        <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500">Pointsystem</div>
        <AdminInput label="Point for at slippe for bidraget" type="number" placeholder="200" icon={<Zap className="w-4 h-4" />} value={pointGoal} onChange={(e) => setPointGoal(e.target.value)} />
        <p className="text-[11px] text-stone-400 -mt-2 leading-relaxed">
          Dét, medlemmet skal nå inden næste opgørelse. Tallet er også målet på
          dashboardet — der er ikke længere to forskellige tal. Point nulstilles
          kun, når en super admin kører en sæsonnulstilling.
        </p>
        <AdminInput label="Frivillighedsbidrag (kr)" type="number" placeholder="400" icon={<DollarSign className="w-4 h-4" />} value={contribution} onChange={(e) => setContrib(e.target.value)} />
        <p className="text-[11px] text-stone-400 -mt-2">Betales af alle under {pointGoal || 200} point ved opgørelsen.</p>
        <AdminInput label="Besked til medlemmerne om opgørelsen" textarea placeholder="Fx: Efteråret er gratis i år. Der gøres op til foråret — 200 point i alt." value={note} onChange={(e) => setNote(e.target.value)} />
        <p className="text-[11px] text-stone-400 -mt-2 leading-relaxed">
          Står under pointbjælken på medlemmets dashboard. Lad feltet stå tomt,
          hvis der ikke er noget at sige.
        </p>
        <div>
          <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-1.5">Sæsonperiode</label>
          <div className="grid grid-cols-2 gap-2">
            <AdminInput type="date" value={seasonStart} onChange={(e) => setStart(e.target.value)} />
            <AdminInput type="date" value={seasonEnd} onChange={(e) => setEnd(e.target.value)} />
          </div>
        </div>
        <div className="pt-3 border-t border-stone-100">
          <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500 mb-3">Automatisk bekræftelse</div>
          <AdminInput label="Godkend automatisk efter (dage)" type="number" placeholder="7" icon={<Clock className="w-4 h-4" />} value={autoDays} onChange={(e) => setAutoDays(e.target.value)} />
          <p className="text-[11px] text-stone-400 mt-1.5 leading-relaxed">
            {parseInt(autoDays) > 0 ? (
              <>Tjanser der stadig afventer {parseInt(autoDays)} dage efter opgavens sidste dag, godkendes af sig selv. Har du markeret nogen som udeblevet, bliver det stående. Skriv 0 for at slå fra.</>
            ) : (
              <>Slået fra — alle tjanser skal gøres op i hånden under Bekræft.</>
            )}
          </p>
        </div>

        <button onClick={save} disabled={saving} className="w-full py-2.5 rounded-xl text-white font-bold text-[13px] flex items-center justify-center gap-2 disabled:opacity-60" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
          {saving ? <><div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />Gemmer...</> : <><Save className="w-4 h-4" />Gem indstillinger</>}
        </button>
      </div>

      <div className="bg-white rounded-2xl p-4 border border-stone-100 shadow-sm space-y-3">
        <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500">Klubdata</div>

        <button
          onClick={() => setShowExport(true)}
          className="w-full flex items-center justify-between px-4 py-3 bg-stone-50 hover:bg-stone-100 rounded-xl text-left"
        >
          <span className="text-[13px] font-semibold">Eksportér klubdata (CSV)</span>
          <Download className="w-4 h-4 text-stone-500" />
        </button>

        <button
          onClick={() => setShowReset(true)}
          className="w-full flex items-center justify-between px-4 py-3 bg-pink-50 hover:bg-pink-100 rounded-xl text-left"
        >
          <span className="text-[13px] font-semibold text-pink-700">Nulstil ny sæson (slet alle point)</span>
          <AlertTriangle className="w-4 h-4 text-pink-500" />
        </button>

        {/* Arkivet. Et arkiv ingen kan se, er ikke et arkiv. */}
        {seasons.length > 0 && (
          <div className="pt-2 border-t border-stone-100">
            <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500 mb-2">Tidligere sæsoner</div>
            <div className="space-y-1.5">
              {seasons.map((s) => (
                <button
                  key={s.season_label}
                  onClick={() => setOpenSeason(s.season_label)}
                  className="w-full flex items-center justify-between px-3 py-2.5 bg-stone-50 hover:bg-stone-100 rounded-xl text-left"
                >
                  <div>
                    <div className="text-[13px] font-semibold text-stone-800">{s.season_label}</div>
                    <div className="text-[11px] text-stone-500">
                      {s.members} medlemmer · {s.total_points} point i alt · {s.reached_goal} nåede målet
                    </div>
                  </div>
                  <ChevronRight className="w-4 h-4 text-stone-400 shrink-0" />
                </button>
              ))}
            </div>
          </div>
        )}
      </div>

      {showReset && (
        <SeasonResetModal
          currentUser={currentUser}
          defaultLabel={seasonLabel}
          onClose={() => setShowReset(false)}
          onDone={() => { setShowReset(false); loadSeasons(); }}
        />
      )}
      {showExport && <ExportModal currentUser={currentUser} onClose={() => setShowExport(false)} />}
      {openSeason && <SeasonArchiveModal label={openSeason} onClose={() => setOpenSeason(null)} />}
    </div>
  );
};

// ---- AUDIT LOG (kun Super Admin) ----
const AdminAuditLog = () => {
  const [logs, setLogs] = useState([]);
  const [errors, setErrors] = useState([]);
  const [view, setView] = useState("actions");

  useEffect(() => {
    supabase.from("audit_log").select("*").order("created_at", { ascending: false }).then(({ data }) => {
      if (data) setLogs(data);
    });
    supabase.from("client_errors")
      .select("*, profiles(name)")
      .order("created_at", { ascending: false })
      .limit(100)
      .then(({ data }) => { if (data) setErrors(data); });
  }, []);

  if (view === "errors") {
    return (
      <div className="space-y-3">
        <div className="flex gap-1.5">
          <button onClick={() => setView("actions")} className="px-3 py-1.5 rounded-lg text-[12px] font-semibold bg-stone-100 text-stone-600">Handlinger</button>
          <button className="px-3 py-1.5 rounded-lg text-[12px] font-bold text-white" style={{ background: `linear-gradient(135deg, ${theme.pink}, ${theme.purple})` }}>Fejl & beskeder ({errors.length})</button>
        </div>

        <div className="bg-violet-50 border border-violet-200 rounded-xl p-3 flex gap-2.5">
          <Info className="w-4 h-4 text-violet-600 shrink-0 mt-0.5" />
          <p className="text-[11px] text-violet-900 leading-relaxed">
            To slags linjer: uventede fejl fra medlemmernes telefoner, som før endte i browserens
            konsol hvor ingen så dem — og beskeder, medlemmerne selv har skrevet via
            <strong> Noget der driller?</strong> på profilskærmen. Samme fejl hos mange på én gang
            betyder som regel, at noget er gået i stykker for alle. Alt ældre end 90 dage slettes.
          </p>
        </div>

        {errors.length === 0 ? (
          <div className="bg-white rounded-2xl border border-dashed border-stone-200 p-8 text-center">
            <CheckCircle2 className="w-10 h-10 mx-auto mb-2 text-emerald-300" />
            <p className="text-[13px] text-stone-600 font-semibold">Ingen fejl registreret</p>
          </div>
        ) : (
          <div className="space-y-2">
            {errors.map((e) => (
              <div key={e.id} className="bg-white rounded-xl border border-stone-100 shadow-sm p-3">
                <div className="flex items-start gap-2.5">
                  {/* En besked skrevet af et menneske skal ikke ligne et nedbrud.
                      Under en prøvekørsel er det de fleste af linjerne her. */}
                  <div className={`w-7 h-7 rounded-lg flex items-center justify-center shrink-0 ${
                    e.source === "feedback" ? "bg-emerald-50 text-emerald-700" : "bg-red-50 text-red-600"}`}>
                    {e.source === "feedback"
                      ? <MessageSquare className="w-3.5 h-3.5" />
                      : <AlertTriangle className="w-3.5 h-3.5" />}
                  </div>
                  <div className="flex-1 min-w-0">
                    {e.source === "feedback" && (
                      <div className="text-[10px] uppercase tracking-widest font-bold text-emerald-700 mb-0.5">
                        Besked fra medlem
                      </div>
                    )}
                    <div className="text-[12px] font-semibold text-stone-900 break-words">{e.message}</div>
                    <div className="text-[11px] text-stone-500 mt-1 flex flex-wrap items-center gap-x-2 gap-y-0.5">
                      <span>{e.profiles?.name || "ukendt medlem"}</span>
                      <span>·</span>
                      <span>{new Date(e.created_at).toLocaleString("da-DK")}</span>
                      {e.source && e.source !== "feedback" && <><span>·</span><span className="mono">{e.source}</span></>}
                    </div>
                    {e.stack && (
                      <details className="mt-1.5">
                        <summary className="text-[11px] text-stone-400 cursor-pointer">Vis detaljer</summary>
                        <pre className="text-[10px] text-stone-500 mt-1 whitespace-pre-wrap break-words max-h-40 overflow-y-auto bg-stone-50 rounded-lg p-2">{e.stack}</pre>
                      </details>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    );
  }

  return (
  <div className="space-y-3">
    <div className="flex gap-1.5">
      <button className="px-3 py-1.5 rounded-lg text-[12px] font-bold text-white" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>Handlinger</button>
      <button onClick={() => setView("errors")} className={`px-3 py-1.5 rounded-lg text-[12px] font-semibold inline-flex items-center gap-1.5 ${errors.length > 0 ? "bg-red-50 text-red-700" : "bg-stone-100 text-stone-600"}`}>
        Fejl{errors.length > 0 && <span className="min-w-[18px] h-[18px] px-1 rounded-full bg-red-500 text-white text-[10px] font-black flex items-center justify-center">{errors.length}</span>}
      </button>
    </div>

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

export default AdminDashboard;
