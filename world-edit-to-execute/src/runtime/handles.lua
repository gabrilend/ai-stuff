--[[
Handle Management System

Provides unique ID generation and lifecycle management for runtime objects.
All JASS handles (triggers, units, items, etc.) go through this system to:
- Get unique integer IDs (for JASS compatibility)
- Track validity (destroyed handles become invalid)
- Support object lookup by ID

This is the foundation for the WC3 handle system where everything
is referenced by integer handle IDs in JASS scripts.
]]

local handles = {}

-- {{{ State
-- Handle ID counter - starts at 1, increments for each new handle
-- JASS uses integers for handle IDs, starting from 0x100001 typically,
-- but we use simple incrementing integers for simplicity
local next_id = 1

-- Handle registry: id -> object
-- Allows looking up objects by their handle ID
local registry = {}

-- Object to handle ID mapping: object -> id
-- Uses weak keys so objects can be garbage collected when only
-- referenced here (after explicit destruction)
local object_ids = setmetatable({}, {__mode = "k"})
-- }}}

-- {{{ handles.register
-- Register an object with the handle system.
-- Assigns a unique ID and stores type information.
-- @param obj The object to register (table)
-- @param type_name Handle type name (e.g., "trigger", "unit")
-- @return The assigned handle ID
function handles.register(obj, type_name)
    local id = next_id
    next_id = next_id + 1

    -- Store in both directions
    registry[id] = obj
    object_ids[obj] = id

    -- Attach handle info to object
    obj._handle_id = id
    obj._handle_type = type_name

    return id
end
-- }}}

-- {{{ handles.destroy
-- Remove an object from the handle system.
-- After destruction, is_valid() returns false.
-- @param obj The object to destroy
function handles.destroy(obj)
    local id = object_ids[obj]
    if id then
        registry[id] = nil
        object_ids[obj] = nil
        obj._handle_id = nil
        -- Keep _handle_type for debugging destroyed handles
    end
end
-- }}}

-- {{{ handles.get_id
-- Get the handle ID for an object.
-- @param obj The object
-- @return Handle ID or nil if not registered
function handles.get_id(obj)
    return object_ids[obj]
end
-- }}}

-- {{{ handles.get_by_id
-- Look up an object by its handle ID.
-- @param id The handle ID
-- @return The object or nil if not found/destroyed
function handles.get_by_id(id)
    return registry[id]
end
-- }}}

-- {{{ handles.is_valid
-- Check if an object is still a valid handle.
-- Returns false for nil, destroyed, or unregistered objects.
-- @param obj The object to check
-- @return true if valid, false otherwise
function handles.is_valid(obj)
    if obj == nil then
        return false
    end
    return object_ids[obj] ~= nil
end
-- }}}

-- {{{ handles.get_type
-- Get the type name of a handle.
-- Works even on destroyed handles (for debugging).
-- @param obj The object
-- @return Type name string or nil
function handles.get_type(obj)
    if obj == nil then
        return nil
    end
    return obj._handle_type
end
-- }}}

-- {{{ handles.get_stats
-- Get statistics about the handle system.
-- Useful for debugging memory leaks.
-- @return Table with count, next_id fields
function handles.get_stats()
    local count = 0
    for _ in pairs(registry) do
        count = count + 1
    end
    return {
        count = count,
        next_id = next_id,
    }
end
-- }}}

-- {{{ handles.reset
-- Reset the handle system to initial state.
-- Used when loading a new map or restarting.
function handles.reset()
    next_id = 1
    registry = {}
    object_ids = setmetatable({}, {__mode = "k"})
end
-- }}}

return handles
