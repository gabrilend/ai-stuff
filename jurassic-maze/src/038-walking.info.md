# 038-walking

The row that steps from surface to surface. Little guys.

Read this page rather than the source, and read
[walking the surface graph](../docs/014-walking-the-surface-graph.md) before
either.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `link(Stone, Locomotion, Moving, Creatures)` | | hands in the modules at world creation |
| `advance(world, bodies, roster, first, last, dt)` | | moves a slice of the walking roster |
| `begin_step(world, bodies, id, kind)` | | sets up one journey; false if there is nowhere to go |
| `drawn_position(Stone, store, bodies, id)` | | where the renderer puts it |
| `INTENT_WANDER`, `INTENT_IDLE` | | |

## How a walker moves

No velocity. It holds the surface it left, the surface it is arriving at, and a
`progress` from zero to one, advanced by `dt / step_seconds`. At one, the stance
becomes the destination and it decides again.

**It is either at one surface or at another.** It is never between them as far as
anything that matters is concerned, which is what makes both spatial questions
simple: which cell it is in is exactly one cell, always, and who is near it is one
bucket lookup. A continuous position would put a walker in two cells for half of
every step and every question about it would need a tie-breaking rule.

## Wandering is weighted against reversing

An unweighted random walk on a graph spends most of its time going back and forth
across the same two cells, which reads as broken rather than as aimless. The
weight is never zero: a body in a dead end must be able to turn around, and a rule
that forbids it produces a body that stands in a corner for the rest of the run,
vibrating.

## Smoothing belongs to the renderer

`drawn_position` interpolates between the two surfaces, and **the simulation
never calls it**. That separation is the whole reason a smoothed graph walk was
chosen over continuous motion for these bodies: the simulation gets a graph,
which is cheap and exact, and the eye gets smoothness, which is a lie the
renderer tells.

The **arc** on a vertical step is a cosmetic hack, and it is written down because
somebody tidying up will delete it. Interpolating a one-layer climb in a straight
line makes the body slide up a diagonal, which reads as ascending an invisible
ramp rather than as climbing. A flat step gets no arc, because the difference is
zero.

## Falling is the shared one

A walker that walks off a ledge hands itself to `Locomotion.apply_falling`, the
same one a ball uses, and **abandons its step rather than resuming it** — the
surface it was heading for is no longer adjacent to where it landed.
