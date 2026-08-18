# Changelog

Every entry here is a change something in a live fleet forced. The dates are when it was
measured, not when it was thought of — where a version says *measured*, a session hit the
failure and the fix followed it.

Versions track `skills/mission-control/SKILL.md`. The other three skills are versioned by the
repo as a whole.

---

## 6.28.0 — 2026-08-19

**The fleet manifest.** What `ListAgents` returns now has a name, because the tool name told
readers nothing and the confusion it caused was structural. It is **every live Claude Code
session on this machine** — a list of *contacts*, not of stations. The board is the roster; the
manifest is the radar. The tool name stays only where a session literally makes the call.

**Three rules the board earned**, all measured the same day:

- **Anchor a board edit by content, never by line number.** A station read its claims row at line
  278, a peer pushed while it was thinking, and by write time the row was at 315. A hardcoded line
  would have rewritten somebody else's row. Match on the row's own text, assert the match count is
  exactly one, abort otherwise.
- **A stale name in an address cell is a bug; the same name in a dated observation is a record.**
  Fixing an address that routes traffic is a fix. Rewriting it inside a peer's account of what
  happened is reformatting their narrative.
- **Remove your own throwaway worktree, never anybody else's.** Three `board-flip` worktrees stood
  under three scratchpads. A detached throwaway is either mid-edit or abandoned and you cannot tell
  which from outside; a detached `HEAD` has nothing to recover it by.

**Generalised for publication** — a private project's repo name, session refs, worktree and item
IDs had leaked into examples that ship to everyone. All now use the house placeholder.

## 6.27.1 — 2026-08-19

**The session listing is a radar with no IFF.** Three stations independently raised the same
off-fleet session — a window working in a different repo on the same machine — and each spent
traffic concluding, correctly, that it was not theirs. Nobody was interfering. The listing reports
every contact in range and carries no friend-or-foe bit.

Three states, decided by **working directory and never by name**: on-fleet with a board row is a
station; on-fleet without one needs a call-sign; off-fleet is somebody else's window. **An
off-fleet session is not an event** — do not raise it, board it, or broadcast to it.

## 6.27.0 — 2026-08-19

**One call instead of twelve.** Measured: a single `/mc identify` spent 2–5 minutes and 8–16k
tokens before writing anything, nearly all of it on eight to twelve sequential one-line shell
calls — none of which depended on the answer to the one before. `mc-init.sh` gathers all of it in
**one call, 1.3 seconds**: repo root, the board measured *at `origin/main`*, project rules, the
coordinator by precedence, ahead/behind, worktrees, this session's own name, and every live
session split on-fleet / off-fleet.

**The bootstrap trap was half solvable all along.** The tool cannot show a session itself, but the
session registry can — it is on disk, keyed by pid. A station now reads its own name locally, with
no radio round-trip, including when it was started by hand. The `[ref]` genuinely is not derivable
(verified: it is in no registry field, and is not `sessionId` nor its md5/sha1/sha256 prefix), so
that half remains a peer's job — and only when a bare call-sign matches two rows.

**"Clear the board" stops meaning "delete the claims."** It defaults to a view.
`/mc board clear` re-renders from `origin/main` showing only live stations, open items and the
single most urgent thing. When the file itself has grown, done rows are **archived** with the count
and destination stated. A row naming a live holder is never removed.

## 6.26.0 — 2026-08-19

**Whoever triggers mission control is Control.** The old rule described a coordinator without ever
binding one, while a standing order told sessions not to take a post unasked — so a fleet whose
board named four dead sessions got two accurate reports and still had nobody coordinating. Running
the command is what puts a coordinator on watch: bind, then report. Three exceptions only.

**The identity surfaces were oversold.** The claim that `set-callsign.sh` makes the `@` header
match the call-sign is withdrawn — measured: two renamed stations kept arriving under their old
handles, because the header resolves when the channel opens and is never re-resolved. It is
**provenance, not identity**.

## 6.25.0 — 2026-08-18
Ship the checks as code, because more rules were never going to work. → `preflight.sh`

## 6.24.0 — 2026-08-18
The coordinator preference is not the top of the stack, and I squatted on it.

## 6.23.1 — 2026-08-18
Narrow the case claim to what was measured, and generalise the provenance loss.

## 6.23.0 — 2026-08-18
`/rename` wins the tab and costs the provenance; verifying beats amplifying.

## 6.22.0 — 2026-08-18
An extracted baseline fails asymmetrically, and that is why it survives.

## 6.21.0 — 2026-08-18
Five findings the fleet produced faster than I did.

## 6.20.0 — 2026-08-18
The `@` lag is not cosmetic — replying to a stale from-name bounces.

## 6.19.0 — 2026-08-18
`/rename` exists, the `@` lags, and counts are not the check for work at risk.

## 6.18.1 — 2026-08-18
Call-signs are allowlisted — two injections, one of them shipped.

## 6.18.0 — 2026-08-18
A call-sign is the user's word, and the address may differ from it.

## 6.17.0 — 2026-08-18
Taking the call-sign becomes a step, so a clone gets it without being told.

## 6.16.0 — 2026-08-18
A fifth blind check, and the way it got caught.

## 6.15.1 — 2026-08-18
The worked example for an ageing approval, with the refusal in it.

## 6.15.0 — 2026-08-18
An approval ages, and the queue behind it keeps moving.

## 6.14.0 — 2026-08-18
A station can take its own name — and two claims this skill made were wrong.

## 6.8.0 — 2026-08-18
Every station writes its own progress log — Control writes the watch.

## 6.7.0 — 2026-08-18
Field notes — the incidents move out, the reasons stay behind.

## 6.6.0 — 2026-08-18
Start paying back the size, add the handle format, clear the last leakage.

---

## 2026-08-17 — first commit

*Fleet Command — run many Claude Code sessions on one repo without collisions.*

---

*Mission Control by Chinmai Reddy (@chinmaireddy09), under the Fleet Command License 1.1.*
