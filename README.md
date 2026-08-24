# Fleet Command

One repository. A live command board. A fleet of Claude Code sessions operating under a single
command.

Each session takes a call-sign, claims its area of the codebase, and reports its position on
the board. They share the same repository but never work the same ground — no crossed commands,
no conflicting changes, no duplicated effort.

Before any session signs off, it hands over its progress, its decisions, and the next course of
action. Nothing disappears when a window closes, and the fleet keeps moving as one.

Deploy as many sessions as the mission demands. **One repo. One command. An entire fleet in
formation.**

Four skills for [Claude Code](https://claude.com/claude-code) that make that true. Nothing to
sign up for, and no limit on how many.

*Why they exist:* open a handful of windows on one project and they will quietly ruin each
other's day — one switches branches and the files change under another; one runs `git add -A`
and swallows a third's unfinished work; two file the same finding twice; a fourth dies and takes
its only copy of something with it. Every one of those happened in a single afternoon.

---

## The four skills

| Skill | Answers | Use it when |
|---|---|---|
| [`mission-control`](skills/mission-control/SKILL.md) | *who is working, on what, and does it clash with me?* | running more than one session on one repo |
| [`work-lock`](skills/work-lock/SKILL.md) | *can I start this?* | before you begin any job |
| [`status-and-backlog`](skills/status-and-backlog/SKILL.md) | *what should I work on next?* | filing or closing work |
| [`progress-and-log`](skills/progress-and-log/SKILL.md) | *what happened, and why?* | end of a working session |

They stand alone. `mission-control` is the one that needs the others; the rest are useful by
themselves.

---

## First run

The first time you type `/mc` on a machine, it offers a two-minute walkthrough — it creates or
finds your board, puts one real claim on it, shows you the row with your name in it, and takes it
back off. **It asks before touching anything, and if you already have a board it will not create a
second one.**

Say **skip** and it goes straight to the board and never asks again. Take it and it never asks
again either. The flag lives in `~/.claude/mission-control.json`, with your settings — **not in
your repo**, so a teammate cloning your project still gets their own first run. `/mc tour` replays
it whenever you want.

## Quick start

1. **Install** — two `cp` commands, below. Thirty seconds.
2. Open a session on your repo and run **`/mc`**. It becomes the coordinator, names itself, and
   tells you who else is working and on what.
3. Open another window and run **`/mc identify FRONTEND`** — **any name you like**, and a name
   nobody has used before is a normal answer, not an error. That session opens its own
   workspace inside the same repository (a git worktree) and moves into it on its own. You never
   `cd` anywhere.
4. Repeat step 3 for as many windows as you want. They do not have to be started in any order,
   and none of them waits for the others.
5. Before starting a job, run **`/mc depends <path>`** — it tells you who else is touching that
   file, so you find out before you start rather than in a merge conflict.
6. When you finish, run **`/mc standdown`** — it pushes your work, writes down what you learned,
   and hands over, so nothing dies with the window.

That is the whole loop. Everything else is for when something goes wrong.

**Requirements:** `git`, [Claude Code](https://claude.com/claude-code), a **POSIX shell** (the
scripts are bash), and `python3` — already present on macOS and most Linux.

**It makes no assumptions about your repository.** There is no layout to adopt and nothing to
add to your project before the first run:

| | |
|---|---|
| **Your default branch** | any name. `main`, `master`, `trunk`, anything — resolved per repo, never assumed. Set `MC_BASE_REF` to override |
| **Your remote** | any name. `origin` if you have one, otherwise the first remote you do have. **No remote at all also works** — it measures against your local branch and says that is what it did, rather than implying agreement with a remote that isn't there |
| **Your board file** | wherever you already keep it. Nothing is moved; if you have none, one is offered at `docs/WORK-LOCKS.md` and you can say no |
| **Your directory layout** | irrelevant. Call-signs name whatever areas your project actually has |
| **Your language and tooling** | no stack is assumed. The one command that runs anything — `/mc go` — takes your test command from your project's own rules, and only when you ask for it |

*Everywhere below writes `origin/main` and `docs/WORK-LOCKS.md`, because a doc has to write
something. Both mean **whatever yours are** — the scripts resolve them and print what they
found.*

### See your fleet under the prompt

Claude Code's footer counts shells; it can't show your stations. `statusLine` can — add
this to `~/.claude/settings.json`:

```json
{ "statusLine": { "type": "command", "refreshInterval": 5,
                  "command": "bash ~/.claude/skills/mission-control/statusline.sh" } }
```

**`refreshInterval` is not optional here.** Claude Code re-runs a status line when something
happens *in your session* — and everything this line reports belongs to a **different** session.
Another station going busy or idle produces no event in your tab, so without the timer the line
freezes at whatever it last saw and cheerfully shows a station working that finished ten minutes
ago. Local events are exactly the wrong clock for a fleet.

```
fleet · CONTROL · BACKEND · CHANNELS · FRONTEND · +1 unidentified
```

Built from the same pieces as Claude Code's own `auto mode on · 1 shell · ← 1 agent` below it:
dim label, dim `·` separators, colour for the live values.

**Colour says how visible the station is.** **White** — a *background* station, no window anywhere,
so this line is the only evidence it exists. **Claude orange** — a *tab*, visible but behind
whichever tab is forward. **Golden yellow** — its *own window*, the most visible a station gets.

White is achromatic on purpose: two earlier palettes failed the same way — an analogous triad read
as one colour at terminal size, and a pastel set converged the moment every station went idle — and
a value with *no* hue cannot collide with one that has hue at any brightness. So the background
station, the one you cannot find by looking at your screen, is the row that can never be misread.

**Your own station is boxed.** Colour tells you how visible a station is; it cannot tell you which
tab you are *in*, and on a screen of identical-looking tabs that is the question you actually have.
Each session boxes its own call-sign — reverse video, filled with that station's own colour — so
the box moves with the tab rather than being one more hue to learn. It joins the `session_id` on
the status line's stdin to the registry's `sessionId`, so there is nothing to configure.

**Tab vs window is measured, not assumed.** Nothing Claude Code records distinguishes them — `kind`
is only `bg` or `interactive`, and no environment variable carries it either (Terminal.app's
`TERM_SESSION_ID` is a per-*session* UUID, not a window index). So `window-probe.sh` asks the
terminal, and the line uses **two measures that must agree**: the tab count that window reported,
and how many live stations share it. A station is called a *window* only when both say it is alone,
so a count that went stale when you dragged a tab out never over-claims.

*Grouping is by the window's **frame**, not its id. Terminal.app's scripting model exposes every
**tab** as its own window object reporting `tabs = 1` — a window holding four visible tabs comes
back as four windows of one tab each — so neither the id nor the tab count can tell a tab from a
window. Tabs of one window share a screen rectangle exactly; a separate window has its own.*

**It keeps itself current.** Identify and deploy both refresh the whole fleet, and a
`UserPromptSubmit` hook re-runs the probe in the background so moving a window or dragging a tab
is picked up without anyone doing anything:

```json
{ "hooks": { "UserPromptSubmit": [ { "hooks": [ { "type": "command", "async": true,
  "command": "bash ~/.claude/skills/mission-control/window-probe.sh --all >/dev/null 2>&1" } ] } ] } }
```

Run it by hand any time, or **backfill the whole fleet from any session**:

```bash
bash ~/.claude/skills/mission-control/window-probe.sh --all
```

That joins every live session's tty to a window in one pass, so a fleet that is already up gets its
colours without every station being made to re-identify — and a station you started **by hand** is
coloured exactly like a deployed one, which a deploy-time record could never manage.

That distinction is **measured, not configured.** It reads `kind` from the session registry, never
the spawn preference — the preference describes *future deploys*, and a hybrid fleet (`spawn.once`)
can disagree with it right now.

**Bold is busy; idle is the same colour dimmed.** Two signals wide, so the station actually working
is the one your eye lands on from across the desk.

**Order: the coordinator leftmost, then whoever identified next, and next.** The eye starts from a
fixed point and the rest follow in the order you deployed them. (It was alphabetical until 6.93.0.
A fleet is not a dictionary.)

**Only this repo's sessions** — the registry holds every Claude session on the machine, and a
status line showing an unrelated project as if it were your fleet is the worst possible place
for that confusion. A session with a generated handle is **counted, never named**: an address is
not a call-sign.

**One unidentified session on its own prints nothing.** That case is not a fleet, it is the tool
describing you to yourself in a word that sounds like a fault. A station that *has* identified
always shows, even alone — the call-sign on screen is the confirmation it worked.

**It spawns nothing.** The obvious build shells out to `claude agents --json`; that costs ~0.21s
per render *and* starts a background service that inherits the caller's stdout — it hung a shell
for two minutes during development. It reads `~/.claude/sessions/*.json` and `/tmp/cc-socks/`
instead: microseconds, cannot hang, cannot start a daemon.

### The `@` header, and the one thing that fixes it

> **Full guide:** [`references/station-identity.md`](skills/mission-control/references/station-identity.md)
> — the three identity surfaces, how to start a station so none of them ever break, the three-step
> repair when one has, and the two things that genuinely cannot be fixed with what to do instead.

A session's own advertised name — the `@` header on every message it sends, and the name on its own
`ListAgents` self-line — is read into the process **at launch and never again**. Measured: after
`set-callsign.sh SKILLDEV`, the registry said `SKILLDEV` while that session's own self-line still
said `fleet-command-fd`; the same registry, read for a *peer*, was live and correct.

**It costs delivery, not just tidiness.** A peer replying to the name it received gets
*"No agent named … is reachable"* — measured — and reaches you only via the `[ref]`, which survives
every rename. That is why a station with a stale envelope ends up writing "resolve me through
ListAgents" into every message: it is routing around a real failure.

So `set-callsign.sh` fixes the address peers **resolve**, and cannot reach the value the process
already holds. `/rename` fixes the **tab title**, a different surface. Neither touches this.

**The repair is a relaunch — but it does not cost you the conversation:**

```bash
bash ~/.claude/skills/mission-control/fix-header.sh <CALLSIGN>
```

**Three steps, not two: quit, relaunch, `/mc identify <CALLSIGN>`.** `--resume` keeps the
conversation and the session id, but the relaunched *process* gets a new `[ref]` (measured: a
station came back as `[7f0b93]` where it had been `[a1c4e2]`). The board's row still carries the
old one, and a row pointing at a dead ref is exactly how Control concludes a station has died and
reassigns its work. `identify` rewrites the row in place.

It prints the exact line, session id filled in so nothing can be mistyped:
`claude --name '<CALLSIGN>' --resume <sessionId>`. `--name` sets the identity at the one moment it
is read; `--resume` reopens *that* conversation rather than starting a new one. The tab title is
fixed in the same move, since `--name` puts the call-sign in every title write.

Stations from `/mc deploy` never need this — they launch with `--name` already. **Control does.**
`/mc deploy` never launches Control: Control is whoever ran `/mc`, in whatever session they were
already sitting in, which is a bare `claude` started before there was a fleet to name. So the
default shape of a correctly-run fleet is every deployed station right and the coordinator carrying
a stale envelope — on the station that sends the most messages and is replied to the most.

**A peer can print the repair for a station that cannot see its own fault.** The envelope is only
visible to the *receiver*, so the station that notices is almost never the station that has it:

```bash
# by call-sign, by the stale name you read on the `@` header, or by pid
bash ~/.claude/skills/mission-control/fix-header.sh --for <CALLSIGN|stale-name|pid>

# or ask the whole fleet at once
bash ~/.claude/skills/mission-control/fix-header.sh --audit
```

```
pid      call-sign    envelope
11187    CHANNELS     OK        named at launch
1170     CONTROL      STALE     peers see `acme-api-54`
13590    FINANCE      OK        named at launch
```

It refuses to hand out a relaunch line for a station that was named at launch — a needless relaunch
costs a new `[ref]` and a board-row rewrite, which is how Control concludes a station has died.

**Better still, never need the repair.** Hand-starting a station with a bare `claude` costs four
things *every time*, and they compound: a **new ref** — so the board's row points at a dead address,
Control reads the station as dead and reassigns its work — plus a stale envelope, a drifting tab
title, and a row rewrite. One field fleet reached its *ninth* holder of a post this way. Start a
hand-run station the way `deploy` does:

```bash
cd '<worktree>' && claude --name '<CALLSIGN>'
```

Then identify has nothing to repair.

### Speed

`/mc` starts in **~0.3s**. It was 1.4s until 2026-08-24, and `git fetch` was 1.12s of that — a
network round trip on every invocation, including several in a row while nothing upstream had
moved. The fetch is now skipped when the remote-tracking refs are under 60 seconds old, and it
**says** it skipped rather than doing it silently. `MC_FETCH_TTL=0` forces one when you have just
been told something landed.

`/mc-config` is a standalone command that does **not** load the skill — 2 KB instead of 184 KB,
because changing one setting should not cost the whole protocol.

**Platforms — what is measured, and what is not.** Be guided by this table rather than by
optimism; the honest state matters more here than the coverage does.

| | Status |
|---|---|
| **macOS** | **Measured.** Everything: the board, worktrees, identity, tab titles, background stations, and opening a window for you in Terminal.app |
| **Linux / WSL** | **Expected to work, lightly exercised.** The scripts are ordinary POSIX shell, background mode is `claude --bg` with no host dependency at all, and the tmux path is the portable visible one. Nothing here depends on macOS except tab titles, which skip cleanly |
| **Windows, Git Bash** | **Unverified, and one specific thing is likely to break.** Finding your own session — the thing that turns a window into a station — walks the process tree with `ps -o ppid=`, and MSYS's `ps` does not implement that the way POSIX does. It **fails honestly** (`ME_PID: unknown`) rather than guessing, so the board still works; stations may need `claude --name <HANDLE>` at launch instead of self-identifying |
| **Windows, native** | **Does not run.** The scripts are bash. Use WSL |
| **The status line, anywhere** | **Works everywhere**, and degrades in one specific way. Call-signs, busy/idle, the box on your own station and the background colour need nothing but the session registry, so they are correct on every host. Telling a **tab** from its **own window** asks Terminal.app via `osascript`; anywhere else — Linux, iTerm2, tmux, a plain SSH session — the probe prints `no osascript (not macOS)`, exits clean, and those stations render in the tab colour. You lose one of three colours, never the line |
| **iTerm2 · Windows Terminal** | Window-opening recipes are shipped and **have never been run**. They say so at runtime |

**If you are the first person to run this on Windows or in iTerm2, you are genuinely the first.**
One command settles the load-bearing unknown — `bash ~/.claude/skills/mission-control/mc-init.sh me`
— and its output is worth sending back.

*Opening* a window is the only part any of this automates, and where no recipe fits it prints the
one line for you to paste. That is not a lesser path: opening a window was the only part a human
was ever doing.

---

## The idea in one minute

Each session takes a **call-sign** — ideally named after the part of the product it owns, so
hearing it tells you instantly whether it concerns you:

```
CONTROL      coordination — holds the board, writes no feature code
BACKEND      server, data, business logic
FRONTEND     UI
INTEGRATIONS outside APIs, adapters
SWEEP        not an area — whoever is making a change that crosses all of them
```

Those are defaults, not a fixed roster. **There is no ceiling on how many stations run** — a
call-sign is initiated when there is work for it and retired when that work lands, so a call-sign can
name an area (`PAYMENTS`) or a single job (`CHECKOUT-REFUNDS`). The board is the roster.

They talk in a dozen phrases you already know — these are the ones you will hear most:
**"Control to Backend"**, *go ahead*, *standby*, *roger*, *say again*, *all stations*,
*all clear*, *out*.

```
CONTROL TO INTEGRATIONS — Frontend is starting the connect screen and needs the
                          auth order. Do you hold adapters/vendor.py?

INTEGRATIONS TO CONTROL — Roger. Confirmed: credentials first, then a SECOND
                          begin-auth returns the redirect. Out.
```

Frontend got its answer without reading anyone's code, and Integrations was interrupted
**once** instead of five times.

Two shapes of work, and they need different rules:

- **Stations go down.** A station owns an area and works inside it. Two stations rarely
  collide because they touch different files.
- **Sweeps go across.** Some changes — a colour token, a renamed field, a library upgrade —
  touch files **more than one station owns**. A sweep conflicts with everyone by definition, so
  it announces itself with an estimate, waits for acknowledgement, lands fast, and calls all
  clear. **The test is ownership, not size:** a 400-file mechanical change inside one station's
  own paths is not a sweep, and announcing it as one freezes a fleet with no stake in it.

---

## What a day of real use changed

The first version was reasoned. Then three sessions ran a real job with it for a night, and the
rules that survived contact look different from the ones that did not:

- **Verify the pushed row, not the live session.** A deploy reported success against a session whose
  session had never registered. The unclaimed row is what proved it.
- **Silence is never evidence.** It does not acknowledge a sweep, release a hold, prove a station
  dead, or free a reserved post. Only an answer, a bounce, or absence from the fleet manifest does.
- **Nothing may block forever on another station answering.** Every wait carries an estimate, one
  follow-up call, and a defined move for when the answer never comes.
- **A check must be able to see what it claims to measure.** Four times in one day a check looked
  authoritative and was structurally blind — an exit code that belonged to `tail`, a name-diff
  against a run that never started, a guard reporting the wrong line, a recommendation reasoned
  from import paths about files nobody had opened.
- **The fleet manifest is not your fleet.** It lists every Claude Code session on the machine, other
  projects included. The board is the roster.
- **Rigour is not the deliverable.** Three stations produced correct audit documents when what
  was asked for was a surface to work on. A census is an input to a design tool, not one.

Each of those is a rule in the skill with a one-line reason and a pointer into
[`references/field-notes.md`](skills/mission-control/references/field-notes.md), which holds the
incident itself — for the moment a rule looks arbitrary and you are about to talk yourself out
of it.

---

## What's in the skill

`SKILL.md` holds what a station needs on post. Everything else loads only when the job calls for
it, so four stations do not each carry procedure they will never run:

| File | Read it when | Who |
|---|---|---|
| `references/control-playbook.md` | the board report, sitreps, alerting a person, recovering lost work, keeping the board small | Control |
| `references/deploying-stations.md` | putting a station on post — terminal recipes, verification, the known stalls | Control |
| `references/sweeps.md` | a change crosses areas more than one station owns | whoever runs it |
| `references/countermeasures.md` | something has already gone wrong | anyone, at the time |
| `references/field-notes.md` | a rule looks arbitrary and you want to know what it cost | anyone, rarely |
| `preflight.sh` | **before a gate, a standdown, a baseline diff, or addressing a peer** — the four checks that were got wrong by hand | anyone |
| `set-callsign.sh` | **step 1 of identify — every station runs it, always, before the board.** Makes the call-sign the address peers see | every station |
| `label-tab.sh` | called by the above — sets the tab title, and reports whether this session's launch lets it hold | every station |
| `tour-state.sh` | owns the first-run flag — offered, taken or declined. `reset` makes the tour appear again | the tour only |
| `spawn-station.sh` | at deploy — starts the station (background by default, a window on request) and reads the manifest back to check it really registered. Requires `--deploy`; starts nothing without it | Control |
| `spawn-pref.sh` | records whether you want stations in the background or in a window. Asked once, on your first deploy | Control |
| `mc-config.sh` | `/mc-config` — the preference picker, and it keeps `settings.json` in agreement with the skill's own file | Control |
| `statusline.sh` | optional, user-level — puts this repo's live stations under your prompt. Reads the session registry and the sockets; **spawns nothing** | anyone |
| `window-probe.sh` | asks the terminal which **window** each session sits in, so the line can tell a tab from its own window. `--all` refreshes the whole fleet. macOS Terminal.app; skips cleanly elsewhere | runs itself, at identify and deploy |
| `fix-header.sh` | prints the one line that repairs a wrong `@` header — `claude --name <CALLSIGN> --resume <sessionId>`, then `/mc identify`. `--for <name\|pid>` prints it for *another* station (resolving the stale name too), `--audit` says whose envelope is wrong fleet-wide | a station whose envelope is stale — or the peer that noticed |

---

## Install

```bash
git clone https://github.com/chinmaireddy09/fleet-command.git
mkdir -p ~/.claude/skills ~/.claude/commands
cp -r fleet-command/skills/*   ~/.claude/skills/
cp -r fleet-command/commands/* ~/.claude/commands/
```

**Copy `commands/` too — that line is what makes the short forms work.** A skill registers one
slash command, named after its directory: `/mission-control`, `/status-and-backlog`. The short
forms `/mc` and `/backlog` are separate command files in `commands/`, and if you skip that
directory they simply will not exist. (Earlier versions declared a `triggers:` list in the skill
frontmatter and assumed it registered aliases. It never did — nothing reads that field. The
list is gone; `commands/` replaces it.)

Skills are picked up immediately, and a newly written command file registered live in the
session that wrote it when this was last checked (2026-08-17). If a short form doesn't appear,
start a new session before assuming the install failed. Check:

```bash
ls ~/.claude/skills/mission-control/SKILL.md ~/.claude/commands/mc.md
```

Take only the ones you want; each skill directory is self-contained. To update later, `git pull`
and copy again.

**Optional, and worth it:** [the fleet status line](#see-your-fleet-under-the-prompt) puts this
repo's live stations under your prompt. It is a **user-level** setting — one `statusLine` key in
`~/.claude/settings.json`, applying to every project — not something a repo can turn on for you.

### Nothing to configure — `deploy` asks you once

`/mc deploy <station>` opens a real session on a real post: it initiates the worktree, starts the
session, has it identify itself, and **verifies the row on the base branch carries its address** —
not that something appeared on screen. Those two came apart in practice, twice.

**By default it opens nothing at all.** A station starts as a Claude Code *background agent*
(`claude --bg`): it comes up in about a second, no window, nothing typed, nothing taking your
focus. It is a full station — it appears in the fleet manifest and answers messages sent to its
call-sign. You look at it when *you* want to:

```
claude agents          every station, background and interactive
claude logs <id>       what it's showing right now
claude attach <id>     take it over in this terminal — answer a prompt
claude stop <id>       stand it down
```

Because no terminal is involved, this behaves identically everywhere: **VS Code, Cursor, Windsurf,
JetBrains, iTerm2, Terminal.app, tmux, a plain SSH session.** There is no per-IDE support matrix
any more, because there is nothing per-IDE to support.

**The first deploy on a machine asks you one question** — background, or a visible window — and
writes the answer to `~/.claude/mission-control.json`. After that it never asks again. It **asks
rather than detects**: `$TERM_PROGRAM` says where *Control* is running, which is routinely not
where you want your stations.

**And the answer is not a one-way door.** `/mc config` shows everything that is set and changes
any of it in place — the same idea as Claude Code's own `/config`:

```
/mc-config                                   # opens a picker, the way /model does
/mc config                                   # same thing, if you prefer the sub-command
bash <skill>/mc-config.sh set spawn.mode window
bash <skill>/mc-config.sh unset spawn.mode   # go back to being asked
```

It also flags **stale keys** — settings an older version wrote that nothing reads today. Harmless
where they sit, but a dead key that looks like live configuration is a question waiting to be
asked, so it gets labelled instead of silently ignored.

**Four choices, and `/mc-config` is the picker** — one question, one keystroke, like `/model`:

| | What you get |
|---|---|
| **Default** *(recommended)* | follow whatever the tool's default is — today background |
| **Tab** | a new tab in your current Terminal window (macOS Terminal.app; needs the Accessibility grant) |
| **Window** | each station in its own window |
| **Background — pinned** | no terminal, and it stays that way even if the default moves |

```
/mc-config              # the picker
/mc-config once tab     # just the next deploy, then back to your default
```

**If you pick a visible window, that is fully automated too — and it is not puppetry.** Each
terminal is driven through its own published API (iTerm2 `create tab`, Terminal.app `do script`,
`tmux new-window`, kitty, WezTerm, Windows Terminal), so the window pops up already in its
worktree, already running, already identified. Nothing is typed while you watch, and clicking away
mid-deploy breaks nothing.

**Tab mode is the one mode that touches your UI, and it says so.** Terminal.app publishes no
scriptable new-tab — measured four ways — so a tab can only come from Terminal's own **Shell →
New Tab** menu item, clicked by name. That needs the Accessibility grant. It is **not** the ⌘T
path that broke, and two things make the difference: **no chord**, so there is no modifier to
lose; and **no "selected tab"** — every tty is snapshotted before the click and the command goes
to the tab carrying a tty that was not there before. Any failure falls back to a window and says
which.

**What it will never do is fake a keypress.** Through 6.77.0 a tab was opened by synthesising ⌘T
through System Events. It failed in the field twice — once losing its modifier race so the station
ran `tcd '/path' && claude …`, and again on 2026-08-23 deploying three stations, where three tabs
came up empty and all three launch commands were typed into Control's own prompt, one of them
mangled to `ntialcd '/Users/…'`. **A host with no real API now gets no window rather than a faked
one**, and deploys in the background instead.

**Asking to deploy is what authorises the automation — and only that.** The spawn automation has
one job (open a station, get it identified) and one trigger (an explicit deploy); it is enforced
by a required `--deploy` flag rather than by good intentions. Anything short of a deploy — a post
nobody is walking to yet, a session you open by hand — **prints one command for you to paste**,
call-sign and path already filled in. The automated path prints it too the moment it cannot prove
a session registered, so you are never left with something that looks fine and no station.

**Your preference file is deliberately not in this repo.** Spawn preferences are per-person; a
clone carrying the author's terminal choice would look configured and be wrong. The repo ships the
recipes, your machine holds the choice — so a fresh clone on someone else's laptop configures
itself on their first deploy, with nothing for you to push. See
`templates/mission-control.json.example` for the shape.

| Host | Status |
|---|---|
| **background — every OS, every IDE, every CLI** | **the default, and measured end to end 2026-08-23**: registers in the manifest and answers a radio check by call-sign |
| **macOS Terminal.app — tab** | **verified end to end 2026-08-24.** Terminal's own *Shell → New Tab* menu item, clicked by name. Needs the *Accessibility* grant; falls back to a window without it |
| **any terminal — the printed command** | **verified end to end.** No permissions, no timing, nothing to mistype |
| macOS Terminal.app — window | `do script`, Terminal's own API. Needs *Automation* only |
| tmux | `new-window` — the portable visible recipe: macOS, Linux, WSL, and inside IDE terminals |
| iTerm2 · kitty · WezTerm · Windows Terminal · Linux terminals | recipes shipped, **unverified** — each says so when it uses one |
| VS Code · Cursor · Windsurf · JetBrains · anything unrecognised | **no window, never a faked one.** Deploys in the background, which needs no host |

Deploy never spawns a session with widened permissions. A new station asks you to approve its
first push — and deploy's report tells you exactly where to answer it (`claude attach <id>` for a
background station, or the window for a visible one).

---

## Uninstall

Nothing here runs as a daemon, writes outside your repo, or phones anywhere — so removal is
deleting files. **Per machine:**

```bash
# the four skills and the two short commands
rm -rf ~/.claude/skills/mission-control ~/.claude/skills/work-lock \
       ~/.claude/skills/status-and-backlog ~/.claude/skills/progress-and-log
rm -f  ~/.claude/commands/mc.md ~/.claude/commands/backlog.md

# the one preferences file, if deploy ever asked you (terminal + coordinator name)
rm -f  ~/.claude/mission-control.json
```

**Per project**, if you used the board and want it gone. **Read these before deleting — they are
the only record of what each station did:**

Run `/mc` first and read the **Board** line — it prints where yours actually lives. On a project
that keeps its board somewhere else, the paths below delete nothing and it looks like it worked.

```bash
/mc                        # read the Board path off the header, then:
rm -f <board> <board-archive> <your-MISSION-CONTROL.md>
git worktree list          # then `git worktree remove <path>` for any lane you no longer want
```

**Your progress log and your status-and-backlog file are yours, not the skill's** — whatever they
are called in your project, they outlive it, and nothing here should delete them for you.

---

## Using it

Every skill runs **only when you ask**. None of them fire on their own — deliberate, because a
coordination skill that triggers on the word "status" is worse than none.

**Getting on station**

```
/mission-control                     the board — who holds what, what's next
                                     (and this session comes on watch as Control)
/mission-control identify <name>     take a call-sign and move yourself into its workspace
/mission-control sitrep              what every station is ACTUALLY doing, vs what it claimed
/mission-control station <name>      own workspace, own test database
/mission-control checkin <task>      tell Control what you're starting, before you start
/mission-control silence / speak     go heads-down; mayday still reaches you
/mission-control state <s>           fleet state — normal | sweep running | mayday
/mission-control standdown           push, report, then close (the ack is not a gate)
```

**Talking**

```
/mission-control call <station>   ask one station one specific thing
/mission-control all-stations     ask everyone to report
/mission-control alert <who> <what>  reach a PERSON — GitHub issue, assigned, emailed
```

**`alert` is the only one that reaches a human being.** Everything else talks to Claude Code
windows on your machine. Use it to say *"I'm holding this, don't start it"* — or to hand over
something nobody owns: *"can you take this, or help?"* The second kind must say plainly that
the assignment is only so it lands in their inbox and they may unassign themselves, because an
assigned issue otherwise reads as being volunteered.

**Not colliding**

```
/mission-control depends <path>   who else touches this, and what must I know first
/mission-control sweep <change>   announce a change that crosses every area
/mission-control deploy <station> put another session on post
/mission-control go               run the tests, say plainly if it's safe
```

**When it goes wrong**

```
/mission-control countermeasures  announce it, then repair without deleting
/mission-control recover          find work a dead session left behind
```

**The other three**

```
/work-lock claim <task>           claim it, and push the claim immediately
/backlog file <finding>           file it so someone can pick it up cold
/progress-and-log                 write up the session
```

Start with `/mission-control` in a repo. It reads whatever rules the project already has, or
offers to write them.

---

## The life of a station

Six steps, and most collisions come from skipping one:

1. **Control comes on watch** — **whoever runs `/mission-control` is Control.** Initiating it
   is what puts a coordinator on watch: that session takes the call-sign, writes its own row,
   and *then* reports the board. It is not a post you deploy and wait for
2. **A new session opens** — no call-sign yet, invisible to everyone
3. **It identifies itself** (`identify [call-sign]` — **it assigns its own if you omit one**,
   and announces what it took rather than asking) — and **binds itself to the post**: it
   reads the row, takes the workspace path from it, and moves into that worktree on its own.
   You never `cd` anywhere. That step used to be the human's job, and when it was skipped the
   board claimed a station that wasn't there
4. **The call-sign goes on the board**, pushed before any code
5. **Check in before starting a task** — this is where a conflict is caught while it's cheap
6. **Hand over before closing** — push, report what's unfinished and where it's parked, wait
   for acknowledgement. *A session must not simply be closed*

---

## Things it will tell you that are worth knowing anyway

- **There is no lock in git.** Nothing stops two people editing one file. A claim board is an
  agreement — with one real exception: if two people claim the same row and both push, **the
  second push is rejected.** That is why you push a claim *before* writing code.
- **`git add -A` photographs the whole desk.** In a shared checkout it takes everyone's
  unfinished work. Name your files.
- **Naming files still doesn't save you** when two sessions edited the *same* file — saving a
  file saves all of it.
- **`git log --author` cannot tell two sessions apart** when they run as one person. The
  branch is the discriminator.
- **A finding that isn't in the repo doesn't exist.** Sessions end without warning.

---

## Testing it

```bash
bash test/e2e.sh                                    # this repo's copy
bash test/e2e.sh ~/.claude/skills/mission-control   # what is installed
```

129 end-to-end checks — a fresh project, board discovery, a station inside a worktree, deploy on
every host, the input guards, renaming against a registry the test owns, the identity surfaces.
**Every check executes something**; a syntax check is not a smoke test. Throwaway repos under
`$TMPDIR`, removed on exit; it never touches your board, starts a session, opens a terminal, relabels a tab, or
renames a live session — the rename checks build their own session registry under a fake `$HOME`,
and `osascript` **and `claude`** are stubbed suite-wide, so no tab is ever addressed and no
billable session is ever started.

**All four skills are covered.** `mission-control`'s scripts are exercised end to end; the other
three are prose, but the shell they *do* contain — the write-root / shared-root resolution that
decides which checkout gets edited — is extracted from each `SKILL.md` and run against a repo, a
linked worktree, a subdirectory, a bare repo and a non-git directory. **The blocks are read from
the files, never retyped**: a test that retypes the code under test is testing the typist.

## Troubleshooting

Every row here is a real failure that cost somebody time, and the answer is what fixed it.

| What you see | What it is | What to do |
|---|---|---|
| The tab title reverts to Claude Code's own text, or to the last turn's summary | Expected **on a session started as plain `claude`** — Claude Code rewrites the title at every status change. Measured 2026-08-22: 7 writes in one turn, ending as the turn summary | `/rename <CALLSIGN>` in that tab sticks — at the cost of the session's rename provenance. `/color` is worth more; it never lapses. A session cannot fix this for itself: argv and env are fixed at launch |
| You want tab titles that just work, without anyone typing `/rename` | Launch the session with `claude --name <HANDLE>` — what `/mc deploy` already does. Measured 2026-08-22: every title Claude Code writes then reads `<glyph> <HANDLE>`, and the turn summary never displaces it. It is plain `ESC]0;`, so it holds in iTerm2/Ghostty/tmux too | Nothing. This is why deployed stations have correct tabs and hand-started ones do not |
| A station says *"I cannot see myself, tell me my address"* and waits | It read its own `ListAgents` **self-line**, whose name is a start-time snapshot and is false after any rename. It was right not to trust it — but it did not need a peer | `bash <skill-dir>/mc-init.sh me` prints `ME_NAME` live off the session registry, and the **`[ref]` on that same self-line is correct**. Both halves are local; a peer read-back is corroboration, not rescue |
| A rename "did not sync" — the tab, the header and the self-line all still show the old name | **Nothing failed to sync.** The registry is correct the instant `set-callsign.sh` returns. Three *caches* were filled before the rename and are never recomputed | Read the five-surface table in `SKILL.md` → *Reading your own identity*. Registry and peer rows are live; self-line name, `@` header and tab title are not |
| Messages keep arriving from a station's **old** handle | The `@` header is the **sender's start-time name**, not a per-channel capture — measured 2026-08-22, a channel opened *after* a rename still carries the old name, because there is one socket per session and no per-channel handshake. Only restarting the sender clears it | Ignore the header. Resolve names through the fleet manifest and match on the `[ref]`, which survives renames |
| *"No agent named '…' is reachable"* | You replied to a from-name that has since been renamed | Re-resolve the current name and send again. This bounce is the trap working, not a broken tool |
| The board's rows all name sessions that are gone | Sessions end without cleaning up; a row outlives its holder | Run `/mc` — Control re-mans the post and rewrites dead rows. Rows are rewritten, never duplicated |
| `Read` refuses to open the board | It is over the size ceiling — usually the *working copy*, not the pushed one | Measure at the ref, using your own base branch and board path: `git show <base-ref>:<board> \| wc -c`. Then `/mc board clear` to archive done rows |
| A worktree-isolated session refuses a command | The isolation guard rejects anything it cannot statically verify stays inside the worktree — `$$`, loops, heredocs, variable-built paths | Break it into plain commands with literal arguments, or run a shipped script instead of pasting one |
| A station reports it "came up unnamed" and asks a peer | It may already know | `bash ~/.claude/skills/mission-control/mc-init.sh me` reads its own name locally. Only the `[ref]` needs a peer |
| Identify or the board feels slow | Facts are being gathered one command at a time | Run `mc-init.sh` once and branch on it. One call, ~1.3s, instead of a dozen round-trips |

## Docs

| File | What is in it |
|---|---|
| [`skills/mission-control/SKILL.md`](skills/mission-control/SKILL.md) | The skill itself — protocol, call-signs, the radio, standing orders |
| [`references/control-playbook.md`](skills/mission-control/references/control-playbook.md) | Control only — the board report, sitreps, recovery, standing a station down |
| [`references/deploying-stations.md`](skills/mission-control/references/deploying-stations.md) | Putting a station on post — terminal recipes, verification, known stalls |
| [`references/field-notes.md`](skills/mission-control/references/field-notes.md) | The measured incidents behind the rules, kept out of the hot path |
| [`references/sweeps.md`](skills/mission-control/references/sweeps.md) · [`countermeasures.md`](skills/mission-control/references/countermeasures.md) | Changes that cross every area · what to do when something went wrong |
| [`VOCABULARY.md`](VOCABULARY.md) | Every word this uses, what it is underneath, and the plain sentence to say instead |
| [`templates/`](templates/) | `MISSION-CONTROL.md` to copy into your own project, and the spawn-preferences shape |

---

## Ownership and licence

Original work by **Chinmai Reddy ([@chinmaireddy09](https://github.com/chinmaireddy09))**,
released under the **[Fleet Command License 1.1](LICENSE)** — its own licence, not a borrowed
one.

**You may** use, copy, modify, publish, distribute and sell this, including commercially. You
get an express patent licence from every contributor.

**You must** keep the notice, credit the author somewhere people actually see it, say so if you
changed it, and not imply endorsement. Break one of those and the licence lapses — you have
thirty days to fix it and it comes back.

Credit line to copy:

> Fleet Command by Chinmai Reddy (@chinmaireddy09)
> https://github.com/chinmaireddy09/fleet-command

The visible-credit condition is the whole reason this is not MIT: MIT would let the credit sit
in a file nobody opens.

**Two consequences worth knowing before you adopt it.** GitHub's sidebar will read "Other" —
unavoidable for any custom licence. And condition 2 is an added restriction, so this **cannot
be combined into GPL-licensed projects**.

The full terms are in [`LICENSE`](LICENSE); [`VOCABULARY.md`](VOCABULARY.md) is the legend for
every word this uses.
