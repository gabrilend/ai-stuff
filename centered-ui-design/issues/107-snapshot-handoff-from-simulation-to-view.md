# 107 — The snapshot handoff from simulation to view

**Phase:** 1 — The world beneath
**Blocked by:** 105, 106, 109
**Blocks**: 108, 801
**Related documents:** docs/architecture.md (Two halves)

## Current Behavior

The simulation runs inside whatever calls it; nothing watches it.

## Intended Behavior

- A snapshot station at the end of the tick loop builds a snapshot (plain
  table: tick, stands with places, levels and strengths, couriers with places
  and arrival estimates, sight — which effects each seat can see — and error
  events) and delivers it to the view's channel, which keeps only the newest
  if the view falls behind.
- The view sends commands (who, what) on a second channel; the command intake
  station reads all waiting commands at the start of each tick.
- Snapshots can be recorded to `tmp/shared-memory/` and replayed into a view
  with no simulation running.
- A plain debug view (dots for stands, sparks for couriers, circles for
  tiers) exists for phase 1 only; phases 2–3 replace it.

## Suggested Implementation Steps

1. `src/NNN-snapshot.lua`: build a snapshot from the world (copying numbers,
   no shared tables).
2. Snapshot and command-intake stations in the simulation map.
3. `src/NNN-snapshot-recorder.lua`: write/read snapshot streams.
4. `src/NNN-debug-view.lua`: the plain view.
5. Tests: a recorded run replays to the same final checksum.
