# see-in-3d — the paintbrush

Every word a scene file may use, and what it means. This is the contract;
`libs/see-in-3d-paintbrush.lua` refuses anything not written here.

A scene file is plain Lua with nothing in it but these words. One `scene{}`,
then any number of shapes. Units are free (call them metres); +y is up, +z
comes toward the front camera, +x goes to its right.

```lua
scene{ what = "a desk with a lamp and a mug" }
box      { name = "desk", at = {0, 0.75, 0}, size = {1.6, 0.05, 0.8}, color = "#8a6a4a" }
cylinder { name = "lamp post", at = {0.6, 1.0, -0.2}, radius = 0.02, height = 0.5, color = "#333333" }
cone     { name = "shade", at = {0.6, 1.3, -0.2}, radius = 0.15, height = 0.15, turn = {180, 0, 0}, color = "#e0c060" }
sphere   { name = "bulb", at = {0.6, 1.22, -0.2}, radius = 0.04, color = "#fff6c0", glow = true }
cylinder { name = "mug", at = {-0.4, 0.83, 0.1}, radius = 0.05, height = 0.11, color = "#3a6ea5" }
box      { name = "left legs", at = {-0.75, 0.36, 0}, size = {0.05, 0.72, 0.7}, color = "#6b5038" }
box      { name = "right legs", at = {0.75, 0.36, 0}, size = {0.05, 0.72, 0.7}, color = "#6b5038" }
```

## Words

| Word | Fields | Means |
|---|---|---|
| `scene{}` | `what` (text, required) | one line saying what the scene shows; printed on the sheet's report. Exactly one per file. |
| `box{}` | `size = {w, h, d}` (three numbers > 0, required) | a box, centred on `at` |
| `sphere{}` | `radius` (number > 0, required) | a ball, centred on `at` |
| `cylinder{}` | `radius`, `height` (numbers > 0, required) | an upright tube, centred on `at` |
| `cone{}` | `radius`, `height` (numbers > 0, required) | a cone, base below and point above `at`'s centre line, centred on `at` |

Every shape also takes:

| Field | Type | Default (when left out) |
|---|---|---|
| `name` | text | none; names appear in error messages and the `.obj` file |
| `at` | `{x, y, z}` numbers | `{0, 0, 0}` |
| `turn` | `{x, y, z}` degrees, applied x then y then z | `{0, 0, 0}` |
| `color` | `"#rrggbb"` | `"#b0b0b0"` (light grey) |
| `glow` | `true` or `false`: gives off its own light (a lit screen, a bulb), so it shows its colour unshaded | `false` |

Those four defaults are the only ones. Any other missing field, any unknown
word or field, any wrong type is an error, reported with the shape's number
and name, the field, and the nearest legal word.

## What render makes

From `scene.lua`: `scene.png` (a 2×2 sheet: FRONT top-left, RIGHT top-right,
TOP bottom-left, ANGLE bottom-right), `scene-front.png`, `scene-right.png`,
`scene-top.png`, `scene-angle.png`, and `scene.obj`. Every camera looks at the
centre of everything drawn, from far enough to fit it all. A chequered floor lies
at height 0 (or under the lowest point, if something goes below 0), so height
and position read: a shape left floating shows its gap.
