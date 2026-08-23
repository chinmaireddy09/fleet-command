# Vocabulary — the legend

Every word Mission Control uses, what it actually is underneath, and the plain sentence to
say instead of jargon.

**The rule this list is built on: if a word needs a glossary, it is the wrong word.** An
earlier version of this skill invented nine aviation-sounding terms, and every one of them had
to be explained before it could be used. They were replaced with words people already knew.
Only the ones anyone recognises from any space film survived: **mission control**,
**go / no-go**, **abort**, **countdown**, **checklist**.

*The retired words are deliberately not listed here.* Naming them is how they get learned, and
a legend that teaches the vocabulary it threw out has undone its own point.

If you extend this skill, hold new words to the same test:

> Could someone who has never written a line of code understand this sentence?

---

## The three ideas

| Word | What it actually is | Say it like this |
|---|---|---|
| **a session** | one Claude Code window doing one job | *"the payments session"* |
| **its own workspace** | a `git worktree` — a second checkout **of this same repository**, with its own branch and its own `HEAD`, sharing one `.git`. Not a clone, and never a copy of some other repo | *"it works in its own folder, on the same project"* |
| **go / no-go** | the test run, plus comparing failures against the known list | *"tests are clean — go"* |

## The three things that happen

| Word | What it actually is | Say it like this |
|---|---|---|
| **we lost contact** | a session ended, possibly mid-job | *"the design session is gone"* |
| **what it left behind** | unsaved files, commits never pushed, parked changes, abandoned workspaces | *"it left two unsaved files"* |
| **shared equipment** | the database, ports, the main copy on GitHub, shared docs | *"the database everyone uses"* |

## The rest of the words

| Word | What it actually is |
|---|---|
| **station** | a post: one area of the product, with a call-sign, a workspace and a row on the board. **A station is not a session.** A session *mans* a station — the session dies when its window closes, the station outlives it. But not forever: a call-sign is initiated when there is work for it and **retired when that work lands**, so the roster is whatever the jobs need. There is no fixed list and no ceiling |
| **identify** | a session taking a call-sign — and **binding itself to the post**: it reads the row, takes the workspace path from it, and moves in on its own. Replaced *join*, which described what the session did rather than what the fleet learned, and which left the human to do the moving |
| **the fleet manifest** | what `ListAgents` returns — **every live Claude Code session on this machine**, not just this repo's. A list of contacts, not of stations: presence in it proves a window is open somewhere, never that a post is manned. The board is the roster; the manifest is the radar |
| **a call-sign** | `INTEGRATIONS`, `FRONTEND`, `CONTROL` — what a station is **called**. Say it in every report and every call |
| **a session name** | `acme-shop-4d` — a machine-generated **address**, not a name. It belongs in a message's `to:` field and the board's lookup column, **nowhere else.** A report full of these has thrown away the one thing call-signs are for |
| **sitrep** | asking every live station where it actually is, what it holds and what is blocking it — then **fixing the board where the answers disagree with it.** A sitrep that ends without correcting a stale row was just a conversation |
| **radio silence** | a station saying *don't interrupt me* — mid-gate, mid-edit. Control holds non-urgent calls and answers from the board where it can. **Mayday always breaks through**; silence is about interruptions, never safety |
| **fleet state** | one line on the board saying what **everyone** is doing: *normal*, *sweep running*, *mayday*. **Named, never numbered** — a DEFCON-style scale gets read backwards by half the people who read it, and a state acted on confidently in the wrong direction is worse than no state at all |
| **sweep** | one change that has to be made across areas **owned by more than one station** — a colour token, a renamed field, a library upgrade. **The test is ownership, not size.** A large mechanical change living entirely inside one station's own lane is *not* a sweep, however sweeping it feels — it is ordinary lane work, and announcing it as one freezes a fleet that has no stake in it |
| **deploy a station** | initiate the post **and man it**: create the workspace, open a session, have it identify, and verify it landed on the board. Nobody types a path. **⚠️ Not the software meaning** — shipping code to production is a different thing. Where both could be meant, say *"ship to production"* for one and *"deploy a station"* for the other, and never a bare "deploy" |
| **initiate** | **start something** — a station, a task, a sweep, a gate run. The plain word for beginning, and it replaced *cut*, which read equally as *create* and as *delete* — fatal in a skill where rows genuinely get deleted. *"Initiating the FRONTEND post"* cannot be misread; *"cutting the FRONTEND row"* could mean either |
| **initiate a post** | the first half of a deploy, on its own — workspace, branch and board row, with **nobody in it**. The row reads *reserved*, never *on post*, until a session identifies as it |
| **countermeasures** | what you do once a collision has already happened — announce it first, then repair *forward*, never by deleting |
| **the board** | the claim file. Who holds what, and what's next. Not a history |
| **alert** | reaching **a person**, not a session — `/mission-control alert`. It opens a GitHub issue **assigned to them**, and GitHub emails them, so they need neither the repo open nor a pull. Two uses: *"I'm holding this, don't start it"* and *"nobody owns this, can you take it or help"*. **The only thing in this skill that reaches a human being**; everything else talks to Claude Code windows. Always show the user the exact title and body and get a yes first — it mails a real person |
| **radio check** | **two different things, and only one costs anything.** A **liveness check** is the fleet manifest plus the board — it tells you who is active, idle or gone, asks nobody anything, and so is run **on a schedule**. A **broadcast radio check** asks every station to reply with its call-sign, branch and paths — it costs one reply per station and so is run **on an event**: coming on watch, a bounced call, before a sweep or a deploy. Never broadcast on a timer |
| **the automation boundary** | the one process that runs without being asked each time: **start the station's session in its workspace and have it identify**. Nothing else — not claiming, committing, pushing, merging, gating, standing down or deleting a row, and not going back to the terminal afterwards to arrange, focus, retitle or close anything. It is enforced, not merely stated: the spawn script starts nothing without `--deploy`. **Being certain the next step is wanted is not the same as being asked for it** |
| **hand over** | before a session closes: push everything, write down what only you know, report. **The acknowledgement is confirmation, not a gate** — once the work is pushed and the knowledge is in the repo you are done, whether or not anyone answered |

