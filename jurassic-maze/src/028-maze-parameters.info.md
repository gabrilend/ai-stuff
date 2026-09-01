# 028-maze-parameters

Every knob the maze generator has, in one table.

Read this page rather than the source. The source is for when one named function
is misbehaving; this is for everything else.

## What it is for

This file and `assets/035-creature-table.lua` hold **every balance number in the
project**. No document restates one. A page that says "walls are two layers tall"
is a page that is wrong the first time somebody tunes it, and it will be believed
anyway because it is written down.

Why a number is what it is belongs in `docs/balance-updates.md`, appended to,
never edited.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `defaults()` | — | a fresh table of every knob at its default |
| `with(overrides)` | table | the defaults with those fields replaced. **Raises** on a field that does not exist, because a silently-accepted typo produces a maze built with the default while somebody believes they changed it. |
| `check(p)` | a parameter table | the same table, having refused anything that cannot produce a maze |

## What `check` refuses, and why

| Refused | Because |
| --- | --- |
| fewer than 3 or more than 32 layers | a column is a 32-bit integer |
| a maze smaller than 9 by 9 | fewer than four rooms in it |
| an even width or depth | the room lattice sits at odd coordinates, and an even extent leaves it without a rim on two sides |
| `terrace_rise` below 1 | a flat plain, not a pile of slabs |

## The knobs

Grouped by the pass that reads them. See
[carving the maze](../docs/003-carving-the-maze.md) for what each pass does.

| Group | Fields |
| --- | --- |
| the world | `width`, `depth`, `layers`, `seed`, `capacity` |
| pass one, terraces | `terrace_count`, `terrace_max`, `terrace_min`, `terrace_rise`, `terrace_wander`, `outcrops` |
| pass two, staircases | `stair_steps`, `extra_stairs` |
| pass three, the maze | `braid` |
| pass four, walls | `wall_rise`, `climb_limit` |
| pass five, repair | `stair_rounds`, `stair_reach`, `stair_candidates`, `orphan_max` |

`climb_limit` is in the table and is **not a knob**. A wall stands two layers
above its corridor precisely because one layer is climbable and two is not.
Raising it to two does not make bodies more agile, it deletes every wall in the
maze at once.
