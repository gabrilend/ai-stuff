--[[
unit_stock.lua - a unit type's values by field code: the map's change, else the stock table (Issue 525)

The units' case of gamedata/object_stock.lua (which reads every kind:
units, abilities, items, upgrades). Kept for the callers written against
it first.

    local unit_stock = require("gamedata.unit_stock")
    local S = unit_stock.new(chain, map.object_data.units)   -- chain may be nil
    S:value("hfoo", "uhpm")          -- 420, "stock"   (or 500, "map")
    S:base("h001")                   -- "hfoo": the stock type it copies
    S.available                      -- whether the stock tables were read

Issue: issues/completed/525-real-unit-stats.md
]]

local object_stock = require("gamedata.object_stock")

local unit_stock = {}

unit_stock.METADATA = object_stock.KINDS.units.metadata
unit_stock.TABLES = object_stock.KINDS.units.tables

function unit_stock.new(chain, units)
    return object_stock.new(chain, units, "units")
end

return unit_stock
