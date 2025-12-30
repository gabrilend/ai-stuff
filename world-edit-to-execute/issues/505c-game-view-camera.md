# Issue 505c: Game View Camera

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 505
**Priority:** High
**Dependencies:** 505b, 501d

---

## Current Behavior

Camera exists (501d) but is not connected to input controls. No way for player to navigate the map.

---

## Intended Behavior

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

## Suggested Implementation Steps

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

## Acceptance Criteria

- [ ] Edge panning works
- [ ] Arrow keys pan camera
- [ ] Mouse wheel zooms
- [ ] Camera respects map bounds
- [ ] Smooth camera movement
- [ ] Zoom toward cursor position

---

## Notes

Camera controls must feel responsive and predictable. Sluggish or erratic camera is frustrating.

**WC3 camera behavior:**
- Very responsive edge panning
- Discrete zoom levels (5-6 levels)
- Camera locked to map bounds
- Double-tap arrow = fast pan

---

## Related Documents

- issues/501d-implement-camera-system.md (camera logic)
- issues/505b-wire-render-systems.md (camera used here)
- issues/507-create-minimap-renderer.md (minimap interaction)
