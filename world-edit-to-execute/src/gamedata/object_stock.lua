--[[
object_stock.lua - any object's value by field code: the map's change, else the stock tables (Issues 525, 527)

WC3 keeps each kind of object's numbers in stock tables (units:
UnitBalance.slk, UnitWeapons.slk ...; abilities: AbilityData.slk; items:
ItemData.slk; upgrades: UpgradeData.slk) and text profiles (names,
hotkeys, button art, some numbers: Units\*Func.txt, *Strings.txt), one
row or section per stock object. A map's object files (war3map.w3u, .w3a,
.w3t, .w3q) hold only what the map changed, under four-character field
codes, and custom objects name the stock object they copy. The kind's
metadata table says where each code lives:

  slk      the table ("UnitBalance", "AbilityData", "Profile" for the
           text profiles)
  field    the column; with `repeat` > 0 the column is per level
           ("Cool" -> Cool1, Cool2 ...); with `data` 1-9 an ability's
           data field ("Data" + A-I + level: DataA1)
  index    >= 0: one entry of a comma list

So a value is found as the game finds it:

  1. the map's change to this object (at this level), if it made one;
  2. else the stock row of the object (or of the stock object a custom
     one copies), at the column its metadata row names.

Profile fields with levels keep every level in one comma list (Tip,
Hotkey...); the level's entry is given (the last when there are fewer).

    local object_stock = require("gamedata.object_stock")
    local S = object_stock.new(chain, map.object_data.abilities, "abilities")
    S:value("AHtb", "Hbz1", 2)       -- a value, and "map" or "stock"
    S:base("A00X")                   -- the stock object it copies
    S.available                      -- whether the stock tables were read

Without a chain only the map's changes are known.
]]

local slk = require("parsers.slk")
local profile = require("parsers.profile_txt")

local object_stock = {}

local LETTERS = "ABCDEFGHI"

-- Per kind: metadata table, stock tables, profile files
object_stock.KINDS = {}
do
    local rules = require("gamedata.field_rules").kinds
    for name, k in pairs(rules) do
        object_stock.KINDS[name] = { metadata = k.metadata, tables = k.tables, profiles = k.profiles }
    end
    -- buffs and effects (their art: Issue 530); their text lives in the
    -- abilities' profile files
    object_stock.KINDS.buffs = {
        metadata = "Units\\AbilityBuffMetaData.slk",
        tables = { AbilityBuffData = "Units\\AbilityBuffData.slk" },
        profiles = object_stock.KINDS.abilities and object_stock.KINDS.abilities.profiles or {},
    }
    object_stock.KINDS.upgrades = {
        metadata = "Units\\UpgradeMetaData.slk",
        tables = { UpgradeData = "Units\\UpgradeData.slk" },
        profiles = { "Units\\HumanUpgradeFunc.txt", "Units\\OrcUpgradeFunc.txt", "Units\\UndeadUpgradeFunc.txt",
                     "Units\\NightElfUpgradeFunc.txt", "Units\\NeutralUpgradeFunc.txt", "Units\\CampaignUpgradeFunc.txt",
                     "Units\\HumanUpgradeStrings.txt", "Units\\OrcUpgradeStrings.txt", "Units\\UndeadUpgradeStrings.txt",
                     "Units\\NightElfUpgradeStrings.txt", "Units\\NeutralUpgradeStrings.txt",
                     "Units\\CampaignUpgradeStrings.txt" },
    }
end

local S = {}
S.__index = S

-- {{{ object_stock.new
-- chain: gamedata/chain.lua (or anything with read(path)), may be nil;
-- objects: the map's object table of this kind (parsers/objectdata.lua), may be nil
function object_stock.new(chain, objects, kind)
    kind = kind or "units"
    local k = object_stock.KINDS[kind]
    if not k then error("unknown object kind " .. tostring(kind)) end
    local self = setmetatable({ chain = chain, objects = objects, kind = kind, spec = k, tables = {},
                                available = false, cache = {} }, S)
    if chain then
        local ok, bytes = pcall(chain.read, chain, k.metadata)
        if ok and bytes then
            self.meta = slk.parse(bytes)
            self.available = true
        else
            self.error = "no " .. k.metadata .. " (" .. tostring(bytes) .. ")"
        end
    end
    return self
end
-- }}}

