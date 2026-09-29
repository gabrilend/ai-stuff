# 905 — Plans joined by shape

*"I gotta take this integer array and this string of text and create an image off of it? Great!"* — a plan is stations in order, each output the next input, every joint checked before anything runs ([068](../docs/068-datapath-the-switchboard.md)).

## Current Behavior

905a is built (issues/completed/905a-shape-graph.md): a station table (any
table of that shape) reads as a graph. 905b (shortest-chain search), 905c
(joint checking) and 905d (plan execution) are not yet built, so a parcel
can still only be routed to one station.

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
