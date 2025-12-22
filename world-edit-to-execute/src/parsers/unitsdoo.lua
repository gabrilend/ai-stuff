-- war3mapUnits.doo Parser
-- Parses WC3 unit/building/item placement files.
-- Units include heroes, regular units, buildings, and preplaced items.
-- Compatible with both LuaJIT and Lua 5.3+.

local compat = require("compat")

local unitsdoo = {}

-- {{{ Constants
local FILE_ID = "W3do"

-- Player number mappings
local PLAYERS = {
    [0]  = "Player 1 (Red)",
    [1]  = "Player 2 (Blue)",
    [2]  = "Player 3 (Teal)",
    [3]  = "Player 4 (Purple)",
    [4]  = "Player 5 (Yellow)",
    [5]  = "Player 6 (Orange)",
    [6]  = "Player 7 (Green)",
    [7]  = "Player 8 (Pink)",
    [8]  = "Player 9 (Gray)",
    [9]  = "Player 10 (Light Blue)",
    [10] = "Player 11 (Dark Green)",
    [11] = "Player 12 (Brown)",
    [12] = "Player 13",
    [13] = "Player 14",
    [14] = "Player 15",
    [15] = "Player 16",
    [24] = "Neutral Hostile",
    [25] = "Neutral Passive",
    [27] = "Neutral Victim",
}

-- Common unit type IDs for reference
local COMMON_UNITS = {
    -- Human
    hfoo = "Footman",
    hkni = "Knight",
    hrif = "Rifleman",
    hsor = "Sorceress",
    hpea = "Peasant",
    htow = "Town Hall",
    hbar = "Barracks",
    -- Human Heroes
    Hpal = "Paladin",
    Hamg = "Archmage",
    Hmkg = "Mountain King",
    Hblm = "Blood Mage",
    -- Orc
    ogru = "Grunt",
    orai = "Raider",
    okod = "Kodo Beast",
    opeo = "Peon",
    ogre = "Great Hall",
    obar = "Barracks",
    -- Orc Heroes
    Obla = "Blademaster",
    Ofar = "Far Seer",
    Otch = "Tauren Chieftain",
    Oshd = "Shadow Hunter",
    -- Undead
    ugho = "Ghoul",
    uabo = "Abomination",
    ucry = "Crypt Fiend",
    uaco = "Acolyte",
    unpl = "Necropolis",
    usep = "Crypt",
    -- Undead Heroes
    Udea = "Death Knight",
    Ulic = "Lich",
    Udre = "Dreadlord",
    Ucrl = "Crypt Lord",
    -- Night Elf
    earc = "Archer",
    edry = "Dryad",
    ehip = "Hippogryph",
    ewsp = "Wisp",
    etol = "Tree of Life",
    eaom = "Ancient of War",
    -- Night Elf Heroes
    Edem = "Demon Hunter",
    Ekee = "Keeper of the Grove",
    Emoo = "Priestess of the Moon",
    Ewar = "Warden",
}

-- Common item type IDs for reference
-- Used by item drop tables and hero inventories
local COMMON_ITEMS = {
    -- Permanent items
    ratc = "Claws of Attack +3",
    rat6 = "Claws of Attack +6",
    rat9 = "Claws of Attack +9",
    rin1 = "Ring of Protection +1",
    rde1 = "Ring of Protection +2",
    rde2 = "Ring of Protection +3",
    bspd = "Boots of Speed",
    rwiz = "Sobi Mask",
    afac = "Alleria's Flute of Accuracy",
    ajen = "Ancient Janggo of Endurance",
    -- Charged items
    pman = "Mana Potion",
    phea = "Healing Potion",
    pinv = "Potion of Invisibility",
    pnvu = "Potion of Invulnerability",
    stwp = "Scroll of Town Portal",
    -- Powerups
    texp = "Tome of Experience",
    tstr = "Tome of Strength",
    tagi = "Tome of Agility",
    tint = "Tome of Intelligence",
    -- Resources
    gold = "Gold Coins",
    lmbr = "Bundle of Lumber",
}
-- }}}

