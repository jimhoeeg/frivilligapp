import {
  useState, useMemo, useEffect, useRef, Component, lazy, Suspense
} from "react";
import { supabase } from "./supabaseClient";
// Admin-panelet hentes FØRST, når nogen åbner det. Langt de fleste medlemmer
// gør det aldrig, og før lå hele panelet i den samme fil, som enhver
// telefon hentede ved hvert besøg.
const AdminDashboard = lazy(() => import("./admin.jsx"));

import {
  theme, ScrollRow, CategoryIcon, parseTaskDate, ClaimStatusPill,
  MemberTasksModal, DifficultyPill
} from "./shared.jsx";
import {
  Home, ListChecks, Trophy, User, MapPin, Clock, Calendar, Zap, ChevronRight,
  Check, X, Filter, Search, Flame, AlertCircle, ArrowLeft, Info, Crown,
  Users, Eye, EyeOff, Camera, Mail, Phone, LogOut, ChevronDown, Lock,
  ArrowRight, CheckCircle2, AtSign, Plus, ShieldCheck, UserPlus,
  AlertTriangle, Pencil, UserCheck, UserX, BellRing, ArrowLeftRight,
  CalendarDays, List, Grid3x3, ChevronLeft
} from "lucide-react";

const erSessionUdloebet = (error) =>
  !!error && (
    error.code === "PGRST301" ||
    error.status === 401 ||
    /jwt|token/i.test(error.message || "")
  );

const medFornyetSession = async (kald) => {
  const svar = await kald();
  if (!erSessionUdloebet(svar?.error)) return svar;

  // Proev at forny — men med en snor i. Svarer fornyelsen aldrig (det sker,
  // naar forbindelsen er halvdoed), maa den ikke kunne laase kaldet fast for
  // evigt. Fem sekunder, saa gaar vi videre uanset.
  //
  // Lykkes fornyelsen ikke, proever vi ALLIGEVEL en gang til: supabase-js kan
  // have fornyet i baggrunden imens, og et ekstra kald koster ingenting mod
  // at efterlade medlemmet med en tom skaerm.
  try {
    await Promise.race([
      supabase.auth.refreshSession(),
      new Promise((r) => setTimeout(r, 5000)),
    ]);
  } catch {
    // ignoreres med vilje – forsoeget nedenfor afgoer sagen
  }
  return kald();
};

// ============ DEN HUSKEDE PROFIL ============
//
// Et gensyn med appen skal ikke foele sig som en ny installation. Navnet,
// holdet og pointene laa allerede paa telefonen sidst — der er ingen grund
// til at stirre paa en spinner, mens serveren siger det samme igen.
//
// Derfor: vis den gemte profil med det samme, og hent den rigtige i
// baggrunden. Er der sket noget (flere point, ny rolle, slettet profil),
// retter det sig selv et oejeblik senere.
//
// Det her er en GENVEJ TIL VISNINGEN, ikke en adgangsbillet. Alt, hvad appen
// laver, gaar gennem databasens egne regler (row level security) med
// medlemmets egen noegle. Ligger der en forgyldt profil i telefonen, giver
// den ikke adgang til noget som helst.
const PROFIL_NOEGLE = "rvk-profil";

// En uge. Derefter er tallene gamle nok til, at et kort hvidt oejeblik er
// bedre end at vise noget forkert.
const PROFIL_MAX_ALDER = 7 * 24 * 60 * 60 * 1000;

const laesProfilCache = (userId) => {
  try {
    const raa = localStorage.getItem(PROFIL_NOEGLE);
    if (!raa) return null;
    const { gemt, profil } = JSON.parse(raa);
    if (!profil || profil.id !== userId) return null;
    if (!gemt || Date.now() - gemt > PROFIL_MAX_ALDER) return null;
    // Et medlem, der endnu ikke er godkendt, skal ikke lukkes ind paa en
    // gammel kopi. Dér venter vi paa serveren.
    if (profil.approved !== true) return null;
    return profil;
  } catch {
    // Privat vindue, ryddet lager, fuld disk. Det er en genvej — den maa
    // aldrig staa i vejen.
    return null;
  }
};

const gemProfilCache = (profil) => {
  try {
    localStorage.setItem(PROFIL_NOEGLE, JSON.stringify({ gemt: Date.now(), profil }));
  } catch { /* ignoreres med vilje */ }
};

const ryddProfilCache = () => {
  try { localStorage.removeItem(PROFIL_NOEGLE); } catch { /* ignoreres */ }
};

// Ét forsøg på at hente egen profil, med en tidsgrænse der rydder op efter
// sig. 8 sekunder var for stramt: et medlem på mobilnet i en hal med dårlig
// dækning rammer det jævnligt, uden at der er noget galt.
//
// Ligger uden for komponenten, fordi den ikke rører React-state — og fordi
// den så ikke tæller med som afhængighed i auth-lytterens effect.
const hentProfil = async (ms = 15000) => {
  let t;
  const timeout = new Promise((_, reject) => {
    t = setTimeout(() => reject(new Error(`Profilen svarede ikke inden ${ms / 1000} sekunder`)), ms);
  });
  try {
    return await Promise.race([
      medFornyetSession(() => supabase.rpc("my_profile").single()),
      timeout,
    ]);
  } finally {
    clearTimeout(t);
  }
};

// ============ SIG TIL, HVIS NOGET DRILLER ============
//
// Under en prøvekørsel er forskellen på brugbar og ubrugelig tilbagemelding,
// om der er en knap. Ellers bliver det til "den var lidt mærkelig i går" i en
// hal, og det er glemt inden nogen skriver det ned.
//
// Beskeden går samme vej som nedbrud — log_client_error med source
// "feedback" — så admins ser den under Audit log → Fejl sammen med
// tidspunkt, hvem der skrev, og hvilken skærm de stod på. Databasens
// grænse på 20 pr. bruger i timen gælder også her.
const FeedbackModal = ({ onClose }) => {
  const [text, setText] = useState("");
  const [sendt, setSendt] = useState(false);
  const [busy, setBusy] = useState(false);

  const send = async () => {
    const besked = text.trim();
    if (!besked) return;
    setBusy(true);
    await supabase.rpc("log_client_error", {
      p_message:    besked.slice(0, 500),
      p_source:     "feedback",
      p_stack:      null,
      p_url:        typeof window !== "undefined" ? window.location.href : null,
      p_user_agent: typeof navigator !== "undefined" ? navigator.userAgent : null,
    });
    setBusy(false);
    setSendt(true);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 backdrop-blur-sm p-4" onClick={onClose}>
      <div className="bg-white rounded-2xl p-5 w-full max-w-md shadow-2xl" onClick={(e) => e.stopPropagation()}>
        {sendt ? (
          <>
            <div className="flex items-center gap-2 mb-2">
              <CheckCircle2 className="w-5 h-5 text-emerald-600" />
              <div className="text-[15px] font-bold text-stone-900">Tak — den er sendt</div>
            </div>
            <p className="text-[13px] text-stone-600 leading-relaxed mb-4">
              Klubbens administratorer kan se den nu. Du får ikke et svar her i appen,
              så skriv til {LEGAL_CONTACT}, hvis det haster.
            </p>
            <button onClick={onClose} className="w-full py-2.5 rounded-xl bg-stone-900 text-white text-[13px] font-bold">Luk</button>
          </>
        ) : (
          <>
            <div className="text-[15px] font-bold text-stone-900 mb-0.5">Noget der driller?</div>
            <p className="text-[13px] text-stone-500 mb-3 leading-relaxed">
              Skriv hvad du lavede, og hvad der skete. Det behøver ikke være pænt —
              det hjælper mest, hvis du skriver det med det samme.
            </p>
            <textarea
              value={text}
              onChange={(e) => setText(e.target.value)}
              rows={4}
              maxLength={500}
              autoFocus
              placeholder="Fx: Jeg trykkede Tag tjansen på dommerbordet, og så skete der ingenting."
              className="w-full px-3.5 py-2.5 rounded-xl border border-stone-200 text-[14px] resize-none focus:outline-none focus:border-stone-400"
            />
            <div className="text-[11px] text-stone-400 mt-1 mb-3 text-right">{text.length}/500</div>
            <div className="flex gap-2">
              <button onClick={onClose} className="flex-1 py-2.5 rounded-xl border border-stone-200 text-[13px] font-semibold text-stone-600">Annuller</button>
              <button
                onClick={send}
                disabled={!text.trim() || busy}
                className="flex-1 py-2.5 rounded-xl text-white text-[13px] font-bold disabled:bg-stone-200 disabled:text-stone-400"
                style={text.trim() && !busy ? { background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` } : undefined}
              >
                {busy ? "Sender..." : "Send"}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

// ============ PROFILEN KUNNE IKKE HENTES ============
//
// Login lykkes i Supabase, men appen kan ikke hente medlemsprofilen. Det sker
// i tre tilfaelde: profilen findes ikke (oprettelsen gik galt undervejs),
// serveren svarer med en fejl, eller kaldet naar ikke igennem inden for 8
// sekunder.
//
// Foer viste appen bare login-skaermen igen. Set fra medlemmet: man skriver
// sit kodeord, der sker ingenting, man skriver det igen. To konti i den
// rigtige database stod praecis saadan, og ingen kunne have gaettet hvorfor.
// Nu siger appen hvad der er galt, og hvad man goer ved det.
const ProfileProblemScreen = ({ kind, onRetry, onSignOut, busy }) => {
  const missing = kind === "missing";
  return (
    <div className="min-h-screen bg-stone-50 font-sans antialiased flex items-center justify-center p-5">
      <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-sm border border-stone-100">
        <div className="w-11 h-11 rounded-xl bg-amber-50 flex items-center justify-center mb-4">
          <AlertTriangle className="w-5 h-5 text-amber-600" />
        </div>

        <h1 className="text-lg font-bold text-stone-900 mb-1.5">
          {missing ? "Din profil mangler" : "Kunne ikke hente din profil"}
        </h1>

        <p className="text-[13px] text-stone-600 leading-relaxed mb-4">
          {missing ? (
            <>
              Du er logget ind, men der er ingen medlemsprofil knyttet til din konto.
              Det sker, hvis oprettelsen blev afbrudt undervejs. Det er ikke noget,
              du kan rette selv — skriv til klubben, så laver en administrator den.
            </>
          ) : (
            <>
              Du er logget ind, men forbindelsen til klubbens database svarede ikke.
              Det er næsten altid midlertidigt. Prøv igen om lidt.
            </>
          )}
        </p>

        {missing && (
          <div className="bg-stone-50 rounded-xl p-3 mb-4">
            <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500 mb-1">Skriv til</div>
            <a href={`mailto:${LEGAL_CONTACT}`} className="text-[13px] font-semibold text-emerald-700 break-all">
              {LEGAL_CONTACT}
            </a>
          </div>
        )}

        <div className="flex gap-2">
          <button
            onClick={onSignOut}
            className="flex-1 py-2.5 rounded-xl border border-stone-200 text-[13px] font-semibold text-stone-600"
          >
            Log ud
          </button>
          {!missing && (
            <button
              onClick={onRetry}
              disabled={busy}
              className="flex-1 py-2.5 rounded-xl bg-stone-900 text-white text-[13px] font-bold disabled:opacity-60"
            >
              {busy ? "Prøver..." : "Prøv igen"}
            </button>
          )}
        </div>

        <p className="text-[11px] text-stone-400 mt-4 leading-relaxed">
          Fejlen er automatisk registreret, så klubbens administratorer kan se den.
        </p>
      </div>
    </div>
  );
};

// ============ HVEM STAAR PAA OPGAVEN ============
//
// Et medlem skal kunne se, hvem der allerede har taget tjansen, FOER de selv
// melder sig. Det er den hyppigste grund til at sige ja: man tager en vagt,
// fordi man kan se, hvem man kommer til at staa der med.
//
// Kun navn, initialer og hold — ikke e-mail og ikke telefon. At vide hvem man
// staar paa vagt med er ikke det samme som at faa deres kontaktoplysninger.
const TaskSignups = ({ taskId, spotsTotal, currentUserId, erTilmeldt }) => {
  const [folk, setFolk] = useState(null);

  // erTilmeldt er med i afhaengighederne med vilje: melder man til eller fra,
  // skal listen hente sig selv igen med det samme. Ellers staar man og kigger
  // paa en liste, man lige er kommet med paa, uden at vaere der.
  useEffect(() => {
    if (!taskId) return;
    let ignore = false;
    supabase.rpc("task_signups", { p_task: taskId }).then(({ data, error }) => {
      if (ignore) return;
      if (error) { reportError(`task_signups: ${error.message}`, "tasks"); setFolk([]); return; }
      setFolk(data || []);
    });
    return () => { ignore = true; };
  }, [taskId, erTilmeldt]);

  // Tallene regnes ud fra den liste, vi lige har hentet — ikke fra opgavens
  // spotsLeft, som kan vaere forAeldet paa den aabne detaljeside.
  const taget = folk?.length ?? 0;
  const spotsLeft = Math.max(0, (spotsTotal ?? 0) - taget);

  return (
    <div className="px-5 pb-6">
      <h2 className="text-[11px] uppercase tracking-widest font-bold text-stone-500 mb-3">
        Hvem er med? {folk !== null && <span className="text-stone-400 normal-case tracking-normal font-semibold">· {taget} af {spotsTotal} pladser taget</span>}
      </h2>

      {folk === null ? (
        <div className="text-[13px] text-stone-400">Henter...</div>
      ) : folk.length === 0 ? (
        <div className="bg-stone-50 border border-dashed border-stone-200 rounded-xl px-4 py-3">
          <p className="text-[13px] text-stone-600 font-semibold">Ingen har taget den endnu</p>
          <p className="text-[12px] text-stone-500 mt-0.5">Du bliver den første.</p>
        </div>
      ) : (
        <div className="space-y-1.5">
          {folk.map((f) => {
            const erMig = f.user_id === currentUserId;
            return (
              <div key={f.user_id}
                   className={`flex items-center gap-2.5 rounded-xl px-3 py-2 border ${
                     erMig ? "bg-emerald-50 border-emerald-200" : "bg-white border-stone-200"}`}>
                <div className="shrink-0 w-8 h-8 rounded-full flex items-center justify-center text-white text-[11px] font-bold"
                     style={{ background: erMig
                       ? `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})`
                       : `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
                  {f.initials || (f.name || "?").slice(0, 1)}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="text-[13px] font-semibold text-stone-900 truncate">
                    {f.name}{erMig && <span className="text-emerald-700 font-bold"> · dig</span>}
                  </div>
                  {f.team && <div className="text-[11px] text-stone-500 truncate">{f.team}</div>}
                </div>
                {f.status === "completed" && (
                  <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                )}
              </div>
            );
          })}

          {(spotsLeft ?? 0) > 0 && (
            <div className="text-[12px] text-stone-500 pt-1">
              {spotsLeft === 1 ? "Der er én plads tilbage." : `Der er ${spotsLeft} pladser tilbage.`}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

const seenErrors = new Set();

const reportError = (message, source, stack) => {
  const key = `${source}:${message}`.slice(0, 200);
  if (seenErrors.has(key)) return;          // samme fejl igen i denne session
  seenErrors.add(key);
  supabase.rpc("log_client_error", {
    p_message:    String(message || "Ukendt fejl"),
    p_source:     source,
    p_stack:      stack ? String(stack) : null,
    p_url:        typeof window !== "undefined" ? window.location.href : null,
    p_user_agent: typeof navigator !== "undefined" ? navigator.userAgent : null,
  }).then(({ error }) => {
    if (error) console.warn("Kunne ikke indrapportere fejl:", error.message);
  });
};

if (typeof window !== "undefined") {
  window.addEventListener("error", (e) => {
    reportError(e.message, "error", e.error?.stack);
  });
  window.addEventListener("unhandledrejection", (e) => {
    const r = e.reason;
    reportError(r?.message || String(r), "unhandledrejection", r?.stack);
  });
}

// Uden denne ville en fejl under rendering give en helt hvid skærm uden
// forklaring — det værste, der kan møde et medlem der skal tage en tjans.
export class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { crashed: false };
  }

  static getDerivedStateFromError() {
    return { crashed: true };
  }

  componentDidCatch(error, info) {
    reportError(error?.message, "render", error?.stack || info?.componentStack);
  }

  render() {
    if (!this.state.crashed) return this.props.children;
    return (
      <div className="min-h-screen flex items-center justify-center px-6" style={{ background: theme.paper }}>
        <div className="max-w-sm w-full bg-white rounded-3xl shadow-xl p-6 text-center">
          <div className="w-14 h-14 rounded-2xl flex items-center justify-center mx-auto mb-4" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
            <AlertTriangle className="w-7 h-7 text-white" />
          </div>
          <h1 className="text-lg font-bold text-stone-900">Der gik noget galt</h1>
          <p className="text-[13px] text-stone-600 mt-2 leading-relaxed">
            Appen løb ind i en fejl. Klubben har fået besked, så vi kan kigge på det.
            Prøv at hente siden igen — dine tilmeldinger og point er ikke berørt.
          </p>
          <button
            onClick={() => window.location.reload()}
            className="w-full mt-5 py-3 rounded-xl font-bold text-white text-[13px]"
            style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}
          >
            Hent siden igen
          </button>
          <p className="text-[11px] text-stone-400 mt-3">
            Bliver ved med at ske? Skriv til {LEGAL_CONTACT}.
          </p>
        </div>
      </div>
    );
  }
}

