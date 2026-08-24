#!/bin/bash
# test/e2e.sh — end-to-end flow test for the mission-control skill.
#
#   bash test/e2e.sh              # test this repo's copy
#   bash test/e2e.sh ~/.claude/skills/mission-control   # test what is INSTALLED
#
# Tests the flow a new adopter actually walks: a fresh repo with nothing set up, a
# board appearing, a project naming its own board and coordinator, a station inside a
# worktree, deploy on every host, every input guard, and the identity surfaces.
#
# WHY IT EXISTS: 6.33.1 shipped a script that passed `bash -n` and died on its first
# real run, because a syntax check is not a smoke test. Everything here EXECUTES.
#
# It creates throwaway git repos in $TMPDIR and removes them. It never writes to your
# board, never opens a terminal, never relabels a tab, and never renames a live session.
# osascript is stubbed suite-wide, because the tab test used to drive the REAL one at a
# live tty and relabelled the tester's own tab (caught in the field, 6.52.0). The rename
# tests build a session registry under a fake $HOME rather than borrowing the real one:
# a test that mutates live state to prove a point is worse than an untested line, and
# one that merely reads live state is flaky in a quieter way -- it drew the tester's own
# session out of the registry and failed on it (6.51.0).
set -uo pipefail

D="${1:-$(cd "$(dirname "$0")/../skills/mission-control" && pwd)}"
[ -f "$D/mc-init.sh" ] || { echo "no mission-control skill at: $D" >&2; exit 2; }
command -v git >/dev/null || { echo "git is required" >&2; exit 2; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 2; }

PASS=0; FAIL=0; SKIP=0
if [ -t 1 ]; then G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; Z=$'\033[0m'; else G=; R=; Y=; Z=; fi
# readonly on purpose: these are one-letter names in a long script, and a later test
# reusing one as scratch silently blanks every FAIL colour after it -- which is exactly
# how a mangled "OLDNAME None FAIL" line got shipped past a green run (6.51.0). A
# clobber now says so on stderr instead of quietly eating the output.
readonly G R Y Z
ok(){ printf '  %sPASS%s  %s\n' "$G" "$Z" "$1"; PASS=$((PASS+1)); }
no(){ printf '  %sFAIL%s  %s\n        got: %s\n' "$R" "$Z" "$1" "$(printf '%s' "$2" | head -2 | tr '\n' ' ')"; FAIL=$((FAIL+1)); }
sk(){ printf '  %sSKIP%s  %s\n' "$Y" "$Z" "$1"; SKIP=$((SKIP+1)); }
chk(){ case "$2" in *"$3"*) ok "$1";; *) no "$1" "$2";; esac; }

WORK=$(mktemp -d); trap 'cd /; rm -rf "$WORK"' EXIT
# SUITE-WIDE, LIKE THE osascript STUB, AND FOR THE SAME REASON. spawn-station.sh records
# which mode each deploy opened, and it defaults to ~/.claude/mission-control-spawns.json
# -- the tester's REAL one. Every --deploy test below wrote into it until this line
# existed, including the AppleScript-injection fixtures, whose repo paths then sat in a
# live config file on the machine. Caught in the field on 2026-08-24, one release after
# the recording shipped. A suite that writes to $HOME is not a suite, it is a side effect.
export MC_SPAWNLOG="$WORK/spawns.json"
STUB="$WORK/stub"; mkdir -p "$STUB"
for b in tmux wt.exe; do
  printf '#!/bin/bash\nexit ${STUB_RC:-0}\n' > "$STUB/$b"; chmod +x "$STUB/$b"
done
# osascript is stubbed for the WHOLE suite, not just the tab tests. Every label-tab.sh
# call below is supposed to be refused by a guard before it reaches a real tab -- but
# that is guard ORDERING, and ordering is exactly what regresses. With the stub on PATH
# the suite cannot relabel a tester's tab even if a guard moves below the osascript.
cat > "$STUB/osascript" <<'OSA'
#!/bin/bash
if [ -n "${STUB_OSA_CAPTURE:-}" ]; then cat > "$STUB_OSA_CAPTURE"; else cat >/dev/null; fi
if [ -n "${STUB_OSA_NOMATCH:-}" ]; then
  echo "NO-MATCH for ${STUB_TTY:-/dev/ttys999}"
else
  echo "${STUB_TTY:-/dev/ttys999} -> ${STUB_OSA_TITLE:-MCTEST}"
fi
OSA
chmod +x "$STUB/osascript"

# claude is stubbed for the WHOLE suite, and this is the most important stub in it.
# spawn-station.sh's DEFAULT mode starts a real background session. When that landed
# (6.78.0) the suite's first run spawned five real ones -- four BACKENDs and one in the
# AppleScript-injection worktree -- which then had to be hunted down with `claude stop`.
# A suite that bills the person running it is worse than an untested line, and gating
# that on remembering to prefix PATH per-call is the same ordering bug the osascript
# stub exists to rule out. So the stub goes on PATH for everything, below.
#
# It behaves like a small registry rather than a fixed echo: a --bg launch records the
# name it was given, and `agents --json` reads it back. That way the "did it register"
# branch is exercised against something that can actually be wrong.
cat > "$STUB/claude" <<'CLA'
#!/bin/bash
REG="${STUB_CLAUDE_REG:-/dev/null}"
if [ "$1" = "agents" ]; then
  [ "${STUB_CLAUDE_AGENTS_RC:-0}" = "0" ] || exit "${STUB_CLAUDE_AGENTS_RC}"
  [ "${STUB_CLAUDE_REGISTERED:-1}" = "1" ] || { echo '[]'; exit 0; }
  printf '['
  sep=""
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    printf '%s{"id":"a1b2c3d4","name":"%s","status":"idle","kind":"background"}' "$sep" "$n"
    sep=","
  done < "$REG" 2>/dev/null
  printf ']
'
  exit ${STUB_CLAUDE_AGENTS_RC:-0}
fi
name=""; prev=""
for a in "$@"; do [ "$prev" = "--name" ] && name="$a"; prev="$a"; done
if [ "${STUB_CLAUDE_RC:-0}" != "0" ]; then echo "stub: refusing to launch" >&2; exit "${STUB_CLAUDE_RC}"; fi
[ "$REG" = /dev/null ] || printf '%s\n' "$name" >> "$REG"
echo "backgrounded · a1b2c3d4 · $name"
exit 0
CLA
chmod +x "$STUB/claude"
# Suite-wide, for the reason argued above. Individual tests still set STUB_* knobs.
export PATH="$STUB:$PATH"
export STUB_CLAUDE_REG="$WORK/claude.registry"; : > "$STUB_CLAUDE_REG"

# THE TESTER'S OWN PREFERENCES ARE NOT PART OF THE FIXTURE. spawn-station.sh reads
# ~/.claude/mission-control.json for spawn.mode, so without this the suite's results
# depend on what the person running it happens to have chosen -- and 6.79.0's own tests
# went red on a machine whose real config said `window`, reporting a dozen failures in
# background mode that had nothing to do with the code under test.
#
# That is the SAME defect this file's header already describes for the session registry:
# "one that merely reads live state is flaky in a quieter way". It was fixed there by
# building a fixture instead of borrowing one, and this is the same fix for the other
# live file. MC_CONFIG points at a path that does not exist -- the state of a machine
# nobody has been asked on -- and any test wanting a real config sets MC_CONFIG itself.
export MC_CONFIG="$WORK/no-such-preferences.json"

# AND THE SAME FOR THE ENV OVERRIDE, WHICH IS THE SECOND DOOR INTO THE SAME ROOM.
# spawn.mode can also come from env.MC_SPAWN_MODE in ~/.claude/settings.json, which
# Claude Code injects into every session -- including the one running this suite. Pinning
# only MC_CONFIG left that door open, and on a machine set to `tab` the suite inherited it
# and drove Terminal's Shell > New Tab MENU FOR REAL, once per deploy test, while
# reporting eighteen unrelated failures in background mode.
#
# That is worse than the MC_CONFIG version of this bug: it does not merely read live user
# state, it ACTS on the user's UI from inside a test run. The suite's header promises it
# never opens a terminal.
#
# The lesson generalises past both variables: EVERY input the code reads from the
# environment is a fixture the suite has to own. When spawn-station.sh gained a second
# source of truth, the suite gained a second thing to pin, and nothing prompted that.
export MC_SPAWN_MODE=""

newrepo(){ local r; r=$(mktemp -d "$WORK/repo.XXXXXX"); cd "$r"
  git init -q; git config user.email t@example.com; git config user.name t
  mkdir -p docs; echo init > README.md; git add -A; git commit -qm init
  git branch -M main >/dev/null 2>&1; git update-ref refs/remotes/origin/main HEAD; printf '%s' "$r"; }

echo "mission-control end-to-end · skill under test: $D"
echo
echo "── 1. a brand new project, nothing set up ─────────────────────────"
# `newrepo` runs in a subshell, so its own cd cannot reach us -- cd here or every
# section below writes into whatever repo the test was launched from. (It did.)
REPO=$(newrepo); cd "$REPO" || exit 1
O=$(bash "$D/mc-init.sh" 2>&1)
chk "reports no board rather than inventing one" "$O" "BOARD: none"
chk "reports no rules"                           "$O" "RULES: none"
chk "coordinator falls back to CONTROL"          "$O" "COORDINATOR: CONTROL"
chk "repo root detected"                         "$O" "REPO: $(basename "$REPO")"

echo
echo "── 2. after a board exists ────────────────────────────────────────"
printf '| station | status |\n|---|---|\n| CONTROL | on watch |\n' > docs/WORK-LOCKS.md
git add -A; git commit -qm board; git update-ref refs/remotes/origin/main HEAD
O=$(bash "$D/mc-init.sh" 2>&1)
chk "board found in a common location"  "$O" "BOARD: docs/WORK-LOCKS.md"
chk "board measured at origin/main"     "$O" "BOARD_BYTES:"

echo
echo "── 3. a project that names its own board and coordinator ──────────"
printf 'Board: docs/claims.md\nCoordinator: HQ\n' > docs/MISSION-CONTROL.md
printf '| x |\n' > docs/claims.md
git add -A; git commit -qm rules; git update-ref refs/remotes/origin/main HEAD
O=$(bash "$D/mc-init.sh" 2>&1)
chk "explicit Board: declaration wins"          "$O" "BOARD: docs/claims.md"
chk "coordinator can be any word the board says" "$O" "COORDINATOR: HQ"

echo
echo "── 4. a station inside its own worktree ───────────────────────────"
git worktree add -q --detach "$REPO/.claude/worktrees/backend" HEAD 2>/dev/null
O=$(cd "$REPO/.claude/worktrees/backend" && bash "$D/mc-init.sh" 2>&1)
chk "preamble runs from inside a worktree"   "$O" "COORDINATOR: HQ"
chk "worktree resolves the same board"       "$O" "BOARD: docs/claims.md"

echo
echo "── 4b. repositories that are not on 'main' ────────────────────────"
altrepo(){ local br="$1" rem="$2" r; r=$(mktemp -d "$WORK/alt.XXXXXX"); cd "$r"
  git init -q -b "$br" 2>/dev/null || { git init -q; git checkout -qb "$br"; }
  git config user.email t@example.com; git config user.name t
  mkdir -p docs; printf '| x |\n' > docs/WORK-LOCKS.md; git add -A; git commit -qm init
  [ -n "$rem" ] && { git remote add "$rem" "$r"; git update-ref "refs/remotes/$rem/$br" HEAD; }
  printf '%s' "$r"; }
for spec in "master origin" "trunk origin" "develop origin" "main upstream"; do
  set -- $spec; A=$(altrepo "$1" "$2"); cd "$A"
  O=$(bash "$D/mc-init.sh" 2>&1)
  chk "board found on $1 via $2" "$O" "BOARD: docs/WORK-LOCKS.md"
  chk "base ref resolves to $2/$1" "$O" "BASE_REF: $2/$1"
done
A=$(altrepo main ""); cd "$A"; O=$(bash "$D/mc-init.sh" 2>&1)
chk "board found with NO remote"          "$O" "BOARD: docs/WORK-LOCKS.md"
chk "no-remote is flagged, not silent"    "$O" "NO REMOTE"
cd "$REPO"

