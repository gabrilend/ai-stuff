# 008-blocked-board

Ranks every source of waiting in an org by how much depends on it.

## What it is for

The vision's promise that "everyone can see what's blocking", computed. The
definitions are [what blocked means](../docs/004-what-blocked-means.md) and
nothing here adds to them.

## Exports

| Function | Returns |
| --- | --- |
| `waits(org)` | every unfed in port on a box that is not done, with its source (a box name, or `$` and an outside's name) |
| `board(org)` | one row per source — `source`, `state` (ready, vacant, outside, blocked), `owes`, `frees`, `reach`, `holders` — ranked by reach, frees, state, name |
| `render(rows)` | a plain-text table |
| `main(args)` | the board's exit status; `--ready` keeps only sources somebody can deliver now |

**Reach before frees.** In a stack of ten, the bottom frees one and reaches
nine; ranking by frees would hide it among every other single dependency.
**Loops are walked with a visited set** and a source is never in its own reach.
For an outside source, `holders` is the people who speak for it.
