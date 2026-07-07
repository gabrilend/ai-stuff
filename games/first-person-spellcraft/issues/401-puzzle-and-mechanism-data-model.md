# 401 — Puzzle & Mechanism Data Model

> Phase 4 (Puzzles, Mechanisms & Traps) — the foundational vocabulary. Every
> other Phase 4 issue imports the structures defined here. Read the
> [puzzles-and-traps datapath](../docs/datapath-puzzles-and-traps.md) first; this
> issue builds Stage 0 ("the puzzle definition, data at rest") of that pipeline.

## Meta

- **Phase:** 4
- **Blocks:** 402, 403, 404, 405, 406, 407 (all of Phase 4 rests on this shape).
- **Blocked by:** nothing inside Phase 4. Leans on Phase 1's notion of a room/point
  and Phase 3's notion of a "magic effect" only as *names* it references, not as
  running code.

## Current Behavior

None of this exists yet. There is no representation of a puzzle, a mechanism, a
trigger, a trap, or an outcome anywhere in the project. `src/` is empty.

## Intended Behavior

A single, shared, at-rest description of a puzzle exists as plain data, with a
matching live-state companion. The shape is identical whether a puzzle is
authored by hand (for the demo and tests) or minted by the
[Phase 6 generator](../docs/datapath-dungeon-master.md) at lair-spawn time — the
runtime must not be able to tell them apart. Nothing here *does* anything yet
(no triggers fire, no predicates evaluate); this issue only fixes the nouns.

The nouns, by role (see the datapath's "Structures, by role" for the canonical
list — keep the two in agreement):

- **Puzzle definition** — the at-rest whole: a goal description, the set of
  mechanisms it contains, the trigger-to-mechanism wiring, the solving-vs-red-
  herring tag on each wire, the failure conditions, the trap(s) that fire on
  failure, and an archetype tag naming which building-block shape it is.
- **Puzzle state** — the live half kept separate from the definition: which state-
  machine node it sits in (`in-progress` / `solved` / `failed`), each mechanism's
  current state, budgets spent (attempts, time), and which wires have been tried.
- **Mechanism** — the solution-provider: a mechanism kind, a current state, a
  solution effect it will fire when driven home, and the set of use-modes it
  exposes.
- **Activation binding** — one wire: a trigger paired with one use-mode of one
  mechanism, tagged `solving` / `inert` / `misleading` / `arms-trap`, and carrying
  an apparent-plausibility profile (filled in by issue 403).
- **Trigger reference** — a named handle to a trigger (the trigger's own machinery
  lands in issue 402); the definition only needs to *name* and *wire* triggers.
- **Solution-set predicate** and **failure predicate(s)** — data-driven tests over
  mechanism states and budgets, stored as data (not closures baked at author
  time) so the generator can assemble them from catalogue parts.
- **Trap reference** — a named handle plus its `armed`/`disarmed`/`sprung` slot
  (the trap's behaviour lands in issue 405).
- **Outcome record** — the emitted-verdict shape (fields only here; the emitting
  happens in issue 407).

Keep **definition** (immutable once built) and **state** (mutates every tick)
strictly separate — this mirrors the project's "generate data, then, abstracted
away, view/advance it" rule and lets one definition spawn many independent live
instances (fresh each visit).

## Suggested Implementation Steps

1. Create the data-model source file in `src/` (indexed name from
   `.file-index-counter`, plus its `.info.md` sibling listing each exported
   constructor and its inputs/outputs). This is the lowest-index Phase 4 file so
   the story reads in dependency order.
2. Define the **puzzle definition** structure as a plain table of the fields
   above. No behaviour — just the shape and a constructor that validates required
   fields are present (prefer a hard error over a nil-tolerant fallback; a
   half-built puzzle is a bug to surface, not to paper over).
3. Define the **puzzle state** structure and a constructor that derives a fresh
   live instance from a definition (all mechanisms at their start state, state
   machine at `in-progress`, budgets full). This "instantiate from template,
   never mutate the template" split is the load-bearing idea.
4. Define **mechanism**, **activation binding**, **trigger reference**, **trap
   reference**, and **outcome record** as their own small structures, each with a
   validating constructor.
5. Represent **solution-set** and **failure** predicates as data (e.g., a small
   list of clauses over mechanism-state equality/counts) with a *separate*
   evaluator to be written in issue 404 — do not fold evaluation in here.
6. Reserve the four dispatch-table keys the rest of the phase fills (trigger
   type, mechanism kind, trap type, archetype) as named string tags on the
   structures, so later issues register behaviour against them.
7. Write a fixtures module: two or three fully hand-authored puzzle definitions
   (a convergent-lever, a lit-glyph-set) used by every later issue's tests. Mark
   it clearly as test scaffolding; keep it, it has permanent use.
8. Add tests: constructing a valid definition succeeds; a definition missing a
   goal/solution-set errors loudly; a fresh state derived from a definition has
   independent mechanism states (mutating one instance does not touch the
   template or a sibling instance).

## Related Documents / Tools

- [datapath-puzzles-and-traps.md](../docs/datapath-puzzles-and-traps.md) — Stage 0
  and the structures/functions role lists this issue must match.
- Downstream: 402 (triggers), 403 (bindings & plausibility), 404 (runtime),
  405 (traps), 406 (archetypes), 407 (composition & outcome seam).
