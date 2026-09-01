# 804 — A Ball Is A Sphere Against Faces

| | |
| --- | --- |
| Phase | 8 — The Mountain |
| Blocked by | 801, 802, 803 |
| Blocks | 805 |
| Reads | [rolling with momentum](../docs/013-rolling-with-momentum.md), `src/071-the-model.info.md` |
| Open questions | three, at the bottom |

## Current behavior

Balls roll on an **interpolated height field**. The floor under a ball is the
four surrounding cell heights blended together, the slope is the derivative of
that blend, and walls are handled by a separate face-and-corner test against the
grid. It works, it is fast, and it is two microseconds a body.

It is also not a three-dimensional simulation, and three of its properties are
wrong for a mountainside:

- **It smooths staircases into ramps on purpose.** That was the right call when a
  staircase was a rare feature cut into a maze of walls. On a mountain whose only
  way down is stairs, it means the balls never bounce down anything — they slide.
  The vision's first sentence is balls *bouncing*.
- **A ball is legitimately inside the stone**, up to a layer, because the blend
  lies about where the floor is. Every test in the project has had to be written
  around that.
- **It knows the world is a grid.** Anything that is not a column of cells — a
  ramp at an angle, a body that is not a ball — cannot be collided with at all.

## Intended behavior

A ball is a sphere with a position, a velocity and a radius. The world is the
model from [803](completed/803-the-height-field-becomes-a-model.md): axis-aligned
rectangles with normals. Every tick, for each ball:

1. **Gravity** adds to the velocity. Straight down, no slope term — a ball on a
   sloped surface accelerates because the surface pushes it sideways, which is
   what a normal is for, and not because anything computed a gradient.
2. **Integrate** the position.
3. **Collect the faces near it** from the model's per-cell index, over the cells
   the sphere overlaps.
4. **For each face, find the closest point on the rectangle** to the sphere's
   centre. Three clamps, one per axis, and for an axis-aligned rectangle that
   point is exact. If it is nearer than the radius, the sphere is overlapping.
5. **Resolve.** Push the sphere out along the face's normal to exactly one radius
   away, then reflect the velocity component along the normal and multiply it by
   restitution. The tangential component is left alone.
6. **Rest.** Below a threshold speed, with a face underneath, the ball stops.

Restitution and friction come from the creature table, not from here.

The thing this buys that the height field cannot: **a staircase collides as a
staircase.** A ball landing on a tread hits a horizontal face and bounces; a ball
arriving fast enough clears the tread and hits the next riser. Neither is
special-cased and neither was possible before.

## Suggested implementation steps

1. Write the closest-point-on-a-rectangle test on its own and check it against a
   slow reference that samples the rectangle. Everything else rests on it, and it
   is four lines that are easy to get subtly wrong at the edges and corners.
2. Do one face at a time and resolve immediately, before checking the next.
   Collecting every overlap and resolving them together sounds more correct and
   is not: two faces meeting at a corner each push out along their own normal, and
   applied together they push twice as far as either wanted.
3. Cap the speed so that one tick's travel is less than a radius, for the same
   reason the old roller does — a body that moves further than its own width can
   pass a face without ever being within a radius of it, and no correct collision
   code catches that.
4. Keep the old roller. It is a row in the locomotion dispatch table, this is a
   second row, and the two can be run against each other on the same map, which
   is the only honest way to find out whether the new one is better.
5. Test that no ball is ever inside a face, with the tolerance at zero this time.
   The old test had to allow a whole layer of penetration because the interpolated
   floor genuinely put balls inside stone. A sphere against real faces has no such
   excuse, and the tolerance being zero is the measurable difference between the
   two approaches.

## Related documents and tools

- [803](completed/803-the-height-field-becomes-a-model.md) — the faces this collides against
- [805](805-a-ball-is-a-sprite-in-a-solid-world.md) — drawing the result
- `docs/013-rolling-with-momentum.md` — what the old roller does, and why

## Open questions

**One. Does a ball spin?** Rolling without slipping ties angular velocity to
linear, and it is the difference between a ball that runs along a rim and one
that climbs it. It is also a second state per body and a second integration. Not
answered.

**Two. What happens at an inside corner?** Two faces meeting at ninety degrees
give two normals, and pushing out along each in turn can walk a ball along the
crease rather than stopping it. The old roller handled this by treating the corner
post as a point rather than as two planes. Whether the same trick is needed here
is not known.

**Three. How many balls does this have to carry?** The old roller does three
hundred in 240 microseconds a tick. A face test is more work per ball and the
per-cell index bounds how much. Nobody has measured it, and the answer decides
whether the aquarium keeps its population.
