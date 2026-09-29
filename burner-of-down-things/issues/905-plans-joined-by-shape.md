# 905 — Plans joined by shape

*"I gotta take this integer array and this string of text and create an image off of it? Great!"* — a plan is stations in order, each output the next input, every joint checked before anything runs ([068](../docs/068-datapath-the-switchboard.md)).

## Current Behavior

A parcel can be routed to one station.

## Intended Behavior

- When no single station takes a parcel's shape to the wanted one, a plan is found through the station table: the shortest chain whose joints fit (a search over shapes, no model).
- Every joint is checked before the first station runs; a joint that does not fit is refused, named.
- Each station's result is a new parcel, recorded, and handed on.

## Suggested Implementation Steps

1. Finding plans. **Test:** `integer-array + text → image` becomes table → chart → png; an impossible shape says which type cannot be reached.
2. Running a plan. **Test:** a two-station plan runs end to end and every intermediate parcel is kept.

## Blocked by

- 904
