# Attribution

**Fleet Command** is original work by **Chinmai Reddy ([@chinmaireddy09](https://github.com/chinmaireddy09))**,
released under the [Fleet Command License 1.1](LICENSE).

## Prior work this learned from

**Fleet Command is original work, and it did not arrive from nowhere.** Naming what it learned
from costs nothing and is the same standard this project asks of the people who use it.

**[gstack](https://github.com/garrytan/gstack) — MIT, © 2026 Garry Tan.**

- **The preamble pattern.** `skills/mission-control/mc-init.sh` — *one bash block, run once per
  skill invocation, emitting greppable `KEY: VALUE` lines that everything downstream reads instead
  of re-deriving* — is adapted from gstack's *"Preamble (run first)"*. The **shape** is gstack's;
  the keys, the logic and the code are this project's, and it is a separate script rather than an
  inline block.
- **`skills/progress-and-log` exists because of gstack, by disagreeing with it.** It is a
  deliberately gstack-free checkpoint skill, written so progress can be captured without pulling
  in `context-save`'s machinery, and it explicitly declines `context-save`'s trigger phrases. That
  is a divergence rather than a derivation — but it is not independent of gstack and should not be
  presented as though it were.

**What this is not.** No gstack code is copied into this repository, and no part of it is
distributed here. A pattern is an idea, and MIT asks nothing for ideas — this section exists
because **condition 2 of this project's own licence argues that credit belongs where people read
it, and a credit buried in a shell-script comment is precisely the failure that condition was
written against.** Applying that standard to ourselves is the least it can mean.

If you know of an influence missing from this list, that is a bug worth filing.

## The credit line

Carry this somewhere people actually see it — your README, your docs, an about page, or the
interface itself:

> Fleet Command by Chinmai Reddy ([@chinmaireddy09](https://github.com/chinmaireddy09))
> https://github.com/chinmaireddy09/fleet-command

If you changed it, say so alongside the credit — for example: *"adapted from Fleet Command by
Chinmai Reddy; station names and test commands modified."*

## What the licence requires

You may use, copy, modify, merge, publish, distribute, sublicense and sell this, including
commercially.

| # | Condition | In plain words |
|---|-----------|----------------|
| 1 | Notice | keep LICENSE with any copy |
| 2 | Visible credit | the credit must be somewhere people read — not buried in a file nobody opens |
| 3 | State changes | if you modified it, say so, so nobody is misled about which parts are the author's |
| 4 | No endorsement | you may not imply the author endorses you or your project |
| 5 | Patents | you get one; sue over patents and you lose it |
| 6 | Breach | miss 1–4 and the licence lapses; fix it within 30 days and it returns |
| 7 | Contributions | what you send in is licensed on these same terms |

Condition 2 is the reason this licence exists rather than using MIT. MIT would let the credit
sit in a file nobody ever opens; this does not.

## Two things to know before adopting it

**GitHub will show "Other".** It can only name licences it recognises from a fixed list of
standard ones — MIT, Apache, GPL, CC BY and so on. **A custom licence can never be
auto-detected.** That is the trade for having terms of your own rather than someone else's.

**It is not GPL-compatible.** Condition 2 is an added restriction beyond what the GPL permits,
so this cannot be combined into a GPL-licensed project. If you need that, ask the author.

## Where the attribution lives

So it survives someone lifting a single file out of the repo:

| Place | What it carries |
|---|---|
| `LICENSE` | copyright notice and the seven conditions |
| `ATTRIBUTION.md` | this file — the credit line to copy |
| `README.md` | credit in the ownership section |
| `CONTRIBUTING.md` | states that PRs are licensed under condition 7 |
| every `skills/*/SKILL.md` | `author`, `source`, `license`, `attribution` in the frontmatter |
| `VOCABULARY.md` | footer credit |
