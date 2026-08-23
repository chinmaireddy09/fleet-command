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

# A worktree label a reader can act on: the shortest tail of the path that is UNIQUE
# among the worktrees. Two path components is not enough -- a fleet whose scratchpads
# are all <uuid>/scratchpad/board-flip rendered three different worktrees as the single
# string "scratchpad/board-flip", with the discriminating UUID one level above the
# window. Reported 2026-08-23. It is the same defect as printing "HEAD" for every
# detached worktree: the one question a reader has here is WHICH DIRECTORY, and a label
# that collides answers it wrongly rather than vaguely. Widen until unique; if nothing
# is unique, print the whole path -- long beats ambiguous when the next step is rm.
wt_label() {
  local p="$1" all n lab cnt
  all=$(git worktree list --porcelain | awk '/^worktree /{print $2}')
  n=2
  while [ "$n" -le 6 ]; do
    lab=$(printf '%s' "$p" | awk -F/ -v n="$n" '{s="";for(i=NF-n+1;i<=NF;i++){if(i>0){s=s (s==""?"":"/") $i}};print s}')
    cnt=$(printf '%s\n' "$all" | awk -F/ -v n="$n" '{s="";for(i=NF-n+1;i<=NF;i++){if(i>0){s=s (s==""?"":"/") $i}};print s}' | grep -Fxc "$lab")
    [ "${cnt:-0}" -le 1 ] && { printf '%s' "$lab"; return; }
    n=$((n+1))
  done
  printf '%s' "$p"
}