-- {{{ Binary reading utilities
-- {{{ read_int32
local function read_int32(data, pos)
    return compat.unpack_int32(data, pos)
end
-- }}}

-- {{{ read_float32
local function read_float32(data, pos)
    return compat.unpack_float(data, pos)
end
-- }}}

-- {{{ read_byte
local function read_byte(data, pos)
    return data:byte(pos), pos + 1
end
-- }}}

-- {{{ read_id
local function read_id(data, pos)
    -- Read 4-character ID string
    return data:sub(pos, pos + 3), pos + 4
end
-- }}}

-- {{{ is_hero
-- Check if a unit type ID represents a hero (capital first letter).
-- Excludes random unit placeholders (YYU*, YYI*) which start with Y but aren't heroes.
local function is_hero(type_id)
    if not type_id or #type_id < 1 then return false end
    local first = type_id:byte(1)
    -- Capital letters: A-Z (65-90)
    if first < 65 or first > 90 then return false end
    -- Exclude random unit/item placeholders (YYU = random unit, YYI = random item)
    -- These start with Y but are not actual hero units
    if first == 89 then  -- 'Y'
        local second = type_id:byte(2)
        if second == 89 then  -- 'YY' prefix = random placeholder
            return false
        end
    end
    return true
end
-- }}}
-- }}}

-- {{{ parse_item_drops
-- Parse the item drop table section of a unit entry.
-- Returns the item_drops structure and the new position.
-- Structure:
--   item_drops = {
--       table_pointer = -1,  -- -1 if none, else index into external table
--       sets = {
--           { items = { { id = "ratc", chance = 100, name = "Claws..." }, ... } },
--           ...
--       }
--   }
local function parse_item_drops(data, pos)
    local item_drops = {
        table_pointer = -1,
        sets = {}
    }

    -- Item table pointer (-1 = none, >= 0 = external table index)
    item_drops.table_pointer = read_int32(data, pos); pos = pos + 4

    -- Number of item sets dropped (one random set chosen on death)
    local num_item_sets = read_int32(data, pos); pos = pos + 4

    -- Parse each item set
    for i = 1, num_item_sets do
        local item_set = { items = {} }

        -- Number of items in this set
        local num_items = read_int32(data, pos); pos = pos + 4

        -- Parse each item (4 bytes ID + 4 bytes chance)
        for j = 1, num_items do
            local item = {}

            -- Item type ID (4 chars, e.g., "ratc")
            item.id, pos = read_id(data, pos)
            item.name = COMMON_ITEMS[item.id]  -- May be nil for unknown items

            -- Drop chance percentage (0-100)
            item.chance = read_int32(data, pos); pos = pos + 4

            item_set.items[j] = item
        end

        item_drops.sets[i] = item_set
    end

    return item_drops, pos
end
-- }}}

-- {{{ parse_abilities
-- Parse the modified abilities section.
-- Returns the abilities array and the new position.
local function parse_abilities(data, pos)
    local abilities = {}

    -- Number of modified abilities
    local num_abilities = read_int32(data, pos); pos = pos + 4

    -- Parse each ability entry (4 bytes ID + 4 bytes autocast + 4 bytes level = 12 bytes each)
    for i = 1, num_abilities do
        local ability = {}

        -- Ability ID (4 chars, e.g., "AHbz" = Blizzard)
        ability.id, pos = read_id(data, pos)

        -- Autocast enabled (0 = off, 1 = on)
        local autocast_raw = read_int32(data, pos); pos = pos + 4
        ability.autocast = (autocast_raw ~= 0)

        -- Ability level (1+)
        ability.level = read_int32(data, pos); pos = pos + 4

        abilities[i] = ability
    end

    return abilities, pos
end
-- }}}

-- {{{ skip_hero_data
-- Skip the hero-specific data section.
-- Only call this for hero units (capital first letter in type ID).
-- Returns the new position after skipping.
local function skip_hero_data(data, pos)
    -- Hero level
    pos = pos + 4

    -- Strength bonus
    pos = pos + 4

    -- Agility bonus
    pos = pos + 4

    -- Intelligence bonus
    pos = pos + 4

    -- Number of items in inventory
    local num_items = read_int32(data, pos); pos = pos + 4

    -- Skip each inventory item (4 bytes slot + 4 bytes item ID = 8 bytes each)
    pos = pos + (num_items * 8)

    return pos
end
-- }}}

-- {{{ skip_random_unit
-- Skip the random unit data section.
-- Returns the new position after skipping.
local function skip_random_unit(data, pos)
    -- Random unit flag (0=not random, 1=random from level, 2=random from group)
    local random_flag = read_int32(data, pos); pos = pos + 4

    if random_flag == 0 then
        -- Not random, no additional data
    elseif random_flag == 1 then
        -- Random from level: 3 chars "YYU" + 1 byte level = 4 bytes
        pos = pos + 4
    elseif random_flag == 2 then
        -- Random from group: 4 bytes group + 4 bytes position = 8 bytes
        pos = pos + 8
    end

    return pos, random_flag
end
-- }}}

