# 402c — Platforming Triggers (the Phase 1 verticality seam)

> Sub-issue of [402](402-trigger-system-and-type-dispatch.md). The trigger family
> that reads verticality — height reached, ledge landed, traversal completed.
> Owns an **IN seam** to [Phase 1 platforming](../docs/datapath-engine-foundation.md).

## Meta

- **Phase:** 4
- **Blocked by:** 402 (shared machinery + dispatch table).
- **Seam owned:** Phase 1 platforming/verticality state -> Phase 4 trigger event.
- **Feeds:** 406's platforming-traversal archetype.

## Current Behavior

None of this exists yet. Nothing reacts to a jump, a height, or a landing.

## Intended Behavior

A platforming trigger watches vertical achievement: **reaching a target height,
landing on a specific ledge, or completing a traversal path**, and emits an event
stamped with a magnitude read from the act (height reached, landing precision,
whether a traversal segment was completed in order). It **reads Phase 1's
platforming/verticality state** — it never moves the player; Phase 1 owns
movement and the vertical world, and this family only asks "did they get there."

Registering this family fills a trigger-family dispatch-table row with:

- **how to watch** — has the player reached the target height / landed on the
  watched ledge / completed the next segment of a watched traversal?
- **how to read magnitude** — stamp height reached and landing precision, so a
  mechanism can care about *how well* a ledge was hit and the plausibility auditor
  can weigh a hard-to-reach solving ledge against an easy-to-reach decoy ledge.

## Suggested Implementation Steps

1. Define the **verticality adapter** behind a thin interface (current height,
   ledge-landings, traversal-segment progress), depending on the Phase 1 seam
   shape only. Stub + loud log if Phase 1 platforming is not yet present.
2. Register the platforming row in the dispatch table with its two functions.
3. Support single-ledge, height-threshold, and ordered-traversal shapes as data,
   so 406 can compose a multi-jump puzzle from a sequence of these.
4. Tests: reaching the target height fires one edge event with height stamped;
   landing on a decoy ledge fires *its* event (not the solving one); an
   out-of-order traversal segment fires nothing until the prior segment is done.

## Related Documents / Tools

- [datapath-engine-foundation.md](../docs/datapath-engine-foundation.md) — the
  platforming/verticality seam this reads.
- [datapath-puzzles-and-traps.md](../docs/datapath-puzzles-and-traps.md) — Stage 1,
  platforming family.
- Parent: [402](402-trigger-system-and-type-dispatch.md). Consumer:
  [406](406-puzzle-archetypes-and-platforming-integration.md).
