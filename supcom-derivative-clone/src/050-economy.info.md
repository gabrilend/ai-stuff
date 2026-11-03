# 050-economy

Ground a team holds pays mass while it is held: the tick's income pass.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

There is no extractor and nothing to place. **Territory implies mass**: every
tick, the income pass (the tick's second row, after commands and before
construction) walks the cells once in cell order. It counts the land cells each
team owns and adds that count times the rules' `mass_per_cell` to the team's
`mass`. The income itself is kept in `mass_income_last_tick`, so a viewer can
show the inflow without counting again.

- A cell that changes hands pays its new owner, and not its old one, on the
  next income pass. The claim row runs after income, so a cell claimed during
  a tick starts paying on the following tick.
- Water is never owned in a match, and is never paid even if it were.
- Everything is integer arithmetic over a fixed walk, so every machine reaches
  the same total.

The pay per cell is one rule, read from the world's copy of the rules. The
world refuses a rules table without it, by name, instead of defaulting to a dead
economy. No document quotes its value; `assets/034-the-rules.lua` holds it.

The pass runs on one worker and is not sliced. Splitting it by cell range would
need a pool that slices a count other than the unit rows, plus per-range
partial totals summed in fixed order. The pass costs one walk of the cells, so
that waits until a profile says it matters.

This file grows with phase 3: energy (issue 303), construction (305),
consequences (309) and improvement (311) add their exports here, as the tests
document's `economy` row lists.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `income_pass(world)` | a world | nothing; the tick's `income` row: every team's `mass` raised by its held land cells times the pay, and `mass_income_last_tick` written |
| `held_cells(world, team)` | a world; a team | how many land cells it owns now |
| `cell_pays(world, cell)` | a world; a cell index | what that cell pays its owner a tick: the pay per cell for an owned land cell, zero otherwise |

## Data structures it owns

None in the world. It writes `world.team.mass` and
`world.team.mass_income_last_tick`, and reads `world.cell.owner`, the field's
heights and water line, and `world.rule.mass_per_cell`. It keeps one small
per-team table of counts, reused every pass, so it allocates nothing during a
match.
