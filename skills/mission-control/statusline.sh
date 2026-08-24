#!/bin/bash
# statusline.sh — how many Claude sessions are live on this repo, under your prompt.
#
# Claude Code's own footer counts shells and offers "← for agents"; a skill cannot add to
# it. `statusLine` in ~/.claude/settings.json is the supported way to put something there:
#
#   { "statusLine": { "type": "command",
#                     "command": "bash ~/.claude/skills/mission-control/statusline.sh" } }
#
# CALL-SIGNS LOOK LIKE `1 shell`. Claude Code puts its own live values in the footer as
# coloured text between dim separators, and a station call-sign is exactly that kind of
# value: live, countable, yours. So the fleet line borrows that grammar rather than
# inventing one.
#
# COLOUR IS FOR IDENTITY, DIM TEXT IS FOR THE RESIDUE. A generated handle is an ADDRESS,
# not a name (VOCABULARY.md), so it can never be printed -- but the session is still real
# and still on the repo, so it is counted in dim text after the chips. Highlighting the
# unidentified would emphasise the one thing on the line that carries no information.
#
# STATIONS IN THE CHIPS, NOT SESSIONS. A station is a post; a session MANS one. Only a
# session that has taken a call-sign mans anything, and only those get chips.
#
# A FLEET OF ONE IS NOT A FLEET -- BUT AN IDENTIFIED STATION IS ALWAYS WORTH SHOWING. With
# a single unidentified session and nothing else, the line a solo user actually saw was
# "fleet +1 unidentified": the tool describing the reader to themselves, in a word that
# sounds like a fault. That case prints NOTHING. One session that HAS identified still
# renders its chip -- that is the confirmation it identified at all.
#
# IT SPAWNS NOTHING. The obvious implementation shells out to `claude agents --json`; do
# not. Measured 2026-08-24: that call takes ~0.21s, which a status line pays on every
# render -- and worse, backgrounding it to hide the cost STARTS THE BACKGROUND SERVICE, a
# long-lived process that inherits the caller's stdout and holds it open. A shell hung for
# two minutes that way. A caching-and-locking version was written to work around it and was
# thrown away: the cost was never the point, the subprocess was.
#
# Everything needed is already on disk and is written by Claude Code itself:
#   ~/.claude/sessions/<pid>.json   name, cwd, kind, status -- one file per session
#   /tmp/cc-socks/<pid>.sock        exists only while that session is alive
# Reading files is microseconds, cannot hang, and cannot start a daemon.
#
# ON-FLEET ONLY. The registry holds every Claude session on the machine, including other
# projects. A status line counting somebody's unrelated window as if it were your fleet is
# the "radar without IFF" confusion the skill warns about.
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

# MC_SOCK_DIR exists for the test harness ONLY. The suite must never write a fake liveness
# marker into the real /tmp/cc-socks -- a test that mutates live state to prove a point is
# worse than an untested line (6.51.0). Unset in every real render.
ROOT="$ROOT" MC_SOCK_DIR="${MC_SOCK_DIR:-}" python3 - <<'PY' 2>/dev/null || true
import json, os, glob

root = os.environ.get("ROOT", "").rstrip("/")
if not root:
    raise SystemExit(0)

# ONE COLOUR, VIOLET (256-colour 141), FOR EVERY CALL-SIGN. A per-station palette was
# built and reverted: it made the line prettier and less readable, because a reader has to
# learn what each colour MEANS before it tells them anything, and the meaning changes the
# moment a station joins or leaves. Violet is the choice because it is the one hue in a
# terminal that carries NO convention -- not error (red), not warning (yellow), not success
# (green), not information (blue/cyan). A call-sign is identity, not status, so it should
# borrow no status colour. It is also furthest from the footer's own yellow directly below.
CS = 141

# BUSY IS FULL COLOUR, IDLE IS THE SAME COLOUR DIMMED -- never bold. Bold changes the
# LETTERFORMS, so a station starting work reflowed the whole line; with three stations
# working that is near-constant movement under the prompt. Brightness changes nothing
# about the glyphs, so the line holds still while it updates.
DIM, RESET = "\033[2m", "\033[0m"
socks = os.environ.get("MC_SOCK_DIR") or "/tmp/cc-socks"
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
    if not pid or not os.path.exists(os.path.join(socks, f"{pid}.sock")):
        continue
    cwd = (d.get("cwd") or "").rstrip("/")
    if not (cwd == root or cwd.startswith(root + "/")):
        continue
    rows.append(d)

named, unnamed = [], 0
for d in rows:
    n = (d.get("name") or "").strip()
    # Two shapes of generated handle, and the second was missed on the first run:
    # `<repo>-<hex>` from a hand-started session, and a BARE HEX id with no repo prefix at
    # all. `fb7b47a7` rendered as if it were a call-sign, which is precisely the address-
    # as-a-name confusion this filter exists to prevent.
    is_hex = len(n) >= 6 and all(c in "0123456789abcdef" for c in n.lower())
    if not n or is_hex or (n.startswith(here + "-") and len(n) > len(here) + 1):
        unnamed += 1
    else:
        named.append(d)

# Nothing identified and nobody else here: there is no fleet to report, only the reader.
if not named and len(rows) < 2:
    raise SystemExit(0)

parts = []
for d in sorted(named, key=lambda x: (x.get("kind") != "background", (x.get("name") or ""))):
    # `(bg)`, NOT the `·bg` this first shipped with. Separators on this line are `·`, so a
    # marker built from one read as a broken separator: `CHANNELS·bg · FRONTEND` parses by
    # eye as three items, one of them called "bg".
    bg = f"{DIM} (bg){RESET}" if d.get("kind") == "background" else ""
    lit = "" if d.get("status") == "busy" else "2;"
    parts.append(f"\033[{lit}38;5;{CS}m{d.get('name')}{RESET}{bg}")
if unnamed:
    parts.append(f"{DIM}+{unnamed} unidentified{RESET}")

print(f"{DIM}fleet ·{RESET} " + f" {DIM}·{RESET} ".join(parts))
PY
