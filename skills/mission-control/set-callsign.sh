#!/bin/bash
# set-callsign.sh <CALLSIGN> — make this session's call-sign the address peers resolve.
#
# Two surfaces, one command, run BY the station IN its own tab. They are NOT equal:
#   1. the ADDRESS peers resolve through ListAgents (~/.claude/sessions/<pid>.json) -- DURABLE.
#      Measured 2026-08-18: survived the session's own registry write 33 minutes later.
#      This is NOT the `@` header on a channel a peer has already opened. That name is
#      the SENDER'S OWN START-TIME NAME -- not a per-channel capture, so a channel opened after
#      the rename carries the old name too (measured 2026-08-22). A renamed station keeps
#      arriving under its old handle -- measured 2026-08-19, and it is the same capture that
#      bounces a reply addressed to a from-name. Resolve names here; match on the [ref].
#      AND THE BOUNCE SUGGESTS ALTERNATIVES THAT ARE ALL WRONG: it matches the DEAD handle,
#      so it offers that handle's lexical neighbours -- live, real, uninvolved stations --
#      and never the renamed sender. Measured 2026-08-23. Ignore them; run ListAgents.
#   2. the Terminal tab title (delegated to label-tab.sh) -- CONDITIONAL, and the condition
#      is fixed at LAUNCH, so THIS SCRIPT CANNOT CHANGE IT for a session already up.
#      Claude Code writes the title once per status change. Measured 2026-08-22 on 2.1.239,
#      one real turn, three launches:
#        plain `claude`      -> 7 writes, ending as the TURN SUMMARY. Our label is gone.
#        `claude --name FOO` -> 5 writes, every one "<glyph> FOO". The summary never
#                               displaces it, so the tab carries the call-sign all watch.
#                               This is what `/mc deploy` passes, and it is plain OSC, so
#                               it holds outside Terminal.app too.
#        CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 -> 0 writes; the custom title stands alone.
#      For a session ALREADY RUNNING as plain `claude`, `/rename <CALLSIGN>` typed by the
#      human is the only thing that holds (measured 2026-08-18). label-tab.sh reads this
#      session's own argv and env and reports which case it is in -- believe that line, and
#      never report the tab as labelled without it.
#
# Finds its own pid and its own tty by walking up from this shell — never by
# "front window" or by scanning for any `claude`, both of which hit somebody else's
# session. Read-modify-write, so no field but the name is touched.
#
# NOTE: the registry under ~/.claude/sessions is Claude Code's own state. This is
# unsupported: a version bump can change the schema. `claude --name <CALLSIGN>` at
# launch is the supported path and is what `/mc deploy` passes. This exists for the
# sessions already up.
set -u
CALLSIGN="${1:-}"; HANDLE="${2:-}"
[ -z "$CALLSIGN" ] && { echo "usage: set-callsign.sh <CALLSIGN> [HANDLE]" >&2; exit 2; }

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
  echo "        got: $CALLSIGN" >&2
  exit 2
fi
if [ ${#CALLSIGN} -gt 64 ]; then echo "FAILED: call-sign too long (max 64)" >&2; exit 2; fi

# A call-sign is what people SAY -- it may contain spaces ("FLEET COMMAND").
# A handle is what peers ADDRESS -- a session name, and those cannot. When the two
# cannot be the same, ASK; never invent somebody's short form for them. Whether a
# handle differs from the call-sign at all is a preference, not a rule: plenty of
# people want CONTROL to be addressed CONTROL, and plenty want FLEETCOM.
if [ -z "$HANDLE" ]; then
  case "$CALLSIGN" in
    *[!A-Za-z0-9_-]*)
      cat >&2 <<MSG
FAILED: "$CALLSIGN" cannot be a session name, so it needs a handle you choose.
        A handle is [A-Za-z0-9_-] only -- no spaces.
        Ask the user which they want, then:  set-callsign.sh "$CALLSIGN" <HANDLE>
        e.g.  set-callsign.sh "$CALLSIGN" FLEETCOM
        Do not pick one for them. Record it in ~/.claude/mission-control.json
        under "naming" so it is asked once and never again.
MSG
      exit 2;;
    *) HANDLE="$CALLSIGN";;
  esac
fi
case "$HANDLE" in *[!A-Za-z0-9_-]*) echo "FAILED: a handle is [A-Za-z0-9_-] only -- got \"$HANDLE\"" >&2; exit 2;; esac