-- {{{ parse_unit_entry
-- Parses a single unit entry.
-- Returns the unit table and the next read position.
local function parse_unit_entry(data, pos, version)
    local unit = {}

    -- Type ID (4 chars)
    unit.id, pos = read_id(data, pos)
    unit.name = COMMON_UNITS[unit.id]  -- May be nil for unknown types
    unit.is_hero = is_hero(unit.id)

    -- Variation index
    unit.variation = read_int32(data, pos); pos = pos + 4

    -- Position (X, Y, Z floats)
    unit.position = {
        x = read_float32(data, pos),
        y = read_float32(data, pos + 4),
        z = read_float32(data, pos + 8),
    }
    pos = pos + 12

    -- Rotation angle in radians
    unit.angle = read_float32(data, pos); pos = pos + 4

    -- Scale (X, Y, Z floats)
    unit.scale = {
        x = read_float32(data, pos),
        y = read_float32(data, pos + 4),
        z = read_float32(data, pos + 8),
    }
    pos = pos + 12

    -- Flags (1 byte)
    unit.flags, pos = read_byte(data, pos)

    -- Player number (4 bytes)
    unit.player = read_int32(data, pos); pos = pos + 4
    unit.player_name = PLAYERS[unit.player]

    -- Unknown bytes (2 bytes)
    unit.unknown1, pos = read_byte(data, pos)
    unit.unknown2, pos = read_byte(data, pos)

    -- Hit points (-1 = default)
    unit.hp = read_int32(data, pos); pos = pos + 4

    -- Mana points (-1 = default)
    unit.mp = read_int32(data, pos); pos = pos + 4

    -- Item drop table (variable length)
    unit.item_drops, pos = parse_item_drops(data, pos)

    -- Modified abilities (variable length)
    unit.abilities, pos = parse_abilities(data, pos)

    -- Hero-specific data (conditional - skip for now, implemented in 202d)
    if unit.is_hero then
        pos = skip_hero_data(data, pos)
    end

    -- Random unit data (variable length - skip for now, implemented in 202e)
    local random_flag
    pos, random_flag = skip_random_unit(data, pos)
    unit.random_flag = random_flag

    -- Waygate destination (-1 = inactive, else region creation number)
    unit.waygate_dest = read_int32(data, pos); pos = pos + 4

    -- Creation number (unique editor ID)
    unit.creation_number = read_int32(data, pos); pos = pos + 4

    return unit, pos
end
-- }}}

