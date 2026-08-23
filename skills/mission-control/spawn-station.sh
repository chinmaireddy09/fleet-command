#!/bin/bash
# spawn-station.sh <CALLSIGN> <WORKTREE> [HANDLE] [--background|--window|--print] — put a station on post.
#
# DEFAULT (what `/mc deploy` calls): --background. `claude --bg` starts the station as a
#          background agent and returns immediately. No terminal is opened, nothing is
#          typed, nothing is focused, and it works identically on macOS, Linux, Windows,
#          and inside every IDE terminal — because no terminal is involved at all.
# --window: open a visible window/tab instead, using the host terminal's OWN scripting
#          API. Never synthesised keystrokes. For when the user wants to watch a station.
# --print: print the command for the human to paste. What `/mc station` uses.
#
# ── THE RULE, AND IT IS A SCOPE LIMIT ────────────────────────────────────────────
# Asking to deploy IS the authorisation to automate. `/mc deploy X` means "put X on post
# without me typing anything". Anything short of that -- initiating a post nobody is
# walking to yet, or a session coming up by hand -- prints instead.
#
# **And the authorisation is exactly that wide and no wider.** The automation exists for
# ONE job: open the station's session and get it identified. It is triggered by ONE
# thing: an explicit deploy. When the station is up and carrying its address, the
# automation is FINISHED -- it does not go back to the terminal to arrange, focus,
# resize, retitle, close or read anything, and no other operation in this skill may
# reach for it because it happens to be here.
#
# This is enforced, not just written down: a spawn requires `--deploy`. Without it the
# script prints the paste-able line and says why. An automation whose scope is a
# sentence in a comment grows; one whose scope is a required flag does not, because
# every call site has to state its intent out loud and `grep -c -- --deploy` counts them.
#
# ── WHY THE KEYSTROKE PATH IS GONE ───────────────────────────────────────────────
# Every version of this script through 6.77.0 opened a TAB by having System Events
# press ⌘T, then wrote the command into whatever tab that produced. That is puppetry:
# it drives the user's UI as if a person were at the keyboard, and it inherits every
# failure a person never has.
#
# It failed in the field on 2026-08-23, deploying three stations at once, and the
# screenshots are unambiguous:
#   * Three tabs opened. All three came up EMPTY, at a plain `%` prompt, still in the
#     spawner's directory. No station started in any of them.
#   * All three command lines were typed into CONTROL'S OWN prompt instead, arriving
#     interleaved and corrupted -- one line read `ntialcd '/Users/...' && claude ...`,
#     a fragment of one spawn's text fused onto the next one's `cd`.
# That is the 2026-08-17 modifier race and the focus race, both of them, at once and
# three times over. The earlier fix -- target our own window by tty, then verify -- did
# not remove the race. It only made the race observable. A race you can see is still a
# race, and `do script ... in (selected tab of window id N)` resolves that reference
# against a tab ⌘T may not have finished creating.
#
# The lesson is not "verify harder". It is that **the tab was never what made a station**.
# A station is a registered session: something ListAgents shows, SendMessage reaches, and
# the board can carry an address for. MEASURED 2026-08-23 on 2.1.241 -- a station started
# with `claude --bg --name MCBGPROBE` in an untrusted worktree:
#   * returned in under a second, no terminal, no keystrokes, no focus change;
#   * registered as `MCBGPROBE [b2aa24] · bg · idle` in ListAgents;
#   * ANSWERED A RADIO CHECK sent to it by call-sign with SendMessage.
# It is a station by every test the fleet applies. So the automated path now starts one
# directly, and the terminal window became an option for people who want to watch, rather
# than the mechanism a deploy depends on.
#
# Note the worktree is passed as the launch directory rather than inherited, so no `cd`
# is required of anybody in the default path.
set -u

