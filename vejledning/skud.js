// Rigtige skærmbilleder af appen til vejledningen. Ingen tegninger, ingen
// rigtige medlemmer: opdigtede navne, men klubbens egne opgaver og tekster.
const { chromium } = require("playwright-core");
const fs = require("fs");
const UD = __dirname;

const b64 = o => Buffer.from(JSON.stringify(o)).toString("base64url");
const nu = Math.floor(Date.now()/1000);
const jwt = `${b64({alg:"HS256",typ:"JWT"})}.${b64({sub:"mette",role:"authenticated",aud:"authenticated",exp:nu+3600,iat:nu})}.sig`;
const SESSION = { access_token:jwt, token_type:"bearer", expires_in:3600, expires_at:nu+3600, refresh_token:"r",
  user:{ id:"mette", aud:"authenticated", role:"authenticated", email:"mette@example.dk", app_metadata:{}, user_metadata:{}, created_at:"2026-08-20T00:00:00Z" } };

const MIG = { id:"mette", name:"Mette Sørensen", email:"mette@example.dk", phone:"+45 20 11 22 33",
  team:"Damer 2", initials:"MS", role:"user", points:120, tasks_done:4, bonus_points:0,
  avatar_url:null, approved:true, admin_requested:false, member_since:"2026-08-20", email_reminders:true };

const HOLD = [{id:"h1",name:"Damer 1"},{id:"h2",name:"Damer 2"},{id:"h3",name:"Herrer 1"},
              {id:"h4",name:"Herrer 2"},{id:"h5",name:"Piger U15"},{id:"h6",name:"Drenge U15"}];

const trin = (...t) => t.map((text, i) => ({ step_order:i+1, text }));

const OPGAVER = [
  { id:"t1", title:"Kioskvagt ved hjemmekamp", category:"Hygge og Socialt", icon:"kiosk",
    date:"lør. 3. okt", date_full:"2026-10-03", date_end:null, duration_type:"single",
    time:"16:30-21:00", location:"Randers Hallen", points:15, difficulty:"Let", urgent:false,
    spots_left:1, spots_total:3, created_at:"2026-09-10T08:00:00Z",
    task_steps: trin("Mød 30 min før kampstart og tænd kaffemaskinen.",
                     "Sælg fra kiosken i pauserne — kassen står i skabet bag disken.",
                     "Tæl kassen op og skriv beløbet på sedlen.",
                     "Ryd op, sluk og lås.") },
  { id:"t2", title:"Dommerbord og skriver ved hjemmekamp", category:"Kampafvikling", icon:"whistle",
    date:"søn. 4. okt", date_full:"2026-10-04", date_end:null, duration_type:"single",
    time:"12:00-15:00", location:"Randers Hallen", points:15, difficulty:"Medium", urgent:true,
    spots_left:1, spots_total:3, created_at:"2026-09-18T08:00:00Z",
    task_steps: trin("Mød 20 min før kampstart ved dommerbordet.",
                     "Skriv kampskemaet — en fra holdet viser dig det første sæt.",
                     "Aflever skemaet til dommeren efter kampen.") },
  { id:"t3", title:"Bage kage til hjemmekamp", category:"Hygge og Socialt", icon:"cake",
    date:"lør. 10. okt", date_full:"2026-10-10", date_end:null, duration_type:"single",
    time:"Afleveres inden 15:00", location:"Randers Hallen", points:10, difficulty:"Let", urgent:false,
    spots_left:2, spots_total:4, created_at:"2026-09-12T08:00:00Z",
    task_steps: trin("Bag en kage til ca. 20 personer.", "Aflever den i kiosken inden kampstart.") },
  { id:"t4", title:"Opsætning af net og baner", category:"Faciliteter og Materialer", icon:"setup",
    date:"lør. 10. okt", date_full:"2026-10-10", date_end:null, duration_type:"single",
    time:"08:30-10:00", location:"Randers Hallen", points:10, difficulty:"Let", urgent:false,
    spots_left:3, spots_total:4, created_at:"2026-09-14T08:00:00Z",
    task_steps: trin("Hent net og stolper i depotet.", "Sæt banerne op efter stregerne.",
                     "Tjek at nettet er i den rigtige højde.") },
  { id:"t5", title:"Holdleder for Damer 2 (halvsæson)", category:"Holdleder og Transport", icon:"team",
    date:"sep. 2026 – mar. 2027", date_full:"2026-09-01", date_end:"2027-03-31", duration_type:"half_season",
    time:"", location:"Følger holdet", points:75, difficulty:"Hård", urgent:false,
    spots_left:1, spots_total:1, created_at:"2026-08-25T08:00:00Z",
    task_steps: trin("Hold kontakt til træner og spillere om kampe og afbud.",
                     "Sørg for kørsel til udekampe.",
                     "Meld resultater ind efter kampene.") },
  { id:"t6", title:"Fotograf til stævne", category:"Kommunikation og SoMe", icon:"camera",
    date:"søn. 18. okt", date_full:"2026-10-18", date_end:null, duration_type:"single",
    time:"09:00-15:00", location:"Randers Hallen", points:15, difficulty:"Let", urgent:false,
    spots_left:2, spots_total:2, created_at:"2026-09-20T08:00:00Z",
    task_steps: trin("Tag billeder i løbet af dagen.", "Send de bedste til klubbens SoMe-ansvarlige.") },
];