HERE="$(cd "$(dirname "$0")" && pwd)"
SESSIONS="$HOME/.claude/sessions"
command -v python3 >/dev/null || { echo "FAILED: python3 not found — needed to edit the session registry" >&2; exit 1; }
[ -d "$SESSIONS" ] || { echo "FAILED: no session registry at $SESSIONS (Claude Code too old, or a different layout)" >&2; exit 1; }

# --- find our own claude process by walking the parent chain -------------------
p=$$; CLAUDE_PID=""
while [ "$p" -gt 1 ]; do
  comm=$(ps -o comm= -p "$p" 2>/dev/null | xargs basename 2>/dev/null)
  if [ "$comm" = "claude" ] && [ -f "$SESSIONS/$p.json" ]; then CLAUDE_PID="$p"; break; fi
  p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  [ -z "$p" ] && break
done
[ -z "$CLAUDE_PID" ] && { echo "FAILED: no claude session in the parent chain" >&2; exit 1; }
REG="$SESSIONS/$CLAUDE_PID.json"

# --- refuse a call-sign another LIVE session already answers to ----------------
CLASH=$(CALLSIGN="$HANDLE" MINE="$REG" python3 - "$SESSIONS" <<'PY'
import glob,json,os,sys
want=os.environ["CALLSIGN"].lower(); mine=os.environ["MINE"]
for f in glob.glob(os.path.join(sys.argv[1],"*.json")):
    if os.path.abspath(f)==os.path.abspath(mine): continue
    try: d=json.load(open(f))
    except Exception: continue
    if str(d.get("name","")).lower()!=want: continue
    try: os.kill(int(d.get("pid",0)),0)
    except Exception: continue          # dead session, its name is free
    print(f"{d.get('name')} (pid {d.get('pid')}, {d.get('cwd','?')})")
PY
)
[ -n "$CLASH" ] && { echo "REFUSED: $HANDLE is answered by a live session — $CLASH" >&2; exit 3; }

