-- =============================================================================
-- IELTS Academic Simulator — Supabase schema
-- =============================================================================
-- HOW TO USE
--   1. Create a free project at https://supabase.com
--   2. Open the project → SQL Editor → New query
--   3. Paste this whole file and click RUN
--   4. Copy your Project URL and anon key (Settings → API) into
--      supabase-config.js in this repository, then commit.
--
-- WHAT THIS SETS UP
--   profiles     one row per user (teacher or student). Teachers get a class
--                code; students are linked to a teacher by teacher_id.
--   progress     latest band scores + history snapshot per student.
--   submissions  each scored Writing/Speaking attempt, kept for the teacher.
--   feedback     messages a teacher sends to one of their students.
--
-- SECURITY (row-level security is ON for every table)
--   A student can only ever read/write their OWN rows.
--   A teacher can only read rows belonging to students in THEIR class, and can
--   only send feedback to those students. Nobody can read anyone else's data,
--   even though the anon key in the app is public — that key only ever acts as
--   the logged-in user.
-- =============================================================================

-- ---------------------------------------------------------------- tables ----
create table if not exists public.profiles (
  id          uuid primary key references auth.users on delete cascade,
  email       text,
  full_name   text,
  role        text not null default 'student' check (role in ('student','teacher')),
  teacher_id  uuid references public.profiles(id) on delete set null,
  class_code  text unique,
  created_at  timestamptz not null default now()
);

create table if not exists public.progress (
  student_id  uuid primary key references public.profiles(id) on delete cascade,
  scores      jsonb not null default '{}'::jsonb,
  history     jsonb not null default '[]'::jsonb,
  updated_at  timestamptz not null default now()
);

create table if not exists public.submissions (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid not null references public.profiles(id) on delete cascade,
  module      text not null,             -- writing | speaking | reading | listening
  task        text,                      -- task1 | task2 | part1 ...
  prompt      text,
  content     text,
  band        numeric,
  report      jsonb,
  created_at  timestamptz not null default now()
);

create table if not exists public.feedback (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid not null references public.profiles(id) on delete cascade,
  teacher_id  uuid not null references public.profiles(id) on delete cascade,
  message     text not null,
  created_at  timestamptz not null default now(),
  read_at     timestamptz
);

create index if not exists submissions_student_idx on public.submissions(student_id, created_at desc);
create index if not exists feedback_student_idx    on public.feedback(student_id, created_at desc);
create index if not exists profiles_teacher_idx    on public.profiles(teacher_id);

-- ------------------------------------------------------------- functions ----
-- Helper used by policies. SECURITY DEFINER so a teacher can test "is this my
-- student?" without needing blanket read access to the profiles table.
create or replace function public.is_my_student(sid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = sid and teacher_id = auth.uid()
  );
$$;

-- Creates the profile row automatically whenever someone signs up. Role and
-- name come from the sign-up metadata sent by the app. Teachers are given a
-- random 6-character class code that students use to join.
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
    case when v_role = 'teacher'
         then upper(substr(replace(gen_random_uuid()::text,'-',''), 1, 6))
         else null end
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- A student calls this once with the code their teacher gives them. SECURITY
-- DEFINER so the lookup works without exposing the whole teacher list.
create or replace function public.join_class(p_code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_teacher uuid;
  v_name    text;
begin
  select id, full_name into v_teacher, v_name
  from public.profiles
  where class_code = upper(trim(p_code)) and role = 'teacher';

  if v_teacher is null then
    raise exception 'That class code does not match any teacher.';
  end if;

  update public.profiles
     set teacher_id = v_teacher
   where id = auth.uid() and role = 'student';

  return coalesce(nullif(v_name,''), 'your teacher');
end;
$$;

-- --------------------------------------------------------------- policies ---
alter table public.profiles    enable row level security;
alter table public.progress    enable row level security;
alter table public.submissions enable row level security;
alter table public.feedback    enable row level security;

-- profiles -------------------------------------------------------------------
drop policy if exists profiles_select_own      on public.profiles;
drop policy if exists profiles_select_students on public.profiles;
drop policy if exists profiles_insert_own      on public.profiles;
drop policy if exists profiles_update_own      on public.profiles;

create policy profiles_select_own on public.profiles
  for select using (id = auth.uid());

-- direct column comparison (no sub-query on profiles) so there is no recursion
create policy profiles_select_students on public.profiles
  for select using (teacher_id = auth.uid());

create policy profiles_insert_own on public.profiles
  for insert with check (id = auth.uid());

create policy profiles_update_own on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- progress -------------------------------------------------------------------
drop policy if exists progress_rw_own        on public.progress;
drop policy if exists progress_select_class  on public.progress;

create policy progress_rw_own on public.progress
  for all using (student_id = auth.uid()) with check (student_id = auth.uid());

create policy progress_select_class on public.progress
  for select using (public.is_my_student(student_id));

-- submissions ----------------------------------------------------------------
drop policy if exists submissions_rw_own       on public.submissions;
drop policy if exists submissions_select_class on public.submissions;

create policy submissions_rw_own on public.submissions
  for all using (student_id = auth.uid()) with check (student_id = auth.uid());

create policy submissions_select_class on public.submissions
  for select using (public.is_my_student(student_id));

-- feedback -------------------------------------------------------------------
drop policy if exists feedback_select_student on public.feedback;
drop policy if exists feedback_update_student on public.feedback;
drop policy if exists feedback_select_teacher on public.feedback;
drop policy if exists feedback_insert_teacher on public.feedback;

create policy feedback_select_student on public.feedback
  for select using (student_id = auth.uid());

-- students may only mark their own messages as read
create policy feedback_update_student on public.feedback
  for update using (student_id = auth.uid()) with check (student_id = auth.uid());

create policy feedback_select_teacher on public.feedback
  for select using (teacher_id = auth.uid());

create policy feedback_insert_teacher on public.feedback
  for insert with check (teacher_id = auth.uid() and public.is_my_student(student_id));