## Call phrases

| Phrase | Means |
|---|---|
| **"Control to Backend"** | I am calling that station |
| **"Backend, go ahead"** | I'm listening, send it |
| **"Backend to Control"** | replying to the caller |
| **"Standby"** | wait — stop committing in these paths |
| **"All clear"** | the hold is over, carry on |
| **"Clear to proceed"** | I checked, nothing conflicts, go |
| **"Roger"** | received and understood |
| **"Say again"** | repeat that |
| **"All stations"** | routine broadcast — read when you get a moment |
| **"All hands"** | urgent — stop what you are doing |
| **"Mayday"** | something is breaking right now, drop everything |
| **"Out"** | this exchange is finished |

**Twelve phrases, and the skill's own table in `skills/mission-control/SKILL.md` is the
canonical copy — if these two ever disagree, that one wins.**

**Two pairs that must stay distinct**, or both halves stop meaning anything:

- **all stations** (routine) vs **all hands** (stop now)
- **standby** (hold) vs **all clear** (release). *A sweep that says standby and never says all
  clear leaves every station frozen — always close the loop, even if the sweep failed.*

**Mayday is for real damage only** — main broken, data being lost, a sweep abandoned
half-finished. Use it once for something that isn't, and nobody moves the next time.

## Words that were replaced

**A table used to sit here listing the invented terms beside their plain replacements. Removing
it is the rule being applied to itself.**

Nobody outside this project ever used those words. To a new reader the table taught eight pieces
of vocabulary they would otherwise never have met — in a document whose first line is *if a word
needs a glossary, it is the wrong word.* Its only measurable effect was to put dead jargon back
into circulation, and it contradicted the paragraph at the top of this file that says the retired
words are deliberately not named.

**The replacements are simply the entries above.** *We lost contact*, *what it left behind*,
*shared equipment*, *a branch*, *a workspace*, *the board*, *a session* — not one of them needs a
translation column, which is the whole reason they won.

**The part that transfers, and the only part worth keeping:** when you catch yourself writing a
glossary row for a word you invented, **delete the word instead of documenting it.**

---

## Status marks on the board

These appear in the Status column of `WORK-LOCKS.md`. Anything reading the board — person or
program — can rely on these meanings.

| Mark | Means | Safe to start this job? |
|---|---|---|
| 🔒 **claimed / reserved** | reserved, not started yet. **Also a post that has been initiated but that no session has identified as** — the workspace exists, the chair is empty | **No** — ask the owner first |
| 🚧 **in progress** | someone is actively working it now. **A station row earns 🚧 only once its session name is in the table** — the name is the proof, not the intent | **No** |
| ⏸ **paused** | started, then stopped. Work is parked somewhere | **Ask first** — read the parked branch before restarting |
| ✅ **done** | finished and landed | Yes — row can be deleted |

