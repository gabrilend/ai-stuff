# Issue 502a: Core Terrain Renderer

**Phase:** 5 - Rendering
**Type:** Sub-Issue of 502
**Priority:** Critical
**Dependencies:** 501a, 105

---

## Current Behavior

W3E terrain data is parsed (Issue 105) but not rendered. Terrain exists as data structures only.

---

## Intended Behavior

Core terrain rendering module that displays the map ground:

```lua
-- src/render/terrain.lua
local terrain = {}

-- Initialize from parsed W3E data
function terrain.init(w3e_data)
    terrain.width = w3e_data.width
    terrain.height = w3e_data.height
    terrain.tiles = w3e_data.tiles
    terrain.tile_size = 128  -- WC3 tile size in world units
end

-- Draw visible terrain
function terrain.draw(renderer, camera)
    local min_x, min_y, max_x, max_y = camera.get_visible_bounds()

    -- Convert to tile coordinates
    local start_x = math.floor(min_x / terrain.tile_size)
    local start_y = math.floor(min_y / terrain.tile_size)
    local end_x = math.ceil(max_x / terrain.tile_size)
    local end_y = math.ceil(max_y / terrain.tile_size)

    -- Draw only visible tiles
    for y = start_y, end_y do
        for x = start_x, end_x do
            local tile = terrain.get_tile(x, y)
            if tile then
                terrain.draw_tile(renderer, camera, x, y, tile)
            end
        end
    end
end

-- Get tile at grid position
function terrain.get_tile(x, y) end

-- Get tile at world position
function terrain.get_tile_at_world(wx, wy) end

-- Draw single tile
function terrain.draw_tile(renderer, camera, x, y, tile) end
```

**Tile Color Mapping (placeholders):**
```lua
local TILE_COLORS = {
    ["Ldrt"] = {139, 90, 43, 255},    -- Dirt (brown)
    ["Lgrs"] = {34, 139, 34, 255},    -- Grass (green)
    ["Lrok"] = {128, 128, 128, 255},  -- Rock (gray)
    ["Lgrd"] = {85, 107, 47, 255},    -- Grassy dirt
    ["Lsnw"] = {255, 250, 250, 255},  -- Snow (white)
    ["Lsnd"] = {210, 180, 140, 255},  -- Sand (tan)
}
```

---

## Suggested Implementation Steps

1. **Create terrain module**
   ```lua
   -- src/render/terrain.lua
   local terrain = {
       width = 0,
       height = 0,
       tiles = {},
       tile_size = 128,
       mode = "flat_color",  -- "wireframe", "flat_color", "textured"
   }
   ```

2. **Implement init from W3E data**
   - Accept parsed W3E table
   - Store tile grid
   - Calculate map bounds

3. **Implement tile access**
   - get_tile(x, y) for grid coordinates
   - get_tile_at_world(wx, wy) for world coordinates
   - Handle out-of-bounds gracefully

4. **Implement basic drawing**
   - Iterate visible tiles only
   - Draw colored rectangles per tile type
   - Convert tile coords to screen via camera

5. **Add visual modes**
   - Wireframe: grid lines only
   - Flat color: solid colors per type
   - Height map: grayscale by elevation

6. **Create tile type registry**
   - Map WC3 tile IDs to colors
   - Support unknown types (fallback color)

---

## Acceptance Criteria

- [ ] terrain.init() accepts W3E data
- [ ] Tiles render at correct world positions
- [ ] Only visible tiles are processed (basic culling)
- [ ] Different tile types show different colors
- [ ] Wireframe mode draws tile boundaries
- [ ] Flat color mode fills tiles
- [ ] get_tile_at_world() returns correct tile

---

## Notes

This is the foundation of the visual map. Everything else renders on top of terrain.

**W3E tile data structure (from Issue 105):**
```lua
tile = {
    ground_height = 0,      -- Base height
    water_level = 0,        -- Water surface height
    ground_type = "Lgrs",   -- 4-char tile type ID
    cliff_type = 0,         -- Cliff variation
    layer_flags = 0,        -- Bitmask for layers
}
```

---

## Related Documents

- issues/502-implement-terrain-rendering.md (parent)
- issues/105-parse-war3map-w3e.md (terrain data source)
- src/parsers/w3e.lua (parser implementation)
- issues/501d-implement-camera-system.md (coordinate conversion)
