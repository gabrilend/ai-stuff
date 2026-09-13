# 303 — Energy is built on the ground and lost with it

| | |
| --- | --- |
| Phase | 3 — Inflows and Outflows |
| Blocked by | 112, 302 |
| Blocks | — |
| Reads | [territory mass and energy](../docs/005-territory-mass-and-energy.md) |
| Open questions | D1, D4 |

## Current behavior

Nothing. There is no energy total, no energy building, and no hydrocarbon
anywhere in the world. The dune tool (issue 102) raises heights; whether a cell
is hydrocarbon is not yet something it decides.

What exists that bears on this: `tests/021-inflows-and-outflows.lua` names this
issue and asserts that a standing energy building on a held cell pays energy
every tick; that when its cell changes hands the building is gone and its pay
stops on that tick; that a hydrocarbon buff applies to exactly the next building
finished and is then spent; and that engineers on energy duty raise buildings
without being told where. The economy document describes the mechanism.

## Intended behavior

Energy generation is a **building**, placed on a held cell, that pays energy
every tick while it stands and while its cell is held. If the cell changes
hands, the building is gone — not captured, not damaged, gone — which is the
vision's "when losing territory, you lose the energy that was built while that
part of territory was controlled by your guys." Energy buildings are naturally
spread out because they stand where the ground is, and each one is a small bet
on holding a place.

Some cells are **hydrocarbon**, raised by the dune tool at a rate given by a
shape parameter, on the `dunes` stream. Finding one — a completed claim on its
cell, or a scout's report over it (issue 406) — buffs the *next* energy building
the team finishes, wherever it is; the buff is a per-team counter of pending
buffs, and finishing a building spends one. A hydrocarbon cell found twice buffs
nothing the second time.

Engineers on energy duty (the energy-duty half of issue 302's split) do two
things, per the working ruling in D1: they **raise** energy buildings on held
ground without being told where — nearest unbuilt hydrocarbon cell first, then
the held cell nearest the team's command truck — and they **operate** what
stands. Raising is construction (issue 305) whose build power is the energy-duty
engineers rather than the build-duty ones, so the two halves of the roster never
compete for the same stream. Nothing here is a command; the only player input to
energy is the menu.

An energy building is a row in a flat array: cell, team, standing (an integer
flag), buffed (an integer flag), and a construction progress pair for the stream.
The energy total is a per-team integer on the world, like mass.

## Suggested implementation steps

1. Add to the world (issue 104) per-team `energy` and `energy_income_last_tick`,
   integers, and a per-team `pending_buffs` counter. Add an energy-building
   array-of-arrays: `cell`, `team`, `standing`, `buffed`, `progress`, all
   integers, allocated once to a catalogue-sized maximum, with a live count.
2. Extend the dune tool (issue 102) to mark hydrocarbon cells on a per-cell flag
   array, drawn on the `dunes` stream at the shape parameter's rate; the field
   validator refuses a field whose hydrocarbon count is zero when the parameter
   asked for some.
3. In the `economy` stem, add to `income_pass(world)`: for each standing building
   whose cell's owner (issue 112) is still its team, add the catalogue's pay —
   or the buffed pay — to that team's energy. A building whose cell is not its
   team's is marked not standing in the consequences pass (issue 309's row), and
   its row is returned to the free list.
4. Add `raise_pass(world)`: for each team with energy-duty engineers and no
   building under construction, pick the site by the rule above and open a
   construction stream (issue 305) driven by those engineers. Finishing sets
   `standing`, and if `pending_buffs` is positive, sets `buffed` and decrements
   it.
5. Add the finding rule to the claim pass (issue 112): a claim completing on a
   hydrocarbon cell not yet found by that team increments `pending_buffs` and
   marks the cell found for that team. Reports (issue 406) call the same
   function.
6. Add the claims to `tests/021-inflows-and-outflows.lua`: pay while standing,
   gone with the cell, the buff spent on exactly the next building, sites chosen
   by the stated order.

## Related documents and tools

- [territory, mass, and energy](../docs/005-territory-mass-and-energy.md) — energy on the ground, hydrocarbon
- [the dunes and the sightlines](../docs/002-the-dunes-and-the-sightlines.md) — the tool that marks hydrocarbon
- `tests/021-inflows-and-outflows.lua`
- issue 112 — cell ownership, which decides whether a building still pays
- issue 302 — the menu that decides how many engineers raise

## Still open

- D1: what engineers on energy duty do — raising and operating is the working
  ruling this issue is written to; if the answer is different, steps 4 and 5
  change and step 3 does not.
- D4: who finds a hydrocarbon — a claim or a report, per the working ruling;
  if only claims count, reports stop calling the finding function.
- Whether a building can be demolished on purpose for a share of its cost, as
  a factory can (A5). Not built; a building is lost only with its ground.