**⚠️ A 🚧 row with no live session behind it is the board lying.** It makes a free job look
taken. When a session ends without closing its row, set it to **⏸ paused** and record the
branch **and its newest commit**, so the next person reads the work instead of starting over.

---

## The four documents, and which question each answers

Mission Control operates these. They look alike — all markdown in `docs/` — and they are not
interchangeable.

| File | Question it answers | Time | How it behaves |
|---|---|---|---|
| `WORK-LOCKS.md` | *Can I start this?* | **now** | edited constantly; rows flip and get deleted; stays **short** |
| `PROGRESS-LOG.md` | *What happened, and why?* | **past** | append-only; never edit an old entry; grows forever |
| `PROJECT-STATUS-AND-BACKLOG.md` | *What should I work on?* | **future** | items added, checked off, re-scoped |
| `MISSION-CONTROL.md` | *How does this project run sessions?* | — | rules; changes rarely |

**When you don't know where something goes:**

- Will it matter in a month? → **PROGRESS-LOG**
- Does someone need it before they start? → **WORK-LOCKS**
- Is it still to be done? → **PLATFORM**
- Is it a step someone should follow? → **PROTOCOL** (or the skill)

Blur them and each fails a specific way: history in the board makes it too long to scan;
claims in the log make it impossible to see what's free; findings left only in a session
transcript disappear when that session ends.

---

## Two channels — never confuse them

| Reaching | How | Speed |
|---|---|---|
| **stations on this repo** | `ListAgents` + `SendMessage`, **cross-checked against the board** | instant |
| **another person**, their own machine | `/mission-control alert` → a GitHub issue **assigned to them**, which GitHub emails | minutes |

**Messaging between sessions cannot reach another person.** `SendMessage` only reaches Claude
Code windows — and not even reliably *this repo's* windows, since the fleet manifest lists every
session on the machine, other projects included. Never report that you "notified the team" when
you messaged your own sessions.

**The mail does not come from git.** Git has no notification mechanism of any kind. It comes
from **GitHub**, which emails a person when an issue is assigned to them — so `alert` checks
`gh auth status` and whether issues are enabled *before* promising anything, and falls back to
the board with an honest *"they won't see this until they pull"* when they aren't.

### The two things `alert` is for

**Both are real, they read completely differently, and picking the wrong one wastes the one
channel you have to a human.**

| | **"I'm holding this"** | **"Can you take this?"** |
|---|---|---|
| It is | a **claim** — stop anyone duplicating your work | a **request** — hand a problem to someone who can own it |
| Title | `WIP: <job> — held by <you>` | `<ID> — <problem> (unowned, needs an owner)` |
| Body carries | branch, paths you hold, what's next | what it is, what you *checked* rather than assumed, how **not** to fix it, what you ruled out, why it matters, what you never tested |
| Assignment means | "this is mine for now" | **"nothing — you are assigned only so it reaches your inbox"** |

**The request shape has one line it cannot go out without**: that the assignment is not blame
and not an assignment of work, and they may unassign themselves freely. **An assigned issue
reads as being volunteered unless you say otherwise**, and someone who feels press-ganged by a
robot will not read the next one.

**The issue is the notification. The repo is the record.** Point at the backlog ID; do not let
the only copy of a finding live in a GitHub issue.

---

## Things that are true about git and worth stating plainly

- **There is no lock in git.** Nothing prevents two people editing the same file. The board is
  an agreement, not a mechanism.
- **One exception, and it is real: the push race.** If two people claim the same job by editing
  the same row and both push, **GitHub rejects the second push.** The loser must pull and see
  the other claim. That is the only part with teeth.
- **Saving a file saves all of it.** Naming one file in `git add` protects you from taking
  *other* files, but not from taking someone else's edits to the *same* file.
- **Uncommitted work exists in one place only.** A session ending takes it. Commit early.
- **Nothing committed is really lost**, even when it looks lost.

---

## The command verbs — the words you actually type

The table in `SKILL.md` says what each command *does*. These are here because they are the words
that turn up in a **transcript**, where nobody has the table open — and because three pairs of them
are genuinely confusable.

