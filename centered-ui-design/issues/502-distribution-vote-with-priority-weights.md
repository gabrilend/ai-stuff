# 502 — The distribution vote, with priority weights

**Phase:** 5 — The round table
**Blocked by:** 501, 401

**Blocks**: 503, 504, 505
**Related documents:** docs/datapath-team-vote.md

## Current Behavior

Resources are split by a fixed table from `input/`, with a warning printed
every game (see 401).

## Intended Behavior

- Each seat has a distribution ballot per resource (how it should split
  between production, upgrades, heroes, reserve) and a set of priority
  weights over all ballots, summing to the same total for every seat.
- The tally per resource is the weighted average of seats' splits, each
  weighted by that seat's priority for that resource.
- The ballot is shown on dials (each resource's split, each priority
  weight, the shared total) and edited only with painted buttons: a
  button per category to shift a share toward it, a button per ballot to
  raise its weight (which lowers the others, since the total is fixed).
  The dials only show; they are never turned.
- When this issue is done, the fixed split from `input/` and its warning are
  removed.

## Suggested Implementation Steps

1. `src/NNN-ballots.lua` and `src/NNN-tally.lua` (data side).
2. Ballot rings on the console (view side).
3. Tests: one seat with all weight on metal decides metal's split alone;
   equal weights give the plain average.

## Open questions

- Voting is the one place the dashboard is used for something other than
  orders. Is editing a ballot with buttons right, or should a vote also be
  "told" to someone (a steward on the map)?
