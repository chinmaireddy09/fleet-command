## Deploying a station

**"Deploy" here always takes a station name** — *deploy Frontend*, *deploy a second Backend*.
It means put a session on post with its own workspace and call-sign.

⚠️ **This is not the software meaning of deploy.** Shipping code to production is a different
thing entirely. Where both could be meant, say **"ship to production"** for one and **"deploy a
station"** for the other. Never say a bare "deploy" in a repo where both are possible.

```
CONTROL TO ALL STATIONS — Deploying a second station on checkout. Call-sign
                          FRONTEND-BRAVO, branch lane/frontend-bravo. It takes
                          the payment step; FRONTEND-ALPHA keeps the cart.
                          Board updated. Out.
```

### Deploy does the whole thing — initiate, spawn, identify, verify

`station <name>` initiates a post and stops. **`deploy <station>` carries it all the way to a manned
station with nobody touching a keyboard.** Four steps, and it is not finished until the fourth
one passes:

**1 · Initiate the post.** Exactly `station <name>`: worktree, branch, copy the ignored instruction
files, write the row, push it.

**2 · Spawn the session** — the way *this* user asked for it, once, on this machine.

#### The default is background, and it is not a terminal at all

`claude --bg` starts a station as a **background agent**: it returns in about a second, opens
no window, types nothing, and takes nobody's focus. **It is a station by every test the fleet
applies.** Measured 2026-08-23 on 2.1.241, in an untrusted worktree:

- it registered as `MCBGPROBE [b2aa24] · bg · idle` in the fleet manifest;
- it **answered a radio check** sent to it by call-sign with `SendMessage`;
- start to registered took ~1.5s, against 4s of deliberate delay per station on the old path.

**The tab was never what made a station.** A station is a registered session — something the
manifest shows, `SendMessage` reaches, and the board can carry an address for. Once that is the
definition, the terminal is a viewing preference, not a mechanism, and every "which terminal is
this person running" problem stops being a deploy problem.

That is also the whole answer to *"make it work in my IDE"*: background mode needs no host, so
it works identically in VS Code, Cursor, Windsurf, JetBrains, a bare SSH session and a CI box.

**A background station has no window for a permission prompt to appear in.** That is the one
real cost, and it is why the deploy report ends with these rather than burying them:

```
claude agents          every station, background and interactive
claude logs <id>       what it is showing right now
claude attach <id>     take it over in this terminal — full TUI, answer a prompt
claude stop <id>       stand it down
```

#### Ask once which mode they want. Never detect it and never assume it

```bash
bash <skill-dir>/spawn-pref.sh read                 # background | window | unset
bash <skill-dir>/spawn-pref.sh set background       # record the answer
```

`read` reports **`unset`** on a machine nobody has been asked on — and `unset` is deliberately
not reported as `background`. They behave the same to a deploy that has to run anyway and mean
opposite things to you: one is a choice, the other is a question nobody has put yet. Collapsing
them is exactly how the ask never happens.

On the **first deploy on a machine**, when `read` says `unset`, ask **one** `AskUserQuestion`:

| Option | What they get |
|---|---|
| **Background — no window** (recommended) | Stations run headless. Nothing opens, nothing steals focus. `claude attach` when you want to look. Works in every IDE and CLI |
| **A visible window** | Each station opens its own window or tab, already in its worktree, already running, already identified |

Then `spawn-pref.sh set <answer>` and carry on. **Never ask again** — and a deploy on an
unrecorded machine says so in its own output, so a skipped ask is visible rather than passing
silently for a preference.

**Tell them it is changeable in the same breath as recording it.** A person who believes a
setting is permanent answers it differently from one who knows it takes a second to change:

> Recorded. `/mc config` changes it any time.

`/mc config` (`mc-config.sh show`) lists every preference with its current value and what each
default actually does, and `set`/`unset` change them in place. **A preference you can only change
by making the tool forget you answered is not a setting, it is a fresh install** — which is what
`spawn-pref.sh reset` alone amounted to before 6.79.0.

