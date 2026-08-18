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
  NEXT: A-25 is unowned and blocks the connect work.
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

  INTEGRATIONS   acme-shop-4d   lane/integrations    apps/integrations/adapters   clean
  FRONTEND   acme-shop-1e   worktree-design-system             3 unpushed
  PLATFORM    —                   —                                            NOT MANNED

  ⚠ PLATFORM's row said working. Nobody is behind it. Flipped to reserved.
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
email, so they don't need to pull or even have the repo open. **Assignment is being used as a
delivery mechanism**, which is the whole trick and also the thing to be honest about in the
body.

**There are two reasons to alert a person, and they are not the same message.**

**1 · "I am holding this — don't start it."** A claim, aimed at preventing duplicate work:

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

**2 · "Nobody owns this — can you take it, or help?"** A *request*, and the one that actually
gets used. It is a harder message to write well, because you are spending someone else's
attention and asking them to act. **Open by defusing the assignment**, then give them enough to
decide without reading your transcript:

```bash
gh issue create \
  --title "<ID> — <the problem in one line> (unowned, needs an owner)" \
  --body  "..." \
  --assignee <their-github-username>
```

What the body has to carry, in this order — modelled on one that worked:

| Section | Why it earns its place |
|---|---|
| **"Not blame, and not a claim"** | Say plainly that nobody is working it, that you assigned it **only so it reaches their inbox**, and that they may unassign themselves freely. Without this, an assignment reads as being volunteered |
| **What it is** | The symptom, with the literal error text or the exact failing behaviour |
| **What you checked, not assumed** | Cite `file:line`. *"The backend is innocent — this was checked"* is worth more than any amount of confident prose, and it stops them redoing your work |
| **⚠️ How NOT to fix it** | If there is an obvious wrong fix, name it and say why it is worse than the bug. This is often the single most valuable paragraph |
| **The findings that survive** | Numbered, so they can be split or handed on |
| **Checked negative** | What you ruled out, so nobody re-tests it |
| **Why it matters** | The consequence in product terms — what is unreachable, unsafe or lost while this stands |
| **Caveat** | What you did *not* test, and on what stack. An honest scope beats an overclaim that collapses on their first attempt |
| **Where the record lives** | The backlog ID and related IDs. The issue is the notification; **the repo is the record** |
| **Provenance footer** | *"Filed from a Claude Code session on `<date>`. Findings from live QA; backend diagnosis read from the adapter."* So they know how much to trust each claim |

**Verified 2026-08-16:** exactly this shape went out as an assigned issue, reached a real inbox,
and was the mechanism that moved an unowned frontend dead end to someone who could take it.

**Before posting: show the user the exact title and body and get a yes.** It emails a real
person. Use their real username from the collaborator list — don't guess. If `gh` isn't
authenticated or issues are off, **say so** and fall back to the board, telling the user
honestly that the person won't see it until they pull.

**Be straight about the limit: there is no lock in git.** None of this stops someone editing
the same file. What it buys is that they *know*, early, through a channel they watch.

**A person has no expiry, and this skill will not pretend otherwise.** Every other hold here is
bounded by an estimate its holder declared; a human collaborator never agreed to one, may be
asleep, and is not yours to time out. So do not write a deadline into the issue and do not treat
silence as consent. **Treat it as a block instead** — record what you asked and who owes it, work
what does not depend on the answer, and when it starts costing real time, that is a decision for
the user, not a rule for you to apply.

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
git -C "$WT" commit -F <message-file>      # -F, not -m: backticks in -m are eaten by the shell
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
stations are initiated and retired as work arrives and belong on the board rather than in a doc; the
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

## An approval ages, and the queue behind it keeps moving

**Control's inbox never stops.** Between asking for a go and hearing one, stations report,
things land, and the board changes — so **the queue at go-time is never the queue at ask-time.**
That is the default case, not the unlucky one, and a blanket *"go"* executed against a
remembered list is how a human authorises work they never saw.

Measured 2026-08-18. Control asked for a go on three items at 3:49. By 4:13 the queue held four:
one of the original three had become redundant (a station had already written the change), two
of them still stood, and **two items that had never been mentioned had joined the list.** A go
given against the 3:49 message would have run two items it named and two it did not.

**1 · Number the items when you ask.** A go can only be given to a list. *"Say go and I'll fix
the board"* is not something anyone can approve, because nobody can tell afterwards what it
covered.

**2 · Re-read the queue when the go arrives, before anything runs.** Not your memory of it —
the board, the branch tips, the traffic since. Each item gets one question: **does this still
need doing?**

**3 · State the delta out loud, then run.** One short block, before the first command:

```
CONTROL — Go received on the 3:49 queue. Since then:
          · item 1 redundant — FRONTEND landed it at 9f2c1ab, dropping it
          · items 2 and 3 stand, running them now
          · two new items appeared (directory table, my own row) — NOT in your go,
            asking separately below
```