check_at_risk() {
  git rev-parse --git-dir >/dev/null 2>&1 || die "not a git repo"
  # NOT READ-ONLY, AND IT SAYS SO. This writes remote-tracking refs. It is also the
  # single point every number below depends on: if it FAILS -- offline, credentials
  # expired, remote renamed -- every ref we compare against is stale, so anything a
  # peer pushed since the last good fetch reads as existing nowhere else. That is the
  # inflating direction, and it was unguarded. Reported 2026-08-23.
  local fetch_ok=1
  git fetch -q --all 2>/dev/null || fetch_ok=0
  echo "commits that exist HERE AND NOWHERE ELSE:"
  echo "  (--not --remotes, i.e. content. NOT 'rev-list --count origin/main..HEAD',"
  echo "   which counts reachability and reports danger for work already upstream)"
  if [ "$fetch_ok" = "0" ]; then
    echo "  WARNING: git fetch FAILED -- remote-tracking refs may be stale, so work a peer"
    echo "           has already pushed can appear here as at risk. This check OVERSTATES"
    echo "           in this state. Fix the fetch before acting on an AT RISK line."
  fi
  local any=0
  for wt in $(git worktree list --porcelain | awk '/^worktree /{print $2}'); do
    local n b gdir ref sha gone
    # A WORKTREE WHOSE DIRECTORY IS GONE WAS SKIPPED SILENTLY, AND THAT IS THE
    # HIGHEST-RISK CASE, NOT THE LOWEST. `git -C <missing dir>` exits 128, stderr went
    # to /dev/null and `|| continue` dropped the worktree without printing anything --
    # so a repo whose only unpushed commit lived in a prunable worktree printed
    # "ok  every commit in every worktree exists on a remote". Reported 2026-08-23
    # (5 of 16 worktrees vanished from the check) and reproduced from scratch here.
    #
    # It is the dangerous direction twice over. Absence of a line reads as nothing
    # wrong; and the tidy-up a reader runs on seeing "prunable" -- `git worktree prune`
    # -- deletes the HEAD ref that is the only thing still pinning that commit. The
    # tool said "ok" immediately before the command that loses the work.
    #
    # git still RECORDS a HEAD sha for a missing worktree, and every worktree shares
    # the object store, so measure it from HERE with that sha instead of giving up.
    gone=""; ref="HEAD"; gdir="$wt"; n=""
    if [ -d "$wt" ]; then
      n=$(git -C "$wt" rev-list --count HEAD --not --remotes 2>/dev/null) || n=""
    fi
    if [ -z "$n" ]; then
      sha=$(git worktree list --porcelain \
            | awk -v w="$wt" '$1=="worktree" && $2==w {f=1; next} f && $1=="HEAD" {print $2; exit}')
      if [ -z "$sha" ]; then
        printf '  UNREADABLE  %-44s could not be measured -- check this one by hand\n' "$(wt_label "$wt")"
        any=1; continue
      fi
      gone=1; gdir="."; ref="$sha"
      n=$(git rev-list --count "$ref" --not --remotes 2>/dev/null) || n=0
    fi
    # NAME THE WORKTREE, NOT JUST THE BRANCH. A detached worktree's branch is the
    # literal string "HEAD", so a fleet with six detached scratchpads printed six
    # rows all labelled HEAD -- and the one question a reader has here is WHICH
    # DIRECTORY holds the work, because that is the directory they must not remove.
    # Reported 2026-08-23 by a coordinator ten seconds from deleting a live
    # station's only copy of its own board row, held in a detached scratchpad.
    if [ -n "$gone" ]; then
      b=$(git worktree list --porcelain \
          | awk -v w="$wt" '$1=="worktree" && $2==w {f=1; next} f && $1=="branch" {print $2; exit} f && /^worktree /{exit}')
      b="${b#refs/heads/}"; [ -z "$b" ] && b="detached"
    else
      b=$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)
      [ "$b" = "HEAD" ] && b="detached"
    fi
    b="$b  $(wt_label "$wt")"
    [ -n "$gone" ] && b="$b  [DIR GONE]"
    if [ "${n:-0}" != "0" ]; then
      # `git cherry` marks + for "no equivalent upstream" and - for "already there
      # under a different sha". Without this, six doc commits whose content had
      # already landed read as a day of exposure. Reachability is not content.
      local up ours dupes
      # No upstream set: fall back to the repo's real base ref, not a guessed
      # "origin/main". On a master/trunk repo, or one whose remote is not called
      # origin, the old fallback compared against a ref that does not exist and
      # reported everything as at risk.
      up=$(git -C "$gdir" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || up=""
      if [ -z "$up" ]; then
        r=$(git -C "$gdir" remote 2>/dev/null | grep -qx origin && echo origin || git -C "$gdir" remote 2>/dev/null | head -1)
        if [ -n "$r" ]; then
          up=$(git -C "$gdir" symbolic-ref -q --short "refs/remotes/$r/HEAD" 2>/dev/null)
          if [ -z "$up" ]; then
            for c in main master trunk develop; do
              git -C "$gdir" rev-parse --verify -q "$r/$c" >/dev/null 2>&1 && { up="$r/$c"; break; }
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
      dup_shas=$(git -C "$gdir" cherry "$up" "$ref" 2>/dev/null | awk '/^-/{print $2}')
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
$(git -C "$gdir" log --format='%H %s' "$ref" --not --remotes 2>/dev/null)
EOF
      dupes=$dupe_n
      if [ "${ours:-0}" = "0" ]; then
        printf '  safe     %-46s %s commit(s) exist only here, but ALL content is already on a remote\n' "$b" "$n"
        [ "${dupes:-0}" != "0" ] && printf '           (%s duplicate by content -- stale, not lost)\n' "$dupes"
      else
        printf '  AT RISK  %-46s %s commit(s) on no remote, by content\n' "$b" "$ours"
        printf '%s' "$at_risk_list" | sed 's/^/           /'
        [ -n "$gone" ] && {
          # DO NOT CLAIM SOLE-PIN WITHOUT CHECKING FOR OTHER REFS. First cut of this
          # warning said the worktree HEAD was "the only thing pinning" the commit and
          # told the reader to create a branch. Reported 2026-08-23 against a commit a
          # local branch ALREADY held: prune would not have lost it, and the recovery
          # command just made a second branch for something already branched. The
          # danger was real but it was the WRONG danger, and the two have different
          # fixes -- sole-pin is fixed by a branch, no-remote is fixed by a push. A
          # reader who ran the printed command got a redundant branch, zero remote
          # copies, and the impression of having been rescued.
          local pins
          pins=$(git for-each-ref --format='%(refname:short)' --contains "$ref" \
                 refs/heads refs/tags 2>/dev/null | head -3 | tr '\n' ' ' | sed 's/ *$//')
          if [ -n "$pins" ]; then
            printf '           The directory is gone, but this commit is also held by: %s\n' "$pins"
            printf '           So `git worktree prune` will NOT lose it. The real exposure is that it is\n'
            printf '           on NO REMOTE -- the fix is a push, not a branch.\n'
          else
            printf '           THE DIRECTORY IS GONE and NO branch or tag holds this commit. The\n'
            printf '           worktree HEAD ref is the only pin, and `git worktree prune` DELETES it.\n'
            printf '           Recover first:  git branch <name> %s\n' "$ref"
          fi
        }
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
