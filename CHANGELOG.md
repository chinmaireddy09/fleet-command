# Changelog

Every entry here is a change something in a live fleet forced. The dates are when it was
measured, not when it was thought of — where a version says *measured*, a session hit the
failure and the fix followed it.

Versions track `skills/mission-control/SKILL.md`. The other three skills are versioned by the
repo as a whole.

---

## 6.43.0 — 2026-08-23

**Third-party acknowledgement removed at the author's direction, and the repo now says one thing
about it rather than two.** 6.41.0 added a credit for an *idea* — a preamble shape — after finding
that a script comment described it more strongly than any human-readable file did. The author's
position is that inspiration was what was asked for and inspiration obliges nothing, which is
correct: **ideas are not licensed, no code from anywhere else is in this repository, and nothing
was ever required.** All mentions are gone, including the comment whose wording started it.

**The lesson that survives it is about consistency, not credit:** a repository must not describe
the same fact two different ways in two places. That was the actual defect; the credit was one
possible fix and removal is another, provided it is done *everywhere*.

**Generalised so this is adoptable rather than merely public.** The board path was hardcoded to
`docs/WORK-LOCKS.md` — one project's convention — so **every other project got `BOARD: none` and
a coordinator offering to create a board it already had.** The sibling skills in this repo already
say *"find whatever claim file the project already uses"*; this did not, and that inconsistency is
what makes a skill feel like it was written for somebody else's repo.

Now discovered, in order: `MC_BOARD` in the environment → a `Board:` line in the project's own
`MISSION-CONTROL.md` → the common locations (`docs/WORK-LOCKS.md`, `WORK-LOCKS.md`,
`docs/CLAIMS.md`, `CLAIMS.md`, `.claude/WORK-LOCKS.md`, `docs/BOARD.md`). **Nothing is guessed
from file content** — a board is a file the project chose, not one we pattern-matched into. The
rules file is found the same way instead of assuming `docs/`.

Verified across six layouts: board at the repo root, board named `CLAIMS.md`, board under
`.claude/`, an explicit `Board:` declaration, rules in `docs/` with a coordinator of `HQ`, and a
project with no board at all — which still correctly reports none rather than inventing one.

---

## 6.42.0 — 2026-08-23

**The skill contradicted itself about the fastest way to raise a fleet — the one most people
actually use.** §3 says a call-sign nobody has used is *"a normal answer, not an error… it creates
the station"*. Identify step 3 said *"if the row has none, that is the bug, fix the row."* Both
cannot be true. The second was written with only `deploy` in mind, where Control prepares the row
before the station exists.

**So the open-a-tab-and-identify flow was undocumented in the one step where it differs.** A human
opening four tabs and typing `/mc identify <name>` in each arrives at a call-sign with **no row**,
which the step called a bug. It is not a bug — it is a station **initiating its own post**:
create the worktree and branch, then write the row. Now a first-class branch at steps 2 and 4.

**And it is the faster flow, which is the reason to say so plainly.** `deploy` is serial —
prepare, spawn, wait, verify, repeat — while a human with four tabs *is* the parallelism. The
skill should not quietly describe only the path it automates.

**tmux, Windows Terminal and the fallbacks were tested with recording stubs** rather than
installed, so the dispatch and the exact argv are verified while the recipes themselves are not:
tmux receives `new-window -c <worktree> -n <CALLSIGN> <cmd>`; a refusal falls back to printing
rather than dying; `--batch` announces itself as unverified.

**Both non-macOS recipes now say what they actually proved.** `tmux new-window` returning 0 proves
a *window*, not a station — the AppleScript path can look inside its own tab for a live `claude`,
tmux returns immediately and there is nothing to look at yet. They print `NOT YET A STATION` and
point at the board, instead of borrowing the verified path's confidence. The Windows recipe also
states it has never run against a real Windows Terminal.

**The third-party acknowledgement added in 6.41.0 was scaled back.** It recorded an *idea*, not
code. Ideas are not licensed and nothing was required.

---

## 6.41.0 — 2026-08-23

**`spawn-station.sh` called `osascript` unconditionally, so on Linux, on Windows and inside the
VS Code terminal a deploy failed with `osascript: command not found` instead of handing over the
paste-able line it already had.** The reference docs and the config template have described five
terminals since 6.18; the script knew one. Now it dispatches, and **a missing recipe is not a
failure** — it prints, explains which host it is on, and exits 0, because the tab is the only part
a human was ever doing and the post is already prepared.