# --- flags may appear anywhere; the rest are positional -------------------------
MODE=""; ARGS=""; DEPLOY=""
for a in "$@"; do
  case "$a" in
    --print)      MODE="print" ;;
    --window)     MODE="window" ;;
    --tab)        MODE="tab" ;;
    --background|--bg) MODE="background" ;;
    # The authorisation, stated at the call site. See THE RULE above.
    --deploy)     DEPLOY=1 ;;
    # --batch was how the OLD tab path amortised its 4-second per-spawn verification
    # across a fleet. Background spawns return immediately and are verified by one
    # `claude agents` read, so there is no per-spawn wait left to amortise. Accepted
    # so existing callers do not break; it no longer changes anything.
    --batch)      : ;;
    *) ARGS="$ARGS
$a" ;;
  esac
done
CALLSIGN=$(printf '%s' "$ARGS" | sed -n '2p'); WT=$(printf '%s' "$ARGS" | sed -n '3p'); HANDLE=$(printf '%s' "$ARGS" | sed -n '4p')
[ -z "$CALLSIGN" ] || [ -z "$WT" ] && { echo "usage: spawn-station.sh <CALLSIGN> <WORKTREE> [HANDLE] --deploy [--background|--window|--print]" >&2; exit 2; }
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
#
# THE ALLOWLIST IS MATCHED UNDER C SEMANTICS, ON PURPOSE, and the placement of LC_ALL
# is the whole trick. [A-Za-z0-9] is a COLLATION range: under a UTF-8 locale it admits
# accented letters and fullwidth forms while the message promises ASCII (reported
# 2026-08-23 against label-tab.sh, which fixed it there and nowhere else).
#
# It has to be set for the shell evaluating the `case`, not for a command inside it --
# `case "$(LC_ALL=C printf %s "$X")"` reads like a fix and is not one, because printf
# only echoes bytes and the pattern match still happens in the caller's locale. This is
# the idiom label-tab.sh already proved: a subshell that sets LC_ALL and then matches.
if ! ( LC_ALL=C; case "$CALLSIGN" in "" | *[!A-Za-z0-9\ ._/\&-]* ) exit 1;; esac ); then
  echo "FAILED: a call-sign may contain letters, digits, spaces and . _ / & - only" >&2
  echo "        got: $CALLSIGN" >&2
  exit 2
fi
if [ ${#CALLSIGN} -gt 64 ]; then echo "FAILED: call-sign too long (max 64)" >&2; exit 2; fi

# The worktree path is not ours either. Escape it for the single-quoted shell context.
Q_WT=${WT//\'/\'\\\'\'}

# ── the user's recorded preference, if they have one ────────────────────────────
# ~/.claude/mission-control.json is PER-MACHINE and user-level, and must never live in
# the repo -- a clone carrying the author's terminal choice looks configured and is
# wrong. Read with python3 when it is there, and simply skip when it is not: a missing
# or unreadable config is a preference nobody expressed, never an error.
CFG="${MC_CONFIG:-$HOME/.claude/mission-control.json}"
CFG_MODE=""; LAUNCH=""
if [ -r "$CFG" ] && command -v python3 >/dev/null 2>&1; then
  eval "$(python3 - "$CFG" <<'PY' 2>/dev/null || true
import json,sys,re
try: d=json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
s=d.get("spawn") or {}
m=s.get("mode")
if m in ("background","window","tab","print"): print('CFG_MODE=%s'%m)
lc=s.get("launchCommand")
# A launch command out of a config file reaches a command line. Bare binary only --
# the same allowlist reasoning as the call-sign, applied to the other free-form input.
if isinstance(lc,str) and re.fullmatch(r"[A-Za-z0-9._/-]{1,64}",lc): print('LAUNCH=%s'%lc)
PY
)"
fi
[ -n "$LAUNCH" ] || LAUNCH="claude"
# Precedence: explicit flag > recorded preference > background.
# MC_SPAWN_MODE comes from Claude Code's own settings:
#     ~/.claude/settings.json  ->  { "env": { "MC_SPAWN_MODE": "tab" } }
# `env` is injected into every Claude Code session, so a plain shell script can read it
# and the user changes it wherever they already change Claude settings. That is why it
# outranks this skill's own file: one place to look beats two that can disagree.
ENV_MODE=""
case "${MC_SPAWN_MODE:-}" in
  tab|window|background|print) ENV_MODE="$MC_SPAWN_MODE" ;;
  "") ;;
  *) echo "NOTE: MC_SPAWN_MODE=\"$MC_SPAWN_MODE\" is not one of tab|window|background|print — ignoring it." >&2 ;;
