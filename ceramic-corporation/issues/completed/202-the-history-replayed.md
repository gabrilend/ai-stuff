# 202 — The org's history, replayed

| | |
| --- | --- |
| Phase | 2 — Maps of maps, and history |
| Blocked by | 104 |
| Blocks | — |
| Reads | [how a change is accepted](../../docs/003-how-a-change-is-accepted.md) |

## Current behavior

Applied proposals keep an `applied` line, and nothing checks that they explain
the map.

## Intended behavior

Starting from a first map, applying every applied proposal in date order
reproduces today's `org.map` exactly. A map edited by hand, outside any
proposal, is then detectable — which is the point of an organisation where
every change is a diff somebody agreed to.

## What Happened

Built as `src/015-history.lua` and `./replay-history`, with the workshop as
the example that keeps a history: founded with two people, then Kai joins
(change 1), then finishing becomes a role of its own between making and the
buyer (change 2, a doors change with its outside eye and its week), with a
third proposal still open. `./run-tests` replays every example. Decisions,
each also written into documents 002 and 003:

- **The founding map is a file, `first.map`.** History is opt-in: an org
  without one keeps none, which suits a generated map like the monorepo's.
  The bakery gets one equal to its map, since it has applied nothing.
- **`applied DATE N` gives the order.** Two proposals applied on one day to
  one block put their lines down in the order they were applied, and a date
  cannot say which came first. The proposal tool now writes N (one more than
  the highest in the org) with `--write`. N is optional in the format for a
  hand-kept history, but all-or-none (H2), and without numbers the order is
  inferred with a warning (W4).
- **Each step is judged as it stood the day it was applied**, setting aside
  answers dated later. An approval added afterwards does not make a change
  agreed after the fact.
- **A step that was not agreed is reported and the replay goes on**; a step
  that does not apply stops it, since nothing after it has a map to apply to.
- **The replay checks the map, not the state.** State churns daily without
  proposals by design.
