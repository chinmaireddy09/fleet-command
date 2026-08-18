#!/bin/bash
# set-callsign.sh <CALLSIGN> — make this session's call-sign the name everyone sees.
#
# Two surfaces, one command, run BY the station IN its own tab. They are NOT equal:
#   1. the `@` header peers see on every message  (~/.claude/sessions/<pid>.json) -- DURABLE.
#      Measured 2026-08-18: survived the session's own registry write 33 minutes later.
#   2. the Terminal tab title (delegated to label-tab.sh) -- BEST EFFORT ONLY. Claude Code
#      rewrites the title with its own status glyph + summary at every status change, i.e.
#      each turn boundary. The label holds while you work and is gone when the turn ends.
#      Only `claude --name` at launch puts a call-sign in the title for good.
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
CALLSIGN="${1:-}"
[ -z "$CALLSIGN" ] && { echo "usage: set-callsign.sh <CALLSIGN>" >&2; exit 2; }
case "$CALLSIGN" in *[!A-Za-z0-9_-]*) echo "FAILED: call-signs are [A-Za-z0-9_-] only" >&2; exit 2;; esac

HERE="$(cd "$(dirname "$0")" && pwd)"
SESSIONS="$HOME/.claude/sessions"

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
CLASH=$(CALLSIGN="$CALLSIGN" MINE="$REG" python3 - "$SESSIONS" <<'PY'
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
[ -n "$CLASH" ] && { echo "REFUSED: $CALLSIGN is answered by a live session — $CLASH" >&2; exit 3; }

# --- 1. the @ header: read-modify-write, name only -----------------------------
CALLSIGN="$CALLSIGN" python3 - "$REG" <<'PY' || exit 1
import json,os,sys,time,tempfile
p=sys.argv[1]; new=os.environ["CALLSIGN"]
d=json.load(open(p))
old=d.get("name")
if old==new:
    print(f"@ header already {new}"); raise SystemExit(0)
former=[x for x in d.get("formerNames",[]) if x!=old]
if old: former.append(old)
d.update(name=new, nameSource="user", nameSince=int(time.time()*1000), formerNames=former)
fd,tmp=tempfile.mkstemp(dir=os.path.dirname(p)); os.close(fd)
json.dump(d,open(tmp,"w")); os.replace(tmp,p)          # atomic, never a torn registry
print(f"@ header {old} -> {json.load(open(p))['name']}")
PY

# --- 2. the tab title ----------------------------------------------------------
if [ -x "$HERE/label-tab.sh" ]; then "$HERE/label-tab.sh" "$CALLSIGN"
else echo "tab title: label-tab.sh not found beside me — skipped" >&2; fi

echo "pid $CLAUDE_PID · registry $REG"
echo "VERIFY: ask a peer to run ListAgents. A session never sees itself."
