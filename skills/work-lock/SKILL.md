---
name: work-lock
version: 1.0.0
description: Claims and releases work on a project's board so two people or two sessions never start the same job. Finds whatever claim file the project already uses, adds or flips your row, pushes it immediately so the claim is real, and clears it when you're done. Also spots rows left behind by sessions that ended. Runs only when explicitly invoked.
author: Chinmai Reddy (@chinmaireddy09)
source: https://github.com/chinmaireddy09/fleet-command
license: LicenseRef-FleetCommand-1.1
attribution: "work-lock by Chinmai Reddy (@chinmaireddy09), Fleet Command License 1.1"
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - AskUserQuestion
triggers:
  - /work-lock
  - claim this task
  - release the lock
---

# work-lock — claim it before you build it

The board answers one question: **who holds what, and what's next.** Nothing else. Keep it
short enough to read in ten seconds — it is not a history and not a backlog.

**Only run when asked** — `/work-lock`, or an unmistakable "claim this task" / "release the
lock". Never on a vague "what's next".

**Never edit another row.** Add or change **your own**. If you must correct someone else's,
say so out loud in the commit message.

---

## Why pushing immediately matters

A claim file is an ordinary text file. Git will not stop anyone editing the same code. It has
exactly **one** genuinely enforcing property:

> **The push race.** If two people claim the same job by editing the same row and both push,
> **the second push is rejected.** Not a convention — git refuses it. The loser has to pull,
> see the other claim, and deal with it.

That only works if you **push the claim before writing code.** A claim sitting uncommitted on
your machine protects nobody.

---

## Commands

| Type this | What happens |
|---|---|
| `/work-lock` | Show the board — who holds what, and anything stale |
| `/work-lock claim <task>` | Add your row and push it |
| `/work-lock release <task>` | Mark it done and clear the row |
| `/work-lock pause <task>` | Mark it paused, with where the work is parked |
| `/work-lock check <path or module>` | Is this already claimed by someone? |

---

## Step 1 — find the board

Projects name it all sorts of things. **Look, don't assume.**

```bash
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
ls "$ROOT"/docs/WORK-LOCKS.md "$ROOT"/WORK-LOCKS.md 2>/dev/null
grep -rilE "work.?lock|who.s working|claim" "$ROOT"/CLAUDE.md "$ROOT"/AGENTS.md \
  "$ROOT"/README.md "$ROOT"/docs/*.md 2>/dev/null | head
```

- **One candidate** → that's the board. Read it and match its existing table shape exactly.
- **Several** → read each, then ask the user once which is the live claim board.
- **None** → offer to create one (template at the end). Say clearly that you're creating it.

**Match the file's own conventions** — its columns, its status marks, its date format. Never
impose a different shape on a board someone has been keeping by hand.

---

## Step 2 — before claiming, check it's free

```bash
git -C "$ROOT" pull --rebase origin main      # someone may have claimed it since you looked
grep -n "<the task or module>" <board>
git log --oneline -5 -- <the paths you'll touch>
```

If someone holds it: **stop and say so.** Suggest talking to them rather than taking it. If
the row belongs to a session that has ended, treat it as stale — see Step 5.

---

## Step 3 — claim it

A row that says "working on orders" tells nobody anything useful. A row worth having carries:

| Column | Why it's there |
|---|---|
| **Task** | what the job is |
| **Who** | person, or session call-sign |
| **Status** | see the marks below |
| **Branch** | how anyone finds the work |
| **Paths / modules** | **this is what makes conflict detection possible** |
| **Next** | what you'll touch after this, so others can plan around you |
| **Since** | date, so stale rows are obvious |

Status marks:

| Mark | Means | Can someone else start it? |
|---|---|---|
| 🔒 claimed | reserved, not started | No — ask first |
| 🚧 in progress | being worked now | No |
| ⏸ paused | started then stopped; work is parked | Ask — read the parked branch first |
| ✅ done | landed | Yes; the row can be deleted |

Then **commit that file by name and push it, before any other work:**

```bash
git -C "$ROOT" add <board>          # never -A
git -C "$ROOT" commit -m "claim: <task> (<who>)"
git -C "$ROOT" push origin main
```

**If the push is rejected**, someone claimed first. Pull, look at their row, and if it's the
same job, go and talk to them before continuing.

---

## Step 4 — release it

When the work lands: set the row to ✅ **and move the story to the progress log** — the board
is not a history. If the project has a progress-logging skill, use it rather than inventing a
format. Then delete the row, or leave it done for a day if others are watching for it.

For **pause**, record where the work is: branch **and its newest commit**. A pointer to the
first commit hands over only part of the work.

---

## Step 5 — stale rows

A row saying 🚧 with nobody behind it is **the board lying**, and it makes a free job look
taken. That is worse than no board at all.

Signs: the branch hasn't moved in days; the session that claimed it is gone; the date is old.

**Do not just delete it.** Set it to ⏸ paused, record the branch and newest commit so the work
is findable, and say in the commit message that the owner appears to be gone.

---

## If there's no board yet

Offer to create one. Keep it minimal — a board grows worse with every column nobody fills in:

```markdown
# Work locks — who holds what

Claim **before** you start, and **push it immediately** — an unpushed claim protects nobody.
When you finish, move the story to the progress log and clear your row here.

**Status:** 🔒 claimed · 🚧 in progress · ⏸ paused · ✅ done

| Task | Who | Status | Branch | Paths / modules | Next | Since |
|---|---|---|---|---|---|---|
| | | | | | | |
```

---

*work-lock by Chinmai Reddy (@chinmaireddy09), under the Fleet Command License 1.1.*
*https://github.com/chinmaireddy09/fleet-command*
