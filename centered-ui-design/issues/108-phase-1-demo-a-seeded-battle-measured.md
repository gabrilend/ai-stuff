# 108 — Phase 1 demo: a seeded battle, measured

**Phase:** 1 — The world beneath
**Blocked by:** 101, 102, 103, 104, 105, 106, 107

**Blocks**: 307
**Related documents:** docs/roadmap.md (Phase 1)

## Current Behavior

No demo exists; `run-phase-demo` says so.

## Intended Behavior

`issues/completed/demos/phase-1-demo` runs a seeded four-direction battle
headless, then prints:

- ticks per second achieved, with 1 worker and with all workers;
- courier transit time by tier (mean, longest);
- units lost by direction;
- determinism check: two runs, same seed, checksums equal (PASS/FAIL);

then opens the debug view replaying the recorded snapshots.

## Suggested Implementation Steps

1. Scripted battle setup in `input/`-shaped settings kept beside the demo.
2. A statistics gatherer reading the recorded snapshots (data side) and a
   printer (viewing side), kept separate.
3. `phase-1-demo` bash script with hard-coded `DIR` and optional argument.
4. Run it via `run-phase-demo 1`.
