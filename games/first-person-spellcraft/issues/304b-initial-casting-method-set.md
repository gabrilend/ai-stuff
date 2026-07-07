# 304b — Initial casting-method set

> Phase 3 · Spell System · sub-issue of
> [304](304-casting-method-dispatch.md). The first concrete verbs of invocation —
> the growing catalogue. Datapath:
> [datapath-spell-system.md](../docs/datapath-spell-system.md) Stage 3. Depends
> on: [304a](304a-casting-method-contract-and-registry.md) (the contract they
> implement).

## Current Behavior

None of this exists yet. With 304a there will be a table and a contract, but no
methods filling it, so no spell can actually be invoked any particular way.

## Intended Behavior

An initial set of casting methods, each a **data-driven entry** in the 304a
dispatch table, each a *distinct route to the same effect* — the concrete meaning
of "more than one ways to do each" (notes/vision ~112-113). The starter set:

- **Gesture-cast** — the immediate, no-aim (or self/point-aimed) invocation: name
  the spell, it goes off. Advertises: needs aim = no (or a simple point), charges
  = no, one hand. The baseline against which the others feel different.
- **Charge-and-release** — hold to build up, release to fire; the handler tracks a
  charge level and only produces a resolved cast past a threshold, passing the
  charge level along as a method-produced parameter. Advertises: charges = yes.
- **Two-hand-combination** — the signature tie to Phase 2's two hands: the method
  reads that both hands contributed (a combination/gesture across the two-mouse
  boomstick) and typically **needs aim**, since a two-handed wave points
  somewhere. Advertises: hands = 2, needs aim = yes.

Every spell template (302) declares which of these it accepts; a spell may accept
several, so the same fireball can be a quick gesture, a charged blast, or a two-
handed aimed beam. The set is expected to **grow** — new methods are new 304a
rows and a new template opt-in, never edits to the dispatch machinery.

Each method is a **distinct route to the *same* effect**: the effect resolution
(305a) must be reachable identically from all three, so the "same result, many
paths" property is real and testable.

## Suggested Implementation Steps

1. Implement gesture-cast first as the simplest baseline handler; confirm a
   template listing it routes to a resolved cast.
2. Implement charge-and-release, exercising the method-produced-parameter path
   (charge level) through 304a's resolved-cast structure.
3. Implement two-hand-combination, exercising the needs-aim path against the 303
   aim seam (via the stub aim source in headless tests).
4. Update the 302 starter spells so at least one spell declares **all three**
   methods, proving multiple routes to one effect.
5. Write tests asserting all three methods on that spell reach the **same** effect
   resolution, differing only where a method legitimately should (charge level,
   aim). Tests are cheap; make several.
6. Add/extend `.info.md` describing each method's traits and when to reach for it.

## Data Structures / Functions / Files (by role)

- *Gesture-cast handler* — immediate invocation.
- *Charge-and-release handler* — threshold + charge level.
- *Two-hand-combination handler* — reads two-hand contribution, consumes aim.
- Files: a casting-methods data/handlers module under `src/` registering into the
  304a table, + `.info.md`. Keep method data separate from the registry
  machinery.

## Related Documents / Tools

- [datapath-spell-system.md](../docs/datapath-spell-system.md) — Stage 3.
- [304a](304a-casting-method-contract-and-registry.md) — the contract/table.
- [datapath-dual-mouse-input.md](../docs/datapath-dual-mouse-input.md) — the two
  hands the two-hand-combination method leans on (planned; Phase 2).
- Blocks: 305a (all methods must reach the same resolution).
