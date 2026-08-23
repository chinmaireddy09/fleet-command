#!/bin/bash
# spawn-pref.sh [read|set <mode>|reset] — does this person want stations in a window?
#
# ONE JOB: own the `spawn.mode` key, the way tour-state.sh owns the tour flag. It is a
# script and not an inline edit for the same reason: this file is the user's own
# preferences, hand-written in places, and a model editing JSON inline is how a repo's
# example once got recorded as a machine-wide preference. Read-modify-write, one key
# touched, atomic replace -- never a torn config.
#
# WHY IT IS ASKED AND NOT DETECTED. $TERM_PROGRAM says where CONTROL happens to be
# running. It does not say where the user wants their stations, and the two are
# routinely different -- Control in an IDE terminal, stations wanted in real windows, or
# the reverse. **Detection alone is not consent.** So this is a question, asked once,
# recorded, and never asked again.
#
# WHY IT IS PER-MACHINE, NOT PER-REPO: ~/.claude/mission-control.json is user-level and
# deliberately outside any repo. A clone must never carry someone else's terminal choice
# -- it looks configured and is wrong.
#
# THE TWO MODES:
#   background  no window at all. `claude --bg`. Works identically on every OS and in
#               every IDE terminal, because no terminal is involved. THE DEFAULT.
#   tab         a new TAB in the current terminal window. On Terminal.app this is the one
#               mode that needs the Accessibility grant: Terminal publishes no scriptable
#               new-tab, so the tab comes from its own Shell > New Tab menu item. No
#               keystroke is synthesised, and it falls back to a window if it cannot.
#   window      a visible window/tab, opened through the terminal's OWN published API
#               (iTerm2 `create tab`, Terminal.app `do script`, tmux `new-window`,
#               kitty, WezTerm, Windows Terminal). Never a synthesised keystroke.
set -u
ACTION="${1:-read}"
CFG="${MC_CONFIG:-$HOME/.claude/mission-control.json}"

command -v python3 >/dev/null || { echo "SPAWN: unset   # python3 not found"; exit 0; }

case "$ACTION" in
  read|reset) ;;
  set) case "${2:-}" in background|window|tab) ;; *) echo "usage: spawn-pref.sh set <background|window|tab>" >&2; exit 2;; esac ;;
  *) echo "usage: spawn-pref.sh [read|set <background|window|tab>|reset]" >&2; exit 2 ;;
esac

ACTION="$ACTION" MODE="${2:-}" CFG="$CFG" python3 <<'PY'
import json, os, tempfile, datetime

cfg = os.environ["CFG"]; action = os.environ["ACTION"]; mode = os.environ["MODE"]

def load():
    try:
        with open(cfg) as f: return json.load(f)
    except FileNotFoundError: return {}
    except Exception: return None          # present but unreadable -- never overwrite it

d = load()
if d is None:
    # A config we cannot parse is somebody's file with something in it. Say so and do
    # nothing: asking once more is a smaller harm than truncating a preferences file.
    print("SPAWN: unset   # ~/.claude/mission-control.json exists but could not be parsed; not touching it")
    raise SystemExit(0)

spawn = d.get("spawn") if isinstance(d.get("spawn"), dict) else {}

if action == "read":
    m = spawn.get("mode")
    if m in ("background", "window", "tab"):
        print(f"SPAWN: {m}   # recorded {spawn.get('date','?')}")
    else:
        # UNSET IS NOT background. They mean the same thing to a deploy that has to run
        # anyway, and opposite things to the caller: one is a choice, the other is a
        # question nobody has asked yet. Collapsing them is how the ask never happens.
        print("SPAWN: unset   # never asked on this machine -- ask once, then record it")
    raise SystemExit(0)

if action == "reset":
    spawn.pop("mode", None); spawn.pop("date", None)
    if spawn: d["spawn"] = spawn
    else: d.pop("spawn", None)
else:
    spawn["mode"] = mode
    spawn["date"] = datetime.date.today().isoformat()
    spawn.setdefault("_comment",
        "How /mc deploy starts a station. background = no window (claude --bg), works "
        "in every IDE and CLI. window = a visible window opened via the terminal's own "
        "API. Run spawn-pref.sh reset to be asked again.")
    d["spawn"] = spawn

os.makedirs(os.path.dirname(cfg), exist_ok=True)
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(cfg)); os.close(fd)
with open(tmp, "w") as f: json.dump(d, f, indent=2)
os.replace(tmp, cfg)                                   # atomic; never a torn config
print(f"SPAWN: {mode}" if action == "set" else "SPAWN: reset")
PY
