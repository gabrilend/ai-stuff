# Issue 501d: Implement Camera System

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 501
**Priority:** High
**Dependencies:** 501a

---

## Current Behavior

No camera abstraction exists. World coordinates cannot be converted to screen coordinates, and there's no way to pan or zoom the view.

---

## Intended Behavior

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

## Suggested Implementation Steps

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

## Acceptance Criteria

- [ ] world_to_screen() correctly converts coordinates
- [ ] screen_to_world() is inverse of world_to_screen()
- [ ] Zoom affects coordinate conversion correctly
- [ ] Camera respects bounds when set
- [ ] Smooth movement interpolates properly
- [ ] get_visible_bounds() returns correct world rectangle
- [ ] Unit tests for coordinate math

---

## Notes

The camera is central to the player experience. Edge panning, smooth following, and proper bounds make the game feel polished.

**WC3 camera behavior to match:**
- Edge panning when mouse at screen edge
- Minimap click centers camera
- Arrow keys pan
- Mouse wheel zooms
- Camera snaps to hero on F1

---

## Related Documents

- issues/501a-define-renderer-interface.md (renderer uses camera)
- issues/505c-game-view-camera.md (integrates camera with input)
- issues/507d-camera-viewport.md (minimap shows camera position)
