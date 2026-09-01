# 901 — A Scene Is A Picture And A Datafile

| | |
| --- | --- |
| Phase | 9 — The Client |
| Blocked by | 801, 803 |
| Blocks | 902, 903 |
| Reads | `src/040-the-projection.info.md`, `src/067-sightlines.info.md` |
| Open questions | two, at the bottom |

## Current behavior

Everything that draws the world builds it first. The viewer loads the map, flattens
it, bakes two meshes out of sixteen thousand polygons and holds a stone store in
memory — all so that it can put a picture of a mountain on the screen that is
identical every single frame and identical between runs.

For the prototype that is the wrong shape entirely. The mountain does not move.
The only things that move are the balls.

## Intended behavior

A **scene** is two files and nothing else:

- a **picture**, in PNG, of the world with nothing alive in it
- a **datafile** of the geometry, which says what shape the world is and where
  that shape lands in the picture

Anything that can read those two can run the simulation and draw it. It does not
need the generator, the map format, the plate list, the mesh builder or the
renderer — none of which have anything to say once the picture exists.

### The datafile

Plain text, line-oriented, and readable by anything. The whole file is a handful
of numbers and a grid.

| Line | Meaning |
| --- | --- |
| `scene <name>` | what it is called |
| `image <file>` | the picture beside it |
| `size <width> <depth>` | the footprint in cells |
| `projection <half_width> <half_height> <layer_pixels>` | how a cell and a layer measure, in pixels |
| `origin <x> <y>` | where world (0, 0, 0) lands in the picture, in pixels |
| `spawn <x> <y> <z>` | where a body enters |
| `height` | followed by one line per row, one number per cell, in planes |

### The five numbers are the whole interface

A world position becomes a pixel of the picture by

    px = origin_x + (x - y) * half_width
    py = origin_y + (x + y) * half_height - z * layer_pixels

and there is nothing else to know. **That is what makes the picture
interchangeable.** The one written by this project's exporter is a picture of the
mountain it built; a hand-drawn painting of a maze would do just as well, and the
work of using one is measuring those five numbers off it — the width and height of
a cell's diamond, the height of one step, and where a known corner sits.

That is the whole point of the format, and it is why the projection lives in the
datafile rather than being assumed.

### Heights are planes

A cell of height 22 is ground you stand on at 22, which is the map's convention
and not the stone store's. The store's off-by-one belongs to a bitmask this format
does not have and does not want.

## Suggested implementation steps

1. Write the reader and the writer together, in one file, and make the test a
   round trip: write a scene, read it back, and require the two to be identical
   field for field. A format with a reader in one place and a writer in another
   drifts, and it drifts silently because each half is self-consistent.
2. Refuse rather than guess. A missing line, a row of the wrong length, a
   projection of zero — each is a file somebody edited by hand, and a scene that
   loads with a plausible default is a simulation running on a world nobody
   described.
3. Keep it plain text. A binary format would be smaller and nobody could look at
   one and see what was wrong with it.

## Related documents and tools

- [902](902-the-exporter-draws-the-world-once.md) — what writes a scene
- [903](903-the-client-draws-only-what-moves.md) — what reads one
- `src/069-the-map.info.md` — the authored format a scene is exported *from*

## Open questions

**One. Does the datafile carry the bodies?** A scene today is a static world and
the client decides what lives in it. If a scene ever wants to say "ninety balls,
here" it would need a population, and that is a different kind of thing from
geometry. Not answered.

**Two. Does the picture have to be one image?** A mountain at a useful zoom is
about a megapixel and that is fine. A painting the size of the reference picture
is fifty times that, and a client that has to hold all of it to draw a corner will
want tiles. Not answered.
