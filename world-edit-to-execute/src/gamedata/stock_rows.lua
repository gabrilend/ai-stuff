--[[
stock_rows.lua - each custom object's full row: its stock parent's row with the map's changes on top

Route A of issue 112 (sub-issue 112c). For one object kind (abilities, units,
items), reads the stock tables through a map's game data chain
(gamedata/chain.lua), then for every custom object in the map's object file:

  1. copies the stock parent's row from every table of that kind, and its
     profile text entries;
  2. applies each change: its field code is looked up in the metadata table,
     which names the table and column (level-dependent fields become
     field..level, "Cool1"; ability data fields "Data"..letter..level,
     "DataA1");
  3. keeps only functional columns: those whose metadata type isn't in
     field_rules.dropped_types, plus field_rules.always_kept.

Problems are collected, never skipped silently: a change whose code has no
metadata row, a parent id not in the stock tables, a profile file missing
from the chain.

Usage:
  local stock_rows = require("gamedata.stock_rows")
  local stock = stock_rows.load(chain, "abilities")
  local result = stock_rows.merge(stock, parsed_object_file)
  result.rows["A003"]      -- { id, parent, fields = { AbilityData = {...}, Profile = {...} } }
  result.problems          -- list of { kind ("orphan", "unknown_parent", "unknown_code"), object, code, problem }
  result.counts            -- objects, changes, applied, not_functional, and one count per problem kind

Issue: issues/112c-route-a-stock-rows-merged-with-map-objects.md
]]

local slk = require("parsers.slk")
local profile = require("parsers.profile_txt")
local rules = require("gamedata.field_rules")

local M = {}

local LETTERS = "ABCDEFGHI"

