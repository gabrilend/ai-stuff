# 402 — Factories and their build queues

**Phase:** 4 — Factories and engineers
**Blocked by:** 401, 304

**Blocks**: 403, 405
**Related documents:** docs/datapath-production.md

## Current Behavior

Stands are placed by the settings file; nothing is built.

## Intended Behavior

- A "build" order button, then a map click within the seat's quadrant near
  the hub, places a factory (one order, one click, like any other).
- A factory has a kind (what it makes), a build queue, and progress. It pulls
  from the production budget; when it cannot afford the next unit it waits,
  and its rim/map marker shows why.
- Factories are shown as round metal plinths on the map with a small
  progress ring.

## Suggested Implementation Steps

1. `src/NNN-factories.lua`: factory state, production step.
2. Build order kind added to the order dispatch table.
3. Tests: a factory with a funded queue produces at the stated rate; an
   unfunded one waits.
