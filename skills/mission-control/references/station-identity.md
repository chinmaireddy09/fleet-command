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

## Getting it right: start correctly, repair nothing

**`/mc deploy <CALLSIGN>` has never had any of these problems**, because it launches with `--name`.
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

**A session cannot observe its own envelope.** There is no command that shows it to you. After a
repair, a station will happily keep reporting the old value in good faith — measured: one did,
minutes after its envelope had been fixed.

*So:* never report the header as fixed on your own authority. Send one line to a peer and have them
read back the name it arrived with. That is the only observation that counts, and it costs one
message.

**The `[ref]` cannot be preserved across a relaunch.** It is a property of the process.

*So:* treat step 3 as part of the repair rather than a follow-up, and expect Control to see a
momentary death. If a station is mid-job, tell Control before you relaunch it — otherwise the
correct thing for Control to do is reassign the work, and it will.

**A running session cannot relabel its own tab reliably.** `label-tab.sh` sets the title and then
tells you the truth about whether it will survive, which on a bare `claude` is *no*.

*So:* `/rename <CALLSIGN>` typed by the human holds it — but if you are relaunching for the header
anyway, `--name` does both and `/rename` becomes unnecessary.

---

## Quick diagnosis

```bash
# Which of my stations were started correctly?
ps -o args= -p <pid>      # `--name` present → envelope and tab title are fine
```

A deployed background station shows `claude bg-spare --bg-spare …` with **no `--name`** and is
still correct — it is a pre-warmed spare that was adopted, and the name reaches it through the job
rather than the command line. Verified by peer read-back: its envelope arrives correct. Do not
infer a broken header from argv alone; that inference was made here once and was wrong.
