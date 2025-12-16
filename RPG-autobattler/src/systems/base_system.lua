-- {{{ BaseSystem framework
local BaseSystem = {}
BaseSystem.__index = BaseSystem

local debug = require("src.utils.debug")

-- {{{ BaseSystem:new
function BaseSystem:new(entity_manager, name)
    local system = {
        entity_manager = entity_manager,
        name = name or "unnamed_system",
        required_components = {},
        enabled = true,
        priority = 0,
        update_count = 0,
        last_entity_count = 0
    }
    setmetatable(system, BaseSystem)
    
    debug.info("Created system: " .. system.name, "ECS")
    return system
end
-- }}}

-- {{{ BaseSystem:set_required_components
function BaseSystem:set_required_components(components)
    self.required_components = components or {}
    if #self.required_components > 0 then
        debug.debug("System " .. self.name .. " requires components: " .. table.concat(self.required_components, ", "), "ECS")
    else
        debug.debug("System " .. self.name .. " requires no specific components", "ECS")
    end
end
-- }}}

-- {{{ BaseSystem:get_entities
function BaseSystem:get_entities()
    if #self.required_components == 0 then
        -- Return all entities if no requirements
        local entities = {}
        for _, entity in pairs(self.entity_manager.entities) do
            table.insert(entities, entity)
        end
        return entities
    end
    
    return self.entity_manager:get_entities_with_components(self.required_components)
end
-- }}}

-- {{{ BaseSystem:get_entity_count
function BaseSystem:get_entity_count()
    return #self:get_entities()
end
-- }}}

-- {{{ BaseSystem:update
function BaseSystem:update(dt)
    if not self.enabled then
        return
    end
    
    self.update_count = self.update_count + 1
    local entities = self:get_entities()
    local entity_count = #entities
    
    if entity_count ~= self.last_entity_count then
        debug.debug("System " .. self.name .. " processing " .. entity_count .. " entities", "ECS")
        self.last_entity_count = entity_count
    end
    
    -- Process each entity (override in subclasses)
    for _, entity in ipairs(entities) do
        self:process_entity(entity, dt)
    end
end
-- }}}

-- {{{ BaseSystem:process_entity
function BaseSystem:process_entity(entity, dt)
    -- Override in subclasses to define specific entity processing
    debug.debug("BaseSystem processing entity " .. entity.name .. " (override process_entity)", "ECS")
end
-- }}}

-- {{{ BaseSystem:draw
function BaseSystem:draw()
    if not self.enabled then
        return
    end
    
    local entities = self:get_entities()
    
    -- Render each entity (override in subclasses)
    for _, entity in ipairs(entities) do
        self:draw_entity(entity)
    end
end
-- }}}

-- {{{ BaseSystem:draw_entity
function BaseSystem:draw_entity(entity)
    -- Override in subclasses to define specific entity rendering
end
-- }}}

-- {{{ BaseSystem:enable
function BaseSystem:enable()
    self.enabled = true
    debug.debug("System " .. self.name .. " enabled", "ECS")
end
-- }}}

-- {{{ BaseSystem:disable
function BaseSystem:disable()
    self.enabled = false
    debug.debug("System " .. self.name .. " disabled", "ECS")
end
-- }}}

-- {{{ BaseSystem:is_enabled
function BaseSystem:is_enabled()
    return self.enabled
end
-- }}}

-- {{{ BaseSystem:set_priority
function BaseSystem:set_priority(priority)
    self.priority = priority or 0
    debug.debug("System " .. self.name .. " priority set to " .. self.priority, "ECS")
end
-- }}}

-- {{{ BaseSystem:get_priority
function BaseSystem:get_priority()
    return self.priority
end
-- }}}

-- {{{ BaseSystem:get_debug_info
function BaseSystem:get_debug_info()
    return {
        name = self.name,
        enabled = self.enabled,
        priority = self.priority,
        required_components = self.required_components,
        entity_count = self:get_entity_count(),
        update_count = self.update_count
    }
end
-- }}}

-- {{{ BaseSystem:print_debug_info
function BaseSystem:print_debug_info()
    local info = self:get_debug_info()
    
    debug.info("=== System Debug Info: " .. info.name .. " ===", "ECS")
    debug.info("Enabled: " .. tostring(info.enabled), "ECS")
    debug.info("Priority: " .. info.priority, "ECS")
    debug.info("Required components: " .. table.concat(info.required_components, ", "), "ECS")
    debug.info("Entity count: " .. info.entity_count, "ECS")
    debug.info("Update count: " .. info.update_count, "ECS")
    debug.info("=== End System Debug Info ===", "ECS")
end
-- }}}

-- {{{ BaseSystem:cleanup
function BaseSystem:cleanup()
    debug.info("Cleaning up system: " .. self.name, "ECS")
    self.entity_manager = nil
    self.enabled = false
end
-- }}}

return BaseSystem
-- }}}