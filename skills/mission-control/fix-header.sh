#!/bin/bash
# fix-header.sh — the ONE repair for a wrong `@` header, without losing the session.
#
#   fix-header.sh [CALLSIGN]                    repair THIS session's header
#   fix-header.sh --for <NAME|pid> [CALLSIGN]   print ANOTHER station's repair line
#   fix-header.sh --audit                       whose envelope is wrong, fleet-wide
#
# THE PROBLEM, MEASURED RATHER THAN ASSUMED (2026-08-24, Claude Code 2.1.241). A session's
# own advertised name -- the `@` header stamped on every message it sends, and the NAME on
# its own ListAgents self-line -- is read into the process at LAUNCH and never again:
#
#   registry name after set-callsign.sh SKILLDEV : SKILLDEV
#   this session's ListAgents self-line          : fleet-command-fd     <- unchanged
#   the same registry, read for a PEER           : correct, live
#
# So peers' names are read live from disk and a session's own is not. set-callsign.sh
# rewrites the registry and fixes the address peers RESOLVE; it cannot reach the value this
# process already holds. /rename fixes the TAB TITLE, a different surface with a different
# mechanism, and fixes nothing here. No file write, no command, and no amount of
# re-identifying changes it. Only a launch does.
#
# IT IS NOT COSMETIC. A PEER THAT REPLIES TO THE NAME IT RECEIVED GETS A BOUNCE.
# Measured 2026-08-24 by a station asked to read back an envelope: this session had renamed
# to SKILLDEV, its message arrived stamped `fleet-command-fd`, and the peer's reply to that
# name failed with "No agent named 'fleet-command-fd' is reachable". It reached us only by
# resolving the [ref], which survives every rename. So a stale envelope costs delivery, not
# just tidiness -- which is why stations with one end up writing "resolve me through
# ListAgents" into every message they send. They are routing around a real failure.
#
# THE REPAIR IS THEREFORE A RELAUNCH -- but a relaunch does NOT have to cost the
# conversation. `--resume <sessionId>` brings the whole session back, and `--name` sets the
# advertised identity at the one moment it is read. Together they are a rename that sticks:
#
#   claude --name 'FINANCE' --resume 46f82be8-...
#
# WHY THIS SCRIPT EXISTS RATHER THAN A LINE IN THE DOCS: the session id is a uuid nobody
# should retype, and the call-sign has to match the one on the board exactly. Both are
# filled in here from the live registry, so the command cannot be mistyped -- the same rule
# spawn-station.sh follows for the deploy line.
#
# WHY `--for` EXISTS (added 2026-08-24, from a live failure). This fault is almost never
# noticed by the station that HAS it: a session cannot see its own envelope. It is noticed
# by a PEER, reading `@ <wrong-name>` on an incoming message. Until this flag existed the
# script could only ever speak for the session it ran in -- so the station that could SEE
# the fault could not print the fix, and the station that could print it could not see the
# fault. That is the shape this problem actually arrives in, and it was the shape the tool
# could not serve. `--for` closes it: any station can resolve any other from the session
# registry and print that station's exact repair line, ready to hand over.
#
# IT RESOLVES A STALE ENVELOPE NAME, because that is the only handle a peer actually holds.
# The registry keeps `formerNames`, so `--for acme-api-54` finds the station that now
# answers to CONTROL. Measured 2026-08-24 on the fleet this was written for:
#
#   registry: pid 1170  name=CONTROL  nameSource=user  formerNames=['acme-api-54']
#   the `@` header a peer read off its message      :  acme-api-54
#
# THAT SAME FIELD SAYS WHOSE HEADER IS WRONG -- without parsing argv, which is unreliable
# for an adopted background spare (see references/station-identity.md):
#
#   no `nameSource` key   -> the name was set AT LAUNCH by --name.   Envelope correct.
#   nameSource=derived    -> never named. Envelope == the derived name; replies still land,
#                            but the station is carrying no call-sign.
#   nameSource=user       -> renamed AFTER launch. ENVELOPE IS STALE. This is the fault.
#
# Measured across four live sessions, 2026-08-24 on 2.1.241: the two `/mc deploy` stations
# had no `nameSource`, the hand-started Control had `user`, an unnamed session had
# `derived`. THE ADOPTED-BG-SPARE CASE WAS NOT MEASURED -- if `--for` reports on one, treat
# the verdict as unproven and fall back to a peer read-back.
#
# IT NEVER RUNS THE COMMAND. A process cannot replace itself mid-turn, and a script that
# tried would be killing the session that called it. It prints; the human runs it.
set -u