-- {{{ Tables and profiles
function S:table(name)
    local t = self.tables[name]
    if t == nil then
        t = false
        local path = self.spec.tables[name]
        if path and self.chain then
            local ok, bytes = pcall(self.chain.read, self.chain, path)
            if ok and bytes then t = slk.parse(bytes) end
        end
        self.tables[name] = t
    end
    return t or nil
end

function S:profile()
    if self.profiles == nil then
        self.profiles = {}
        if self.chain then
            for _, path in ipairs(self.spec.profiles or {}) do
                local ok, bytes = pcall(self.chain.read, self.chain, path)
                if ok and bytes then profile.parse(bytes, self.profiles) end
            end
        end
    end
    return self.profiles
end
-- }}}

-- {{{ S:base
-- The stock object whose stock values an object has: its parent if the
-- map made it, else itself
function S:base(id)
    local o = self.objects
    if o and o.custom and o.custom[id] and o.custom[id].parent_id then return o.custom[id].parent_id end
    return id
end
-- }}}

-- {{{ S:stock_value
local function list_entry(v, index)
    local k = 0
    for part in (v .. ","):gmatch("([^,]*),") do
        if k == index then return part end
        k = k + 1
    end
    return nil
end

function S:stock_value(id, code, level)
    if not self.available then return nil end
    local meta = self.meta.rows[code]
    if not meta then return nil end
    local base = self:base(id)
    local table_name = tostring(meta.slk)
    local field = tostring(meta.field)
    local levels = tonumber(meta["repeat"]) or 0
    local data = tonumber(meta.data) or 0
    level = level or 1
    local v
    if table_name == "Profile" then
        local sec = self:profile()[base]
        v = sec and sec[field]
        -- per-level profile fields are one comma list
        if type(v) == "string" and levels > 0 and v:find(",") then
            local entry = list_entry(v, level - 1)
            if entry == nil then
                local last
                for part in v:gmatch("[^,]+") do last = part end
                entry = last
            end
            v = entry
        end
    else
        local t = self:table(table_name)
        local row = t and t.rows[base]
        if not row then return nil end
        local column = field
        if data > 0 then column = field .. LETTERS:sub(data, data) .. level
        elseif levels > 0 then column = field .. level end
        v = row[column]
    end
    local index = tonumber(meta.index)
    if index and index >= 0 and type(v) == "string" and v:find(",") then v = list_entry(v, index) end
    if v == nil or v == "-" or v == "_" or v == "" then return nil end
    if type(v) == "string" then
        v = v:gsub('^"(.*)"$', "%1")
        return tonumber(v) or v
    end
    return v
end
-- }}}

-- {{{ S:value
-- The value of code for object id (at level, for levelled fields), and
-- where it came from ("map" or "stock")
function S:value(id, code, level)
    local key = id .. code .. (level or "")
    local c = self.cache[key]
    if c then return c[1], c[2] end
    local v, origin
    local o = self.objects
    if o and o.has and o:has(id) then
        v = o:get_modification(id, code, level)
        if v == nil and level then
            -- a levelled change filed without a level (level 0 in some files)
            v = o:get_modification(id, code, 0)
        end
        if v ~= nil then origin = "map" end
    end
    if v == nil then
        v = self:stock_value(id, code, level)
        if v ~= nil then origin = "stock" end
    end
    self.cache[key] = { v, origin }
    return v, origin
end
-- }}}

-- {{{ S:profile_field
-- A text profile's field by its name ("CasterArt"), for the object (its
-- base's section): for when a field code isn't known
function S:profile_field(id, name)
    local sec = self:profile()[self:base(id)] or self:profile()[id]
    local v = sec and sec[name]
    if v == nil then
        -- profile keys aren't consistently capitalised
        local low = name:lower()
        for k, x in pairs(sec or {}) do if k:lower() == low then v = x break end end
    end
    if type(v) == "string" then v = v:gsub('^"(.*)"$', "%1") end
    return v
end
-- }}}

-- {{{ S:list
-- A comma-list value as a table of 4-character ids (ability lists ...)
function S:list(id, code, level)
    local v = self:value(id, code, level)
    local out = {}
    if type(v) ~= "string" then return out end
    for x in v:gmatch("[^,%s]+") do if #x == 4 then out[#out + 1] = x end end
    return out
end
-- }}}

return object_stock
