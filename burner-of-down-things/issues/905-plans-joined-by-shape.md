# 905 — Plans joined by shape

*"I gotta take this integer array and this string of text and create an image off of it? Great!"* — a plan is stations in order, each output the next input, every joint checked before anything runs ([068](../docs/068-datapath-the-switchboard.md)).

## Current Behavior

All four pieces are built (issues/completed/905a-905d), in
`src/083-the-shape-graph.lua` and `src/127-plans.lua`: the station table
read as a graph, the shortest chain found by search over shapes, every
joint checked before anything runs, and a plan run with each result kept
as a new parcel. Both of this issue's tests hold, against a fixture table
shaped like 902d's (the real table holds one station today).

What is left: nothing yet *calls* a plan when a parcel arrives — that is
the router (904), which this issue is blocked by. Kept open for that
wiring.

## Intended Behavior

- When no single station takes a parcel's shape to the wanted one, a plan is found through the station table: the shortest chain whose joints fit (a search over shapes, no model).
- Every joint is checked before the first station runs; a joint that does not fit is refused, named.
- Each station's result is a new parcel, recorded, and handed on.

## Suggested Implementation Steps

1. Finding plans. **Test:** `integer-array + text → image` becomes table → chart → png; an impossible shape says which type cannot be reached.
2. Running a plan. **Test:** a two-station plan runs end to end and every intermediate parcel is kept.

## Sub-issues

- 905a — the shape graph
- 905b — shortest-chain search
- 905c — joint checking
- 905d — plan execution

## Blocked by

- 904