| host | recipe |
|---|---|
| **tmux** (checked first) | `tmux new-window -c <worktree> -n <CALLSIGN>` |
| **Windows Terminal** | `wt -w 0 nt -d <worktree> …` |
| **macOS Terminal.app** | the measured AppleScript path, the only one with an in-tab verification |
| **VS Code / anything else** | prints the line, and points at tmux |

**tmux is checked first on purpose: it is the only recipe that works on macOS, Linux, Windows via
WSL, *and inside VS Code's integrated terminal*.** One recipe covering every platform this skill
will meet is worth more than four that each cover one — a user who runs tmux gets real automation
everywhere.

**It also stopped pretending to be Terminal.app when it is not.** Running under iTerm2 or Warp,
the AppleScript would have targeted the wrong application; it now checks `TERM_PROGRAM` and prints
instead of misfiring into somebody else's window.

**A third-party acknowledgement was added in this release and removed again in 6.43.0** — see
that entry. It named an *idea* rather than any code, and no code from anywhere else is in this
repository.

---

## 6.40.0 — 2026-08-23

**Two usability defects, both reported as "this will not work for other users", and both fixed
without asking anyone to change a setting or remember a flag.**

**1. The deploy prompt was eating the tab bar.** Terminal composes a tab's title from the working
directory, the title the process sets, the process name **and its full argument list** — so the
prompt `deploy` passes is *on the tab*, pushing the repo and the call-sign off the readable part.
That prompt read *"/mc identify X — your ListAgents address is X; confirm with `ps -o args=` on
your own claude process"* — 230 characters, existing only because a station could not read its own
address. **6.34.0 retired that premise**; the registry gives the name and the self-line gives the
`[ref]`. Now it is `/mc identify X`, the command line is 100 characters, and the tab gets its
width back.

**Measured first, because the obvious fix was wrong.** Setting Terminal's `custom title` to a
stable `repo — CALLSIGN` looked like the answer. It is not: **Claude Code writes that same
property.** A custom title set to `fleet-command — SKILLDEV` was replaced by `◐ Issues resolution
check` within seconds. There is no separate field to hide in — which leaves exactly two levers,
`--name` (already ours) and the length of what we put on the command line (now fixed).

**The rule this establishes: do not solve our legibility problem out of the user's settings.**
Telling people to reconfigure Terminal to make our output readable is a bad first impression and
most will not do it. Shorten our own output first; the setting is then optional, not required.

**2. `deploy` was serial, so raising a fleet meant watching a progress line.** Each spawn spent
~4s proving its own tab came up, and the identify that followed added 30–45s before the next
began. **None of that waiting is work** — nothing about station two depends on station one
existing. `spawn-station.sh` now takes `--batch`, which opens the tab and returns; deploy prepares
every post, pushes all rows in **one** board commit, opens every tab, then verifies the whole fleet
in a single pass.

**`--batch` moves the verification, it does not remove it** — it prints, on every run, that the
tab is not yet verified, because the check exists for a keypress that misfired twice in one deploy
on 2026-08-17.

**Why this rather than teaching the faster hand-typed launch.** Opening tabs yourself and pasting
`claude --name X '/mc identify X'` is genuinely fast and produces a clean station — but it only
works if you remember the exact shape. **A workflow that depends on remembering a flag is one most
people get wrong the second time and every new person gets wrong the first.** The user's own words:
*"everytime remembering that will not help."* So the command they already know got faster, rather
than a faster command being added to what they must know.

---

## 6.39.0 — 2026-08-23

**Every station in its own worktree saw its whole fleet as strangers.** The preamble's
on-fleet/off-fleet split compared a peer's working directory against `ROOT`, and `ROOT` came from
`git rev-parse --show-toplevel` — which for a station **is its own worktree**, not the shared
checkout. So a station in `.claude/worktrees/backend` classified the shared checkout *and every
sibling worktree* as `OFF-FLEET (different repo — do not board, do not broadcast)`. Four of five
peers, every one of them its own fleet.