usage() {
  cat >&2 <<'USG'
usage:
  fix-header.sh [CALLSIGN]                    repair THIS session's @ header
  fix-header.sh --for <NAME|pid> [CALLSIGN]   print ANOTHER station's repair line
  fix-header.sh --audit                       whose envelope is wrong, fleet-wide

  <NAME|pid> may be the station's current call-sign, its pid, or the STALE NAME you read
  on its `@` header -- former names are resolved too, which is the whole point.
USG
}

TARGET=""; WANT=""; AUDIT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --audit|--list) AUDIT=1; shift ;;
    --for)   TARGET="${2:-}"; [ -n "$TARGET" ] || { usage; exit 2; }; shift 2 ;;
    --for=*) TARGET="${1#--for=}"; [ -n "$TARGET" ] || { usage; exit 2; }; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "FAILED: unknown option $1" >&2; usage; exit 2 ;;
    *)  if [ -z "$WANT" ]; then WANT="$1"; shift
        else echo "FAILED: too many arguments" >&2; usage; exit 2; fi ;;
  esac
done

SESSDIR="$HOME/.claude/sessions"

# THE FLEET-WIDE QUESTION, answered without a lookup that has to fail first. "Whose
# envelope is wrong" is what a peer actually arrives with, and until 2026-08-24 the only
# way to see it was to mistype a --for target and read the error.
if [ -n "$AUDIT" ]; then
  python3 - "$SESSDIR" <<'AUD'
import json, os, sys
d = sys.argv[1]
rows = []
for fn in sorted(os.listdir(d)) if os.path.isdir(d) else []:
    if not fn.endswith(".json"):
        continue
    try:
        with open(os.path.join(d, fn)) as fh:
            rows.append(json.load(fh))
    except Exception:
        continue            # a half-written registry file is not this script's business

def verdict(j):
    ns = j.get("nameSource")
    if ns is None:
        return "OK", "named at launch"
    if ns == "user":
        former = j.get("formerNames") or []
        return "STALE", "peers see `%s`" % (former[0] if former else "its birth name")
    return "UNNAMED", "no call-sign (nameSource=%s)" % ns

if not rows:
    print("no sessions in the registry -- nothing to audit")
    sys.exit(0)

print("%-8s %-18s %-9s %s" % ("pid", "call-sign", "envelope", ""))
bad = 0
for j in sorted(rows, key=lambda r: str(r.get("name") or "")):
    v, why = verdict(j)
    bad += (v == "STALE")
    print("%-8s %-18s %-9s %s" % (j.get("pid"), j.get("name") or "-", v, why))
print("")
if bad:
    print("%d station(s) carrying a stale envelope. For each one:" % bad)
    print("  fix-header.sh --for <call-sign>    -> its repair line, ready to hand over")
    print("A stale envelope means a peer replying BY NAME gets a bounce; only the [ref] resolves.")
else:
    print("No stale envelopes. (An adopted bg spare's registry signature has never been measured")
    print("-- if one is listed here, confirm it by peer read-back rather than by this table.)")
AUD
  exit 0
fi

# Same parent walk every script in this family uses: the Bash tool has no tty, the `claude`
# above it does. It runs even under --for, so that resolving YOURSELF through the peer path
# is recognised rather than printing "hand this to that station" to the station holding it.
p=$$; CLAUDE_PID=""
while [ "$p" -gt 1 ]; do
  comm=$(ps -o comm= -p "$p" 2>/dev/null | xargs basename 2>/dev/null)
  [ "$comm" = "claude" ] && { CLAUDE_PID="$p"; break; }
  p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  [ -z "$p" ] && break
