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
#   ~/.claude/mission-control-windows.json   { "sessions": { "<sessionId>": "<windowId>" } }
# The status line then GROUPS live stations by that id -- two stations sharing a window are
# tabs, a station alone in its window has a window to itself. Grouping is used rather than
# a tab count taken here, because a count is true only at the instant it is taken and a
# grouping re-derives itself on every render as stations come and go.
#
# IT IS BEST-EFFORT AND NEVER FATAL. No Terminal.app, no tty, no match, no AppleScript:
# it says so and exits 0. A missing record costs one colour, and the station still renders
# as a tab -- "visible somewhere" is the honest fallback and it is never wrong about that.
#
# SAFE TO RUN REPEATEDLY. It rewrites its own key and touches nothing else.
set -u

CFG="${MC_WINDOWS:-$HOME/.claude/mission-control-windows.json}"

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
      if tty of t is "$MYTTY" then return (id of w) as text
    end repeat
  end repeat
  return ""
end tell
AS
)
WID=$(printf '%s' "$WID" | tr -d '[:space:]')
[ -n "$WID" ] || { echo "WINDOW: unknown — no Terminal.app tab matches $MYTTY (iTerm2, tmux or another host)"; exit 0; }

CFG="$CFG" SID="$SESSION_ID" WID="$WID" python3 - <<'PY' 2>/dev/null || { echo "WINDOW: $WID (not recorded — config unwritable)"; exit 0; }
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
d.setdefault("sessions", {})[os.environ["SID"]] = os.environ["WID"]
t = tempfile.NamedTemporaryFile("w", dir=os.path.dirname(f) or ".", delete=False)
json.dump(d, t, indent=2); t.write("\n"); t.close()
os.replace(t.name, f)
PY
echo "WINDOW: $WID — recorded for session $SESSION_ID"
echo "  The status line now groups by this: a station sharing a window with another is a"
echo "  tab; one alone in its window gets the window colour."
