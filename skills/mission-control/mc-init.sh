#!/bin/bash
# mc-init.sh — everything a station needs to start, in ONE command.
#
# WHY THIS EXISTS. Measured 2026-08-19: a single `/mc identify` spent 2-5 minutes
# and 8-16k tokens before it wrote anything, almost all of it on eight to twelve
# sequential one-line shell calls -- repo root, board size, own launch args, the
# roster, the worktree, ahead/behind -- each a separate turn with a separate model
# round-trip. None of them depended on the answer to the one before. The skill was
# not slow because the work was hard; it was slow because the work was serialised.
#
# So: one call, one turn, KEY: VALUE out. Read the block, then branch. Do not
# re-derive any line of it with a follow-up command -- if a value is here, it is
# measured, and measured at the ref you are about to write.
#
# ONE BASH BLOCK, RUN ONCE PER SKILL INVOCATION, emitting greppable KEY: VALUE lines
# that everything downstream reads instead of re-deriving. The value is that a figure
# quoted later in the run is the figure that was MEASURED, at the ref it was measured
# at -- re-deriving it mid-run is how two numbers for the same thing end up in one
# report.
#
#   mc-init.sh          full block
#   mc-init.sh me       just this session's identity (the bootstrap answer)
set -uo pipefail

SESSIONS="$HOME/.claude/sessions"

# ── which ref is "the truth" for this repo ──────────────────────────────────
# EVERYTHING HERE USED TO SAY origin/main, HARDCODED. That is one project's
# convention, and on a repo using master, trunk or develop -- or a remote not
# called origin, or no remote at all -- every board read came back empty and the
# coordinator offered to create a board the project already had. Same class of bug
# as the hardcoded board path, and a much larger share of adopters.
#
# Resolution, in order, so a correct answer is preferred to a lucky one:
#   1. MC_BASE_REF, if the user set it
#   2. the remote's own published default branch (refs/remotes/<r>/HEAD)
#   3. the first of main/master/trunk/develop that actually exists on that remote
#   4. no remote at all -> the local branch, and SAY SO, because "ahead/behind"
#      against yourself is meaningless and a reader must not take it as agreement
resolve_base_ref() {
  local root="$1" r b
  if [ -n "${MC_BASE_REF:-}" ]; then printf '%s' "$MC_BASE_REF"; return; fi
  r=$(git -C "$root" remote 2>/dev/null | grep -qx origin && echo origin || git -C "$root" remote 2>/dev/null | head -1)
  if [ -n "$r" ]; then
    b=$(git -C "$root" symbolic-ref -q --short "refs/remotes/$r/HEAD" 2>/dev/null)
    if [ -n "$b" ] && git -C "$root" rev-parse --verify -q "$b" >/dev/null 2>&1; then printf '%s' "$b"; return; fi
    for c in main master trunk develop; do
      if git -C "$root" rev-parse --verify -q "$r/$c" >/dev/null 2>&1; then printf '%s' "$r/$c"; return; fi
    done
  fi
  b=$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ -z "$b" ] || [ "$b" = "HEAD" ] && b="HEAD"
  printf 'LOCAL:%s' "$b"
}

# ── who am I ────────────────────────────────────────────────────────────────
# THE REGISTRY IS THE ONLY SURFACE THAT IS LIVE. It is on disk, keyed by pid, and
# this process is a descendant of its own claude -- so walk up until a pid has a
# registry file. That answers NAME locally with no radio round-trip, works for
# hand-started sessions (reading your own --name flag does not), and is correct the
# instant set-callsign.sh returns.
#
# The [ref] is in no registry field -- verified 2026-08-19, and it is not sessionId
# nor its md5/sha1/sha256 prefix. But it is NOT unreadable: ListAgents prints a
# self-line, "This session is <name> [ref]", and measured 2026-08-22 across a
# four-station fleet THE REF THERE IS CORRECT WHILE THE NAME BESIDE IT IS STALE --
# a start-time snapshot that keeps asserting the pre-rename handle. So:
#   your NAME -> here (live)          your [ref] -> the ListAgents self-line
#   NEVER your name off the self-line, and never a peer's name off a message header.
# A peer read-back is corroboration, not retrieval. It is worth one call when a bare
# call-sign matches two rows; it is not a blocker, and it used to be treated as one.
find_me() {
  local p=$$ i
  for i in 1 2 3 4 5 6 7 8; do
    [ -f "$SESSIONS/$p.json" ] && { echo "$p"; return 0; }
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
    [ -z "$p" ] || [ "$p" = "0" ] || [ "$p" = "1" ] && { [ -z "$p" ] && return 1; }
  done
  return 1
}

