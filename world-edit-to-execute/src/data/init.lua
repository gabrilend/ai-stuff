-- Map Data Structure
-- Provides unified Map class that aggregates all parsed map components.
-- This is the primary interface for accessing map data.

local mpq = require("mpq")
local w3i = require("parsers.w3i")
local wts = require("parsers.wts")
local w3e = require("parsers.w3e")

-- {{{ Player colors
local PLAYER_COLORS = {
    [0] = { r = 255, g = 3, b = 3, name = "Red" },
    [1] = { r = 0, g = 66, b = 255, name = "Blue" },
    [2] = { r = 28, g = 230, b = 185, name = "Teal" },
    [3] = { r = 84, g = 0, b = 129, name = "Purple" },
    [4] = { r = 255, g = 252, b = 0, name = "Yellow" },
    [5] = { r = 254, g = 138, b = 14, name = "Orange" },
    [6] = { r = 32, g = 192, b = 0, name = "Green" },
    [7] = { r = 229, g = 91, b = 176, name = "Pink" },
    [8] = { r = 149, g = 150, b = 151, name = "Gray" },
    [9] = { r = 126, g = 191, b = 241, name = "Light Blue" },
    [10] = { r = 16, g = 98, b = 70, name = "Dark Green" },
    [11] = { r = 78, g = 42, b = 4, name = "Brown" },
    [12] = { r = 155, g = 0, b = 0, name = "Maroon" },
    [13] = { r = 0, g = 0, b = 195, name = "Navy" },
    [14] = { r = 0, g = 234, b = 255, name = "Turquoise" },
    [15] = { r = 190, g = 0, b = 254, name = "Violet" },
}
-- }}}

-- {{{ Map class
local Map = {}
Map.__index = Map

-- {{{ new
-- Create an empty Map object.
function Map.new()
    local self = setmetatable({}, Map)

    -- Metadata
    self.name = ""
    self.author = ""
    self.description = ""
    self.suggested_players = ""
    self.version = 0

    -- Dimensions
    self.width = 0
    self.height = 0
    self.playable_width = 0
    self.playable_height = 0

    -- Tileset
    self.tileset = ""
    self.tileset_code = ""

    -- Components
    self.terrain = nil      -- Terrain object from w3e parser
    self.strings = nil      -- StringTable object from wts parser
    self.players = {}       -- Player definitions from w3i
    self.forces = {}        -- Force definitions from w3i
    self.flags = {}         -- Map flags from w3i

    -- Additional data
    self.fog = nil          -- Fog settings from w3i
    self.weather = nil      -- Weather ID from w3i
    self.loading_screen = nil

    -- Source
    self.source_path = ""

    return self
end
-- }}}

-- {{{ apply_info
-- Apply parsed w3i info to map.
local function apply_info(map, info)
    map.name = info.name or ""
    map.author = info.author or ""
    map.description = info.description or ""
    map.suggested_players = info.players_recommended or ""
    map.version = info.version or 0

    map.width = info.width or 0
    map.height = info.height or 0
    map.playable_width = info.playable_width or map.width
    map.playable_height = info.playable_height or map.height

    map.tileset = info.tileset or ""
    map.tileset_code = info.tileset_code or ""

    map.players = info.players or {}
    map.forces = info.forces or {}
    map.flags = info.flags or {}

    map.fog = info.fog
    map.weather = info.weather
    map.loading_screen = info.loading_screen
end
-- }}}

-- {{{ load
-- Load a map from a .w3x/.w3m file.
-- Returns a Map object with all components loaded.
function Map.load(path)
    local map = Map.new()
    map.source_path = path

    -- Open archive
    local archive = mpq.open(path)

    -- Load string table first (others may reference it)
    if archive:has("war3map.wts") then
        local ok, wts_data = pcall(archive.extract, archive, "war3map.wts")
        if ok and wts_data then
            map.strings = wts.new(wts_data)
        end
    end

    -- Load map info
    if archive:has("war3map.w3i") then
        local ok, w3i_data = pcall(archive.extract, archive, "war3map.w3i")
        if ok and w3i_data then
            local info_ok, info = pcall(w3i.parse, w3i_data)
            if info_ok and info then
                apply_info(map, info)
            end
        end
    end

    -- Load terrain
    if archive:has("war3map.w3e") then
        local ok, w3e_data = pcall(archive.extract, archive, "war3map.w3e")
        if ok and w3e_data then
            local terrain_ok, terrain = pcall(w3e.parse, w3e_data)
            if terrain_ok and terrain then
                map.terrain = terrain
            end
        end
    end

    archive:close()
    return map
end
-- }}}

-- {{{ String resolution
-- {{{ resolve_string
-- Resolve TRIGSTR_xxx references in text.
function Map:resolve_string(text)
    if self.strings then
        return self.strings:resolve(text)
    end
    return text
end
-- }}}

-- {{{ get_display_name
-- Get the map name with TRIGSTR resolved.
function Map:get_display_name()
    return self:resolve_string(self.name)
end
-- }}}

-- {{{ get_display_author
-- Get the author with TRIGSTR resolved.
function Map:get_display_author()
    return self:resolve_string(self.author)
end
-- }}}

-- {{{ get_display_description
-- Get the description with TRIGSTR resolved.
function Map:get_display_description()
    return self:resolve_string(self.description)
end
-- }}}
-- }}}

-- {{{ Player/Force accessors
-- {{{ get_player
-- Get player by number (0-indexed).
function Map:get_player(num)
    for _, player in ipairs(self.players) do
        if (player.number or player.id) == num then
            return player
        end
    end
    return nil
end
-- }}}

-- {{{ get_force
-- Get force by index (1-indexed).
function Map:get_force(index)
    return self.forces[index]
end
-- }}}

-- {{{ get_player_color
-- Get player color by ID.
function Map:get_player_color(id)
    return PLAYER_COLORS[id]
end
-- }}}

-- {{{ player_count
-- Get number of players.
function Map:player_count()
    return #self.players
end
-- }}}

-- {{{ force_count
-- Get number of forces.
function Map:force_count()
    return #self.forces
end
-- }}}
-- }}}

-- {{{ Terrain accessors
-- {{{ get_height
-- Get terrain height at tile coordinates.
function Map:get_height(x, y)
    if self.terrain then
        return self.terrain:get_height(x, y)
    end
    return nil
end
-- }}}

-- {{{ is_walkable
-- Check if tile is walkable.
function Map:is_walkable(x, y)
    if self.terrain then
        return self.terrain:is_walkable(x, y)
    end
    return false
end
-- }}}

-- {{{ is_water
-- Check if tile has water.
function Map:is_water(x, y)
    if self.terrain then
        return self.terrain:is_water(x, y)
    end
    return false
end
-- }}}

-- {{{ get_tile
-- Get full tile data.
function Map:get_tile(x, y)
    if self.terrain then
        return self.terrain:get_tile(x, y)
    end
    return nil
end
-- }}}
-- }}}

-- {{{ Coordinate conversion
-- {{{ tile_to_world
-- Convert tile coordinates to world coordinates.
function Map:tile_to_world(tx, ty)
    if self.terrain then
        return self.terrain:tile_to_world(tx, ty)
    end
    return { x = tx * 128, y = ty * 128 }
end
-- }}}

-- {{{ world_to_tile
-- Convert world coordinates to tile coordinates.
function Map:world_to_tile(wx, wy)
    if self.terrain then
        return self.terrain:world_to_tile(wx, wy)
    end
    return { x = math.floor(wx / 128), y = math.floor(wy / 128) }
end
-- }}}
-- }}}

-- {{{ Info/Stats
-- {{{ info
-- Get map info summary.
function Map:info()
    return {
        name = self:get_display_name(),
        author = self:get_display_author(),
        description = self:get_display_description(),
        suggested_players = self.suggested_players,
        dimensions = { width = self.width, height = self.height },
        playable = { width = self.playable_width, height = self.playable_height },
        tileset = self.tileset,
        player_count = self:player_count(),
        force_count = self:force_count(),
        has_terrain = self.terrain ~= nil,
        has_strings = self.strings ~= nil,
    }
end
-- }}}

-- {{{ terrain_stats
-- Get terrain statistics.
function Map:terrain_stats()
    if self.terrain then
        return self.terrain:stats()
    end
    return nil
end
-- }}}
-- }}}
-- }}}

