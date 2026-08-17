# Fleet Command

Four skills for [Claude Code](https://claude.com/claude-code) that let **several sessions work
one repository at the same time without tripping over each other.**

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
call-sign is cut when there is work for it and retired when that work lands, so a call-sign can
name an area (`PAYMENTS`) or a single job (`CHECKOUT-REFUNDS`). The board is the roster.

They talk in a dozen phrases you already know — these are the ones you will hear most:
**"Control to Backend"**, *go ahead*, *standby*, *roger*, *say again*, *all stations*,
*all clear*, *out*.

```
CONTROL TO INTEGRATIONS — Frontend is starting the eBay screen and needs the
                          auth order. Do you hold adapters/ebay.py?

INTEGRATIONS TO CONTROL — Roger. Confirmed: credentials first, then a SECOND
                          begin-auth returns the redirect. Out.
```

Frontend got its answer without reading anyone's code, and Integrations was interrupted
**once** instead of five times.

Two shapes of work, and they need different rules:

- **Stations go down.** A station owns an area and works inside it. Two stations rarely
  collide because they touch different files.
- **Sweeps go across.** Some changes — a colour token, a renamed field, a library upgrade —
  touch *every* area at once. A sweep conflicts with everyone by definition, so it announces
  itself, waits for acknowledgement, lands fast, and calls all clear.

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

`/mc deploy <station>` opens a real session on a real post: it cuts the worktree, spawns a
terminal, has the session identify itself, and verifies it landed on the board.

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
| macOS Terminal.app | **verified** — tab and window. A tab needs Accessibility granted to Terminal |
| iTerm2 · Windows Terminal | recipe shipped, **unverified** — it will say so when it uses one |
| VS Code · Warp · Ghostty · anything else | prints the exact command to paste, call-sign and path filled in |

Deploy never spawns a session with widened permissions. A new station asks you to approve its
first push, in its own tab — and deploy's report tells you to go and do that.

---

## Using it

Every skill runs **only when you ask**. None of them fire on their own — deliberate, because a
coordination skill that triggers on the word "status" is worse than none.

**Getting on station**

```
/mission-control                     the board — who holds what, what's next
/mission-control identify <name>     take a call-sign and move yourself into its workspace
/mission-control sitrep              what every station is ACTUALLY doing, vs what it claimed
/mission-control station <name>      own workspace, own test database
/mission-control checkin <task>      tell Control what you're starting, before you start
/mission-control silence / speak     go heads-down; mayday still reaches you
/mission-control state <s>           fleet state — normal | sweep running | mayday
/mission-control standdown           push, report, get acknowledged, then close
```

**Talking**

```
/mission-control call <station>   ask one station one specific thing
/mission-control all-stations     ask everyone to report
/mission-control alert            email a human collaborator
```

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

1. **Control comes on watch** — the first session holds the board
2. **A new session opens** — no call-sign yet, invisible to everyone
3. **It identifies itself** (`identify <call-sign>`) — and **binds itself to the post**: it
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
