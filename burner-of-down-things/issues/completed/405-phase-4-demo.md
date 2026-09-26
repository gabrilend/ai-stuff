# 405 — Phase 4 demo

## Current Behavior

Built: `issues/completed/demos/phase-4-demo` and `phase-4-demo.lua`. The notes fixture is surveyed, outlined (the first outline forgets a file and is caught) and described (one issue omits its checks twice and is caught twice); the ledger's account is printed as ticks and crosses; the graph is drawn as boxed columns, one per level, each box naming what it is built on; every code file is mapped to its issue; the house validator runs on the whole blueprint; numbers: issues, levels, coverage, turns and retries, seconds.

## Intended Behavior

`issues/completed/demos/phase-4-demo`: a real small source (a fixture program
kept in `tests/fixtures/`) surveyed (phase 2) and described by stand-in turns
(phase 3) into a blueprint; the blueprint's graph drawn level by level; the
survey coverage shown as every code file mapped to its issue; the house
validator's verdict on the whole blueprint. Numbers: issues, levels, turns
spent, files covered.

## Suggested Implementation Steps

1. The demo script. **Test:** runs through `./run-phase-demo 4`.

## Blocked by

- 404
