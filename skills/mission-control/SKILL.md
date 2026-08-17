---
name: mission-control
version: 5.0.0
description: Fleet Command for several Claude Code sessions working the same repo. Gives each session a call-sign and its own workspace, keeps a live board of who holds what and what's next, detects when one station's work depends on another's, calls between them to pass the information needed, and coordinates changes that cross every area at once. Alerts human collaborators by email when a job affects them. Runs only when explicitly invoked.
author: Chinmai Reddy (@chinmaireddy09)
source: https://github.com/chinmaireddy09/fleet-command
license: LicenseRef-FleetCommand-1.1
attribution: "Mission Control by Chinmai Reddy (@chinmaireddy09), Fleet Command License 1.1"
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - AskUserQuestion
  - ListAgents
  - SendMessage
  - EnterWorktree
---

```
   ┌────────────────────────────────────────────────────────┐
   │   M I S S I O N   C O N T R O L                        │
   │   many sessions · one repo · one place that knows      │
   └────────────────────────────────────────────────────────┘
```

You are **Control**. Several Claude Code sessions work the same repository at the same
time. Each one is a **station**. Your job is not to write their code — it is to know who holds
what, spot when one station's work depends on another's, and **call between them so nobody
guesses, waits, or duplicates.**

**Speak plainly.** Use the call-signs below — you already know every one of them.
Beyond those, use ordinary words. Say *"we lost contact with Frontend"*, never
*"the frontend session went LOS"*. If a term needs explaining, it is the wrong term.

**Only run when asked** — `/mission-control` or `/mc`. Never on the bare words "control",
"status", "go", or "abort" in ordinary conversation.

**Never destroy another station's work.** No `docker compose down`. No `git stash pop`/`drop`
on a stash you did not create *and verify*. No `git add -A`. No `git checkout --`. No
force-push. Never push a commit you did not write.

---

## The stations

Each session is assigned one station.

**A call-sign works when hearing it tells you instantly whether it concerns you.** So name
stations after **the part of the product they own** — never after ship departments. "Supply"
and "CIC" mean nothing to anyone; `PAYMENTS` and `CHECKOUT` mean everything.

Sensible defaults, if a project hasn't named its own:

| Call-sign | Owns |
|---|---|
| **CONTROL** / **FLEET COMMAND** | coordination itself — holds the board, writes no feature code. Two names for one station |
| **BACKEND** | server, data, business logic |
| **FRONTEND** | UI — everything a user sees |
| **INTEGRATIONS** | outside connections: third-party APIs, adapters |
| **SWEEP** | not an area — whoever is running a change that crosses all of them |

**`SWEEP` needs no number, because only one sweep runs at a time.** Whoever drives it takes
that call-sign for the duration, whatever station they normally hold — what every listener
needs to know is *"this crosses everything and it is temporary"*, not who is at the keyboard.
The board records who is actually running it.

**Better: use this project's real area names.** In an e-commerce platform that might be
`CHANNELS`, `FINANCE`, `FRONTEND`, `PLATFORM`. Then *"Control to Finance"* is understood by
anyone who has seen the codebase, with nothing to learn.

Read the project's own `MISSION-CONTROL.md` first (Step 0) — its station names win. Small
projects often run only **CONTROL**, **BACKEND** and **FRONTEND**.

---

## The life of a station, start to finish

Six steps. Follow them in order — most collisions happen because a step was skipped.

### 1 · Control comes on watch

The first session runs `/mission-control`. It holds the board and answers calls. **Control
and Fleet Command are the same station** — use whichever you prefer on the radio.

### 2 · A new session opens on the same repo

Started by you in a new window, or by the CLI. At this point it has **no call-sign** and is
invisible to everyone else.

### 3 · It identifies itself — `/mission-control identify <call-sign>`

The first thing a new session does. It shows what is already taken, suggests what is free,
and **lets you type your own**:

```
MISSION CONTROL — identify

  Repo    ecom-nexus-oss                 Board   docs/WORK-LOCKS.md
  Live    BACKEND · BACKEND [e29977]             apps/orders
          FRONTEND · ecom-nexus-oss-85 [6d86b0]  frontend/src/checkout  ← unnamed, came up by hand

  Reserved for you — a post is already cut and waiting:
    1  CHANNELS       apps/integrations, adapters   .claude/worktrees/channels
    2  BACKLOG        cross-module                  .claude/worktrees/backlog

  Free, no post cut yet:
    3  PLATFORM       core, retry, events
    4  TIGER          no area yet — decide later

  Identify as:  ________
```

#### The session binds itself. Never the human.

**This is the step that used to fail silently.** The old flow told the user to `cd` into a
worktree and start a session there. When they didn't — and they often didn't, because opening
a terminal where you already are is the natural thing to do — the session came up in the shared
checkout, the board still said 🚧 on post, and **the row was lying from the moment it was
written.** Three sessions once came up in the shared checkout against three empty posts, and it
took two stations interrogating each other to notice.