done

if [ -z "$TARGET" ]; then
  [ -n "$CLAUDE_PID" ] || { echo "FAILED: no claude process in the parent chain" >&2; exit 1; }
  REG="$SESSDIR/$CLAUDE_PID.json"
  [ -f "$REG" ] || { echo "FAILED: no registry entry at $REG" >&2; exit 1; }
else
  # Resolve a peer by pid, current name, or a name it used to carry. Exit 3 = nobody,
  # exit 4 = more than one; both print a listing, because "which station did you mean"
  # is only answerable with the fleet in front of you.
  REG=$(python3 - "$SESSDIR" "$TARGET" <<'PY'
import json, os, sys
d, want = sys.argv[1], sys.argv[2]
rows = []
for fn in sorted(os.listdir(d)) if os.path.isdir(d) else []:
    if not fn.endswith(".json"):
        continue
    p = os.path.join(d, fn)
    try:
        with open(p) as fh:
            j = json.load(fh)
    except Exception:
        continue            # a half-written registry file is not this script's business
    rows.append((p, j))

def hit(j, pid):
    if want == str(pid):
        return True
    if want == (j.get("name") or ""):
        return True
    return want in (j.get("formerNames") or [])

found = [(p, j) for (p, j) in rows if hit(j, j.get("pid"))]
if len(found) == 1:
    print(found[0][0])
    sys.exit(0)

def why(j):
    ns = j.get("nameSource")
    if ns is None:  return "envelope OK (named at launch)"
    if ns == "user": return "ENVELOPE STALE (renamed after launch)"
    return "no call-sign (nameSource=%s)" % ns

sys.stderr.write(
    ("FAILED: no station matches %r\n" if not found
     else "FAILED: %r matches more than one station -- name a pid instead\n") % want)
sys.stderr.write("\nstations in the registry right now:\n")
for _, j in rows:
    former = ", ".join(j.get("formerNames") or []) or "-"
    sys.stderr.write("  pid %-7s %-18s was: %-22s %s\n"
                     % (j.get("pid"), j.get("name") or "-", former, why(j)))
sys.exit(4 if found else 3)
PY
  ) || exit $?
fi

# One reader for both paths. Tabs and newlines cannot occur in any of these values, and a
# cwd CAN contain spaces -- so this is line-per-field rather than a word split.
INFO=$(python3 - "$REG" <<'PY'
import json, sys
with open(sys.argv[1]) as fh:
    d = json.load(fh)
former = d.get("formerNames") or []
# The envelope is frozen at LAUNCH, so the value peers see is the name this process was
# BORN with -- the FIRST former name, not the most recent one. Measured only in the
# single-rename case (2026-08-24), where first and last coincide; the index follows from
# the freeze, not from a second measurement.
print(d.get("sessionId", ""))
print(d.get("cwd", ""))
print(d.get("name") or "")
print(d.get("nameSource") if d.get("nameSource") is not None else "@launch")
print(d.get("kind", ""))
print(former[0] if former else "")
print(d.get("pid", ""))
PY
) || { echo "FAILED: could not read $REG" >&2; exit 1; }

SID=$(printf '%s\n' "$INFO" | sed -n 1p)
CWD=$(printf '%s\n' "$INFO" | sed -n 2p)
NAME=$(printf '%s\n' "$INFO" | sed -n 3p)
NSRC=$(printf '%s\n' "$INFO" | sed -n 4p)
KIND=$(printf '%s\n' "$INFO" | sed -n 5p)
BORN=$(printf '%s\n' "$INFO" | sed -n 6p)
PID=$(printf '%s\n' "$INFO" | sed -n 7p)

[ -n "$SID" ] || { echo "FAILED: that session has no sessionId in the registry" >&2; exit 1; }
CALLSIGN="${WANT:-$NAME}"
[ -n "$CALLSIGN" ] || { echo "usage: fix-header.sh <CALLSIGN>   (this session has no name to reuse)" >&2; exit 2; }

