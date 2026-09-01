# 077-the-scene-file

Reads and writes a scene: five numbers, a height field, and the name of a picture.

Read this page rather than the source, and read
[901](../issues/completed/901-a-scene-is-a-picture-and-a-datafile.md) before either.

## What it is for

A scene is the whole interface between the thing that builds a world and the
thing that draws one. Two files — a picture with nothing alive in it, and this —
and anything that can read them can run the simulation. No generator, no plate
list, no mesh, no renderer.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `read(path)` | | a scene, or an error naming the line |
| `write(path, scene)` | | |
| `to_pixels(scene, x, y, z)` | a world position | where it lands in the picture |
| `bounds(width, depth, highest, hw, hh, lp)` | | how large a picture of that world must be, and where its origin goes |

## The five numbers are the point of the format

    px = origin_x + (x - y) * half_width
    py = origin_y + (x + y) * half_height - z * layer_pixels

There is nothing else to know. **That is what makes the picture
interchangeable**: the one this project's exporter writes is a picture of the
mountain it built, and a painting somebody made by hand would do just as well.
The work of using one is measuring those five numbers off it — the width and
height of a cell's diamond, the height of one step, and where a known corner
lands.

The projection therefore lives in the file rather than being assumed, and that is
the single decision the format is built around.

## What a scene says

| Line | Meaning |
| --- | --- |
| `scene <name>` | what it is called |
| `image <file>` | the picture beside it |
| `size <width> <depth>` | the footprint in cells |
| `projection <hw> <hh> <lp>` | how a cell and a layer measure, in pixels |
| `origin <x> <y>` | where world (0, 0, 0) lands in the picture |
| `spawn <x> <y> <z>` | where a body enters |
| `height` | then one line per row, one number per cell |

Heights are **planes**: a cell of 22 is ground you stand on at 22. The stone
store's off-by-one belongs to a bitmask this format does not have.

## The reader and the writer are in one file on purpose

Split across two, a format drifts, and it drifts *silently*, because each half
stays consistent with itself and only the pair disagrees. The test is a round
trip for the same reason.

## It refuses rather than guesses

No field has a default and every missing line is an error naming its line number.
A scene that loads with a plausible substitute is a simulation running on a world
nobody described, and the symptom is bodies in the wrong place by an amount
nobody can account for. A projection with a zero in it is refused outright: it
collapses the world onto a line and puts every body on the same pixel.