The binding is a tool call, so make it one:

1. **Read the board**, find the row for the call-sign given.
2. **Take the workspace path from that row** — the board already carries it. Do not ask the
   user for a path; if the row has none, that is the bug, fix the row.
3. **Move in, if you are not already there.** Compare your working directory to the row's
   workspace:
   - **already there** → skip the move entirely and go to step 4. This is the normal case when
     `deploy` spawned you, because it starts you inside the lane.
   - **somewhere else** → **`EnterWorktree({path: "<workspace from the row>"})`**. The session
     moves *itself*. No `cd`, no restart, no second window.

   **Make this check, don't assume either way.** A session reached by `deploy` and a session
   started by hand both run `identify`, and calling `EnterWorktree` from inside the target is a
   different situation from calling it from outside.
4. **Write your `ListAgents` address onto the row** and flip it from reserved to on post, then
   push. Until that address is on the board, no other station can call you — which is exactly
   why a board full of 🚧 rows can still leave everyone unable to find anyone.

   **If `deploy` spawned you, you already know it: it is your call-sign**, because you were
   started `--name <CALLSIGN>`. Write it and move on.

   **If you came up by hand and unnamed, you cannot look it up** — `ListAgents` never shows you
   yourself. **Ask a peer or Control** — *"what address does this message arrive from?"* — and
   write back what they read out. **Never invent it, and never write the row with the name
   pending.** Both produce a row that fails at its one job.

5. **The row's commit must sit directly on current `origin/main`, and must be pushed to `main`.**
   Two separate requirements, and the old flow got the second one wrong: a row pushed to a lane
   ref updates a board nobody reads. The first matters because `HEAD:main` pushes *the whole
   ancestry underneath the commit* — which is how feature code has reached `main` by accident
   here. One commit, one file, parent = `origin/main`, pushed `HEAD:main`.

   **Use a throwaway worktree. It is the route that works from anywhere:**

   ```bash
   git worktree add <scratchpad>/board-flip --detach origin/main   # NO -C
   # edit docs/WORK-LOCKS.md, commit, then:
   git push origin HEAD:main
   git worktree remove <scratchpad>/board-flip
   ```

   **Run it from inside your own worktree.** `git worktree add` works fine from an isolated
   session — measured, twice, by two different stations.

   **What the isolation guard actually refuses is any command it cannot STATICALLY VERIFY stays
   inside the worktree — it is about command *shape*, not about git.** Read the error literally:
   *"too complex to verify that it stays inside the worktree; break it into plain, separate
   commands."* The counter-example that settles it: **`ps -o ppid= -p $$` was refused, and it
   contains no git at all.**

   | Trips the guard | Passes |
   |---|---|
   | `$$`, loops, heredocs, variable-built paths | plain commands with literal arguments |
   | `-C` pointed outside your worktree | `&&` chains, pipes, `$(...)` |

   **This took three wrong explanations in one hour to pin down** — "isolation blocks worktree
   creation", then "the `-C` redirect is what's blocked", each killed by the next data point,
   because each of us varied the factor we happened to notice while command *shape* moved
   uncontrolled alongside it. **A rule that gives the right answer for the wrong reason fails the
   next time you apply it to a different command**, which is exactly what happened here twice.
   When a guard refuses you, change one factor at a time.

   **Do NOT reach for "just fast-forward the lane and push `HEAD:main`" as the fallback.** It
   looks tidier and it is the more dangerous option, for two independent reasons:

   - **`HEAD:main` from a lane pushes every commit underneath it.** One lane on 2026-08-17 held
     **four commits written by sessions that had since died** — pushing the row from it would
     have put other sessions' work on `main` under a docs commit message. That is standing
     order 6 ("only push commits you wrote") broken silently, and it is the same mechanism that
     leaked C24 to `main` in the first place.
   - **If `origin/main` holds a revert of anything your lane carries, the fast-forward deletes
     it with no conflict raised.** Live in one lane in this repo right now.

   If you somehow must use it, **measure both preconditions first, never assume them**:
   `git merge-base --is-ancestor <lane> origin/main` is TRUE, **and** the lane has zero commits
   of its own. The throwaway worktree needs neither check, which is the whole reason it exists.

