# 404 — Engineers dismantle and rebuild

**Phase:** 4 — Factories and engineers
**Blocked by:** 403

**Blocks**: 405
**Related documents:** docs/datapath-production.md

## Current Behavior

A locked factory is permanent.

## Intended Behavior

- A stand containing engineers is told to *dismantle* (map click on the
  engineers, then the dismantle button); they dismantle the factory nearest
  them, walking there if needed. The courier carries the order; dismantling
  takes time proportional to the factory's price.
  price.
- When done, the factory is gone and part of its price returns to the
  production budget. The site can be built on again, with a new path.
- Engineers can also be ordered to *rebuild* directly (dismantle then build a
  new kind at the same site, as one order).

## Suggested Implementation Steps

1. Dismantle and rebuild order kinds in the dispatch table.
2. Dismantling state on factories; refund rule in the treasury.
3. Tests: a stand without engineers cannot dismantle; refund matches the
   rule; rebuild yields an unlocked factory in pathing state.

## Open questions

- Where do engineers come from? (Open question 13.)