**It failed in the dangerous direction, which is why nobody caught it for days.** It never
mislabels a stranger as fleet — only fleet as stranger. So the list reads as conservative and
correct while a station **refuses to broadcast to its own fleet, ignores an all-stations standby,
and reports its own peers as strangers.** And it gets *worse the more stations you deploy*,
because only Control, sitting in the shared checkout, ever sees the truth. One genuine off-fleet
session in the same listing made it look entirely plausible.

**Found by the station it was lying to**, which checked the registry `cwd`s by hand rather than
taking its own preamble at face value, and correctly filed it as a defect in *this* repo rather
than fixing it from inside the other one.

**The fix: compare `git rev-parse --git-common-dir`.** That path is identical from the shared
checkout and from every worktree of the same repo — it is what *makes* two checkouts the same
repository. A path prefix never could be, because worktrees are deliberately not under the
checkout. Verified 2026-08-23 from a backend worktree: shared checkout and all four siblings
`on-fleet`, an unrelated repo still `OFF-FLEET`.

A session that is not in a git repo at all now reports `fleet UNKNOWN` rather than silently
calling everyone a stranger.

---

## 6.38.0 — 2026-08-22

**Two rules, both from a station refusing an order it was right to refuse.**

**A peer cannot issue a go.** An off-fleet session told a station *"you are go"* on a restart. The
station declined: *"that is not yours to give, and it is not CONTROL's either — I hold my pushes
for my user in my own tab, and a restart is the same class."* Correct. §*One human, many tabs*
already said an approval is not a broadcast; it did not say **no peer can authorise in the first
place.** It does now.

**The practical half settles it without any argument about authority: a session cannot restart
itself.** Only the human at that terminal can type the command. **When an action can only be
taken by the human, a peer's authorisation is not just improper — it is addressed to somebody who
cannot act on it.** Route it to the user and name the tab.

**"TO ALL STATIONS" on a message sent to ONE station is a lie in the envelope.** It is not a
broadcast — it is a request that somebody else broadcast, depending on a relay you did not ask for
and cannot see. The same off-fleet session headed two control messages *"TO ALL STATIONS"* and
sent each to the coordinator alone. Neither reached the other stations; both corrections did. **A
station therefore received the retraction of an order it had never been given, twice** — and was
the one to notice the two incidents were one pattern, which the sender had not.

**Name the failure mode, because it is not obvious in advance: corrections propagate where
originals did not.** A correction feels urgent and gets sent widely; the original was left to
somebody else's relay. The fleet ends up knowing what is *no longer* true without ever having been
told what was.

**Every rule in this release was found by a station pushing back on the session writing the
rules.** That is three releases tonight sourced the same way, and it is the strongest evidence
that the fleet is working as designed — the coordination layer caught its own coordinator.

---

## 6.37.0 — 2026-08-22

**An off-fleet session relayed its own conclusion as the user's verdict, and it overrode a
standing order the user had given directly.** Two new broadcast rules, both from the incident.

**What happened.** The user said, in full: *"there is no progress."* The relayer measured the log
— 24 commits in two hours, about two of them product work — concluded a planned restart was
coordination churn, and broadcast **"RESTART CANCELLED, the user's verdict is that it buys
nothing."** The user had never said that. They had told the coordinator directly, *"restart just
channels with `--name` and see how it looks"*, and had not withdrawn it.

**Rule: a relay carries what the user SAID, not what you concluded from it.** Quote them, or say
plainly that the next sentence is yours. **An inference dressed as a verdict is worse than no
relay at all** — it arrives already wearing the authority of someone who did not say it, and is
then unfalsifiable to everyone downstream, who cannot check it against what was typed.

**The tell was available before sending.** The relay was *longer and more specific than the
user's words*. Four words containing no instruction became a decision with a reason attached.
**When your relay says more than the user did, the surplus is yours and must be labelled** —
*"the user said X; my read is Y"* keeps both and lets a reader reject Y without disbelieving X.

**Rule: a relay never outranks a direct instruction, and a conflict is asked, not resolved.** The
coordinator caught this, not the relayer. It acted on neither, named both, and asked which was
current: *"your instruction to me is the one I'd follow, and a peer's relay doesn't override it,
but you're the only one who knows which is current, so I'm not guessing."* **That is the correct
shape of every conflict between a peer's word and the user's** — name both, act on neither, ask
once. Guessing would have been defensible and still wrong.

