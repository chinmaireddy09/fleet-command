#!/bin/bash
# label-tab.sh <CALLSIGN> — put a call-sign on THIS session's own Terminal tab.
# Finds its own tab by tty, never by "front window" (that is whichever window has
# focus — i.e. somebody else's tab). Verified macOS Terminal.app 2026-08-17.
#
# WHETHER THE LABEL STICKS IS DECIDED AT LAUNCH, NOT BY THIS SCRIPT. Claude Code
# writes the tab title itself, once per status change. MEASURED 2026-08-22 on
# 2.1.239 by capturing the pty across one real turn, three ways:
#   plain `claude`        -> 7 writes: "✳ Claude Code" ... "✳ <turn summary>".
#                            Whatever we set here is gone at the first status change,
#                            and the tab ends up showing the turn summary. THIS is the
#                            "tab name only lasts a little while" everyone reports.
#   `claude --name FOO`   -> 5 writes, every one "<glyph> FOO". The summary NEVER
#                            displaces it. The call-sign is on the tab all watch, and
#                            it is plain OSC so it also holds in iTerm2/Ghostty/tmux.
#   CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 -> 0 writes, so a custom title set here is
#                            the only thing on the tab. Terminal.app-only.
# A RUNNING SESSION CANNOT MOVE ITSELF BETWEEN THOSE WORLDS -- argv and env are fixed
# at exec. So this script reports which one it is in and never claims a label holds.
set -u
CALLSIGN="${1:-}"
[ -z "$CALLSIGN" ] && { echo "usage: label-tab.sh <CALLSIGN>" >&2; exit 2; }

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

# The Bash tool has no tty; the `claude` process above it does. Walk up to find it.
p=$$; MYTTY=""
while [ "$p" -gt 1 ]; do
  t=$(ps -o tty= -p "$p" 2>/dev/null | tr -d ' ')
  if [ -n "$t" ] && [ "$t" != "??" ]; then MYTTY="/dev/$t"; break; fi
  p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
done
[ -z "$MYTTY" ] && { echo "FAILED: no tty in the parent chain" >&2; exit 1; }

OUT=$(osascript <<AS
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
)
echo "$OUT"
case "$OUT" in NO-MATCH*) exit 1 ;; esac

# The label is set. Now say honestly whether it survives the next turn. Both conditions
# below are READ from this session, never assumed: env is inherited by this shell, and
# argv comes off our own claude process. Report what they say, not what you hoped.
p=$$; CLAUDE_ARGS=""
while [ "$p" -gt 1 ]; do
  comm=$(ps -o comm= -p "$p" 2>/dev/null | xargs basename 2>/dev/null)
  if [ "$comm" = "claude" ]; then CLAUDE_ARGS=$(ps -o args= -p "$p" 2>/dev/null); break; fi
  p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  [ -z "$p" ] && break
done

if [ -n "${CLAUDE_CODE_DISABLE_TERMINAL_TITLE:-}" ]; then
  echo "persists: YES — CLAUDE_CODE_DISABLE_TERMINAL_TITLE is set, so Claude Code writes"
  echo "          no title of its own and \"$CALLSIGN\" is the only thing on this tab."
elif printf '%s' "$CLAUDE_ARGS" | grep -q -- '--name'; then
  NAMED=$(printf '%s' "$CLAUDE_ARGS" | sed -n 's/.*--name[= ]*\([^ ]*\).*/\1/p' | tr -d "'\"")
  echo "persists: YES (as \"$NAMED\") — this session was launched with --name, so Claude Code's"
  echo "          own title writes carry it: the tab will read \"<status glyph> $NAMED\" and the"
  echo "          turn summary never displaces it. The custom title just set above WILL be"
  echo "          replaced at the next status change — by the call-sign, which is the point."
  if [ "$NAMED" != "$CALLSIGN" ]; then
    echo "          NOTE: the tab will show the HANDLE \"$NAMED\", not the call-sign \"$CALLSIGN\"."
    echo "          That is expected when the two differ; the board maps one to the other."
  fi
else
  echo "persists: NO — launched without --name and without CLAUDE_CODE_DISABLE_TERMINAL_TITLE."
  echo "          Claude Code overwrites this tab at its next status change and the tab ends up"
  echo "          showing the TURN SUMMARY (measured: 7 writes in one turn). The label above is"
  echo "          cosmetic until the next prompt."
  echo "          A running session cannot fix this itself — argv and env are fixed at launch."
  echo "          The human types  /rename $CALLSIGN  in this tab (measured to hold), or the"
  echo "          session is relaunched with  claude --name <HANDLE>  as /mc deploy does."
  echo "          Do NOT report this tab as labelled until one of those is true."
fi
