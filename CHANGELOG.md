# Changelog

Every entry here is a change something in a live fleet forced. The dates are when it was
measured, not when it was thought of — where a version says *measured*, a session hit the
failure and the fix followed it.

Versions track `skills/mission-control/SKILL.md`. The other three skills are versioned by the
repo as a whole.

---

## 6.68.0 — 2026-08-23

**One project's stack was baked into a tool meant for anybody.** `preflight.sh stack` probed
`db:5432`, `redis:6379` and `minio:9000` by default — the author's own services — so every other
project got a health check for things it does not run and never will. Worse, it **died outright**
on any project without Docker: `FAIL: no docker binary`. **A check that fails because you are not
containerised reads as a broken stack**, which is the opposite of what it is for.

Now: **arguments win, then `MC_STACK_TARGETS`, then this project's own declared compose
services** — read from `docker compose ps`, never a list somebody else needed. No Docker, or no
compose file, is reported as *"nothing of this kind to check"* and **exits 0**, because *no shared
services* is a valid healthy answer. It still states the rule it exists for on the way out — **a
status column is a claim, a socket is evidence** — so a project checking by hand gets the reason,
not just a shrug.

**The go/no-go recipe presented one stack as the procedure.** Docker Compose, a database per
station, `npx vitest`. The *principles* are universal — the files under test and any mutable state
must be private to the station — and the recipe was one way of achieving them. Now the two rules
come first as a table, the container form is labelled as **one worked example**, and the
non-containerised form is given: run from inside your own worktree, which makes the files private
for free, and isolate state with whatever your stack has. **A worktree already isolates the files;
the state is the half people forget.** With no shared mutable state there is nothing to isolate but
the files — *do not invent a container to satisfy a table.*

Two smaller ones from the same sweep: the standing order now says *never stop a shared service
others are using*, with `docker compose down` as the usual way that happens rather than the only
one; and a narrative line reading *"three of today's four"* now reads *"three of one fleet's
four"*, because this file is read by people who were not there.

**And the test written to enforce this fell into the trap catalogued the same day.** It ran
`grep -c 'minio:9000\|redis:6379'` over the whole file and counted the hits inside the comment
*explaining why those defaults are gone* — **a count cannot tell live code from a comment
documenting its own removal.** It now greps executable lines only. The rule was three releases
old and still caught its own author.

`test/e2e.sh` 122 → **129**, covering both degradation paths and asserting no project's services
are hardcoded.

---

## 6.67.0 — 2026-08-23

**Three identity checks ran on the author's machine and silently vanished everywhere else.** They
sat behind a skip that fired whenever no session registry entry could be found by walking up from
the shell — so on this machine the suite reported `119 passed · 0 skipped`, and in a fresh-user
simulation with an empty `$HOME` it reported `116 passed · 1 skipped`. **The same suite, the same
commit, three fewer assertions**, and the environment that lost them is the one you actually want
to be sure about.

**Green locally and uncovered where it matters is the worst of both**, and a skip is how it hides:
it reads as *"not applicable here"* when it means *"this went untested"*.

The fix is the technique already used for the rename and tour checks — **build the registry, do not
depend on having one.** `find_me()` walks up from `mc-init.sh`'s own shell looking for
`$HOME/.claude/sessions/<pid>.json`, and its parent is the test script, so an entry written for
`$$` is found on the second hop **with no `claude` ancestor required**.

**And the degraded path is now a test rather than the excuse for not having one.** No registry at
all must say `ME_PID: unknown` *and say why* — it must not guess a name. That branch was previously
the reason the block was skipped; it is now two assertions.

`test/e2e.sh` 119 → **122**, and — the point of the change — **it reports the same 122 under a real
`$HOME` and under an empty one.** A suite whose count depends on whose machine it runs on cannot
tell you what it covers.

---

## 6.66.0 — 2026-08-23

**The tour's closing named the wrong verb, and a real project's name had leaked into the skill.**
Both found by asking whether this is fit to hand to somebody else, which is a different question
from whether the tests pass.

**Step 4 said `standdown`; it should say `secure`.** The step *releases a claim* — the row comes
off the board and the call-sign is free — and that is `secure`. `standdown` is a **session** ending
its own watch: push, report, wait to be acknowledged, exit. Naming it there was wrong twice over:
it described something that did not happen, and **it tells somebody who has just arrived how to
leave.** The two are near neighbours and the difference is exactly the one a new arrival should
learn first — `secure` retires a POST, `standdown` ends a SESSION — so the tour now names `secure`
and says why.

**A real project's session handles were sitting in the bounce example** — a verbatim
*"did you mean"* list captured from a live fleet, carrying that repository's name into a skill
meant for anyone. It was also inconsistent with the skill's own convention: every other example
uses `acme-shop`. Generalised. **An example carrying a real name is a leak in anything shared, and
this file is written to be handed to strangers.**

Suite unchanged at **119**.

---

## 6.65.0 — 2026-08-23

**The first-run tour demonstrated a board anti-pattern, in the one step where somebody is learning
what a row is.** Found by running it — its author took the tour on a real repo and watched step 2
append a *second* `CONTROL` row beside the first, one reading *on watch* and one *trying the tour*.

**A claim is a cell you update, not a line you add.** The board is one row per live station —
who · what · where · status — and the task cell is the part that moves. The call-sign, address,
branch and workspace are facts about *the station*; the task and status are facts about *what it is
doing right now*. Step 2 now updates the existing row and says so in capitals, because the wrong
version is the intuitive one.

**Two rows for one call-sign is not a harmless duplicate — it is a shape that reads as
meaningful.** It cost a coordinator real time earlier the same day: a duplicate turned out to be a
live row beside a **retired provenance record**, and an outside reader advised merging them with
line numbers and a rationale, which would have destroyed the thing the second row was kept for.
**A tour that teaches "claiming means adding a line" teaches people to produce exactly that.**

*Nothing found this but running it.* The suite covers the flag, the trigger and the config safety;
the walkthrough is prose the model follows, and the only way to see it demonstrate the wrong thing
was to watch it do so — which is the limit this changelog stated when the tour shipped, arriving
one release later.

Suite unchanged at **119**.

---

## 6.64.0 — 2026-08-23

**A first run that shows up once.** Typing `/mc` for the first time on a machine now offers a
two-minute walkthrough: find or create the board, put one real claim on it, look at the row with
your own call-sign in it, take it back off. **It teaches by doing** — a row somebody has seen with
their name on it is worth more than a paragraph explaining claims.

**No new hook, and the skill keeps its promise to run only when invoked.** `mc-init.sh` already
runs on every `/mc`, so it emits one read-only `TOUR:` line and the walkthrough rides the entry
point that already exists.

**Three outcomes, not two.** Completing it is terminal and declining it is *equally* terminal —
**a first-run prompt that keeps returning is not a tour, it is a nag.** Abandoning it midway
records nothing and it is offered again, because an abandoned tour is not a refused one. `/mc tour`
replays it regardless. A `version` field lets a future rewrite re-offer once without anyone
hand-editing a config.

**The flag is per-machine, not per-repo**, in `~/.claude/mission-control.json` — the file whose own
comment says a clone must never carry someone else's terminal choice. The walkthrough teaches *the
tool*, not the project: you should not retake it in every checkout, and **a teammate cloning your
repo still gets their own first run.** The skill is told to say out loud where the flag went,
because a tool that silently remembers something about a person is one they have to guess about
later.