**Detection is not consent.** `$TERM_PROGRAM` says where *Control* happens to be running. It
does not say where the user wants their stations, and the two differ routinely — Control in an
IDE terminal, stations wanted in real windows, or the reverse.

**The preference is per-machine and lives outside any repo**, in `~/.claude/mission-control.json`.
A clone carrying the author's terminal choice is the same class of bug as a workspace missing
its gitignored `CLAUDE.md`: it looks configured and is wrong. **The repo ships the recipes; the
machine holds the choice.** There is nothing to push, because the first deploy on a new machine
configures itself.

#### The scope rule: this automation is for deploy, and for nothing else

**The spawn automation has one job — open a station's session and get it identified — and one
trigger: an explicit deploy.** When the station is up and carrying its address, the automation
is finished. It does not go back to the terminal to arrange, focus, resize, retitle, close or
read anything, and no other operation in this skill may reach for it merely because it is here.

This is **enforced, not merely documented**: a spawn requires `--deploy`.

```bash
bash <skill-dir>/spawn-station.sh BACKEND "$WT" BACKEND --deploy     # deploy: really spawns
bash <skill-dir>/spawn-station.sh BACKEND "$WT" BACKEND              # anything else: prints
bash <skill-dir>/spawn-station.sh BACKEND "$WT" BACKEND --print      # explicitly print
```

Without `--deploy` the script starts nothing and prints the paste-able line instead. It is a
demotion rather than a refusal on purpose: the caller still ends up with something that works,
and a guard that leaves a human empty-handed gets routed around. **An automation whose scope is
a sentence in a comment grows; one whose scope is a required flag does not**, because every call
site has to state its intent out loud and `grep -c -- --deploy` counts them.

| The ask | What happens |
|---|---|
| **`/mc deploy <station>`** | **Automated.** Asking to deploy *is* the authorisation. Session starts, registers, identifies |
| **`/mc station <name>`** | **Printed.** A post is initiated with nobody walking to it yet, so there is nothing to automate |
| **A session coming up by hand** | **Printed.** Nobody asked for a spawn |
| **The automated path cannot finish** | **Printed automatically**, on top of the failure report — you are never left with nothing to act on |

#### Always spawn with `--name <CALLSIGN>`

**Every recipe passes `claude --name "$CALLSIGN"`, and none of them is optional.** That flag sets
the session's display name, which is simultaneously:

- what **the fleet manifest shows other stations**, so the call-sign *is* the `SendMessage` address;
- what the **user sees** on that session's prompt box and terminal title, so they can tell four
  identical windows apart at a glance;
- what the station **knows about itself** from its first instant, rather than deriving it a step later.

**Verified 2026-08-17:** a session spawned `--name TESTRIG-CALLSIGN` appeared to its peers as
`TESTRIG-CALLSIGN [eefa7c]`. Without the flag the same session would have listed as
`acme-shop-4d [9a7a96]` — an address nobody can remember, say aloud, or match to a row.

Pass the call-sign in **exactly the form the board uses** — same case, same spelling. `INTEGRATIONS`
on the board and `channels` in the manifest is a directory that fails at its one job.

#### The recipes — every one of them a published API, never a synthesised keystroke

**This is the line that matters, and it is why the old path is gone.**

*UI puppetry* is pretending to be a human at the keyboard: synthesising a keypress and hoping it
lands. `tell application "System Events" to keystroke "t" using command down` is not "open a tab"
— it is *press ⌘T*, the identical keypress a finger makes, and only the synthetic one can go
wrong. It lands wherever focus happens to be, its modifier can lose a race, and its timing is a
`delay` and a hope.

*A real API* is a command the terminal publishes that does the thing directly. You ask the
application; it does it and tells you, or it errors. No focus, no keys, no sleeping.

