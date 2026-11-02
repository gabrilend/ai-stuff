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
| `assemble(modules, parameters)` | a list of stems the caller needs; the world's allocation parameters | a validated world, and the named modules keyed by stem; raises naming any absent stem |
| `ticks_of(seconds)` | seconds | whole ticks at the match's rate (`ticks_per_second` in the rules); refuses less than half a tick |
| `load(stem)`, `load_asset(stem)` | a stem | the world's loader, passed through |

## Data structures it owns

`SYSTEMS`, each row `{name, run, sliceable, run_slice, waiting_for}`. `run` takes
the world; `run_slice` takes the world and a first and last unit id.

| # | Row | Sliceable | Built by |
| --- | --- | --- | --- |
| 1 | `commands` | no | waiting for 108 |
| 2 | `income` | no | waiting for 301 |
| 3 | `construction` | no | waiting for 305 |
| 4 | `emit` | no | waiting for 307 |
| 5 | `move` | yes | waiting for 204 |
| 6 | `claim` | no | waiting for 112 |
| 7 | `sight-and-aim` | yes | waiting for 205 |
| 8 | `fire` | yes | waiting for 206 |
| 9 | `land` | no | waiting for 206 |
| 10 | `die` | no | waiting for 208 |
| 11 | `the-cloud` | no | waiting for 401 |
| 12 | `consequences` | no | waiting for 309 |
| 13 | `snapshot` | no | waiting for 109 |

A sliceable row's module exports `<function>_slice` beside its whole-world
function.