esac

UNRECORDED=""
if [ -z "$MODE" ]; then
  MODE="${ENV_MODE:-${CFG_MODE:-background}}"
  [ -n "$ENV_MODE" ] || [ -n "$CFG_MODE" ] || UNRECORDED=1
fi


# KEEP THIS PROMPT SHORT, AND THE REASON IS THE TAB TITLE -- in --window mode Terminal
# composes a tab's title out of the process name AND ITS FULL ARGUMENT LIST, so every
# character here lands on the user's tab bar, pushing the repo and call-sign off the
# readable part.
PROMPT="/mc identify $CALLSIGN"
# `--name` is not only the ListAgents address. MEASURED 2026-08-22 on 2.1.239, capturing
# the pty across one real turn: plain `claude` writes the turn SUMMARY to the title,
# `claude --name FOO` holds "<glyph> FOO" across all five title writes. It is plain OSC,
# so it holds in iTerm2/Ghostty/tmux too, and it is what makes the call-sign the address.
CMD="cd '$Q_WT' && $LAUNCH --name '$HANDLE' '$PROMPT'"

# THE RULE, ENFORCED. No --deploy, no spawn. This is deliberately a demotion to --print
# rather than a refusal: the caller still ends up with something that works, and the
# post is already prepared either way. A guard that leaves the human empty-handed gets
# routed around.
if [ "$MODE" != "print" ] && [ -z "$DEPLOY" ]; then
  cat <<TXT
NOT A DEPLOY — no session was started and no window was opened.

The spawn automation runs only when a deploy asked for it, and only to open a station
and get it identified. This call did not say --deploy, so it printed instead:

  $CMD

If this IS a deploy, pass --deploy. If it is not, this is the correct outcome.
TXT
  exit 0
fi

# ── shared reporting ────────────────────────────────────────────────────────────
print_paste() {   # $1 = leading line
  cat <<TXT
$1

  $CMD

The call-sign and path are already filled in and cannot be mistyped. Verify by the
BOARD, not by the window looking right — the deploy is finished when $CALLSIGN's row
on the repo's base branch carries its fleet-manifest address.
TXT
}

# Is a session called $HANDLE actually registered? `claude agents --json` prints active
# sessions -- interactive AND background -- and explicitly does not require a TTY, which
# is what finally makes verification scriptable. The old path had nothing like this and
# had to read Terminal's scrollback to guess.
registered() {
  command -v "$LAUNCH" >/dev/null 2>&1 || return 2
  local j; j=$("$LAUNCH" agents --json 2>/dev/null) || return 2
  [ -n "$j" ] || return 2
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$j" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(2)
sys.exit(0 if any(s.get("name")==sys.argv[1] for s in d) else 1)' "$HANDLE"
  else
    # No python3: a name match in the raw JSON. Looser, and it says so rather than
    # claiming the structured check ran.
    case "$j" in *"\"name\":\"$HANDLE\""*|*"\"name\": \"$HANDLE\""*) return 0;; *) return 1;; esac
  fi
}

# ════════════════════════════════════════════════════════════════════════════════
# PRINT
# ════════════════════════════════════════════════════════════════════════════════
if [ "$MODE" = "print" ]; then
  print_paste "STATION $CALLSIGN — open a terminal and paste this:"
  exit 0
