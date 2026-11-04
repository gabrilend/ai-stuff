# 701 — The choice catalog, built from equal value budgets

**Phase:** 7 — Growing outward
**Blocked by:** 102, 104

**Blocks**: 702, 708
**Related documents:** docs/datapath-choices.md, docs/game-design.md
(Choices and balance)

## Current Behavior

Unit kinds are a small hand-written table (104).

## Intended Behavior

- At game start, a generator makes the choice catalog from the seed: units,
  upgrades, buildings, hero gear.
- Each choice is given its tier's value budget and spends it across stats by
  seeded proportions, each stat having a cost-per-point (from a balance
  table). So every choice in a tier is worth the same budget, spent
  differently.
- Names are generated from word lists in the glass-and-metal register.
- The hand-written unit table from 104 is replaced.
- The cost-per-point table is a balance knob: changes go in
  docs/balance-updates.md.

## Suggested Implementation Steps

1. `src/NNN-choice-generator.lua` (data generation only).
2. Stat cost table as data.
3. Tests: every choice's spent value equals its budget within rounding;
   same seed → same catalog.