emit_me() {
  local mypid; mypid=$(find_me) || { echo "ME_PID: unknown"; echo "ME_NAME: unknown  # no registry entry found walking up from this shell"; return; }
  MYPID="$mypid" python3 - <<'PY'
import json,os
pid=os.environ["MYPID"]
d=json.load(open(os.path.expanduser(f"~/.claude/sessions/{pid}.json")))
print(f"ME_PID: {pid}")
print(f"ME_NAME: {d.get('name','?')}   # SNAPSHOT AS OF NOW. If you have not run set-callsign.sh yet, this is your PRE-rename handle")
print(f"ME_NAMESOURCE: {d.get('nameSource','?')}   # 'derived' = generated handle, you have NOT taken a call-sign yet")
print("ME_NAME_AFTER_RENAME: re-run `mc-init.sh me`   # the registry is LIVE; a preamble reading is merely OLD.")
print("                      Do NOT infer from a stale reading that the source cannot know -- reported 2026-08-22,")
print("                      it cost a station a radio round-trip for a fact sitting in a file.")
print(f"ME_CWD: {d.get('cwd','?')}")
print("ME_REF: run ListAgents -- your own self-line carries it, and that ref is CORRECT")
print("ME_SELFLINE_NAME: DO NOT USE   # the name on that self-line is a start-time snapshot: false after any rename")
PY
}