**4 · New items never ride an old yes.** This is the part with teeth. Anything discovered after
the ask needs its own approval, however obviously it belongs with the rest and however much
cheaper one commit would be. **The cost of asking twice is a sentence; the cost of a widened
yes is that approval stops meaning anything.**

**5 · A redundant item is dropped, never repurposed.** Do not slide a new task into an approved
slot because the slot is free. The slot was for the thing that is no longer needed.

**6 · An approval does not transfer to whoever holds the post next.** *"Approved conditional on
green"* was given to a named station; when that session died and a new one re-manned the same
post, the new station found the approval on the board and **declined to inherit it** — correctly.
The person said yes to a station that had shown them its evidence, and the evidence itself could
not be refreshed because the gate infrastructure was down. **A post is inherited; an approval is
not.** Re-ask, and say what changed: who asked originally, why they are gone, and whether the
evidence still stands.

**7 · An approval expires like every other wait here.** Say how long the queue is good for when
you ask — *"this is the queue as of now; if it sits more than a few minutes I'll re-state it"* —
and when it lapses, re-state rather than assume. **A yes does not get more accurate with age.**

### The whole thing, worked — 2026-08-18

**Asked at 3:49**, numbered, which is the part Control got right:

```
1. FRONTEND's row -> paused, branch and tip recorded
2. Archive the 109 done rows so the board opens in Read again
3. File the approval-crossing-tabs gap into MISSION-CONTROL.md §4

All three are one commit on origin/main. Say go.
```

**The failure mode, for contrast.** The go arrives an hour later and Control answers:

```
CONTROL — Go received. Running all four now.
```

Four. Three were approved. Nothing false was typed and nobody would ever catch it — which is
the entire problem. Two items the user never saw ride in on a yes given for something else, and
the commit message will describe all four as approved work.

**What this rule requires instead**, before the first command runs:

```
CONTROL — Go received on the 3:49 queue. Re-read it before running. Three changes:

  1  pause FRONTEND's row      DROPPED — redundant. FRONTEND wrote the flip
                               itself at 9f2c1ab. Not re-doing it as a second
                               commit; it needs your yes on its push instead,
                               in its own tab.
  2  archive the 109 done rows STANDS — and worse than when I asked: the board
                               is 320 KB now and three stations have hit the
                               Read ceiling.
  3  file the approval gap     STANDS.

  Running 2 and 3 now — one commit parented on origin/main, nobody else's rows
  touched.

  NOT COVERED BY YOUR GO, asking separately:
  4  the directory table disagrees with ListAgents on all four addresses
  5  my own row names a dead session, so I am uncallable by anyone reading
     the board

  Both are one-line edits in the same file and it would be cheaper to fold them
  into the commit above. I am not doing that. Say go on 4 and 5 and they ride
  the next one. Out.
```

**The last paragraph is the load-bearing one.** Folding 4 and 5 in is *obviously* right — same
file, same commit, same intent, saves a round trip — and that is exactly why the refusal has to
be absolute. **Every widened yes is locally reasonable.** The damage is cumulative, and it is
that after enough of them a go no longer means the human saw the list.

Note what dropping item 1 also prevents: Control writing a second commit over work another
station had already done. That is the *unclaimed is not unowned* collision arriving by a
different road — which is a fair sign these two rules are pointing at the same thing.

**The same rule binds a station** that sends something up and keeps working: what you get back
answers the message you sent, not the state you are in when it arrives.

## Rigour is not the deliverable — check the output against the ask

**A fleet optimises for what it can verify, and what it can verify is not always what was
wanted.** Measured 2026-08-18: asked for a surface where a designer could *work*, three stations
produced **audit documents** — reproducible counts, refuted mechanisms, corrected arithmetic, all
of it correct. The user's verdict was the useful one: *"the output didn't meet the
expectations."* Control's reply named it exactly — **"a census is an input to a design tool, not
a substitute for one."**

**This is a coordination failure, not a work failure, which is why it belongs here.** Every rule
in this skill points inward: verify the claim, prove the run, diff the names, hold the paths.
None of them ask *is this still the thing they asked for?* — so a fleet can be rigorous,
well-coordinated, honest about its evidence, and building the wrong artifact all afternoon.

**Control owns this one.** It is the station with the whole picture and the only one positioned
to notice drift, and on the day it *steered* the drift — *"I steered FRONTEND toward the worklist
framing, so that's on me as much as it."*

**So, at every check-in and before anything is called done:**

- **Read the ask again, in the user's words, not your summary of it.** Summaries drift toward
  what turned out to be measurable.
- **Name the deliverable in one line** — *"a page they can design on"*, not *"an analysis of the
  design system"* — and say whether what exists matches it.
- **When rigour and the ask diverge, say so out loud and ask.** Producing the verifiable thing
  because it is verifiable is the failure; announcing the divergence is the fix.
- **A correction from the user is data, not a rebuke.** *"That's a miss, not a
  misunderstanding on your end"* is the right register to answer it in.

---

### The board has a size limit, and it is enforced by the tools, not by taste

