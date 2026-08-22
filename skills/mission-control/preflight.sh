#!/bin/bash
# preflight.sh <check> — the checks that were got wrong by hand, shipped as code.
#
# Every failure this replaces was somebody writing a one-off command and trusting
# it. The rules telling you to check carefully already existed; what did not exist
# was a correct check you could run instead of inventing one. Run these; do not
# re-derive them.
#
#   stack            are the shared services ACTUALLY up and reachable
#   at-risk [repo]   what exists here and nowhere else
#   baseline <file> <n>   extract a gate baseline and prove it came out whole
#   peers            who is live, by registry -- never by a message's from-name
set -uo pipefail

die() { echo "FAIL: $*" >&2; exit 1; }
ok()  { echo "  ok   $*"; }
bad() { echo "  FAIL $*"; FAILED=1; }
FAILED=0

check_stack() {
  command -v docker >/dev/null || die "no docker binary"
  docker info >/dev/null 2>&1 || die "docker daemon unreachable -- the socket is absent, not sick. 'open -a Docker' on macOS"
  echo "docker daemon: $(docker info --format '{{.ServerVersion}}')"

  # -a is the whole point: WITHOUT it, a container that has died and been reaped
  # simply has no line, and absence of a line reads as nothing wrong. That is how
  # a 135-second MinIO lifetime was reported as healthy by two independent sessions.
  echo "services (ps -a, so the dead are visible too):"
  docker compose ps -a --format '{{.Service}}|{{.State}}|{{.Status}}' 2>/dev/null | while IFS='|' read -r s st stat; do
    printf '  %-14s %-9s %s\n' "$s" "$st" "$stat"
  done

  # A status column is a claim. A socket is evidence.
  local probe_from
  probe_from=$(docker compose ps --services --filter status=running 2>/dev/null | head -1)
  [ -z "$probe_from" ] && die "nothing running to probe from"
  echo "reachability, probed from inside the network (not read off a column):"
  local targets=("$@"); [ ${#targets[@]} -eq 0 ] && targets=(db:5432 redis:6379 minio:9000)
  for target in "${targets[@]}"; do
    local host=${target%%:*} port=${target##*:}
    if docker compose exec -T "$probe_from" sh -lc "timeout 4 bash -c '</dev/tcp/$host/$port'" >/dev/null 2>&1; then
      ok "$target reachable"
    else
      bad "$target UNREACHABLE -- a gate run now produces failures that look like regressions"
    fi
  done

  local free; free=$(df -Pk . | awk 'NR==2{print int($4/1048576)}')
  [ "$free" -lt 5 ] && bad "only ${free}GiB free -- 'docker compose run' leaks a container per invocation; at 0 the daemon refuses to start" || ok "${free}GiB free"
  return $FAILED
}

check_at_risk() {
  git rev-parse --git-dir >/dev/null 2>&1 || die "not a git repo"
  git fetch -q --all 2>/dev/null
  echo "commits that exist HERE AND NOWHERE ELSE:"
  echo "  (--not --remotes, i.e. content. NOT 'rev-list --count origin/main..HEAD',"
  echo "   which counts reachability and reports danger for work already upstream)"
  local any=0
  for wt in $(git worktree list --porcelain | awk '/^worktree /{print $2}'); do
    local n b
    n=$(git -C "$wt" rev-list --count HEAD --not --remotes 2>/dev/null) || continue
    # NAME THE WORKTREE, NOT JUST THE BRANCH. A detached worktree's branch is the
    # literal string "HEAD", so a fleet with six detached scratchpads printed six
    # rows all labelled HEAD -- and the one question a reader has here is WHICH
    # DIRECTORY holds the work, because that is the directory they must not remove.
    # Reported 2026-08-23 by a coordinator ten seconds from deleting a live
    # station's only copy of its own board row, held in a detached scratchpad.
    b=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)
    [ "$b" = "HEAD" ] && b="detached"
    b="$b  $(basename "$(dirname "$wt")")/$(basename "$wt")"
    if [ "${n:-0}" != "0" ]; then
      # `git cherry` marks + for "no equivalent upstream" and - for "already there
      # under a different sha". Without this, six doc commits whose content had
      # already landed read as a day of exposure. Reachability is not content.
      local up ours dupes
      # No upstream set: fall back to the repo's real base ref, not a guessed
      # "origin/main". On a master/trunk repo, or one whose remote is not called
      # origin, the old fallback compared against a ref that does not exist and
      # reported everything as at risk.
      up=$(git -C "$wt" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || up=""
      if [ -z "$up" ]; then
        r=$(git -C "$wt" remote 2>/dev/null | grep -qx origin && echo origin || git -C "$wt" remote 2>/dev/null | head -1)
        if [ -n "$r" ]; then
          up=$(git -C "$wt" symbolic-ref -q --short "refs/remotes/$r/HEAD" 2>/dev/null)
          if [ -z "$up" ]; then
            for c in main master trunk develop; do
              git -C "$wt" rev-parse --verify -q "$r/$c" >/dev/null 2>&1 && { up="$r/$c"; break; }
            done
          fi
        fi
      fi
      [ -z "$up" ] && up="HEAD"   # no remote anywhere: nothing to be at risk against
      # WHAT IS PRINTED MUST HAVE THE SAME BASIS AS THE GATE ABOVE, AND UNTIL
      # 2026-08-23 IT DID NOT. `n` is content across ALL remotes -- correct, and the
      # thing the header two lines up promises. `ours` was `git cherry "$up"`, which
      # is reachability against ONE ref, so every commit merged in from the base
      # branch and not yet pushed on THIS branch was marked +. The correct number was
      # computed, used only as an entry gate, and then thrown away in favour of the
      # wrong one. Reported and reproduced by a coordinator: 7 commits reported at
      # risk, all seven confirmed on origin/main, truth was 1.
      #
      # It failed in the dangerous direction -- INFLATING risk -- and this repo had
      # already had one false at-risk alarm. A tool that cries wolf about lost work is
      # one a station stops reading on the night something really is lost. It also
      # contradicted the hand-run command this skill tells stations to trust:
      # `git log HEAD --not --remotes` returned 1 while this printed 7.
      #
      # So: the LIST is the --not --remotes set. `cherry` is kept for the one thing it
      # is actually good at -- spotting a commit whose CONTENT already landed under a
      # different sha, which --not --remotes cannot see -- and is used only to move
      # commits OUT of the at-risk list, never to put them in.
      local dup_shas at_risk_list dupe_n
      dup_shas=$(git -C "$wt" cherry "$up" 2>/dev/null | awk '/^-/{print $2}')
      at_risk_list=""; ours=0; dupe_n=0
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        local sha="${line%% *}"
        if [ -n "$dup_shas" ] && printf '%s\n' "$dup_shas" | grep -q "^$sha$"; then
          dupe_n=$((dupe_n+1))
        else
          at_risk_list="$at_risk_list$line
"
          ours=$((ours+1))
        fi
      done <<EOF
$(git -C "$wt" log --format='%H %s' HEAD --not --remotes 2>/dev/null)
EOF
      dupes=$dupe_n
      if [ "${ours:-0}" = "0" ]; then
        printf '  safe     %-46s %s commit(s) exist only here, but ALL content is already on a remote\n' "$b" "$n"
        [ "${dupes:-0}" != "0" ] && printf '           (%s duplicate by content -- stale, not lost)\n' "$dupes"
      else
        printf '  AT RISK  %-46s %s commit(s) on no remote, by content\n' "$b" "$ours"
        printf '%s' "$at_risk_list" | sed 's/^/           /'
        [ "${dupes:-0}" != "0" ] && printf '           (%s more exist only here but are duplicates by content -- stale, not lost)\n' "$dupes"
        any=1
      fi
    fi
  done
  [ "$any" = "0" ] && ok "every commit in every worktree exists on a remote"
  # TRACKED AND UNTRACKED ARE NOT THE SAME RISK, AND THIS USED TO ADD THEM UP.
  # `git status --porcelain | wc -l` counts a modified source file and a scratch
  # gate log identically, and the total was printed under "uncommitted work (dies
  # with a tidy-up)". Reported 2026-08-23 by a coordinator that had to check all
  # thirteen worktrees by hand to establish that six flagged files were ALL gate
  # logs and not one line of source was at risk. The header did the damage: it is
  # the sentence that makes a reader think source is in danger.
  #
  # This skill's own rule: a check must be able to observe the thing it claims to
  # measure. This was observing `git status` and reporting "work".
  echo "uncommitted work:"
  local any=0
  for wt in $(git worktree list --porcelain | awk '/^worktree /{print $2}'); do
    local st tracked untracked
    st=$(git -C "$wt" status --porcelain 2>/dev/null)
    [ -z "$st" ] && continue
    untracked=$(printf '%s\n' "$st" | grep -c '^??')
    tracked=$(printf '%s\n' "$st" | grep -vc '^??')
    any=1
    if [ "$tracked" != "0" ]; then
      printf '  %-34s %s tracked file(s) MODIFIED  <- real work, lost by a checkout or reset\n' "$(basename "$wt")" "$tracked"
    fi
    if [ "$untracked" != "0" ]; then
      printf '  %-34s %s untracked file(s)          scratch until added; lost only to `git clean`\n' "$(basename "$wt")" "$untracked"
    fi
  done
  [ "$any" = "0" ] && echo "  none -- no tracked modifications and no untracked files anywhere"
  echo "  (untracked is NOT automatically at risk. Gate logs and scratch live here."
  echo "   Do not report a station as having work in danger on an untracked count alone.)"
  return 0
}

check_baseline() {
  local file="${1:?usage: preflight.sh baseline <file> <expected-count>}"
  local want="${2:?expected count is required -- 'non-empty' is not the check}"
  FILE="$file" WANT="$want" python3 - <<'PY'
import re,io,os,sys
f=os.environ["FILE"]; want=int(os.environ["WANT"])
doc=io.open(f,encoding="utf-8").read()
# Anchored at line start. A bare substring also matches the file's own backticked
# examples of its own heading -- that returned a zero-name baseline and 21 phantom
# NEW failures, and a hardcoded line range before it returned 17 of 21.
m=re.search(r'^##\s+Current baseline', doc, re.M)
if not m: sys.exit("FAIL: no '## Current baseline' anchored at line start")
fence=re.search(r'```(?:text)?\n(.*?)```', doc[m.end():], re.S)
if not fence: sys.exit("FAIL: no fence under the heading")
names=[l.strip() for l in fence.group(1).splitlines() if l.strip() and not l.strip().startswith('#')]
print(f"  extracted {len(names)} names, expected {want}")
if len(names)!=want:
    sys.exit(f"FAIL: extraction is wrong, ABORT before diffing. "
             f"A short baseline is LOUD (phantom NEW); a long one is SILENT (phantom FIXED), "
             f"and nobody checks the silent direction.")
print("  ok   baseline extracted whole")
PY
}

check_peers() {
  python3 - <<'PY'
import glob,json,os
rows=[]
for f in glob.glob(os.path.expanduser("~/.claude/sessions/*.json")):
    try: d=json.load(open(f))
    except Exception: continue
    try: os.kill(int(d["pid"]),0)
    except Exception: continue
    rows.append(d)
if not rows: print("  no live sessions"); raise SystemExit
print("  live sessions (the registry IS the truth):")
for d in sorted(rows,key=lambda x:x.get("startedAt",0)):
    cwd=d["cwd"].replace(os.path.expanduser("~"),"~")
    print(f"    {d['name']:<14} src={str(d.get('nameSource')):<8} {cwd}")
print()
print("  NEVER reply to a message's from-name: it is captured when the channel")
print("  opens, so after the sender renames it no longer resolves and the reply")
print("  bounces. Resolve the name here, or match on the [ref], which is stable.")
PY
}

case "${1:-}" in
  stack)    shift; check_stack "$@" ;;
  at-risk)  shift; check_at_risk "$@" ;;
  baseline) shift; check_baseline "$@" ;;
  peers)    shift; check_peers "$@" ;;
  *) echo "usage: preflight.sh {stack|at-risk|baseline <file> <n>|peers}" >&2; exit 2 ;;
esac