# ── who else is live ────────────────────────────────────────────────────────
# The registry is the truth, not a message's from-name: the from-name is captured
# when a channel opens and stops resolving the moment the sender renames.
# On-fleet vs off-fleet is decided by the REPOSITORY -- never by name, and never by a
# path prefix. A session in another repo owes this board nothing and must not be
# broadcast to.
#
# IT USED TO BE A PATH PREFIX, AND THAT WAS BROKEN FROM INSIDE A WORKTREE. ROOT came
# from `git rev-parse --show-toplevel`, which for a station is ITS OWN WORKTREE, not
# the shared checkout -- so a station in .claude/worktrees/backend saw the shared
# checkout and every sibling worktree as "OFF-FLEET (different repo)". Four of five
# peers, every one of them its own fleet. Reported 2026-08-23 by the station that
# caught it, and only by reading the registry cwds by hand.
#
# IT FAILED IN THE DANGEROUS DIRECTION: it never mislabels a stranger as fleet, only
# fleet as stranger -- so the list reads as conservative and correct while a station
# refuses to broadcast to its own fleet, ignores an all-stations standby, and reports
# its own peers as strangers. It gets WORSE the more stations you deploy, because only
# Control, sitting in the shared checkout, ever sees the truth.
#
# THE FIX: compare `git rev-parse --git-common-dir`, which is the SAME path from the
# shared checkout and from every worktree of that repo -- that is what makes two
# checkouts the same repository. Verified 2026-08-23: identical from both.
emit_peers() {
  local root="${1:-}"
  local fleet_id
  fleet_id=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || fleet_id=""
  if [ -z "$fleet_id" ]; then
    fleet_id=$(git rev-parse --git-common-dir 2>/dev/null) || fleet_id=""
    case "$fleet_id" in ""|/*) ;; *) fleet_id="$(cd "$(dirname "$fleet_id")" 2>/dev/null && pwd)/$(basename "$fleet_id")";; esac
  fi
  # A DISPLACED STATION SAW ITS WHOLE FLEET AS STRANGERS, AND NOTHING SAID SO.
  # Peers are classified by the peer's REGISTERED SESSION cwd -- the directory the
  # session was launched in -- while `fleet_id` above comes from wherever this command
  # is RUNNING. Those stop being the same the moment a station works outside its launch
  # directory (a `cd`-prefixed command is enough; EnterWorktree refuses a cross-repo
  # worktree, so there is no supported way to move the session cwd at all). Every peer
  # then computes as OFF-FLEET -- correctly computed from the wrong input. Reproduced
  # 2026-08-23 from a scratch repo: five live peers, all five called strangers,
  # including the coordinator running the exercise.
  # It fails conservatively -- fleet read as stranger, never the reverse -- but it goes
  # TOTAL, and a coordinator reading it concludes it has no fleet at all.
  # The tell was already on screen and nothing noticed it: ROOT and ME_CWD disagree, and
  # ME_CWD is the value silently driving every verdict. So SAY SO. Re-deriving the right
  # answer is not possible from here -- an honest "I cannot classify this" beats five
  # confident wrong verdicts.
  local my_cwd my_cwd_fleet
  my_cwd=$(MYPID="${2:-0}" python3 -c "
import json,os,sys
p=os.path.expanduser('~/.claude/sessions/%s.json' % os.environ.get('MYPID','0'))
try: print(json.load(open(p)).get('cwd',''))
except Exception: print('')
" 2>/dev/null)
  if [ -n "$my_cwd" ] && [ -d "$my_cwd" ]; then
    my_cwd_fleet=$(git -C "$my_cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || my_cwd_fleet=""
    if [ -n "$my_cwd_fleet" ] && [ -n "$fleet_id" ] \
       && [ "$(cd "$my_cwd_fleet" 2>/dev/null && pwd -P)" != "$(cd "$fleet_id" 2>/dev/null && pwd -P)" ]; then
      echo "PEERS_WARNING: your session's registered cwd ($my_cwd) is a DIFFERENT repository from"
      echo "               the one you are running in ($root). Peers are classified by their"
      echo "               registered cwd, so EVERY on-fleet/off-fleet verdict below is computed"
      echo "               against your LAUNCH repo, not this one, and is UNRELIABLE -- most"
      echo "               likely calling your whole fleet strangers. Do not conclude you have no"
      echo "               fleet. Run ListAgents, or re-run this from your session's own repo."
    fi
  fi
  MYPID="${2:-0}" ROOT="$root" FLEET_ID="$fleet_id" python3 - <<'PY'
import glob,json,os,subprocess
me=os.environ.get("MYPID","0"); root=os.environ.get("ROOT","")
mine=os.path.realpath(os.environ["FLEET_ID"]) if os.environ.get("FLEET_ID") else ""

def fleet_of(cwd):
    """The repo a directory belongs to -- identical across all that repo's worktrees."""
    if not cwd or not os.path.isdir(cwd): return None
    for args in (["rev-parse","--path-format=absolute","--git-common-dir"],
                 ["rev-parse","--git-common-dir"]):
        try:
            r=subprocess.run(["git","-C",cwd]+args,capture_output=True,text=True,timeout=5)
        except Exception:
            return None
        if r.returncode==0 and r.stdout.strip():
            g=r.stdout.strip()
            if not os.path.isabs(g): g=os.path.join(cwd,g)
            return os.path.realpath(g)
    return None
rows=[]
for f in glob.glob(os.path.expanduser("~/.claude/sessions/*.json")):
    try: d=json.load(open(f))
    except Exception: continue
    try: os.kill(int(d["pid"]),0)          # a stale file is not a live session
    except Exception: continue
    rows.append(d)
if not rows:
    print("PEERS: none"); raise SystemExit
print(f"PEERS: {max(0,len(rows)-1)} live besides you")
for d in sorted(rows,key=lambda x:x.get("startedAt",0)):
    if str(d.get("pid"))==str(me): continue
    cwd=d.get("cwd","")
    theirs=fleet_of(cwd)
    if mine and theirs and theirs==mine:
        fleet="on-fleet"
    elif not mine:
        fleet="fleet UNKNOWN (this session is not in a git repo -- classify by hand)"
    else:
        fleet="OFF-FLEET (different repo -- do not board, do not broadcast)"
    src=d.get("nameSource","?")
    named="named" if src!="derived" else "unidentified"
    print(f"  {d.get('name','?'):<16} {d.get('status','?'):<8} {named:<14} {fleet}")
PY
}

# ── the fleet's own vocabulary ──────────────────────────────────────────────
# Precedence, and it does not bend: the project's MISSION-CONTROL.md names the
# coordinator; then the user's recorded preference; then CONTROL.
emit_coordinator() {
  local root="$1"
  local base="${2:-}"
  local name=""
  local tmpf=""
  # Separate statements on purpose: bash expands EVERY argument of `local` before it
  # performs any of the assignments, so `local a="$1" b="$a/x"` leaves $a unbound --
  # and under `set -u` that is a hard exit, not an empty string. Cost one smoke test
  # 2026-08-22, having passed `bash -n` cleanly, because it is a runtime error.
  local f=""
  # READ THE SAME COPY THE BOARD IS READ FROM. This used to read $root/<file>, i.e. the
  # WORKING TREE -- so a station in a lane worktree resolved its coordinator and its
  # rules from a file 64 commits behind, while the board three lines above was
  # deliberately pinned to the ref for exactly that reason. Same block, same defect,
  # opposite treatment. Reported 2026-08-23: the two copies differed by 38 diff lines.
  if [ -n "$base" ]; then
    for c in docs/MISSION-CONTROL.md MISSION-CONTROL.md .claude/MISSION-CONTROL.md; do
      if git -C "$root" cat-file -e "$base:$c" 2>/dev/null; then
        tmpf=$(mktemp 2>/dev/null) || tmpf=""
        if [ -n "$tmpf" ] && git -C "$root" show "$base:$c" > "$tmpf" 2>/dev/null; then f="$tmpf"; fi
        break
      fi
    done
  fi
  if [ -z "$f" ]; then
    for c in docs/MISSION-CONTROL.md MISSION-CONTROL.md .claude/MISSION-CONTROL.md; do
      [ -f "$root/$c" ] && { f="$root/$c"; break; }
    done
  fi
  [ -z "$f" ] && f="$root/docs/MISSION-CONTROL.md"
  if [ -f "$f" ]; then
    # 1. AN EXPLICIT DECLARATION, and it works for ANY word the project chose.
    #    `Coordinator: HQ` / `**Coordinator:** BRIDGE` / `| Coordinator | COMMAND |`.
    #    This exists because the name-allowlist below could only ever find names this
    #    skill already knew, so a board that named its coordinator HQ was silently
    #    ignored by the very precedence rule that says the board WINS. Corrected
    #    2026-08-22, after one project's example name spread to every other fleet.
    name=$(grep -m1 -oiE '^[[:space:]>*|-]*coordinator[[:space:]|*]*[:=|][[:space:]*]*[A-Za-z0-9][A-Za-z0-9 ._/&-]{0,63}' "$f" 2>/dev/null \
           | sed -E 's/^[[:space:]>*|-]*[Cc][Oo][Oo][Rr][Dd][Ii][Nn][Aa][Tt][Oo][Rr][[:space:]|*]*[:=|][[:space:]*]*//' \
           | tr -d '*|' | sed -E 's/[[:space:]]+$//')
    # 2. LEGACY FALLBACK: boards written before a declaration line existed, which
    #    only mention a conventional name. Kept so those keep working; it is not the
    #    supported path and it cannot learn a name it has not been told.
    #    IT MUST BE A DECLARATION, NOT A SENTENCE THAT STARTS WITH THE WORD. The old
    #    pattern anchored at ^ and stopped at the name, so ANY line beginning with
    #    "Control" matched -- and paragraph reflow puts words at column 1 for free. A
    #    real project resolved COORDINATOR from the line
    #        "Control was right to rule out `passWithNoTests`.** Two independent facts"
    #    which is the middle of a sentence. Reported 2026-08-23. The answer happened to
    #    be right, which is the kind of wrong that survives testing: reflowing that
    #    paragraph would have silently changed it, and the value is load-bearing.
    #    So: the whole line must reduce to the name once markdown decoration is
    #    stripped. A mention inside prose is not a project naming its coordinator, and
    #    falling through to the user's preference (or CONTROL) is the correct answer
    #    for a file that never declared one.
    #    Emitted in the canonical spelling -- these are conventional constants, and a
    #    board writing "Control" was resolving to a registry handle of "CONTROL".
    if [ -z "$name" ]; then
      name=$(grep -oiE '^[[:space:]>*|#-]*(CONTROL|FLEET COMMAND|FLEETCOM)[[:space:]*|:.-]*$' "$f" 2>/dev/null \
             | head -1 | tr -d '|*#>:.' | xargs 2>/dev/null | tr '[:lower:]' '[:upper:]')
    fi
  fi
  if [ -z "$name" ] && [ -f "$HOME/.claude/mission-control.json" ]; then
    name=$(python3 -c "import json,os;d=json.load(open(os.path.expanduser('~/.claude/mission-control.json')));print(d.get('naming',{}).get('coordinator',''))" 2>/dev/null)
  fi
  [ -z "$name" ] && name="CONTROL"
  [ -n "$tmpf" ] && rm -f "$tmpf"
  echo "COORDINATOR: $name"
}

