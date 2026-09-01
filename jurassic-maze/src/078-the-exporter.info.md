# 078-the-exporter

Draws the world once, at its own size, and writes the picture and the datafile
together.

Read this page rather than the source, and read
[902](../issues/completed/902-the-exporter-draws-the-world-once.md) before either.

## What it is for

The mountain does not move. Nothing about it changes between one frame and the
next or between one run and the next, and the viewer has been rebuilding sixteen
thousand polygons of it sixty times a second to produce the same picture every
time. Once the picture exists *as a picture*, the only thing left to draw is the
balls.

Run it with `./export-scene`.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `export(deps, world, into, name, love_graphics)` | | what it wrote, how big, and how much of it can be seen |

`deps` carries Stone, Projection, Palette, Renderer, SceneFile and Sightlines,
handed in rather than loaded — a second copy of the palette would be a picture
drawn in colours nothing else uses.

## The canvas is the size of the world, not of a window

The projected bounds are arithmetic, and each extreme is a named corner: the
leftmost point is the far end of the y axis, the rightmost the far end of x, the
topmost the summit, the lowest the near corner at ground level. A canvas sized by
guesswork crops the summit, and nobody notices until a ball rolls off the top of
the picture.

## Both files come out of one run, from the same numbers

An exporter that wrote the picture and left somebody to work out the origin
afterwards would produce scenes that are subtly wrong in a way nothing catches
until a ball is seen floating a foot above the ground.

## It reports how much of the world can be seen

The client has no depth buffer and no way to draw a body *behind* stone — it has
a photograph and some sprites, so it can only decline to draw one. The fraction
of the surface the camera can reach is therefore the number that says whether a
scene is usable, and it comes free from the sightline survey. A scene that hides
a third of its own floor will hide a third of its bodies.
