# 803 — The Height Field Becomes A Model

| | |
| --- | --- |
| Phase | 8 — The Mountain |
| Blocked by | 801, 802 |
| Blocks | 804, 805 |
| Reads | [the stone and what is inferred](../../docs/002-the-stone-and-what-is-inferred.md) |
| Open questions | two, at the bottom |

## Current behavior

Nothing in the project has ever built geometry. The renderer draws a diamond and
two parallelograms per column straight from the height field, and the ball
physics samples an interpolated height field rather than touching anything solid.
Both work by knowing that the world is a grid, and neither could answer the
question "what is the surface here" without that assumption.

That was affordable while the world was a grid of columns. It stops being
affordable the moment a ball is supposed to bounce off a staircase, because a
staircase is a sequence of small flat faces and small vertical faces and the
interpolated-height-field trick deliberately smooths exactly that away.

## Intended behavior

One pass turns the height field into a **model**: a list of flat quadrilaterals
in three dimensions, each with a normal, which is what the ball collides against
and what the renderer draws.

Three kinds of face come out of a height field, and no others.

**Tops.** One horizontal quad per cell, at that cell's elevation, normal
straight up. Adjacent cells at the same elevation may be merged into one larger
quad, and the merge is worth doing: a shelf twelve cells across is one face
rather than a hundred and forty-four, and both the physics and the renderer are
linear in faces.

**Risers.** Where two neighbouring cells differ in elevation, the taller one has
a vertical quad along the shared edge, spanning the difference, normal pointing
horizontally toward the lower cell. This is every cliff, every rim, and every
step of every staircase, and none of them are a special case.

**The skirt.** The rim of the world has risers to elevation zero, so the model is
closed and a ball that leaves the map falls out of a solid object rather than
through a hole in one.

The model is built once, at load, and never changes. Nothing in phase 8 modifies
stone, and when something eventually does, it rebuilds the faces it touched
rather than the world.

## Suggested implementation steps

1. Emit one quad per cell top and one per elevation difference, with no merging
   at all, and get the count right first. A model with the right faces in the
   wrong order is debuggable; a model missing faces is not.
2. Check it against the height field rather than against a picture: every top's
   elevation must equal the field, and every riser must have a taller cell on one
   side and a shorter on the other.
3. Merge tops only once the unmerged version is correct, and keep the unmerged
   one behind a flag, because the merge is the only part of this that can be
   subtly wrong.
4. Index the faces by cell so that the physics can ask "what is near this ball"
   without scanning the model. A ball touches at most a handful of faces and the
   model has tens of thousands.

## Related documents and tools

- [801](801-a-map-is-plates-and-stairs.md) — where the height field comes from
- [804](804-a-ball-is-a-sphere-against-faces.md) — the thing that collides with this

## Open questions

**One. Quads or triangles?** Every face here is axis-aligned and rectangular, so
quads are exact, half the count, and simpler to collide against. A triangle list
is what any renderer or exporter would want. Carrying both is a duplication that
will drift. Not answered.

**Two. Does the model know about materials?** The renderer's three tones are
currently chosen from face orientation, which the model has. Whether a face also
carries what it is made of depends on open question one of
[801](801-a-map-is-plates-and-stairs.md). Not answered.