# ── main ────────────────────────────────────────────────────────────────────
HERE_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ "${1:-}" = "me" ]; then emit_me; exit 0; fi

ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$ROOT" ]; then
  echo "ROOT: none   # not a git repo -- there is no fleet here"
  emit_me
  exit 0
fi

BASE=$(resolve_base_ref "$ROOT")
BASE_NOTE=""
case "$BASE" in
  LOCAL:*)
    BASE="${BASE#LOCAL:}"
    BASE_NOTE="   # NO REMOTE -- this is your own branch. AHEAD/BEHIND against yourself mean nothing,"
    BASE_NOTE="$BASE_NOTE and nothing here has been agreed with anyone. Push before you trust a number." ;;
  */*) : ;;
esac
echo "ROOT: $ROOT"
# REPO IS THE REPOSITORY, NOT THE DIRECTORY YOU HAPPEN TO BE STANDING IN. This was
# `basename "$ROOT"`, and ROOT is `rev-parse --show-toplevel`, which for a station
# inside a worktree IS ITS OWN WORKTREE. A station in .claude/worktrees/backend printed
# `REPO: backend`. Reported 2026-08-23, and it fails INVISIBLY: lane worktrees are named
# backend, finance, channels, backlog -- every one of which reads as a plausible repo
# name, so nothing about the wrong answer looks wrong. It is the same substitution the
# PEERS block already guards against; REPO was the one line never converted.
# git-common-dir is the SAME path from the shared checkout and from every worktree.
REPO_COMMON=$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || REPO_COMMON=""
if [ -z "$REPO_COMMON" ]; then
  REPO_COMMON=$(git -C "$ROOT" rev-parse --git-common-dir 2>/dev/null) || REPO_COMMON=""
  case "$REPO_COMMON" in
    ""|/*) ;;
    *) REPO_COMMON="$(cd "$ROOT" && cd "$(dirname "$REPO_COMMON")" 2>/dev/null && pwd)/$(basename "$REPO_COMMON")";;
  esac
fi
case "$REPO_COMMON" in
  */.git) REPO_NAME=$(basename "$(dirname "$REPO_COMMON")") ;;   # normal repo
  "")     REPO_NAME=$(basename "$ROOT") ;;                       # cannot tell; say what we stand in
  *)      REPO_NAME=$(basename "${REPO_COMMON%.git}") ;;         # bare, or a linked gitdir
