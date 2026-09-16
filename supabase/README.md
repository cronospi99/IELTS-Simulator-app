# Database

Two files, run in order, in the Supabase project's **SQL Editor → New query**.
Both are safe to re-run: every statement is create-if-not-exists or
drop-then-create, so running them again on a live project adds what is new and
leaves the data alone.

| File | What it does |
|---|---|
| `01_schema.sql` | Tables, row-level security, and the trigger that creates a profile on sign-up. |
| `02_roles_and_tasks.sql` | The write boundaries between student and teacher, and the functions for joining, leaving and managing a class. |

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
feedback to their own students. Plus, through a function: remove a student from
their class.

## Testing a change to these files

They were developed against a local PostgreSQL with `auth.uid()` stubbed off a
GUC and the `anon` / `authenticated` roles created by hand, which is enough to
run the statements above as a real signed-in student and watch them fail. If you
change a policy, re-run that check rather than reasoning about it — the four
holes above all looked fine on the page.
