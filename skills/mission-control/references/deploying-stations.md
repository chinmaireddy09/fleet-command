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

**2 · Spawn the session** — in whatever terminal *this* user actually runs, the way *they* want
it. Everyone's machine differs: macOS Terminal, iTerm2, VS Code, Windows Terminal, a Linux
terminal. **Ask once, remember it, never ask again.**

#### Read the config first, and write it if it isn't there

**`~/.claude/mission-control.json`** — per-machine, user-level:

```json
{ "spawn": {
    "platform": "darwin", "terminal": "Apple_Terminal",
    "placement": "tab", "launchCommand": "claude", "permissionMode": null } }
```

`launchCommand` is the **bare binary only**. `deploy` appends `--name "$CALLSIGN"` and the
identify prompt itself — do not bake either into the config, or every station on this machine
spawns wearing one call-sign.

**This file must never live in the repo.** Preferences are per-person: a clone carrying the
author's terminal choice is the same class of bug as a workspace missing its gitignored
`CLAUDE.md` — it looks configured and is wrong. **The repo ships the recipes; the machine
holds the choice.** That is also the whole answer to "make it work for whoever clones this":
there is nothing to push, because the first `deploy` on their machine configures itself.

On `deploy`:

1. **Config exists** → use it, no questions.
2. **No config** → detect, then **ask, then write it**:

   | Signal | Means |
   |---|---|
   | `$TERM_PROGRAM=Apple_Terminal` | macOS Terminal.app |
   | `$TERM_PROGRAM=iTerm.app` | iTerm2 |
   | `$TERM_PROGRAM=vscode` | VS Code integrated terminal |
   | `$TERM_PROGRAM=WarpTerminal` / `ghostty` | Warp / Ghostty |
   | `$WT_SESSION` set | Windows Terminal |
   | `uname -s` = `Darwin` / `Linux`; `$OS=Windows_NT` | the platform underneath |

   Then **one** `AskUserQuestion`: tab or window, and confirm the detected terminal. Write the
   answer to the config and carry on. **Detection alone is not consent** — a detected terminal
   still gets confirmed once, because `$TERM_PROGRAM` says where *Control* is running, not where
   the user wants stations to appear.

#### Always spawn with `--name <CALLSIGN>`

**Every recipe below passes `claude --name "$CALLSIGN"`, and none of them is optional.** That
flag sets the session's display name, which is simultaneously:

- what **the fleet manifest shows other stations**, so the call-sign *is* the `SendMessage` address;
- what the **user sees on that window's prompt box** and terminal title, so they can tell four
  identical windows apart at a glance;
- what the station **knows about itself** — narrowing the bootstrap trap described under *Who is
  who*. **It no longer closes it, because the trap is no longer there to close:** since 6.34.0 a
  session reads its live name off the registry (`mc-init.sh me`) and its correct `[ref]` off its
  own `ListAgents` self-line, so even a hand-started station can fill in its own row honestly.
  What `--name` still buys is agreement from the first instant rather than agreement derived a
  step later.

**Verified 2026-08-17:** a session spawned `--name TESTRIG-CALLSIGN` appeared to its peers as
`TESTRIG-CALLSIGN [eefa7c]`. Without the flag the same session would have listed as
`acme-shop-4d [9a7a96]` — an address nobody can remember, say aloud, or match to a row.

Pass the call-sign in **exactly the form the board uses** — same case, same spelling. `INTEGRATIONS`
on the board and `channels` in `ListAgents` is a directory that fails at its one job.

#### The recipes

**macOS Terminal.app — verified 2026-08-17.** A tab needs `System Events` to press ⌘T, which is
*Accessibility*, a **different** grant from the *Automation* one `do script` uses. Capture the
tab ⌘T just made and write into **that reference** — never `in front window`, which opens
another window instead:

**Both paths exist, and which one you get is decided by what was asked for.**

```bash
bash <skill-dir>/spawn-station.sh INTEGRATIONS "$WT"            # deploy: opens the tab and types it
bash <skill-dir>/spawn-station.sh INTEGRATIONS "$WT" --print    # prints the command to paste
```

