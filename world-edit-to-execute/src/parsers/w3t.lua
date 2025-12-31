--[[
war3map.w3t Parser - Item Object Data

Parses item modifications from the World Editor.
Items do NOT use level/column format.

Usage:
  local w3t = require("parsers.w3t")
  local items = w3t.parse(data)

  -- Get item info
  local potion = items:get("phea")

  -- Get stat
  local gold = items:get_stat("phea", "gold_cost")
]]

local objectdata = require("parsers.objectdata")

local w3t = {}

-- {{{ Field ID mappings
w3t.FIELDS = {
    -- Basic info
    name = "unam",
    description = "ides",
    hotkey = "uhot",
    tooltip = "utip",
    uber_tooltip = "utub",

    -- Costs
    gold_cost = "igol",
    lumber_cost = "ilum",
    level = "ilev",
    stock_max = "isma",
    stock_regen = "isrg",
    stock_start = "isst",

    -- Classification
    class = "icla",
    armor_type = "iarm",
    priority = "ipri",

    -- Stats
    hp = "ihtp",
    hp_regen = "ihpr",
    mana = "imtp",
    mana_regen = "impr",
    damage_bonus = "idam",
    armor_bonus = "idef",
    str_bonus = "istr",
    agi_bonus = "iagi",
    int_bonus = "iint",
    attack_speed_bonus = "ispe",
    move_speed_bonus = "imov",
    life_steal = "ivam",
    spell_damage_bonus = "isdb",
    sight_bonus = "isig",

    -- Abilities
    abilities = "iabi",
    cooldown_id = "icid",
    ignores_cooldown = "iicd",

    -- Visual
    icon = "iico",
    model = "ifil",
    scale = "isca",
    color_red = "iclr",
    color_green = "iclg",
    color_blue = "iclb",
    tinting_color = "iclc",

    -- Flags
    is_sellable = "isel",
    is_pawnable = "ipaw",
    is_droppable = "idro",
    is_powerup = "ipow",
    is_perishable = "iper",
    is_usable = "iusa",
    include_in_random = "iprn",

    -- Uses
    uses = "iuse",

    -- Sound
    drop_sound = "idps",
}

-- Reverse mapping
w3t.FIELD_NAMES = {}
for name, id in pairs(w3t.FIELDS) do
    w3t.FIELD_NAMES[id] = name
end

-- Item classes
w3t.ITEM_CLASS = {
    PERMANENT = "Permanent",
    CHARGED = "Charged",
    POWERUP = "PowerUp",
    ARTIFACT = "Artifact",
    PURCHASABLE = "Purchasable",
    CAMPAIGN = "Campaign",
    MISCELLANEOUS = "Miscellaneous",
}
-- }}}

-- {{{ w3t.parse
-- Parse w3t binary data.
-- @param data Binary string
-- @return ItemDataTable or nil and error
function w3t.parse(data)
    local result, err = objectdata.parse(data, {
        has_level_column = false,  -- Items don't use level/column
    })

    if not result then
        return nil, err
    end

    -- Extend with w3t-specific methods
    setmetatable(result, { __index = w3t.ItemDataTable })
    return result
end
-- }}}

-- {{{ ItemDataTable class
w3t.ItemDataTable = setmetatable({}, { __index = objectdata.ObjectDataTable })

-- {{{ ItemDataTable:get_stat
-- Get an item stat by friendly name.
-- @param id Item ID
-- @param stat_name Friendly stat name
-- @return Stat value or nil
function w3t.ItemDataTable:get_stat(id, stat_name)
    local field_id = w3t.FIELDS[stat_name] or stat_name
    return self:get_modification(id, field_id)
end
-- }}}

-- {{{ ItemDataTable:get_all_stats
-- Get all modified stats for an item.
-- @param id Item ID
-- @return Table of {stat_name = value}
function w3t.ItemDataTable:get_all_stats(id)
    local obj = self:get(id)
    if not obj then return {} end

    local stats = {}
    for _, mod in ipairs(obj.modifications) do
        local name = w3t.FIELD_NAMES[mod.field_id] or mod.field_id
        stats[name] = mod.value
    end
    return stats
end
-- }}}

-- {{{ ItemDataTable:get_costs
-- Get resource costs for an item.
-- @param id Item ID
-- @return Table with cost info
function w3t.ItemDataTable:get_costs(id)
    return {
        gold = self:get_stat(id, "gold_cost"),
        lumber = self:get_stat(id, "lumber_cost"),
        level = self:get_stat(id, "level"),
    }
end
-- }}}

-- {{{ ItemDataTable:get_bonuses
-- Get stat bonuses from an item.
-- @param id Item ID
-- @return Table of stat bonuses
function w3t.ItemDataTable:get_bonuses(id)
    return {
        hp = self:get_stat(id, "hp"),
        hp_regen = self:get_stat(id, "hp_regen"),
        mana = self:get_stat(id, "mana"),
        mana_regen = self:get_stat(id, "mana_regen"),
        damage = self:get_stat(id, "damage_bonus"),
        armor = self:get_stat(id, "armor_bonus"),
        str = self:get_stat(id, "str_bonus"),
        agi = self:get_stat(id, "agi_bonus"),
        int = self:get_stat(id, "int_bonus"),
        attack_speed = self:get_stat(id, "attack_speed_bonus"),
        move_speed = self:get_stat(id, "move_speed_bonus"),
        life_steal = self:get_stat(id, "life_steal"),
        spell_damage = self:get_stat(id, "spell_damage_bonus"),
    }
end
-- }}}

-- {{{ ItemDataTable:get_class
-- Get the item class.
-- @param id Item ID
-- @return Class string or nil
function w3t.ItemDataTable:get_class(id)
    return self:get_stat(id, "class")
end
-- }}}

-- {{{ ItemDataTable:is_sellable
-- Check if item can be sold.
-- @param id Item ID
-- @return boolean
function w3t.ItemDataTable:is_sellable(id)
    local val = self:get_stat(id, "is_sellable")
    return val == nil or val == 1  -- Default true
end
-- }}}

-- {{{ ItemDataTable:is_droppable
-- Check if item can be dropped.
-- @param id Item ID
-- @return boolean
function w3t.ItemDataTable:is_droppable(id)
    local val = self:get_stat(id, "is_droppable")
    return val == nil or val == 1  -- Default true
end
-- }}}

-- {{{ ItemDataTable:is_powerup
-- Check if item is a powerup (consumed on pickup).
-- @param id Item ID
-- @return boolean
function w3t.ItemDataTable:is_powerup(id)
    local val = self:get_stat(id, "is_powerup")
    return val == 1
end
-- }}}

-- {{{ ItemDataTable:get_uses
-- Get number of uses (charges).
-- @param id Item ID
-- @return Number of uses or nil
function w3t.ItemDataTable:get_uses(id)
    return self:get_stat(id, "uses")
end
-- }}}

-- {{{ ItemDataTable:get_abilities
-- Get abilities granted by the item.
-- @param id Item ID
-- @return Array of ability IDs
function w3t.ItemDataTable:get_abilities(id)
    local abi_str = self:get_stat(id, "abilities")
    if not abi_str or abi_str == "" then
        return {}
    end

    local abilities = {}
    for abi in abi_str:gmatch("([^,]+)") do
        abilities[#abilities + 1] = abi
    end
    return abilities
end
-- }}}

-- }}}

return w3t
