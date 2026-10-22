# 506 — Phase 5 demo: four machines, one page

phase 5, bringing up the fg-sora machines

## Current behavior

Phase 4's demo runs everything on kuvalu once 407 is done.

## Intended behavior

`issues/completed/demos/phase-5-demo` runs the health check, then watches
the live system for a few minutes and shows, per voice: its backend, turn
time, fit tries, rmail delay, and frames skipped. It also shows the page live
at the box size. It runs the phase-3 round-trip histogram on real machines,
for comparison with the rehearsal.

## Suggested implementation steps

1. The run script.
2. Fill in `issues/phase-5-progress.md` and add phase 5 to `run-phase-demo`.

## Related documents

- `docs/roadmap.md`, phase 5

## Blocked by

505.

## Blocks

None.
