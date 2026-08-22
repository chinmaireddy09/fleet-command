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
# --print may appear anywhere; the rest are positional.
MODE=""; BATCH=""; ARGS=""
for a in "$@"; do
  case "$a" in
    --print) MODE="--print" ;;
    # --batch: open the tab and return WITHOUT the 4s in-tab verification. For deploying
    # several stations at once: the per-spawn wait is what makes N stations take N times
    # as long, and it is pure latency -- the tabs can all be opened first and the whole
    # fleet verified in ONE pass afterwards. Use it ONLY when a batch verification really
    # follows; a spawn nobody checks is the 2026-08-17 failure this script exists to stop.
    --batch) BATCH="1" ;;
    *) ARGS="$ARGS
$a" ;;
  esac
done
CALLSIGN=$(printf '%s' "$ARGS" | sed -n '2p'); WT=$(printf '%s' "$ARGS" | sed -n '3p'); HANDLE=$(printf '%s' "$ARGS" | sed -n '4p')
[ -z "$CALLSIGN" ] || [ -z "$WT" ] && { echo "usage: spawn-station.sh <CALLSIGN> <WORKTREE> [HANDLE] [--print]" >&2; exit 2; }
[ -d "$WT" ] || { echo "FAILED: no such worktree: $WT" >&2; exit 1; }

# The call-sign is what people say; the handle is what peers address. They are the
# same unless the user chose otherwise -- a call-sign with a space cannot be a
# session name, and which short form they want is theirs to pick, never ours.
if [ -z "$HANDLE" ]; then
  case "$CALLSIGN" in
    *[!A-Za-z0-9_-]*)
      echo "FAILED: \"$CALLSIGN\" cannot be a session name. Ask the user for a handle and pass it:" >&2
      echo "        spawn-station.sh \"$CALLSIGN\" $WT <HANDLE>" >&2
      exit 2;;
    *) HANDLE="$CALLSIGN";;
  esac
fi
case "$HANDLE" in *[!A-Za-z0-9_-]*) echo "FAILED: a handle is [A-Za-z0-9_-] only -- got \"$HANDLE\"" >&2; exit 2;; esac

# A call-sign is free-form ON PURPOSE -- "FLEET COMMAND", "CHANNELS & INTEGRATIONS" --
# and it is interpolated into a command line below. Free-form plus interpolation is a
# shell injection, and this one is worse than most: in --print mode the HUMAN pastes
# the result, so anything smuggled in runs by their own hand and with their consent.
#
# ALLOWLIST, not a blocklist. A call-sign is a name a person says: letters, digits,
# spaces, and the few separators real ones use. Quotes, backticks, $, backslashes,
# newlines and every metacharacter are then gone by construction rather than by
# remembering to enumerate them.
case "$CALLSIGN" in
  "" | *[!A-Za-z0-9\ ._/\&-]* )
    echo "FAILED: a call-sign may contain letters, digits, spaces and . _ / & - only" >&2
    echo "        got: $CALLSIGN" >&2
    exit 2 ;;
