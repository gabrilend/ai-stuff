# 040-the-projection

World to screen and back. Two-to-one isometric.

Read this page rather than the source, and read
[the isometric projection](../docs/006-the-isometric-projection.md) before
either.

## What it is for

Pure arithmetic. It does not import the engine, and the headless runner loads it,
because the culling range is useful without a window.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `to_screen(camera, x, y, height)` | | a point on the screen |
| `to_cell(camera, sx, sy)` | | the fractional cell under a screen point, at height zero |
| `visible_range(camera, store, w, h)` | | the cell bounds worth sweeping |
| `pick(Stone, camera, store, sx, sy)` | | the cell and layer actually being pointed at |
| `centre_on(camera, x, y, height, w, h)` | | sets the pan so a world point lands in the middle |
| `HALF_WIDTH`, `HALF_HEIGHT`, `LAYER_PIXELS` | | measured off the reference picture |

## Two-to-one, and why

A cell is twice as wide as it is tall, so every diamond edge advances exactly two
pixels across for one down. Diagonals land on whole pixels and the stone reads as
stone instead of as a stack of slightly wrong staircases. It is why essentially
every hand-drawn isometric picture ever made is two-to-one, including the one
this is copying.

`LAYER_PIXELS` is independent of the cell size, which is what lets the maze be
squat or towering without the floor plan changing underneath it.

## `to_cell` is exact only at height zero

A tall column's top face is drawn `height * LAYER_PIXELS` further up the screen,
so a click landing on a wall's top reports the cell *behind* the one being looked
at. `pick` marches down through the layers to fix that — a handful of iterations,
once per click — and `to_cell` is the cheap version the culling uses, where being
a few cells wrong is harmless.

## The culling range is deliberately generous

It is extended by the tallest a column can reach, converted from pixels into
cells, in the direction of increasing `x + y`. Without that, a column whose base
is below the window but whose top face is inside it gets dropped, and walls
vanish off the bottom edge of the screen while you scroll. Overestimating costs a
few skipped cells, which is the correct direction to be wrong in.
