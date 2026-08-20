# IELTS Academic Simulator

A single-file, browser-based IELTS Academic mock-test app covering all four
modules — **Listening, Reading, Writing, and Speaking** — with AI-assisted
scoring and feedback powered by Google Gemini.

Open `index.html` in any modern browser. No build step, no server required.

## Features

- **Dashboard** — overall band, per-skill cards, and progress charts.
- **Listening / Reading** — full question sets with answer keys and auto-marking.
- **Writing** — Task 1 & Task 2 drafting with word count, AI coaching hints,
  paragraph-level feedback, and band-score estimation against the four official
  criteria. Task 1 ships with an **interactive 3D graphic generator** (see below).
- **Speaking** — cue cards, live recording, and Gemini scoring from the actual
  audio (pronunciation and intonation, not just the transcript).
- **Language desk** — a translator on every skill tab, with verb conjugation
  tables, register-ranked alternative words and collocations (see below).
- **Sessions** — export/import progress to a file, or quick-save snapshots in
  the browser.

## Writing Task 1 — 3D graphic generator

The chart a candidate must describe is rendered with a self-contained
[Three.js](https://threejs.org/) engine instead of a flat 2D plot:

- **3D Bars** — lit, shadowed, animated bars grouped by series and time, with
  floating value labels.
- **3D Trend** — glossy tube-lines with translucent area ribbons ("mountain
  range") and endpoint value callouts.
- Drag to orbit, scroll to zoom, gentle auto-rotation, and a graceful fall-back
  to the classic 2D **Line / Bar / Pie / Mind-map** views.

The "Generate New Writing Exam" button asks Gemini for a fresh Task 1 + Task 2
context (including new chart data) on demand.

## Language desk — the translator on every skill tab

Listening, Reading, Writing and Speaking each carry a collapsible **🌐 Language
desk**. Type a word or phrase — or **select any text in the exam material** and
a small bubble offers to translate it, so nothing has to be retyped and you
never lose your place in a passage.

Beyond the translation itself it gives you:

- **Verb conjugation tables** — full paradigms in *both* languages, source and
  target, so a candidate can see `consider → considers → considered →
  considering` next to `considero → consideras → consideró → considere`.
- **Alternative words**, each tagged with the nuance or register that separates
  it — tap one to promote it to the headline translation.
- **Stronger source-language synonyms**, for upgrading a Band 6 word to a Band 8
  one in a Writing draft.
- **Collocations**, an IELTS usage note, IPA, and read-aloud.
- A **saved word list** that persists in the browser and travels inside session
  export files.

### Which translation API, and why the mix

There is no single API that does all of this — **no machine-translation service
on the market returns verb conjugations.** So the translation and the linguistics
come from different places, and the engine is switchable in **⚙ AI engine**:

| Engine | Setup | Notes |
|---|---|---|
| **MyMemory** | none — works out of the box | Free and keyless, and CORS-open so the browser can call it directly. Its translation-memory matches double as alternative renderings. Capped at ~480 characters per lookup. This is the default. |
| **Google Cloud Translation** | its own API key | 100+ languages, solid quality, and its v2 endpoint sends `Access-Control-Allow-Origin`, so it works from this page with no server. Note this is **not** the Gemini key — enable *Cloud Translation API* in Google Cloud and create a separate key. |
| **Gemini** | the key you already set above | Context-aware translation that also returns its own alternatives and a literal back-translation. |
| **DeepL** | a proxy you run | The most accurate engine for European pairs, but DeepL [blocks browser calls by design](https://developers.deepl.com/docs/best-practices/cors-requests) (403 + CORS) so it cannot be reached from a static page. Point the app at a small proxy (DeepL publishes a ready-made one) and it will use it. |

**Auto** — the default — picks the best engine you have actually configured:
DeepL proxy → Google → Gemini → MyMemory.

The **conjugation tables, alternatives, collocations and register notes always
run on Gemini**, whichever translation engine is selected, because that part
simply isn't something a translation API exposes. Without a Gemini key the desk
still translates; the word-studio card just explains what it needs.

## AI engine — setup

AI features (Writing hints/scoring, paragraph feedback, Speaking scoring, and
the "Generate New Writing Exam" button) run on Google **Gemini**. You need a
free API key from <https://aistudio.google.com/apikey> (keys look like
`AIzaSy…`). There are two ways to provide it:

**Option 1 — paste it in the app (simplest).**
Open **⚙ AI engine**, paste your key, click **Save**. It's stored in this
browser only (`localStorage`).

**Option 2 — local config file (auto-loads, nothing to paste each time).**
This is the static-app equivalent of a `.env` file:

```bash
cp config.example.js config.local.js   # then edit config.local.js
```

```js
// config.local.js
window.GEMINI_CONFIG = {
  key: "AIzaSy...your-real-key...",
  model: "gemini-2.5-flash"
};
```

`config.local.js` is in `.gitignore`, so your key **never enters Git**. When
the file sits next to `index.html`, the app loads the key automatically. On a
fresh browser the file is authoritative; once you Save in the panel, the saved
values win.

> **Why not a real `.env`?** This app is a single static HTML file with no
> server or build step, and a browser can't read a `.env` file. `config.local.js`
> is the browser-native equivalent — a gitignored file loaded via a `<script>` tag.

## Teacher & student accounts (optional)

With a free [Supabase](https://supabase.com) project you can turn the app into a
small classroom: students sign in, their progress syncs automatically, and you
see everything from a **My class** dashboard and send them feedback.

**Leave it unconfigured and nothing changes** — the app runs exactly as before,
fully offline, with the account button hidden.

### Setup (about 5 minutes)

1. Create a free project at <https://supabase.com>.
2. Open **SQL Editor → New query**, paste all of [`supabase-schema.sql`](supabase-schema.sql), and click **Run**.
   This creates the tables *and* the security rules.
3. Go to **Settings → API** and copy your **Project URL** and **anon / public key**
   into [`supabase-config.js`](supabase-config.js), then commit. The live site picks it up on the next deploy.
4. *(Recommended for classrooms)* **Authentication → Providers → Email** and turn
   **Confirm email** off, so students can sign in immediately without checking their inbox.

### Using it

- **You:** click **👤 Sign in → Create account**, choose **Teacher**. You get a
  **class code** (shown in the account panel and on the My class tab).
- **Students:** click **Create account**, choose **Student**, and enter your class code.
- Their band scores and their Writing/Speaking submissions then appear in **My class**.
  Click a student to read their actual responses and send feedback — it shows up on
  their dashboard the next time they open the app.

### Is committing the anon key safe?

Yes — that's what it's for. The anon key only ever acts as the **logged-in user**,
and the row-level security policies in the schema mean a student can read only
their own rows and a teacher only their own students'. Never commit the
**`service_role`** key, which bypasses those rules.

> **Note on student data:** this stores student names, emails and their written
> work on Supabase's servers. If your students are minors, check what your school
> or institution allows before rolling it out.

## Troubleshooting "no content" / generation fails

Open **⚙ AI engine** and click **Test connection**. It calls Google and tells
you exactly what's wrong, and — if the key works — **lists the model IDs your
key can actually use.** Common outcomes:

| What you see | Meaning / fix |
|---|---|
| ✅ *Key works, model available* | You're set. |
| ✅ *Key works, but `<model>` is not in your available models* | Change the **model** field to one of the listed IDs, then Save. |
| ❌ *401/403 Key rejected* | The key isn't a valid Gemini API key. Get one at aistudio.google.com/apikey (it should start with `AIza`). |
| ❌ *404 Model not found* | The model ID is wrong for this key — use one from Test connection. |
| ❌ *429 quota* | You hit a rate/quota limit; wait, or check quota in AI Studio. |
| ❌ *Network error* | No internet, or the browser/extension blocked the request. |

> ⚠️ **Security note:** this app calls Gemini directly from the browser, so the
> key is visible to anyone who can open your copy or inspect its network
> traffic. That's fine for personal use, but **don't hand out a copy with your
> key in it.** For shared/classroom use, have each student enter their own key,
> or run a tiny proxy server (Cloudflare Worker / Vercel / Netlify function)
> that holds the key server-side and forwards requests — ask and this repo can
> add one.
