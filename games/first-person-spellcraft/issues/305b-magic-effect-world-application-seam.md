# 305b — World application & the Phase 4 magic-effect seam

> Phase 3 · Spell System · sub-issue of
> [305](305-effect-resolution-and-world-seam.md). Where effects become
> consequences — to monsters, and to puzzles. Datapath:
> [datapath-spell-system.md](../docs/datapath-spell-system.md) Stage 5. Depends
> on: [305a](305a-effect-resolution-core.md) (effect events) and Phase 1 (the
> world/monsters to mutate).

## Current Behavior

None of this exists yet. Effect events from 305a describe what should happen, but
nothing applies them: no monster takes damage, no wall moves, and there is no
published seam for a Phase 4 mechanism to notice a spell landed on it.

## Intended Behavior

Effect events are **applied** to the world, and this is the one place spells are
allowed to mutate. There are two destinations — the two ways a spell "means
something":

1. **The Phase 1 world / monsters.** Damage a zombie, move a wall, light a room —
   through whatever query/mutate handles Phase 1 exposes. Phase 3 depends on that
   surface; it does not reimplement world state.
2. **The Phase 4 magic-effect seam.** A spell can **trigger a mechanism**. Phase 3
   does not know what a puzzle is. It **publishes** magic-effects — "a FIRE effect
   landed here", "a WATER effect there" — and Phase 4 mechanisms **subscribe** and
   decide for themselves whether they were triggered. This is the outward mirror
   of the inward aim seam (303): narrow, neutral, and owned on Phase 3's side as
   *emission only*. The vision: "apply certain magic effects to certain puzzles ...
   create a mechanism that provides the solution" (notes/vision ~118-119).

Application routes each effect event through a **dispatch table keyed by effect
kind** to the right world mutation and/or magic-effect emission — a new effect's
application is a new row, not a new branch.

A **magic-effect emission** carries: kind, location/region, magnitude, source
caster — enough for a subscriber to judge a match, no more. Subscription is a
plain publish/subscribe seam so Phase 4 (and nothing else) owns the meaning of
"this effect solves this."

## Suggested Implementation Steps

1. Define the **magic-effect emission structure** (kind, location/region,
   magnitude, source) and a small **publish/subscribe seam**: *subscribe to
   magic-effects*, *emit a magic-effect*.
2. Build the **world-application dispatch table** keyed by effect kind; write
   *apply effect events to the world* to walk events and route each: world/monster
   mutation via Phase 1's handles, magic-effect kinds via the emit seam, some
   effects doing both.
3. Wire monster/world mutation against Phase 1's exposed query/mutate surface;
   where Phase 1's surface is not yet final, isolate the dependency behind a thin
   named adapter so the seam is honest and a gap is visible, not faked.
4. Leave the magic-effect seam **caller-agnostic** — do not import Phase 4. Ship a
   tiny **example subscriber in tests** (a fake "torch that lights when a FIRE
   effect lands on it") proving the seam fires, marked as test scaffolding.
5. Add a comment at the mutation boundary recording that this is the *only* place
   spells mutate, and why (the generation/application wall).
6. Write tests: apply events, assert monster state changed **and** the matching
   magic-effect was observed by a subscriber. Add the seam to
   [strategems/](../strategems/README) if the publish/subscribe shape proves
   reusable (it likely mirrors Phase 4's trigger routing).
7. Add a `.info.md` for the application module and the seam.

## Data Structures / Functions / Files (by role)

- *Magic-effect emission* — kind, location/region, magnitude, source caster.
- *Magic-effect seam* — subscribe / emit (the Phase 4 hook).
- *World-application dispatch table* — effect kind → mutation and/or emission.
- *Apply effect events to the world* — the one mutating entry point.
- Files: a world-application module + `.info.md`; a thin Phase 1 adapter if
  needed; an example subscriber kept in tests only.

## Related Documents / Tools

- [datapath-spell-system.md](../docs/datapath-spell-system.md) — Stage 5.
- [datapath-engine-foundation.md](../docs/datapath-engine-foundation.md) — Phase 1
  world/monster surface (planned; owned by Phase 1).
- [datapath-puzzles-and-traps.md](../docs/datapath-puzzles-and-traps.md) — Phase 4,
  the subscriber to this seam (planned; owned by Phase 4).
- Blocks: 306 (may echo events for viewing), 307 (demo), Phase 4 (subscribes).
