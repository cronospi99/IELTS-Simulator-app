/* =============================================================================
   SUPABASE CONNECTION  —  fill these in to switch on teacher/student accounts
   -----------------------------------------------------------------------------
   1. Create a free project at https://supabase.com
   2. Run supabase-schema.sql in the project's SQL Editor (one click)
   3. In Supabase go to  Settings → API  and copy:
        • Project URL      →  url    below
        • anon / public key →  anonKey below
   4. Commit this file. The live site picks it up on the next deploy.

   IS IT SAFE TO COMMIT THE anon KEY?  Yes — that is exactly what it is for.
   The anon key only ever acts as the currently logged-in user, and the
   row-level security rules in supabase-schema.sql mean a student can only read
   their own rows and a teacher only their own students'. Never commit the
   "service_role" key, which does bypass those rules.

   Leave the placeholders as they are and the app simply runs in offline mode,
   exactly as before: everything works, progress just stays in this browser.
   ============================================================================= */

window.SUPABASE_CONFIG = {
  url: "YOUR_SUPABASE_PROJECT_URL",
  anonKey: "YOUR_SUPABASE_ANON_KEY"
};
