/* =============================================================================
   LOCAL CONFIG TEMPLATE  —  the static-app equivalent of a .env file
   -----------------------------------------------------------------------------
   HOW TO USE
     1. Copy this file to  config.local.js   (same folder as index.html).
     2. Put your real Gemini API key + model below.
     3. Open index.html — the key loads automatically. Nothing to paste.

   config.local.js is listed in .gitignore, so your key stays OUT of Git.
   This file (config.example.js) is safe to commit because it has no real key.

   NOTES
     • A Gemini API key normally looks like  "AIzaSy...."  (get one free at
       https://aistudio.google.com/apikey ). If yours looks very different, it
       may not work with this API — use the app's “Test connection” button.
     • Not sure which model to use? Leave the default, open “⚙ AI engine” in the
       app, and click “Test connection” — it lists the exact model IDs your key
       can use. Put one of those here.
     • This still runs entirely in the browser, so the key is visible to anyone
       who can open your local copy. Don't hand out a copy with your key in it;
       for shared/classroom use, run a small proxy server instead (see README).
   ============================================================================= */

window.GEMINI_CONFIG = {
  key: "PASTE_YOUR_GEMINI_API_KEY_HERE",
  model: "gemini-3.5-flash-lite"
};

/* -----------------------------------------------------------------------------
   OPTIONAL — translator engine for the 🌐 Language desk on each skill tab.

   Leave all of this out and the desk still works: it falls back to MyMemory,
   which is free and needs no key. These are the upgrades:

     googleTranslateKey  A *separate* key from the Gemini one above. In Google
                         Cloud, enable "Cloud Translation API" and create an API
                         key under Credentials. 100+ languages.
     deeplProxyUrl       DeepL is the most accurate engine for European pairs but
                         refuses browser requests by design (403 + CORS), so it
                         needs a small proxy you run. Put its base URL here.
     deeplKey            Only if your proxy expects the auth key from the client
                         rather than holding it itself.
     provider            "auto" (default) | "google" | "deepl" | "gemini" | "mymemory"

   Conjugation tables and alternative words always run on the Gemini key above,
   whichever engine is chosen — no translation API returns verb forms.
   --------------------------------------------------------------------------- */
window.TRANSLATE_CONFIG = {
  provider: "auto",
  googleTranslateKey: "",
  deeplProxyUrl: "",
  deeplKey: ""
};
