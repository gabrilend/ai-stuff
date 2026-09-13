# 406 — A report sends bombers

| | |
| --- | --- |
| Phase | 4 — The Cloud |
| Blocked by | 210, 403 |
| Blocks | 505 |
| Reads | [the cloud](../docs/007-the-cloud.md) |
| Open questions | E3, E4 |

## Current behavior

Nothing. The command truck's plane from issue 210 sees the ground beneath it
and has nowhere to send what it sees; the `bombing` row in the `MISSIONS` table
raises by name. `tests/022-the-cloud.lua` files a report and asserts that
exactly the unbothered, equipped planes leave the cloud for it, and that a run
that arrives damages what stands on the cell and claims it.

## Intended behavior

A **report** is a position an enemy was seen at. The truck's plane files one
for everything it sees; a completed claim on a hydrocarbon cell files one too
(issue 303). Reports are a per-team queue in the world: flat arrays of x, y, and
the tick filed, with a count.

Every tick, after the round pass, the cloud answers the oldest unanswered
report. The planes that answer are the ones that are **suitably unbothered and
have the requisite bombing gear**, which is the vision's phrase and E3's working
ruling made concrete: mission `in-cloud`, not paired in a round this tick, and
the bombing bit set in the plane's `gear` field. In the demo every plane has the
bit; in the full game it is an upgrade (issue 407). All of them go, and the
report is consumed. A report nobody can answer waits.

A **bombing run** is the `bombing` mission: the plane flies to the reported cell
at flight height and, on arrival, does two things — E4's working ruling is both:

- **damage** to what is there: a shot is buffered against every enemy unit
  standing within one cell of the target, with the bomb's damage from the
  catalogue and an arrival tick of now;
- **a claim** on the cell: the cell's owner becomes the bomber's team, unless an
  enemy unit stands within the claim radius, in which case the cell is contested
  and does not flip.

Then the plane's mission becomes `returning` and it flies back to the cloud.
Along the whole way out and back it is a plane over ground, and the guns of
issue 405 fire at it when they see it. That is how the air war reaches the
roster: every cell a bomber flips is a share of the enemy's territory, and
issue 309 does the rest.

## Suggested implementation steps

1. Add the report queue to `the-world`: per team, `report_x`, `report_y`
   (doubles), `report_tick` (integer), and a count; allocated once at the
   catalogue's capacity, refused when full rather than grown.
2. In `the-cloud`, export `report(world, team, x, y)`: append, or return a named
   refusal when the queue is full. Have issue 210's plane call it for each
   sighting, once per enemy per sortie.
3. Add `gear` (integer bitmask) to the unit record and a `gear` column to the
   catalogue's air kinds; the demo's helicopter carries the bombing bit.
4. Export `answer_reports(world)`: for each team with a report, gather the
   unbothered, equipped in-cloud planes by array walk, set their mission to
   `bombing` and their `target` to the cell (negative index, issue 404's
   convention), and consume the report. Register it as the row after the cloud
   in `the-tick`'s `SYSTEMS`.
5. Fill the `bombing` row: step toward the cell; on arrival, buffer the shots
   through `combat` and flip the cell through `territory`'s claim function,
   which already knows what contested means; then set `returning`.
6. Write the test's three assertions: who leaves, what is hurt, what flips.
7. Update the companions of `the-cloud`, `the-world`, and the catalogue.

## Related documents and tools

- [The cloud](../docs/007-the-cloud.md)
- [The command truck and its plane](../docs/008-the-command-truck-and-its-plane.md) — where reports come from
- [Territory, mass, and energy](../docs/005-territory-mass-and-energy.md) — what a flipped cell costs
- `tests/022-the-cloud.lua`

## Still open

- E3: what "suitably unbothered" means. In the cloud, not in a round this tick,
  not defensive — and whether *all* such planes should answer one report or only
  a fixed number is the part the proving ground will decide.
- E4: whether a run damages, claims, or both. Both is the ruling; damage alone
  makes the air war a nuisance, a claim alone makes it bloodless.
- Whether a report should age out unanswered, and after how many increments.
