# 402a — Magic-Effect Triggers (the Phase 3 seam)

> Sub-issue of [402](402-trigger-system-and-type-dispatch.md). The trigger family
> that lets a spell solve a puzzle. Owns the **IN seam** to the
> [Phase 3 spell system](../docs/datapath-spell-system.md).

## Meta

- **Phase:** 4
- **Blocked by:** 402 (the shared machinery + dispatch table).
- **Seam owned:** Phase 3 "a magic effect landed here" -> Phase 4 trigger event.

## Current Behavior

None of this exists yet. No trigger reacts to a spell.

## Intended Behavior

A magic-effect trigger watches for **an effect of a given path and (at least) a
given level landing within a given place**, and emits an event stamped with the
effect's path and level as its magnitude. It **subscribes** to the spell system's
published "magic effect" seam — it must never poll spells, never know how a spell
was cast, never reach into the caster. All it learns is: *an effect of this path,
this level, occurred at this point/volume.* This is exactly the vision's "apply
certain magic effects to certain puzzles."

Registering this family means filling one row of the trigger-family dispatch
table with:

- **how to watch** — is there an unconsumed magic-effect notification whose
  path matches, whose level meets-or-exceeds the threshold, and whose location
  falls inside this trigger's watched place?
- **how to read magnitude** — stamp the event with the effect's path and level
  (so a red-herring binding can, e.g., care that it was Fire not Water, and the
  plausibility auditor can reason about tool-match).

## Suggested Implementation Steps

1. Define the **subscription adapter** to Phase 3's magic-effect seam behind a
   thin interface, so Phase 4 depends on the *shape* of an effect notification
   (path, level, location), not on Phase 3 internals. If Phase 3 is not built yet,
   depend on the documented seam shape and drive tests with a stub publisher —
   and log loudly that a stub is standing in (a stub is a fallback; surface it).
2. Register the magic-effect row in the trigger-family dispatch table with its
   two functions.
3. Handle path/level matching as data (threshold level, accepted path[s]) so the
   generator can dial a trigger's pickiness without new code.
4. Tests: an effect of the right path at/above threshold inside the place fires
   exactly one edge event with path/level stamped; wrong path, too-low level, or
   outside the place fires nothing.

## Related Documents / Tools

- [datapath-spell-system.md](../docs/datapath-spell-system.md) — the seam this
  subscribes to.
- [datapath-puzzles-and-traps.md](../docs/datapath-puzzles-and-traps.md) — Stage 1,
  magic-effect family; the "IN — Phase 3" seam.
- Parent: [402](402-trigger-system-and-type-dispatch.md). Sibling archetype that
  leans on this: 406's break-the-enchantment.
