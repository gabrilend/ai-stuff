-- Map Renderer (Issue 508d)
-- Converts loaded WC3 map data to render commands.
-- Uses the render module's terrain and entity APIs.

local render = require("render")

-- {{{ map_renderer module
local map_renderer = {}

-- {{{ Terrain tile type to color mapping
-- Based on common WC3 tilesets. Key is 4-char tileset code.
local TILE_COLORS = {
    -- Lordaeron Summer
    Ldrt = { 139, 90, 43 },     -- Dirt (brown)
    Ldro = { 101, 67, 33 },     -- Dark dirt (darker brown)
    Lrok = { 128, 128, 128 },   -- Rock (gray)
    Lgrs = { 34, 139, 34 },     -- Grass (green)
    Lgrd = { 85, 107, 47 },     -- Grass dark (olive)
    Lsno = { 220, 220, 220 },   -- Snow (white)

    -- Lordaeron Fall
    Fdrt = { 139, 90, 43 },     -- Fall dirt
    Frok = { 128, 128, 128 },   -- Fall rock
    Fgrs = { 144, 113, 43 },    -- Fall grass (yellow-brown)
    Fgrd = { 120, 80, 40 },     -- Fall grass dark

    -- Lordaeron Winter
    Wdrt = { 100, 80, 60 },     -- Winter dirt
    Wrok = { 150, 150, 150 },   -- Winter rock
    Wgrs = { 180, 180, 180 },   -- Winter grass (snow-covered)
    Wsno = { 240, 240, 250 },   -- Snow

    -- Ashenvale
    Adrt = { 80, 60, 50 },      -- Ashenvale dirt
    Arok = { 100, 100, 110 },   -- Ashenvale rock
    Agrs = { 40, 90, 60 },      -- Ashenvale grass
    Avin = { 60, 100, 80 },     -- Ashenvale vines

    -- Barrens
    Bdrt = { 194, 145, 87 },    -- Barrens dirt (tan)
    Brok = { 160, 130, 100 },   -- Barrens rock
    Bdsn = { 210, 180, 140 },   -- Barrens desert (sand)
    Bgrs = { 150, 130, 60 },    -- Barrens grass (dry)

    -- Dungeon
    Ddrt = { 60, 55, 50 },      -- Dungeon dirt
    Drok = { 80, 80, 85 },      -- Dungeon rock
    Dbrk = { 70, 65, 60 },      -- Dungeon brick

    -- Water types
    Cwtr = { 30, 100, 180 },    -- Deep water (blue)
    Swtr = { 50, 130, 180 },    -- Shallow water
    Dwtr = { 40, 90, 140 },     -- Dark water

    -- Cliff/boundary
    Cliff = { 90, 90, 90 },     -- Cliff edge
    Bound = { 50, 50, 50 },     -- Map boundary
}

-- Default color for unknown tile types
local DEFAULT_COLOR = { 60, 60, 60 }
-- }}}

-- {{{ Player colors (matches data/init.lua)
local PLAYER_COLORS = {
    [0] = { 255, 3, 3 },        -- Red
    [1] = { 0, 66, 255 },       -- Blue
    [2] = { 28, 230, 185 },     -- Teal
    [3] = { 84, 0, 129 },       -- Purple
    [4] = { 255, 252, 0 },      -- Yellow
    [5] = { 254, 138, 14 },     -- Orange
    [6] = { 32, 192, 0 },       -- Green
    [7] = { 229, 91, 176 },     -- Pink
    [8] = { 149, 150, 151 },    -- Gray
    [9] = { 126, 191, 241 },    -- Light Blue
    [10] = { 16, 98, 70 },      -- Dark Green
    [11] = { 78, 42, 4 },       -- Brown
    [12] = { 155, 0, 0 },       -- Maroon (Neutral Hostile)
    [13] = { 0, 0, 195 },       -- Navy
    [14] = { 0, 234, 255 },     -- Turquoise
    [15] = { 190, 0, 254 },     -- Violet
}
-- }}}

-- {{{ Helper: get_tile_color
-- Returns RGB color for a tilepoint based on terrain data.
local function get_tile_color(tile, ground_tilesets)
    -- Priority: water > boundary > ground texture

    if tile.has_water then
        return TILE_COLORS.Cwtr
    end

    if tile.boundary or tile.is_boundary then
        return TILE_COLORS.Bound
    end

    -- Get ground texture name from tileset index
    local tex_idx = tile.ground_texture
    if tex_idx and ground_tilesets and ground_tilesets[tex_idx + 1] then
        local tex_name = ground_tilesets[tex_idx + 1]
        if TILE_COLORS[tex_name] then
            return TILE_COLORS[tex_name]
        end
    end

    return DEFAULT_COLOR
end
-- }}}

-- {{{ map_renderer.load_terrain
-- Converts terrain data to render commands.
-- Creates a terrain grid and sets tile colors from w3e data.
function map_renderer.load_terrain(map)
    local terrain = map.terrain
    if not terrain then
        print("[map_renderer] No terrain data in map")
        return false
    end

    local w = terrain.width
    local h = terrain.height
    if w <= 0 or h <= 0 then
        print("[map_renderer] Invalid terrain dimensions: " .. w .. "x" .. h)
        return false
    end

    -- WC3 uses 128 units per tile; scale down for rendering
    -- Use 1.0 world unit = 1 tile for simplicity
    local tile_size = 1.0
    local scale = 1.0 / 128.0  -- For position scaling

    -- Create terrain grid
    local ok = render.terrain_create(w, h, tile_size)
    if not ok then
        print("[map_renderer] Failed to create terrain grid")
        return false
    end

    -- Center terrain around origin
    local offset_x = -w * tile_size / 2
    local offset_z = -h * tile_size / 2
    render.terrain_set_offset(offset_x, offset_z)

    -- Set tile colors
    local tiles_data = {}
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local tile = terrain:get_tile(x, y)
            if tile then
                local color = get_tile_color(tile, terrain.ground_tilesets)
                table.insert(tiles_data, { x, y, color[1], color[2], color[3] })
            end
        end
    end

    -- Bulk set tiles for efficiency
    render.terrain_set_tiles(tiles_data)

    print("[map_renderer] Loaded terrain: " .. w .. "x" .. h .. " tiles")
    return true, { width = w, height = h, tile_size = tile_size, offset_x = offset_x, offset_z = offset_z }
end
-- }}}

-- {{{ map_renderer.load_doodads
-- Creates render entities for static doodads.
-- Returns count of loaded doodads.
function map_renderer.load_doodads(map, scale)
    scale = scale or (1.0 / 128.0)
    local count = 0
    local registry = map.registry

    if not registry then
        print("[map_renderer] No object registry in map")
        return 0
    end

    -- Iterate doodads
    registry:each_doodad(function(doodad)
        local x = (doodad.x or 0) * scale
        local z = (doodad.y or 0) * scale  -- WC3 Y -> render Z
        local y = 0.1  -- Slightly above ground

        -- Use creation_number as entity ID if available
        local entity_id = doodad.creation_number or (1000000 + count)

        local slot = render.create_entity(entity_id, render.MESH_CUBE, x, y, z)
        if slot >= 0 then
            -- Doodads are green-ish, semi-transparent
            render.set_color(slot, 34, 139, 34, 180)
            render.set_scale(slot, (doodad.scale_x or 1.0) * 0.3)
            count = count + 1
        end
    end)

    if count > 0 then
        print("[map_renderer] Loaded " .. count .. " doodads")
    end
    return count
end
-- }}}

-- {{{ map_renderer.load_units
-- Creates render entities for placed units.
-- Returns count of loaded units.
function map_renderer.load_units(map, scale)
    scale = scale or (1.0 / 128.0)
    local count = 0
    local registry = map.registry

    if not registry then
        print("[map_renderer] No object registry in map")
        return 0
    end

    -- Iterate units
    registry:each_unit(function(unit)
        local x = (unit.x or 0) * scale
        local z = (unit.y or 0) * scale  -- WC3 Y -> render Z
        local y = 0.3  -- Above ground

        -- Use creation_number as entity ID
        local entity_id = unit.creation_number or (2000000 + count)

        local slot = render.create_entity(entity_id, render.MESH_CIRCLE, x, y, z)
        if slot >= 0 then
            -- Color by player/owner
            local player_id = unit.player or 12  -- Default to neutral hostile
            local color = PLAYER_COLORS[player_id] or PLAYER_COLORS[12]
            render.set_color(slot, color[1], color[2], color[3], 255)
            render.set_scale(slot, 0.4)
            count = count + 1
        end
    end)

    if count > 0 then
        print("[map_renderer] Loaded " .. count .. " units")
    end
    return count
end
-- }}}

-- {{{ map_renderer.load
-- Main entry point: loads terrain, doodads, and units from a Map object.
-- Returns true on success, false on failure.
function map_renderer.load(map)
    if not map then
        print("[map_renderer] No map provided")
        return false
    end

    print("[map_renderer] Loading map: " .. (map:get_display_name() or map.name or "unknown"))

    -- Load terrain
    local terrain_ok, terrain_info = map_renderer.load_terrain(map)
    if not terrain_ok then
        return false
    end

    -- Calculate position scale from terrain info
    local scale = 1.0 / 128.0

    -- Load objects
    local doodad_count = map_renderer.load_doodads(map, scale)
    local unit_count = map_renderer.load_units(map, scale)

    print("[map_renderer] Map load complete: " ..
          terrain_info.width .. "x" .. terrain_info.height .. " terrain, " ..
          doodad_count .. " doodads, " ..
          unit_count .. " units")

    return true
end
-- }}}

-- {{{ map_renderer.unload
-- Clears all rendered content.
function map_renderer.unload()
    render.terrain_destroy()
    -- Note: Entities are not tracked here, so they persist
    -- In a full implementation, we'd track and destroy them
    print("[map_renderer] Unloaded map renderer")
end
-- }}}

return map_renderer
-- }}}
