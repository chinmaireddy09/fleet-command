---
name: progress-and-log
version: 4.1.0
description: Lightweight, user-owned progress checkpoint — self-contained, no init or preamble. Detects whatever progress, status or backlog document a project already keeps, by content and purpose rather than a fixed filename list, asks once how to split updates when several exist, remembers that mapping, and creates a new file only when none exists at all. Writes what happened and why so it survives the session that learned it. Runs only when explicitly invoked — never on generic "save progress" phrasing.
author: Chinmai Reddy (@chinmaireddy09)
source: https://github.com/chinmaireddy09/fleet-command
license: LicenseRef-FleetCommand-1.1
attribution: "progress-and-log by Chinmai Reddy (@chinmaireddy09), Fleet Command License 1.1"
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - AskUserQuestion
---

# /progress-and-log — Save Progress, Self-Contained, Adapted Per Project

A plain, self-contained checkpoint skill. It calls **no** external binaries,
runs no telemetry, upgrade or sync preamble, and writes nothing outside the
project and its own output file. It exists specifically so progress can be
captured without pulling in a heavier checkpointing system.

**Core behavior: every project is different — detect, don't assume.**
Real projects name their living progress/status document all kinds of
things: `PROGRESS.md`, `PROGRESS-LOG.md`, `STATUS.md`, `WORK-LOCKS.md`,
`PROJECT-STATUS-AND-BACKLOG.md`, `CHANGES.md`, `CHANGELOG.md`, `NOTES.md`,
`ROADMAP.md`, lowercase variants, or something else entirely — and some
projects have **more than one**, each serving a genuinely different purpose
(e.g. one project might have a chronological log, a separate
current-work/claims file, and a separate backlog/status file, all at once).
**Never rely on a fixed filename list, and never assume a single file.**
Detect the right file(s) by *purpose* for THIS project, every time.

Once found, **match each document's own conventions** — its section
terminology, date format, and entry structure — rather than always stamping
the same generic template onto every file in every project. If nothing
suitable exists, create a new file shaped simply for that project's context,
not a clone of any other project's file.

**HARD GATE:** Do not invoke this skill on generic phrasing like "save
progress," "save the progress," "save my work," or "log where we are." Those
phrases are registered triggers of other checkpointing skills, and must NOT
fire this one — or those — automatically. Only an explicit, unambiguous
request counts: the user typing `/progress-and-log`, or saying "progress and log" /
"log the progress" in close to those words. If a request is ambiguous, ask
rather than guessing.

**HARD GATE:** Do not implement code changes. This skill only writes/edits
progress note(s) — never touches source code, config, or anything outside
the detected (or newly created) progress document(s).

**HARD GATE:** Never overwrite, reformat, reorder, or delete existing content
in a detected file. Only ever insert a new entry into a section this skill
clearly owns (see Step 4), never touch anything else in the file — a
project's progress document(s) may follow a careful hand-curated convention
that this skill must not disturb.

## Detect command

- `/progress-and-log` or `/progress-and-log <title>` → **Save**
- `/progress-and-log list` → **List** recent session notes for the current project

## Save flow

### Step 1: Gather git state

```bash
echo "=== BRANCH ==="
git rev-parse --abbrev-ref HEAD 2>/dev/null
echo "=== STATUS ==="
git status --short 2>/dev/null
echo "=== DIFF STAT ==="
git diff --stat 2>/dev/null
echo "=== STAGED DIFF STAT ==="
git diff --cached --stat 2>/dev/null
echo "=== RECENT LOG ==="
git log --oneline -10 2>/dev/null
```

If not inside a git repo, skip the git-derived fields — this skill works in
any project, git or not.

### Step 2: Check for a saved per-project mapping first

Before searching, check whether this project already has a saved decision
from a prior run:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
CONFIG="$PROJECT_ROOT/.claude/progress-and-log.config.json"
[ -f "$CONFIG" ] && cat "$CONFIG"
```

If `$CONFIG` exists, `Read` it. It has this shape:

```json
{
  "version": 1,
  "files": [
    { "path": "docs/PROGRESS-LOG.md", "role": "narrative-log", "gets": ["working-on", "decisions", "notes"], "update_style": "free text describing how entries look in this file, e.g. dated H3 headings, newest first, prose paragraphs" },
    { "path": "WORK-LOCKS.md", "role": "current-claims", "gets": ["working-on"], "update_style": "one line per active claim: `- {date} {who/agent}: {title} (in progress)`; remove/replace the prior line for the same title rather than accumulating" },
    { "path": "PROJECT-STATUS-AND-BACKLOG.md", "role": "status-and-backlog", "gets": ["remaining-work"], "update_style": "bullet appended under the existing `## Backlog` heading, matching its existing bullet style" }
  ]
}
```

Verify every listed `path` still exists. If all still exist, **use this
mapping directly — do not re-detect, do not re-ask.** Skip to Step 4, using
this mapping. Only re-run detection (Step 3) if:
- the config file is missing, OR
- a listed file no longer exists, OR
- detection (Step 3) surfaces a plausible new candidate file not already in
  the config (in which case, tell the user what's new and ask whether to add
  it to the mapping, update the mapping file, then continue).

### Step 3: Detect the project's progress/status document(s) — by purpose, not filename

Only runs when Step 2 found no usable saved mapping.

**3a. Follow explicit pointers first (highest confidence).**

```bash
grep -riE "(progress|status|backlog|worklog|changelog|roadmap|lock)[^.]*\.md" \
  CLAUDE.md AGENTS.md README.md README 2>/dev/null
