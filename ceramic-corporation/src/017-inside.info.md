# 017-inside

Checks that a map inside a box lines up with the box, and looks inside.

## What it is for

"A map is a box." A box may say `inside PATH`, and the org there is how the
box does its work; from inside, the box's ports are the outside world. This
module holds that wall: N1–N6 in [the org map](../docs/002-the-org-map.md#maps-inside-boxes),
all the way down. The one that matters most is N5 — an inner map reaches the
world only through its box — because without it a door could be hidden one
level down, where the parent's doors rule never sees it.

`./validate-org` runs the check once the org itself reads; `./blocked-board`
runs `descend` whenever a box has an inside.

## Exports

| Function | Returns |
| --- | --- |
| `check(dir)` | problems and warnings for every box with an inside, recursively; N6 by real path |
| `check_box(box, inner_map, file, problems)` | N2–N5 for one box |
| `descend(org, rows)` | the board's rows, each source box with an inside carrying `inside = { path, top }`, where `top` is the inner board's first row (itself descended) |
| `main(args)` | the nesting check alone |

**It looks inside sources, not blocked boxes**: a blocked box is blocked by its
inputs, which the board already ranks; a source that owes something is the box
whose inside explains the delay.
