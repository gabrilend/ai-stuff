# 062-sight

Marching a line through stone, and finding somewhere it cannot reach.

Read this page rather than the source, and read
[line of sight through stone](../docs/018-line-of-sight-through-stone.md) before
either.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `link(Stone, Moving, Creatures)` | | at world creation |
| `can_see(store, from_cell, from_layer, to_cell, to_layer, range)` | | whether the line reaches, and the distance |
| `sees_body(world, watcher, quarry)` | | the same, for two bodies |
| `due(world, bodies, id, kind)` | | whether this body's sight check is due |
| `find_cover(world, id, from_id, budget)` | | a cell and layer the other cannot see, or nil |
| `EYE` | | how far above a creature's feet its eyes are |

## The eye height is above the **feet**

Not above the stance's layer, and the difference is the whole of it. A body
standing on the surface at layer L has its feet on top of that block, at height
L+1; measuring the eye from L instead puts the line inside the very block the
creature is standing on, so the first sample of every march hits stone and
**nothing can ever see anything**.

Measured, before the fix: one pair in four hundred and forty-one could see each
other, and that pair was adjacent. After: forty-two percent within four cells,
twenty within ten, five within twenty-six. That last shape is what a maze looks
like.

## The cadence, and the phase offset

Sight is asked every `sight_interval` seconds, not every tick, and each body's
check is offset by its own id — so the whole population does not check on the
same tick and produce a periodic stall.

Spreading regular-but-not-urgent work by giving each body a phase is worth naming
as a technique. The cost becomes flat instead of spiky, and a flat cost is one
nobody has to think about again.

## Finding cover is breadth-first, and the first answer is the best one

The walk expands outward over surfaces the body could actually stand on, so the
first hidden place it reaches is the nearest one and there is nothing better
further out.

**It is asked on the cadence too**, and that was not optional. Without it, a body
that cannot find cover asks again next tick and next tick — three hundred
surfaces and a sight march apiece, seventy thousand failed searches a minute,
with the move pass costing nine tenths of the whole simulation. The body is in
the open; the answer is not going to be different in a sixtieth of a second.

## Failure is counted, and falls back to fleeing

A maze where hiding always fails is a maze with no cover, which is a fact about
the generator's parameters and should arrive as a number rather than as
creatures behaving oddly.

The fallback is to run instead. That difference is worth keeping both halves of:
fleeing looks like panic and stopping behind a wall looks like intent, and a
creature does the second when it can.