echo
echo "── 5. deploy, on every host ───────────────────────────────────────"
# 6.78.0 replaced the ⌘T keystroke path with `claude --bg`. These tests pin the two
# properties the old path could not hold: nothing is typed, and nothing is claimed
# that was not read back.
chk "print path yields a paste-able launch line" \
    "$(bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --print 2>&1)" \
    "claude --name 'BACKEND' '/mc identify BACKEND'"

# THE ANTI-PUPPETRY ASSERTION, AND ITS BOUNDARY. A source test on purpose: every field
# failure this rewrite answers came from SYNTHESISING A KEYPRESS, and the cheapest way
# for that to return is somebody restoring the old tab recipe.
#
# The invariant is "no synthesised keystroke", NOT "never touch System Events" -- and the
# difference is load-bearing now that tab mode exists. A CHORD is what failed: `keystroke
# "t" using command down` can lose its modifier, and the bare `t` then reaches the shell
# (`tcd /path`, 2026-08-17). Clicking a NAMED MENU ITEM sends no chord, cannot half-fire,
# and is addressed to Terminal's own menu bar rather than to whatever holds focus.
#
# So: keystroke synthesis is banned outright; a named menu click is allowed and is
# asserted to be the only System Events call present. Widening this to ban System Events
# entirely would have been easier to write and would have banned the safe thing along
# with the dangerous one.
SRC=$(grep -vE '^\s*#|^\s*--' "$D/spawn-station.sh" | grep -vE '^\s*echo|^\s*cat <<|^[A-Z ]+·' || true)
case "$SRC" in
  *"keystroke"*|*"key code"*|*"key down"*) no "no keystroke is ever synthesised" "an executable line still synthesises keys" ;;
  *) ok "no keystroke is ever synthesised" ;;
esac
# ...and if System Events is used at all, it may only be to click a named menu item.
case "$SRC" in
  *"System Events"*)
    case "$SRC" in
      *"click target"*|*"click menu item"*) ok "System Events is used only to click a named menu item" ;;
      *) no "System Events is used only to click a named menu item" "System Events used for something other than a menu click" ;;
    esac ;;
  *) ok "System Events is used only to click a named menu item" ;;
esac

O=$(bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --deploy 2>&1)
chk "background is the default with no flag"  "$O" "started as a background agent"
chk "it says nothing took the user's focus"   "$O" "nothing took your focus"
chk "the session id is handed back"           "$O" "session a1b2c3d4"
chk "registration is READ BACK, not assumed"  "$O" "REGISTERED"
chk "it never claims a manned post"           "$O" "NOT YET A MANNED POST"
chk "the human gets attach"                   "$O" "claude attach a1b2c3d4"
chk "the human gets logs"                     "$O" "claude logs a1b2c3d4"
chk "the human gets stop"                     "$O" "claude stop a1b2c3d4"

# A launch that returns cleanly while the manifest does not show it is the exact shape
# of the 2026-08-18 "spawned but never registered" failure. It must be SAID, not implied.
O=$(STUB_CLAUDE_REGISTERED=0 bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --deploy 2>&1)
chk "an unregistered station is reported"      "$O" "NOT YET REGISTERED"
# Anchored at line start ON PURPOSE. A substring test for "REGISTERED ·" also matches
# "NOT YET REGISTERED ·" -- the very string this is meant to accept -- so the check
# failed against correct output and would have passed against silence.
if printf '%s\n' "$O" | grep -q '^REGISTERED ·'; then
  no "it does not claim registration it lacks" "claimed REGISTERED"
else ok "it does not claim registration it lacks"; fi

# Cannot read the manifest at all is a THIRD state, and it must not borrow either of the
# other two's confidence: the launch did return cleanly, and we still do not know.
O=$(STUB_CLAUDE_AGENTS_RC=3 bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --deploy 2>&1)
chk "an unreadable manifest is its own answer" "$O" "REGISTRATION UNVERIFIED"

# A refused launch must still leave the human something to run.
O=$(STUB_CLAUDE_RC=1 bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --deploy 2>&1); RC=$?
chk "a refused launch says so"                 "$O" "BACKGROUND SPAWN FAILED"
chk "and still prints the paste-able line"     "$O" "claude --name 'BACKEND'"
[ $RC -ne 0 ] && ok "a refused launch is an error (non-zero)" || no "a refused launch is an error" "exit 0"

# --window, and every recipe in it is an API the terminal publishes.
O=$(TMUX="x,1,0" bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --window --deploy 2>&1)
chk "tmux opens a window"                      "$O" "TMUX WINDOW OPENED"
chk "tmux does not claim a station"            "$O" "NOT YET A STATION"
O=$(STUB_RC=1 TMUX="x,1,0" bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --window --deploy 2>&1)
chk "tmux refusing is reported"                "$O" "NO WINDOW RECIPE HERE"
O=$(WT_SESSION=1 bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --window --deploy 2>&1)
chk "windows terminal opens a tab"             "$O" "WT TAB OPENED"
chk "windows recipe admits it is unverified"   "$O" "UNVERIFIED"
O=$(TERM_PROGRAM=Apple_Terminal bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --window --deploy 2>&1)
chk "Terminal.app uses do script, not a tab"   "$O" "TERMINAL WINDOW OPENED"
chk "and says WINDOW rather than implying tab" "$O" "It is a WINDOW, not a tab"

# An IDE terminal cannot be driven from outside, and the point of 6.78.0 is that it no
# longer has to be: --window declines, and declining is not a failure.
O=$(TERM_PROGRAM=vscode bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --window --deploy 2>&1); RC=$?
chk "an IDE terminal declines rather than guessing" "$O" "NO WINDOW RECIPE HERE"
chk "it names background as the way through"        "$O" "background agent"
[ $RC -eq 0 ] && ok "no window recipe is not an error (exit 0)" || no "no window recipe is not an error" "exit $RC"
# ...and the same host still deploys, because background needs no host at all.
O=$(TERM_PROGRAM=vscode bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --deploy 2>&1)
chk "the SAME IDE host still deploys in background" "$O" "started as a background agent"

echo
echo "── 5b. the recorded preference, and its guards ────────────────────"
CFGD="$WORK/cfg"; mkdir -p "$CFGD"
printf '{"spawn":{"mode":"print"}}' > "$CFGD/mc.json"
O=$(MC_CONFIG="$CFGD/mc.json" bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --deploy 2>&1)
chk "a recorded mode is honoured"          "$O" "open a terminal and paste this"
O=$(MC_CONFIG="$CFGD/mc.json" bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --background --deploy 2>&1)
chk "an explicit flag beats the config"    "$O" "started as a background agent"
# A launchCommand out of a config file reaches a command line. Same allowlist reasoning
# as the call-sign, applied to the input nobody thought of as dangerous.
printf '{"spawn":{"launchCommand":"claude; touch %s/PWNED"}}' "$CFGD" > "$CFGD/evil.json"
O=$(MC_CONFIG="$CFGD/evil.json" bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --deploy 2>&1)
[ -e "$CFGD/PWNED" ] && no "a booby-trapped launchCommand is refused" "it executed" || ok "a booby-trapped launchCommand is refused"
printf 'not json at all' > "$CFGD/bad.json"
O=$(MC_CONFIG="$CFGD/bad.json" bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --deploy 2>&1)
chk "an unreadable config is a preference nobody expressed" "$O" "started as a background agent"
O=$(MC_CONFIG="$CFGD/nothing-here.json" bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --deploy 2>&1)
chk "a missing config is not an error"     "$O" "started as a background agent"

echo "── 5f. tab mode, and the setting that selects it ──────────────────"
# tab mode is the one recipe that touches the UI, so its BOUNDARY is what gets pinned:
# a named menu click, never a chord, and a fallback whenever it cannot finish.
SRC=$(cat "$D/spawn-station.sh")
case "$SRC" in
  *'is "New Tab"'*) ok "the New Tab item is addressed BY NAME" ;;
  *) no "the New Tab item is addressed BY NAME" "not found" ;;
esac
# Index 1 of the Shell menu is "New Window". The first version of tab mode used it and
# clicked "New Window with Profile" -- producing precisely the window tab mode exists to
# avoid, while reporting success. Caught 2026-08-24 by reading back WHICH item was
# clicked rather than trusting that a click had happened.
case "$SRC" in
  *'menu 1 of menu item 1 of menu 1 of menu bar item "Shell"'*)
    no "it does not click Shell menu item 1 (that is New Window)" "index-1 path is back" ;;
  *) ok "it does not click Shell menu item 1 (that is New Window)" ;;
esac
# The command must go to the tab proven new, never to "selected tab" -- the reference
# that let three launch commands interleave into Control's own prompt.
case "$SRC" in
  *"do script \"__CMD__\" in theTab"*) ok "the command targets the tab found by tty diff" ;;
  *) no "the command targets the tab found by tty diff" "not found" ;;
esac
# Comments are STRIPPED for this one. The prose above the recipe explains at length what
# `selected tab of window id N` did wrong, so a test that greps the raw file finds the
# warning and reports it as the defect -- which it did on first run. The rule is about
# executable lines, so the check has to look at executable lines.
CODE=$(grep -vE '^\s*#|^\s*--' "$D/spawn-station.sh" || true)
case "$CODE" in
  *"selected tab of window id"*) no "selected tab is never written to again" "selected tab reference is back" ;;
  *) ok "selected tab is never written to again" ;;
esac
# Missing Accessibility must degrade, not fail: the grant is real and not everyone has it.
case "$SRC" in
  *"NOACCESS"*) ok "a missing Accessibility grant falls back rather than failing" ;;
  *) no "a missing Accessibility grant falls back rather than failing" "no NOACCESS branch" ;;
esac

# The mode can be selected from Claude Code's own settings.json via env.
O=$(MC_CONFIG=/nonexistent MC_SPAWN_MODE=print bash "$D/spawn-station.sh" B "$REPO" B --deploy 2>&1)
chk "MC_SPAWN_MODE selects the mode"        "$O" "open a terminal and paste this"
O=$(MC_CONFIG=/nonexistent MC_SPAWN_MODE=print bash "$D/spawn-station.sh" B "$REPO" B --background --deploy 2>&1)
chk "an explicit flag still beats the env"  "$O" "started as a background agent"
# A junk value must be reported, not silently treated as a choice.
O=$(MC_CONFIG=/nonexistent MC_SPAWN_MODE=sideways bash "$D/spawn-station.sh" B "$REPO" B --deploy 2>&1)
chk "a junk MC_SPAWN_MODE is reported"      "$O" "is not one of default|tab|window|background|print"
chk "and it falls back to the default"      "$O" "started as a background agent"
# The recorded preference file must accept tab too, or the two surfaces disagree.
PT="$WORK/tabpref.json"
MC_CONFIG="$PT" bash "$D/spawn-pref.sh" set tab >/dev/null 2>&1
chk "tab is a recordable preference"        "$(MC_CONFIG="$PT" bash "$D/spawn-pref.sh" read 2>&1)" "SPAWN: tab"
chk "and mc-config offers it"               "$(MC_CONFIG="$PT" bash "$D/mc-config.sh" keys 2>&1)" "background | window | tab"

echo "── 5g. Default is a CHOICE, not the absence of one ────────────────"
# Three states, and the middle one is why this exists: absent means nobody was asked and
# the next deploy asks; "default" means they WERE asked and chose to track whatever the
# tool's default is rather than pin a mode. Both deploy the same way today, so collapsing
# them looks harmless -- and then it either nags someone who already answered, or silently
# pins a value they never chose.
DP="$WORK/defpref.json"
chk "never asked reads unset"        "$(MC_CONFIG="$DP" bash "$D/spawn-pref.sh" read 2>&1)" "SPAWN: unset"
MC_CONFIG="$DP" bash "$D/spawn-pref.sh" set default >/dev/null 2>&1
chk "default is recordable"          "$(MC_CONFIG="$DP" bash "$D/spawn-pref.sh" read 2>&1)" "SPAWN: default"
O=$(MC_CONFIG="$DP" bash "$D/spawn-station.sh" B "$REPO" B --deploy 2>&1)
chk "default deploys in background"  "$O" "started as a background agent"
case "$O" in
  *"nobody has been asked"*) no "and a recorded default is not nagged" "still nagged" ;;
  *) ok "and a recorded default is not nagged" ;;