// Hun står på to: én gennemført, én kommende.
const MINE = [
  { id:"c1", task_id:"t1", status:"signed_up", points_awarded:15, credited_to:null },
];
const FULDFOERTE = [
  { id:"c9", task_id:"t9", status:"completed", points_awarded:15, credited_to:null },
];

const RANGLISTE = [
  { id:"j1", name:"Jonas Vestergaard", initials:"JV", team:"Herrer 1", points:210, tasks_done:8, role:"user" },
  { id:"a1", name:"Anne Krogh",        initials:"AK", team:"Damer 1",  points:185, tasks_done:7, role:"admin" },
  { id:"mette", ...MIG },
  { id:"s1", name:"Søren Bach",        initials:"SB", team:"Herrer 2", points:95,  tasks_done:4, role:"user" },
  { id:"l1", name:"Line Dahl",         initials:"LD", team:"Damer 2",  points:60,  tasks_done:3, role:"user" },
  { id:"p1", name:"Peter Holm",        initials:"PH", team:"Herrer 1", points:45,  tasks_done:2, role:"user" },
];

const BESKEDER = [
  { id:"n1", user_id:"mette", type:"task_reminder", title:"Husk din tjans om 2 dage",
    body:"Kioskvagt ved hjemmekamp · lør. 3. okt", read:false, created_at:"2026-10-01T15:05:00Z", action_task_id:"t1" },
  { id:"n2", user_id:"mette", type:"points_awarded", title:"Tjansen er godkendt — +15 point",
    body:"Kagebagning til hjemmekamp", read:false, created_at:"2026-09-21T18:00:00Z", action_task_id:null },
  { id:"n3", user_id:"mette", type:"approved", title:"Din profil er godkendt",
    body:"Velkommen! Du kan nu tage tjanser.", read:true, created_at:"2026-08-20T10:00:00Z", action_task_id:null },
];

const MAERKER = [
  { badge_id:"kom_godt_igang", earned_at:"2026-09-05T10:00:00Z", er_ny:false },
  { badge_id:"kiosken",        earned_at:"2026-09-12T10:00:00Z", er_ny:false },
  { badge_id:"alsidig",        earned_at:"2026-09-19T10:00:00Z", er_ny:false },
  { badge_id:"weekendkrigeren",earned_at:"2026-09-21T10:00:00Z", er_ny:false },
];

// Ordret som den star i klubbens indstillinger — billedet skal vise det,
// medlemmet faktisk ser i appen.
const NOTE = "Efteråret er gratis i år — det er vores prøveperiode. Der gøres op til foråret, hvor der skal 200 point til i alt for at slippe for frivilligbidraget på 400 kr.";