**Measured 2026-08-18: a live board reached 313 KB and 109 done rows, and `Read` refused it** —
*"File content (282.5KB) exceeds maximum allowed size (256KB)."* **The skill's own first
instruction — read the board — failed outright.** Nothing had enforced "short", nothing defined
it, and nothing said what to do about a board that is already too big.

**The ceiling: ~150 rows or ~100 KB, whichever comes first, and no board should exceed what
`Read` accepts.** Past that it is not a board, it is an archive that also blocks people.

**Done rows move to `docs/WORK-LOCKS-ARCHIVE.md` at standdown — not at some later tidy-up**,
because "later" is what produced 109 of them. Closing a row *is* moving it.

**A row is capped too, and this matters more than the file size.** One row measured ~6,000 words
inside a single table cell — a re-land sequence, two gate results, migration notes and four
historical corrections. All true, much of it valuable, and **a row that takes ten minutes to read
is not a row.**

> **A row is: who · what · where · status · a pointer.** The reasoning goes in
> `PROGRESS-LOG.md`, which exists to answer *what happened and why*. This skill caps radio
> traffic to five lines and then let rows run to six thousand words — **same instinct, apply it
> in both places.**

**Recovering a board that is already oversized — `Read` will not open it:**

```bash
git show origin/main:docs/WORK-LOCKS.md > <scratchpad>/board.md   # then awk the active section
awk '/^## Active/,/^## Done/' <scratchpad>/board.md
```

**Say that you did this**, and file trimming the board as real work — it is the one file every
station pays for on every read.

### A rebase conflict on the board: abort and re-apply, never hand-resolve

**Re-applying your edit onto fresh `origin/main` is both cleaner and more informative than
resolving the conflict.** A station hit this with three sessions writing a 38 KB board at once:
its commit conflicted because a peer had landed two commits underneath it. It aborted, re-read,
and re-applied — and **the exact-string assert passing on the second attempt was positive
evidence the peer had not touched its rows.** A hand-resolved conflict produces a file that
looks right and tells you nothing about who changed what.

**And keep a claims-table row on ONE line.** A row here can run 1700 characters; an edit that
re-wraps it splits one row across ten lines and breaks the table for every reader. Prose above
the table wraps freely — **rows do not.** Assert every row still closes with a pipe before
pushing.

### Three stations write this file at once, and it works by convention

**Nothing in git prevents two stations mangling one board; what prevented it was manners, and
manners that were never written down do not survive a new station.** Measured 2026-08-18: three
stations pushed rows to one file inside twenty minutes with zero collisions. What made that work:

- **Edit your own row. Never reformat, retrim or "tidy" another station's** — even when it is
  6,000 words and you are right about it. Say it on the radio instead.
- **Push immediately**, before code. The push race is the one mechanism with teeth.
- **On rejection, start again from the new `origin/main`** and reapply your row — do not merge the
  board by hand. One station kept a peer's line and rebased its own underneath it rather than
  overwriting; that is the behaviour to copy.
| `PROGRESS-LOG.md` | what happened, and why | past | append-only; never edit an old entry |
| `PROJECT-STATUS-AND-BACKLOG.md` | what to work on next | future | items added, checked off, re-scoped |
| `MISSION-CONTROL.md` | this project's own rules for running sessions | — | changes rarely |

### Who writes the progress log — every station writes its own

**A logging skill runs in one session and can only write what that session knows.** Run it in
Control and you get **Control's** log: the board, the radio traffic, and Control's own actions.
You do **not** get what a station ruled out, the measurement it has not filed yet, or why it
chose one approach over another — none of that has ever left its window.

**The failure is that a Control-written fleet log reads like the whole story.** It is a summary
of the radio, and the radio is deliberately sparse — brevity is a rule here. A reader a week
later cannot tell the difference between *"the fleet did these six things"* and *"these are the
six things that happened to get mentioned"*, and they will trust it because it is written down.
Same family as a filed-but-resolved item: a blank space costs nothing, a confident partial record
costs somebody a day.

**So the split is:**

- **Each station logs its own, at standdown, before the window closes.** It is the only thing
  that knows its own dead ends. This is the same step as *"write down anything only you know"* —
  the log is where it goes.
- **Control logs the watch**, and says so in the entry: what the fleet held, what crossed
  stations, what is parked and where, what is still open. **Not a summary of the stations' work
  — a record of the coordination**, which is the part only Control saw.
- **When a station ends without logging**, Control records *that*, names the branch and newest
  commit, and marks the entry as second-hand. **An entry that says "reported over the radio, not
  written by the station" is honest; the same entry without that clause is a quiet lie.**

**A good test of whether this is working is the restart question**: if a station were restarted
right now, would its log already hold what it knows? If not, that is what standdown is for.

At the end of a watch, progress goes into **`PROGRESS-LOG.md`** — use the project's own
progress-logging skill if it has one, rather than inventing a format.

---

*Mission Control by Chinmai Reddy (@chinmaireddy09), under the Fleet Command License 1.1.*