**The same error as 6.33.0, one level up.** There it was a name the user used once becoming a
recorded preference; here it is a sentence the user said once becoming a recorded verdict. Both
are *putting words in the user's mouth and then obeying them* — and the second is worse, because
a fleet obeys it too.

---

## 6.36.3 — 2026-08-22

**Tonight's entries put a private repo's session handles into a public skill.** 6.36.0 quoted a
real measurement using the real handle from the fleet it was measured on. That fleet is a private
repo; this skill is public. Replaced with the house placeholder (`acme-shop-3c`), which every
other example here already uses.

**This is 6.28.0's rule — no private repo left in a public skill — broken by the mechanism that
rule exists for.** The leak did not arrive by carelessness about privacy; it arrived because
quoting the *exact* string is what makes a measurement credible, and the exact string was
somebody's repo. **Anonymise at the moment you write the evidence down, not at review** — by
review the specific string looks load-bearing and you will be reluctant to touch it.

Release audit run before calling this final, and recorded here because "it works" is not a
verification: version agreement across `SKILL.md` and this file; all four in-text section
cross-references resolve to real headings; nine retired phrasings return nothing outside this
changelog; the config template is valid JSON; all six scripts execute (not merely parse) against
the installed copy; and all five input guards refuse — AppleScript injection, shell injection,
multi-word call-sign without a handle, live call-sign clash, over-length call-sign.

---

## 6.36.2 — 2026-08-22

**6.36.0 leaned on a coincidence and called it corroboration.** It offered `formerNames[0] == the
`@` header` across a five-session fleet as supporting evidence. A station checking the claim
rather than adopting it found the one row that appeared not to fit — the off-fleet session's, whose
`formerNames` held **two** entries with its *current* name at `[0]` — and filed it as
**unexplained rather than letting the rule harden around it.**

**Run down: that row does fit, and the general rule still does not hold.** The off-fleet session
started as `fleet-command-c2`, renamed away during a clash test and back, so `[0]` is its startup
name and the match is real. But `set-callsign.sh` **filters any duplicate of the outgoing name out
of the list before appending**, so `[0]` is the startup name *only until a session renames back to
a name already in it*:

```
A -> B    formerNames [A]
  -> A    formerNames [A, B]
  -> B    formerNames [B, A]      <-- [0] is now B
```

**So the invariant breaks silently on the third rename, and the match across five sessions was an
artifact of their histories.** Demoted, with the trace, and marked *do not use*.

**What 6.36.0 actually rests on is unchanged and sufficient:** one socket per session
(`/tmp/cc-socks/<pid>.sock`) means no per-channel capture is *possible*, and the post-rename
channel test shows the old name arriving anyway. Those two are the proof; the third line was
decoration that would have misled the first reader whose session renamed three times.

**A coincidence that holds across every case you happen to have is still a coincidence** — which
is the kind of evidence this skill spends most of its rules teaching stations to distrust, offered
here by the skill itself.

---

## 6.36.1 — 2026-08-22

**Sweep after three releases in one evening: the retired claims had survived in two places
nobody greps.** 6.34.0 retired *"a session cannot see itself"* and 6.36.0 retired *"the header is
captured when the channel opens"*, but both were still being taught — once in a **script comment**
that explains why `deploy` asserts a station's address, and once in **`references/`**, which is
loaded on demand and so is easy to forget is a surface at all.

Neither changed behaviour; both would have taught a station something false at the moment it was
deciding whether to trust itself. **This is 6.28.1's rule again — a withdrawal that reaches the
changelog and not every surface has not landed** — and the honest reading is that a doc-sweep on
each of the three releases would have caught it, and did not happen because the finding felt
like the deliverable.

**Dated changelog entries were deliberately left alone.** They record what was believed on the
day, later entries supersede them, and rewriting history to match current knowledge would destroy
the one thing this file is for.

Verified after: a grep sweep for all seven retired phrasings across every `.md` and `.sh` outside
`CHANGELOG.md` returns nothing.

---

## 6.36.0 — 2026-08-22

**The `@` header and the `ListAgents` self-line are one cache, and this skill was offering a
repair that does not exist.** The old model said the header is *captured when a channel opens* —
which implies a channel opened **after** a rename carries the new name. **It does not.**

**Decisive case.** An off-fleet session had never messaged `FINANCE`. It resolved `FINANCE` off
`ListAgents` — the current name — and sent, so that channel opened *after* the rename. The reply
arrived headed **`acme-shop-3c`**, the pre-rename handle.