# The call-sign is going into a shell command the human will paste. Refuse anything that
# could carry more than a name -- the same allowlist label-tab.sh uses, under C collation
# so a UTF-8 locale cannot widen the range.
case "$(LC_ALL=C printf '%s' "$CALLSIGN" | tr -d 'A-Za-z0-9 ._/&-')" in
  "") ;;
  *) echo "FAILED: call-sign may contain letters, digits, spaces and . _ / & - only" >&2; exit 2 ;;
esac

# A background station must be relaunched as one. The line below is pasted verbatim, so a
# missing --bg would quietly convert a background agent into a tab session -- the same
# branch set-callsign.sh carries, which this script did not until 2026-08-24.
BGFLAG=""; [ "$KIND" = "bg" ] && BGFLAG="--bg "

# A relaunch is indistinguishable from a death from outside, so somebody has to be told
# first -- and who that is changes when the station is the coordinator. Control cannot warn
# Control, and a fleet whose Control disappears mid-job has nobody to reassign the work it
# is holding.
MIDJOB="IF $CALLSIGN IS MID-JOB, TELL CONTROL BEFORE IT RELAUNCHES. From outside, a relaunch is
indistinguishable from a death, and the correct thing for Control to do with a dead
station's work is hand it to somebody else."
case "$CALLSIGN" in
  CONTROL|Control|control)
    MIDJOB="THIS STATION IS THE COORDINATOR, so the warning goes the other way: every station
holding work needs to know Control is about to go dark, because for the length of the
relaunch there is nobody to escalate to and nobody reading the board. Say so on the board
before the quit, not after -- Control is the one station that cannot be told by Control." ;;
esac

# A station is allowed to reach itself through --for -- a peer tells you your header is
# wrong, and `--for <the name they read>` is the obvious thing to type. Everything the peer
# path says ("hand this over", "you cannot run it from here") is false when the station is
# you, so this becomes the self path, which is the version that is true.
if [ -n "$TARGET" ] && [ -n "$CLAUDE_PID" ] && [ "$PID" = "$CLAUDE_PID" ]; then
  echo "(--for resolved to THIS session -- printing your own repair)"
  echo ""
  TARGET=""
fi

# ── the peer path: report the verdict first, and refuse a needless relaunch ──────────────
if [ -n "$TARGET" ]; then
  ALIVE="running"
  kill -0 "$PID" 2>/dev/null || ALIVE="NOT RUNNING (pid $PID is gone; the line below still resumes the conversation)"

  echo "STATION: $NAME  [pid $PID]  $ALIVE"
  echo "         registry says nameSource=$NSRC${BORN:+, born as \`$BORN\`}"
  echo ""

  if [ "$NSRC" = "@launch" ]; then
    cat <<TXT
NOTHING TO REPAIR HERE. $NAME was launched with --name, so its envelope, its tab title and
its address all carry $NAME. Relaunching it would cost a new [ref] and a board-row rewrite
and buy nothing.

If you DID read a wrong name on a message from it, one of these is true, in this order of
likelihood: the message predates a repair that has already happened; you resolved the
wrong station; or it is an adopted background spare, whose registry signature this script
has never been measured against -- in which case ask for a read-back rather than trusting
this verdict.
TXT
    exit 0
  fi

  if [ "$NSRC" != "user" ] && [ -z "$WANT" ]; then
    cat <<TXT
THIS STATION HAS NEVER BEEN NAMED (nameSource=$NSRC). Its envelope matches its address, so
replies to it do land -- what it lacks is a call-sign, not a working envelope.

Re-run with the call-sign it should carry to get its repair line:

  fix-header.sh --for $PID <CALLSIGN>
TXT
    exit 0
  fi

  cat <<TXT
THIS IS ${CALLSIGN}'S REPAIR, AND YOU CANNOT RUN IT FROM HERE. A session's advertised name is
read at launch and never re-read, so only a relaunch in ${CALLSIGN}'s own tab changes it. Hand
the line over; do not try to run it, and do not expect a file write or a re-identify to
substitute for it.

