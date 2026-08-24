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

### The wrong name belongs to the SENDER, not to the tab you are reading it in

This is the one sentence everything else here depends on, and it is the step where this actually
goes wrong in practice.

A wrong `@` header can only ever appear in **somebody else's** tab. The station that has the fault
cannot see it; the station that can see it does not have it. So the instinct on reading
`@ wrong-name` in FINANCE's tab — *something is wrong with FINANCE* — is exactly backwards. Read
the body: if it opens `CONTROL TO FINANCE`, the envelope is CONTROL's — so CONTROL is the station
that must publish it, and FINANCE is not broken.

**Observed 2026-08-24**, on the fleet in the table below: the receiving station was restarted
instead of the sending one. It was relaunched correctly, with `--name`, so nothing broke — but it
cost a new `[ref]` (and so a `/mc identify` that would not otherwise have been needed), and it left
the actual fault exactly where it was.

*Before restarting anything, run `fix-header.sh --audit`.* It names the station by pid, from the
registry, and does not care which tab you are sitting in.

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

`/mc identify CONTROL` fixes Control's **address**. It cannot fix the envelope, and no amount of
re-identifying will.

### Control cannot be launched with `--name`, so stop treating that as the fix

`set-callsign.sh` is not merely unable to fix the envelope — **it is what breaks it.** Until that
rename, a bare session is internally consistent: its address and its envelope are both the derived
handle, and replies land. The rename moves one and freezes the other.

**But the repair that follows from that is unavailable to Control, by construction.** Control is
*whoever runs `/mc`* — the post is taken, not deployed — so at launch that session had no call-sign
to pass. `--name CONTROL` requires a decision that had not been made yet, and `deploy` never
launches Control. Two releases asked anyway (7.9.0 before the rename, 7.10.0 again at the first
deploy) and a user who hand-starts Control — the only way Control ever starts — was asked twice per
fleet for something nobody could have done.

**So the envelope is PUBLISHED, not repaired.** The preamble still reports the launch before step 1,
and the relaunch line is still computed — for `fix-header.sh`, and for a user who asks — but it is
**never volunteered**:

```
ME_LAUNCH: bare        # NO --name on this process
ME_ENVELOPE: repo-12   # frozen here for the life of the process
ME_RELAUNCH: cd '<cwd>' && claude --name 'CONTROL' --resume <sessionId>   # DO NOT VOLUNTEER
```

Two writes, both of which you are making anyway, and they cost nothing:

1. **Control's own board row** — `CONTROL · envelope repo-12`.
2. **One line in each station's first order** — *"address `CONTROL`; the name on my envelope is not
   my call-sign — do not spend a transmission reporting it back."* `spawn-station.sh` prints it at
   the first spawn.

**What that buys is the only cost the mismatch ever had.** Measured 2026-08-24 on a fleet where it
went unpublished: the next two stations each spent part of their **first transmission** reporting
the stale envelope back to Control — a fact none of them could act on. Three sessions paid for it,
and nothing bounced.

**Observed twice on one fleet, 2026-08-24, and it is the clearest argument against asking at
all.** Control was relaunched without `--name` and re-identified, twice, and came back stale each
time under a fresh birth name (`…-54`, then `…-7d`). Both relaunches were the user acting in good
faith on a notice that was correct about the fault. **Each one bought a new instance of it** —
because a relaunch that does not carry `--name` cannot help, and Control has no call-sign to carry
until `/mc` has run. Three relaunches later the envelope was still stale. Publishing it would have
cost one line the first time.

---

## Getting it right: start correctly, repair nothing

**`/mc deploy <CALLSIGN>` has never had any of these problems**, because it launches with `--name`
— but read the section above before reading that as "so the fleet is fine". It covers every
station except the one running the fleet.

If you hand-start a station, do what deploy does:

```bash
cd '<the station's worktree>' && claude --name '<CALLSIGN>'
```

**That advice is for STATIONS, and CONTROL is the one post it cannot reach.** Control is whoever
runs `/mc` — the post is taken, not deployed — so at launch there was no call-sign to pass.
`--name CONTROL` needs a decision that had not been made yet. **Never tell a hand-started Control
it should have used `--name`, and never ask it to relaunch;** publish the envelope handle on its
board row and in each station's first order instead. A person hand-starting a *station* already
knows the call-sign, so for them this genuinely is a next-time — mention it once, in passing, and
only if they are starting stations by hand.

**A bare `claude` costs four things, every time, and they compound:**

1. **A new `[ref]`.** The board's row for that call-sign now points at a dead address, so Control
   reads the station as dead and **reassigns its work.** Observed: a station's in-flight gate result
   and its next task were handed to a peer. Correctly — from outside, it had died.
2. **A stale envelope** — peers replying by name bounce. **And the bounce is the smaller half.**
   Measured 2026-08-24 on a fleet whose Control had skipped the relaunch: the next two stations to
   come up each spent part of their **first transmission** reporting the stale envelope back to
   Control — a fact none of them could act on, because only a relaunch reaches it. Three sessions
   paid for one skipped flag, and nothing bounced. `spawn-station.sh` now prints `ENVELOPE_COST:
   NOW` on the first station of such a fleet, which is the moment the cost becomes real; one line
   in that station's first order — *"address `CONTROL`; the name on my envelope is not my
   call-sign"* — is what actually prevents the round-trip.
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

Former names resolve **for this lookup**, so the only handle a peer holds — the wrong name on the
envelope — is enough to find the station.

**That is a registry read, NOT an address.** `fix-header.sh` finds the station by scanning
`formerNames` in `~/.claude/sessions/*.json`. `SendMessage` does no such thing: **a former name is
not reachable.** Measured 2026-08-24 against a probe renamed twice, and the failure has two shapes:

| Addressed | Current name | Result |
|---|---|---|
| `MCENVPROBE` | `MCENVPROBE2` | bounces, but the error **names the right session** — only because one is a prefix of the other |
| `MCENVPROBE` | `ZULU` | `No agent named 'MCENVPROBE' is reachable.` — **no suggestion at all** |

A real fleet is always the second row: a derived handle (`acme-shop-33`) and a call-sign
(`CONTROL`) share no characters, so **a peer replying to an envelope gets a dead end, not a hint.**
Which is why the mapping is published on the board and in each station's first order rather than
left for a bounce to explain. It prints that station's exact repair line to hand over, and **refuses** when
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
