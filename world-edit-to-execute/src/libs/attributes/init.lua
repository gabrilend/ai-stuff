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
--   - Getters: Dispatch table getters with modifier application
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
--   -- Get computed value (with modifiers)
--   local value = attributes.get_value(stats, "strength")
--
--   -- Validate values
--   local schema = attributes.get("strength")
--   local valid, err = schema:validate(50)

-- Load submodules
local schema_module = require("libs.attributes.schema")
local registry = require("libs.attributes.registry")
local getters_module = require("libs.attributes.getters")

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

    -- Getter functions (016b)
    get_value = getters_module.get,
    get_raw = getters_module.get_raw,
    get_base = getters_module.get_base,
    get_many = getters_module.get_many,
    get_all_values = getters_module.get_all,
    get_all_raw = getters_module.get_all_raw,
    get_modifier_breakdown = getters_module.get_modifier_breakdown,
    get_getter = getters_module.get_getter,
    get_raw_getter = getters_module.get_raw_getter,
    has_getter = getters_module.has,
    rebuild_getters = getters_module.rebuild,
    mark_dirty = getters_module.mark_dirty,
    invalidate_all_derived = getters_module.invalidate_all_derived,
}
-- }}}

return attributes
