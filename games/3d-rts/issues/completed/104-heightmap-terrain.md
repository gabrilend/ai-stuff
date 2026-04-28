# 104 — Heightmap Terrain

## Status

DONE — completed 2026-04-27.

## Current behavior

There is no terrain. The 3D scene is empty.

## Intended behavior

A square heightmap renders as a 3D mesh in the scene. The heightmap is
generated procedurally (layered sine octaves) so it has visible
variation — peaks and valleys that will later block line of sight in
interesting ways. The map is sized from `MAP_SIZE_TILES` and
`TILE_SIZE_WORLD` constants. (These live in `020-terrain.c` for now;
they will move to `010-config.h` once another module needs them.)

A function `terrain_height_at(world_x, world_y)` returns the height
at any X/Y. A function `terrain_segment_blocked(a, b)` returns
whether a 3D segment dips below the terrain at any sampled point
along its length — this is the building block for issue 111.

## Suggested implementation steps

1. Create `src/020-terrain.c` / `.h` owning a 2D `float` array of
   heights.
2. Generate the heightmap with a deterministic sum of sine octaves so
   the same parameters always produce the same map.
3. Build a raylib `Mesh` from the height grid by hand. raylib's
   `GenMeshHeightmap` assumes Y-up and would put the height in the
   wrong axis — building the triangle list directly is cheap and
   produces an idiomatic Z-up mesh.
4. Bake per-vertex lighting against a fixed sun direction into the
   vertex colors. raylib's default shader is unlit, so vertex color
   is the only knob that gets to the GPU; per-vertex baking
   produces readable shading "for free."
5. Implement `terrain_height_at` with bilinear interpolation over
   the four nearest grid cells, clamping at the boundary.
6. Implement `terrain_segment_blocked` by sampling along the segment
   at a step of `TILE_SIZE_WORLD / 2`, skipping the endpoints (so
   shooter/target positions sitting on the surface don't spuriously
   block).
7. Render the mesh in the main render loop with the altitude gradient
   plus baked lighting.

## Related documents

- `docs/002-mechanics.md` — terrain rules.
- `docs/004-architecture.md` — `020-terrain.c` location.

## Notes

The terrain mesh is owned by the main thread (it is a render asset).
The heightmap *array* is read-only after generation, so both threads
can read it without locking. Make this distinction explicit in code
comments to spare future contributors a synchronization headache.

## Completion log

### What was implemented

- `src/020-terrain.{h,c}` — heightmap generation, hand-rolled
  indexed mesh, bilinear height query, segment-vs-heightmap blocked
  query. Functions wrapped in vimfolds.
- Procedural noise: three sine octaves with mild phase offsets,
  amplitudes 2.5 / 1.0 / 0.4 producing roughly ±4 unit hills.
- Per-vertex shading: a fixed sun direction `(0.4, 0.5, 0.8)` and
  Lambertian factor with 0.45 ambient floor, baked once at
  build_mesh time. Result is uniformly readable terrain with hills
  visibly self-shading.
- Altitude tint ramping from dark forest green at z = -4 to tan at
  z = +4, capped at the boundary.
- 64×64 tiles → 65×65 vertex grid, indexed mesh: 4225 vertices and
  8192 triangles using `unsigned short` indices. Memory: ~150 KB
  CPU-side, well within budget.
- `001-main.c` updated: `terrain_init()` after `camera_init()`,
  `terrain_draw()` inside `BeginMode3D`, `terrain_shutdown()` before
  `CloseWindow()` so `UnloadMesh` runs while GL is still alive. The
  placeholder grid and axis markers from issue 103 were removed —
  terrain replaces them as visual reference.

### What was tested

- Visual: user confirmed terrain renders correctly with rolling
  hills, altitude gradient, and visible sun shading.
- Camera + terrain: panning, zooming, rotating all work; the
  terrain is the visual reference replacing the prior grid.
- Build: clean compile under `-Wall -Wextra -Wpedantic` after
  removing two unused includes (stdlib.h, string.h) flagged by
  clangd.

### What was not tested

- `terrain_height_at` and `terrain_segment_blocked` were not
  exercised at runtime — issues 105 (raypick) and 111 (LoS) are
  the first real callers. The implementations have inline
  reasoning but no observable behavior in 104. A debug query for
  spot-checking was discussed and skipped because it would just
  be scaffolding that 105 immediately replaces.
- Boundary clamping on `terrain_height_at` was not poked at out-of-
  bounds inputs by hand. The clamp logic is direct but should be
  re-tested when the first caller (raypick / unit movement)
  starts hitting it.

### Lessons & caveats for later issues

- raylib's default shader is unlit. Any per-pixel lighting effect
  (dynamic lights, normal maps, etc.) requires a custom shader —
  baking into vertex colors only buys static lighting.
- The heightmap array's read-only-after-init contract is what makes
  issue 102's threading model work for terrain queries. Both the
  sim thread and main thread can read freely. Do not introduce
  *any* mutable state into `g_terrain.heights` without revisiting
  the cross-thread contract.
- The static "sun" directional light produces decent shading but
  the world feels static. A *movable* point light is captured in
  the new issue 401 (Phase 4 — rendering polish).
