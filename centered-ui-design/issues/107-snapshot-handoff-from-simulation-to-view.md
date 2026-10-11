# 107 — The snapshot handoff from simulation to view

**Phase:** 1 — The world beneath
**Blocked by:** 105, 106

**Blocks**: 108, 801
**Related documents:** docs/architecture.md (Two halves)

## Current Behavior

The simulation runs inside whatever calls it; nothing watches it.

## Intended Behavior

- The simulation runs on its own LÖVE thread. Each tick it publishes a
  snapshot (plain table: tick, stands with positions and strengths, couriers
  with positions and arrival estimates, error events) on a channel, keeping
  only the newest if the view falls behind.
- The view thread sends commands on a second channel; the simulation reads
  all waiting commands at the start of each tick.
- Snapshots can be recorded to `tmp/shared-memory/` and replayed into a view
  with no simulation running.
- A plain debug view (dots for stands, sparks for couriers, circles for
  tiers) exists for phase 1 only; phase 2–3 replace it.

## Suggested Implementation Steps

1. `src/016-snapshot.lua`: build a snapshot from the world (copying numbers,
   no shared tables).
2. `src/017-simulation-thread.lua`: the loop body run on the thread.
3. `src/018-snapshot-recorder.lua`: write/read snapshot streams.
4. `src/019-debug-view.lua`: the plain view.
5. Tests: a recorded run replays to the same final checksum.
