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
| **its own workspace** | a `git worktree` — a separate copy of the project files | *"it has its own copy of the files"* |
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
| **station** | one session, owning one area of the product |
| **sweep** | one change that has to be made in *every* area at once — a colour token, a renamed field, a library upgrade |
| **deploy a station** | put a session on post with its own workspace and call-sign. **⚠️ Not the software meaning** — shipping code to production is a different thing. Where both could be meant, say *"ship to production"* for one and *"deploy a station"* for the other, and never a bare "deploy" |
| **countermeasures** | what you do once a collision has already happened — announce it first, then repair *forward*, never by deleting |
| **the board** | the claim file. Who holds what, and what's next. Not a history |
| **radio check** | asking every live session for its call-sign, branch and paths, then writing the answers on the board |
| **hand over** | before a session closes: push everything, write down what only you know, report, wait for acknowledgement |

## Call phrases

| Phrase | Means |
|---|---|
| **"Control to Backend"** | I am calling that station |
| **"Go ahead"** | I'm listening |
| **"Standby"** | wait — stop committing in these paths |
| **"All clear"** | the hold is over, carry on |
| **"Clear to proceed"** | I checked, nothing conflicts, go |
| **"Roger"** | received and understood |
| **"Say again"** | repeat that |
| **"All stations"** | routine broadcast — read when you get a moment |
| **"All hands"** | urgent — stop what you are doing |
| **"Mayday"** | something is breaking right now, drop everything |
| **"Out"** | this exchange is finished |

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
| 🔒 **claimed** | reserved, not started yet | **No** — ask the owner first |
| 🚧 **in progress** | someone is actively working it now | **No** |
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
| **your own sessions**, same machine | `ListAgents` + `SendMessage` | instant |
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
