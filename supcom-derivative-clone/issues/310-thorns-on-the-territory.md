# 310 — Thorns on the territory

| | |
| --- | --- |
| Phase | 3 — Inflows and Outflows |
| Blocked by | 112, 206, 305 |
| Blocks | — |
| Reads | [territory mass and energy](../docs/005-territory-mass-and-energy.md) |
| Open questions | C3 |

## Current behavior

Nothing. Build power can make units, roster members and energy buildings, but
there is no defence to make: a team's ground is taken without cost to the taker
beyond what its units do.

What exists that bears on this: `tests/021-inflows-and-outflows.lua` names this
issue and asserts that thorns are a capacity built with build power; that when
an enemy claims a percent of a team's territory, the thorns deal the catalogue
damage to the units that did the claiming; that each such spending reduces the
capacity by the catalogue share; and that a team with no capacity deals nothing.
The economy document describes thorns.

## Intended behavior

Build power can be turned into **defences**: a capacity, held by the team, that
hurts whoever takes its ground. For every percent of territory an enemy claims,
the thorns deal a fixed damage to the units doing the claiming — and lose a
share of their capacity in doing it. Thorns are spent by being used; a team that
loses half its ground has lost half its thorns as well as the half that were
spent hurting the takers.

Per the working ruling in C3, thorns are a **team-wide capacity with no
position**. The full game will have many kinds of tower; the demo treats thorns
as one artillery-like capacity, as the vision says: "for now treat them like
artillery. They deal thorns damage, essentially." The damage lands on the
claimers of the cell that flipped, wherever it is — the units whose presence
completed the claim (issue 112 records them) — and it lands through the same
buffered shot mechanism as everything else (issue 206), so that thorn damage
and shell damage arrive in one fixed order and two machines apply them
identically.

Capacity is bought as a construction stream (issue 305) with its own row in the
cost table: a unit of thorns costs mass and build ticks like anything else, and
a team decides how much of its build power goes to walls rather than to lines.
The capacity is an integer on the team. Each percent of ground taken from the
team spends one catalogue share of it and fires one catalogue damage at each
claimer of the flipped cells; a team whose capacity is zero fires nothing and
loses nothing more.

"Percent" is measured the way issue 309 measures it — held cells now against
last tick — in the same consequences pass, so that the roster's hurt and the
thorns' answer happen together and in a known order: thorns first, then the
roster, because the thorns are a defence and the roster is a cost.

## Suggested implementation steps

1. Claim the `thorns` stem with `./new-source-file`. Add to the world a per-team
   `thorns` capacity, integer, zero at allocation.
2. Add a thorns row to the cost table (issue 306) and a construction opener whose
   finish handler adds one unit of capacity to the team. Export `build(world,
   team, amount)` to open that many builds at once; the door (issue 108) gets a
   verb for it.
3. Export `spend_pass(world)`, called from the consequences pass (issue 309, step
   3) before the roster is hurt: for each team whose held cells fell, compute
   the percent taken in integer arithmetic, and for each whole percent, if the
   capacity is positive, append a shot (issue 206) from nobody to each recorded
   claimer of a flipped cell and reduce the capacity by the share.
4. Extend issue 112's claim pass to record, per flipped cell this tick, which
   unit ids completed the claim, in a small per-tick array cleared each tick, so
   the thorns know whom to hurt without re-deriving presence.
5. Give the shot record a shooter of zero for "the thorns" and make the land
   pass (issue 206) accept it: a shot with no shooter is still a shot, and the
   kill attribution simply names the team.
6. Add the claims to `tests/021-inflows-and-outflows.lua`: capacity from build
   power, damage per percent to the claimers, capacity spent per use, nothing
   from nothing.

## Related documents and tools

- [territory, mass, and energy](../docs/005-territory-mass-and-energy.md) — thorns
- [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) — damage buffered, then applied
- `tests/021-inflows-and-outflows.lua`
- issue 112 — the claims that spend thorns
- issue 206 — the buffer thorn damage lands through
- issue 305 — the stream capacity is bought on

## Still open

- C3: where thorns live — a team pool with no position is the working ruling;
  placed towers with sightlines would make this a structure record with a
  position and a targeting pass, and the full game's "many tower types" is
  that. This issue is the demo's shape and is written so that a positioned
  thorn is a row in a later table rather than a rewrite.
- Whether thorns should also hurt planes that bomb a cell (issue 406), since a
  bombing run claims ground. Yes under this design — a claimer is a claimer —
  and it is noted so that nobody exempts planes by accident.