**It asks before every write, and never creates a second board.** If the repo already has one it
shows them the real one and moves on — *a tour that creates a board beside a real one has taught
them the exact thing this skill exists to prevent.* The deploy step describes and offers rather
than doing: opening a terminal window is the one step with a side effect nobody asked for.

**And it does not end by telling a new arrival to stand down.** The draft's last step was
`/mc standdown`, which is how a station *leaves* — push, report, wait to be acknowledged, exit.
Ending a first run with it reads as *"and now close everything."* It ends by releasing the claim
instead, so they finish where they started having seen a full cycle. **Caught because someone read
the mockup and asked what the word meant** — which is also why `VOCABULARY.md` now carries the
command verbs.

`tour-state.sh` owns the flag rather than the model editing JSON inline: read-modify-write, one key
touched, atomic replace. **An unparseable config is never overwritten** — re-offering a tour is a
smaller harm than truncating somebody's settings — and every hand-written key survives.

**`VOCABULARY.md` gains the thirteen command verbs**, with the three confusable pairs called out:
`standdown` (reflexive — you end your own watch) against `secure` (issued — Control ends it for
you); `board clear` (archives, never wipes) against what it sounds like; `deploy a station`
against shipping to production. The file called itself *the legend* while carrying the concepts and
none of the words people actually type.

**An honest limit:** the walkthrough is prose the model follows, so `tour-state.sh` and the trigger
are tested but *the walkthrough's own behaviour is not* — same caveat as `progress-and-log`
prompting for honesty without enforcing it. Eleven checks cover the flag, the trigger and the
config safety, all under a fake `$HOME`; the suite asserts the tester's own preferences file is
byte-identical afterwards.

`test/e2e.sh` 108 → **119**.

---

## 6.63.0 — 2026-08-23

**Three of the four skills had no automated coverage at all, and today's worst regression lived in
exactly the part of them that is code.** `test/e2e.sh` covered `mission-control` and nothing else.
`work-lock`, `status-and-backlog` and `progress-and-log` are prose — but each contains the shell
that decides **which checkout gets edited**, and that is where the two-roots bug and its
over-correction both lived. Every fix to them shipped today was verified by exactly one manual
field run.

Now covered, and **the blocks are extracted from each `SKILL.md` rather than retyped** — a test
that retypes the code under test is testing the typist. Each is run against five layouts: a repo, a
linked worktree, a subdirectory, a bare repo, and a non-git directory.

**The acceptance pair is the assertion that matters:** a worktree and its main repo must resolve to
the **same remembered root** while keeping **different write roots**. Either half alone passes on a
broken build — which is not a guess, it is measured. Replaying the regression that actually shipped
(write root collapsed into the shared root), *"a worktree still writes to its own checkout"*
**passed**, because `--git-common-dir` returns a relative `.git` from the main repo and an absolute
path from a worktree, so the two roots differed for the wrong reason. The check that caught it was
the stricter one — *the write root is the worktree, **exactly***. **A pair test that only compares
two values to each other can be satisfied by two wrong values.**

Both bugs replayed and both go red: the original per-worktree mapping fails the shared-root
assertion; the over-correction fails three checks including the exact-path one.

**And a test defect found in the same pass, of the class this file keeps cataloguing:** the new
checks failed six times on six correct results, because macOS symlinks `$TMPDIR`
(`/var` → `/private/var`) and the blocks under test normalise with `cd`+`pwd` while the expected
value did not. **The instrument disagreed with itself, not with the code.** Resolved with `pwd -P`.

`VOCABULARY.md` gains the words this work made load-bearing — *write root*, *shared root*, the
*two-roots rule*, *work at risk*, *a prunable worktree*, *a false green*, *an inverted check* —
each with the reason it exists rather than a definition alone.

`test/e2e.sh` 93 → **108**, and for the first time it covers all four skills.

---

## 6.62.0 — 2026-08-23

**A checksum published without naming its algorithm verified four correct files as four
mismatches.** The digests handed over for a sync check were bare `shasum` — SHA-1, truncated to
eight hex. An install manifest exchanged earlier in the same conversation listed 64-hex **SHA-256**
under the same word, `checksums:`. A verifier following the convention *this side had itself
established* got nothing matching on any file, and **the natural conclusion is "the sync did not
land"** — not "the instrument is wrong".

**It is a clean inversion, and it is the third of that shape recorded here** — after `pgrep -x`
returning a false negative for a running Terminal, and `grep -c` counting a comment that documents
a removal as evidence the removal never happened. Every file correct, every check failed, and the
failure pointing away from the truth.

The fix is four characters: `sha1:0cbe8909`, or quote the digest full-length so its length names
the algorithm. **An identifier nobody can reproduce is not evidence, however precise it looks** —
and precision is exactly what makes an unreproducible one persuasive.

Recorded as a row in *A check must be able to observe the thing it claims to measure*. Found by the
station verifying the sync, which noticed that four-for-four failure was likelier to be its
instrument than the work, and checked the instrument.

Suite unchanged at **93**; this is a rule.

---

## 6.61.0 — 2026-08-23

**6.60.0's fix was an over-correction that moved the WRITES, not just the mapping — and the same
mistake had been made in a second skill.** Caught within two minutes by a station that was in the
same file fixing the same bug, and independently by an audit here at the same moment.

**The rule the whole thing turns on:** `--git-common-dir` is for **what should be remembered
once**; `--show-toplevel` is for **anything written or committed**. *One variable cannot be both,
and inside a worktree the difference is not cosmetic.*

`progress-and-log`'s `PROJECT_ROOT` was not only the config root — it is also the write target and
the value printed by the new "About to write to …" step. Pointing it at the main repository fixed
*the mapping dies with the worktree* and introduced **the entry lands in someone else's checkout**:
a station in a lane would edit the SHARED checkout's `PROGRESS-LOG.md` rather than its own, and a
bootstrapped file would be created outside the branch it belongs to. On a repo where several
sessions share one checkout that is precisely the documented way one session's work gets swept into
another's commit. **Two roots now — `PROJECT_ROOT` (write, unchanged) and `SHARED_ROOT` (the
remembered mapping, and nothing else).**

**`status-and-backlog` had the identical over-correction**, made here in the same pass and not
reported by anyone: its `ROOT` drives the `find` whose results are then *edited*, so a station in a
worktree would have edited the shared checkout's backlog. Separated the same way. The discovery
miss it was originally fixing is now handled where it actually bites: **before creating**, look in
the main repository, and **a hit there means DO NOT CREATE** — the backlog exists and your branch
simply does not have it yet.

**`work-lock` had the original bug and nobody had tested that path.** Found by auditing every
remaining `--show-toplevel` rather than waiting for a report. Its `ROOT` is correct as-is and must
not move — it stages, commits and pushes through it — so only the create path changed: check the
main repository before offering to create a board, because **two claim boards is worse than none**,
each looking authoritative and neither showing the claims on the other.

**Two smaller corrections adopted from the same station**, both mine: `--path-format=absolute`
returns empty on git older than 2.31 and silently falls back to `--show-toplevel` — *the original
bug, with no signal* — so the plain form normalised with `cd` is used instead; and plain `dirname`
on a **bare** repo escapes it (`/x/bare.git` → `/x`), so a `*/.git` case guard handles it.

Verified across six cases against the blocks as they appear in the files rather than retyped:
normal repo, subdir, linked worktree, its main repo, bare repo, non-git directory. **The acceptance
test is that a worktree and its main repo resolve to the SAME shared root while keeping DIFFERENT
write roots** — that pair is what the bug was, and it was the check that had been missing.

*Recorded plainly: a peer's fix to my fix was better than mine, and I took it. The failure mode of
a good fix is a second bug in the same lines, which is why the station that had just been told the
answer still went and measured it.*