esac
echo "REPO: $REPO_NAME"

# THIS SCRIPT IS NOT READ-ONLY, AND UNTIL 2026-08-23 IT NEVER SAID SO. This line writes
# remote-tracking refs, and from a worktree it writes them into the SHARED .git that
# every other lane reads -- a station "just orienting itself" mutates state for the whole
# fleet. It is also the FIRST thing a station runs, so the undisclosed write happens
# before preflight's disclosed one.
# Two more defects reported with it, both fixed here:
#   - it was hardcoded to `origin` while resolve_base_ref goes to real trouble to be
#     remote-agnostic. On a repo whose only remote is `upstream`, BASE resolved to
#     upstream/main, this fetch silently failed, and BASE_HEAD/AHEAD/BEHIND were then
#     computed off stale refs and printed with no marker.
#   - a FAILED fetch was silent. preflight.sh warns in exactly this case and this did
#     not, so the two scripts had diverged on the same defect -- which is worse than
#     both being wrong in the same way, because one of them looks trustworthy.
FETCH_REMOTE=$(git -C "$ROOT" remote 2>/dev/null | grep -qx origin && echo origin \
               || git -C "$ROOT" remote 2>/dev/null | head -1)
FETCH_NOTE=""
if [ -n "$FETCH_REMOTE" ]; then
  git -C "$ROOT" fetch -q "$FETCH_REMOTE" 2>/dev/null \
    || FETCH_NOTE="   # FETCH FAILED against '$FETCH_REMOTE' -- every number below that names a remote ref
       #       (BASE_HEAD, AHEAD, BEHIND, the board measured at the ref) was computed from
       #       POSSIBLY STALE remote-tracking refs. Fix the fetch before trusting them."
