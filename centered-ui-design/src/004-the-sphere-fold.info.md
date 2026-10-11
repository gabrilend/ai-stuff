<!-- written by Claude (Opus 5.5), 2026-10-10, for the first renderer slice: what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 004-the-sphere-fold

The sphere's tiers folded into a circle: inner tiers wide, outer tiers squeezed toward the edge.

| Offers | Takes | Gives |
|---|---|---|
| `radius(fold, r)` / `tier_distance(fold, radius)` | tier distance / ground radius | the other; exact inverses |
| `slope(fold, r)` | tier distance | ground units per tier there |
| `size_scale(fold, r)` | tier distance | how much things there are shrunk (1 at tier 1); always 1 when `fold.size_keep` is 1 (the slant view's size law) |
| `ground_position(fold, r, angle)` | place | world x, z |
| `from_settings(settings)` | | fold: strength, tiers_shown, hub_radius, edge_radius (numbers) |
| `GLSL`, `send(fold, shader)` | | shader twins: fold_radius, fold_size_scale, fold_ground_position; sends `fold_size_keep` to the shaders that size things |
