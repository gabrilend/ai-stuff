# 405 — Trap System & Trap-Type Dispatch Table

> Phase 4 — Stage 4b of the
> [puzzles-and-traps datapath](../docs/datapath-puzzles-and-traps.md). Traps fire
> on puzzle failure. Implements the vision's "when the NPC fails a puzzle, a trap
> will trigger. sometimes, the puzzle is disarming this trap, other-times it's a
> magical style enchantment."

## Meta

- **Phase:** 4
- **Blocked by:** 401 (trap reference shape), 404 (the runtime that hands off on
  failure).
- **Blocks:** 406 (the disarm-the-trap and break-the-enchantment archetypes),
  407 (traps appear in the composed demo).

## Current Behavior

None of this exists yet. On failure (once 404 lands) there is a hand-off point but
nothing to hand off to.

## Intended Behavior

A **trap** is a trap type, an `armed` / `disarmed` / `sprung` state, an effect
payload, and (for disarm-as-puzzle) a back-reference the solution-set reads.
Trap behaviour is chosen through a **dispatch table keyed by trap type** (dispatch
table #3 of four): dart-volley, floor-drop, gas, seal-the-room, summon, magical-
backlash, ... Each row says how the trap **springs** (its effect on the world /
party) and how it may be **disarmed**. Adding a trap type is adding a row.

Two vision-mandated shapes are first-class, not special cases:

- **Disarm-as-puzzle.** The trap begins `armed`; the puzzle's *goal* is to reach
  a mechanism state that moves the trap to `disarmed`. Here the trap and the
  solution-set are one object seen from two sides — a solving mechanism's solution
  effect **is** "disarm this trap." Springing (on failure) and disarming (on
  success) are the two exits.
- **Enchantment challenge.** The obstacle is "a magical style enchantment"; the
  solving triggers are [magic-effect triggers](402a-magic-effect-triggers.md) of
  the right path/level; the failure trap is a **magical-backlash** type.

Firing a trap does **not** decide the puzzle's fate — 404's state machine owns
whether a sprung trap ends the puzzle or merely raises its cost. This issue only
provides *what the trap does when it springs* and *how it can be disarmed*.

## Suggested Implementation Steps

1. Create the trap-system source file (indexed name + `.info.md`), importing 401.
2. Build the **trap-type dispatch table** and its registration function; seed it
   with a handful of types spanning the flavours (a direct-harm dart-volley, a
   room-shaping seal-the-room, a spawn-oriented summon, a magic magical-backlash).
   Each row: **spring** function + **disarm** function.
3. Implement the trap **state** (`armed`/`disarmed`/`sprung`) and the transitions
   between them, with each branch commented for what it means in play.
4. Wire the **failure hand-off** from 404: on failure the runtime names the trap;
   this system springs it via the type row and reports the world-effect back for
   the runtime to fold into the outcome record.
5. Implement **disarm-as-puzzle** support: expose the back-reference the
   solution-set reads, and make a solving mechanism's solution effect able to call
   the type's disarm function.
6. Provide the **enchantment challenge** wiring as data (a ward mechanism + a
   magical-backlash trap) so 406 can name it as an archetype.
7. Tests: springing each seeded type produces its documented world-effect;
   disarm-as-puzzle moves `armed -> disarmed` when the solving mechanism completes
   and `armed -> sprung` on failure; the enchantment challenge disarms on the
   right magic path/level and backlashes on the wrong one.

## Related Documents / Tools

- [datapath-puzzles-and-traps.md](../docs/datapath-puzzles-and-traps.md) — Stage
  4b and trap-type table (dispatch table #3 of four).
- `notes/vision` lines ~76-78 — the disarm / enchantment source lines.
- Upstream: [404](404-puzzle-runtime-state-machine-and-solution-checking.md).
  Downstream: [406](406-puzzle-archetypes-and-platforming-integration.md).