Suite unchanged at **93** — all three are prose skills; `test/e2e.sh` covers `mission-control`.

---

## 6.60.0 — 2026-08-23

**A retraction first: "`progress-and-log` has never been tested by anyone" was false, and this
changelog said it in those words.** It was relayed to me as an honest coverage gap, I agreed it was
the honest framing, and I published it. A station checked instead of inheriting it and found the
disproof sitting in a real repo:

`​.claude/progress-and-log.config.json`, **mtime five weeks old**, four entries — and writing that
file is something *only the completed multi-file ask path* does. So that branch has run end to end,
on a real project, with a human answering. It is not a default either: the fourth entry carries
`gets: []` and the note *"Leave alone — this is a dated, one-time triage snapshot, not an ongoing
log."* That is a considered human answer, not a generated one. Corroborated independently:
`docs/PROGRESS-LOG.md` holds **215** `##` blocks in exactly the style that config describes.
Verified here rather than taken on report.

**The defensible claim is version-scoped: the CURRENT version is untested. "Never tested by
anyone" is not the same sentence, and the difference is not pedantry** — it sends the next reader
hunting first-run bugs in a code path with five weeks of production use behind it. Corrected above.

**The finding to act on: the blast radius is decided by the current directory, and a saved mapping
suppresses the only question that would have caught it.** The skill takes a TITLE, not a path;
its target derives entirely from cwd; and there is no way to point it elsewhere. A session cannot
always change that — `EnterWorktree` refuses a cross-repo worktree, so a station is stuck in the
repo it was launched in. Step 2 short-circuits **both** detection and the ask when a config exists,
which is true of every repo where this has been used once. **The natural, correct-looking
invocation would have gone straight from "invoked" to editing three live documents in a repository
it had been explicitly forbidden to touch, with no question asked at any point.** It was avoided
only because the station read the skill before running it.

Now a mandatory step that a saved mapping cannot skip: **state the resolved repository and the
exact files before any edit**, and stop for confirmation when that repository is not the one under
discussion, when the session's registered cwd is a different repo, or when a station is pointed at
a repository that is not its own. A saved mapping settles *what goes where*; it does not settle
*which repo*. **An entry written to the wrong PROGRESS-LOG is not a wrong answer in a scratch
file — it is a durable, dated, plausible-looking record in someone else's project.**

**And the saved mapping was per-worktree, not per-repo** — `--show-toplevel` again, the third
place today. The config was written under `.../worktrees/<name>/.claude/`, so *ask once and
remember* degraded to **ask once per station per worktree**, and the mapping died when the worktree
was removed, which is exactly what retiring a station does. Every station re-answered the same
question forever and no station ever benefited from another's answer. Resolved through
`--git-common-dir`.

**Measured positives worth recording, because they are the reason this skill was not the disaster
the above implies.** Detection is genuinely semantic, not filename luck: it surfaced the log, the
status/backlog and the claims board while correctly *excluding* a rules document. On multiple
candidates the ask is a hard gate with no `--yes` escape — so on any fleet repo, which always has
at least two tracking documents, **it is human-gated by construction**. And it never stages,
commits or pushes: its allowed-tools list has no git-write path at all.

Suite unchanged at **93** — `test/e2e.sh` covers `mission-control` only, and that remains the
honest limit of what is automated here.

---

## 6.59.0 — 2026-08-23

**A grep COUNT cannot tell live code from a comment documenting its own removal — and the better a
fix is written up, the more hits it leaves behind.** A coordinator checking whether the
`status-and-backlog` fixes had landed found `--show-toplevel` still appearing twice and
`-maxdepth 2` once, which reads as a fix that never shipped. All three were legitimate: one comment
explaining why `--show-toplevel` is wrong, one correct fallback *after* `--git-common-dir`, one
line documenting the removed depth limit.

**It is the mirror of the wrapped-sentence row already in that table.** One reads absence as
removal; this reads presence as failure. Both come from asking a counter a question only a reader
can answer. **Read the context, never the count.**

Two things make it worth a row rather than a footnote. It was hit **twice in one day by the same
coordinator**, both times against fixes that had landed correctly, both times a hair from filing a
false regression — by the person cataloguing this exact defect class as it happened. And it
punishes good practice specifically: **a well-documented fix is the hardest kind to verify by
grep**, because retiring a name properly means leaving it behind in the note that explains why it
is gone. This repo's own convention of keeping a near-miss documented rather than erasing it — the
`PROBABLY NOT` comment retired in 6.57.0 is the example — would trip the same counter.

Suite unchanged at **93**; this is a rule, not a code path.

---

## 6.58.0 — 2026-08-23

**`status-and-backlog` had five defects and had never been tested by anything.** A station ran it
end to end against a real backlog and filed all five with mechanisms; four are code-read defects it
labelled as such rather than claiming to have observed.

**Discovery resolved the WORKTREE, not the repository — and the miss does not fail safe, it
duplicates.** Step 1 used `--show-toplevel`, so a station on a lane that had not merged the branch
adding the backlog found nothing. **"Not found" falls straight through to "offer to create one".**
Same root-resolution defect as the fleet blackout in `mc-init.sh`, in a place where the consequence
is a SECOND backlog beside the real one — **duplication being the single outcome a backlog-finder
must never produce, and the failure mode of this skill's central claim.** Now resolved through
`--git-common-dir`, and the skill says never to create one from inside a worktree without checking
the shared checkout.

**And the search could not have found it anyway: `-maxdepth 2`, while `docs/planning/BACKLOG.md`
is depth 3.** The depth limit is gone, `node_modules` and `.git` are pruned instead, and the
instruction is to widen the search at the moment you are about to create a file rather than trust
the first look.

**`close` was told to mark an item done and never told how.** One station wrote `- [x] **T6**`,
another invented `- **T6** ✅ **DONE**`. **Done-ness spelled three ways is not greppable**, which is
the one property a closed item needs. Worse, the skill's only two examples use `- [ ]` — the very
format Step 1 forbids imposing on an existing file — so `close` was caught between *match what's
there* and a template contradicting it. Now: copy the file's own convention; if it has none use
`[x]` and nothing else; and the templates are explicitly marked as for files being created from
scratch, with *match what's there* winning over them.

**It never mentioned staging or committing at all — so it could not reach for `git add -A`, and
nothing in it forbade one either.** Every `-A` protection in the run that found this came from the
surrounding fleet rules and the project's `CLAUDE.md`, not from the skill. **Run on its own,
outside any fleet, nothing stopped it** — and a backlog edit is almost always made in a tree
holding unrelated work-in-progress, which `-A` sweeps in behind a commit message that says only
*backlog*. Now an explicit step: stage by path, never `-A`.

**The strongest result in the exercise was a negative one, and it belongs here.** The station hit a
genuinely unexplained cause, recorded it as unexplained with its ruled-out set, then probed the
tempting explanation with `git commit --amend --dry-run`. It was allowed — and it recorded that as
**INCONCLUSIVE rather than as a narrowing, because `--dry-run` performs no rewrite, so the allow
proves nothing.** The tempting write-up was a confident wrong entry of exactly the class this skill
exists to prevent, and it declined it and said why. **Its caveat is carried verbatim: the skill
PROMPTS for honesty and cannot ENFORCE it.** Guidance present and usable is not invention
prevented.

**One caveat retired rather than left standing:** that station's findings were called the most
stable in the exercise *because the file had not moved in six days*. This release moves it. The
findings still attribute to the recorded hash, but anyone re-running them today is testing a
different file, and **a caveat about stability is exactly the kind nothing prompts you to
re-read.**

