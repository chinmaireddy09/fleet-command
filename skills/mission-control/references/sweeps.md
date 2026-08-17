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

---

