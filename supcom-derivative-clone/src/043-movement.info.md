# 043-movement

Land and sea units walk their pattern one leg at a time and hold at its end.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

A pattern is a list of points in the world's pattern store. A unit's row
names the pattern in `pattern` and, in `leg`, the point it is heading for. Each
move pass moves every live land and sea unit with a pattern toward its point by
its step length. A unit that reaches a point lands on it exactly and turns to
the next. One past the last point it **holds** for good: no chase, no return
and no loop (open question A4's working ruling).

- **Slope costs** (C1's working ruling). A land unit's step is its catalogue
  `speed` divided by `1 + climb * rise`, where `rise` is the height from the
  cell it stands in to the cell one whole cell ahead along its way. Downhill is
  never faster than flat, and a ship's water is flat.
- **The water is a wall.** If a step would land where the unit's domain may
  not stand (water for land, land for a ship, or off the field), it is not
  taken. The unit stays put and keeps its leg; it does not turn round.
- **One cell, one land unit.** If a step would enter a cell another land unit
  held when the pass began, the unit waits that pass. On later passes, while
  the way is still blocked, it steps aside, square to its way (left first, then
  right), which carries it into the next row of cells and past the one that
  was held. A straight step clears the wait.
- **Planes do not move here.** Their missions move them (issue 401 on), and
  `domains.altitude_at` keeps their altitude.

The pass is sliced (issue 209). A slice reads the field, the patterns and the
occupancy, and writes only its own units' `x`, `y`, `leg` and `waited`. The
occupancy is rewritten by `occupancy_pass`, which is not sliced. The
whole-world `move_pass` runs it first, and the thread pool must do the same
before it hands out slices.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `move_pass(world)` | a world | nothing; the tick's `move` row: the occupancy, then every unit |
| `move_pass_slice(world, first, last)` | a world; a range of unit ids | nothing; walks the live land and sea units in the range |
| `move_pass_before(world)` | a world | nothing; the occupancy pass, which the thread pool runs once before the move row's slices |
| `occupancy_pass(world)` | a world | nothing; rewrites `world.cell.occupant` from every live land unit, the lowest id first when two share a cell |
| `step_length(field, kind, from_x, from_y, to_x, to_y)` | a field; a kind's name or index; where it stands; where it heads | how far it goes this pass |
| `held(world, id)` | a world; a unit | whether it has passed the last point of its pattern |

## Data structures it owns

- `world.cell.occupant` -- the land unit standing in each cell as the pass
  began; zero for none.
- `world.unit.waited` -- one while a unit is waiting for, or stepping round, a
  held cell; zero once it steps straight again.

It reads the pattern store, `world.pattern = {count, points}`, where
`points[n]` is pattern n's list of `{x, y}` points. The world allocates it empty.
The hash and the snapshot copy include it, and the world's validator checks it.
Issue 308 is where patterns are drawn.
