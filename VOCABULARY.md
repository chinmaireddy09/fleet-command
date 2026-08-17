# Vocabulary — the legend

Every word Mission Control uses, what it actually is underneath, and the plain sentence to
say instead of jargon.

**The rule this list is built on: if a word needs a glossary, it is the wrong word.** An
earlier version of this skill invented nine aviation terms — `LOS`, `RANGE`, `TRAJECTORY`,
`DEBRIS` — and every one of them had to be explained. They were replaced with words people
already knew. Only the ones anyone recognises from any space film survived: **mission
control**, **go / no-go**, **abort**, **countdown**, **checklist**.

If you extend this skill, hold new words to the same test:

> Could someone who has never written a line of code understand this sentence?

---

## The three ideas

| Word | What it actually is | Say it like this |
|---|---|---|
| **a session** | one Claude Code window doing one job | *"the payments session"* |
| **its own workspace** | a `git worktree` — a second checkout **of this same repository**, with its own branch and its own `HEAD`, sharing one `.git`. Not a clone, and never a copy of some other repo | *"it has its own copy of the files"* |
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
| **station** | a post: one area of the product, with a call-sign, a workspace and a row on the board. **A station is not a session.** A session *mans* a station — the session dies when its window closes, the station outlives it. But not forever: a call-sign is cut when there is work for it and **retired when that work lands**, so the roster is whatever the jobs need. There is no fixed list and no ceiling |
| **identify** | a session taking a call-sign — and **binding itself to the post**: it reads the row, takes the workspace path from it, and moves in on its own. Replaced *join*, which described what the session did rather than what the fleet learned, and which left the human to do the moving |
| **a call-sign** | `CHANNELS`, `FRONTEND`, `CONTROL` — what a station is **called**. Say it in every report and every call |
| **a session name** | `ecom-nexus-oss-4d` — a machine-generated **address**, not a name. It belongs in a message's `to:` field and the board's lookup column, **nowhere else.** A report full of these has thrown away the one thing call-signs are for |
| **sitrep** | asking every live station where it actually is, what it holds and what is blocking it — then **fixing the board where the answers disagree with it.** A sitrep that ends without correcting a stale row was just a conversation |
| **radio silence** | a station saying *don't interrupt me* — mid-gate, mid-edit. Control holds non-urgent calls and answers from the board where it can. **Mayday always breaks through**; silence is about interruptions, never safety |
| **fleet state** | one line on the board saying what **everyone** is doing: *normal*, *sweep running*, *mayday*. **Named, never numbered** — a DEFCON-style scale gets read backwards by half the people who read it, and a state acted on confidently in the wrong direction is worse than no state at all |
| **sweep** | one change that has to be made in *every* area at once — a colour token, a renamed field, a library upgrade |
| **deploy a station** | cut the post **and man it**: create the workspace, open a session, have it identify, and verify it landed on the board. Nobody types a path. **⚠️ Not the software meaning** — shipping code to production is a different thing. Where both could be meant, say *"ship to production"* for one and *"deploy a station"* for the other, and never a bare "deploy" |
| **cut a post** | the first half of a deploy, on its own — workspace, branch and board row, with **nobody in it**. The row reads *reserved*, never *on post*, until a session identifies as it |
| **countermeasures** | what you do once a collision has already happened — announce it first, then repair *forward*, never by deleting |
| **the board** | the claim file. Who holds what, and what's next. Not a history |
| **radio check** | asking every live station for its call-sign, branch and paths, then writing the answers on the board. **Triggered by an event** — coming on watch, a bounced call, before a sweep or a deploy — never by a clock |
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

## Words replaced, and why

| Never say | Say instead |
|---|---|
| `LOS` / loss of signal | **we lost contact** |
| `DEBRIS` | **what it left behind** |
| `RANGE` | **shared equipment** |
| `TRAJECTORY` | **branch** |
| `PAD` | **workspace** |
| `FLIGHT MANIFEST` | **the board** |
| `COMMS LOOP` | **comms** |
| `FLIGHT` | **a session** |

---

## Status marks on the board

These appear in the Status column of `WORK-LOCKS.md`. Anything reading the board — person or
program — can rely on these meanings.

| Mark | Means | Safe to start this job? |
|---|---|---|
| 🔒 **claimed / reserved** | reserved, not started yet. **Also a post that has been cut but that no session has identified as** — the workspace exists, the chair is empty | **No** — ask the owner first |
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
- Is it still to be done? → **BACKLOG**
- Is it a step someone should follow? → **PROTOCOL** (or the skill)

Blur them and each fails a specific way: history in the board makes it too long to scan;
claims in the log make it impossible to see what's free; findings left only in a session
transcript disappear when that session ends.

---

## Two channels — never confuse them

| Reaching | How | Speed |
|---|---|---|
| **stations on this repo** | `ListAgents` + `SendMessage`, **cross-checked against the board** | instant |
| **another person**, their own machine | GitHub issue, assigned to them | minutes |

**Messaging between sessions cannot reach another person.** It only reaches your own Claude
Code windows. Never report that you "notified the team" when you messaged your own sessions.

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

*Fleet Command by Chinmai Reddy (@chinmaireddy09), under the*
*Fleet Command License 1.1. https://github.com/chinmaireddy09/fleet-command*
