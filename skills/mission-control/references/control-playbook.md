# Control playbook — the board, sitreps, recovery, standing a station down

Loaded by **Control only**, and only for the command in hand. Stations do not need this file.

## The board — `/mission-control`

`docs/WORK-LOCKS.md` is the board. **It is the one place that answers "who holds what, and
what's next."** Keep it short enough to read in ten seconds — it is not a history.

Gather:

```bash
ROOT=$(git rev-parse --show-toplevel); cd "$ROOT"
git fetch -q origin 2>/dev/null
echo "── workspaces ──";     git worktree list
echo "── branches ──";       git branch -vv | head -20
echo "── shared copy ──";    git log --oneline -1 origin/main
echo "   ours ahead:  $(git rev-list --count origin/main..HEAD 2>/dev/null)"
echo "   ours behind: $(git rev-list --count HEAD..origin/main 2>/dev/null)"
echo "── unsaved ──";        git status --short
echo "── parked ──";         git stash list
echo "── services ──";       docker compose ps --format '{{.Service}} {{.Status}}' 2>/dev/null
```

Then `ListAgents` for who is actually alive, and read the board.

Report it as a watch report, in sentences:

```
BOARD — 3 stations manned

  BACKEND       orders refund path        lane/backend    working
  FRONTEND      checkout screen           lane/frontend    working
  INTEGRATIONS  —                         —                   not manned

  ⚠ The board says Integrations holds the eBay audit, but that session is gone.
  ⚠ Two files unsaved, and they are not yours.
  NEXT: C25 is unowned and blocks the eBay work.
```

Always end by naming **the single most urgent thing** in one sentence.

---

## Assign a station — `/mission-control station <name>`

Never work in the shared copy of the files.

**1 · Look first.** Run the board. Stop and explain if the station is already manned, tests
are running, or someone else's unsaved files are sitting in the tree.

**2 · Radio check.** `ListAgents`; if anyone is live, ask every one of them for its
call-sign, branch and the paths it holds — then record the answers on the board so this
station can be reached by call-sign later. **Ask — never assume.** You can usually check a fact in under a minute; several people
agreeing from memory is not proof.

**3 · Give it its own workspace.**

```bash
ROOT=$(git rev-parse --show-toplevel)
STATION=<name>
git -C "$ROOT" fetch origin
git -C "$ROOT" worktree add "$ROOT/.claude/worktrees/$STATION" -b lane/$STATION origin/main
```

**4 · Copy in the instruction files.** A new workspace does **not** include files git was told
to ignore — and project guides often are (they hold private links). Without this the station
starts with no orders at all:

```bash
for f in CLAUDE.md AGENTS.md frontend/CLAUDE.md; do
  [ -f "$ROOT/$f" ] && git -C "$ROOT" check-ignore -q "$f" \
    && mkdir -p "$(dirname "$ROOT/.claude/worktrees/$STATION/$f")" \
    && cp "$ROOT/$f" "$ROOT/.claude/worktrees/$STATION/$f" && echo "copied $f"
done
```

Copy them. Do **not** un-ignore the file — it is ignored on purpose.

**5 · Post it on the board, and push immediately** — before any code. The row must carry:

- **station** and **who** — the call-sign
- **what it holds** — the job, and *the modules and paths it will touch*
- **what's next** — the trajectory: what it will touch after this
- **branch** and **workspace**
- **date**

The *modules and paths* and *what's next* columns are what make dependency checks possible.
A row that only says "working on orders" tells another station nothing.

**Push it before writing code.** This is the one part with teeth: if two stations claim the
same row and both push, **GitHub rejects the second push** and forces them to see each other.

**6 · Report back**: station, workspace, branch, and its test database name.

---

## Sitrep — `/mission-control sitrep`

**The board says what stations *claimed*. A sitrep says what is *true right now*.** Those drift
apart constantly, because a row is written once and the work moves every minute.

Ask every live station for five things, and collect the replies into **one** report:

1. **call-sign**, and its `ListAgents` name
2. **where it actually is** — its `pwd` and branch, not what the board says
3. **what it holds** — the paths it has open right now
4. **what is uncommitted or unpushed** — the part that dies with the window
5. **what is blocking it**, if anything

**Ask for the working directory explicitly, every time.** It is the one fact that catches a
session which came up in the wrong place, and it is the only one a station cannot get wrong.
A station that reports the repo root instead of its lane is not on post, whatever the board says.

Then **reconcile the replies against the board and fix the board** — a sitrep that ends without
correcting a stale row was just a conversation. Name the drift out loud:

```
SITREP — 3 stations, 2 corrections

  CHANNELS   ecom-nexus-oss-4d   lane/channels    apps/integrations/adapters   clean
  FRONTEND   ecom-nexus-oss-1e   worktree-design-foundation-shell             3 unpushed
  BACKLOG    —                   —                                            NOT MANNED

  ⚠ BACKLOG's row said working. Nobody is behind it. Flipped to reserved.
  ⚠ FRONTEND has 3 commits on one disk. Told it to push before anything else.
```

## Fleet state — `/mission-control state <normal | sweep running | mayday>`

