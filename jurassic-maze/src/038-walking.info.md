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
| `drawn_position(store, bodies, id)` | | where the renderer puts it |
| `idle_offset(Creatures, bodies, id)` | | what the current idle does to the drawn height |
| `release_partner(world, bodies, id)` | | ends a shared idle, for both |
| `INTENT_WANDER`, `INTENT_IDLE`, `INTENT_ERRAND` | | |

`drawn_position` takes **no** `Stone` argument. It used to, and the parameter
shadowed the module's own — so every caller passing nil for it got a nil index,
in the draw path, only for walking bodies. It did not show up until the first
screenshot of a scene that had any, and that screenshot was written off at the
time as the window manager throttling a background window.

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

## Errands, and why they exist

A wandering body never arrives, so nothing it does ever finishes — which is fine
for the body and useless for the camera, whose whole job is to notice when the
thing it is watching is over. An errand gives a body a destination and therefore
an ending.

The destination is deliberately **near**: a block or two away, drawn from the
floor cells bucketed by block at world creation. A cell drawn from the whole maze
is a three-hundred-step journey costing five milliseconds to plan, and it is also
the wrong journey — nobody watches a two-minute trek.

The path is computed once and kept. A body knocked off it — by a fall, or by
being pushed aside in a crowd — **replans once** from where it actually is toward
where it was actually going. Abandoning outright throws the errand away for a
displacement of one cell, and at any real density that happened nineteen times in
twenty.

## Idling

An idle is a row in the creature table with a clock. The simulation's whole
involvement is which row and how much of that clock is left; `idle_offset` turns
it into a drawn height — a sine for the bob, a constant for the squat, both eased
in and out over the whole idle so a squat does not snap on and off.

`breathe` is the default and the one that matters. A genuinely motionless body
reads as a bug: the eye assumes something crashed.

## Falling is the shared one

A walker that walks off a ledge hands itself to `Locomotion.apply_falling`, the
same one a ball uses, and **abandons its step rather than resuming it** — the
surface it was heading for is no longer adjacent to where it landed.
