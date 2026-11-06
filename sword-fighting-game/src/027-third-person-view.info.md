<!-- made by scripts/build-info-pages from the comments in 027-third-person-view.lua; change the comments and rebuild, not this page -->
# 027-third-person-view


The commander's seat: a raised camera behind the player's contingent,
looking down at the field, slid with the movement keys and zoomed with the
wheel. Every figure is drawn at the same detail as in the front rank.

Drawn in the world itself, not as interface: the push direction as a clay
arrow on the ground ahead, the ring where the next volley's fixed arc will
land, darts in flight, raised shields, and a pennant over the player's own
soldier so the commander can find themself before dropping in.

## Functions other files call

| Name | Takes | What it does |
| --- | --- | --- |
| `M.camera` | `battle, view, w, h` | view.slide_x, view.slide_z: how far the commander has slid the camera, in metres; view.zoom: the distance multiplier. |
| `M.marks` | `battle, parts, show_arrow` | The arrow, the landing ring and the shield wall. |
| `M.raised_shield` | `parts, s, cell, color` | A shield disc held upright a little in front of a soldier. |
| `M.draw` | `battle, view, w, h, show_arrow` | (no comment in the source) |

## Tables of rows

| Name | What it is |
| --- | --- |
| `RING` | (no comment in the source) |
| `ARROW` | (no comment in the source) |

## Private helpers

| Name | Takes | What it does |
| --- | --- | --- |
| `centre` | `battle, team` | The middle of a team's standing soldiers, in cells. |
| `front` | `battle, team` | The middle of a team's front: the mean of its battalion origins. |
| `flat` | `parts, shape, x, y, z, sx, sy, sz, color, turn` | (no comment in the source) |