| The ask | What happens |
|---|---|
| **`/mc deploy <station>`** | **Automated.** Asking to deploy *is* the authorisation — it means "put it on post without me typing anything." Tab opens, command runs, row is verified |
| **`/mc station <name>`** | **Printed.** A post is initiated with nobody walking to it yet, so there is nothing to automate |
| **A session coming up by hand** | **Printed.** Nobody asked for a spawn |
| **The automated path cannot finish** | **Printed automatically**, on top of the failure report — you are never left with nothing to act on |

**The automation stayed; what changed is that it no longer trusts itself.** Its two 2026-08-17
failures were not caused by automating — they were caused by automating *blind*:

1. **`keystroke "t" using command down` synthesises the same keypress a finger makes**, and only
   the synthetic one can lose its modifier race. It did: the bare `t` reached the shell and the
   station ran `tcd '/path' && claude …`.
2. **A synthetic keypress goes wherever focus is**, so the station's tab opened in an unrelated
   window — the same `front window` bug already fixed for tab-labelling.

So it now **targets its own window by tty**, **checks a `claude` process is really running in the
new tab**, and **prints the paste-able command whenever it cannot prove that** — including when
`osascript` exits 0 while its script returned `FAILED:`, which it does.

**A note on the inherited directory:** a new tab does inherit the current one's working
directory (Terminal's default), but it inherits **the spawner's** — Control sits in the repo root
while the station belongs in `.claude/worktrees/<station>`. **So the leading `cd` is required
whoever opens the tab.**

**Three things it fixes, all of which happened on 2026-08-17 in one deploy:**

1. **`keystroke "t" using command down` is a race, and losing it corrupts the command.** The
   modifier failed to register, the bare `t` reached the shell, `do script` appended to that
   same line, and the station tried to run **`tcd '/path' && claude …`**. `zsh: command not
   found: tcd`, nothing else ran, and the deploy reported only that the station never came up.
2. **`front window` is whichever window has FOCUS** — someone else's. The station's tab opened
   in an unrelated window, and Terminal then titled it with *that* window's directory, so a
   station working `acme-shop` advertised a different project in its title bar. **This is the
   identical bug already fixed for tab-labelling**; the lesson was learned there and never
   carried across. The script resolves its own window by tty and focuses that one.
3. **It never read the tab back.** `label-tab.sh` has read its result back since it shipped;
   this had no equivalent, so both failures above were invisible. The script now checks
   `processes of tab` for a live `claude` and, when it is missing, returns the scrollback tail —
   which is where `command not found` is already written down.

**Verified 2026-08-17** that both readback hooks exist in Terminal's AppleScript: `processes of
tab` returns e.g. `login-zshclaudemcp@latestnodecaffeinate`, and `history of tab` returns the
scrollback.

Missing Accessibility fails with `osascript is not allowed to send keystrokes. (1002)`; match on
that and fall back to a window. **Say which one you got** — a window when they asked for a tab
is not a silent detail — and give the path: *System Settings → Privacy & Security →
Accessibility → enable Terminal*, then restart Terminal.

**iTerm2 — recipe shipped, NOT verified.** `tell current window to create tab with default
profile`, then `write text` into `current session` — the same `cd … && claude --name '$CALLSIGN'
'/mc identify $CALLSIGN'` string as above. Say it is untested when you use it.

**Windows Terminal — recipe shipped, NOT verified.**
`wt -w 0 nt -d "<worktree>" cmd /k claude --name "<CALLSIGN>" "/mc identify <CALLSIGN>"`.

**VS Code — there is no recipe, and do not invent one.** Nothing outside the editor can open its
integrated terminal reliably. Use the fallback.

**The fallback is not a failure.** For any terminal you cannot drive — VS Code, Warp, Ghostty,
an unknown `$TERM_PROGRAM`, a missing grant — **print the exact command and let the human paste
it**:

```
Can't drive VS Code's terminal from outside. Open a terminal and paste:
  cd '<worktree>' && claude --name 'INTEGRATIONS' '/mc identify INTEGRATIONS'
```

That still beats the old flow, because the call-sign and path are filled in and cannot be
mistyped. **Never guess AppleScript or PowerShell for a terminal you cannot see.**

**Keep `--name` in the pasted command too.** It is the easiest thing to drop when a human is
copying by hand, and dropping it is silent — the station comes up, works fine, and is simply
unaddressable by its call-sign until someone reads its handle back to it over the radio.

#### Two traps that already cost a session

**A slash command DOES execute when passed as the CLI prompt** — measured 2026-08-17, `claude -p
"/some-command"` runs it rather than treating it as text. So `claude '/mc identify X'` is sound;
if a station fails to identify, the launch is not the reason. Look at the permission prompt.

**Do not verify a tab by counting tabs.** `count of tabs of window` cannot see macOS window
tabs — each is a *separate window* reporting exactly `1` tab, so a spawn that lands as a tab
reads as "a new window" through that API. On 2026-08-17 that cost four probes and a wrong
conclusion: Accessibility was already granted, tabs *were* appearing, and the measurement said
otherwise. **The user's screen is the instrument.** Report which call succeeded, and ask what
they see rather than counting. Check your checks: confirm the identifier identifies what you
think it does.

**Yes, deploy runs `cd` — that does not contradict the rule above.** The rule is that a *human*
must never be the one to remember it, because when they skip it the post stays empty and the
board lies. A script cannot forget. And `identify` still checks its own directory in step 3, so
it is correct either way.

**3 · Let the session identify itself.** It comes up already inside the lane, runs `identify`,
takes the row, and writes its own address onto it — which, because you spawned it
`--name <CALLSIGN>`, it already knows without having to ask anyone.

**4 · Verify — and this is the step that matters.** Poll `ListAgents` until **the call-sign
appears as a session name** — that is the confirmation the `--name` took — then **read the board
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
| **The command never ran** | The tab exists and sits at a plain shell prompt, with an error in the scrollback. Nothing is listed, because no session was ever started. **This is the cause that was missing on 2026-08-17**, when a mangled `cd` meant the four causes above were all wrong and Control had to ask a human what was on screen |
| **Spawned but never registered** | `osascript` reported success and named the tab, and **no session ever appeared** — no process, no socket, nothing to stall. It did not hang; it never came up. Measured 2026-08-18 |

**Two outside measurements are free and decisive — take them BEFORE you ask.**

```bash
pgrep -f "claude --name <CALLSIGN>"   # is the process alive?
ls /tmp/cc-socks/                     # is there a <PID>.sock for it?
```

**Verified 2026-08-18:** each live session holds `/tmp/cc-socks/<PID>.sock`, and a station
spawned `--name FRONTEND` appeared as both a matching process and its socket. That gives a clean
three-way split:

| What you measure | What it means | What to do |
|---|---|---|
| process **and** socket | it is up and registered | it is a `ListAgents` or board problem, not a spawn one |
| process, **no socket** | alive but not registered — sitting at a prompt or a dialog | **ask the user what is on that tab** |
| **no process** | it never started, or it died | re-spawn; retrying is safe by design |

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

**When it IS the prompt, end the deploy report by sending the user to the tab:**

```
INTEGRATIONS is up in a new tab. Switch to it and approve the push — until you do,
it can't claim its row and no other station can call it.
```

Deploy **surfaces** this; it does not solve it. **Never spawn with a bypassed permission mode to
make the prompt go away.** Control does not widen another session's permissions for its own
convenience — that is the user's setting, in their own config, chosen deliberately.

**If verification fails, say the deploy failed.** A spawned session that never identified is
worse than no deploy at all — there is now a live window nobody can address, holding a post the
board still shows as reserved. Report it, say which tab it is in, and let the user decide.

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
- **Two separate macOS grants, and they fail differently.** *Automation* lets you open a window;
  *Accessibility* lets you open a tab. Having the first tells you nothing about the second —
  observed 2026-08-17: the window spawned with no dialog at all, and the tab failed outright
  with `not allowed to send keystrokes (1002)`. If a spawn fails before *any* dialog appears,
  suspect the sandbox rather than macOS, and surface it instead of trying variations.

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

