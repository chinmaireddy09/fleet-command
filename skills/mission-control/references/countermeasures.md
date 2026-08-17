## Countermeasures — when it has already gone wrong

Everything above is about *preventing* collisions. This is what to do once one has happened.

**Say it out loud first.** The instinct is to quietly fix it before anyone notices. That is how
a small mess becomes an unrecoverable one, because two people then "fix" it in opposite
directions at the same time.

```
ALL HANDS — Countermeasures. My commit 475fbc3 swallowed ~190 lines of two other
            stations' uncommitted work and I have already pushed it. Nothing is
            lost; the content is intact on main. Do not pull-rebase or revert
            until I say all clear. Investigating now. Out.
```

| What went wrong | Countermeasure |
|---|---|
| **You committed someone else's work** | **Do not rewrite pushed history.** Say so, name whose work it was, correct the record in the next commit. A wrong commit message costs far less than a rebase everyone must recover from |
| **A sweep broke something halfway** | Call **all clear anyway**, stating it failed. A hold nobody releases freezes every station. Then fix forward |
| **Two stations edited the same file** | Neither reverts. Keep **both** changes, in order, and say in the message that it holds two stations' work |
| **You pushed something wrong** | Nobody pulled it yet — fix it. They did — **fix forward with a new commit.** Rewriting shared history breaks everyone's copy |
| **A station went quiet holding work** | Recovery, not deletion. Find it, park it, record branch **and newest commit** |
| **Main is broken** | **Mayday.** Everyone stops pushing until it is green again |

**The rule underneath all of these: prefer a visible mess to an invisible fix.** Every row says
"tell people" before it says "repair", because the repair is usually easy and the confusion is
not.

**Never fix by deleting.** No `git checkout --` on work you did not write, no bare `git stash`,
no dropping a stash you have not read. Those turn a recoverable mess into a real loss.

---

