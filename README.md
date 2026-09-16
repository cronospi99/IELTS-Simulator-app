# IELTS Academic Simulator

A single-file, browser-based IELTS Academic mock-test app covering all four
modules — **Listening, Reading, Writing, and Speaking** — with AI-assisted
scoring and feedback powered by Google Gemini.

Open `index.html` in any modern browser. No build step, no server required.

## Features

- **Home** — a launcher built to the project's page template: hero, the four
  papers as cards with the band each one earned, a band-trend chart with the
  overall-band ring, recent activity and quick links. The app runs in a sidebar
  shell with a quick-jump search (⌘K), a notifications bell for teacher
  feedback, and an account menu.
- **Full mock test** — the four papers in exam order on their official clocks,
  tracked to the band each earned, with a "continue" that opens the next paper
  you have not finished.
- **Free practice** — the same four skills with the exam taken off them. No
  band and no CEFR level anywhere: Writing and Speaking come back as an
  **accuracy percentage** with every correction marked in your own text, and
  Listening and Reading are simply marked right or wrong. The timer is a button
  you press only if you want one, there is a live word counter throughout, and
  Speaking is recorded one question at a time and assessed as a whole set at the
  end. Nothing here touches your dashboard.
- **Progress** — the overall seal, per-skill cards, skill-profile and
  band-history charts, and the full attempt history.
- **Listening / Reading** — full question sets with answer keys and auto-marking.
- **Writing** — Task 1 & Task 2 drafting with word count, AI coaching hints,
  paragraph-level feedback, and band-score estimation against the four official
  criteria. Task 1 ships with an **interactive 3D graphic generator** (see below).
- **Speaking** — cue cards, live recording, and Gemini scoring from the actual
  audio (pronunciation and intonation, not just the transcript).
- **Exam clocks** — each paper is timed the way the real one is: Writing 60:00
  (20:00 for Task 1, 40:00 for Task 2, clocked separately), Reading 60:00, and
  Listening for the accumulated running time of the four section audios (≈30:00
  until they are attached). At 00:00 the paper locks — the response becomes
  read-only and answer controls are disabled — and marking still runs on what
  was written.
- **Length limits** — Task 1 is capped at 170 words and Task 2 at 280. Past the
  minimum the counter warns; at the ceiling no further words can be added,
  though existing text can still be corrected or deleted.
- **Annotated feedback** — every band report highlights the candidate's own
  words in green (excellent), yellow (improvable) and red (an error), each with
  a note in Spanish, alongside the strengths, fixes and the justification for
  the bands awarded.
- **Language desk** — a translator on every skill tab, with verb conjugation
  tables, register-ranked alternative words and collocations (see below).
- **Accounts, homework and feedback** — students sign in with their teacher's
  class code and their progress follows them to any device; teachers see the
  class roster, read every submission, write feedback, and set homework for one
  student or the whole class at once. Students get it on their home page and
  under the 🔔 bell, and tick it off when it is done. Password reset and
  "resend the confirmation email" are built in, and a class code typed at
  sign-up survives the email-confirmation step.
- **Sessions** — export/import progress to a file, or quick-save snapshots in
  the browser.
- **Liquid Glass controls** — every button is a translucent pill with a
  backdrop blur, a domed specular highlight, a sheen that sweeps across on
  hover and a ripple from the point of contact, all of it dropped under
  `prefers-reduced-motion`.

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

