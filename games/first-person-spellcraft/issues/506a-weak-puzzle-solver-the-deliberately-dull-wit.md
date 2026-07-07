# 506a — Weak Puzzle Solver: the deliberately dull wit

> When an NCP reaches a Phase-4 puzzle, *this* is what tries to crack it — a
> **deliberately weaker** reasoner than the powerful AI that built the lair. The
> weakness is the feature, not a bug: the gap between the strong builder and the
> weak solver is exactly what lets the Dungeon Master measure difficulty (506b).
>
> First half of the weak-solver work (paired with 506b, the capability signal).
> Depends on 501 (stats gate the attempt), 502 (memory can strengthen it), and
> Phase 4 (the puzzles). NCP = New Character Person; see
> [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md).

## Current Behavior

None of this exists yet. Phase 4 will produce puzzles with multiple triggers
(some solving, some red-herrings) and traps on failure, but nothing on the NCP
side attempts them; an autonomous adventurer would walk up to a puzzle and stop.

## Intended Behavior

A **weak puzzle solver** that takes a Phase-4 puzzle (as an opaque handle) plus the
NCP's per-stat levels (501) and memory context (502), and produces an **attempt**:
a chosen trigger/mechanism to try, or a considered give-up.

The defining property, straight from the vision (*"these puzzles are created by a
powerful local AI / the NPC characters have to figure it out with a weaker
version"*):

- **Deliberately weaker than the DM's generator.** The solver reasons with a
  capped, dulled competence — it does not see through red-herrings reliably, does
  not brute-force, and can genuinely fail. Its strength is *bounded by the NCP's
  relevant per-stat level* and *lifted by relevant memory* (the fairy-tales Phase 6
  wrote in, issue 502): a higher stat or a matching learned lesson makes a correct
  trigger more likely, but never guaranteed. This is the whole engine of the
  weak/strong asymmetry the DM depends on.
- **Stat-attributed.** An attempt records *which stat carried it*, because 506b and
  the DM (Phase 6) need to know which per-stat level the outcome speaks to.
- **Honest about failure.** When the solver picks a non-solving trigger (a
  red-herring), the attempt resolves through Phase 4 into a **trap** — the solver
  must be capable of being wrong, so failure is a real, frequent outcome, not a
  formality.

Keep the solver a *pure attempt-maker*: puzzle + stats + memory in, chosen trigger
(or give-up) out. It does not move the body (that is exploration, 507), does not
narrate (that is the companion, 504), and does not itself decide the outcome (that
is Phase 4 resolving the trigger). The success/failure *signal* it feeds is 506b.

## Suggested Implementation Steps

1. Agree the **puzzle handle** shape with Phase 4: enough for the solver to
   enumerate candidate triggers and know its relevant stat/skill demand, without
   the solver seeing the "answer." Treat it as opaque beyond that.
2. Define the **attempt** structure: the chosen trigger (or give-up) plus the stat
   that carried it and a confidence, so 506b can shape a signal from it.
3. Implement the **weak reasoning** as an explicitly capped competence: model the
   chance of choosing a solving trigger as a bounded function of the relevant
   per-stat level (501) and matching memory (502), staying below the strong
   generator's competence by construction. Keep the "how weak" knobs in config /
   validator-reported, never hardcoded in docs — the weak/strong gap is a tuning
   surface Phase 6 will calibrate against.
4. Make wrongness real: ensure the solver can and does pick red-herring triggers,
   so Phase-4 traps actually fire. Add a test that runs many attempts at a fixed
   puzzle/stat and asserts the success rate sits in the intended weak band (not ~0,
   not ~1).
5. Show memory's lift: a test where adding a matching fairy-tale to memory (502)
   measurably raises the success rate for the puzzle it teaches — this is the hook
   Phase 6's learning mechanic pulls on.
6. Comment every branch (solve-trigger vs. red-herring vs. give-up) with what each
   path leads to, per project policy on control-flow comments.
7. Write the file's `.info.md`: the attempt operation, inputs/outputs, as a black box.

## Related Documents / Tools

- [datapath-ncp-characters.md](../docs/datapath-ncp-characters.md) — "Weak puzzle
  solver" and the Phase-6 weak-vs-strong asymmetry seam.
- Pairs with: capability signal (506b). Feeds and is fed by: data model (501),
  memory store (502). Consumes: Phase 4 puzzles. Invoked by: exploration (507).
