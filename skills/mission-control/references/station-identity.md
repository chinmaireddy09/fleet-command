# Station identity — the three surfaces, and which of them you can fix

**Read this before you hand-start a station, and again the first time a peer says it cannot reach
you.** A station has *three* identities, they are set at three different moments, and fixing one
does not touch the others. Almost every identity complaint against this skill has been somebody
who fixed one and reasonably assumed they had fixed all three.

Everything here was measured on Claude Code 2.1.241 on 2026-08-24, against a live five-station
fleet. Where a number appears, it came off that fleet.

---

## The three surfaces

| Surface | What it is | Set when | Fixed by |
|---|---|---|---|
| **The address** | the name peers *resolve* — what `ListAgents` shows, what `SendMessage` targets | any time | `set-callsign.sh` / `/mc identify`. **Live.** |
| **The tab title** | what the terminal tab says | every status change | `--name` at launch, or a human typing `/rename` |
| **The `@` header** | the name stamped on every message this session *sends* | **process launch, once** | `--name` at launch. **Nothing else.** |

The trap is that the first is live and the third is frozen. `set-callsign.sh` genuinely fixes the
address, prints success, and every word of it is true — while the envelope on your next message
still carries the name your process was born with.

**Measured:**

```
registry name after set-callsign.sh SKILLDEV : SKILLDEV
that session's own ListAgents self-line      : fleet-command-fd   ← unchanged
the same registry, read for a PEER           : correct, live
```

---

## The `@` header is not cosmetic

A peer that replies to the name it received gets **`No agent named '…' is reachable`**. It reaches
you only via the `[ref]`, which survives every rename.

That is why a station with a stale envelope ends up writing *"resolve me through ListAgents"* into
every message it sends. It is not being fussy; it is routing around a real delivery failure.

---

## Control is the station this bites, and it is not an edge case

**`/mc deploy` never launches Control.** Control is whoever ran `/mc` — in whatever session they
were already sitting in, which is a bare `claude` started by hand before there was any fleet to
name. Every station deploy starts is correct on all three surfaces. The coordinator is the one
station that was never deployed, so it is the one station that starts wrong *by default*.

Measured on a three-station fleet, 2026-08-24, with nothing done incorrectly by the user — they
deployed both stations and ran `/mc identify CONTROL`:

```
pid 11187  CHANNELS   deployed   nameSource absent    envelope  CHANNELS       ✓
pid 13590  FINANCE    deployed   nameSource absent    envelope  FINANCE        ✓
pid  1170  CONTROL    hand-run   nameSource=user      envelope  acme-api-54    ✗
                                 formerNames=['acme-api-54']
```

The third row is what a peer actually saw: `@ acme-api-54` stamped on a message whose body
opened `CONTROL TO FINANCE`.

**It is the worst station to have it on.** Control sends more messages than anyone, and Control's
messages are the ones stations reply *to* — so a stale envelope on the coordinator costs a bounce
on the fleet's busiest edge, and it costs it every time.

`/mc identify CONTROL` fixes Control's **address** and prints the relaunch line unprompted. It
cannot fix the envelope, and no amount of re-identifying will.

---

## Getting it right: start correctly, repair nothing

**`/mc deploy <CALLSIGN>` has never had any of these problems**, because it launches with `--name`
— but read the section above before reading that as "so the fleet is fine". It covers every
station except the one running the fleet.

If you hand-start a station, do what deploy does:

```bash
cd '<the station's worktree>' && claude --name '<CALLSIGN>'
```

**A bare `claude` costs four things, every time, and they compound:**

1. **A new `[ref]`.** The board's row for that call-sign now points at a dead address, so Control
   reads the station as dead and **reassigns its work.** Observed: a station's in-flight gate result
   and its next task were handed to a peer. Correctly — from outside, it had died.
2. **A stale envelope** — peers replying by name bounce.
3. **A drifting tab title** — the turn summary overwrites it at the next boundary.
4. **A row rewrite**, and a predecessor record. One post reached its **tenth holder in a day** this
   way, and the board crossed its ~100 KB ceiling twice — the churn inflates the file it writes to.

None of the four is visible from inside the session that caused them.

---

## Repairing a station that is already wrong

Three steps. **Two of them is worse than none**, because you end up correct on every surface a peer
can see and dead on the board.

```bash
# 1. quit Claude in that tab (Ctrl+C twice, or /quit)
# 2. relaunch — --name fixes the envelope AND the tab title, --resume keeps the conversation
cd '<worktree>' && claude --name '<CALLSIGN>' --resume '<sessionId>'
# 3. in the new session:
/mc identify <CALLSIGN>
```

`fix-header.sh` prints steps 2 and 3 with the cwd, call-sign and session id already filled in, so
none of them can be mistyped. `/mc identify` prints it too, unprompted, whenever the session it runs
in was launched without `--name`.