6. **Pin your call-sign to the terminal tab, so the human can always see which window is which.**
   This is not cosmetic. **The most expensive mistake a human makes with a fleet is typing the
   right prompt into the wrong window** — and every tab in a repo looks identical, because they
   all show the same directory and the same rotating status text.

   **Find your own tab by its tty. Never by `front window`** — that is whichever window has
   focus, which for any station but the one the human is looking at is *somebody else's tab*, and
   mislabelling another station's window is worse than not labelling your own.

   The Bash tool has no tty of its own (`tty` returns *not a tty*), but the `claude` process
   above it does — walk up the parents until one has a real tty.

   **The script ships with this skill — do not paste it inline.** A worktree-isolated session
   refuses a pasted multi-line block (`$$`, loops and heredocs all trip the static-verification
   guard; see the shape rule above). Running a file is one plain command:

   ```bash
   bash <skill-dir>/label-tab.sh CHANNELS
   ```

   It finds its own tab by tty, aborts loudly if the tty walk yields nothing, and reads the title
   back so a silent no-op cannot pass as success. Prints `<tty> -> CHANNELS`, or `NO-MATCH`.

   **Verified 2026-08-17**, both halves. The tty walk resolved `/dev/ttys000` through
   `zsh → claude → login`, and the tab matched on it regardless of which window was frontmost.
   Terminal.app's `custom title` **overrides** the title Claude Code writes and survives its
   constant status updates: the window went from
   `ecom-nexus-oss — ✳ Initiate mission control — caffeinate • claude` to
   `ecom-nexus-oss — CONTROL — node ◂ claude` and stayed there. The tab bar shows just the
   call-sign.

   **This works on a session that is ALREADY RUNNING**, which matters because `--name` is
   launch-only. A station that came up by hand can pin its tab immediately without restarting
   and without losing any state.

   | Terminal | How |
   |---|---|
   | **macOS Terminal.app** | the `osascript` above — verified, overrides Claude Code |
   | **iTerm2** | `tell current session of current window to set name to "<CALLSIGN>"` — untested |
   | **Anything else** | `printf '\033]0;%s\007' "<CALLSIGN>"` — works widely, but Claude Code may overwrite it on its next status update |

   Do this at identify and **do it again if you ever change call-sign.** A tab pinned to the
   wrong call-sign is worse than an unpinned one.

**A call-sign with no address on its row is reserved, not manned.** Say so in that state
and never render it as working — a row that claims a holder it does not have makes free work
look taken, which is the one failure this whole board exists to prevent.

**A row whose address is not a real `ListAgents` name fails the same way, more quietly.** A cell
reading `channels-1b` looks filled in and is uncallable; the row renders as manned while nothing
can reach it. Record what `ListAgents` prints, exactly.

**How to choose:**

- **Prefer an area name** — `INTEGRATIONS`, `CHECKOUT`, `PAYMENTS`. Hearing it tells everyone
  what you own, which is the entire point.
- **Use a team name when the area isn't decided yet** — `ALPHA`, `BRAVO`, `CHARLIE`, `DELTA`,
  `TIGER`, `FALCON`. Fine as a placeholder; rename once the work is clear.
- **Two sessions in one area?** Add a letter: `FRONTEND-ALPHA`, `FRONTEND-BRAVO`. This is what
  letters are actually for.
- **Never take a call-sign already on the board.** Check first.
- **Anything the user types wins** — suggestions are suggestions.

**If you came up unnamed, say so once and offer the fix.** A running session cannot rename
itself — `--name` is set at launch. So a hand-started station keeps its generated handle for
life, and every peer must address it by that instead of its call-sign. That works; it is just
worse. Tell the user plainly: *"I'm on post as CHANNELS but my address is
`ecom-nexus-oss-4d` — restart me with `claude --name CHANNELS` if you want the tab and the
radio to agree."* Their call, and never worth losing session state over mid-task.

### 4 · The call-sign goes on the board

Immediately, and **pushed before any code**. The row carries call-sign, session name from
`ListAgents`, branch, workspace, the paths it holds, and what it plans to touch next.

This is the radio check written down. Until it is on the board, no other station can find you.

### 5 · Before starting a task — check in with Control

Not after. Before.

```
FRONTEND TO CONTROL — Taking the checkout screen. Touching frontend/src/checkout
                      and components/Button.tsx. Next after that: the payment
                      step. Any conflicts? Over.

CONTROL TO FRONTEND — Roger. Backend holds apps/orders — no overlap. But Sweep
                      is renaming Order.total in about ten minutes and that
                      touches Button.tsx. Start with checkout, hold Button.
                      Board updated. Out.
```

**This call is what puts the task on the board**, and it is where a conflict gets caught
while it is still cheap. A station that starts work without checking in is invisible until it
collides with someone.

### 6 · Before the session ends — hand over, then close

**A session must not simply be closed.** When the user asks to exit, or the work is done,
finish the handover first:

1. **Push everything.** Commits, branch, all of it. Unpushed work dies with the window.
2. **Write down anything only you know** — findings, decisions, dead ends. If it is not in the
   repo it does not exist.
3. **Report to Control** — what landed, what is unfinished, where it is parked:

```
FRONTEND TO CONTROL — Standing down. Checkout screen landed on lane/frontend,
                      pushed, tests green. Button.tsx is HALF DONE — hover
                      states missing, parked at commit 8fa21c3. Board updated
                      to paused. Nothing unsaved. Out.

CONTROL TO FRONTEND — Roger, board shows paused with the commit. All clear to
                      close. Out.
```