esac
chk "show renders it as a value"     "$(MC_CONFIG="$DP" bash "$D/mc-config.sh" show 2>&1)" "Default → background"
chk "and mc-config offers it"        "$(MC_CONFIG="$DP" bash "$D/mc-config.sh" keys 2>&1)" "default | background | window | tab"
chk "the env var accepts it too"     "$(MC_CONFIG=/nonexistent MC_SPAWN_MODE=default bash "$D/spawn-station.sh" B "$REPO" B --deploy 2>&1)" "started as a background agent"

echo "── 5h. once vs always ─────────────────────────────────────────────"
# "Just the next deploy" is a SEPARATE key, never a temporary value of spawn.mode.
# Overwriting the standing preference and restoring it afterwards means a crash, a closed
# window or a failed spawn leaves the temporary value looking permanent -- the user asked
# for one deploy and silently acquired a new default.
OP="$WORK/oncepref.json"
MC_CONFIG="$OP" bash "$D/spawn-pref.sh" set background >/dev/null 2>&1
MC_CONFIG="$OP" bash "$D/spawn-pref.sh" once window >/dev/null 2>&1
chk "a pending one-shot is reported"    "$(MC_CONFIG="$OP" bash "$D/spawn-pref.sh" read 2>&1)" "ONCE: window"
chk "and mc-config shows it"            "$(MC_CONFIG="$OP" bash "$D/mc-config.sh" show 2>&1)" "PENDING ONE-SHOT"
chk "the standing preference survives"  "$(MC_CONFIG="$OP" bash "$D/spawn-pref.sh" read 2>&1)" "SPAWN: background"
# --print starts nothing, so it must not consume the one-shot.
MC_CONFIG="$OP" bash "$D/spawn-station.sh" B "$REPO" B --print >/dev/null 2>&1
chk "--print does not consume it"       "$(MC_CONFIG="$OP" bash "$D/spawn-pref.sh" read 2>&1)" "ONCE: window"
# Neither does a call with no --deploy: it starts nothing either.
MC_CONFIG="$OP" bash "$D/spawn-station.sh" B "$REPO" B >/dev/null 2>&1
chk "no --deploy does not consume it"   "$(MC_CONFIG="$OP" bash "$D/spawn-pref.sh" read 2>&1)" "ONCE: window"
O=$(MC_CONFIG="$OP" TERM_PROGRAM=vscode bash "$D/spawn-station.sh" B "$REPO" B --deploy 2>&1)
chk "a deploy uses it"                  "$O" "ONE-SHOT: window"
chk "and says it is now cleared"        "$O" "now cleared"
chk "and names the flag for siblings"   "$O" "Pass --window to the others"
case "$(MC_CONFIG="$OP" bash "$D/spawn-pref.sh" read 2>&1)" in
  *"ONCE:"*) no "it is consumed exactly once" "still pending" ;;
  *) ok "it is consumed exactly once" ;;
esac
chk "the next deploy is back to standing" "$(MC_CONFIG="$OP" bash "$D/spawn-station.sh" B "$REPO" B --deploy 2>&1)" "started as a background agent"
chk "and the standing preference is untouched" "$(MC_CONFIG="$OP" bash "$D/spawn-pref.sh" read 2>&1)" "SPAWN: background"
# An explicit flag is the more specific instruction and still wins over a pending one-shot.
MC_CONFIG="$OP" bash "$D/spawn-pref.sh" once window >/dev/null 2>&1
chk "an explicit flag beats a one-shot" "$(MC_CONFIG="$OP" bash "$D/spawn-station.sh" B "$REPO" B --background --deploy 2>&1)" "started as a background agent"
chk "a bogus one-shot is refused"       "$(MC_CONFIG="$OP" bash "$D/spawn-pref.sh" once sideways 2>&1)" "usage:"

echo "── 5i. the first-run contract ─────────────────────────────────────"
# The picker is built from `mc-config.sh keys`, so the ORDER there is the order the user
# sees. Default must come first and be the recommended answer: a first preference nobody
# changed should be "follow the tool's default", not a mode they were nudged into pinning.
chk "Default is the first option offered" "$(bash "$D/mc-config.sh" keys 2>&1 | head -1)" "default | background | window | tab"
# And recording `default` must COUNT AS ANSWERED. If it left the key absent, the tour would
# ask, record nothing, and the first deploy would ask the same question again.
FR="$WORK/firstrun.json"
chk "before the ask, nobody has been asked" "$(MC_CONFIG="$FR" bash "$D/spawn-pref.sh" read 2>&1)" "SPAWN: unset"
MC_CONFIG="$FR" bash "$D/mc-config.sh" set spawn.mode default >/dev/null 2>&1
chk "choosing Default records an answer"    "$(MC_CONFIG="$FR" bash "$D/spawn-pref.sh" read 2>&1)" "SPAWN: default"
case "$(MC_CONFIG="$FR" bash "$D/spawn-station.sh" B "$REPO" B --deploy 2>&1)" in
  *"nobody has been asked"*) no "so no later deploy asks again" "asked a second time" ;;
  *) ok "so no later deploy asks again" ;;
esac

echo "── 5j. the preamble does not pay for the network twice ────────────"
# MEASURED 2026-08-24: mc-init.sh was 1.4s and `git fetch` was 1.12s of it -- a network
# round trip on EVERY /mc, including several in a row while nothing upstream moved.
# The window is a trade, so it must be VISIBLE: this script already argues that a silent
# failed fetch is worse than a loud one "because one of them looks trustworthy", and a
# silent skip is that same defect.
FR2=$(newrepo); cd "$FR2"
touch "$(git rev-parse --git-common-dir)/FETCH_HEAD"
O=$(bash "$D/mc-init.sh" 2>&1)
chk "a fresh fetch is skipped, and said so"  "$O" "FETCH: skipped"
chk "it names the age and the window"        "$O" "inside the"
chk "and how to force one"                   "$O" "MC_FETCH_TTL=0"
# TTL 0 must never skip, whatever the timestamps say.
case "$(MC_FETCH_TTL=0 bash "$D/mc-init.sh" 2>&1)" in
  *"FETCH: skipped"*) no "MC_FETCH_TTL=0 always fetches" "skipped anyway" ;;
  *) ok "MC_FETCH_TTL=0 always fetches" ;;
esac
# The skip must not disturb anything the preamble reports.
chk "the board is still measured"            "$O" "BOARD:"
chk "and the base ref still resolves"        "$O" "BASE_REF:"
cd "$REPO"

