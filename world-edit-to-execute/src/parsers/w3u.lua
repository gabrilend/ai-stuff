--[[
war3map.w3u Parser - Unit Object Data

Parses unit modifications from the World Editor.
Units do NOT use level/column format.

Usage:
  local w3u = require("parsers.w3u")
  local units = w3u.parse(data)

  -- Get a unit's modifications
  local footman = units:get("hfoo")

  -- Get a specific stat
  local hp = units:get_stat("hfoo", "hp")
  local name = units:get_stat("hfoo", "name")
]]

local objectdata = require("parsers.objectdata")

local w3u = {}

-- {{{ Field ID mappings
-- Maps friendly names to WC3 field IDs
w3u.FIELDS = {
    -- Basic info
    name = "unam",
    editor_suffix = "unsf",
    hotkey = "uhot",
    tooltip = "utip",
    uber_tooltip = "utub",
    description = "ides",

    -- Stats
    hp = "uhpm",
    hp_regen = "uhpr",
    mana = "umpm",
    mana_regen = "umpr",
    move_speed = "umvs",
    turn_rate = "umvr",
    collision_size = "ucol",
    acquisition_range = "uacq",

    -- Combat
    attack1_damage_base = "ua1b",
    attack1_damage_sides = "ua1s",
    attack1_damage_dice = "ua1d",
    attack1_range = "ua1r",
    attack1_cooldown = "ua1c",
    attack1_type = "ua1t",
    attack1_weapon_type = "ua1w",
    attack2_damage_base = "ua2b",
    attack2_range = "ua2r",
    armor = "udef",
    armor_type = "udty",

    -- Abilities and upgrades
    abilities = "uabi",
    hero_abilities = "uhab",
    default_ability = "udaa",

    -- Visual
    model = "umdl",
    shadow = "ushu",
    shadow_size = "ushw",
    shadow_height = "ushh",
    shadow_x = "ushx",
    shadow_y = "ushy",
    icon = "uico",
    score_screen_icon = "ussi",
    selection_scale = "ussc",
    scale = "usca",

    -- Classification
    race = "urac",
    unit_class = "utyp",
    level = "ulev",
    priority = "upri",
    food_cost = "ufoo",
    food_made = "ufma",
    gold_cost = "ugol",
    lumber_cost = "ulum",
    build_time = "ubld",
    repair_time = "urtm",
    stock_max = "usma",
    stock_regen = "usrg",
    stock_start = "usst",

    -- Flags
    is_building = "ubdg",
    can_be_built_on = "uibo",
    can_build_on = "ucbo",
    requires_place = "upar",
    hide_minimap = "uhom",
    neutral_building = "unbm",

    -- Sound
    move_sound = "umsl",
    random_sound = "ursl",
    death_sound = "udsl",

    -- Pathing
    pathing_map = "upat",
    placement_requires = "upap",
    placement_prevents = "upar",
}

-- Reverse mapping for lookup
w3u.FIELD_NAMES = {}
for name, id in pairs(w3u.FIELDS) do
    w3u.FIELD_NAMES[id] = name
end
-- }}}

-- {{{ w3u.parse
-- Parse w3u binary data.
-- @param data Binary string
-- @return UnitDataTable or nil and error
function w3u.parse(data)
    local result, err = objectdata.parse(data, {
        has_level_column = false,
    })

    if not result then
        return nil, err
    end

    -- Extend with w3u-specific methods
    setmetatable(result, { __index = w3u.UnitDataTable })
    return result
end
-- }}}

-- {{{ UnitDataTable class
w3u.UnitDataTable = setmetatable({}, { __index = objectdata.ObjectDataTable })

-- {{{ UnitDataTable:get_stat
-- Get a unit stat by friendly name.
-- @param id Unit ID
-- @param stat_name Friendly stat name (e.g., "hp", "name")
-- @return Stat value or nil
function w3u.UnitDataTable:get_stat(id, stat_name)
    local field_id = w3u.FIELDS[stat_name]
    if not field_id then
        -- Try as raw field ID
        field_id = stat_name
    end
    return self:get_modification(id, field_id)
end
-- }}}

-- {{{ UnitDataTable:get_all_stats
-- Get all modified stats for a unit as a table.
-- @param id Unit ID
-- @return Table of {stat_name = value}
function w3u.UnitDataTable:get_all_stats(id)
    local obj = self:get(id)
    if not obj then return {} end

    local stats = {}
    for _, mod in ipairs(obj.modifications) do
        local name = w3u.FIELD_NAMES[mod.field_id] or mod.field_id
        stats[name] = mod.value
    end
    return stats
end
-- }}}

-- {{{ UnitDataTable:get_combat_stats
-- Get combat-related stats for a unit.
-- @param id Unit ID
-- @return Table with attack/armor info
function w3u.UnitDataTable:get_combat_stats(id)
    return {
        hp = self:get_stat(id, "hp"),
        mana = self:get_stat(id, "mana"),
        armor = self:get_stat(id, "armor"),
        armor_type = self:get_stat(id, "armor_type"),
        attack1_damage = self:get_stat(id, "attack1_damage_base"),
        attack1_range = self:get_stat(id, "attack1_range"),
        attack1_cooldown = self:get_stat(id, "attack1_cooldown"),
        attack1_type = self:get_stat(id, "attack1_type"),
        move_speed = self:get_stat(id, "move_speed"),
    }
end
-- }}}

-- {{{ UnitDataTable:get_costs
-- Get resource costs for a unit.
-- @param id Unit ID
-- @return Table with cost info
function w3u.UnitDataTable:get_costs(id)
    return {
        gold = self:get_stat(id, "gold_cost"),
        lumber = self:get_stat(id, "lumber_cost"),
        food = self:get_stat(id, "food_cost"),
        build_time = self:get_stat(id, "build_time"),
    }
end
-- }}}

-- {{{ UnitDataTable:is_building
-- Check if a unit is a building.
-- @param id Unit ID
-- @return boolean
function w3u.UnitDataTable:is_building(id)
    local val = self:get_stat(id, "is_building")
    return val == 1
end
-- }}}

-- {{{ UnitDataTable:get_abilities
-- Get ability list for a unit.
-- @param id Unit ID
-- @return Array of ability IDs or empty table
function w3u.UnitDataTable:get_abilities(id)
    local abi_str = self:get_stat(id, "abilities")
    if not abi_str or abi_str == "" then
        return {}
    end

    -- Abilities are comma-separated 4-char IDs
    local abilities = {}
    for abi in abi_str:gmatch("([^,]+)") do
        abilities[#abilities + 1] = abi
    end
    return abilities
end
-- }}}

-- }}}

return w3u
