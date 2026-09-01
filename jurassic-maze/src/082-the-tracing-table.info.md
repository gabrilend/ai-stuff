# 082-the-tracing-table

A picture, a lattice over it, and the shapes somebody draws onto it. No buttons
anywhere.

Read this page rather than the source, and read
[1002](../issues/1002-the-lattice-is-the-measurement.md) and
[1003](../issues/1003-tracing-is-clicking-corners.md) before either.

## What it is for

Producing the geometry of a world that already exists as a picture, by tracing it
rather than by typing it. Run it with `./trace-scene`.

Nothing on the screen but the picture, the lattice, the vertices and the lines
between them. Every action is a click, a drag, a wheel or a key.

## The lattice is the instrument

A scene needs five numbers saying where the world sits in its picture, and for a
picture somebody else made they are not known. Rather than measure them with a
ruler, **the world's own cell grid is drawn over the painting and nudged until the
two agree.** A half-pixel error in the cell width is a whole cell of drift by the
far corner: invisible in a number, obvious on a picture.

Raising the elevation slides the lattice up by exactly one layer's pixels, which
is the second measurement and comes free. Pick a step in the painting, raise the
elevation by one, and see whether the lattice moves from the tread below to the
tread above.

The lattice is bounded by the view and by nothing else. There is no world extent
to clip against, because there is no world until something has been traced — it is
a ruler laid over a picture rather than the edge of a place.

## Elevation is chosen before a vertex is placed

Not a convenience. A pixel of an isometric picture is a whole line of world
points, one for every height, and the only thing that picks one out is somebody
saying which height they meant. **There is no way here to place a vertex whose
height is unknown.**

Elevation is shown as colour rather than position, because position cannot show
it: every height of one pixel column projects to the same place, which is the
whole difficulty this tool exists to get around. Cool for low, warm for high.

## What the mouse does

| Doing | Means |
| --- | --- |
| left click on empty ground | put down a vertex, joined to the last |
| left click on the first vertex of the shape being drawn | close it into a structure |
| left click on an existing vertex, then drag | move it |
| left click on a line | put a vertex into it |
| right click on a vertex | take it out, and rejoin its neighbours |
| right click inside a structure | take the whole structure away |
| middle drag | pan |
| wheel | zoom, at the pointer |

Middle drag pans rather than left, so that the left button is only ever about
vertices. A tool whose main button does two things depending on where you are is a
tool that deletes work by accident.

The grab reach is measured in **world cells rather than pixels**, so it does not
change with the zoom — a reach in pixels makes every vertex unclickable when
zoomed out and every click a grab when zoomed in.

## What the keys do

`[` `]` elevation · `s` save · `tab` snapping · `g` holes · `n` nudge size ·
`t` cycle the tag under the pointer · `backspace` undo a point · arrows move the
origin · `-` `=` cell size · `,` `.` layer height · `escape` leave.

Cell size keeps the two-to-one ratio unless shift is held, because that ratio is
the one thing about an isometric picture that is nearly always the same, and
keeping it means one key to calibrate instead of two that have to agree.

## Holes are shown, and are off to begin with

At the start every cell is untraced, so shading them is a wash over the whole
picture that hides the very thing being traced. It earns its place once there is
some work to compare against.

## Saving writes both files

The plan, which keeps the shapes and can be reopened, and the scene, which is the
rasterised height field the client plays. Reopening its own work is the difference
between a tool and a stunt.
