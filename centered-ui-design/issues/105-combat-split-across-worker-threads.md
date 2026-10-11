# 105 — Combat, split across worker threads

**Phase:** 1 — The world beneath
**Blocked by:** 104

**Blocks**: 107, 108, 602
**Related documents:** docs/datapath-world-tick.md (Steps 3–4),
docs/architecture.md (Many threads)

## Current Behavior

Stands move but never fight.

## Intended Behavior

- Each tick, units within range of an enemy deal damage: shields absorb
  first, then health. Dead units are removed; an empty stand is removed.
- Target choice and damage rolls use the combat random stream, so results are
  reproducible.
- The work is split by direction across a pool of LÖVE worker threads:
  each worker gets a copy of one direction's stands (plain tables of numbers)
  through a channel and returns damage and moves. Stands close to a quadrant
  edge are held back and settled on the simulation thread after the join, so
  no pair of units is decided twice.
- Results are identical whether 1 worker or 8 are used (a test compares).
- Each worker gets its own random stream derived from (seed, tick,
  direction), so the order workers finish in cannot change the result.

## Suggested Implementation Steps

1. `src/010-combat-rules.lua`: pure functions — given stands, return damage
   events. No threads in this file, so it can be tested alone.
2. `src/011-worker-pool.lua`: start N LÖVE threads, a job channel, a result
   channel; jobs are plain tables.
3. `src/012-worker-body.lua`: the code each thread runs, calling the combat
   rules.
4. `src/013-edge-settlement.lua`: the held-back pairs near quadrant edges.
5. Tests: two stands meet, the stronger survives; 1-worker vs 4-worker
   checksum equality.
