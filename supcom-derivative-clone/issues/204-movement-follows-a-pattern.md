# 204 — Movement follows a pattern

| | |
| --- | --- |
| Phase | 2 — Things That Roll, Fly, and Sail |
| Blocked by | 201, 203 |
| Blocks | 308 |
| Reads | [factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md) |
| Open questions | A4, C1 |

## Current behavior

Nothing. The test program `tests/020-things-that-roll-fly-and-sail.lua` names
this issue and looks for the stem `movement`. Patterns as a thing a player draws
are issue 308; this issue is what a unit does with one it already carries.

## Intended behavior

A land or sea unit **walks its pattern one leg at a time and holds at the end.**
A pattern is a list of points on the field; the unit's row holds which pattern
and which leg. Each tick the move pass advances every live land and sea unit
along its current leg by its speed, turns to the next leg when it reaches the
leg's end point, and when it passes the last point stops moving for good.

**Slope costs.** The working ruling on C1: a step's length is the catalogue's
flat-ground speed scaled down by the height difference between the cell it
leaves and the cell it enters, so a ridge is slow to climb and a trough is fast
to run. Downhill is never faster than flat. The scaling is a catalogue curve,
not a number in this file.

**The water is a wall.** A land unit whose next step lands on a sea cell does not
take it; it stands where it is. A sea unit whose next step lands on land does
the same. Neither turns around, because the pattern is where the player put
them and a unit does not decide otherwise. The validator in issue 308 refuses
a pattern that crosses the line, so this is the case of a pattern's edge
running along a shore and a step rounding the wrong way.

**One cell, one unit.** Two land units cannot occupy a cell. A unit whose next
cell is occupied waits one tick, then tries the neighbouring cells along its
leg. Whether that keeps a column from knotting on a narrow ridge is a
proving-ground question.

**Planes do not move here.** A plane's mission (issue 401 and after) decides its
movement; the move pass skips air rows, and a plane's altitude column is kept
current by the mission code through `altitude_at` from issue 203.

**No chase, no return, no loop.** At the end of the pattern the unit holds and
fires at whatever it sees from there (issue 205). A4's working ruling is hold,
because a pattern that loops is a patrol and a pattern that holds is a siege,
and the vision's factory-game framing reads as the latter.

The move pass is **sliced** (issue 209): it reads the field and the pattern and
writes only its own unit's position, leg, and altitude. The occupancy check reads
a cell-occupancy array written by an unsliced step at the end of the previous
tick, so two workers never race on it.

## Suggested implementation steps

1. Claim `src/NNN-movement.lua` with `./new-source-file movement`.
2. Write the pattern store the unit row references by integer: a flat array of
   points with a start index and a count per pattern, so a unit's `pattern` and
   `leg` are two integers and the walk is arithmetic.
3. Write `step_length(field, kind, from_x, from_y, to_x, to_y)`: the catalogue
   speed scaled by the slope curve.
4. Write `move_pass(world)`: for each live land or sea row, compute the step
   toward the leg's end point, test `can_stand` (issue 203) and the occupancy
   array, take the step or wait, advance `leg` when the end point is reached,
   and mark the unit held when the last point is passed.
5. Write `occupancy_pass(world)`, unsliced, at the tick's end: clears and
   rewrites the cell-occupancy array from every live land unit's position.
6. Refuse, by name, a unit whose `pattern` names no pattern and a `leg` past
   the pattern's count; both are validator questions at load.

## Related documents and tools

- [factories and patterns in the sand](../docs/006-factories-and-patterns-in-the-sand.md)
- [a unit and what it carries](../docs/004-a-unit-and-what-it-carries.md) — the movement section
- [the dunes and the sightlines](../docs/002-the-dunes-and-the-sightlines.md) — slope
- `tests/020-things-that-roll-fly-and-sail.lua`

## Still open

- **A4.** What a land unit does at the end of its pattern: the working ruling is
  hold; the alternatives are loop and return.
- **C1.** Whether slope slows movement or only decides sight: the working ruling
  is both.
- Raised here: whether the occupancy rule needs a queue behind a blocked unit
  or whether waiting a tick is enough. The proving ground answers it.
