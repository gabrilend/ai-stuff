<!-- made by scripts/build-info-pages from the comments in 005-battlefield.lua; change the comments and rebuild, not this page -->
# 005-battlefield


The grid a battle is fought on. Positions are continuous, but a soldier
holds exactly one cell (the one its centre is in), and the occupancy array
is what "moving into an occupied space" is judged against.

Cells are numbered from 0; the occupancy array is allocated once at
creation and never grows. An empty slot holds false rather than nil so the
array has no holes.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.new` | `width, height` | (no comment in the source) |
| `M.cell_of` | `x, y` | (no comment in the source) |
| `M.inside` | `field, cx, cy` | (no comment in the source) |
| `M.holder` | `field, cx, cy` | Who holds the cell, or false. Outside the field counts as held by the edge, which is returned as the string "edge" so a caller cannot mistake it for a soldier or for an empty cell. |
| `M.claim` | `field, cx, cy, soldier` | Takes an empty cell. Claiming a held cell is a bug in the caller, so it stops the program rather than quietly stacking two bodies in one place. |
| `M.release` | `field, soldier` | (no comment in the source) |
| `M.swap` | `field, a, b` | Two soldiers trade cells: the ally-yield rule. |
| `M.near` | `field, x, y, radius, out` | The soldiers within radius of a point, appended to `out` in cell order (so the result is the same on every run). The cost depends on the radius, not on how many soldiers there are. |

## Tables of rows

| Name | What it is |
| --- | --- |
| `COMPASS` | (no comment in the source) |
| `COMPASS_ORDER` | (no comment in the source) |
