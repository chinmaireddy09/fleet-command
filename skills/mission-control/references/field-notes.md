# Field notes — the incidents behind the rules
**Read this when a rule looks arbitrary and you want to know what it cost.** Nothing here is
procedure; every entry is something that actually happened, kept because *a rule whose reason has
been deleted is the first one somebody talks themselves out of.* The rules themselves live in
`SKILL.md` with a one-line reason and a pointer here.

---

## 1 · A correct observation carrying a wrong conclusion

Measured 2026-08-18, and it is the clearest case this skill has: a station reported that
  one adapter's `begin_auth` reads a model field that does not exist, and concluded the CSRF defence
  had shipped as a no-op. **Control confirmed the first half exactly** — no field, no migration
  anywhere — **and the conclusion was wrong, in the direction that produces a bad fix.** State
  is decoded and verified for every channel before a connection resolves, returning 401; the
  system is fail-closed, not open. The real consequence was narrower and worse for the user:
  **every eBay connect attempt dies at the callback**, because the state sent is empty and comes
  back falsy. And the fix inverted with the diagnosis — not a model field and a migration, but
  **one line** calling the HMAC state helper its sibling adapters already use.

  **Verifying changed the diagnosis and the fix, and the wrong version was a schema change.**
  That is the whole reason this rule exists.

---

## 2 · Three checks agreed a lane was green while nothing ran

Measured 2026-08-18, all three of those agreed a lane was
green while **not one test had executed**:

- **The exit code belonged to the wrong command.** `npx vitest run > log 2>&1; echo "EXIT=$?";
  tail -20 log` reports **`tail`'s** status, because a shell reports the *last* command's. Proved
  directly: `false; echo "EXIT=$?"; tail -1 /etc/hosts` prints EXIT=1 and still exits 0 overall.
  The runner's real exit was 1 the whole time and nothing read it.
- **A startup error emits zero FAIL lines.** Nothing ran, so nothing failed.
- **So the name diff returned `0 new, 0 fixed`** — the exact signature of a clean run.

**Capture the status of the command you care about, immediately**: `npx vitest run > log 2>&1;
RC=$?` before anything else touches `$?`. Then read the count. **A gate with no test count is not
a gate result, whatever colour it reports.**

---

## 3 · A standing hold whose hazard inverted

Measured 2026-08-18: *"never sync this lane — syncing deletes 776
lines silently"* sat on a board for two days as the most dangerous item on it. Then the reverted
work re-landed on `main` and **the hazard inverted**: a fast-forward would now *restore* the
change rather than destroy it, and the warning had quietly become wrong. Nothing prompted anyone
to notice — it was caught only because someone re-measured after verifying an unrelated merge.

---

## 4 · Named, and unable to tell

Observed 2026-08-17: a station spawned `--name FRONTEND` reported
*"I came up unnamed and cannot see myself in ListAgents"* and spent a radio round-trip asking
Control for an address it already had. It was not unnamed; it just could not tell — because
**named and unnamed sessions look identical from inside `ListAgents`, which shows neither.**

**Read your own launch arguments instead.** Walk the parents to the `claude` process — the same
walk `label-tab.sh` does for the tty — and the `--name` is sitting right there:

```bash
ps -o args= -p <the claude pid>
```

**Measured 2026-08-17:** a deployed station printed `claude --name FRONTEND /mc identify FRONTEND`;
a hand-started one printed a bare `claude`. So **before you tell anyone you came up unnamed,
check** — the answer is local, free, and needs no peer.

---

## 5 · Coming back to a world that had ended

Observed 2026-08-17: a station went quiet holding two things it intended to file — an unpushed
data-loss risk, and "the Docker daemon is down, so no station can gate." By the time it came back
the history had been pushed and the stack was up with a gate mid-run. **Both items would have
described a problem that no longer existed.** It was caught only because it announced its
intentions before acting.

---

## 6 · ListAgents is the whole machine, not your fleet

**Measured 2026-08-17, in this repo:** a session working `fleet-command` ran `ListAgents` and the
only peer it saw was `acme-shop-f3 [6db8a8]` — **a session in a different repository
entirely**, five hours into unrelated work. Nothing in the listing said so. The handle hinted at
it; the listing itself carried no repo, no path, no way to tell.

---

## 7 · The correction a five-line cap would have ruined

**The fourth category is new, and it was earned.** Measured 2026-08-18: the two most valuable
messages of the session ran ~18 lines each and **a five-line cap would have ruined both.** One
overturned a station's diagnosis — its framing pointed straight at a model field and a migration
when the real fix was one line calling a facility its sibling adapters already use, and **the
lines that mattered most were the ones explaining why the obvious fix was wrong.** Brevity is
right for status. It is actively harmful when you are telling someone their conclusion is wrong,
because a short *"wrong, use X"* corrects the filing and misses the code. That correction went on
to catch a live bug in the other station's own commit, which a terse version would not have.

---

## 8 · The guard that reddened at the wrong line

**Both halves matter, and the second is the one that gets skipped.** Observed 2026-08-18: a
freshly written guard did go red under mutation — and reported the offence at a source file at line 36
when the declaration was on **line 43**. The guard stripped comments before scanning, which
deleted their newlines and shifted every line number after them. It would have caught the
regression and then sent whoever fixed it to the wrong line. **The mutation check found a real
defect in the check itself**, which is exactly what it is for. The fix was to blank comments *in
place* rather than delete them, so the line count is preserved.

---

## 9 · A dependency that had to be recorded twice

Measured 2026-08-18: verifying one station's finding turned up a **second, independent** reason
another station's item was blocked — a frontend flow that would still fail at the callback even
after a perfect frontend fix. Landing them in the wrong order means the second item is "fixed",
the flow still fails, and its owner re-debugs from scratch **something already understood and
written down**. Control put the cross-reference on both rows rather than the one it was found on.

---

*Mission Control by Chinmai Reddy (@chinmaireddy09), under the Fleet Command License 1.1.*
