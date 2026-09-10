// ============================================================================
// delete-member – sletter et medlem HELT (punkt 9)
//
// Admin-panelet slettede før kun profil-rækken. Selve brugerkontoen blev
// liggende i Supabase Auth med e-mailen, og personen kunne stadig logge ind
// uden at have en profil – de sad fast, og de kunne ikke oprette sig igen.
//
// At slette en auth-bruger kræver service-nøglen, som aldrig må ligge i
// browseren. Derfor sker det her, på serveren.
//
// Udrulning:
//   supabase functions deploy delete-member
//
// SUPABASE_URL og SUPABASE_SERVICE_ROLE_KEY sættes automatisk af Supabase.
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Kun POST" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  // 1. Hvem spørger? Token'et kommer fra den indloggede admins session.
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return json({ error: "Du skal være logget ind" }, 401);
  }

  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: userErr } = await caller.auth.getUser();
  if (userErr || !user) return json({ error: "Ugyldig session" }, 401);

  // 2. Er den, der spørger, super admin? Slås op med service-nøglen, så
  //    svaret ikke afhænger af, hvad klienten påstår.
  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: actor, error: actorErr } = await admin
    .from("profiles")
    .select("role, name")
    .eq("id", user.id)
    .single();

  if (actorErr) return json({ error: "Kunne ikke slå din profil op" }, 500);
  if (actor?.role !== "super_admin") {
    return json({ error: "Kun en super admin kan slette medlemmer" }, 403);
  }

  // 3. Hvem skal slettes?
  let body: { user_id?: string; reason?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Ugyldig forespørgsel" }, 400);
  }

  const targetId = body.user_id;
  if (!targetId) return json({ error: "user_id mangler" }, 400);
  if (targetId === user.id) {
    return json({ error: "Du kan ikke slette din egen konto herfra" }, 400);
  }

  const { data: target } = await admin
    .from("profiles")
    .select("name, role")
    .eq("id", targetId)
    .single();

  if (target?.role === "super_admin") {
    const { count } = await admin
      .from("profiles")
      .select("id", { count: "exact", head: true })
      .eq("role", "super_admin");
    if ((count ?? 0) <= 1) {
      return json({ error: "Klubben skal have mindst én super admin" }, 400);
    }
  }

  // 4. Skriv i audit-loggen FØR sletningen, mens navnet stadig findes.
  await admin.from("audit_log").insert({
    type: "member",
    action: `Slettede (GDPR) ${target?.name ?? targetId}` +
      (body.reason ? ` – årsag: ${body.reason}` : ""),
    actor_id: user.id,
    actor_name: actor.name,
  });

  // 5. Slet auth-brugeren. profiles-rækken følger med via
  //    "references auth.users(id) on delete cascade", og tilmeldinger,
  //    beskeder og byttetilbud følger med derfra.
  const { error: delErr } = await admin.auth.admin.deleteUser(targetId);
  if (delErr) return json({ error: `Sletning fejlede: ${delErr.message}` }, 500);

  // 6. Sikkerhedsnet, hvis profilen ikke var koblet til en auth-bruger.
  await admin.from("profiles").delete().eq("id", targetId);

  return json({ ok: true, deleted: targetId });
});
