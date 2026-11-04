# 105 — Combat, one station per direction

**Phase:** 1 — The world beneath
**Blocked by:** 104, 109
**Blocks**: 107, 108, 602, 308
**Related documents:** docs/datapath-world-tick.md (Steps 3–4),
docs/architecture.md (The shape: soramech)

## Current Behavior

Stands move but never fight.

## Intended Behavior

- Each tick, units within range of an enemy deal damage: shields absorb
  first, then health. Dead units are removed; an empty stand is removed.
- Each direction's movement and combat is its own soramech station. It runs
  as soon as that direction's stands for the tick have arrived, on whatever
  worker is free, and outputs new positions and damage.
- Stands close to a quadrant edge are held back and settled by the join
  station, so no pair of units is decided twice.
- The join station waits for every direction and combines them in direction
  order, so results are identical however many workers run.
- Each direction draws randomness from a stream named by (seed, tick,
  direction), so finishing order cannot change the result.

## Suggested Implementation Steps

1. `src/NNN-combat-rules.lua`: pure functions — given stands, return damage
   events. Testable alone.
2. The per-direction box and the join box, wired in the simulation map.
3. Edge settlement inside the join box.
4. Tests: two stands meet, the stronger survives; 1-worker vs 4-worker
   checksum equality.
