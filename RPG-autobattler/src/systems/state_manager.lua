-- {{{ StateManager system
local StateManager = {}

-- State management properties
StateManager.states = {}
StateManager.current_state = nil
StateManager.previous_state = nil
StateManager.transition_time = 0
StateManager.transitioning = false

local debug = require("src.utils.debug")

-- {{{ StateManager:add_state
function StateManager:add_state(name, state)
    if not name or not state then
        debug.error("Invalid state parameters: name=" .. tostring(name) .. " state=" .. tostring(state), "STATE")
        return false
    end
    
    self.states[name] = state
    debug.info("State added: " .. name, "STATE")
    return true
end
-- }}}

-- {{{ StateManager:get_state
function StateManager:get_state(name)
    return self.states[name]
end
-- }}}

-- {{{ StateManager:change_state
function StateManager:change_state(name, ...)
    local new_state = self.states[name]
    
    if not new_state then
        debug.error("Attempted to change to non-existent state: " .. tostring(name), "STATE")
        return false
    end
    
    debug.info("Changing state from " .. (self.current_state and self.current_state.name or "none") .. " to " .. name, "STATE")
    
    -- Exit current state
    if self.current_state and self.current_state.exit then
        self.current_state:exit()
    end
    
    -- Store previous state for potential restoration
    self.previous_state = self.current_state
    
    -- Set new current state
    self.current_state = new_state
    
    -- Enter new state
    if self.current_state and self.current_state.enter then
        self.current_state:enter(...)
    end
    
    -- Reset transition state
    self.transitioning = false
    self.transition_time = 0
    
    return true
end
-- }}}

-- {{{ StateManager:get_current_state_name
function StateManager:get_current_state_name()
    return self.current_state and self.current_state.name or "none"
end
-- }}}

-- {{{ StateManager:update
function StateManager:update(dt)
    if self.transitioning then
        self.transition_time = self.transition_time + dt
    end
    
    if self.current_state and self.current_state.update then
        self.current_state:update(dt)
    end
end
-- }}}

-- {{{ StateManager:draw
function StateManager:draw()
    if self.current_state and self.current_state.draw then
        self.current_state:draw()
    end
    
    -- Draw transition effects if transitioning
    if self.transitioning then
        self:draw_transition()
    end
end
-- }}}

-- {{{ StateManager:draw_transition
function StateManager:draw_transition()
    -- Simple fade transition effect
    if self.transition_time < 0.5 then
        local alpha = self.transition_time * 2
        love.graphics.setColor(0, 0, 0, alpha * 0.5)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end
end
-- }}}

-- {{{ StateManager:keypressed
function StateManager:keypressed(key)
    if self.current_state and self.current_state.keypressed then
        return self.current_state:keypressed(key)
    end
    return false
end
-- }}}

-- {{{ StateManager:keyreleased
function StateManager:keyreleased(key)
    if self.current_state and self.current_state.keyreleased then
        return self.current_state:keyreleased(key)
    end
    return false
end
-- }}}

-- {{{ StateManager:mousepressed
function StateManager:mousepressed(x, y, button)
    if self.current_state and self.current_state.mousepressed then
        return self.current_state:mousepressed(x, y, button)
    end
    return false
end
-- }}}

-- {{{ StateManager:mousereleased
function StateManager:mousereleased(x, y, button)
    if self.current_state and self.current_state.mousereleased then
        return self.current_state:mousereleased(x, y, button)
    end
    return false
end
-- }}}

-- {{{ StateManager:mousemoved
function StateManager:mousemoved(x, y, dx, dy)
    if self.current_state and self.current_state.mousemoved then
        return self.current_state:mousemoved(x, y, dx, dy)
    end
    return false
end
-- }}}

-- {{{ StateManager:textinput
function StateManager:textinput(text)
    if self.current_state and self.current_state.textinput then
        return self.current_state:textinput(text)
    end
    return false
end
-- }}}

-- {{{ StateManager:cleanup
function StateManager:cleanup()
    debug.info("Cleaning up StateManager", "STATE")
    
    -- Exit current state
    if self.current_state and self.current_state.exit then
        self.current_state:exit()
    end
    
    -- Cleanup all states
    for name, state in pairs(self.states) do
        if state.cleanup then
            state:cleanup()
        end
    end
    
    self.states = {}
    self.current_state = nil
    self.previous_state = nil
end
-- }}}

-- {{{ StateManager:get_debug_info
function StateManager:get_debug_info()
    return {
        current_state = self:get_current_state_name(),
        state_count = self:get_state_count(),
        transitioning = self.transitioning,
        transition_time = self.transition_time
    }
end
-- }}}

-- {{{ StateManager:get_state_count
function StateManager:get_state_count()
    local count = 0
    for _ in pairs(self.states) do
        count = count + 1
    end
    return count
end
-- }}}

return StateManager
-- }}}