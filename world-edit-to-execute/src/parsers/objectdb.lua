--[[
ObjectDatabase - Unified Object Definition Lookup

Aggregates all object data parsers (w3u, w3a, w3t, w3b, w3d, w3h, w3q)
into a single database for O(1) lookup by object ID.

This module handles object DEFINITIONS (stats, abilities, costs),
while the ObjectRegistry handles object INSTANCES (placements, positions).

Usage:
  local objectdb = require("parsers.objectdb")

  -- Load from MPQ archive
  local db = objectdb.load_from_archive(archive)

  -- Or load from raw binary data
  local db = objectdb.new()
  db:load_units(w3u_data)
  db:load_abilities(w3a_data)

  -- Lookup by ID
  local unit = db:get("hfoo")           -- Returns unit definition
  local ability = db:get("AHhb")        -- Returns ability definition
  local item = db:get("phea")           -- Returns item definition

  -- Get stat with type-specific helper
  local hp = db:get_stat("hfoo", "hp")
  local dmg = db:get_stat("AHhb", "damage", 2)  -- Level 2

  -- Get object type
  local obj_type = db:get_type("hfoo")  -- Returns "unit"
]]

local w3u = require("parsers.w3u")
local w3a = require("parsers.w3a")
local w3t = require("parsers.w3t")
local w3b = require("parsers.w3b")
local w3d = require("parsers.w3d")
local w3h = require("parsers.w3h")
local w3q = require("parsers.w3q")

local objectdb = {}

-- {{{ Object type constants
objectdb.TYPE = {
    UNIT = "unit",
    ABILITY = "ability",
    ITEM = "item",
    DESTRUCTIBLE = "destructible",
    DOODAD = "doodad",
    BUFF = "buff",
    UPGRADE = "upgrade",
}

-- Map file names to types
objectdb.FILE_TO_TYPE = {
    ["war3map.w3u"] = objectdb.TYPE.UNIT,
    ["war3map.w3a"] = objectdb.TYPE.ABILITY,
    ["war3map.w3t"] = objectdb.TYPE.ITEM,
    ["war3map.w3b"] = objectdb.TYPE.DESTRUCTIBLE,
    ["war3map.w3d"] = objectdb.TYPE.DOODAD,
    ["war3map.w3h"] = objectdb.TYPE.BUFF,
    ["war3map.w3q"] = objectdb.TYPE.UPGRADE,
}
-- }}}

