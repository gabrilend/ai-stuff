-- war3map.w3i Parser
-- Parses WC3 map info files containing metadata: name, players, forces, etc.
-- Supports Frozen Throne (version 25) and Reign of Chaos (version 18) formats.
-- Compatible with both LuaJIT and Lua 5.3+.

local compat = require("compat")
local band, lshift, rshift = compat.band, compat.lshift, compat.rshift

local w3i = {}

-- {{{ Constants
local PLAYER_TYPES = {
    [1] = "human",
    [2] = "computer",
    [3] = "neutral",
    [4] = "rescuable",
}

local RACE_TYPES = {
    [0] = "selectable",
    [1] = "human",
    [2] = "orc",
    [3] = "undead",
    [4] = "night_elf",
    [5] = "selectable",
}

local TILESETS = {
    A = "ashenvale",
    B = "barrens",
    C = "felwood",
    D = "dungeon",
    F = "lordaeron_fall",
    G = "underground",
    I = "icecrown",
    J = "dalaran_ruins",
    K = "black_citadel",
    L = "lordaeron_summer",
    N = "northrend",
    O = "outland",
    Q = "village_fall",
    V = "village",
    W = "lordaeron_winter",
    X = "dalaran",
    Y = "cityscape",
    Z = "sunken_ruins",
}

local MAP_FLAGS = {
    HIDE_MINIMAP           = 0x0001,
    MODIFY_ALLY_PRIORITIES = 0x0002,
    MELEE_MAP              = 0x0004,
    LARGE_NEVER_REDUCED    = 0x0008,
    MASKED_PARTIAL_VISIBLE = 0x0010,
    FIXED_PLAYER_SETTINGS  = 0x0020,
    USE_CUSTOM_FORCES      = 0x0040,
    USE_CUSTOM_TECHTREE    = 0x0080,
    USE_CUSTOM_ABILITIES   = 0x0100,
    USE_CUSTOM_UPGRADES    = 0x0200,
    PROPERTIES_OPENED      = 0x0400,
    SHOW_WAVES_CLIFF       = 0x0800,
    SHOW_WAVES_ROLLING     = 0x1000,
}

local FORCE_FLAGS = {
    ALLIED            = 0x0001,
    ALLIED_VICTORY    = 0x0002,
    SHARE_VISION      = 0x0004,
    SHARE_UNIT_CONTROL = 0x0008,
    SHARE_ADV_CONTROL = 0x0010,
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

local function read_string(data, pos)
    local str_end = data:find("\0", pos, true)
    if not str_end then
        return "", pos
    end
    return data:sub(pos, str_end - 1), str_end + 1
end

local function read_char4(data, pos)
    return data:sub(pos, pos + 3), pos + 4
end
-- }}}

-- {{{ parse_flags
-- Parses a bitmask into a table of boolean flags.
local function parse_map_flags(value)
    local flags = { raw = value }
    for name, flag_bit in pairs(MAP_FLAGS) do
        flags[name:lower()] = band(value, flag_bit) ~= 0
    end
    return flags
end

local function parse_force_flags(value)
    local flags = { raw = value }
    for name, flag_bit in pairs(FORCE_FLAGS) do
        flags[name:lower()] = band(value, flag_bit) ~= 0
    end
    return flags
end
-- }}}

-- {{{ parse_players
-- Parses player slot definitions.
local function parse_players(data, pos)
    local count = read_int32(data, pos)
    pos = pos + 4

    local players = {}
    for i = 1, count do
        local player = {}

        player.number = read_int32(data, pos); pos = pos + 4
        local type_id = read_int32(data, pos); pos = pos + 4
        player.type = PLAYER_TYPES[type_id] or ("unknown_" .. type_id)
        local race_id = read_int32(data, pos); pos = pos + 4
        player.race = RACE_TYPES[race_id] or ("unknown_" .. race_id)
        player.fixed_start = read_int32(data, pos) == 1; pos = pos + 4
        player.name, pos = read_string(data, pos)
        player.start_x = read_float32(data, pos); pos = pos + 4
        player.start_y = read_float32(data, pos); pos = pos + 4
        player.ally_low = read_uint32(data, pos); pos = pos + 4
        player.ally_high = read_uint32(data, pos); pos = pos + 4

        players[i] = player
    end

    return players, pos
end
-- }}}

-- {{{ parse_forces
-- Parses force/team definitions.
local function parse_forces(data, pos)
    local count = read_int32(data, pos)
    pos = pos + 4

    local forces = {}
    for i = 1, count do
        local force = {}

        local flags = read_uint32(data, pos); pos = pos + 4
        force.flags = parse_force_flags(flags)
        force.player_mask = read_uint32(data, pos); pos = pos + 4
        force.name, pos = read_string(data, pos)

        -- Decode player mask into list
        force.players = {}
        for p = 0, 27 do
            if band(force.player_mask, lshift(1, p)) ~= 0 then
                force.players[#force.players + 1] = p
            end
        end

        forces[i] = force
    end

    return forces, pos
end
-- }}}

-- {{{ parse_upgrades
-- Parses upgrade availability (TFT only).
local function parse_upgrades(data, pos)
    local count = read_int32(data, pos)
    pos = pos + 4

    local upgrades = {}
    for i = 1, count do
        local upgrade = {}
        upgrade.player_mask = read_uint32(data, pos); pos = pos + 4
        upgrade.id, pos = read_char4(data, pos)
        upgrade.level = read_int32(data, pos); pos = pos + 4
        upgrade.availability = read_int32(data, pos); pos = pos + 4
        upgrades[i] = upgrade
    end

    return upgrades, pos
end
-- }}}

-- {{{ parse_tech
-- Parses tech availability (TFT only).
local function parse_tech(data, pos)
    local count = read_int32(data, pos)
    pos = pos + 4

    local tech = {}
    for i = 1, count do
        local entry = {}
        entry.player_mask = read_uint32(data, pos); pos = pos + 4
        entry.id, pos = read_char4(data, pos)
        tech[i] = entry
    end

    return tech, pos
end
-- }}}

-- {{{ parse_random_unit_tables
-- Parses random unit tables (TFT only).
local function parse_random_unit_tables(data, pos)
    local count = read_int32(data, pos)
    pos = pos + 4

    local tables = {}
    for i = 1, count do
        local tbl = {}
        tbl.number = read_int32(data, pos); pos = pos + 4
        tbl.name, pos = read_string(data, pos)

        local position_count = read_int32(data, pos); pos = pos + 4
        tbl.positions = {}

        for j = 1, position_count do
            local position = {}
            position.type = read_int32(data, pos); pos = pos + 4

            local unit_count = read_int32(data, pos); pos = pos + 4
            position.units = {}

            for k = 1, unit_count do
                local unit = {}
                unit.id, pos = read_char4(data, pos)
                unit.chance = read_int32(data, pos); pos = pos + 4
                position.units[k] = unit
            end

            tbl.positions[j] = position
        end

        tables[i] = tbl
    end

    return tables, pos
end
-- }}}

-- {{{ parse_random_item_tables
-- Parses random item tables (TFT only).
local function parse_random_item_tables(data, pos)
    local count = read_int32(data, pos)
    pos = pos + 4

    local tables = {}
    for i = 1, count do
        local tbl = {}
        tbl.number = read_int32(data, pos); pos = pos + 4
        tbl.name, pos = read_string(data, pos)

        local set_count = read_int32(data, pos); pos = pos + 4
        tbl.sets = {}

        for j = 1, set_count do
            local set = {}
            local item_count = read_int32(data, pos); pos = pos + 4
            set.items = {}

            for k = 1, item_count do
                local item = {}
                item.id, pos = read_char4(data, pos)
                item.chance = read_int32(data, pos); pos = pos + 4
                set.items[k] = item
            end

            tbl.sets[j] = set
        end

        tables[i] = tbl
    end

    return tables, pos
end
-- }}}

-- {{{ w3i.parse
-- Parses a war3map.w3i file.
-- data: raw binary data string
-- Returns: structured map info table, or nil and error message
function w3i.parse(data)
    if not data or #data < 12 then
        return nil, "Invalid data: too short"
    end

    local pos = 1
    local map = {}

    -- Header
    map.version = read_int32(data, pos); pos = pos + 4
    map.saves = read_int32(data, pos); pos = pos + 4
    map.editor_version = read_int32(data, pos); pos = pos + 4

    -- Version check
    if map.version ~= 18 and map.version ~= 25 and map.version ~= 28 and map.version ~= 31 then
        -- Allow parsing but note unknown version
        map._version_warning = "Unknown w3i version: " .. map.version
    end

    -- Strings
    map.name, pos = read_string(data, pos)
    map.author, pos = read_string(data, pos)
    map.description, pos = read_string(data, pos)
    map.players_recommended, pos = read_string(data, pos)

    -- Camera bounds (8 floats)
    map.camera_bounds = {}
    for i = 1, 8 do
        map.camera_bounds[i] = read_float32(data, pos); pos = pos + 4
    end

    -- Camera complements (4 ints: A, B, C, D margins)
    map.margins = {}
    for i = 1, 4 do
        map.margins[i] = read_int32(data, pos); pos = pos + 4
    end

    -- Playable dimensions
    map.playable_width = read_int32(data, pos); pos = pos + 4
    map.playable_height = read_int32(data, pos); pos = pos + 4

    -- Calculate full map dimensions
    map.width = map.margins[1] + map.playable_width + map.margins[2]
    map.height = map.margins[3] + map.playable_height + map.margins[4]

    -- Flags
    local flags_raw = read_uint32(data, pos); pos = pos + 4
    map.flags = parse_map_flags(flags_raw)

    -- Tileset
    map.tileset_code = data:sub(pos, pos)
    map.tileset = TILESETS[map.tileset_code] or ("unknown_" .. map.tileset_code)
    pos = pos + 1

    -- Loading screen
    map.loading_screen = {}
    map.loading_screen.preset = read_int32(data, pos); pos = pos + 4
    map.loading_screen.model, pos = read_string(data, pos)
    map.loading_screen.text, pos = read_string(data, pos)
    map.loading_screen.title, pos = read_string(data, pos)
    map.loading_screen.subtitle, pos = read_string(data, pos)

    -- Game data set
    map.game_data_set = read_int32(data, pos); pos = pos + 4

    -- Prologue screen
    map.prologue = {}
    map.prologue.model, pos = read_string(data, pos)
    map.prologue.text, pos = read_string(data, pos)
    map.prologue.title, pos = read_string(data, pos)
    map.prologue.subtitle, pos = read_string(data, pos)

    -- TFT-specific fields (version 25+)
    if map.version >= 25 then
        -- Fog settings
        map.fog = {}
        map.fog.style = read_int32(data, pos); pos = pos + 4
        map.fog.start_z = read_float32(data, pos); pos = pos + 4
        map.fog.end_z = read_float32(data, pos); pos = pos + 4
        map.fog.density = read_float32(data, pos); pos = pos + 4
        map.fog.color = read_uint32(data, pos); pos = pos + 4

        -- Extract RGB from BGRA
        local color = map.fog.color
        map.fog.color_r = band(rshift(color, 16), 0xFF)
        map.fog.color_g = band(rshift(color, 8), 0xFF)
        map.fog.color_b = band(color, 0xFF)

        -- Environment
        map.weather, pos = read_char4(data, pos)
        map.sound_environment, pos = read_string(data, pos)
        map.light_environment = data:sub(pos, pos)
        pos = pos + 1

        -- Water color
        map.water_color = read_uint32(data, pos); pos = pos + 4
    end

    -- Players
    map.players, pos = parse_players(data, pos)

    -- Forces
    map.forces, pos = parse_forces(data, pos)

    -- TFT: Upgrades and tech (optional - some maps don't have these)
    if map.version >= 25 and pos + 4 <= #data then
        map.upgrades, pos = parse_upgrades(data, pos)

        if pos + 4 <= #data then
            map.tech, pos = parse_tech(data, pos)
        end

        -- Random unit tables
        if pos + 4 <= #data then
            map.random_unit_tables, pos = parse_random_unit_tables(data, pos)
        end

        -- Random item tables
        if pos + 4 <= #data then
            map.random_item_tables, pos = parse_random_item_tables(data, pos)
        end
    end

    return map
end
-- }}}

-- {{{ w3i.format
-- Returns a human-readable summary of the map info.
function w3i.format(map)
    local lines = {}

    lines[#lines + 1] = "=== Map Info (w3i) ==="
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Name: " .. map.name
    lines[#lines + 1] = "Author: " .. map.author
    lines[#lines + 1] = "Description: " .. (map.description:sub(1, 100) ..
        (#map.description > 100 and "..." or ""))
    lines[#lines + 1] = "Recommended Players: " .. map.players_recommended
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Version: " .. map.version
    lines[#lines + 1] = "Editor Version: " .. map.editor_version
    lines[#lines + 1] = "Saves: " .. map.saves
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Dimensions: " .. map.width .. " x " .. map.height
    lines[#lines + 1] = "Playable Area: " .. map.playable_width .. " x " .. map.playable_height
    lines[#lines + 1] = "Tileset: " .. map.tileset .. " (" .. map.tileset_code .. ")"
    lines[#lines + 1] = ""

    -- Flags summary
    local flag_list = {}
    if map.flags.melee_map then flag_list[#flag_list + 1] = "Melee" end
    if map.flags.use_custom_forces then flag_list[#flag_list + 1] = "Custom Forces" end
    if map.flags.use_custom_techtree then flag_list[#flag_list + 1] = "Custom Tech" end
    if map.flags.fixed_player_settings then flag_list[#flag_list + 1] = "Fixed Players" end
    lines[#lines + 1] = "Flags: " .. (#flag_list > 0 and table.concat(flag_list, ", ") or "None")
    lines[#lines + 1] = ""

    -- Players
    lines[#lines + 1] = "Players (" .. #map.players .. "):"
    for _, p in ipairs(map.players) do
        lines[#lines + 1] = string.format("  [%d] %s (%s, %s)%s",
            p.number, p.name, p.type, p.race,
            p.fixed_start and " [fixed]" or "")
    end
    lines[#lines + 1] = ""

    -- Forces
    lines[#lines + 1] = "Forces (" .. #map.forces .. "):"
    for _, f in ipairs(map.forces) do
        local flags_str = {}
        if f.flags.allied then flags_str[#flags_str + 1] = "Allied" end
        if f.flags.share_vision then flags_str[#flags_str + 1] = "Shared Vision" end
        lines[#lines + 1] = string.format("  %s: players %s%s",
            f.name, table.concat(f.players, ","),
            #flags_str > 0 and " (" .. table.concat(flags_str, ", ") .. ")" or "")
    end

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ Exports
w3i.PLAYER_TYPES = PLAYER_TYPES
w3i.RACE_TYPES = RACE_TYPES
w3i.TILESETS = TILESETS
w3i.MAP_FLAGS = MAP_FLAGS
w3i.FORCE_FLAGS = FORCE_FLAGS
-- }}}

return w3i
