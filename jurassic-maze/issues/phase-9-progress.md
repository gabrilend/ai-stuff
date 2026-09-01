# Phase 9 — The Client

**All three done.** A world is now two files — a picture and a datafile — and the
thing that draws it needs nothing else. No generator, no map format, no plate
list, no mesh builder, no renderer.

| Issue | |
| --- | --- |
| [901](completed/901-a-scene-is-a-picture-and-a-datafile.md) | a scene is a picture and a datafile |
| [902](completed/902-the-exporter-draws-the-world-once.md) | the exporter draws the world once |
| [903](completed/903-the-client-draws-only-what-moves.md) | the client draws only what moves |

`./export-scene` makes one, `./run-client` plays it.

## The journey, and what it taught

### The five numbers are the whole interface

A world position becomes a pixel by `origin + (x - y) * half_width` across and
`origin + (x + y) * half_height - z * layer_pixels` down, and there is nothing
else to know. That is what makes the picture interchangeable — the one the
exporter writes is a picture of the mountain this project builds, and a painting
somebody made by hand does just as well, with the work of using one being the
measuring of those five numbers off it.

So the projection lives in the datafile rather than being assumed. A client that
used its own constants would be right only for pictures this project drew, which
is the opposite of the point.

### Occlusion without a depth buffer, and it is exact

A body behind a rock has to not be drawn, and the world is a photograph with
nothing to sort it behind. The geometry answers it outright: cast the ray from the
body toward the camera and ask whether any column stands over it. One ray a body a
frame, the same march the sightline survey uses, and **exact** rather than an
approximation of a depth test.

**What it taught:** the sightline work from issue 109 has now paid for itself
three times — first as the measurement that condemned the generator, then as the
check on the hand-authored map, and now as the client's entire visibility model.
It was written to answer a question about a maze and turned out to be about the
camera.

### Two collisions that only showed up when run

`--scene` already meant "which creatures are in it" and had since phase four, so
the front desk routed an ordinary viewer run into the client, which then tried to
parse the word `empty` as a scene file. Two flags of one name in one program is a
collision whose symptom is the wrong program starting.

And the engine's image loader resolves a name inside its own sandbox, rooted at
the game directory, so it could not open a scene sitting anywhere else. The
picture is read with plain Lua io and handed over as bytes now — which is what the
rest of the project already does with its catalogues, and for the same reason.

## What is deferred

**Whether a scene should carry its population.** A radius and a gravity are
properties of a ball rather than of a mountain, so they come from the creature
table — one file the scene does not describe. Open question one of
[903](completed/903-the-client-draws-only-what-moves.md).

**Whether one picture is enough.** A mountain at a useful zoom is about a
megapixel. A painting the size of the reference picture is fifty times that, and a
client holding all of it to draw a corner will want tiles.