fi
[ -n "$FETCH_NOTE" ] && echo "FETCH: failed$FETCH_NOTE"

# Has this person ever been walked through this? Read-only here -- the flag is only ever
# WRITTEN by the walkthrough itself, at the point it finishes or is refused. Emitted from
# the one command every /mc already runs, so the first run needs no new hook and the
# skill keeps its promise to run only when invoked.
if [ -f "$HERE_DIR/tour-state.sh" ]; then
  bash "$HERE_DIR/tour-state.sh" read 2>/dev/null || echo "TOUR: unknown   # tour-state.sh failed"
else
  echo "TOUR: unknown   # tour-state.sh not found beside mc-init.sh"
fi

# The board is measured AT THE REF YOU WILL WRITE. Measured 2026-08-19: two
# stations independently reported a 289 KB unreadable board while origin/main
# held 50,137 bytes -- both had measured the shared checkout's stale working
# copy, and one stale file read twice arrived as two confirmations.
# FIND THE BOARD, DO NOT ASSUME IT. This was hardcoded to docs/WORK-LOCKS.md, which is
# one project's convention -- so every other project got "BOARD: none" and a coordinator
# that offered to create a board it already had. The sibling skills in this repo already
# say "find whatever claim file the project already uses"; this did not, and that
# inconsistency is what makes a skill feel like it was written for somebody else's repo.
#
# Order: an explicit override wins, then the common locations, and NOTHING is guessed
# from content -- a board is a file the project chose, not one we pattern-matched into.
# Set `board` in this project's own MISSION-CONTROL.md front matter, or MC_BOARD in the
# environment, and this stops searching.
BOARD=""
if [ -n "${MC_BOARD:-}" ]; then
  BOARD="$MC_BOARD"
else
  for f in "$ROOT/docs/MISSION-CONTROL.md" "$ROOT/MISSION-CONTROL.md" "$ROOT/.claude/MISSION-CONTROL.md"; do
    [ -f "$f" ] || continue
    d=$(grep -m1 -iE '^[[:space:]>*|-]*board[[:space:]|*]*[:=|][[:space:]*]*[^[:space:]|]+' "$f" 2>/dev/null \
        | sed -E 's/^[[:space:]>*|-]*[Bb][Oo][Aa][Rr][Dd][[:space:]|*]*[:=|][[:space:]*]*//' | tr -d '`*|' | sed -E 's/[[:space:]]+$//')
    [ -n "$d" ] && { BOARD="$d"; break; }
  done
