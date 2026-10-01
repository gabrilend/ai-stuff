# Issue 517: WC3 Maps Drawn With Geometry Designs

**Phase:** 5
**Type:** Implementation
**Priority:** High
**Dependencies:** 516 (geometry painting), 103/110 (w3e), 206+ (doodads, object data)

---

## Current Behavior

The renderer draws a map's terrain as flat coloured squares and nothing
else from it: no heights, cliffs or water, no doodads beyond slot limits,
no units (the test maps have no war3mapUnits.doo). The terrain parser read
two bytes of every tilepoint with their nibbles swapped, so every cliff
layer, cliff texture, ground texture and flag the project had read was
wrong (found while building this; see 517a).

## Intended Behavior

Load a real WC3 map and show it: the ground as it rises and falls, cliffs,
water, every doodad and every unit and building the map places, each drawn
with a box-built design in the style of the fort's bowmen.

| Part | What | Where |
|------|------|-------|
| 517a | Terrain parser fix: byte 4 is texture (low) + flags (high), byte 6 is layer (low) + cliff texture (high); `w3e.ground_z`, `water_z`, `is_wet` | `src/parsers/w3e.lua`, `docs/formats/w3e-terrain.md`, `test_w3e.lua` |
| 517b | Landscape (flat-shaded heightmap with cliff rock and water by depth) and baking static geometry into chunk meshes | `src/render/landscape.{c,h}`, `geometry.c` |
| 517c | Designs: trees (by tileset), rocks, plants, props, walls; buildings by race and size in team colour; eleven unit archetypes; heroes | `src/geometry/designs.lua` |
| 517d | Classifying map objects; reading the units the map's script places; the map scene | `src/demo/wc3map/classify.lua`, `scene.lua` |
| 517e | The fort demo becomes a scene viewer; `run-map` | `src/render/scene_viewer.c`, `run-map`, `src/demo/wc3map/main.lua` |

## Acceptance Criteria

- [x] Tilepoint fields read the right way round, with a test that fails on the old reading
- [x] Ground, cliffs and water drawn from the map's heights
- [x] Every doodad drawn (blockers skipped) and every script-placed unit drawn in its owner's colour
- [x] Each object's design chosen from the best evidence, and how it was chosen counted
- [x] `test_wc3map_scene.lua`: 38 tests pass; the full suite (106 files) passes
- [x] DAoW 5.4b and Daow4.4 load and draw (checked by screenshot under Xvfb)

## Implementation Notes

**Date:** 2026-09-29

### 517a: the parser bug

Read the old way, DAoW 5.4b's "layer heights" were only ever 0, 1 or 15
and its "cliff textures" ran up to 14 against two cliff tilesets. Read the
other way, the heights draw a coherent Azeroth, and on Daow4.4 the water
flag (0x40 of the high nibble) agrees with "water surface above ground" on
21,965 of 22,264 wet tilepoints. Ramps fall from 73,299 (a third of the
map, nonsense) to 111. The 89.6 drop between stored water level and the
surface comes from map tools' notes; with it the water meets the
coastlines. The pathing grid (`runtime/pathfinding/grid.lua`) reads the
same fields and so now gets real cliff levels. `test_w3e.lua` gained
`test_field_meanings`, which fails on the old reading ("cliff texture 5 of
2").

Some maps set the water flag far past their water (DAoW 5.4b: 225k flagged,
120k actually under water), so water shows only where the flag is set and
the surface is above the ground.

### 517b: landscape and baking

`render.land_build` takes packed arrays (LuaJIT FFI strings: float heights,
float water levels, RGB per cell) and builds 32x32-cell chunks of
unindexed triangles with baked colours; triangles rising more than 80 units
across a cell are cliff rock; water is shaded by depth. `render.geo_bake`
moves the static geometry layer into chunk meshes (16 tiles a side) so a
map's ~73,000 primitives draw only near the camera. The static layer now
grows as needed (up to 400,000).

DAoW 5.4b: 225 land chunks, 73,281 primitives in 621 chunks, built in about
3 s; 8-11 FPS under software GL in this container at a 2200-6500 camera.

### 517c-d: designs and classification

Units come from the map script: each `CreateUnit(p, 'id', x, y, facing)`
with a literal position, owner from the last `set p=Player(n)` or
`local player p=Player(n)` (hex `$C` and the neutral constants included).
DAoW 5.4b: 4,378 units and buildings for 14 owners; 13,561 doodads, 711
blockers skipped.

How each object's design was chosen, strongest first: model path, name
(whole words, colour codes stripped), parent, a stock-id table, naming
convention. **The stock-id table is written from memory of the game**; the
real stock tables are on the owner's install. On DAoW 5.4b, 866 of 4,378
units (20%) are still guesses (mostly neutral creep types, drawn as foot
soldiers in their owner's colour); the HUD shows the count.

Sculpted doodads: this map builds round towers from dozens of stone wall
pieces scaled to 0.4 x 0.4 x 3.3 and turned about a point. The wall design
is therefore a plain capped slab; battlements on every piece turned each
pillar into a staircase.

### 517e: viewer

`src/render/scene_viewer.c` (was `fort_demo.c`) runs any scene script:
`run-fort` for the fort, `run-map [MAP]` for a map. Scene scripts define
`scene_tick/paint/status/key`, optionally `scene_ground` (the camera
follows the ground) and `CAMERA_START`. Unattended runs use `SCENE_SHOTS`,
`SCENE_SHOT_DIR`, `SCENE_QUIT_AT`, `SCENE_CAMERA` (were `FORT_*`).

### Still open

- Units placed by triggers after the map starts are not shown; only the
  script's literal placements are read.
- Ground colours are keyword guesses from tileset names, not the textures.
- The stock-id table should give way to the owner's game data where present.
- The fort's ground (the DAoW map's centre) is now correctly the Great Sea.
