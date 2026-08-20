#!/bin/bash
# set-callsign.sh <CALLSIGN> — make this session's call-sign the address peers resolve.
#
# Two surfaces, one command, run BY the station IN its own tab. They are NOT equal:
#   1. the ADDRESS peers resolve through ListAgents (~/.claude/sessions/<pid>.json) -- DURABLE.
#      Measured 2026-08-18: survived the session's own registry write 33 minutes later.
#      This is NOT the `@` header on a channel a peer has already opened. That name is
#      captured when the channel opens and is never re-resolved, so a renamed station keeps
#      arriving under its old handle -- measured 2026-08-19, and it is the same capture that
#      bounces a reply addressed to a from-name. Resolve names here; match on the [ref].
#   2. the Terminal tab title (delegated to label-tab.sh) -- BEST EFFORT ONLY. Claude Code
#      rewrites the title with its own status glyph + summary at every status change, i.e.
#      each turn boundary. The label holds while you work and is gone when the turn ends.
#      `/rename <CALLSIGN>`, typed by the human in that tab, is the only thing MEASURED to hold
#      the title (2026-08-18). `claude --name` at launch is expected to as well -- the flag's own
#      help says it feeds the terminal title -- but no one has measured that across a turn
#      boundary, so do not report it as verified.
#
# Finds its own pid and its own tty by walking up from this shell — never by
# "front window" or by scanning for any `claude`, both of which hit somebody else's
# session. Read-modify-write, so no field but the name is touched.
#
# NOTE: the registry under ~/.claude/sessions is Claude Code's own state. This is
# unsupported: a version bump can change the schema. `claude --name <CALLSIGN>` at
# launch is the supported path and is what `/mc deploy` passes. This exists for the
# sessions already up.
set -u
CALLSIGN="${1:-}"; HANDLE="${2:-}"
[ -z "$CALLSIGN" ] && { echo "usage: set-callsign.sh <CALLSIGN> [HANDLE]" >&2; exit 2; }

# A call-sign reaches an AppleScript string literal below. A double quote closes that
# string and AppleScript has `do shell script`, so an unfiltered call-sign is remote
# code execution with extra steps -- demonstrated 2026-08-18, it ran.
# ALLOWLIST: letters, digits, spaces and the separators real call-signs use.
case "$CALLSIGN" in
  "" | *[!A-Za-z0-9\ ._/\&-]* )
    echo "FAILED: a call-sign may contain letters, digits, spaces and . _ / & - only" >&2
    exit 2 ;;
esac
if [ ${#CALLSIGN} -gt 64 ]; then echo "FAILED: call-sign too long (max 64)" >&2; exit 2; fi

# A call-sign is what people SAY -- it may contain spaces ("FLEET COMMAND").
# A handle is what peers ADDRESS -- a session name, and those cannot. When the two
# cannot be the same, ASK; never invent somebody's short form for them. Whether a
# handle differs from the call-sign at all is a preference, not a rule: plenty of
# people want CONTROL to be addressed CONTROL, and plenty want FLEETCOM.
if [ -z "$HANDLE" ]; then
  case "$CALLSIGN" in
    *[!A-Za-z0-9_-]*)
      cat >&2 <<MSG
FAILED: "$CALLSIGN" cannot be a session name, so it needs a handle you choose.
        A handle is [A-Za-z0-9_-] only -- no spaces.
        Ask the user which they want, then:  set-callsign.sh "$CALLSIGN" <HANDLE>
        e.g.  set-callsign.sh "$CALLSIGN" FLEETCOM
        Do not pick one for them. Record it in ~/.claude/mission-control.json
        under "naming" so it is asked once and never again.
MSG
      exit 2;;
    *) HANDLE="$CALLSIGN";;
  esac
fi
case "$HANDLE" in *[!A-Za-z0-9_-]*) echo "FAILED: a handle is [A-Za-z0-9_-] only -- got \"$HANDLE\"" >&2; exit 2;; esac

