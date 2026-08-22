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
# Adapted from gstack's preamble pattern (one bash block, greppable output,
# computed once per skill run) -- gstack/SKILL.md, "Preamble (run first)".
#
#   mc-init.sh          full block
#   mc-init.sh me       just this session's identity (the bootstrap answer)
set -uo pipefail

SESSIONS="$HOME/.claude/sessions"

# ── who am I ────────────────────────────────────────────────────────────────
# A session cannot see itself in the fleet listing -- but the registry is on
# disk, keyed by pid, and this process is a descendant of its own claude. Walk
# up until a pid has a registry file. That answers NAME locally, with no radio
# round-trip, and it answers it for hand-started sessions too, which reading
# your own --name flag does not.
#
# It does NOT answer [ref]. Verified 2026-08-19: the bracketed ref appears in no
# registry field and is not sessionId, nor its md5/sha1/sha256 prefix. That half
# still needs a peer -- and only when a bare call-sign matches two rows.
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
print(f"ME_NAME: {d.get('name','?')}")
print(f"ME_NAMESOURCE: {d.get('nameSource','?')}   # 'derived' = generated handle, you have NOT taken a call-sign yet")
print(f"ME_CWD: {d.get('cwd','?')}")
print("ME_REF: unreadable-from-inside   # ask a peer, and only if a bare call-sign is ambiguous")
PY
}

# ── who else is live ────────────────────────────────────────────────────────
# The registry is the truth, not a message's from-name: the from-name is captured
# when a channel opens and stops resolving the moment the sender renames.
# On-fleet vs off-fleet is decided by working directory, never by name -- a
# session in another repo owes this board nothing and must not be broadcast to.
emit_peers() {
  local root="${1:-}"
  MYPID="${2:-0}" ROOT="$root" python3 - <<'PY'
import glob,json,os
me=os.environ.get("MYPID","0"); root=os.environ.get("ROOT","")
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
    fleet="on-fleet" if root and (cwd==root or cwd.startswith(root+os.sep)) else "OFF-FLEET (different repo -- do not board, do not broadcast)"
    src=d.get("nameSource","?")
    named="named" if src!="derived" else "unidentified"
    print(f"  {d.get('name','?'):<16} {d.get('status','?'):<8} {named:<14} {fleet}")
PY
}

# ── the fleet's own vocabulary ──────────────────────────────────────────────
# Precedence, and it does not bend: the project's MISSION-CONTROL.md names the
# coordinator; then the user's recorded preference; then CONTROL.
emit_coordinator() {
  local root="$1" name="" f="$root/docs/MISSION-CONTROL.md"
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
    [ -z "$name" ] && name=$(grep -oiE '^\|?[[:space:]]*\*{0,2}(CONTROL|FLEET COMMAND|FLEETCOM)\*{0,2}' "$f" 2>/dev/null | head -1 | tr -d '|*' | xargs 2>/dev/null)
  fi
  if [ -z "$name" ] && [ -f "$HOME/.claude/mission-control.json" ]; then
    name=$(python3 -c "import json,os;d=json.load(open(os.path.expanduser('~/.claude/mission-control.json')));print(d.get('naming',{}).get('coordinator',''))" 2>/dev/null)
  fi
  [ -z "$name" ] && name="CONTROL"
  echo "COORDINATOR: $name"
}

# ── main ────────────────────────────────────────────────────────────────────
if [ "${1:-}" = "me" ]; then emit_me; exit 0; fi

ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$ROOT" ]; then
  echo "ROOT: none   # not a git repo -- there is no fleet here"
  emit_me
  exit 0
fi
echo "ROOT: $ROOT"
echo "REPO: $(basename "$ROOT")"

git -C "$ROOT" fetch -q origin 2>/dev/null

# The board is measured AT THE REF YOU WILL WRITE. Measured 2026-08-19: two
# stations independently reported a 289 KB unreadable board while origin/main
# held 50,137 bytes -- both had measured the shared checkout's stale working
# copy, and one stale file read twice arrived as two confirmations.
BOARD="docs/WORK-LOCKS.md"
if git -C "$ROOT" cat-file -e "origin/main:$BOARD" 2>/dev/null; then
  echo "BOARD: $BOARD"
  echo "BOARD_BYTES: $(git -C "$ROOT" show "origin/main:$BOARD" | wc -c | tr -d ' ')   # at origin/main, NOT the working copy"
  echo "BOARD_LINES: $(git -C "$ROOT" show "origin/main:$BOARD" | wc -l | tr -d ' ')"
else
  echo "BOARD: none at origin/main   # no board yet -- Step 0 offers to write one"
fi
[ -f "$ROOT/docs/MISSION-CONTROL.md" ] && echo "RULES: docs/MISSION-CONTROL.md   # its station names WIN over any default" || echo "RULES: none"

emit_coordinator "$ROOT"

echo "HEAD: $(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null) @ $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)"
echo "ORIGIN_MAIN: $(git -C "$ROOT" rev-parse --short origin/main 2>/dev/null)"
echo "AHEAD: $(git -C "$ROOT" rev-list --count origin/main..HEAD 2>/dev/null)"
echo "BEHIND: $(git -C "$ROOT" rev-list --count HEAD..origin/main 2>/dev/null)"

echo "WORKTREES:"
git -C "$ROOT" worktree list 2>/dev/null | sed 's/^/  /'

MYPID=$(find_me || echo 0)
emit_me
emit_peers "$ROOT" "$MYPID"

echo "DIRTY: $(git -C "$ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ') file(s) in the shared checkout"
