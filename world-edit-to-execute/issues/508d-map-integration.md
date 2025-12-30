# Issue 508d: Map Integration

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** High
**Dependencies:** 508c (Lua-C bridge)

---

## Current Behavior

Maps load via `Map.load()` and populate the registry with doodads, units, etc.
But nothing is rendered - the data exists only in Lua memory.

---

## Intended Behavior

When a map loads:
1. Terrain displays as a colored grid
2. Doodads appear as static rendered objects
3. Units appear as rendered entities linked to ECS

The map becomes visible.

---

## Suggested Implementation Steps

### 1. Terrain Grid Rendering (C)

Add terrain rendering to draw thread:

```c
/* {{{ TerrainGrid */
typedef struct terrain_grid {
    int width, height;
    float tile_size;
    unsigned char* tile_colors;  // 3 bytes per tile (RGB)
} TerrainGrid;

TerrainGrid* terrain_create(int w, int h, float tile_size);
void terrain_set_tile(TerrainGrid* t, int x, int y, unsigned char r, unsigned char g, unsigned char b);
void terrain_draw(TerrainGrid* t);
/* }}} */

/* {{{ terrain_draw */
void terrain_draw(TerrainGrid* t) {
    for (int y = 0; y < t->height; y++) {
        for (int x = 0; x < t->width; x++) {
            int idx = (y * t->width + x) * 3;
            Color c = {
                t->tile_colors[idx],
                t->tile_colors[idx + 1],
                t->tile_colors[idx + 2],
                255
            };

            float wx = x * t->tile_size;
            float wz = y * t->tile_size;

            DrawCube((Vector3){wx, 0, wz},
                     t->tile_size, 0.1f, t->tile_size, c);
        }
    }
}
/* }}} */
```

### 2. Terrain Bridge (C API)

```c
/* {{{ l_terrain_create */
// Lua: render.terrain_create(width, height, tile_size)
static int l_terrain_create(lua_State* L) {
    int w = luaL_checkinteger(L, 1);
    int h = luaL_checkinteger(L, 2);
    float size = luaL_checknumber(L, 3);

    g_terrain = terrain_create(w, h, size);

    return 0;
}
/* }}} */

/* {{{ l_terrain_set_tile */
// Lua: render.terrain_set_tile(x, y, r, g, b)
static int l_terrain_set_tile(lua_State* L) {
    int x = luaL_checkinteger(L, 1);
    int y = luaL_checkinteger(L, 2);
    int r = luaL_checkinteger(L, 3);
    int g = luaL_checkinteger(L, 4);
    int b = luaL_checkinteger(L, 5);

    terrain_set_tile(g_terrain, x, y, r, g, b);

    return 0;
}
/* }}} */
```

### 3. Map Load Integration (Lua)

```lua
-- src/demo/map_renderer.lua
-- {{{ map_renderer
-- Converts loaded map data to render commands

local render = require("render")

local map_renderer = {}

-- Tile type to color mapping
local TILE_COLORS = {
    Ldrt = {139, 90, 43},    -- Lordaeron Dirt (brown)
    Ldro = {101, 67, 33},    -- Lordaeron Rock
    Lrok = {128, 128, 128},  -- Lordaeron Rock
    Lgrs = {34, 139, 34},    -- Lordaeron Grass (green)
    Lgrd = {85, 107, 47},    -- Lordaeron Grass Dark
    Cwtr = {30, 144, 255},   -- Water (blue)
    -- ... more tile types
}

-- {{{ map_renderer.load_terrain
function map_renderer.load_terrain(map)
    local terrain = map.terrain
    local w = terrain.width
    local h = terrain.height
    local tile_size = 128.0 / 4  -- WC3 tile is 128 units, scale down

    render.terrain_create(w, h, tile_size)

    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local tile = terrain:get_tile(x, y)
            local tile_type = tile.ground_texture or "Lgrs"
            local color = TILE_COLORS[tile_type] or {100, 100, 100}

            -- Adjust for water
            if tile.water_level and tile.water_level > tile.ground_height then
                color = TILE_COLORS.Cwtr
            end

            render.terrain_set_tile(x, y, color[1], color[2], color[3])
        end
    end
end
-- }}}

-- {{{ map_renderer.load_doodads
function map_renderer.load_doodads(map)
    local doodads = map.registry:get_all_doodads()

    for _, doodad in ipairs(doodads) do
        -- Doodads are static, create directly
        local x = doodad.x / 128  -- Scale from WC3 units
        local z = doodad.y / 128
        local y = 0  -- Ground level

        render.create(doodad.creation_number, "cube", x, y, z)
        render.set_color(doodad.creation_number, 34, 139, 34, 200)  -- Green, semi-transparent
        render.set_scale(doodad.creation_number, doodad.scale or 1.0)
    end
end
-- }}}

-- {{{ map_renderer.load_units
function map_renderer.load_units(map, ecs)
    local units = map.registry:get_all_units()

    for _, unit in ipairs(units) do
        -- Create ECS entity
        local entity_id = ecs.create()

        -- Add components
        ecs.add(entity_id, "position", {
            x = unit.x / 128,
            y = 0,
            z = unit.y / 128
        })

        ecs.add(entity_id, "renderable", {
            mesh = "circle",
            team = unit.player or 0
        })

        ecs.add(entity_id, "unit_type", {
            type_id = unit.type_id
        })

        -- Render entity created by ECS hook (see 508c)
    end
end
-- }}}

-- {{{ map_renderer.load
function map_renderer.load(map, ecs)
    print("Loading terrain...")
    map_renderer.load_terrain(map)

    print("Loading doodads...")
    map_renderer.load_doodads(map)

    print("Loading units...")
    map_renderer.load_units(map, ecs)

    print("Map rendered!")
end
-- }}}

return map_renderer
-- }}}
```

### 4. Demo Script

```lua
-- src/demo/testing_room.lua
-- {{{ testing_room
-- Main demo entry point

local Map = require("data")
local ecs = require("runtime.ecs")
local map_renderer = require("demo.map_renderer")

local testing_room = {}

function testing_room.run(map_path)
    print("=== Testing Room Demo ===")
    print("Loading map: " .. map_path)

    -- Load map data
    local map = Map.load(map_path)
    if not map then
        print("Failed to load map!")
        return
    end

    print("Map loaded: " .. (map.info.name or "unnamed"))

    -- Initialize ECS
    ecs.init()

    -- Load into renderer
    map_renderer.load(map, ecs)

    print("Ready! Use mouse to interact.")
end

return testing_room
-- }}}
```

---

## Files to Create/Modify

- `src/render/terrain.h` - Terrain grid structs
- `src/render/terrain.c` - Terrain rendering
- `src/render/bridge.c` - Add terrain C API
- `src/demo/map_renderer.lua` - Map to render conversion
- `src/demo/testing_room.lua` - Demo entry point

---

## Acceptance Criteria

- [ ] Terrain grid renders as colored tiles
- [ ] Tile colors reflect terrain type (grass=green, water=blue, etc.)
- [ ] Doodads render as static shapes
- [ ] Units render as dynamic shapes linked to ECS
- [ ] Demo script loads and displays a test map
- [ ] Camera positioned to see map overview

---

## Notes

Coordinate scaling is important: WC3 uses 128-unit tiles. Scale appropriately
for the viewport (e.g., divide by 128, or use a scale factor).

The initial terrain is very simplified - just colored quads. Height variation,
cliff rendering, and proper textures come later.

---

## Related Documents

- `issues/508c-lua-c-bridge.md` - Bridge this uses
- `src/parsers/w3e.lua` - Terrain data source
- `src/registry/` - Registry for doodads/units