echo "── 5k. the status line cannot hang and cannot spawn ───────────────"
# It renders under the user's prompt on every event, so its failure modes are the two that
# would be most visible: blocking, and starting processes.
SL="$D/statusline.sh"
if [ ! -f "$SL" ]; then sk "status line not shipped in this copy"; else
  # `IN=$(cat)` reads stdin forever when stdin is a pipe nobody writes to. Claude Code
  # always supplies a payload, so the bug is invisible in the one place it is used and
  # fatal everywhere else -- it wedged a build here on 2026-08-24.
  if echo -n "" | timeout 10 bash "$SL" >/dev/null 2>&1; then ok "an empty pipe does not hang it"
  else no "an empty pipe does not hang it" "timed out or failed"; fi
  if timeout 10 bash "$SL" </dev/null >/dev/null 2>&1; then ok "no stdin does not hang it"
  else no "no stdin does not hang it" "timed out or failed"; fi
  # `claude agents --json` costs ~0.21s per render AND starts a background service that
  # inherits the caller's stdout -- backgrounding it hung a shell for two minutes.
  case "$(grep -vE '^\s*#' "$SL")" in
    *"claude agents"*) no "it never shells out to claude" "claude agents is back" ;;
    *) ok "it never shells out to claude" ;;
  esac
  # An off-fleet repo must render nothing rather than somebody else's sessions.
  O=$(cd "$WORK" && timeout 10 bash "$SL" </dev/null 2>/dev/null)
  [ -z "$O" ] && ok "an unrelated directory shows no fleet" || no "an unrelated directory shows no fleet" "$O"

  # WHAT IT PRINTS, against a registry built here. Never the live one: a test that reads
  # real state drew the tester's own session out of the registry and failed on it (6.51.0),
  # and MC_SOCK_DIR keeps the fake liveness markers out of the real /tmp/cc-socks.
  SLH="$WORK/slhome"; SLS="$WORK/slsocks"; SLR=$(newrepo)
  # The PHYSICAL path, because that is what the script's own `git rev-parse` returns. On
  # macOS $TMPDIR lives under /var -> /private/var, so a registry holding the symlinked
  # path never matches the resolved one and the line renders empty for the wrong reason.
  SLR=$(cd "$SLR" && git rev-parse --show-toplevel)
  mkdir -p "$SLH/.claude/sessions" "$SLS"
  # kind is "bg" HERE BECAUSE THAT IS WHAT CLAUDE CODE WRITES. The fixture said
  # "background" until 6.93.0 and the script compared against "background" too, so both
  # agreed with each other and neither agreed with reality: no real background station was
  # ever recognised, for four releases. A fixture that invents its input tests the fixture.
  # nameSince is the identification moment, and the line orders by it.
  slsess(){ printf '{"pid":%s,"name":"%s","cwd":"%s","kind":"%s","status":"%s","nameSince":%s}' \
              "$1" "$2" "$SLR" "${4:-interactive}" "${5:-idle}" "${6:-$1}" > "$SLH/.claude/sessions/$1.json"
            [ "${3:-live}" = "live" ] && : > "$SLS/$1.sock"; }
  # MC_CONFIG points at nothing, so the coordinator falls back to CONTROL rather than
  # reading the tester's own machine-level naming.
  slrender(){ (cd "${1:-$SLR}" && HOME="$SLH" MC_CONFIG="$SLH/absent.json" MC_SPAWNLOG="$SLH/spawns.json" MC_WINDOWS="$SLH/windows.json" MC_SOCK_DIR="$SLS" timeout 10 bash "$SL" </dev/null 2>/dev/null); }
  slplain(){ slrender "${1:-}" | sed $'s/\033\[[0-9;]*m//g'; }
  # Renders as a specific session would see it -- stdin carries session_id, the same value
  # the registry stores as sessionId, so the two join with nothing to configure.
  slas(){ (cd "$SLR" && printf '{"cwd":"%s","session_id":"%s"}' "$SLR" "$1" \
           | HOME="$SLH" MC_CONFIG="$SLH/absent.json" MC_SPAWNLOG="$SLH/spawns.json" \
             MC_WINDOWS="$SLH/windows.json" MC_SOCK_DIR="$SLS" timeout 10 bash "$SL" 2>/dev/null); }
  slsid(){ printf '{"pid":%s,"sessionId":"%s","name":"%s","cwd":"%s","kind":"interactive","status":"%s","nameSince":%s}' \
             "$1" "$2" "$3" "$SLR" "${4:-idle}" "$1" > "$SLH/.claude/sessions/$1.json"; : > "$SLS/$1.sock"; }

  # THE SILENT CASE. One unidentified session and nothing else is not a fleet -- it is the
  # tool describing the reader to themselves, in a word that sounds like a fault. That is
  # the line a solo user actually saw ("fleet +1 unidentified") and it must print nothing.
  slsess 9001 "${SLR##*/}-fd"
  O=$(slrender)
  [ -z "$O" ] && ok "a solo unidentified session is silent" || no "a solo unidentified session is silent" "$O"
  # But a session that HAS identified renders alone -- the chip IS the confirmation that
  # identifying worked, and suppressing it would hide the one thing worth confirming.
  slsess 9001 CONTROL live interactive busy
  chk "a solo IDENTIFIED station still shows"  "$(slplain)" "fleet · CONTROL"

  # Call-signs, in the footer's own grammar: dim label, dim `·` separators, cyan names.
  slsess 9002 FRONTEND
  O=$(slplain)
  chk "each station is named by call-sign"     "$O" "CONTROL"
  chk "and so is the next one"                 "$O" "FRONTEND"
  chk "separated the way the footer separates" "$O" "CONTROL · FRONTEND"
  # Busy and idle must be distinguishable, or the line reports presence and calls it status.
  # BRIGHTNESS, NEVER WEIGHT: bold changes the letterforms, so a station starting work
  # reflowed the whole line -- near-constant movement under the prompt with three stations.
  case "$(slrender)" in *$'\033[2;38;5;141mCONTROL'*) no "a busy station is never dimmed" "$(slrender | cat -v)" ;; *) ok "a busy station is never dimmed" ;; esac
  case "$(slrender)" in *$'\033[2;38;5;'*'mFRONTEND'*) ok "an idle one is the same hue, dimmed" ;; *) no "an idle one is the same hue, dimmed" "$(slrender | cat -v)" ;; esac
  # `shell` IS WORK. This tested `== "busy"` until 6.94.0, so a station running a shell
  # command -- status "shell", seen live -- rendered as resting. Only `idle` rests now.
  slsess 9040 SHELLED live interactive shell 9040
  case "$(slrender)" in *$'\033[1;38;5;80mSHELLED'*) ok "a station running a shell is working" ;; *) no "a station running a shell is working" "$(slrender | cat -v)" ;; esac
  # ...but a record with no status at all must not be promoted to working.
  printf '{"pid":9041,"name":"NOSTATUS","cwd":"%s","kind":"interactive","nameSince":9041}' "$SLR" > "$SLH/.claude/sessions/9041.json"; : > "$SLS/9041.sock"
  case "$(slrender)" in *$'\033[2;38;5;80mNOSTATUS'*) ok "a station with no status stays dim" ;; *) no "a station with no status stays dim" "$(slrender | cat -v)" ;; esac
  for p in 9040 9041; do rm -f "$SLH/.claude/sessions/$p.json" "$SLS/$p.sock"; done

  # Bold marks the busy station -- removed in 6.91.0, asked for again after seeing both.
  case "$(slrender)" in *$'\033[1;38;5;80mCONTROL'*|*$'\033[1;38;5;141mCONTROL'*) ok "a busy station is bold" ;; *) no "a busy station is bold" "$(slrender | cat -v)" ;; esac
  case "$(slrender)" in *$'\033[1;38;5;80mFRONTEND'*|*$'\033[1;38;5;141mFRONTEND'*) no "an idle one is never bold" "$(slrender | cat -v)" ;; *) ok "an idle one is never bold" ;; esac

  # ONE COLOUR FOR EVERY CALL-SIGN. A per-station palette was built and reverted: it made
  # the line prettier and less readable, because a colour only says something once the
  # reader has learned what it means, and its meaning moved whenever the fleet did.
  slsess 9010 BACKEND; slsess 9011 PAYMENTS; slsess 9012 CHANNELS live bg idle
  HUES=$(slrender | grep -o '38;5;[0-9]*' | sort -u | tr '\n' ' ')
  case "$HUES" in *38\;5\;1[14]*) : ;; *) no "only the visibility triad is used" "$HUES"; false ;; esac 2>/dev/null
  BAD=$(printf '%s' "$HUES" | tr ' ' '\n' | grep -v '^$' | grep -vE '^38;5;(141|80|179)$' || true)
  [ -z "$BAD" ] && ok "only the visibility triad is used" || no "only the visibility triad is used" "$BAD"
  # Violet on purpose: the one terminal hue carrying no convention -- not error, warning,
  # success or information. A call-sign is identity, so it borrows no status colour.
  case "$(slrender)" in *$'\033[31m'*|*$'\033[32m'*|*$'\033[33m'*|*$'\033[36m'*)
       no "no status colour is borrowed" "$(slrender | cat -v)" ;;
     *) ok "no status colour is borrowed" ;; esac
  # The render must not depend on anything that varies per process.
  [ "$(slrender)" = "$(slrender)" ] && ok "two renders agree byte for byte" \
    || no "two renders agree byte for byte" "they differed"
  for p in 9010 9011 9012; do rm -f "$SLH/.claude/sessions/$p.json" "$SLS/$p.sock"; done
  # VISIBILITY IS THE SECOND SIGNAL, and it is MEASURED from the registry's `kind`, never
  # read from the spawn preference -- the preference describes future deploys, and a hybrid
  # fleet (spawn.once) can disagree with it right now.
  slsess 9003 CHANNELS live bg idle
  case "$(slrender)" in *$'\033[2;38;5;141mCHANNELS'*) ok "a background station is violet" ;; *) no "a background station is violet" "$(slrender | cat -v)" ;; esac
  case "$(slrender)" in *$'\033[2;38;5;80mFRONTEND'*) ok "a tab station is turquoise" ;; *) no "a tab station is turquoise" "$(slrender | cat -v)" ;; esac
  # A WINDOW is not distinguishable from a TAB in the session registry -- `kind` says only
  # bg or interactive -- so the deploy records which it opened and the line reads it back.
  printf '{"stations":{"%s":{"WINDOWED":"window","FRONTEND":"tab"}}}' "$SLR" > "$SLH/spawns.json"
  slsess 9030 WINDOWED live interactive idle 9030
  case "$(slrender)" in *$'\033[2;38;5;179mWINDOWED'*) ok "a windowed station is gold" ;; *) no "a windowed station is gold" "$(slrender | cat -v)" ;; esac
  # MEASURED BEATS RECORDED: a session reporting bg is background whatever the log says.
  printf '{"stations":{"%s":{"CHANNELS":"window"}}}' "$SLR" > "$SLH/spawns.json"
  case "$(slrender)" in *$'\033[2;38;5;141mCHANNELS'*) ok "the live registry outranks the spawn log" ;; *) no "the live registry outranks the spawn log" "$(slrender | cat -v)" ;; esac
  # A hand-started session has no record and must not be guessed into a window.
  : > "$SLH/spawns.json"
  case "$(slrender)" in *$'\033[2;38;5;179mWINDOWED'*) no "an unrecorded station falls back to tab" "$(slrender | cat -v)" ;; *) ok "an unrecorded station falls back to tab" ;; esac
  rm -f "$SLH/.claude/sessions/9030.json" "$SLS/9030.sock" "$SLH/spawns.json"
  # The old `(bg)` suffix is gone: colour says it without spending four characters a station.
  case "$(slplain)" in *"(bg)"*|*"·bg"*) no "no bg suffix survives" "$(slplain)" ;; *) ok "no bg suffix survives" ;; esac

  # ORDER: coordinator leftmost, then by when each station took its call-sign. Alphabetical
  # was the old order; a fleet is not a dictionary. ZEBRA identified before ALPHA, so ZEBRA
  # comes first -- an alphabetical sort would put ALPHA there and a test would not notice.
  for p in 9001 9002 9003; do rm -f "$SLH/.claude/sessions/$p.json" "$SLS/$p.sock"; done
  slsess 9020 ZEBRA   live bg          idle 1000
  slsess 9021 CONTROL live interactive busy 2000
  slsess 9022 ALPHA   live bg          busy 3000
  chk "the coordinator leads, then identification order" "$(slplain)" "fleet · CONTROL · ZEBRA · ALPHA"
  for p in 9020 9021 9022; do rm -f "$SLH/.claude/sessions/$p.json" "$SLS/$p.sock"; done
  slsess 9001 CONTROL live interactive busy; slsess 9002 FRONTEND; slsess 9003 CHANNELS live bg idle

  # WINDOW vs TAB IS GROUPED FROM THE PROBE, not stored as a count. Two stations reporting
  # the same window id are tabs in one window; one alone in its window has it to itself.
  # This is what makes a HAND-STARTED station colour correctly -- the deploy log can only
  # know about stations `deploy` opened.
  for p in 9001 9002 9003; do rm -f "$SLH/.claude/sessions/$p.json" "$SLS/$p.sock"; done
  slsid 9060 sid-t1 TABBED-A idle
  slsid 9061 sid-t2 TABBED-B idle
  slsid 9062 sid-w1 ALONE    idle
  # tabs=2 for the pair, tabs=1 for the one that owns its window -- the shape the probe writes.
  printf '{"sessions":{"sid-t1":{"window":"w7","tabs":2},"sid-t2":{"window":"w7","tabs":2},"sid-w1":{"window":"w9","tabs":1}}}' > "$SLH/windows.json"
  O=$(slrender)
  case "$O" in *$'\033[2;38;5;80mTABBED-A'*) ok "two stations in one window are tabs" ;; *) no "two stations in one window are tabs" "$(printf '%s' "$O" | cat -v)" ;; esac
  case "$O" in *$'\033[2;38;5;80mTABBED-B'*) ok "and so is the other one" ;; *) no "and so is the other one" "$(printf '%s' "$O" | cat -v)" ;; esac
  case "$O" in *$'\033[2;38;5;179mALONE'*) ok "a station alone in its window is pink" ;; *) no "a station alone in its window is pink" "$(printf '%s' "$O" | cat -v)" ;; esac
  # A STALE COUNT MUST NOT OVER-CLAIM. Close one of the pair and the grouping now sees one
  # station in w7 -- but the recorded count still says 2 tabs, and a tab that holds no
  # station is still a tab. Both must agree before the line calls it a window.
  rm -f "$SLH/.claude/sessions/9061.json" "$SLS/9061.sock"
  case "$(slrender)" in *$'\033[2;38;5;80mTABBED-A'*) ok "a stale tab count is not over-claimed" ;; *) no "a stale tab count is not over-claimed" "$(slrender | cat -v)" ;; esac
  # Re-probed (tabs now 1) it becomes a window, which is what a fresh probe would record.
  printf '{"sessions":{"sid-t1":{"window":"w7","tabs":1}}}' > "$SLH/windows.json"
  case "$(slrender)" in *$'\033[2;38;5;179mTABBED-A'*) ok "and a re-probe promotes it" ;; *) no "and a re-probe promotes it" "$(slrender | cat -v)" ;; esac
  # No probe record falls back to the deploy log, then to tab -- never guessed into a window.
  : > "$SLH/windows.json"
  printf '{"stations":{"%s":{"ALONE":"window"}}}' "$SLR" > "$SLH/spawns.json"
  case "$(slrender)" in *$'\033[2;38;5;179mALONE'*) ok "no probe falls back to the deploy log" ;; *) no "no probe falls back to the deploy log" "$(slrender | cat -v)" ;; esac
  case "$(slrender)" in *$'\033[2;38;5;80mTABBED-A'*) ok "and to tab when neither knows" ;; *) no "and to tab when neither knows" "$(slrender | cat -v)" ;; esac
  for p in 9060 9062; do rm -f "$SLH/.claude/sessions/$p.json" "$SLS/$p.sock"; done
  rm -f "$SLH/windows.json" "$SLH/spawns.json"
  slsess 9001 CONTROL live interactive busy; slsess 9002 FRONTEND; slsess 9003 CHANNELS live bg idle

  # YOUR OWN STATION IS BOXED, so a screen of identical tabs still tells you where you are
  # standing. Reverse video (7) fills the call-sign's own colour behind it -- a different
  # SHAPE, not one more hue to learn.
  for p in 9001 9002 9003; do rm -f "$SLH/.claude/sessions/$p.json" "$SLS/$p.sock"; done
  slsid 9050 sid-aaa MINE  idle
  slsid 9051 sid-bbb THEIRS busy
  case "$(slas sid-aaa)" in *$'\033[7;38;5;80m MINE '*) ok "your own station is boxed" ;; *) no "your own station is boxed" "$(slas sid-aaa | cat -v)" ;; esac
  case "$(slas sid-aaa)" in *$'\033[7;38;5;80m THEIRS '*) no "nobody else is boxed" "$(slas sid-aaa | cat -v)" ;; *) ok "nobody else is boxed" ;; esac
  # The box moves with the tab: the same fleet, read from the other session.
  case "$(slas sid-bbb)" in *$'\033[7;38;5;80m THEIRS '*) ok "the box follows the reader" ;; *) no "the box follows the reader" "$(slas sid-bbb | cat -v)" ;; esac
  # A box is never dimmed -- it says where you are, not what you are doing, and an idle
  # station is exactly when you most need to find your own row.
  case "$(slas sid-aaa)" in *$'\033[2;7'*|*$'\033[7;2'*) no "the box is never dimmed" "$(slas sid-aaa | cat -v)" ;; *) ok "the box is never dimmed" ;; esac
  # No session_id on stdin (a tty, a pipeline, an older host) must box nothing, not guess.
  case "$(slrender)" in *$'\033[7;'*) no "no session_id boxes nothing" "$(slrender | cat -v)" ;; *) ok "no session_id boxes nothing" ;; esac
  for p in 9050 9051; do rm -f "$SLH/.claude/sessions/$p.json" "$SLS/$p.sock"; done
  slsess 9001 CONTROL live interactive busy; slsess 9002 FRONTEND; slsess 9003 CHANNELS live bg idle

  # A generated handle is an ADDRESS (VOCABULARY.md). It is counted, never printed --
  # BOTH shapes: `<repo>-<hex>` from a hand-started session, and a bare hex id.
  slsess 9004 "${SLR##*/}-fd"
  slsess 9005 fb7b47a7
  O=$(slplain)
  chk "generated handles are counted, not named" "$O" "+2 unidentified"
  case "$O" in *-fd*|*fb7b47a7*) no "no address reaches the line" "$O" ;; *) ok "no address reaches the line" ;; esac
  # The residue is dim: highlighting it would emphasise the one item carrying no information.
  case "$(slrender)" in *$'\033[2m+2 unidentified'*) ok "the unidentified count stays dim" ;; *) no "the unidentified count stays dim" "$(slrender | cat -v)" ;; esac

  # A registry file outlives the session that wrote it, so the socket is the liveness test.
  slsess 9006 GHOST dead
  case "$(slplain)" in *GHOST*) no "a dead station is not shown" "$(slplain)" ;; *) ok "a dead station is not shown" ;; esac
  # A station edits inside <repo>/.claude/worktrees/<name>; that must fold back to the repo,
  # or four stations read as four unrelated repositories and the line is empty in exactly
  # the fleet it describes.
  WT="$SLR/.claude/worktrees/BACKEND"
  if git -C "$SLR" worktree add -q "$WT" -b sl-wt >/dev/null 2>&1; then
    chk "a worktree still sees its own fleet" "$(slplain "$WT")" "CONTROL"
  else sk "worktree could not be created here"; fi
