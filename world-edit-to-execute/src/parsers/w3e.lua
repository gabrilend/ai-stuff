-- W3E (Terrain) Parser
-- Parses war3map.w3e terrain files containing height maps, textures, cliffs, and water.
-- Each tilepoint is 7 bytes with complex bit-level encoding.

local compat = require("compat")
local band, rshift = compat.band, compat.rshift

local w3e = {}

-- {{{ Constants
local MAGIC = "W3E!"
local EXPECTED_VERSION = 11
local TILEPOINT_SIZE = 7

-- Tileset names
local TILESETS = {
    ['A'] = "ashenvale",
    ['B'] = "barrens",
    ['C'] = "felwood",
    ['D'] = "dungeon",
    ['F'] = "lordaeron_fall",
    ['G'] = "underground",
    ['I'] = "icecrown",
    ['J'] = "dalaran_ruins",
    ['K'] = "black_citadel",
    ['L'] = "lordaeron_summer",
    ['N'] = "northrend",
    ['O'] = "outland",
    ['Q'] = "village_fall",
    ['V'] = "village",
    ['W'] = "lordaeron_winter",
    ['X'] = "dalaran",
    ['Y'] = "cityscape",
    ['Z'] = "sunken_ruins",
}
-- }}}

-- {{{ Height/Water decoding
-- {{{ decode_height
-- Convert raw height to world units.
-- Formula: (raw - 8192) / 4
local function decode_height(raw)
    return (raw - 8192) / 4.0
end
-- }}}

-- {{{ decode_water
-- Extract water level and boundary flags from 16-bit value.
-- Bits 0-13: water level
-- Bits 14-15: boundary flags
local function decode_water(raw)
    local level = band(raw, 0x3FFF)  -- Lower 14 bits
    local boundary = band(raw, 0xC000) ~= 0  -- Upper 2 bits
    return {
        raw = level,
        level = (level - 8192) / 4.0,
        boundary = boundary
    }
end
-- }}}
-- }}}

-- {{{ Tilepoint parsing
-- {{{ parse_tilepoint
-- Parse a single 7-byte tilepoint.
local function parse_tilepoint(data, pos)
    local tp = {}

    -- Bytes 0-1: Ground height (int16)
    local height_raw = compat.unpack_int16(data, pos)
    tp.height_raw = height_raw
    tp.height = decode_height(height_raw)

    -- Bytes 2-3: Water level + boundary (uint16)
    local water_raw = compat.unpack_uint16(data, pos + 2)
    local water = decode_water(water_raw)
    tp.water_raw = water.raw
    tp.water_level = water.level
    tp.boundary = water.boundary
    tp.water_flags = band(water_raw, 0xC000)   -- (kept for writing back: issue 911a)

    -- Byte 4: Ground texture (low nibble) + Flags (high nibble: 0x10 ramp,
    -- 0x20 blight, 0x40 water, 0x80 boundary). Until issue 517 these two
    -- nibbles were read the other way round (see its notes for the check).
    local byte4 = data:byte(pos + 4)
    tp.ground_texture = band(byte4, 0x0F)
    tp.is_ramp = band(byte4, 0x10) ~= 0
    tp.is_blight = band(byte4, 0x20) ~= 0
    tp.has_water = band(byte4, 0x40) ~= 0
    tp.is_boundary = band(byte4, 0x80) ~= 0

    -- Byte 5: Texture details (5 bits) + Cliff variation (3 bits)
    local byte5 = data:byte(pos + 5)
    tp.texture_details = band(byte5, 0x1F)
    tp.cliff_variation = band(rshift(byte5, 5), 0x07)

    -- Byte 6: Layer height (low nibble; 2 is the usual ground level) +
    -- Cliff texture (high nibble; 15 = none). Also swapped until issue 517.
    local byte6 = data:byte(pos + 6)
    tp.layer_height = band(byte6, 0x0F)
    tp.cliff_texture = band(rshift(byte6, 4), 0x0F)

    return tp
end
-- }}}
-- }}}