> **Already have a project?** Run both files again. Every statement is
> create-if-not-exists or drop-then-create, so they add what is new and leave
> your data alone. `02_roles_and_tasks.sql` in particular is worth running on
> any project set up before it existed — see [what it fixes](#what-02_roles_and_taskssql-fixes).

1. Create a free project at <https://supabase.com>.
2. Open **SQL Editor → New query** and run the two files in [`supabase/`](supabase/),
   in order:
   - [`supabase/01_schema.sql`](supabase/01_schema.sql) — the tables, the row-level
     security rules, and the sign-up trigger.
   - [`supabase/02_roles_and_tasks.sql`](supabase/02_roles_and_tasks.sql) — the write
     boundaries between the two roles, and the functions for joining, leaving and
     managing a class.
3. Go to **Settings → API** and copy your **Project URL** and **anon / public key**
   into [`supabase-config.js`](supabase-config.js), then commit. The live site picks it up on the next deploy.
4. *(Recommended for classrooms)* **Authentication → Providers → Email** and turn
   **Confirm email** off, so students can sign in immediately without checking their inbox.

### What `02_roles_and_tasks.sql` fixes

`01_schema.sql` gets the *reads* right: no student can see another student, no
teacher can see outside their class. What it does not do is limit **which
columns of their own rows** a user may write — and "your own row" turns out to
include things that are not yours to decide. Against the schema on its own, each
of these is one line in the browser console of any signed-in student, and each
one works:

| One line a student could run | What it did |
|---|---|
| `update profiles set role='teacher'` | Promoted themselves, class code and all |
| `update profiles set teacher_id=…` | Joined a class without ever having the code |
| `update homework set title=…` | Rewrote the task they had been set |
| `delete from submissions` | Removed the essay before it was marked |

The second file closes all four, and hands back as explicit functions the few
things they legitimately covered:

| Function | Who may call it |
|---|---|
| `join_class(code)` | a student, with a code that matches a teacher |
| `leave_class()` | a student, on their own membership |
| `remove_student(id)` | a teacher, for someone in their own class |
| `regenerate_class_code()` | a teacher, when a code has spread too far |
| `switch_role(role)` | anyone, but only while their account is still empty |

Homework and feedback are guarded by triggers rather than policies, because a
policy judges whole rows and the rule here is about columns: a student's update
keeps their tick and their note, and silently restores the title, instructions
and due date. They get their edit; the teacher's wording survives it.

### Using it

- **You:** click **👤 Sign in → Create account**, choose **Teacher**. You get a
  **class code** (shown in the account panel and on the My class tab). Issue a new
  one from the account panel if it spreads beyond your class — students already in
  it stay in it.
- **Students:** click **Create account**, choose **Student**, and enter your class code.
  A student who joined without one, or with the wrong one, can enter it later from
  the same panel, and can leave a class from there too.
- Their band scores and their Writing/Speaking submissions then appear in **My class**.
  Click a student to read their actual responses and send feedback — it shows up on
  their dashboard the next time they open the app.
- **Homework:** set a task against one student or the whole class at once, with a
  module, instructions and a due date. Students tick it off and can leave a note
  back ("found Part 3 hard"), which you see on the tracking list. Edit a task in
  place rather than deleting it — the student's tick and note survive the edit.
- **Picked the wrong role at sign-up?** The account panel offers to switch, and
  allows it while the account is still empty. After that it says so and asks you
  to make a separate account, rather than moving an account that a class already
  depends on.

> **On a shared computer,** signing out clears the bands and history held in the
> browser, and signing in as someone else starts clean. Without that, the next
> student inherits the last one's scores — and the sync would then upload them
> into that student's row for you to mark.

### No confirmation email arrives

This is the first thing that goes wrong for almost everyone, and it is a
setting, not a bug.

A Supabase project that has not been given its own SMTP provider uses
Supabase's built-in sender, and that sender **only delivers to email addresses
that belong to the project's own team** — everything else is refused, silently
as far as the app can see. It is also capped at **two messages an hour for the
whole project**. So the first student who signs up with a Hotmail, Gmail or
school address waits for an email that was never going to arrive.

**The fix, for a classroom: don't use confirmation emails at all.**

1. Supabase dashboard → **Authentication → Sign In / Providers → Email**.
2. Turn **Confirm email** OFF, and save.
3. **Authentication → Users**, delete any account that is stuck unconfirmed —
   turning the setting off does not retro-confirm accounts created while it was
   on.
4. Create the account again in the app. It signs in immediately, no email.

Your students never see a confirmation step, which is what you want for a class
anyway: a code on the board, a name, a password, and they are in.

**If you do want real confirmation emails** — worth it if strangers can reach
your URL — add a custom SMTP provider under **Project Settings → Authentication
→ SMTP Settings**. Resend, Postmark, SendGrid and Brevo all have free tiers that
cover a class. Then turn **Confirm email** back on.

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
