--[[
System Registration and Execution for ECS

Systems process entities with specific components each tick:
- Register named systems with required components
- Execute systems in priority order (lower runs first)
- Track performance statistics
- Enable/disable individual or all systems

Systems are where game logic lives - movement, combat, AI, etc.
]]

local system = {}

local query = require("runtime.ecs.query")

-- {{{ State
-- Ordered list of systems (execution order by priority)
local systems = {}
local system_count = 0

-- System lookup by name
local systems_by_name = {}

-- Global enable/disable
local systems_enabled = true
-- }}}

-- {{{ system.register
-- Register a system to process entities.
--
-- @param name unique string identifier
-- @param required_components array of component names entities must have
-- @param update_fn function(query_iterator, dt) called each tick
-- @param options optional table with:
--   priority: number (lower = runs first, default 0)
--   enabled: boolean (default true)
--
-- Returns system handle for later modification
function system.register(name, required_components, update_fn, options)
    if type(name) ~= "string" then
        error("register: name must be a string")
    end

    if systems_by_name[name] then
        error("register: system '" .. name .. "' already registered")
    end

    if type(required_components) ~= "table" then
        error("register: required_components must be a table")
    end

    if type(update_fn) ~= "function" then
        error("register: update_fn must be a function")
    end

    options = options or {}

    local sys = {
        name = name,
        components = required_components,
        update = update_fn,
        priority = options.priority or 0,
        enabled = options.enabled ~= false,  -- default true
        stats = {
            update_count = 0,
            total_time = 0,
            last_entity_count = 0,
        },
    }

    system_count = system_count + 1
    systems[system_count] = sys
    systems_by_name[name] = sys

    -- Re-sort by priority (stable sort - maintain order for same priority)
    -- Lua's table.sort is not stable, so we use a key that includes position
    for i = 1, system_count do
        systems[i]._sort_order = i
    end

    table.sort(systems, function(a, b)
        if a.priority == b.priority then
            return a._sort_order < b._sort_order
        end
        return a.priority < b.priority
    end)

    return sys
end
-- }}}

-- {{{ system.update
-- Execute all enabled systems.
-- Called once per game tick.
--
-- @param dt delta time (usually TICK_DURATION from gameloop)
--
-- Returns number of systems that ran
function system.update(dt)
    if not systems_enabled then
        return 0
    end

    local ran_count = 0

    for i = 1, system_count do
        local sys = systems[i]

        if sys.enabled then
            -- Get query iterator for required components
            local iter
            if #sys.components == 0 then
                -- Empty components list - run once with no-op iterator
                iter = function() return nil end
            else
                iter = query.query(unpack(sys.components))
            end

            -- Track performance
            local start_time = os.clock()
            local entity_count = 0

            -- Wrap iterator to count entities
            local counting_iter = function()
                local results = {iter()}
                if results[1] then
                    entity_count = entity_count + 1
                    return unpack(results)
                end
                return nil
            end

            -- Call system update with iterator
            sys.update(counting_iter, dt)

            -- Update stats
            local elapsed = os.clock() - start_time
            sys.stats.update_count = sys.stats.update_count + 1
            sys.stats.total_time = sys.stats.total_time + elapsed
            sys.stats.last_entity_count = entity_count

            ran_count = ran_count + 1
        end
    end

    return ran_count
end
-- }}}

-- {{{ system.enable
-- Enable a system by name.
function system.enable(name)
    local sys = systems_by_name[name]
    if sys then
        sys.enabled = true
        return true
    end
    return false
end
-- }}}

-- {{{ system.disable
-- Disable a system by name.
function system.disable(name)
    local sys = systems_by_name[name]
    if sys then
        sys.enabled = false
        return true
    end
    return false
end
-- }}}

-- {{{ system.is_enabled
-- Check if a system is enabled.
function system.is_enabled(name)
    local sys = systems_by_name[name]
    return sys and sys.enabled
end
-- }}}

-- {{{ system.set_all_enabled
-- Enable or disable all systems globally.
function system.set_all_enabled(enabled)
    systems_enabled = enabled
end
-- }}}

-- {{{ system.get
-- Get a system by name.
function system.get(name)
    return systems_by_name[name]
end
-- }}}

-- {{{ system.get_all
-- Get all systems in execution order.
function system.get_all()
    local result = {}
    for i = 1, system_count do
        result[i] = systems[i]
    end
    return result
end
-- }}}

-- {{{ system.get_count
-- Get total number of registered systems.
function system.get_count()
    return system_count
end
-- }}}

-- {{{ system.unregister
-- Remove a system by name.
-- Returns true if removed, false if not found.
function system.unregister(name)
    local sys = systems_by_name[name]
    if not sys then
        return false
    end

    -- Find and remove from ordered list
    for i = 1, system_count do
        if systems[i] == sys then
            table.remove(systems, i)
            system_count = system_count - 1
            break
        end
    end

    systems_by_name[name] = nil
    return true
end
-- }}}

-- {{{ system.reset
-- Reset all systems (clear registrations).
-- Called when loading a new map.
function system.reset()
    systems = {}
    system_count = 0
    systems_by_name = {}
    systems_enabled = true
end
-- }}}

-- {{{ system.get_stats
-- Get performance statistics for all systems.
function system.get_stats()
    local result = {
        total_systems = system_count,
        enabled_count = 0,
        systems = {},
    }

    for i = 1, system_count do
        local sys = systems[i]
        if sys.enabled then
            result.enabled_count = result.enabled_count + 1
        end

        result.systems[sys.name] = {
            priority = sys.priority,
            enabled = sys.enabled,
            components = sys.components,
            update_count = sys.stats.update_count,
            total_time = sys.stats.total_time,
            avg_time = sys.stats.update_count > 0
                and (sys.stats.total_time / sys.stats.update_count)
                or 0,
            last_entity_count = sys.stats.last_entity_count,
        }
    end

    return result
end
-- }}}

-- {{{ system.reset_stats
-- Reset performance statistics.
function system.reset_stats()
    for i = 1, system_count do
        local sys = systems[i]
        sys.stats.update_count = 0
        sys.stats.total_time = 0
        sys.stats.last_entity_count = 0
    end
end
-- }}}

return system
