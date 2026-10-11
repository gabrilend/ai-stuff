# 104 — Stands, units, and movement in tier-time

**Phase:** 1 — The world beneath
**Blocked by:** 103

**Blocks**: 105, 106, 108, 701
**Related documents:** docs/core-terms.md (stand, tier-time),
docs/datapath-world-tick.md

## Current Behavior

The world has positions and rings but nothing in it.

## Intended Behavior

- A stand is a group of units with one position, one owner seat, one current
  order, and a speed in tiers per second (the slowest unit's speed).
- Units have kind, health, attack, range, shield. For now unit kinds are a
  small hand-written table; phase 7 replaces it with the generated catalog.
- Each tick, a stand with a move-like order steps toward its target. Speed is
  in tier-distance, so every band takes the same time to cross (tier-time).
- A stand with no order holds position.

## Suggested Implementation Steps

1. `src/008-unit-kinds.lua`: the temporary unit table (soldier, shield
   bearer, engineer, courier-speed reference).
2. `src/009-stands.lua`: stand creation, speed from its units, step toward a
   target position.
3. Tests: a stand at tier 0.5 with speed 0.1 reaches tier 2.5 in exactly
   20 seconds of ticks; a stand never overshoots its target.
