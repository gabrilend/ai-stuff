-- war3map.doo Parser
-- Parses WC3 doodad/destructible placement files.
-- Doodads include trees, rocks, and other map decorations.
-- Compatible with both LuaJIT and Lua 5.3+.

local compat = require("compat")

local doo = {}

-- {{{ Constants
local FILE_ID = "W3do"

-- Doodad visibility/collision flags
local DOODAD_FLAGS = {
    [0] = "invisible_non_solid",  -- Not rendered, no collision
    [1] = "visible_non_solid",    -- Rendered but no collision
    [2] = "normal",               -- Rendered with collision (default)
}

-- Common doodad type IDs for reference
local COMMON_DOODADS = {
    -- Trees
    LTlt = "Lordaeron Summer Tree",
    ATtr = "Ashenvale Tree",
    BTtw = "Barrens Twig",
    CTtr = "Cityscape Tree",
    FTtw = "Felwood Tree",
    NTtw = "Northrend Tree",
    WTtw = "Underground Tree",
    ZTtw = "Dungeon Tree",
    -- Destructibles
    LTbr = "Lordaeron Barrel",
    LTcr = "Lordaeron Crate",
}
-- }}}

-- {{{ Binary reading utilities
local function read_int32(data, pos)
    return compat.unpack_int32(data, pos)
end

local function read_uint32(data, pos)
    return compat.unpack_uint32(data, pos)
end

local function read_float32(data, pos)
    return compat.unpack_float(data, pos)
end

local function read_byte(data, pos)
    return data:byte(pos), pos + 1
end

local function read_id(data, pos)
    -- Read 4-character ID string
    return data:sub(pos, pos + 3), pos + 4
end
-- }}}

-- {{{ parse_doodad_entry
-- Parses a single doodad entry.
-- Version 7: 42 bytes per entry
-- Version 8: 50 bytes per entry (adds item_table_pointer and item_sets_count)
-- Returns the doodad table and the next read position.
local function parse_doodad_entry(data, pos, version)
    local doodad = {}

    -- Type ID (4 chars)
    doodad.id, pos = read_id(data, pos)
    doodad.name = COMMON_DOODADS[doodad.id]  -- May be nil for unknown types

    -- Variation index
    doodad.variation = read_int32(data, pos); pos = pos + 4

    -- Position (X, Y, Z floats)
    doodad.position = {
        x = read_float32(data, pos),
        y = read_float32(data, pos + 4),
        z = read_float32(data, pos + 8),
    }
    pos = pos + 12

    -- Rotation angle in radians
    doodad.angle = read_float32(data, pos); pos = pos + 4

    -- Scale (X, Y, Z floats)
    doodad.scale = {
        x = read_float32(data, pos),
        y = read_float32(data, pos + 4),
        z = read_float32(data, pos + 8),
    }
    pos = pos + 12

    -- Flags (1 byte)
    local flags_raw
    flags_raw, pos = read_byte(data, pos)
    doodad.flags = flags_raw
    doodad.flags_name = DOODAD_FLAGS[flags_raw] or ("unknown_" .. flags_raw)

    -- Life percentage (1 byte, 100 = 100%)
    local life_raw
    life_raw, pos = read_byte(data, pos)
    doodad.life = life_raw

    -- Creation number (unique editor ID)
    doodad.creation_number = read_int32(data, pos); pos = pos + 4

    -- Version 8+ has additional fields
    if version >= 8 then
        -- Item table pointer (-1 if none, otherwise index into item drop table)
        doodad.item_table_pointer = read_int32(data, pos); pos = pos + 4
        -- Number of item sets dropped
        doodad.item_sets_count = read_int32(data, pos); pos = pos + 4
    end

    return doodad, pos
end
-- }}}

