# 106 — Couriers carry orders with transit delay

**Phase:** 1 — The world beneath
**Blocked by:** 104

**Blocks**: 107, 108, 304
**Related documents:** docs/datapath-orders.md, docs/core-terms.md
(Commanding)

## Current Behavior

Stands can be given targets directly in code; there is no delay.

## Intended Behavior

- Every command (seat, stand, order kind, target, tick issued) becomes a
  courier at the hub.
- The courier moves each tick toward the stand's *current* position at
  courier speed (faster than any unit), re-aiming as the stand moves.
- On arrival the stand's order is replaced; the courier is removed.
- Two couriers to the same stand: whichever arrives later wins.
- A command for a stand that no longer exists is reported as an error event
  in the snapshot (the view will show it), never silently dropped.
- The snapshot lists every courier with its estimated ticks to arrival.

## Suggested Implementation Steps

1. `src/014-commands.lua`: command shape and validation (stand belongs to
   the seat; order kind is known).
2. `src/015-couriers.lua`: spawn, chase, arrive, estimate arrival.
3. Tests: a courier to a stand at tier 3 arrives later than one to tier 1;
   a later-sent courier that arrives later wins; dead-stand command is an
   error event.
