--[[
war3map.w3a Parser - Ability Object Data

Parses ability modifications from the World Editor.
Abilities USE level/column format for per-level stats.

Usage:
  local w3a = require("parsers.w3a")
  local abilities = w3a.parse(data)

  -- Get ability info
  local holy_bolt = abilities:get("AHhb")

  -- Get stat at specific level
  local dmg_lv3 = abilities:get_stat("AHhb", "damage", 3)

  -- Get all level data
  local all_levels = abilities:get_level_data("AHhb", "damage")
]]

local objectdata = require("parsers.objectdata")

local w3a = {}

-- {{{ Field ID mappings
-- Common ability fields (many are ability-type specific)
w3a.FIELDS = {
    -- Basic info
    name = "anam",
    editor_suffix = "ansf",
    hotkey = "ahky",
    tooltip = "atp1",
    uber_tooltip = "aub1",
    research_tooltip = "aret",
    research_uber_tooltip = "arut",
    order_string = "aord",
    unorder_string = "aoru",

    -- Stats
    mana_cost = "amcs",
    cooldown = "acdn",
    cast_range = "aran",
    area_of_effect = "aare",
    duration = "adur",
    hero_duration = "ahdu",
    buff = "abuf",
    effect = "aeff",
    levels = "alev",

    -- Flags
    hero_ability = "aher",
    item_ability = "aite",
    requires_research = "areq",

    -- Visual
    icon = "aart",
    effect_art = "aeat",
    target_art = "atat",
    caster_art = "acat",
    missile_art = "amat",
    missile_speed = "amsp",
    missile_arc = "amac",

    -- Targeting
    target_type = "atar",
    options = "aopt",

    -- Sound
    effect_sound = "aefs",
}

-- Reverse mapping
w3a.FIELD_NAMES = {}
for name, id in pairs(w3a.FIELDS) do
    w3a.FIELD_NAMES[id] = name
end

-- Common per-level ability data fields (ability-type specific)
-- These vary by ability type, so we store common patterns
w3a.LEVEL_FIELDS = {
    damage = "Htb1",  -- Holy Bolt damage
    heal = "Htb2",    -- Holy Bolt heal
    -- Many more - depends on ability type
}
-- }}}

-- {{{ w3a.parse
-- Parse w3a binary data.
-- @param data Binary string
-- @return AbilityDataTable or nil and error
function w3a.parse(data)
    local result, err = objectdata.parse(data, {
        has_level_column = true,  -- Abilities use level/column
    })

    if not result then
        return nil, err
    end

    -- Extend with w3a-specific methods
    setmetatable(result, { __index = w3a.AbilityDataTable })
    return result
end
-- }}}

-- {{{ AbilityDataTable class
w3a.AbilityDataTable = setmetatable({}, { __index = objectdata.ObjectDataTable })

-- {{{ AbilityDataTable:get_stat
-- Get an ability stat by friendly name and optional level.
-- @param id Ability ID
-- @param stat_name Friendly stat name
-- @param level Optional level (1 if not specified for level-based stats)
-- @return Stat value or nil
function w3a.AbilityDataTable:get_stat(id, stat_name, level)
    local field_id = w3a.FIELDS[stat_name] or w3a.LEVEL_FIELDS[stat_name] or stat_name
    return self:get_modification(id, field_id, level)
end
-- }}}

-- {{{ AbilityDataTable:get_level_data
-- Get data for all levels of a stat.
-- @param id Ability ID
-- @param field_id Field ID to query
-- @return Table of {level = value}
function w3a.AbilityDataTable:get_level_data(id, field_id)
    local obj = self:get(id)
    if not obj then return {} end

    -- Resolve friendly name
    if w3a.FIELDS[field_id] then
        field_id = w3a.FIELDS[field_id]
    elseif w3a.LEVEL_FIELDS[field_id] then
        field_id = w3a.LEVEL_FIELDS[field_id]
    end

    local levels = {}
    for _, mod in ipairs(obj.modifications) do
        if mod.field_id == field_id and mod.level then
            levels[mod.level] = mod.value
        end
    end
    return levels
end
-- }}}

-- {{{ AbilityDataTable:get_all_stats
-- Get all modified stats for an ability.
-- @param id Ability ID
-- @return Table of stats (level-based stats grouped)
function w3a.AbilityDataTable:get_all_stats(id)
    local obj = self:get(id)
    if not obj then return {} end

    local stats = {}
    local level_stats = {}

    for _, mod in ipairs(obj.modifications) do
        local name = w3a.FIELD_NAMES[mod.field_id] or mod.field_id

        if mod.level and mod.level > 0 then
            -- Level-based stat
            level_stats[name] = level_stats[name] or {}
            level_stats[name][mod.level] = mod.value
        else
            -- Base stat
            stats[name] = mod.value
        end
    end

    stats._levels = level_stats
    return stats
end
-- }}}

-- {{{ AbilityDataTable:get_max_level
-- Get the maximum level defined for an ability.
-- @param id Ability ID
-- @return Max level or 0
function w3a.AbilityDataTable:get_max_level(id)
    local levels = self:get_stat(id, "levels")
    if levels then
        return levels
    end

    -- Infer from modifications
    local obj = self:get(id)
    if not obj then return 0 end

    local max = 0
    for _, mod in ipairs(obj.modifications) do
        if mod.level and mod.level > max then
            max = mod.level
        end
    end
    return max
end
-- }}}

-- {{{ AbilityDataTable:is_hero_ability
-- Check if this is a hero ability.
-- @param id Ability ID
-- @return boolean
function w3a.AbilityDataTable:is_hero_ability(id)
    local val = self:get_stat(id, "hero_ability")
    return val == 1
end
-- }}}

-- {{{ AbilityDataTable:is_item_ability
-- Check if this is an item ability.
-- @param id Ability ID
-- @return boolean
function w3a.AbilityDataTable:is_item_ability(id)
    local val = self:get_stat(id, "item_ability")
    return val == 1
end
-- }}}

-- {{{ AbilityDataTable:get_costs
-- Get mana cost and cooldown at a level.
-- @param id Ability ID
-- @param level Level (default 1)
-- @return Table with cost info
function w3a.AbilityDataTable:get_costs(id, level)
    level = level or 1
    return {
        mana = self:get_stat(id, "mana_cost", level),
        cooldown = self:get_stat(id, "cooldown", level),
        cast_range = self:get_stat(id, "cast_range", level),
    }
end
-- }}}

-- {{{ AbilityDataTable:get_targeting
-- Get targeting info.
-- @param id Ability ID
-- @return Table with target info
function w3a.AbilityDataTable:get_targeting(id)
    return {
        target_type = self:get_stat(id, "target_type"),
        options = self:get_stat(id, "options"),
        range = self:get_stat(id, "cast_range"),
        aoe = self:get_stat(id, "area_of_effect"),
    }
end
-- }}}

-- }}}

return w3a