fi
if [ -z "$BOARD" ]; then
  for c in docs/WORK-LOCKS.md WORK-LOCKS.md docs/CLAIMS.md CLAIMS.md .claude/WORK-LOCKS.md docs/BOARD.md; do
    if git -C "$ROOT" cat-file -e "$BASE:$c" 2>/dev/null; then BOARD="$c"; break; fi
  done
fi
[ -z "$BOARD" ] && BOARD="docs/WORK-LOCKS.md"   # nothing found: name the one Step 0 would create
if git -C "$ROOT" cat-file -e "$BASE:$BOARD" 2>/dev/null; then
  echo "BOARD: $BOARD"
  echo "BOARD_BYTES: $(git -C "$ROOT" show "$BASE:$BOARD" | wc -c | tr -d ' ')   # at $BASE, NOT the working copy"
  echo "BOARD_LINES: $(git -C "$ROOT" show "$BASE:$BOARD" | wc -l | tr -d ' ')"
else
  echo "BOARD: none at $BASE   # no board yet -- Step 0 offers to write one"
fi
RULES=""; RULES_AT=""
for f in docs/MISSION-CONTROL.md MISSION-CONTROL.md .claude/MISSION-CONTROL.md; do
  if git -C "$ROOT" cat-file -e "$BASE:$f" 2>/dev/null; then RULES="$f"; RULES_AT="$BASE"; break; fi
done
if [ -z "$RULES" ]; then
  for f in docs/MISSION-CONTROL.md MISSION-CONTROL.md .claude/MISSION-CONTROL.md; do
    [ -f "$ROOT/$f" ] && { RULES="$f"; RULES_AT="working copy"; break; }
  done
fi
if [ -n "$RULES" ]; then
  echo "RULES: $RULES   # at $RULES_AT -- its station names WIN over any default"
  # Say it out loud when the copy you would EDIT is not the copy that was READ.
  if [ "$RULES_AT" = "$BASE" ] && [ -f "$ROOT/$RULES" ] \
     && ! git -C "$ROOT" diff --quiet "$BASE" -- "$RULES" 2>/dev/null; then
    echo "       # NOTE: your working copy of this file DIFFERS from $BASE. The names above were"
    echo "       #       read at the ref, which is what your peers see. Reconcile before relying on it."
  fi
else
  echo "RULES: none"
fi

emit_coordinator "$ROOT" "$BASE"

# A detached worktree used to print "HEAD: HEAD @ abc1234", which reads as a bug
# rather than as the intended state. Say detached; it costs nothing.
_BR=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)
[ "$_BR" = "HEAD" ] && _BR="detached"
echo "HEAD: $_BR @ $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)"
echo "BASE_REF: $BASE$BASE_NOTE"
echo "BASE_HEAD: $(git -C "$ROOT" rev-parse --short "$BASE" 2>/dev/null)"
echo "AHEAD: $(git -C "$ROOT" rev-list --count "$BASE..HEAD" 2>/dev/null)"
echo "BEHIND: $(git -C "$ROOT" rev-list --count "HEAD..$BASE" 2>/dev/null)"

echo "WORKTREES:"
git -C "$ROOT" worktree list 2>/dev/null | sed 's/^/  /'

MYPID=$(find_me || echo 0)
emit_me
emit_peers "$ROOT" "$MYPID"

# ROOT is the WORKTREE when a station runs this, not the shared checkout -- so the
# old fixed wording described the wrong directory to every station that read it.
# Name what was actually measured, and split tracked from untracked for the same
# reason preflight does: they are not the same risk.
_ST=$(git -C "$ROOT" status --porcelain 2>/dev/null)
_UN=$(printf '%s\n' "$_ST" | grep -c '^??'); _TR=$(printf '%s\n' "$_ST" | grep -vc '^??')
[ -z "$_ST" ] && { _UN=0; _TR=0; }
_WHERE="$(basename "$ROOT")"
git -C "$ROOT" rev-parse --git-common-dir 2>/dev/null | grep -qv '^\.git$' \
  && _WHERE="$_WHERE (a worktree, not the shared checkout)" || _WHERE="$_WHERE (the shared checkout)"
echo "DIRTY: $_TR tracked modified, $_UN untracked -- in $_WHERE"
