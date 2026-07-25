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
