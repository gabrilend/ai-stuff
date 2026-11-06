<!-- written by Claude (Opus 5.5), 2026-10-10, for issue 010 (tolerance records on the model): what this file offers to other files. Read this instead of the source unless chasing a bug. -->
# 026-finding-joints

Which parts of a model touch or nearly touch, from each part's corners measured to the other part's nearest triangles (through a grid of cubes, so only nearby triangles are tried).

| Offers | Takes | Gives |
|---|---|---|
| `find(shape, contact_distance)` | a finished shape record; distance in model units | list of { a, b (part names), gap, contact_point {x,y,z}, normal {x,y,z} (a toward b), reach_a, reach_b (extents along the normal), contact_size } |
| `closest_on_triangle(p, a, b, c)` | four {x,y,z} | the triangle's point nearest p |
