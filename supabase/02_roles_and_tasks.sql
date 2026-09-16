-- =============================================================================
-- IELTS Academic Simulator — role boundaries and homework integrity
-- -----------------------------------------------------------------------------
-- Run this AFTER 01_schema.sql, in the same SQL Editor, the same way.
-- Re-running it is safe: every statement replaces or recreates.
--
-- WHY THIS FILE EXISTS
-- 01_schema.sql gets the reads right — no student can see another student, no
-- teacher can see outside their class. What it does not do is limit WHICH
-- COLUMNS of their own rows a user may write, and "your own row" turns out to
-- include some things that are not theirs to decide. Against the schema as it
-- stands, all four of these succeed:
--
--   update profiles  set role = 'teacher'      -- a student promotes themselves
--   update profiles  set teacher_id = <uuid>   -- joins a class with no code
--   update homework  set title = 'nothing'     -- rewrites the task they were set
--   delete from submissions                    -- hides the essay from marking
--
-- None of them is an exotic attack; each is one line in the browser console of
-- a signed-in student. This file closes all four and gives back, as explicit
-- functions, the few things they legitimately covered.
-- =============================================================================


-- ============================================================ 1. PROFILES ===
-- role, teacher_id and class_code decide what the app shows you and whose data
-- you can reach, so they stop being user-writable. Column-level privileges are
-- the right tool: a policy can only say yes or no to the whole row, while this
-- says "you may edit your name, and nothing else".
--
-- The functions further down are SECURITY DEFINER, so they run as the owner and
-- are unaffected by this revoke — which is exactly how the legitimate changes
-- still happen.

revoke update on public.profiles from authenticated;
revoke update on public.profiles from anon;
grant  update (full_name) on public.profiles to authenticated;


-- One generator for class codes, so the trigger, the client fallback and the
-- regenerate button cannot drift apart. The alphabet leaves out I, O, 0 and 1:
-- a code is read aloud or copied off a whiteboard, and those four are where
-- that goes wrong.
create or replace function public.new_class_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
  v_try  int := 0;
begin
  loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.profiles where class_code = v_code);
    v_try := v_try + 1;
    if v_try > 50 then
      raise exception 'Could not find a free class code. Try again.';
    end if;
  end loop;
  return v_code;
end;
$$;


-- Same trigger as before, now using the shared generator and tolerating a
-- collision instead of failing the sign-up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := coalesce(new.raw_user_meta_data->>'role', 'student');
begin
  if v_role not in ('student','teacher') then
    v_role := 'student';
  end if;

  insert into public.profiles (id, email, full_name, role, class_code)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    v_role,
    case when v_role = 'teacher' then public.new_class_code() else null end
  )
  on conflict (id) do nothing;

  return new;
end;
$$;


-- --------------------------------------------------------- class membership --
-- join_class already existed; it is repeated here so that it, leave_class and
-- remove_student read as one set, and so this file can be run against a project
-- created from an older copy of the schema.
create or replace function public.join_class(p_code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_teacher uuid;
  v_name    text;
  v_role    text;
begin
  select role into v_role from public.profiles where id = auth.uid();
  if v_role is null then
    raise exception 'Your profile has not been created yet. Reload the page and try again.';
  end if;
  -- Previously a teacher could call this: the update matched nothing but the
  -- function still returned a name, so the app reported a class had been
  -- joined when none had.
  if v_role <> 'student' then
    raise exception 'Only a student account can join a class.';
  end if;

  select id, full_name into v_teacher, v_name
  from public.profiles
  where class_code = upper(trim(p_code)) and role = 'teacher';

  if v_teacher is null then
    raise exception 'That class code does not match any teacher.';
  end if;

  update public.profiles set teacher_id = v_teacher where id = auth.uid();

  return coalesce(nullif(v_name,''), 'your teacher');
end;
$$;


-- A student can no longer clear teacher_id by hand, so leaving needs a door of
-- its own. Their work stays where it is; only the link goes.
create or replace function public.leave_class()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
     set teacher_id = null
   where id = auth.uid() and role = 'student';
end;
$$;


-- The teacher's side of the same door: removing someone who joined by mistake,
-- or who has left the course.
create or replace function public.remove_student(p_student uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and role = 'teacher') then
    raise exception 'Only a teacher can remove a student.';
  end if;
  if not exists (select 1 from public.profiles where id = p_student and teacher_id = auth.uid()) then
    raise exception 'That student is not in your class.';
  end if;
  update public.profiles set teacher_id = null where id = p_student;
end;
$$;


-- A leaked code is worth changing, and until now nothing could change it.
-- Students already linked stay linked — teacher_id is what the class is made
-- of, the code is only the way in.
create or replace function public.regenerate_class_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and role = 'teacher') then
    raise exception 'Only a teacher has a class code.';
  end if;
  v_code := public.new_class_code();
  update public.profiles set class_code = v_code where id = auth.uid();
  return v_code;
