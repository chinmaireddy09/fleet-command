---
name: status-and-backlog
version: 1.0.0
description: Keeps a project's backlog and status document honest. Files a new item with enough detail that someone else could pick it up cold, closes one with what actually shipped, and re-scopes one when the facts change. Finds whatever backlog file the project already uses and matches its conventions rather than imposing a format. Runs only when explicitly invoked.
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
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
find "$ROOT" -maxdepth 2 -iname "*.md" | grep -iE "backlog|status|roadmap|todo" | grep -v node_modules
grep -rilE "backlog|epic|roadmap" "$ROOT"/CLAUDE.md "$ROOT"/README.md 2>/dev/null | head
```

- **One** → that's it. Read enough to learn its ID scheme, grouping and checkbox style.
- **Several** → read each and ask the user once which is the live backlog.
- **None** → offer to create one, and say clearly you're creating it.

**Match what's there.** If the project uses `- [ ] **C22** …` inside epics A–J, use that. Do
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
