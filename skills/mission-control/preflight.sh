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
    b=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)
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
      ours=$(git -C "$wt" cherry "$up" 2>/dev/null | grep -c '^+' || echo 0)
      dupes=$(git -C "$wt" cherry "$up" 2>/dev/null | grep -c '^-' || echo 0)
      if [ "${ours:-0}" = "0" ]; then
        printf '  safe     %-34s %s commit(s) exist only here, but ALL content is already on %s\n' "$b" "$n" "$up"
        [ "${dupes:-0}" != "0" ] && printf '           (%s duplicate by content -- stale, not lost)\n' "$dupes"
      else
        printf '  AT RISK  %-34s %s commit(s) with NO equivalent upstream\n' "$b" "$ours"
        git -C "$wt" cherry -v "$up" 2>/dev/null | grep '^+' | sed 's/^+ /           /'
        any=1
      fi
    fi
  done
  [ "$any" = "0" ] && ok "every commit in every worktree exists on a remote"
  echo "uncommitted work (dies with a tidy-up, not with a window):"
  for wt in $(git worktree list --porcelain | awk '/^worktree /{print $2}'); do
    local d; d=$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    [ "$d" != "0" ] && printf '  %-40s %s file(s)\n' "$(basename "$wt")" "$d"
  done
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
