# Issue 507a: Minimap Module

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 507
**Priority:** High
**Dependencies:** 506a, 501a

---

## Current Behavior

No minimap system. Players cannot see an overview of the map or unit positions.

---

## Intended Behavior

Core minimap component with render-to-texture and coordinate mapping:

```lua
-- src/ui/minimap/minimap.lua
local Component = require("ui.component")
local Minimap = setmetatable({}, {__index = Component})
Minimap.__index = Minimap

function Minimap.new(config)
    local self = Component.new(config)
    setmetatable(self, Minimap)

    self.type = "minimap"

    -- Map bounds (world coordinates)
    self.map_bounds = config.map_bounds or {
        min_x = 0, min_y = 0,
        max_x = 1024, max_y = 1024,
    }

    -- Display size (screen pixels)
    self.width = config.width or 200
    self.height = config.height or 200

    -- Render layers
    self.layers = {
        terrain = nil,    -- Pre-rendered terrain texture
        fog = nil,        -- Fog of war overlay
        units = {},       -- Unit position markers
        viewport = nil,   -- Camera view rectangle
        pings = {},       -- Player pings
    }

    -- State
    self.show_terrain = true
    self.show_units = true
    self.show_viewport = true
    self.show_fog = true

    return self
end

-- Convert world coordinates to minimap pixel coordinates
function Minimap:world_to_minimap(wx, wy)
    local bounds = self.map_bounds
    local map_width = bounds.max_x - bounds.min_x
    local map_height = bounds.max_y - bounds.min_y

    local nx = (wx - bounds.min_x) / map_width
    local ny = (wy - bounds.min_y) / map_height

    local mx = self.x + nx * self.width
    local my = self.y + ny * self.height

    return mx, my
end

-- Convert minimap pixel coordinates to world coordinates
function Minimap:minimap_to_world(mx, my)
    local bounds = self.map_bounds
    local map_width = bounds.max_x - bounds.min_x
    local map_height = bounds.max_y - bounds.min_y

    local nx = (mx - self.x) / self.width
    local ny = (my - self.y) / self.height

    local wx = bounds.min_x + nx * map_width
    local wy = bounds.min_y + ny * map_height

    return wx, wy
end

function Minimap:set_map_bounds(min_x, min_y, max_x, max_y)
    self.map_bounds = {
        min_x = min_x, min_y = min_y,
        max_x = max_x, max_y = max_y,
    }
    self:invalidate_terrain()
end

function Minimap:invalidate_terrain()
    self.layers.terrain = nil  -- Force re-render
end

function Minimap:update(dt)
    -- Update ping animations
    for i = #self.layers.pings, 1, -1 do
        local ping = self.layers.pings[i]
        ping.time = ping.time - dt
        if ping.time <= 0 then
            table.remove(self.layers.pings, i)
        end
    end

    Component.update(self, dt)
end

function Minimap:draw(renderer)
    if not self.visible then return end

    local x, y = self:get_absolute_position()

    -- Border
    renderer:draw_rect(x - 2, y - 2, self.width + 4, self.height + 4,
                       {60, 60, 60, 255}, false)

    -- Background (black for unexplored)
    renderer:draw_rect(x, y, self.width, self.height,
                       {0, 0, 0, 255}, true)

    -- Layer rendering
    if self.show_terrain and self.layers.terrain then
        self:draw_terrain(renderer)
    end

    if self.show_fog and self.layers.fog then
        self:draw_fog(renderer)
    end

    if self.show_units then
        self:draw_units(renderer)
    end

    if self.show_viewport then
        self:draw_viewport(renderer)
    end

    self:draw_pings(renderer)

    Component.draw(self, renderer)
end

return Minimap
```

---

## Suggested Implementation Steps

1. **Create Minimap component**
   - Extends UI Component
   - Fixed size in bottom-left
   - Border and background

2. **Implement coordinate conversion**
   - world_to_minimap(wx, wy)
   - minimap_to_world(mx, my)
   - Handle map bounds

3. **Define layer system**
   - Terrain (background)
   - Fog of war (overlay)
   - Units (dots)
   - Camera viewport (rectangle)
   - Pings (temporary markers)

4. **Set up map bounds**
   - Extract from W3E terrain data
   - Or from map info file

5. **Implement update loop**
   - Animate pings
   - Update unit positions
   - Sync camera viewport

6. **Create draw pipeline**
   - Draw layers in order
   - Clip to minimap bounds

---

## Acceptance Criteria

- [ ] Minimap component renders in correct position
- [ ] Coordinate conversion works correctly
- [ ] Layer system supports all required layers
- [ ] Map bounds configurable from terrain data
- [ ] Border and background render properly

---

## Notes

The minimap is essential for strategic awareness in RTS games. It must be clear and responsive.

**Sizing:**
- WC3 minimap: ~200x200 pixels
- Square aspect (may clip non-square maps)
- Fixed position: bottom-left

**Performance:**
Minimap should render efficiently. Pre-render terrain to texture, only update unit dots each frame.

---

## Related Documents

- issues/507-create-minimap-renderer.md (parent issue)
- issues/506a-ui-component-system.md (base component)
- issues/502-implement-terrain-rendering.md (terrain data)
- issues/105-parse-war3map-w3e.md (map bounds)
