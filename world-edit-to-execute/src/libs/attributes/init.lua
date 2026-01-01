-- Attribute System Module
-- Centralized attribute definition, validation, and storage system.
--
-- This module provides a schema-driven approach to defining game attributes
-- (stats, properties) with type validation, range constraints, and support
-- for derived (computed) attributes.
--
-- Core concepts:
--   - AttributeSchema: Defines structure/constraints for one attribute
--   - Registry: Stores all schemas with dual lookup (ID and index)
--   - Container: Per-entity attribute storage with defaults
--
-- Usage:
--   local attributes = require("libs.attributes")
--
--   -- Register attributes
--   attributes.register_bulk({
--       strength = { type = "integer", min = 0, max = 999, default = 10 },
--       agility = { type = "integer", min = 0, max = 999, default = 10 },
--       attack_power = {
--           type = "integer",
--           flags = attributes.ATTR_FLAGS.DERIVED,
--           derived_from = { "strength", "agility" },
--           formula = function(get) return get("strength") * 2 + get("agility") end,
--       },
--   })
--
--   -- Create a container for an entity
--   local stats = attributes.create_container()
--
--   -- Access by index (O(1))
--   local str_index = attributes.get_index("strength")
--   stats.values[str_index] = 50
--
--   -- Validate values
--   local schema = attributes.get("strength")
--   local valid, err = schema:validate(50)

-- Load submodules
local schema_module = require("libs.attributes.schema")
local registry = require("libs.attributes.registry")

-- {{{ Module exports
local attributes = {
    -- Constants
    ATTR_TYPE = schema_module.ATTR_TYPE,
    ATTR_FLAGS = schema_module.ATTR_FLAGS,

    -- Classes
    AttributeSchema = schema_module.AttributeSchema,

    -- Registry functions
    register = registry.register,
    register_bulk = registry.register_bulk,
    get = registry.get,
    has = registry.has,
    get_index = registry.get_index,
    get_id = registry.get_id,
    get_dependents = registry.get_dependents,
    get_dependencies = registry.get_dependencies,
    list = registry.list,
    count = registry.count,
    create_container = registry.create_container,
    reset = registry.reset,
    validate_all_dependencies = registry.validate_all_dependencies,
    get_topological_order = registry.get_topological_order,
}
-- }}}

return attributes
