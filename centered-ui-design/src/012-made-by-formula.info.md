<!-- written by Claude (Opus 5.5), 2026-10-10, for the first renderer slice: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 012-made-by-formula

Every picture is drawn by code; none is AI-generated.

| Offers | Gives |
|---|---|
| `unit_skin(width, height)` | image data: red = metal brightness (panels, seams, rivets, grain), green = where the owner's color shows (a band) |
| `light_at(material, x, y)` | a light dial's colour at a point (metal, glaze, earth): noon at the top, night at the bottom, brighter at the rim |
| `light_dial(size, material)` | the dial painted from light_at, as image data |
| `flat_map(size, tiers, seat_colors, sections)` | a canvas: quadrant tints, angle grid, equally spaced tier rings, quadrant lines, the color-coded sections |

`dial_light(material, facing_x, facing_y, hour_angle, window_center, window_radius)`: the light a surface facing that way receives from the material's dial at that hour, without a picture — the Lua twin of the world shaders' dial lookup (used for the console's metal). Returns r, g, b.

`round_relief(size)`: the one round picture every terrain point is drawn with — which way each pixel of a small dome faces (red across, green up, blue out) and whether it is inside the circle (alpha). Lit by a sun, one side comes out bright, the other dark. Returns image data.
