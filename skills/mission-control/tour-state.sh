#!/bin/bash
# tour-state.sh [read|complete|decline|reset] — has this person been shown the first run?
#
# ONE JOB: own the flag that decides whether the first-run walkthrough appears. It is a
# script and not an inline edit because this file is the user's own preferences, it is
# hand-written prose in places, and a model editing JSON inline is how the `naming` key
# got a repo's example recorded as a machine-wide preference once already. Read-modify-
# write, one key touched, atomic replace -- never a torn config.
#
# WHERE THE FLAG LIVES, AND WHY IT IS PER-MACHINE, NOT PER-REPO:
# ~/.claude/mission-control.json is USER-LEVEL and deliberately outside any repo -- its
# own comment says a clone must never carry someone else's terminal choice. The same
# reasoning applies here: the walkthrough teaches THE TOOL, not the project. Someone who
# has taken it should not retake it in every new checkout, and a colleague cloning your
# repo should not inherit your answer.
#
# THREE OUTCOMES, NOT TWO. `completed` and `declined` are both terminal -- nagging
# somebody who said "not now" every time they type /mc is worse than never offering.
# Abandoning midway records NOTHING, so it offers again: only a finished or a refused
# tour is settled. `/mc tour` replays it whatever the flag says.
#
# `version` is what lets a future rewrite re-offer once, without anyone hand-editing a
# config: bump TOUR_VERSION here and a person who took v1 is offered v2 exactly once.
set -u
TOUR_VERSION=2
ACTION="${1:-read}"
CFG="$HOME/.claude/mission-control.json"

command -v python3 >/dev/null || { echo "TOUR: unknown   # python3 not found"; exit 0; }

case "$ACTION" in
  read|complete|decline|reset) ;;
  *) echo "usage: tour-state.sh [read|complete|decline|reset]" >&2; exit 2 ;;
esac

ACTION="$ACTION" CFG="$CFG" TOUR_VERSION="$TOUR_VERSION" python3 <<'PY'
import json, os, sys, tempfile, datetime

cfg = os.environ["CFG"]; action = os.environ["ACTION"]; ver = int(os.environ["TOUR_VERSION"])

def load():
    try:
        with open(cfg) as f: return json.load(f)
    except FileNotFoundError: return {}
    except Exception: return None          # present but unreadable -- never overwrite it

d = load()
if d is None:
    # A config we cannot parse is somebody's file with something in it. Say so and do
    # nothing: re-offering a tour is a smaller harm than truncating a preferences file.
    print("TOUR: unknown   # ~/.claude/mission-control.json exists but could not be parsed; not touching it")
    raise SystemExit(0)

tour = d.get("tour") if isinstance(d.get("tour"), dict) else {}

if action == "read":
    state = tour.get("state"); taken = tour.get("version")
    if state in ("completed", "declined") and isinstance(taken, int) and taken >= ver:
        print(f"TOUR: taken   # {state} {tour.get('date','?')} (v{taken})")
    elif state in ("completed", "declined"):
        # CARRY THE DATE. The returning-user offer is told to say "you took this on <date>" --
        # that one clause is what makes it read as a changelog rather than as the tool having
        # forgotten it already asked. It cannot say it if this line does not print it.
        print(f"TOUR: not taken   # {state} {tour.get('date','?')} on an older version (v{taken}); offer v{ver} once")
    else:
        print("TOUR: not taken   # first run on this machine -- offer the walkthrough")
    raise SystemExit(0)

if action == "reset":
    d.pop("tour", None)
else:
    d["tour"] = {
        "state": "completed" if action == "complete" else "declined",
        "version": ver,
        "date": datetime.date.today().isoformat(),
        "_comment": "Set by /mc's first-run walkthrough. Delete this key (or run "
                    "tour-state.sh reset) to be offered it again.",
    }

os.makedirs(os.path.dirname(cfg), exist_ok=True)
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(cfg)); os.close(fd)
with open(tmp, "w") as f: json.dump(d, f, indent=2)
os.replace(tmp, cfg)                                   # atomic; never a torn config
print(f"TOUR: {action}d" if action != "reset" else "TOUR: reset")
PY
