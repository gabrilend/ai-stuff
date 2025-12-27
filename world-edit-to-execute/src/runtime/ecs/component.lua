--[[
Component Registry - ECS Component Attachment System

Provides component type registration and entity attachment:
- Register component types with default values
- Attach/detach components to entities
- Metatable inheritance for efficient defaults
- Automatic cleanup on entity destruction

Components are pure data containers with no methods.
All behavior lives in systems (402d).
]]

local component = {}

local entity_mod = require("runtime.ecs.entity")

-- {{{ State
-- Component type registry: name -> default values table
local component_types = {}

-- Component storage: component_name -> { entity_id -> component_data }
local component_storage = {}

-- Track all component names for an entity: entity_id -> { name -> true }
local entity_components = {}

-- Track if destroy hook is registered
local destroy_hook_registered = false
-- }}}

-- {{{ cleanup_entity_components
-- Internal function to clean up all components for a destroyed entity.
-- Called via entity.on_destroy hook.
local function cleanup_entity_components(entity_id)
    local tracked = entity_components[entity_id]

    if tracked then
        for name in pairs(tracked) do
            if component_storage[name] then
                component_storage[name][entity_id] = nil
            end
        end
    end

    entity_components[entity_id] = nil
end
-- }}}

-- {{{ component.init
-- Initialize the component system.
-- Registers the entity destroy hook for automatic cleanup.
-- Pass force=true to re-register even if already registered.
function component.init(force)
    if force or not destroy_hook_registered then
        entity_mod.on_destroy(cleanup_entity_components)
        destroy_hook_registered = true
    end
end
-- }}}

-- {{{ component.register
-- Register a component type with its default values.
-- Defaults are used via metatable inheritance.
--
-- @param name string identifier for the component type
-- @param defaults table of default field values
function component.register(name, defaults)
    if type(name) ~= "string" then
        error("register: component name must be a string")
    end

    if type(defaults) ~= "table" then
        error("register: defaults must be a table")
    end

    if component_types[name] then
        error("register: component '" .. name .. "' already registered")
    end

    -- Store defaults (frozen copy)
    component_types[name] = {}
    for k, v in pairs(defaults) do
        component_types[name][k] = v
    end

    -- Initialize storage for this component type
    component_storage[name] = {}
end
-- }}}

-- {{{ component.add
-- Add a component to an entity.
--
-- @param entity_id numeric entity ID from entity.create()
-- @param name registered component type name
-- @param data optional table of initial values (merged with defaults)
-- @return the component instance
function component.add(entity_id, name, data)
    if not entity_mod.exists(entity_id) then
        error("add: entity " .. tostring(entity_id) .. " does not exist")
    end

    local defaults = component_types[name]
    if not defaults then
        error("add: component type '" .. name .. "' not registered")
    end

    -- Check if entity already has this component
    if component_storage[name][entity_id] then
        error("add: entity " .. entity_id .. " already has component '" .. name .. "'")
    end

    -- Create component instance with metatable for defaults
    local instance = {}
    if data then
        for k, v in pairs(data) do
            instance[k] = v
        end
    end
    setmetatable(instance, {__index = defaults})

    -- Store the component
    component_storage[name][entity_id] = instance

    -- Track which components this entity has
    if not entity_components[entity_id] then
        entity_components[entity_id] = {}
    end
    entity_components[entity_id][name] = true

    return instance
end
-- }}}

-- {{{ component.get
-- Get a component from an entity.
-- Returns nil if entity doesn't have this component.
function component.get(entity_id, name)
    local storage = component_storage[name]
    if not storage then
        return nil
    end

    return storage[entity_id]
end
-- }}}

-- {{{ component.has
-- Check if entity has a specific component.
-- Returns true/false.
function component.has(entity_id, name)
    local storage = component_storage[name]
    return storage ~= nil and storage[entity_id] ~= nil
end
-- }}}

-- {{{ component.remove
-- Remove a component from an entity.
-- Returns true if component was removed, false if didn't exist.
function component.remove(entity_id, name)
    local storage = component_storage[name]
    if not storage or not storage[entity_id] then
        return false
    end

    -- Remove from storage
    storage[entity_id] = nil

    -- Update entity's component tracking
    if entity_components[entity_id] then
        entity_components[entity_id][name] = nil
    end

    return true
end
-- }}}

-- {{{ component.get_all_for_entity
-- Get all components attached to an entity.
-- Returns table: { component_name -> component_instance }
function component.get_all_for_entity(entity_id)
    local result = {}
    local tracked = entity_components[entity_id]

    if tracked then
        for name in pairs(tracked) do
            result[name] = component_storage[name][entity_id]
        end
    end

    return result
end
-- }}}

-- {{{ component.get_component_names
-- Get list of component names attached to an entity.
-- Returns array of strings.
function component.get_component_names(entity_id)
    local result = {}
    local tracked = entity_components[entity_id]

    if tracked then
        for name in pairs(tracked) do
            result[#result + 1] = name
        end
    end

    return result
end
-- }}}

-- {{{ component.reset
-- Reset all component storage (but keep type registrations).
-- Called when entity system resets.
function component.reset()
    for name in pairs(component_storage) do
        component_storage[name] = {}
    end

    entity_components = {}
end
-- }}}

-- {{{ component.clear_all
-- Clear everything including type registrations.
-- Used for testing to start completely fresh.
function component.clear_all()
    component_types = {}
    component_storage = {}
    entity_components = {}
    -- Note: destroy_hook_registered remains true since the hook
    -- is still registered with the entity module
end
-- }}}

-- {{{ component.get_registered_types
-- Get list of all registered component type names.
function component.get_registered_types()
    local result = {}
    for name in pairs(component_types) do
        result[#result + 1] = name
    end
    return result
end
-- }}}

-- {{{ component.get_defaults
-- Get the default values for a component type.
-- Returns nil if not registered.
function component.get_defaults(name)
    return component_types[name]
end
-- }}}

-- {{{ component.get_storage
-- Get direct access to component storage table.
-- For use by query system - returns entity_id -> component map.
-- Returns nil if component not registered.
function component.get_storage(name)
    return component_storage[name]
end
-- }}}

-- {{{ component.get_stats
-- Get debug statistics about component system.
function component.get_stats()
    local type_count = 0
    local instance_counts = {}

    for name, storage in pairs(component_storage) do
        type_count = type_count + 1
        local count = 0
        for _ in pairs(storage) do
            count = count + 1
        end
        instance_counts[name] = count
    end

    return {
        registered_types = type_count,
        instances_by_type = instance_counts,
    }
end
-- }}}

-- Initialize on module load
component.init()

return component