fi

# ════════════════════════════════════════════════════════════════════════════════
# BACKGROUND — the default, and the only path with no host dependency at all
# ════════════════════════════════════════════════════════════════════════════════
if [ "$MODE" = "background" ]; then
  if ! command -v "$LAUNCH" >/dev/null 2>&1; then
    print_paste "CANNOT SPAWN — \`$LAUNCH\` is not on PATH here. Open a terminal and paste this:"
    exit 1
  fi
  # cwd is passed by launching from the worktree, so nothing depends on an inherited
  # directory and no `cd` is typed anywhere.
  OUT=$(cd "$WT" && "$LAUNCH" --bg --name "$HANDLE" "$PROMPT" 2>&1); RC=$?
  # `backgrounded · <id> · <NAME>` is the launch line. The id is what `attach`, `logs`
  # and `stop` take, so it is the single most useful thing to hand back.
  # Take the token after "backgrounded", whatever it is made of. The first version of
  # this matched [0-9a-f]{6,} because every real id observed was hex -- so it silently
  # returned nothing for anything else, and a missing id is not visible in the happy
  # path: the report still reads fine, just with `<id>` where attach/logs/stop needed
  # a value. Matching the SHAPE (a separator, then a token) rather than the alphabet
  # costs nothing and does not encode a guess about someone else's id format.
  SID=$(printf '%s\n' "$OUT" | sed -n 's/.*backgrounded[^A-Za-z0-9]*\([A-Za-z0-9]\{4,\}\).*/\1/p' | head -1)
  if [ $RC -ne 0 ]; then
    echo "$OUT"
    print_paste "BACKGROUND SPAWN FAILED (exit $RC). Open a terminal and paste this instead:"
    exit 1
  fi

  echo "STATION $CALLSIGN — started as a background agent${SID:+ · session $SID}"
  echo "  no terminal was opened, nothing was typed, and nothing took your focus."
  # A default nobody chose is not the same as a choice, and the difference is invisible
  # in the output unless it is said. Deploy is supposed to ask once and record the
  # answer; if that never happened, this is the line that shows the ask was skipped
  # rather than letting a silent default pass for a preference.
  [ -z "$UNRECORDED" ] || cat <<'TXT'
  MODE: background, by default — nobody has been asked on this machine yet.
        /mc deploy asks once and records it; spawn-pref.sh set <background|window>
        sets it directly, and spawn-pref.sh read shows what is recorded.
TXT
  if registered; then
    echo "REGISTERED · $HANDLE is live in the fleet manifest — addressable by call-sign now."
  else
    case $? in
      1) echo "NOT YET REGISTERED · the launch returned cleanly but $HANDLE is not in the"
         echo "   manifest yet. It registers a moment after start — re-read the manifest"
         echo "   before treating this as a failure, and read the board for the address." ;;
      *) echo "REGISTRATION UNVERIFIED · could not read \`$LAUNCH agents --json\`. The launch"
         echo "   returned cleanly; the manifest is the thing to check by hand." ;;
    esac
  fi
  # A background station has no window to show a permission prompt in. That is the one
  # real cost of dropping the terminal, so the commands that answer it are not an
  # afterthought at the bottom of the report -- they ARE the report's second half.
  echo
  echo "The station runs with the user's own permissions, so it can still stop at a prompt"
  echo "with no window to show it in. That is what these are for:"
  printf '  %-26s %s\n' "$LAUNCH logs ${SID:-<id>}"   "what it is showing right now"
  printf '  %-26s %s\n' "$LAUNCH attach ${SID:-<id>}" "take it over in this terminal, answer a prompt"
  printf '  %-26s %s\n' "$LAUNCH stop ${SID:-<id>}"   "stand it down"
  printf '  %-26s %s\n' "$LAUNCH agents"              "every station, background and interactive"
  cat <<TXT