4. **Wait for Control to acknowledge.** Only then close the window.

**If Control is not manned**, do the same thing into the board and the progress log instead —
the point is that the knowledge survives the window, not that someone said "roger".

---

## Countermeasures — when it has already gone wrong

**Say it out loud first.** The instinct is to quietly fix it before anyone notices. That is how a
small mess becomes an unrecoverable one, because two people then "fix" it in opposite directions
at the same time. **Prefer a visible mess to an invisible fix.**

**Never fix by deleting.** No `git checkout --` on work you did not write, no bare `git stash`,
no dropping a stash you have not read. Those turn a recoverable mess into a real loss.
**Never rewrite pushed history** — fix forward.

→ **Full procedures per failure mode: `references/countermeasures.md`.** Read it when something
has actually gone wrong, not before.


## Deploying a station — Control only

**"Deploy" here means putting a session on post with its own workspace and call-sign.** It is not
the software meaning; say **"ship to production"** for that, and never a bare "deploy" in a repo
where both are possible.

`deploy` cuts the post, spawns the session **named `--name <CALLSIGN>`**, lets it identify itself,
and **verifies the row carries its address** — a deploy that ends with a 🚧 row and no session
name has produced a lie, not a station.

**Before deploying, ask whether the work splits — and whether the station can work RIGHT NOW.**
A station blocked behind a shared blocker still costs a board row, a radio check and every
broadcast it reads. Station count tracks *gateable work*, not ambition.

→ **Terminal recipes, spawn config, verification and the known stalls:
`references/deploying-stations.md`.** Control reads it when deploying; stations never need it.


## Stations go down. Sweeps go across.

A **station** owns an area. A **sweep** owns a *change* that touches files several stations own —
a library upgrade, a shared rename, a design-system pass.

**The test:** does this change touch files owned by more than one station? If yes it is a sweep.

**Stations have right of way. A sweep has to ask.** Announce it, collect every live station's
acknowledgement, land it fast, and **always call all clear — even if the sweep failed.** A
standby nobody lifts freezes the whole fleet. **Only one sweep at a time.**

→ **Full procedure, the two sweep modes, and how to put one on the board: `references/sweeps.md`.**


## How stations talk

Address the station, state your business, end the call. Every line below is a phrase people
already know.

| Phrase | Means |
|---|---|
| **"Control to Backend"** | I am calling that station |
| **"Backend, go ahead"** | I'm listening, send it |
| **"Backend to Control"** | replying to the caller |
| **"All stations"** | broadcast — everyone needs this |
| **"Standby"** | wait, I'm not ready |
| **"Roger"** | received and understood |
| **"Say again"** | repeat that, I didn't get it |
| **"All clear"** | the hold is over — carry on |
| **"Clear to proceed"** | I checked, nothing conflicts — go |
| **"All hands"** | urgent — everyone stop and read this |
| **"Mayday"** | something is breaking right now, drop everything |
| **"Out"** | this exchange is finished |

Eleven phrases, and you already knew all eleven. **If you catch yourself wanting a twelfth,
use ordinary words instead** — "will do" beats "wilco", and nobody has to be taught it.

### Radio discipline — every message costs the user money

**A fleet's running cost is its radio traffic, and verbosity is the failure mode this skill is
most prone to.** Measured on 2026-08-17: four stations produced *one* product commit and a dozen
coordination commits, with routine calls running 400–600 words. Stations copy the register they
are answered in, so a long Control makes a long fleet — the drift is automatic and compounding.

**The caps. Treat them as real limits, not aspirations:**

| Message | Cap | |
|---|---|---|
| Routine call, answer, acknowledgement | **≤ 5 lines** | most traffic |
| Check-in, dependency answer, standdown | **≤ 10 lines** | |
| Sitrep | **≤ 10 lines** | five facts, no narration |
| Mayday, sweep announcement, countermeasures | **uncapped** | safety beats brevity, always |

**Six rules that do the actual work:**

1. **Write it to the repo, send the reference.** A finding, a decision, a measurement belongs in
   the board, the backlog or the log. Then the message is *"C28 filed at `09286a7`"* — not the
   finding. The repo is the shared memory; the radio is only a pointer to it.
2. **Never restate the other station's message back to it.** It knows what it said. This alone
   was half of today's traffic.
3. **Do not narrate reasoning that belongs in a commit message.** Put it in the commit, name the
   commit.
4. **Skip acknowledgements** unless someone is *blocked* on yours. "Roger" costs the same as a
   fact. A hold needs an ack; a filed finding does not.
5. **Read before you ask.** If the board, a doc, or the code answers it, that is free and a peer's
   attention is not.
