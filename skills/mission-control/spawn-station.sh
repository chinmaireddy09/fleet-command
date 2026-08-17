#!/bin/bash
# spawn-station.sh <CALLSIGN> <WORKTREE> — open a station in a new Terminal tab.
#
# Three things the old inline recipe got wrong, all seen live on 2026-08-17:
#   1. It typed ⌘T with `keystroke "t" using command down`. When the modifier lost
#      the race the bare "t" reached the shell, `do script` appended the command to
#      that same line, and the station tried to run `tcd '/path' && claude …`.
#   2. It resolved the new tab through `front window` — whichever window had FOCUS,
#      which is somebody else's. Stations landed in the wrong window and the title
#      bar then advertised the wrong repo.
#   3. It never read the tab back, so both failures were silent. label-tab.sh has
#      read its result back since the day it shipped; this did not.
#
# So: target OUR OWN window by tty, and verify a claude process is actually running
# in the new tab before calling it a spawn.
set -u
CALLSIGN="${1:-}"; WT="${2:-}"
[ -z "$CALLSIGN" ] || [ -z "$WT" ] && { echo "usage: spawn-station.sh <CALLSIGN> <WORKTREE>" >&2; exit 2; }
[ -d "$WT" ] || { echo "FAILED: no such worktree: $WT" >&2; exit 1; }

# Our own tty — the Bash tool has none, the claude process above it does.
p=$$; MYTTY=""
while [ "$p" -gt 1 ]; do
  t=$(ps -o tty= -p "$p" 2>/dev/null | tr -d ' ')
  if [ -n "$t" ] && [ "$t" != "??" ]; then MYTTY="/dev/$t"; break; fi
  p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
done
[ -z "$MYTTY" ] && { echo "FAILED: no tty in the parent chain" >&2; exit 1; }

# Hand the station its own address in the prompt. It cannot read it from ListAgents
# (a session never sees itself), and the spawner knows it before the station exists --
# so asserting it here removes a radio round-trip that happened three times in one hour.
CMD="cd '$WT' && claude --name '$CALLSIGN' '/mc identify $CALLSIGN — your ListAgents address is $CALLSIGN; confirm with: ps -o args= on your own claude process'"

osascript <<AS
on findWindowId(theTty)
  tell application "Terminal"
    repeat with w in windows
      repeat with t in tabs of w
        if tty of t is theTty then return id of w
      end repeat
    end repeat
  end tell
  return 0
end findWindowId

set myWin to findWindowId("$MYTTY")
tell application "Terminal" to activate

if myWin is 0 then
  -- Cannot find our own window: a new window is honest, a stranger's tab is not.
  tell application "Terminal" to do script "$CMD"
  return "WINDOW (own window not found by tty)"
end if

-- Focus OUR window, never whatever happens to be frontmost.
tell application "Terminal" to set frontmost of window id myWin to true
delay 0.5

try
  tell application "System Events" to keystroke "t" using command down
on error errMsg number errNum
  tell application "Terminal" to do script "$CMD"
  return "WINDOW (no Accessibility: " & errNum & ")"
end try
delay 0.9

tell application "Terminal"
  set theTab to selected tab of window id myWin
  do script "$CMD" in theTab
end tell

-- Verify: a tab exists is not the claim. A claude process running in it is.
delay 4
tell application "Terminal"
  set procs to (processes of (selected tab of window id myWin)) as string
  if procs contains "claude" then
    return "TAB ok · window " & myWin & " · " & (tty of (selected tab of window id myWin))
  else
    set h to history of (selected tab of window id myWin)
    if (count of h) > 400 then set h to text -400 thru -1 of h
    return "FAILED: no claude process in the new tab. Scrollback tail:" & return & h
  end if
end tell
AS
