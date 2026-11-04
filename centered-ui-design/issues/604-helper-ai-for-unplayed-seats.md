# 604 — Helper AI for unplayed seats

**Phase:** 6 — Foes in every direction
**Blocked by:** 603, 501

**Blocks**: 607
**Related documents:** docs/game-design.md (The team table)

## Current Behavior

A seat not being played only continues its last orders.

## Intended Behavior

- Each seat has a helper setting: off (last orders only), defend (helper
  gives defensive orders only), full (helper plays the seat).
- The helper is the same commander AI as the foes, on the seat's side, using
  the seat's ballot priorities.
- The setting is changed with a painted button per seat and shown on a
  three-position dial.

## Suggested Implementation Steps

1. Reuse 603's AI with a seat's view and permission set.
2. Button and dial on the dashboard.

## Open questions

- What should unplayed seats do by default? (Open question 9.)
