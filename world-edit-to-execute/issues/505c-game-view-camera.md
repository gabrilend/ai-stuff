# Issue 505c: Game View Camera

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 505
**Priority:** High
**Dependencies:** 501d (the camera model)
**Blocks:** 507e
**Re-cut:** 2026-09-26, from "Game View Camera"

---

## Current Behavior

The camera doesn't move (`src/render/main.c`, fixed at (8, 6, 8)). The
vertical slice left panning and zoom out (508d).

## Intended Behavior

WC3's camera controls on 501d's camera: the view pans when the mouse is at
a screen edge and with the arrow keys; the wheel zooms within limits; a key
returns to the selected unit; clicking the minimap moves the view (507e).
Speeds as WC3's defaults.

## Suggested Implementation Steps

1. Edge and arrow-key panning.
2. Wheel zoom.
3. Jump to the selected unit.

## Acceptance Criteria

- [ ] Edge panning and arrow keys move the view within the map's bounds
- [ ] The wheel zooms within limits
- [x] A key centres the view on the selection

---

## Earlier Design (January 2026, for a Lua renderer interface)

Kept as the record; not built as written.

### Current Behavior

Camera exists (501d) but is not connected to input controls. No way for player to navigate the map.

---

### Intended Behavior

Integrate camera with input for map navigation:

```lua
-- src/render/game_view.lua
local game_view = {}
local camera = require("render.camera")

-- Edge panning
local EDGE_PAN_MARGIN = 20  -- pixels from screen edge
local EDGE_PAN_SPEED = 500  -- world units per second

function game_view.update(dt)
    -- Edge panning
    local mx, my = get_mouse_position()
    local dx, dy = 0, 0

    if mx < EDGE_PAN_MARGIN then dx = -EDGE_PAN_SPEED * dt end
    if mx > screen_width - EDGE_PAN_MARGIN then dx = EDGE_PAN_SPEED * dt end
    if my < EDGE_PAN_MARGIN then dy = -EDGE_PAN_SPEED * dt end
    if my > screen_height - EDGE_PAN_MARGIN then dy = EDGE_PAN_SPEED * dt end

    camera.move(dx, dy)

    -- Keyboard panning (arrows)
    if is_key_down("left") then camera.move(-EDGE_PAN_SPEED * dt, 0) end
    if is_key_down("right") then camera.move(EDGE_PAN_SPEED * dt, 0) end
    if is_key_down("up") then camera.move(0, -EDGE_PAN_SPEED * dt) end
    if is_key_down("down") then camera.move(0, EDGE_PAN_SPEED * dt) end

    -- Update camera smooth movement
    camera.update(dt)
end

-- Mouse wheel zoom
function game_view.on_wheel(delta)
    if delta > 0 then
        camera.zoom_in(0.1)
    else
        camera.zoom_out(0.1)
    end
end
```

---

### Suggested Implementation Steps

1. **Implement edge panning**
   - Detect mouse near screen edges
   - Move camera proportionally
   - Configurable speed and margin

2. **Implement keyboard panning**
   - Arrow keys for direction
   - Configurable speed
   - Optional: WASD alternative

3. **Implement mouse wheel zoom**
   - Scroll up = zoom in
   - Scroll down = zoom out
   - Zoom toward cursor position

4. **Add camera hotkeys**
   - Home = center on start
   - F1-F4 = jump to hero
   - Space = jump to last event

5. **Integrate with minimap**
   - Click minimap = move camera
   - Camera position shown on minimap

6. **Set up camera bounds**
   - Limit to map edges
   - No scrolling past terrain

---

### Acceptance Criteria

- Edge panning works
- Arrow keys pan camera
- Mouse wheel zooms
- Camera respects map bounds
- Smooth camera movement
- Zoom toward cursor position

---

### Notes

Camera controls must feel responsive and predictable. Sluggish or erratic camera is frustrating.

**WC3 camera behavior:**
- Very responsive edge panning
- Discrete zoom levels (5-6 levels)
- Camera locked to map bounds
- Double-tap arrow = fast pan

---

### Related Documents

- issues/501d-implement-camera-system.md (camera logic)
- issues/505b-wire-render-systems.md (camera used here)
- issues/507-create-minimap-renderer.md (minimap interaction)

---

## Decisions (2026-11-06)

Made without the owner, each one theirs to overturn.

1. **The controls are built on 501d's camera as plain C**
   (`src/render/camera_input.c`, with `camera_input.h`): one frame of
   input (arrow keys, whether the screen's edges scroll, the mouse, the
   screen's size, wheel notches) moves the camera and clamps it. The
   window already pans and zooms its own `ViewCamera` the same way
   (`scene_viewer.c`, since 517) but never against the map's bounds;
   moving it onto `camera_step` needs raylib to build and check, so it
   waits with 501d's wiring. The first two boxes wait on it.
2. **The speeds are the window's stand-ins**, kept until 516d measures
   WC3's: 1400 units a second at the default distance and in proportion
   to the distance; 150 units of distance a wheel notch; the outer 3
   pixels of the screen scroll. Diagonals add both ways, as the window
   does (faster than one way, as in WC3).
3. **Panning follows the view's heading**: up the screen is the way the
   camera looks. The window pans by the map's north, which is the same at
   WC3's default rotation (90); once a trigger turns the camera, the
   keys still match the screen.
4. **The keys that bring the view to the selection are the interface's,
   already built (518b), and now tested**: a hero's F1-F3 twice, a
   control group's number twice within half a second, and F8 for the
   next idle worker. WC3 has no single "centre on selection" key; those
   are its ways. The minimap's click and drag (507e) also move the view.
5. **No glide**: a frame's pan is applied at once, as the window does.
   The camera natives' glides (904) stay in `wc3map/main.lua`.
6. **Based on 501d's branch, not on the headless renderer (#307)**: the
   controls use the camera model and nothing that draws.

## What happened

- `src/render/camera_input.h`, `camera_input.c`, with an info page;
  `src/render/camera.lua` builds it in and offers `cam:step(input, dt)`.
- `src/tests/test_camera_controls.lua` (37 checks): keys, edges, wheel,
  bounds and the interface's keys on a fake game.
- Mutation check of `camera_input.c`: 26 mutants, 26 caught.

## Follow-up (needs raylib, not built)

- `scene_viewer.c`: fill a `CameraInput` from `IsKeyDown`,
  `GetMousePosition` and `GetMouseWheelMove` (edges on when the scene has
  an interface and the window is focused, as now) and call
  `camera_step` in place of its own pan and zoom.
