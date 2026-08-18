## Stations go down. Sweeps go across.

A **station** owns an area and works inside it. Two stations rarely collide, because they
touch different files.

But plenty of real work does not fit inside one area — upgrading a library, renaming a shared
model, applying a design system to every screen, a security pass. That work **crosses every
area at once**. Call it a **sweep**.

|  | **Station** (down) | **Sweep** (across) |
|---|---|---|
| Owns | a set of paths | a *change*, not paths |
| Touches | its own area | files other stations own |
| Conflicts with | rarely anyone | **everyone, by definition** |
| Lives | as long as the work | should be **as short as possible** |
| Claims | a lane | **time**, plus every station's acknowledgement |

**The test:** *does this change touch files owned by more than one station?* If yes, it is a
sweep, and the rules below apply. If no, it is ordinary station work.

### The rule that keeps this sane

**Stations have right of way. A sweep has to ask.** A sweep may not simply start editing
another station's files because its change is "small" or "mechanical" — that is exactly how one
session's work ends up inside another's commit.

### Running a sweep

**1 · Announce it before touching anything.** All stations, with a real time estimate:

```
SWEEP TO ALL STATIONS — Standby. Renaming `Order.total` to `Order.total_minor`
               across every module. Touches ~40 files in backend, frontend and
               integrations. Mechanical, no logic change. Expect 20 minutes.
               Please don't commit in those paths until I call all-clear.
               Acknowledge when ready. Out.
```

**2 · Wait for every live station to acknowledge.** A station that is mid-edit in an affected
file says **standby** and finishes first. A sweep that starts before acknowledgements is how
work gets lost.

**But the wait is bounded, because otherwise one busy station can stop a sweep forever** — and
the larger the fleet, the likelier that is. Say when you need the answers by, in the same breath
as the estimate: *"acknowledge in the next few minutes."* Then, for anyone still silent:

1. **Re-check who is actually live.** A station absent from the fleet manifest was never owed an ack —
   it is gone, and that is a recovery job, not a sweep blocker.
2. **Call the silent station once, directly.** Broadcasts are easy to miss; a call is not.
3. **Still silent → you may not sweep its paths.** Silence is not an acknowledgement, and it
   never becomes one by waiting. That rule has teeth and keeps them.
4. **Then pick, out loud** — and which one is available depends on the change, not your patience:
   - **Narrow the sweep** to the paths whose owners acknowledged, *only if what you leave behind
     still stands up on its own.* Say exactly which paths you excluded and why, so the gap is
     deliberate and visible rather than discovered later.
   - **A change that cannot be split — a rename, a signature change, anything where half is
     broken — cannot be narrowed.** Then the only moves are keep waiting or **put it to the
     user**, and the user is usually the faster answer.

**When you put it to the user, say which tab is asking and whether another tab is holding the
same question.** The user is one person across every window, so a yes collected in one tab is
not evidence that the other tab's ask was seen. **Never resolve a standoff with "whoever gets
approval first proceeds"** — both stations comply, the same person authorises twice, and neither
yes was informed. SKILL.md, *One human, many tabs*.

**Never proceed over a silent station because it is "probably fine."** That is the one failure
this step exists to prevent, and it stays forbidden no matter how long you have waited.

**3 · Pick the mode that fits:**

| Mode | When | How |
|---|---|---|
| **Fast sweep** | mechanical, minutes, no judgement calls | everyone holds, you sweep, land it, call all-clear. **Land it fast — the longer it stays open, the more it collides** |
| **Rolling sweep** | long, needs judgement per area | go area by area. Call each station as you reach it, take only that slice, hand it back when done. Stations keep working everywhere else |

**Prefer fast.** If a sweep can't be done in one short pass, it is usually better split into
per-area jobs that each station does inside its own lane — then it stops being a sweep at all.

**4 · Only one sweep at a time.** Two sweeps crossing each other is unrecoverable. If a sweep
is running, the next one waits.

**5 · Call all-clear when it lands.**

```
BACKEND TO SWEEP      — Roger, standing by. I have uncommitted work in
                        orders/models.py — give me two minutes. Standby.
BACKEND TO SWEEP      — Committed and pushed. Go ahead.

SWEEP TO ALL STATIONS — All clear. Order.total is now total_minor everywhere,
                        pushed to main. Pull before you continue. Out.
```

**6 · Put it on the board as a sweep**, not a station row — so it is obvious it crosses
everything and when it ends:

```
| SWEEP: rename Order.total → total_minor | crosses all | started 14:05, est 20 min | acknowledged: backend, frontend |
```

### The hold has an expiry, and it is the estimate you announced

**The estimate in step 1 is not decoration — it is how long the fleet has agreed to hold**, which
is why the board row carries it. A sweep that blows through it owes every held station a revised
one, *before* it lapses: one line, "still going, another fifteen." That is the same bargain radio
silence runs on, and it costs less than one station guessing.

**What a held station does when all-clear never comes** — because every rule above points at the
sweeper, and a station frozen by a sweep that died had nothing to follow:

1. **The estimate passes → call the sweep once.** Not twice.
2. **It answers** → take the new estimate and keep holding.
3. **It bounces, or stays silent after that one call** → the sweep is gone, and **its change is
   half-landed until proven otherwise.**
4. **Do not simply resume committing.** `git fetch`, then look at what actually landed in the
   affected paths. A rename that reached three modules of five leaves the tree building in some
   places and broken in others, and committing into that is how a dead sweep becomes an
   unrecoverable one.
5. **Lift your own hold out loud** — all stations, saying the sweep is gone, what you found in
   the paths, and that you are releasing. **Never lift silently.** The fleet is holding because
   it heard *standby*; it can only stop holding if it hears something.
6. **Then tell Control and the user.** A dead half-landed sweep is a countermeasures situation,
   not a station-level cleanup.

**A hold with no expiry is the failure this skill names on its own front page** — *a standby
nobody lifts freezes the whole fleet.* Closing the loop is still the sweeper's job. This is only
what to do when the sweeper cannot.

---

