#!/bin/bash
# mc-config.sh [show|set <key> <value>|unset <key>|keys] — the preferences surface.
#
# WHY THIS EXISTS. Every preference here was reachable before, but only through the
# moment that first recorded it: `spawn-pref.sh reset` and be asked again, `tour-state.sh
# reset` and be re-offered. **A preference you can only change by making the tool forget
# you answered is not a setting, it is a fresh install.** Claude Code's own `/config`
# shows what is set and lets you change it in place; this is the same surface for this
# skill's file, and `/mc config` is the way in.
#
# OWNERSHIP IS NOT DUPLICATED. Two keys already have scripts that own them, with their
# own validation and their own reasoning written down. This DELEGATES to those rather
# than reimplementing them:
#     spawn.mode  -> spawn-pref.sh      tour  -> tour-state.sh
# A second writer for one key is how two files disagree about what the user chose.
#
# EVERYTHING ELSE is written here with the same discipline those two use: read-modify-
# write, one key touched, atomic replace, and a file we cannot parse is never overwritten.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CFG="${MC_CONFIG:-$HOME/.claude/mission-control.json}"
ACTION="${1:-show}"

command -v python3 >/dev/null || { echo "mc-config: python3 not found -- cannot read preferences" >&2; exit 2; }

case "$ACTION" in
  show|keys) ;;
  set)   [ $# -ge 3 ] || { echo "usage: mc-config.sh set <key> <value>" >&2; exit 2; } ;;
  unset) [ $# -ge 2 ] || { echo "usage: mc-config.sh unset <key>" >&2; exit 2; } ;;
  *) echo "usage: mc-config.sh [show|set <key> <value>|unset <key>|keys]" >&2; exit 2 ;;
esac

KEY="${2:-}"; VAL="${3:-}"

# ── delegation, before anything else touches the file ────────────────────────────
if [ "$ACTION" = "set" ] && [ "$KEY" = "spawn.mode" ]; then
  exec bash "$HERE/spawn-pref.sh" set "$VAL"
fi
if [ "$ACTION" = "unset" ] && [ "$KEY" = "spawn.mode" ]; then
  exec bash "$HERE/spawn-pref.sh" reset
fi
if [ "$ACTION" = "set" ] && [ "$KEY" = "tour" ]; then
  case "$VAL" in
    completed) exec bash "$HERE/tour-state.sh" complete ;;
    declined)  exec bash "$HERE/tour-state.sh" decline ;;
    reset)     exec bash "$HERE/tour-state.sh" reset ;;
    *) echo "mc-config: tour is completed | declined | reset -- got \"$VAL\"" >&2; exit 2 ;;
  esac
fi
if [ "$ACTION" = "unset" ] && [ "$KEY" = "tour" ]; then
  exec bash "$HERE/tour-state.sh" reset
fi

ACTION="$ACTION" KEY="$KEY" VAL="$VAL" CFG="$CFG" python3 <<'PY'
import json, os, re, sys, tempfile, datetime

cfg=os.environ["CFG"]; action=os.environ["ACTION"]; key=os.environ["KEY"]; val=os.environ["VAL"]

# key -> (validator, human description, what "not set" actually does)
def one_of(*opts):
    return (lambda v: v in opts, "one of: " + " | ".join(opts))
CALLSIGN=(lambda v: bool(re.fullmatch(r"[A-Za-z0-9 ._/&-]{1,64}", v)),
          "letters, digits, spaces and . _ / & - only")
SPEC={
 "spawn.mode":           (one_of("default","background","window","tab")[0], "default | background | window | tab",
                          "nobody has been asked yet -- the next deploy asks and records it"),
 "spawn.launchCommand":  (lambda v: bool(re.fullmatch(r"[A-Za-z0-9._/-]{1,64}", v)),
                          "a bare binary name, e.g. claude",
                          "claude"),
 "spawn.permissionMode": (one_of("null","acceptEdits","auto","manual","plan","bypassPermissions")[0],
                          "null | acceptEdits | auto | manual | plan | bypassPermissions",
                          "null -- a station prompts for its own pushes, like any session"),
 "naming.coordinator":   (CALLSIGN[0], CALLSIGN[1],
                          "this project's MISSION-CONTROL.md decides, else plain CONTROL"),
 "naming.stationStyle":  (one_of("same","long-callsign-short-handle","per-station")[0],
                          "same | long-callsign-short-handle | per-station",
                          "same -- one word is both call-sign and address"),
 "tour":                 (one_of("completed","declined","reset")[0], "completed | declined | reset",
                          "not taken -- the walkthrough is offered on first run"),
}
# Keys that mattered to a mechanism that no longer exists. Named so they can be SEEN and
# cleared, rather than sitting in the file looking like live configuration.
STALE={
 "spawn.platform":  "detected at runtime now; nothing reads it",
 "spawn.terminal":  "the recipe is chosen by what is actually running, not by a recorded name",
 "spawn.placement": "replaced by spawn.mode in 6.78.0. `tab` referred to the keystroke path that was removed",
}

def load():
    try:
        with open(cfg) as f: return json.load(f)
    except FileNotFoundError: return {}
    except Exception: return None

def get(d, dotted):
    cur=d
    for p in dotted.split("."):
        if not isinstance(cur, dict) or p not in cur: return None
        cur=cur[p]
    return cur