NOT YET A MANNED POST. Verify by the BOARD: $CALLSIGN is on post when its row on the
base branch carries its fleet-manifest address, not when this printed.
TXT
  exit 0
fi

# ════════════════════════════════════════════════════════════════════════════════
# WINDOW — a visible session, using each terminal's OWN API. No synthesised keys.
# ════════════════════════════════════════════════════════════════════════════════
# ONE RECIPE PER HOST, AND EVERY ONE OF THEM IS AN API THE TERMINAL PUBLISHES. If a host
# has no such API, this does NOT fall back to driving its UI -- it falls back to
# background, which needs no host at all, and says so. **A missing recipe is not an
# error**, and it is no longer even a degradation.
window_unavailable() {   # $1 = why
  cat <<TXT
NO WINDOW RECIPE HERE — $1
Nothing was typed and no UI was driven; that is deliberate.

  Re-run without --window to start $CALLSIGN as a background agent (works everywhere),
  or open a terminal yourself and paste:

  $CMD
TXT
}

# 1. tmux, already inside one — the station lands in its own worktree directly, and this
#    is the one visible recipe that works on macOS, Linux, Windows (WSL) AND inside an
#    IDE's integrated terminal.
if [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
  if tmux new-window -c "$WT" -n "$CALLSIGN" "$CMD" 2>/dev/null; then
    echo "TMUX WINDOW OPENED · named $CALLSIGN · command dispatched"
    echo "NOT YET A STATION. Verify by the fleet manifest or the board — $CALLSIGN is on"
    echo "post when its row on the base branch carries its address, not when this printed."
    exit 0
  fi
  window_unavailable "tmux is running but refused to open a window"; exit 1
fi

# There is deliberately NO "tmux is installed but we are not inside it" recipe here.
# A detached tmux session is not a window -- `--window` is asked for by someone who
# wants to WATCH a station, and handing them something invisible answers a question
# they did not ask. Background mode already covers "start it without showing me", and
# covers it better: `claude --bg` is native, addressable, and attachable by id.

# 2. iTerm2 — a published AppleScript API. `create tab` is a real call, not a ⌘T.
if [ "${TERM_PROGRAM:-}" = "iTerm.app" ] && command -v osascript >/dev/null 2>&1; then
  # AppleScript literal escaping: BACKSLASH FIRST, then the double quote -- reversed,
  # the backslash pass would escape the backslashes the quote pass just added. $CMD is
  # built for a SHELL parser and then dropped into an APPLESCRIPT one; escaping for only
  # the first parser is how a worktree path containing `"` became live code (2026-08-23).
  as_lit() { local v="$1"; v=${v//\\/\\\\}; v=${v//\"/\\\"}; printf '%s' "$v"; }
  OUT=$(osascript <<AS 2>&1
tell application "iTerm"
  if (count of windows) = 0 then
    set w to (create window with default profile)
    set s to current session of w
  else
    tell current window
      set t to (create tab with default profile)
      set s to current session of t
    end tell
  end if
  tell s to write text "$(as_lit "$CMD")"
end tell
return "ok"
AS
)
  case "$OUT" in
    *ok*) echo "ITERM2 TAB OPENED · $CALLSIGN · command dispatched via iTerm's own API"
          echo "NOT YET A STATION. Verify by the manifest or the board."; exit 0 ;;
    *)    window_unavailable "iTerm2 refused: $OUT"; exit 1 ;;
  esac
fi

# 3. kitty / WezTerm — both ship a CLI for exactly this.
if [ -n "${KITTY_WINDOW_ID:-}" ] && command -v kitty >/dev/null 2>&1; then
  if kitty @ launch --type=tab --tab-title "$CALLSIGN" --cwd "$WT" \
       "$LAUNCH" --name "$HANDLE" "$PROMPT" >/dev/null 2>&1; then
    echo "KITTY TAB OPENED · $CALLSIGN"; echo "NOT YET A STATION. Verify by the manifest or the board."; exit 0
  fi
  window_unavailable "kitty refused (remote control may be off: \`allow_remote_control yes\`)"; exit 1
fi
if [ -n "${WEZTERM_PANE:-}" ] && command -v wezterm >/dev/null 2>&1; then
  if wezterm cli spawn --cwd "$WT" -- "$LAUNCH" --name "$HANDLE" "$PROMPT" >/dev/null 2>&1; then
    echo "WEZTERM TAB OPENED · $CALLSIGN"; echo "NOT YET A STATION. Verify by the manifest or the board."; exit 0
  fi
  window_unavailable "wezterm cli refused"; exit 1
fi

# 4. Windows Terminal.
if [ -n "${WT_SESSION:-}" ] && command -v wt.exe >/dev/null 2>&1; then
  if wt.exe -w 0 nt -d "$WT" cmd /k "$LAUNCH --name $HANDLE \"$PROMPT\"" 2>/dev/null; then
    echo "WT TAB OPENED · $CALLSIGN · command dispatched"
    echo "NOT YET A STATION, and this recipe is UNVERIFIED against a real Windows Terminal."
    echo "Verify by the board: $CALLSIGN is on post when its row carries its address."
    exit 0
  fi
  window_unavailable "Windows Terminal is running but \`wt\` refused to open a tab"; exit 1
fi

# 5. macOS Terminal.app — `do script` is Terminal's OWN API and opens a WINDOW.
#    A tab would need System Events to press ⌘T, which is the puppetry this script
#    removed; a window it can actually create is worth more than a tab it races for.
#    Say WINDOW, plainly: a window when someone pictured a tab is not a silent detail.
if [ "$(uname -s)" = "Darwin" ] && [ "${TERM_PROGRAM:-}" = "Apple_Terminal" ] && command -v osascript >/dev/null 2>&1; then
  as_lit() { local v="$1"; v=${v//\\/\\\\}; v=${v//\"/\\\"}; printf '%s' "$v"; }
  # ---- TAB MODE ---------------------------------------------------------------
  # Terminal.app publishes no scriptable new-tab (measured four ways, 2026-08-24), so a
  # native tab can only come from Terminal's own MENU. That is UI automation and it is
  # named as such -- but it is NOT the Cmd-T path that corrupted three deploys, and the
  # difference is exactly the two things that went wrong there:
  #
  #   THE MODIFIER RACE IS GONE. keystroke "t" using command down synthesises a CHORD,
  #   and a chord can lose its modifier -- that is how a bare t reached the shell and a
  #   station ran `tcd /path`. Clicking a menu item by name sends no chord at all.
  #
  #   THE "WHICH TAB" RACE IS GONE, and this is the one that did the damage. The old code
  #   wrote to `selected tab of window id N`, a reference resolved against a tab Cmd-T may
  #   not have finished creating -- which is how three launch commands ended up
  #   interleaved in Control's own prompt. This snapshots every tty BEFORE the click and
  #   waits for a tty that was not there before. The command goes to the tab we can PROVE
  #   is new, or it goes nowhere.
  #
  # What remains, said plainly rather than buried: this needs the Accessibility grant, and
  # the tab is born in whatever Terminal window is frontmost. We raise our own window
  # first through Terminal's real API, so that is normally ours -- but a human switching
  # windows mid-deploy can still land the tab elsewhere. Thanks to the tty diff that
  # yields a correct station in an unexpected window, never a corrupted one. Every failure
  # falls through to the window recipe; nothing is left half done.
  if [ "$MODE" = "tab" ]; then
    p=$$; MYTTY=""
    while [ "$p" -gt 1 ]; do
      t=$(ps -o tty= -p "$p" 2>/dev/null | tr -d ' ')
      if [ -n "$t" ] && [ "$t" != "??" ]; then MYTTY="/dev/$t"; break; fi
      p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
    done
    TAB_SRC=$(cat <<'ASEOF'
on allTtys()
  set acc to {}
  tell application "Terminal"
    repeat with w in windows
      repeat with t in tabs of w
        try
          set end of acc to (tty of t) as text
        end try
      end repeat
    end repeat
  end tell
  return acc
end allTtys

on isIn(v, lst)
  repeat with x in lst
    if (x as text) is v then return true
  end repeat
  return false
end isIn

on tabWithTty(theTty)
  tell application "Terminal"
    repeat with w in windows
      repeat with t in tabs of w
        try
          if ((tty of t) as text) is theTty then return t
        end try
      end repeat
    end repeat
  end tell
  return missing value
end tabWithTty

set myWin to 0
tell application "Terminal"
  repeat with w in windows
    repeat with t in tabs of w
      try
        if ((tty of t) as text) is "__MYTTY__" then set myWin to (id of w)
      end try
    end repeat
  end repeat
end tell

set beforeList to my allTtys()

tell application "Terminal" to activate
if myWin is not 0 then
  try
    tell application "Terminal" to set frontmost of window id myWin to true
  end try
end if
delay 0.4

-- Terminal own menu item. Located by name where possible and by position otherwise:
-- the visible name carries the default profile and is localised, while item 1 of that
-- submenu is the Cmd-T equivalent on every machine.
try
  tell application "System Events"
    tell process "Terminal"
      set shellMenu to menu 1 of menu bar item "Shell" of menu bar 1
      -- "New Tab" IS ADDRESSED BY NAME, and the first version of this did not do that.
      -- It used `menu item 1`, which is "New Window" -- the Shell menu lists New Window
      -- above New Tab -- and then matched "Profile" inside THAT submenu, so it clicked
      -- "New Window with Profile" and produced exactly the window tab mode exists to
      -- avoid. Caught 2026-08-24 by reading back which item was clicked instead of
      -- assuming the click did what it was for.
      set tabItem to missing value
      repeat with mi in menu items of shellMenu
        try
          if (name of mi) is "New Tab" then
            set tabItem to mi
            exit repeat
          end if
        end try
      end repeat
      if tabItem is missing value then return "NOTAB: no \"New Tab\" item in the Shell menu"
      set sub to menu 1 of tabItem
      set target to missing value
      repeat with mi in menu items of sub
        try
          if (name of mi) contains "Profile" then
            set target to mi
            exit repeat
          end if
        end try
      end repeat
      if target is missing value then set target to menu item 1 of sub
      click target
    end tell
  end tell
on error errMsg number errNum
  return "NOACCESS: " & errNum & " " & errMsg
end try

-- Wait for a tty that was not there before. THIS is what makes the new tab identifiable.
set newTty to ""
repeat 50 times
  delay 0.1
  repeat with c in (my allTtys())
    if not (my isIn((c as text), beforeList)) then
      set newTty to (c as text)
      exit repeat
    end if
  end repeat
  if newTty is not "" then exit repeat
end repeat
if newTty is "" then return "NOTAB: the menu item was clicked but no new tty appeared"

set theTab to my tabWithTty(newTty)
if theTab is missing value then return "NOTAB: the new tty vanished before it could be used"

tell application "Terminal" to do script "__CMD__" in theTab

delay 4
set procs to ""
try
  tell application "Terminal" to set procs to (processes of theTab) as string
end try
if procs contains "claude" then
  return "TABOK " & newTty
else
  return "FAILED: no claude process in the new tab (tty " & newTty & ")"
end if
ASEOF
)
    TAB_SRC=${TAB_SRC//__MYTTY__/$(as_lit "${MYTTY:-/dev/null}")}
    TAB_SRC=${TAB_SRC//__CMD__/$(as_lit "$CMD")}
    OUT=$(printf '%s' "$TAB_SRC" | osascript - 2>&1)
    case "$OUT" in
      TABOK*)
        echo "TERMINAL TAB OPENED - $CALLSIGN - ${OUT#TABOK }"
        echo "  Created through the Shell > New Tab menu item, and the command was written to"
        echo "  the tab identified by a NEW tty. Never to selected tab, which is the reference"
        echo "  that corrupted three deploys on 2026-08-23."
        echo "NOT YET A STATION. Verify by the manifest or the board."
        exit 0 ;;
      NOACCESS*)
        echo "TAB MODE NEEDS THE ACCESSIBILITY GRANT - falling back to a window."
        echo "  $OUT"
        echo "  System Settings > Privacy and Security > Accessibility > enable Terminal."
        echo "  Terminal.app publishes no scriptable new-tab, so a tab can only come from its"
        echo "  own menu, and clicking a menu is what that grant covers. Background mode needs"
        echo "  no grant at all." ;;
      NOTAB*|FAILED*)
        echo "TAB MODE DID NOT COMPLETE - falling back to a window."
        echo "  $OUT" ;;
    esac
  fi


  # Fed on STDIN rather than with -e, and that is not a style choice: the escaping
  # regression test captures what reaches osascript by reading its stdin. A recipe that
  # passes the script as an argv string is invisible to that instrument, so the test
  # that proves a `"` in a worktree path cannot close the AppleScript literal would
  # quietly downgrade to a SKIP while the hole it guards stayed open.
  OUT=$(printf 'tell application "Terminal" to do script "%s"\n' "$(as_lit "$CMD")" | osascript - 2>&1)
  if [ $? -eq 0 ]; then
    echo "TERMINAL WINDOW OPENED · $CALLSIGN · via \`do script\`, no keystrokes synthesised"
    echo "  It is a WINDOW, not a tab. Terminal.app publishes no scriptable new-tab; the"
    echo "  ⌘T path that used to fake one is what corrupted three deploys on 2026-08-23."
    echo "NOT YET A STATION. Verify by the manifest or the board."
    exit 0
  fi
  window_unavailable "Terminal.app refused: $OUT"; exit 1
fi

# 6. Linux terminals that take a command directly.
for t in gnome-terminal konsole xfce4-terminal alacritty ghostty xterm; do
  command -v "$t" >/dev/null 2>&1 || continue
  case "$t" in
    gnome-terminal) gnome-terminal --working-directory="$WT" -- bash -lc "$CMD; exec bash" >/dev/null 2>&1 ;;
    konsole)        konsole --workdir "$WT" -e bash -lc "$CMD; exec bash" >/dev/null 2>&1 & ;;
    xfce4-terminal) xfce4-terminal --working-directory="$WT" -e "bash -lc '$CMD; exec bash'" >/dev/null 2>&1 & ;;
    alacritty)      alacritty --working-directory "$WT" -e bash -lc "$CMD; exec bash" >/dev/null 2>&1 & ;;
    ghostty)        ghostty --working-directory="$WT" -e bash -lc "$CMD; exec bash" >/dev/null 2>&1 & ;;
    xterm)          xterm -e bash -lc "cd '$Q_WT' && $CMD; exec bash" >/dev/null 2>&1 & ;;
  esac
  if [ $? -eq 0 ]; then
    echo "$t WINDOW OPENED · $CALLSIGN"
    echo "NOT YET A STATION, and this recipe is UNVERIFIED against a real $t."
    echo "Verify by the manifest or the board."
    exit 0
  fi
done

# 7. An IDE's integrated terminal, or anything unrecognised. There is no API here and
#    inventing one is what this rewrite exists to stop.
window_unavailable "no published window API for this host ($(uname -s)${TERM_PROGRAM:+, $TERM_PROGRAM}). IDE terminals — VS Code, Cursor, Windsurf, JetBrains — cannot be driven from outside, and background mode does not need to be."
exit 0     # not a failure: background works here, and the paste-able line is above
