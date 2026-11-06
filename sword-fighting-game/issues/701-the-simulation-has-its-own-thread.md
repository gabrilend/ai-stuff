# 701 — The Simulation Has Its Own Thread

| | |
| --- | --- |
| Phase | 7 — Distance |
| Blocked by | 305, 407 |
| Blocks | 702 |
| Files | (planned) `src/031-simulation-thread.lua` |

## Current behavior

The simulation ticks on the engine's main thread, between frames, inside the
front desk's accumulator. One battle is small enough that this costs nothing
visible.

## Intended behavior

The simulation runs in an engine thread of its own. The view sends intents
and commands down one channel, tagged with the tick they apply on; the
thread sends back, each tick, a snapshot of what the view draws (positions,
facings, U, swing progress, health, stamina, events). The view draws the
latest snapshot. The same tick-tagged intent messages are what the network
sends in 702, so the thread boundary and the network boundary are one design.

## Suggested implementation steps

1. Define the snapshot format as flat arrays of numbers (one per field per
   soldier), so a channel copy is cheap.
2. Make the view read snapshots instead of records.
3. Test: a scripted run gives the same receipt with and without the thread.