# `keys` is a dump of the SCHEMA and does not read the file at all, so it is answered
# before the config is even loaded. It used to sit after the unreadable-config bail and
# so failed on exactly the machine where it is most useful: the caller needs the valid
# values in order to ASK the user something, and a broken preferences file is a reason
# to ask, not a reason to be unable to.
if action=="keys":
    for k,(_,desc,dflt) in SPEC.items(): print(f"{k}\t{desc}\t{dflt}")
    raise SystemExit(0)

d=load()
if d is None:
    print(f"mc-config: {cfg} exists but could not be parsed. Not touching it.")
    print("           Fix or remove the file, then run this again.")
    raise SystemExit(0)

if action=="show":
    print(f"MISSION CONTROL PREFERENCES  ·  {cfg}")
    print()
    # ONE SCREEN MUST TELL THE WHOLE TRUTH. spawn.mode can also be set from Claude Code's
    # own settings.json as env.MC_SPAWN_MODE, and that value OUTRANKS this file. Showing
    # only the file would render a value that is not the one in force -- a config screen
    # that is confidently wrong is worse than one that omits the setting, because the
    # reader has no reason to look further. Reported by the user 2026-08-24, asking why
    # the setting was not in Claude's own /config: the honest answer is that /config
    # renders a fixed schema and cannot be extended, so THIS is the screen, and it has to
    # carry both sources.
    envmode = os.environ.get("MC_SPAWN_MODE", "")
    if envmode:
        filemode = (d.get("spawn") or {}).get("mode")
        if envmode == filemode:
            print(f"  IN FORCE: spawn.mode = {envmode}   (settings.json env, agreeing with this file)")
        elif filemode:
            print(f"  ⚠ IN FORCE: spawn.mode = {envmode}   — from ~/.claude/settings.json env.MC_SPAWN_MODE,")
            print(f"    which OVERRIDES the {filemode!r} recorded below. Change the env entry, or clear it")
            print( "    to let this file decide again.")
        else:
            print(f"  IN FORCE: spawn.mode = {envmode}   (settings.json env.MC_SPAWN_MODE; nothing recorded here)")
        print()
    width=max(len(k) for k in SPEC)
    for k,(_,desc,dflt) in SPEC.items():
        if k=="tour":
            t=d.get("tour") if isinstance(d.get("tour"),dict) else {}
            v=t.get("state"); when=t.get("date")
        else:
            v=get(d,k); when=get(d,k.rsplit(".",1)[0]+".date") if k.startswith("spawn.") else None
        if k == "spawn.mode" and v == "default":
            print(f"  {k.ljust(width)}  Default → background   (set {when})" if when
                  else f"  {k.ljust(width)}  Default → background")
        elif v is None:
            print(f"  {k.ljust(width)}  (not set)   → {dflt}")
        else:
            print(f"  {k.ljust(width)}  {v}{('   (set '+when+')') if when else ''}")
    found=[k for k in STALE if get(d,k) is not None]
    if found:
        print()
        print("  STALE — written by an older version, read by nothing today:")
        for k in found: print(f"    {k} = {json.dumps(get(d,k))}   # {STALE[k]}")
        print("    Clear with: mc-config.sh unset <key>. Harmless where they are; just not live.")
    print()
    print("  change:  mc-config.sh set <key> <value>        (or /mc config)")
    print("  clear:   mc-config.sh unset <key>")
    raise SystemExit(0)

# ── set / unset ─────────────────────────────────────────────────────────────────
if key not in SPEC and key not in STALE:
    print(f"mc-config: unknown key \"{key}\"", file=sys.stderr)
    print("known keys: " + ", ".join(list(SPEC)+list(STALE)), file=sys.stderr)
    raise SystemExit(2)

if action=="set":
    # STALE is checked BEFORE the SPEC lookup, not after. Reversed, a stale key raises a
    # KeyError out of the lookup and the user gets a Python traceback instead of the
    # sentence explaining why the key is dead -- which is the entire point of naming it.
    if key in STALE:
        print(f"mc-config: \"{key}\" is not read by anything today ({STALE[key]}). Refusing to write it.", file=sys.stderr)
        print(f"           Clear it instead:  mc-config.sh unset {key}", file=sys.stderr)
        raise SystemExit(2)
    ok,desc=SPEC[key][0],SPEC[key][1]
    if not ok(val):
        print(f"mc-config: {key} takes {desc} -- got \"{val}\"", file=sys.stderr)
        raise SystemExit(2)

parts=key.split(".")
if action=="unset":
    cur=d
    for p in parts[:-1]:
        if not isinstance(cur.get(p), dict): cur=None; break
        cur=cur[p]
    if cur is not None: cur.pop(parts[-1], None)
else:
    cur=d
    for p in parts[:-1]:
        if not isinstance(cur.get(p), dict): cur[p]={}
        cur=cur[p]
    cur[parts[-1]] = None if val=="null" else val
    if parts[0]=="spawn": d["spawn"]["date"]=datetime.date.today().isoformat()

os.makedirs(os.path.dirname(cfg) or ".", exist_ok=True)
fd,tmp=tempfile.mkstemp(dir=os.path.dirname(cfg) or "."); os.close(fd)
with open(tmp,"w") as f: json.dump(d,f,indent=2)
os.replace(tmp,cfg)                                    # atomic; never a torn config
print(f"{key} = {val}" if action=="set" else f"{key} cleared")
if action=="set" and key=="spawn.permissionMode" and val=="bypassPermissions":
    print()
    print("⚠️  Every station deployed from now on runs with ALL permission checks bypassed,")
    print("    unattended, in a worktree of this repo. Deploy will never set this for you --")
    print("    you have set it deliberately, and it stays set until you clear it:")
    print("      mc-config.sh unset spawn.permissionMode")
PY
