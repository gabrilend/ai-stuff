# 402 — Trigger System & Trigger-Type Dispatch Table

> Phase 4 — the input edge of the pipeline (Stage 1 of the
> [puzzles-and-traps datapath](../docs/datapath-puzzles-and-traps.md)). A trigger
> is a latent condition watching the world that emits a named event when it turns
> true. This is a **large** issue: the shared machinery lives here, and each of
> the three trigger *families* is a sub-issue (402a magic-effect, 402b physical,
> 402c platforming).

## Meta

- **Phase:** 4
- **Blocked by:** 401 (needs the trigger-reference and event shapes).
- **Blocks:** 403 (bindings route events), 404 (runtime advances watchers).
- **Sub-issues:** [402a](402a-magic-effect-triggers.md),
  [402b](402b-physical-triggers.md), [402c](402c-platforming-triggers.md).

## Current Behavior

None of this exists yet. Puzzle definitions (once 401 lands) can *name* triggers,
but nothing watches the world or emits an event. There is no trigger dispatch
table.

## Intended Behavior

A trigger is a small object with: the family it belongs to, its watched
condition, and the identity it stamps onto the event it emits. A **dispatch table
keyed by trigger family** (the project's tables-over-branch-ladders rule) holds,
per family, two functions: *how to watch* (given world/effect state, has my
condition turned true?) and *how to read magnitude* (what strength/kind to stamp
on the event — which magic path/level, how hard the footfall, what height
reached). Adding a fourth family later must mean adding one table row, never
editing the shared machinery.

The shared machinery (this parent issue) provides:

- The trigger-family dispatch table and its registration function.
- A **watcher pass**: once per tick, walk the active triggers, ask each family's
  "how to watch" whether its condition turned true, and for those that did, mint a
  **trigger event** (which trigger, where, what magnitude).
- A clean **subscription** boundary so the runtime (404) consumes events without
  knowing which family produced them, and so the three families can be built and
  tested independently.

The three families themselves (their conditions and magnitude readings) are the
sub-issues, each owning one **IN seam**:

- **402a magic-effect** — subscribes to [Phase 3's "magic effect" seam](../docs/datapath-spell-system.md).
- **402b physical** — reads [Phase 1 world & collision](../docs/datapath-engine-foundation.md)
  (footfalls, pressure, moved objects at rest).
- **402c platforming** — reads [Phase 1 verticality](../docs/datapath-engine-foundation.md)
  (height reached, ledge landed, traversal completed).

## Suggested Implementation Steps

1. Create the trigger-system source file (indexed name + `.info.md`), importing
   the 401 data model.
2. Build the **trigger-family dispatch table** and its registration function.
   Seed it with three empty rows the sub-issues fill; never dispatch on family
   with an if/else chain.
3. Implement the **watcher pass** over active triggers, minting trigger events for
   conditions that turned true this tick. Include per-trigger edge detection
   (fire on the *transition* to true, not every tick it stays true) so a held
   condition does not spam events.
4. Define the **subscription** surface the runtime attaches to, and a test double
   world/effect source so families can be exercised without the real Phase 1/3
   systems present yet.
5. Land the three families as sub-issues 402a/402b/402c, each registering its two
   table functions and bringing its own tests.
6. Integration test: a hand-authored puzzle (from 401's fixtures) with one trigger
   of each family; feed the test doubles a condition-true for each; assert exactly
   one edge-triggered event per family with the right magnitude stamped.

## Related Documents / Tools

- [datapath-puzzles-and-traps.md](../docs/datapath-puzzles-and-traps.md) — Stage 1
  and the trigger-type table (dispatch table #1 of four).
- Upstream seams: [spell system](../docs/datapath-spell-system.md) (402a),
  [engine foundation](../docs/datapath-engine-foundation.md) (402b, 402c).