No test-count change — `test/e2e.sh` covers `mission-control` only. **`progress-and-log` is the one
skill of the four with no coverage of the CURRENT version**, which is a narrower and truer claim
than the one first written here; see 6.60.0. Suite stands at **93**.

---

## 6.57.0 — 2026-08-23

**A hedge in the wrong field quietly widened what a station may claim about itself.** 6.52.0's
honesty fix softened `label-tab.sh`'s verdict from `persists: NO` to `persists: PROBABLY NOT`,
because the overwrite it predicts had been measured *not* to happen once. **The uncertainty was
real and it was put in the wrong place.** `SKILL.md` enforces *"never report a tab as labelled
unless that line agrees"* — so that field is not a prediction, it is the thing the rule is checked
against, and **a station can talk itself past "probably not" where it cannot talk itself past
"no".**

The question the field answers is *may I rely on this label?*, and **unpredictable means no** — a
label whose timing you cannot predict is one you cannot rely on. The verdict is flat again, with
the flat sentence *"You may NOT report this tab as labelled"* stated outright, and the genuine
uncertainty moved into the explanation where it describes the MECHANISM instead of licensing a
claim. Regression-tested: the check fails if the verdict is re-hedged.

Caught by a station that ran `set-callsign.sh` twice in one session straddling an install, same
tty and same launch conditions, and noticed the verdict had moved while nothing about its own
session had. **It is also behavioural evidence that `label-tab.sh` was in the changed set — reached
from the opposite direction to hashing, and agreeing with it.**

**`status-and-backlog` advertised a capability its body never described.** The `description:`
frontmatter promises it *"cross-references items that must land in a given order onto both"*, and
the 152-line body contained no mention of cross-referencing, ordering, or dependencies. **The
frontmatter is what decides whether the skill is invoked; the body is what is actually followed**,
so a promise made only in the description is a promise nobody is instructed to keep. Now a step,
with the rule that a one-sided cross-reference is worse than none — *the person who needs it is
almost never the person who wrote it* — plus naming what the blocker must produce rather than only
that it comes first, and a test for whether a dependency is real at all: **if there is no artefact,
the items are merely related.**

**The harness pins its own working directory per section.** Every `cd` in `test/e2e.sh` is
absolute, but section 7 inherited whatever the previous section left, and 6d's `cd` sits inside a
conditional. **A chained `cd` is how a coordinator produced a confident false FAILURE against a fix
that was correct** — it ran case 2 in case 1's directory and got a warning comparing a path to
itself. The same shape bit this file's author the same day. Latent rather than live, and closed
while it was cheap.

`test/e2e.sh` gains the flat-verdict check and is at **93**.

---

## 6.56.0 — 2026-08-23

**`work-lock` gains the rejection recipe it never had, and it exists because a fleet exercise ran
the push race for real instead of reasoning about it.** The board's one enforcing property was
described in two lines — *"if the push is rejected, pull, look at their row, and if it's the same
job go and talk to them"* — which reads as a discipline somebody has to remember.

**It is not a discipline. It is mechanical, and git tells you which case you are in.** Two stations
claimed concurrently and one rebase produced both answers: a *different* row auto-merged silently
with zero markers, and the *same* row conflicted with both claims preserved verbatim and git
refusing to pick a winner. **The board's teeth are git's 3-way merge, not the paragraph.** An
uncontested claim never asks you to adjudicate; a contested one is impossible to miss.

**The dangerous option is `git rebase --skip`, and git recommends it to you.** Everyone watches for
`--force` — nothing in this flow offers force, and force is not the trap. `--skip` needs no
alarming flag, is suggested by the tool in its own conflict advice, and is exactly what a losing
claimant reaches for to make a conflict go away.

**It is a FALSE GREEN, and that is stronger than "you might not notice".** Measured in an isolated
lane: `--skip` prints *"Successfully rebased"*, exits 0, leaves a clean working tree, an **in-sync**
branch, zero conflict markers, and a board whose row reads correctly — while the claim commit is
reachable from **zero** branches. Every observable reports pass; **the tool itself is what reports
the false pass**, and the board would corroborate a station that wrongly told its coordinator the
claim had landed. Git refuses to commit with an unresolved conflict and warns on a detached HEAD;
here it destroys a commit and calls it success. Recovery exists in `ORIG_HEAD` and the reflog —
both local-only, both expiring, and neither consulted by anyone who has just been told
*"Successfully"*.

The contrast is the prescription, both measured in the same lane an hour apart: `--abort` and
`--skip` both exit 0, but `--abort` retains the claim and leaves the branch reading *ahead 1,
behind 4*, while `--skip` discards it and reads in sync. **`--abort` leaves the disagreement visible
in the branch state; `--skip` resolves it into silence** — which is why the exit code is not the
thing to read. Both are now in the skill as a table, with the false-green table beside it.

*This is the sharpest instance yet of this repo's own rule that a check must be able to observe the
thing it claims to measure — and the first where the tool doing the reporting is the one lying.*

No test-count change: `test/e2e.sh` covers `mission-control` and this is `work-lock`. Extending it
to the other three skills is the open gap, and it is what the fleet exercise is currently probing by
hand. Suite stands at **92**.

---

## 6.55.0 — 2026-08-23

**A four-station fleet exercise against a scratch repo found two defects the single-station testing
could not reach — and one of them was in a regression test written three hours earlier.**

**The NBSP regression test passed on the unfixed build and pinned nothing.** 6.54.0 corrected the
*comment* that claimed a non-breaking space was admitted, and left the *test* built on it in place.
A tester verified the claim instead of inheriting it: NBSP is refused under every locale and both
shells, because **it is not a letter and so never collated among `[A-Za-z]` in the first place.**
The underlying defect is real and is about LETTERS — `é` `ñ` `ä` and fullwidth `Ａ` were admitted
under `en_IN.UTF-8`, Cyrillic and Greek were not, and `LC_ALL=C` refuses all of them. Decisive
pair, same input, same checksum, locale the only variable: `LC_ALL=C` exits 2 at the allowlist,
`en_IN.UTF-8` exits 1 having *passed* it. The witnesses are now `é`, `ä` and fullwidth `Ａ`, each
verified to go red when `LC_ALL=C` is removed; NBSP is kept and **labelled as the negative control
it always was**. *This skill's own rule, failing against itself: mutate it and watch it go red, or
it is not a test.*

**A displaced station reported its entire fleet as strangers.** Peers are classified by the peer's
REGISTERED SESSION cwd — the directory the session was launched in — while the fleet id is derived
from wherever the command is RUNNING. A `cd`-prefixed command is enough to separate them, and
`EnterWorktree` refuses a cross-repo worktree, so there is no supported way to move a session's cwd
at all. Reproduced from a scratch repo: five live peers, **all five OFF-FLEET, including the
coordinator running the exercise and the station being deliberately collided with.** Correctly
computed, from the wrong input.

**This is not the worktree bug; that one is fixed and was verified separately.** It is a second,
independent path to the same symptom — `--git-common-dir` is only as good as the cwd it is handed.
It fails conservatively (a fleet reads as strangers, never the reverse) but it fails **totally**,
and a coordinator reading it concludes it has no fleet.

**The tell was already on screen and nothing noticed it:** `ROOT` and `ME_CWD` disagree, and
`ME_CWD` is the value silently driving every verdict. It now says so, and says what to do instead.
The right answer cannot be re-derived from there — **an honest "I cannot classify this" beats five
confident wrong verdicts.** Regression-tested both ways, because a warning that never goes quiet is
as useless as one that never fires.