# --- 0. capture the LAUNCH facts before the rename overwrites them -------------
# `nameSource` absent == this process was launched with --name; 'derived' == a bare launch.
# Read it HERE, because step 1 sets it to 'user' and the answer would be lost. Read from the
# REGISTRY, not from `ps -o args=`: the argv test could only ever inspect the live process, so
# the --name branch was unreachable in any test and shipped unexercised (found 2026-08-25).
PRE_NS=$(python3 -c "import json,sys
d=json.load(open(sys.argv[1])); v=d.get('nameSource')
print('' if v is None else str(v))" "$REG" 2>/dev/null)
PRE_NAME=$(python3 -c "import json,sys
print(json.load(open(sys.argv[1])).get('name',''))" "$REG" 2>/dev/null)

# --- 1. the address peers resolve: read-modify-write, name only ----------------
CALLSIGN="$HANDLE" python3 - "$REG" <<'PY' || exit 1
import json,os,sys,time,tempfile
p=sys.argv[1]; new=os.environ["CALLSIGN"]
d=json.load(open(p))
old=d.get("name")
if old==new:
    print(f"address already {new}"); raise SystemExit(0)
# Drop BOTH the name being replaced and the name being ADOPTED. Only `old` was
# filtered, so renaming BACK to a name you previously held left it in `name` and in
# `formerNames` at once -- measured on a live registry 2026-08-23 after
# CONTROL -> CONTROL-PROBE -> CONTROL: name=CONTROL, formerNames=[..., 'CONTROL', ...].
# It lands in the worst possible place: the ONLY reason to read formerNames is to decide
# whether an address is STALE, so the field false-positived on exactly the name it was
# being consulted to validate. (This is a SECOND defect in this list, independent of the
# documented one about formerNames[0] not being a reliable start-time name.)
former=[x for x in d.get("formerNames",[]) if x!=old and x!=new]
if old: former.append(old)
d.update(name=new, nameSource="user", nameSince=int(time.time()*1000), formerNames=former)
fd,tmp=tempfile.mkstemp(dir=os.path.dirname(p)); os.close(fd)
json.dump(d,open(tmp,"w")); os.replace(tmp,p)          # atomic, never a torn registry
print(f"address (fleet manifest) {old} -> {json.load(open(p))['name']}")
PY

# --- 2. the tab title (best effort; never fails the rename) ---------------------
# macOS Terminal.app only. Anywhere else this is a clean skip, not an error: the
# address above is the half the fleet reads, and it has already landed.
if [ ! -f "$HERE/label-tab.sh" ]; then
  echo "tab title: skipped — label-tab.sh not found beside me"
elif [ "$(uname -s)" != "Darwin" ] || ! command -v osascript >/dev/null; then
  echo "tab title: skipped — needs macOS Terminal.app; the manifest address is set regardless"
else
  # Do not restate the outcome here. label-tab.sh reads this session's own env and
  # says whether the label survives the next turn; a second voice on the same fact is
  # how 6.28.1 happened -- one surface kept promising what another had withdrawn.
  bash "$HERE/label-tab.sh" "$CALLSIGN" 2>&1 | sed "s/^/tab title: /" || \
    echo "tab title: skipped — could not match this tty"
fi

# WINDOW OR TAB, recorded here so a HAND-STARTED station is coloured like a deployed one.
# The deploy log only knows about stations `deploy` opened; identify is the one moment
# every station passes through, however it was started. Best-effort and never fatal --
# a missing record costs one colour on the status line and nothing else.
if [ -f "$HERE/window-probe.sh" ]; then
  # --all, NOT a self-probe. One station identifying is the moment the fleet's shape most
  # often just changed -- a tab was opened, a window pulled apart -- and everyone else's
  # record is now as stale as this one was. Refreshing only yourself leaves the rest wrong
  # and is the same cost: one osascript pass either way.
  bash "$HERE/window-probe.sh" --all 2>&1 | sed "s/^/window: /" || true
fi

# HAND OVER THE REPAIR, DO NOT DESCRIBE IT. identify is where somebody learns their header
# is wrong, so it is where the fix belongs -- asked as "why should i paste? why not trying
# identify?", which is the right question: identify cannot perform this repair (the value
# is read at launch), but it can stop making the human go and find the command.
# Only printed when this session actually lacks --name; a deployed station needs nothing.
# THE ENVELOPE IS PUBLISHED, NOT REPAIRED, AND THIS IS WHERE THAT USED TO GO WRONG.
# Through 7.10.1 this block printed "YOUR @ HEADER IS WRONG AND THIS COMMAND IS THE ONLY FIX"
# and told the user to quit and relaunch. For CONTROL that instruction is unanswerable: the
# post is TAKEN by whoever runs /mc, so the session had no call-sign to pass at launch --
# `--name CONTROL` needs a decision that had not been made yet. Every hand-started Control
# failed it, deploy never launches Control, and the user got the lecture on every fleet.
# Reported 2026-08-24, twice in one evening, and it was right both times.
#
# What the mismatch actually costs is peers spending transmissions reporting a fault none of
# them can fix -- measured: two stations, first transmission each. Publishing removes that for
# one line. The relaunch still exists in fix-header.sh for anyone who asks for it.
if [ -n "$PRE_NS" ]; then          # non-empty == derived == launched WITHOUT --name
  MYENV=$(python3 -c "import json,sys
d=json.load(open(sys.argv[1])); f=d.get('formerNames') or []
print(f[0] if f else d.get('name',''))" "$REG" 2>/dev/null)
  echo ""
  echo "PUBLISH YOUR ENVELOPE -- DO NOT ASK TO BE RELAUNCHED."
  echo "This session was launched without --name, so everything you send arrives stamped"
  echo "  @ ${MYENV:-<your birth handle>}   -- not $CALLSIGN."
  echo "That value froze at launch and nothing here can reach it. There is nothing to repair"
  echo "and nothing to put to the user."
  echo ""
  echo "TWO PLACES, AND YOU ARE WRITING BOTH ANYWAY:"
  echo "  1. your board row -> $CALLSIGN · envelope ${MYENV:-<handle>}"
  echo "  2. your first transmission, once ->"
  echo "     \"address $CALLSIGN; the name on my envelope is not my call-sign --"
  echo "      do not spend a transmission reporting it back.\""
  echo ""
  echo "A reply addressed to the envelope is the one thing that fails, and it fails DEAD --"
  echo "a former name does not resolve, and when the call-sign shares no characters with the"
  echo "handle the bounce suggests nothing at all (measured 2026-08-24, both shapes). Published,"
  echo "nobody addresses it. If the USER asks for the repair, fix-header.sh prints it."
  echo ""
else
  # LAUNCHED WITH --name, AND NOW RENAMED TO SOMETHING ELSE. This is the one envelope fault
  # that MISDELIVERS instead of bouncing, and until 7.14.2 it was completely silent.
  #
  # It is created by the control-shell-hook: a hand-started session in a repo with no live
  # coordinator comes up `--name CONTROL`, and if the human then types `/mc identify CHANNELS`
  # the address moves to CHANNELS while the envelope stays frozen at CONTROL. CONTROL is not a
  # dead handle -- it is a REAL call-sign that a live coordinator answers to. A peer replying to
  # that header does not get "no agent named ..."; it reaches the ACTUAL COORDINATOR, who reads
  # a reply to a message they never sent. Every other envelope fault in this skill is bounded by
  # failing loudly. This one fails quietly and in somebody else's tab.
  #
  # `/mc deploy` never produces it -- it launches --name X and identifies as the same X.
  LAUNCHNAME="$PRE_NAME"
  if [ -n "$LAUNCHNAME" ] && [ "$LAUNCHNAME" != "$HANDLE" ]; then
    echo ""
    echo "STOP -- YOUR ENVELOPE NAMES A DIFFERENT STATION, AND IT WILL MISDELIVER."
    echo "This process was launched with  --name '$LAUNCHNAME'  and you have just taken $HANDLE."
    echo "Your address is $HANDLE. Your \`@\` header is frozen at $LAUNCHNAME and cannot be changed."
    echo ""
    echo "WHY THIS ONE IS DIFFERENT from an ordinary stale envelope: $LAUNCHNAME is a REAL"
    echo "call-sign, not a dead machine handle. A peer replying to your header does NOT get a"
    echo "bounce -- it reaches whoever actually holds $LAUNCHNAME, who receives a reply to a"
    echo "message they never sent. Publishing cannot fix that; only the launch can."
    echo ""
    echo "RELAUNCH, and here that is a question you CAN answer -- you already know your call-sign:"
    MYSID=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('sessionId',''))" "$REG" 2>/dev/null)
    MYCWD=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('cwd',''))" "$REG" 2>/dev/null)
    MYKIND=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('kind',''))" "$REG" 2>/dev/null)
    BGF=""; [ "$MYKIND" = "bg" ] && BGF="--bg "
    echo "  cd '$MYCWD' && claude ${BGF}--name '$HANDLE' --resume $MYSID"
    echo "  ...then  /mc identify $HANDLE"
    echo ""
    echo "UNTIL THEN, TELL YOUR PEERS IN YOUR FIRST TRANSMISSION: \"my header reads $LAUNCHNAME"
    echo "and that is NOT me -- address $HANDLE, and never reply to my header.\""
    echo ""
    echo "NEXT TIME: \`/mc deploy $HANDLE\` launches a station as its own call-sign and this"
    echo "cannot happen. A station started by hand should be started as"
    echo "  cd '$MYCWD' && claude --name '$HANDLE'"
    echo ""
  fi
fi

echo "NOTE: every peer keeps seeing your OLD handle on the \`@\` header -- not only the ones with a"
echo "      channel already open. That name is your SESSION'S START-TIME name, stamped on everything"
echo "      you send; there is one socket per session and no per-channel handshake, so a channel"
echo "      opened after this rename carries the old name too (measured 2026-08-22). Only a restart"
echo "      clears it, and THAT IS NOT A TASK FOR YOU TO RAISE -- publish the handle instead (above)."
echo "      fix-header.sh prints the relaunch line if the USER asks for it; do not volunteer it."
echo "      Do not report the \`@\` header as changed, and do not reopen a channel"
echo "      expecting a fresh one. Open every transmission with \"<CALLSIGN> TO <CALLSIGN>\" -- the"
echo "      body is the only correct identity your peer receives."
echo "pid $CLAUDE_PID · registry $REG"
echo "VERIFY: re-run mc-init.sh me -- ME_NAME is live in the registry, so this is a LOCAL check."
echo "        Your [ref] is on your own ListAgents self-line and is correct; the NAME on that line"
echo "        is not. A peer read-back is corroboration, not retrieval -- it is not a blocker."
