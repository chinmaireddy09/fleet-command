#!/bin/bash
# label-tab.sh <CALLSIGN> — pin a call-sign to THIS session's own Terminal tab.
# Finds its own tab by tty, never by "front window" (that is whichever window has
# focus — i.e. somebody else's tab). Verified macOS Terminal.app 2026-08-17.
set -u
CALLSIGN="${1:-}"
[ -z "$CALLSIGN" ] && { echo "usage: label-tab.sh <CALLSIGN>" >&2; exit 2; }

# The Bash tool has no tty; the `claude` process above it does. Walk up to find it.
p=$$; MYTTY=""
while [ "$p" -gt 1 ]; do
  t=$(ps -o tty= -p "$p" 2>/dev/null | tr -d ' ')
  if [ -n "$t" ] && [ "$t" != "??" ]; then MYTTY="/dev/$t"; break; fi
  p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
done
[ -z "$MYTTY" ] && { echo "FAILED: no tty in the parent chain" >&2; exit 1; }

osascript <<AS
tell application "Terminal"
  repeat with w in windows
    repeat with t in tabs of w
      if tty of t is "$MYTTY" then
        set custom title of t to "$CALLSIGN"
        return "$MYTTY" & " -> " & (custom title of t)
      end if
    end repeat
  end repeat
  return "NO-MATCH for $MYTTY"
end tell
AS