-- {{{ Header parsing
-- {{{ parse_header
-- Parse w3e header and return (header, next_position).
local function parse_header(data)
    local pos = 1
    local header = {}

    -- Magic number
    local magic = data:sub(pos, pos + 3)
    if magic ~= MAGIC then
        error(string.format("Invalid w3e magic: expected '%s', got '%s'", MAGIC, magic))
    end
    pos = pos + 4

    -- Version
    header.version = compat.unpack_int32(data, pos)
    pos = pos + 4
    if header.version ~= EXPECTED_VERSION then
        -- Warning but continue - might work with different versions
    end

    -- Main tileset
    header.tileset_code = data:sub(pos, pos)
    header.tileset = TILESETS[header.tileset_code] or ("unknown_" .. header.tileset_code)
    pos = pos + 1

    -- Custom tileset flag
    header.custom_tileset = compat.unpack_int32(data, pos) ~= 0
    pos = pos + 4

    -- Ground tilesets
    local ground_count = compat.unpack_int32(data, pos)
    pos = pos + 4
    header.ground_tilesets = {}
    for i = 1, ground_count do
        header.ground_tilesets[i] = data:sub(pos, pos + 3)
        pos = pos + 4
    end

    -- Cliff tilesets
    local cliff_count = compat.unpack_int32(data, pos)
    pos = pos + 4
    header.cliff_tilesets = {}
    for i = 1, cliff_count do
        header.cliff_tilesets[i] = data:sub(pos, pos + 3)
        pos = pos + 4
    end

    -- Dimensions (stored as width+1, height+1 = tilepoint count)
    header.width = compat.unpack_int32(data, pos)
    pos = pos + 4
    header.height = compat.unpack_int32(data, pos)
    pos = pos + 4

    -- Center offset
    header.offset_x = compat.unpack_float(data, pos)
    pos = pos + 4
    header.offset_y = compat.unpack_float(data, pos)
    pos = pos + 4

    return header, pos
end
-- }}}
-- }}}

-- {{{ Terrain class
local Terrain = {}
Terrain.__index = Terrain

-- {{{ new
-- Create a new Terrain object (internal use).
function Terrain.new()
    local self = setmetatable({}, Terrain)
    self.version = 0
    self.tileset = ""
    self.tileset_code = ""
    self.width = 0
    self.height = 0
    self.offset_x = 0
    self.offset_y = 0
    self.ground_tilesets = {}
    self.cliff_tilesets = {}
    self.tilepoints = {}
    return self
end
-- }}}

-- {{{ get_tile
-- Get tilepoint at (x, y). Returns nil if out of bounds.
function Terrain:get_tile(x, y)
    if x < 0 or x >= self.width or y < 0 or y >= self.height then
        return nil
    end
    return self.tilepoints[y] and self.tilepoints[y][x]
end
-- }}}

-- {{{ get_height
-- Get height at (x, y) in world units.
function Terrain:get_height(x, y)
    local tp = self:get_tile(x, y)
    return tp and tp.height or nil
end
-- }}}

-- {{{ get_texture
-- Get ground texture index at (x, y).
function Terrain:get_texture(x, y)
    local tp = self:get_tile(x, y)
    return tp and tp.ground_texture or nil
end
-- }}}

-- {{{ get_texture_name
-- Get ground texture name at (x, y).
function Terrain:get_texture_name(x, y)
    local idx = self:get_texture(x, y)
    if idx and self.ground_tilesets[idx + 1] then
        return self.ground_tilesets[idx + 1]
    end
    return nil
end
-- }}}

-- {{{ is_walkable
-- Check if tilepoint is walkable (not water, cliff, or boundary).
function Terrain:is_walkable(x, y)
    local tp = self:get_tile(x, y)
    if not tp then
        return false
    end
    -- Not walkable if: has water, is boundary, or is a cliff edge
    if tp.has_water or tp.boundary or tp.is_boundary then
        return false
    end
    -- Check for cliff edges (different layer heights with neighbors)
    -- This is a simplified check - full cliff detection is more complex
    return true
end
-- }}}

-- {{{ is_water
-- Check if tilepoint has water.
function Terrain:is_water(x, y)
    local tp = self:get_tile(x, y)
    return tp and tp.has_water or false
end
-- }}}

-- {{{ get_layer
-- Get cliff layer height at (x, y).
function Terrain:get_layer(x, y)
    local tp = self:get_tile(x, y)
    return tp and tp.layer_height or nil
end
-- }}}

-- {{{ tile_to_world
-- Convert tile coordinates to world coordinates.
function Terrain:tile_to_world(x, y)
    return {
        x = x * 128 + self.offset_x,
        y = y * 128 + self.offset_y
    }
end
-- }}}

-- {{{ world_to_tile
-- Convert world coordinates to tile coordinates.
function Terrain:world_to_tile(wx, wy)
    return {
        x = math.floor((wx - self.offset_x) / 128),
        y = math.floor((wy - self.offset_y) / 128)
    }
end
-- }}}

-- {{{ stats
-- Get terrain statistics.
function Terrain:stats()
    local water_count = 0
    local blight_count = 0
    local ramp_count = 0
    local boundary_count = 0
    local min_height = math.huge
    local max_height = -math.huge
    local layer_counts = {}

    for y = 0, self.height - 1 do
        for x = 0, self.width - 1 do
            local tp = self.tilepoints[y][x]
            if tp.has_water then water_count = water_count + 1 end
            if tp.is_blight then blight_count = blight_count + 1 end
            if tp.is_ramp then ramp_count = ramp_count + 1 end
            if tp.boundary or tp.is_boundary then boundary_count = boundary_count + 1 end
            if tp.height < min_height then min_height = tp.height end
            if tp.height > max_height then max_height = tp.height end
            layer_counts[tp.layer_height] = (layer_counts[tp.layer_height] or 0) + 1
        end
    end

    return {
        total_tilepoints = self.width * self.height,
        water_count = water_count,
        blight_count = blight_count,
        ramp_count = ramp_count,
        boundary_count = boundary_count,
        min_height = min_height,
        max_height = max_height,
        layer_counts = layer_counts,
    }
end
-- }}}
-- }}}

