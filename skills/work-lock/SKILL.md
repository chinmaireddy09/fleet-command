---
name: work-lock
version: 1.0.0
description: Claims and releases work on a project's board so two people or two sessions never start the same job. Finds whatever claim file the project already uses, adds or flips your row, and pushes it immediately — the rejected second push is the only part of this with real teeth. Edits your own row and never reformats anyone else's, clears it when you are done, and spots rows left behind by sessions that ended, marking them paused rather than deleting work it cannot prove is finished. Runs only when explicitly invoked.
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
# ROOT is the checkout you are in, and it stays that way: everything below EDITS,
# stages, commits and pushes through it, so it must be your own worktree and your own
# branch -- never the shared checkout. `--show-toplevel` is correct here.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# SHARED_ROOT is the main repository, and it is used for ONE thing: answering "does a
# board already exist where I cannot see it?" before offering to create one. A station on
# a lane that has not merged the commit adding the board finds nothing here, and "none"
# falls through to "offer to create one" -- which is how a fleet ends up with two claim
# boards, the one outcome a claim board must never produce.
CDIR=$(git rev-parse --git-common-dir 2>/dev/null)
[ -n "$CDIR" ] && CDIR=$(cd "$CDIR" 2>/dev/null && pwd)
case "$CDIR" in
  */.git) SHARED_ROOT=$(dirname "$CDIR") ;;   # normal repo, or a linked worktree
  *)      SHARED_ROOT="$ROOT" ;;              # bare repo, or not a git repo at all
esac

ls "$ROOT"/docs/WORK-LOCKS.md "$ROOT"/WORK-LOCKS.md 2>/dev/null
grep -rilE "work.?lock|who.s working|claim" "$ROOT"/CLAUDE.md "$ROOT"/AGENTS.md \
  "$ROOT"/README.md "$ROOT"/docs/*.md 2>/dev/null | head
```

- **One candidate** → that's the board. Read it and match its existing table shape exactly.
- **Several** → read each, then ask the user once which is the live claim board.
- **None** → **look in the main repository first**, and only create if that is empty too:

```bash
[ "$SHARED_ROOT" != "$ROOT" ] && ls "$SHARED_ROOT"/docs/WORK-LOCKS.md "$SHARED_ROOT"/WORK-LOCKS.md 2>/dev/null
```

  **A hit means DO NOT CREATE.** The board exists and your branch simply does not have it
  yet — merge or check out the branch that does, then claim in your own copy. Creating one
  here gives the fleet a second board, and **two claim boards is worse than none**: each
  looks authoritative, and neither shows the claims on the other. Only if this is empty as
  well, offer to create one (template at the end) and say clearly that you're creating it.

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

### If the push is rejected

```
! [rejected]  HEAD -> main (non-fast-forward)
```

Someone claimed first. **You do not have to remember to check whether it was the same job — git
tells you which case you are in, mechanically.** Run the rebase and read what happens:

```bash
git -C "$ROOT" pull --rebase origin main
```

- **It rebases cleanly, no markers.** They claimed a *different* row. Git 3-way merged the two
  rows and there is nothing to adjudicate. Push again and carry on.
- **It stops with a conflict in the board.** You both claimed the **same row**. Both claims are
  preserved verbatim, and git refuses to pick a winner — which is the correct behaviour for a
  claim board.

**The board's teeth are git's 3-way merge, not this paragraph.** Measured 2026-08-23: two stations
claimed concurrently, one row auto-merged silently and the contested row conflicted, out of a
single rebase. An uncontested claim never asks you to adjudicate; a contested one is impossible to
miss.

**When it conflicts, the dangerous option is `--skip`, and git recommends it to you.**

```
Resolve all conflicts manually, then run "git rebase --continue".
You can instead skip this commit: run "git rebase --skip".
```

**Do NOT run `git rebase --skip`.** It discards *your* claim commit and leaves their row standing.
Everyone watches for `--force`; nothing here offers force, and force is not the trap. `--skip`
needs no alarming flag, is recommended by the tool itself, and is exactly what a losing claimant
reaches for to make a conflict go away.

**It is not that you "might not notice". EVERY signal you can cheaply read says it worked.**
Measured 2026-08-23, in an isolated lane:

```
$ git rebase --skip
Successfully rebased and updated refs/heads/lane/orders-rounding.     exit 0
```

| what you would check | what it says | truth |
|---|---|---|
| the tool's own words | `Successfully rebased` | a commit was destroyed |
| `git status --porcelain` | empty — clean tree | nothing to review |
| branch state | `...origin/main` — **in sync** | your claim is gone |
| conflict markers | none | no evidence a dispute happened |
| the board | the row reads correctly | **correct is the trap** |
| your claim commit | — | reachable from **0** branches |

**This is a false green:** a check whose every observable reports pass while the thing it was meant
to secure is gone — and here the *tool itself* is what reports the false pass. A station that ran
`--skip` would reasonably tell its coordinator the claim landed, would be wrong, would have no way
to notice, **and the board would corroborate it.**

It is recoverable only if you already know it happened: `ORIG_HEAD` and the reflog still hold the
commit. Both are **local-only, both expire, and neither is consulted by anyone who has just been
told "Successfully".** The recovery path exists; the prompt to use it does not.

**Do this instead:**

```bash
git -C "$ROOT" rebase --abort     # their row stands, YOUR claim commit stays on your branch
```

Then go and talk to them — that conversation is the actual resolution, not the git command.

**The contrast is the whole reason to prefer it**, both measured in the same lane an hour apart:

| | exit | your claim | branch reads |
|---|---|---|---|
| `--abort` | 0 | **retained** | `ahead 1, behind 4` |
| `--skip` | 0 | **discarded** | in sync |

**`--abort` leaves the disagreement visible in the branch state. `--skip` resolves it into
silence.** Same exit code, opposite outcome — which is why the exit code is not the thing to read.

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