const TaskCard = ({ task, onClick }) => {
  const isFull = task.spotsLeft === 0;
  const isLong = task.durationType && task.durationType !== "single";
  return (
    <button
      onClick={() => onClick(task)}
      className="w-full text-left bg-white rounded-xl px-3 py-2.5 border border-stone-200/70 hover:border-emerald-300 active:scale-[0.99] transition-all shadow-sm hover:shadow-md group relative overflow-hidden flex items-center gap-3"
    >
      {/* Icon */}
      <div className="shrink-0 w-9 h-9 rounded-lg flex items-center justify-center text-white shadow-sm" style={{ background: isLong ? `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` : `linear-gradient(135deg, ${theme.greenDark} 0%, ${theme.greenMid} 100%)` }}>
        <CategoryIcon type={task.icon} className="w-4.5 h-4.5" />
      </div>

      {/* Main content */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1.5 mb-0.5">
          {task.urgent && !isLong && <Flame className="w-3 h-3 text-pink-500 shrink-0" />}
          {isLong && <CalendarDays className="w-3 h-3 text-violet-500 shrink-0" />}
          <span className="font-semibold text-[13px] leading-tight text-stone-900 truncate">{task.title}</span>
        </div>
        <div className="flex items-center gap-2 text-[11px] text-stone-500">
          <span className="inline-flex items-center gap-0.5"><Calendar className="w-3 h-3" />{task.date}</span>
          {!isLong && task.time && <span className="inline-flex items-center gap-0.5"><Clock className="w-3 h-3" />{task.time}</span>}
          <span className="inline-flex items-center gap-0.5 truncate"><MapPin className="w-3 h-3 shrink-0" /><span className="truncate">{task.location}</span></span>
        </div>
      </div>

      {/* Right side: points + spots */}
      <div className="shrink-0 flex flex-col items-end gap-1">
        <div className="inline-flex items-center gap-0.5 px-2 py-0.5 rounded-full text-white text-[11px] font-bold" style={{ background: `linear-gradient(135deg, ${theme.purple} 0%, ${theme.pink} 100%)` }}>
          <Zap className="w-3 h-3" fill="white" />+{task.points}
        </div>
        <span className={`text-[10px] font-semibold ${isFull ? "text-red-400" : "text-stone-400"}`}>
          {isFull ? "Fuldt" : `${task.spotsLeft} ledig`}
        </span>
      </div>

      <div className="absolute bottom-0 left-0 right-0 h-0.5 opacity-0 group-hover:opacity-100 transition-opacity" style={{ background: `linear-gradient(90deg, ${theme.greenMid}, ${theme.purple}, ${theme.pink})` }} />
    </button>
  );
};

const AuthField = ({ icon, label, type = "text", name, autoComplete, value, onChange, placeholder, error, rightIcon }) => (
  <div>
    <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-1.5">{label}</label>
    <div className="relative">
      <div className="absolute left-3 top-1/2 -translate-y-1/2 text-stone-400 pointer-events-none">{icon}</div>
      <input
        type={type}
        name={name}
        autoComplete={autoComplete}
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

const LEGAL_UPDATED = "10. september 2026";
const LEGAL_CONTACT = "kontakt@randersvk.dk";

const LEGAL_DOCS = {
  terms: {
    title: "Vilkår for brug",
    intro: "RVK Frivillig er Randers Volleyballklubs værktøj til at fordele frivillige opgaver blandt klubbens medlemmer.",
    sections: [
      { h: "Hvem kan bruge appen", p: [
        "Appen er for medlemmer af Randers Volleyballklub og deres pårørende, der hjælper til i klubben.",
        "Når du opretter en profil, skal en administrator godkende dig, før du kan tage opgaver. Det er for at sikre, at vi ved, hvem der står på vagtplanen.",
      ]},
      { h: "Når du tager en tjans", p: [
        "Når du melder dig til en opgave, regner klubben med dig. Kan du alligevel ikke, så meld fra i god tid eller tilbyd tjansen på bytte-markedet, så en anden kan overtage den.",
        "Du kan melde fra, så længe tjansen ikke er gjort op. Er den først bekræftet som gennemført, skal du kontakte klubben.",
      ]},
      { h: "Point og frivillighedsbidrag", p: [
        "Du optjener point, når en administrator har bekræftet, at du gennemførte tjansen — ikke allerede når du melder dig til. Indtil da står pointene som \u201eafventer bekræftelse\u201c på dit dashboard.",
        "Har ingen administrator gjort tjansen op inden for en uge efter opgavens sidste dag, bliver den godkendt automatisk. Det er for ikke at lade nogen vente på point, de har gjort sig fortjent til.",
        "Møder du ikke op uden at melde afbud, kan tjansen blive registreret som ikke gennemført. Så giver den ingen point. Mener du, det er en fejl, så kontakt klubben — det kan altid laves om.",
        "Point bruges til at vise, hvor meget den enkelte bidrager, og kan indgå i klubbens ordning om frivillighedsbidrag. De aktuelle pointmål og beløb fastsættes af bestyrelsen og fremgår i appen.",
        "En administrator kan regulere point manuelt, hvis noget er registreret forkert. Det bliver noteret i klubbens log.",
      ]},
      { h: "God tone", p: [
        "Beskeder du skriver i appen — for eksempel når du tilbyder en tjans til bytte — kan læses af andre medlemmer. Skriv, som du ville tale til hinanden i hallen.",
      ]},
      { h: "Hvis noget går galt", p: [
        `Oplever du fejl i appen, eller mener du at dine point er registreret forkert, så skriv til ${LEGAL_CONTACT}.`,
        "Klubben kan lukke en profil, hvis appen bruges til noget, den ikke er tænkt til.",
      ]},
    ],
  },
  privacy: {
    title: "Privatlivspolitik",
    intro: "Randers Volleyballklub er dataansvarlig for de oplysninger, du giver os i RVK Frivillig. Her står, hvad vi gemmer, hvorfor, og hvordan du får det slettet igen.",
    sections: [
      { h: "Hvad vi gemmer om dig", p: [
        "Navn, e-mailadresse, telefonnummer (hvis du oplyser det), hvilket hold du hører til, og et profilbillede hvis du uploader et.",
        "Hvilke opgaver du har meldt dig til, om de er bekræftet som gennemført, hvor mange point du har optjent, og hvornår du oprettede din profil.",
        "Registreres en tjans som ikke gennemført, kan en administrator notere en kort bemærkning om hvorfor. Den kan du selv se i beskeden, du får.",
        "Din adgangskode gemmes aldrig i klar tekst — den håndteres krypteret af vores databaseleverandør.",
      ]},
      { h: "Hvorfor vi gemmer det", p: [
        "For at kunne fordele frivillige opgaver og vide, hvem der står på hvilken vagt.",
        "For at kunne gøre op, hvem der har bidraget, i forbindelse med klubbens ordning om frivillighedsbidrag.",
        "Grundlaget er klubbens legitime interesse i at drive foreningen, og for kontaktoplysninger dit eget samtykke, som du giver ved oprettelsen.",
      ]},
      { h: "Hvem kan se hvad", p: [
        "Andre medlemmer kan se dit navn, dit hold, dine point og hvilke opgaver du står på. Det er hele pointen med en fælles vagtplan.",
        "Din e-mail og dit telefonnummer kan kun ses af dig selv og af klubbens administratorer. De er ikke tilgængelige for andre medlemmer.",
        "Vi sælger ikke dine oplysninger og deler dem ikke med nogen uden for klubben.",
      ]},
      { h: "Hvor længe", p: [
        "Vi gemmer dine oplysninger, så længe du er aktiv i klubben, og i op til 12 måneder efter du er meldt ud — så vi kan gøre sæsonen op. Derefter slettes de.",
      ]},
      { h: "Hvor det ligger", p: [
        "Appen kører hos Vercel, og oplysningerne ligger i en database hos Supabase på servere i EU.",
      ]},
      { h: "Dine rettigheder", p: [
        "Du kan altid se og rette dine egne oplysninger under \"Min profil\".",
        "Du har ret til at få udleveret, rettet eller slettet dine oplysninger, og til at gøre indsigelse mod at vi behandler dem.",
        `Skriv til ${LEGAL_CONTACT}, så ordner vi det. Er du ikke tilfreds med vores svar, kan du klage til Datatilsynet.`,
      ]},
    ],
  },
};

const LegalScreen = ({ doc, onBack }) => {
  const d = LEGAL_DOCS[doc];
  if (!d) return null;
  return (
    <div className="min-h-screen bg-stone-50 pb-16">
      <div className="px-5 pt-12 pb-6 text-white" style={{ background: `linear-gradient(135deg, ${theme.greenDark} 0%, ${theme.greenMid} 100%)` }}>
        <button onClick={onBack} className="inline-flex items-center gap-1.5 text-white/90 text-[13px] mb-4"><ArrowLeft className="w-4 h-4" />Tilbage</button>
        <div className="text-[11px] uppercase tracking-widest font-bold text-emerald-200">Randers Volleyballklub</div>
        <h1 className="text-2xl font-bold mt-1">{d.title}</h1>
        <p className="text-[13px] text-white/80 mt-2 leading-relaxed">{d.intro}</p>
      </div>

      <div className="px-5 mt-5">
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-3 flex gap-2.5 mb-4">
          <AlertTriangle className="w-4 h-4 text-amber-700 shrink-0 mt-0.5" />
          <p className="text-[11px] text-amber-900 leading-relaxed">
            <strong>Udkast.</strong> Teksten skal godkendes af bestyrelsen, før appen sendes ud til medlemmerne.
          </p>
        </div>

        <div className="bg-white rounded-2xl border border-stone-100 shadow-sm divide-y divide-stone-100">
          {d.sections.map((sec) => (
            <div key={sec.h} className="p-4">
              <h2 className="text-[13px] font-bold text-stone-900 mb-2">{sec.h}</h2>
              {sec.p.map((para, i) => (
                <p key={i} className="text-[13px] text-stone-600 leading-relaxed mb-2 last:mb-0">{para}</p>
              ))}
            </div>
          ))}
        </div>

        <p className="text-[11px] text-stone-400 mt-4 text-center">Senest opdateret {LEGAL_UPDATED}</p>
      </div>
    </div>
  );
};

const ResetPasswordScreen = ({ onDone }) => {
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);

  const handleSave = async () => {
    setError("");
    if (password.length < 6) { setError("Adgangskode skal være mindst 6 tegn"); return; }
    if (password !== confirm) { setError("Adgangskoderne matcher ikke"); return; }
    setLoading(true);
    const { error } = await supabase.auth.updateUser({ password });
    setLoading(false);
    if (error) { setError(error.message); return; }
    setSuccess(true);
    setTimeout(() => onDone(), 2000);
  };

  return (
    <div className="min-h-screen relative overflow-hidden flex items-center" style={{ background: `linear-gradient(160deg, ${theme.greenDark} 0%, ${theme.greenMid} 55%, ${theme.purple} 100%)` }}>
      <div className="relative max-w-md mx-auto w-full px-6">
        <div className="bg-white rounded-3xl shadow-2xl p-6">
          <div className="flex flex-col items-center mb-5">
            <div className="w-14 h-14 rounded-2xl flex items-center justify-center mb-3" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
              <Lock className="w-7 h-7 text-white" />
            </div>
            <h2 className="text-xl font-bold text-stone-900">Vælg ny adgangskode</h2>
            <p className="text-[13px] text-stone-500 mt-1 text-center">Indtast en ny adgangskode på mindst 6 tegn</p>
          </div>
          {success ? (
            <div className="bg-emerald-50 border border-emerald-200 rounded-xl p-4 flex items-center gap-3 text-emerald-800">
              <Check className="w-5 h-5" />
              <div className="text-sm font-semibold">Adgangskode opdateret! Logger ind...</div>
            </div>
          ) : (
            <div className="space-y-3">
              <AuthField icon={<Lock className="w-4 h-4" />} label="Ny adgangskode" type="password" value={password} onChange={setPassword} placeholder="Mindst 6 tegn" />
              <AuthField icon={<Lock className="w-4 h-4" />} label="Bekræft adgangskode" type="password" value={confirm} onChange={setConfirm} placeholder="Gentag" />
              {error && <p className="text-[12px] text-pink-600">{error}</p>}
              <button onClick={handleSave} disabled={loading} className="w-full py-3.5 rounded-xl font-bold text-white shadow-lg disabled:opacity-60 mt-2" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
                {loading ? "Gemmer..." : "Gem adgangskode"}
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

const AuthScreen = ({ onAuthenticated, onShowLegal }) => {
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
  const [resetSent, setResetSent] = useState(false);
  const [confirmEmailSent, setConfirmEmailSent] = useState(false);

  const [teams, setTeams] = useState([]);
  const [teamsLoaded, setTeamsLoaded] = useState(false);

  useEffect(() => {
    // Holdene hentes UDEN session — man vælger sit hold, mens man opretter sig.
    // Går det galt, er den forkerte reaktion at finde på et holdnavn: så ender
    // alle nye medlemmer samme sted, og ingen opdager det. Sig det i stedet.
    supabase.from("teams").select("name").order("name").then(({ data, error }) => {
      if (error) reportError(`Kunne ikke hente hold: ${error.message}`, "signup");
      setTeams((data || []).map((t) => t.name));
      setTeamsLoaded(true);
    });
  }, []);

  const validate = () => {
    const e = {};
    if (!email) e.email = "E-mail er påkrævet";
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) e.email = "Ugyldig e-mail";
    if (mode !== "forgot") {
      if (!password) e.password = "Adgangskode er påkrævet";
      else if (password.length < 6) e.password = "Mindst 6 tegn";
    }
    if (mode === "signup") {
      if (!name) e.name = "Navn er påkrævet";
      if (!team) e.team = "Vælg dit hold";
      if (!acceptTerms) e.terms = "Du skal acceptere vilkårene";
    }
    setErrors(e);
    return Object.keys(e).length === 0;
  };

  const handleForgot = async () => {
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      setErrors({ email: "Indtast en gyldig e-mail" });
      return;
    }
    setLoading(true);
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: window.location.origin,
    });
    setLoading(false);
    if (error) { setErrors({ email: error.message }); return; }
    setResetSent(true);
  };

  const handleSubmit = async (e) => {
    if (e) e.preventDefault();
    if (!validate()) return;
    setLoading(true);
    try {
      if (mode === "login") {
        const { data, error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) { setErrors({ email: error.message }); setLoading(false); return; }
        onAuthenticated({ email: data.user.email, userId: data.user.id, isNew: false });
      } else {
        const { data, error } = await supabase.auth.signUp({
          email, password,
          options: { data: { name, team, phone: phone.trim() } },
        });
        if (error) { setErrors({ email: error.message }); setLoading(false); return; }

        // Kræver projektet e-mailbekræftelse, får man ingen session med det
        // samme. Så skal brugeren i indbakken – ikke sendes videre ind i
        // appen, hvor alting ville fejle uden en gyldig session.
        if (!data.session) {
          setLoading(false);
          setConfirmEmailSent(true);
          return;
        }

        onAuthenticated({ email: data.user?.email || email, userId: data.user?.id, name, team, phone, isNew: true });
      }
    } catch {
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
          {mode !== "forgot" && (
            <div className="bg-stone-100 rounded-xl p-1 flex mb-6">
              <button onClick={() => { setMode("login"); setErrors({}); setResetSent(false); }} className={`flex-1 py-2.5 rounded-lg text-sm font-bold transition-all ${mode === "login" ? "bg-white text-stone-900 shadow-sm" : "text-stone-500"}`}>Log ind</button>
              <button onClick={() => { setMode("signup"); setErrors({}); setResetSent(false); }} className={`flex-1 py-2.5 rounded-lg text-sm font-bold transition-all ${mode === "signup" ? "bg-white text-stone-900 shadow-sm" : "text-stone-500"}`}>Opret bruger</button>
            </div>
          )}

          <h2 className="text-xl font-bold text-stone-900 mb-1">{mode === "login" ? "Velkommen tilbage" : mode === "signup" ? "Bliv frivillig" : "Nulstil adgangskode"}</h2>
          <p className="text-[13px] text-stone-500 mb-5">{mode === "login" ? "Log ind for at se dine opgaver og point" : mode === "signup" ? "Opret en profil og kom i gang med at samle point" : "Indtast din e-mail, så sender vi dig et link til at nulstille din adgangskode"}</p>

          {confirmEmailSent ? (
            <div className="space-y-4">
              <div className="bg-emerald-50 border border-emerald-200 rounded-xl p-4 flex items-start gap-3">
                <Mail className="w-5 h-5 text-emerald-600 shrink-0 mt-0.5" />
                <div>
                  <div className="font-bold text-emerald-900 text-sm">Bekræft din e-mail</div>
                  <p className="text-[12px] text-emerald-800 mt-1 leading-relaxed">
                    Vi har sendt et link til <strong>{email}</strong>. Klik på det for at aktivere din profil.
                    Derefter kan du logge ind – og så mangler kun en administrators godkendelse.
                  </p>
                </div>
              </div>
              <button onClick={() => { setConfirmEmailSent(false); setMode("login"); setErrors({}); }} className="w-full py-3 rounded-xl bg-stone-100 text-stone-700 text-sm font-bold">
                Tilbage til login
              </button>
            </div>
          ) : mode === "forgot" && resetSent ? (
            <div className="space-y-4">
              <div className="bg-emerald-50 border border-emerald-200 rounded-xl p-4 flex items-start gap-3">
                <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0 mt-0.5" />
                <div>
                  <div className="font-bold text-emerald-900 text-sm">Tjek din indbakke</div>
                  <p className="text-[12px] text-emerald-800 mt-0.5">Vi har sendt et link til <strong>{email}</strong>. Klik på linket for at vælge en ny adgangskode.</p>
                </div>
              </div>
              <button onClick={() => { setMode("login"); setResetSent(false); setErrors({}); }} className="w-full py-3 rounded-xl bg-stone-100 text-stone-700 text-sm font-bold">
                Tilbage til login
              </button>
            </div>
          ) : (
          <form className="space-y-3" onSubmit={mode === "forgot" ? (e) => { e.preventDefault(); handleForgot(); } : handleSubmit} autoComplete="on">
            {mode === "signup" && <AuthField icon={<User className="w-4 h-4" />} label="Fulde navn" name="name" autoComplete="name" value={name} onChange={setName} placeholder="F.eks. Mette Sørensen" error={errors.name} />}
            <AuthField icon={<AtSign className="w-4 h-4" />} label="E-mail" type="email" name="email" autoComplete="email" value={email} onChange={setEmail} placeholder="din@email.dk" error={errors.email} />
            {mode !== "forgot" && <AuthField icon={<Lock className="w-4 h-4" />} label="Adgangskode" type={showPassword ? "text" : "password"} name="password" autoComplete={mode === "signup" ? "new-password" : "current-password"} value={password} onChange={setPassword} placeholder={mode === "signup" ? "Mindst 6 tegn" : "••••••••"} error={errors.password} rightIcon={<button type="button" onClick={() => setShowPassword(!showPassword)} className="text-stone-400">{showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}</button>} />}
            {mode === "login" && (
              <div className="text-right">
                <button type="button" onClick={() => { setMode("forgot"); setErrors({}); }} className="text-[12px] text-emerald-700 font-semibold hover:underline">
                  Glemt adgangskode?
                </button>
              </div>
            )}

            {mode === "signup" && <>
              <AuthField icon={<Phone className="w-4 h-4" />} label="Telefon (valgfri)" type="tel" name="tel" autoComplete="tel" value={phone} onChange={setPhone} placeholder="+45 ..." />
              <div>
                <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-1.5">Hold</label>
                <div className="relative">
                  <div className="absolute left-3 top-1/2 -translate-y-1/2 text-stone-400 pointer-events-none"><Users className="w-4 h-4" /></div>
                  <select value={team} onChange={(e) => setTeam(e.target.value)} disabled={!teamsLoaded || teams.length === 0} className={`w-full pl-10 pr-10 py-3 text-sm bg-stone-50 rounded-xl border outline-none appearance-none transition-colors disabled:opacity-60 ${errors.team ? "border-pink-300 bg-pink-50" : "border-stone-200 focus:border-emerald-500"}`}>
                    <option value="">
                      {!teamsLoaded ? "Henter hold..." : teams.length === 0 ? "Ingen hold tilgængelige" : "Vælg dit hold..."}
                    </option>
                    {teams.map((t) => <option key={t} value={t}>{t}</option>)}
                  </select>
                  <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-stone-400 pointer-events-none" />
                </div>
                {teamsLoaded && teams.length === 0 && (
                  <p className="text-[11px] text-amber-700 mt-1">
                    Holdlisten kunne ikke hentes. Skriv til {LEGAL_CONTACT} — det er ikke noget, du kan rette.
                  </p>
                )}
                {errors.team && <p className="text-[11px] text-pink-600 mt-1">{errors.team}</p>}
              </div>
              <label className="flex items-start gap-2.5 pt-1 cursor-pointer">
                <input type="checkbox" checked={acceptTerms} onChange={(e) => setAcceptTerms(e.target.checked)} className="mt-0.5 w-4 h-4 accent-pink-500" />
                <span className="text-[12px] text-stone-600 leading-relaxed">Jeg accepterer klubbens{" "}
                  <button type="button" onClick={(e) => { e.preventDefault(); onShowLegal("terms"); }} className="text-emerald-700 font-semibold underline">vilkår</button>{" "}og{" "}
                  <button type="button" onClick={(e) => { e.preventDefault(); onShowLegal("privacy"); }} className="text-emerald-700 font-semibold underline">privatlivspolitik (GDPR)</button>
                </span>
              </label>
              {errors.terms && <p className="text-[11px] text-pink-600 -mt-2">{errors.terms}</p>}
            </>}

            <button type="submit" disabled={loading} className="w-full py-3.5 rounded-xl font-bold text-white shadow-lg active:scale-[0.98] transition-transform flex items-center justify-center gap-2 mt-2 disabled:opacity-60" style={{ background: `linear-gradient(135deg, ${theme.purple} 0%, ${theme.pink} 100%)`, boxShadow: "0 8px 24px -8px rgba(236, 72, 153, 0.5)" }}>
              {loading ? (
                <>
                  <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  {mode === "login" ? "Logger ind..." : mode === "signup" ? "Opretter profil..." : "Sender..."}
                </>
              ) : (
                <>
                  {mode === "login" ? "Log ind" : mode === "signup" ? "Opret min profil" : "Send nulstillings-link"}
                  <ArrowRight className="w-4 h-4" />
                </>
              )}
            </button>
            {mode === "forgot" && (
              <button type="button" onClick={() => { setMode("login"); setErrors({}); }} className="w-full py-2.5 text-[12px] text-stone-600 font-semibold">
                ← Tilbage til login
              </button>
            )}
          </form>
          )}
        </div>

        <div className="text-center mt-5 text-[11px] text-white/70">© Randers Volleyballklub 2026</div>
      </div>
    </div>
  );
};

const DA_MONTH_NAMES = ["Januar","Februar","Marts","April","Maj","Juni","Juli","August","September","Oktober","November","December"];

const TasksScreen = ({ tasks, onTaskClick, claimedIds, onOpenNotifications, onOpenSwaps, onOpenCalendar, unreadCount }) => {
  const [catFilter,     setCatFilter]     = useState("Alle");
  const [dateFilter,    setDateFilter]    = useState("Alle");
  const [sortOrder,     setSortOrder]     = useState("date");   // "date" | "points_desc" | "points_asc"
  const [query,         setQuery]         = useState("");
  const [showLongTasks, setShowLongTasks] = useState(false);
  const [showFilters,   setShowFilters]   = useState(false);
  const [showPast,      setShowPast]      = useState(false);

  const catFilters  = ["Alle", "Haster", "Kampafvikling & Sekretærbord", "Hygge og Socialt", "Holdleder & Transport", "Stævneplanlægning og Afholdelse", "Kommunikation & PR", "Faciliteter & Materialer", "Klubadministration"];
  const dateFilters = ["Alle", "Denne måned", "Næste måned", "Halvt sæson"];

  const sortOptions = [
    { id: "date",        label: "Dato ↑" },
    { id: "points_desc", label: "Point ↓" },
    { id: "points_asc",  label: "Point ↑" },
  ];

  const visible = useMemo(() => {
    const today = new Date();
    const thisMonth = today.getMonth();
    const thisYear  = today.getFullYear();
    const nextMonth = (thisMonth + 1) % 12;
    const nextYear  = thisMonth === 11 ? thisYear + 1 : thisYear;
    const halfEnd   = new Date(thisYear, thisMonth + 6, 1);
    // Dagen i dag tæller stadig med – en tjans kl. 19 er ikke overstået kl. 08.
    const cutoff    = new Date(thisYear, thisMonth, today.getDate(), 0, 0, 0);

    return tasks
      .filter((t) => {
        if (t.durationType && t.durationType !== "single") return false;
        if (claimedIds.has(t.id)) return false;
        // Overståede opgaver skal ud af feedet, ellers vokser listen bare.
        if (!showPast) {
          const d = parseTaskDate(t);
          if (d && d < cutoff) return false;
        }
        if (catFilter === "Haster" && !t.urgent) return false;
        if (catFilter !== "Alle" && catFilter !== "Haster" && t.category !== catFilter) return false;
        if (query && !t.title.toLowerCase().includes(query.toLowerCase())) return false;
        if (dateFilter !== "Alle") {
          const d = parseTaskDate(t);
          if (!d) return false;
          if (dateFilter === "Denne måned"  && !(d.getMonth() === thisMonth && d.getFullYear() === thisYear)) return false;
          if (dateFilter === "Næste måned"  && !(d.getMonth() === nextMonth && d.getFullYear() === nextYear)) return false;
          if (dateFilter === "Halvt sæson"  && !(d >= today && d < halfEnd)) return false;
        }
        return true;
      })
      .sort((a, b) => {
        if (sortOrder === "points_desc") return b.points - a.points;
        if (sortOrder === "points_asc")  return a.points - b.points;
        const da = parseTaskDate(a), db = parseTaskDate(b);
        if (!da && !db) return 0;
        if (!da) return 1;
        if (!db) return -1;
        return da - db;
      });
  }, [tasks, catFilter, dateFilter, sortOrder, query, claimedIds, showPast]);

  // Group by month for display
  const grouped = useMemo(() => {
    const map = new Map();
    visible.forEach((t) => {
      const d = parseTaskDate(t);
      const key = d ? `${d.getFullYear()}-${String(d.getMonth()).padStart(2,"0")}` : "zz-ukendt";
      const label = d ? `${DA_MONTH_NAMES[d.getMonth()]} ${d.getFullYear()}` : "Ukendt dato";
      if (!map.has(key)) map.set(key, { label, tasks: [] });
      map.get(key).tasks.push(t);
    });
    return Array.from(map.entries()).sort(([a],[b]) => a.localeCompare(b)).map(([,v]) => v);
  }, [visible]);

  const longTasks = useMemo(() =>
    tasks.filter((t) => t.durationType && t.durationType !== "single" && !claimedIds.has(t.id) &&
      (catFilter === "Alle" || t.category === catFilter) &&
      (!query || t.title.toLowerCase().includes(query.toLowerCase()))),
  [tasks, catFilter, query, claimedIds]);

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
        {/* Søg + filterknap */}
        <div className="bg-white rounded-2xl shadow-lg border border-stone-100 p-3 mb-3">
          <div className="flex items-center gap-2">
            <div className="flex items-center gap-2 bg-stone-50 rounded-xl px-3 py-2 border border-stone-100 flex-1">
              <Search className="w-4 h-4 text-stone-400 shrink-0" />
              <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Søg i opgaver..." className="flex-1 bg-transparent outline-none text-sm placeholder:text-stone-400" />
              {query && <button onClick={() => setQuery("")}><X className="w-4 h-4 text-stone-400" /></button>}
            </div>
            <button
              onClick={() => setShowFilters((v) => !v)}
              className={`shrink-0 w-9 h-9 rounded-xl border flex items-center justify-center transition-all ${showFilters || dateFilter !== "Alle" || catFilter !== "Alle" || sortOrder !== "date" ? "text-white border-transparent shadow-md" : "bg-stone-50 border-stone-200 text-stone-500"}`}
              style={showFilters || dateFilter !== "Alle" || catFilter !== "Alle" || sortOrder !== "date" ? { background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` } : {}}
            >
              <Filter className="w-4 h-4" />
            </button>
          </div>

          {showFilters && (
            <div className="mt-3 space-y-3 border-t border-stone-100 pt-3">
              {/* Dato */}
              <div>
                <div className="text-[10px] uppercase tracking-widest font-bold text-stone-400 mb-1.5">Periode</div>
                <div className="flex gap-1.5 flex-wrap">
                  {dateFilters.map((f) => {
                    const active = dateFilter === f;
                    return (
                      <button key={f} onClick={() => setDateFilter(f)} className={`px-3 py-1 rounded-full text-[12px] font-semibold transition-all ${active ? "text-white shadow-sm" : "bg-stone-100 text-stone-600 hover:bg-stone-200"}`} style={active ? { background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` } : {}}>
                        {f}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Sortering */}
              <div>
                <div className="text-[10px] uppercase tracking-widest font-bold text-stone-400 mb-1.5">Sortering</div>
                <div className="flex gap-1.5">
                  {sortOptions.map((s) => {
                    const active = sortOrder === s.id;
                    return (
                      <button key={s.id} onClick={() => setSortOrder(s.id)} className={`px-3 py-1 rounded-full text-[12px] font-semibold transition-all ${active ? "text-white shadow-sm" : "bg-stone-100 text-stone-600 hover:bg-stone-200"}`} style={active ? { background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` } : {}}>
                        {s.label}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Kategori */}
              <div>
                <div className="text-[10px] uppercase tracking-widest font-bold text-stone-400 mb-1.5">Kategori</div>
                <ScrollRow className="flex gap-1.5 overflow-x-auto pb-1 -mx-1 px-1 scrollbar-hide">
                  {catFilters.map((f) => {
                    const active = catFilter === f;
                    const isUrgent = f === "Haster";
                    return (
                      <button key={f} onClick={() => setCatFilter(f)} className={`shrink-0 px-3 py-1 rounded-full text-[12px] font-semibold transition-all flex items-center gap-1 ${active ? "text-white shadow-sm" : "bg-stone-100 text-stone-600 hover:bg-stone-200"}`} style={active ? { background: isUrgent ? `linear-gradient(135deg, ${theme.pink}, ${theme.purple})` : `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` } : {}}>
                        {isUrgent && <Flame className="w-3 h-3" />}{f}
                      </button>
                    );
                  })}
                </ScrollRow>
              </div>

              {/* Tidligere opgaver */}
              <div>
                <div className="text-[10px] uppercase tracking-widest font-bold text-stone-400 mb-1.5">Overstået</div>
                <label className="flex items-center gap-2 cursor-pointer">
                  <input type="checkbox" id="vis-tidligere" checked={showPast} onChange={(e) => setShowPast(e.target.checked)} className="w-4 h-4 accent-emerald-600" />
                  <span className="text-[12px] text-stone-600">Vis også opgaver der er overstået</span>
                </label>
              </div>

              {/* Nulstil */}
              {(dateFilter !== "Alle" || catFilter !== "Alle" || sortOrder !== "date" || showPast) && (
                <button onClick={() => { setDateFilter("Alle"); setCatFilter("Alle"); setSortOrder("date"); setShowPast(false); }} className="text-[11px] text-stone-400 hover:text-stone-600 underline">
                  Nulstil filtre
                </button>
              )}
            </div>
          )}
        </div>

        {/* Aktive filter-chips (vises kun når filtermenuen er lukket) */}
        {!showFilters && (dateFilter !== "Alle" || catFilter !== "Alle" || sortOrder !== "date" || showPast) && (
          <div className="flex gap-1.5 flex-wrap mb-2">
            {showPast && (
              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-stone-200 text-stone-700">
                Inkl. overståede<button onClick={() => setShowPast(false)}><X className="w-3 h-3" /></button>
              </span>
            )}
            {dateFilter !== "Alle" && (
              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-semibold text-white" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
                {dateFilter}<button onClick={() => setDateFilter("Alle")}><X className="w-3 h-3" /></button>
              </span>
            )}
            {catFilter !== "Alle" && (
              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-semibold text-white" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>
                {catFilter}<button onClick={() => setCatFilter("Alle")}><X className="w-3 h-3" /></button>
              </span>
            )}
            {sortOrder !== "date" && (
              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-stone-200 text-stone-700">
                {sortOptions.find(s => s.id === sortOrder)?.label}<button onClick={() => setSortOrder("date")}><X className="w-3 h-3" /></button>
              </span>
            )}
          </div>
        )}
      </div>

      <div className="px-5 mt-2">
        {visible.length === 0 && longTasks.length === 0 ? (
          <div className="text-center py-12 text-stone-500">
            <AlertCircle className="w-10 h-10 mx-auto mb-2 text-stone-300" />
            <p className="text-sm">Ingen opgaver matcher lige nu</p>
          </div>
        ) : (
          <>
            {sortOrder === "date" ? (
              grouped.map((group) => (
                <div key={group.label} className="mb-3">
                  <div className="flex items-center gap-2 mb-1.5">
                    <span className="text-[10px] font-bold uppercase tracking-widest text-stone-400">{group.label}</span>
                    <div className="flex-1 h-px bg-stone-200" />
                    <span className="text-[10px] text-stone-400">{group.tasks.length}</span>
                  </div>
                  <div className="space-y-1.5">
                    {group.tasks.map((t) => <TaskCard key={t.id} task={t} onClick={onTaskClick} />)}
                  </div>
                </div>
              ))
            ) : (
              <div className="space-y-1.5 mb-3">
                {visible.map((t) => <TaskCard key={t.id} task={t} onClick={onTaskClick} />)}
              </div>
            )}

            {/* Long-running / season tasks */}
            {longTasks.length > 0 && (
              <div className="mt-2 mb-4">
                <button onClick={() => setShowLongTasks((v) => !v)}
                  className="w-full flex items-center gap-2 py-2 mb-2">
                  <span className="text-[11px] font-bold uppercase tracking-widest text-violet-600">Sæsonopgaver & langvarige</span>
                  <div className="flex-1 h-px bg-violet-200" />
                  <span className="text-[10px] text-violet-500 font-semibold">{longTasks.length}</span>
                  <ChevronDown className={`w-4 h-4 text-violet-500 transition-transform ${showLongTasks ? "rotate-180" : ""}`} />
                </button>
                {!showLongTasks && (
                  <p className="text-[11px] text-stone-400 text-center pb-1">Tryk for at se sæson- og årsopgaver</p>
                )}
                {showLongTasks && (
                  <div className="space-y-3">
                    {longTasks.map((t) => <TaskCard key={t.id} task={t} onClick={onTaskClick} />)}
                  </div>
                )}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
};

// Mærkerne følger klubbens pointmål, som sættes i admin-panelet.
const badgeDefs = (halfGoal) => [
  { id: "signup",   emoji: "🌱", label: "Frivillig",     desc: "Tilmeldt som frivillig",                      req: () => true },
  { id: "first",    emoji: "⭐", label: "Første tjans",  desc: "Taget sin første opgave",                     req: (e, t) => t >= 1 },
  { id: "halfway",  emoji: "🔥", label: "Halvvejs",      desc: `${Math.round(halfGoal / 2)} point optjent`,   req: (e) => e >= halfGoal / 2 },
  { id: "halfgoal", emoji: "🏅", label: "Halvsmål nået", desc: `${halfGoal} point – bidragsfri`,              req: (e) => e >= halfGoal },
  { id: "veteran",  emoji: "🎯", label: "Veteran",       desc: "5 tjanser taget",                             req: (e, t) => t >= 5 },
  { id: "fullgoal", emoji: "🏆", label: "Sæsonmål",      desc: `${halfGoal * 2} point – hele sæsonen`,        req: (e) => e >= halfGoal * 2 },
];

const Dashboard = ({ claimedTasks, currentUser, onTaskClick, pointGoal, pendingPoints = 0, claimStatus }) => {
  // Point kommer udelukkende fra databasen. Tidligere blev opgavepointene
  // lagt til her OVENI den gemte sum, hvor de allerede indgik – derfor viste
  // dashboardet og scoreboardet forskellige tal for den samme frivillige.
  const earned    = currentUser?.pointsEarned || 0;
  const tasks     = currentUser?.tasksCompleted || 0;
  const halfGoal  = pointGoal || 100;
  const fullGoal  = halfGoal * 2;
  const pct       = Math.min(100, Math.round((earned / fullGoal) * 100));
  const halfPct   = Math.min(50, Math.round((Math.min(earned, halfGoal) / fullGoal) * 100));
  const restPct   = Math.max(0, Math.min(50, Math.round(((earned - halfGoal) / fullGoal) * 100)));
  const halfDone  = earned >= halfGoal;
  const fullDone  = earned >= fullGoal;

  const [rank, setRank] = useState(null);
  useEffect(() => {
    if (!currentUser?.id) return;
    supabase.from("profiles").select("id", { count: "exact", head: true })
      .gt("points", currentUser.pointsEarned || 0)
      .then(({ count }) => setRank((count ?? 0) + 1));
  }, [currentUser?.id, currentUser?.pointsEarned]);

  const badges       = useMemo(() => badgeDefs(halfGoal), [halfGoal]);
  const earnedBadges = badges.filter((b) => b.req(earned, tasks));

  const statusOf  = (t) => claimStatus?.get(t.id) || "signed_up";
  const openTasks = claimedTasks.filter((t) => statusOf(t) === "signed_up");

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
                  <span className="text-lg text-white/70">/ {fullGoal}</span>
                </div>
                <div className="text-[10px] text-white/60 mt-0.5">Halvt sæsonmål: {halfGoal} pt</div>
                {pendingPoints > 0 && (
                  <div className="inline-flex items-center gap-1 mt-2 px-2 py-0.5 rounded-full bg-white/15 border border-white/20 text-[10px] font-semibold">
                    <Clock className="w-2.5 h-2.5" />{pendingPoints} pt afventer bekræftelse
                  </div>
                )}
              </div>
              <div className={`px-3 py-1.5 rounded-full text-xs font-bold ${fullDone ? "bg-emerald-400/80" : ""}`} style={!fullDone ? { background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` } : {}}>{pct}%</div>
            </div>

            {/* Two-segment progress bar: first half (0-100) + second half (100-200) */}
            <div className="h-3 bg-white/15 rounded-full overflow-hidden mb-1 relative flex">
              <div className="h-full rounded-l-full transition-all duration-700 relative overflow-hidden" style={{ width: `${halfPct}%`, background: `linear-gradient(90deg, ${theme.pinkLight}, ${theme.pink})`, boxShadow: `0 0 8px ${theme.pink}80` }} />
              {restPct > 0 && <div className="h-full transition-all duration-700" style={{ width: `${restPct}%`, background: `linear-gradient(90deg, ${theme.purple}, #7c3aed)` }} />}
            </div>
            <div className="flex justify-between text-[9px] text-white/50 mb-2">
              <span>0</span><span>{halfGoal}</span><span>{fullGoal}</span>
            </div>

            <div className="text-xs text-white/80">
              {fullDone
                ? <span className="text-emerald-100 font-semibold">🎉 Hele sæsonens mål nået!</span>
                : halfDone
                  ? <span>✓ 1. halvsmål nået · <strong className="text-white">{fullGoal - earned} pt</strong> til hele sæsonen</span>
                  : <span><strong className="text-white">{halfGoal - earned} pt</strong> til 1. halvsmål – fritaget bidrag</span>}
            </div>
            <div className="text-[10px] text-white/50 mt-2 leading-relaxed">
              Point tæller med, når en administrator har bekræftet, at tjansen er gennemført.
            </div>
          </div>
        </div>
      </div>

      <div className="px-5 mt-5 grid grid-cols-3 gap-2.5">
        <div className="bg-white rounded-xl p-3 border border-stone-100 shadow-sm"><div className="text-xl font-black text-stone-900">{openTasks.length}</div><div className="text-[10px] uppercase tracking-wider text-stone-500 font-bold">Kommende</div></div>
        <div className="bg-white rounded-xl p-3 border border-stone-100 shadow-sm">
          <div className="text-xl font-black" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})`, WebkitBackgroundClip: "text", WebkitTextFillColor: "transparent" }}>{earnedBadges.length}</div>
          <div className="text-[10px] uppercase tracking-wider text-stone-500 font-bold">Badges</div>
        </div>
        <div className="bg-white rounded-xl p-3 border border-stone-100 shadow-sm">
          <div className="text-xl font-black text-stone-900">{rank != null ? `#${rank}` : "–"}</div>
          <div className="text-[10px] uppercase tracking-wider text-stone-500 font-bold">Rangliste</div>
        </div>
      </div>

      {/* Badges */}
      {earnedBadges.length > 0 && (
        <div className="px-5 mt-5">
          <h2 className="text-sm font-bold text-stone-900 mb-2">Mine badges</h2>
          <ScrollRow className="flex gap-2 overflow-x-auto -mx-5 px-5 pb-1 scrollbar-hide">
            {badges.map((b) => {
              const unlocked = b.req(earned, tasks);
              return (
                <div key={b.id} className={`shrink-0 flex flex-col items-center gap-1 px-3 py-2.5 rounded-xl border text-center min-w-[72px] transition-all ${unlocked ? "bg-white border-stone-200 shadow-sm" : "bg-stone-100 border-stone-100 opacity-40"}`}>
                  <span className="text-2xl">{b.emoji}</span>
                  <span className={`text-[10px] font-bold leading-tight ${unlocked ? "text-stone-800" : "text-stone-400"}`}>{b.label}</span>
                </div>
              );
            })}
          </ScrollRow>
        </div>
      )}

      <div className="px-5 mt-6">
        <div className="flex items-center justify-between mb-3"><h2 className="text-sm font-bold text-stone-900">Mine tjanser</h2></div>
        {claimedTasks.length === 0 ? (
          <div className="bg-white rounded-xl p-5 border border-dashed border-stone-200 text-center">
            <ListChecks className="w-8 h-8 mx-auto mb-2 text-stone-300" />
            <p className="text-sm text-stone-500">Du har endnu ikke taget nogen tjanser.</p>
            <p className="text-xs text-stone-400 mt-1">Gå til <strong className="text-emerald-700">Opgaver</strong> for at komme i gang.</p>
          </div>
        ) : (
          <div className="space-y-2">
            {claimedTasks.map((t) => (
              <button key={t.id} onClick={() => onTaskClick && onTaskClick(t)} className="w-full bg-white rounded-xl px-3 py-2.5 border border-stone-100 shadow-sm flex items-center gap-3 hover:border-emerald-300 active:scale-[0.99] transition-all text-left">
                <div className="w-9 h-9 rounded-lg flex items-center justify-center text-white shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}><CategoryIcon type={t.icon} className="w-4 h-4" /></div>
                <div className="flex-1 min-w-0">
                  <div className="font-semibold text-[13px] text-stone-900 truncate">{t.title}</div>
                  <div className="text-[11px] text-stone-500 flex items-center gap-1.5 mt-0.5"><span>{t.date}</span>{t.time && <><span>·</span><span>{t.time}</span></>}</div>
                  <div className="mt-1"><ClaimStatusPill status={statusOf(t)} /></div>
                </div>
                <div className="shrink-0 flex items-center gap-1.5">
                  <div className={`px-2 py-0.5 rounded-full text-[11px] font-bold ${statusOf(t) === "completed" ? "text-white" : statusOf(t) === "no_show" ? "bg-stone-100 text-stone-400 line-through" : "text-white opacity-60"}`} style={statusOf(t) === "no_show" ? {} : { background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>{statusOf(t) === "completed" ? "+" : ""}{t.points}</div>
                  <ChevronRight className="w-4 h-4 text-stone-300" />
                </div>
              </button>
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
  const [selectedMember, setSelectedMember] = useState(null);

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
        <ScrollRow className="flex gap-2 overflow-x-auto pb-2 -mx-5 px-5 scrollbar-hide">
          {teams.map((t) => {
            const active = filter === t;
            return (
              <button key={t} onClick={() => setFilter(t)} className={`shrink-0 px-3.5 py-1.5 rounded-full text-[12px] font-semibold transition-all ${active ? "text-white shadow-md" : "bg-white text-stone-700 border border-stone-200"}`} style={active ? { background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` } : {}}>
                {t}
              </button>
            );
          })}
        </ScrollRow>
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
            <button key={m.id} onClick={() => setSelectedMember(m)} className="w-full flex items-center gap-3 px-4 py-3 border-b border-stone-100 last:border-b-0 hover:bg-stone-50 active:bg-stone-100 text-left">
              <div className="text-sm font-black text-stone-400 w-5 shrink-0">{i + 1}</div>
              <div className="w-10 h-10 rounded-full flex items-center justify-center font-bold text-white text-xs shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>{m.initials}</div>
              <div className="flex-1 min-w-0">
                <div className="font-semibold text-[14px] text-stone-900">{m.name}</div>
                <div className="text-[11px] text-stone-500">{m.team} · {m.tasksDone} opgaver</div>
              </div>
              <div className="text-right shrink-0"><div className="font-black text-base text-stone-900">{m.points}</div><div className="text-[9px] text-stone-400 uppercase">point</div></div>
              <ChevronRight className="w-4 h-4 text-stone-300 shrink-0" />
            </button>
          ))}
        </div>
      </div>

      {selectedMember && <MemberTasksModal member={selectedMember} onClose={() => setSelectedMember(null)} />}
    </div>
  );
};

// ============ KALENDER ============

const CalendarScreen = ({ tasks, claimedTasks, onTaskClick, onBack }) => {
  const [viewMode, setViewMode] = useState("month");
  const [current, setCurrent] = useState(() => { const d = new Date(); return new Date(d.getFullYear(), d.getMonth()); });

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

  // Opgaver fordelt paa dage i den viste maaned.
  //
  // Foer laeste den her den danske TEKST med et regulaert udtryk og slog
  // maaneden op i en tabel med seks maaneder:
  //
  //     { apr: 3, maj: 4, jun: 5, jul: 6, aug: 7, sep: 8 }
  //
  // Oktober til marts fandtes slet ikke, saa de opgaver var usynlige i
  // kalenderen. Aarstallet blev heller ikke set paa, saa en opgave i
  // september 2027 ville dukke op i september 2026.
  //
  // parseTaskDate() kan det hele i forvejen: den bruger ISO-datoen naar den
  // findes, og kender alle tolv danske maaneder som reserve.
  const tasksByDay = {};
  tasks.forEach((t) => {
    const d = parseTaskDate(t);
    if (!d) return;
    if (d.getFullYear() !== year || d.getMonth() !== month) return;
    const day = d.getDate();
    (tasksByDay[day] ||= []).push(t);
  });

  // Opgaver, der loeber over flere maaneder (uge, maaned, halv saeson, saeson)
  // og daekker den viste maaned uden at STARTE i den. De ville ellers vaere
  // usynlige hele vejen, og det er netop de store, faste tjanser.
  const maanedStart = new Date(year, month, 1, 12);
  const maanedSlut  = new Date(year, month + 1, 0, 12);
  const loebende = tasks.filter((t) => {
    if (!t.dateEnd) return false;
    const start = parseTaskDate(t);
    const slut  = new Date(t.dateEnd + "T12:00:00");
    if (!start || isNaN(slut)) return false;
    if (start.getFullYear() === year && start.getMonth() === month) return false; // vist i gitteret
    return start <= maanedSlut && slut >= maanedStart;
  });

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
            {/* .sort() aendrer arrayet, den kaldes paa — og her var det props
                fra foraelderen. Kopiér foerst. Og sorter paa den rigtige dato:
                foer sorterede den kun paa DAGEN i maaneden, saa 3. november
                lagde sig foer 20. oktober. */}
            {[...tasks].sort((a, b) => {
              const ad = parseTaskDate(a), bd = parseTaskDate(b);
              if (!ad && !bd) return 0;
              if (!ad) return 1;
              if (!bd) return -1;
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
        {/* Sæson- og månedsopgaver, der løber gennem denne måned uden at
            starte i den. De har ingen enkelt dag at sidde på i gitteret. */}
        {viewMode === "month" && loebende.length > 0 && (
          <div className="mt-4">
            <h2 className="text-[11px] uppercase tracking-widest font-bold text-stone-500 mb-2">
              Løber hele {monthNames[month]}
            </h2>
            <div className="space-y-2">
              {loebende.map((t) => (
                <button key={t.id} onClick={() => onTaskClick(t)}
                        className="w-full text-left bg-white rounded-xl p-3 border border-violet-200 shadow-sm hover:border-violet-300 flex items-center gap-3 active:scale-[0.99] transition-all">
                  <div className="w-9 h-9 rounded-lg flex items-center justify-center text-white shrink-0"
                       style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
                    <CalendarDays className="w-4 h-4" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="font-semibold text-[13px] text-stone-900 truncate">{t.title}</div>
                    <div className="text-[11px] text-stone-500">{t.date}</div>
                  </div>
                  <div className="px-2 py-0.5 rounded-full text-white text-[11px] font-black shrink-0"
                       style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>+{t.points}</div>
                </button>
              ))}
            </div>
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

const SwapScreen = ({ onBack, claimedTasks, currentUser, onSwapAccepted }) => {
  const [tab, setTab] = useState("available");
  const [offers, setOffers] = useState([]);
  const [showNewOffer, setShowNewOffer] = useState(false);
  const [selected, setSelected] = useState(null);
  const [swapError, setSwapError] = useState(null);
  const [accepting, setAccepting] = useState(false);

  const loadOffers = async () => {
    if (!currentUser?.id) return;
    const { data } = await supabase
      .from("swap_offers")
      .select(`*, offering_task:tasks!offering_task_id(id,title,date,time,location,points,icon), wants_task:tasks!wants_task_id(id,title,date), from_user:profiles!from_user_id(id,name,initials,team)`)
      .not("status", "in", '("accepted","declined")')
      .order("created_at", { ascending: false });
    if (!data) return;
    const claimedSet = new Set(claimedTasks.map((t) => t.id));
    setOffers(data.map((o) => {
      let status = o.from_user_id === currentUser.id ? "outgoing" : (o.wants_task_id && claimedSet.has(o.wants_task_id)) ? "incoming" : "available";
      return { id: o.id, status, from: o.from_user, offering: o.offering_task, wants: o.wants_task, message: o.message, sentAt: new Date(o.created_at).toLocaleDateString("da-DK") };
    }));
  };

  // Dataindlæsning ved visning. Reglerne advarer mod setState i en effect og
  // mod at udelade loadOffers fra deps, men her sker opdateringen først efter
  // et svar fra serveren — det er netop det, effects er til: at synkronisere
  // med noget uden for React. Tages loadOffers med i deps, kører den i ring.
  /* eslint-disable-next-line react-hooks/set-state-in-effect, react-hooks/exhaustive-deps */
  useEffect(() => { loadOffers(); }, [currentUser?.id]);

  const incoming  = offers.filter((o) => o.status === "incoming");
  const available = offers.filter((o) => o.status === "available");
  const outgoing  = offers.filter((o) => o.status === "outgoing");

  const remove = async (id) => {
    const { error } = await supabase.rpc("decline_swap", { p_offer_id: id });
    if (error) { setSwapError(error.message); return; }
    setOffers((prev) => prev.filter((o) => o.id !== id));
    setSwapError(null);
  };

  // Hele byttet – flyt tilmelding, flyt point, luk tilbuddet – sker i én
  // databasefunktion. Ellers kunne begge parter ende med at stå på opgaven.
  const acceptOffer = async (offer) => {
    setAccepting(true);
    const { error } = await supabase.rpc("accept_swap", { p_offer_id: offer.id });
    setAccepting(false);
    if (error) { setSwapError(error.message); return; }
    setSwapError(null);
    setSelected(null);
    await loadOffers();
    onSwapAccepted?.();
  };

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
        {swapError && (
          <div className="bg-red-50 border border-red-200 rounded-xl p-3 flex items-start gap-2">
            <AlertTriangle className="w-4 h-4 text-red-600 shrink-0 mt-0.5" />
            <p className="text-[12px] text-red-900 flex-1">{swapError}</p>
            <button onClick={() => setSwapError(null)} className="text-red-400"><X className="w-4 h-4" /></button>
          </div>
        )}
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
                    onAccept={() => acceptOffer(o)}
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
        <NewSwapModal claimedTasks={claimedTasks} currentUser={currentUser} onClose={() => { setShowNewOffer(false); loadOffers(); }} />
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
              {selected.status === "outgoing" ? (
                <button onClick={() => { remove(selected.id); setSelected(null); }} className="flex-[2] py-3 rounded-xl bg-stone-800 text-white font-bold shadow-md">Træk tilbuddet tilbage</button>
              ) : (
                <button onClick={() => acceptOffer(selected)} disabled={accepting} className="flex-[2] py-3 rounded-xl text-white font-bold shadow-md disabled:opacity-60" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>{accepting ? "Overtager..." : `Overtag tjansen (+${selected.offering.points} pt)`}</button>
              )}
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

const NewSwapModal = ({ claimedTasks, currentUser, onClose }) => {
  const [selected, setSelected] = useState(null);
  const [message, setMessage] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
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
          {error && <div className="bg-red-50 border border-red-200 rounded-xl p-3 text-[12px] text-red-900">{error}</div>}
        </div>
        <div className="sticky bottom-0 bg-white border-t border-stone-100 p-4 flex gap-2">
          <button onClick={onClose} className="flex-1 py-3 rounded-xl bg-stone-100 text-stone-700 font-semibold">Annullér</button>
          <button onClick={async () => {
            if (!selected || !currentUser?.id) return;
            setSaving(true);
            const { error } = await supabase.from("swap_offers").insert({ from_user_id: currentUser.id, offering_task_id: selected, message: message || null, status: "available" });
            setSaving(false);
            if (error) { setError("Kunne ikke oprette tilbuddet: " + error.message); return; }
            onClose();
          }} disabled={!selected || saving} className="flex-[2] py-3 rounded-xl text-white font-bold shadow-md disabled:opacity-50 flex items-center justify-center gap-2" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
            {saving ? <><div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />Sender...</> : "Tilbyd til bytte"}
          </button>
        </div>
      </div>
    </div>
  );
};

// ============ ADMIN CENTER ============

// Bootstrap: disse e-mails får automatisk super_admin
const ProfileEditSection = ({ currentUser, setCurrentUser, setToast }) => {
  const [name, setName]   = useState(currentUser?.name || "");
  const [phone, setPhone] = useState(currentUser?.phone || "");
  const [team, setTeam]   = useState(currentUser?.team || "");
  const [teams, setTeams] = useState([]);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved]   = useState(false);

  useEffect(() => {
    supabase.from("teams").select("name").order("name").then(({ data }) => {
      setTeams(data && data.length > 0 ? data.map((t) => t.name) : ["Ny"]);
    });
  }, []);

  const dirty = name !== (currentUser?.name || "") || phone !== (currentUser?.phone || "") || team !== (currentUser?.team || "");

  const save = async () => {
    if (!dirty || saving) return;
    setSaving(true);
    const { error } = await supabase.from("profiles").update({ name: name.trim(), phone: phone.trim(), team }).eq("id", currentUser.id);
    setSaving(false);
    if (error) { setToast("Kunne ikke gemme: " + error.message); setTimeout(() => setToast(null), 3000); return; }
    setCurrentUser((u) => ({ ...u, name: name.trim(), phone: phone.trim(), team,
      initials: name.trim().split(" ").map((n) => n[0]).slice(0, 2).join("").toUpperCase() }));
    setSaved(true);
    setToast("✅ Profil opdateret");
    setTimeout(() => { setToast(null); setSaved(false); }, 2500);
  };

  return (
    <div className="px-5 mt-5">
      <div className="bg-white rounded-2xl border border-stone-100 shadow-sm p-4 space-y-3">
        <div className="text-[11px] uppercase tracking-widest font-bold text-stone-500 mb-1">Rediger oplysninger</div>

        <div>
          <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-1.5">Navn</label>
          <div className="relative"><User className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-stone-400" />
            <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Dit fulde navn" className="w-full pl-9 pr-3 py-2.5 text-sm bg-stone-50 rounded-xl border border-stone-200 focus:border-emerald-500 outline-none" />
          </div>
        </div>

        <div>
          <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-1.5">Telefon</label>
          <div className="relative"><Phone className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-stone-400" />
            <input value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="+45 ..." type="tel" className="w-full pl-9 pr-3 py-2.5 text-sm bg-stone-50 rounded-xl border border-stone-200 focus:border-emerald-500 outline-none" />
          </div>
        </div>

        <div>
          <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-1.5">Hold</label>
          <div className="relative"><Users className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-stone-400" />
            <select value={team} onChange={(e) => setTeam(e.target.value)} className="w-full pl-9 pr-8 py-2.5 text-sm bg-stone-50 rounded-xl border border-stone-200 focus:border-emerald-500 outline-none appearance-none">
              <option value="">Vælg hold...</option>
              {teams.map((t) => <option key={t} value={t}>{t}</option>)}
            </select>
            <ChevronDown className="w-4 h-4 absolute right-3 top-1/2 -translate-y-1/2 text-stone-400 pointer-events-none" />
          </div>
        </div>

        <div>
          <label className="text-[11px] font-semibold text-stone-600 uppercase tracking-wider block mb-1.5">E-mail</label>
          <div className="relative"><Mail className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-stone-400" />
            <input value={currentUser?.email || ""} disabled className="w-full pl-9 pr-3 py-2.5 text-sm bg-stone-100 rounded-xl border border-stone-200 outline-none text-stone-500 cursor-not-allowed" />
          </div>
          <p className="text-[10px] text-stone-400 mt-1">E-mail kan ikke ændres her</p>
        </div>

        <button onClick={save} disabled={!dirty || saving} className="w-full py-3 rounded-xl font-bold text-white text-[13px] flex items-center justify-center gap-2 disabled:opacity-40 transition-opacity" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>
          {saving ? <><div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />Gemmer...</> : saved ? <><Check className="w-4 h-4" />Gemt!</> : "Gem ændringer"}
        </button>
      </div>
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
      const msg = upErr.message?.toLowerCase().includes("bucket")
        ? "Avatars-bucket mangler – se instruktioner i appen"
        : "Upload fejlede: " + upErr.message;
      setToast(msg);
      setTimeout(() => setToast(null), 4000);
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
  // Anmodningen kan komme to steder fra: profilen vi allerede har hentet,
  // eller et tryk lige nu. Begge dele læses ud af det samme udtryk.
  const [justRequested, setJustRequested] = useState(false);
  const [loading, setLoading] = useState(false);
  const requested = justRequested || !!currentUser?.adminRequested;

  const handleRequest = async () => {
    setLoading(true);
    const { error } = await supabase.rpc("request_admin_access");
    setLoading(false);
    if (error) {
      setToast("Kunne ikke sende anmodningen: " + error.message);
      setTimeout(() => setToast(null), 3500);
      return;
    }
    setJustRequested(true);
    setToast("📨 Din anmodning er sendt til Super Admin");
    setTimeout(() => setToast(null), 3000);
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

// Udseende pr. beskedtype. Typerne oprettes af databasen – se
// supabase/migrations/20260910120000_launch_hardening.sql, afsnit 6.
const NOTIF_STYLE = {
  approved:        { icon: <UserCheck className="w-4 h-4" />,      bg: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` },
  task_assigned:   { icon: <UserPlus className="w-4 h-4" />,       bg: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` },
  task_unassigned: { icon: <UserX className="w-4 h-4" />,          bg: `linear-gradient(135deg, ${theme.pink}, ${theme.purple})` },
  task_changed:    { icon: <Pencil className="w-4 h-4" />,         bg: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` },
  task_completed:  { icon: <CheckCircle2 className="w-4 h-4" />,   bg: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` },
  task_no_show:    { icon: <UserX className="w-4 h-4" />,          bg: `linear-gradient(135deg, #78716c, #57534e)` },
  task_reopened:   { icon: <Clock className="w-4 h-4" />,          bg: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` },
  task_cancelled:  { icon: <AlertTriangle className="w-4 h-4" />,  bg: `linear-gradient(135deg, ${theme.pink}, ${theme.purpleDark})` },
  swap_accepted:   { icon: <ArrowLeftRight className="w-4 h-4" />, bg: `linear-gradient(135deg, ${theme.greenMid}, ${theme.purple})` },
  swap_declined:   { icon: <ArrowLeftRight className="w-4 h-4" />, bg: `linear-gradient(135deg, ${theme.pink}, ${theme.purple})` },
  points_adjusted: { icon: <Zap className="w-4 h-4" />,            bg: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` },
  role_changed:    { icon: <ShieldCheck className="w-4 h-4" />,    bg: `linear-gradient(135deg, ${theme.greenDark}, ${theme.purple})` },
  task_reminder:   { icon: <Clock className="w-4 h-4" />,          bg: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` },
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
  // null = alt vel. "missing" = ingen profilraekke. "error" = serveren svarede ikke.
  const [profileProblem, setProfileProblem] = useState(null);

  // Har vi allerede en profil paa skaermen? Ref, ikke state: auth-lytteren
  // registreres een gang og ville ellers se en foraeldet vaerdi resten af
  // sessionen.
  const harProfilRef = useRef(false);

  // Er en profilhentning i gang lige nu? Bruges af sikkerhedsnettet, saa det
  // ikke afbryder en hentning der er paa vej.
  const henterProfilRef = useRef(false);

  // Den hentning der er i gang, hvis der er en. Flere ting kan finde paa at
  // bede om profilen i samme sekund — getSession ved opstart, auth-lytteren,
  // en gentilslutning. De skal dele ét svar, ikke sende hvert sit kald.
  const profilKaldRef = useRef(null);

  // Samme historie for opgavelisten: getSession og auth-lytteren beder om
  // den i samme sekund ved en almindelig aabning (supabase-js sender baade
  // SIGNED_IN og INITIAL_SESSION for den samme gemte session).
  const opgaveKaldRef = useRef(null);

  const [authLoading, setAuthLoading] = useState(() =>
    !(typeof window !== "undefined" && window.location.hash.includes("type=recovery")));
  const [currentUser, setCurrentUser] = useState(null);
  const [tab, setTab] = useState("tasks");
  // Tilmeldingerne gemmes nu med deres tilstand, fordi point først tæller
  // når en admin har bekræftet, at tjansen er gennemført.
  const [myClaims, setMyClaims] = useState([]);
  const [toast, setToast] = useState(null);
  const [welcomeToast, setWelcomeToast] = useState(null);
  const [showCalendar, setShowCalendar] = useState(false);
  const [showSwaps, setShowSwaps] = useState(false);
  const [showAdmin, setShowAdmin] = useState(false);
  const [showNotif, setShowNotif] = useState(false);
  const [notifications, setNotifications] = useState([]);
  const [selectedTask, setSelectedTask] = useState(null);
  const [tasks, setTasks] = useState([]);
  const [legalDoc, setLegalDoc] = useState(null);
  const [showFeedback, setShowFeedback] = useState(false);
  const [pointGoal, setPointGoal] = useState(100);

  const claimedIds = useMemo(
    () => new Set(myClaims.map((c) => c.task_id)),
    [myClaims]
  );

  const claimStatus = useMemo(() => {
    const m = new Map();
    myClaims.forEach((c) => m.set(c.task_id, c.status || "signed_up"));
    return m;
  }, [myClaims]);

  const claimedTasks = useMemo(
    () => tasks.filter((t) => claimedIds.has(t.id)),
    [claimedIds, tasks]
  );

  // Point der venter på en admins bekræftelse. Vises adskilt fra de optjente,
  // så ingen tror de allerede tæller med mod sæsonmålet.
  const pendingPoints = useMemo(
    () => myClaims
      .filter((c) => (c.status || "signed_up") === "signed_up")
      .reduce((sum, c) => sum + (c.points_awarded || 0), 0),
    [myClaims]
  );

  // Detect password recovery flow (when user clicks email link)
  // Klikker man linket i nulstillings-mailen, står det i URL'ens hash allerede
  // inden React renderer første gang. Læs det der, i stedet for at rette state
  // bagefter i en effect — så slipper vi for et glimt af login-skærmen.
  const isRecoveryUrl = () =>
    typeof window !== "undefined" && window.location.hash.includes("type=recovery");
  const [recoveryMode, setRecoveryMode] = useState(isRecoveryUrl);

  // Load profile from Supabase and update currentUser
  const hentOgSaetProfil = async (userId) => {
    // Er appen allerede i gang? Så er dette en baggrundsopdatering — ved
    // tokenfornyelse, når telefonen vågner, eller når fanen får fokus igen.
    // En fejl dér må ALDRIG overtage skærmen: medlemmet står måske midt i at
    // tage en tjans. Ref frem for state, fordi lytteren registreres én gang
    // og ellers ville se en forældet værdi for evigt.
    const iBaggrunden = harProfilRef.current;
    henterProfilRef.current = true;

    const gikGalt = (besked, stack) => {
      console.error("loadProfile:", besked);
      reportError(besked, "auth", stack);
      if (iBaggrunden) {
        setToast("Forbindelsen blev afbrudt et øjeblik");
        setTimeout(() => setToast(null), 3500);
      } else {
        setProfileProblem("error");
      }
    };

    try {
      let svar;
      try {
        svar = await hentProfil();
      } catch {
        // Timeout eller netværk. Ét ekstra forsøg — de fleste af disse er ét
        // enkelt hik, og at smide medlemmet ud på grund af det er for hårdt.
        await new Promise((r) => setTimeout(r, 1500));
        svar = await hentProfil();
      }

      let { data, error } = svar;

      // PostgREST svarer PGRST116 på .single(), når der ikke er nogen række.
      // Det er ikke en serverfejl — det er en bruger uden medlemsprofil, og
      // de to skal ikke have samme besked.
      let ingenRaekke = error?.code === "PGRST116";

      if (error && !ingenRaekke) {
        await new Promise((r) => setTimeout(r, 1500));
        ({ data, error } = await hentProfil());
        ingenRaekke = error?.code === "PGRST116";
      }

      if (error && !ingenRaekke) {
        gikGalt(`my_profile() fejlede: ${error.message}`);
        return;
      }

      if (data && userId && data.id !== userId) {
        console.warn("Profilen matcher ikke sessionen – logger ud");
        harProfilRef.current = false;
        ryddProfilCache();
        await supabase.auth.signOut();
        setIsAuthenticated(false);
        return;
      }

      // Gyldig session, men ingen medlemsprofil. Tidligere faldt vi bare
      // igennem her, og medlemmet endte på login-skærmen igen uden at vide
      // hvorfor. Det her er værd at vise, også midt i en session: er profilen
      // slettet under en, kan man alligevel ikke gøre mere.
      if (ingenRaekke || !data) {
        reportError("Logget ind, men my_profile() gav ingen række", "auth");
        harProfilRef.current = false;
        ryddProfilCache();
        setProfileProblem("missing");
        return;
      }

      {
        harProfilRef.current = true;
        setProfileProblem(null);
        const profil = {
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
          approved: data.approved === true,
          adminRequested: data.admin_requested === true,
        };
        setCurrentUser(profil);
        gemProfilCache(profil);
        setIsAuthenticated(true);
      }
    } catch (e) {
      gikGalt(`loadProfile: ${e.message}`, e.stack);
    } finally {
      henterProfilRef.current = false;
      setAuthLoading(false);
    }
  };

  // Hentning af opgavelisten.
  //
  // Foer laa den i sin egen mount-effekt og hentede paa egen haand,
  // ogsaa naar ingen var logget ind: 31 gange i doegnet svarede serveren
  // 401 paa /tasks, fordi kaldet blev sendt med en noegle, ingen havde
  // tjekket foerst. Nu kaldes den fra auth-effekten, naar der er en
  // session — og saa samtidig med profilen, ikke efter.
  const hentOpgaver = async () => {
    // Fejlen blev foer kastet vaek. Afviste serveren kaldet — fx fordi
    // token'et var udloebet, mens telefonen laa i lommen — saa medlemmet
    // en tom opgaveliste og troede, der ikke var nogen tjanser. Det er
    // vaerre end en fejlbesked, fordi ingen opdager det.
    const { data: taskRows, error } = await medFornyetSession(() =>
      supabase.from("tasks").select("*, task_steps(step_order, text)").order("created_at", { ascending: true })
    );

    if (error) {
      reportError(`Kunne ikke hente opgaver: ${error.message}`, "tasks");
      setToast("Kunne ikke hente opgaverne. Luk appen og aabn den igen.");
      setTimeout(() => setToast(null), 5000);
      return;
    }

    if (taskRows && taskRows.length > 0) {
      const mapped = taskRows.map((t) => ({
        id: t.id,
        title: t.title,
        category: t.category,
        icon: t.icon || "setup",
        date: t.date,
        dateFull: t.date_full || t.date,
        dateEnd: t.date_end || "",
        durationType: t.duration_type || "single",
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

  // Én hentning af opgavelisten ad gangen, af samme grund som for profilen.
  const loadTasks = () => {
    if (opgaveKaldRef.current) return opgaveKaldRef.current;
    const loefte = hentOpgaver().finally(() => {
      if (opgaveKaldRef.current === loefte) opgaveKaldRef.current = null;
    });
    opgaveKaldRef.current = loefte;
    return loefte;
  };

  // Én profilhentning ad gangen.
  //
  // Maalt paa et doegn i produktion: 80 af 173 app-aabninger sendte to eller
  // flere ens my_profile-kald inden for samme sekund, seksten sendte fire.
  // Det kom af, at baade getSession ved opstart og auth-lytteren bad om den
  // samme profil. Kaldene stod i koe efter hinanden paa en Micro-instans, og
  // skaermen ventede paa det foerste.
  //
  // Beder nogen om profilen, mens en hentning er undervejs, faar de svaret
  // fra den i stedet for at starte en ny.
  const loadProfile = (userId) => {
    const igang = profilKaldRef.current;
    if (igang && igang.userId === userId) return igang.loefte;

    const loefte = hentOgSaetProfil(userId).finally(() => {
      if (profilKaldRef.current?.loefte === loefte) profilKaldRef.current = null;
    });
    profilKaldRef.current = { userId, loefte };
    return loefte;
  };

  // Initial session check + auth state listener
  useEffect(() => {
    let mounted = true;

    // Sikkerhedsnet, saa man aldrig haenger paa indlaesningsskaermen for
    // evigt. Men det maa ikke fyre, MENS profilen er undervejs: foer sad det
    // paa 6 sekunder og smed medlemmet tilbage paa login-skaermen midt i en
    // langsom hentning. loadProfile har sin egen tidsgraense og rydder op
    // efter sig, saa det her er kun en bagstopper.
    const safety = setTimeout(() => {
      if (mounted && !henterProfilRef.current) {
        console.warn("Auth loading timeout — forcing render");
        setAuthLoading(false);
      }
    }, 6000);

    // Én sessionhentning — og foerst derefter data.
    //
    // getSession() fornyer selv noeglen, hvis den er udloebet eller udloeber
    // inden for halvandet minut. Ved at vente paa den ene gang henter vi
    // profil og opgaver med en noegle, vi ved er gyldig, i stedet for at
    // sende dem af sted og faa 401 tilbage. Den gamle vej var: kald fejler,
    // forny (op til fem sekunder), kald igen — flere sekunders
    // "Indlaeser..." hver gang telefonen havde ligget i lommen.
    //
    // De to hentninger startes SAMTIDIG. Opgavelisten skal ikke vente paa
    // profilen; den skal bare ikke vaere foer sessionen.
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (!mounted) return;
      if (session?.user) {
        // Kender vi personen fra sidst, saa vis appen NU og hent profilen i
        // baggrunden. harProfilRef saettes med vilje foer: saa ved
        // loadProfile, at den ikke maa overtage skaermen med en fejlskaerm,
        // hvis nettet driller — medlemmet staar maaske midt i hallen.
        const husket = laesProfilCache(session.user.id);
        if (husket) {
          harProfilRef.current = true;
          setCurrentUser(husket);
          setIsAuthenticated(true);
          setAuthLoading(false);
        }
        loadProfile(session.user.id);
        loadTasks();
      } else {
        // Ingen session: hent ingenting. Login-skaermen har ikke brug for
        // opgavelisten, og maa heller ikke se den.
        setAuthLoading(false);
      }
    }).catch((e) => {
      console.error("getSession failed:", e);
      if (mounted) setAuthLoading(false);
    });

    // Listen for future changes
    //
    // VIGTIGT: lytteren maa ikke vente paa et supabase-kald. supabase-js
    // kalder den, mens den selv holder sin laas paa sessionen, og ethvert
    // kald indefra skal bruge den samme laas. Venter vi, staar de og venter
    // paa hinanden, og appen bliver staaende paa "Indlaeser...", til laasen
    // bliver revet fri fem sekunder senere. Derfor: ingen await herinde —
    // arbejdet lægges udenfor med setTimeout(..., 0).
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (!mounted) return;
      if (event === "PASSWORD_RECOVERY") {
        setRecoveryMode(true);
        setAuthLoading(false);
        return;
      }
      // INITIAL_SESSION er den samme session, som getSession lige har hentet,
      // og TOKEN_REFRESHED er en ny noegle til den samme person. Ingen af
      // delene er en ny profil, og hentede vi paa dem, betalte medlemmet for
      // det samme svar to gange.
      if (event === "INITIAL_SESSION" || event === "TOKEN_REFRESHED") return;

      if (session?.user) {
        const uid = session.user.id;
        setTimeout(() => {
          if (!mounted) return;
          loadProfile(uid);
          // Man kan vaere kommet ind ved at logge ind: saa er opgavelisten
          // ikke hentet endnu, for der var ingen session ved opstart.
          loadTasks();
        }, 0);
      } else {
        // Ingen session: ryd også et hængende profilproblem, ellers bliver
        // fejlskærmen stående efter en udlogning. Og den huskede profil skal
        // væk — næste, der logger ind på telefonen, er måske en anden.
        harProfilRef.current = false;
        ryddProfilCache();
        setProfileProblem(null);
        setIsAuthenticated(false);
        setAuthLoading(false);
      }
    });

    return () => { mounted = false; clearTimeout(safety); subscription.unsubscribe(); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);


  const loadNotifications = async (userId = currentUser?.id) => {
    if (!userId) return;
    const { data } = await supabase.from("notifications")
      .select("*").eq("user_id", userId)
      .order("created_at", { ascending: false }).limit(50);
    if (data) setNotifications(data);
  };

  // Load claimed task IDs and notifications when user is set
  useEffect(() => {
    const uid = currentUser?.id;
    if (!uid) return;
    supabase.from("task_claims").select("task_id, status, points_awarded").eq("user_id", uid).then(({ data }) => {
      if (data) setMyClaims(data);
    });
    // Dataindlæsning ved visning. Reglen advarer mod setState i en effect,
    // men her sker det først efter et svar fra serveren — det er netop det,
    // effects er til: at synkronisere med noget uden for React.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    loadNotifications(uid);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentUser?.id]);

  // Klubbens pointmål sættes i admin-panelet. Før stod 100/200 hårdt i koden,
  // så indstillingen havde ingen effekt.
  useEffect(() => {
    supabase.from("settings").select("key,value").then(({ data }) => {
      const goal = data?.find((r) => r.key === "point_goal")?.value;
      const n = parseInt(goal, 10);
      if (Number.isFinite(n) && n > 0) setPointGoal(n);
    });
  }, []);

  const markNotifsRead = async () => {
    const unreadIds = notifications.filter((n) => !n.read).map((n) => n.id);
    if (unreadIds.length === 0) return;
    await supabase.from("notifications").update({ read: true }).in("id", unreadIds);
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
  };

  // Efter et bytte har både tilmeldinger, point og opgaveliste ændret sig.
  const reloadMine = async () => {
    if (!currentUser?.id) return;
    const [{ data: me }, { data: claims }, { data: taskRows }] = await Promise.all([
      supabase.rpc("my_profile").single(),
      supabase.from("task_claims").select("task_id, status, points_awarded").eq("user_id", currentUser.id),
      supabase.from("tasks").select("id, spots_left"),
    ]);
    if (me) setCurrentUser((prev) => prev && ({ ...prev, pointsEarned: me.points ?? 0, tasksCompleted: me.tasks_done ?? 0 }));
    if (claims) setMyClaims(claims);
    if (taskRows) {
      const bySpots = new Map(taskRows.map((r) => [r.id, r.spots_left]));
      setTasks((prev) => prev.map((t) => bySpots.has(t.id) ? { ...t, spotsLeft: bySpots.get(t.id) } : t));
    }
    loadNotifications();
  };

  // Sikkerhedsnet for den automatiske bekræftelse. Er pg_cron slået til på
  // Supabase-projektet, klarer det daglige job arbejdet, og dette kald finder
  // ikke noget. Er det ikke, sker opgørelsen her i stedet — funktionen har en
  // spærretid på en time, så den kører højst én gang i timen uanset hvor
  // mange der åbner appen.
  useEffect(() => {
    if (!currentUser?.id) return;
    supabase.rpc("auto_confirm_due_claims").then(({ data, error }) => {
      if (error) { console.warn("auto_confirm_due_claims:", error.message); return; }
      if (data > 0) reloadMine();
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentUser?.id]);


  // Kaldes naar login eller oprettelse er lykkedes.
  //
  // Den roerer IKKE authLoading. Det gjorde den foer, og det var en faelde:
  // supabase-js koerer auth-lytteren faerdig, FOER signInWithPassword giver
  // svar tilbage, saa paa en langsom forbindelse naaede loadProfile at blive
  // faerdig og slukke indlaesningsskaermen — hvorefter handleAuth taendte den
  // igen. Derefter var der ingenting tilbage til at slukke den, og appen
  // haengte paa "Indlaeser..." for evigt.
  //
  // Nu ejer loadProfile den skaerm alene, fra start til slut.
  const handleAuth = (authData) => {
    const first = authData.name ? authData.name.split(" ")[0] : "";
    setWelcomeToast(authData.isNew ? `Velkommen til RVK, ${first}! 🎉` : `Velkommen tilbage!`);
    setTimeout(() => setWelcomeToast(null), 3000);
    setTab("tasks");
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
    setIsAuthenticated(false);
    setTab("tasks");
    setMyClaims([]);
    setShowCalendar(false);
    setShowSwaps(false);
    setShowAdmin(false);
    setSelectedTask(null);
  };

  // Point og ledige pladser vedligeholdes udelukkende af databasen.
  // Appen skriver aldrig selv i points/spots_left – den læser resultatet.
  const refreshAfterClaimChange = async (taskId) => {
    const [{ data: me }, { data: task }] = await Promise.all([
      supabase.rpc("my_profile").single(),
      supabase.from("tasks").select("spots_left").eq("id", taskId).single(),
    ]);
    if (me) {
      setCurrentUser((prev) => prev && ({
        ...prev,
        pointsEarned: me.points ?? prev.pointsEarned,
        tasksCompleted: me.tasks_done ?? prev.tasksCompleted,
      }));
    }
    if (task) {
      setTasks((prev) => prev.map((t) => t.id === taskId ? { ...t, spotsLeft: task.spots_left } : t));
    }
  };

  const showToast = (msg, ms = 2500) => {
    setToast(msg);
    setTimeout(() => setToast(null), ms);
  };

  const handleClaim = async (taskId) => {
    if (!currentUser?.id) return;
    const task = tasks.find((t) => t.id === taskId);

    if (!currentUser.approved) {
      showToast("Din profil skal godkendes, før du kan tage tjanser", 3500);
      return;
    }
    if ((task?.spotsLeft ?? 0) <= 0) {
      showToast("Opgaven er desværre fuldt besat", 3000);
      return;
    }

    const { error } = await supabase.from("task_claims").insert({ task_id: taskId, user_id: currentUser.id });

    if (error) {
      // Databasen afviser blandt andet, hvis nogen nåede den sidste plads først.
      const full = /fuldt besat/i.test(error.message || "");
      showToast(full ? "Nogen nåede den sidste plads før dig" : `Kunne ikke tilmelde: ${error.message}`, 3500);
      await refreshAfterClaimChange(taskId);
      return;
    }

    setMyClaims((prev) => [...prev, { task_id: taskId, status: "signed_up", points_awarded: task?.points ?? 0 }]);
    showToast(`🎉 Tjansen er din! ${task?.points ?? 0} point når den er gennemført`, 3200);
    setTimeout(() => setTab("dashboard"), 900);
    await refreshAfterClaimChange(taskId);
  };

  const handleUnclaim = async (taskId) => {
    if (!currentUser?.id) return;

    const { error } = await supabase.from("task_claims")
      .delete().eq("task_id", taskId).eq("user_id", currentUser.id);

    if (error) {
      const settled = /gjort op/i.test(error.message || "");
      showToast(settled
        ? "Tjansen er allerede gjort op og kan ikke frameldes"
        : `Kunne ikke framelde: ${error.message}`, 3500);
      return;
    }

    setMyClaims((prev) => prev.filter((c) => c.task_id !== taskId));
    showToast("Tjans frameldt");
    await refreshAfterClaimChange(taskId);
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

  // Gyldig session, men profilen kunne ikke hentes. Skal komme FØR
  // login-skærmen, ellers er vi tilbage ved det tavse loop.
  if (profileProblem) {
    return (
      <ProfileProblemScreen
        kind={profileProblem}
        busy={authLoading}
        onRetry={async () => {
          setAuthLoading(true);
          const { data } = await supabase.auth.getSession();
          if (data?.session?.user) {
            setProfileProblem(null);
            await loadProfile(data.session.user.id);
          } else {
            setProfileProblem(null);
            setIsAuthenticated(false);
            setAuthLoading(false);
          }
        }}
        onSignOut={async () => {
          harProfilRef.current = false;
          await supabase.auth.signOut();
          setProfileProblem(null);
          setIsAuthenticated(false);
        }}
      />
    );
  }

  if (recoveryMode) {
    return (
      <div className="min-h-screen bg-stone-50 font-sans antialiased">
        <ResetPasswordScreen onDone={() => { setRecoveryMode(false); window.location.hash = ""; }} />
      </div>
    );
  }

  // Vilkår og privatlivspolitik lægger sig OVENPÅ skærmen, så en halvt
  // udfyldt oprettelsesformular ikke går tabt, når man læser dem.
  const feedbackOverlay = showFeedback && (
    <FeedbackModal onClose={() => setShowFeedback(false)} />
  );

  const legalOverlay = legalDoc && (
    <div className="fixed inset-0 z-[60] overflow-y-auto bg-stone-50">
      <div className="max-w-md mx-auto bg-white min-h-screen shadow-xl">
        <LegalScreen doc={legalDoc} onBack={() => setLegalDoc(null)} />
      </div>
    </div>
  );

  if (!isAuthenticated) {
    return (
      <div className="min-h-screen bg-stone-50 font-sans antialiased">
        <style>{`@keyframes slideup { from { transform: translateY(100%); } to { transform: translateY(0); } } .animate-slideup { animation: slideup 0.3s cubic-bezier(0.16, 1, 0.3, 1); } .scrollbar-hide::-webkit-scrollbar { display: none; } .scrollbar-hide { -ms-overflow-style: none; scrollbar-width: none; }`}</style>
        <AuthScreen onAuthenticated={handleAuth} onShowLegal={setLegalDoc} />
        {legalOverlay}
        {feedbackOverlay}
      </div>
    );
  }

  // Nye medlemmer venter på en admin, før de kan tage tjanser.
  if (currentUser && !currentUser.approved) {
    return (
      <div className="min-h-screen bg-stone-50 font-sans antialiased">
        <div className="max-w-md mx-auto min-h-screen flex items-center px-6" style={{ background: `linear-gradient(160deg, ${theme.greenDark} 0%, ${theme.greenMid} 55%, ${theme.purple} 100%)` }}>
          <div className="bg-white rounded-3xl shadow-2xl p-6 w-full">
            <div className="flex flex-col items-center text-center">
              <div className="w-14 h-14 rounded-2xl flex items-center justify-center mb-4" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
                <Clock className="w-7 h-7 text-white" />
              </div>
              <h2 className="text-xl font-bold text-stone-900">Tak for din tilmelding, {currentUser.name?.split(" ")[0]}!</h2>
              <p className="text-[14px] text-stone-600 mt-2 leading-relaxed">
                En af klubbens administratorer skal lige godkende din profil, før du kan tage tjanser.
                Du får besked, så snart det er sket – som regel inden for et døgn.
              </p>
            </div>

            <div className="bg-stone-50 rounded-xl p-3.5 mt-5 space-y-2">
              <div className="flex justify-between text-[12px]"><span className="text-stone-500">Navn</span><span className="font-semibold text-stone-800">{currentUser.name}</span></div>
              <div className="flex justify-between text-[12px]"><span className="text-stone-500">Hold</span><span className="font-semibold text-stone-800">{currentUser.team || "Ikke valgt"}</span></div>
              <div className="flex justify-between text-[12px]"><span className="text-stone-500">E-mail</span><span className="font-semibold text-stone-800 truncate ml-2">{currentUser.email}</span></div>
            </div>

            <p className="text-[11px] text-stone-400 mt-4 text-center leading-relaxed">
              Haster det? Skriv til {LEGAL_CONTACT}, så kigger vi på det.
            </p>

            <div className="flex gap-2 mt-5">
              <button onClick={() => loadProfile(currentUser.id)} className="flex-1 py-3 rounded-xl font-bold text-white text-[13px]" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>
                Tjek igen
              </button>
              <button onClick={handleLogout} className="px-4 py-3 rounded-xl bg-stone-100 text-stone-700 text-[13px] font-semibold">
                Log ud
              </button>
            </div>

            <div className="flex items-center justify-center gap-4 mt-4">
              <button onClick={() => setLegalDoc("terms")} className="text-[11px] text-stone-400 underline">Vilkår</button>
              <button onClick={() => setLegalDoc("privacy")} className="text-[11px] text-stone-400 underline">Privatlivspolitik</button>
            </div>
          </div>
        </div>
        {legalOverlay}
        {feedbackOverlay}
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-stone-50 font-sans antialiased">
      <style>{`@keyframes slideup { from { transform: translateY(100%); } to { transform: translateY(0); } } .animate-slideup { animation: slideup 0.3s cubic-bezier(0.16, 1, 0.3, 1); } .scrollbar-hide::-webkit-scrollbar { display: none; } .scrollbar-hide { -ms-overflow-style: none; scrollbar-width: none; }`}</style>

      <div className="max-w-md mx-auto bg-white min-h-screen relative shadow-xl">
        {welcomeToast && <div className="fixed top-5 left-1/2 -translate-x-1/2 px-4 py-2.5 rounded-xl text-white text-sm font-semibold shadow-lg z-50 animate-slideup" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>{welcomeToast}</div>}

        {showAdmin ? (
          // Mens admin-filen hentes (typisk et øjeblik, og kun første gang)
          // står den samme indlæsningsskærm, appen ellers bruger.
          <Suspense fallback={
            <div className="min-h-screen bg-stone-50 flex items-center justify-center">
              <div className="flex flex-col items-center gap-3">
                <div className="w-10 h-10 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin" />
                <div className="text-sm text-stone-500 font-medium">Henter admin...</div>
              </div>
            </div>
          }>
            <AdminDashboard currentUser={currentUser} onBack={() => setShowAdmin(false)} tasks={tasks} setTasks={setTasks} onPointsChanged={reloadMine} />
          </Suspense>
        ) : showCalendar ? (
          <CalendarScreen tasks={tasks} claimedTasks={claimedTasks} onTaskClick={(task) => { setSelectedTask(task); setShowCalendar(false); }} onBack={() => setShowCalendar(false)} />
        ) : showSwaps ? (
          <SwapScreen onBack={() => setShowSwaps(false)} claimedTasks={claimedTasks} currentUser={currentUser} onSwapAccepted={reloadMine} />
        ) : selectedTask ? (
          <div className="flex flex-col" style={{ height: "100dvh" }}>
            {/* Scrollable content */}
            <div className="flex-1 overflow-y-auto">
              <div className="px-5 pt-12 pb-8 text-white relative overflow-hidden" style={{ background: `linear-gradient(135deg, ${theme.greenDark} 0%, ${theme.greenMid} 100%)` }}>
                <button onClick={() => setSelectedTask(null)} className="inline-flex items-center gap-1.5 text-white/90 text-sm mb-5"><ArrowLeft className="w-4 h-4" />Tilbage til opgaver</button>
                <div className="flex items-center gap-2 mb-2"><span className="text-[11px] uppercase tracking-widest font-bold text-emerald-200">{selectedTask.category}</span>{selectedTask.urgent && <span className="inline-flex items-center gap-1 bg-pink-500/90 text-white text-[10px] font-bold px-2 py-0.5 rounded-full"><Flame className="w-3 h-3" />HASTER</span>}</div>
                <h1 className="text-2xl font-bold mb-4">{selectedTask.title}</h1>
                <div className="grid grid-cols-2 gap-3">
                  <div className="bg-white/10 rounded-xl p-3 border border-white/10"><div className="text-[10px] uppercase tracking-wider text-emerald-200 font-semibold mb-1">Dato</div><div className="text-sm font-semibold">{selectedTask.dateFull || selectedTask.date}</div></div>
                  {selectedTask.durationType === "single" && <div className="bg-white/10 rounded-xl p-3 border border-white/10"><div className="text-[10px] uppercase tracking-wider text-emerald-200 font-semibold mb-1">Tidsrum</div><div className="text-sm font-semibold">{selectedTask.time}</div></div>}
                  <div className={`bg-white/10 rounded-xl p-3 border border-white/10 ${selectedTask.durationType === "single" ? "col-span-2" : ""}`}><div className="text-[10px] uppercase tracking-wider text-emerald-200 font-semibold mb-1">Lokation</div><div className="text-sm font-semibold flex items-center gap-1.5"><MapPin className="w-4 h-4" />{selectedTask.location}</div></div>
                </div>
              </div>

              <div className="px-5 -mt-5 relative z-10 mb-4">
                <div className="rounded-2xl p-4 flex items-center justify-between text-white shadow-lg" style={{ background: `linear-gradient(135deg, ${theme.purple} 0%, ${theme.pink} 100%)` }}>
                  <div><div className="text-[11px] uppercase tracking-widest font-bold text-white/80">Når den er gennemført</div><div className="text-2xl font-black flex items-center gap-1"><Zap className="w-6 h-6" fill="white" />{selectedTask.points} point</div></div>
                  <DifficultyPill level={selectedTask.difficulty} />
                </div>
              </div>

              <div className="px-5 pb-6">
                <h2 className="text-[11px] uppercase tracking-widest font-bold text-stone-500 mb-3">Sådan løser du opgaven</h2>
                <ol className="space-y-3">{selectedTask.description.map((step, i) => <li key={i} className="flex gap-3"><div className="shrink-0 w-7 h-7 rounded-full flex items-center justify-center text-white text-xs font-bold" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>{i + 1}</div><p className="text-[14px] text-stone-700 leading-relaxed pt-0.5">{step}</p></li>)}</ol>
              </div>

              <TaskSignups
                taskId={selectedTask.id}
                spotsTotal={selectedTask.spotsTotal}
                currentUserId={currentUser?.id}
                erTilmeldt={claimedIds.has(selectedTask.id)}
              />
            </div>

            {/* Sticky button — never overlaps content */}
            <div className="shrink-0 p-4 bg-white border-t border-stone-100 shadow-[0_-4px_12px_rgba(0,0,0,0.06)]">
              {claimStatus.get(selectedTask.id) === "completed" ? (
                <div className="w-full py-3.5 rounded-xl font-semibold text-[13px] text-emerald-800 bg-emerald-50 border-2 border-emerald-300 flex items-center justify-center gap-2"><CheckCircle2 className="w-4 h-4 text-emerald-600" />Gennemført og godkendt · +{selectedTask.points} point</div>
              ) : claimStatus.get(selectedTask.id) === "no_show" ? (
                <div className="w-full py-3.5 rounded-xl font-semibold text-[13px] text-stone-600 bg-stone-100 border border-stone-200 flex items-center justify-center gap-2"><AlertTriangle className="w-4 h-4 text-stone-500" />Registreret som ikke gennemført</div>
              ) : claimedIds.has(selectedTask.id) ? (
                <div className="space-y-2">
                  <div className="text-[11px] text-stone-500 text-center">Pointene tilføjes, når en administrator har bekræftet tjansen.</div>
                  <button onClick={() => handleUnclaim(selectedTask.id)} className="w-full py-3.5 rounded-xl font-bold text-emerald-800 bg-emerald-50 border-2 border-emerald-300 flex items-center justify-center gap-2"><Check className="w-5 h-5 text-emerald-600" />Tilmeldt – tryk for at framelde</button>
                </div>
              ) : !currentUser?.approved ? (
                <div className="w-full py-3.5 rounded-xl font-semibold text-[13px] text-amber-900 bg-amber-50 border border-amber-200 flex items-center justify-center gap-2"><Clock className="w-4 h-4" />Din profil skal godkendes først</div>
              ) : (selectedTask.spotsLeft ?? 0) <= 0 ? (
                <div className="w-full py-3.5 rounded-xl font-semibold text-[13px] text-stone-500 bg-stone-100 border border-stone-200 flex items-center justify-center gap-2"><Users className="w-4 h-4" />Opgaven er fuldt besat</div>
              ) : (
                <button onClick={() => handleClaim(selectedTask.id)} className="w-full py-3.5 rounded-xl font-bold text-white shadow-lg flex items-center justify-center gap-2" style={{ background: `linear-gradient(135deg, ${theme.purple} 0%, ${theme.pink} 100%)` }}><Zap className="w-5 h-5" fill="white" />Tag tjansen ( {selectedTask.points} point )</button>
              )}
            </div>
          </div>
        ) : (
          <>
            {tab === "tasks" && <TasksScreen tasks={tasks} onTaskClick={setSelectedTask} claimedIds={claimedIds} onOpenNotifications={() => { setShowNotif(true); markNotifsRead(); }} onOpenSwaps={() => setShowSwaps(true)} onOpenCalendar={() => setShowCalendar(true)} unreadCount={notifications.filter((n) => !n.read).length} />}
            {tab === "dashboard" && <Dashboard claimedTasks={claimedTasks} currentUser={currentUser} onTaskClick={setSelectedTask} pointGoal={pointGoal} pendingPoints={pendingPoints} claimStatus={claimStatus} />}
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

                {/* Rediger profil */}
                <ProfileEditSection currentUser={currentUser} setCurrentUser={setCurrentUser} setToast={setToast} />

                <div className="px-5 mt-4 space-y-2">
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
                  <button onClick={() => setShowFeedback(true)} className="w-full bg-white border border-stone-200 rounded-xl py-3 text-[13px] font-semibold text-stone-700 flex items-center justify-center gap-2 hover:bg-stone-50"><AlertTriangle className="w-4 h-4 text-amber-500" />Noget der driller?</button>
                  <button onClick={handleLogout} className="w-full bg-stone-100 border border-stone-200 rounded-xl py-3 text-[13px] font-semibold text-stone-700 flex items-center justify-center gap-2 hover:bg-stone-50"><LogOut className="w-4 h-4" />Log ud</button>

                  <div className="flex items-center justify-center gap-4 pt-2 pb-1">
                    <button onClick={() => setLegalDoc("terms")} className="text-[11px] text-stone-400 underline hover:text-stone-600">Vilkår</button>
                    <button onClick={() => setLegalDoc("privacy")} className="text-[11px] text-stone-400 underline hover:text-stone-600">Privatlivspolitik</button>
                  </div>
                </div>
              </div>
            )}
          </>
        )}

        {toast && <div className="fixed bottom-24 left-1/2 -translate-x-1/2 px-4 py-2.5 rounded-xl text-white text-sm font-semibold shadow-lg z-50" style={{ background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>{toast}</div>}

        {!showCalendar && !showSwaps && !showAdmin && !selectedTask && <BottomNav active={tab} onChange={setTab} />}

        {legalOverlay}
        {feedbackOverlay}

        {/* Notification drawer */}
        {showNotif && (
          <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 backdrop-blur-sm" onClick={() => setShowNotif(false)}>
            <div className="bg-white rounded-t-3xl w-full max-w-md max-h-[80vh] flex flex-col animate-slideup" onClick={(e) => e.stopPropagation()}>
              <div className="px-5 py-4 border-b border-stone-100 flex items-center justify-between">
                <div className="w-12 h-1 bg-stone-200 rounded-full absolute top-2 left-1/2 -translate-x-1/2" />
                <h3 className="text-lg font-bold mt-1">Notifikationer</h3>
                <button onClick={() => setShowNotif(false)} className="p-1.5 hover:bg-stone-100 rounded-lg"><X className="w-5 h-5" /></button>
              </div>
              <div className="overflow-y-auto flex-1 divide-y divide-stone-100">
                {notifications.length === 0 ? (
                  <div className="p-10 text-center"><BellRing className="w-10 h-10 mx-auto mb-2 text-stone-300" /><p className="text-[13px] text-stone-500">Ingen notifikationer endnu</p></div>
                ) : notifications.map((n) => (
                  <div key={n.id} className={`px-5 py-3.5 flex items-start gap-3 ${n.read ? "" : "bg-violet-50/60"}`}>
                    <div className="w-9 h-9 rounded-full flex items-center justify-center shrink-0 text-white text-sm" style={{ background: NOTIF_STYLE[n.type]?.bg || `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
                      {NOTIF_STYLE[n.type]?.icon || <BellRing className="w-4 h-4" />}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="font-semibold text-[13px] text-stone-900">{n.title}</div>
                      {n.body && <p className="text-[12px] text-stone-500 mt-0.5 leading-relaxed">{n.body}</p>}
                      <div className="text-[11px] text-stone-400 mt-1">{new Date(n.created_at).toLocaleDateString("da-DK")}</div>
                    </div>
                    {!n.read && <div className="w-2 h-2 rounded-full mt-1.5 shrink-0" style={{ background: theme.pink }} />}
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