**Mechanism, from the registry:** `messagingSocketPath` is `/tmp/cc-socks/<pid>.sock` — **one
socket per session, keyed by pid.** There is no per-channel handshake, so there is no per-channel
moment at which a name could be captured. What travels with a message is what the sending process
cached about itself **at startup** — the same value its self-line prints. Across a four-station
fleet, each station's `formerNames[0]` is character-for-character the string in *both* places.

**So five surfaces are really four, and two pieces of waste die with the correction:**

- **Reopening a channel to get a fresh name.** The old text implied that repair existed. It does
  not; only restarting the sender clears it.
- **Re-verifying a peer's rename because its header looks wrong.** A station on this fleet had to
  tell its coordinator *"not a failed rename; do not re-verify it on my account."* The skill
  invited that round-trip.

**The mitigation was already in the protocol and is now stated as load-bearing:** every
transmission opens *"CALLSIGN TO CALLSIGN"*. **The body is the only correct identity on an inbound
message** — the envelope cannot carry it. Every station on the measured fleet was already doing
this, which is why nothing was actually misrouted.

Corrected in `SKILL.md` (three sites plus a new subsection), `README.md`, and the note
`set-callsign.sh` prints on every run — which also stopped ending with *"a session never sees
itself"*, retired in 6.34.0 and still being printed at people.

---

## 6.35.0 — 2026-08-22

**"A stale reading of a live source, mistaken for a limit of the source."** A station that had
paid the identity round-trip reported *why* it paid it, and the reason was not the one 6.34.0
fixed. It had not reasoned from the old `ME_REF` text at all. It ran the preamble **once, before
`set-callsign.sh`**, saw its pre-rename handle in `ME_NAME`, and concluded **the registry could
not know its new name** — so it went to the radio for a fact sitting in a file.

**The preamble's own rule is what licensed that.** *"Do not re-derive a line it printed"* is
correct for repo state — the board, HEAD, the worktrees — and **exactly wrong for `ME_NAME`**,
because the preamble runs before identify step 1 renames the session. Those two lines are
**pre-rename by construction, every time.** The rule now carries that exception explicitly, and
`mc-init.sh` marks `ME_NAME` as a snapshot at the point of printing rather than leaving the
reader to infer it.

**The generalisation, which outlives this field:** two different failures sit in the identity
table and **their remedies are opposite.** A surface that is a *cache* — the `ListAgents`
self-line name, the `@` header — must never be trusted. A surface that is *live* — the registry —
must simply be **re-read**. Picking the wrong remedy costs you the fact either way: distrust a
live source and you go to the radio; trust a cache and you publish something false. **When a
cached value looks wrong after you changed what it came from, re-read the source before
concluding anything about the source.**

**Credit where it is due:** this came back from the station that lost the time, unprompted, as a
correction to the fix rather than an acknowledgement of it — and it verified 6.34.0 locally rather
than taking it on relay before replying. That is the loop this skill is supposed to produce.

---

## 6.34.0 — 2026-08-22

**A four-station fleet measured every identity surface at once, and the skill had one of them
backwards.** This entry is that run's findings, generalised.

**"Nothing is failing to sync."** The registry on disk is correct the instant `set-callsign.sh`
returns. What goes stale is three *caches* filled before the rename and never recomputed:

| surface | correct after a rename? | when it reads the name |
|---|---|---|
| **session registry on disk** | ✅ live | when `set-callsign.sh` writes it |
| **`ListAgents` → peer rows** | ✅ live | re-read every call |
| `ListAgents` → **your own self-line** | **name stale · `[ref]` correct** | name snapshotted at session start |
| `@` header on an open channel | ❌ stale | once, when that socket opened |
| terminal tab title | per launch argv | every status change |

**The correction: this skill said the manifest never lists you, so the `[ref]` was the half that
needed a peer. Backwards.** The manifest *does* list you, on a self-line — and its **ref is right
while its name is the stale part**. A station read `[a84930]` for itself correctly while that same
line showed its pre-rename handle, and a peer confirmed `[a84930]` independently.

