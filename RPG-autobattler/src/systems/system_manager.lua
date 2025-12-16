-- {{{ SystemManager
local SystemManager = {}
SystemManager.__index = SystemManager

local debug = require("src.utils.debug")

-- {{{ SystemManager:new
function SystemManager:new(entity_manager)
    local manager = {
        entity_manager = entity_manager,
        systems = {},
        update_systems = {},
        render_systems = {},
        system_count = 0
    }
    setmetatable(manager, SystemManager)
    
    debug.info("SystemManager created", "ECS")
    return manager
end
-- }}}

-- {{{ SystemManager:add_system
function SystemManager:add_system(system, update_order, render_order)
    if not system then
        debug.error("Attempted to add nil system", "ECS")
        return false
    end
    
    self.systems[system.name] = system
    self.system_count = self.system_count + 1
    
    -- Add to update list if it has update order
    if update_order then
        table.insert(self.update_systems, {system = system, order = update_order})
        -- Sort by order
        table.sort(self.update_systems, function(a, b) return a.order < b.order end)
    end
    
    -- Add to render list if it has render order
    if render_order then
        table.insert(self.render_systems, {system = system, order = render_order})
        -- Sort by order
        table.sort(self.render_systems, function(a, b) return a.order < b.order end)
    end
    
    debug.info("Added system: " .. system.name .. " (update: " .. tostring(update_order) .. ", render: " .. tostring(render_order) .. ")", "ECS")
    return true
end
-- }}}

-- {{{ SystemManager:remove_system
function SystemManager:remove_system(system_name)
    local system = self.systems[system_name]
    if not system then
        debug.error("System not found: " .. system_name, "ECS")
        return false
    end
    
    -- Remove from update systems
    for i = #self.update_systems, 1, -1 do
        if self.update_systems[i].system.name == system_name then
            table.remove(self.update_systems, i)
        end
    end
    
    -- Remove from render systems
    for i = #self.render_systems, 1, -1 do
        if self.render_systems[i].system.name == system_name then
            table.remove(self.render_systems, i)
        end
    end
    
    -- Cleanup system
    if system.cleanup then
        system:cleanup()
    end
    
    self.systems[system_name] = nil
    self.system_count = self.system_count - 1
    
    debug.info("Removed system: " .. system_name, "ECS")
    return true
end
-- }}}

-- {{{ SystemManager:get_system
function SystemManager:get_system(system_name)
    return self.systems[system_name]
end
-- }}}

-- {{{ SystemManager:update
function SystemManager:update(dt)
    for _, entry in ipairs(self.update_systems) do
        if entry.system:is_enabled() then
            entry.system:update(dt)
        end
    end
end
-- }}}

-- {{{ SystemManager:draw
function SystemManager:draw()
    for _, entry in ipairs(self.render_systems) do
        if entry.system:is_enabled() then
            entry.system:draw()
        end
    end
end
-- }}}

-- {{{ SystemManager:enable_system
function SystemManager:enable_system(system_name)
    local system = self.systems[system_name]
    if system then
        system:enable()
        return true
    end
    debug.error("System not found: " .. system_name, "ECS")
    return false
end
-- }}}

-- {{{ SystemManager:disable_system
function SystemManager:disable_system(system_name)
    local system = self.systems[system_name]
    if system then
        system:disable()
        return true
    end
    debug.error("System not found: " .. system_name, "ECS")
    return false
end
-- }}}

-- {{{ SystemManager:get_system_count
function SystemManager:get_system_count()
    return self.system_count
end
-- }}}

-- {{{ SystemManager:get_system_names
function SystemManager:get_system_names()
    local names = {}
    for name, _ in pairs(self.systems) do
        table.insert(names, name)
    end
    return names
end
-- }}}

-- {{{ SystemManager:cleanup
function SystemManager:cleanup()
    debug.info("Cleaning up SystemManager", "ECS")
    
    for name, system in pairs(self.systems) do
        if system.cleanup then
            system:cleanup()
        end
    end
    
    self.systems = {}
    self.update_systems = {}
    self.render_systems = {}
    self.system_count = 0
end
-- }}}

-- {{{ SystemManager:get_debug_info
function SystemManager:get_debug_info()
    local system_info = {}
    for name, system in pairs(self.systems) do
        system_info[name] = system:get_debug_info()
    end
    
    return {
        system_count = self.system_count,
        update_systems_count = #self.update_systems,
        render_systems_count = #self.render_systems,
        systems = system_info
    }
end
-- }}}

-- {{{ SystemManager:print_debug_info
function SystemManager:print_debug_info()
    local info = self:get_debug_info()
    
    debug.info("=== SystemManager Debug Info ===", "ECS")
    debug.info("Total systems: " .. info.system_count, "ECS")
    debug.info("Update systems: " .. info.update_systems_count, "ECS")
    debug.info("Render systems: " .. info.render_systems_count, "ECS")
    
    for name, system_info in pairs(info.systems) do
        debug.info("System " .. name .. ": enabled=" .. tostring(system_info.enabled) .. ", entities=" .. system_info.entity_count, "ECS")
    end
    
    debug.info("=== End SystemManager Debug Info ===", "ECS")
end
-- }}}

return SystemManager
-- }}}