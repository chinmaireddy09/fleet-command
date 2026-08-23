---
description: Change how /mc deploy opens a station — tab, window, or background
argument-hint: "[once <mode>] — omit for the picker"
---

**Do NOT invoke the mission-control skill.** It is 176 KB and none of it is needed to change one
setting; loading it is what made this command take minutes and cost thousands of tokens for a
one-keystroke choice. Everything required is below.

Run exactly one command, then show the picker. No exploring, no extra reads, no commentary.

```bash
bash ~/.claude/skills/mission-control/mc-config.sh show
```

Its first lines give the current mode. Then **one `AskUserQuestion`**, modelled on `/model`:
**one short line per option, no paragraphs**, and the value in force marked `(current)`.

| Label | description — keep it to one line |
|---|---|
| `Default (recommended)` | Background · nothing opens, works in every IDE and CLI |
| `Tab` | A new tab in this Terminal window |
| `Window` | Each station in its own window |
| `Background — pinned` | Stays background even if the default changes |

Write it with **one** command, then stop:

```bash
bash ~/.claude/skills/mission-control/mc-config.sh set spawn.mode <default|tab|window|background>
```

Reply in **one sentence**: what it is now, and that `/mc-config` changes it any time.

**Never explain precedence, `env.MC_SPAWN_MODE`, `settings.json` or one-shot semantics in the
options.** The script keeps both places in agreement, so there is nothing for the user to know.
Those explanations are what turned four choices into four paragraphs nobody could read.

**`/mc-config once <mode>`** arms a one-shot for the next deploy only — run
`mc-config.sh set spawn.once <mode>` and say one sentence. This is the equivalent of `/model`'s
*use this session only*; it is not a second question, and the picker must not ask it.

**Any other key** — `spawn.launchCommand`, `spawn.permissionMode`, `naming.coordinator`,
`naming.stationStyle`, `tour` — is set only when the user names it: `mc-config.sh set <key>
<value>`. **Never offer them in the picker.** Three of them are things the mission-control
documentation tells you not to set, and a menu entry reads as a recommendation.

$ARGUMENTS
