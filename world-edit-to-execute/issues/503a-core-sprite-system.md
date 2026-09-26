# Issue 503a: Core Sprite System

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 503
**Priority:** Critical
**Dependencies:** 508 (completed; its 508b built the shapes)
**Blocks:** 503c
**Re-cut:** 2026-09-26, from "Core Sprite System" (its criteria named a Lua `sprites` module; the C renderer built the shapes instead)

---

## Current Behavior

Built by the vertical slice (508b): each render slot carries a `mesh_id`
choosing one of four shapes (circle, cube, triangle, cylinder), drawn in 3D
at the slot's position and scale. Depth in the 3D view does what this
issue's "Y-sorting" was for. Not done: units outside the camera's view are
still drawn.

## Intended Behavior

The placeholder shapes, unchanged, as 516's fallback when a model can't be
found or read; units outside the camera's view (501d) left out of the
frame.

## Suggested Implementation Steps

1. Cull units by the camera's view rectangle when the page is built.

## Acceptance Criteria

- [x] Shapes draw from the slots (508b)
- [x] Overlap is correct (3D depth)
- [ ] Units outside the view are not drawn

---

## Earlier Design (January 2026, for a Lua renderer interface)

Kept as the record; not built as written.

### Current Behavior

Units exist as ECS entities with position components but have no visual representation.

---

### Intended Behavior

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

### Suggested Implementation Steps

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

### Acceptance Criteria

- sprites.register() stores visual configs
- sprites.draw_entity() renders single entity
- sprites.draw_all() renders visible entities
- Circle and rectangle shapes work
- Off-screen entities are culled
- Y-sorting for correct overlap

---

### Notes

This is the foundation for all entity visuals. The placeholder system must be functional enough to play the game without art assets.

**ECS integration:**
Sprites system reads from ECS but doesn't modify it. Position, unit type, and player ownership come from components.

---

### Related Documents

- issues/503-build-sprite-placeholder-system.md (parent)
- issues/501a-define-renderer-interface.md (drawing API)
- src/runtime/ecs/ (entity data source)
