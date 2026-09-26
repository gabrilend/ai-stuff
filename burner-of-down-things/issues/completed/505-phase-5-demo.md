# 505 — Phase 5 demo

## Current Behavior

Built: `issues/completed/demos/phase-5-demo` and `phase-5-demo.lua`. Case one builds the notes blueprint with 202 broken the first time: the ledger's timeline of build and repair turns with ticks, waves, turns, seconds, the delivery fingerprint checked against the ledger line it names, the chain verified; then the delivered design is used (add three notes, list, list by tag, find) and its size counted. Case two makes 202 unbuildable and draws the graph marked built, FAILED and held with the reason.

## Intended Behavior

`issues/completed/demos/phase-5-demo`: phase 4's fixture source, described,
then built by stand-in turns wave by wave into a running design; the design's
own program run to show it works. A second run where one issue is made to
fail shows its reach held. Numbers: waves, turns, repairs, acceptance
commands run, time per wave. The delivered fingerprint printed and checked
against the ledger (phase 1).

## Suggested Implementation Steps

1. The demo script. **Test:** runs through `./run-phase-demo 5`.

## Blocked by

- 504
