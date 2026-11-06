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

-- {{{ Reader
-- A unit entry is read through a reader that checks every read against the
-- end of the data (issue 202f): a file cut short, or one whose counts don't
-- fit it, stops the reading with an error naming the place, which
-- unitsdoo.parse turns into nil and that message.
local Reader = {}
Reader.__index = Reader

local function new_reader(data, pos)
    return setmetatable({ data = data, pos = pos }, Reader)
end

function Reader:need(n, what)
    if self.pos + n - 1 > #self.data then
        error({ unitsdoo = string.format("%s runs past the end of the data (byte %d of %d)",
            what, self.pos - 1, #self.data) }, 0)
    end
end

function Reader:i32(what)
    self:need(4, what)
    local v = read_int32(self.data, self.pos)
    self.pos = self.pos + 4
    return v
end

function Reader:f32(what)
    self:need(4, what)
    local v = read_float32(self.data, self.pos)
    self.pos = self.pos + 4
    return v
end

function Reader:u8(what)
    self:need(1, what)
    local v = self.data:byte(self.pos)
    self.pos = self.pos + 1
    return v
end

function Reader:id(what)
    self:need(4, what)
    local v = self.data:sub(self.pos, self.pos + 3)
    self.pos = self.pos + 4
    return v
end

-- a count, refused when negative or when even its smallest entries
-- (min_size bytes each) can't fit in what is left
function Reader:count(min_size, what)
    local n = self:i32(what)
    if n < 0 or n * min_size > #self.data - self.pos + 1 then
        error({ unitsdoo = string.format("%s: %d doesn't fit the data (byte %d of %d)",
            what, n, self.pos - 5, #self.data) }, 0)
    end
    return n
end
-- }}}

-- {{{ parse_item_drops
-- Parse the item drop table section of a unit entry.
-- Structure:
--   item_drops = {
--       table_pointer = -1,  -- -1 if none, else index into the map's item tables
--       sets = {
--           { items = { { id = "ratc", chance = 100, name = "Claws..." }, ... } },
--           ...
--       }
--   }
-- The table pointer is in the file only from subversion 11 on (TFT); older
-- files have none and read as -1.
local function parse_item_drops(r, has_pointer)
    local item_drops = { table_pointer = -1, sets = {} }

    if has_pointer then
        item_drops.table_pointer = r:i32("item table pointer")
    end

    -- Number of item sets dropped (one random set chosen on death)
    local num_item_sets = r:count(4, "item set count")
    for i = 1, num_item_sets do
        local item_set = { items = {} }
        local num_items = r:count(8, "item count")
        for j = 1, num_items do
            local item = {}
            item.id = r:id("dropped item")
            item.name = COMMON_ITEMS[item.id]  -- May be nil for unknown items
            item.chance = r:i32("drop chance")
            item_set.items[j] = item
        end
        item_drops.sets[i] = item_set
    end

    return item_drops
end
-- }}}

-- {{{ parse_hero_data
-- Parse the hero section. Every entry has it, hero or not (non-heroes
-- carry level 1 or 0 and no bonuses); the stat bonuses are TFT only
-- (version 8 on). The inventory can hold items for a non-hero too.
-- Inventory slots are 0-5, laid out as:
--   [0] [1]
--   [2] [3]
--   [4] [5]
local function parse_hero_data(r, has_stats)
    local hero_data = {}

    hero_data.level = r:i32("hero level")
    if has_stats then
        hero_data.str_bonus = r:i32("strength bonus")
        hero_data.agi_bonus = r:i32("agility bonus")
        hero_data.int_bonus = r:i32("intelligence bonus")
    else
        hero_data.str_bonus, hero_data.agi_bonus, hero_data.int_bonus = 0, 0, 0
    end

    local num_items = r:count(8, "inventory count")
    hero_data.inventory = {}
    for _ = 1, num_items do
        local slot = r:i32("inventory slot")
        hero_data.inventory[slot] = r:id("inventory item")
    end

    return hero_data
end
-- }}}

-- {{{ parse_abilities
-- Parse the modified abilities section (12 bytes each: id, autocast, level).
local function parse_abilities(r)
    local abilities = {}
    local num_abilities = r:count(12, "ability count")
    for i = 1, num_abilities do
        local ability = {}
        ability.id = r:id("ability")
        ability.autocast = (r:i32("autocast") ~= 0)
        ability.level = r:i32("ability level")
        abilities[i] = ability
    end
    return abilities
end
-- }}}

-- {{{ decode_random_level
-- Decode level character to numeric level.
-- '0'-'9' = levels 0-9, 'A'-'Z' = levels 10-35
local function decode_random_level(char)
    local byte = string.byte(char)
    if byte >= 48 and byte <= 57 then  -- '0'-'9'
        return byte - 48
    elseif byte >= 65 and byte <= 90 then  -- 'A'-'Z'
        return byte - 65 + 10
    else
        return 0
    end
end
-- }}}

-- {{{ random_kind
-- What a placed random object stands for, from its type ID: the editor's
-- random unit, building and item (uDNR, bDNR, iDNR), and the older
-- YYU/YYI placeholders. nil for every other type.
local RANDOM_IDS = { uDNR = "unit", bDNR = "building", iDNR = "item" }

local function random_kind(type_id)
    if RANDOM_IDS[type_id] then return RANDOM_IDS[type_id] end
    if type_id:sub(1, 3) == "YYU" then return "unit" end
    if type_id:sub(1, 3) == "YYI" then return "item" end
    return nil
end
-- }}}

-- {{{ parse_random_unit
-- Parse the random unit/item section. Every entry has its flag:
--   0  any object of a level: 3 bytes level (a 24-bit number, -1 = any)
--      and 1 byte item class (0 = any). Every non-random entry has flag 0
--      and these 4 bytes too.
--   1  from one of the map's random groups (war3map.w3i): group index and
--      the position (column) in that group
--   2  from a table of its own: a count, then a type ID and a chance each
-- Returns the random_unit structure (nil for an entry that isn't random)
-- and errors on an unknown flag, whose length can't be known.
--   random_unit = {
--       flag = 0/1/2,
--       type = "unit"/"building"/"item",  -- flag 0, from the type ID
--       level = N, item_class = N,        -- flag 0
--       group_index = N, position = N,    -- flag 1
--       choices = { { id, chance }, ... } -- flag 2
--   }
local function parse_random_unit(r, type_id)
    local flag = r:i32("random flag")

    if flag == 0 then
        r:need(4, "random level")
        local b1, b2, b3, class = r.data:byte(r.pos, r.pos + 3)
        r.pos = r.pos + 4
        local kind = random_kind(type_id)
        if not kind then return nil end
        local level = b1 + b2 * 256 + b3 * 65536
        if level >= 8388608 then level = level - 16777216 end
        return { flag = 0, type = kind, level = level, item_class = class }

    elseif flag == 1 then
        local group_index = r:i32("random group")
        local position = r:i32("random group position")
        return { flag = 1, group_index = group_index, position = position }

    elseif flag == 2 then
        local n = r:count(8, "random choice count")
        local choices = {}
        for i = 1, n do
            local id = r:id("random choice")
            choices[i] = { id = id, chance = r:i32("random choice chance") }
        end
        return { flag = 2, choices = choices }
    end

    error({ unitsdoo = string.format("unknown random flag %d (byte %d of %d)",
        flag, r.pos - 5, #r.data) }, 0)
end
-- }}}

-- {{{ parse_unit_entry
-- Parses a single unit entry; returns the unit table and the next read
-- position. The order of the parts, as the World Editor writes them
-- (issue 202f, checked against every byte of the test maps' files):
--   type, variation, position, angle, scale, flags, player, 2 unknown
--   bytes, hp, mp; item drops (the table pointer from subversion 11 on);
--   gold, target acquisition; hero section (level, then from version 8
--   the three stat bonuses, then the inventory); modified abilities;
--   random section; custom color; waygate; creation number.
local function parse_unit_entry(data, pos, version, subversion)
    local r = new_reader(data, pos)
    local unit = {}

    -- Type ID (4 chars)
    unit.id = r:id("type ID")
    unit.name = COMMON_UNITS[unit.id]  -- May be nil for unknown types
    unit.is_hero = is_hero(unit.id)

    unit.variation = r:i32("variation")

    -- Position (X, Y, Z floats)
    local x, y, z = r:f32("position"), r:f32("position"), r:f32("position")
    unit.position = { x = x, y = y, z = z }

    -- Rotation angle in radians
    unit.angle = r:f32("angle")

    -- Scale (X, Y, Z floats)
    local sx, sy, sz = r:f32("scale"), r:f32("scale"), r:f32("scale")
    unit.scale = { x = sx, y = sy, z = sz }

    unit.flags = r:u8("flags")

    unit.player = r:i32("player")
    unit.player_name = PLAYERS[unit.player]

    unit.unknown1 = r:u8("unknown byte")
    unit.unknown2 = r:u8("unknown byte")

    -- Hit points and mana (-1 = default)
    unit.hp = r:i32("hit points")
    unit.mp = r:i32("mana")

    -- Item drops (variable length)
    unit.item_drops = parse_item_drops(r, version >= 8 and subversion >= 11)

    -- Gold held (a gold mine's; 12500 by default) and target acquisition
    -- range (-1 = normal, -2 = camp)
    unit.gold = r:i32("gold")
    unit.target_acquisition = r:f32("target acquisition")

    -- The hero section: every entry has it; only a hero keeps it as
    -- hero_data. Any unit's inventory is unit.inventory.
    local hero = parse_hero_data(r, version >= 8)
    unit.inventory = hero.inventory
    unit.hero_data = unit.is_hero and hero or nil

    -- Modified abilities (variable length)
    unit.abilities = parse_abilities(r)

    -- Random unit/item (variable length)
    unit.random_unit = parse_random_unit(r, unit.id)

    -- Custom color (-1 = the player's own)
    unit.custom_color = r:i32("custom color")

    -- Waygate destination (-1 = inactive, else region creation number)
    unit.waygate_dest = r:i32("waygate")

    -- Creation number (unique editor ID)
    unit.creation_number = r:i32("creation number")

    return unit, r.pos
end
-- }}}

-- {{{ unitsdoo.parse
-- Parses a war3mapUnits.doo file.
-- data: raw binary data string
-- Returns: structured unit table, or nil and error message. An entry that
-- runs past the end of the data, a count that doesn't fit, or an unknown
-- random flag gives nil and a message naming the unit and the place.
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

    if unit_count < 0 then
        return nil, string.format("Invalid unit count %d", unit_count)
    end

    -- Parse unit entries
    result.units = {}
    for i = 1, unit_count do
        local ok, unit, new_pos = pcall(parse_unit_entry, data, pos, result.version, result.subversion)
        if not ok then
            local msg = type(unit) == "table" and unit.unitsdoo or tostring(unit)
            return nil, string.format("war3mapUnits.doo: unit %d/%d: %s", i, unit_count, msg)
        end
        -- its bytes as read, for writing back (issue 911a)
        unit.raw = data:sub(pos, new_pos - 1)
        result.units[i] = unit
        pos = new_pos
    end
    result.tail_raw = data:sub(pos)

    return result
end
-- }}}

-- {{{ unitsdoo.write (issue 911a)
-- The units back as war3mapUnits.doo bytes. Each entry is its bytes as
-- read, with its fixed-place fields written over from the table: type,
-- variation, position, angle, scale, flags, player (the first 41 bytes)
-- and creation number (the last 4). A unit made in the editor copies the
-- bytes of a unit of its kind (hero or not; unitsdoo.template) and is
-- written over the same way. Its other parts (drops, abilities, hero
-- data) are the template's.
function unitsdoo.template(result, hero)
    for _, u in ipairs(result.units) do
        if u.raw and (u.is_hero == (hero == true)) and not u.random_unit then
            return u.raw
        end
    end
    return nil
end

function unitsdoo.write(result)
    local bw = require("parsers.binwrite")
    local b = bw.new()
    b:str(FILE_ID):i32(result.version):i32(result.subversion):i32(#result.units)
    for _, u in ipairs(result.units) do
        local raw = u.raw or unitsdoo.template(result, is_hero(u.id))
        if not raw then error("unitsdoo.write: no bytes to copy for a new " .. tostring(u.id)) end
        local head = bw.new()
        head:str(u.id):i32(u.variation or 0)
        head:f32(u.position.x):f32(u.position.y):f32(u.position.z)
        head:f32(u.angle or 0)
        head:f32(u.scale.x):f32(u.scale.y):f32(u.scale.z)
        head:u8(u.flags or 2):i32(u.player or 0)
        local tail = bw.new():i32(u.creation_number or 0):done()
        b:str(head:done() .. raw:sub(42, #raw - 4) .. tail)
    end
    b:str(result.tail_raw or "")
    return b:done()
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

    -- Count units by player and units with abilities
    local player_counts = {}
    local hero_count = 0
    local units_with_abilities = 0
    local total_abilities = 0
    for _, u in ipairs(result.units) do
        player_counts[u.player] = (player_counts[u.player] or 0) + 1
        if u.is_hero then hero_count = hero_count + 1 end
        if u.abilities and #u.abilities > 0 then
            units_with_abilities = units_with_abilities + 1
            total_abilities = total_abilities + #u.abilities
        end
    end

    lines[#lines + 1] = string.format("Heroes: %d", hero_count)
    if units_with_abilities > 0 then
        lines[#lines + 1] = string.format("Units with modified abilities: %d (%d total)",
            units_with_abilities, total_abilities)
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
        -- Show random unit info if present (202e)
        if u.random_unit then
            if u.random_unit.flag == 0 then
                lines[#lines + 1] = string.format("      random: %s level %d",
                    u.random_unit.type, u.random_unit.level)
            elseif u.random_unit.flag == 1 then
                lines[#lines + 1] = string.format("      random: group %d pos %d",
                    u.random_unit.group_index, u.random_unit.position)
            elseif u.random_unit.flag == 2 then
                lines[#lines + 1] = string.format("      random: one of %d",
                    #u.random_unit.choices)
            end
        end
        -- Show waygate if active (202e)
        if u.waygate_dest >= 0 then
            lines[#lines + 1] = string.format("      waygate -> region %d", u.waygate_dest)
        end
    end
    if #result.units > max_samples then
        lines[#lines + 1] = string.format("  ... and %d more units",
            #result.units - max_samples)
    end

    -- Show heroes with details (202d enhancement)
    local heroes = {}
    for _, u in ipairs(result.units) do
        if u.is_hero and u.hero_data then
            heroes[#heroes + 1] = u
        end
    end

    if #heroes > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Hero details:"
        local max_heroes = math.min(5, #heroes)
        for i = 1, max_heroes do
            local u = heroes[i]
            local h = u.hero_data
            local name = COMMON_UNITS[u.id] or u.id
            lines[#lines + 1] = string.format("  %s (Lv.%d) STR+%d AGI+%d INT+%d",
                name, h.level, h.str_bonus, h.agi_bonus, h.int_bonus)

            -- Show inventory items if any
            local item_count = 0
            for _ in pairs(h.inventory) do item_count = item_count + 1 end
            if item_count > 0 then
                local items_str = "    Inventory:"
                for slot = 0, 5 do
                    local item_id = h.inventory[slot]
                    if item_id then
                        local item_name = COMMON_ITEMS[item_id] or item_id
                        items_str = items_str .. string.format(" [%d]=%s", slot, item_name)
                    end
                end
                lines[#lines + 1] = items_str
            end
        end
        if #heroes > max_heroes then
            lines[#lines + 1] = string.format("  ... and %d more heroes",
                #heroes - max_heroes)
        end
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
unitsdoo.decode_random_level = decode_random_level

-- {{{ new
-- Convenience function to create a UnitTable.
function unitsdoo.new(data)
    return UnitTable.new(data)
end
-- }}}
-- }}}

return unitsdoo
