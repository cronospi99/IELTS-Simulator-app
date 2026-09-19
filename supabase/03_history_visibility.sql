-- =============================================================================
-- IELTS Academic Simulator — who may read a student's own work back
-- -----------------------------------------------------------------------------
-- Run this AFTER 01_schema.sql and 02_roles_and_tasks.sql, in the same SQL
-- Editor, the same way. Re-running it is safe: every statement replaces,
-- recreates, or is add-if-missing.
--
-- WHY THIS FILE EXISTS
-- Every scored attempt is already kept in `submissions` — the essay as it was
-- written, the Speaking transcripts, and now the Reading and Listening answer
-- sheets. Until now only the teacher ever read them back: the student's own
-- work was written once and disappeared.
--
-- Giving it back to the student is the point of this file, and the reason it
-- needs a switch is that "show every student their own history" is not a
-- decision an app should make for a classroom. A teacher may want a paper kept
-- back until it has been marked in class, or one student held out while the
-- rest of the group has it. So the teacher owns the switch:
--
--   profiles.history_default   on a TEACHER row — the class-wide setting
--   profiles.history_override  on a STUDENT row — null follows the class,
--                              true/false overrides it for that one student
--
-- and the rule is enforced in row-level security, not in the page. A student
-- who is not allowed to read their history cannot read it from the browser
-- console either, which is the only version of this switch worth having.
-- =============================================================================


-- ============================================================= 1. COLUMNS ===
alter table public.profiles add column if not exists history_default  boolean not null default true;
alter table public.profiles add column if not exists history_override boolean;

comment on column public.profiles.history_default is
  'Teacher rows: may the students in this class read their own submission history? Ignored on a student row.';
comment on column public.profiles.history_override is
  'Student rows: null = follow the teacher''s history_default; true/false = decided for this student alone.';

-- Neither column is the user's to write. 02_roles_and_tasks.sql already
-- revoked table-level UPDATE on profiles and granted back only full_name, so a
-- column added afterwards is unwritable by default -- this repeats the grant so
-- the rule still holds if the files are ever run out of order.
revoke update on public.profiles from authenticated;
revoke update on public.profiles from anon;
grant  update (full_name) on public.profiles to authenticated;


-- =========================================================== 2. THE RULE ====
-- One function, consulted by the policy and by the app, so the page and the
-- database can never disagree about what a student is allowed to see.
--
-- A student with no teacher is self-studying: nobody else owns their work, so
-- it is theirs to read. Otherwise the override decides if it is set, and the
-- class-wide default decides if it is not.
--
-- SECURITY DEFINER because the student must not be able to read their teacher's
-- profile row directly, only the one boolean that follows from it. The guard
-- keeps that narrow: you may ask about yourself, or about your own student.
create or replace function public.history_visible_to(p_student uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_teacher  uuid;
  v_override boolean;
  v_default  boolean;
begin
  if p_student is null then
    return false;
  end if;

  select teacher_id, history_override
    into v_teacher, v_override
    from public.profiles
   where id = p_student;

  if not found then
    return false;
  end if;

  -- Only the student themselves, or the teacher whose class they are in, has
  -- any business asking. Anyone else is told "no" rather than the truth.
  if p_student <> auth.uid() and (v_teacher is null or v_teacher <> auth.uid()) then
    return false;
  end if;

  if v_override is not null then
    return v_override;
  end if;

  if v_teacher is null then
    return true;                        -- self-study: their own work is theirs
  end if;

  select history_default into v_default from public.profiles where id = v_teacher;
  return coalesce(v_default, true);
end;
$$;

-- The policy below runs this as the querying user, so EXECUTE has to stay.
-- The guard inside is what keeps it from being an oracle.
grant execute on function public.history_visible_to(uuid) to authenticated;

-- What the student's own page asks on sign-in. Takes no argument, so it cannot
-- be pointed at anyone else.
create or replace function public.can_see_my_history()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.history_visible_to(auth.uid());
$$;

grant execute on function public.can_see_my_history() to authenticated;


-- ======================================================== 3. THE POLICY =====
-- 02_roles_and_tasks.sql split submissions into select-own and insert-own, and
-- deliberately gave students no UPDATE and no DELETE: a submission is a record
-- of an attempt, so it is written once and then it stands. That is unchanged.
-- What changes is that reading it back is now conditional.
--
-- INSERT is untouched on purpose. A student whose history is switched off still
-- records every attempt for their teacher; they simply cannot read it back.
-- Switching it on later reveals the whole history, not just what came after.
drop policy if exists submissions_select_own on public.submissions;

create policy submissions_select_own on public.submissions
  for select using (
    student_id = auth.uid()
    and public.history_visible_to(auth.uid())
  );

-- The teacher's view is unchanged and unconditional: submissions_select_class
-- from 01_schema.sql still lets them read everything in their own class. The
-- switch decides what the STUDENT sees, never what the teacher sees.


-- ====================================================== 4. THE TEACHER'S ====
--                                                           TWO SWITCHES
-- Both are functions rather than columns for the same reason as join_class:
-- the column is not writable, and the check belongs next to the write.

-- The class-wide setting. Applies to every student who is following the class
-- default -- anyone given an explicit yes or no keeps it.
create or replace function public.set_class_history(p_on boolean)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_on is null then
    raise exception 'Pass true or false.';
  end if;
  if not exists (select 1 from public.profiles where id = auth.uid() and role = 'teacher') then
    raise exception 'Only a teacher can change this setting.';
  end if;

  update public.profiles set history_default = p_on where id = auth.uid();
  return p_on;
end;
$$;

grant execute on function public.set_class_history(boolean) to authenticated;


-- The exception for one student. Passing null puts them back on the class
-- default rather than freezing today's value into their row -- so a teacher who
-- later flips the class switch moves them too, which is what "follow the class"
-- has to mean for the setting to be worth having.
create or replace function public.set_student_history(p_student uuid, p_value boolean)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and role = 'teacher') then
    raise exception 'Only a teacher can change this setting.';
  end if;
  if not exists (select 1 from public.profiles where id = p_student and teacher_id = auth.uid()) then
    raise exception 'That student is not in your class.';
  end if;

  update public.profiles set history_override = p_value where id = p_student;
  return public.history_visible_to(p_student);
end;
$$;

grant execute on function public.set_student_history(uuid, boolean) to authenticated;


-- -----------------------------------------------------------------------------
-- WHAT CHANGED FOR EACH ROLE
--   student   may read their own submissions only while their teacher allows
--             it; still records every attempt either way; still cannot edit or
--             delete one, and still cannot see anybody else's
--   teacher   reads their whole class as before, and now owns two switches:
--             set_class_history(bool) for the group,
--             set_student_history(id, bool|null) for one student
--
-- A project set up before this file existed gets history_default = true, so
-- running it turns the history ON for every class. Turn it off from the
-- My class tab if that is not what you want.
-- -----------------------------------------------------------------------------