end;
$$;


-- Picking the wrong button on the sign-up form should not mean a dead account,
-- but a role change is also not something to allow on an account that is
-- already part of a class and has work in it. So: only while the account is
-- still empty.
create or replace function public.switch_role(p_role text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me public.profiles;
begin
  if p_role not in ('student','teacher') then
    raise exception 'Role must be student or teacher.';
  end if;

  select * into v_me from public.profiles where id = auth.uid();
  if v_me.id is null then
    raise exception 'Your profile has not been created yet. Reload the page and try again.';
  end if;
  if v_me.role = p_role then
    return p_role;
  end if;

  if v_me.teacher_id is not null
     or exists (select 1 from public.profiles    where teacher_id = v_me.id)
     or exists (select 1 from public.submissions where student_id = v_me.id)
     or exists (select 1 from public.homework    where student_id = v_me.id or teacher_id = v_me.id)
     or exists (select 1 from public.feedback    where student_id = v_me.id or teacher_id = v_me.id)
  then
    raise exception 'This account is already in use as a %. Create a separate account for the other role.', v_me.role;
  end if;

  update public.profiles
     set role = p_role,
         class_code = case when p_role = 'teacher'
                           then coalesce(v_me.class_code, public.new_class_code())
                           else null end
   where id = auth.uid();

  return p_role;
end;
$$;


-- =========================================================== 2. HOMEWORK ====
-- A student must be able to tick a task off and leave a note with it, and must
-- not be able to touch anything else on the row. RLS cannot express that — it
-- judges rows, not columns — and column grants cannot either, because teacher
-- and student are the same database role here. A trigger can.
--
-- It pins rather than rejects: a student sending a whole row back (which is
-- what a PATCH of several fields is) gets their tick recorded and the rest
-- quietly restored, instead of an error they can do nothing about.

create or replace function public.homework_student_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() = old.student_id and auth.uid() <> old.teacher_id then
    new.id           := old.id;
    new.teacher_id   := old.teacher_id;
    new.student_id   := old.student_id;
    new.title        := old.title;
    new.module       := old.module;
    new.instructions := old.instructions;
    new.due_at       := old.due_at;
    new.created_at   := old.created_at;
  end if;
  return new;
end;
$$;

drop trigger if exists homework_student_guard_trg on public.homework;
create trigger homework_student_guard_trg
  before update on public.homework
  for each row execute function public.homework_student_guard();


-- ======================================================== 3. SUBMISSIONS ====
-- "for all" gave students DELETE as well, so an essay could be removed from
-- under the teacher between being scored and being read. A submission is a
-- record of an attempt: write it once, then it stands.

drop policy if exists submissions_rw_own      on public.submissions;
drop policy if exists submissions_select_own  on public.submissions;
drop policy if exists submissions_insert_own  on public.submissions;

create policy submissions_select_own on public.submissions
  for select using (student_id = auth.uid());

create policy submissions_insert_own on public.submissions
  for insert with check (student_id = auth.uid());


-- =========================================================== 4. PROGRESS ====
-- Progress is a live mirror of the browser, so update belongs here — but
-- delete does not: wiping the row is wiping every band the teacher can see.

drop policy if exists progress_rw_own     on public.progress;
drop policy if exists progress_select_own on public.progress;
drop policy if exists progress_insert_own on public.progress;
drop policy if exists progress_update_own on public.progress;

create policy progress_select_own on public.progress
  for select using (student_id = auth.uid());

create policy progress_insert_own on public.progress
  for insert with check (student_id = auth.uid());

create policy progress_update_own on public.progress
  for update using (student_id = auth.uid()) with check (student_id = auth.uid());


-- ============================================================ 5. FEEDBACK ===
-- Same shape as homework: the student's only legitimate write is marking a
-- note read, and nothing stopped them rewriting the note itself.

create or replace function public.feedback_student_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() = old.student_id and auth.uid() <> old.teacher_id then
    new.id         := old.id;
    new.teacher_id := old.teacher_id;
    new.student_id := old.student_id;
    new.message    := old.message;
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;

drop trigger if exists feedback_student_guard_trg on public.feedback;
create trigger feedback_student_guard_trg
  before update on public.feedback
  for each row execute function public.feedback_student_guard();


-- -----------------------------------------------------------------------------
-- WHAT A STUDENT CAN NOW WRITE
--   profiles     their own full_name
--   progress     their own scores and history
--   submissions  new rows for themselves; no edits, no deletions
--   homework     done_at and student_note on their own tasks
--   feedback     read_at on notes addressed to them
--   and, through functions: join a class with a valid code, or leave one
--
-- WHAT A TEACHER CAN NOW WRITE
--   profiles     their own full_name; their class code via regenerate_class_code
--   homework     anything, on tasks they set for students in their class
--   feedback     new notes to students in their class
--   and, through functions: remove a student from their class
-- -----------------------------------------------------------------------------