`test/e2e.sh` gains six checks — five new and one that was passing vacuously — and is at **92**.

---

## 6.54.0 — 2026-08-23

**Three corrections, two of them to 6.53.0 itself, and one of them to a false sentence 6.53.0 wrote
into a source comment.**

**`mc-init.sh` never disclosed that it fetches, and 6.53.0 claimed it did.** The changelog said
*"both these scripts fetch, and neither said so — the headers now admit it."* That was true of
`preflight.sh` and false of `mc-init.sh`, which was left completely unchanged. Caught by the
reporter re-reading the fixed build against the checkout that produced the original finding. It
matters more than the symmetry: `mc-init.sh` is the **first** thing a station runs, so the
undisclosed write happens before the disclosed one, and from a worktree it writes remote-tracking
refs into the shared `.git` that every other lane reads. Now disclosed, and the other two halves of
that report are fixed with it — the fetch is no longer hardcoded to `origin` while
`resolve_base_ref` goes to real trouble to be remote-agnostic, and a FAILED fetch is reported
instead of swallowed, naming every field computed from possibly-stale refs. **The two scripts had
diverged on the same defect, which is worse than both being wrong the same way: one of them looked
trustworthy.**

**The justification written into the allowlist fix was false, and the disproof was already in
hand.** 6.53.0's comment said a tester had measured a NON-BREAKING SPACE admitted under a UTF-8
locale, and built two further sentences on it — that an *invisible* character could be accepted and
then match nothing. The reporter re-measured with explicit bytes and withdrew it: their literal
NBSP had been normalised to a plain space before it reached the guard. **The measurement that
refuted it had already been run here and was read past.** The collation defect is real and the fix
is right — `é` `Å` `ﬀ` were admitted under `en_IN.UTF-8` and are rejected under `LC_ALL=C`, while
NBSP and ZWSP were rejected under both — but the comment now states the bytes, and the `got:` echo
is re-motivated on characters that are **visually confusable** rather than invisible. *Assert the
bytes, never the literal.*

**The stale-handle bounce hands you a confident wrong answer, and that is the dangerous half.**
Documented here because this skill is the only place anyone reads about the stale `@` header, even
though the behaviour is the harness's. A reply to a renamed peer's `from-name` fails with a *"did
you mean"* list built by string-similarity against the **dead** handle — so it offers that handle's
lexical neighbours, which on a `<repo>-<hex>` fleet is exactly the set of sessions that are not the
sender, and never the sender itself. Observed from both ends, twice: three suggestions, all live
uninvolved stations, correct target absent. **A bounce announces itself and is recoverable; a
confident wrong suggestion is a misdirected-prompt generator** — the station you deliver to has no
way to know it was not the intended recipient. Ignore the suggestions, run `ListAgents`.

**`formerNames` listed the CURRENT name as a former name.** Found by reading the code, confirmed
against a live registry. The filter dropped the name being *replaced* and nothing ever dropped the
name being *adopted*, so any rename that RETURNED to a previously-held name left it in `name` and
in `formerNames` simultaneously — `CONTROL -> CONTROL-PROBE -> CONTROL` produced
`name: CONTROL, formerNames: [..., 'CONTROL', 'CONTROL-PROBE']`. **It fails in the worst possible
place:** the only reason anyone reads `formerNames` is to decide whether an address is stale, so
the field false-positived on exactly the name it was being consulted to validate, inside the
rename-resolution problem it exists to serve. One clause. This is a **second, independent** defect
in that list — the existing warning that `formerNames[0]` is not a reliable start-time name covers
a different case and both reasons to distrust it stand.

`test/e2e.sh` gains the round-trip check and is at **85**.

---

## 6.53.0 — 2026-08-23

**Four sessions field-tested the skill against a real 16-worktree fleet and returned nine
findings. Seven were real, all seven are fixed here, and one of them was a bug in the fix shipped
three hours earlier.** Every one was reported with a mechanism and a reproduction, and every one is
regression-tested. The suite is at **84**.

**`at-risk` printed `ok` over a commit that existed on no remote.** `git -C <missing dir>` exits
128; stderr went to `/dev/null` and `|| continue` dropped the worktree without printing a line — so
five of sixteen worktrees vanished from the check, and a repo whose only unpushed commit lived in a
prunable worktree read as clean. **It is the dangerous direction twice over:** absence of a line
reads as nothing wrong, and the tidy-up a reader runs on seeing *prunable* — `git worktree prune` —
deletes the HEAD ref that is the only thing pinning that commit. The tool said `ok` immediately
before the command that loses the work. git still records a HEAD sha for a missing worktree and
every worktree shares the object store, so it is now measured from the main repo with that sha.
Confirmed live: the reporter had already told their user *"nothing is single-disk"* off a
hand-rolled sweep; the fixed check found the commit their loop missed.

**Then the warning that fix printed was itself wrong, and it was caught the same way.** It said the
worktree HEAD was *the only thing pinning* the commit and told the reader to create a branch —
against a commit a local branch already held. Prune would not have lost it. **The danger was real
but it was the WRONG danger, and the two have different fixes:** sole-pin is fixed by a branch,
no-remote is fixed by a push. A reader following the printed command got a redundant branch, still
had zero remote copies, and had just been told they were rescued. The claim is now checked with
`for-each-ref --contains` before it is made. Both shapes are tested, because a naive fix deletes
the true sole-pin warning — the case that actually loses work.

**AppleScript injection through the worktree PATH.** The call-sign was allowlisted from the start;
the path was escaped for the shell (`'` handled correctly) and then handed to a *second* parser as
an AppleScript string literal, where `"` closes it. A worktree named
`X" & (do shell script "…") & "Y` compiled as concatenation around a live call — proven by
`osacompile`/`osadecompile` without ever running it. **Escaping the input that looked dangerous
instead of every input that reaches the parser.** Both literals are now escaped, backslash before
quote, and the regression test captures what is actually handed to `osascript`.

**The allowlist was a collation range, so it did not mean what its message said.** Under a UTF-8
locale it admitted accented letters and a NON-BREAKING SPACE while promising "letters, digits,
spaces and . _ / & - only". Nothing exploitable — no quote or metacharacter homoglyph passes — but
a call-sign carrying an invisible space is accepted and then matches nothing anywhere else, and the
refusal could not be acted on because it never showed the offending character. Matched under
`LC_ALL=C` now, and the refusal echoes the input.

**`REPO:` named the directory you were standing in, not the repository.** `basename` of
`--show-toplevel`, which for a station inside a worktree *is its own worktree*: a station in
`.claude/worktrees/backend` printed `REPO: backend`. **It fails invisibly** — lanes are named
backend, finance, channels, backlog, every one a plausible repo name. Derived from
`--git-common-dir` now, the same value the PEERS block already computed correctly.

**`COORDINATOR:` was read out of a wrapped prose sentence.** The legacy pattern anchored at `^` and
stopped at the name, so any line *beginning* with the word matched — and paragraph reflow puts
words at column 1 for free. A real project resolved its coordinator from the middle of the sentence
*"Control was right to rule out `passWithNoTests`."* The answer happened to be right, which is the
kind of wrong that survives testing: reflowing that paragraph would have silently changed a
load-bearing value. It must now be a declaration — the whole line reduces to the name. The old
pattern was wrong in **both** directions, and the fix corrects both: it read a coordinator out of
prose, and it missed a genuine `# FLEET COMMAND` heading.