const opsaet = async (ctx, { medMine = true } = {}) => {
  await ctx.route("**/*.supabase.co/**", async r => {
    const req = r.request(); const url = new URL(req.url()); const u = url.pathname;
    const json = (b, st=200) => r.fulfill({ status:st, contentType:"application/json", body:JSON.stringify(b) });
    if (u.includes("/auth/v1/token")) return json(SESSION);
    if (u.includes("/auth/v1/user"))  return json(SESSION.user);
    if (u.includes("/rest/v1/rpc/")) {
      const navn = u.split("/rpc/")[1];
      if (navn === "my_profile")        return json(MIG);
      if (navn === "my_bidrag")         return json({ bidrag:120, egne:120, fra_hjaelpere:0, bonus:0, givet:0, er_hjaelper:false, kun_hjaelper:false });
      if (navn === "my_helper_members") return json([]);
      if (navn === "my_helpers")        return json([]);
      if (navn === "my_badges")         return json(MAERKER);
      if (navn === "task_signups")      return json([
        { user_id:"l1", name:"Line Dahl",  initials:"LD", team:"Damer 2", status:"signed_up" },
        { user_id:"s1", name:"Søren Bach", initials:"SB", team:"Herrer 2", status:"signed_up" }]);
      if (navn === "auto_confirm_due_claims") return json(0);
      return json(null);
    }
    if (u.includes("/rest/v1/tasks"))         return json(OPGAVER);
    if (u.includes("/rest/v1/task_claims"))   return json(medMine ? [...MINE, ...FULDFOERTE] : []);
    if (u.includes("/rest/v1/notifications")) return json(BESKEDER);
    if (u.includes("/rest/v1/profiles")) {
      // Dashboardet spørger om ANTALLET af dem med flere point end mig selv
      // (head + count=exact). Svares der med en liste, bliver pladsen til #1,
      // og så modsiger dashboardet ranglisten to skærme senere.
      if ((url.search || "").includes("points=gt.")) {
        const graense = parseInt((url.search.match(/points=gt\.(\d+)/) || [])[1] || "0", 10);
        const over = RANGLISTE.filter(m => (m.points || 0) > graense).length;
        return r.fulfill({ status:200, contentType:"application/json",
          headers:{ "content-range": `*/${over}` }, body:"[]" });
      }
      return json(RANGLISTE);
    }
    if (u.includes("/rest/v1/teams"))         return json(HOLD);
    if (u.includes("/rest/v1/settings"))      return json([
      { key:"point_goal", value:"200" }, { key:"contribution_kr", value:"400" },
      { key:"contribution_note", value:NOTE }]);
    if (u.includes("/rest/v1/swap_offers"))   return json([]);
    return json([]);
  });
};

let nr = 0;
const gem = async (page, navn, { helSide = false } = {}) => {
  nr++;
  const fil = `${UD}/${String(nr).padStart(2,"0")}-${navn}.jpg`;
  await page.screenshot({ path:fil, type:"jpeg", quality:88, fullPage:helSide });
  const kb = Math.round(fs.statSync(fil).size / 1024);
  console.log(`  ${String(nr).padStart(2,"0")}-${navn}.jpg  ${kb} kB`);
};