6. **Stations call each other directly for lane questions.** Routing through Control doubles the
   cost of every exchange. Control is for conflicts, sequencing and holds — **not a switchboard.**

**Silence is the default, not the exception.** A station with nothing to coordinate says nothing.
Traffic should be *unusual*.

**But silence has one cost, and it is not optional to pay it: re-read the board from `origin`
before you write anything after a gap.** A quiet station's picture of the fleet goes stale
silently, and the failure it produces — filing a risk that was resolved while you were away —
is worse than the traffic you saved. See *Coming back* under radio silence.

**And the biggest saving is structural: do not deploy a station that cannot work right now.**
Three of today's four had nothing to gate because Docker was down — they still cost check-ins,
radio checks, board rows and coordination. **Station count should track gateable work, not
ambition.** One station working through a queue in order beats four stations negotiating over it.
For one or two stations, skip Control entirely: the board plus direct calls is the whole protocol.

### `@callsign` — how a human addresses a station

**A human types `@<callsign> <whatever>` into ANY session, and that session relays it.** They
should never have to find the right window first.

```
@backend sitrep
@channels do you hold adapters/ebay.py?
@all-stations standby, sweep incoming
```

**Any session that sees a prompt opening with `@<callsign>`:**

1. **It is not for you.** Do not act on it, even if you could — that is the misdirected prompt
   with extra steps.
2. **Resolve the call-sign to an address** off the board, then `SendMessage` the text after the
   token, saying who it is really from: *"CONTROL relaying from the user: sitrep"*.
3. **Report the reply back** in the window the human typed in.
4. **`@all-stations` / `@all-hands`** broadcast to every live station.
5. **Unknown call-sign → say so and list the manned ones. Never guess** — a near-miss delivers
   someone else's instruction to the wrong station.

**Case-insensitive in, canonical out.** `@backend`, `@Backend` and `@BACKEND` all reach
`BACKEND`; the board and the radio always render it `BACKEND`.

**This is the antidote to the fleet's most expensive human error.** With four identical-looking
tabs, a prompt meant for Frontend lands in Backend — and by the time anyone notices, Backend has
done work nobody wanted, in a lane that does not own it. `@callsign` puts the target in the text
instead of in whichever window had focus. **`@` makes misdirection recoverable; the pinned tab
title from identify step 6 makes it unlikely.** Use both.

**If a human types a bare prompt that plainly belongs to another station** — no `@`, but the
content is someone else's lane — **do not act on it and do not silently forward it.** Say which
station it looks meant for, and offer to relay.

**"All stations" and "all hands" are not the same.** *All stations* is routine — read it when
you get a moment. *All hands* means stop what you are doing. Keep them distinct or both stop
meaning anything.

**"Mayday" is for real damage only** — main is broken, data is being lost, a sweep went wrong
half-finished. Use it once for something that is not, and nobody moves the next time.

**"Standby"** and **"all clear"** are a pair, and they are what a sweep runs on: *standby*
means stop committing in these paths, *all clear* means it landed, pull and carry on. A sweep
that says standby and never says all clear has left every station frozen — **always close the
loop, even if the sweep failed.**

### Who is who — the radio check

**Name the session after its call-sign, and this problem mostly disappears.** `claude --name
<CALLSIGN>` sets the session's display name — and that name is what `ListAgents` shows other
stations, what appears in their `SendMessage` address, and what the user sees on the prompt box
of that window. **Verified 2026-08-17:** a session spawned `--name TESTRIG-CALLSIGN` listed to
its peers as `TESTRIG-CALLSIGN [eefa7c]`, not as a generated handle. So `deploy` always passes
it, and the call-sign becomes the address:

```
CONTROL [3f1a02]    ·  the shared checkout, holding the board
CHANNELS [5ea498]   ·  busy
FRONTEND [7b6568]   ·  busy
BACKLOG [028df2]    ·  waiting
```

That listing is readable. Compare what you get without `--name`, which is what every station
saw before this was fixed:

```
ecom-nexus-oss-d9 [864a63]   busy
ecom-nexus-oss-d9 [e92446]   busy      ← same name as the one above
ecom-nexus-oss-28 [e29977]   busy
ecom-nexus-oss-85 [6d86b0]   waiting
```

Nothing there says which one is Frontend. **Names can even repeat** — when they do, the
`[ref]` in brackets is the only way to tell them apart, and you must pass it exactly as shown.
Naming by call-sign makes repeats far less likely, because two stations must not share a
call-sign in the first place.

#### The bootstrap trap: a session cannot see itself

**`ListAgents` never lists the session calling it.** So a station that came up unnamed **cannot
read its own address**, and identify's step 4 — *write your `ListAgents` name onto the row* — is
**unsatisfiable alone**. It needs a peer or Control to read the name back over the radio.