esac
if [ ${#CALLSIGN} -gt 64 ]; then echo "FAILED: call-sign too long (max 64)" >&2; exit 2; fi

# The worktree path is not ours either. Escape it for the single-quoted context.
Q_WT=${WT//\'/\'\\\'\'}

# Hand the station its own address anyway. It CAN read it for itself now -- ME_NAME off
# the registry, [ref] off its own ListAgents self-line (6.34.0) -- so this is no longer
# the rescue it once was. It is still worth sending: the spawner knows the address before
# the station exists, so the station starts already agreeing with the board instead of
# deriving agreement. What it must NOT do is trust the NAME on that self-line, which is a
# start-time snapshot; the prompt below therefore asserts the address rather than telling
# it to go look one up.
# KEEP THIS PROMPT SHORT, AND THE REASON IS THE TAB TITLE. Terminal composes a tab's
# title out of the working directory, the title the process sets, the process name AND
# ITS FULL ARGUMENT LIST. This prompt IS an argument, so every character of it is on
# the user's tab bar, pushing the repo and the call-sign off the readable part.
#
# It used to read "/mc identify X -- your ListAgents address is X; confirm with
# ps -o args= on your own claude process", which existed only because a station could
# not read its own address. 6.34.0 retired that: ME_NAME is live in the registry and
# the [ref] is on the station's own ListAgents self-line. The long form is now both
# unnecessary and wrong-headed, so the tab gets its width back for free -- no Terminal
# setting to change, which matters because we should not be asking people to
# reconfigure their terminal to make our own output legible.
PROMPT="/mc identify $CALLSIGN"
# `--name` is not only the ListAgents address. MEASURED 2026-08-22 on 2.1.239, by capturing
# the pty across one real turn, three launches of the same session:
#   plain `claude`          -> 7 title writes: "✳ Claude Code" ... then "✳ Pong reply".
#                              The turn SUMMARY takes the tab. This is the tab going wrong.
#   `claude --name FOO`     -> 5 title writes, every one "<glyph> FOO". The summary never
#                              displaces it, so the call-sign is on the tab all watch.
#   with CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 -> 0 writes.
# So the tab is held by --name at LAUNCH and by nothing a running session can do to itself.
# It is also plain OSC, so it holds in iTerm2/Ghostty/tmux where the AppleScript path cannot
# reach. Do not "fix" the tab by disabling title writes here: that switches the durable,
# portable mechanism off and replaces it with a Terminal.app-only one.
CMD="cd '$Q_WT' && claude --name '$HANDLE' '$PROMPT'"

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

# ── which automation can actually open a tab here ────────────────────────────
# ONE RECIPE PER HOST, AND `--print` IS THE ONE THAT WORKS EVERYWHERE. This used to
# call `osascript` unconditionally, so on Linux, on Windows, and inside the VS Code
# integrated terminal it failed with "osascript: command not found" instead of simply
# handing over the paste-able line it already had. **A missing recipe is not an
# error** -- the human opening a tab by hand is the normal path on most machines, and
# the deploy is finished by the board either way.
#
# tmux is checked FIRST and deliberately: it is the only recipe that works on macOS,
# Linux, Windows (WSL) and INSIDE VS Code's terminal, so a user who runs tmux gets
# real automation on every platform this skill will ever meet.

print_fallback() {   # $1 = why
  cat <<TXT
CANNOT AUTOMATE HERE — $1
Open a new tab yourself and paste this:

  $CMD

That is not a degraded deploy. The tab is the only part a human was ever doing, and
the post is already prepared: worktree, branch and board row are done. Verify by the
BOARD, not by the tab looking right — the deploy is finished when $CALLSIGN's row on
origin/main carries its fleet-manifest address.
TXT
}

# 1. tmux — portable, and the station lands in its own worktree directly.
if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
  if tmux new-window -c "$WT" -n "$CALLSIGN" "$CMD" 2>/dev/null; then
    # tmux's exit code proves a WINDOW was created. It does not prove a station started,
    # and this script exists because "a tab is not a station". The AppleScript path can
    # look inside its own tab for a live `claude`; tmux is told to run a command and
    # returns immediately, so there is nothing here to look at yet. Say exactly that
    # rather than borrowing the other path's confidence.
    echo "TMUX WINDOW OPENED · named $CALLSIGN · command dispatched"
    echo "NOT YET A STATION. Verify by the fleet manifest or the board — $CALLSIGN is on"
    echo "post when its row on origin/main carries its address, not when this printed."
    echo "  tmux list-panes -t '$CALLSIGN' -F '#{pane_current_command}'   # should say: claude"
    exit 0
  fi
  print_fallback "tmux is running but refused to open a window"; exit 1
fi

# 2. Windows Terminal.
if [ -n "${WT_SESSION:-}" ] && command -v wt.exe >/dev/null 2>&1; then
  if wt.exe -w 0 nt -d "$WT" cmd /k "claude --name $HANDLE \"/mc identify $CALLSIGN\"" 2>/dev/null; then
    # Same caveat as tmux, plus one more: this recipe has never been run against a real
    # Windows Terminal. Do not report it as a verified deploy on either count.
    echo "WT TAB OPENED · $CALLSIGN · command dispatched"
    echo "NOT YET A STATION, and this recipe is UNVERIFIED against a real Windows Terminal."
    echo "Verify by the board: $CALLSIGN is on post when its row carries its address."
    exit 0
  fi
  print_fallback "Windows Terminal is running but \`wt\` refused to open a tab"; exit 1
fi

# 3. macOS Terminal.app — the measured path, and the only one with a verification step.
if [ "$(uname -s)" != "Darwin" ] || ! command -v osascript >/dev/null 2>&1; then
  print_fallback "no recipe for this host ($(uname -s)${TERM_PROGRAM:+, $TERM_PROGRAM}). tmux would give you one on every platform."
  exit 0     # not a failure: the human has everything they need
fi
if [ "${TERM_PROGRAM:-}" != "Apple_Terminal" ]; then
  print_fallback "this is $TERM_PROGRAM, not Apple Terminal — the AppleScript recipe here is written for Terminal.app and would target the wrong application. Inside VS Code, run tmux and re-run, or paste the line."
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
delay __VERIFYDELAY__
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
# In batch mode the per-spawn verification is skipped here and done once for the whole
# fleet afterwards -- so this delay goes to 0 rather than the check being deleted.
if [ -n "$BATCH" ]; then AS_SRC=${AS_SRC//__VERIFYDELAY__/0}; else AS_SRC=${AS_SRC//__VERIFYDELAY__/4}; fi
AS_SRC=${AS_SRC//__MYTTY__/$MYTTY}
AS_SRC=${AS_SRC//__CMD__/$CMD}
OUT=$(printf '%s' "$AS_SRC" | osascript - 2>&1)
RC=$?
echo "$OUT"

# osascript exits 0 even when the SCRIPT returns "FAILED:" — so inspect what it said,
# not just how it exited. Either way the human must end up with something to act on.
case "$OUT" in
  *"not found by tty"*|*"no Accessibility"*) RC=1 ;;
  *FAILED*) [ -n "$BATCH" ] || RC=1 ;;   # in batch mode "no claude yet" is expected, not a failure
esac
if [ -n "$BATCH" ]; then
  echo "BATCH: tab opened for $CALLSIGN — NOT yet verified. The batch verification after"
  echo "       the last spawn is what makes this a deploy; without it you have opened a tab."
fi
if [ $RC -ne 0 ]; then
  printf '\nAutomated spawn did not finish cleanly. Open a tab (⌘T) and paste this instead:\n\n  %s\n' "$CMD"
fi
exit $RC
