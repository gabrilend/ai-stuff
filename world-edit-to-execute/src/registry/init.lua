-- src/registry/init.lua
-- ObjectRegistry: Centralized storage and lookup for game objects
--
-- Provides unified storage for all game object types (doodads, units, regions,
-- cameras, sounds) with indexing by creation_id and name for fast lookup.
--
-- Usage:
--   local ObjectRegistry = require("registry")
--   local registry = ObjectRegistry.new()
--   registry:add_unit(unit)
--   local obj = registry:get_by_creation_id(1234)

local ObjectRegistry = {}
ObjectRegistry.__index = ObjectRegistry

-- {{{ ObjectRegistry.new
-- Create a new empty registry with storage tables and indexes.
local function ObjectRegistry_new()
    local self = setmetatable({}, ObjectRegistry)

    -- Type-specific storage arrays (ipairs-compatible)
    self.doodads = {}
    self.units = {}
    self.regions = {}
    self.cameras = {}
    self.sounds = {}

    -- Cross-type indexes
    -- Note: creation_id collisions between types are possible; later registration wins
    self.by_creation_id = {}
    self.by_name = {}

    -- Object counts by type
    self.counts = {
        doodads = 0,
        units = 0,
        regions = 0,
        cameras = 0,
        sounds = 0,
    }

    return self
end
ObjectRegistry.new = ObjectRegistry_new
-- }}}

-- {{{ add_object (internal helper)
-- Internal helper to add an object to a type-specific array and update indexes.
-- @param storage The array to store in (e.g., self.doodads)
-- @param count_key The key in self.counts to increment
-- @param obj The object to add
local function add_object(self, storage, count_key, obj)
    -- Add to type-specific array
    storage[#storage + 1] = obj

    -- Increment count
    self.counts[count_key] = self.counts[count_key] + 1

    -- Index by creation_id if present
    -- Objects may have creation_id or creation_number (parser output uses creation_number)
    local creation_id = obj.creation_id or obj.creation_number
    if creation_id then
        self.by_creation_id[creation_id] = obj
    end

    -- Index by name if present
    if obj.name and obj.name ~= "" then
        self.by_name[obj.name] = obj
    end
end
-- }}}

-- {{{ add_doodad
-- Register a doodad object in the registry.
-- @param doodad The doodad object to add
function ObjectRegistry:add_doodad(doodad)
    add_object(self, self.doodads, "doodads", doodad)
end
-- }}}

-- {{{ add_unit
-- Register a unit object in the registry.
-- @param unit The unit object to add
function ObjectRegistry:add_unit(unit)
    add_object(self, self.units, "units", unit)
end
-- }}}

-- {{{ add_region
-- Register a region object in the registry.
-- @param region The region object to add
function ObjectRegistry:add_region(region)
    add_object(self, self.regions, "regions", region)
end
-- }}}

-- {{{ add_camera
-- Register a camera object in the registry.
-- @param camera The camera object to add
function ObjectRegistry:add_camera(camera)
    add_object(self, self.cameras, "cameras", camera)
end
-- }}}

-- {{{ add_sound
-- Register a sound object in the registry.
-- @param sound The sound object to add
function ObjectRegistry:add_sound(sound)
    add_object(self, self.sounds, "sounds", sound)
end
-- }}}

-- {{{ get_by_creation_id
-- Look up an object by its creation ID (cross-type lookup).
-- @param id The creation ID to search for
-- @return The object with that creation ID, or nil if not found
function ObjectRegistry:get_by_creation_id(id)
    return self.by_creation_id[id]
end
-- }}}

-- {{{ get_by_name
-- Look up an object by its name (for named objects like cameras, regions, sounds).
-- @param name The name to search for
-- @return The object with that name, or nil if not found
function ObjectRegistry:get_by_name(name)
    return self.by_name[name]
end
-- }}}

-- {{{ get_total_count
-- Get the total number of objects across all types.
-- @return Total object count
function ObjectRegistry:get_total_count()
    return self.counts.doodads
         + self.counts.units
         + self.counts.regions
         + self.counts.cameras
         + self.counts.sounds
end
-- }}}

-- {{{ __tostring
-- String representation for debugging.
function ObjectRegistry:__tostring()
    return string.format(
        "ObjectRegistry<doodads=%d, units=%d, regions=%d, cameras=%d, sounds=%d>",
        self.counts.doodads,
        self.counts.units,
        self.counts.regions,
        self.counts.cameras,
        self.counts.sounds
    )
end
-- }}}

return ObjectRegistry
