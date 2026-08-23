---
name: status-and-backlog
version: 1.0.0
description: Keeps a project's backlog and status document honest. Files a new item with enough detail that someone else could pick it up cold — what was measured, what was ruled out, and how NOT to fix it — closes one with what actually shipped, and re-scopes it when the facts change. Records an unexplained cause as unexplained rather than implying a diagnosis, and cross-references items that must land in a given order onto both. Finds whatever backlog file the project already uses and matches its conventions rather than imposing a format. Runs only when explicitly invoked, as /status-and-backlog or /backlog.
author: Chinmai Reddy (@chinmaireddy09)
source: https://github.com/chinmaireddy09/fleet-command
license: LicenseRef-FleetCommand-1.1
attribution: "status-and-backlog by Chinmai Reddy (@chinmaireddy09), Fleet Command License 1.1"
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - AskUserQuestion
---

# status-and-backlog — what's left, and how healthy each part is

This document answers **"what should I work on next?"** It holds two things: the **backlog**
(everything worth doing that isn't done) and the **status** (how complete or healthy each part
of the system is).

It is not a history — that's the progress log. It is not a claim board — that's work-lock.

**Only run when asked** — `/backlog`, `/status-and-backlog`, or an unmistakable "file this as
a backlog item".

**Never rewrite someone's existing entry.** Add, check off, or append a dated correction.
Entries are decisions with reasoning; overwriting one destroys why it was made.

---

## Commands

| Type this | What happens |
|---|---|
| `/backlog` | Show what's open, grouped, with anything blocked called out |
| `/backlog file <finding>` | File a new item, with enough detail to act on cold |
| `/backlog close <id>` | Mark it done, with what actually shipped |
| `/backlog rescope <id>` | The facts changed — correct it without erasing the old reading |

---

## Step 1 — find the file

**Look, don't assume.** Projects call it `BACKLOG.md`, `ROADMAP.md`, `PROJECT-STATUS.md`,
`TODO.md`, or something else.

```bash
# TWO ROOTS, AND ONLY ONE OF THEM IS WHERE YOU WRITE.
#
# ROOT — the checkout you are in, and the copy you EDIT. `--show-toplevel` is correct here
# and must stay: a linked worktree has its own copy of the tracked files and its own
# branch, so a station edits ITS OWN backlog and commits it on its own lane. An earlier
# fix here pointed ROOT at the main repo to solve the discovery miss below, and that is an
# over-correction — it makes a station edit the SHARED checkout out from under whoever is
# sitting in it. `--git-common-dir` is for what should be REMEMBERED once;
# `--show-toplevel` is for anything WRITTEN or COMMITTED. One variable cannot be both.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# SHARED_ROOT — the main repository, used ONLY to answer "does a backlog already exist
# somewhere I cannot see from this lane?" before offering to create one. A station on a
# branch that has not merged the commit adding the backlog finds nothing in its own
# checkout, and "not found" falls through to "create one".
CDIR=$(git rev-parse --git-common-dir 2>/dev/null)
[ -n "$CDIR" ] && CDIR=$(cd "$CDIR" 2>/dev/null && pwd)
case "$CDIR" in
  */.git) SHARED_ROOT=$(dirname "$CDIR") ;;   # normal repo, or a linked worktree
  *)      SHARED_ROOT="$ROOT" ;;              # bare repo (dirname would escape it), or not git
esac

# No -maxdepth. It was 2, and docs/planning/BACKLOG.md is depth 3.
find "$ROOT" -iname "*.md" \
     -not -path "*/node_modules/*" -not -path "*/.git/*" \
  | grep -iE "backlog|status|roadmap|todo"
grep -rilE "backlog|epic|roadmap" "$ROOT"/CLAUDE.md "$ROOT"/README.md 2>/dev/null | head
```

- **One** → that's it. Read enough to learn its ID scheme, grouping and checkbox style.
- **Several** → read each and ask the user once which is the live backlog.
- **None** → **look in the main repository before you believe it**, and only then offer to
  create one, saying clearly that you're creating it:

```bash
[ "$SHARED_ROOT" != "$ROOT" ] && find "$SHARED_ROOT" -iname "*.md" \
  -not -path "*/node_modules/*" -not -path "*/.git/*" | grep -iE "backlog|status|roadmap|todo"
```

  **A hit here means DO NOT CREATE.** It means the backlog exists and your branch simply
  does not have it yet — merge or check out the branch that does, and edit your own copy.

**A missed file does not fail safe — it duplicates.** "Not found" falls straight through to
"create one", so a backlog one directory deeper than you looked becomes a SECOND backlog beside
the real one. **Duplication is the single outcome a backlog-finder must never produce**, and it is
the failure mode of this skill's central claim. The depth limit that caused it was `-maxdepth 2`;
if you are about to create a file, that is the moment to widen the search rather than trust the
first one. **Never create a backlog from inside a worktree without checking the shared checkout.**

**Match what's there.** If the project uses `- [ ] **A-22** …` inside lettered epics, use that. Do
not introduce a new numbering scheme alongside an existing one.

---

## Step 2 — filing an item worth having

