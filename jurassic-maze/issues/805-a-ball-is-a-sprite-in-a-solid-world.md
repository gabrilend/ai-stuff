# 805 — A Ball Is A Sprite In A Solid World

| | |
| --- | --- |
| Phase | 8 — The Mountain |
| Blocked by | 803, 804 |
| Blocks | — |
| Reads | [drawing a pile of stones](../docs/007-drawing-a-pile-of-stones.md), `src/071-the-model.info.md` |
| Open questions | two, at the bottom |

## Current behavior

A ball is drawn as a filled circle with a shadow under it, at the screen position
its world position projects to. It is convincing enough at a distance and it is
obviously a circle up close.

The stone around it is drawn by a sweep over columns rather than from any model,
so the two disagree about what the world is: the physics will be colliding with
faces while the renderer draws bitmasks.

## Intended behavior

Two halves that meet at the projection and nowhere else.

**The world is drawn from the model.** Each face is already a rectangle with a
normal, and the normal is what picks its tone — up is lit, the two horizontal
directions that face the camera get the other two. That is the three-tone shading
the renderer already does, arrived at from geometry rather than from a face
constant, and it means a surface added later that is neither a top nor a riser
shades correctly without anybody deciding what it is.

Faces are drawn back to front, which for a fixed camera is a sort on `x + y`
and nothing more.

**A ball is a two-dimensional sprite.** Not geometry. It has a world position in
three dimensions, that position projects to a screen point, and a sprite is drawn
centred there, scaled by the camera. Its size does not change with distance —
there is no perspective in this projection, so a sphere of a given radius is
always the same number of pixels across.

The sprite is drawn between bands of stone, in the band its cell belongs to, so
that stone in front of a ball covers it and stone behind it does not. The
existing renderer already splits its mesh into bands for exactly this, and the
argument is unchanged: a ball drawn after all the stone sits on top of walls that
are in front of it.

## Suggested implementation steps

1. Draw the model with flat colours first and no sprites at all, and compare it
   against the existing column sweep on the same map. They are drawing the same
   world by two different routes, so any difference is a bug in the new one.
2. Take the tone from the normal rather than from the face kind, even though
   there are only two kinds today. The whole reason to have normals is that the
   shading stops being a table of special cases.
3. Then the sprites, and start with the circle that is already there so that only
   one thing has changed at a time.
4. The shadow is a separate question and probably a separate sprite: an ellipse
   on the surface below the ball, which the model can find by asking for the
   nearest face beneath it.

## Related documents and tools

- [804](804-a-ball-is-a-sphere-against-faces.md) — where the position comes from
- `src/042-the-renderer.info.md` — the sweep this would replace, and its banding

## Open questions

**One. Does the model renderer replace the column sweep or sit beside it?** The
sweep is fast, correct, and does an outline trick with two meshes that the model
has no equivalent for yet. Two renderers is two things to keep in step; one
renderer means losing something that works. Not answered.

**Two. Where do sprites come from?** There is no art in this project at all. A
ball can be a drawn circle forever, but "two-dimensional sprites" implies files
somebody made, and nobody has said what draws them or what they look like. Not
answered.
