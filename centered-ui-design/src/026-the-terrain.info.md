<!-- written by Claude (Opus 5.5), 2026-10-10: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 026-the-terrain

The land as a grid of points, each with a height, a facing (which way its slope points) and a colour — the data the renderer (013) draws as round sprites lit by the sun. No ground texture: "a completely empty canvas with invisible points" (issue 214). Points are spaced evenly along every ring and between rings, so longer rings far out hold more.

| Offers | Takes | Gives |
|---|---|---|
| `build(seed, fold)` | the game's seed, the fold (004) | a list of points: `r` (tier distance), `angle` (radians), `height` (ground units), `facing` {x, y, z} (unit vector), `color` {r, g, b} |
| `mesas(seed, fold)` | | the flat-topped hills: list of {x, z, radius, height, edge} (ground units) |
| `height_at(hills, x, z)` | ground x, z | the land's height there |
| `facing_at(hills, x, z)` | ground x, z | the slope's facing, a unit vector |
| `sun_direction(hour_angle)` | the dials' hour (0 noon, -pi/2 morning, pi/2 evening) | a unit vector toward the sun (Lua twin of the dot shader's sun) |
| `POINT_SPACING`, `MESA_COUNT`, `ROLL_HEIGHT`, `PAINTS` | | tuning knobs (record changes in docs/balance-updates.md) |
