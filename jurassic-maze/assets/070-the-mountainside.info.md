# 070-the-mountainside

The mountainside, written by hand from the reference picture.

Read this page rather than the source, and read
[801](../issues/completed/801-a-map-is-plates-and-stairs.md) for the format it is written
in.

## What it is for

The known-good map. Nothing generates it and nothing about it is random, which
makes it the one thing in the project that can be trusted while the code around
it is under suspicion: when a ball does something strange here, the ball is what
is wrong.

Run it with `./run-maze --map 070-the-mountainside`.

## What was taken from the picture

It is read off `inspiration/inspiration-maze.png` rather than traced from it —
its idiom, not its cells. Four things, and the first is the one the generator got
wrong:

**There are no walls in that picture.** Not one. Every vertical surface is the
side of a higher flat plate, and what reads as a wall between two corridors is
the edge of a block whose own top is walkable.

**The maze lies on the face of a mountain with a high corner and a low corner.**
The projection draws small x and y at the top of the screen, so (0, 0) is the far
corner and (47, 47) is the near one, and elevation falls as x and y rise. This is
the whole reason the picture can be read: the ground tilts toward the viewer, so
nothing stands in front of anything.

**The shelves are flat and several cells deep**, running across the slope.

**Staircases are the only way down that is not a fall**, and there are a great
many of them.

## How it is built, in four kinds of plate

| | |
| --- | --- |
| **Shelves** | eight nested squares anchored at the far corner, each lower and larger than the last, three layers apart. Each is therefore an L-shaped band six cells wide wrapping the corner — a stepped mountain face made of axis-aligned rectangles. |
| **Rims** | one cell wide along each shelf's downhill edge, two layers up. A kerb, not a fence: its top is a surface like any other, and it exists so a rolling ball is turned rather than dropped. |
| **Dividers** | short blocks three layers up reaching partway across a band, never the whole way. They turn a shelf from a corridor into a choice. A divider that spanned a band would be a wall, and would trap balls above it forever, since nothing here can climb. |
| **The bottom lip** | around the near two edges of the world, so a ball that has come all the way down stays on the mountain. The far edges need none: nothing travels uphill. |

Twelve staircases, alternating between the x edge and the y edge of successive
shelves, so the route down is a switchback. A ball leaving one flight has to
cross its new shelf to reach the next.

## How much of it can be seen

81.2% of cells show some of their face to the camera, and 78.5% show their
centre. Every hidden cell is behind a rim (351 of them) or a divider (83) — the
two features that are deliberately taller than the ground behind them. Nothing is
hidden by accident.

For comparison, the generated maze this replaces showed 29.3%, and the reason was
structural rather than incidental: see
[109](../issues/109-nothing-hides-behind-anything.md).

Measure it again with `src/067-sightlines.info.md` rather than trusting these
numbers; they were true when they were written.

## The three-layer concession

Shelves are three layers apart rather than four. That is not a design choice: the
stone store keeps a column as a 32-bit integer with one bit per layer, and a
mountain with four-layer shelves comes to thirty-four. The map format has no such
ceiling and does not need the bitmask, having no holes in it. See open question
two of [801](../issues/completed/801-a-map-is-plates-and-stairs.md).