HERE="$(cd "$(dirname "$0")" && pwd)"
SESSIONS="$HOME/.claude/sessions"
command -v python3 >/dev/null || { echo "FAILED: python3 not found — needed to edit the session registry" >&2; exit 1; }
[ -d "$SESSIONS" ] || { echo "FAILED: no session registry at $SESSIONS (Claude Code too old, or a different layout)" >&2; exit 1; }

# --- find our own claude process by walking the parent chain -------------------
p=$$; CLAUDE_PID=""
while [ "$p" -gt 1 ]; do
  comm=$(ps -o comm= -p "$p" 2>/dev/null | xargs basename 2>/dev/null)
  if [ "$comm" = "claude" ] && [ -f "$SESSIONS/$p.json" ]; then CLAUDE_PID="$p"; break; fi
  p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  [ -z "$p" ] && break
done
[ -z "$CLAUDE_PID" ] && { echo "FAILED: no claude session in the parent chain" >&2; exit 1; }
REG="$SESSIONS/$CLAUDE_PID.json"

# --- refuse a call-sign another LIVE session already answers to ----------------
CLASH=$(CALLSIGN="$HANDLE" MINE="$REG" python3 - "$SESSIONS" <<'PY'
import glob,json,os,sys
want=os.environ["CALLSIGN"].lower(); mine=os.environ["MINE"]
for f in glob.glob(os.path.join(sys.argv[1],"*.json")):
    if os.path.abspath(f)==os.path.abspath(mine): continue
    try: d=json.load(open(f))
    except Exception: continue
    if str(d.get("name","")).lower()!=want: continue
    try: os.kill(int(d.get("pid",0)),0)
    except Exception: continue          # dead session, its name is free
    print(f"{d.get('name')} (pid {d.get('pid')}, {d.get('cwd','?')})")
PY
)
[ -n "$CLASH" ] && { echo "REFUSED: $HANDLE is answered by a live session — $CLASH" >&2; exit 3; }

# --- 1. the address peers resolve: read-modify-write, name only ----------------
CALLSIGN="$HANDLE" python3 - "$REG" <<'PY' || exit 1
import json,os,sys,time,tempfile
p=sys.argv[1]; new=os.environ["CALLSIGN"]
d=json.load(open(p))
old=d.get("name")
if old==new:
    print(f"address already {new}"); raise SystemExit(0)
former=[x for x in d.get("formerNames",[]) if x!=old]
if old: former.append(old)
d.update(name=new, nameSource="user", nameSince=int(time.time()*1000), formerNames=former)
fd,tmp=tempfile.mkstemp(dir=os.path.dirname(p)); os.close(fd)
json.dump(d,open(tmp,"w")); os.replace(tmp,p)          # atomic, never a torn registry
print(f"address (fleet manifest) {old} -> {json.load(open(p))['name']}")
PY

# --- 2. the tab title (best effort; never fails the rename) ---------------------
# macOS Terminal.app only. Anywhere else this is a clean skip, not an error: the
# address above is the half the fleet reads, and it has already landed.
if [ ! -x "$HERE/label-tab.sh" ]; then
  echo "tab title: skipped — label-tab.sh not found beside me"
elif [ "$(uname -s)" != "Darwin" ] || ! command -v osascript >/dev/null; then
  echo "tab title: skipped — needs macOS Terminal.app; the manifest address is set regardless"
elif ! "$HERE/label-tab.sh" "$CALLSIGN" >/dev/null 2>&1; then
  echo "tab title: skipped — could not match this tty"
else
  echo "tab title: set to \"$CALLSIGN\" — BUT Claude Code overwrites it at the next turn"
  echo "           boundary. For a title that sticks: type  /rename $CALLSIGN  in this tab,"
  echo "           or  /color  to tell tabs apart a way nothing overwrites."
fi

echo "NOTE: a peer whose channel to you is ALREADY OPEN keeps seeing your OLD handle. That name"
echo "      was captured when the channel opened and is never re-resolved -- only a channel opened"
echo "      after this rename carries the new one. Do not report the \`@\` header as changed."
echo "pid $CLAUDE_PID · registry $REG"
echo "VERIFY: ask a peer to run ListAgents. A session never sees itself."
