# Database

Four files, run in order, in the Supabase project's **SQL Editor → New query**.
All four are safe to re-run: every statement is create-if-not-exists or
drop-then-create, so running them again on a live project adds what is new and
leaves the data alone.

| File | What it does |
|---|---|
| `01_schema.sql` | Tables, row-level security, and the trigger that creates a profile on sign-up. |
| `02_roles_and_tasks.sql` | The write boundaries between student and teacher, and the functions for joining, leaving and managing a class. |
| `03_history_visibility.sql` | Whether a student may read their own submitted work back, and the teacher's switch that decides it. |
| `04_audio_library.sql` | The private `listening-audio` Storage bucket: each teacher's Listening recordings, readable by their own class only. |

And one Edge Function, deployed separately (dashboard → **Edge Functions**):

| Function | What it does |
|---|---|
| `functions/gemini/index.ts` | Holds the class's Gemini key as the secret `GEMINI_API_KEY` and makes calls with it for signed-in teachers and class members. Deployment steps are at the top of the file. |

## Why there are two

`01_schema.sql` gets the **reads** right — no student sees another student, no
teacher sees outside their class. What it leaves open is **which columns of
their own rows** a user may write, and "your own row" turns out to include
things that are not the user's to decide. Against the first file alone, every
one of these succeeds for any signed-in student:

```sql
update profiles   set role = 'teacher';   -- promotes themselves
update profiles   set teacher_id = '…';   -- joins a class with no code
update homework   set title = 'nothing';  -- rewrites the task they were set
delete from submissions;                  -- hides the essay before marking
```

`02_roles_and_tasks.sql` closes all four. It is not optional for a real class.

## Why there is a third

`submissions` has always kept every scored attempt — the essay as it was
written, the Speaking transcripts, and (since this file) the Reading and
Listening answer sheets. Until now only the teacher ever read them back, and a
student's own work vanished the moment they left the page.

Handing it back to them is what `03_history_visibility.sql` does, and the reason
it comes with a switch is that *"show every student their own history"* is not a
decision an app should make on a classroom's behalf. A teacher may want a paper
held back until it has been marked in class, or one student held out while the
rest of the group has it. So the teacher owns it, in two columns:

| Column | On whose row | Means |
|---|---|---|
| `history_default` | the **teacher** | the class-wide setting — on by default |
| `history_override` | a **student** | `null` follows the class; `true` / `false` decides for that student alone |

`history_visible_to(student)` folds the two together (a student with no teacher
is self-studying, so their work is their own), and the `submissions` select
policy calls it. That is the whole point: a student who is not allowed to read
their history cannot read it from the browser console either. The two switches
are `set_class_history(bool)` and `set_student_history(id, bool|null)`, both
teacher-only.

`INSERT` is deliberately untouched. A student whose history is switched off
still records every attempt for their teacher; they simply cannot read it back,
and switching it on later reveals the whole history rather than only what came
after.

## The audio library and the class key

`04_audio_library.sql` gives each teacher one folder in a **private** bucket,
named by their user id, with a subfolder per Listening section. The first
folder of an object's path decides everything: a teacher reads and writes only
their own; a student reads only their teacher's (`audio_library_owner()`), and
writes nothing. Private rather than public because official IELTS recordings
are copyrighted — this keeps them inside the class instead of on an open URL.
Files are capped at 18 MB, the most Gemini accepts inline in one request.

The Gemini function is not SQL, but it applies the same idea: it asks Supabase
whose session it has been sent, reads that user's own profile with their own
token, and serves only a teacher or a student with a `teacher_id`. It also
decides the model, so the key's owner — not a student's settings — chooses
what the key is spent on.

## How each rule is enforced, and why

Three different mechanisms, because they answer three different questions:

- **Row-level security** answers *may this user touch this row at all?* That is
  the right question for "is this student mine", and `01_schema.sql` already
  answers it well.
- **Column privileges** answer *may this user write this field?* Used on
  `profiles`, so `role`, `teacher_id` and `class_code` stop being writable while
  `full_name` stays editable. The functions are `security definer`, so they run
  as the owner and are unaffected — which is how the legitimate changes still
  happen.
- **Triggers** answer the same question where column privileges cannot, because
  teacher and student are the same database role (`authenticated`). Used on
  `homework` and `feedback`: a student's update keeps their `done_at` and
  `student_note` and silently restores everything else, rather than failing with
  an error they can do nothing about.

## After running them

A **student** can write: their own name; their own progress; new submissions (no
edits, no deletes); `done_at` and `student_note` on their own tasks; `read_at` on
notes addressed to them. Plus, through functions: join a class with a valid code,
or leave one.

A **teacher** can write: their own name; their class code, via
`regenerate_class_code()`; anything on tasks they set for their own students; new
feedback to their own students. Plus, through functions: remove a student from
their class, and open or close the history for the class
(`set_class_history`) or for one student (`set_student_history`).

A student **reads** their own submissions only while that switch allows it. A
teacher reads their whole class either way — the switch decides what the student
sees, never what the teacher sees.

## Testing a change to these files

They were developed against a local PostgreSQL with `auth.uid()` stubbed off a
GUC and the `anon` / `authenticated` roles created by hand, which is enough to
run the statements above as a real signed-in student and watch them fail. If you
change a policy, re-run that check rather than reasoning about it — the four
holes above all looked fine on the page.

The visibility rules in `03_history_visibility.sql` were checked the same way,
as a teacher and three students (two in the class, one self-studying): class
switch on and off, a student forced on while the class is off and forced off
while the class is on, a student put back on the class default, a blocked
student still able to submit, no student able to read another's work, and both
switches refused to a student who calls them directly.

`04_audio_library.sql` was checked the same way, with a stand-in for Supabase's
`storage` schema and a second teacher and class: each class sees only its own
teacher's recordings, a student with no class sees none, only the owning teacher
can upload, replace or delete, and neither a student nor another teacher can.

`functions/gemini/index.ts` was run in Deno against stand-ins for Supabase Auth
and Gemini: no session, an expired one, a student without a class, a student
asking for a model the owner has not allowed, the key not yet set, and the
browser's CORS preflight.
