#!/bin/bash
# statusline.sh — the live fleet, by call-sign, under your prompt.
#
# Claude Code's own footer counts shells and offers "← for agents"; a skill cannot add to
# it. `statusLine` in ~/.claude/settings.json is the supported way to put something there:
#
#   { "statusLine": { "type": "command",
#                     "command": "bash ~/.claude/skills/mission-control/statusline.sh" } }
#
# IT SPAWNS NOTHING, AND THAT IS THE DESIGN. The obvious implementation shells out to
# `claude agents --json`; do not. Measured 2026-08-24: that call takes ~0.21s, which a
# status line pays on every render -- and worse, backgrounding it to hide the cost STARTS
# THE BACKGROUND SERVICE, a long-lived process that inherits the caller's stdout and holds
# it open. A shell hung for two minutes that way. A caching-and-locking version was written
# to work around it and was thrown away: the cost was never the point, the subprocess was.
#
# Everything needed is already on disk and is written by Claude Code itself:
#   ~/.claude/sessions/<pid>.json   name, cwd, kind, status -- one file per session
#   /tmp/cc-socks/<pid>.sock        exists only while that session is alive
# Reading files is microseconds, cannot hang, and cannot start a daemon.
#
# ON-FLEET ONLY. The registry holds every Claude session on the machine, including other
# projects. A status line showing somebody's unrelated window as if it were your fleet is
# the "radar without IFF" confusion the skill warns about, in the one place on screen you
# cannot look away from.
set -u

# READING STDIN MUST NOT BE ABLE TO BLOCK. Claude Code hands this script a JSON context on
# stdin, so the obvious `IN=$(cat)` works there and hangs FOREVER anywhere else -- run from
# a pipeline, a script, or a test harness, stdin is not a tty and not closed, and `cat`
# waits for input that never arrives. It wedged a build here on 2026-08-24.
# A status line that can hang is worse than no status line: it hangs the prompt.
CWD=""
if [ ! -t 0 ]; then
  IN=$( { timeout 0.3 cat 2>/dev/null || true; } 2>/dev/null )
  CWD=$(printf '%s' "$IN" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi
[ -n "$CWD" ] || CWD="$PWD"
ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$CWD")
# A station's worktree lives under <repo>/.claude/worktrees/<name>, so fold it back to the
# repo -- otherwise four stations read as four unrelated repositories and the line is empty
# in exactly the fleet it is meant to describe.
case "$ROOT" in */.claude/worktrees/*) ROOT="${ROOT%%/.claude/worktrees/*}" ;; esac

ROOT="$ROOT" python3 - <<'PY' 2>/dev/null || true
import json, os, glob

root = os.environ.get("ROOT", "").rstrip("/")
if not root:
    raise SystemExit(0)

DIM, RESET, BOLD = "\033[2m", "\033[0m", "\033[1m"
here = os.path.basename(root)

rows = []
for f in glob.glob(os.path.expanduser("~/.claude/sessions/*.json")):
    try:
        with open(f) as fh: d = json.load(fh)
    except Exception:
        continue
    pid = d.get("pid")
    # The socket is the liveness test. A registry file outlives the session that wrote it,
    # so trusting the file alone puts dead stations on screen permanently -- the board's
    # own "a row is a claim, not a measurement" rule, applied to the status line.
    if not pid or not os.path.exists(f"/tmp/cc-socks/{pid}.sock"):
        continue
    cwd = (d.get("cwd") or "").rstrip("/")
    if not (cwd == root or cwd.startswith(root + "/")):
        continue
    rows.append(d)

if not rows:
    raise SystemExit(0)

# A generated handle is an address, never a name -- the skill's own rule. Printing
# `acme-shop-4d` here would put the one string it says never to use in prose permanently on
# screen, so unidentified sessions are counted instead of named.
named, unnamed = [], 0
for d in rows:
    n = (d.get("name") or "").strip()
    # Two shapes of generated handle, and the second was missed on the first run:
    # `<repo>-<hex>` from a hand-started session, and a BARE HEX id with no repo prefix at
    # all. `fb7b47a7` rendered as if it were a call-sign, which is precisely the address-as-
    # a-name confusion this filter exists to prevent.
    is_hex = len(n) >= 6 and all(c in "0123456789abcdef" for c in n.lower())
    if not n or is_hex or (n.startswith(here + "-") and len(n) > len(here) + 1):
        unnamed += 1
    else:
        named.append(d)

parts = []
for d in sorted(named, key=lambda x: (x.get("kind") != "background", (x.get("name") or ""))):
    bg = "·bg" if d.get("kind") == "background" else ""
    hot = d.get("status") == "busy"
    parts.append(f"{BOLD if hot else DIM}{d.get('name')}{bg}{RESET}")
if unnamed:
    parts.append(f"{DIM}+{unnamed} unidentified{RESET}")

print(f"{DIM}fleet{RESET} " + " ".join(parts))
PY