**So the radio round-trip for identity is gone.** Your **name** comes from the registry
(`mc-init.sh me`, live, works for hand-started sessions); your **`[ref]`** comes from your own
self-line. Both local. A peer read-back is now **corroboration, not retrieval** — worth one call
when a bare call-sign matches two rows, never a blocker. In the measured run two stations sat
blocked on exactly this, and both were right not to trust the self-line and wrong to think the
answer was on the radio.

**The self-line does not merely go stale — it asserts something false**, *"this session is
`<old-handle>`"*, while peers address the new name. Never read your own name off it.

`mc-init.sh me` now says all of this in its own output: `ME_REF` points at the self-line instead
of claiming the ref is unreadable, and a new `ME_SELFLINE_NAME: DO NOT USE` line marks the trap
at the exact place a station would otherwise walk into it.

**Unchanged and still true:** the `@` header on an already-open channel never re-resolves, and
replying to a from-name bounces. Both stations hit that bounce in the run, which is the documented
behaviour working, not a regression.

---

## 6.33.1 — 2026-08-22

**`bash -n` passed and the script died on its first real run.** 6.33.0's rewritten
`emit_coordinator` opened with `local root="$1" name="" f="$root/docs/MISSION-CONTROL.md"`. Bash
expands **every argument of `local` before it performs any of the assignments**, so `$root` was
still unbound when `f` was built — and under `set -u` that is a hard exit, not an empty string.
`/mc` died four lines into its own preamble, before printing a coordinator at all.

**A syntax check is not a smoke test.** This was caught only because the release was followed by
actually running `mc-init.sh` in a repo. Every script in this skill now gets run, not parsed,
before a release is called ready.

---

## 6.33.0 — 2026-08-22

**One project's example name had become the default for every fleet on the machine, and the
detector that should have overruled it could only recognise three names.** Two bugs, one shape:
a name that belonged to one post in one repo escaping into everything.

**The user said it plainly:** *"fleet command is an example which I shared, I never meant by only
fleetcommand should have the header."*

**What had gone wrong.** `FLEET COMMAND` was said while discussing one repo. A session recorded
it in `~/.claude/mission-control.json` as the machine's coordinator preference and stamped it
`confirmedByUser`, and from then on **every project whose board did not name a coordinator
resolved to it.** The record made a guess look like a decision. It has been removed, and the file
now carries why, so the next session does not re-derive it.

**And the board could not overrule it, because the detector was an allowlist.**
`emit_coordinator` matched `CONTROL|FLEET COMMAND|FLEETCOM` and nothing else — so a project whose
board named its coordinator `HQ`, `BRIDGE` or `COMMAND DECK` was **silently skipped by the very
precedence rule that says the board wins**, and fell through to the stored preference. *A
precedence rule enforced by a list of names it already knows is not a precedence rule.* Boards now
declare it on one line — `Coordinator: <NAME>` — and any word works; the old allowlist stays only
as a fallback for boards written before the line existed.

**The rule that generalises both:** *a name the user used once is an example, not a preference.*
Before writing anything under `naming`, decide which you saw — the user **stating how they want
their fleets named**, or the user **using a name while discussing one project**. **When you cannot
tell, it is an example.** The cost is asymmetric: an unrecorded preference costs one moment of
deriving `CONTROL`; a recorded example renames the coordinator of every other fleet they own.

**This is the same error as *never take a coordinator's call-sign for a session that is not the
coordinator*** — already in this skill since 6.26.0, and violated again here in the other
direction. One name, one post, one repo. It does not travel.

---

## 6.32.0 — 2026-08-22

**Identify assigns its own call-sign now. `Identify as: ____` was a station not on post.**
The prompt was there because naming felt like a decision only a human should make. It is not:
a fleet's call-signs come from the areas the work already has, and a session that has read the
board and knows which worktree it is standing in has strictly more information about which post
it is filling than the human who just opened a tab.

**The resolution order, first match wins:** the project's own `MISSION-CONTROL.md` names a
standing station for this area → a reserved row on the board, preferring the one whose workspace
is the directory you are in → the area or lane the work names → a team name, only when the area
is genuinely undecided. Never one that is on the board or answered by a live session.

**Announcing beats asking because the correction is free.** The call-sign is taken at step 1 and
the row that publishes it does not land until step 5. Between those points a wrong guess costs
one `/mc identify <other>` and nobody has seen it. Asking up front trades that free correction
for a guaranteed stall — and the stall is not free, because a session with no call-sign is
invisible to the fleet the entire time it is waiting.

