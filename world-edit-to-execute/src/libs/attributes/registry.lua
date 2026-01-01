-- Attribute Registry Module
-- Centralized storage and lookup for attribute schemas.
--
-- The registry provides:
-- - Dual lookup by string ID and numeric index (O(1) both ways)
-- - Automatic index assignment for array-based storage
-- - Dependency graph tracking for derived attributes
-- - Bulk registration from config blocks
-- - Container creation with default values
--
-- Usage:
--   local registry = require("libs.attributes.registry")
--   registry.register({ id = "strength", type = "integer", min = 0, max = 999 })
--   local schema = registry.get("strength")
--   local container = registry.create_container()

local schema_module = require("libs.attributes.schema")
local AttributeSchema = schema_module.AttributeSchema
local ATTR_TYPE = schema_module.ATTR_TYPE
local ATTR_FLAGS = schema_module.ATTR_FLAGS

-- {{{ Registry state
local registry = {
    -- Primary storage: id -> AttributeSchema
    schemas = {},

    -- Secondary index: numeric index -> AttributeSchema
    by_index = {},

    -- Next auto-assigned index
    next_index = 1,

    -- Dependency graph: id -> { dependent_ids }
    -- Maps each attribute to the list of derived attributes that depend on it
    dependency_graph = {},

    -- Reverse dependency graph: id -> { source_ids }
    -- Maps each derived attribute to its dependencies
    reverse_deps = {},
}
-- }}}

-- {{{ registry.register
-- Register a new attribute schema.
-- @param spec Attribute specification table (see AttributeSchema.new)
-- @return The created AttributeSchema
function registry.register(spec)
    -- Validate required fields
    if not spec.id then
        error("Attribute registration requires 'id' field")
    end

    -- Check for duplicate registration
    if registry.schemas[spec.id] then
        error("Attribute '" .. spec.id .. "' is already registered")
    end

    -- Auto-assign index if not provided
    if not spec.index then
        spec.index = registry.next_index
        registry.next_index = registry.next_index + 1
    else
        -- Update next_index to avoid collisions
        if spec.index >= registry.next_index then
            registry.next_index = spec.index + 1
        end
        -- Check for index collision
        if registry.by_index[spec.index] then
            error("Index " .. spec.index .. " is already used by '" ..
                  registry.by_index[spec.index].id .. "'")
        end
    end

    -- Create schema
    local attr_schema = AttributeSchema.new(spec)

    -- Store in both lookups
    registry.schemas[attr_schema.id] = attr_schema
    registry.by_index[attr_schema.index] = attr_schema

    -- Build dependency graph for derived attributes
    if attr_schema.derived_from and #attr_schema.derived_from > 0 then
        -- Store reverse dependencies (for the derived attribute)
        registry.reverse_deps[attr_schema.id] = {}

        for i = 1, #attr_schema.derived_from do
            local dep_id = attr_schema.derived_from[i]

            -- Forward graph: dep_id -> dependents
            if not registry.dependency_graph[dep_id] then
                registry.dependency_graph[dep_id] = {}
            end
            table.insert(registry.dependency_graph[dep_id], attr_schema.id)

            -- Reverse graph: attr_schema.id -> dependencies
            table.insert(registry.reverse_deps[attr_schema.id], dep_id)
        end
    end

    return attr_schema
end
-- }}}

-- {{{ registry.register_bulk
-- Register multiple attributes from a definition table.
-- Keys become attribute IDs.
-- @param definitions Table of id -> spec mappings
-- @return Number of attributes registered
function registry.register_bulk(definitions)
    local count = 0
    for id, spec in pairs(definitions) do
        spec.id = id
        registry.register(spec)
        count = count + 1
    end
    return count
end
-- }}}

-- {{{ registry.get
-- Get an attribute schema by ID or index.
-- @param id_or_index String ID or numeric index
-- @return AttributeSchema or nil if not found
function registry.get(id_or_index)
    if type(id_or_index) == "number" then
        return registry.by_index[id_or_index]
    else
        return registry.schemas[id_or_index]
    end
end
-- }}}

-- {{{ registry.has
-- Check if an attribute is registered.
-- @param id_or_index String ID or numeric index
-- @return boolean
function registry.has(id_or_index)
    return registry.get(id_or_index) ~= nil
end
-- }}}

-- {{{ registry.get_index
-- Get the numeric index for an attribute ID.
-- @param id Attribute ID
-- @return Index or nil if not found
function registry.get_index(id)
    local schema = registry.schemas[id]
    return schema and schema.index or nil
end
-- }}}

-- {{{ registry.get_id
-- Get the string ID for an attribute index.
-- @param index Attribute index
-- @return ID or nil if not found
function registry.get_id(index)
    local schema = registry.by_index[index]
    return schema and schema.id or nil
end
-- }}}

