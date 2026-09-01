# 037-rolling

The row with momentum in it. Balls.

Read this page rather than the source, and read
[rolling with momentum](../docs/013-rolling-with-momentum.md) before either.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `link(Stone, Locomotion, Moving, Creatures)` | | hands in the modules, once, at world creation |
| `advance(world, bodies, roster, first, last, dt)` | | moves a slice of the rolling roster |

The modules are handed in rather than loaded here because the world already has
them, and loading them again would produce a second copy of every table —
including the creature table, which would then be tuned in one copy and read from
the other. That is exactly the bug that made a parameter sweep report identical
numbers for twelve different settings.

## How a ball moves

It is never on a cell. It has a real position, a velocity, and a floor obtained
by interpolating the heights of the four cells around it.

Per tick, on the ground: slope, friction, speed cap, integrate, resolve faces,
resolve corners, glue to the floor. In the air: resolve against the stone at the
ball's *current* height, integrate, fall.

## Four things this file gets right on purpose

**The interpolation clamp.** Only cells within one layer of the ball's own
contribute their real height. Without the wall half, the blend ramps into the
wall and the ball rolls up it. Without the cliff half, the floor slopes away over
the edge and the ball is dragged down the cliff face instead of leaving the ledge.

**The slope is analytic.** Four corner heights make the patch exactly bilinear,
so the derivative is one subtraction per axis. Sampling the field either side
costs four more interpolations and is wrong wherever the samples straddle a patch
boundary. This was five interpolations per ball per tick and is now one, which is
most of the difference between fourteen microseconds a body and two.

**Corners, not just faces.** Where two walls meet, the nearest point of the
obstacle is the corner post, so the ball is pushed away from a *point*. Handling
only the faces lets a ball squeeze diagonally through the join between two
blocks, which looks exactly like passing through solid stone and happens rarely
enough to be dismissed as a glitch. It is the single most likely bug in this file.

**The airborne wall check is against the stone at the ball's height**, not
against the surface below it. Skipping it lets a ball tunnel into the side of a
wall and re-emerge inside it, after which every rule gives the wrong answer: the
floor under it is the top of the block it is inside, so it is standing on
nothing, so it falls forever.

## The speed cap is load-bearing

One tick at `max_speed` moves less than the ball's radius. A body that moves
further than its own width in a tick can pass a wall without ever being within
radius of it, and **no amount of correct collision code catches that**. It is
also why the timestep is fixed rather than whatever the frame happened to take.

## A ball is legitimately inside stone, a little

Halfway across a step the blended floor is between the two cells' heights while
the ball is still over one of them. The clamp bounds the dip at one layer.
`tests/053-bodies-stay-outside-stone.lua` checks that bound rather than zero, and
the note there explains why.