```

Any filename(s) surfaced here are strong candidates.

**3b. Broad, purpose-pattern glob**, independent of 3a:

```bash
find . -maxdepth 2 -type f -iname "*.md" \
  | grep -iE "(progress|status|backlog|work[-_]?log|work[-_]?lock|change[-_]?log|changes|roadmap|notes)" \
  | grep -v node_modules
```

**3c. Merge candidates from 3a and 3b** into one deduplicated list.

- **Zero candidates** → nothing exists. Go to Step 4's bootstrap path.
- **Exactly one candidate** → that's the target. Go to Step 4, single-file
  path (no need to ask about splitting — there's nothing to split across).
- **Two or more candidates** → this is the multi-file case. Do NOT guess
  which content goes where. `Read` each candidate file (enough to see its
  structure and any obvious purpose — e.g. a file titled "locks" that lists
  who's working on what right now reads very differently from a narrative
  log or a backlog). Then ask the user, once, via `AskUserQuestion`:

  > Found multiple tracking files: `{list}`. For each, what should
  > `/progress-and-log` write there — a full session narrative, just a
  > current-work claim line, just backlog/remaining-work items, or should
  > this one be left alone entirely? (You can also describe the format each
  > one already uses, or I'll infer it from what's there and confirm.)

  From the answer, build the `files` array (role, `gets` categories chosen
  from `working-on` / `decisions` / `remaining-work` / `notes`, and an
  `update_style` — either what the user described, or your own read of the
  file's existing convention, stated back to them for confirmation before
  saving). Write this to `$CONFIG` (create the `.claude/` directory if
  needed):

  ```bash
  mkdir -p "$PROJECT_ROOT/.claude"
  # write the JSON shape above to $CONFIG
  ```

  Then remind the user once: "Add `.claude/progress-and-log.config.json` to
  `.gitignore`?" — only add it if they say yes.

### Step 4: Write the entry/entries

Break the session's content into these categories before writing anything:
- **working-on** — 1-3 sentences, the current goal.
- **decisions** — bulleted, with reasoning, not just the choice.
- **remaining-work** — numbered, priority order.
- **notes** — gotchas, open questions.

**Multi-file case (mapping from Step 2 or 3c):** for each file in the
mapping, write only the categories listed in its `gets`, formatted per its
`update_style`. If a file's `gets` is empty or the mapping says "leave alone,"
skip it entirely this run. Use `Edit`, never `Write`, on each file — touch
nothing outside the section/line this skill owns in that file.

**Single existing file (Step 3c found exactly one, or historically-detected
single-file project):** `Read` it first (at least ~40-60 lines, skim
further). Identify its own heading/terminology/date-format conventions.
Find or create one section this skill owns for its entries — named to fit
the document's own voice, not forced to a fixed phrase — and insert all four
categories there, newest entry first (or appended at the end, matching
however the rest of the document already orders content). Use `Edit`, never
`Write`.

Entry shape (adapt wording/headings to the target file's own voice):

```markdown
### {ISO date/time} — {title}

**Working on:** {1-3 sentences}

**Decisions made this session:**
- {bulleted, with reasoning}

**Remaining work:**
1. {numbered, priority order}

**Notes:** {gotchas, open questions}
```

**Bootstrap (nothing found in Step 3, zero candidates):** create a new,
simple file — don't clone any other project's structure:

```bash
if [ -d "$PROJECT_ROOT/docs" ]; then
  TARGET="$PROJECT_ROOT/docs/PROGRESS.md"
else
  TARGET="$PROJECT_ROOT/PROGRESS.md"
fi
echo "TARGET=$TARGET"
```

(Non-git, non-code scratch directory → fall back to
`.claude/progress-log/<timestamp>-<slug>.md`, sanitized by allowlist so a
title can never escape into the path.) Seed minimally: a one-line title,
one sentence on the file's purpose, and the first dated entry (all four
categories). Tell the user a new file was created and where — more
consequential than appending to something existing.

### Step 5: Confirm

```
PROGRESS LOGGED
════════════════════════════════════
Title:   {title}
Branch:  {branch, or "n/a"}
Files:   {path — "appended" | "created"}  (one line per file touched)
════════════════════════════════════
```

## List flow

Re-run Step 2/3's detection (using the saved mapping if present) to find the
project's document(s), then show whatever entries exist in each file's
skill-owned section as a numbered list (newest first), grouped by file if
there's more than one. If none found, say so — don't create anything just to
list it.

## Important Rules

- **User-level skill, works in any project** — lives in `~/.claude/skills/`,
  not tied to any specific repo or skill suite.
- **Detect by purpose every time, per project — and per file when there's
  more than one.** No fixed filename list, no copy-pasting one project's file
  shape (or mapping) onto another.
- **Ask once for multi-file projects, then remember.** Save the mapping to
  `.claude/progress-and-log.config.json` so future runs in that project
  don't re-ask — only re-confirm if the file set actually changes.
- **Own only the section/line you write, per file, using vocabulary
  consistent with the rest of that document.** Never edit, reorder, or
  remove content outside your own entry.
- **A "locks"/claims-style file may need a completely different entry
  shape than a narrative log** (e.g. a single current-claim line that gets
  replaced, not an accumulating dated entry) — don't force the same
  four-category markdown block onto every file type. Ask or infer, per file.
- **Never modify source code.** Note-writing only.
- **Never fire on generic "save progress" phrasing.** Explicit invocation
  only — `/progress-and-log`, "progress and log," or "log the progress."
