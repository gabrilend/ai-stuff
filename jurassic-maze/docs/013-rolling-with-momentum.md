# Rolling With Momentum

The first thing that moves. A ball, with a real position that is not on any
grid, a velocity that accumulates, and gravity pulling it down whatever slope it
happens to be on.

## The floor is a height field, and it is interpolated

A ball is never on a cell. It is at some fractional `x` and `y`, and the floor
under it is a smooth surface obtained by interpolating the heights of the four
cells around it.

That interpolation is the whole trick, and it has one rule attached that keeps it
honest:

> **Only cells within one layer of the ball's own surface contribute their real
> height.** A cell whose surface is higher than that is a wall, and it
> contributes the ball's own height instead.

Without that rule, interpolating between a corridor at layer 4 and a wall at
layer 6 produces a gentle ramp into the wall, and the ball rolls up it. With it,
the interpolated floor is flat right up to the wall, and the wall is dealt with
by collision rather than by slope — which is what a wall is.

A staircase is where the rule pays off. Each step is one layer, so every step is
within the limit, so the interpolation turns the flight of stairs into a
continuous ramp and the ball accelerates smoothly down it. That is a lie about
the geometry — the stairs really are steps — and it is a lie told deliberately,
because the alternative is a ball that bounces down every staircase in a way
that is chaotic, hard to test, and no more convincing.

## The forces

Per tick, in this order:

| Force | Arithmetic |
| --- | --- |
| **gravity along the slope** | the floor's gradient, times `gravity`, applied as an acceleration in the downhill direction |
| **rolling resistance** | velocity times `roll_friction`, opposing the motion, so a ball on flat ground eventually stops |
| **integration** | position moves by velocity times the timestep |

The gradient comes from the same interpolated field: the difference between the
floor height a small distance ahead and a small distance behind, in each axis.
Sampling the field rather than reasoning about which cell is which means the
gradient is automatically zero on flat ground, automatically points downhill on a
staircase, and automatically goes to zero at a wall, because that is what the
field does there.

`roll_friction` exists so that the aquarium does not slowly fill with balls
oscillating in the bottom of every dip forever. A ball at rest for
`rest_seconds` is taken out and dropped in again at the top, which is what makes
this an aquarium rather than a run with an end.

## Walls, and hitting them

The ball has a `radius`, a bit under half a cell. A neighbouring cell whose
surface is more than `climb_limit` above the ball's is a **wall**, and the plane
at the boundary between the two cells is a **face**.

When the ball's centre comes within `radius` of a face, two things happen:

1. The ball is pushed back out along the face's normal, to exactly `radius`
   away. Pushed out, not moved back along its path — resolving the overlap is
   about ending up somewhere legal, and the cheapest legal place is straight out.
2. The velocity component along the normal is reversed and multiplied by
   `restitution`. The component along the face is left alone, so a ball rolling
   at a shallow angle slides along the wall instead of stopping dead.

Corners are the case that gets forgotten. Where two walls meet, the nearest point
of the obstacle is not on either face — it is the corner post between them, and
the ball must be pushed away from a *point* rather than a plane. Handling only
the faces lets a ball squeeze diagonally through the join between two blocks,
which looks exactly like the ball passing through solid stone, and which is
the single most likely bug in this file.

## Cliffs, and going over them

A neighbouring cell whose surface is more than one layer *below* the ball's is a
cliff. Nothing stops the ball going over it. This is where a roller and a walker
part company: the same three-layer drop that a walker treats as a wall and routes
around, a roller treats as the interesting part.

Once the ball's centre crosses into the lower cell, it stops being on a surface
and becomes **airborne**:

- `vz` starts at whatever it was, gravity adds to it every tick
- `vx` and `vy` continue unchanged — no air resistance, because at these speeds
  and over these distances it would be arithmetic performed to produce no visible
  difference
- when `z` reaches the surface below, the ball **lands**: `vz` is reversed and
  multiplied by `restitution`, and if what is left is smaller than
  `bounce_floor`, it is set to zero and the ball is on a surface again

`bounce_floor` is not a nicety. Without it a bouncing ball's `vz` approaches zero
without ever reaching it, and the ball spends the rest of the run performing
several hundred infinitesimal bounces a second, each one a landing event, none of
them visible.

## Falling into a wall

The one geometric case that has to be handled explicitly: a ball that goes over
a cliff and, while airborne, drifts sideways into a column that is taller than
where it is falling.

While airborne the ball is checked against the stone at its **current** height,
not at the height of the surface below it. A column that is solid at the ball's
`z` is a wall to it right now, and it collides with the face the same way it
would on the ground. Skipping that check means balls tunnelling into the side of
walls and re-emerging inside them, and once a ball is inside stone every rule in
this document gives the wrong answer.

## The numbers

All of them in the creature table, none of them here:

`gravity`, `roll_friction`, `restitution`, `bounce_floor`, `radius`,
`rest_seconds`, `max_speed`.

`max_speed` exists so that a ball falling the full height of the world cannot
move more than a fraction of a cell in one tick. A body that moves further than
its own radius between ticks can pass straight through a wall without ever being
within `radius` of it, and no amount of correct collision code will catch it. The
speed cap is the cheapest fix and it is the reason the timestep is fixed.

## Related documents and tools

- [Locomotion is a dispatch table](012-locomotion-is-a-dispatch-table.md) — the row this is
- [The stone and what is inferred](002-the-stone-and-what-is-inferred.md) — what a face is
- `./run-maze --headless` — reports how far balls got and how many are resting
