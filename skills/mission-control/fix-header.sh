#!/bin/bash
# fix-header.sh [CALLSIGN] — the ONE repair for a wrong `@` header, without losing the session.
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
# IT NEVER RUNS THE COMMAND. A process cannot replace itself mid-turn, and a script that
# tried would be killing the session that called it. It prints; the human runs it.
set -u

WANT="${1:-}"

# Same parent walk every script in this family uses: the Bash tool has no tty, the `claude`
# above it does.
p=$$; CLAUDE_PID=""
while [ "$p" -gt 1 ]; do
  comm=$(ps -o comm= -p "$p" 2>/dev/null | xargs basename 2>/dev/null)
  [ "$comm" = "claude" ] && { CLAUDE_PID="$p"; break; }
  p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  [ -z "$p" ] && break
done
[ -n "$CLAUDE_PID" ] || { echo "FAILED: no claude process in the parent chain" >&2; exit 1; }

REG="$HOME/.claude/sessions/$CLAUDE_PID.json"
[ -f "$REG" ] || { echo "FAILED: no registry entry at $REG" >&2; exit 1; }

read -r SID CWD NAME <<EOF
$(python3 - "$REG" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(d.get("sessionId", ""), d.get("cwd", ""), (d.get("name") or ""))
PY
)
EOF
[ -n "$SID" ] || { echo "FAILED: this session has no sessionId in the registry" >&2; exit 1; }
CALLSIGN="${WANT:-$NAME}"
[ -n "$CALLSIGN" ] || { echo "usage: fix-header.sh <CALLSIGN>   (this session has no name to reuse)" >&2; exit 2; }

# The call-sign is going into a shell command the human will paste. Refuse anything that
# could carry more than a name -- the same allowlist label-tab.sh uses, under C collation
# so a UTF-8 locale cannot widen the range.
case "$(LC_ALL=C printf '%s' "$CALLSIGN" | tr -d 'A-Za-z0-9 ._/&-')" in
  "") ;;
  *) echo "FAILED: call-sign may contain letters, digits, spaces and . _ / & - only" >&2; exit 2 ;;
esac

cat <<TXT
THE @ HEADER CANNOT BE FIXED FROM INSIDE THIS SESSION. It is read at launch and never
re-read; that was measured, not assumed. What follows is the only repair, and it KEEPS
this conversation -- --resume brings the whole session back.

Run this IN THIS TAB, after quitting Claude Code here:

  cd '$CWD' && claude --name '$CALLSIGN' --resume $SID

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

AFTER RELAUNCHING, say nothing about the header being fixed until you have seen it: send
one message to a peer and have them read back the name on it. The value you are changing
is one you cannot observe from in here.
TXT
