# 042-the-renderer

One sweep that turns disagreements between columns into polygons.

Read this page rather than the source, and read
[drawing a pile of stones](../docs/007-drawing-a-pile-of-stones.md) before
either.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `sweep(Stone, store, minx, miny, maxx, maxy, emit)` | | every visible face in a rectangle, in memory order |
| `sweep_by_diagonal(Stone, store, emit)` | | the same faces, grouped into bands |
| `sweep_cell(Stone, store, x, y, band, emit)` | | one column's faces; both orders call this |
| `corners(Projection, flat, face, x, y, low, high, out)` | | the four screen points of a face |
| `build(Stone, Projection, Palette, store, love_graphics)` | | the two static meshes and their band ranges |
| `bucket_bodies(store, bodies, into)` | | groups live bodies by the band they draw in |
| `draw_body(...)` | | one body, with its shadow |
| `count_faces(Stone, store)` | | how many faces the maze has, without building anything |
| `FACE_TOP`, `FACE_LEFT`, `FACE_RIGHT` | | |

`emit(face, cell, x, y, low, high, edges)` gets heights in layers, where a block
occupying layer L spans L to L+1, and `edges` says which of the face's four sides
is a real edge rather than a seam against an identical neighbour.

## The renderer never draws a block

A block is a set bit and a face is a disagreement between two neighbouring
columns. The exposed part of a side is `column & ~neighbour`, one operation — two
identical columns side by side give zero and draw nothing, which is why a large
solid terrace costs its outline rather than its area.

The other two sides of every block and its underside face away from the viewer
and are never considered. Two-thirds of the geometry gone for free, which is the
whole benefit of a fixed camera angle.

## Two sweep orders, both correct

Row by row is the array's own memory order. Band by band groups cells sharing one
value of `x + y`, which cannot occlude each other.

The bands exist because **bodies have to be drawn between them**. The stone is
one static mesh, a mesh drawn in one call is drawn all at once, and a ball drawn
afterwards would sit on top of every wall in the maze including the ones in front
of it. `build` records each band's index range so the frame can draw stone, then
bodies, then the next band.

## The outline is two meshes and no lines

The faces tile without gaps, so a mesh of full-size faces in the outline colour
is completely hidden by a mesh of **inset** faces on top — except along whichever
sides were pulled in, where the gap shows a line of it. Two draw calls for the
whole maze's linework, and no second sweep.

**Which sides get pulled in is the part that matters.** Insetting all four draws
a line between every pair of neighbouring cells, including two cells of one long
wall whose tops are the same continuous slab. With those lines in, the maze reads
as a field of separate cubes rather than as corridors between walls — the largest
visual error in the first working renderer, and invisible in every number.

## Nothing is rebuilt per frame

The stone does not change, so `build` runs once. When a golem starts breaking
walls in phase seven, it reruns on the store's version counter — which exists
now, and is never bumped, so that the first thing to change the stone cannot
forget it.

`bucket_bodies` reuses the arrays it is given. A renderer that allocates per
frame stutters every time the collector notices, correlated with nothing anybody
can see.

## A body gets a shadow

On the stone its *stance* says it is on, not at its own height — which is the
difference between a falling ball trailing its shadow downward and one whose
shadow waits on the floor for it. There is no perspective in an isometric
projection to say how far away the ground is, so a mark on the ground is the only
cue that a thing is on it rather than floating.
