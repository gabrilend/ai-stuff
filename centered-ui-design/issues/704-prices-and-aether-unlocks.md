# 704 — Prices and aether unlocks

**Phase:** 7 — Growing outward
**Blocked by:** 703, 401

**Blocks**: 705, 708
**Related documents:** docs/datapath-choices.md, docs/core-terms.md (price,
unlock)

## Current Behavior

Offered choices are free.

## Intended Behavior

- A choice may have a price in metal and glass (paid from the upgrades
  budget), and may require an unlock.
- Unlocks are bought with aether; each unlock opens a family of choices.
- The offer is shown on dials: each choice in its own window with its price
  readouts and, if locked, its unlock's name; painted take and hold buttons
  beside each window are how a choice is taken or held.

## Suggested Implementation Steps

1. Price and requirement fields used at take time.
2. Unlock purchase as a candidate in the purchase vote (503).
3. Tests: a locked choice cannot be taken; buying the unlock makes it
   takeable.