| Host | The actual call | Status |
|---|---|---|
| **anything at all** | `claude --bg --name <HANDLE>` | **measured 2026-08-23** — registers, answers radio |
| **tmux** (inside one) | `tmux new-window -c <wt> -n <CALLSIGN>` | portable: macOS, Linux, WSL, and inside IDE terminals |
| **iTerm2** | `create tab with default profile` → `write text` | recipe shipped, **not verified** |
| **macOS Terminal.app** | `do script "<cmd>"` | opens a **WINDOW**. See below |
| **kitty** | `kitty @ launch --type=tab --cwd <wt>` | needs `allow_remote_control yes`; **not verified** |
| **WezTerm** | `wezterm cli spawn --cwd <wt>` | recipe shipped, **not verified** |
| **Windows Terminal** | `wt.exe -w 0 nt -d <wt>` | recipe shipped, **not verified** |
| **gnome-terminal / konsole / xfce4-terminal / alacritty / ghostty / xterm** | `-e` with a working directory | recipes shipped, **not verified** |
| **VS Code · Cursor · Windsurf · JetBrains** | *none exists* | see the fallback rule |

**The window comes up finished.** Each recipe launches in the worktree, running `claude --name`,
with the identify prompt already in argv — so it appears already in its lane, already named,
already starting work. Nothing is typed into it while the user watches, and clicking away
mid-deploy breaks nothing.

**macOS Terminal.app gives you a WINDOW, and you must say so.** Terminal.app publishes no
scriptable new-tab; a tab requires the ⌘T keypress, which is the puppetry this rewrite removed.
`do script` is Terminal's own API and creates a window atomically. **A window when somebody
pictured a tab is not a silent detail** — say which one they got. It also needs only the
*Automation* grant, never *Accessibility*, because nothing is sending keystrokes any more.

**The fallback rule: no published API means no window — never a faked one.** For VS Code, Cursor,
Windsurf, JetBrains, or an unrecognised `$TERM_PROGRAM`, `--window` **declines**, says why, and
points at background mode. It does not fall back to driving the UI. That decline is not a
degradation now: the same host still deploys perfectly in background, because background needs
no host at all.

**Never guess AppleScript or PowerShell for a terminal you cannot see.**

#### What the keystroke path actually cost, twice

Kept because this is the reasoning that must not be re-derived from scratch by whoever is next
tempted to "just open a tab".

**2026-08-17 — two failures in one deploy.** The modifier lost its race, a bare `t` reached the
shell, and the station tried to run `tcd '/path' && claude …`. Separately, a synthetic keypress
goes wherever focus is, so a station's tab opened in an unrelated window and advertised the wrong
project in its title. The response then was to target our own window by tty and read the tab back.

**2026-08-23 — the same race, three at once, with all that verification in place.** Deploying
three stations: three tabs opened **empty**, at a plain `%` prompt, still in the spawner's
directory. All three launch commands were typed into **Control's own prompt** instead, interleaved
and corrupted — one line read `ntialcd '/Users/…' && claude …`, a fragment of one spawn's text
fused onto the next one's `cd`.

**The lesson is not "verify harder".** Targeting by tty and reading the tab back did not remove
the race; it only made the race observable, and then the race happened anyway. `do script … in
(selected tab of window id N)` resolves that reference against a tab ⌘T may not have finished
creating. **The fix was to stop needing a tab**, which followed from noticing that a station was
never a tab in the first place.


#### Two traps that already cost a session

**A slash command DOES execute when passed as the CLI prompt** — measured 2026-08-17, `claude -p
"/some-command"` runs it rather than treating it as text. So `claude '/mc identify X'` is sound;
if a station fails to identify, the launch is not the reason. Look at the permission prompt.

**Do not verify a tab by counting tabs** *(window mode only — background mode has no tab to
miscount, and `claude agents --json` answers the question outright).* `count of tabs of window` cannot see macOS window
tabs — each is a *separate window* reporting exactly `1` tab, so a spawn that lands as a tab
reads as "a new window" through that API. On 2026-08-17 that cost four probes and a wrong
conclusion: Accessibility was already granted, tabs *were* appearing, and the measurement said
otherwise. **The user's screen is the instrument.** Report which call succeeded, and ask what
they see rather than counting. Check your checks: confirm the identifier identifies what you
think it does.

