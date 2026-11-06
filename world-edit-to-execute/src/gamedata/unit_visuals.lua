--[[
unit_visuals.lua - each unit type's art fields, read from object data: the map's changes over the stock row

Issue 503b. For every unit type a map uses, the fields the renderer needs to
draw it: the model path, its scale, its tint, the selection circle's size,
whether it is a building and how it moves. Read from 112's rows (the stock
row with the map's changes on top, gamedata/stock_rows.lua), so a map that
rescales or recolours a unit is drawn as it asked.

Which table and column holds each field is not written here: it comes from
the metadata table's row for the field's code (Units\UnitMetaData.slk), the
same way stock_rows lays a map's changes over a stock row. So a version
whose tables keep the model path in UnitUI.slk and one that keeps it in a
profile text file both answer.

  field       code  meaning
  model       umdl  the model path the map asks for (516's chooser looks it up)
  scale       usca  the model's scale, 1 = as made
  red/green/  uclr  the tint, 0-255 each, 255 = no tint
    blue      uclg
              uclb
  selection   ussc  the selection circle's scale
  building    ubdg  true for buildings
  move_type   umvt  "foot", "horse", "fly", "hover", "float", "amph" or "" (none)

The placeholder shape (503a's four, drawn when no model can be found or
read) follows from these: a building is a cube, a flyer a triangle, a large
unit (selection scale 1.5 or more) a cylinder, any other a circle.

Usage:
  local stock_rows = require("gamedata.stock_rows")
  local unit_visuals = require("gamedata.unit_visuals")
  local stock = stock_rows.load(chain, "units")
  local merged = stock_rows.merge(stock, parsed_w3u)        -- or { rows = {} } for a map with no w3u
  local result = unit_visuals.for_types(stock, merged, { "hfoo", "h000" })
  result.rows.h000   -- { id, parent, model, scale, tint = { r, g, b }, selection, building,
                     --   move_type, flyer, shape, from_map = { scale = true, ... } }
  result.problems    -- { kind ("unknown_type", "no_metadata"), id, code, problem }

Issue: issues/503b-unit-visual-mappings.md
]]

local M = {}

-- The art fields and their codes in the unit metadata table.
M.CODES = {
    model = "umdl",
    scale = "usca",
    red = "uclr",
    green = "uclg",
    blue = "uclb",
    selection = "ussc",
    building = "ubdg",
    move_type = "umvt",
}

-- The order fields are read in, so problems come out in a fixed order.
local FIELD_ORDER = { "model", "scale", "red", "green", "blue", "selection", "building", "move_type" }

-- At or above this selection scale a ground unit's placeholder is the
-- cylinder rather than the circle (decided 2026-11-06, in the issue).
M.LARGE_SELECTION = 1.5

-- {{{ local function stock_fields
-- A stock type's columns, per table, as stock_rows keeps them (nil when no
-- table has the id). The rows are read, never copied or changed.
local function stock_fields(stock, id)
    local fields, found = {}, false
    for table_name, sheet in pairs(stock.tables or {}) do
        local row = sheet.rows and sheet.rows[id]
        if row then
            fields[table_name] = row
            found = true
        end
    end
    local profile = stock.profile and stock.profile[id]
    if profile then
        fields.Profile = profile
        found = true
    end
    if not found then
        return nil
    end
    return fields
end
-- }}}

-- {{{ local function number_or
local function number_or(value, default)
    local n = tonumber(value)
    if n == nil then
        return default
    end
    return n
end
-- }}}

-- {{{ local function flag
-- A table's 0/1 flag; profile files and maps may write "1"/"0" or true/false.
local function flag(value)
    if value == true then return true end
    local n = tonumber(value)
    return n ~= nil and n ~= 0
end
-- }}}

-- {{{ function M.placeholder
-- The placeholder shape for a type's row: "cube", "triangle", "cylinder"
-- or "circle" (render.MESH_TYPES' names).
function M.placeholder(row)
    if row.building then
        return "cube"
    end
    if row.flyer then
        return "triangle"
    end
    if (row.selection or 0) >= M.LARGE_SELECTION then
        return "cylinder"
    end
    return "circle"
end
-- }}}

-- {{{ function M.of
-- One type's row. merged is stock_rows.merge's result (its rows win: they
-- carry the map's changes); a type the map doesn't change is read from the
-- stock tables. Returns the row, or nil and a problem when neither has it.
-- Codes the metadata doesn't describe are listed in row.no_metadata.
function M.of(stock, merged, id)
    local merged_row = merged and merged.rows and merged.rows[id]
    local fields, origin, parent
    if merged_row then
        fields, origin, parent = merged_row.fields, merged_row.origin or {}, merged_row.parent
    else
        fields, origin, parent = stock_fields(stock, id), {}, id
    end
    if not fields then
        return nil, { kind = "unknown_type", id = id, problem = "unit type " .. tostring(id)
            .. " is in neither the map's object data nor the stock tables" }
    end

    local raw, from_map, no_metadata = {}, {}, {}
    for _, name in ipairs(FIELD_ORDER) do
        local code = M.CODES[name]
        local meta = stock.metadata and stock.metadata.rows and stock.metadata.rows[code]
        if not meta then
            no_metadata[#no_metadata + 1] = code
        else
            local table_name, column = tostring(meta.slk), tostring(meta.field)
            local values = fields[table_name]
            raw[name] = values and values[column]
            if origin[table_name] and origin[table_name][column] == "map" then
                from_map[name] = true
            end
        end
    end

    local model = raw.model
    if type(model) ~= "string" or model == "" or model == "_" then
        model = nil                                  -- "_" is the tables' "nothing here"
    end
    local move_type = raw.move_type
    if type(move_type) ~= "string" or move_type == "_" then
        move_type = ""
    end
    local row = {
        id = id,
        parent = parent,
        model = model,
        scale = number_or(raw.scale, 1),
        tint = { r = number_or(raw.red, 255), g = number_or(raw.green, 255), b = number_or(raw.blue, 255) },
        selection = number_or(raw.selection, 1),
        building = flag(raw.building),
        move_type = move_type,
        from_map = from_map,
        no_metadata = no_metadata,
    }
    row.flyer = move_type == "fly"
    row.shape = M.placeholder(row)
    return row
end
-- }}}

-- {{{ function M.for_types
-- Rows for a list of type ids (duplicates read once). Returns
-- { rows = id -> row, problems = list, counts = { types, from_map, unknown } }.
function M.for_types(stock, merged, ids)
    local result = { rows = {}, problems = {}, counts = { types = 0, from_map = 0, unknown = 0 } }
    local missing_codes, failed = {}, {}
    for _, id in ipairs(ids) do
        if result.rows[id] == nil and not failed[id] then
            local row, problem = M.of(stock, merged, id)
            if row then
                result.rows[id] = row
                result.counts.types = result.counts.types + 1
                if next(row.from_map) then
                    result.counts.from_map = result.counts.from_map + 1
                end
                for _, code in ipairs(row.no_metadata) do
                    missing_codes[code] = true
                end
            else
                failed[id] = true
                result.problems[#result.problems + 1] = problem
                result.counts.unknown = result.counts.unknown + 1
            end
        end
    end
    -- One problem per code the metadata lacks, not one per type.
    for _, name in ipairs(FIELD_ORDER) do
        local code = M.CODES[name]
        if missing_codes[code] then
            result.problems[#result.problems + 1] = { kind = "no_metadata", code = code,
                problem = "the unit metadata table has no row for " .. code .. " (" .. name .. "); defaults used" }
        end
    end
    return result
end
-- }}}

return M
