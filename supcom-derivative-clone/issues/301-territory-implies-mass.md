# 301 — Territory implies mass

| | |
| --- | --- |
| Phase | 3 — Inflows and Outflows |
| Blocked by | 112 |
| Blocks | 305, 311 |
| Reads | [territory mass and energy](../docs/005-territory-mass-and-energy.md) |
| Open questions | none |

## Current behavior

Nothing. The world has no resource totals and no income pass. Territory is
painted on cells by issue 112, which gives every cell an owner and every team a
percentage of the field, but holding a cell pays nothing.

What exists that bears on this: the test program `tests/021-inflows-and-outflows.lua`
names this issue and asserts that a team's mass income for a tick equals its held
cell count times the pay per cell, and that a cell which changes hands moves its
pay from one team's total to the other's on the very next tick. The economy
document describes the loop this issue is the first link of.

## Intended behavior

There is no mass extractor and nothing to place. **Ground a team holds pays mass
while it is held.** Every tick, the income pass walks the territory arrays once,
counts the cells each team owns, multiplies by the mass a cell pays, and adds
the result to that team's mass total. Lose the ground and the income leaves on
the tick it is lost; take it and the income arrives the same way.

The reason it is this simple: the vision's economy is "minimal resources, focus
on inflows and outflows," and territory-as-income is the one inflow that needs
no building, no placement, and no menu. It is also what makes the whole loop
close — units take ground, ground pays for units, losing ground costs the means
of making more (issue 309). Any extra step between holding and earning would be
a place for that loop to leak.

The mass total is a per-team field on the world, an integer count of mass held,
never negative. Construction (issue 305) draws from it; nothing else does until
improvement (issue 311) and thorns (issue 310) exist. Water cells are never
owned and never pay. The pay per cell is one catalogue number, read once at
load, and no document states it.

The income pass is sliced by cell range across the thread pool (issue 209), with
each worker counting into its own partial totals and an unsliced step summing
them, so that two machines count the same cells in the same order and reach the
same integer — the determinism the network model (issue 701) leans on.

## Suggested implementation steps

1. Add to the world (issue 104) a per-team array `mass`, integers, and a per-team
   array `mass_income_last_tick`, integers, so the viewer can show inflow without
   recomputing it. Both hold zero at allocation.
2. Claim the `economy` stem with `./new-source-file` and give it `income_pass(world)`:
   count owned cells per team from the territory arrays (issue 112), multiply by
   the catalogue's pay per cell, add to `mass`, record the income.
3. Put the pay per cell in the catalogue table under `assets/`, beside the unit
   catalogue (issue 202). The loader refuses a catalogue with no such row, by
   name; it does not default to zero, because a zero income is a silent dead
   economy rather than an error.
4. Register `income_pass` as the second row of the tick's dispatch table (issue
   105), after commands and before construction, so a cell claimed this tick
   pays this tick and a build started this tick can draw on it.
5. Slice the count by cell range through the thread pool (issue 209), summing the
   per-worker partials in fixed worker order.
6. Add the two claims to `tests/021-inflows-and-outflows.lua` if they are not
   already there: income equals cells times pay, and a flipped cell moves its pay
   between teams within one tick.

## Related documents and tools

- [territory, mass, and energy](../docs/005-territory-mass-and-energy.md) — the loop this is the first link of
- [the tick and the timers](../docs/003-the-tick-and-the-timers.md) — where the income pass sits in the order
- `tests/021-inflows-and-outflows.lua` — the claims this issue must satisfy
- issue 112 — territory painted on cells, which this reads
- issue 305 — construction, which spends what this earns

## Still open

Nothing cited in the table. One thing this issue raises: whether the pay per
cell should differ by height — a crest paying more than a hollow would make
the ridges worth holding for two reasons at once. Not built; noted so it is not
re-derived.