-- {{{ unitsdoo.parse
-- Parses a war3mapUnits.doo file.
-- data: raw binary data string
-- Returns: structured unit table, or nil and error message
function unitsdoo.parse(data)
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

    -- Number of units
    local unit_count = read_int32(data, pos); pos = pos + 4

    -- Version validation
    if result.version ~= 7 and result.version ~= 8 then
        result._version_warning = string.format(
            "Unexpected unitsdoo version %d (expected 7 or 8)", result.version)
    end

    -- Parse unit entries
    result.units = {}
    for i = 1, unit_count do
        -- Check minimum remaining bytes (basic fields without variable sections)
        -- 4 (id) + 4 (var) + 12 (pos) + 4 (angle) + 12 (scale) + 1 (flags) +
        -- 4 (player) + 2 (unknown) + 4 (hp) + 4 (mp) = 51 bytes minimum
        if pos + 50 > #data then
            return nil, string.format(
                "Unexpected end of data at unit %d/%d (pos %d, size %d)",
                i, unit_count, pos, #data)
        end

        local unit, new_pos = parse_unit_entry(data, pos, result.version)
        result.units[i] = unit
        pos = new_pos
    end

    return result
end
-- }}}

-- {{{ unitsdoo.format
-- Returns a human-readable summary of the unit data.
function unitsdoo.format(result)
    local lines = {}

    lines[#lines + 1] = "=== Units (war3mapUnits.doo) ==="
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("Version: %d, Subversion: %d",
        result.version, result.subversion)
    lines[#lines + 1] = string.format("Unit count: %d", #result.units)

    if result._version_warning then
        lines[#lines + 1] = "Warning: " .. result._version_warning
    end
    lines[#lines + 1] = ""

    -- Count units by player, abilities, and item drops
    local player_counts = {}
    local hero_count = 0
    local units_with_abilities = 0
    local total_abilities = 0
    local units_with_drops = 0
    local total_drop_items = 0
    for _, u in ipairs(result.units) do
        player_counts[u.player] = (player_counts[u.player] or 0) + 1
        if u.is_hero then hero_count = hero_count + 1 end
        if u.abilities and #u.abilities > 0 then
            units_with_abilities = units_with_abilities + 1
            total_abilities = total_abilities + #u.abilities
        end
        if u.item_drops and #u.item_drops.sets > 0 then
            units_with_drops = units_with_drops + 1
            for _, set in ipairs(u.item_drops.sets) do
                total_drop_items = total_drop_items + #set.items
            end
        end
    end

    lines[#lines + 1] = string.format("Heroes: %d", hero_count)
    if units_with_abilities > 0 then
        lines[#lines + 1] = string.format("Units with modified abilities: %d (%d total)",
            units_with_abilities, total_abilities)
    end
    if units_with_drops > 0 then
        lines[#lines + 1] = string.format("Units with item drops: %d (%d total items)",
            units_with_drops, total_drop_items)
    end
    lines[#lines + 1] = ""

    -- Sort players by count
    local sorted_players = {}
    for player, count in pairs(player_counts) do
        sorted_players[#sorted_players + 1] = { player = player, count = count }
    end
    table.sort(sorted_players, function(a, b) return a.count > b.count end)

    lines[#lines + 1] = "Units by player:"
    for i, p in ipairs(sorted_players) do
        if i > 10 then
            lines[#lines + 1] = string.format("  ... and %d more players",
                #sorted_players - 10)
            break
        end
        local name = PLAYERS[p.player] or ("Player " .. p.player)
        lines[#lines + 1] = string.format("  %s: %d", name, p.count)
    end
    lines[#lines + 1] = ""

    -- Count units by type
    local type_counts = {}
    for _, u in ipairs(result.units) do
        type_counts[u.id] = (type_counts[u.id] or 0) + 1
    end

    -- Sort types by count
    local sorted_types = {}
    for id, count in pairs(type_counts) do
        sorted_types[#sorted_types + 1] = { id = id, count = count }
    end
    table.sort(sorted_types, function(a, b) return a.count > b.count end)

    lines[#lines + 1] = "Unit types:"
    local max_types = math.min(10, #sorted_types)
    for i = 1, max_types do
        local t = sorted_types[i]
        local name = COMMON_UNITS[t.id] or ""
        local hero_marker = is_hero(t.id) and " [HERO]" or ""
        if name ~= "" then name = " (" .. name .. ")" end
        lines[#lines + 1] = string.format("  %s: %d%s%s", t.id, t.count, name, hero_marker)
    end
    if #sorted_types > max_types then
        lines[#lines + 1] = string.format("  ... and %d more types",
            #sorted_types - max_types)
    end
    lines[#lines + 1] = ""

    -- Show first few units
    lines[#lines + 1] = "Sample units:"
    local max_samples = math.min(5, #result.units)
    for i = 1, max_samples do
        local u = result.units[i]
        local hero_marker = u.is_hero and " [HERO]" or ""
        local hp_str = u.hp == -1 and "default" or tostring(u.hp)
        lines[#lines + 1] = string.format(
            "  [%d] %s%s at (%.1f, %.1f) player=%d hp=%s",
            u.creation_number, u.id, hero_marker,
            u.position.x, u.position.y,
            u.player, hp_str)
        -- Show abilities if present
        if u.abilities and #u.abilities > 0 then
            local ability_strs = {}
            for _, a in ipairs(u.abilities) do
                local autocast_str = a.autocast and " [auto]" or ""
                ability_strs[#ability_strs + 1] = string.format("%s L%d%s",
                    a.id, a.level, autocast_str)
            end
            lines[#lines + 1] = "      abilities: " .. table.concat(ability_strs, ", ")
        end
        -- Show item drops if present
        if u.item_drops and #u.item_drops.sets > 0 then
            local drop_strs = {}
            for set_idx, set in ipairs(u.item_drops.sets) do
                for _, item in ipairs(set.items) do
                    local item_name = item.name or item.id
                    drop_strs[#drop_strs + 1] = string.format("%s %d%%",
                        item_name, item.chance)
                end
            end
            lines[#lines + 1] = "      drops: " .. table.concat(drop_strs, ", ")
        end
    end
    if #result.units > max_samples then
        lines[#lines + 1] = string.format("  ... and %d more units",
            #result.units - max_samples)
    end

    return table.concat(lines, "\n")
end
-- }}}

-- {{{ UnitTable class
local UnitTable = {}
UnitTable.__index = UnitTable

-- {{{ new
-- Create a new UnitTable from unitsdoo content.
function UnitTable.new(unitsdoo_data)
    local self = setmetatable({}, UnitTable)
    self.units = {}
    self.by_creation_number = {}
    self.by_type = {}
    self.by_player = {}
    self.version = 8
    self.subversion = 0
    if unitsdoo_data then
        self:load(unitsdoo_data)
    end
    return self
end
-- }}}

-- {{{ load
-- Load units from unitsdoo binary data.
function UnitTable:load(unitsdoo_data)
    local result, err = unitsdoo.parse(unitsdoo_data)
    if not result then
        error("Failed to parse unitsdoo: " .. tostring(err))
    end

    self.version = result.version
    self.subversion = result.subversion
    self.units = result.units

    -- Build lookup indices
    self.by_creation_number = {}
    self.by_type = {}
    self.by_player = {}

    for _, u in ipairs(self.units) do
        -- Index by creation number (unique ID)
        self.by_creation_number[u.creation_number] = u

        -- Index by type ID
        if not self.by_type[u.id] then
            self.by_type[u.id] = {}
        end
        self.by_type[u.id][#self.by_type[u.id] + 1] = u

        -- Index by player
        if not self.by_player[u.player] then
            self.by_player[u.player] = {}
        end
        self.by_player[u.player][#self.by_player[u.player] + 1] = u
    end
end
-- }}}

-- {{{ get
-- Get a unit by its creation number. Returns nil if not found.
function UnitTable:get(creation_number)
    return self.by_creation_number[creation_number]
end
-- }}}

-- {{{ get_by_type
-- Get all units of a specific type. Returns empty table if none found.
function UnitTable:get_by_type(type_id)
    return self.by_type[type_id] or {}
end
-- }}}

-- {{{ get_by_player
-- Get all units owned by a specific player. Returns empty table if none found.
function UnitTable:get_by_player(player)
    return self.by_player[player] or {}
end
-- }}}

-- {{{ count
-- Return the total number of units.
function UnitTable:count()
    return #self.units
end
-- }}}

-- {{{ count_by_type
-- Return the number of units of a specific type.
function UnitTable:count_by_type(type_id)
    local list = self.by_type[type_id]
    return list and #list or 0
end
-- }}}

-- {{{ count_by_player
-- Return the number of units owned by a specific player.
function UnitTable:count_by_player(player)
    local list = self.by_player[player]
    return list and #list or 0
end
-- }}}

-- {{{ types
-- Return a list of all unique unit type IDs.
function UnitTable:types()
    local result = {}
    for type_id, _ in pairs(self.by_type) do
        result[#result + 1] = type_id
    end
    table.sort(result)
    return result
end
-- }}}

-- {{{ heroes
-- Return a list of all hero units.
function UnitTable:heroes()
    local result = {}
    for _, u in ipairs(self.units) do
        if u.is_hero then
            result[#result + 1] = u
        end
    end
    return result
end
-- }}}

-- {{{ with_drops
-- Return a list of all units with item drops configured.
function UnitTable:with_drops()
    local result = {}
    for _, u in ipairs(self.units) do
        if u.item_drops and #u.item_drops.sets > 0 then
            result[#result + 1] = u
        end
    end
    return result
end
-- }}}

-- {{{ pairs
-- Iterate over all units (index, unit).
function UnitTable:pairs()
    return ipairs(self.units)
end
-- }}}

-- {{{ in_bounds
-- Find all units within a rectangular region.
-- Returns a table of units where min_x <= x <= max_x and min_y <= y <= max_y.
function UnitTable:in_bounds(min_x, min_y, max_x, max_y)
    local result = {}
    for _, u in ipairs(self.units) do
        local x, y = u.position.x, u.position.y
        if x >= min_x and x <= max_x and y >= min_y and y <= max_y then
            result[#result + 1] = u
        end
    end
    return result
end
-- }}}
-- }}}

-- {{{ Module interface
unitsdoo.UnitTable = UnitTable
unitsdoo.PLAYERS = PLAYERS
unitsdoo.COMMON_UNITS = COMMON_UNITS
unitsdoo.COMMON_ITEMS = COMMON_ITEMS
unitsdoo.FILE_ID = FILE_ID
unitsdoo.is_hero = is_hero

-- {{{ new
-- Convenience function to create a UnitTable.
function unitsdoo.new(data)
    return UnitTable.new(data)
end
-- }}}
-- }}}

return unitsdoo
