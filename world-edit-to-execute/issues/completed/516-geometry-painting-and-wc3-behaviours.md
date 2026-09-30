# Issue 516: Geometry Painting and WC3-Style Behaviours (the Fort)

**Phase:** 5
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 508c (Lua bridge), 508d (terrain), 404 (movement)

---

## Current Behavior

Lua can place entities (one of four fixed meshes per slot) and colour
terrain tiles, but can't draw anything else: no walls, ramps, buildings or
figures. Units have a movement system (404), but it treats the turn rate
field as radians per second (0.6: over five seconds to turn about) and
moves a unit toward its waypoint whichever way it faces. Nothing lets a
unit stand on anything above the ground.

## Intended Behavior

A toolbox for painting geometry from Lua and scripting units that move
the way WC3 units do, shown by a scene: a fort on a blue square, manned by
orange bowmen who walk in through a fortified gate, climb a ramp, spread
along the walkways and up into a belltower, and shoot at dummies outside.

The work is in five parts, labelled in the code:

| Part | What | Where |
|------|------|-------|
| 516a | Geometry painting in C: boxes, wedges, quads; static and per-frame layers; Lua `render.geo_*` | `src/render/geometry.{c,h}`, `bridge.c` |
| 516b | Geometry kit (walls with battlements, towers, belltower, gatehouse, ramps, stairs, standing surfaces) and figures (bowman, dummy, arrow, range ring) | `src/geometry/kit.lua`, `figures.lua` |
| 516c | WC3 locomotion (constant speed, turn rate, propulsion window, surfaces underfoot) and behaviours (walk graph, garrison with the attack cycle, patrol, arrows) | `src/runtime/locomotion.lua`, `behaviors.lua` |
| 516d | Measuring the stand-in numbers on a real install | `issues/516d-measure-wc3-movement-and-camera.md` (open) |
| 516e | The fort scene and its demo program | `src/demo/fort/`, `src/render/fort_demo.c`, `run-fort` |

## Acceptance Criteria

- [x] Lua paints boxes, wedges and quads, kept (static) or per frame (dynamic)
- [x] Structures are data with standing surfaces, testable without a window
- [x] A unit turns in place until its goal is within its propulsion
      window, then walks along its facing at constant speed
- [x] A unit follows ramps and stairs but can't step up onto a wall, and
      walks under the gate bridge rather than onto it
- [x] Bowmen turn to face a target before loosing; one attack per cooldown
- [x] All 25 posts manned in the demo, at the right heights; arrows hit
- [x] `src/tests/test_fort_scene.lua`: 46 tests pass; the full suite passes

## Implementation Notes

**Date:** 2026-09-29

### 516a: geometry painting

`render.geo_box(x, y, z, sx, sy, sz, yaw, r, g, b [, dynamic])`,
`geo_wedge` (same arguments; rises along its length) and `geo_quad` (four
corners and a colour) add primitives, in render space, placed by the centre
of their base. Faces are shaded by how squarely they meet a fixed light and
drawn from both sides. The static layer stays until `geo_clear(false)`;
the dynamic layer is emptied every time `geometry_draw()` draws it. Both
demos draw it.

Found on the way: raylib batches triangles, so switching back-face
culling off and on around the draw calls did nothing until the batch is
flushed on both sides; without that, half of every box's faces were
dropped (walls looked hollow, the plinth's top vanished).

`terrain_draw_region()` draws the tiles within a radius of the camera, so
the fort demo draws the map's ground at 42-60 FPS under software GL
(the whole 481x481 map as cubes is 231,000 draws a frame).

### 516b: kit and figures

Everything is in WC3 units (128 to a tile). A `kit.new()` world collects
primitives and surfaces; `height_at(x, y, z_now)` gives the highest surface
a unit can reach, at most `MAX_STEP` (48) above its feet. That one rule is
what keeps a bowman beside a wall rather than on it, and under the gate's
bridge rather than on top of it.

**Mirror.** WC3 (x, y, up) to raylib (x, up, z) as `y -> z` swaps two
axes, which reflects the world. The kit places north at render -z
(`kit.to_render`). `map_renderer.load_terrain(map, north_up)` gains an
option to lay the terrain the same way; the threaded demo keeps the old,
mirrored layout until someone decides to change it.

### 516c: locomotion and behaviours

- Speed is constant (no acceleration); the tests check each tick moves
  exactly speed * dt.
- A unit turns at `turn_rate * TURN_SCALE` radians per second and walks
  only while its goal is within the propulsion window of its facing,
  walking *along its facing* (so it arcs). TURN_SCALE is a stand-in (10).
- Garrison: march by route; hold, facing out; acquire the nearest target
  in acquisition range; turn to within `face_tolerance`; draw
  (attack point); loose; recover (backswing). The cooldown runs from the
  start of one attack to the start of the next, so shots come exactly
  `cooldown` apart (the first version started it at release, giving
  cooldown + windup; the test caught it).
- Arrows home on the target and arc by the missile arc.

The movement system from 404 (`runtime/systems/movement.lua`) still has
the radians-per-second turn rate and moves regardless of facing; it
could adopt `runtime/locomotion.lua` once 516d settles the numbers.

### 516e: the fort

`src/render/run-fort` builds and runs it from any checkout (raylib from
`RAYLIB_PATH`). Arrows/WASD pan, wheel zooms, 1 sets WC3's default
camera distance (1650), R cycles range rings: one bowman's attack (500)
and acquisition (600) ranges, then every bowman's attack range. The camera
uses WC3's default angle of attack (304 degrees) and distance.
`FORT_SHOTS`, `FORT_QUIT_AT` and `FORT_CAMERA` run it unattended; that is
how it was checked here (Xvfb, software GL, screenshots at 3, 10, 22, 28 s):
the column files through the gate and up the ramp, all 25 posts are manned
by about 20 s, and the bowmen turn, draw and shoot at the passing dummies.

---

## Note (2026-09-29, issue 517)

`src/render/fort_demo.c` is now `src/render/scene_viewer.c`, which runs any
scene script; `run-fort` still runs the fort. Its entry points are
`scene_tick/paint/status/key` (were `fort_*`) and the unattended-run
variables are `SCENE_SHOTS`, `SCENE_SHOT_DIR`, `SCENE_QUIT_AT`,
`SCENE_CAMERA` (were `FORT_*`). With the terrain parser fixed in 517a, the
fort's default ground (the centre of the DAoW 5.4b map) reads as open sea.
