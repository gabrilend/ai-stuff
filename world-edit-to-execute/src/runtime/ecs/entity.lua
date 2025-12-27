--[[
Entity Manager - ECS Entity ID Management

Provides entity lifecycle management:
- Creates entities as numeric IDs for fast lookup
- Destroys entities and recycles IDs
- Tracks entity existence for validation
- Lifecycle hooks for component integration

Entities are just numeric IDs. All data attachment
happens in the component system (402b).
]]

local entity = {}

-- {{{ State
-- Entity ID allocation
local next_id = 1           -- Next ID to assign if no recycled IDs
local entities = {}         -- id -> true (existence marker)
local entity_count = 0      -- Active entity count

-- ID recycling (LIFO stack for cache locality)
local free_ids = {}         -- Stack of recycled IDs
local free_count = 0        -- Count of free IDs

-- Lifecycle hooks for component system integration
local on_create_hooks = {}
local on_destroy_hooks = {}
-- }}}

-- {{{ entity.create
-- Create a new entity, returning its numeric ID.
-- Recycles IDs from destroyed entities when available.
function entity.create()
    local id

    -- Try to recycle an ID first (LIFO)
    if free_count > 0 then
        id = free_ids[free_count]
        free_ids[free_count] = nil
        free_count = free_count - 1
    else
        -- Allocate new ID
        id = next_id
        next_id = next_id + 1
    end

    -- Mark as existing
    entities[id] = true
    entity_count = entity_count + 1

    -- Call creation hooks
    for i = 1, #on_create_hooks do
        on_create_hooks[i](id)
    end

    return id
end
-- }}}

-- {{{ entity.destroy
-- Destroy an entity by ID.
-- The ID is recycled for future use.
-- Returns true if entity existed, false otherwise.
function entity.destroy(id)
    if not entities[id] then
        return false
    end

    -- Call destruction hooks BEFORE removal
    -- This allows components to be read during cleanup
    for i = 1, #on_destroy_hooks do
        on_destroy_hooks[i](id)
    end

    -- Mark as non-existing
    entities[id] = nil
    entity_count = entity_count - 1

    -- Recycle the ID (push to stack)
    free_count = free_count + 1
    free_ids[free_count] = id

    return true
end
-- }}}

-- {{{ entity.exists
-- Check if an entity ID is currently valid.
-- Returns true if entity exists, false otherwise.
function entity.exists(id)
    return entities[id] == true
end
-- }}}

-- {{{ entity.get_count
-- Return the number of active entities.
function entity.get_count()
    return entity_count
end
-- }}}

-- {{{ entity.iterate
-- Return iterator over all active entity IDs.
-- Usage: for id in entity.iterate() do ... end
function entity.iterate()
    local id = 0
    return function()
        repeat
            id = id + 1
            if id >= next_id then
                return nil
            end
        until entities[id]
        return id
    end
end
-- }}}

-- {{{ entity.on_create
-- Register a callback for entity creation.
-- Callback receives (entity_id).
-- Used by component system to initialize storage.
function entity.on_create(callback)
    if type(callback) ~= "function" then
        error("on_create: callback must be a function")
    end

    on_create_hooks[#on_create_hooks + 1] = callback
end
-- }}}

-- {{{ entity.on_destroy
-- Register a callback for entity destruction.
-- Callback receives (entity_id).
-- Called BEFORE entity is removed (components still accessible).
-- Used by component system to cleanup storage.
function entity.on_destroy(callback)
    if type(callback) ~= "function" then
        error("on_destroy: callback must be a function")
    end

    on_destroy_hooks[#on_destroy_hooks + 1] = callback
end
-- }}}

-- {{{ entity.reset
-- Reset entity manager to initial state.
-- Calls destroy hooks for all existing entities.
-- Used when loading a new map or restarting.
function entity.reset()
    -- Call destroy hooks for all existing entities
    for id = 1, next_id - 1 do
        if entities[id] then
            for i = 1, #on_destroy_hooks do
                on_destroy_hooks[i](id)
            end
        end
    end

    -- Reset state
    next_id = 1
    entities = {}
    entity_count = 0
    free_ids = {}
    free_count = 0

    -- Note: hooks are NOT cleared - they're module-level registrations
end
-- }}}

-- {{{ entity.clear_hooks
-- Clear all lifecycle hooks.
-- Used primarily for testing to prevent hook accumulation.
function entity.clear_hooks()
    on_create_hooks = {}
    on_destroy_hooks = {}
end
-- }}}

-- {{{ entity.get_stats
-- Return debug statistics about entity manager state.
function entity.get_stats()
    return {
        active_count = entity_count,
        next_id = next_id,
        free_pool_size = free_count,
        peak_id = next_id - 1,
    }
end
-- }}}

-- {{{ entity.get_all_ids
-- Return array of all active entity IDs.
-- Useful for debugging, not for hot paths.
function entity.get_all_ids()
    local ids = {}
    for id = 1, next_id - 1 do
        if entities[id] then
            ids[#ids + 1] = id
        end
    end
    return ids
end
-- }}}

return entity
