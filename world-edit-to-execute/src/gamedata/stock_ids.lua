--[[
stock_ids.lua - which object ids the game itself defines, as a map's game data chain has them

Issue 112 (its criterion "the cross-reference validator looks stock ids up in
the map's chain instead of assuming them valid"). The validator meets ids a
map uses but doesn't define (a placed footman, a dropped Claws of Attack) and
asks this module whether the game defines them.

The answer comes from the first column of each kind's stock table, read
through the map's chain (gamedata/chain.lua), so a map's own copy of a table
(map optimizers ship them) and the map's patch layer and data set are what
count:

  unit          Units\UnitData.slk
  item          Units\ItemData.slk
  ability       Units\AbilityData.slk
  destructible  Units\DestructableData.slk
  doodad        Doodads\Doodads.slk

A table is read the first time its kind is asked about, and kept.

Usage:
  local stock_ids = require("gamedata.stock_ids")
  local c = chain.open({ install = ..., layers = ..., w3i = parsed_w3i, map = path })
  local stock = stock_ids.from_chain(c)
  stock:has("unit", "hfoo")     -- true; false when the table lacks it;
                                --   nil when the chain has no such table
  stock:find({ "unit", "item" }, "ratc")   -- "item" (the first kind that has it), or false/nil
  stock.searched                -- "patch layer 1.29.2, data set Custom_V1": what was searched,
                                --   for messages
  stock:missing("doodad")       -- the table's path when the chain lacks it, else nil

  -- for tests, or ids gathered elsewhere:
  local stock = stock_ids.from_sets({ unit = { hfoo = true } }, "a hand-made list")

Issue: issues/112-stock-object-tables-by-two-routes.md
]]

local slk = require("parsers.slk")

local M = {}

-- The table whose first column lists every id of a kind.
M.TABLES = {
    unit         = "Units\\UnitData.slk",
    item         = "Units\\ItemData.slk",
    ability      = "Units\\AbilityData.slk",
    destructible = "Units\\DestructableData.slk",
    doodad       = "Doodads\\Doodads.slk",
}

-- {{{ function M.is_random_placeholder
-- Ids the editor writes for "a random unit/item/building here", which the
-- game resolves when the map starts. No table defines them, and none should:
--   YYU + level char  a random unit of that level
--   YYI + level char  a random item of that level
--   uDNR, bDNR, iDNR  a random unit, building or item from the map's groups
function M.is_random_placeholder(id)
    if type(id) ~= "string" or #id ~= 4 then
        return false
    end
    if id:sub(1, 3) == "YYU" or id:sub(1, 3) == "YYI" then
        return true
    end
    return id == "uDNR" or id == "bDNR" or id == "iDNR"
end
-- }}}

local Stock = {}
Stock.__index = Stock

-- {{{ local function describe_chain
-- What a chain searches, in a few words: its patch layer and data set.
local function describe_chain(c)
    local layer = c.layer and ("patch layer " .. tostring(c.layer)) or "no patch layer"
    local set = c.data_set and ("data set " .. tostring(c.data_set)) or "the plain melee tables"
    return layer .. ", " .. set
end
-- }}}

-- {{{ function M.from_chain
-- A lookup over a chain. Nothing is read until a kind is first asked about.
function M.from_chain(c)
    if type(c) ~= "table" or type(c.find) ~= "function" or type(c.read) ~= "function" then
        error("stock_ids.from_chain needs a chain (gamedata/chain.lua)", 2)
    end
    local self = setmetatable({ chain = c, sets = {}, absent = {} }, Stock)
    self.searched = describe_chain(c)
    return self
end
-- }}}

-- {{{ function M.from_sets
-- A lookup over ready-made sets: kind -> id -> true. A kind left out is
-- treated as a table the chain lacks.
function M.from_sets(sets, searched)
    local self = setmetatable({ sets = {}, absent = {} }, Stock)
    for kind, path in pairs(M.TABLES) do
        if sets[kind] then
            self.sets[kind] = sets[kind]
        else
            self.absent[kind] = path
        end
    end
    self.searched = searched or "a list given by hand"
    return self
end
-- }}}

-- {{{ function Stock:load
-- Reads one kind's table through the chain, once. Returns its id set, or
-- nil when the chain has no such table.
function Stock:load(kind)
    local path = M.TABLES[kind]
    if not path then
        error("stock_ids: unknown kind " .. tostring(kind), 2)
    end
    if self.sets[kind] then
        return self.sets[kind]
    end
    if self.absent[kind] or not self.chain then
        self.absent[kind] = path
        return nil
    end
    if not self.chain:find(path) then
        self.absent[kind] = path
        return nil
    end
    local sheet = slk.parse((self.chain:read(path)))
    local set = {}
    for _, id in ipairs(sheet.order) do
        set[id] = true
    end
    self.sets[kind] = set
    return set
end
-- }}}

-- {{{ function Stock:has
-- true when the kind's table lists the id, false when it doesn't, nil when
-- the chain has no such table (nothing could be checked).
function Stock:has(kind, id)
    local set = self:load(kind)
    if not set then
        return nil
    end
    return set[id] == true
end
-- }}}

-- {{{ function Stock:find
-- The first of several kinds whose table lists the id; false when every
-- table was read and none does; nil when none does and at least one table
-- was missing (so the answer isn't known).
function Stock:find(kinds, id)
    local unknown = false
    for _, kind in ipairs(kinds) do
        local found = self:has(kind, id)
        if found then
            return kind
        elseif found == nil then
            unknown = true
        end
    end
    if unknown then
        return nil
    end
    return false
end
-- }}}

-- {{{ function Stock:missing
-- The path of the kind's table when the chain lacks it, else nil.
function Stock:missing(kind)
    self:load(kind)
    return self.absent[kind]
end
-- }}}

M.Stock = Stock

return M