fi

echo "── 5m. the window probe is best-effort and never fatal ───────────"
WP="$D/window-probe.sh"
if [ ! -f "$WP" ]; then sk "window-probe.sh not shipped in this copy"; else
  # It runs at every identify, so a failure here would break identify itself. Every
  # unknown must be a clean exit 0 with a reason, never an error.
  O=$(MC_WINDOWS="$WORK/win.json" timeout 10 bash "$WP" 2>&1); RC=$?
  [ $RC -eq 0 ] && ok "the probe always exits clean" || no "the probe always exits clean" "exit $RC: $O"
  chk "and says what it found or why not"  "$O" "WINDOW:"
  # An unparseable record is left alone, exactly like every other file this skill owns.
  printf 'not json' > "$WORK/win.json"; BEFORE=$(wc -c < "$WORK/win.json")
  MC_WINDOWS="$WORK/win.json" timeout 10 bash "$WP" >/dev/null 2>&1
  [ "$(wc -c < "$WORK/win.json")" = "$BEFORE" ] && ok "an unparseable window file is not rewritten" \
    || no "an unparseable window file is not rewritten" "it was rewritten"
  # --all backfills every live session in one pass, so a fleet that is already up gets
  # colours without each station being made to re-identify. Same contract: never fatal.
  O=$(MC_WINDOWS="$WORK/win2.json" timeout 20 bash "$WP" --all 2>&1); RC=$?
  [ $RC -eq 0 ] && ok "--all always exits clean" || no "--all always exits clean" "exit $RC: $O"
  chk "and reports what it did"            "$O" "WINDOW:"
  # It must GROUP BY FRAME, never by window id or `count of tabs`. Terminal.app exposes
  # every TAB as its own window object with tabs=1 -- measured on a window holding four
  # visible tabs, which reported as four windows of one tab each -- so both of those
  # measures are structurally unable to tell a tab from a window.
  case "$(grep -vE '^\s*#' "$WP")" in
    *"count of tabs"*) no "the probe does not count tabs of a window" "Terminal reports 1 for every tab" ;;
    *) ok "the probe does not count tabs of a window" ;;
  esac
  case "$(grep -vE '^\s*#' "$WP")" in
    *"bounds of w"*) ok "the probe groups by window frame" ;;
    *) no "the probe groups by window frame" "no bounds lookup" ;;
  esac
  # It must never shell out to claude, for the same reason the status line must not.
  case "$(grep -vE '^\s*#' "$WP")" in
    *"claude agents"*) no "the probe never shells out to claude" "claude agents present" ;;
    *) ok "the probe never shells out to claude" ;;
  esac
fi

echo
echo "── 5c. the scope rule: automation only under an explicit deploy ───"
# The spawn automation exists for ONE job -- open a station and get it identified -- and
# is triggered by ONE thing. The rule is enforced by a required flag rather than by a
# comment, because a scope written in prose grows and a required flag has to be typed.
O=$(bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND 2>&1); RC=$?
chk "no --deploy means no spawn"            "$O" "NOT A DEPLOY"
chk "and it says nothing was started"       "$O" "no session was started and no window was opened"
chk "it still hands over a usable line"     "$O" "claude --name 'BACKEND'"
[ $RC -eq 0 ] && ok "declining to spawn is not an error (exit 0)" || no "declining to spawn is not an error" "exit $RC"
# The demotion must be a DEMOTION, not a quiet spawn: nothing may reach the launcher.
: > "$STUB_CLAUDE_REG"
bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND >/dev/null 2>&1
bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --window >/dev/null 2>&1
if [ -s "$STUB_CLAUDE_REG" ]; then no "nothing is launched without --deploy" "the launcher ran anyway"
else ok "nothing is launched without --deploy"; fi
chk "--print needs no --deploy"             "$(bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --print 2>&1)" "open a terminal and paste this"

# THE DEPLOY RECORDS WHICH MODE IT OPENED. Nothing else can: the session registry says
# `bg` or `interactive` and never window-vs-tab, so the status line reads this log back.
SPL="$WORK/spawns.json"; rm -f "$SPL"
MC_SPAWNLOG="$SPL" bash "$D/spawn-station.sh" WINSTATION "$REPO" WINSTATION --window --deploy >/dev/null 2>&1
if [ -f "$SPL" ]; then
  chk "a deploy records the mode it opened"  "$(cat "$SPL")" '"WINSTATION": "window"'
else no "a deploy records the mode it opened" "no log written"; fi
# --print must not: it opened nothing, so it has nothing to report about.
rm -f "$SPL"; bash "$D/spawn-station.sh" PRINTONLY "$REPO" PRINTONLY --print >/dev/null 2>&1
[ -f "$SPL" ] && no "--print records nothing" "a log appeared" || ok "--print records nothing"
# Neither may a refused spawn -- no --deploy means nothing happened at all.
rm -f "$SPL"; MC_SPAWNLOG="$SPL" bash "$D/spawn-station.sh" NODEPLOY "$REPO" NODEPLOY --window >/dev/null 2>&1
[ -f "$SPL" ] && no "a refused spawn records nothing" "a log appeared" || ok "a refused spawn records nothing"
# An unparseable log is left alone rather than truncated, exactly as spawn-pref.sh does.
printf 'not json' > "$SPL"; BEFORE=$(wc -c < "$SPL")
MC_SPAWNLOG="$SPL" bash "$D/spawn-station.sh" SAFE "$REPO" SAFE --window --deploy >/dev/null 2>&1
[ "$(wc -c < "$SPL")" = "$BEFORE" ] && ok "an unparseable spawn log is not rewritten" || no "an unparseable spawn log is not rewritten" "it was rewritten"

echo
echo "── 5d. the preference is ASKED once, not detected ─────────────────"
PD="$WORK/pref"; mkdir -p "$PD"; PCFG="$PD/mc.json"
chk "a fresh machine has no preference"     "$(MC_CONFIG="$PCFG" bash "$D/spawn-pref.sh" read 2>&1)" "SPAWN: unset"
# unset must not read as background: they behave the same and MEAN different things.
case "$(MC_CONFIG="$PCFG" bash "$D/spawn-pref.sh" read 2>&1)" in
  *"SPAWN: background"*) no "unset is not silently reported as a choice" "reported background" ;;
  *) ok "unset is not silently reported as a choice" ;;
esac
chk "a deploy on an unrecorded machine says so" \
    "$(MC_CONFIG="$PCFG" bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --deploy 2>&1)" \
    "nobody has been asked on this machine yet"
MC_CONFIG="$PCFG" bash "$D/spawn-pref.sh" set window >/dev/null 2>&1
chk "a recorded preference reads back"      "$(MC_CONFIG="$PCFG" bash "$D/spawn-pref.sh" read 2>&1)" "SPAWN: window"
chk "and the deploy then honours it"        "$(MC_CONFIG="$PCFG" TERM_PROGRAM=vscode bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --deploy 2>&1)" "NO WINDOW RECIPE HERE"
case "$(MC_CONFIG="$PCFG" bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --deploy 2>&1)" in
  *"nobody has been asked"*) no "a recorded machine is not nagged" "still says nobody was asked" ;;
  *) ok "a recorded machine is not nagged" ;;
esac
# The same read-modify-write rule tour-state.sh follows: one key touched, everything
# else survives, and a file we cannot parse is never overwritten.
printf '{"_comment":"hand written, do not lose me","tour":{"state":"completed"},"spawn":{"mode":"window"}}' > "$PCFG"
MC_CONFIG="$PCFG" bash "$D/spawn-pref.sh" set background >/dev/null 2>&1
O=$(python3 -c "import json;d=json.load(open('$PCFG'));print(d.get('_comment',''),d.get('tour',{}).get('state',''),d.get('spawn',{}).get('mode',''))")
chk "existing preferences survive the write" "$O" "hand written, do not lose me completed background"
printf 'not json at all' > "$PCFG"; BEFORE=$(wc -c < "$PCFG")
MC_CONFIG="$PCFG" bash "$D/spawn-pref.sh" set window >/dev/null 2>&1
[ "$(wc -c < "$PCFG")" = "$BEFORE" ] && ok "an unparseable config is left alone" || no "an unparseable config is left alone" "it was rewritten"
chk "and it says so rather than failing silently" "$(MC_CONFIG="$PCFG" bash "$D/spawn-pref.sh" read 2>&1)" "could not be parsed"
chk "reset puts it back to unasked"          "$(printf '{"spawn":{"mode":"window"}}' > "$PCFG"; MC_CONFIG="$PCFG" bash "$D/spawn-pref.sh" reset >/dev/null 2>&1; MC_CONFIG="$PCFG" bash "$D/spawn-pref.sh" read 2>&1)" "SPAWN: unset"
chk "a bogus mode is refused"                "$(MC_CONFIG="$PCFG" bash "$D/spawn-pref.sh" set sideways 2>&1)" "usage:"

echo
echo "── 5e. preferences change in place, like /config ──────────────────"
# A preference you can only change by making the tool forget you answered is not a
# setting, it is a fresh install. That was the state before 6.79.0.
CD2="$WORK/cfg2"; mkdir -p "$CD2"; CC="$CD2/mc.json"
printf '{"spawn":{"placement":"tab","launchCommand":"claude"},"naming":{"stationStyle":"same"}}' > "$CC"
O=$(MC_CONFIG="$CC" bash "$D/mc-config.sh" show 2>&1)
chk "show lists a set value"                "$O" "spawn.launchCommand"
chk "show explains what an unset one does"  "$O" "(not set)"
chk "show names the file it is reading"     "$O" "$CC"
# A dead key that looks like live configuration is a question waiting to be asked.
chk "stale keys are named, not ignored"     "$O" "STALE"
chk "and it says what replaced them"        "$O" "replaced by spawn.mode in 6.78.0"

# ONE OWNER PER KEY. mc-config delegates rather than writing these itself; if it ever
# stops, two writers disagree about what the user chose and both look right.
MC_CONFIG="$CC" bash "$D/mc-config.sh" set spawn.mode window >/dev/null 2>&1
chk "setting spawn.mode goes through its owner" "$(MC_CONFIG="$CC" bash "$D/spawn-pref.sh" read 2>&1)" "SPAWN: window"
chk "and the deploy honours it immediately"     "$(MC_CONFIG="$CC" TERM_PROGRAM=vscode bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --deploy 2>&1)" "NO WINDOW RECIPE HERE"
MC_CONFIG="$CC" bash "$D/mc-config.sh" set spawn.mode background >/dev/null 2>&1
chk "and it changes back in place"              "$(MC_CONFIG="$CC" bash "$D/spawn-pref.sh" read 2>&1)" "SPAWN: background"
chk "unset returns it to being asked"           "$(MC_CONFIG="$CC" bash "$D/mc-config.sh" unset spawn.mode >/dev/null 2>&1; MC_CONFIG="$CC" bash "$D/spawn-pref.sh" read 2>&1)" "SPAWN: unset"

