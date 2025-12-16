-- {{{ EntityManager system
local EntityManager = {}
EntityManager.__index = EntityManager

local debug = require("src.utils.debug")

-- {{{ EntityManager:new
function EntityManager:new()
    local manager = {
        entities = {},
        next_id = 1,
        components = {},
        entity_count = 0,
        component_types = {}
    }
    setmetatable(manager, EntityManager)
    
    debug.info("EntityManager created", "ECS")
    return manager
end
-- }}}

-- {{{ EntityManager:create_entity
function EntityManager:create_entity(name)
    local entity = {
        id = self.next_id,
        name = name or ("entity_" .. self.next_id),
        components = {},
        created_time = love and love.timer and love.timer.getTime() or 0
    }
    
    self.entities[self.next_id] = entity
    self.next_id = self.next_id + 1
    self.entity_count = self.entity_count + 1
    
    debug.debug("Created entity: " .. entity.name .. " (ID: " .. entity.id .. ")", "ECS")
    return entity
end
-- }}}

-- {{{ EntityManager:add_component
function EntityManager:add_component(entity, component_type, component_data)
    if not entity or not component_type then
        debug.error("Invalid parameters for add_component", "ECS")
        return false
    end
    
    -- Add component to entity
    entity.components[component_type] = component_data
    
    -- Initialize component type tracking if needed
    if not self.components[component_type] then
        self.components[component_type] = {}
        self.component_types[component_type] = true
        debug.debug("Registered new component type: " .. component_type, "ECS")
    end
    
    -- Add to component index
    self.components[component_type][entity.id] = {
        entity = entity,
        data = component_data
    }
    
    debug.debug("Added " .. component_type .. " component to entity " .. entity.name, "ECS")
    return true
end
-- }}}

-- {{{ EntityManager:remove_component
function EntityManager:remove_component(entity, component_type)
    if not entity or not component_type then
        debug.error("Invalid parameters for remove_component", "ECS")
        return false
    end
    
    -- Remove from entity
    entity.components[component_type] = nil
    
    -- Remove from component index
    if self.components[component_type] then
        self.components[component_type][entity.id] = nil
    end
    
    debug.debug("Removed " .. component_type .. " component from entity " .. entity.name, "ECS")
    return true
end
-- }}}

-- {{{ EntityManager:get_component
function EntityManager:get_component(entity, component_type)
    return entity.components[component_type]
end
-- }}}

-- {{{ EntityManager:has_component
function EntityManager:has_component(entity, component_type)
    return entity.components[component_type] ~= nil
end
-- }}}

-- {{{ EntityManager:has_components
function EntityManager:has_components(entity, component_types)
    for _, component_type in ipairs(component_types) do
        if not self:has_component(entity, component_type) then
            return false
        end
    end
    return true
end
-- }}}

-- {{{ EntityManager:get_entities_with_component
function EntityManager:get_entities_with_component(component_type)
    local entities = {}
    
    if self.components[component_type] then
        for entity_id, entry in pairs(self.components[component_type]) do
            table.insert(entities, entry.entity)
        end
    end
    
    return entities
end
-- }}}

-- {{{ EntityManager:get_entities_with_components
function EntityManager:get_entities_with_components(component_types)
    local entities = {}
    
    for _, entity in pairs(self.entities) do
        if self:has_components(entity, component_types) then
            table.insert(entities, entity)
        end
    end
    
    return entities
end
-- }}}

-- {{{ EntityManager:remove_entity
function EntityManager:remove_entity(entity)
    if not entity then
        debug.error("Attempted to remove nil entity", "ECS")
        return false
    end
    
    -- Remove from all component indices
    for component_type, _ in pairs(entity.components) do
        if self.components[component_type] then
            self.components[component_type][entity.id] = nil
        end
    end
    
    -- Remove from entities table
    self.entities[entity.id] = nil
    self.entity_count = self.entity_count - 1
    
    debug.debug("Removed entity: " .. entity.name .. " (ID: " .. entity.id .. ")", "ECS")
    return true
end
-- }}}

-- {{{ EntityManager:get_entity_by_id
function EntityManager:get_entity_by_id(id)
    return self.entities[id]
end
-- }}}

-- {{{ EntityManager:get_entity_by_name
function EntityManager:get_entity_by_name(name)
    for _, entity in pairs(self.entities) do
        if entity.name == name then
            return entity
        end
    end
    return nil
end
-- }}}

-- {{{ EntityManager:get_entity_count
function EntityManager:get_entity_count()
    return self.entity_count
end
-- }}}

-- {{{ EntityManager:get_component_types
function EntityManager:get_component_types()
    local types = {}
    for component_type, _ in pairs(self.component_types) do
        table.insert(types, component_type)
    end
    return types
end
-- }}}

-- {{{ EntityManager:get_component_count
function EntityManager:get_component_count(component_type)
    if not self.components[component_type] then
        return 0
    end
    
    local count = 0
    for _ in pairs(self.components[component_type]) do
        count = count + 1
    end
    return count
end
-- }}}

-- {{{ EntityManager:clear_all
function EntityManager:clear_all()
    debug.info("Clearing all entities and components", "ECS")
    
    local entity_count = self.entity_count
    
    self.entities = {}
    self.components = {}
    self.component_types = {}
    self.entity_count = 0
    self.next_id = 1
    
    debug.info("Cleared " .. entity_count .. " entities", "ECS")
end
-- }}}

-- {{{ EntityManager:get_debug_info
function EntityManager:get_debug_info()
    local component_counts = {}
    for component_type, _ in pairs(self.component_types) do
        component_counts[component_type] = self:get_component_count(component_type)
    end
    
    return {
        entity_count = self.entity_count,
        next_id = self.next_id,
        component_types = self:get_component_types(),
        component_counts = component_counts
    }
end
-- }}}

-- {{{ EntityManager:print_debug_info
function EntityManager:print_debug_info()
    local info = self:get_debug_info()
    
    debug.info("=== EntityManager Debug Info ===", "ECS")
    debug.info("Entities: " .. info.entity_count, "ECS")
    debug.info("Next ID: " .. info.next_id, "ECS")
    debug.info("Component types: " .. #info.component_types, "ECS")
    
    for component_type, count in pairs(info.component_counts) do
        debug.info("  " .. component_type .. ": " .. count .. " entities", "ECS")
    end
    
    debug.info("=== End EntityManager Debug Info ===", "ECS")
end
-- }}}

return EntityManager
-- }}}