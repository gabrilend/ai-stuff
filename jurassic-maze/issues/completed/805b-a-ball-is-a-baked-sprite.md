# 805b — A Ball Is A Baked Sprite

| | |
| --- | --- |
| Phase | 8 — The Mountain |
| Blocked by | 804 |
| Blocks | — |
| Part of | [805](../805-a-ball-is-a-sprite-in-a-solid-world.md) |
| Reads | `src/042-the-renderer.info.md` |
| Open questions | one, at the bottom, and one answered here |

## Current behavior

A ball is three vector calls a frame: a filled circle, a smaller white circle
offset up and left for a highlight, and an outline. It reads well enough and it
is entirely re-computed sixty times a second for a picture that does not change.

At the sizes it is actually drawn — a radius of 0.4 cells is six pixels across at
scale one — a vector circle is a polygon with visible corners, and the highlight
is a hard-edged white disc rather than a highlight.

## The question this answers, and the answer

**Where do sprites come from, in a project with no art in it?** They are
generated. Nothing is drawn by hand and no image file enters the repository.

A sphere lit from a fixed direction is a closed-form calculation: for each pixel
inside the disc, the surface normal is known from the offset alone, and the
brightness follows from it. That is a function, and a function is a tool. Writing
one is the difference between an asset somebody has to maintain and a number
somebody can change.

## Intended behavior

**The generation is pure arithmetic and knows nothing about the engine.** It
produces the pixels of a sprite as bytes: width, height, and red-green-blue-alpha
per pixel. No window, no texture, no love. The headless runner can produce a
sprite and the test can read one, which is the whole reason for the split.

**The sprite is a shading mask, not a coloured ball.** One sprite serves every
colour: the pixels carry brightness and coverage, and the draw tints them. Baking
one per creature colour would be a sheet that has to be rebuilt whenever a team
colour changes, and the tint costs nothing.

**Coverage is supersampled.** Each pixel's alpha is the fraction of it that falls
inside the disc, measured by sampling a grid inside the pixel. That is what makes
a six-pixel ball look round rather than like a plus sign, and it is the one thing
a vector circle at this size cannot do.

**Three terms make the shading.** A diffuse term from the angle between the
surface normal and the light; a specular highlight, tight and offset toward the
light; and a darkened rim near the silhouette, which is what stops a shaded disc
reading as a flat gradient.

**The shadow is a second sprite** with a soft edge, so a ball reads as being *on*
a surface. There is no perspective in this projection to say how far away the
ground is, so a mark on the ground is the only cue there is.

## Suggested implementation steps

1. Write the pixel generation and its test before anything is drawn. It is pure
   arithmetic over a grid, so the test can assert the things that must be true —
   nothing outside the disc, full coverage at the centre, brightest toward the
   light, symmetric about the light's axis — none of which needs a window.
2. Bake once, at a generous size, and let the draw scale it down. The ball is six
   pixels across at scale one and twenty-six at the zoom somebody actually
   watches at, and a texture scaled down looks better than one scaled up.
3. Keep the vector circle behind a flag until the sprite is clearly better, and
   compare them at the same zoom rather than from memory.

## Related documents and tools

- [805](../805-a-ball-is-a-sprite-in-a-solid-world.md) — the whole of which this is half
- [805a](../805a-the-world-is-drawn-from-the-model.md) — the other half
- `src/041-the-palette.info.md` — where a creature's colour comes from

## Open question

**Does a rolling ball show that it is rolling?** A sphere with no marking on it
looks identical however it is turned, so a ball crossing the screen reads as
sliding. A stripe or a pair of dots would make the rotation visible — and there
is no rotation in the physics to draw, since the sphere carries no angular
velocity. Open question one of
[804](804-a-ball-is-a-sphere-against-faces.md) is the same question
from the other side. Not answered.
