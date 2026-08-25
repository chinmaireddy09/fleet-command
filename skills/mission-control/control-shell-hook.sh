#!/bin/bash
# control-shell-hook.sh — make a bare `claude` come up ALREADY NAMED as the coordinator.
#
# ── THE PROBLEM THIS IS THE ONLY REAL FIX FOR ────────────────────────────────────
# A session's `@` envelope -- the name stamped on every message it sends -- is frozen at
# process launch and is set by exactly ONE thing: the `--name` flag on the command line.
# Measured 2026-08-24: CLAUDE_CODE_SESSION_NAME exists in the binary and DOES NOT set it
# (a bg session launched with it came up named `5708410f`, nameSource absent). No setting,
# no config file, no in-session command reaches the value.
#
# And Control is the one post that can never pass the flag itself: Control is whoever runs
# `/mc`, so at launch there was no call-sign to pass -- the decision had not been made yet.
# Releases 7.9.0 and 7.10.0 tried asking the user to relaunch. That was rejected, correctly:
# it asks, on every fleet forever, for something that could not have been done in advance.
# 7.11.0 stopped asking and published the mismatch instead, which removes the COST but
# leaves the header wrong.
#
# THIS REMOVES THE MISMATCH ITSELF, by supplying the flag before the process exists. The
# user types the same three words they always typed:
#
#     cd <repo> && claude          -> becomes `claude --name CONTROL`
#     /mc                          -> comes on watch, header ALREADY correct
#
# ── WHY THE TRIGGER IS "NO ARGUMENTS AT ALL" ────────────────────────────────────
# Claude Code re-executes ITSELF for internal work -- `claude daemon run ...`,
# `claude bg-pty-host ...`, `claude bg-spare ...` were all observed live on this machine.
# A wrapper that injected a flag into those would corrupt the harness's own plumbing. So
# the rule is deliberately the narrowest one that still covers the workflow: fire ONLY on a
# bare `claude` with zero arguments, at an interactive terminal. Anything else -- a flag, a
# subcommand, a pipe, `-p`, `--resume`, `--bg` -- passes through untouched, byte for byte.
#
# ── THE ONE TRAP THIS CREATES, AND WHERE IT IS CAUGHT ───────────────────────────
# This names a bare session after the COORDINATOR, because that is what a bare session in a
# repo with no live coordinator almost always is. If the human meant to raise a STATION and
# types `/mc identify CHANNELS`, the address moves to CHANNELS while the envelope stays frozen
# at CONTROL -- and CONTROL is a REAL call-sign, not a dead machine handle. A peer replying to
# that header does not bounce; it reaches the ACTUAL coordinator. That is the only envelope
# fault in this skill that MISDELIVERS rather than failing loudly.
#
# It cannot be prevented here: at launch there is no way to know which the user meant. It is
# caught at the moment intent becomes visible instead -- `set-callsign.sh` compares the launch
# name against the call-sign being taken and refuses to be quiet about a mismatch. There the
# relaunch IS answerable, because a station knows its call-sign; and `/mc deploy <STATION>`
# never produces the trap at all, since it launches --name X and identifies as the same X.
#
# ── AND IT NEVER CLAIMS A NAME SOMEBODY ELSE ANSWERS TO ─────────────────────────
# If a live session already answers to the coordinator name in this repo, this does nothing
# and the session comes up bare, exactly as today. Two sessions sharing one address is a
# worse failure than a wrong envelope: a peer's message would reach whichever one the
# harness picked. First session in a repo becomes Control; the second does not.
#
# INSTALL (idempotent, prints what it did):
#     bash <skill-dir>/control-shell-hook.sh --install
# REMOVE:
#     bash <skill-dir>/control-shell-hook.sh --uninstall
# The install appends one `source` line to ~/.zshrc (or ~/.bashrc) and nothing else.

set -u