**Rules were read from the working tree while the board was read at the ref.** Same block, opposite
treatment — a station in a lane resolved its coordinator and its rules from a file 64 commits
behind (38 diff lines apart), under a banner saying those names *win over any default*. Both are
ref-pinned now, and a working copy that differs from the ref is called out rather than silently
preferred.

**A failed `git fetch` was silent, and it inflates.** Every number `at-risk` prints depends on
remote-tracking refs; offline or with expired credentials they are stale, so work a peer already
pushed reads as existing nowhere else. Reported now, naming the direction of the error. Both these
scripts fetch, and neither said so — they are measurement tools that write refs, and the headers
now admit it.

**Two worktrees could render as the same label.** Two path components were printed, and a fleet
whose scratchpads are all `<uuid>/scratchpad/board-flip` rendered three different worktrees as one
string, with the discriminator one level above the window. The label now widens until unique, and
prints the whole path rather than an ambiguous one — long beats ambiguous when the next step is
`rm`.

---

## 6.52.0 — 2026-08-23

**The suite relabelled the tab of anyone who ran it.** A field tester ran it twice and reported the
constraint violation before the results: custom title `[◐ Claude Code]` before, `[MCTEST]` after.
The identity section called the REAL `label-tab.sh` with `MCTEST` — a call-sign that passes every
guard — so it walked the parent chain to the live tty and ran `set custom title of t` against the
tester's own Terminal tab. **The header two screens above promises it never opens a terminal or
renames a live session. It was doing the tab half of that on every run.**

**It hid behind the very behaviour the skill documents.** Claude Code rewrites the tab title at
each status change, so on a plain session `MCTEST` is overwritten within the turn and nobody sees
it — which is why it survived this long here. On a session run with
`CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1`, which by measurement writes **no** title of its own, there
is nothing to overwrite it and **the relabel is permanent**. The configuration this skill documents
as *"the custom title stands alone"* is precisely the one it silently vandalised.

**Second order, and worse away from this machine:** `tell application "Terminal"` LAUNCHES
Terminal.app when it is not running. On an iTerm2, Ghostty or VS Code host, a test suite promising
never to open a terminal opens one. Not observable here, correctly reasoned by the tester from the
AppleScript.

**The damning part is the distance.** 6.51.0 had just copied `set-callsign.sh` away from
`label-tab.sh` specifically so no `osascript` could reach a real tab, and was scrupulous about it.
One hundred lines later the same file did the thing that care was taken against. *Care applied at
one site is not a property of the file.*

`osascript` is now stubbed **suite-wide**, beside the existing `tmux` and `wt.exe` stubs — not just
at the tab test. The other two `label-tab.sh` calls are refused by input guards before any
AppleScript runs, which is true and is also **guard ordering**, and ordering is what regresses; the
stub means the suite cannot relabel a tab even if a guard moves. It also tests *more* than the live
call did, because a tty that does NOT match can now be simulated: the unmatched path is asserted to
report `NO-MATCH` and exit 1, which no live run could ever reach on a machine where the tab exists.

**Verified by the thing that was missing before: a before/after measurement.** Tab title snapshotted
either side of a full run — identical, stderr empty. Both new checks mutation-tested.

**Also from the same report, and it re-reads every green run in this file:** the tester's stdout was
not a tty, so `G/R/Y/Z` were empty and every check they ran took the UNCOLOURED path. 6.51.0's
`readonly` colour guard was never under load there. A green run says less than it looks like it
says, and the tester said so unprompted rather than banking the pass.

`test/e2e.sh` gains four checks and is at **62**.

---

## 6.51.0 — 2026-08-23

**The call-sign clash test drew the tester's own session out of the live registry and failed on
it.** It picked a name off `~/.claude/sessions` to guarantee a real collision, taking the glob's
first live entry — which is as likely to be the session running the test as anyone else's. It was.
`set-callsign.sh` skips its own file when scanning for a clash, correctly, so there was no clash to
find and the assert landed on `address already fleet-command-a4`. **The script was right and the
test was wrong**, which is the reading that takes longest to reach when a suite goes red.

**It was also unsafe in the direction nobody looks.** Had the clash check regressed, that same test
would have renamed the tester's OWN live session — the one thing the file header promises never
happens. It survived only because name==name exits early, i.e. by luck, on the path where the
guard it was testing was already broken. **A test that borrows live state to prove a point is
flaky; one that can mutate live state when the code under test regresses is a hazard wearing a
test's clothes.**

So build the registry instead of borrowing one. `set-callsign.sh` resolves its registry through
`$HOME`, so a fake `$HOME` gives the test a private one: our own entry under the REAL claude pid —
it walks the true parent chain and will not be fooled about who it is — plus a peer whose liveness
the test chooses. Copied WITHOUT `label-tab.sh` beside it, so the tab surface takes its documented
skip and no `osascript` ever runs against somebody's terminal.

**That unlocked four paths that could not be tested before at any price**, because every one of
them ends in a real rename: a dead session's call-sign is free, the rename lands with
`nameSource=user`, the former name is kept, and re-setting the same name is a no-op that does not
re-log it. Verified by mutation, not by reading: removing the clash guard, treating dead sessions
as live, and dropping `formerNames` each turn the relevant checks red and leave the rest green.
Under every mutant, *the tester's own session was never renamed* still passes — which is the
property the fake `$HOME` was for.

**A second bug, in the harness, found only because a mutant made a FAIL line render:** the new
block used `R` as a scratch variable. `R` is the harness's red escape, read by `no()`. Assigning it
blanked the colour for every failure after it and printed the registry contents where the escape
belonged — `OLDNAME None FAIL  the registry carries the new name`. **It is invisible on a green
run**, which is when nobody is reading the FAIL path. Renamed to `REGN`, and `G R Y Z` are now
`readonly` so the next clobber says so on stderr instead of quietly eating the output.

**The README said 28 end-to-end checks.** It has been 43, 45 and 49 since that number was written.
Now 58, and it names the rename section and how it stays off live state.

**Measured in passing, and it is the documented trap reproducing in the wild:** a peer renamed
itself mid-exchange, and a reply addressed to the `from-name` on its message bounced with *no agent
named … is reachable*. The address had moved; the start-time name stamped on the envelope had not.
Resolving the peer by its current name delivered. The rule that says *resolve names, never reply to
a from-name* is not theoretical, and the failure is silent to the sender who does not check.

`test/e2e.sh` gains ten checks — nine new and the one that was failing — and is at **58**.

---

## 6.50.0 — 2026-08-23

**`at-risk` computed the right number, used it only as a gate, and then printed the wrong one.**
Reported with the mechanism and reproduced here from scratch: a lane that had merged the base
branch in without pushing reported **7 commits at risk, every one of them sitting on
`origin/main`.** The truth was 1 — the merge commit.

**The two numbers had different bases and only one was ever printed:**

```
n    = rev-list --count HEAD --not --remotes   -> 1   content, ALL remotes   (gate only)
ours = git cherry "$up" | grep -c '^+'         -> 7   reachability, ONE ref  (printed)
```

Commits merged in from the base branch are not reachable from *this branch's* upstream, so
`cherry` marked every one of them `+`. **The header two lines above the output disclaims exactly
this error** — *"`--not --remotes`, i.e. content. NOT `rev-list --count origin/main..HEAD`, which
counts reachability and reports danger for work already upstream"* — and then the AT RISK line
did it anyway.

**It failed in the dangerous direction: it inflates risk.** This repo had already had one false
at-risk alarm, six doc commits reported as a day's exposure when the content was upstream. **A
tool that cries wolf about lost work is one a station stops reading on the night something really
is lost.**

