# 081-the-plan

Polygons at elevations, drawn over a picture, and the height field they rasterise
to.

Read this page rather than the source, and read
[1001](../issues/completed/1001-a-plan-is-polygons-at-elevations.md) before either.

## What it is for

A world that already exists as a picture cannot be typed. The reference painting
is a mountain with a real shape covered in a maze somebody drew, and the
simulation has to agree with it — so the shape has to be *traced*, and a traced
shape has corners rather than a width and a depth.

The plan is the source; the scene is the output. A scene is rasterised and cannot
be edited back into shapes, so throwing the shapes away after the first save
would make every later correction a retrace.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `new(header)` | | an empty plan over a picture |
| `read(path)` / `write(path, plan)` | | |
| `rasterise(plan)` | | the height field, its extent, and what is not covered |
| `to_scene(plan, field, spawn)` | | the same world as a scene |
| `to_pixels(plan, x, y, z)` | | where a world point lands in the picture |
| `to_cell(plan, px, py, z)` | | where a pixel is in the world, at a chosen elevation |

## A structure is flat, and that is what the painting is made of

Every surface in that picture is either a flat top or the vertical side of a
higher flat top, so the sides follow from the tops without anybody drawing them.
A structure is a closed loop of world points at one elevation, with a tag.

**Where two overlap, the higher wins, and the order does not matter.** A block
standing on a plaza is the plaza and then the block, rather than the plaza cut
into a ring around it — and somebody adding a structure must not have to work out
where in the list it belongs.

## The world is as big as what was traced

Nothing declares a width and a depth. Declaring them first means choosing how much
of a picture is going to be the world before knowing what is in it, and then
fitting the trace into that box — which is backwards, and makes the box a thing to
get right in advance and adjust afterwards. The extent falls out of the shapes.

**Cells no structure covers are holes, counted rather than filled.** Inside the
traced region a hole is a real gap between two shapes and is exactly what somebody
needs to see; outside it there is no region at all, so nothing is missing.

## `to_cell` needs the elevation, and cannot be given without it

A pixel of an isometric picture is a whole *line* of world points, one for every
height, and the only thing that picks one out is somebody saying which height they
meant. That is the entire reason the tracing table makes you choose an elevation
before you may place a vertex.

## The shift in `to_scene`, worked through once

A traced world begins wherever the first shape landed and a scene's height field
begins at cell zero, so the world is shifted to the origin and the picture's
origin is shifted the opposite way by exactly as much, leaving every pixel where
it was.

A world point is drawn at `origin_x + (x - y) * half_width`. Substituting
`x = x_scene + min_x` gives `[origin_x + (min_x - min_y) * half_width] +
(x_scene - y_scene) * half_width`, and the bracket is the scene's origin. The
vertical works the same way with a plus instead of a minus, because the screen's
y is the *sum* of the world's two axes rather than their difference.

## Even-odd, so holes need not be declared

A cell belongs to a structure when the structure's outline encloses the cell's
**centre**. Testing a corner would put a cell in whichever of four shapes happened
to touch that corner. Even-odd handles a shape traced with a hole in it without
anybody having to say that holes exist — and a traced painting is full of them.
