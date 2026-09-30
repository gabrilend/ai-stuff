--[[
unit_stock.lua - a unit type's values by field code: the map's change, else the stock table (Issue 525)

WC3 keeps a unit's numbers in its stock tables (Units\UnitBalance.slk,
UnitWeapons.slk, UnitData.slk ...), one row per stock unit type. A map's
object data (war3map.w3u) only holds what the map changed, filed under a
four-character field code ("uhpm", hit points), and custom types name the
stock type they copy. Units\UnitMetaData.slk says which table and column
each code lives in (uhpm -> UnitBalance, "HP").

So a value is found as the game finds it:

  1. the map's change to this type, if it made one;
  2. else the stock row of the type (or, for a custom type, the stock type
     it copies), at the column the code's metadata row names.

Stock tables come through a game data chain (gamedata/chain.lua, the
owner's install). Without one, only the map's changes are known and
value() gives nil for the rest; callers keep their stand-ins for those.

    local unit_stock = require("gamedata.unit_stock")
    local S = unit_stock.new(chain, map.object_data.units)   -- chain may be nil
    S:value("hfoo", "uhpm")          -- 420, "stock"   (or 500, "map")
    S:base("h001")                   -- "hfoo": the stock type it copies
    S.available                      -- whether the stock tables were read

Issue: issues/completed/525-real-unit-stats.md
]]

local slk = require("parsers.slk")

local unit_stock = {}

unit_stock.METADATA = "Units\\UnitMetaData.slk"
unit_stock.TABLES = {
    UnitData = "Units\\UnitData.slk", UnitBalance = "Units\\UnitBalance.slk",
    UnitWeapons = "Units\\UnitWeapons.slk", UnitAbilities = "Units\\UnitAbilities.slk",
    UnitUI = "Units\\UnitUI.slk",
}

local S = {}
S.__index = S

-- {{{ unit_stock.new
function unit_stock.new(chain, units)
    local self = setmetatable({ chain = chain, units = units, tables = {}, available = false, cache = {} }, S)
    if chain then
        local ok, bytes = pcall(chain.read, chain, unit_stock.METADATA)
        if ok and bytes then
            self.meta = slk.parse(bytes)
            self.available = true
        else
            self.error = "no " .. unit_stock.METADATA .. " (" .. tostring(bytes) .. ")"
        end
    end
    return self
end
-- }}}

-- {{{ S:table
function S:table(name)
    local t = self.tables[name]
    if t == nil then
        t = false
        local path = unit_stock.TABLES[name]
        if path and self.chain then
            local ok, bytes = pcall(self.chain.read, self.chain, path)
            if ok and bytes then t = slk.parse(bytes) end
        end
        self.tables[name] = t
    end
    return t or nil
end
-- }}}

-- {{{ S:base
-- The stock type a type's stock values come from: its parent if the map
-- made it, else itself
function S:base(id)
    local u = self.units
    if u and u.custom and u.custom[id] and u.custom[id].parent_id then return u.custom[id].parent_id end
    return id
end
-- }}}

-- {{{ S:stock_value
-- The stock table's value for a code (nil when there's none)
function S:stock_value(id, code)
    if not self.available then return nil end
    local meta = self.meta.rows[code]
    if not meta then return nil end
    local t = self:table(tostring(meta.slk))
    if not t then return nil end
    local row = t.rows[self:base(id)]
    if not row then return nil end
    local v = row[tostring(meta.field)]
    -- a field that is one entry of a comma list (index 0, 1, ...)
    local index = tonumber(meta.index)
    if index and index >= 0 and type(v) == "string" and v:find(",") then
        local k = 0
        for part in (v .. ","):gmatch("([^,]*),") do
            if k == index then v = part; break end
            k = k + 1
        end
    end
    if v == "-" or v == "_" or v == "" then return nil end
    return tonumber(v) or v
end
-- }}}

-- {{{ S:value
-- The value of code for type id, and where it came from ("map" or "stock")
function S:value(id, code)
    local key = id .. code
    local c = self.cache[key]
    if c then return c[1], c[2] end
    local v, origin
    local u = self.units
    if u and u.has and u:has(id) then
        v = u:get_modification(id, code)
        if v ~= nil then origin = "map" end
    end
    if v == nil then
        v = self:stock_value(id, code)
        if v ~= nil then origin = "stock" end
    end
    self.cache[key] = { v, origin }
    return v, origin
end
-- }}}

return unit_stock
