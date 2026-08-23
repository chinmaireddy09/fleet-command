---
description: Coordinate any number of Claude sessions on one repo — who is working on what, what clashes with the file you are about to touch, and starting new sessions (alias for /mission-control)
argument-hint: [identify [call-sign] | sitrep | checkin <task> | call <station> | all-stations | alert <who> <what> | depends <what> | station <name> | deploy <station> | secure <station> | sweep <change> | silence | speak | state <normal|sweep running|mayday> | go | recover | countermeasures | standdown | tour]
---

Invoke the `mission-control` skill using the Skill tool, passing these arguments through
verbatim as the skill's `args`:

$ARGUMENTS

If no arguments were given, invoke it with no args — that is the board request.
