// ============================================================================
// Skabelonerne til de fem mails, appen selv sender.
//
// Almindelig JavaScript med vilje: så kan både Deno (i send-mail) og en
// ganske almindelig node-test læse den samme fil. En skabelon, der kun kan
// afprøves ved at sende en rigtig mail, bliver aldrig afprøvet.
//
// Samme ramme som de tre mails, Supabase selv sender (supabase/email/).
// Tabeller og stilarter direkte på hvert element: Gmail fjerner <style>, og
// Outlook gengiver med Word.
// ============================================================================

export const KLUB_MAIL = "randersvolleyball@gmail.com";

const esc = (s) =>
  String(s ?? "").replace(/[&<>"]/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

const ramme = (o) => `<!doctype html>
<html lang="da"><body style="margin:0;padding:0;background:#FAFAF7;">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">${esc(o.fortekst)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#FAFAF7;padding:24px 12px;">
<tr><td align="center">
  <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:600px;background:#FFFFFF;border-radius:16px;overflow:hidden;border:1px solid #E7E5E4;">
    <tr><td style="background:#1B8A5A;background-image:linear-gradient(135deg,#0F4C3A 0%,#1B8A5A 100%);padding:28px 32px;">
      <div style="font:700 11px/1 -apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;letter-spacing:1.5px;color:#A7F3D0;text-transform:uppercase;">Randers Volleyballklub</div>
      <div style="font:700 22px/1.3 -apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;color:#FFFFFF;padding-top:6px;">${esc(o.overskrift)}</div>
    </td></tr>
    <tr><td style="padding:28px 32px 8px 32px;font:400 15px/1.6 -apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;color:#44403C;">${o.broedtekst}</td></tr>
    ${o.knap ? `<tr><td align="center" style="padding:20px 32px 24px 32px;">
      <a href="${esc(o.knap.url)}" style="display:inline-block;background:#8B5CF6;background-image:linear-gradient(135deg,#8B5CF6 0%,#EC4899 100%);color:#FFFFFF;text-decoration:none;font:700 15px/1 -apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;padding:15px 28px;border-radius:12px;">${esc(o.knap.tekst)}</a>
    </td></tr>` : `<tr><td style="padding:0 0 16px 0;"></td></tr>`}
    <tr><td style="padding:0 32px;"><div style="height:1px;background:#E7E5E4;"></div></td></tr>
    <tr><td style="padding:20px 32px 28px 32px;font:400 12px/1.7 -apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;color:#A8A29E;">
      ${o.fod}
      <div style="padding-top:14px;"><strong style="color:#78716C;">Du kan ikke svare på denne mail.</strong><br />
      Har du brug for at skrive til os, så send en mail til <a href="mailto:${KLUB_MAIL}" style="color:#1B8A5A;font-weight:600;">${KLUB_MAIL}</a>.</div>
      ${o.afmeld ? `<div style="padding-top:10px;">Vil du ikke have påmindelser på mail? Slå dem fra under <strong style="color:#78716C;">Profil</strong> i appen.</div>` : ""}
    </td></tr>
  </table>
  <div style="font:400 11px/1.6 -apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;color:#C4C0BC;padding-top:16px;">RVK Frivillig · Randers Volleyballklub</div>
</td></tr></table></body></html>`;

const p = (t) => `<p style="margin:0 0 14px 0;">${t}</p>`;
const sidste = (t) => `<p style="margin:0;">${t}</p>`;
const staerk = (t) => `<strong style="color:#0A1F17;">${esc(t)}</strong>`;

const naarOgHvor = (d) => {
  const dele = [d.dato, d.tid, d.sted].filter(Boolean).map(esc);
  return dele.length ? sidste(dele.join(" · ")) : "";
};

export function skriv(r, appUrl) {
  const d = r.data ?? {};
  const hej = d.navn ? `Hej ${esc(d.navn)},` : "Hej,";
  const knap = { tekst: "Åbn RVK Frivillig", url: appUrl };

  switch (r.kind) {
    case "approved":
      return ramme({
        overskrift: "Du er med",
        fortekst: "Din profil er godkendt.",
        broedtekst: p(hej) + p(`Din profil i ${staerk("RVK Frivillig")} er godkendt. Du kan tage tjanser og samle point fra nu af.`) +
          sidste("Log ind og se, hvad der er ledigt."),
        knap,
        fod: "Du får denne mail, fordi du har oprettet dig som frivillig i Randers Volleyballklub.",
      });

    case "task_assigned":
      return ramme({
        overskrift: "Du er sat på en tjans",
        fortekst: `${d.opgave ?? "En tjans"} — se hvornår.`,
        broedtekst: p(hej) + p(`En af klubbens admins har sat dig på ${staerk(d.opgave ?? "en tjans")}.`) + naarOgHvor(d),
        knap,
        fod: "Kan du ikke alligevel, så meld fra i appen i god tid — så kan en anden nå at tage den.",
      });

    case "task_changed":
      return ramme({
        overskrift: "En tjans er ændret",
        fortekst: `${d.opgave ?? "En tjans"} er blevet ændret.`,
        broedtekst: p(hej) + p(`${staerk(d.opgave ?? "En tjans")}, som du står på, er blevet ændret.`) +
          naarOgHvor(d) + (d.tekst ? p("") + sidste(esc(d.tekst)) : ""),
        knap,
        fod: "Tjek tid og sted i appen, så du ikke møder op på det gamle tidspunkt.",
      });

    case "task_cancelled":
      return ramme({
        overskrift: "En tjans er aflyst",
        fortekst: `${d.opgave ?? "En tjans"} er aflyst.`,
        broedtekst: p(hej) + p(`${staerk(d.opgave ?? "Tjansen")} er aflyst. Du skal ikke møde op.`) +
          sidste("Pointene for den er væk igen, men du kan tage en anden."),
        knap,
        fod: "Aflysningen kommer fra en af klubbens admins.",
      });

    case "reminder":
      return ramme({
        overskrift: "Husk din tjans",
        fortekst: `Om ${d.dage ?? 2} dage: ${d.opgave ?? "din tjans"}.`,
        broedtekst: p(hej) + p(`Om ${staerk(`${d.dage ?? 2} dage`)} står du på ${staerk(d.opgave ?? "en tjans")}.`) +
          naarOgHvor(d) + p("") + sidste("Kan du ikke alligevel, så meld fra i appen nu — så når en anden at tage den."),
        knap,
        fod: "Det er en venlig påmindelse. Du skal ikke gøre noget, hvis det passer.",
        afmeld: true,
      });

    default:
      return ramme({
        overskrift: esc(r.subject),
        fortekst: esc(r.subject),
        broedtekst: p(hej) + sidste(esc(d.tekst ?? "")),
        knap,
        fod: "Beskeden kommer fra RVK Frivillig.",
      });
  }
}

