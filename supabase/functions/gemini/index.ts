// =============================================================================
// IELTS Academic Simulator — the class's shared Gemini key
// -----------------------------------------------------------------------------
// One Gemini key, held here as a server secret, used on behalf of every teacher
// and every student in a class. The browser never sees it: the app sends the
// request here with the signed-in user's session, and this forwards it to
// Google with the key attached.
//
// Why not just put the key in a file the site loads? Because anything a page
// loads, every visitor can read — and a Gemini key committed to a public repo is
// found by scanners within minutes and revoked by Google. Here it is a secret.
//
// Who may use it: a teacher, or a student who has joined a class. Not "anyone
// with an account": with email confirmation off (as the README recommends for
// classrooms) anybody on the internet can make one, and the key is yours.
// A student without a class — or anyone who prefers — can still paste a key of
// their own in ⚙ AI engine, and that key is then used instead of this one.
//
// DEPLOY (no command line needed)
//   Supabase dashboard → Edge Functions → Deploy a new function → Via editor.
//   Name it exactly   gemini   paste this file, deploy.
//   Then Edge Functions → Secrets → add   GEMINI_API_KEY = AIza…
//   Optional secret   GEMINI_MODEL   (default gemini-3.5-flash-lite)
//   Optional secret   GEMINI_MODELS  comma-separated extra models the app may
//                                    ask for; anything else gets GEMINI_MODEL.
//   With the CLI instead:  supabase functions deploy gemini
//                          supabase secrets set GEMINI_API_KEY=AIza…
//
// If the app reports "Invalid JWT": turn OFF "Verify JWT with legacy secret" /
// "Enforce JWT verification" for this function. It checks the session itself,
// below, which works with both the old and the new Supabase keys.
// =============================================================================

const GEMINI_BASE = Deno.env.get("GEMINI_API_BASE") || "https://generativelanguage.googleapis.com/v1beta";
const DEFAULT_MODEL = "gemini-3.5-flash-lite";
// Listening generation sends a whole section's audio inline. The app already
// refuses files over 18 MB, which is ~24 MB once base64-encoded.
const MAX_BODY_BYTES = 30 * 1024 * 1024;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Every error is shaped like one of Google's ({error:{message}}), so the app
// reads it the same way whichever side it came from.
function reply(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}
function fail(status: number, message: string, code?: string): Response {
  return reply(status, { error: { message, code: code || null } });
}
function passThrough(r: Response, text: string): Response {
  return new Response(text, { status: r.status, headers: { ...CORS, "Content-Type": "application/json" } });
}

// The model is the key owner's decision, not the caller's: without this a
// student could point the class key at the most expensive model there is.
function pickModel(asked: unknown): string {
  const fallback = (Deno.env.get("GEMINI_MODEL") || DEFAULT_MODEL).trim();
  const allowed = new Set(
    [fallback, ...(Deno.env.get("GEMINI_MODELS") || "").split(",")].map((m) => m.trim()).filter(Boolean),
  );
  const m = typeof asked === "string" ? asked.trim() : "";
  return allowed.has(m) ? m : fallback;
}

type Caller = { id: string; role: string; teacher_id: string | null };

// Asks Supabase who this session belongs to, then reads their own profile row
// with their own token — so row-level security answers, not this function.
async function whoIsCalling(req: Request): Promise<Caller | Response> {
  const url = Deno.env.get("SUPABASE_URL");
  const auth = req.headers.get("Authorization") || "";
  // supabase-js sends the project's public key as `apikey` on every call; the
  // env var covers a client that does not.
  const apikey = req.headers.get("apikey") || Deno.env.get("SUPABASE_ANON_KEY") || "";
  if (!url) return fail(500, "SUPABASE_URL is not set for this function.");
  if (!/^Bearer\s+\S+/i.test(auth)) return fail(401, "Sign in to use the class's AI key.", "signed_out");

  const u = await fetch(`${url}/auth/v1/user`, { headers: { Authorization: auth, apikey } });
  if (!u.ok) return fail(401, "Your session has expired. Sign in again.", "signed_out");
  const user = await u.json();
  if (!user || !user.id) return fail(401, "Sign in to use the class's AI key.", "signed_out");

  const p = await fetch(
    `${url}/rest/v1/profiles?id=eq.${encodeURIComponent(user.id)}&select=role,teacher_id`,
    { headers: { Authorization: auth, apikey, Accept: "application/json" } },
  );
  const rows = p.ok ? await p.json() : [];
  const me = Array.isArray(rows) ? rows[0] : null;
  if (!me) return fail(403, "Your profile could not be read. Reload the page and try again.", "no_profile");
  return { id: user.id, role: me.role, teacher_id: me.teacher_id };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return fail(405, "POST only.");

  const size = Number(req.headers.get("content-length") || 0);
  if (size > MAX_BODY_BYTES) {
    return fail(413, "That request is too large for the shared key — compress the audio (mono, 64 kbps MP3) and try again.");
  }

  const who = await whoIsCalling(req);
  if (who instanceof Response) return who;
  if (who.role !== "teacher" && !who.teacher_id) {
    return fail(403,
      "The class's AI key is for teachers and for students who have joined a class. Join yours with its class code, or add your own Gemini key in ⚙ AI engine.",
      "no_class");
  }

  let body: any;
  try { body = await req.json(); } catch { return fail(400, "The request was not valid JSON."); }

  const key = (Deno.env.get("GEMINI_API_KEY") || "").trim();
  const op = body && body.op;

  // Lets the app decide, once per sign-in, whether to offer AI features on
  // the shared key — without spending a call to Google to find out.
  if (op === "status") {
    return reply(200, { ok: true, configured: !!key, model: pickModel(null), role: who.role });
  }
  if (!key) {
    return fail(503, "The class's Gemini key has not been set yet. Your teacher adds it under Supabase → Edge Functions → Secrets as GEMINI_API_KEY.", "no_key");
  }

  if (op === "models") {
    const r = await fetch(`${GEMINI_BASE}/models?pageSize=1000`, { headers: { "x-goog-api-key": key } });
    return passThrough(r, await r.text());
  }

  if (op === "generate") {
    if (!Array.isArray(body.contents) || !body.contents.length) return fail(400, "Nothing to send to Gemini.");
    const model = pickModel(body.model);
    const r = await fetch(`${GEMINI_BASE}/models/${encodeURIComponent(model)}:generateContent`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": key },
      body: JSON.stringify({ contents: body.contents }),
    });
    return passThrough(r, await r.text());
  }

  return fail(400, "Unknown request.");
});