**Worse, it contradicted the instrument this skill had just told everyone to trust.** 6.49.0 put
`git log --oneline HEAD --not --remotes` beside the stray-worktree warning as *the* executable
test. A reader running it by hand got **1** while `preflight at-risk` said **7** — two instruments
in one skill disagreeing, with the hand-run one correct.

**The fix follows the stated contract:** the list is now the `--not --remotes` set directly.
`cherry` is kept for the one thing it is genuinely good at — spotting a commit whose *content*
already landed under a different sha, which `--not --remotes` cannot see — and is used **only to
move commits OUT of the at-risk list, never to put them in.**

**Both shapes are now regression-tested**, because the second is the reason `cherry` was there and
a naive fix would have deleted it: a lane with the base merged in (expect 1, the merge) and a
commit whose patch already landed upstream under another sha (expect *safe · duplicate by
content*). `test/e2e.sh` is at **49**.

---

## 6.49.0 — 2026-08-23

**A coordinator came ten seconds from deleting a live station's only copy of its own board row,
and the thing that stopped it was a rule in this skill. This release gives that rule teeth.**

**What nearly happened.** Six detached throwaway worktrees. The coordinator classified them as
dead-session leftovers, told a station it would clear them, and ran the check first. One held
`d701f02` — *"lock: FINANCE re-manned a third time"*, unpushed, in the **live** FINANCE station's
scratchpad. Removing it destroys a station's only copy of its own row while that station is
mid-write, and a detached HEAD has nothing to recover it by.

**The failure was not carelessness — it was a premise that its own action had invalidated.** It
judged which scratchpads were dead using timestamps formed **before it deployed four stations**,
and four of the six had been created in the very minute it raised the fleet. *"My own action
invalidated my own premise, and nothing prompted me to re-check it."* That is **a stale reading of
a live source (6.35.0) wearing different clothes — applied to a roster instead of a registry.**

**The rule said do not tidy someone else's throwaway. It did not say how to tell.** Now it carries
the one command that settles it, beside the warning:

```
git -C <worktree> log --oneline HEAD --not --remotes    # non-empty = IN FLIGHT, full stop
```

**Non-empty settles it regardless of what you believe about whose it is or whether that session is
alive.** *A rule with an executable test beside it prevents the mistake; a rule without one only
describes it afterwards* — which is the coordinator's own critique of two of the four rules in
6.46.0, applied here.

**And a real bug the near-miss exposed in the check that was supposed to help.** `preflight at-risk`
did flag the commit — labelled **`HEAD`**. A detached worktree's branch *is* the literal string
`HEAD`, so a fleet with six detached scratchpads printed six rows all called `HEAD`, and **the one
question a reader has at that moment is which directory holds the work**, because that is the
directory they must not remove. It now prints `detached  <parent>/<worktree>`.

**New standing rule for Control specifically:** after you deploy anything, **every judgement you
formed about who is alive is stale — re-derive it before classifying a single worktree as
abandoned.** The trap is specific to the minutes after a deploy, which is exactly when a
coordinator is most likely to be tidying up.

`test/e2e.sh` gains two regression checks and is at **45**.

---

## 6.48.0 — 2026-08-23

**A coordinator tested 6.47.0 against a real 68 KB board, thirteen worktrees and live remotes, and
returned eight passes and five findings. All five are fixed here.** It changed nothing to make
anything pass, and it reported a negative result it had expected to be a bug — which is the part
worth copying.

**The real bug: `at-risk` was adding untracked scratch to tracked edits and calling the total
"uncommitted work (dies with a tidy-up)".** Six flagged files across two worktrees were *all* gate
logs; not one line of source was at risk, and establishing that took a hand check of all thirteen
worktrees. **The header did the damage** — it is the sentence that makes a reader think source is
in danger. Now split: tracked modifications are named as real work lost by a checkout or reset;
untracked is counted separately and labelled scratch, with an explicit line saying an untracked
count alone is not grounds to report work in danger. **This skill's own rule, failing against
itself: a check must be able to observe the thing it claims to measure.** It was observing
`git status` and reporting *work*.

**Rule 3 had a duty gap, and it was the one rule that would not have prevented the mistake it was
written from.** It said *re-check every external blocker before reporting a station blocked* — but
nobody was reporting a station blocked. The coordinator probed Docker for an unrelated reason and
found rows that had carried *"gate when the daemon returns"* for nine hours after the daemon
returned. **The reader of a blocked row and the person who learns the world changed are different
people at different times.** The duty now runs both ways and is joined to the hold-expiry rule that
already said the other half.

**Rule 2 was in the wrong place to fire.** *Do not collapse rows that merely look duplicated* sat
in the row section, which a station reads at identify; **the mistake happens during board
cleanup.** A rule only prevents a mistake if it is in front of the person about to make it. Now
cross-referenced from *"Clear the board" almost never means delete the rows*.

**And the rule that was missing entirely — the general form of this repository's own error:**
**an outside read of your board has less context than the board does.** An off-fleet session read
the board, correctly found six dead rows, and recommended collapsing two — with line numbers, a
rationale and a resolution. It was wrong, because the second row was a retired provenance record
whose reason for existing is invisible from a row read. **The precision of the report is what made
it persuasive, and it is also what made it wrong.** An outside read is a hypothesis; the rows are
the evidence. Take the parts naming something checkable and check them; refuse the parts asking you
to destroy something whose purpose you would have to already know to defend. *Including advice from
this skill, which is an outside read of every fleet but the one it was written from.*

**Cosmetic, both from the same report:** a detached worktree printed `HEAD: HEAD @ abc1234` and now
says `detached`; and `DIRTY: … in the shared checkout` was printed to stations running inside a
worktree, describing the wrong directory — it now names what it measured and splits tracked from
untracked for the same reason `at-risk` does.

`test/e2e.sh` gains five regression checks and is at **43**.

---

## 6.47.0 — 2026-08-23

**The scripts hardcoded `origin/main`, so five of six common repository layouts read as having no
board at all.** Fourteen references across three scripts, and no check that a remote even existed.
A project on `master`, `trunk` or `develop`, or whose remote is not called `origin`, or with no
remote — every board read came back empty, and the coordinator politely offered to create the
board that was sitting right there. **Same class as the hardcoded board path in 6.43.0, and a far
larger share of adopters.**

**Now resolved, in order:** `MC_BASE_REF` if set → the remote's own published default branch
(`refs/remotes/<remote>/HEAD`) → the first of `main`, `master`, `trunk`, `develop` that exists on
that remote → and with **no remote at all**, the local branch, *flagged as such*.

**That last flag matters more than it looks.** With no remote, `AHEAD` and `BEHIND` are measured
against yourself: both read `0`, which is exactly what a fully pushed, fully agreed branch prints.
**Nothing has been agreed with anyone.** The preamble now says so on the line, rather than handing
a reader a zero that means the opposite of what they will take it for.

**One rule instead of thirty-six edits.** `SKILL.md` and the reference files say `origin/main` in
about thirty places because a concrete ref reads better than a placeholder. Mechanically rewriting
each was the larger risk. Instead there is now a single normative statement at the preamble:
**wherever this skill says `origin/main`, it means `BASE_REF`** — the value the preamble prints —
and that governs every command and every row.

**Verified across six layouts** (`main`/`master`/`trunk`/`develop` on `origin`, a remote named
`upstream`, and no remote at all), all now finding the board; previously only the first worked.
`test/e2e.sh` covers all six and is up to **38 checks**.

