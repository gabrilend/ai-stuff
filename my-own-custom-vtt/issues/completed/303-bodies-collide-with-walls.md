# 303 -- Bodies collide with walls

**Phase:** 3, the world ticks
**Blocked by:** [302](302-motion-is-intent-then-resolve.md),
[104](104-walls-are-segments.md)
**Blocks:** [310](310-the-phase-three-demo.md)
**Documents:** [the map is geometry](../../docs/006-the-map-is-geometry-not-a-picture.md)

## Current behaviour

Nothing moves, so nothing collides.

## Intended behaviour

The resolve half of motion: given where a body intends to be, decide where it
actually ends up.

A body is a circle of `radius` at a point. A wall is a segment. The question is
whether the swept circle crosses a segment with `BLOCKS_MOVEMENT` set, and if so
where it stops.

### Slide, do not stop

A body pushed into a wall at an angle should slide along it, not halt. This is the
difference between controls that feel alive and controls that feel broken, and it
is one projection: take the remaining movement, project it onto the wall's
direction, move by that.

Doing it twice handles the corner case literally -- a body sliding into a corner
projects against the first wall, then against the second, and stops. **Twice, then
stop.** Iterating until convergence is how a body ends up jittering in a corner
forever or escaping through it, and both are worse than not moving.

### `BLOCKS_SIGHT` is not consulted here

The two flags are separate and this pass reads only one of them. A chasm blocks
movement and not sight; a curtain does the reverse. A `ONE_WAY` segment is checked
against which side the body started on.

### Bodies do not collide with each other

Not in this phase and possibly not ever. Two bodies may stand in the same place.
That is normal at a tabletop -- miniatures get stacked, a character is carried, a
swarm occupies a square -- and enforcing separation is a *rules* question about how
much space a creature claims, not a geometric fact about the world.

If a ruleset wants exclusion it refuses the command, which is
[gate 5](../../docs/010-commands-enter-through-one-door.md). Writing body-body
collision into the server would mean the server having an opinion about how big a
creature is, and it has none.

**This decision should be commented in the source**, because "bodies pass through
each other" reads as a missing feature to anybody who has not been told why.

## Suggested implementation steps

1. Use the broad phase from [202](202-an-eye-and-its-wedge.md) against the swept
   circle's bounding box.
2. Write swept-circle-against-segment in fixed point. The endpoints are the awkward
   part -- a circle can hit a segment's end cap rather than its side -- and both
   cases need handling and a comment.
3. Write the slide as a projection, applied at most twice, with the reason for the
   limit beside it.
4. Handle the body that starts already overlapping a wall. It happens after an
   `EDIT_WORLD` drops a wall on somebody. Push it to the nearest free point rather
   than trapping it, and say so in a comment.
5. Write the companion `.info.md`.
6. Test: head-on stop, angled slide, corner, doorway just wider than the body,
   doorway just narrower, a body starting inside a wall, and a `ONE_WAY` from both
   sides.
