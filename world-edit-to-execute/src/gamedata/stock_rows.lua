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
  3. labels every column by whose it is (field_rules.lua): "fact",
     "borrowed" (Blizzard's text and art, on the replacement track),
     "editor" (no metadata row, not read by the game) or "map" (the map
     changed it). Everything is copied; the labels let the replacement work
     count what is still borrowed, object by object.

Problems are collected, never skipped silently: a change whose code has no
metadata row, a parent id not in the stock tables, a profile file missing
from the chain.

Usage:
  local stock_rows = require("gamedata.stock_rows")
  local stock = stock_rows.load(chain, "abilities")
  local result = stock_rows.merge(stock, parsed_object_file)
  result.rows["A003"]      -- { id, parent, fields = { AbilityData = {...}, Profile = {...} },
                           --   origin = { AbilityData = { Cool1 = "fact", ... }, Profile = { Art = "borrowed", ... } } }
  result.problems          -- list of { kind ("orphan", "unknown_parent", "unknown_code"), object, code, problem }
  result.counts            -- objects, changes, applied, borrowed (columns still Blizzard's),
                           --   map_table_only (objects only the map's own tables define), and one count per problem kind

Open the chain with the map (chain.open{..., map = path}): some maps ship
their own object tables, and objects defined only there get rows too
(defined_in = "map table").

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
    local stock = { kind = kind_name, rules = kind, tables = {}, profile = {}, missing = {}, map_defined = {} }
    stock.metadata = slk.parse((chain:read(kind.metadata)))
    for table_name, path in pairs(kind.tables) do
        local bytes, source = chain:read(path)
        stock.tables[table_name] = slk.parse(bytes)
        -- A map that ships its own copy of a table (map optimizers do this)
        -- can define objects there and nowhere else. Those ids are the ones
        -- the stock copy beneath lacks; merge gives each one a row.
        if source:match("^map: ") then
            local beneath = slk.parse((chain:read(path, { below_map = true })))
            for _, id in ipairs(stock.tables[table_name].order) do
                if not beneath.rows[id] then
                    stock.map_defined[id] = true
                end
            end
        end
    end
    for _, path in ipairs(kind.profiles) do
        if chain:find(path) then
            profile.parse((chain:read(path)), stock.profile)
        else
            stock.missing[#stock.missing + 1] = path
        end
    end

    -- Which columns each metadata row covers, for the labels:
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
    local prefixes = stock.prefix_types[table_name]
    if not prefixes then
        return nil
    end
    -- Profile files keep a level-dependent field under its bare name, all
    -- levels comma-separated in one value (Tip=..., not Tip1=...), so the bare
    -- name is tried before the name-plus-level form tables use (Cool1).
    if prefixes[column] then
        return prefixes[column]
    end
    local prefix = column:match("^(.-)%d+$")
    if prefix then
        return prefixes[prefix]
    end
    return nil
end
-- }}}

-- {{{ local function label_for
-- Whose a stock column is: "fact", "borrowed" or "editor" (see field_rules).
local function label_for(stock, table_name, column)
    local ids = rules.id_columns[table_name]
    if ids and ids[column] then
        return "fact"                      -- an id the game needs, though no metadata row names it
    end
    local kind = column_type(stock, table_name, column)
    if kind == nil then
        return "editor"                    -- comments, sort keys, beta flags: copied, never read by the game
    end
    if rules.borrowed_types[kind] then
        return "borrowed"                  -- Blizzard's text or art, until replaced
    end
    return "fact"
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
-- The stock parent's columns, every one, per table, each with its label;
-- nil when no table has the parent.
local function copy_stock(stock, parent)
    local fields, origin, found = {}, {}, false
    local function copy(table_name, row)
        fields[table_name], origin[table_name] = {}, {}
        if row then
            found = true
            for column, value in pairs(row) do
                fields[table_name][column] = value
                origin[table_name][column] = label_for(stock, table_name, column)
            end
        end
    end
    for table_name, sheet in pairs(stock.tables) do
        copy(table_name, sheet.rows[parent])
    end
    copy("Profile", stock.profile[parent])
    if not found then
        return nil
    end
    return fields, origin
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
    local result = { rows = {}, problems = {}, counts = { objects = 0, changes = 0, applied = 0, borrowed = 0 } }
    local function problem(kind, object, code, text)
        result.problems[#result.problems + 1] = { kind = kind, object = object, code = code, problem = text }
        result.counts[kind] = (result.counts[kind] or 0) + 1
    end

    local emitted = {}
    for _, object in ipairs(objects_in(parsed)) do
        result.counts.objects = result.counts.objects + 1
        local id, parent = object.id, object.parent
        local fields, origin = copy_stock(stock, parent)
        emitted[id] = true
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
                    -- The map's value replaces the stock one, whatever its type:
                    -- a name or model path the map author set is theirs, not Blizzard's.
                    fields[table_name] = fields[table_name] or {}
                    origin[table_name] = origin[table_name] or {}
                    fields[table_name][column] = change.value
                    origin[table_name][column] = "map"
                    result.counts.applied = result.counts.applied + 1
                end
            end
            for _, labels in pairs(origin) do
                for _, label in pairs(labels) do
                    if label == "borrowed" then
                        result.counts.borrowed = result.counts.borrowed + 1
                    end
                end
            end
            result.rows[id] = { id = id, parent = parent, fields = fields, origin = origin }
        end
    end

    -- Objects defined only in the map's own copy of a table, which the map's
    -- change file never mentions: their row is the map's table row as it
    -- stands. Labels stay by type (an optimizer copies stock text too, so a
    -- name here may still be Blizzard's). Parent is the base ability code
    -- where the table has one, else the object itself.
    local defined = {}
    for id in pairs(stock.map_defined) do
        if not emitted[id] then
            defined[#defined + 1] = id
        end
    end
    table.sort(defined)
    for _, id in ipairs(defined) do
        local fields, origin = copy_stock(stock, id)
        local base = fields.AbilityData and fields.AbilityData.code
        result.counts.objects = result.counts.objects + 1
        result.counts.map_table_only = (result.counts.map_table_only or 0) + 1
        result.rows[id] = { id = id, parent = type(base) == "string" and base or id, fields = fields,
            origin = origin, defined_in = "map table" }
        for _, labels in pairs(origin) do
            for _, label in pairs(labels) do
                if label == "borrowed" then
                    result.counts.borrowed = result.counts.borrowed + 1
                end
            end
        end
    end
    return result
end
-- }}}

return M
