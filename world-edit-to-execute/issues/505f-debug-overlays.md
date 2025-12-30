# Issue 505f: Debug Overlays

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 505
**Priority:** Low
**Dependencies:** 505b

---

## Current Behavior

No debug visualization. Developers cannot see pathfinding grids, collision shapes, or performance metrics.

---

## Intended Behavior

Toggle-able debug overlays:

```lua
-- src/render/debug.lua
local debug = {}

debug.overlays = {
    pathing = false,     -- Show pathable/blocked tiles
    collision = false,   -- Show collision shapes
    entity_ids = false,  -- Show entity IDs above units
    fps = true,          -- Show FPS counter
    grid = false,        -- Show tile grid
    bounds = false,      -- Show camera bounds
}

function debug.draw(renderer, camera)
    if debug.overlays.pathing then
        debug.draw_pathing(renderer, camera)
    end

    if debug.overlays.collision then
        debug.draw_collision(renderer, camera)
    end

    if debug.overlays.entity_ids then
        debug.draw_entity_ids(renderer, camera)
    end

    if debug.overlays.fps then
        debug.draw_fps(renderer)
    end

    if debug.overlays.grid then
        debug.draw_grid(renderer, camera)
    end
end

function debug.draw_fps(renderer)
    local fps = get_fps()
    local color = fps >= 60 and GREEN or (fps >= 30 and YELLOW or RED)
    renderer:draw_text(screen_width - 60, 5, "FPS: " .. fps, 14, color)
end

function debug.toggle(overlay_name)
    debug.overlays[overlay_name] = not debug.overlays[overlay_name]
end
```

---

## Suggested Implementation Steps

1. **Implement FPS counter**
   - Calculate frame rate
   - Color-coded (green/yellow/red)
   - Top-right corner

2. **Implement pathing overlay**
   - Draw grid over terrain
   - Green = walkable
   - Red = blocked
   - Blue = water/special

3. **Implement collision overlay**
   - Draw collision shapes around entities
   - Wireframe circles/rectangles
   - Different colors by type

4. **Implement entity ID display**
   - Show ECS entity ID above each unit
   - Useful for debugging specific entities

5. **Add tile grid**
   - Lines at tile boundaries
   - Helps visualize map structure

6. **Add toggle hotkeys**
   - F1 = toggle pathing
   - F2 = toggle collision
   - F3 = toggle IDs
   - F11 = toggle FPS

---

## Acceptance Criteria

- [ ] FPS counter displays and updates
- [ ] Pathing overlay shows walkable tiles
- [ ] Collision shapes visible when enabled
- [ ] Entity IDs appear above units
- [ ] Overlays can be toggled on/off
- [ ] Overlays don't significantly impact performance

---

## Notes

Debug overlays are essential for development but should be easily hidden for normal play.

**Performance:**
Drawing debug overlays should be cheap. Skip overlays for off-screen areas. Use simple primitives.

**Hotkey convention:**
F-keys for debug toggles:
- F1-F4: Quick actions (hero select)
- F9-F12: Debug toggles

---

## Related Documents

- issues/505b-wire-render-systems.md (renders after game)
- issues/403-implement-basic-pathfinding.md (pathing data)
- issues/405-implement-basic-collision-detection.md (collision data)