**On the `cd`: background mode does not need one at all.** The station is launched *from* its
worktree, so its working directory is set by the launch rather than by a command run inside it.
Window mode still carries a leading `cd`, because a new window inherits the spawner's directory
— Control's repo root, not the station's lane. The rule that a *human* must never be the one to
remember it is unchanged: a script cannot forget, and `identify` re-checks its own directory in
step 3 either way.

**3 · Let the session identify itself.** It comes up already inside the lane, runs `identify`,
takes the row, and writes its own address onto it — which, because you spawned it
`--name <CALLSIGN>`, it already knows without having to ask anyone.

**4 · Verify — and this is the step that matters.** `claude agents --json` prints active
sessions — interactive *and* background — and explicitly does not need a TTY, so verification is
finally scriptable rather than inferred from a terminal's scrollback. Poll it, or `ListAgents`,
until **the call-sign appears as a session name** — that is the confirmation the `--name` took — then **read the board
back from `origin` and confirm the row carries it.** Liveness is not the proof; the address on
the pushed row is, because that is the thing every other station needs in order to call it.

**Read the board back from the remote, not from a local copy.** A station that verifies its own
push against its own working tree has checked nothing.

#### Live session, reserved row: four causes, and you must not guess which

A station that is alive while its row still reads 🔒 is the **two-sided lie** — a session nobody
can address, and a post that reads free while somebody sits in it. Four things cause it:

| Cause | Tell |
|---|---|
| **Waiting on a permission prompt** | Station alive, silent, no traffic. The prompt is in a tab nobody is looking at |
| **Cannot read its own address** | It is *asking* for its name. the fleet manifest never shows a session itself — see the bootstrap trap |
| **The human interrupted `identify` mid-flow** | It stopped at a step *by instruction* and is waiting on the human to resume. Observed 2026-08-17 |
| **The session died** | Calls bounce. Now it is a recovery job, not a deploy job |
| **The command never ran** | *Window mode.* The tab exists and sits at a plain shell prompt, with an error in the scrollback. Nothing is listed, because no session was ever started. **This is the cause that was missing on 2026-08-17**, when a mangled `cd` meant the four causes above were all wrong and Control had to ask a human what was on screen. Background mode cannot fail this way: there is no shell to mistype into |
| **Spawned but never registered** | The launcher reported success and **no session ever appeared** — no process, nothing to stall. It did not hang; it never came up. Measured 2026-08-18 |

**Three outside measurements are free and decisive — take them BEFORE you ask.**

```bash
claude agents --json                  # every session, background and interactive. No TTY needed
claude logs <id>                      # what a background station is showing RIGHT NOW
pgrep -f "claude --name <CALLSIGN>"   # is the process alive at all?
```

`claude logs` is the one that changed the shape of this problem. A background station has no
window for you to send someone to, but its output is readable on demand — so "what is it stuck
on" became something Control can answer for itself instead of asking a human to go and look.

**A socket is not readiness, and this correction is load-bearing.** The old table treated
`/tmp/cc-socks/<PID>.sock` as proof a station was up and registered. Measured 2026-08-23: a
session launched into a fresh pty in an untrusted directory **registered its socket while still
sitting at the folder-trust prompt** — present, listed, and unable to do a thing. Socket presence
proves the process got far enough to register. It does not prove the station can work.

| What you measure | What it means | What to do |
|---|---|---|
| listed by `claude agents`, and `logs` shows a working session | it is up | it is a manifest or board problem, not a spawn one |
| listed, but `logs` shows a prompt or a dialog | alive and blocked | `claude attach <id>` and answer it, or send the user there |
| **not listed** | it never started, or it died | re-spawn; retrying is safe by design |

