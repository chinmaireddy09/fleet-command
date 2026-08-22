---
description: Mission Control — the board, stations, dependency checks, sweeps and deploys (alias for /mission-control)
argument-hint: [identify [call-sign] | sitrep | checkin <task> | call <station> | all-stations | alert <who> <what> | depends <what> | station <name> | deploy <station> | secure <station> | sweep <change> | silence | speak | state <normal|sweep running|mayday> | go | recover | countermeasures | standdown]
---

Invoke the `mission-control` skill using the Skill tool, passing these arguments through
verbatim as the skill's `args`:

$ARGUMENTS

If no arguments were given, invoke it with no args — that is the board request.