**Wording:** *"muster… no roster, no ceiling"* became *"bring up as many as the job needs: nothing
to register, no limit"* — the same fact, in words that do not need a glossary. The naval register
stays where it is doing work: **command a fleet · call-sign · holds · reports to a live board ·
stands down · the same ground · goes down with the window.**

---

## 6.46.0 — 2026-08-23

**A coordinator cleaned a dead fleet's board, and corrected the session that had told it how.**
Four rules, all from that run, and one of them is a retraction of advice sent an hour earlier.

**A ROW IS A CLAIM, NOT A MEASUREMENT — and the address is only the cell people remember to
doubt.** A row said a station was *"writing now"* on a file that **does not exist** — not on disk,
not on any remote ref — and had read as work in progress for a day. Another row's branch cell
pointed at a *pre-rescue tip*, several commits behind the branch's real head, including the commit
that mattered. **A stale branch cell is worse than an empty one**: it invites a reader to reason
confidently about the wrong tree. Verify what a cell asserts in the same pass you verify who holds
it.

**Do not collapse rows that merely look duplicated — and this repository was the source of the bad
advice.** A relay from here recommended merging two `CHANNELS` rows and offered *"the honest one
may be the one to keep"*. The coordinator refused, correctly: the upper row was the **retired
record of a previous holder**, kept for its provenance, and a coordinator had *already once caught
a station about to flip it*, which would have overwritten that provenance with its own arrival.
They are two rows deliberately. **"Keep the honest one" is not a resolution; it loses whichever you
drop.** Archive, never merge.

**A blocker naming an outside condition outlives the condition.** Rows still carried *"gate when
the daemon returns"* — the daemon had been back for nine hours. **Nothing tells a board when the
outside world changes.** The cheapest lie on a board is a true statement that stopped being true.

**Archiving can make a board bigger.** The cleanup removed three done rows, added stand-down
evidence for five, and the file **grew 66,147 → 68,444 bytes**. Measure after, not before —
*"I archived things"* is not evidence the ceiling moved, and recording it as addressed while it
grew is how a size limit reaches the day it actually fails.

**Also worth keeping, from the same reply:** the loss check that made "nothing was lost" sayable
was `git log HEAD --not --remotes` across **all thirteen worktrees**, not just the lanes named on
the board — a wider claim than any previous coordinator had made, and the reason the sentence was
safe to write.

---

## 6.45.2 — 2026-08-23

**6.45.1 kept the naval nouns and made every verb plain, which drained the register it was
supposed to set.** *Fleet*, *call-sign* and *station* sat in a sentence that otherwise said *run*,
*shows* and *is not duplicated* — the vocabulary was there and the voice was not. Tone lives in
verbs, and that was the miss.

Raised: **command · takes a call-sign · holds · reports to · stands down · the same ground ·
goes down with the window · muster · no roster, no ceiling.** Every one of them is a word this
skill already uses operationally — `standdown` is a command, a station really does hold a
worktree, and *nothing goes down with the window* is the exact failure the whole project exists to
prevent, not a flourish.

**The constraint from 6.45.1 still holds and is what keeps this from being costume:** the concrete
anchors stay in the sentence. A reader still learns there is a call-sign, a git worktree per
session, and a shared board, because those are what the thing does. The register is how it is
said; the facts are not negotiable.

---

## 6.45.1 — 2026-08-23

**Register set to match the project's own name, without spending the clarity 6.45.0 bought.** The
repository is called Fleet Command; *fleet*, *call-sign* and *station* are its native words, not
jargon borrowed for effect. Two extremes were drafted and both rejected — a plain version that
read like any other utility and gave the name nothing to stand on, and a heavier one stacking four
metaphors in one sentence, where *"no two stations work the same ground"* sounded good and told a
reader nothing about what the tool does.

**The rule kept: every clause still has to state a fact.** *Call-sign* and *git worktree* survive
because they are what actually happens; *"stands down cleanly"* and *"nothing goes down with the
window"* did not, because they decorate rather than describe. One naval word per idea, and the
rest in ordinary English.

Applied to the GitHub description and the README's first lines so the outside voice and the inside
explanation agree.

---

## 6.45.0 — 2026-08-23

**The outward-facing description contradicted the skill's central claim, and understated it.**
`SKILL.md` has said *"any number… there is no fixed roster and no ceiling"* since 6.26.0. The
GitHub description and the README both said **"several sessions"** — which reads as *three or
four*, and is the first and often only thing anyone reads. **A project that undersells its own
main property in the one place people actually look has a documentation bug, not a wording
preference.** Both now say as many as you want, and the README states plainly that there is no
roster to set up: open a window, name it, it is part of the group; close it and it is not.

**Jargon removed from the places a newcomer meets first.** *"Comes on watch as Control, takes the
call-sign, writes its row, and reports the board"* is four pieces of vocabulary in one sentence,
none defined yet. The quick start now says what happens in ordinary words — it becomes the
coordinator, names itself, tells you who else is working — and explains a worktree the first time
it appears rather than assuming it. The internal vocabulary is still exact everywhere it matters;
it is just no longer the first thing a stranger has to decode.

**And a stale claim the rewrite exposed:** the README still said *"tab labelling uses macOS
Terminal.app; everywhere else it degrades to a no-op"*, written before 6.41.0. That is now wrong
in the direction that loses users — naming works anywhere Claude Code runs, and opening windows is
automated on macOS Terminal.app, in tmux (Linux, Windows via WSL, and inside VS Code), and in
Windows Terminal. Anywhere else it prints one line to paste, **which is not a lesser path, because
opening a window was the only part a human was ever doing.**

**The quick start also gained the step that was missing:** *repeat for as many windows as you
want — they do not have to be started in any order and none waits for the others.* That is the
fastest way to raise a fleet, it was already true, and the guide described only the slower one.

---

## 6.44.0 — 2026-08-23

**`test/e2e.sh` — the whole flow, executed rather than asserted.** 28 checks over the path a new
adopter actually walks: a fresh repo with nothing set up, a board appearing, a project naming its
own board and coordinator, a station inside its own worktree, deploy on every host, every input
guard, and the identity surfaces. Run it against this repo (`bash test/e2e.sh`) or against what is
installed (`bash test/e2e.sh ~/.claude/skills/mission-control`). Both pass 28/28.

**This is 6.25.0's rule applied to the thing that keeps breaking:** ship the checks as code,
because more rules were never going to work. 6.33.1 shipped a script that passed `bash -n` and died
on its first real run — **every check here executes.**

**Two failures the test found while being written, both mine, both worth recording:**

- **A test that hardcoded a live call-sign.** It asserted that taking `CONTROL` is refused. When
  the fleet that held `CONTROL` shut down, the name was free, so `set-callsign.sh` correctly
  succeeded — **and renamed the session running the test.** A test whose result depends on who
  else happens to be running is not a test, and one that mutates live state to prove a point is
  worse than an untested line. It now derives the clash from whatever is actually running and
  **skips** when nothing is.
- **`REPO=$(newrepo)` runs in a subshell, so its `cd` never reached the caller** — and every
  section after it wrote into whatever repo the test was launched from. It committed the test file
  into this repository under the message *"board"* before anyone noticed. Nothing was pushed and
  the `origin/main` pointer was untouched; the commit was reset and the stray worktree pruned. The
  fix is one `cd`, and the reason it is commented in the file is that it failed silently in exactly
  the direction that looks like success.

**The test cleans up after itself** — throwaway repos under `$TMPDIR`, removed on exit; it never
writes to your board, never opens a terminal, and never renames a live session.

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
