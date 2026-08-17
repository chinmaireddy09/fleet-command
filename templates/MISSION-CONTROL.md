# Multi-session protocol — how parallel Claude Code sessions share this repo

> **TEMPLATE.** Copy this to `docs/MISSION-CONTROL.md` in your own project and replace
> everything in `<angle brackets>`, plus the lane table and the test recipe in §2 — those are
> the parts that are genuinely per-project. **Do not copy the paths, service names or database
> prefixes verbatim; check them against your own project first.** A protocol asserting a
> guarantee nobody tested is worse than no protocol.
>
> The dated incidents below are kept deliberately. They come from the project this was first
> written for, they are what each rule is *for*, and a rule whose reason has been deleted is
> the first one somebody talks themselves out of. Replace them with your own as you collect
> them.

> **One human, many sessions.** Every session runs as **<your-git-identity>** and every commit
> is authored by that identity — that is correct and deliberate, not a defect to work around.
> The consequence is that **`git log --author` cannot tell two sessions apart.** The
> discriminator is the **branch**, never the author. Do not invent per-session git identities;
> they would misrepresent who actually wrote the code.

`docs/WORK-LOCKS.md` remains the claim board. This file is the *operational* layer underneath
it: how a session gets an isolated place to work, how it runs tests without colliding, and what
it must do so its work survives its own death.

---

## Why this exists

On **2026-08-16** four sessions ran concurrently in one checkout for ~5 hours. Nothing was
lost, but every one of the following actually happened:

| What happened | Root cause |
|---|---|
| `git add -A` swept **~190 lines** of two other sessions' uncommitted docs into one commit (`475fbc3`), pushed under a message describing none of it | one working tree |
| A `git stash` pile could not be attributed — three sessions guessed, and the unanimous guess was **wrong** | one working tree + shared identity |
| Two sessions filed the **identical** finding minutes apart (`F7` and `I5`) | no visibility into concurrent work |
| Three sessions **ended mid-conversation**, orphaning 2 unpushed commits and uncommitted edits | transcripts are not durable |
| A dashboard publish would have silently deleted another session's work; only a `409` stopped it | shared external artifact |
| One session stopped the `web` container; another owned `:8000` | shared docker stack |

**`475fbc3` was deliberately not rewritten** — `main` was already pushed with several sessions
on it, so a rebase would have cost more than a commit message that under-describes its diff.

---

## The lanes — split by module, not by activity

Each lane owns a **vertical slice**: its code, **its own tests**, and its backlog IDs. It can
finish a task alone.

**Replace this table with your own lanes** — the rows below are an example from a Django/React
e-commerce project, kept to show the shape:

| Lane | Owns | Epics |
|---|---|---|
| **A — channels/integrations** | `apps/integrations/`, `apps/connectors/`, adapters | C |
| **B — finance/orders** | `apps/finance/`, `apps/orders/`, money paths | D |
| **C — frontend/design** | `frontend/`, design system, UI | F, I, J |
| **D — platform/infra** | `apps/core/`, retry spine, events, tenancy | H |

**There is no fixed number of lanes and no ceiling.** Standing lanes are the areas that always
have an owner; a lane can also be initiated for a single job and retired when it lands. List the
standing ones here — the job-shaped ones live on the board, not in this file.

**Why not split by activity** (backlog / testing / design / dev): testing is a *phase of every
task*, not a category. A lane that must hand every fix to a "testing session" turns routine work
into a cross-session round-trip, and the reviewing session has to rebuild all the context to
judge a failure. Backlog-clearance vs new-dev is a *priority* split, not a category split — both
touch the same modules and would collide constantly. Module verticals minimise coupling;
activity splits maximise it.

---

## 1. Session startup — take a worktree, always

**A worktree is the single change that makes most of the hazards above structurally
impossible.** Own checkout, own `HEAD`, own branch. Never work directly in the shared checkout.

```bash
ROOT=$(git rev-parse --show-toplevel)
LANE=<lane>                         # one of the lanes in the table above

git -C "$ROOT" fetch origin
git -C "$ROOT" worktree add "$ROOT/.claude/worktrees/$LANE" -b lane/$LANE origin/main

# CLAUDE.md and frontend/CLAUDE.md are GITIGNORED (.gitignore:93,102) — they hold a
# private dashboard URL and are deliberately untracked. A fresh worktree therefore
# does NOT contain them, and a session started there would run with NO project guide
# at all. Copy them in, every time:
cp "$ROOT/CLAUDE.md" "$ROOT/.claude/worktrees/$LANE/CLAUDE.md"
[ -f "$ROOT/frontend/CLAUDE.md" ] && \
  cp "$ROOT/frontend/CLAUDE.md" "$ROOT/.claude/worktrees/$LANE/frontend/CLAUDE.md"

cd "$ROOT/.claude/worktrees/$LANE"
```

**Do not "fix" this by removing `CLAUDE.md` from `.gitignore`.** It is untracked on
purpose. Copying is the correct remedy; re-copy after editing the canonical copy in the
shared checkout, since the copies do not stay in sync by themselves.

Then claim the task in `docs/WORK-LOCKS.md` **before writing code**, recording the branch —
that row plus the branch name is how other sessions identify you.