One line at the top of the board saying what the **whole fleet** is doing, so no station has to
infer it from who is talking:

| State | Means | What stations do |
|---|---|---|
| **normal** | ordinary work | carry on |
| **sweep running** | a cross-area change is open | do not commit in the swept paths until all clear |
| **mayday** | main is broken, or work is being lost | **stop pushing.** Nothing lands until it is green |

**Named, not numbered.** A number has to be looked up, and half the people who look it up get
the direction backwards — which is worse than having no state at all, because they act
confidently on it. Three words nobody has to learn beat five levels everybody misreads.

**The state is on the board, not in someone's memory.** Set it when it changes and clear it the
moment it is over — a `mayday` nobody lifted freezes the whole fleet just as surely as a sweep
that never called all clear.

---

## Alert a person — `/mission-control alert`

For reaching **a human collaborator**, not a session.

**Messaging between sessions cannot reach another person.** It only reaches your own Claude
Code windows. Never say you "told the team" when you messaged your own stations.

Check what exists before promising it:

```bash
gh auth status
gh repo view --json hasIssuesEnabled,nameWithOwner
gh api repos/{owner}/{repo}/collaborators --jq '.[].login'
```

**The only channel that actively reaches someone** is an assigned issue — it sends a real
email, so they don't need to pull or even have the repo open:

```bash
gh issue create \
  --title "WIP: <the job> — held by <you>" \
  --body  "Working this now on branch <branch>. Please don't start it.
Touching: <modules/paths>. Next: <what you'll touch after>.
I'll close this when it lands." \
  --assignee <their-github-username>
```

Then also: **push the board row** (the durable record and the push race), and **push your
branch early** so the work survives even if your station dies.

**Before posting: show the user the exact title and body and get a yes.** It emails a real
person. Use their real username from the collaborator list — don't guess. If `gh` isn't
authenticated or issues are off, **say so** and fall back to the board, telling the user
honestly that the person won't see it until they pull.

**Be straight about the limit: there is no lock in git.** None of this stops someone editing
the same file. What it buys is that they *know*, early, through a channel they watch.

---

## Find lost work — `/mission-control recover`

When a station has gone quiet, look in this order and **report before touching anything**:

```bash
git status --short                          # unsaved files, possibly not yours
git log --oneline origin/main..HEAD         # commits never pushed
git stash list --date=iso                   # parked changes
git worktree list                           # abandoned workspaces
git branch -vv --no-merged origin/main      # branches still holding work
```

**Find out what something is before you touch it.** Run `git stash show -p` and read it. Don't
ask around and don't trust memory — a confident, unanimous answer about who owned some parked
changes has already turned out to be wrong, and thirty seconds of looking settled it.

Then:

- **Unsaved work you didn't write** → leave it, say it's there. Never `checkout --`, never a
  bare `git stash`.
- **Commits never pushed** → safe where they are. Don't push them; that's the user's call,
  especially if the author is gone.
- **An abandoned workspace with work in it** → record the branch **and its newest commit** on
  the board. Pointing at the *first* commit hands over only part of the work.
- **A row on the board with nobody behind it** → mark it **paused**, never leave it
  "working" — that makes a free job look taken. **Paused, not deleted:** deletion is only for
  rows whose handover provably completed, and a station that vanished did not hand over.
- **Anything measured but not written down** → write it into the repo now.

---

## Stand down — `/mission-control secure <station>`

```bash
git -C "$WT" add <name the files>            # never -A
git -C "$WT" commit -m "..."
git -C "$WT" push origin HEAD:lane/$STATION  # once pushed, anyone can pick it up
# record branch + newest commit in the log, then take the row off the board
git worktree remove "$WT"
```

Push **before** removing the workspace. Always.

**The row is deleted, not archived in place** — the board carries the live fleet only, and the
branch plus newest commit in the log is what the next station actually picks the work up from.
Delete only after the session behind it has closed or re-identified: a row removed from under a
running station makes it invisible to the whole fleet. Still running, work finished → **paused**.

---

## If the project has no standing orders yet

Offer to write `docs/MISSION-CONTROL.md`: the **standing** stations and what each owns — the
areas that always have a holder, not every call-sign that will ever run, since job-shaped
stations are cut and retired as work arrives and belong on the board rather than in a doc; the
workspace commands; the per-station test-database settings **checked against this project
first**; what stays shared; how stations call each other; and the standing orders above.

**Split stations by part of the product** — payments, storefront, admin — **not by activity**
(one station writing, another testing). Testing is part of every job, so splitting that way
makes every small task need two stations and a conversation. Confirm the split with the user
before writing it down.

**Check, don't assume, how this project names its test database.** For Django:

```bash
<test_service> bash -lc "python -c \"
import os, django; os.environ.setdefault('DJANGO_SETTINGS_MODULE','<settings>')
django.setup(); from django.conf import settings
print('database is called:', settings.DATABASES['default']['NAME'])\""
```

If you cannot prove each station gets its own database, **say so** and have one station run
the tests for everyone. Never write down a guarantee you have not tested.

---

*Mission Control by Chinmai Reddy (@chinmaireddy09), under the Fleet Command License 1.1.*