-- {{{ Format function
-- {{{ format
-- Format map info for display.
local function format(map)
    local lines = {}

    lines[#lines + 1] = "=== Map Info ==="
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("Name: %s", map:get_display_name())
    lines[#lines + 1] = string.format("Author: %s", map:get_display_author())
    lines[#lines + 1] = string.format("Suggested Players: %s", map.suggested_players)
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("Dimensions: %dx%d tiles", map.width, map.height)
    lines[#lines + 1] = string.format("Playable: %dx%d tiles", map.playable_width, map.playable_height)
    lines[#lines + 1] = string.format("Tileset: %s (%s)", map.tileset, map.tileset_code)
    lines[#lines + 1] = ""

    -- Players
    lines[#lines + 1] = string.format("Players (%d):", map:player_count())
    for _, player in ipairs(map.players) do
        local player_num = player.number or player.id or 0
        local color = PLAYER_COLORS[player_num]
        local color_name = color and color.name or "Unknown"
        lines[#lines + 1] = string.format("  [%d] %s (%s, %s) - %s",
            player_num,
            map:resolve_string(player.name or ""),
            player.type or "unknown",
            player.race or "unknown",
            color_name)
    end
    lines[#lines + 1] = ""

    -- Forces
    lines[#lines + 1] = string.format("Forces (%d):", map:force_count())
    for i, force in ipairs(map.forces) do
        lines[#lines + 1] = string.format("  [%d] %s (%d players)",
            i,
            map:resolve_string(force.name or ""),
            #(force.players or {}))
    end
    lines[#lines + 1] = ""

    -- Terrain
    if map.terrain then
        local stats = map:terrain_stats()
        lines[#lines + 1] = "Terrain:"
        lines[#lines + 1] = string.format("  Tilepoints: %dx%d", map.terrain.width, map.terrain.height)
        lines[#lines + 1] = string.format("  Height range: %.1f to %.1f",
            stats.min_height, stats.max_height)
        lines[#lines + 1] = string.format("  Water tiles: %d", stats.water_count)
        lines[#lines + 1] = string.format("  Blight tiles: %d", stats.blight_count)
    else
        lines[#lines + 1] = "Terrain: Not loaded"
    end
    lines[#lines + 1] = ""

    -- Strings
    if map.strings then
        lines[#lines + 1] = string.format("String Table: %d strings", map.strings:count())
    else
        lines[#lines + 1] = "String Table: Not loaded"
    end

    return table.concat(lines, "\n")
end
-- }}}
-- }}}

-- {{{ Module exports
local data = {}
data.Map = Map
data.PLAYER_COLORS = PLAYER_COLORS
data.format = format

-- {{{ load
-- Convenience function to load a map.
function data.load(path)
    return Map.load(path)
end
-- }}}
-- }}}

return data
