# Phase 9 Progress

## Goals
The switchboard: parcels with arbitrary inputs, routed by a light local model to the station that needs them, planned by shape, and results that go wrong turned into observations of a mechanism and adjustments to it (docs/068).

Counts: run `/home/ritz/programming/ai-stuff/scripts/progress-dashboard.lua /mnt/mtwo/programming/ai-stuff/burner-of-down-things -m`.

## Completed Issues
- 903a the row — a harness-table row for `ollama` (037): free per call,
  local, refuses a turn with no model named rather than guess one.
- 901a the parcel folder — reading every file dropped in a switchboard
  folder as one parcel; an empty folder is nothing arrived, not an error.
- 902a scalar types — recognisers for `integer-array`, `number-array` and
  `text`, without a model, tried in that order; the closed list of all
  eleven shape types.
- 905a the shape graph — a station table (any table shaped like one) read
  as nodes (shapes) and edges (stations), built generically so it did not
  have to wait on 902d.

- 903c model name resolution — a case's own `router-model` file, then the
  switchboard's own setting; refuses naming both places when neither
  names one.
- 902d the station table — the real table (grows as more studio ends
  land) and the shape-matching function; proved to feed 905a's shape
  graph unchanged, the first working example of
  strategems/build-to-the-shape-not-the-neighbor.md.

903b and 903d, 901b-d, 902b-c and 905b-d remain: the needs check and
confinement; tag parsing, number issuance and reuse refusal; structured
and remaining types; shortest-chain search, joint checking and plan
execution.