This is not theoretical. On 2026-08-17 three stations in a row hit it within fifteen minutes,
and each one correctly refused to guess — one explicitly retracted a plan to write the row
"with the name pending", on the grounds that a row naming a holder it cannot prove is exactly
the lie the board exists to prevent. A lone first session has no way to comply at all.

**`--name` is the fix, because a station named after its call-sign already knows its own
address — it does not have to look it up.** Two consequences worth stating:

- **A named station can write its own row immediately**, with no radio check and no peer.
- **If you are unnamed, you must still ask.** Say so plainly — *"I cannot see myself; what
  address does this message arrive from?"* — and **never invent a name or leave the cell
  blank.** A nameless row is reserved, not manned.

**Control: when any station asks for its own address, answer it immediately and exactly**,
including the `[ref]`. It is a two-second lookup for you and a hard block for them.

So do a **radio check** whenever names are unknown or the board looks stale:

```
CONTROL TO ALL STATIONS — Radio check. Reply with your call-sign, your working
                          directory, your branch, and the paths you hold. Out.
```

**Ask for the working directory, not just the branch.** It is the one fact that catches a
station which came up in the shared checkout against a row claiming it is on post.

Then put the answers on the board. **The board is the phone directory:**

| Call-sign | Address (from `ListAgents`) | Branch | Holds |
|---|---|---|---|
| FRONTEND | `FRONTEND [6d86b0]` | `lane/frontend` | `frontend/src/checkout` |
| BACKEND | `ecom-nexus-oss-28 [e29977]` | `lane/backend` | `apps/orders` |

Both forms are valid — the second is a station that came up by hand without `--name`. **Record
what `ListAgents` actually prints, never what it ought to print.** To call a station: look up its
address on the board → confirm it is still listed in `ListAgents` → message that exact name. If
the bare name matches two rows, append the `[ref]`.

#### An address is an address, never a name

A machine-generated handle like `ecom-nexus-oss-4d [9a7a96]` belongs in exactly two places: the
`to:` field of a message, and the address column of the board. **Nowhere else.**

Everything a human reads — radio traffic, the board report, a sitrep, your summary at the end
of a watch — uses the **call-sign**:

| Say this | Not this |
|---|---|
| `CONTROL TO CHANNELS — Radio check.` | `CONTROL TO ecom-nexus-oss-4d — Radio check.` |
| "Channels holds the adapters." | "4d holds the adapters." |
| "We lost contact with Frontend." | "ecom-nexus-oss-1e stopped responding." |
| "Backlog and Channels both want C24." | "-c7 and -4d both want C24." |

**This is the entire reason call-signs exist.** `CHANNELS` tells every listener what that
station owns; `ecom-nexus-oss-4d` tells them nothing and cannot be remembered, said aloud, or
matched to a row at a glance. A report full of session handles has thrown away the one piece of
information the naming scheme was for.

**A station with no call-sign yet is the one exception** — before it identifies there is nothing
else to call it, so say *"the unidentified session in the shared checkout"* and get it a
call-sign. Do not let a handle become its name by habit.

**Re-run the radio check whenever the board looks stale**, because a session that ended still
has a row but no longer answers. A call that bounces means that station is gone — and its row
is now lying.

**For a human trying to work out which window is which:** ask any session *"what's your
call-sign?"*, or read the board. A session can also identify itself by the id in its own
scratchpad path — useful when two windows look identical.

**A call must carry three things**, or it wastes the other station's attention:

1. **Who you are and who you want** — *"Control to Integrations"*
2. **What you need, specifically** — not "any update?" but *"do you hold `adapters/ebay.py`?"*
3. **Why it matters to them** — *"Frontend is blocked on it"*

Example of the whole exchange:

```
CONTROL TO INTEGRATIONS — Frontend is starting the eBay connect screen and needs to know
                   the two-step auth order. Do you hold apps/integrations/adapters/ebay.py,
                   and is the second begin-auth call confirmed?
INTEGRATIONS TO CONTROL — Roger. I hold ebay.py on branch lane/integrations. Confirmed: creds first,
                   then a SECOND begin-auth returns the redirect. Do not make `code`
                   optional. Out.
CONTROL TO FRONTEND — Integrations confirms two-step. Creds, then a second begin-auth.
                   You are clear to start. Out.
```

That is the whole point of the skill: **Frontend got the answer without reading
Integrations' code, and Integrations was interrupted once instead of five times.**

---

## Reference files — loaded on demand, not up front

**This skill is split so a station does not pay for Control's playbook.** `SKILL.md` holds
everything a station needs on post. The rest loads only when the command in hand calls for it:

| File | Read it when | Who |
|---|---|---|
| `references/deploying-stations.md` | deploying a station — terminal recipes, spawn config, verification, known stalls | Control |
| `references/control-playbook.md` | the board report, assigning a post, sitreps, fleet state, alerting a human, recovering lost work, standing a station down | Control |
| `references/sweeps.md` | a change crosses areas several stations own | whoever runs the sweep |
| `references/countermeasures.md` | something has already gone wrong | anyone, at the time |
| `label-tab.sh` | at identify — pins your call-sign to your terminal tab | every station |