(async () => {
  const browser = await chromium.launch({ executablePath:"/opt/pw-browsers/chromium-1194/chrome-linux/chrome" });
  const fejl = [];

  // ---------- 1. Opret bruger (uden session) ----------
  const ctxUd = await browser.newContext({ viewport:{width:390,height:844}, deviceScaleFactor:2 });
  const s1 = await ctxUd.newPage();
  s1.on("pageerror", e => fejl.push("login: " + e.message));
  await opsaet(ctxUd);
  await s1.goto("http://127.0.0.1:4192/", { waitUntil:"commit" });
  await s1.waitForTimeout(1500);
  await s1.getByRole("button",{name:"Opret bruger"}).click();
  await s1.waitForTimeout(500);
  await s1.locator('input[name="name"]').fill("Mette Sørensen");
  await s1.locator('input[name="email"]').fill("mette@example.dk");
  await s1.locator('input[name="password"]').fill("mindstsekstegn");
  await s1.locator('input[name="tel"]').fill("20 11 22 33");
  await s1.selectOption('select', "Damer 2").catch(()=>{});
  await s1.waitForTimeout(400);
  await gem(s1, "opret-bruger");
  await ctxUd.close();

  // ---------- resten med session ----------
  const ctx = await browser.newContext({ viewport:{width:390,height:844}, deviceScaleFactor:2 });
  await ctx.addInitScript((s) => localStorage.setItem("sb-mohrmjirotuabsjppank-auth-token", JSON.stringify(s)), SESSION);
  await opsaet(ctx);
  const p = await ctx.newPage();
  p.on("pageerror", e => fejl.push("app: " + e.message));
  await p.goto("http://127.0.0.1:4192/", { waitUntil:"commit" });
  await p.waitForFunction(() => document.body.innerText.includes("Frivillig-feed"), null, { timeout:20000 }).catch(()=>{});
  await p.waitForTimeout(1200);

  // 2. Opgavelisten
  await gem(p, "opgaveliste");

  // 3. Filtre aabnet
  // Tragten ved siden af søgefeltet har ingen tekst — den findes på sin plads.
  const tragt = p.locator('input[placeholder*="Søg"] ~ button, input[placeholder*="Søg"]').locator("xpath=../following-sibling::button").first();
  await tragt.click({ timeout:5000 }).catch(async () => {
    await p.locator("button").filter({ hasNot: p.locator("text=/.+/") }).nth(3).click().catch(()=>{});
  });
  await p.waitForTimeout(600);
  await gem(p, "filtre");
  await tragt.click({ timeout:5000 }).catch(()=>{});
  await p.waitForTimeout(400);

  // 4. En opgave i detaljer
  await p.getByText("Dommerbord og skriver").first().click();
  await p.waitForTimeout(900);
  await gem(p, "opgave-detalje");

  // 5. Hvem staar paa den (nederst)
  await p.getByText("Tilbage til opgaver").click();
  await p.waitForTimeout(500);

  // 6. Dashboard med point
  await p.getByRole("button",{name:"Dashboard"}).click();
  await p.waitForTimeout(1000);
  await gem(p, "dashboard-point");
  await gem(p, "dashboard-maerker");

  // 7. Kalender
  await p.getByRole("button",{name:"Opgaver"}).click();
  await p.waitForTimeout(600);
  // De tre runde knapper øverst: kalender, bytte, klokke. Kalenderen er den første.
  await p.locator("button.rounded-full.bg-white\\/10").first().click();
  await p.waitForTimeout(1000);
  await gem(p, "kalender");
  // Kalenderen dækker hele skærmen — bundmenuen er der først, når man er ude igen.
  await p.getByRole("button",{name:/Tilbage/}).first().click();
  await p.waitForTimeout(700);

  // 8. Rangliste
  await p.getByRole("button",{name:"Rangliste"}).click();
  await p.waitForTimeout(900);
  await gem(p, "rangliste");

  // 9. Byttecentralen — de runde knapper findes kun paa opgavefanen.
  await p.getByRole("button",{name:"Opgaver"}).click();
  await p.waitForTimeout(700);
  await p.locator("button.rounded-full.bg-white\\/10").nth(1).click();
  await p.waitForTimeout(900);
  await gem(p, "bytte");
  await p.getByRole("button",{name:/Tilbage/}).first().click();
  await p.waitForTimeout(700);

  // 10. Beskeder
  await p.locator("button.rounded-full.bg-white\\/10").nth(2).click();
  await p.waitForTimeout(900);
  await gem(p, "beskeder");
  await p.getByRole("button",{name:/Luk|Tilbage/}).first().click().catch(()=>{});
  await p.waitForTimeout(600);

  // 11. Profil
  await p.getByRole("button",{name:"Profil"}).click();
  await p.waitForTimeout(900);
  await gem(p, "profil");

  console.log(fejl.length ? "\n  JS-fejl: " + fejl.join(" | ") : "\n  ingen JS-fejl");
  await browser.close();
})();
