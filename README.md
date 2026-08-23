# Fleet Command

Four skills for [Claude Code](https://claude.com/claude-code) that let you **command a fleet of
sessions on one repository at the same time without them overwriting each other.**

Nothing to register and no limit on how many. Open a window, give it a call-sign, and it is on
the fleet; close it and it is not.

Open three windows on the same project and they will quietly ruin each other's day: one
switches branches and the files change under another; one runs `git add -A` and swallows a
third's unfinished work; two file the same finding twice; a fourth dies and takes its only
copy of something with it. Every one of those happened in a single afternoon — that afternoon
is why these exist.

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
   nobody has used before is a normal answer, not an error. That session gives itself its own
   copy of the repo (a git worktree) and moves into it on its own. You never `cd` anywhere.
4. Repeat step 3 for as many windows as you want. They do not have to be started in any order,
   and none of them waits for the others.
5. Before starting a job, run **`/mc depends <path>`** — it tells you who else is touching that
   file, so you find out before you start rather than in a merge conflict.
6. When you finish, run **`/mc standdown`** — it pushes your work, writes down what you learned,
   and hands over, so nothing dies with the window.

That is the whole loop. Everything else is for when something goes wrong.

**Requirements:** `git`, [Claude Code](https://claude.com/claude-code), and `python3` (already on
macOS and most Linux). No accounts, no services, no config file to fill in.

**Platforms.** Naming a window and everything on the board works anywhere Claude Code runs.
*Opening* a new window for you is automated on macOS Terminal.app, in tmux (which covers Linux,
Windows via WSL, and inside VS Code's terminal), and in Windows Terminal. Anywhere else it prints
the one line for you to paste — which is not a lesser path, because opening a window was the only
part a human was ever doing.

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

- **Verify the pushed row, not the live session.** A deploy reported success against a tab whose
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
| `spawn-station.sh` | at deploy — opens the tab in *your* window and verifies a session really started | Control |

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

### Nothing to configure — `deploy` asks you once

`/mc deploy <station>` opens a real session on a real post: it initiates the worktree, opens a
terminal tab, has the session identify itself, and **verifies the row on `origin/main` carries
its address** — not that the tab looks right. Those two came apart in practice: a spawn once
reported success and left a tab whose session had never registered at all.

**Asking to deploy is what authorises the automation.** `/mc deploy X` means *put X on post
without me typing anything*. Anything short of that — initiating a post nobody is walking to yet,
or a session you open by hand — **prints one command for you to paste instead**, call-sign and
path already filled in. And the automated path prints it too the moment it cannot prove a session
started, so you are never left with a tab that looks fine and a station that does not exist.

That means it has to know **your** terminal, and everyone's differs. The first time you run it,
it detects what you're on (`$TERM_PROGRAM`, `$WT_SESSION`, `uname`), **confirms it with you**
along with whether you want a tab or a window, and writes the answer to
`~/.claude/mission-control.json`. After that it never asks again. See
`templates/mission-control.json.example` for the shape.

**That file is deliberately not in this repo.** Spawn preferences are per-person; a clone
carrying the author's terminal choice would look configured and be wrong. The repo ships the
recipes, your machine holds the choice — so a fresh clone on someone else's laptop configures
itself on their first deploy, with nothing for you to push.

| Terminal | Status |
|---|---|
| **any terminal — the printed command** | **verified end to end.** No permissions, no timing, nothing to mistype |
| macOS Terminal.app — tab | works, and **failed twice in the field before being rewritten**: a synthesised ⌘T lost its modifier race and corrupted the command, and the keypress landed in whichever window had focus. Now targets its own window by tty and checks a real session started. Needs Accessibility |
| iTerm2 · Windows Terminal | recipe shipped, **unverified** — it says so when it uses one |
| VS Code · Warp · Ghostty · anything else | prints the command, which is the default anyway |

Deploy never spawns a session with widened permissions. A new station asks you to approve its
first push, in its own tab — and deploy's report tells you to go and do that.

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

```bash
rm -f docs/WORK-LOCKS.md docs/WORK-LOCKS-ARCHIVE.md docs/MISSION-CONTROL.md
git worktree list          # then `git worktree remove <path>` for any lane you no longer want
```

**`docs/PROGRESS-LOG.md` and `docs/PROJECT-STATUS-AND-BACKLOG.md` are yours, not the skill's** —
they outlive it, and nothing here should delete them for you.

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

119 end-to-end checks — a fresh project, board discovery, a station inside a worktree, deploy on
every host, the input guards, renaming against a registry the test owns, the identity surfaces.
**Every check executes something**; a syntax check is not a smoke test. Throwaway repos under
`$TMPDIR`, removed on exit; it never touches your board, opens a terminal, relabels a tab, or
renames a live session — the rename checks build their own session registry under a fake `$HOME`,
and `osascript` is stubbed suite-wide so no tab is ever addressed.

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
| `Read` refuses to open the board | It is over the size ceiling — usually the *working copy*, not `origin/main` | Measure at the ref: `git show origin/main:docs/WORK-LOCKS.md \| wc -c`. Then `/mc board clear` to archive done rows |
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
| [`CHANGELOG.md`](CHANGELOG.md) | What changed, and the failure that forced each change |
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

See [`ATTRIBUTION.md`](ATTRIBUTION.md) for the conditions in plain words, and
[`VOCABULARY.md`](VOCABULARY.md) for the full legend.