**Control resolves its own name the same way** — this project's board, then the user's recorded
preference, then plain `CONTROL`. Every fleet has a coordinator and it is always the same post,
so there was never a real question there either.

**What still gets asked, and why it is not the same thing.** A handle for a call-sign *the user
typed* that cannot be a session name — `FLEET COMMAND` → `FLEETCOM`. The scripts still refuse
rather than guess, because there you are shortening **their** word and they live with the result
in every message afterwards. Naming yourself when they named nothing is not that: there is no
word of theirs to shorten, and anything you pick is one command from being replaced. The rule
was never "never choose a name", it was **"never put words in the user's mouth"**, and 6.32.0
is what that distinction looks like applied.

**Preferences are recorded when stated, never solicited.** The old text said *"ask at the first
identification of a fleet, record it, and stop asking"*. Now: if they have never said, the
coordinator is `CONTROL` and a station names itself off its area — and the moment they say
otherwise, that is what gets written down.

---

## 6.31.1 — 2026-08-22

**"Before you touch the board" was not what 6.31.0 meant.** Identify can be invoked bare, in
which case the session reads the board to render the listing the user picks a call-sign off —
so a station that had done exactly the right thing would read step 1 and think it had already
broken it. The constraint is on **writes**, not reads, and the step now says so.

---

## 6.31.0 — 2026-08-22

**Identify took the call-sign at step 6 and wrote the address onto the board at step 4.** Those
two facts were three lines apart in the same list for months, and in that order they cannot both
be right. A hand-started station read its derived address (`acme-shop-4d`), pushed it onto the
row peers resolve it through, and *then* ran `set-callsign.sh` — which changed the address out
from under the row it had just published. **The row was stale the moment it landed**, and it
fails the same way as a row with no address at all, only more quietly: it renders as manned, and
every peer that resolves it bounces.

**The call-sign is now step 1, before the board is touched at all.** Nothing was waiting on
anything — the call-sign arrives in the command that starts identify, so there was never a reason
to take it last. Step 5 then writes an address the station already holds.

**It also deletes a radio round-trip that the old order made unavoidable.** A session cannot look
its own address up — `ListAgents` never shows you yourself — so a station reaching the row-write
unnamed had to stop and ask a peer *"what address does this message arrive from?"*. That question
was answered by reordering rather than by answering it faster.

**"Always" meant fixing the order, not adding another instruction saying always.** The old text
already read *"this is a step, not a suggestion — run it now"* and *"do not skip it because you
were started with `--name`"*. It was emphatic and it was in the wrong place, and emphasis does
not fix sequence. The rule that shipped in 6.25.0 — ship the checks as code, because more rules
were never going to work — applies to ordering too.

The long tab-surface material that used to sit inside step 6 is now the reference subsection
*Your two identity surfaces*, unchanged in substance, so the numbered list reads as six actions
instead of one action and a hundred and seventy lines of digression.

---

## 6.30.0 — 2026-08-22

**The tab title was never a lost cause; `--name` had been holding it all along and this skill
called that unverified.** A user reported both identity surfaces failing in a live fleet: *"tab
name is set only for a certain time and it is changing when a new prompt is given."* That is the
documented behaviour, so the question was why the documented behaviour was the one they were
getting. Measured on 2.1.239 by capturing the pty across one real turn, three launches of the
same session:

| launched as | `ESC]0;` title writes in one turn | what the tab ends up reading |
|---|---|---|
| `claude` | 7 | `✳ Claude Code` → **`✳ <turn summary>`** |
| `claude --name TESTSTATION` | 5 | **`✳ TESTSTATION`** — every write |
| `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 claude` | 0 | whatever `label-tab.sh` set |

**Claude Code overwrites the title either way. What changes is what it overwrites it WITH.**
With `--name`, every write carries the call-sign and the turn summary never appears — so a
station `deploy` spawned has had a correct tab since launch, in any terminal, because it is plain
OSC rather than AppleScript. The skill had said *"no one has measured a `--name` session's title
across a turn boundary, so do not report that half as verified."* Now measured; caveat retired.

**The reported failure is real but is a different case: a session started as plain `claude`.**
Control itself, and anything hand-started, is in that world — and **nothing it runs can move it
out**, because argv and env are fixed at exec. `label-tab.sh` and `set-callsign.sh` cannot fix a
tab there and never could; `/rename` typed by the human still can.