# Guards. Same reasoning as the call-sign allowlist, applied to every value that lands
# in a config file other code reads back.
chk "an invalid value is refused"           "$(MC_CONFIG="$CC" bash "$D/mc-config.sh" set naming.stationStyle sideways 2>&1)" "takes"
chk "an unknown key is refused"             "$(MC_CONFIG="$CC" bash "$D/mc-config.sh" set spawn.nonsense x 2>&1)" "unknown key"
chk "an injection-shaped value is refused"  "$(MC_CONFIG="$CC" bash "$D/mc-config.sh" set naming.coordinator 'A`whoami`' 2>&1)" "letters, digits, spaces"
# A stale key must refuse cleanly. Looking it up in the live table first raises a
# KeyError, and a traceback is not the sentence explaining why the key is dead.
O=$(MC_CONFIG="$CC" bash "$D/mc-config.sh" set spawn.placement tab 2>&1)
chk "a stale key refuses with a reason"     "$O" "is not read by anything today"
case "$O" in *Traceback*) no "and not with a traceback" "python traceback" ;; *) ok "and not with a traceback" ;; esac
chk "a stale key can still be cleared"      "$(MC_CONFIG="$CC" bash "$D/mc-config.sh" unset spawn.placement 2>&1)" "cleared"
# Widening a spawned station's permissions is the user's call and must never be quiet.
chk "bypassPermissions warns loudly"        "$(MC_CONFIG="$CC" bash "$D/mc-config.sh" set spawn.permissionMode bypassPermissions 2>&1)" "ALL permission checks bypassed"
# Same rule the other two config writers follow.
printf '{"_comment":"hand written","naming":{"coordinator":"HQ"}}' > "$CC"
MC_CONFIG="$CC" bash "$D/mc-config.sh" set naming.stationStyle per-station >/dev/null 2>&1
O=$(python3 -c "import json;d=json.load(open('$CC'));print(d.get('_comment',''),d['naming']['coordinator'],d['naming']['stationStyle'])")
chk "other preferences survive the write"   "$O" "hand written HQ per-station"
printf 'not json at all' > "$CC"; B=$(wc -c < "$CC")
MC_CONFIG="$CC" bash "$D/mc-config.sh" set naming.coordinator HQ >/dev/null 2>&1
[ "$(wc -c < "$CC")" = "$B" ] && ok "an unparseable config is left alone" || no "an unparseable config is left alone" "it was rewritten"
chk "keys lists the valid values for asking" "$(MC_CONFIG="$CC" bash "$D/mc-config.sh" keys 2>&1)" "background | window"

echo "── 6. the guards ──────────────────────────────────────────────────"
chk "AppleScript injection refused"    "$(PATH="$STUB:$PATH" bash "$D/label-tab.sh" 'A"; do shell script "x' 2>&1)" "FAILED:"
chk "shell injection refused"          "$(bash "$D/spawn-station.sh" 'A`whoami`' "$REPO" X --print 2>&1)" "FAILED:"
chk "over-long call-sign refused"      "$(PATH="$STUB:$PATH" bash "$D/label-tab.sh" "$(python3 -c 'print("A"*70)')" 2>&1)" "too long"
# The allowlist is a COLLATION range: under a UTF-8 locale it admitted accented letters
# and a NON-BREAKING SPACE while its message promised ASCII. Not exploitable -- no quote
# or metacharacter homoglyph passes -- but an invisible character that is accepted here
# and matches nowhere else is a call-sign nobody can address. Reported 2026-08-23.
chk "an accented letter is refused"    "$(PATH="$STUB:$PATH" bash "$D/label-tab.sh" 'CAFÉ' 2>&1)" "FAILED:"
# WITNESS CHARACTERS MATTER. The first version of this check used a NON-BREAKING SPACE,
# and NBSP is refused under EVERY locale -- it is not a letter, so it never collated
# among [A-Za-z] in the first place. That check passed on the unfixed build and pinned
# nothing. Caught 2026-08-23 by a tester who verified the claim instead of inheriting it.
# The characters that actually WERE admitted are LETTERS: e-acute, a-umlaut, fullwidth A.
chk "an umlaut is refused"             "$(PATH="$STUB:$PATH" bash "$D/label-tab.sh" "$(printf 'C\303\244FE')" 2>&1)" "FAILED:"
chk "a fullwidth letter is refused"    "$(PATH="$STUB:$PATH" bash "$D/label-tab.sh" "$(printf '\357\274\241BC')" 2>&1)" "FAILED:"
# kept as a negative control, and labelled as one: this was refused BEFORE the fix too.
chk "a non-breaking space stays refused (control)" "$(PATH="$STUB:$PATH" bash "$D/label-tab.sh" "$(printf 'A\302\240B')" 2>&1)" "FAILED:"
chk "a plain ASCII call-sign still passes" "$(PATH="$STUB:$PATH" bash "$D/label-tab.sh" 'BACK-END_2' 2>&1)" "BACK-END_2"
# ...and the refusal must show what was passed. This was the one guard that stated the
# rule without echoing the input, on the script most likely to reject something invisible.
chk "the refusal echoes the input"     "$(PATH="$STUB:$PATH" bash "$D/label-tab.sh" 'BAD;NAME' 2>&1)" "got: BAD;NAME"
chk "spaced call-sign needs a handle"  "$(PATH="$STUB:$PATH" bash "$D/set-callsign.sh" 'FLEET COMMAND' 2>&1)" "needs a handle"
chk "missing worktree refused"         "$(bash "$D/spawn-station.sh" X /nope/nope X --print 2>&1)" "no such worktree"

echo
echo "── 6a. renaming, against a registry we own ────────────────────────"
# The clash test USED to pick a name off the live registry. It picked the session
# RUNNING THE TEST -- the glob's first live entry is as likely to be us as anyone --
# and set-callsign.sh skips its own file when scanning for a clash, so there was no
# clash to find and the assert failed on "address already". Measured 2026-08-23.
# It was also unsafe in the other direction: had the clash check regressed, the
# rename would have landed on the tester's OWN live session, which is the one thing
# the header promises never happens. It survived only because name==name exits early.
#
# So build the registry instead of borrowing one. set-callsign.sh reads $HOME, so a
# fake HOME gives us a private registry: our own entry under the REAL claude pid (it
# walks the true parent chain and will not be fooled about who it is), plus a peer
# whose liveness we choose. Nothing here can touch the real registry or a real tab.
# Copied WITHOUT label-tab.sh beside it, so the tab surface takes its documented skip
# and no osascript ever runs against somebody's terminal.
CP=$$
while [ "$CP" -gt 1 ]; do
  [ "$(ps -o comm= -p "$CP" 2>/dev/null | xargs basename 2>/dev/null)" = "claude" ] && break
  CP=$(ps -o ppid= -p "$CP" 2>/dev/null | tr -d ' '); [ -z "$CP" ] && { CP=1; break; }
done
if [ "$CP" -le 1 ]; then
  sk "renaming — no claude in the parent chain (run this from inside a session)"
else
  TH="$WORK/home"; mkdir -p "$TH/.claude/sessions" "$TH/bin"
  cp "$D/set-callsign.sh" "$TH/bin/set-callsign.sh"
  SC="$TH/bin/set-callsign.sh"
  REAL="$HOME/.claude/sessions/$CP.json"
  BEFORE=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('name',''))" "$REAL" 2>/dev/null)
  printf '{"pid":%s,"name":"OLDNAME","cwd":"/tmp"}' "$CP" > "$TH/.claude/sessions/$CP.json"

  # a peer that is genuinely alive, holding TAKEN
  sleep 30 & PEER=$!
  printf '{"pid":%s,"name":"TAKEN","cwd":"/tmp/peer"}' "$PEER" > "$TH/.claude/sessions/peer.json"
  chk "a live peer's call-sign is refused" \
      "$(HOME="$TH" bash "$SC" TAKEN 2>&1)" "REFUSED"
  chk "the refusal names who holds it" \
      "$(HOME="$TH" bash "$SC" TAKEN 2>&1)" "/tmp/peer"
  kill $PEER 2>/dev/null; wait $PEER 2>/dev/null

  # same name, same file -- but the holder is now dead, so the name is free
  printf '{"pid":%s,"name":"GHOST","cwd":"/tmp/ghost"}' "$PEER" > "$TH/.claude/sessions/peer.json"
  O=$(HOME="$TH" bash "$SC" GHOST 2>&1)
  chk "a dead session's call-sign is free"  "$O" "OLDNAME -> GHOST"
  chk "no label-tab.sh means a clean skip"  "$O" "tab title: skipped"
  chk "the old handle is not claimed fixed" "$O" "ONLY A RESTART"
  REGN=$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d['name'],d.get('nameSource'),','.join(d.get('formerNames',[])))" "$TH/.claude/sessions/$CP.json")
  chk "the registry carries the new name"   "$REGN" "GHOST user"
  chk "the former name is kept"             "$REGN" "OLDNAME"
  chk "re-setting the same name is a no-op" "$(HOME="$TH" bash "$SC" GHOST 2>&1)" "address already"
  REGN=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('formerNames',[]))" "$TH/.claude/sessions/$CP.json")
  case "$REGN" in *OLDNAME*OLDNAME*) no "a no-op does not re-log the former name" "$REGN";; *) ok "a no-op does not re-log the former name";; esac

  # RENAMING BACK TO A NAME YOU ALREADY HELD must not leave it listed as former. Only
  # the outgoing name was filtered, never the incoming one, so a CONTROL -> PROBE ->
  # CONTROL round trip left CONTROL in `name` and in `formerNames` at once. The only
  # reason anyone reads formerNames is to decide whether an address is STALE, so it
  # false-positived on exactly the name it was consulted to validate. Live registry,
  # 2026-08-23.
  HOME="$TH" bash "$SC" ROUNDTRIP >/dev/null 2>&1
  HOME="$TH" bash "$SC" GHOST     >/dev/null 2>&1
  REGN=$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d['name'],'|',','.join(d.get('formerNames',[])))" "$TH/.claude/sessions/$CP.json")
  case "$REGN" in
    "GHOST | "*GHOST*) no "a re-taken name is not also listed as former" "$REGN" ;;
    "GHOST | "*ROUNDTRIP*) ok "a re-taken name is not also listed as former" ;;
    *) no "a re-taken name is not also listed as former" "$REGN" ;;
  esac

  # the whole point of the fake HOME: the tester's own session is untouched
  AFTER=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('name',''))" "$REAL" 2>/dev/null)
  [ "$BEFORE" = "$AFTER" ] && ok "the tester's own session was never renamed" \
                           || no "the tester's own session was never renamed" "$BEFORE -> $AFTER"
fi

echo
echo "── 6b. at-risk tells scratch apart from real work ─────────────────"
cd "$REPO"; echo "modified" >> README.md; : > docs/scratch-untracked.txt
O=$(bash "$D/preflight.sh" at-risk 2>&1)
chk "tracked modification named as real work" "$O" "tracked file(s) MODIFIED"
chk "untracked counted separately"            "$O" "untracked file(s)"
chk "untracked is not called work at risk"    "$O" "untracked is NOT automatically at risk"
git checkout -q -- README.md; rm -f docs/scratch-untracked.txt

echo
echo "── 6bb. at-risk names WHICH worktree holds unpushed work ──────────"
WT="$WORK/scratch-flip"; git -C "$REPO" worktree add -q --detach "$WT" HEAD 2>/dev/null
( cd "$WT" && echo x > f.txt && git add -A && git -c user.email=t@e -c user.name=t commit -qm "lock: unpushed" ) >/dev/null 2>&1
O=$(cd "$REPO" && bash "$D/preflight.sh" at-risk 2>&1)
chk "unpushed commit in a detached worktree is flagged" "$O" "AT RISK"
chk "the worktree is named, not just 'HEAD'"            "$O" "scratch-flip"
git -C "$REPO" worktree remove --force "$WT" 2>/dev/null; cd "$REPO"

