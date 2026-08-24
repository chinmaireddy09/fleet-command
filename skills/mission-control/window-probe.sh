#!/bin/bash
# window-probe.sh — record which terminal WINDOW this session's tab lives in.
#
# WHY IT EXISTS. The status line colours a station by how visible it is: background, a
# tab, or its own window. Nothing Claude Code records distinguishes the last two -- `kind`
# is only `bg` or `interactive` -- and no environment variable carries it either. Measured
# on Terminal.app 2026-08-24: TERM_SESSION_ID is a per-SESSION UUID, not the `w0t0p0` form
# that would have given a window index for free; ITERM_SESSION_ID and WINDOWID are unset.
# So the terminal has to be asked, and only a station can ask about itself.
#
# WHAT IT WRITES. One line into a skill-owned file, keyed by sessionId:
#   ~/.claude/mission-control-windows.json
#     { "sessions": { "<sessionId>": { "window": "<id>", "tabs": <n> } } }
#
# TWO MEASURES, AND THE STATUS LINE USES BOTH. `tabs` is the true one -- a window holding
# one tab belongs to that station, and it counts tabs that are not stations at all, which
# is what a person means by "its own window". `window` lets the line GROUP live stations
# and re-derive as they come and go, catching the case where the count went stale because
# somebody dragged a tab out. Neither alone is right: a count is true only when taken, and
# a grouping cannot see a tab that holds no station.
#
# --all BACKFILLS THE WHOLE FLEET from any session. The per-session probe needs the station
# to identify; --all joins every live session's tty to a window in ONE osascript pass, so a
# fleet that was already up gets colours without every station being made to re-identify.
#
# IT IS BEST-EFFORT AND NEVER FATAL. No Terminal.app, no tty, no match, no AppleScript:
# it says so and exits 0. A missing record costs one colour, and the station still renders
# as a tab -- "visible somewhere" is the honest fallback and it is never wrong about that.
#
# SAFE TO RUN REPEATEDLY. It rewrites its own key and touches nothing else.
set -u

CFG="${MC_WINDOWS:-$HOME/.claude/mission-control-windows.json}"

if [ "${1:-}" = "--all" ]; then
  command -v osascript >/dev/null 2>&1 || { echo "WINDOW: unknown — no osascript (not macOS)"; exit 0; }
  MAP=$(osascript <<'AS' 2>/dev/null
tell application "Terminal"
  set out to ""
  repeat with w in windows
    set n to (count of tabs of w)
    repeat with t in tabs of w
      set out to out & ((id of w) as text) & " " & (n as text) & " " & (tty of t) & linefeed
    end repeat
  end repeat
  return out
end tell
AS
)
  [ -n "$MAP" ] || { echo "WINDOW: nothing to record — Terminal.app reported no tabs"; exit 0; }
  CFG="$CFG" MAP="$MAP" python3 - <<'PY' 2>/dev/null || { echo "WINDOW: not recorded — config unwritable"; exit 0; }
import json, os, glob, subprocess, tempfile

# tty -> (windowId, tabCount), straight from the terminal.
bytty = {}
for line in os.environ["MAP"].splitlines():
    parts = line.split()
    if len(parts) == 3:
        bytty[parts[2]] = (parts[0], int(parts[1]))

f = os.environ["CFG"]
try:
    with open(f) as fh: d = json.load(fh)
    if not isinstance(d, dict): raise ValueError
except FileNotFoundError:
    d = {}
except Exception:
    raise SystemExit(1)
d.setdefault("_comment", "written by mission-control window-probe.sh: which terminal window each session sits in")
sess = d.setdefault("sessions", {})

n = 0
for path in glob.glob(os.path.expanduser("~/.claude/sessions/*.json")):
    try:
        with open(path) as fh: r = json.load(fh)
    except Exception:
        continue
    pid, sid = r.get("pid"), r.get("sessionId")
    # LIVE ONLY. A registry file outlives its session, and recording a dead one's window
    # would keep a stale id in the grouping forever.
    if not pid or not sid or not os.path.exists(f"/tmp/cc-socks/{pid}.sock"):
        continue
    try:
        tty = subprocess.run(["ps", "-o", "tty=", "-p", str(pid)],
                             capture_output=True, text=True, timeout=5).stdout.strip()
    except Exception:
        continue
    hit = bytty.get("/dev/" + tty) if tty and tty != "??" else None
    if not hit:
        continue          # a background session has no tab; it is coloured by `kind` anyway.
    sess[sid] = {"window": hit[0], "tabs": hit[1]}
    n += 1