**A peer can print it for a station that cannot see its own fault** — which is how this is normally
noticed, since the envelope is only visible to the receiver:

```bash
fix-header.sh --for CONTROL              # by call-sign
fix-header.sh --for acme-api-54    # by the stale name you read on the `@` header
fix-header.sh --for 1170                 # by pid
```

Former names resolve, so the only handle a peer holds — the wrong name on the envelope — is enough
to find the station. It prints that station's exact repair line to hand over, and **refuses** when
the registry says the station was named at launch, because a needless relaunch costs a new `[ref]`
and a board-row rewrite. `fix-header.sh --audit` answers the same question for the whole fleet at
once — see [Quick diagnosis](#quick-diagnosis).

**Step 3 is not optional.** `--resume` keeps the conversation and the session id, and the relaunched
*process still gets a new `[ref]`*:

```
before relaunch   CHANNELS [a1c4e2]
after  relaunch   CHANNELS [7f0b93]     same sessionId, same conversation
```

`identify` rewrites the board row in place with the new ref. It does not duplicate it.

**For a background station, keep `--bg`** — the line is pasted verbatim, and dropping it silently
converts a background agent into a tab session.

---

## What this still cannot do, and what to do instead

**A session cannot observe its own envelope directly.** Nothing in the process reports it, and after
a repair a station will happily keep quoting the old value in good faith — measured: one did,
minutes after its envelope had been fixed.

*Partly closed:* the registry keeps `formerNames`, and the envelope is the name the process was born
with, so `fix-header.sh` now prints it — for yourself or, with `--for`, for a peer. That is a read of
what the launch *should* have produced, from a field measured to match the observed envelope once.

*So:* it is a strong check, not a proof, and it does not change the rule. **Never report the header
as fixed on your own authority.** Send one line to a peer and have them read back the name it
arrived with. That is still the only direct observation, and it costs one message.

**The `[ref]` cannot be preserved across a relaunch.** It is a property of the process.

*So:* treat step 3 as part of the repair rather than a follow-up, and expect Control to see a
momentary death. If a station is mid-job, tell Control before you relaunch it — otherwise the
correct thing for Control to do is reassign the work, and it will.

**A running session cannot relabel its own tab reliably.** `label-tab.sh` sets the title and then
tells you the truth about whether it will survive, which on a bare `claude` is *no*.

*So:* `/rename <CALLSIGN>` typed by the human holds it — but if you are relaunching for the header
anyway, `--name` does both and `/rename` becomes unnecessary.

---

## What works where

Nothing in this document is macOS-only except one colour.

| | |
|---|---|
| **The address, the `@` header, `--name`, `--resume`, `/mc identify`** | Every host. These are Claude Code's own mechanisms; no terminal is asked anything. |
| **The status line** — call-signs, busy/idle, your own station boxed, the background colour | Every host. Read from the session registry alone. |
| **Tab title labelling** (`label-tab.sh`) | Terminal.app. Elsewhere it skips cleanly and says so. `--name` still puts the call-sign in the title on iTerm2, Ghostty and tmux, because that is plain OSC. |
| **Telling a tab from its own window** (`window-probe.sh`) | Terminal.app, via `osascript`. Anywhere else it prints `no osascript (not macOS)` and exits 0, and those stations render in the tab colour. |

So on Linux, iTerm2 or tmux you lose **one of three colours** and nothing else. A station is still
named, still coloured for background-vs-visible, still boxed when it is yours.

---

## Quick diagnosis

```bash
fix-header.sh --audit      # whose envelope is wrong, across the whole fleet
```

```
pid      call-sign    envelope
11187    CHANNELS     OK        named at launch
1170     CONTROL      STALE     peers see `acme-api-54`
13590    FINANCE      OK        named at launch
67952    tooling-17   UNNAMED   no call-sign (nameSource=derived)
```

It reads the session registry rather than argv, because the registry answers directly. Measured
2026-08-24 across four live sessions on 2.1.241:

| `nameSource` | means | envelope |
|---|---|---|
| *absent* | the name was set at **launch**, by `--name` | correct |
| `derived` | never named — the name is the auto one | matches the address, so replies land |
| `user` | renamed **after** launch, by `identify` | **stale** — it is `formerNames[0]` |

`formerNames[0]` and not `[-1]`: the envelope froze at launch, so the value peers see is the name
the process was *born* with. Only the single-rename case has been measured, where the two coincide.

The older recipe was `ps -o args= -p <pid>`, looking for `--name`. **Do not rely on it.** A deployed
background station shows `claude bg-spare --bg-spare …` with no `--name` and is still correct — it
is a pre-warmed spare that was adopted, and the name reaches it through the job rather than the
command line. Verified by peer read-back: its envelope arrives correct. That inference was made here
once from argv alone and was wrong.

The registry signature of an **adopted bg spare has not been measured**. If a verdict here concerns
one, treat it as unproven and get a peer read-back instead.