echo
echo "── 6bc. at-risk counts CONTENT, not reachability ──────────────────"
# Two shapes that used to be reported wrongly, both with a real remote.
mkrepo(){ local d="$WORK/$1"; mkdir -p "$d/up.git"; git init -q --bare -b main "$d/up.git"
  git clone -q "$d/up.git" "$d/w" 2>/dev/null; cd "$d/w"
  git config user.email t@e; git config user.name t
  echo base > f.txt; git add -A; git commit -qm base; git push -q -u origin main; }

# (a) base branch merged into a lane, nothing pushed: only the merge is at risk.
mkrepo mergecase
git checkout -qb lane; echo l > l.txt; git add -A; git commit -qm lane; git push -q -u origin lane
git checkout -q main; for i in 1 2 3 4 5; do echo "m$i" >> f.txt; git add -A; git commit -qm "main $i"; done
git push -q origin main; git checkout -q lane; git merge -q --no-edit main -m "merge main into lane" 2>/dev/null
O=$(bash "$D/preflight.sh" at-risk 2>&1)
chk "merged-in base commits are NOT called at risk" "$O" "1 commit(s) on no remote"
case "$O" in *"main 3"*) no "merged-in base commits are not listed" "listed 'main 3'";; *) ok "merged-in base commits are not listed";; esac

# (b) content already upstream under a different sha: safe, not at risk.
mkrepo dupcase
git checkout -qb lane2; echo d > d.txt; git add -A; git commit -qm "docs: finding"; git push -q -u origin lane2
S=$(git rev-parse HEAD); git checkout -q main; git cherry-pick "$S" >/dev/null 2>&1; git push -q origin main
git checkout -q lane2; git commit -q --amend --no-edit --date="2026-01-01T00:00:00"
O=$(bash "$D/preflight.sh" at-risk 2>&1)
chk "content already upstream reads safe"      "$O" "ALL content is already on a remote"
chk "and is named a duplicate, not a loss"     "$O" "duplicate by content"
cd "$REPO"

echo
echo "── 6bd. at-risk cannot go blind on a worktree ─────────────────────"
# The regression that matters most in this file: a worktree whose DIRECTORY is gone was
# skipped silently, so the one repo state where work is most likely to be lost printed
# "ok every commit in every worktree exists on a remote". Build exactly that state.
GONE=$(newrepo); cd "$GONE"
git worktree add -q --detach "$GONE/../gonewt" HEAD 2>/dev/null
( cd "$GONE/../gonewt" && echo secret > only-here.txt && git add -A && git commit -qm "exists nowhere else" )
LOSTSHA=$(git -C "$GONE/../gonewt" rev-parse HEAD)
rm -rf "$GONE/../gonewt"                       # the worktree is now prunable
O=$(bash "$D/preflight.sh" at-risk 2>&1)
chk "a prunable worktree is still measured"   "$O" "AT RISK"
chk "it is not reported as safe"              "$(printf '%s' "$O" | grep -c 'every commit in every worktree')" "0"
chk "the missing directory is named as such"  "$O" "[DIR GONE]"
chk "the lost commit is listed"               "$O" "exists nowhere else"
chk "prune is named as the thing that loses it" "$O" "worktree prune"
chk "recovery is spelled out, not implied"    "$O" "git branch <name>"

# ...and the claim must be CHECKED, not assumed. If a branch or tag also holds the
# commit, prune cannot lose it: the exposure is "no remote", whose fix is a push, not
# the branch this used to recommend. Reported against a live commit, 2026-08-23.
git branch pinned/elsewhere "$LOSTSHA" >/dev/null 2>&1
O=$(bash "$D/preflight.sh" at-risk 2>&1)
chk "another ref holding it is named"          "$O" "pinned/elsewhere"
chk "prune is NOT blamed when a branch holds it" "$(printf '%s' "$O" | grep -c 'prune. DELETES')" "0"
chk "the real exposure is named instead"       "$O" "the fix is a push, not a branch"
chk "it is still reported as at risk"          "$O" "AT RISK"

# and the inverse: a gone worktree whose content IS on a remote must not cry wolf
GONE2=$(newrepo); cd "$GONE2"
git worktree add -q --detach "$GONE2/../gonewt2" HEAD 2>/dev/null
rm -rf "$GONE2/../gonewt2"
O=$(bash "$D/preflight.sh" at-risk 2>&1)
chk "a gone worktree already on a remote is not at risk" "$O" "every commit in every worktree"

echo
echo "── 6be. a worktree label a reader can act on ──────────────────────"
# Two worktrees whose last TWO path components are identical used to render as the
# same string, with the discriminator one level above the window.
# The reported shape exactly: the last TWO components are identical on both, and the
# discriminator sits one level higher. An earlier version of this test used
# <side>/scratchpad, whose 2-component label is already unique -- so it passed against
# the very bug it was written for. Caught by mutation, 2026-08-23.
COL=$(newrepo); cd "$COL"; mkdir -p "$COL/../aaa" "$COL/../bbb"
for side in aaa bbb; do
  git worktree add -q --detach "$COL/../$side/scratchpad/board-flip" HEAD 2>/dev/null
  ( cd "$COL/../$side/scratchpad/board-flip" && echo "$side" > f."$side" && git add -A && git commit -qm "work in $side" )
done
O=$(bash "$D/preflight.sh" at-risk 2>&1)
chk "colliding labels are widened until unique" "$O" "aaa/scratchpad/board-flip"
chk "and the other side is distinguishable"     "$O" "bbb/scratchpad/board-flip"
[ "$(printf '%s' "$O" | grep -c 'AT RISK')" = "2" ] && ok "both worktrees get their own row" \
  || no "both worktrees get their own row" "$(printf '%s' "$O" | grep -c 'AT RISK') AT RISK rows"

echo
echo "── 6bf. a failed fetch is not a silent stale read ─────────────────"
# Every number at-risk prints depends on remote-tracking refs. If the fetch fails, they
# are stale and the check OVERSTATES -- work a peer already pushed reads as at risk.
FF=$(newrepo); cd "$FF"
git remote add broken /nope/no/such/remote
O=$(bash "$D/preflight.sh" at-risk 2>&1)
chk "a failed fetch is reported"            "$O" "git fetch FAILED"
chk "the direction of the error is named"   "$O" "OVERSTATES"

echo
echo "── 6bg. the worktree path reaches a SECOND parser ─────────────────"
# The call-sign is allowlisted; the PATH was only shell-escaped, and then handed to
# AppleScript, where `"` closes the string literal. A worktree named
#   X" & (do shell script "...") & "Y
# compiled as concatenation around a live call. Reported with an osacompile proof,
# 2026-08-23. The operator chooses the path, so "it is our own value" was never true.
INJ=$(newrepo); cd "$INJ"
EVILWT="$WORK/X\" & (do shell script \"echo INJECTED\") & \"Y"
mkdir -p "$EVILWT"
CAP="$WORK/osa.capture"; : > "$CAP"
# --window is required to reach an AppleScript parser at all now: the default path
# never builds one. Without the flag this test would pass by not executing the code it
# is meant to guard, which is the most expensive kind of green.
TERM_PROGRAM=Apple_Terminal STUB_OSA_CAPTURE="$CAP" \
  bash "$D/spawn-station.sh" BACKEND "$EVILWT" BACKEND --window --deploy >/dev/null 2>&1
CAPTXT=$(cat "$CAP" 2>/dev/null)
if [ -z "$CAPTXT" ]; then
  sk "AppleScript path escaping — no osascript recipe reached on this host"
else
  chk "the quote in the path is escaped for AppleScript" "$CAPTXT" 'X\" & (do shell script \"'
  case "$CAPTXT" in
    *'" & (do shell script "'*) no "the path cannot close the AppleScript literal" "unescaped quote survived" ;;
    *) ok "the path cannot close the AppleScript literal" ;;
  esac
fi

echo
echo "── 6c. detached HEAD and worktree wording ─────────────────────────"
git worktree add -q --detach "$REPO/.claude/worktrees/det" HEAD 2>/dev/null
O=$(cd "$REPO/.claude/worktrees/det" && bash "$D/mc-init.sh" 2>&1)
chk "detached HEAD says detached, not 'HEAD'"     "$O" "HEAD: detached @"
chk "dirty line names the worktree, not the checkout" "$O" "a worktree, not the shared checkout"
cd "$REPO"

echo
echo "── 6d. a displaced station must not call its fleet strangers ──────"
# Peers are classified by the peer's REGISTERED SESSION cwd, while the fleet id comes
# from where the command is RUNNING. Work outside your launch directory and every peer
# computes OFF-FLEET -- correctly computed from the wrong input. Reproduced from a
# scratch repo 2026-08-23: five live peers, all five called strangers, the coordinator
# among them. It cannot re-derive the right answer, so it must say it cannot classify.
if [ "$CP" -le 1 ]; then
  sk "displaced-station warning — no claude in the parent chain"
else
  DIS=$(newrepo)            # a repo that is NOT the registry cwd we are about to write
  ELSEWHERE=$(newrepo)
  TH2="$WORK/home2"; mkdir -p "$TH2/.claude/sessions"
  printf '{"pid":%s,"name":"DISPLACED","cwd":"%s"}' "$CP" "$ELSEWHERE" > "$TH2/.claude/sessions/$CP.json"
  cd "$DIS"
  O=$(HOME="$TH2" bash "$D/mc-init.sh" 2>&1)
  chk "the mismatch is announced"            "$O" "PEERS_WARNING"
  chk "it names the registered cwd"          "$O" "$ELSEWHERE"
  chk "it says the verdicts are unreliable"  "$O" "UNRELIABLE"
  chk "it warns against the wrong conclusion" "$O" "Do not conclude you have no"
  # and it must stay QUIET when the session really is where it says it is
  printf '{"pid":%s,"name":"HOMEBODY","cwd":"%s"}' "$CP" "$DIS" > "$TH2/.claude/sessions/$CP.json"
  O=$(HOME="$TH2" bash "$D/mc-init.sh" 2>&1)
  [ "$(printf '%s' "$O" | grep -c PEERS_WARNING)" = "0" ] \
    && ok "no warning when the cwd matches" || no "no warning when the cwd matches" "warned anyway"
fi

echo
# ONE ABSOLUTE cd PER SECTION. Never inherit the previous section's directory: 6d's cd
# is inside a conditional, so skipping it silently hands this section whatever 6bg left.
# A chained cd is how a coordinator produced a confident false FAILURE against a fix that
# was correct -- it ran case 2 in case 1's directory and got a warning comparing a path
# to itself (2026-08-23). The same shape bit the author of this file the same day. It is
# latent here rather than live, and it is being closed while it is still cheap.
cd "$REPO" || exit 1
echo "── 7. identity surfaces ───────────────────────────────────────────"
# BUILD THE REGISTRY, DO NOT DEPEND ON HAVING ONE. These three checks used to be
# wrapped in a skip that fired whenever no session registry entry could be found by
# walking up from this shell -- so they ran on the author's machine and silently
# vanished anywhere else, which is the worst of both: green locally, uncovered in the
# environment you actually wanted to test. Measured 2026-08-23 in a fresh-user
# simulation: 119 checks here, 116 + 1 skip under an empty $HOME.
#
# mc-init.sh's find_me() walks up from its own shell looking for
# $HOME/.claude/sessions/<pid>.json, and its parent is THIS script -- so an entry
# written for $$ is found on the second hop, with no claude ancestor required.
IDH="$WORK/idhome"; mkdir -p "$IDH/.claude/sessions"
printf '{"pid":%s,"name":"TESTSTATION","cwd":"%s"}' "$$" "$REPO" > "$IDH/.claude/sessions/$$.json"
O=$(HOME="$IDH" bash "$D/mc-init.sh" me 2>&1)
chk "own name readable locally, no radio call" "$O" "ME_NAME: TESTSTATION"
chk "the pid it resolved is reported"          "$O" "ME_PID: $$"
chk "ref pointed at the ListAgents self-line"  "$O" "self-line carries it"
chk "self-line NAME marked do-not-use"         "$O" "DO NOT USE"