-- {{{ parse_special_doodads
-- Parses the special doodads section.
-- Version 7: Variable-length item drop tables
-- Version 8: Fixed 16-byte entries (ID + 3 int32s for position/reference data)
-- Returns the special doodads array and next position.
local function parse_special_doodads(data, pos, doo_version)
    local special = {}

    -- Check if we have enough data for the header
    if pos + 8 > #data + 1 then
        return special, pos  -- No special doodads section
    end

    -- Special doodads version
    local version = read_int32(data, pos); pos = pos + 4
    special.version = version

    -- Number of special doodads
    local count = read_int32(data, pos); pos = pos + 4
    special.doodads = {}

    -- Version 8+ uses fixed-size entries (16 bytes each)
    if doo_version >= 8 then
        for i = 1, count do
            local sd = {}
            sd.id, pos = read_id(data, pos)
            -- Three int32 values - exact meaning unclear, possibly position/reference
            sd.unknown1 = read_int32(data, pos); pos = pos + 4
            sd.x = read_int32(data, pos); pos = pos + 4
            sd.y = read_int32(data, pos); pos = pos + 4
            special.doodads[i] = sd
        end
    else
        -- Version 7: Variable-length item drop tables
        for i = 1, count do
            local sd = {}

            -- Doodad ID that has item drops
            sd.id, pos = read_id(data, pos)

            -- Number of item sets
            local num_sets = read_int32(data, pos); pos = pos + 4
            sd.item_sets = {}

            for j = 1, num_sets do
                local item_set = {}

                -- Number of items in this set
                local num_items = read_int32(data, pos); pos = pos + 4
                item_set.items = {}

                for k = 1, num_items do
                    local item = {}
                    item.id, pos = read_id(data, pos)
                    item.chance = read_int32(data, pos); pos = pos + 4
                    item_set.items[k] = item
                end

                sd.item_sets[j] = item_set
            end

            special.doodads[i] = sd
        end
    end

    return special, pos
end
-- }}}

