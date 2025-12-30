# Issue 503a: Core Sprite System

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 503
**Priority:** Critical
**Dependencies:** 501a

---

## Current Behavior

Units exist as ECS entities with position components but have no visual representation.

---

## Intended Behavior

Core sprite system for rendering game entities:

```lua
-- src/render/sprites.lua
local sprites = {}

-- Register a visual type
function sprites.register(type_id, config)
    sprites.types[type_id] = {
        shape = config.shape or "circle",  -- "circle", "rect", "diamond"
        size = config.size or 16,
        color = config.color or {255, 255, 255, 255},
        outline = config.outline or false,
    }
end

-- Draw an entity
function sprites.draw_entity(renderer, camera, entity)
    local pos = ecs.get_component(entity, "position")
    local unit = ecs.get_component(entity, "unit")

    if not pos then return end

    local sx, sy = camera.world_to_screen(pos.x, pos.y)
    local config = sprites.get_config(unit and unit.type_id)

    sprites.draw_shape(renderer, sx, sy, config)
end

-- Draw all visible entities
function sprites.draw_all(renderer, camera)
    local visible = camera.get_visible_bounds()
    for entity in ecs.query("position") do
        local pos = ecs.get_component(entity, "position")
        if is_in_bounds(pos, visible) then
            sprites.draw_entity(renderer, camera, entity)
        end
    end
end
```

---

## Suggested Implementation Steps

1. **Create sprites module**
   ```lua
   -- src/render/sprites.lua
   local sprites = {
       types = {},         -- type_id -> config
       defaults = {
           shape = "circle",
           size = 16,
           color = {200, 200, 200, 255},
       },
   }
   ```

2. **Implement type registration**
   - register(type_id, config) stores visual config
   - get_config(type_id) returns config or defaults
   - Support inheritance (hero extends unit)

3. **Implement shape drawing**
   ```lua
   function sprites.draw_shape(renderer, x, y, config)
       if config.shape == "circle" then
           renderer:draw_circle(x, y, config.size/2, config.color, true)
       elseif config.shape == "rect" then
           renderer:draw_rect(x - config.size/2, y - config.size/2,
                             config.size, config.size, config.color, true)
       end
   end
   ```

4. **Implement entity drawing**
   - Get position from ECS
   - Convert to screen coords via camera
   - Apply unit-specific visual config

5. **Implement batch drawing**
   - draw_all() for all visible entities
   - Cull off-screen entities
   - Sort by y-position for overlap

6. **Add z-ordering**
   - Entities lower on screen draw on top
   - Flying units draw above ground units
   - Buildings draw behind units

---

## Acceptance Criteria

- [ ] sprites.register() stores visual configs
- [ ] sprites.draw_entity() renders single entity
- [ ] sprites.draw_all() renders visible entities
- [ ] Circle and rectangle shapes work
- [ ] Off-screen entities are culled
- [ ] Y-sorting for correct overlap

---

## Notes

This is the foundation for all entity visuals. The placeholder system must be functional enough to play the game without art assets.

**ECS integration:**
Sprites system reads from ECS but doesn't modify it. Position, unit type, and player ownership come from components.

---

## Related Documents

- issues/503-build-sprite-placeholder-system.md (parent)
- issues/501a-define-renderer-interface.md (drawing API)
- src/runtime/ecs/ (entity data source)