# AND the degraded path, which was previously the reason to skip rather than a thing
# that was tested: no registry at all must say so plainly, not guess a name.
IDH2="$WORK/idhome-empty"; mkdir -p "$IDH2/.claude"
O=$(HOME="$IDH2" bash "$D/mc-init.sh" me 2>&1)
chk "no registry says unknown, not a guess"    "$O" "ME_PID: unknown"
chk "and says why, not just that it failed"    "$O" "no registry entry found"
# The tab surface, WITHOUT touching a tab. This test used to call the real label-tab.sh
# with a VALID call-sign -- so it passed the guards, walked the parent chain to the live
# tty, and osascript'd `set custom title` onto THE TESTER'S OWN Terminal tab. A field
# tester caught it and measured the change: [◐ Claude Code] -> [MCTEST], 2026-08-23.
# Two ways it hid. Claude Code rewrites the title at every status change, so on a plain
# session MCTEST is overwritten within the turn and nobody sees it -- but on a session
# run with CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1, which writes NO title of its own, the
# relabel is PERMANENT. And `tell application "Terminal"` LAUNCHES Terminal.app when it
# is not running, so on an iTerm2/Ghostty/VS Code host this opened a terminal outright.
# Both halves of the header's promise, broken by one line, 100 lines after 6a took care
# to copy set-callsign.sh away from label-tab.sh for exactly this reason.
# Stub osascript instead -- same pattern as tmux and wt.exe above. It exercises MORE of
# the script than the live call did, because the tty match can now be made to fail.
O=$(PATH="$STUB:$PATH" CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 bash "$D/label-tab.sh" MCTEST 2>&1)
chk "the tab label names the tty it matched"    "$O" "-> MCTEST"
chk "persistence is reported, not assumed"      "$O" "persists:"
chk "disabled title writes read as durable"     "$O" "persists: YES"
# The VERDICT must stay FLAT for the un-durable case. It briefly read "PROBABLY NOT",
# hedged because the overwrite was once measured not to happen -- but SKILL.md enforces
# "never report a tab as labelled unless this line agrees", and a station can talk itself
# past "probably not" where it cannot talk itself past "no". The uncertainty belongs in
# the explanation, not the verdict. Caught 2026-08-23 by a station that ran this twice
# across the change and saw the verdict move while its own session had not.
O2=$(PATH="$STUB:$PATH" bash "$D/label-tab.sh" MCTEST 2>&1)
case "$O2" in
  *"persists: NO"*|*"persists: YES"*) ok "the persistence verdict is flat, never hedged" ;;
  *) no "the persistence verdict is flat, never hedged" "$O2" ;;
esac
O=$(PATH="$STUB:$PATH" STUB_OSA_NOMATCH=1 bash "$D/label-tab.sh" MCTEST 2>&1); RC=$?
chk "an unmatched tty is reported, not faked"   "$O" "NO-MATCH"
[ $RC -eq 1 ] && ok "no matching tab is an error (exit 1)" || no "no matching tab is an error" "exit $RC"

echo
echo "── 7b. the first-run tour appears once, and only once ─────────────"
# The flag lives in the USER'S OWN preferences file, so every check here runs under a
# fake $HOME. A test that can write to ~/.claude/mission-control.json is a test that can
# silently switch off somebody's first run -- or worse, truncate a hand-written config.
TS="$D/tour-state.sh"
if [ ! -f "$TS" ]; then
  sk "first-run tour — tour-state.sh not present"
else
  TT="$WORK/tourhome"; mkdir -p "$TT/.claude"
  REALCFG="$HOME/.claude/mission-control.json"
  REALSUM=$(shasum -a 256 "$REALCFG" 2>/dev/null | cut -d' ' -f1)

  chk "a fresh machine is offered the tour"  "$(HOME="$TT" bash "$TS" read)"     "not taken"
  chk "completing it is recorded"            "$(HOME="$TT" bash "$TS" complete)" "completed"
  chk "and it never offers again"            "$(HOME="$TT" bash "$TS" read)"     "TOUR: taken"
  chk "reset puts it back"                   "$(HOME="$TT" bash "$TS" reset)"    "reset"
  chk "declining is ALSO terminal"           "$(HOME="$TT" bash "$TS" decline; HOME="$TT" bash "$TS" read)" "TOUR: taken"

  # A config is somebody's own file. The flag must be the ONLY thing that changes.
  HOME="$TT" bash "$TS" reset >/dev/null
  cat > "$TT/.claude/mission-control.json" <<'CFGJ'
{ "_comment": "hand written, do not lose me", "spawn": { "terminal": "Apple_Terminal" } }
CFGJ
  HOME="$TT" bash "$TS" complete >/dev/null
  O=$(python3 -c "import json;d=json.load(open('$TT/.claude/mission-control.json'));print(d.get('_comment',''),d.get('spawn',{}).get('terminal',''),'tour' in d)")
  chk "existing preferences survive the write" "$O" "hand written, do not lose me Apple_Terminal True"

  # An unparseable config is a file with something in it. Re-offering a tour is a smaller
  # harm than truncating somebody's settings.
  printf 'not json {{{' > "$TT/.claude/mission-control.json"
  chk "an unreadable config is not overwritten" "$(HOME="$TT" bash "$TS" complete)" "could not be parsed"
  chk "and its bytes are left alone"            "$(cat "$TT/.claude/mission-control.json")" "not json {{{"

  # mc-init must SURFACE the flag -- the tour has no other trigger.
  cd "$REPO"
  rm -f "$TT/.claude/mission-control.json"
  chk "mc-init surfaces the tour state"  "$(HOME="$TT" bash "$D/mc-init.sh" 2>&1)" "TOUR: not taken"
  HOME="$TT" bash "$TS" complete >/dev/null
  chk "and reports it taken once it is"  "$(HOME="$TT" bash "$D/mc-init.sh" 2>&1)" "TOUR: taken"

  # THE POINT OF THE FAKE HOME.
  NOWSUM=$(shasum -a 256 "$REALCFG" 2>/dev/null | cut -d' ' -f1)
  [ "$REALSUM" = "$NOWSUM" ] && ok "the tester's own preferences were never touched" \
    || no "the tester's own preferences were never touched" "$REALSUM -> $NOWSUM"
fi

echo
echo "── 7c. the stack check belongs to the project, not to one stack ───"
# Its defaults were ONE project's services -- db:5432, redis:6379, minio:9000 -- hardcoded into
# a tool meant for anybody, and it died outright on any project without Docker. A health check
# that fails because you are not containerised reads as a broken stack.
NOPATH="$WORK/nopath"; mkdir -p "$NOPATH"
O=$(PATH="$NOPATH:/usr/bin:/bin" bash "$D/preflight.sh" stack 2>&1); RC=$?
chk "no docker is not a failure"            "$O" "does not appear to use containers"
[ $RC -eq 0 ] && ok "and it exits clean (0)" || no "and it exits clean (0)" "exit $RC"
chk "it still teaches the rule it exists for" "$O" "A SOCKET IS"
cd "$REPO"                                   # a git repo with no compose file
O=$(bash "$D/preflight.sh" stack 2>&1); RC=$?
chk "no compose file is not a failure"      "$O" "declares no compose file"
[ $RC -eq 0 ] && ok "that exits clean too"  || no "that exits clean too" "exit $RC"
# COUNT ONLY CODE, NOT THE COMMENT THAT EXPLAINS THE REMOVAL. First version of this check
# grepped the whole file and counted the service names inside the note saying why they are
# gone -- the exact inverted check this repo catalogued hours earlier: a count cannot tell
# live code from a comment documenting its own removal.
HARDCODED=$(grep -v '^[[:space:]]*#' "$D/preflight.sh" | grep -c 'minio:9000\|redis:6379\|db:5432')
[ "$HARDCODED" = "0" ] && ok "no project's own services are hardcoded" \
  || no "no project's own services are hardcoded" "$HARDCODED in executable lines"
[ "$(grep -v '^[[:space:]]*#' "$D/preflight.sh" | grep -c MC_STACK_TARGETS)" -ge 1 ] \
  && ok "targets are overridable by env" || no "targets are overridable by env" "no MC_STACK_TARGETS in code"

echo
echo "── 8. the other three skills: two roots, not one ──────────────────"
# THE ONLY AUTOMATED COVERAGE work-lock, status-and-backlog and progress-and-log have.
# Everything else in them is prose. This is the part that is CODE, and it is where the
# worst regression of 2026-08-23 lived: a fix that pointed the write root at the main
# repo, so a station in a lane would have edited the SHARED checkout instead of its own,
# and bootstrapped files outside the branch they belong to. Three skills, same shape.
#
# The rule being pinned: `--git-common-dir` for what is REMEMBERED once,
# `--show-toplevel` for anything WRITTEN or committed. One variable cannot be both.
#
# Blocks are EXTRACTED FROM THE SKILL FILES, never retyped -- a test that retypes the
# code under test is testing the typist.
SKROOT=$(cd "$D/../.." && pwd)
extract_roots(){ sed -n '/^\(PROJECT_\)\{0,1\}ROOT=/,/^esac/p' "$1"; }   # \? and \$( are not portable BSD BRE

# one repo, one linked worktree, a bare repo and a non-git dir
# Resolve RT to its REAL path. On macOS $TMPDIR is a symlink (/var -> /private/var), and
# the blocks under test normalise with `cd`+`pwd` while a raw "$WORK/roots" does not -- so
# comparing them fails on six correct results. Same class as everything else caught today:
# the instrument disagreed with itself, not with the code.
RT="$WORK/roots"; mkdir -p "$RT"; RT=$(cd "$RT" && pwd -P)
( cd "$RT" && git init -q proj 2>/dev/null )
( cd "$RT/proj" && git config user.email t@e.com && git config user.name t \
  && echo a > f && git add -A && git commit -qm i && mkdir -p sub \
  && git worktree add -q "$RT/proj/wt" -b lane ) >/dev/null 2>&1
git init -q --bare "$RT/bare.git" >/dev/null 2>&1; mkdir -p "$RT/plain"

for SK in work-lock status-and-backlog progress-and-log; do
  F="$SKROOT/skills/$SK/SKILL.md"
  if [ ! -f "$F" ]; then sk "$SK — skill not found beside the one under test"; continue; fi
  BLK=$(extract_roots "$F")
  if [ -z "$BLK" ]; then no "$SK exposes a root-resolution block" "no block matched"; continue; fi

  roots_at(){ ( cd "$1" 2>/dev/null || exit 1; eval "$BLK" >/dev/null 2>&1
                printf '%s|%s' "${PROJECT_ROOT:-$ROOT}" "$SHARED_ROOT" ); }
  MAIN=$(roots_at "$RT/proj");  MAIN_W=${MAIN%%|*};  MAIN_S=${MAIN##*|}
  WT=$(roots_at "$RT/proj/wt"); WT_W=${WT%%|*};      WT_S=${WT##*|}
  SUB=$(roots_at "$RT/proj/sub")
  BARE=$(roots_at "$RT/bare.git"); BARE_W=${BARE%%|*}

  # THE ACCEPTANCE PAIR. Same remembered root from both places, different write root
  # inside the worktree. That pair IS the bug; either half alone passes on a broken build.
  [ "$WT_S" = "$MAIN_S" ] && ok "$SK: worktree and main repo share one remembered root" \
    || no "$SK: worktree and main repo share one remembered root" "$WT_S vs $MAIN_S"
  [ "$WT_W" != "$MAIN_W" ] && ok "$SK: a worktree still writes to its OWN checkout" \
    || no "$SK: a worktree still writes to its OWN checkout" "both $WT_W"
  # the write root must be the worktree itself, not merely different
  [ "$WT_W" = "$RT/proj/wt" ] && ok "$SK: the write root is the worktree, exactly" \
    || no "$SK: the write root is the worktree, exactly" "$WT_W"
  # a subdirectory resolves like its repo
  [ "${SUB%%|*}" = "$MAIN_W" ] && ok "$SK: a subdirectory resolves to its repo" \
    || no "$SK: a subdirectory resolves to its repo" "${SUB%%|*}"
  # dirname on a bare repo escapes it unless guarded
  [ "$BARE_W" = "$RT/bare.git" ] && ok "$SK: a bare repo is not escaped" \
    || no "$SK: a bare repo is not escaped" "$BARE_W"
done

echo
printf '── %d passed · %d failed · %d skipped ─────────────────────────────\n' $PASS $FAIL $SKIP
[ $FAIL -eq 0 ]