${BORN:+THE ENVELOPE PEERS ARE SEEING, read out of the registry rather than guessed:
  \`$BORN\`
Confirm that against the name you read on the message before handing this over. If it does
not match, you have resolved the wrong station.

}The line, for ${CALLSIGN}'s tab, after quitting Claude Code there:

  cd '$CWD' && claude ${BGFLAG}--name '$CALLSIGN' --resume $SID

THEN $CALLSIGN MUST RUN  /mc identify $CALLSIGN  IN THE NEW SESSION. NOT OPTIONAL.
--resume keeps the conversation and the sessionId, but the relaunched process gets a NEW
[ref] -- measured 2026-08-24: a station resumed with the same session id came back as
[7f0b93] where it had been [a1c4e2]. The board's row still carries the old one, and a row
pointing at a dead ref is how Control concludes a station is DEAD and reassigns its work.
identify rewrites the row in place; it does not duplicate it.

ADDRESSING $CALLSIGN TO TELL IT: send to \`$CALLSIGN\`. The ADDRESS is live and correct -- it
is only the envelope that is frozen. Do NOT address whatever name arrived on its message:
that bounce is the thing this repair exists to end.

$MIDJOB
TXT
  exit 0
fi

# ── the self path ───────────────────────────────────────────────────────────────────────
# The one value this session is told it cannot see. It is a registry read, not an
# observation of the wire, so it is offered as a check and not as proof -- the read-back
# below stays the rule.
[ -n "$BORN" ] && cat <<TXT
WHAT PEERS ARE SEEING ON YOUR MESSAGES, out of the registry (you were born \`$BORN\` and
renamed after launch, which is exactly the fault):

  @ $BORN

Treat that as a strong check, not a proof: it is what your launch should have stamped, not
a reading off the wire. The peer read-back at the bottom is still the observation that
settles it.

TXT

cat <<TXT
THE @ HEADER CANNOT BE FIXED FROM INSIDE THIS SESSION. It is read at launch and never
re-read; that was measured, not assumed. What follows is the only repair, and it KEEPS
this conversation -- --resume brings the whole session back.

Run this IN THIS TAB, after quitting Claude Code here:

  cd '$CWD' && claude ${BGFLAG}--name '$CALLSIGN' --resume $SID

What each half does, so nothing here is cargo:
  --name '$CALLSIGN'   sets the advertised identity at the one moment it is read. This is
                       what puts $CALLSIGN on the @ header of every message you send, and
                       on your own ListAgents self-line.
  --resume $SID
                       reopens THIS conversation rather than starting a new one. Nothing
                       is lost. (Use --fork-session instead if you want a copy and want
                       to leave this session's history untouched.)

It also fixes the tab title for free: --name puts the call-sign in every title write
Claude Code makes, so the turn summary never displaces it again.

THEN RUN  /mc identify $CALLSIGN  IN THE NEW SESSION. THIS STEP IS NOT OPTIONAL.
--resume keeps the conversation and the sessionId, but the RELAUNCHED PROCESS GETS A NEW
[ref] -- measured 2026-08-24: a station resumed with the same session id came back as
[7f0b93] where it had been [a1c4e2]. The board's row still carries the old one, and a row
pointing at a dead ref is how Control concludes a station is DEAD and reassigns its work
to somebody else. That happened to this fleet before the repair existed.

identify rewrites the row in place with the new ref -- it does not duplicate it -- so the
sequence is: quit, relaunch, identify. Two out of three leaves you correct on every
surface a peer can see and dead on the board, which is worse than the header you started
with.

AFTER RELAUNCHING, say nothing about the header being fixed until you have seen it: send
one message to a peer and have them read back the name on it. The value you are changing
is one you cannot observe from in here.

UNTIL THEN, PEERS CANNOT REPLY TO YOU BY NAME -- a reply addressed to the stale handle
bounces, and only the [ref] resolves. Open every transmission with "<CALLSIGN> TO
<CALLSIGN>" and expect to be answered by ref, not by envelope.

A PEER CAN NOW PRINT THIS FOR YOU, AND SEE THE VALUE YOU CANNOT: \`fix-header.sh --for
<your-call-sign>\` resolves you from the registry -- by call-sign, by pid, or by the stale
name they read on your envelope -- and prints this same line already filled in.
TXT
