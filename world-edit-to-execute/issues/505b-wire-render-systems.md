# Issue 505b: Wire Render Systems

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 505
**Priority:** High
**Dependencies:** 505a, 502, 503

---

## Current Behavior

Render systems (terrain, sprites) exist but are not connected to the main game loop.

---

## Intended Behavior

Wire all render systems into a unified render pipeline:

```lua
-- src/render/pipeline.lua
local pipeline = {}

local terrain = require("render.terrain")
local sprites = require("render.sprites")
local camera = require("render.camera")
local registry = require("render.registry")
local events = require("runtime.events")

function pipeline.init(w3e_data, ecs)
    terrain.init(w3e_data)
    sprites.set_ecs(ecs)
    camera.init()
end

function pipeline.render(dt)
    local renderer = registry.get_active()

    events.emit("render.pre_frame", dt)

    renderer:begin_frame()

    -- Layer 1: Terrain
    events.emit("render.layer_start", "terrain")
    terrain.draw(renderer, camera)
    events.emit("render.layer_end", "terrain")

    -- Layer 2: Units/Sprites
    events.emit("render.layer_start", "units")
    sprites.draw_all(renderer, camera)
    events.emit("render.layer_end", "units")

    -- Layer 3: UI (handled by 505d)

    renderer:end_frame()

    events.emit("render.post_frame", dt)
end
```

---

## Suggested Implementation Steps

1. **Create pipeline module**
   - Central coordination point
   - Initializes all render subsystems

2. **Connect terrain renderer**
   - Pass W3E data from map loader
   - Hook into camera for culling

3. **Connect sprite renderer**
   - Link to ECS for entity data
   - Connect to player system for team colors

4. **Establish render order**
   - Terrain first (background)
   - Sprites second (entities)
   - Effects third (particles/projectiles)
   - UI last (always on top)

5. **Integrate with game loop**
   ```lua
   -- main game loop
   function love.draw()
       pipeline.render(dt)
   end
   ```

6. **Add camera update**
   - Camera updates before render
   - Smooth interpolation

---

## Acceptance Criteria

- [ ] Terrain renders as background
- [ ] Sprites render above terrain
- [ ] Correct draw order maintained
- [ ] Camera affects all systems
- [ ] Render events fire correctly
- [ ] No visual glitches between layers

---

## Notes

This is the integration point where separate systems become a unified visual experience.

**Performance consideration:**
The pipeline should be efficient - no redundant calculations. Cache visible bounds once per frame and share across systems.

---

## Related Documents

- issues/505a-default-renderer-backend.md (active renderer)
- issues/502-implement-terrain-rendering.md (terrain system)
- issues/503-build-sprite-placeholder-system.md (sprite system)
- issues/501e-create-render-events.md (event hooks)
