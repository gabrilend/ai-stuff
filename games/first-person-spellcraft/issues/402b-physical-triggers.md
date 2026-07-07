# 402b — Physical Triggers (the Phase 1 world seam)

> Sub-issue of [402](402-trigger-system-and-type-dispatch.md). The trigger family
> for stepping, pressure, and moved objects. Owns an **IN seam** to
> [Phase 1 world & collision](../docs/datapath-engine-foundation.md).

## Meta

- **Phase:** 4
- **Blocked by:** 402 (shared machinery + dispatch table).
- **Seam owned:** Phase 1 world/collision state -> Phase 4 trigger event.

## Current Behavior

None of this exists yet. Nothing reacts to a footstep, a pressure plate, or a
crate shoved onto a tile.

## Intended Behavior

A physical trigger watches the world's occupancy: **a body or object resting in /
passing through a watched volume**, and emits an event stamped with a magnitude
read from the physical act (how much weight/pressure, whether it is a transient
step or a sustained rest). It **reads Phase 1's world and collision state** — it
never simulates physics itself; Phase 1 owns bodies, volumes, and collision, and
this family only asks "is this volume occupied, and by how much."

Registering this family fills a trigger-family dispatch-table row with:

- **how to watch** — is the watched volume occupied (by a body, or by a moved
  object at rest) meeting a pressure/duration threshold?
- **how to read magnitude** — stamp weight/pressure and transient-vs-sustained, so
  a mechanism can distinguish "tapped" from "held down," and a red-herring plate
  can look identical to a solving plate.

Two common shapes to support from data: **pressure plate** (occupancy over a
threshold) and **object-placement** (a specific movable object come to rest in a
specific socket) — both the same family, different thresholds/targets.

## Suggested Implementation Steps

1. Define the **world-occupancy adapter** behind a thin interface (given a volume,
   what occupies it and with what pressure), so Phase 4 depends on the seam shape,
   not Phase 1 internals. Stub + loud log if Phase 1 is not yet present.
2. Register the physical row in the dispatch table with its two functions.
3. Support transient (step) vs sustained (rest/hold) as data on the trigger, with
   edge detection deferring to 402's watcher pass.
4. Tests: occupancy over threshold fires one edge event with pressure stamped;
   an object at rest in the wrong socket fires nothing; a held weight does not
   re-fire every tick; releasing then re-pressing fires a fresh edge.

## Related Documents / Tools

- [datapath-engine-foundation.md](../docs/datapath-engine-foundation.md) — the
  world/collision seam this reads.
- [datapath-puzzles-and-traps.md](../docs/datapath-puzzles-and-traps.md) — Stage 1,
  physical family; the "IN — Phase 1" seam.
- Parent: [402](402-trigger-system-and-type-dispatch.md).
