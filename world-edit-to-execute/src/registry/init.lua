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

    -- Spatial index (optional, created by enable_spatial_index)
    self.spatial = nil

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
-- If spatial indexing is enabled, also inserts into spatial index.
-- @param doodad The doodad object to add
function ObjectRegistry:add_doodad(doodad)
    add_object(self, self.doodads, "doodads", doodad)
    if self.spatial and doodad.position then
        self.spatial:insert(doodad)
    end
end
-- }}}

-- {{{ add_unit
-- Register a unit object in the registry.
-- If spatial indexing is enabled, also inserts into spatial index.
-- @param unit The unit object to add
function ObjectRegistry:add_unit(unit)
    add_object(self, self.units, "units", unit)
    if self.spatial and unit.position then
        self.spatial:insert(unit)
    end
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

-- {{{ enable_spatial_index
-- Enable spatial indexing for proximity queries.
-- Creates a spatial index and populates it with existing doodads and units.
-- @param cell_size Grid cell size in game units (default 512)
function ObjectRegistry:enable_spatial_index(cell_size)
    local SpatialIndex = require("registry.spatial")
    self.spatial = SpatialIndex.new(cell_size or 512)

    -- Index existing positioned objects
    for _, doodad in ipairs(self.doodads) do
        if doodad.position then
            self.spatial:insert(doodad)
        end
    end
    for _, unit in ipairs(self.units) do
        if unit.position then
            self.spatial:insert(unit)
        end
    end
end
-- }}}

-- {{{ has_spatial_index
-- Check if spatial indexing is enabled.
-- @return true if spatial index is available
function ObjectRegistry:has_spatial_index()
    return self.spatial ~= nil
end
-- }}}

-- {{{ get_objects_in_radius
-- Find all doodads and units within a circular area.
-- Requires spatial indexing to be enabled.
-- @param x Center X coordinate
-- @param y Center Y coordinate
-- @param radius Search radius in game units
-- @return Array of objects (doodads and units) within the radius
function ObjectRegistry:get_objects_in_radius(x, y, radius)
    if not self.spatial then
        error("Spatial indexing not enabled. Call enable_spatial_index() first.")
    end
    return self.spatial:query_radius(x, y, radius)
end
-- }}}

-- {{{ get_objects_in_rect
-- Find all doodads and units within a rectangular area.
-- Requires spatial indexing to be enabled.
-- @param left Left bound (min X)
-- @param bottom Bottom bound (min Y)
-- @param right Right bound (max X)
-- @param top Top bound (max Y)
-- @return Array of objects (doodads and units) within the rectangle
function ObjectRegistry:get_objects_in_rect(left, bottom, right, top)
    if not self.spatial then
        error("Spatial indexing not enabled. Call enable_spatial_index() first.")
    end
    return self.spatial:query_rect(left, bottom, right, top)
end
-- }}}

-- {{{ get_objects_in_region
-- Find all doodads and units within a region's bounds.
-- Requires spatial indexing to be enabled.
-- @param region Region object with bounds (left, bottom, right, top)
-- @return Array of objects within the region
function ObjectRegistry:get_objects_in_region(region)
    if not self.spatial then
        error("Spatial indexing not enabled. Call enable_spatial_index() first.")
    end
    if not region.bounds then
        error("Region must have bounds field")
    end
    local b = region.bounds
    return self.spatial:query_rect(b.left, b.bottom, b.right, b.top)
end
-- }}}

-- {{{ get_units_in_radius
-- Find all units within a circular area.
-- Requires spatial indexing to be enabled.
-- @param x Center X coordinate
-- @param y Center Y coordinate
-- @param radius Search radius in game units
-- @return Array of units within the radius
function ObjectRegistry:get_units_in_radius(x, y, radius)
    local objects = self:get_objects_in_radius(x, y, radius)
    local units = {}
    for _, obj in ipairs(objects) do
        -- Check if it's a unit (units have player field, doodads don't)
        if obj.player ~= nil then
            units[#units + 1] = obj
        end
    end
    return units
end
-- }}}

-- {{{ get_doodads_in_radius
-- Find all doodads within a circular area.
-- Requires spatial indexing to be enabled.
-- @param x Center X coordinate
-- @param y Center Y coordinate
-- @param radius Search radius in game units
-- @return Array of doodads within the radius
function ObjectRegistry:get_doodads_in_radius(x, y, radius)
    local objects = self:get_objects_in_radius(x, y, radius)
    local doodads = {}
    for _, obj in ipairs(objects) do
        -- Doodads don't have player field
        if obj.player == nil then
            doodads[#doodads + 1] = obj
        end
    end
    return doodads
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

-- ============================================================================
-- Filtering and Iteration (207b)
-- ============================================================================

-- {{{ get_units_for_player
-- Get all units belonging to a specific player.
-- @param player_id The player number (0-based, matching WC3 player indices)
-- @return Array of units owned by that player
function ObjectRegistry:get_units_for_player(player_id)
    local result = {}
    for i = 1, #self.units do
        local unit = self.units[i]
        if unit.player == player_id then
            result[#result + 1] = unit
        end
    end
    return result
end
-- }}}

-- {{{ get_heroes
-- Get all hero units (units whose type ID starts with uppercase).
-- @return Array of hero units
function ObjectRegistry:get_heroes()
    local result = {}
    for i = 1, #self.units do
        local unit = self.units[i]
        -- Check if unit has is_hero method (gameobject) or use type ID heuristic
        if unit.is_hero and unit:is_hero() then
            result[#result + 1] = unit
        elseif unit.id then
            -- Fallback: capital first letter indicates hero
            local first = unit.id:byte(1)
            if first and first >= 65 and first <= 90 then
                result[#result + 1] = unit
            end
        end
    end
    return result
end
-- }}}

-- {{{ get_buildings
-- Get all building units.
-- Note: WC3 doesn't have a simple is_building flag. Detection relies on
-- unit having is_building() method returning true.
-- @return Array of building units
function ObjectRegistry:get_buildings()
    local result = {}
    for i = 1, #self.units do
        local unit = self.units[i]
        if unit.is_building and unit:is_building() then
            result[#result + 1] = unit
        end
    end
    return result
end
-- }}}

-- {{{ get_waygates
-- Get all units that have an active waygate destination.
-- Waygates teleport units to a region identified by creation_id.
-- @return Array of waygate units
function ObjectRegistry:get_waygates()
    local result = {}
    for i = 1, #self.units do
        local unit = self.units[i]
        -- Check for is_waygate method (gameobject) or direct waygate_dest field
        if unit.is_waygate and unit:is_waygate() then
            result[#result + 1] = unit
        elseif unit.waygate_dest and unit.waygate_dest >= 0 then
            result[#result + 1] = unit
        end
    end
    return result
end
-- }}}

-- {{{ each_doodad
-- Iterate over all doodads, calling callback for each.
-- @param callback Function to call with each doodad
function ObjectRegistry:each_doodad(callback)
    for i = 1, #self.doodads do
        callback(self.doodads[i])
    end
end
-- }}}

-- {{{ each_unit
-- Iterate over all units, calling callback for each.
-- @param callback Function to call with each unit
function ObjectRegistry:each_unit(callback)
    for i = 1, #self.units do
        callback(self.units[i])
    end
end
-- }}}

-- {{{ each_region
-- Iterate over all regions, calling callback for each.
-- @param callback Function to call with each region
function ObjectRegistry:each_region(callback)
    for i = 1, #self.regions do
        callback(self.regions[i])
    end
end
-- }}}

-- {{{ each_camera
-- Iterate over all cameras, calling callback for each.
-- @param callback Function to call with each camera
function ObjectRegistry:each_camera(callback)
    for i = 1, #self.cameras do
        callback(self.cameras[i])
    end
end
-- }}}

-- {{{ each_sound
-- Iterate over all sounds, calling callback for each.
-- @param callback Function to call with each sound
function ObjectRegistry:each_sound(callback)
    for i = 1, #self.sounds do
        callback(self.sounds[i])
    end
end
-- }}}

-- {{{ filter
-- Generic filter method to query subsets of objects matching a predicate.
-- @param object_type String: "doodad", "unit", "region", "camera", or "sound"
-- @param predicate Function that takes an object and returns true to include it
-- @return Array of objects matching the predicate
function ObjectRegistry:filter(object_type, predicate)
    -- Map singular type names to plural storage keys
    local collection = self[object_type .. "s"]
    if not collection then
        error("Unknown object type: " .. tostring(object_type))
    end

    local result = {}
    for i = 1, #collection do
        local obj = collection[i]
        if predicate(obj) then
            result[#result + 1] = obj
        end
    end
    return result
end
-- }}}

return ObjectRegistry
