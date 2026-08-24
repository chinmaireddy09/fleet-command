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
# IT RE-RUNS ONLY ON YOUR OWN EVENTS, SO IT NEEDS `refreshInterval`. Claude Code re-runs a
# status line when something happens IN THIS SESSION. Every other station's busy/idle
# transition happens somewhere else and produces no event here, so without a timer the line
# freezes at whatever it last saw -- reported 2026-08-24 as "it shows CHANNELS working but
# in reality its idle", and the registry was right while the line was stale. Set it
# alongside the command:
#
#   { "statusLine": { "type": "command", "refreshInterval": 5,
#                     "command": "bash ~/.claude/skills/mission-control/statusline.sh" } }
#
# This is the one status line for which the timer is not a nicety: everything it reports
# belongs to a DIFFERENT session, so local events are exactly the wrong clock.
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
MYSESSION=""   # `set -u` is on: this must exist even when stdin was a tty.
if [ ! -t 0 ]; then
  IN=$( { timeout 0.3 cat 2>/dev/null || true; } 2>/dev/null )
  CWD=$(printf '%s' "$IN" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  # WHICH ROW IS *ME*. Claude Code puts session_id on this stdin, and the registry stores
  # the same value as sessionId, so the two join without asking anything. Without it a
  # station has to read its own call-sign off a line of four to know where it is standing.
  MYSESSION=$(printf '%s' "$IN" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
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
ROOT="$ROOT" MYSESSION="${MYSESSION:-}" MC_SOCK_DIR="${MC_SOCK_DIR:-}" python3 - <<'PY' 2>/dev/null || true
import json, os, glob

root = os.environ.get("ROOT", "").rstrip("/")
if not root:
    raise SystemExit(0)

# TWO COLOURS, AND EACH ONE MEANS EXACTLY ONE THING: can you see this station or not.
#
#   magenta (201)     BACKGROUND -- no window anywhere. This line is the ONLY evidence it
#                     exists, so it gets the most arresting hue of the three: it is the one
#                     station you cannot find by looking at your screen.
#   orange (208)      A TAB in some window. Visible, but behind whichever tab is forward.
#   cyan (51)         ITS OWN WINDOW. Already the most visible thing you own, so it gets
#                     the calm one -- the row is a reminder, not a discovery.
#
# THE PRINT PRIMARIES, AND THE SPACING IS THE POINT. Roughly 120 degrees apart, which is as
# far as three vibrant colours can get from each other. That is what makes them memorable
# rather than merely bright: you stop reading the words and recognise the hue.
#
# TWO EARLIER SETS FAILED THE SAME TEST AND IT IS ALWAYS THE DIM ONE. An analogous triad
# (purple 141, blue 111, aqua 115) read as ONE colour at terminal size -- "i dont see any
# difference with colors" -- and a softer pastel set converged as soon as every station
# went idle. High chroma has the most to lose to dimming and still leaves plenty; that is
# the whole argument for vibrance here, and it is not an aesthetic one.
#
# NONE OF THE THREE IS A STATUS COLOUR -- not error red, warning yellow, success green or
# information blue. A call-sign is identity and visibility is not a health claim. Orange
# 208 is the closest to an alert hue and sits on TAB, the least alarming of the three roles.
#
# A per-station palette was built before this and reverted: a colour that means "which
# station" has to be LEARNED, and its meaning moved whenever the fleet did. A colour that
# means "visible or not" is read at a glance and never changes meaning.
#
# WHY IT IS MEASURED, NOT CONFIGURED. The obvious build gated the whole line on the spawn
# preference -- show it only when stations are set to background. That is wrong for a
# HYBRID fleet, and hybrids are a supported case: `spawn.once` exists precisely so one
# station can open in a window while the standing preference stays background. The
# preference describes FUTURE DEPLOYS; `kind` in the session registry describes what is
# actually running. Gating a live readout on a default is 6.89.0's bug in a new costume:
# reading a stale proxy instead of the state itself.
#
# NEITHER IS A STATUS COLOUR -- not error (red), warning (yellow), success (green) or
# information (cyan). A call-sign is identity, and the second signal is visibility; neither
# is a health claim. Both are also far from the footer's own yellow directly below.
CS_BG, CS_TAB, CS_WIN = 201, 208, 51

# WHICH MODE A STATION GOT is not in the session registry -- `kind` says `bg` or
# `interactive` and nothing finer -- so the deploy writes it down and this reads it back.
# A station started by hand has no record and falls back to the tab colour: it is visible
# somewhere, which is all this can honestly claim about it.
me = (os.environ.get("MYSESSION") or "").strip()

# WHICH TERMINAL WINDOW EACH SESSION SITS IN, recorded by window-probe.sh at identify.
# Nothing Claude Code writes distinguishes a tab from a window, and no env var carries it
# either (measured: Terminal.app's TERM_SESSION_ID is a per-session UUID, not w0t0p0), so
# the terminal is asked once per station and the answer is grouped here.
windows = {}
try:
    wf = os.environ.get("MC_WINDOWS") or os.path.expanduser("~/.claude/mission-control-windows.json")
    with open(wf) as fh:
        windows = (json.load(fh).get("sessions", {}) or {})
except Exception:
    pass

spawns = {}
try:
    f = os.environ.get("MC_SPAWNLOG") or os.path.expanduser("~/.claude/mission-control-spawns.json")
    with open(f) as fh:
        spawns = (json.load(fh).get("stations", {}) or {}).get(root, {}) or {}
except Exception:
    pass

# BUSY IS BOLD AND FULL COLOUR; IDLE IS THE SAME COLOUR DIMMED. Bold was removed in
# 6.91.0 because it changes the LETTERFORMS, so a station starting work nudges the rest of
# the line -- and it was asked for again, deliberately, after seeing both. It is the right
# call: on a proportional-width terminal font the shift is slight, and a station actually
# working is the one thing on this line worth catching your eye from across the desk.
# Idle stays dim and unbolded, so the contrast between the two is now two signals wide.
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

# `bg`, NOT `background`. Claude Code writes kind="bg" for a background session; this
# compared against "background" from 6.89.0 to 6.92.0 and so NEVER MATCHED ONE. It went
# unseen because the suite's own fixture wrote "background" -- a value the real registry
# does not produce. A test fixture that invents its input tests the fixture.
def is_bg(d):
    return (d.get("kind") or "") in ("bg", "background")

# ORDER: THE COORDINATOR FIRST, THEN BY WHEN EACH STATION TOOK ITS CALL-SIGN. Alphabetical
# was the old order and it is meaningless here -- a fleet is not a dictionary. Control is
# leftmost because it is the one post that is always the same post, so the eye starts from
# a fixed point; everyone else follows in the order they identified, which is the order you
# deployed them and therefore the order you already think of them in.
#
# `nameSince` is written by Claude Code when a session takes a name, so it is the real
# identification moment. NOT the file's mtime: that is rewritten on every status change, so
# ordering by it would reshuffle the whole line every time anybody went busy or idle.
COORD = "CONTROL"
try:
    cfg = os.environ.get("MC_CONFIG") or os.path.expanduser("~/.claude/mission-control.json")
    with open(cfg) as fh:
        c = (json.load(fh).get("naming", {}) or {}).get("coordinator", "")
    if c.strip():
        COORD = c.strip()
except Exception:
    pass  # a project that never named its coordinator uses the default, like mc-init does.

def order(d):
    n = d.get("name") or ""
    return (0 if n.upper() == COORD.upper() else 1,
            d.get("nameSince") or d.get("startedAt") or 0,
            n)

# GROUPING, NOT A STORED COUNT. Two stations reporting the same window id are tabs in one
# window; a station alone in its window has that window to itself. Derived on every render,
# so it re-answers itself as stations come and go -- a tab count taken at identify would be
# true for exactly as long as nobody opened or closed anything.
seen_windows = {}
for d in named:
    rec = windows.get(d.get("sessionId")) or {}
    w = rec.get("window") if isinstance(rec, dict) else rec
    if w:
        seen_windows[w] = seen_windows.get(w, 0) + 1

parts = []
for d in sorted(named, key=order):
    # NO `(bg)` SUFFIX ANY MORE. It shipped as `·bg`, became `(bg)` when the first form
    # read as a broken separator, and is now gone entirely: colour carries the same fact
    # without spending four characters per station on a line with no room to waste.
    # MEASURED BEATS RECORDED. `kind` comes from the live registry; the spawn log is a
    # note written at deploy time and can be stale if a station was relaunched by hand.
    # So a session reporting `bg` is background whatever the log remembers.
    if is_bg(d):
        c = CS_BG
    else:
        rec = windows.get(d.get("sessionId")) or {}
        w = rec.get("window") if isinstance(rec, dict) else rec
        tabs = rec.get("tabs", 0) if isinstance(rec, dict) else 0
        if w:
            # TWO MEASURES, WHICHEVER SAYS "TAB" WINS. `tabs` was counted by the terminal
            # and sees tabs that hold no station at all -- which is what a person means by
            # "its own window". The grouping re-derives live and catches a count that went
            # stale when somebody dragged a tab out. A station is called a window only when
            # BOTH agree it is alone, so the line never over-claims.
            alone = (tabs <= 1) and (seen_windows.get(w, 0) == 1)
            c = CS_WIN if alone else CS_TAB
        else:
            # No probe: fall back to what the deploy recorded, then to "visible somewhere".
            c = CS_WIN if spawns.get(d.get("name")) == "window" else CS_TAB
    # IDLE IS THE ONLY RESTING STATE; EVERYTHING ELSE IS WORK. This tested `== "busy"`
    # until 6.94.0 and so rendered `status: "shell"` -- a station running a shell command,
    # seen live on 2026-08-24 -- as though it were resting. Claude Code is free to add more
    # working states, and an allow-list of them would be wrong again the next time one
    # appears, so the test is inverted: only the state that MEANS resting reads as resting.
    # A record with no status at all stays dim: absence of evidence is not evidence of work.
    st = (d.get("status") or "idle").strip().lower()
    lit = "2;" if st in ("idle", "") else "1;"
    # YOUR OWN STATION IS BOXED. Colour answers "how visible is that station"; it cannot
    # answer "which one am I looking at right now", and on a screen of identical-looking
    # tabs that is the question you actually have. Reverse video fills the call-sign's own
    # colour behind it, so the box is a different SHAPE rather than one more hue to learn.
    # Never dimmed: the box is about where you are standing, not what you are doing, and a
    # dim box on an idle station is the case that has to stay readable.
    if me and d.get("sessionId") == me:
        parts.append(f"\033[7;38;5;{c}m {d.get('name')} {RESET}")
        continue
    parts.append(f"\033[{lit}38;5;{c}m{d.get('name')}{RESET}")
if unnamed:
    parts.append(f"{DIM}+{unnamed} unidentified{RESET}")

print(f"{DIM}fleet ·{RESET} " + f" {DIM}·{RESET} ".join(parts))
PY
