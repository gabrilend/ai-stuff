--[[
Entity Component System - Main API

Provides entity management, component attachment, and system execution.
This module re-exports sub-module functions for a unified API.

Usage:
    local ecs = require("runtime.ecs")
    local entity = ecs.create_entity()
    ecs.destroy_entity(entity)
]]

local ecs = {}

-- {{{ Load sub-modules
local entity = require("runtime.ecs.entity")
local component = require("runtime.ecs.component")
local query_mod = require("runtime.ecs.query")
local system_mod = require("runtime.ecs.system")
-- }}}

-- {{{ Entity management exports
ecs.create_entity = entity.create
ecs.destroy_entity = entity.destroy
ecs.entity_exists = entity.exists
ecs.get_entity_count = entity.get_count
ecs.iterate_entities = entity.iterate
ecs.on_entity_create = entity.on_create
ecs.on_entity_destroy = entity.on_destroy
ecs.get_entity_stats = entity.get_stats
ecs.get_all_entity_ids = entity.get_all_ids
-- }}}

-- {{{ Component management exports
ecs.register_component = component.register
ecs.add_component = component.add
ecs.get_component = component.get
ecs.has_component = component.has
ecs.remove_component = component.remove
ecs.get_all_components = component.get_all_for_entity
ecs.get_component_names = component.get_component_names
ecs.get_component_defaults = component.get_defaults
ecs.get_registered_component_types = component.get_registered_types
ecs.get_component_storage = component.get_storage
ecs.get_component_stats = component.get_stats
-- }}}

-- {{{ Query exports
ecs.query = query_mod.query
ecs.query_single = query_mod.single
ecs.query_multi = query_mod.multi
ecs.query_count = query_mod.count
ecs.query_all = query_mod.all
ecs.query_first = query_mod.first
ecs.query_with_value = query_mod.with_value
ecs.query_with_predicate = query_mod.with_predicate
ecs.query_without = query_mod.without
-- }}}

-- {{{ System exports
ecs.register_system = system_mod.register
ecs.update_systems = system_mod.update
ecs.enable_system = system_mod.enable
ecs.disable_system = system_mod.disable
ecs.is_system_enabled = system_mod.is_enabled
ecs.set_all_systems_enabled = system_mod.set_all_enabled
ecs.get_system = system_mod.get
ecs.get_all_systems = system_mod.get_all
ecs.get_system_count = system_mod.get_count
ecs.unregister_system = system_mod.unregister
ecs.get_system_stats = system_mod.get_stats
ecs.reset_system_stats = system_mod.reset_stats
-- }}}

-- {{{ ecs.reset
-- Reset entire ECS to initial state.
-- Clears all entities and component instances (keeps type registrations).
function ecs.reset()
    entity.reset()
    component.reset()
end
-- }}}

-- {{{ ecs.clear_all
-- Clear everything for testing.
-- Removes all entities, components, and component type registrations.
function ecs.clear_all()
    entity.reset()
    component.clear_all()
end
-- }}}

-- {{{ ecs.clear_hooks
-- Clear all hooks (for testing).
function ecs.clear_hooks()
    entity.clear_hooks()
end
-- }}}

return ecs
