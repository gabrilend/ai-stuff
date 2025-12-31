--[[
war3map.w3h Parser - Buff/Effect Object Data

Parses buff/effect modifications from the World Editor.
Buffs do NOT use level/column format.

Usage:
  local w3h = require("parsers.w3h")
  local buffs = w3h.parse(data)

  -- Get buff info
  local slow = buffs:get("Bslo")

  -- Get stat
  local tooltip = buffs:get_stat("Bslo", "tooltip")
]]

local objectdata = require("parsers.objectdata")

local w3h = {}

-- {{{ Field ID mappings
w3h.FIELDS = {
    -- Basic info
    name = "fnam",
    editor_suffix = "fnsf",
    tooltip = "ftip",
    uber_tooltip = "fube",
    race = "frac",

    -- Visual
    icon = "fart",
    effect_art = "feat",
    effect_attach = "feft",
    effect_attach_point = "fefp",
    target_art = "ftat",
    target_attach = "ftat",
    target_attach_point = "ftp1",
    special_art = "fsat",
    special_attach = "fspt",
    lightning_effect = "flig",
    missile_art = "fmat",
    missile_speed = "fmsp",
    missile_arc = "fmac",
    missile_homing = "fmho",

    -- Sound
    effect_sound = "fefs",
    effect_sound_looping = "fefl",

    -- Flags
    is_effect = "feff",
}

-- Reverse mapping
w3h.FIELD_NAMES = {}
for name, id in pairs(w3h.FIELDS) do
    w3h.FIELD_NAMES[id] = name
end
-- }}}

-- {{{ w3h.parse
-- Parse w3h binary data.
-- @param data Binary string
-- @return BuffDataTable or nil and error
function w3h.parse(data)
    local result, err = objectdata.parse(data, {
        has_level_column = false,  -- Buffs don't use level/column
    })

    if not result then
        return nil, err
    end

    -- Extend with w3h-specific methods
    setmetatable(result, { __index = w3h.BuffDataTable })
    return result
end
-- }}}

-- {{{ BuffDataTable class
w3h.BuffDataTable = setmetatable({}, { __index = objectdata.ObjectDataTable })

-- {{{ BuffDataTable:get_stat
-- Get a buff stat by friendly name.
-- @param id Buff ID
-- @param stat_name Friendly stat name
-- @return Stat value or nil
function w3h.BuffDataTable:get_stat(id, stat_name)
    local field_id = w3h.FIELDS[stat_name] or stat_name
    return self:get_modification(id, field_id)
end
-- }}}

-- {{{ BuffDataTable:get_all_stats
-- Get all modified stats for a buff.
-- @param id Buff ID
-- @return Table of {stat_name = value}
function w3h.BuffDataTable:get_all_stats(id)
    local obj = self:get(id)
    if not obj then return {} end

    local stats = {}
    for _, mod in ipairs(obj.modifications) do
        local name = w3h.FIELD_NAMES[mod.field_id] or mod.field_id
        stats[name] = mod.value
    end
    return stats
end
-- }}}

-- {{{ BuffDataTable:get_visual
-- Get visual effect information.
-- @param id Buff ID
-- @return Table with visual info
function w3h.BuffDataTable:get_visual(id)
    return {
        icon = self:get_stat(id, "icon"),
        effect_art = self:get_stat(id, "effect_art"),
        effect_attach = self:get_stat(id, "effect_attach_point"),
        target_art = self:get_stat(id, "target_art"),
        target_attach = self:get_stat(id, "target_attach_point"),
        special_art = self:get_stat(id, "special_art"),
        lightning = self:get_stat(id, "lightning_effect"),
    }
end
-- }}}

-- {{{ BuffDataTable:get_missile
-- Get missile information if present.
-- @param id Buff ID
-- @return Table with missile info or nil
function w3h.BuffDataTable:get_missile(id)
    local art = self:get_stat(id, "missile_art")
    if not art then return nil end

    return {
        art = art,
        speed = self:get_stat(id, "missile_speed"),
        arc = self:get_stat(id, "missile_arc"),
        homing = self:get_stat(id, "missile_homing") == 1,
    }
end
-- }}}

-- {{{ BuffDataTable:is_effect
-- Check if this is an effect (vs a buff).
-- @param id Buff ID
-- @return boolean
function w3h.BuffDataTable:is_effect(id)
    local val = self:get_stat(id, "is_effect")
    return val == 1
end
-- }}}

-- }}}

return w3h
