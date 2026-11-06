# Issue 507a: Minimap Module

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 507
**Priority:** High
**Dependencies:** 506a (interface elements), 501d (the camera)
**Blocks:** 507b, 507c, 507d, 507e, 507f
**Re-cut:** 2026-09-26, from "Minimap Module"

---

## Current Behavior

No minimap.

## Intended Behavior

A minimap element on the page: a screen rectangle in the console, the
map's playable area mapped into it (map bounds from `war3map.w3i`, the
square fitted as WC3 fits non-square maps), and the two conversions the
others use: world point to minimap point and back.

## Suggested Implementation Steps

1. The element and its rectangle.
2. World-to-minimap and minimap-to-world, with tests.

## Acceptance Criteria

- [x] The two conversions are tested on a square and a non-square map

---

## Earlier Design (January 2026, for a Lua renderer interface)

Kept as the record; not built as written.

### Current Behavior

No minimap system. Players cannot see an overview of the map or unit positions.

---

### Intended Behavior

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

### Suggested Implementation Steps

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

### Acceptance Criteria

- Minimap component renders in correct position
- Coordinate conversion works correctly
- Layer system supports all required layers
- Map bounds configurable from terrain data
- Border and background render properly

---

### Notes

The minimap is essential for strategic awareness in RTS games. It must be clear and responsive.

**Sizing:**
- WC3 minimap: ~200x200 pixels
- Square aspect (may clip non-square maps)
- Fixed position: bottom-left

**Performance:**
Minimap should render efficiently. Pre-render terrain to texture, only update unit dots each frame.

---

### Related Documents

- issues/507-create-minimap-renderer.md (parent issue)
- issues/506a-ui-component-system.md (base component)
- issues/502-implement-terrain-rendering.md (terrain data)
- issues/105-parse-war3map-w3e.md (map bounds)

---

## Decisions (2026-11-06)

Made without the owner, each one theirs to overturn.

1. **The minimap already lived in the interface** (`src/ui/wc3/hud.lua`,
   issue 518b, 2026-09-29, after this issue's re-cut): its square in the
   console, dots, view box, clicks and pings, with conversions that
   stretched the map to the square. The newer code is followed: the
   module is Lua beside it, `src/ui/wc3/minimap.lua`, and the interface
   now goes through it, rather than a new element on the page (501),
   which does not exist yet.
2. **A map that is not square is fitted as WC3 fits it**: the whole map
   at one scale across and down, centred in the square, the rest dark.
   The map's picture is drawn over that rectangle only.
3. **A click in the dark margin, or past the picture, is the nearest
   point of the map**, so dragging along the minimap's edge holds the
   camera to the map's edge.
4. **The extent is the one the game gives** (`game.minimap`: today the
   whole terrain, which its picture is made from). Whether WC3's minimap
   shows the whole terrain, the playable area or the camera bounds is
   not measured here; changing it is one line in `wc3map/game.lua` and
   the picture with it.
5. Based on 501d's branch (#314), not on the headless renderer (#307): the minimap draws through the interface's 2D calls, not the render slots, and its tests take the view's corners from 501d's camera.

## What happened

- `src/ui/wc3/minimap.lua` (with an info page): `fit`, `new`,
  `to_minimap`, `to_world`, `inside`, `view_box`; `hud.lua` uses it for
  every minimap point and draws the picture fitted.
- `src/tests/test_minimap.lua` (59 checks, with 507c-e): a square map, one
  twice as wide and one twice as tall, both ways, the margins, a map
  with no width or height.
- Mutation check of `minimap.lua`: 96 mutants, 89 caught. The 7 left are
  equivalent: `>` for `>=` where a corner on the picture's edge is cut to
  itself (4), the loop over the quad's eight numbers run to 8 (1), and a
  map one unit wide taken as none (2). Of the lines changed in `hud.lua`,
  30 mutants, 30 caught.