HOOK_MARK="# >>> fleet-command control-shell-hook >>>"
HOOK_END="# <<< fleet-command control-shell-hook <<<"
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# ── the function that actually runs in the user's shell ─────────────────────────
# Written to be sourced. Everything is guarded; on ANY doubt it runs the real claude
# unchanged, because a shell wrapper that can break `claude` is worse than a wrong header.
emit_function() {
  cat <<'FUNC'
claude() {
  # ONLY a bare `claude`, at a terminal. Any argument at all -> untouched passthrough.
  # This is what keeps the harness's own `claude daemon run` / `bg-pty-host` re-execs safe.
  if [ "$#" -ne 0 ] || [ ! -t 0 ] || [ ! -t 1 ]; then
    command claude "$@"; return $?
  fi

  local _mc_root _mc_name _mc_sessions _mc_taken
  _mc_root=$(git rev-parse --show-toplevel 2>/dev/null) || { command claude; return $?; }
  [ -n "$_mc_root" ] || { command claude; return $?; }
  # A worktree under .claude/worktrees belongs to a STATION, not to Control. Coming up as
  # Control there would claim the coordinator's address from inside somebody's lane.
  case "$_mc_root" in */.claude/worktrees/*) command claude; return $?;; esac

  # The coordinator this project actually uses: its own MISSION-CONTROL.md wins, then the
  # user's recorded preference, then CONTROL. Never invent one, and never ask here -- a
  # shell prompt is not the place for a question.
  _mc_name=""
  for _f in "$_mc_root/docs/MISSION-CONTROL.md" "$_mc_root/MISSION-CONTROL.md" "$_mc_root/.claude/MISSION-CONTROL.md"; do
    if [ -f "$_f" ]; then
      _mc_name=$(grep -im1 '^[[:space:]>*|-]*coordinator[[:space:]|*]*[:=|]' "$_f" 2>/dev/null \
        | sed -E 's/^[[:space:]>*|-]*[Cc]oordinator[[:space:]|*]*[:=|][[:space:]*]*//' \
        | tr -d '`*|' | sed -E 's/[[:space:]]+$//')
      [ -n "$_mc_name" ] && break
    fi
  done
  if [ -z "$_mc_name" ] && [ -f "$HOME/.claude/mission-control.json" ]; then
    _mc_name=$(python3 -c "
import json,sys
try:
    d=json.load(open('$HOME/.claude/mission-control.json'))
except Exception: raise SystemExit
n=(d.get('naming') or {})
v=n.get('coordinator') or d.get('coordinator') or ''
print(v if isinstance(v,str) else '')" 2>/dev/null)
  fi
  [ -n "$_mc_name" ] || _mc_name="CONTROL"
  # A session name cannot contain spaces. If the project's call-sign does, leave it alone
  # rather than inventing somebody's short form for them.
  case "$_mc_name" in *[!A-Za-z0-9_-]*) command claude; return $?;; esac

  # DO NOT CLAIM A LIVE NAME. Two sessions on one address is worse than a wrong envelope.
  _mc_sessions="$HOME/.claude/sessions"
  _mc_taken=""
  if [ -d "$_mc_sessions" ]; then
    _mc_taken=$(MC_WANT="$_mc_name" python3 -c "
import glob,json,os
want=os.environ['MC_WANT'].lower()
for f in glob.glob(os.path.expanduser('~/.claude/sessions/*.json')):
    try: d=json.load(open(f))
    except Exception: continue
    if str(d.get('name','')).lower()!=want: continue
    try: os.kill(int(d.get('pid',0)),0)
    except ProcessLookupError: continue
    except PermissionError: pass
    except Exception: continue
    print('taken'); break" 2>/dev/null)
  fi
  if [ -n "$_mc_taken" ]; then
    command claude; return $?
  fi

  command claude --name "$_mc_name"
}
FUNC
}

case "${1:-}" in
  --print) emit_function; exit 0 ;;
  --install)
    RC="$HOME/.zshrc"; [ -n "${BASH_VERSION:-}" ] && [ ! -f "$RC" ] && RC="$HOME/.bashrc"
    [ -f "$RC" ] || : > "$RC"
    if grep -qF "$HOOK_MARK" "$RC" 2>/dev/null; then
      echo "already installed in $RC — nothing changed"
      echo "  (the hook sources this file, so edits here are live in every NEW shell)"
      exit 0
    fi
    {
      echo ""
      echo "$HOOK_MARK"
      echo "[ -f '$SELF' ] && eval \"\$(bash '$SELF' --print)\""
      echo "$HOOK_END"
    } >> "$RC"
    echo "installed in $RC"
    echo "  A bare \`claude\` inside a git repo now launches as the coordinator."
    echo "  Open a NEW terminal, or run:  source $RC"
    exit 0 ;;
  --uninstall)
    for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
      [ -f "$RC" ] || continue
      grep -qF "$HOOK_MARK" "$RC" || continue
      python3 - "$RC" "$HOOK_MARK" "$HOOK_END" <<'PY'
import sys
p,a,b=sys.argv[1],sys.argv[2],sys.argv[3]
lines=open(p).read().splitlines(True)
out=[];skip=False
for ln in lines:
    if ln.strip()==a: skip=True; continue
    if ln.strip()==b: skip=False; continue
    if not skip: out.append(ln)
while out and out[-1].strip()=="": out.pop()
open(p,"w").write("".join(out)+"\n")
PY
      echo "removed from $RC"
    done
    echo "Open a new terminal, or unset it now with:  unset -f claude"
    exit 0 ;;
  *)
    echo "usage: control-shell-hook.sh --install | --uninstall | --print" >&2
    echo "" >&2
    echo "Makes a bare \`claude\` in a git repo come up already named as the coordinator," >&2
    echo "so Control's \`@\` header is correct from birth. The envelope is set at launch by" >&2
    echo "--name and by nothing else (measured), so supplying the flag is the only fix." >&2
    exit 2 ;;
esac
