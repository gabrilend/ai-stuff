# 902 — The Exporter Draws The World Once

| | |
| --- | --- |
| Phase | 9 — The Client |
| Blocked by | 901 |
| Blocks | 903 |
| Reads | `src/042-the-renderer.info.md`, `src/067-sightlines.info.md` |
| Open questions | one, at the bottom |

## Current behavior

The renderer draws the whole maze every frame, into a window whose size has
nothing to do with the size of the world. A picture of the entire mountain at
full resolution has never existed, because nothing ever needed one.

## Intended behavior

One run that produces a scene and stops.

**The canvas is the size of the world, not the size of a window.** The projected
bounds of the map are arithmetic — the leftmost point is the far corner of the y
axis, the rightmost the far corner of x, the topmost the summit, the lowest the
near corner at the ground — so the picture is exactly as large as the mountain
and no larger, plus a margin.

**The picture and the datafile are written by the same run**, from the same
numbers, so they cannot disagree about where the world is. An exporter that wrote
the picture and left somebody to work out the origin afterwards would be an
exporter that produces a scene which is subtly wrong in a way nothing catches
until a ball is drawn floating a foot above the ground.

**It reports how much of the world can be seen.** The client has no depth buffer
and no way to draw a body *behind* stone — it has a photograph and some sprites.
So the fraction of the surface the camera can actually see is the number that says
whether a scene is usable, and it comes free from the sightline survey. A scene
that hides a third of its own floor will hide a third of its bodies.

## Suggested implementation steps

1. Compute the bounds before drawing anything, and make the canvas from them. A
   canvas sized by guesswork crops the summit and nobody notices until the scene
   is loaded.
2. Draw with the existing renderer at scale one and the computed pan. The same
   mesh, the same palette, the same everything — the only difference from a
   normal frame is where it lands.
3. Write the datafile with the pan as the origin, in the same function, before
   the canvas is released.
4. Verify by loading the scene straight back and projecting a known corner. The
   round trip is the only proof that the two files agree.

## Related documents and tools

- [901](901-a-scene-is-a-picture-and-a-datafile.md) — the format it writes
- [903](903-the-client-draws-only-what-moves.md) — what consumes it

## Open question

**Should the exporter draw the bodies' shadows into the picture?** A shadow is a
mark on the ground and the ground does not move, so an unmoving body's shadow
could be baked. Bodies move, so it cannot — but the *ambient occlusion* of the
stone against itself could be, and that is the thing that would make a flat
picture read as carved. Not answered, and not needed for a prototype.