**Then ask, for anything these cannot settle. Do not diagnose the REST from the outside.** On 2026-08-17 Control announced a
stuck permission prompt; the station replied that there was none — the user had typed
`/mc identify`, interrupted it, and asked for a radio check instead, so it had stopped at step 3
exactly as told. Sending the user to a tab to approve a dialog that does not exist costs them a
context switch and costs you credibility on the next call, when it *is* the prompt.

The remaining ones look identical from Control's chair: live session, stale row, no traffic
explaining why. One question resolves it; a guess resolves nothing and may mislead.

**The line between measuring and guessing is the point.** *"Do not diagnose from the outside"* is
about **inferring a cause from a stale row and a feeling** — it was never meant to discourage two
commands that answer the question outright. Measure what is measurable, ask about the rest, and
never present either as the other.

**When it IS the prompt, end the deploy report by sending the user straight to it:**

```
INTEGRATIONS is up but blocked on a permission prompt. Run `claude attach 4f2a1c` to
answer it — until you do, it can't claim its row and no other station can call it.
```

In window mode, name the window instead. Either way, name the *one action* that unblocks it.

Deploy **surfaces** this; it does not solve it. **Never spawn with a bypassed permission mode to
make the prompt go away.** Control does not widen another session's permissions for its own
convenience — that is the user's setting, in their own config, chosen deliberately.

**If verification fails, say the deploy failed.** A spawned session that never identified is
worse than no deploy at all — there is now a live session nobody can address, holding a post the
board still shows as reserved. Report it, say exactly where it is — a session id for a background
station, a window for a visible one — and let the user decide.

**Then come back for the row.** A failed deploy leaves a reservation behind, and a reservation
outlives the deploy that initiated it unless somebody ends it — at which point it is a stale row making
a free job look taken, which is the thing the board exists to prevent. **The reservation is
protected only while this deploy is in flight.** Once it has failed and the user has decided:
either a session is accounted for and the row gets its address, or nothing claims it in
`ListAgents` and **the row is released and the release is announced.** Never leave it sitting as
"reserved" because the deploy that created it is over and nobody owns the cleanup.

**Retrying a failed deploy must be safe.** A station that got half-way may have already written
part of its row. `identify` therefore has to be idempotent on the **board row** as well as on
the worktree: re-running it updates the row in place rather than adding a second one, and a
station finding its own call-sign already on the board with its own session name should treat
that as success, not a collision.

### What deploy cannot do for you

Say all three out loud rather than discovering them mid-deploy:

- **The spawned session has its own permissions**, and will prompt for its own pushes and edits.
  **Never paper over this by deploying with a bypassed permission mode.** Control does not get to
  widen another session's permissions because it is convenient — that is the user's setting to
  make, not deploy's to assume.
- **Every spawned session bills.** Announce how many you are opening *before* opening them.
- **The *Accessibility* grant is no longer involved, and that is a feature.** It was only ever
  needed to synthesise ⌘T. Background mode needs no macOS grant at all; window mode on
  Terminal.app needs only *Automation*, which `do script` already used. The old failure mode —
  `not allowed to send keystrokes (1002)` on a machine that could open windows perfectly well —
  cannot occur any more, because nothing sends keystrokes. If a spawn still fails before *any*
  dialog appears, suspect the sandbox rather than macOS, and surface it instead of trying
  variations.

**Deploying initiates the post; identifying mans it.** A row is 🚧 only once a session name is on it.
A deploy that ends with a 🚧 row and no session name has produced a lie, not a station.

**Before deploying another station, ask whether the work actually splits.** Two stations in one
area with unclear boundaries collide more than one station working through it in order. Split
by *what each owns*, or do not split.

**And ask the harder question first: can this station work RIGHT NOW?** A station with no
gateable work still costs a board row, a radio check, check-ins and every broadcast it must read.
On 2026-08-17 three of four stations sat idle because the Docker stack was down — the fleet paid
full coordination cost for one station's worth of output. **Deploy against available work, not
against the shape of the backlog.** If the blocker is shared (services down, a decision pending),
deploying more stations multiplies the waiting, it does not divide it.

---