-- {{{ registry.get_dependents
-- Get the list of attribute IDs that depend on this attribute.
-- Used to know what derived attributes need recalculation when this changes.
-- @param id Attribute ID
-- @return Array of dependent attribute IDs (may be empty)
function registry.get_dependents(id)
    return registry.dependency_graph[id] or {}
end
-- }}}

-- {{{ registry.get_dependencies
-- Get the list of attribute IDs that this attribute depends on.
-- @param id Attribute ID
-- @return Array of dependency attribute IDs (may be empty)
function registry.get_dependencies(id)
    return registry.reverse_deps[id] or {}
end
-- }}}

-- {{{ registry.list
-- List all registered attributes, optionally filtered.
-- @param filter Optional table with filter criteria:
--   - type: Only return attributes of this type
--   - derived: true = only derived, false = only non-derived
--   - modifiable: true = only modifiable, false = only non-modifiable
--   - persisted: true = only persisted, false = only non-persisted
-- @return Array of AttributeSchema objects
function registry.list(filter)
    local results = {}

    for _, schema in pairs(registry.schemas) do
        local include = true

        if filter then
            if filter.type and schema.type ~= filter.type then
                include = false
            end
            if filter.derived ~= nil then
                if filter.derived ~= schema:is_derived() then
                    include = false
                end
            end
            if filter.modifiable ~= nil then
                if filter.modifiable ~= schema:is_modifiable() then
                    include = false
                end
            end
            if filter.persisted ~= nil then
                if filter.persisted ~= schema:is_persisted() then
                    include = false
                end
            end
        end

        if include then
            results[#results + 1] = schema
        end
    end

    return results
end
-- }}}

-- {{{ registry.count
-- Get the number of registered attributes.
-- @return Count
function registry.count()
    local count = 0
    for _ in pairs(registry.schemas) do
        count = count + 1
    end
    return count
end
-- }}}

-- {{{ registry.create_container
-- Create a new attribute container with default values.
-- The container is an array indexed by attribute index for O(1) access.
-- @return Container table with values, modifiers, and dirty tracking
function registry.create_container()
    local container = {
        -- Base values indexed by attribute index
        values = {},

        -- Modifier stacks (populated by modifier system, not this module)
        -- modifiers[index] = { modifier1, modifier2, ... }
        modifiers = {},

        -- Dirty flags for derived attributes needing recalculation
        -- dirty[index] = true means needs recalc
        dirty = {},

        -- Cached computed values for derived attributes
        -- cached[index] = last computed value
        cached = {},
    }

    -- Initialize with defaults
    for _, schema in pairs(registry.schemas) do
        container.values[schema.index] = schema.default

        -- Mark derived attributes as dirty initially
        if schema:is_derived() then
            container.dirty[schema.index] = true
        end
    end

    return container
end
-- }}}

-- {{{ registry.reset
-- Clear all registered attributes. Useful for testing.
function registry.reset()
    registry.schemas = {}
    registry.by_index = {}
    registry.next_index = 1
    registry.dependency_graph = {}
    registry.reverse_deps = {}
end
-- }}}

-- {{{ registry.validate_all_dependencies
-- Validate that all derived attributes reference registered attributes.
-- Call after bulk registration to catch missing dependencies.
-- @return true if valid, or false and error message
function registry.validate_all_dependencies()
    for id, schema in pairs(registry.schemas) do
        if schema.derived_from then
            for i = 1, #schema.derived_from do
                local dep_id = schema.derived_from[i]
                if not registry.schemas[dep_id] then
                    return false, "Attribute '" .. id ..
                        "' depends on unregistered attribute '" .. dep_id .. "'"
                end
            end
        end
    end
    return true
end
-- }}}

-- {{{ registry.get_topological_order
-- Get attributes in topological order (dependencies before dependents).
-- Useful for initialization and derived attribute calculation.
-- @return Array of attribute IDs in dependency order
function registry.get_topological_order()
    local visited = {}
    local result = {}

    -- Depth-first post-order traversal
    local function visit(id)
        if visited[id] then return end
        visited[id] = true

        -- Visit dependencies first
        local deps = registry.reverse_deps[id] or {}
        for i = 1, #deps do
            visit(deps[i])
        end

        result[#result + 1] = id
    end

    -- Visit all attributes
    for id in pairs(registry.schemas) do
        visit(id)
    end

    return result
end
-- }}}

-- {{{ Module exports
-- Re-export types for convenience
registry.ATTR_TYPE = ATTR_TYPE
registry.ATTR_FLAGS = ATTR_FLAGS
registry.AttributeSchema = AttributeSchema

return registry
-- }}}
