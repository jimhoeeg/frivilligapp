// ============ FÆLLES ============
//
// De dele, BÅDE medlemmernes app og admin-panelet bruger. De ligger her,
// fordi admin-panelet nu er sin egen fil, som kun hentes af dem, der åbner
// det — og to filer kan ikke importere hinanden uden at løbe i ring.
//
// Alt andet bliver, hvor det er: i App.jsx (medlemmerne) eller admin.jsx.
//
// Reglen om fast refresh gælder komponentfiler; det her er en delefil.
/* eslint-disable react-refresh/only-export-components */
import {
  useState, useEffect, useRef, useCallback
} from "react";
import { supabase } from "./supabaseClient";
import {
  Trophy, Users, Coffee, Camera, Flame, Crown, ShieldCheck, Clock, X,
  CheckCircle2, AlertTriangle, ChevronLeft, ChevronRight, ClipboardList,
  Timer, Mic, Volleyball, Tent, Table, ShoppingCart, Utensils, Car, Bus,
  KeyRound, SprayCan, Wrench, Package, Shirt, Megaphone, Newspaper, Monitor,
  Briefcase, Banknote, Handshake, PartyPopper, Cake, Heart
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

// ============ UDLØBET SESSION ============
//
// En telefon, der har ligget i lommen, vågner med et forældet token. Appen
// sender det af sted, før supabase-js når at forny det, og serveren svarer
// 401. Det er set i produktionen: tre gange den 23. september, fra en iPhone
// og en Android, på opgavelisten.
//
// Konsekvensen var forskellig og begge dele dårlige: profilen gav
// fuldskærmsfejl, og opgavelisten gav ingenting — medlemmet så en tom skærm
// og troede, der ikke var nogen tjanser.
//
// Her fornyes sessionen i stedet, og kaldet prøves igen. Det er ét ekstra
// rundtur, og medlemmet mærker det ikke.

// ============ VANDRET LISTE ============
//
// Appen har syv rækker, der er bredere end skærmen: kategorifiltre, badges,
// holdene på scoreboardet, admin-fanerne og et par filtre mere. Admin-fanerne
// er 1109px brede i et 390px vindue — to tredjedele er gemt.
//
// De kunne godt rulles, men tre ting manglede:
//
//   1. Intet fortalte, at der var mere. Klassen "scrollbar-hide" stod i
//      markup'en uden nogensinde at være defineret, så rullepanelet var
//      hverken vist eller skjult — det afhang af styresystemet.
//   2. På en computer gør musehjulet ingenting på en vandret liste. Man skal
//      holde Shift nede, og det ved næsten ingen. De sidste fire admin-faner
//      var i praksis uden for rækkevidde med en almindelig mus.
//   3. Skiftede man fane programmatisk (fx via tallet på "Bekræft"), kunne den
//      aktive fane ende uden for det synlige felt.
//
// Løsningen her holder sig ude af syne, til den er nødvendig:
//
//   * Indholdet tones blødt ud i den kant, hvor der er mere. Det er en
//      mask-image på selve indholdet, ikke en gradient malet ovenpå — derfor
//      virker det lige godt på den grønne header og på hvid baggrund.
//   * Pilene vises kun, hvis der er noget at rulle til, og kun på enheder med
//      mus. På en telefon svæver der ikke knapper over indholdet.
//   * Musehjulet ruller sidelæns, når markøren er over rækken.
//   * Den aktive knap rulles selv ind i billedet.
// Pilen er skjult for skærmlæsere og tastatur med vilje: den fører ikke nogen
// steder hen, som knapperne i rækken ikke allerede gør. Den findes kun for
// musebrugere, der ikke kan svippe.
const RowArrow = ({ dir, show, onClick, arrowClass }) => (
  <button
    type="button"
    tabIndex={-1}
    aria-hidden="true"
    onClick={() => onClick(dir)}
    className={`hidden [@media(hover:hover)]:flex absolute top-1/2 -translate-y-1/2 ${dir < 0 ? "left-0" : "right-0"} z-10
      w-7 h-7 items-center justify-center rounded-full bg-white text-stone-600 shadow-md ring-1 ring-stone-900/10
      transition-opacity duration-150 ${show ? "opacity-90 hover:opacity-100" : "opacity-0 pointer-events-none"} ${arrowClass}`}
  >
    {dir < 0 ? <ChevronLeft className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
  </button>
);

const ScrollRow = ({ children, className = "", arrowClass = "", wrapperClassName = "" }) => {
  const ref = useRef(null);
  const [edge, setEdge] = useState({ left: false, right: false });

  const update = useCallback(() => {
    const el = ref.current;
    if (!el) return;
    const max = el.scrollWidth - el.clientWidth;
    // 1px slør: subpixel-bredder gør ellers pilen synlig i yderpositionen.
    setEdge({ left: el.scrollLeft > 1, right: el.scrollLeft < max - 1 });
  }, []);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    update();
    const ro = new ResizeObserver(update);
    ro.observe(el);
    Array.from(el.children).forEach((c) => ro.observe(c));
    return () => ro.disconnect();
  }, [update, children]);

  // Hold den aktive knap synlig, også når fanen skiftes inde fra koden.
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const active = el.querySelector('[data-active="true"]');
    if (active) active.scrollIntoView({ block: "nearest", inline: "nearest", behavior: "smooth" });
  }, [children]);

  // Lodret hjul → vandret rulning. Kun når der faktisk ER noget at rulle,
  // ellers stjæler rækken sidens scroll.
  const onWheel = (e) => {
    const el = ref.current;
    if (!el || el.scrollWidth <= el.clientWidth) return;
    if (Math.abs(e.deltaY) <= Math.abs(e.deltaX)) return;   // pladen ruller selv sidelæns
    el.scrollLeft += e.deltaY;
    update();
  };

  const nudge = (dir) => {
    const el = ref.current;
    if (!el) return;
    el.scrollBy({ left: dir * Math.max(120, el.clientWidth * 0.7), behavior: "smooth" });
  };

  const mask =
    edge.left && edge.right ? "fade-both"
    : edge.left ? "fade-left"
    : edge.right ? "fade-right"
    : "";

  return (
    // wrapperClassName er til layout-klasser, der hoerer til den YDRE kasse —
    // fx shrink-0, naar raekken sidder i en flex-kolonne. Laegges de kun paa
    // den indre, klemmer flexboksen wrapperen flad, og raekken forsvinder.
    <div className={`relative ${wrapperClassName}`}>
      <div ref={ref} onScroll={update} onWheel={onWheel} className={`${className} ${mask}`}>
        {children}
      </div>
      <RowArrow dir={-1} show={edge.left} onClick={nudge} arrowClass={arrowClass} />
      <RowArrow dir={1}  show={edge.right} onClick={nudge} arrowClass={arrowClass} />
    </div>
  );
};