| Verb | What it means | Not to be confused with |
|---|---|---|
| **check in** | tell Control what you are **about to start**, before you start. The claim, not the report | *standdown*, which is the other end |
| **standdown** | a station **ending its own watch**: push, report, **wait to be acknowledged**, then exit. The acknowledgement is part of it — leaving before it is not a standdown. Done rows are **archived**, never deleted | *secure* — standdown is reflexive, you do it to yourself |
| **secure `<station>`** | what **Control does to** a station: save the work, free the workspace, take the row off the board, retire the call-sign | *standdown* — this one is issued, not chosen |
| **board clear** | re-render the board from the ref, showing only live stations. **Archives done rows and never deletes a live one** | wiping the board. *"Clear the board"* never means that here |
| **sitrep** | ask every live station where it is — **and correct the board where the answers disagree with it** | a status report. A sitrep that changes nothing was a conversation |
| **silence / speak** | go heads-down and come back. Control holds non-urgent calls meanwhile. **Mayday still reaches you** | being unreachable. Silence is about interruptions, never safety |
| **state** | set what the **whole fleet** is doing — *normal*, *sweep running*, *mayday* — so nobody has to infer it | a station's own status, which is its row |
| **depends `<what>`** | who else touches this, and what must land before I start | a build-system dependency |
| **recover** | sweep for work a **dead** station left behind | *countermeasures*, which is for a live mistake |
| **countermeasures** | something went wrong: **announce it, then repair without deleting** | recover. This one is about a mistake, not a death |
| **go / no-go** | run the tests and say plainly whether it is safe | permission to start. It is a statement about the tests |
| **alert `<who>`** | reach a **human** by email — GitHub sends it. Messaging cannot and never could | calling a station, which is a machine |
| **deploy `<station>`** | initiate the post **and man it** — open the session, identify it, verify it landed | ⚠️ **shipping to production.** Say *"ship to production"* for that, and never a bare *"deploy"* |

---

## Words about where things live, and how a check can lie

These are recent, and every one of them is here because getting it wrong cost something real.

| Word | What it actually is |
|---|---|
| **write root** | the checkout you are standing in — `git rev-parse --show-toplevel`. **Everything that is edited, staged, committed or pushed resolves through it.** Inside a worktree it is *that worktree*, and it must stay that way: a station edits inside its own worktree, on its own branch. Point this at the shared checkout and one session writes into another's working tree |
| **shared root** | the repository itself — the parent of `git rev-parse --git-common-dir`, and **the same path from the shared checkout and from every worktree.** For things that should be *remembered once* across a fleet: a saved mapping, a "does this already exist somewhere I cannot see?" check. **Never for writes** |
| **the two-roots rule** | `--git-common-dir` for what is **remembered** once; `--show-toplevel` for anything **written or committed**. One variable cannot be both, and inside a worktree the difference is not cosmetic. Collapsing them fixes *"the setting dies with the worktree"* and introduces *"the edit lands in someone else's checkout"* |
| **work at risk** | content that exists **here and nowhere else** — measured with `--not --remotes`, across *all* remotes, never `origin/main..HEAD`. That second form counts **reachability**, so it reports danger for work already safely upstream. Untracked scratch is *not* automatically at risk; a tracked modification is |
| **a prunable worktree** | one whose directory is gone but whose `HEAD` ref git still records. **The highest-risk place work can sit**, not the lowest: that ref may be the only thing pinning a commit, and `git worktree prune` — the obvious tidy-up — deletes it. Check for another branch or tag before calling anything a sole pin |
| **a false green** | a check whose every observable reports success while the thing it secured is gone. `git rebase --skip` is the type specimen: *"Successfully rebased"*, exit 0, clean tree, in-sync branch, correct-looking board — and your commit reachable from **zero** branches. **The tool itself reports the false pass**, so the board corroborates the wrong conclusion |
| **an inverted check** | one that returns the *opposite* of the truth, so acting on it does the harm you were checking for. `pgrep -x Terminal` calling a running Terminal absent; `grep -c` counting the comment that documents a removal as proof it never happened; a checksum published without naming its algorithm, verifying four correct files as four mismatches. **Read the context, never the count. Name the algorithm** |

---

*Fleet Command by Chinmai Reddy (@chinmaireddy09), under the*
*Fleet Command License 1.1. https://github.com/chinmaireddy09/fleet-command*
