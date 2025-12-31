--[[
war3map.w3q Parser - Upgrade Object Data

Parses upgrade modifications from the World Editor.
Upgrades USE level/column format for per-level data.

Usage:
  local w3q = require("parsers.w3q")
  local upgrades = w3q.parse(data)

  -- Get upgrade info
  local attack = upgrades:get("Rhme")

  -- Get stat at specific level
  local cost_lv2 = upgrades:get_stat("Rhme", "gold_cost", 2)

  -- Get all level data
  local all_costs = upgrades:get_level_data("Rhme", "gold_cost")
]]

local objectdata = require("parsers.objectdata")

local w3q = {}

-- {{{ Field ID mappings
w3q.FIELDS = {
    -- Basic info
    name = "gnam",
    tooltip = "gtp1",
    uber_tooltip = "gub1",
    hotkey = "ghk1",

    -- Costs per level
    gold_cost = "gglb",        -- gold_base
    gold_increment = "gglm",   -- gold_multiplier
    lumber_cost = "glmb",      -- lumber_base
    lumber_increment = "glmm", -- lumber_multiplier
    time_cost = "gtib",        -- time_base
    time_increment = "gtim",   -- time_multiplier

    -- Stats
    levels = "glvl",           -- max level

    -- Classification
    class = "gcls",
    race = "grac",

    -- Requirements
    requires = "greq",         -- tech requirements
    applies_to = "gef1",       -- affected units

    -- Visual
    icon = "gar1",

    -- Effects
    effect_type = "gef1",      -- what type of effect
    effect_base = "gba1",      -- base effect value
    effect_increment = "gmo1", -- effect per level
}

-- Reverse mapping
w3q.FIELD_NAMES = {}
for name, id in pairs(w3q.FIELDS) do
    w3q.FIELD_NAMES[id] = name
end
-- }}}

-- {{{ w3q.parse
-- Parse w3q binary data.
-- @param data Binary string
-- @return UpgradeDataTable or nil and error
function w3q.parse(data)
    local result, err = objectdata.parse(data, {
        has_level_column = true,  -- Upgrades use level/column
    })

    if not result then
        return nil, err
    end

    -- Extend with w3q-specific methods
    setmetatable(result, { __index = w3q.UpgradeDataTable })
    return result
end
-- }}}

-- {{{ UpgradeDataTable class
w3q.UpgradeDataTable = setmetatable({}, { __index = objectdata.ObjectDataTable })

-- {{{ UpgradeDataTable:get_stat
-- Get an upgrade stat by friendly name and optional level.
-- @param id Upgrade ID
-- @param stat_name Friendly stat name
-- @param level Optional level (1 if not specified for level-based stats)
-- @return Stat value or nil
function w3q.UpgradeDataTable:get_stat(id, stat_name, level)
    local field_id = w3q.FIELDS[stat_name] or stat_name
    return self:get_modification(id, field_id, level)
end
-- }}}

-- {{{ UpgradeDataTable:get_level_data
-- Get data for all levels of a stat.
-- @param id Upgrade ID
-- @param field_id Field ID to query
-- @return Table of {level = value}
function w3q.UpgradeDataTable:get_level_data(id, field_id)
    local obj = self:get(id)
    if not obj then return {} end

    -- Resolve friendly name
    if w3q.FIELDS[field_id] then
        field_id = w3q.FIELDS[field_id]
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

-- {{{ UpgradeDataTable:get_all_stats
-- Get all modified stats for an upgrade.
-- @param id Upgrade ID
-- @return Table of stats (level-based stats grouped)
function w3q.UpgradeDataTable:get_all_stats(id)
    local obj = self:get(id)
    if not obj then return {} end

    local stats = {}
    local level_stats = {}

    for _, mod in ipairs(obj.modifications) do
        local name = w3q.FIELD_NAMES[mod.field_id] or mod.field_id

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

-- {{{ UpgradeDataTable:get_max_level
-- Get the maximum level for an upgrade.
-- @param id Upgrade ID
-- @return Max level or 0
function w3q.UpgradeDataTable:get_max_level(id)
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

-- {{{ UpgradeDataTable:get_costs
-- Get resource costs at a specific level.
-- @param id Upgrade ID
-- @param level Level (default 1)
-- @return Table with cost info
function w3q.UpgradeDataTable:get_costs(id, level)
    level = level or 1
    return {
        gold = self:get_stat(id, "gold_cost", level),
        lumber = self:get_stat(id, "lumber_cost", level),
        time = self:get_stat(id, "time_cost", level),
    }
end
-- }}}

-- {{{ UpgradeDataTable:get_total_cost
-- Get total cost through a given level using base + increment.
-- @param id Upgrade ID
-- @param target_level Target level
-- @return Table with total costs
function w3q.UpgradeDataTable:get_total_cost(id, target_level)
    local gold_base = self:get_stat(id, "gold_cost", 1) or 0
    local gold_inc = self:get_stat(id, "gold_increment") or 0
    local lumber_base = self:get_stat(id, "lumber_cost", 1) or 0
    local lumber_inc = self:get_stat(id, "lumber_increment") or 0
    local time_base = self:get_stat(id, "time_cost", 1) or 0
    local time_inc = self:get_stat(id, "time_increment") or 0

    local total_gold = 0
    local total_lumber = 0
    local total_time = 0

    for lv = 1, target_level do
        total_gold = total_gold + gold_base + (gold_inc * (lv - 1))
        total_lumber = total_lumber + lumber_base + (lumber_inc * (lv - 1))
        total_time = total_time + time_base + (time_inc * (lv - 1))
    end

    return {
        gold = total_gold,
        lumber = total_lumber,
        time = total_time,
    }
end
-- }}}

-- {{{ UpgradeDataTable:get_effect
-- Get the upgrade effect at a level.
-- @param id Upgrade ID
-- @param level Level (default 1)
-- @return Table with effect info
function w3q.UpgradeDataTable:get_effect(id, level)
    level = level or 1
    return {
        type = self:get_stat(id, "effect_type", level),
        base = self:get_stat(id, "effect_base", level),
        increment = self:get_stat(id, "effect_increment"),
    }
end
-- }}}

-- }}}

return w3q
