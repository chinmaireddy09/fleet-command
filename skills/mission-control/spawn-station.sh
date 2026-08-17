#!/bin/bash
# spawn-station.sh <CALLSIGN> <WORKTREE> [--print] — put a station on post.
#
# DEFAULT (what `/mc deploy` calls): open the tab, type the command, verify a
#          session really started, and fall back to printing if any of that fails.
# --print: print the command for the human to paste. What `/mc station` uses, and
#          what you get automatically whenever the automated path cannot finish.
#
# THE RULE: asking to deploy IS the authorisation to automate. `/mc deploy X` means
# "put X on post without me typing anything". Anything short of that -- initiating a
# post nobody is walking to yet, or a session coming up by hand -- prints instead.
#
# Everything below survives from the 2026-08-17 failures, because the automation was
# never the problem; being unverified and silent was:
#   `keystroke "t" using command down` does not do something cleverer than pressing
#   ⌘T — it synthesises the identical keypress, and only the synthetic version can
#   go wrong. On 2026-08-17 the modifier lost its race, the bare "t" reached the
#   shell, and the station tried to run `tcd '/path' && claude …`. The same keypress
#   also lands in whichever window has focus, so a station opened in an unrelated
#   window. A finger has neither failure mode.
#
#   So the automated path stayed, but it no longer trusts itself: it targets its own
#   window by tty, checks a claude process is really running in the new tab, and
#   prints the paste-able command whenever it cannot prove that.
#
# Note the new tab inherits the SPAWNER's directory, not the worktree — Control sits
# in the repo root and the station belongs in .claude/worktrees/<station> — so the
# `cd` is required whoever opens the tab.
set -u
CALLSIGN="${1:-}"; WT="${2:-}"; MODE="${3:-}"
[ -z "$CALLSIGN" ] || [ -z "$WT" ] && { echo "usage: spawn-station.sh <CALLSIGN> <WORKTREE> [--print]" >&2; exit 2; }
[ -d "$WT" ] || { echo "FAILED: no such worktree: $WT" >&2; exit 1; }

# Hand the station its own address. It cannot read it from ListAgents (a session
# never sees itself), and the spawner knows it before the station exists — so
# asserting it here removes a radio round-trip that happened three times in one hour.
PROMPT="/mc identify $CALLSIGN — your ListAgents address is $CALLSIGN; confirm with ps -o args= on your own claude process"
CMD="cd '$WT' && claude --name '$CALLSIGN' '$PROMPT'"

if [ "$MODE" = "--print" ]; then
  cat <<TXT
STATION $CALLSIGN — open a tab (⌘T) and paste this:

  $CMD

The tab inherits this window's directory, so the leading cd is what puts it in its
own worktree. Nothing is typed for you and nothing can be mistyped — the call-sign
and path are already filled in.

Then verify by the BOARD, not by the tab looking right: the deploy is done when
$CALLSIGN's row on origin/main carries its ListAgents address.
TXT
  exit 0
fi

# Automated path. Find our own tty so the tab opens in OUR window, never "front window".
p=$$; MYTTY=""
while [ "$p" -gt 1 ]; do
  t=$(ps -o tty= -p "$p" 2>/dev/null | tr -d ' ')
  if [ -n "$t" ] && [ "$t" != "??" ]; then MYTTY="/dev/$t"; break; fi
  p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
done
[ -z "$MYTTY" ] && { echo "FAILED: no tty in the parent chain" >&2; exit 1; }

AS_SRC=$(cat <<'ASEOF'
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

set myWin to findWindowId("__MYTTY__")
tell application "Terminal" to activate

if myWin is 0 then
  tell application "Terminal" to do script "__CMD__"
  return "WINDOW (own window not found by tty)"
end if

tell application "Terminal" to set frontmost of window id myWin to true
delay 0.5

try
  tell application "System Events" to keystroke "t" using command down
on error errMsg number errNum
  tell application "Terminal" to do script "__CMD__"
  return "WINDOW (no Accessibility: " & errNum & ")"
end try
delay 0.9

tell application "Terminal"
  set theTab to selected tab of window id myWin
  do script "__CMD__" in theTab
end tell

-- A tab existing is not the claim. A claude process running in it is.
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
ASEOF
)
AS_SRC=${AS_SRC//__MYTTY__/$MYTTY}
AS_SRC=${AS_SRC//__CMD__/$CMD}
OUT=$(printf '%s' "$AS_SRC" | osascript - 2>&1)
RC=$?
echo "$OUT"

# osascript exits 0 even when the SCRIPT returns "FAILED:" — so inspect what it said,
# not just how it exited. Either way the human must end up with something to act on.
case "$OUT" in
  *FAILED*|*"not found by tty"*|*"no Accessibility"*) RC=1 ;;
esac
if [ $RC -ne 0 ]; then
  printf '\nAutomated spawn did not finish cleanly. Open a tab (⌘T) and paste this instead:\n\n  %s\n' "$CMD"
fi
exit $RC