**Do not read them speculatively.** The whole point of the split is that four stations no longer
each carry Control's 25KB of procedure they will never run. **Every KB in `SKILL.md` is paid once
per station, so it multiplies with fleet size** — that fixed cost is the parallelism tax, and it
is what makes four sessions cost more than one doing the same work rather than the same.

## Commands

| Type this | What happens |
|---|---|
| `/mission-control` | **Board** — who holds what, what's next, what needs attention |
| `/mission-control identify <call-sign>` | **Identify** — take a call-sign, **move yourself into its workspace**, and go on the board |
| `/mission-control sitrep` | **Sitrep** — every live station reports where it is, what it holds and what is blocking it, collected into one report |
| `/mission-control silence` / `/mission-control speak` | **Radio silence** — go heads-down; Control holds non-urgent calls until you lift it. Mayday still reaches you |
| `/mission-control state <normal\|sweep running\|mayday>` | **Fleet state** — set what the whole fleet is doing, so nobody has to infer it |
| `/mission-control checkin <task>` | **Check in** — tell Control what you're starting, before you start |
| `/mission-control standdown` | **Hand over and close** — push, report, get acknowledged, then exit |
| `@<callsign> <anything>` | **Address a station from any window** — the session you typed in relays it and reports the reply. `@all-stations` broadcasts |
| `/mission-control call <station>` | **Call a station** — ask one specific thing |
| `/mission-control all-stations` | **Broadcast** — ask every live station to report |
| `/mission-control depends <what>` | **Dependency check** — who else touches this, and what must I know first |
| `/mission-control station <name>` | **Cut a post** — workspace, branch, board row. Nobody is in it yet |
| `/mission-control deploy <station>` | **Deploy a station** — cut the post, **open the session named `--name <CALLSIGN>`, identify it, and verify** it landed. No keyboard |
| `/mission-control countermeasures` | **Something went wrong** — announce it, then repair without deleting |
| `/mission-control sweep <change>` | **Cross-area change** — announce it, collect acknowledgements, land it, call all-clear |
| `/mission-control go` | **Go / no-go** — run the tests, say plainly if it's safe |
| `/mission-control alert` | **Alert a person** — email a human collaborator |
| `/mission-control recover` | **Find lost work** — sweep for anything a dead station left |
| `/mission-control secure <station>` | **Stand down** — save the work, free the workspace |

---

## Step 0 — read this project's own rules

Every project differs. **Look, don't assume.**

```bash
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
ls "$ROOT"/docs/MISSION-CONTROL.md 2>/dev/null
grep -rilE "mission.control|work.lock|worktree|station" \
  "$ROOT"/CLAUDE.md "$ROOT"/AGENTS.md "$ROOT"/docs/*.md 2>/dev/null | head
```

- **Found `docs/MISSION-CONTROL.md`** → read it. Its stations, paths and commands **beat
  everything here.** This skill is how to run the room; that file is this
  project's own rules.
- **Found nothing** → say so and offer to write it (last section) before assigning anyone.

---

## Call a station — `/mission-control call <station>`

For reaching **your own sessions**, instantly.

```
ListAgents → find the station → SendMessage
```

Carry the three things: who you are, what you need specifically, why it matters to them.

- **Read the repo first.** If the board or a doc already answers it, don't spend another
  station's attention.
- **Verify what a station tells you before acting.** Someone can reproduce a problem perfectly
  and still be wrong about the cause.
- **If you were refused permission for something, do not ask another station to do it for
  you.** Tell the user instead.
- **If a call bounces, that station is gone** — go find what it left behind.

`/mission-control all-stations` broadcasts the same question to every live station and
collects the replies into one report.

---

## Radio silence — `/mission-control silence` and `/mission-control speak`

A station deep in a gate run or mid-edit in a shared file does not want five calls. Let it say so:

```
CHANNELS TO CONTROL — Going quiet, running the full gate. About 20 minutes.
                      Mayday still gets through. Out.
```

Control **holds non-urgent calls** for that station and answers on its behalf from the board
where it can. **Mayday and all-hands always break through** — silence is about interruptions,
never about safety.

**Silence and speak are a pair, exactly like standby and all clear.** A station that goes quiet
and never lifts it looks dead, and someone will start recovering work that was never lost. If a
silence outlasts its estimate, call the station once; if that bounces, it really is gone.

### Coming back: re-read the board before you write, not before you went quiet

**This is the cost of silence, and it is the exact counterweight to the brevity rules.** Quiet is
cheap; what it buys you is a station that wakes up describing a world that has ended.