t = tempfile.NamedTemporaryFile("w", dir=os.path.dirname(f) or ".", delete=False)
json.dump(d, t, indent=2); t.write("\n"); t.close()
os.replace(t.name, f)
print(f"WINDOW: recorded {n} live session(s) from Terminal.app")
PY
  exit 0
fi

# The Bash tool has no tty; the `claude` process above it does. Same walk label-tab.sh
# uses, and for the same reason: "front window" is whichever window has FOCUS, i.e.
# somebody else's, and that mistake is the one this whole family of scripts exists to
# avoid making.
p=$$; MYTTY=""; CLAUDE_PID=""
while [ "$p" -gt 1 ]; do
  t=$(ps -o tty= -p "$p" 2>/dev/null | tr -d ' ')
  [ -n "$t" ] && [ "$t" != "??" ] && [ -z "$MYTTY" ] && MYTTY="/dev/$t"
  comm=$(ps -o comm= -p "$p" 2>/dev/null | xargs basename 2>/dev/null)
  [ "$comm" = "claude" ] && [ -z "$CLAUDE_PID" ] && CLAUDE_PID="$p"
  p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  [ -z "$p" ] && break
done
[ -n "$MYTTY" ] || { echo "WINDOW: unknown — no tty in the parent chain (not a terminal session)"; exit 0; }
[ -n "$CLAUDE_PID" ] || { echo "WINDOW: unknown — no claude process in the parent chain"; exit 0; }

SESSION_ID=$(python3 - "$CLAUDE_PID" <<'PY' 2>/dev/null
import json, os, sys
try:
    with open(os.path.expanduser(f"~/.claude/sessions/{sys.argv[1]}.json")) as fh:
        print(json.load(fh).get("sessionId", ""))
except Exception:
    pass
PY
)
[ -n "$SESSION_ID" ] || { echo "WINDOW: unknown — this session is not in the registry yet"; exit 0; }

command -v osascript >/dev/null 2>&1 || { echo "WINDOW: unknown — no osascript (not macOS)"; exit 0; }

# `id of w` is stable for the life of the window and is what makes two tabs comparable.
WID=$(osascript <<AS 2>/dev/null
tell application "Terminal"
  repeat with w in windows
    repeat with t in tabs of w
      if tty of t is "$MYTTY" then return ((id of w) as text) & " " & ((count of tabs of w) as text)
    end repeat
  end repeat
  return ""
end tell
AS
)
TABS=$(printf '%s' "$WID" | awk '{print $2}')
WID=$(printf '%s' "$WID" | awk '{print $1}' | tr -d '[:space:]')
[ -n "$TABS" ] || TABS=0
[ -n "$WID" ] || { echo "WINDOW: unknown — no Terminal.app tab matches $MYTTY (iTerm2, tmux or another host)"; exit 0; }

CFG="$CFG" SID="$SESSION_ID" WID="$WID" TABS="$TABS" python3 - <<'PY' 2>/dev/null || { echo "WINDOW: $WID (not recorded — config unwritable)"; exit 0; }
import json, os, tempfile
f = os.environ["CFG"]
try:
    with open(f) as fh: d = json.load(fh)
    if not isinstance(d, dict): raise ValueError
except FileNotFoundError:
    d = {}
except Exception:
    raise SystemExit(1)   # unparseable: leave it alone, like every other file this skill owns
d.setdefault("_comment", "written by mission-control window-probe.sh: which terminal window each session sits in")
d.setdefault("sessions", {})[os.environ["SID"]] = {"window": os.environ["WID"],
                                                   "tabs": int(os.environ.get("TABS") or 0)}
t = tempfile.NamedTemporaryFile("w", dir=os.path.dirname(f) or ".", delete=False)
json.dump(d, t, indent=2); t.write("\n"); t.close()
os.replace(t.name, f)
PY
echo "WINDOW: $WID — recorded for session $SESSION_ID"
echo "  The status line now groups by this: a station sharing a window with another is a"
echo "  tab; one alone in its window gets the window colour."
