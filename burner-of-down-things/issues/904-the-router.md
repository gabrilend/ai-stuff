# 904 — The router

The light model's one job: *"it looks like I'm being handed a circle, so here I'll hand this to the place that needs a circle"* — name the shape and the station, nothing else ([068](../docs/068-datapath-the-switchboard.md)).

## Current Behavior

Nothing routes parcels.

## Intended Behavior

- A router turn is handed the parcel's tag (if any), the types the machine recognised, and the station table; it answers `shape: …` and `station: …`.
- The answer is checked against the table: an unknown station or a shape the station does not take is sent back with the nearest names, up to three times; then the parcel waits for the person.
- Every routing is a ledger line: parcel, shape, station, attempts.

## Suggested Implementation Steps

1. With the stand-in. **Test:** an invented station is sent back naming the nearest real one; a good answer is recorded.
2. With ollama, by hand (903).

## Blocked by

- 901
- 902
- 903
