-- =============================================================================
-- IELTS Academic Simulator — the class's Listening audio library
-- -----------------------------------------------------------------------------
-- Run this AFTER 01, 02 and 03, in the same SQL Editor, the same way. Re-running
-- it is safe.
--
-- WHY THIS FILE EXISTS
-- The Listening generator needs four real recordings, one per section. Until
-- now every student had to find them: attach four files from their own
-- computer, or configure a Google Drive folder, an OAuth client and a Google
-- sign-in of their own. That is a teacher's job, done once.
--
-- So each teacher gets one library, in a private Storage bucket:
--
--   listening-audio/<teacher id>/section-1/…mp3
--                                section-2/…
--                                section-3/…
--                                section-4/…
--
-- The teacher uploads into it from the app (My class → Listening audio
-- library). Their students' Listening tab draws one recording at random from
-- each section — no files, no Google account, no settings.
--
-- WHO CAN DO WHAT
--   a teacher   reads, uploads, replaces and deletes in their own folder only
--   a student   reads their own teacher's folder, and nothing else
--   anyone else nothing — the bucket is private, not public: official IELTS
--               recordings are copyrighted, and this keeps them inside the
--               class rather than on an open URL
-- =============================================================================


-- ============================================================= 1. BUCKET ====
-- 18 MB per file: the most Gemini accepts inline in one request, which is how
-- the generator sends a section's audio. A larger file would upload fine and
-- then fail at generation time, which is the worse place to find out.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('listening-audio', 'listening-audio', false, 18874368,
        array['audio/mpeg','audio/mp3','audio/mp4','audio/x-m4a','audio/aac',
              'audio/wav','audio/x-wav','audio/wave','audio/ogg','audio/webm','audio/flac'])
on conflict (id) do update
   set public             = false,
       file_size_limit    = excluded.file_size_limit,
       allowed_mime_types = excluded.allowed_mime_types;


-- ========================================================= 2. THE OWNER =====
-- Whose library this user sees: their own if they teach, their teacher's if
-- they are in a class, nobody's otherwise. SECURITY DEFINER so a student can
-- learn their teacher's id without reading the teacher's profile row.
create or replace function public.audio_library_owner()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case when role = 'teacher' then id::text else teacher_id::text end
    from public.profiles
   where id = auth.uid();
$$;

grant execute on function public.audio_library_owner() to authenticated;

create or replace function public.is_teacher()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'teacher');
$$;

grant execute on function public.is_teacher() to authenticated;


-- ========================================================== 3. POLICIES =====
-- The first folder of every path is the teacher's id; storage.foldername()
-- splits the path, and [1] is that folder.
drop policy if exists listening_audio_read   on storage.objects;
drop policy if exists listening_audio_insert on storage.objects;
drop policy if exists listening_audio_update on storage.objects;
drop policy if exists listening_audio_delete on storage.objects;

create policy listening_audio_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'listening-audio'
    and (storage.foldername(name))[1] = public.audio_library_owner()
  );

create policy listening_audio_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'listening-audio'
    and public.is_teacher()
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Update is what an upload that replaces a same-named file needs.
create policy listening_audio_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'listening-audio'
    and public.is_teacher()
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'listening-audio'
    and public.is_teacher()
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy listening_audio_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'listening-audio'
    and public.is_teacher()
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- -----------------------------------------------------------------------------
-- MOVING YOUR DRIVE AUDIOS HERE
-- Download the folder from Google Drive (right-click → Download gives a zip),
-- then in the app open My class → Listening audio library and add each
-- section's files to its column. Several files can be chosen at once.
-- -----------------------------------------------------------------------------
