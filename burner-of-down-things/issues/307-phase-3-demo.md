# 307 — Phase 3 demo

## Current Behavior

No demo.

## Intended Behavior

`issues/completed/demos/phase-3-demo`: a case on a small source; a pool of
stand-in turns of every kind, one of which writes into the source and one of
which hangs. Prints a table of turns with their verdicts, the breach and the
path it touched, the hang stopped at its limit, turns per second through the
pool, snapshot time per thousand files, and the Claude Code command line each
kind would have been started with — showing that no build turn can see the
source. Ends with the ledger's verification (phase 1).

## Suggested Implementation Steps

1. The demo script. **Test:** runs through `./run-phase-demo 3`.

## Blocked by

- 305
- 306