-- {{{ function M.load
-- Reads a kind's metadata, stock tables and profile files through a chain.
-- A missing stock table or metadata table is an error; a missing profile
-- file is recorded in stock.missing.
function M.load(chain, kind_name)
    local kind = rules.kinds[kind_name]
    if not kind then
        error("unknown object kind " .. tostring(kind_name))
    end
    local stock = { kind = kind_name, rules = kind, tables = {}, profile = {}, missing = {} }
    stock.metadata = slk.parse((chain:read(kind.metadata)))
    for table_name, path in pairs(kind.tables) do
        stock.tables[table_name] = slk.parse((chain:read(path)))
    end
    for _, path in ipairs(kind.profiles) do
        if chain:find(path) then
            profile.parse((chain:read(path)), stock.profile)
        else
            stock.missing[#stock.missing + 1] = path
        end
    end

    -- Which columns each metadata row covers, for the functional filter:
    -- table -> column name (or column prefix for level-dependent fields) -> type.
    stock.column_types = {}
    stock.prefix_types = {}
    for _, code in ipairs(stock.metadata.order) do
        local meta = stock.metadata.rows[code]
        local table_name = tostring(meta.slk)
        stock.column_types[table_name] = stock.column_types[table_name] or {}
        stock.prefix_types[table_name] = stock.prefix_types[table_name] or {}
        local field = tostring(meta.field)
        local data = tonumber(meta.data) or 0
        local levels = tonumber(meta["repeat"]) or 0
        if data > 0 then
            stock.prefix_types[table_name][field .. LETTERS:sub(data, data)] = tostring(meta.type)
        elseif levels > 0 then
            stock.prefix_types[table_name][field] = tostring(meta.type)
        else
            stock.column_types[table_name][field] = tostring(meta.type)
        end
    end
    return stock
end
-- }}}

-- {{{ local function column_type
-- The metadata type covering a column, or nil when no metadata row does.
local function column_type(stock, table_name, column)
    local exact = stock.column_types[table_name] and stock.column_types[table_name][column]
    if exact then
        return exact
    end
    local prefix = column:match("^(.-)%d+$")
    if prefix and stock.prefix_types[table_name] then
        return stock.prefix_types[table_name][prefix]
    end
    return nil
end
-- }}}

-- {{{ local function is_functional
local function is_functional(stock, table_name, column)
    local kept = rules.always_kept[table_name]
    if kept and kept[column] then
        return true
    end
    local kind = column_type(stock, table_name, column)
    if kind == nil then
        return false                       -- editor-only columns (comments, sort, …)
    end
    return rules.dropped_types[kind] == nil
end
-- }}}

-- {{{ local function column_for
-- The table and column a change writes, from its metadata row.
local function column_for(meta, level, data_column)
    local field = tostring(meta.field)
    local data = tonumber(meta.data) or 0
    local levels = tonumber(meta["repeat"]) or 0
    if data > 0 then
        return field .. LETTERS:sub(data, data) .. level
    elseif levels > 0 then
        return field .. level
    end
    return field
end
-- }}}

-- {{{ local function copy_stock
-- The stock parent's functional columns, per table; nil when no table has it.
local function copy_stock(stock, parent)
    local fields, found = {}, false
    for table_name, sheet in pairs(stock.tables) do
        local row = sheet.rows[parent]
        fields[table_name] = {}
        if row then
            found = true
            for column, value in pairs(row) do
                if is_functional(stock, table_name, column) then
                    fields[table_name][column] = value
                end
            end
        end
    end
    fields.Profile = {}
    local entry = stock.profile[parent]
    if entry then
        found = true
        for key, value in pairs(entry) do
            if is_functional(stock, "Profile", key) then
                fields.Profile[key] = value
            end
        end
    end
    return found and fields or nil
end
-- }}}

-- {{{ local function objects_in
-- parsers.objectdata keeps two tables keyed by id: "original" (stock objects
-- the map changes in place: parent is the object itself) and "custom" (new
-- objects copied from a stock parent). Returns both as one sorted list of
-- { id, parent, modifications }, so results don't depend on table order.
local function objects_in(parsed)
    local list = {}
    for id, object in pairs(parsed.original or {}) do
        list[#list + 1] = { id = id, parent = object.original_id or id, source = "original", modifications = object.modifications }
    end
    for id, object in pairs(parsed.custom or {}) do
        list[#list + 1] = { id = id, parent = object.original_id, source = "custom", modifications = object.modifications }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end
-- }}}

-- {{{ function M.merge
-- parsed: the result of parsers.objectdata for the kind's map file.
-- Returns { rows = id -> row, problems = list, counts = {...} }.
function M.merge(stock, parsed)
    local result = { rows = {}, problems = {}, counts = { objects = 0, changes = 0, applied = 0, not_functional = 0 } }
    local function problem(kind, object, code, text)
        result.problems[#result.problems + 1] = { kind = kind, object = object, code = code, problem = text }
        result.counts[kind] = (result.counts[kind] or 0) + 1
    end

    for _, object in ipairs(objects_in(parsed)) do
        result.counts.objects = result.counts.objects + 1
        local id, parent = object.id, object.parent
        local fields = copy_stock(stock, parent)
        if not fields and object.source == "original" then
            -- Seen in the DAoW maps: changes filed under an id that is neither
            -- stock nor one of the map's custom objects (leftovers from edits
            -- the map no longer uses). The game has nothing to apply them to.
            problem("orphan", id, nil, "changes to " .. id .. ", which is neither a stock object nor one of the map's custom objects")
        elseif not fields then
            problem("unknown_parent", id, nil, "stock parent " .. tostring(parent) .. " is not in the stock tables")
        else
            for _, change in ipairs(object.modifications or {}) do
                result.counts.changes = result.counts.changes + 1
                local meta = stock.metadata.rows[change.field_id]
                if not meta then
                    problem("unknown_code", id, change.field_id, "no metadata row for this field code")
                else
                    local table_name = tostring(meta.slk)
                    local column = column_for(meta, change.level or 0, change.column or 0)
                    if is_functional(stock, table_name, column) then
                        fields[table_name] = fields[table_name] or {}
                        fields[table_name][column] = change.value
                        result.counts.applied = result.counts.applied + 1
                    else
                        result.counts.not_functional = result.counts.not_functional + 1
                    end
                end
            end
            result.rows[id] = { id = id, parent = parent, fields = fields }
        end
    end
    return result
end
-- }}}

return M
