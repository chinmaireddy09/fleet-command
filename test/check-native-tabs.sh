#!/bin/bash
# check-native-tabs.sh — does a spawned station land as a TAB or a WINDOW on this Mac?
#
# Run it, read the verdict. It opens one throwaway Terminal window/tab, measures, and
# closes it again. Nothing else is touched.
#
# WHY A SCRIPT AND NOT A LOOK: because the obvious instrument is blind, and it has now
# produced a wrong conclusion twice in this project's history. Terminal's own AppleScript
# CANNOT SEE macOS window tabs -- three tabs in one window report as three windows with
# one tab each, identical to three separate windows. Counting `windows` or `tabs of
# window` therefore cannot answer this question at all.
#
# System Events sees the real thing: a native tab group is ONE accessibility window. So
# the measurement is: how many accessibility windows before, how many after. Unchanged
# means the new terminal joined an existing window as a tab; +1 means it is its own
# window. Measured 2026-08-24: Terminal reported 4 windows where System Events reported
# 2, because the user had merged three of them into one tab group.
#
# BACKGROUND MODE DOES NOT CARE ABOUT ANY OF THIS. This only affects `spawn.mode=window`.
set -u
[ "$(uname -s)" = "Darwin" ] || { echo "macOS only — this question does not arise elsewhere."; exit 0; }

MODE=$(defaults read -g AppleWindowTabbingMode 2>/dev/null || echo "(not set — macOS default is 'fullscreen': tabs only in fullscreen)")
echo "AppleWindowTabbingMode: $MODE"
echo

axcount() { osascript -e 'tell application "System Events" to tell process "Terminal" to count windows' 2>&1; }

BEFORE=$(axcount)
case "$BEFORE" in
  ''|*[!0-9]*)
    echo "CANNOT MEASURE — System Events would not answer:"
    echo "  $BEFORE"
    echo
    echo "Terminal needs the Accessibility grant for this check only:"
    echo "  System Settings → Privacy & Security → Accessibility → enable Terminal"
    echo "Nothing in mission-control needs that grant; this diagnostic does."
    exit 2 ;;
esac
echo "accessibility windows before: $BEFORE"

osascript -e 'tell application "Terminal" to do script "echo MC-TABCHECK; sleep 4"' >/dev/null 2>&1
sleep 2
AFTER=$(axcount)
echo "accessibility windows after:  $AFTER"
echo

if [ "$AFTER" = "$BEFORE" ]; then
  echo "VERDICT: TAB ✅"
  echo "  A spawned station joins your existing window as a tab."
  echo "  Set window mode and you are done:"
  echo "     bash skills/mission-control/mc-config.sh set spawn.mode window"
else
  echo "VERDICT: WINDOW"
  echo "  A spawned station opens as its own window on this Mac."
  case "$MODE" in
    always)
      echo "  Tabbing is set to 'always' and it still did not join, so \`do script\` is not"
      echo "  going through the path native tabbing hooks. Terminal.app publishes no"
      echo "  scriptable new-tab (\`make new tab\` fails; \`do script ... in <window>\` reuses"
      echo "  the EXISTING tab), so the remaining ways to get tabs are:"
      echo "    · Window → Merge All Windows after a deploy — one action, no automation"
      echo "    · tmux — real tabs, fully scriptable, but its own status bar, not native tabs"
      echo "    · iTerm2 — publishes a real \`create tab\`, which mission-control already uses" ;;
    *)
      echo "  Try turning native tabbing on first, then RESTART Terminal (apps read this"
      echo "  setting at launch) and run this again:"
      echo "     defaults write -g AppleWindowTabbingMode -string always" ;;
  esac
fi

# ── THIS SCRIPT CLOSES NOTHING, AND THAT IS DELIBERATE ──────────────────────────
# It was written to clean up after itself with:
#     close w  WHERE history of selected tab contains "MC-TABCHECK"
# which is unsafe for two reasons that compound:
#   1. `close w` closes a WINDOW, and once macOS native tabs are in play a window is a
#      TAB GROUP -- so that call takes every session in the group, not the one tab meant.
#   2. `history of selected tab` inspects only whichever tab is CURRENTLY SELECTED, so a
#      marker sitting in an UNRELATED session's scrollback -- including the scrollback of
#      whatever session ran this script and printed the marker in its own output -- makes
#      an innocent window match.
# Together: a string written by the caller can select the user's live sessions for
# closing, and Terminal's AppleScript cannot tell you it is about to do that, because it
# is the same blindness this project already documents in the spawn path -- it cannot
# distinguish a tab group from a window.
#
# Nothing in mission-control needs to close a terminal, so nothing here closes one.
echo
echo "A test window/tab is open running \`echo MC-TABCHECK\`. Close it yourself (⌘W)."
echo "This script deliberately closes nothing: \`close window\` shuts an entire TAB GROUP,"
echo "and no AppleScript reliably tells you which sessions are inside it."
