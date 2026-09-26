# 307 — Phase 3 demo

## Current Behavior

Built: `issues/completed/demos/phase-3-demo` and `phase-3-demo.lua`. Throughput of 48 stand-in turns through pools of 1, 4 and 8 with bars; five single-turn sets showing each verdict (write outside → breach with the path, write into the source → breach and "a run would stop here", error → failed with the harness's words, hang → failed at the 2 s limit, well-behaved → kept); the Claude Code command line for an outline and a build turn, saying which can read the source; first and second snapshot times on the AzerothCore tree; the ledger's verification. Paths are shortened as plain text (the folder name's dashes would be read as pattern instructions).

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
