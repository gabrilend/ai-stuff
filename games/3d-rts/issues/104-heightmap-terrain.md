# 104 — Heightmap Terrain

## Status

TODO

## Current behavior

There is no terrain. The 3D scene is empty.

## Intended behavior

A square heightmap renders as a 3D mesh in the scene. The heightmap is
generated procedurally (e.g. layered sine waves or simple value noise)
so it has visible variation — peaks and valleys that will later block
line of sight in interesting ways. The map is sized from
`MAP_SIZE_TILES` and `TILE_SIZE_WORLD` constants in `src/010-config.h`.

A function `terrain_height_at(world_x, world_y)` returns the height at
any X/Y. A function `terrain_segment_blocked(a, b)` returns whether a
3D segment dips below the terrain at any sampled point along its
length — this is the building block for issue 111.

## Suggested implementation steps

1. Create `src/020-terrain.c` / `.h` owning a 2D `float` array of
   heights.
2. Generate the heightmap with a simple deterministic noise so the same
   seed produces the same map. Seed from a config constant.
3. Build a raylib `Mesh` from the height grid (raylib has heightmap
   helpers — use `GenMeshHeightmap` if it fits, otherwise build the
   triangle list directly).
4. Implement `terrain_height_at` with bilinear interpolation over the
   four nearest grid cells, clamping at the boundary.
5. Implement `terrain_segment_blocked` by sampling along the segment at
   a step derived from `TILE_SIZE_WORLD / 2` and comparing each sample's
   Z to `terrain_height_at(x, y)`.
6. Render the mesh in the main render loop with a flat color or simple
   gradient by altitude.

## Related documents

- `docs/002-mechanics.md` — terrain rules.
- `docs/004-architecture.md` — `020-terrain.c` location.

## Notes

The terrain mesh is owned by the main thread (it is a render asset).
The heightmap *array* is read-only after generation, so both threads
can read it without locking. Make this distinction explicit in code
comments to spare future contributors a synchronization headache.
