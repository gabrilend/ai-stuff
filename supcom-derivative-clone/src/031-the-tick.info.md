# 031-the-tick

The heartbeat: an ordered table of systems.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

One tick is one pass over `SYSTEMS` and then the tick count rising by one. The
order is data, from the tick document. A system that is not a row does not run.

A row not yet built carries `waiting_for`, the issue that builds it, and runs
nothing. The issue that builds the system replaces that with the module's stem
and export; a built row's module is loaded when this file is, so a missing one is
refused at load by name, never skipped.

Before the rows run, every counter in the world's `COUNTERS` is brought up to the
tick, so the increment of now is settled before any system reads it.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `SYSTEMS` | | the ordered rows, below |
| `advance(world)` | a world | `true`, the match continuing (nothing ends a match until the command truck) |
| `advance_timed(world, seconds)` | a world; a table | the same tick, with each row's processor seconds added into `seconds` under its name |
| `assemble(modules, parameters)` | a list of stems the caller needs; the world's allocation parameters | a validated world, and the named modules keyed by stem; raises naming any absent stem |
| `ticks_of(seconds)` | seconds | whole ticks at the match's rate (`ticks_per_second` in the rules); refuses less than half a tick |
| `load(stem)`, `load_asset(stem)` | a stem | the world's loader, passed through |

## Data structures it owns

`SYSTEMS`, each row `{name, run, sliceable, run_slice, before, waiting_for}`.
`run` takes the world; `run_slice` takes the world and a first and last unit id;
`before`, when a sliceable row has one, is an unsliced step its slices read, run
once first. `advance` runs a sliceable row through the thread pool's
`run_sliced` (issue 209) and every other row's `run` directly.

| # | Row | Sliceable | Built by |
| --- | --- | --- | --- |
| 1 | `commands` | no | `commands.apply_due` (108) |
| 2 | `income` | no | waiting for 301 |
| 3 | `construction` | no | waiting for 305 |
| 4 | `emit` | no | waiting for 307 |
| 5 | `move` | yes | `movement.move_pass` (204) |
| 6 | `claim` | no | `territory.claim_pass` (112) |
| 7 | `sight-and-aim` | yes | `targeting.aim_pass` (205) |
| 8 | `fire` | yes | `combat.fire_pass` (206) |
| 9 | `land` | no | `combat.land_pass` (206) |
| 10 | `die` | no | `combat.die_row` (206, 211): the die pass, then the enforcers' eat pass |
| 11 | `the-cloud` | no | waiting for 401 |
| 12 | `consequences` | no | waiting for 309 |
| 13 | `snapshot` | no | `snapshot.snapshot_pass` (109) |

A sliceable row's module exports `<function>_slice` beside its whole-world
function, and `<function>_before` when the slices need an unsliced step first
(the move pass's occupancy).
