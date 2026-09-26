// ============================================================================
// send-mail – tømmer mailudbakken gennem Resend
//
// Databasen sender ikke selv mail. Den lægger beskeden i public.email_outbox
// og banker på her (pg_cron + pg_net, hvert femte minut). Så ligger nøglen
// til Resend ét sted: i den her funktions miljøvariabler, aldrig i browseren
// og aldrig i databasen.
//
// Udrulning:
//   supabase functions deploy send-mail --no-verify-jwt
//
// Hemmeligheder, der skal sættes (Edge Functions → Secrets):
//   RESEND_API_KEY   nøglen fra Resend
//   OUTBOX_KEY       samme streng som vault-hemmeligheden 'outbox_key'
//   MAIL_FRA         fx "RVK Frivillig <frivillig@randersvk.dk>"
//   APP_URL          fx https://frivilligapp.vercel.app
//
// SUPABASE_URL og SUPABASE_SERVICE_ROLE_KEY sætter Supabase selv.
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { skriv, KLUB_MAIL } from "./skabeloner.js";

const MAKS_PR_KALD = 40;   // 100 om dagen på Resends gratisplan – god margin
const MAKS_FORSOEG = 3;

type Række = {
  id: number;
  kind: string;
  to_email: string;
  subject: string;
  data: Record<string, string | number | null>;
  attempts: number;
};

// ------------------------------------------------------------------ KALD ---

Deno.serve(async (req) => {
  const outboxKey = Deno.env.get("OUTBOX_KEY");
  if (!outboxKey || req.headers.get("x-outbox-key") !== outboxKey) {
    return new Response(JSON.stringify({ error: "nej" }), { status: 401 });
  }

  const resendKey = Deno.env.get("RESEND_API_KEY");
  const fra       = Deno.env.get("MAIL_FRA") ?? "RVK Frivillig <frivillig@randersvk.dk>";
  const appUrl    = Deno.env.get("APP_URL") ?? "https://frivilligapp.vercel.app";
  if (!resendKey) {
    return new Response(JSON.stringify({ error: "RESEND_API_KEY mangler" }), { status: 500 });
  }

  const db = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: raekker, error } = await db
    .from("email_outbox")
    .select("id, kind, to_email, subject, data, attempts")
    .is("sent_at", null)
    .lt("attempts", MAKS_FORSOEG)
    .order("created_at", { ascending: true })
    .limit(MAKS_PR_KALD);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  let sendt = 0, fejlet = 0;

  for (const r of (raekker ?? []) as Række[]) {
    // Tælles op FØR afsendelsen. Går noget galt midt i — en timeout, en
    // genstart — må rækken ikke kunne prøve i det uendelige.
    await db.from("email_outbox").update({ attempts: r.attempts + 1 }).eq("id", r.id);

    try {
      const svar = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { Authorization: `Bearer ${resendKey}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          from: fra,
          to: [r.to_email],
          subject: r.subject,
          html: skriv(r, appUrl),
          headers: r.kind === "reminder"
            ? { "List-Unsubscribe": `<mailto:${KLUB_MAIL}?subject=Afmeld%20paamindelser>` }
            : undefined,
        }),
      });

      if (!svar.ok) {
        const tekst = await svar.text();
        await db.from("email_outbox")
          .update({ last_error: `${svar.status}: ${tekst}`.slice(0, 500) }).eq("id", r.id);
        fejlet++;
        continue;
      }

      await db.from("email_outbox")
        .update({ sent_at: new Date().toISOString(), last_error: null }).eq("id", r.id);
      sendt++;
    } catch (e) {
      await db.from("email_outbox")
        .update({ last_error: String(e).slice(0, 500) }).eq("id", r.id);
      fejlet++;
    }
  }

  return new Response(JSON.stringify({ sendt, fejlet, i_koe: raekker?.length ?? 0 }), {
    headers: { "Content-Type": "application/json" },
  });
});