-- {{{ Main parse function
-- {{{ parse
-- Parse w3e data and return a Terrain object.
function w3e.parse(data)
    local terrain = Terrain.new()

    -- Parse header
    local header, pos = parse_header(data)

    terrain.version = header.version
    terrain.tileset = header.tileset
    terrain.tileset_code = header.tileset_code
    terrain.custom_tileset = header.custom_tileset
    terrain.width = header.width
    terrain.height = header.height
    terrain.offset_x = header.offset_x
    terrain.offset_y = header.offset_y
    terrain.ground_tilesets = header.ground_tilesets
    terrain.cliff_tilesets = header.cliff_tilesets

    -- Calculate expected data size
    local expected_size = pos - 1 + (header.width * header.height * TILEPOINT_SIZE)
    if #data < expected_size then
        error(string.format("w3e data too short: expected %d bytes, got %d",
            expected_size, #data))
    end

    -- Parse tilepoints
    terrain.tilepoints = {}
    for y = 0, header.height - 1 do
        terrain.tilepoints[y] = {}
        for x = 0, header.width - 1 do
            terrain.tilepoints[y][x] = parse_tilepoint(data, pos)
            pos = pos + TILEPOINT_SIZE
        end
    end

    return terrain
end
-- }}}
-- }}}

-- {{{ w3e.write (issue 911a)
-- The terrain back as war3map.w3e bytes. Heights and water levels are
-- written from tp.height and tp.water_level (world units), so an editor
-- changes those; the rest from the fields the parser reads.
function w3e.write(terrain)
    local b = require("parsers.binwrite").new()
    b:str(MAGIC):i32(terrain.version or EXPECTED_VERSION)
    b:str(terrain.tileset_code ~= "" and terrain.tileset_code or "L")
    b:i32(terrain.custom_tileset and 1 or 0)
    b:i32(#terrain.ground_tilesets)
    for _, t in ipairs(terrain.ground_tilesets) do b:str(t) end
    b:i32(#terrain.cliff_tilesets)
    for _, t in ipairs(terrain.cliff_tilesets) do b:str(t) end
    b:i32(terrain.width):i32(terrain.height)
    b:f32(terrain.offset_x):f32(terrain.offset_y)
    local function raw(world) return math.floor(world * 4 + 8192 + 0.5) end
    for y = 0, terrain.height - 1 do
        local row = terrain.tilepoints[y]
        for x = 0, terrain.width - 1 do
            local tp = row[x]
            b:i16(raw(tp.height))
            b:u16(raw(tp.water_level) % 0x4000 + (tp.water_flags or (tp.boundary and 0x4000 or 0)))
            local flags = tp.ground_texture % 16
                + (tp.is_ramp and 0x10 or 0) + (tp.is_blight and 0x20 or 0)
                + (tp.has_water and 0x40 or 0) + (tp.is_boundary and 0x80 or 0)
            b:u8(flags)
            b:u8(tp.texture_details % 32 + (tp.cliff_variation % 8) * 32)
            b:u8(tp.layer_height % 16 + (tp.cliff_texture % 16) * 16)
        end
    end
    return b:done()
end
-- }}}

-- {{{ Format function
-- {{{ format
-- Format terrain info for display.
function w3e.format(terrain)
    local lines = {}

    lines[#lines + 1] = "=== Terrain Info ==="
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("Version: %d", terrain.version)
    lines[#lines + 1] = string.format("Tileset: %s (%s)", terrain.tileset, terrain.tileset_code)
    lines[#lines + 1] = string.format("Custom tileset: %s", terrain.custom_tileset and "yes" or "no")
    lines[#lines + 1] = string.format("Dimensions: %dx%d tilepoints", terrain.width, terrain.height)
    lines[#lines + 1] = string.format("Tiles: %dx%d", terrain.width - 1, terrain.height - 1)
    lines[#lines + 1] = string.format("Center offset: (%.1f, %.1f)", terrain.offset_x, terrain.offset_y)
    lines[#lines + 1] = ""

    -- Ground tilesets
    lines[#lines + 1] = string.format("Ground tilesets (%d):", #terrain.ground_tilesets)
    for i, ts in ipairs(terrain.ground_tilesets) do
        lines[#lines + 1] = string.format("  [%d] %s", i - 1, ts)
    end
    lines[#lines + 1] = ""

    -- Cliff tilesets
    lines[#lines + 1] = string.format("Cliff tilesets (%d):", #terrain.cliff_tilesets)
    for i, ts in ipairs(terrain.cliff_tilesets) do
        lines[#lines + 1] = string.format("  [%d] %s", i - 1, ts)
    end
    lines[#lines + 1] = ""

    -- Statistics
    local stats = terrain:stats()
    lines[#lines + 1] = "Statistics:"
    lines[#lines + 1] = string.format("  Total tilepoints: %d", stats.total_tilepoints)
    lines[#lines + 1] = string.format("  Height range: %.1f to %.1f", stats.min_height, stats.max_height)
    lines[#lines + 1] = string.format("  Water tiles: %d", stats.water_count)
    lines[#lines + 1] = string.format("  Blight tiles: %d", stats.blight_count)
    lines[#lines + 1] = string.format("  Ramp tiles: %d", stats.ramp_count)
    lines[#lines + 1] = string.format("  Boundary tiles: %d", stats.boundary_count)

    -- Layer distribution
    lines[#lines + 1] = "  Cliff layers:"
    local layers = {}
    for layer, count in pairs(stats.layer_counts) do
        layers[#layers + 1] = layer
    end
    table.sort(layers)
    for _, layer in ipairs(layers) do
        local count = stats.layer_counts[layer]
        local pct = count / stats.total_tilepoints * 100
        lines[#lines + 1] = string.format("    Layer %d: %d (%.1f%%)", layer, count, pct)
    end

    return table.concat(lines, "\n")
end
-- }}}
-- }}}

-- {{{ Heights in the world
-- WC3 z of a tilepoint's ground: its height plus 128 for each cliff layer
-- above layer 2 (the usual ground level)
function w3e.ground_z(tp)
    return tp.height + (tp.layer_height - 2) * 128
end

-- WC3 z of a tilepoint's water surface. The 89.6 drop is the offset map
-- tools use between the stored level and the drawn surface; with it the
-- test maps' water meets their coastlines (issue 517).
w3e.WATER_OFFSET = 89.6
function w3e.water_z(tp)
    return tp.water_level - w3e.WATER_OFFSET
end

-- True where water shows: the water flag is set and its surface is above
-- the ground
function w3e.is_wet(tp)
    return tp.has_water and w3e.water_z(tp) > w3e.ground_z(tp)
end
-- }}}

-- {{{ Module exports
w3e.Terrain = Terrain
w3e.decode_height = decode_height
w3e.decode_water = decode_water
w3e.TILESETS = TILESETS
-- }}}

return w3e