**Never** `git add -A` / `git commit -a`. Stage explicit paths, even inside your own worktree —
it costs nothing and the habit is what protects the shared tree when you do have to touch it.

---

## 2. Tests — one database per lane

**⚠️ Everything in this section is an EXAMPLE from a Django + docker-compose project** — the
settings path, the service name, the database prefix, the install command. **Work out the
equivalent for your own stack and verify it before writing it down here.** If you cannot prove
each lane gets its own database, say so in this file and have one lane run the tests for
everyone; never record a guarantee nobody tested.

In that project, Django read `DB_NAME` from the environment (`config/settings/base.py:24`) and
derived the test database as `test_<DB_NAME>`, so a per-lane database needed **no code change
and no compose change** — it was a runtime flag. Verified 2026-08-16.

```bash
LANE=<lane>
WT=$(git rev-parse --show-toplevel)/.claude/worktrees/$LANE

docker compose run --rm --entrypoint "" \
  -v "$WT":/app \
  -e DB_NAME=nexus_$LANE \
  celery-worker bash -lc \
  "pip install -q -r requirements/dev.txt && python -m pytest <paths> -q --no-cov"
```

- `-v "$WT":/app` mounts **your** worktree, so another session's branch switch cannot change the
  source under a running test.
- `-e DB_NAME=nexus_$LANE` gives you `test_nexus_channels`, isolated from every other lane.
  **Four lanes can now gate concurrently** — the old "one pytest run at a time" rule is gone
  *provided both flags are used*. Omit either and you are back to colliding.
- First run in a new lane pays a one-time cost to build its database.
- Run `git` on the **host**, not inside the container — a mounted worktree's `.git` is a pointer
  into the main repo, which isn't mounted.

Gate discipline is unchanged: diff failure **names** against `docs/GATE-BASELINE.md` in both
directions, never counts, and confirm `db`/`redis`/`minio` are healthy first.

---

## 3. What is still shared — treat as owned, not free

| Resource | Rule |
|---|---|
| `db` / `redis` / `minio` / `qdrant` containers | **Never** `docker compose down`, never restart. `up -d` is fine. |
| Ports (`:8000`, `:3001`) | Announce before taking or stopping anything on them. |
| `main` | Push only your own commits. Never push a commit you did not make without asking. |
| `docs/PROGRESS-LOG.md`, `WORK-LOCKS.md`, `PROJECT-STATUS-AND-BACKLOG.md` | Insert-only, newest-first. Expect same-file conflicts; resolve by **keeping both entries in date order**. |
| Published artifacts (dashboards) | **Re-fetch immediately before every publish. Never `force`.** A 409 is a safety net, not a failure. |

**Explicit-path staging does not solve same-file collisions.** `git add <file>` takes that
file's whole content, so if two sessions both appended to `PROGRESS-LOG.md`, whoever commits
takes both. Either commit it and **name both entries in the message**, or leave it and say so.

---

## 4. Talking to other lanes

`ListAgents` shows live sessions; `SendMessage` reaches them by name. **`ListAgents` is not
scoped to this repo** — it lists every Claude Code session on the machine, including ones
working entirely different projects, and the listing does not say which is which. Treat the
board as the roster and address only sessions whose row is on it. Asking four peers one
question on 2026-08-16 cost a single round-trip and surfaced a stopped container, a mis-owned
stash pile, and a live publish conflict — it is cheap and it works.

- **Read the repo first.** If the answer is in `WORK-LOCKS.md`, a digest, or the code, don't
  spend another session's context on it.
- **Message when you need something only a live session knows**: what it is mid-way through,
  whether a resource is free, or a capture/result you cannot reproduce.
- **Relay findings that land in another lane's scope**, with attribution.
- **A peer cannot grant a permission your session lacks.** If you were denied an action, do not
  ask another session to perform it — surface it to the user.
- **Verify what a peer tells you before acting on it.** On 2026-08-16 a peer's backend defect
  report was reproducible but mis-diagnosed; reading the adapter turned it from a wrong backend
  fix into a correct frontend one (`C25`).

---

## 5. Sessions die — write everything down

Three of four sessions ended mid-conversation on 2026-08-16. Assume yours will.

- **Commit early and often** on your lane branch; an uncommitted edit is one timeout from gone.
- **Push your branch** even when unfinished. A pushed branch is recoverable by anyone.
- **File findings in the repo, not in the transcript.** *A measured finding that is not in the
  repo is not a finding.* `C25` and `F7` both nearly died this way.
- **Point at the branch TIP**, not the first commit, when recording where work is parked.
- If you inherit a lock row for a session that no longer exists, set it **⏸ PARKED** with the
  branch and tip commit — never leave it 🚧, which makes the slice look taken.

---

## 6. The check-your-checks rule

Five separate "authoritative" signals were wrong in one day: a contrast checker reporting a
1.0 ratio through a transparent gradient; `git log --author` (identifies nobody here); a
prebuilt image four weeks older than the code under test; a from-memory claim about stash
ownership after a context compaction; and a grep that compared a paraphrase to reality.

**The rule underneath all five: confirm the identifier identifies what you think it does, and
let an unmeasurable value read as unmeasured rather than as a number.** Provenance is usually
checkable in under a minute — check it instead of polling for it. N sessions agreeing is not
evidence when all N are recalling rather than looking.