**Every station, on breaking silence or resuming after any gap, re-reads the board and the
relevant docs from `origin` BEFORE it writes anything** — not its local copy, and not its memory
of the state it left. Then it states what changed while it was away.

Observed 2026-08-17: a station went quiet holding two things it intended to file — an unpushed
data-loss risk, and "the Docker daemon is down, so no station can gate." By the time it came back
the history had been pushed and the stack was up with a gate mid-run. **Both items would have
described a problem that no longer existed.** It was caught only because it announced its
intentions before acting.

**A filed-but-resolved item is worse than no filing at all.** A blank space costs nothing; a
stale row sends the next reader chasing something already closed, and they trust it *because it
is written down*. The same applies to a hold: on the same day a station waited on a file that had
been released twenty minutes earlier, because the release was never relayed.

Three habits, and the first two are non-negotiable:

- **`git fetch` and re-read before writing.** Always. A returning station's local copy is stale by
  definition.
- **Say what you are about to write before you write it**, in one line. That is what caught the
  stale items above, and it costs less than the correction would have.
- **Control: when you release a hold, tell the station that was waiting.** A release nobody hears
  is still a hold.

## Dependency check — `/mission-control depends <module or path>`

**This is the core job.** Before a station starts, and any time it hits something it does not
own.

**1 · Who else touches this?**

```bash
grep -n "<module or path>" docs/WORK-LOCKS.md     # is it claimed?
git log --oneline -5 -- <path>                     # who changed it recently
git branch -a --contains $(git log -1 --format=%H -- <path>) 2>/dev/null | head
```

**2 · Decide from what you find:**

| What you find | What to do |
|---|---|
| **Nobody holds it** | Claim it on the board and proceed |
| **A live station holds it** | **Call them.** Ask the specific question, get the answer, proceed with it |
| **A dead station held it** | Recover what it left behind before touching anything |
| **A human collaborator holds it** | `/mission-control alert` — email them |

**3 · Pass the answer on, and record it.** When a station answers a dependency question, the
answer belongs in the repo — not only in a chat. Put it in the backlog item or the progress
log. **A finding that is not in the repo does not exist**, because the session holding it can
end at any moment.

**4 · If it is genuinely blocked**, say so plainly on the board — *blocked, waiting on
Integrations for the auth order* — rather than leaving the row looking merely slow. Blocked work
looks like lazy work if nobody says otherwise.

---

## Go / no-go — `/mission-control go`

Run the tests **on this station's own database**, so no other station waits.

```bash
ROOT=$(git rev-parse --show-toplevel); STATION=<name>
WT="$ROOT/.claude/worktrees/$STATION"
docker compose run --rm --entrypoint "" \
  -v "$WT":/app \
  -e DB_NAME=<db_prefix>_$STATION \
  <test_service> bash -lc "<install cmd> && <test cmd>" > /tmp/tests-$STATION.txt 2>&1
```

Both flags matter. `-v` means this station tests **its own files**, so another station
switching branches cannot change them mid-run. `-e DB_NAME` gives it **its own database**. Use
both, or stations collide. Take the exact service and commands from the project's rules.

**Before starting:** services healthy; nobody else running tests (ask if unsure); **nobody
edits code while a run is going.**

**Reading it.** If the project keeps a list of already-known failures, compare the **names**,
**both directions** — never the count. A count cannot tell "the same 21" from "20 old plus 1
new". Check the **clock** too: a broken run is usually *faster* than a good one, never slower.

Then say **"go"** or **"no-go"**, and if no-go, name exactly what broke. **Never soften a
no-go into a go.**

---

## Standing orders

1. **Never `git add -A`.** Name the files. This has already swept one station's unfinished
   work into another's commit.
2. **Naming files doesn't help if two stations edited the *same* file.** Saving a file saves
   all of it. Either commit it and **say in the message it contains both stations' work**, or
   leave it and tell someone.
3. **Never shut down shared services.** Starting them is fine.
4. **Say so before taking or freeing a port.**
5. **Fetch the latest before republishing anything shared. Never force.**
6. **Only push commits you wrote.**
7. **Pull, then merge, then push** — backwards silently deletes the merge.
8. **Save and push early.** A station can go quiet at any moment.

---

## The four documents

Control keeps these. They look alike and are not interchangeable.

| File | Answers | When | Behaviour |
|---|---|---|---|
| `WORK-LOCKS.md` | **who holds what, and what's next** | now | edited constantly; stays short |
| `PROGRESS-LOG.md` | what happened, and why | past | append-only; never edit an old entry |
| `PROJECT-STATUS-AND-BACKLOG.md` | what to work on next | future | items added, checked off, re-scoped |
| `MISSION-CONTROL.md` | this project's own rules for running sessions | — | changes rarely |

At the end of a watch, progress goes into **`PROGRESS-LOG.md`** — use the project's own
progress-logging skill if it has one, rather than inventing a format.

---