**So the scripts stopped guessing and started reading.** `label-tab.sh` now walks to its own
`claude` process, reads argv and env, and prints `persists: YES`, `persists: YES (as <handle>)`
or `persists: NO` with what to do about it — and where the handle differs from the call-sign it
says so, because the tab will show the handle. `set-callsign.sh` pipes that verdict through
instead of restating it: **one fact, one voice.** Restating it in a second place is exactly how
6.28.1 happened.

**A fix that was measured and then thrown away.** `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` genuinely
works — zero writes — and was wired into `spawn-station.sh` before the `--name` measurement came
in. It was then reverted: it buys a bare title with no status glyph, at the price of switching off
the durable portable mechanism and replacing it with a Terminal.app-only one. **A measured fix is
not automatically the right fix, and the second measurement is what tells you which.** It is
documented as the user's lever for their own settings, not something the skill sets for them.

**The `@` header did not move.** It is still captured when a channel opens and never re-resolved.
Nothing in this release changes that, and nothing should be reported as though it did.

---

## 6.29.0 — 2026-08-20

**A repo's work belongs to that repo, and crossing into another one is a decision the user
makes.** Standing order 15. Two repos collaborating toward one goal is legitimate — but it is a
**joint operation**: authorized, temporary, and finished when the goal is met. What it is not is
somewhere a station ends up because a thread led there.

**Every step in the incident was asked for, which is exactly what made it hard to see.** A
session working this repo was asked about its own call-sign surfaces. The user then asked about
their live fleet in another repo, and — one authorized step at a time — the session read that
board, drafted two row fixes, and relayed them to that fleet's stations. Then a station replied
with a genuinely good correction, and the session carried on into rewriting its own tooling,
building a regression test, and re-verifying a draft **nobody had asked it to touch.** The user
stopped it: *"are you fixing the issues of fleet command or building ecom nexus?"*

**The mechanism is order 11 with a second repo as a disguise.** Certainty that the next step is
obvious is not permission to take it — and a peer's reply is the most convincing disguise that
feeling has, because it arrives looking like the work continuing rather than like a new decision.

**Authorization is scoped to the thing asked.** *"Draft the edits"* is not *"and maintain the
tooling."* *"Relay them"* is not *"and act on the replies."* Name which repo a piece of work
belongs to before doing it; if the answer is the other one, stop and ask.

**And when the joint operation IS granted, the deliverables still split:** the fix lands in the
repo it fixes, the lesson lands in the repo that teaches it. This entry is that rule applied to
itself — the board fixes stayed in the other repo, written by the stations that own those rows,
and only the lesson came home.

---

## 6.28.1 — 2026-08-20

**The withdrawn claim was still in the file a station actually reads.** 6.26.0 retired
*"`set-callsign.sh` makes the `@` header match the call-sign"* and this changelog said so — but
`SKILL.md` still taught it in bold at identify step 6, and the script still printed
`@ header <old> -> <new>` on success. A station read that line, reported the header updated, and
every peer holding an open channel went on seeing the old handle. **A withdrawal that reaches the
changelog and not the surfaces has not landed.** Corrected in both, and the script now states the
limit on every run: a channel already open keeps the old name, and only one opened afterwards
carries the new one.

Five smaller overstatements of the same two surfaces, found in one sweep:

- **"Only the terminal tab title still needs a relaunch" was not "only."** An already-open
  channel's `@` header is repaired by neither `set-callsign.sh` nor `/rename`.
- **"The pinned tab title makes misdirection unlikely"** — nothing is pinned. The label is gone at
  the next turn boundary. `/rename` and `/color` persist, and both need the human to type them.
- **The script index called `label-tab.sh` a pin** and omitted `set-callsign.sh` altogether, so it
  pointed at the delegate rather than at the step every station runs.
- **The script's one-line synopsis** still promised "the name everyone sees."
- **`--name` holding the title for good was never measured.** It is sourced to the flag's own help
  and is now labelled that way. `/rename` is the only surface here with a before-and-after.

**The rule this earned:** *a claim is retired when every surface that teaches it stops teaching
it* — including the strings a script prints. The changelog is where a correction is recorded, never
where it takes effect.

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