-- {{{ doo.parse
-- Parses a war3map.doo file.
-- data: raw binary data string
-- Returns: structured doodad table, or nil and error message
function doo.parse(data)
    if not data or #data < 16 then
        return nil, "Invalid data: too short (need at least 16 bytes for header)"
    end

    local pos = 1
    local result = {}

    -- File ID check
    local file_id = data:sub(pos, pos + 3)
    if file_id ~= FILE_ID then
        return nil, string.format("Invalid file ID: expected '%s', got '%s'", FILE_ID, file_id)
    end
    pos = pos + 4

    -- Version
    result.version = read_int32(data, pos); pos = pos + 4

    -- Subversion
    result.subversion = read_int32(data, pos); pos = pos + 4

    -- Number of doodads
    local doodad_count = read_int32(data, pos); pos = pos + 4

    -- Version validation
    if result.version ~= 7 and result.version ~= 8 then
        result._version_warning = string.format(
            "Unexpected doo version %d (expected 7 or 8)", result.version)
    end

    -- Calculate bytes per doodad based on version
    local bytes_per_doodad = (result.version >= 8) and 50 or 42

    -- Parse doodad entries
    result.doodads = {}
    for i = 1, doodad_count do
        -- Check bounds before parsing
        if pos + bytes_per_doodad - 1 > #data then
            return nil, string.format(
                "Unexpected end of data at doodad %d/%d (pos %d, size %d, need %d bytes)",
                i, doodad_count, pos, #data, bytes_per_doodad)
        end

        local doodad, new_pos = parse_doodad_entry(data, pos, result.version)
        result.doodads[i] = doodad
        pos = new_pos
    end

    -- Parse special doodads section (item drops for v7, position data for v8)
    if pos <= #data then
        local special, new_pos = parse_special_doodads(data, pos, result.version)
        result.special_doodads = special
        pos = new_pos
    else
        result.special_doodads = { version = 0, doodads = {} }
    end

    return result
end
-- }}}

-- {{{ doo.format
-- Returns a human-readable summary of the doodad data.
function doo.format(result)
    local lines = {}

    lines[#lines + 1] = "=== Doodads (war3map.doo) ==="
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("Version: %d, Subversion: %d",
        result.version, result.subversion)
    lines[#lines + 1] = string.format("Doodad count: %d", #result.doodads)

    if result._version_warning then
        lines[#lines + 1] = "Warning: " .. result._version_warning
    end
    lines[#lines + 1] = ""

    -- Count doodads by type
    local type_counts = {}
    for _, d in ipairs(result.doodads) do
        type_counts[d.id] = (type_counts[d.id] or 0) + 1
    end

    -- Sort types by count
    local sorted_types = {}
    for id, count in pairs(type_counts) do
        sorted_types[#sorted_types + 1] = { id = id, count = count }
    end
    table.sort(sorted_types, function(a, b) return a.count > b.count end)

    lines[#lines + 1] = "Doodad types:"
    local max_types = math.min(10, #sorted_types)
    for i = 1, max_types do
        local t = sorted_types[i]
        local name = COMMON_DOODADS[t.id] or ""
        if name ~= "" then name = " (" .. name .. ")" end
        lines[#lines + 1] = string.format("  %s: %d%s", t.id, t.count, name)
    end
    if #sorted_types > max_types then
        lines[#lines + 1] = string.format("  ... and %d more types",
            #sorted_types - max_types)
    end
    lines[#lines + 1] = ""

    -- Show first few doodads
    lines[#lines + 1] = "Sample doodads:"
    local max_samples = math.min(5, #result.doodads)
    for i = 1, max_samples do
        local d = result.doodads[i]
        lines[#lines + 1] = string.format(
            "  [%d] %s at (%.1f, %.1f, %.1f) angle=%.2f scale=(%.1f,%.1f,%.1f) life=%d%%",
            d.creation_number, d.id,
            d.position.x, d.position.y, d.position.z,
            d.angle,
            d.scale.x, d.scale.y, d.scale.z,
            d.life)
    end
    if #result.doodads > max_samples then
        lines[#lines + 1] = string.format("  ... and %d more doodads",
            #result.doodads - max_samples)
    end
    lines[#lines + 1] = ""

    -- Special doodads (item drops)
    if result.special_doodads and #result.special_doodads.doodads > 0 then
        lines[#lines + 1] = string.format("Special doodads (with item drops): %d",
            #result.special_doodads.doodads)
        for i, sd in ipairs(result.special_doodads.doodads) do
            if i > 5 then
                lines[#lines + 1] = string.format("  ... and %d more",
                    #result.special_doodads.doodads - 5)
                break
            end
            local total_items = 0
            for _, set in ipairs(sd.item_sets) do
                total_items = total_items + #set.items
            end
            lines[#lines + 1] = string.format("  %s: %d item sets, %d items total",
                sd.id, #sd.item_sets, total_items)
        end
    else
        lines[#lines + 1] = "Special doodads: none"
    end

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ DoodadTable class
local DoodadTable = {}
DoodadTable.__index = DoodadTable

-- {{{ new
-- Create a new DoodadTable from doo content.
function DoodadTable.new(doo_data)
    local self = setmetatable({}, DoodadTable)
    self.doodads = {}
    self.by_creation_number = {}
    self.by_type = {}
    self.version = 7
    self.subversion = 0
    self.special_doodads = {}
    if doo_data then
        self:load(doo_data)
    end
    return self
end
-- }}}

-- {{{ load
-- Load doodads from doo binary data.
function DoodadTable:load(doo_data)
    local result, err = doo.parse(doo_data)
    if not result then
        error("Failed to parse doo: " .. tostring(err))
    end

    self.version = result.version
    self.subversion = result.subversion
    self.doodads = result.doodads
    self.special_doodads = result.special_doodads

    -- Build lookup indices
    self.by_creation_number = {}
    self.by_type = {}

    for _, d in ipairs(self.doodads) do
        -- Index by creation number (unique ID)
        self.by_creation_number[d.creation_number] = d

        -- Index by type ID
        if not self.by_type[d.id] then
            self.by_type[d.id] = {}
        end
        self.by_type[d.id][#self.by_type[d.id] + 1] = d
    end
end
-- }}}

-- {{{ get
-- Get a doodad by its creation number. Returns nil if not found.
function DoodadTable:get(creation_number)
    return self.by_creation_number[creation_number]
end
-- }}}

-- {{{ get_by_type
-- Get all doodads of a specific type. Returns empty table if none found.
function DoodadTable:get_by_type(type_id)
    return self.by_type[type_id] or {}
end
-- }}}

-- {{{ count
-- Return the total number of doodads.
function DoodadTable:count()
    return #self.doodads
end
-- }}}

-- {{{ count_by_type
-- Return the number of doodads of a specific type.
function DoodadTable:count_by_type(type_id)
    local list = self.by_type[type_id]
    return list and #list or 0
end
-- }}}

-- {{{ types
-- Return a list of all unique doodad type IDs.
function DoodadTable:types()
    local result = {}
    for type_id, _ in pairs(self.by_type) do
        result[#result + 1] = type_id
    end
    table.sort(result)
    return result
end
-- }}}

-- {{{ pairs
-- Iterate over all doodads (index, doodad).
function DoodadTable:pairs()
    return ipairs(self.doodads)
end
-- }}}

-- {{{ in_bounds
-- Find all doodads within a rectangular region.
-- Returns a table of doodads where min_x <= x <= max_x and min_y <= y <= max_y.
function DoodadTable:in_bounds(min_x, min_y, max_x, max_y)
    local result = {}
    for _, d in ipairs(self.doodads) do
        local x, y = d.position.x, d.position.y
        if x >= min_x and x <= max_x and y >= min_y and y <= max_y then
            result[#result + 1] = d
        end
    end
    return result
end
-- }}}
-- }}}

-- {{{ Module interface
doo.DoodadTable = DoodadTable
doo.DOODAD_FLAGS = DOODAD_FLAGS
doo.COMMON_DOODADS = COMMON_DOODADS
doo.FILE_ID = FILE_ID

-- {{{ new
-- Convenience function to create a DoodadTable.
function doo.new(data)
    return DoodadTable.new(data)
end
-- }}}
-- }}}

return doo