// ============ FEJLOPSAMLING ============
//
// Gik noget i stykker hos et medlem, endte det før i browserens konsol, hvor
// ingen kigger. Nu havner det i databasen, så admins kan se det i panelet.
// Databasen sætter en grænse på 20 fejl pr. bruger i timen, så en fejl inde
// i en render-løkke ikke kan fylde tabellen.

// ============ IKONKATALOG ============
//
// Foer fandtes der fire ikoner i hele appen — floejte, kaffekop, hus og kage —
// og de blev valgt ud fra KATEGORIEN. Derfor stod "Fotograf til kampdag" og
// "Dele flyers ud ved sprogcentret" begge med en kaffekop, og bestyrelsen med
// et hus. Ikonet sagde altsaa ikke noget om opgaven.
//
// De fire gamle id'er staar foerst i hver gruppe og er beholdt, saa opgaver i
// databasen beholder deres ikon. Et ukendt id falder tilbage paa "setup".
//
// tegn() faar klassen med, saa det samme ikon kan vaere 12px i en liste og
// 40px paa en opgaveside.
const IKON_KATALOG = [
  { gruppe: "Kamp", ikoner: [
    { id: "whistle",   navn: "Dommer",       tegn: (c) => <svg viewBox="0 0 24 24" fill="none" className={c} stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="9" cy="13" r="5" /><path d="M14 13h8" /><path d="M22 10v6" /><circle cx="9" cy="13" r="1" fill="currentColor" /></svg> },
    { id: "scorecard", navn: "Sekretærbord", tegn: (c) => <ClipboardList className={c} /> },
    { id: "timer",     navn: "Tidtagning",   tegn: (c) => <Timer className={c} /> },
    { id: "speaker",   navn: "Speaker",      tegn: (c) => <Mic className={c} /> },
    { id: "net",       navn: "Bane og net",  tegn: (c) => <Volleyball className={c} /> },
    { id: "setup",     navn: "Hallen",       tegn: (c) => <svg viewBox="0 0 24 24" fill="none" className={c} stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M3 9l9-6 9 6" /><path d="M5 9v11h14V9" /><path d="M9 20v-6h6v6" /></svg> },
  ]},
  { gruppe: "Stævne", ikoner: [
    { id: "trophy",    navn: "Stævne",       tegn: (c) => <Trophy className={c} /> },
    { id: "table",     navn: "Stævnebord",   tegn: (c) => <Table className={c} /> },
    { id: "tent",      navn: "Overnatning",  tegn: (c) => <Tent className={c} /> },
  ]},
  { gruppe: "Mad og kiosk", ikoner: [
    { id: "cake",      navn: "Kage",         tegn: (c) => <Cake className={c} /> },
    { id: "coffee",    navn: "Kaffe",        tegn: (c) => <Coffee className={c} /> },
    { id: "kiosk",     navn: "Kiosk",        tegn: (c) => <ShoppingCart className={c} /> },
    { id: "food",      navn: "Mad",          tegn: (c) => <Utensils className={c} /> },
    { id: "grill",     navn: "Grill",        tegn: (c) => <Flame className={c} /> },
  ]},
  { gruppe: "Transport", ikoner: [
    { id: "car",       navn: "Kørsel",       tegn: (c) => <Car className={c} /> },
    { id: "bus",       navn: "Bus",          tegn: (c) => <Bus className={c} /> },
  ]},
  { gruppe: "Faciliteter", ikoner: [
    { id: "key",       navn: "Nøgler",       tegn: (c) => <KeyRound className={c} /> },
    { id: "clean",     navn: "Rengøring",    tegn: (c) => <SprayCan className={c} /> },
    { id: "tools",     navn: "Værktøj",      tegn: (c) => <Wrench className={c} /> },
    { id: "gear",      navn: "Materialer",   tegn: (c) => <Package className={c} /> },
    { id: "laundry",   navn: "Vask",         tegn: (c) => <Shirt className={c} /> },
  ]},
  { gruppe: "Kommunikation", ikoner: [
    { id: "camera",    navn: "Foto",         tegn: (c) => <Camera className={c} /> },
    { id: "megaphone", navn: "SoMe og PR",   tegn: (c) => <Megaphone className={c} /> },
    { id: "flyer",     navn: "Flyers",       tegn: (c) => <Newspaper className={c} /> },
    { id: "web",       navn: "Hjemmeside",   tegn: (c) => <Monitor className={c} /> },
  ]},
  { gruppe: "Klubben", ikoner: [
    { id: "board",     navn: "Bestyrelse",   tegn: (c) => <Briefcase className={c} /> },
    { id: "money",     navn: "Økonomi",      tegn: (c) => <Banknote className={c} /> },
    { id: "sponsor",   navn: "Sponsor",      tegn: (c) => <Handshake className={c} /> },
    { id: "committee", navn: "Udvalg",       tegn: (c) => <Users className={c} /> },
    { id: "party",     navn: "Fest",         tegn: (c) => <PartyPopper className={c} /> },
    { id: "heart",     navn: "Hjælp",        tegn: (c) => <Heart className={c} /> },
  ]},
];

const IKONER = Object.fromEntries(
  IKON_KATALOG.flatMap((g) => g.ikoner.map((i) => [i.id, i]))
);

const ikonNavn = (id) => IKONER[id]?.navn || IKONER.setup.navn;

const CategoryIcon = ({ type, className = "w-5 h-5" }) =>
  (IKONER[type] || IKONER.setup).tegn(className);

// Ikonet foelger ORDENE i titlen, ikke kategorien. Raekkefoelgen er ikke
// tilfaeldig: det mest bestemte ord vinder. "Stævnebord" skal ramme bordet,
// foer "stævne" rammer pokalen, og "stævneudvalg" er et udvalg, ikke et
// staevne. Kategorien er reserve, naar titlen ikke siger noget.

// Ikonet foelger ORDENE i titlen, ikke kategorien. Raekkefoelgen er ikke
// tilfaeldig: det mest bestemte ord vinder. "Stævnebord" skal ramme bordet,
// foer "stævne" rammer pokalen, og "stævneudvalg" er et udvalg, ikke et
// staevne. Kategorien er reserve, naar titlen ikke siger noget.
const IKON_ORD = [
  [/stævnebord|kampbord/i,                          "table"],
  [/udvalg/i,                                       "committee"],
  [/sekretær|holdkort|kampskema|resultat/i,         "scorecard"],
  [/dommer|fløjt|træner/i,                          "whistle"],
  [/speaker|mikrofon|annonc/i,                      "speaker"],
  [/tidtag|kampur|stopur/i,                         "timer"],
  [/boldrum|materiale|udstyr|depot/i,               "gear"],
  [/bane|net |nettet|opsætning|nedtagning/i,        "net"],
  [/overnat|natvagt/i,                              "tent"],
  [/foto|billed/i,                                  "camera"],
  [/some|sociale medier|presse|markedsføring|pr\b/i, "megaphone"],
  [/flyer|plakat|stand |uddel/i,                    "flyer"],
  [/hjemmeside|webmaster|web\b/i,                   "web"],
  [/kiosk|indkøb|varer/i,                           "kiosk"],
  [/kage|bag(e|ning)/i,                             "cake"],
  [/mad|spisning|madpakke|køkken/i,                 "food"],
  [/grill/i,                                        "grill"],
  [/kaffe/i,                                        "coffee"],
  [/kørsel|kør |transport|hente|aflever/i,          "car"],
  [/bus/i,                                          "bus"],
  [/nøgle|halsover|låse|lukke hallen/i,             "key"],
  [/rengør|oprydning|rydde|vaske gulv/i,            "clean"],
  [/vask|spillertøj|trøjer/i,                       "laundry"],
  [/værktøj|reparation|vedligehold/i,               "tools"],
  [/bestyrels|formand|næstformand|referat/i,        "board"],
  [/kasser|økonomi|regnskab|budget|kontingent/i,    "money"],
  [/sponsor/i,                                      "sponsor"],
  [/fest|arrangement|hygge|socialt/i,               "party"],
  [/stævne/i,                                       "trophy"],
];

const KATEGORI_IKON = {
  "Kampafvikling & Sekretærbord":    "whistle",
  "Hygge og Socialt":                "party",
  "Holdleder & Transport":           "car",
  "Stævneplanlægning og Afholdelse": "trophy",
  "Kommunikation & PR":              "megaphone",
  "Faciliteter & Materialer":        "gear",
  "Klubadministration":              "board",
};

const foreslaaIkon = (titel, kategori) => {
  const t = titel || "";
  for (const [ord, id] of IKON_ORD) if (ord.test(t)) return id;
  return KATEGORI_IKON[kategori] || "setup";
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

// ============ VILKÅR OG PRIVATLIVSPOLITIK ============
//
// UDKAST. Skrevet ud fra hvad appen faktisk gemmer og gør, men det er
// klubbens ansvar at læse teksterne igennem og godkende dem, før appen
// sendes ud til medlemmerne. Ret navn, kontaktadresse og opbevaringsfrist
// til, så de passer til RVK's øvrige praksis.

const DA_MONTH_ABBR  = { jan:0,feb:1,mar:2,apr:3,maj:4,jun:5,jul:6,aug:7,sep:8,okt:9,nov:10,dec:11 };

const parseTaskDate = (task) => {
  if (task.dateFull && /^\d{4}-\d{2}-\d{2}/.test(task.dateFull))
    return new Date(task.dateFull + "T12:00:00");
  const m = (task.date || "").match(/(\d+)\.\s*(\w+)/);
  if (!m) return null;
  const mo = DA_MONTH_ABBR[m[2].toLowerCase()];
  if (mo === undefined) return null;
  const today = new Date();
  const d = new Date(today.getFullYear(), mo, parseInt(m[1]), 12);
  if (d < today && (today - d) > 180 * 24 * 60 * 60 * 1000) d.setFullYear(d.getFullYear() + 1);
  return d;
};

// Sådan ser en tilmelding ud i medlemmets egne skærme.
const CLAIM_STATE = {
  signed_up: { label: "Afventer bekræftelse", cls: "bg-amber-50 text-amber-800 border-amber-200",       icon: Clock },
  completed: { label: "Godkendt",             cls: "bg-emerald-50 text-emerald-800 border-emerald-200", icon: CheckCircle2 },
  no_show:   { label: "Ikke gennemført",      cls: "bg-stone-100 text-stone-600 border-stone-200",      icon: AlertTriangle },
};

const ClaimStatusPill = ({ status }) => {
  const s = CLAIM_STATE[status] || CLAIM_STATE.signed_up;
  const Icon = s.icon;
  return (
    <span className={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md border text-[10px] font-semibold ${s.cls}`}>
      <Icon className="w-2.5 h-2.5" />{s.label}
    </span>
  );
};

// ---- MEMBER OPGAVEOVERSIGT ----
const MemberTasksModal = ({ member, onClose }) => {
  const [claims, setClaims] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      setLoading(true);
      const { data } = await supabase
        .from("task_claims")
        .select("task_id, status, tasks(id, title, date, date_full, time, location, points, icon, category)")
        .eq("user_id", member.id);
      setClaims((data || [])
        .filter((c) => c.tasks)
        .map((c) => ({ ...c.tasks, status: c.status || "signed_up" })));
      setLoading(false);
    })();
  }, [member.id]);

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const upcoming = claims.filter((t) => {
    const d = t.date_full ? new Date(t.date_full + "T00:00:00") : null;
    return d ? d >= today : true;
  }).sort((a, b) => new Date(a.date_full || 0) - new Date(b.date_full || 0));

  const past = claims.filter((t) => {
    const d = t.date_full ? new Date(t.date_full + "T00:00:00") : null;
    return d ? d < today : false;
  }).sort((a, b) => new Date(b.date_full || 0) - new Date(a.date_full || 0));

  // Kun bekræftede tjanser giver point.
  const totalPoints   = claims.filter((t) => t.status === "completed").reduce((s, t) => s + (t.points || 0), 0);
  const pendingPoints = claims.filter((t) => t.status === "signed_up").reduce((s, t) => s + (t.points || 0), 0);

  const TaskRow = ({ t }) => (
    <div className="flex items-center gap-3 py-2.5 border-b border-stone-100 last:border-b-0">
      <div className="w-8 h-8 rounded-lg flex items-center justify-center text-white shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>
        <CategoryIcon type={t.icon} className="w-4 h-4" />
      </div>
      <div className="flex-1 min-w-0">
        <div className="text-[13px] font-semibold text-stone-900 truncate">{t.title}</div>
        <div className="text-[11px] text-stone-400">{t.date_full || t.date}{t.time ? ` · ${t.time}` : ""}</div>
        <div className="mt-1"><ClaimStatusPill status={t.status} /></div>
      </div>
      <div className={`shrink-0 text-[11px] font-bold px-2 py-0.5 rounded-full ${t.status === "completed" ? "text-white" : t.status === "no_show" ? "bg-stone-100 text-stone-400 line-through" : "text-white opacity-60"}`} style={t.status === "no_show" ? {} : { background: `linear-gradient(135deg, ${theme.purple}, ${theme.pink})` }}>
        {t.status === "completed" ? "+" : ""}{t.points}
      </div>
    </div>
  );

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 backdrop-blur-sm" onClick={onClose}>
      <div className="bg-white rounded-t-2xl w-full max-w-md max-h-[85vh] flex flex-col shadow-2xl" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="px-5 pt-5 pb-4 border-b border-stone-100 shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-11 h-11 rounded-full flex items-center justify-center text-white font-bold shrink-0" style={{ background: `linear-gradient(135deg, ${theme.greenDark}, ${theme.greenMid})` }}>
              {(member.name || "?")[0].toUpperCase()}
            </div>
            <div className="flex-1 min-w-0">
              <div className="font-bold text-[15px] text-stone-900">{member.name}</div>
              <div className="text-[11px] text-stone-400">
                {totalPoints} point optjent · {claims.length} tilmeldinger
                {pendingPoints > 0 && <> · {pendingPoints} pt afventer</>}
              </div>
            </div>
            <button onClick={onClose} className="p-1.5 hover:bg-stone-100 rounded-lg"><X className="w-4 h-4 text-stone-500" /></button>
          </div>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto px-5 py-4 space-y-5">
          {loading ? (
            <div className="text-center py-10 text-stone-400 text-sm">Indlæser...</div>
          ) : claims.length === 0 ? (
            <div className="text-center py-10 text-stone-400 text-sm">Ingen opgaver registreret</div>
          ) : (
            <>
              {upcoming.length > 0 && (
                <div>
                  <div className="text-[10px] uppercase tracking-widest font-bold text-stone-400 mb-1">Kommende ({upcoming.length})</div>
                  <div className="bg-white border border-stone-100 rounded-xl shadow-sm overflow-hidden">
                    {upcoming.map((t) => <TaskRow key={t.id} t={t} />)}
                  </div>
                </div>
              )}
              {past.length > 0 && (
                <div>
                  <div className="text-[10px] uppercase tracking-widest font-bold text-stone-400 mb-1">Tidligere ({past.length})</div>
                  <div className="bg-stone-50 border border-stone-100 rounded-xl overflow-hidden">
                    {past.map((t) => <TaskRow key={t.id} t={t} />)}
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
};

const logAction = (type, action, actor) =>
  supabase.from("audit_log").insert({
    type,
    action,
    actor_name: actor?.name || "Ukendt",
    actor_id:   actor?.id   || null,
  });

export {
  logAction,
  theme,
  RowArrow,
  ScrollRow,
  IKON_KATALOG,
  IKONER,
  ikonNavn,
  CategoryIcon,
  IKON_ORD,
  KATEGORI_IKON,
  foreslaaIkon,
  RoleBadge,
  parseTaskDate,
  CLAIM_STATE,
  ClaimStatusPill,
  MemberTasksModal,
  DifficultyPill,
};
