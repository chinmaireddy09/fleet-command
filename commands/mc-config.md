---
description: Mission Control preferences — opens a picker to change how /mc deploy starts a station (tab, visible window, or background), plus the coordinator name and other per-machine settings
argument-hint: "[key] — omit to pick spawn.mode; or name a key: spawn.mode | spawn.launchCommand | spawn.permissionMode | naming.coordinator | naming.stationStyle | tour"
---

Invoke the `mission-control` skill using the Skill tool, passing this as the skill's `args`:

config $ARGUMENTS

This is the same entry point as `/mc config`, given its own command because it is the one
preference surface people reach for by name. **Open the picker immediately** — read the current
values with `mc-config.sh show`, then put an `AskUserQuestion` in front of the user with the
value in force marked `(current)`. Do not print a table and ask whether they want to change
anything; typing this command already answered that.
