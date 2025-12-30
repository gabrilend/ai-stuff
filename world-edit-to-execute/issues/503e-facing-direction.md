# Issue 503e: Facing Direction

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 503
**Priority:** Low
**Dependencies:** 503a

---

## Current Behavior

Units render as circles/shapes with no indication of facing. Movement direction is not visible.

---

## Intended Behavior

Visual indicator showing unit facing direction:

```lua
-- src/render/facing.lua
local facing = {}

-- Draw facing indicator
function facing.draw(renderer, x, y, angle, radius, color)
    -- Arrow pointing in facing direction
    local arrow_length = radius * 0.8
    local arrow_width = radius * 0.4

    -- Calculate arrow tip
    local tip_x = x + math.cos(angle) * arrow_length
    local tip_y = y + math.sin(angle) * arrow_length

    -- Draw line from center to tip
    renderer:draw_line(x, y, tip_x, tip_y, color, 2)

    -- Optional: draw arrowhead
    local head_angle = 2.5  -- radians from tip
    local head_length = arrow_width
    -- ... arrowhead triangles
end

-- Integrate with sprite drawing
function sprites.draw_entity_with_facing(renderer, camera, entity)
    sprites.draw_entity(renderer, camera, entity)

    local pos = ecs.get_component(entity, "position")
    local mov = ecs.get_component(entity, "movement")

    if mov and mov.facing then
        local sx, sy = camera.world_to_screen(pos.x, pos.y)
        local config = sprites.get_config(entity)
        facing.draw(renderer, sx, sy, mov.facing, config.size/2, {255, 255, 255, 200})
    end
end
```

**Visual Styles:**
```
1. Line - Simple line from center outward
2. Arrow - Line with arrowhead
3. Wedge - Pie-slice showing direction
4. Dot - Small dot at the front edge
```

---

## Suggested Implementation Steps

1. **Create facing module**
   - Draw facing indicator given angle
   - Multiple visual styles

2. **Integrate with movement component**
   - Read facing from movement component
   - Handle units with no movement (buildings)

3. **Implement line indicator**
   ```lua
   function facing.draw_line(renderer, x, y, angle, radius)
       local end_x = x + math.cos(angle) * radius
       local end_y = y + math.sin(angle) * radius
       renderer:draw_line(x, y, end_x, end_y, WHITE, 1)
   end
   ```

4. **Implement arrow indicator**
   - Line plus small triangle at tip
   - More visible than simple line

5. **Add toggle for facing display**
   - facing.enabled = true/false
   - Per-entity override

6. **Handle buildings and stationary units**
   - Buildings: no facing indicator
   - Stationary units: show last facing
   - Turrets/towers: show target direction

---

## Acceptance Criteria

- [ ] Moving units show facing direction
- [ ] Facing updates as units turn
- [ ] Indicator is visible but not obtrusive
- [ ] Can toggle facing display on/off
- [ ] Buildings don't show facing
- [ ] Works at various zoom levels

---

## Notes

Facing indicators help players understand unit state, especially:
- Which direction a unit will attack
- Expected movement direction
- Turn progress during rotation

**Integration with movement system (Phase 4):**
The movement component stores facing angle in radians. This system just reads and displays it.

**Optional enhancement:**
- Fade indicator when unit is not moving
- Pulse during active rotation
- Color-code by movement state

---

## Related Documents

- issues/503a-core-sprite-system.md (base rendering)
- issues/404-create-unit-movement-system.md (facing data source)
- src/runtime/systems/movement.lua (facing calculation)
