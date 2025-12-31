--[[
war3map.w3d Parser - Doodad Object Data

Parses doodad modifications from the World Editor.
Doodads USE level/column format for variation data.

Usage:
  local w3d = require("parsers.w3d")
  local doodads = w3d.parse(data)

  -- Get doodad info
  local tree = doodads:get("DTfr")

  -- Get stat at specific variation
  local model = doodads:get_stat("DTfr", "model", 1)
]]

local objectdata = require("parsers.objectdata")

local w3d = {}

-- {{{ Field ID mappings
w3d.FIELDS = {
    -- Basic info
    name = "dnam",
    category = "dcat",

    -- Visual
    model = "dfil",
    texture = "dptx",
    max_pitch = "dmap",
    max_roll = "dmar",
    visibility_radius = "dvis",
    min_scale = "dins",
    max_scale = "dmas",
    scale = "dscl",
    variation = "dvar",
    color_red = "dclr",
    color_green = "dclg",
    color_blue = "dclb",
    animation = "dani",
    animation_speed = "danr",
    shadow = "dshd",
    show_minimap = "dsmm",
    minimap_color = "dmmc",
    uses_clickable_size = "ducs",
    fixed_rotation = "dfxr",
    ignore_model_clicks = "dimc",

    -- Pathing
    pathing_texture = "dptx",
    pathing_walkable = "dwlk",
    pathing_flyable = "dfly",
    pathing_buildable = "dbld",

    -- Sound
    looping_sound = "dsnd",

    -- Placement
    can_place_dead = "dcpd",
    can_place_random_scale = "dcpr",
    use_selection_in_game = "dsel",
    occlude_boundary = "dobd",
}

-- Reverse mapping
w3d.FIELD_NAMES = {}
for name, id in pairs(w3d.FIELDS) do
    w3d.FIELD_NAMES[id] = name
end
-- }}}

-- {{{ w3d.parse
-- Parse w3d binary data.
-- @param data Binary string
-- @return DoodadDataTable or nil and error
function w3d.parse(data)
    local result, err = objectdata.parse(data, {
        has_level_column = true,  -- Doodads use level/column for variations
    })

    if not result then
        return nil, err
    end

    -- Extend with w3d-specific methods
    setmetatable(result, { __index = w3d.DoodadDataTable })
    return result
end
-- }}}

-- {{{ DoodadDataTable class
w3d.DoodadDataTable = setmetatable({}, { __index = objectdata.ObjectDataTable })

-- {{{ DoodadDataTable:get_stat
-- Get a doodad stat by friendly name and optional variation.
-- @param id Doodad ID
-- @param stat_name Friendly stat name
-- @param variation Optional variation level
-- @return Stat value or nil
function w3d.DoodadDataTable:get_stat(id, stat_name, variation)
    local field_id = w3d.FIELDS[stat_name] or stat_name
    return self:get_modification(id, field_id, variation)
end
-- }}}

-- {{{ DoodadDataTable:get_variation_data
-- Get data for all variations of a stat.
-- @param id Doodad ID
-- @param field_id Field ID to query
-- @return Table of {variation = value}
function w3d.DoodadDataTable:get_variation_data(id, field_id)
    local obj = self:get(id)
    if not obj then return {} end

    -- Resolve friendly name
    if w3d.FIELDS[field_id] then
        field_id = w3d.FIELDS[field_id]
    end

    local variations = {}
    for _, mod in ipairs(obj.modifications) do
        if mod.field_id == field_id and mod.level then
            variations[mod.level] = mod.value
        end
    end
    return variations
end
-- }}}

-- {{{ DoodadDataTable:get_all_stats
-- Get all modified stats for a doodad.
-- @param id Doodad ID
-- @return Table of stats (variation-based stats grouped)
function w3d.DoodadDataTable:get_all_stats(id)
    local obj = self:get(id)
    if not obj then return {} end

    local stats = {}
    local var_stats = {}

    for _, mod in ipairs(obj.modifications) do
        local name = w3d.FIELD_NAMES[mod.field_id] or mod.field_id

        if mod.level and mod.level > 0 then
            -- Variation-based stat
            var_stats[name] = var_stats[name] or {}
            var_stats[name][mod.level] = mod.value
        else
            -- Base stat
            stats[name] = mod.value
        end
    end

    stats._variations = var_stats
    return stats
end
-- }}}

-- {{{ DoodadDataTable:get_pathing
-- Get pathing flags for a doodad.
-- @param id Doodad ID
-- @return Table with pathing info
function w3d.DoodadDataTable:get_pathing(id)
    return {
        walkable = self:get_stat(id, "pathing_walkable"),
        flyable = self:get_stat(id, "pathing_flyable"),
        buildable = self:get_stat(id, "pathing_buildable"),
    }
end
-- }}}

-- {{{ DoodadDataTable:get_scale_range
-- Get the scale range for a doodad.
-- @param id Doodad ID
-- @return Table with min_scale, max_scale, scale
function w3d.DoodadDataTable:get_scale_range(id)
    return {
        min = self:get_stat(id, "min_scale"),
        max = self:get_stat(id, "max_scale"),
        default = self:get_stat(id, "scale"),
    }
end
-- }}}

-- }}}

return w3d
