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
# board, never opens a terminal, and never renames a live session -- the one test that
# needs a name collision derives it from whatever is already running and SKIPS when
# nothing is, because a test that mutates live state to prove a point is worse than an
# untested line.
set -uo pipefail

D="${1:-$(cd "$(dirname "$0")/../skills/mission-control" && pwd)}"
[ -f "$D/mc-init.sh" ] || { echo "no mission-control skill at: $D" >&2; exit 2; }
command -v git >/dev/null || { echo "git is required" >&2; exit 2; }
command -v python3 >/dev/null || { echo "python3 is required" >&2; exit 2; }

PASS=0; FAIL=0; SKIP=0
if [ -t 1 ]; then G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; Z=$'\033[0m'; else G=; R=; Y=; Z=; fi
ok(){ printf '  %sPASS%s  %s\n' "$G" "$Z" "$1"; PASS=$((PASS+1)); }
no(){ printf '  %sFAIL%s  %s\n        got: %s\n' "$R" "$Z" "$1" "$(printf '%s' "$2" | head -2 | tr '\n' ' ')"; FAIL=$((FAIL+1)); }
sk(){ printf '  %sSKIP%s  %s\n' "$Y" "$Z" "$1"; SKIP=$((SKIP+1)); }
chk(){ case "$2" in *"$3"*) ok "$1";; *) no "$1" "$2";; esac; }

WORK=$(mktemp -d); trap 'cd /; rm -rf "$WORK"' EXIT
STUB="$WORK/stub"; mkdir -p "$STUB"
for b in tmux wt.exe; do
  printf '#!/bin/bash\nexit ${STUB_RC:-0}\n' > "$STUB/$b"; chmod +x "$STUB/$b"
done

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
chk "print path yields a paste-able launch line" \
    "$(bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND --print 2>&1)" \
    "claude --name 'BACKEND' '/mc identify BACKEND'"
O=$(PATH="$STUB:$PATH" TMUX="x,1,0" bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND 2>&1)
chk "tmux opens a window"                    "$O" "TMUX WINDOW OPENED"
chk "tmux does not claim a station"          "$O" "NOT YET A STATION"
O=$(PATH="$STUB:$PATH" STUB_RC=1 TMUX="x,1,0" bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND 2>&1)
chk "tmux refusing falls back to printing"   "$O" "CANNOT AUTOMATE HERE"
O=$(PATH="$STUB:$PATH" WT_SESSION=1 bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND 2>&1)
chk "windows terminal opens a tab"           "$O" "WT TAB OPENED"
chk "windows recipe admits it is unverified" "$O" "UNVERIFIED"
O=$(TERM_PROGRAM=vscode bash "$D/spawn-station.sh" BACKEND "$REPO" BACKEND 2>&1); RC=$?
chk "an unsupported host prints instead"     "$O" "CANNOT AUTOMATE HERE"
[ $RC -eq 0 ] && ok "no recipe is not an error (exit 0)" || no "no recipe is not an error" "exit $RC"

echo
echo "── 6. the guards ──────────────────────────────────────────────────"
chk "AppleScript injection refused"    "$(bash "$D/label-tab.sh" 'A"; do shell script "x' 2>&1)" "FAILED:"
chk "shell injection refused"          "$(bash "$D/spawn-station.sh" 'A`whoami`' "$REPO" X --print 2>&1)" "FAILED:"
chk "over-long call-sign refused"      "$(bash "$D/label-tab.sh" "$(python3 -c 'print("A"*70)')" 2>&1)" "too long"
chk "spaced call-sign needs a handle"  "$(bash "$D/set-callsign.sh" 'FLEET COMMAND' 2>&1)" "needs a handle"
chk "missing worktree refused"         "$(bash "$D/spawn-station.sh" X /nope/nope X --print 2>&1)" "no such worktree"
LIVE=$(python3 - "$$" <<'PY'
import glob,json,os,sys
for f in glob.glob(os.path.expanduser("~/.claude/sessions/*.json")):
    try: d=json.load(open(f))
    except Exception: continue
    try: os.kill(int(d["pid"]),0)
    except Exception: continue
    n=d.get("name")
    if n: print(n); break
PY
)
# Derived from live state on purpose: a hardcoded name passes or fails depending on
# who happens to be running, and when the name is FREE set-callsign.sh succeeds and
# renames the session running the test. Measured that happening 2026-08-23.
if [ -n "$LIVE" ]; then
  chk "live call-sign clash refused ($LIVE)" "$(bash "$D/set-callsign.sh" "$LIVE" 2>&1)" "REFUSED"
else
  sk "live call-sign clash — no live session to clash with"
fi

echo
echo "── 7. identity surfaces ───────────────────────────────────────────"
O=$(bash "$D/mc-init.sh" me 2>&1)
if printf '%s' "$O" | grep -q "ME_PID: unknown"; then
  sk "identity checks — not running inside a registered session"
else
  chk "own name readable locally, no radio call" "$O" "ME_NAME:"
  chk "ref pointed at the ListAgents self-line"  "$O" "self-line carries it"
  chk "self-line NAME marked do-not-use"         "$O" "DO NOT USE"
fi
O=$(bash "$D/label-tab.sh" MCTEST 2>&1)
case "$O" in
  *"persists:"*)  ok "tab persistence reported honestly" ;;
  *"skipped"*|*"NO-MATCH"*) sk "tab label — no addressable terminal here" ;;
  *) no "tab persistence reported honestly" "$O" ;;
esac

echo
printf '── %d passed · %d failed · %d skipped ─────────────────────────────\n' $PASS $FAIL $SKIP
[ $FAIL -eq 0 ]
