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
--   - Setters: Dispatch table setters with validation, events, and transactions
--   - Modifiers: Buff/equipment bonus management with stacking and expiry
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
local setters_module = require("libs.attributes.setters")
local modifiers_module = require("libs.attributes.modifiers")
local derived_module = require("libs.attributes.derived")

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

    -- Setter functions (016c)
    set_value = setters_module.set,
    set_raw = setters_module.set_raw,
    set_many = setters_module.set_many,
    adjust = setters_module.adjust,
    reset_value = setters_module.reset,
    reset_all = setters_module.reset_all,
    has_setter = setters_module.has,
    get_setter = setters_module.get_setter,
    rebuild_setters = setters_module.rebuild,
    begin_transaction = setters_module.begin_transaction,
    on_attribute_change = setters_module.on,
    off_attribute_change = setters_module.off,
    clear_attribute_listeners = setters_module.clear_listeners,

    -- Modifier functions (016d)
    MOD_TYPE = modifiers_module.MOD_TYPE,
    MOD_PRIORITY = modifiers_module.MOD_PRIORITY,
    SOURCE_CATEGORY = modifiers_module.SOURCE_CATEGORY,
    Modifier = modifiers_module.Modifier,
    add_modifier = modifiers_module.add,
    remove_modifier = modifiers_module.remove,
    remove_modifier_stack = modifiers_module.remove_stack,
    remove_modifiers_by_source = modifiers_module.remove_by_source,
    remove_modifiers_by_category = modifiers_module.remove_by_category,
    clean_expired_modifiers = modifiers_module.clean_expired,
    get_modifier = modifiers_module.get,
    get_modifiers = modifiers_module.get_all,
    count_modifiers = modifiers_module.count,
    has_modifier = modifiers_module.has,
    list_modifier_sources = modifiers_module.list_sources,
    clear_modifiers = modifiers_module.clear,
    clear_all_modifiers = modifiers_module.clear_all,
    refresh_modifier = modifiers_module.refresh,
    set_modifier_stacks = modifiers_module.set_stacks,
    apply_modifiers = modifiers_module.apply,
    get_modifiers_breakdown = modifiers_module.get_breakdown,

    -- Derived attribute functions (016e)
    -- Dependency graph utilities
    get_all_dependents = derived_module.get_all_dependents,
    get_all_dependencies = derived_module.get_all_dependencies,
    get_evaluation_order = derived_module.get_evaluation_order,

    -- Circular dependency detection
    detect_cycle = derived_module.detect_cycle,
    validate_no_cycles = derived_module.validate_no_cycles,

    -- Cache management
    is_dirty = derived_module.is_dirty,
    mark_derived_dirty = derived_module.mark_dirty,  -- Note: mark_dirty already exists from getters
    invalidate_all = derived_module.invalidate_all,
    recompute = derived_module.recompute,
    recompute_all = derived_module.recompute_all,
    get_dirty_count = derived_module.get_dirty_count,

    -- Debug and introspection
    explain_derivation = derived_module.explain,
    get_dependency_tree = derived_module.get_dependency_tree,
    format_dependency_tree = derived_module.format_dependency_tree,
    get_reverse_tree = derived_module.get_reverse_tree,
    list_derived = derived_module.list_derived,
    get_derived_stats = derived_module.get_stats,

    -- Formula helpers
    create_formula = derived_module.create_formula,
}
-- }}}

return attributes
