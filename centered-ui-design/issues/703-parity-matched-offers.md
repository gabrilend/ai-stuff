# 703 — Parity-matched offers

**Phase:** 7 — Growing outward
**Blocked by:** 702

**Blocks**: 704, 708
**Related documents:** docs/datapath-choices.md, docs/game-design.md
(Mechabellum balance)

## Current Behavior

Rolling gives each side whatever comes up.

## Intended Behavior

- At a level-up, every side involved gets an offer with the same number of
  choices.
- The offers' total values must lie within a parity margin of each other;
  the side furthest out is re-rolled until all are within it. Each side's
  offer is rolled on its own worker thread.
- The re-roll uses each side's own offer stream, so results are reproducible.
- If the margin cannot be met within a fixed number of attempts, that is an
  error (the tables are unbalanced), not a quiet acceptance.

## Suggested Implementation Steps

1. `src/NNN-offers.lua`.
2. Tests: across thousands of level-ups, every offer set is within margin;
   the failure case raises the error.
