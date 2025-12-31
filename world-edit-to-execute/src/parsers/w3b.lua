--[[
war3map.w3b Parser - Destructible Object Data

Parses destructible modifications from the World Editor.
Destructibles do NOT use level/column format.

Usage:
  local w3b = require("parsers.w3b")
  local destructibles = w3b.parse(data)

  -- Get destructible info
  local tree = destructibles:get("ATtr")

  -- Get stat
  local hp = destructibles:get_stat("ATtr", "hp")
]]

local objectdata = require("parsers.objectdata")

local w3b = {}

-- {{{ Field ID mappings
w3b.FIELDS = {
    -- Basic info
    name = "bnam",
    editor_suffix = "bsuf",
    category = "bcat",

    -- Stats
    hp = "bhps",
    occlude_height = "boch",

    -- Visual
    model = "bfil",
    portrait = "bptx",
    icon = "bico",
    scale = "bscl",
    variation = "bvar",
    color_red = "bclr",
    color_green = "bclg",
    color_blue = "bclb",
    shadow = "bshd",
    uberplat = "bups",
    selectable = "bgse",
    selection_scale = "bsel",
    minimap_color = "bmmc",
    minimap_show = "bsmm",

    -- Pathing
    pathing_texture = "bptx",
    walkable = "bwal",
    cliffable = "bcli",
    flyable = "bfly",
    buildable = "bbui",

    -- Sound
    death_sound = "bdsn",
    looping_sound = "bsnd",

    -- Targeting
    target_type = "btar",
    armor_type = "barm",

    -- Death
    death_type = "bdea",
    elevated = "bele",
    fog_visibility = "bfog",

    -- Combat
    can_be_targeted = "btgt",
    can_attack = "batk",
}

-- Reverse mapping
w3b.FIELD_NAMES = {}
for name, id in pairs(w3b.FIELDS) do
    w3b.FIELD_NAMES[id] = name
end
-- }}}

-- {{{ w3b.parse
-- Parse w3b binary data.
-- @param data Binary string
-- @return DestructibleDataTable or nil and error
function w3b.parse(data)
    local result, err = objectdata.parse(data, {
        has_level_column = false,  -- Destructibles don't use level/column
    })

    if not result then
        return nil, err
    end

    -- Extend with w3b-specific methods
    setmetatable(result, { __index = w3b.DestructibleDataTable })
    return result
end
-- }}}

-- {{{ DestructibleDataTable class
w3b.DestructibleDataTable = setmetatable({}, { __index = objectdata.ObjectDataTable })

-- {{{ DestructibleDataTable:get_stat
-- Get a destructible stat by friendly name.
-- @param id Destructible ID
-- @param stat_name Friendly stat name
-- @return Stat value or nil
function w3b.DestructibleDataTable:get_stat(id, stat_name)
    local field_id = w3b.FIELDS[stat_name] or stat_name
    return self:get_modification(id, field_id)
end
-- }}}

-- {{{ DestructibleDataTable:get_all_stats
-- Get all modified stats for a destructible.
-- @param id Destructible ID
-- @return Table of {stat_name = value}
function w3b.DestructibleDataTable:get_all_stats(id)
    local obj = self:get(id)
    if not obj then return {} end

    local stats = {}
    for _, mod in ipairs(obj.modifications) do
        local name = w3b.FIELD_NAMES[mod.field_id] or mod.field_id
        stats[name] = mod.value
    end
    return stats
end
-- }}}

-- {{{ DestructibleDataTable:is_walkable
-- Check if destructible allows walking.
-- @param id Destructible ID
-- @return boolean
function w3b.DestructibleDataTable:is_walkable(id)
    local val = self:get_stat(id, "walkable")
    return val == 1
end
-- }}}

-- {{{ DestructibleDataTable:is_selectable
-- Check if destructible can be selected.
-- @param id Destructible ID
-- @return boolean
function w3b.DestructibleDataTable:is_selectable(id)
    local val = self:get_stat(id, "selectable")
    return val == nil or val == 1  -- Default true
end
-- }}}

-- {{{ DestructibleDataTable:get_pathing
-- Get pathing flags for a destructible.
-- @param id Destructible ID
-- @return Table with pathing info
function w3b.DestructibleDataTable:get_pathing(id)
    return {
        walkable = self:get_stat(id, "walkable"),
        flyable = self:get_stat(id, "flyable"),
        buildable = self:get_stat(id, "buildable"),
        cliffable = self:get_stat(id, "cliffable"),
    }
end
-- }}}

-- }}}

return w3b
