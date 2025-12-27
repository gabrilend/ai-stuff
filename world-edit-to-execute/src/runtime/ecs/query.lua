--[[
Component Query System for ECS

Provides efficient iteration over entities by component type:
- Single and multi-component queries
- Value and predicate filtering
- Exclusion queries (entities without certain components)

Queries return iterators for memory efficiency on hot paths.
]]

local query = {}

local component = require("runtime.ecs.component")

-- {{{ query.single
-- Query entities with a single component.
-- Returns iterator: entity_id, component_instance
--
-- Usage: for entity, comp in query.single("position") do ... end
function query.single(component_name)
    local storage = component.get_storage(component_name)
    if not storage then
        -- Return empty iterator for unregistered components
        return function() return nil end
    end

    -- Return iterator over storage
    local entity_id = nil
    return function()
        local comp_instance
        entity_id, comp_instance = next(storage, entity_id)
        if entity_id then
            return entity_id, comp_instance
        end
        return nil
    end
end
-- }}}

-- {{{ query.multi
-- Query entities with ALL specified components.
-- Returns iterator: entity_id, comp1, comp2, ...
--
-- Usage: for e, pos, mov in query.multi({"position", "movement"}) do ... end
function query.multi(component_names)
    if #component_names == 0 then
        return function() return nil end
    end

    if #component_names == 1 then
        return query.single(component_names[1])
    end

    -- Get storage tables for all components
    local storages = {}
    for i, name in ipairs(component_names) do
        local storage = component.get_storage(name)
        if not storage then
            -- If any component not registered, no results
            return function() return nil end
        end
        storages[i] = storage
    end

    -- Iterate over smallest storage for efficiency
    -- Find storage with fewest entries
    local smallest_idx = 1
    local smallest_count = math.huge
    for i, storage in ipairs(storages) do
        local count = 0
        for _ in pairs(storage) do count = count + 1 end
        if count < smallest_count then
            smallest_count = count
            smallest_idx = i
        end
    end

    local base_storage = storages[smallest_idx]
    local entity_id = nil

    return function()
        while true do
            entity_id = next(base_storage, entity_id)
            if not entity_id then
                return nil
            end

            -- Check if entity has ALL other components
            local has_all = true
            local components = {}

            for i, storage in ipairs(storages) do
                local comp = storage[entity_id]
                if not comp then
                    has_all = false
                    break
                end
                components[i] = comp
            end

            if has_all then
                -- Return entity_id followed by all components
                return entity_id, unpack(components)
            end
        end
    end
end
-- }}}

-- {{{ query.query
-- Unified query interface.
-- Accepts variadic component names.
-- Returns iterator: entity_id, comp1, comp2, ...
--
-- Usage: for e, pos in query.query("position") do ... end
-- Usage: for e, pos, mov in query.query("position", "movement") do ... end
function query.query(...)
    local names = {...}

    if #names == 0 then
        return function() return nil end
    end

    if #names == 1 then
        return query.single(names[1])
    end

    return query.multi(names)
end
-- }}}

-- {{{ query.count
-- Count entities matching the query.
-- More efficient than iterating when you just need the count.
function query.count(...)
    local names = {...}

    if #names == 0 then
        return 0
    end

    if #names == 1 then
        local storage = component.get_storage(names[1])
        if not storage then return 0 end

        local count = 0
        for _ in pairs(storage) do
            count = count + 1
        end
        return count
    end

    -- Multi-component: must iterate and check
    local count = 0
    for _ in query.multi(names) do
        count = count + 1
    end
    return count
end
-- }}}

-- {{{ query.all
-- Get all matching entities as an array.
-- Returns array of entity IDs.
-- Use when you need to modify entities during iteration.
function query.all(...)
    local results = {}
    for entity_id in query.query(...) do
        results[#results + 1] = entity_id
    end
    return results
end
-- }}}

-- {{{ query.first
-- Get first matching entity.
-- Returns entity_id, comp1, comp2, ... or nil
function query.first(...)
    local iter = query.query(...)
    return iter()
end
-- }}}

-- {{{ query.with_value
-- Query entities where component.field == value.
-- Returns iterator: entity_id, component
--
-- Usage: for e, owner in query.with_value("owner", "player_id", 0) do ... end
function query.with_value(component_name, field, value)
    local storage = component.get_storage(component_name)
    if not storage then
        return function() return nil end
    end

    local entity_id = nil

    return function()
        while true do
            entity_id = next(storage, entity_id)
            if not entity_id then
                return nil
            end

            local comp = storage[entity_id]
            if comp[field] == value then
                return entity_id, comp
            end
        end
    end
end
-- }}}

-- {{{ query.with_predicate
-- Query entities where predicate(component) returns true.
-- Returns iterator: entity_id, component
--
-- Usage: for e, stats in query.with_predicate("stats",
--                          function(s) return s.hp < s.hp_max end) do ... end
function query.with_predicate(component_name, predicate)
    local storage = component.get_storage(component_name)
    if not storage then
        return function() return nil end
    end

    local entity_id = nil

    return function()
        while true do
            entity_id = next(storage, entity_id)
            if not entity_id then
                return nil
            end

            local comp = storage[entity_id]
            if predicate(comp) then
                return entity_id, comp
            end
        end
    end
end
-- }}}

-- {{{ query.without
-- Query entities with required components but WITHOUT excluded ones.
-- Returns iterator: entity_id, required_comp1, required_comp2, ...
--
-- Usage: for e, pos in query.without({"position"}, {"frozen"}) do ... end
function query.without(required_components, excluded_components)
    if #required_components == 0 then
        return function() return nil end
    end

    -- Get required storages
    local req_storages = {}
    for i, name in ipairs(required_components) do
        local storage = component.get_storage(name)
        if not storage then
            return function() return nil end
        end
        req_storages[i] = storage
    end

    -- Get excluded storages
    local excl_storages = {}
    for _, name in ipairs(excluded_components) do
        local storage = component.get_storage(name)
        -- Nil storage means component doesn't exist, so no exclusions needed
        if storage then
            excl_storages[#excl_storages + 1] = storage
        end
    end

    local entity_id = nil
    local base_storage = req_storages[1]

    return function()
        while true do
            entity_id = next(base_storage, entity_id)
            if not entity_id then
                return nil
            end

            -- Check exclusions first (usually faster)
            local excluded = false
            for _, storage in ipairs(excl_storages) do
                if storage[entity_id] then
                    excluded = true
                    break
                end
            end

            if not excluded then
                -- Check all required components
                local has_all = true
                local components = {}

                for i, storage in ipairs(req_storages) do
                    local comp = storage[entity_id]
                    if not comp then
                        has_all = false
                        break
                    end
                    components[i] = comp
                end

                if has_all then
                    return entity_id, unpack(components)
                end
            end
        end
    end
end
-- }}}

return query