The test: **could someone who wasn't there pick this up cold and act on it correctly?**

A good entry carries:

1. **What is wrong, specifically** — the observable symptom, with the exact error text if
   there is one. Not "the connect flow is broken".
2. **Evidence** — file and line, a captured request, a measurement. Say where it came from.
3. **How confident you are, honestly** — reproduced? read in the code? guessed from a
   symptom? *A finding filed as certain when it was a guess costs someone a day.*
4. **What NOT to do** — the tempting wrong fix, and why it's wrong. Often the most valuable
   line in the entry.
5. **Checked negatives** — things you already ruled out, so nobody re-tests them.
6. **Why it matters** — what breaks, for whom.
7. **What would settle an open question**, if it isn't settled.

**File it as a question when it is a question.** An item that says *"does X handle Y? — check
before claiming a defect"* is more useful than a confident claim that turns out wrong. Real
example: five such questions were filed in one batch, and **two turned out to be non-defects**
— filing them as questions is what stopped two pointless changes.

---

## Step 3 — closing an item

Record **what actually shipped**, not that it's done:

- what changed, and the shape of the fix
- how it was verified — the real numbers, if there was a test run
- **what was deliberately left out, and why** — scope decisions are the thing future readers
  most need and least often find
- anything discovered along the way that deserves its own item

**Marking it done: copy the file's own convention, and if it has none, use `[x]`.**
`close` is told to mark an item done and was never told how — so one station wrote
`- [x] **T6**`, another `- **T6** ✅ **DONE**`, and **done-ness spelled three ways is not
greppable**, which is the one property a closed item needs.

- The file already uses `- [ ]` → tick it: `- [x]`.
- The file uses its own marker (`~~struck~~`, a `Status` column, a `## Done` section) → use that.
- **The file has no convention at all** → use `- [x]` and nothing else. Do not invent a
  decoration, and do not add an emoji the file has never used.

Note the examples further down this page use `- [ ] **A1**` — that is a template for a file being
created from scratch, **not a format to impose on a file that already exists.** Step 1's "match
what's there" wins over it every time.

---

## Step 4 — re-scoping

When facts change, **correct the entry without erasing the old reading**. Mark it — a dated
`[CORRECTED]` note, or a struck-through line with the new one beside it.

Why this matters: an entry that silently changes cannot be audited, and the person who acted
on the old version has no way to see what moved. Keep the wrong version visible with the
reason it changed.

---

## Step 5 — blocked is not the same as not started

Say **why** something is blocked, in the entry:

- *needs live credentials nobody has*
- *needs a product decision*
- *needs a primary source read before anyone acts*

**Blocked work looks like lazy work if nobody says otherwise.** And an item blocked on a
decision will sit forever unless the decision is named as the next step.

---

## Step 6 — when one item must land before another, write it on BOTH

Ordering between items is the thing a backlog most often knows and least often records.
When item A must land before item B, **put the reference on both entries** — not on the one
you happen to be editing:

- on **B**: `blocked by: A — <what A has to produce first>`
- on **A**: `blocks: B — do not close without telling whoever holds B`

**One-sided cross-references are worse than none.** The person who needs it is almost never
the person who wrote it: whoever opens B needs to know it cannot start, and whoever closes A
needs to know somebody is waiting. Write it only on B and closing A goes unannounced; write
it only on A and B gets picked up by someone who cannot finish it.

**Name what A must produce, not just that it comes first.** *"blocked by A"* leaves the reader
to guess whether A is half-enough. *"blocked by A — needs the migration's final column names"*
tells them exactly what to watch for, and lets them start the rest of B now.

**If you cannot state the dependency in a sentence, it may not be one.** Two items touching the
same file is not an ordering. A real dependency has an artefact: a schema, a decision, an
interface, a name. If there is no artefact, the items are merely related — say *"see also"*
and leave both startable.

---

## Step 7 — committing it

**Stage the backlog file by name. Never `git add -A`.**

```bash
git add docs/BACKLOG.md          # the path you edited, and nothing else
git commit -m "backlog: file T7 — <one line>"
```

This page previously said nothing about staging at all — so it never reached for `-A`, and
equally **nothing in it forbade one.** Every `-A` protection in the run that found this came from
the surrounding fleet rules and the project's own `CLAUDE.md`, not from here. **Run this skill on
its own, outside any fleet, and there was nothing to stop it.** A backlog edit is almost always
made in a working tree holding unrelated work-in-progress, and `-A` sweeps that in behind a commit
message that says only *backlog*.

---

## If there's no backlog yet

Offer to create one. Keep it plain:

```markdown
# Project status and backlog

**Status:** how complete each part is. **Backlog:** what's left, grouped by area.

## Status
| Area | State | Notes |
|---|---|---|
| | | |

## Backlog

### Area A — <name>
- [ ] **A1** — <what, evidence, what not to do, why it matters>
```

Group by **area of the product**, so an item lands near the code it concerns and whoever owns
that area sees it.

---

*status-and-backlog by Chinmai Reddy (@chinmaireddy09), under the Fleet Command License 1.1.*
*https://github.com/chinmaireddy09/fleet-command*
