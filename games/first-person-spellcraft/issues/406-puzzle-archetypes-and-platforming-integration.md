# 406 — Puzzle Archetypes & Platforming Integration

> Phase 4 — the reusable **composed** puzzles the generator picks from, and the
> place [Phase 1 platforming](../docs/datapath-engine-foundation.md) becomes a
> whole puzzle rather than just a trigger. This is the "archetype table"
> (dispatch table #4 of four) in the
> [puzzles-and-traps datapath](../docs/datapath-puzzles-and-traps.md).

## Meta

- **Phase:** 4
- **Blocked by:** 401-405 (an archetype is a pre-wired assembly of all of them).
- **Blocks:** 407 (the generator picks archetypes; the demo shows them).

## Current Behavior

None of this exists yet. The primitives (triggers, mechanisms, red herrings,
runtime, traps) exist once 401-405 land, but there is no *named, reusable puzzle
shape* that bundles them into something the generator can pick off a shelf.

## Intended Behavior

An **archetype** is a named recipe: how to build one puzzle of that shape from
catalogue parts, and what its solution-set looks like. Archetypes live in a
**dispatch table keyed by archetype tag**; each row is a **builder** (produces a
puzzle definition from a few parameters: difficulty, place, which magic paths are
"in theme," how many decoys) that already respects the equal-plausibility auditor.
This is the shelf Phase 6 shops from.

Seed archetypes (each a distinct vision flavour):

- **convergent-lever** — one gate mechanism, several `solving` triggers of
  different families converging on it, plus equal-plausible decoy levers. The
  purest expression of "multiple ways to trigger... multiple ways that don't
  provide the solution."
- **lit-glyph-set** — several glyph mechanisms; the solution-set is "all lit";
  decoys are glyphs that light but un-light a sibling (misleading).
- **disarm-the-trap** — the [405](405-trap-system-and-trap-type-dispatch.md)
  disarm-as-puzzle shape as a ready recipe: the goal *is* moving an armed trap to
  `disarmed`.
- **break-the-enchantment** — a ward mechanism solved only by
  [magic-effect triggers](402a-magic-effect-triggers.md) of the right path/level;
  a magical-backlash trap on failure.
- **platforming-traversal** — the **Phase 1 integration**: the goal is a vertical
  route, built from a sequence of [platforming triggers](402c-platforming-triggers.md)
  (height/ledge/ordered-traversal) that drive a reveal-the-path mechanism; decoy
  ledges that look equally reachable lead to an `arms-trap` drop instead.

The platforming-traversal archetype is where Phase 4 and Phase 1 meet as a *whole
puzzle*: it composes platforming-trigger primitives (402c) into a traversal whose
completion is the solution, and whose plausible-but-wrong branches spring traps.
It must build the same shared puzzle-definition shape as every other archetype, so
the runtime treats a jump-puzzle exactly like a lever-puzzle.

## Suggested Implementation Steps

1. Create the archetype source file (indexed name + `.info.md`), importing the
   whole Phase 4 stack.
2. Build the **archetype dispatch table** and its registration function.
3. Write each seed archetype as a **builder** that assembles a valid puzzle
   definition (mechanisms, solving + decoy bindings, solution-set, failure
   conditions, trap) and **runs the equal-plausibility auditor** on its output,
   erroring loudly if a builder ever emits an unbalanced puzzle (a builder that
   cheats the ruler is a bug to surface).
4. For **platforming-traversal**, compose a sequence of 402c triggers into an
   ordered route; wire decoy ledges to an `arms-trap` drop; confirm the completed
   route drives the reveal mechanism.
5. Parameterise each builder by difficulty / place / in-theme paths / decoy-count
   so Phase 6 can dial them without new code.
6. Tests: each archetype's builder emits a definition the runtime can drive to
   `solved` along its intended path and to `failed` along a decoy; every builder's
   output passes the auditor; the platforming-traversal fails when a decoy ledge
   is taken and solves when the route is completed in order.

## Related Documents / Tools

- [datapath-puzzles-and-traps.md](../docs/datapath-puzzles-and-traps.md) —
  archetype table (dispatch table #4 of four).
- [datapath-engine-foundation.md](../docs/datapath-engine-foundation.md) — the
  platforming this archetype composes.
- Upstream: 401-405. Downstream:
  [407](407-composition-and-outcome-seam-for-the-dungeon-master.md).
