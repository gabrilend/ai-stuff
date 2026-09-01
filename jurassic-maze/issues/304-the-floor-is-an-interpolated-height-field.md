# 304 — The Floor Is An Interpolated Height Field

| | |
| --- | --- |
| Phase | 3 — The Rolling |
| Blocked by | 102, 303 |
| Blocks | 305, 306 |
| Reads | [rolling with momentum](../docs/013-rolling-with-momentum.md) |
| Open questions | none |

## Current behavior

The locomotion table has a `rolling` row and it does nothing.

## Intended behavior

A ball is never on a cell. It is at a fractional x and y, and the floor under it
is obtained by bilinearly interpolating the surface heights of the four cells
around it — with one rule attached that keeps the interpolation honest:

> **Only cells within one layer of the ball's own surface contribute their real
> height.** A cell higher than that is a wall and contributes the ball's own
> height instead.

Without the rule, interpolating between a corridor at layer four and a wall at
layer six makes a gentle ramp into the wall and the ball rolls up it. With it,
the floor is flat right up to the wall and the wall is handled by collision,
which is what a wall is.

A **staircase is where this pays off**: every step is one layer, so every step is
within the limit, so the flight becomes a continuous ramp and the ball
accelerates smoothly down it. That is a deliberate lie about the geometry — the
steps really are steps — told because the alternative is a ball bouncing
chaotically down every staircase in the maze, which is harder to test and no more
convincing.

The forces, per tick, in order: gravity along the floor's gradient, then rolling
resistance opposing the velocity, then integration. The gradient is sampled from
the same field rather than reasoned about from cell heights, so it is
automatically zero on flat ground, automatically downhill on a staircase, and
automatically zero at a wall — because that is what the field does there.

`roll_friction` exists so the aquarium does not fill with balls oscillating in
the bottom of dips forever.

## Suggested implementation steps

1. Write `floor_height(store, x, y, layer)`: find the four surrounding cells,
   clamp each one's contribution by the one-layer rule, bilinearly interpolate.
   Fold it and comment the clamp with the rolls-up-the-wall failure it prevents.
2. Write `floor_gradient` by sampling the field a small distance either side in
   each axis. Do not differentiate the interpolation analytically — the clamp
   makes it piecewise and the sampled version is correct at the seams where the
   analytic one is not.
3. Write the `rolling` row's `advance`: for each body in the chunk, gradient,
   friction, integrate, then hand off to issue 305's collision and issue 306's
   fall check.
4. Cap the speed at `max_speed`, and comment it with why: one tick at that speed
   must move less than the ball's radius or it can pass a wall without ever being
   near it, and no amount of correct collision code catches that.
5. Test: a ball released on a staircase accelerates monotonically until friction
   balances it. A ball on flat ground comes to rest within `rest_seconds`. A
   ball beside a wall taller than one layer feels no slope toward it.

## Related documents and tools

- [Rolling with momentum](../docs/013-rolling-with-momentum.md)
