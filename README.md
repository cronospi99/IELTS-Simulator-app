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

## AI engine

AI features run on **Gemini 3.6 Flash-Lite** by default. The API key and model
are configurable from the **⚙ AI engine** panel and are stored only in the
browser.

> ⚠️ **Security note:** this app calls Gemini directly from the browser, so the
> key is visible to anyone who inspects the page or its network traffic. That is
> fine for personal use, but **do not distribute a copy of this file with your
> key saved in it.** For shared/classroom use, have each user enter their own
> key, or proxy requests through a small server you control that holds the key.
