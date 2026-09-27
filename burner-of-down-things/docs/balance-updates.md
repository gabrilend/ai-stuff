# Balance updates

Append-only. Every change to a number or line the machine weighs by — the
grade boundaries, the center's weights — is written here with the date, the
old and new values, and why. Nothing here is ever edited or removed; a
change is a new entry below the last.

---

## 2026-09-27 — the first grade lines

Where: `src/053-grading.lua`, the table `RULE`.

| Setting | Value | Why |
|---|---|---|
| `foundation_level` | 0 | Touching an issue nothing else is built under means changing what everything stands on |
| `foundation_fraction` | 0.5 | A request that rebuilds half the design or more is, to the person, a rebuild; below half it is a repair |

A first draft: the owner said the grades will be offered "as we go along".
Real requests will show whether these lines are in the right places
(docs/010, questions 4 and 5).

## 2026-09-27 — the first center

Where: `src/058-the-center.lua`, the table `BALANCE`.

| Setting | Value | Why |
|---|---|---|
| `keep` | 0.97 per ledger line | Attention fades unless renewed: after about 23 lines a weight is halved, after about 76 it is a tenth. A request's handling is 10–20 lines, so the last few requests dominate |
| `request-received` | 3 | The person pointing at something is the strongest signal there is |
| `graded`, per touched issue | 1 | A request's attention spreads to the issues it touches |
| `build-failed`, `describe-failed`, `breach` | 2 | Trouble draws attention |
| `built`, `described` | 0.5 | Settled things still count a little |

Ordering follows from these: a request's score is its own weight plus its
touched issues' weights, so the most recently noticed request goes first
unless an older one touches heavier issues. A first draft (docs/010,
question 6).