-- {{{ ObjectDatabase class
local ObjectDatabase = {}
ObjectDatabase.__index = ObjectDatabase

-- {{{ new
-- Create an empty ObjectDatabase.
function objectdb.new()
    local self = setmetatable({}, ObjectDatabase)

    -- Parsed data tables (one per type)
    self.units = nil
    self.abilities = nil
    self.items = nil
    self.destructibles = nil
    self.doodads = nil
    self.buffs = nil
    self.upgrades = nil

    -- Unified index: id -> { type, table_ref }
    self._index = {}

    -- Counts
    self.counts = {
        units = 0,
        abilities = 0,
        items = 0,
        destructibles = 0,
        doodads = 0,
        buffs = 0,
        upgrades = 0,
    }

    return self
end
-- }}}

-- {{{ _index_table
-- Add all IDs from a parsed table to the unified index.
local function _index_table(self, table_data, obj_type)
    if not table_data then return 0 end

    local count = 0
    for _, id in ipairs(table_data:all_ids()) do
        self._index[id] = {
            type = obj_type,
            table = table_data,
        }
        count = count + 1
    end
    return count
end
-- }}}

-- {{{ load_units
-- Load unit definitions from w3u binary data.
-- @param data Binary string
-- @return true on success, nil and error on failure
function ObjectDatabase:load_units(data)
    local result, err = w3u.parse(data)
    if not result then
        return nil, "Failed to parse w3u: " .. tostring(err)
    end

    self.units = result
    self.counts.units = _index_table(self, result, objectdb.TYPE.UNIT)
    return true
end
-- }}}

-- {{{ load_abilities
-- Load ability definitions from w3a binary data.
function ObjectDatabase:load_abilities(data)
    local result, err = w3a.parse(data)
    if not result then
        return nil, "Failed to parse w3a: " .. tostring(err)
    end

    self.abilities = result
    self.counts.abilities = _index_table(self, result, objectdb.TYPE.ABILITY)
    return true
end
-- }}}

-- {{{ load_items
-- Load item definitions from w3t binary data.
function ObjectDatabase:load_items(data)
    local result, err = w3t.parse(data)
    if not result then
        return nil, "Failed to parse w3t: " .. tostring(err)
    end

    self.items = result
    self.counts.items = _index_table(self, result, objectdb.TYPE.ITEM)
    return true
end
-- }}}

-- {{{ load_destructibles
-- Load destructible definitions from w3b binary data.
function ObjectDatabase:load_destructibles(data)
    local result, err = w3b.parse(data)
    if not result then
        return nil, "Failed to parse w3b: " .. tostring(err)
    end

    self.destructibles = result
    self.counts.destructibles = _index_table(self, result, objectdb.TYPE.DESTRUCTIBLE)
    return true
end
-- }}}

-- {{{ load_doodads
-- Load doodad definitions from w3d binary data.
function ObjectDatabase:load_doodads(data)
    local result, err = w3d.parse(data)
    if not result then
        return nil, "Failed to parse w3d: " .. tostring(err)
    end

    self.doodads = result
    self.counts.doodads = _index_table(self, result, objectdb.TYPE.DOODAD)
    return true
end
-- }}}

-- {{{ load_buffs
-- Load buff definitions from w3h binary data.
function ObjectDatabase:load_buffs(data)
    local result, err = w3h.parse(data)
    if not result then
        return nil, "Failed to parse w3h: " .. tostring(err)
    end

    self.buffs = result
    self.counts.buffs = _index_table(self, result, objectdb.TYPE.BUFF)
    return true
end
-- }}}

-- {{{ load_upgrades
-- Load upgrade definitions from w3q binary data.
function ObjectDatabase:load_upgrades(data)
    local result, err = w3q.parse(data)
    if not result then
        return nil, "Failed to parse w3q: " .. tostring(err)
    end

    self.upgrades = result
    self.counts.upgrades = _index_table(self, result, objectdb.TYPE.UPGRADE)
    return true
end
-- }}}

-- {{{ get
-- Get object definition by ID.
-- Returns the raw object data or nil if not found.
-- @param id Object ID (e.g., "hfoo", "AHhb", "phea")
-- @return Object data table or nil
function ObjectDatabase:get(id)
    local entry = self._index[id]
    if not entry then
        return nil
    end
    return entry.table:get(id)
end
-- }}}

-- {{{ has
-- Check if object exists in database.
-- @param id Object ID
-- @return boolean
function ObjectDatabase:has(id)
    return self._index[id] ~= nil
end
-- }}}

-- {{{ get_type
-- Get the type of an object.
-- @param id Object ID
-- @return Type string or nil
function ObjectDatabase:get_type(id)
    local entry = self._index[id]
    if not entry then
        return nil
    end
    return entry.type
end
-- }}}

-- {{{ get_table
-- Get the type-specific data table for an object.
-- @param id Object ID
-- @return Data table (UnitDataTable, AbilityDataTable, etc.) or nil
function ObjectDatabase:get_table(id)
    local entry = self._index[id]
    if not entry then
        return nil
    end
    return entry.table
end
-- }}}

-- {{{ get_stat
-- Get a stat for an object, using the appropriate type-specific method.
-- @param id Object ID
-- @param stat_name Stat name (friendly or raw)
-- @param level Optional level (for abilities/upgrades)
-- @return Stat value or nil
function ObjectDatabase:get_stat(id, stat_name, level)
    local entry = self._index[id]
    if not entry then
        return nil
    end
    return entry.table:get_stat(id, stat_name, level)
end
-- }}}

-- {{{ get_all_stats
-- Get all stats for an object.
-- @param id Object ID
-- @return Table of stats or empty table
function ObjectDatabase:get_all_stats(id)
    local entry = self._index[id]
    if not entry then
        return {}
    end
    return entry.table:get_all_stats(id)
end
-- }}}

-- {{{ is_custom
-- Check if object is custom (map-created) vs original (Blizzard).
-- @param id Object ID
-- @return boolean
function ObjectDatabase:is_custom(id)
    local entry = self._index[id]
    if not entry then
        return false
    end
    return entry.table:is_custom(id)
end
-- }}}

-- {{{ get_parent_id
-- Get the parent ID for a custom object.
-- @param id Object ID
-- @return Parent ID or nil
function ObjectDatabase:get_parent_id(id)
    local obj = self:get(id)
    if obj and obj.parent_id then
        return obj.parent_id
    end
    return nil
end
-- }}}

-- {{{ count
-- Get total object count or count by type.
-- @param obj_type Optional type filter
-- @return Count
function ObjectDatabase:count(obj_type)
    if obj_type then
        local key = obj_type .. "s"  -- unit -> units
        return self.counts[key] or 0
    end

    local total = 0
    for _, c in pairs(self.counts) do
        total = total + c
    end
    return total
end
-- }}}

-- {{{ all_ids
-- Get all object IDs in the database.
-- @param obj_type Optional type filter
-- @return Array of IDs
function ObjectDatabase:all_ids(obj_type)
    local ids = {}
    for id, entry in pairs(self._index) do
        if not obj_type or entry.type == obj_type then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    return ids
end
-- }}}

-- {{{ format
-- Format database info as readable string.
function ObjectDatabase:format()
    local lines = {}

    lines[#lines + 1] = "ObjectDatabase"
    lines[#lines + 1] = string.format("  Total objects: %d", self:count())
    lines[#lines + 1] = ""

    for _, type_name in ipairs({"unit", "ability", "item", "destructible", "doodad", "buff", "upgrade"}) do
        local key = type_name .. "s"
        local count = self.counts[key] or 0
        if count > 0 then
            lines[#lines + 1] = string.format("  %s: %d", type_name:sub(1,1):upper() .. type_name:sub(2) .. "s", count)

            -- Show first few IDs
            local ids = self:all_ids(type_name)
            local show_count = math.min(5, #ids)
            if show_count > 0 then
                local samples = {}
                for i = 1, show_count do
                    samples[#samples + 1] = ids[i]
                end
                if #ids > show_count then
                    samples[#samples + 1] = "..."
                end
                lines[#lines + 1] = string.format("    IDs: %s", table.concat(samples, ", "))
            end
        end
    end

    return table.concat(lines, "\n")
end
-- }}}

-- }}}

-- {{{ load_from_archive
-- Load all object data from an MPQ archive.
-- @param archive Opened MPQ archive (from mpq.open)
-- @return ObjectDatabase with all available data loaded
function objectdb.load_from_archive(archive)
    local db = objectdb.new()

    -- Load each file type if present
    local loaders = {
        { file = "war3map.w3u", loader = "load_units" },
        { file = "war3map.w3a", loader = "load_abilities" },
        { file = "war3map.w3t", loader = "load_items" },
        { file = "war3map.w3b", loader = "load_destructibles" },
        { file = "war3map.w3d", loader = "load_doodads" },
        { file = "war3map.w3h", loader = "load_buffs" },
        { file = "war3map.w3q", loader = "load_upgrades" },
    }

    for _, entry in ipairs(loaders) do
        if archive:has(entry.file) then
            local ok, data = pcall(archive.extract, archive, entry.file)
            if ok and data then
                -- Ignore parse errors - map may not have modifications
                pcall(db[entry.loader], db, data)
            end
        end
    end

    return db
end
-- }}}

-- {{{ Module exports
objectdb.ObjectDatabase = ObjectDatabase
-- }}}

return objectdb
