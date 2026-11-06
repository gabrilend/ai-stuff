# Issue 501d: Implement Camera System

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 501
**Priority:** High
**Dependencies:** 508 (completed)
**Blocks:** 505c (camera controls), 507d (the minimap's viewport box), 502e, 506, 507, 507a
**Re-cut:** 2026-09-26, from "Implement Camera System"

---

## Current Behavior

The renderer uses a raylib 3D camera fixed at (8, 6, 8) looking at the
origin (`src/render/main.c`, around line 1299). Picking casts a ray from
the mouse through it (`src/render/input.c`). There is no camera state
beyond that: no position the game knows, no zoom, no limits from the map.

## Code review findings to fix

The code review of 2026-11-05 read the unmerged pull request #314 that build this issue. The issue text above is brought over from the branch; the code is still on the branch. Each point below is to be fixed (or answered) before the code merges and this issue is called complete. "Confirmed" means the review reproduced it by running the branch's code; the rest come from reading it. The review's overall summary is in the message of the "code review results" commit.

- When a corner ray looks past the far clip, the view quad keeps the x/y of the ray's point at the clip depth, which lies beyond the drawn ground. At distance 5000 the top edge is reported at y≈2902 where the drawn ground ends at 0, so the minimap box is about 23 tiles too far north (confirmed). The test hard-codes the same formula.
- A zero-height (or zero-width) screen makes the ray direction NaN, which passes the "looks down" check, so screen-to-ground returns success with NaN coordinates (confirmed); NaN corners then reach picking, culling and the minimap.
- Clamping limits only the target and distance; pitch and field of view have no limits, so a map script setting angle of attack 30 puts the eye under the ground, and fov 180 inverts the mapping.
- Screen-to-ground ignores the far clip while the view quad honours it, so clicks near the top can order units to ground that isn't drawn.
- Missing camera-bounds values silently become 0; missing x/y/z become 0.
- The rectangle-around-four-points loop is written twice in C and twice in the test.
- Every Lua query recomputes the frame (trig and tan) and allocates; per-unit per-frame use will churn garbage.
- The test builds into `tmp/camera` without making sure the RAM folders exist, so a fresh clone creates a real `tmp/` on disk.
- Methods inside the module have no folds; the issue gained log sections with fixed counts.

## Intended Behavior

The camera model, in C beside the renderer: where it looks (a point on the
ground), its height and pitch, WC3's default angle, zoom limits, and the
map's camera bounds read from `war3map.w3i`. It answers two questions the
rest need: which world point is under a screen point (picking, minimap
clicks), and which ground rectangle is in view (terrain culling 502e, the
minimap's viewport box 507d). The camera is renderer state: input moves it
(505c), and the game never writes it except through trigger natives that
set the camera (Phase 3's camera natives, when they are wired to the
renderer).

## Suggested Implementation Steps

1. A camera struct: target point, distance, pitch, yaw, zoom limits, bounds.
2. Screen point to ground point, and ground rectangle in view.
3. The map's bounds from `war3map.w3i` applied on load.
4. Tests: known camera, known screen points give known ground points.

## Acceptance Criteria

- [ ] The camera starts at the map's start location, at WC3's default angle
- [x] Screen-to-ground and view-rectangle answers are tested
- [ ] The camera can't leave the map's camera bounds

---

## Earlier Design (January 2026, for a Lua renderer interface)

Kept as the record; not built as written.

### Current Behavior

No camera abstraction exists. World coordinates cannot be converted to screen coordinates, and there's no way to pan or zoom the view.

---

### Intended Behavior

Camera system for viewport management:

```lua
-- src/render/camera.lua
local camera = {}

-- Camera state
camera.x = 0           -- World X position (center of view)
camera.y = 0           -- World Y position (center of view)
camera.zoom = 1.0      -- Zoom level (1.0 = normal, 2.0 = zoomed in)
camera.rotation = 0    -- Rotation in radians (optional)

-- Coordinate conversion
function camera.world_to_screen(wx, wy)
    local sx = (wx - camera.x) * camera.zoom + screen_width / 2
    local sy = (wy - camera.y) * camera.zoom + screen_height / 2
    return sx, sy
end

function camera.screen_to_world(sx, sy)
    local wx = (sx - screen_width / 2) / camera.zoom + camera.x
    local wy = (sy - screen_height / 2) / camera.zoom + camera.y
    return wx, wy
end

-- Movement
function camera.move(dx, dy) end
function camera.move_to(x, y) end
function camera.center_on(entity) end

-- Zoom
function camera.set_zoom(level) end
function camera.zoom_in(amount) end
function camera.zoom_out(amount) end

-- Bounds
function camera.set_bounds(min_x, min_y, max_x, max_y) end
function camera.clamp_to_bounds() end

-- Smooth movement
function camera.lerp_to(x, y, speed) end
function camera.update(dt) end  -- Process smooth movement
```

**Zoom Levels:**
```lua
ZOOM_MIN = 0.25    -- Very far out (strategic view)
ZOOM_MAX = 4.0     -- Very close (detail view)
ZOOM_DEFAULT = 1.0 -- Normal gameplay
```

---

### Suggested Implementation Steps

1. **Create camera module**
   ```lua
   -- src/render/camera.lua
   local camera = {
       x = 0, y = 0,
       zoom = 1.0,
       target_x = nil, target_y = nil,  -- For smooth movement
       bounds = nil,
   }
   ```

2. **Implement coordinate conversion**
   - world_to_screen(wx, wy) → sx, sy
   - screen_to_world(sx, sy) → wx, wy
   - Handle zoom in conversion math

3. **Implement movement functions**
   - move(dx, dy) - relative movement
   - move_to(x, y) - absolute positioning
   - center_on(entity) - follow entity

4. **Implement zoom**
   - set_zoom(level) with clamping
   - Zoom toward mouse cursor (optional)
   - Smooth zoom transitions

5. **Implement bounds**
   - set_bounds() defines map edges
   - clamp_to_bounds() enforces limits
   - Handle zoom affecting visible area

6. **Implement smooth movement**
   - lerp_to() sets target
   - update(dt) interpolates position
   - Configurable lerp speed

7. **Add viewport queries**
   - get_visible_bounds() → min_x, min_y, max_x, max_y
   - is_visible(x, y, w, h) → boolean
   - For culling optimization

---

### Acceptance Criteria

- world_to_screen() correctly converts coordinates
- screen_to_world() is inverse of world_to_screen()
- Zoom affects coordinate conversion correctly
- Camera respects bounds when set
- Smooth movement interpolates properly
- get_visible_bounds() returns correct world rectangle
- Unit tests for coordinate math

---

### Notes

The camera is central to the player experience. Edge panning, smooth following, and proper bounds make the game feel polished.

**WC3 camera behavior to match:**
- Edge panning when mouse at screen edge
- Minimap click centers camera
- Arrow keys pan
- Mouse wheel zooms
- Camera snaps to hero on F1

---

### Related Documents

- issues/501a-define-renderer-interface.md (renderer uses camera)
- issues/505c-game-view-camera.md (integrates camera with input)
- issues/507d-camera-viewport.md (minimap shows camera position)

---

## Decisions (2026-11-06)

Made without the owner, each one theirs to overturn.

1. **The camera's math is built and tested; wiring it into the window is
   left.** `src/render/camera.c` (with `camera.h`) needs neither raylib
   nor Lua. Placing the window's raylib camera from it, and reading the
   map's bounds on load, change `scene_viewer.c`, which needs raylib to
   build and check; the owner said "not now" to raylib, so that is the
   follow-up below. Two of the three acceptance boxes wait on it.
2. **The window to wire is `scene_viewer.c`, not `main.c`.** The issue
   names `main.c`'s fixed camera at (8, 6, 8), but the maps are played in
   `scene_viewer.c` (517, 518), which since then has had a WC3-style
   camera of its own (`ViewCamera`: target, distance, rotation, pitch,
   fov) and pans and zooms. The newer code is followed: the camera model
   keeps its numbers and its WC3 defaults, in WC3's units and axes
   (x east, y north, z up) instead of the window's render units.
3. **WC3's default camera is Blizzard.j's**: distance 1650, angle of
   attack 304 (56 degrees down), rotation 90, field of view 70, far clip
   5000. The zoom limits 250 to 9000 are the window's stand-ins, kept
   until 516d measures WC3's. The 70 is taken as the vertical angle, as
   the window takes it; 516d is to settle that too.
4. **The camera bounds are the rectangle around the four corners**
   `war3map.w3i` stores (eight floats: lower left, upper right, upper left,
   lower right, as `src/editor/new_map.lua` writes them). WC3 stores four
   corners, but every map seen has them as a rectangle. The bounds hold
   the camera's target, as WC3's `SetCameraBounds` does, not the edges of
   the view.
5. **The ground is taken as level** at a height the caller gives (the
   ground under the target, by default), as the window's `to_ground`
   does. Picking on hills, against the height field, is for 502's
   terrain.
6. **The view's ground corners never go missing.** A corner whose ray
   looks past the far clip (5000 along the view), or above the horizon,
   is taken where it crosses the far clip, and the count of corners that
   reached the ground is returned. The window's minimap box now drops
   the box when any corner misses the ground (`hud.lua`); 507d can draw
   it always.
7. **Lua reaches it through LuaJIT's FFI** (`src/render/camera.lua`), as
   `render.null` reaches the headless renderer (501c, open PR #307), so
   the interface's tests and scenes can ask the same camera headless.

## What happened

- `src/render/camera.h`, `camera.c`, `camera.lua`, with info pages.
- `src/tests/test_camera.lua` (46 checks): the ground points under known
  screen points against ones worked out from the angles alone; there and
  back within 0.01 pixel; the view's trapezoid and its rectangle, at every
  turn; the far clip; the bounds; `camera.c` built alone as strict C99.
- Mutation check of `camera.c`: 179 mutants, 151 caught. The 28 left
  are equivalent: `<` for `<=` where a value clamped at its edge is the
  same either way (14); the small tolerances near zero (9); a "no hit"
  marker of -2 for -1 (1); loops one past their arrays (2, undefined but
  unseen); and the screen's right, whose height is always 0, left unset or
  subtracted (2).

## Follow-up (needs raylib, not built)

- `scene_viewer.c`: keep a `GameCamera` in place of `ViewCamera`, place
  the raylib camera from `camera_frame` (eye, forward, up; WC3's z up is
  the window's y, WC3's y the window's -z, 128 units a tile), and answer
  `viewer.to_ground` and `viewer.to_screen` from
  `camera_screen_to_ground` and `camera_world_to_screen`.
- `src/demo/wc3map/main.lua`: hand the window `map.camera_bounds` from
  `war3map.w3i` with `CAMERA_START`, for `camera_bounds_from_w3i`; the
  camera already starts at the player's start location there.
