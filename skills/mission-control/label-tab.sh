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
# THE ALLOWLIST IS MATCHED UNDER C SEMANTICS, ON PURPOSE. [A-Za-z0-9] is a COLLATION
# range, so under a UTF-8 locale it admits whatever the locale sorts inside it. Measured
# 2026-08-23 with explicit bytes, en_IN.UTF-8 vs C:
#   U+00E9 e-acute  c3a9    UTF-8 ADMIT / C REJECT
#   U+00C5 A-ring   c385    UTF-8 ADMIT / C REJECT
#   U+FB00 ff-lig   efac80  UTF-8 ADMIT / C REJECT
#   U+00A0 NBSP     c2a0    REJECTED under BOTH
#   U+200B ZWSP     e2808b  REJECTED under BOTH
# while the message promised "letters, digits, spaces and . _ / & - only".
# NOTHING INVISIBLE EVER GOT IN, and an earlier version of this comment said otherwise --
# a first report claimed NBSP was admitted, having typed a literal that was normalised to
# a plain space before it reached the guard; the reporter caught and corrected it. The
# real defect is narrower and still worth fixing: a call-sign can be accepted here with a
# character that is VISUALLY CONFUSABLE with an ASCII one (CAFE vs CAFE with an accent)
# and then match nothing anywhere else. Assert the bytes, never the literal.
# LC_ALL=C makes the rule mean exactly what it says, in bytes.
if ! ( LC_ALL=C; case "$CALLSIGN" in "" | *[!A-Za-z0-9\ ._/\&-]* ) exit 1;; esac ); then
  echo "FAILED: a call-sign may contain letters, digits, spaces and . _ / & - only" >&2
  # ECHO WHAT WAS PASSED. This was the one guard that stated the rule without showing
  # the input -- and a rejected call-sign is most often rejected for a character that
  # LOOKS like an allowed one, which a rule restated without the input cannot resolve.
  echo "        got: $CALLSIGN" >&2
  exit 2
fi
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
  # THE VERDICT STAYS FLAT. This briefly read "PROBABLY NOT" -- hedged because the
  # overwrite was measured NOT to happen once. That was the wrong place to put the
  # uncertainty: SKILL.md enforces "never report a tab as labelled unless this line
  # agrees", and a station can talk itself past "probably not" where it cannot talk
  # itself past "no". A hedge here widens what a station may claim about its own tab.
  # The QUESTION is "may I rely on this label?", and unreliable means NO. The
  # uncertainty is about the MECHANISM, so it lives in the explanation below.
  # Caught 2026-08-23 by a station that ran this twice across the change and noticed
  # the verdict had moved while nothing about its session had.
  echo "persists: NO — launched without --name and without CLAUDE_CODE_DISABLE_TERMINAL_TITLE."
  echo "          You may NOT report this tab as labelled. That verdict is flat, and it is the"
  echo "          one this skill enforces."
  echo "          Claude Code usually overwrites this tab at its next status change, leaving the"
  echo "          TURN SUMMARY (measured: 7 writes in one turn). The TIMING is not certain --"
  echo "          a tester on exactly this configuration kept a custom title for a whole turn"
  echo "          across many status changes (2026-08-23). Unpredictable is why the answer is NO:"
  echo "          a label you cannot predict is a label you cannot rely on. Do not read the"
  echo "          uncertainty as permission -- go and look at the tab."
  echo "          A running session cannot fix this itself — argv and env are fixed at launch."
  echo "          The human types  /rename $CALLSIGN  in this tab and it holds (measured)."
  echo "          That is the whole fix for THIS surface, it costs nothing, and it needs no"
  echo "          relaunch. Do NOT report this tab as labelled until it is done."
  echo
  echo "          AND /rename DOES NOT FIX THE @ HEADER. Two surfaces, two mechanisms, and"
  echo "          offering one repair for both is how somebody concludes they have fixed an"
  echo "          identity that is still wrong on every message they send:"
  echo "            tab title  — rewritten at each status change. /rename holds it. FIXABLE HERE."
  echo "            @ header   — the name this process cached AT STARTUP. There is one socket"
  echo "                         per pid and no per-channel handshake, so nothing a running"
  echo "                         session does can change what its messages are stamped with."
  echo "                         Measured 2026-08-22: a channel opened AFTER a rename still"
  echo "                         carried the pre-rename name. NOT FIXABLE HERE."
  echo
  echo "          DO NOT TURN THAT INTO A REQUEST TO RELAUNCH. For CONTROL it is not even"
  echo "          answerable: the post is taken by whoever runs /mc, so that session never had"
  echo "          a call-sign to launch with. PUBLISH the envelope instead — carry the handle"
  echo "          on your board row, and say once in your first transmission: \"address"
  echo "          $CALLSIGN; the name on my envelope is not my call-sign.\" fix-header.sh"
  echo "          prints the relaunch line if the USER asks; never volunteer it."
  echo "          The protocol already carries the truth: every transmission opens"
  echo "          \"CALLSIGN TO CALLSIGN\" — the body is the identity, the envelope is not."
fi
