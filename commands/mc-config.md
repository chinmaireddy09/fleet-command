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

Its first lines give the current mode. Then **one `AskUserQuestion` carrying TWO questions**,
modelled on `/model` — because `/model` does two things in one screen and so does this.

**Question 1 — the mode.** Lead with the sentence `/model` leads with, so the screen says what
picking does rather than leaving it to be inferred:

> *"How should stations appear when deployed? Your pick becomes the default for every deploy on
> this machine."*

| Label | description — one line, no paragraphs |
|---|---|
| `Default (recommended)` | Background · nothing opens, works in every IDE and CLI |
| `Background — pinned` | Stays background even if the default changes |
| `Tab` | A new tab in this Terminal window |
| `Window` | Each station in its own window |

**Append ` ✓` to the label of whichever one is in force** — `Tab ✓`, not `Tab (current)`. Keep the
order above fixed so the row a person is looking for does not move between runs.

**Question 2 — how long it applies.** This is `/model`'s `Enter to set as default · s to use this
session only`, which a skill cannot put in the footer, so it becomes a question instead:

> *"Apply it how?"*

| Label | description |
|---|---|
| `Set as the default` | Every deploy from now on, on this machine |
| `Just this once` | The next deploy only, then it reverts |

Then write the answer with **one** command and stop:

```bash
# "Set as the default"
bash ~/.claude/skills/mission-control/mc-config.sh set spawn.mode <default|tab|window|background>
# "Just this once"
bash ~/.claude/skills/mission-control/spawn-pref.sh once <default|tab|window|background>
```

*What is NOT reachable, so nobody goes looking: `/model`'s green on the selected row, its
two-column layout (label and description on ONE line), and its footer key hints are Claude Code's
own picker chrome. A skill's `AskUserQuestion` renders a plain numbered list with the description
beneath the label, and its options 5 and 6 — "type something" and "chat about this" — are the
harness's, not ours. The `✓`, the wording, the fixed order and the second question are the parts
that are ours, so they are the parts that match.*

**A one-off, without changing the standing setting**, is `spawn-pref.sh once <mode>` — the
equivalent of `/model`'s `s to use this session only`. Offer it in words if someone asks for
"just this once"; it is a separate key and is cleared after the next deploy uses it.

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
