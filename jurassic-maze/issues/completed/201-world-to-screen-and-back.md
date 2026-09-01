# 201 — World To Screen, And Back

| | |
| --- | --- |
| Phase | 2 — The Eye |
| Blocked by | 101 |
| Blocks | 202, 204 |
| Reads | [the isometric projection](../../docs/006-the-isometric-projection.md) |
| Open questions | none |

## Current behavior

Two-to-one isometric, in `040-the-projection.lua`. Pure arithmetic that does not
import the engine, so the headless runner loads it.

`visible_range` extends the swept range by the tallest a column can reach,
converted from pixels into cells, in the direction of increasing `x + y`.
`pick` marches down through the layers rather than using the cheap inversion,
because a click landing on a wall's top otherwise reports the cell behind the one
being looked at.

`LAYER_PIXELS` was raised from 7 to 10 after the first screenshots. At 7 the whole
pile of terraces rose less than a tenth of the footprint's projected height and
the mound read as flat.

## Intended behavior

Two functions and their inverse. Three numbers in — a cell's x, its y, and a
height in layers — and a point on the screen:

    screen_x = (x - y) * half_width  + pan_x
    screen_y = (x + y) * half_height - height * layer_pixels + pan_y

**Two-to-one**, so `half_width` is twice `half_height`. Measured off the
reference picture and recorded in
[the inspiration notice](../../inspiration/NOTICE.md) beside the other
measurements. Two-to-one rather than a true thirty-degree isometric because at
two-to-one every diamond edge advances exactly two pixels across for one down, so
diagonals land on whole pixels and the stone reads as stone.

`layer_pixels` is independent of the cell size, which is what lets the maze be
squat or towering without the floor plan changing.

The inversion returns the cell under a screen point. Exact only at height zero:
a tall column's top face is drawn `height * layer_pixels` up the screen, so a
click on a wall's top reports the cell behind the one being looked at. Fixing
that properly means marching down the ray layer by layer until a solid one is
hit — a handful of iterations, once per click.

Everything in this file is pure arithmetic. It does not import the engine and
the headless runner loads it, because the culling range is useful without a
window.

## Suggested implementation steps

1. Write `to_screen(camera, x, y, height)` and `to_cell(camera, sx, sy)` as
   folded one-liners over the constants above.
2. Write `visible_range(camera, store, screen_w, screen_h)` returning the cell
   bounds to sweep. Extend the range by `layers * layer_pixels / half_height`
   cells in the direction of increasing `x + y`, or tall columns vanish off the
   bottom edge while you scroll. Overestimating costs a few skipped cells, which
   is the correct direction to be wrong in.
3. Write `pick(camera, store, sx, sy)` — the ray march that gets tall geometry
   right.
4. Test: `to_cell(to_screen(x, y, 0))` returns `(x, y)` for every cell in a
   maze, at several scales and pans. The visible range at a known camera contains
   a known cell and excludes another.

## Related documents and tools

- [The isometric projection](../../docs/006-the-isometric-projection.md)
