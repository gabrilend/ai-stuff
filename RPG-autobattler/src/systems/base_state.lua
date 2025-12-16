-- {{{ BaseState class
local BaseState = {}
BaseState.__index = BaseState

local debug = require("src.utils.debug")

-- {{{ BaseState:new
function BaseState:new(name)
    local state = {
        name = name or "unnamed_state",
        created_time = love and love.timer and love.timer.getTime() or 0,
        enter_time = 0,
        data = {}
    }
    setmetatable(state, BaseState)
    
    debug.info("Created new state: " .. state.name, "STATE")
    return state
end
-- }}}

-- {{{ BaseState:enter
function BaseState:enter(...)
    self.enter_time = love and love.timer and love.timer.getTime() or 0
    debug.info("Entering state: " .. self.name, "STATE")
    
    -- Override in subclasses for custom enter logic
end
-- }}}

-- {{{ BaseState:exit
function BaseState:exit()
    local time_in_state = (love and love.timer and love.timer.getTime() or 0) - self.enter_time
    debug.info("Exiting state: " .. self.name .. " (time in state: " .. string.format("%.2f", time_in_state) .. "s)", "STATE")
    
    -- Override in subclasses for custom exit logic
end
-- }}}

-- {{{ BaseState:update
function BaseState:update(dt)
    -- Override in subclasses for state-specific update logic
end
-- }}}

-- {{{ BaseState:draw
function BaseState:draw()
    -- Override in subclasses for state-specific rendering
end
-- }}}

-- {{{ BaseState:keypressed
function BaseState:keypressed(key)
    debug.debug("Key pressed in " .. self.name .. ": " .. key, "STATE")
    
    -- Common debug key handling
    if key == "f5" then
        debug.info("State debug info: " .. self.name, "STATE")
        self:print_debug_info()
        return true
    end
    
    -- Return false to allow other handlers to process the key
    return false
end
-- }}}

-- {{{ BaseState:keyreleased
function BaseState:keyreleased(key)
    debug.debug("Key released in " .. self.name .. ": " .. key, "STATE")
    return false
end
-- }}}

-- {{{ BaseState:mousepressed
function BaseState:mousepressed(x, y, button)
    debug.debug("Mouse pressed in " .. self.name .. " at (" .. x .. ", " .. y .. ") button " .. button, "STATE")
    return false
end
-- }}}

-- {{{ BaseState:mousereleased
function BaseState:mousereleased(x, y, button)
    debug.debug("Mouse released in " .. self.name .. " at (" .. x .. ", " .. y .. ") button " .. button, "STATE")
    return false
end
-- }}}

-- {{{ BaseState:mousemoved
function BaseState:mousemoved(x, y, dx, dy)
    -- Usually don't log mouse movement due to frequency
    return false
end
-- }}}

-- {{{ BaseState:textinput
function BaseState:textinput(text)
    debug.debug("Text input in " .. self.name .. ": " .. text, "STATE")
    return false
end
-- }}}

-- {{{ BaseState:set_data
function BaseState:set_data(key, value)
    self.data[key] = value
    debug.debug("Set data in " .. self.name .. ": " .. key .. " = " .. tostring(value), "STATE")
end
-- }}}

-- {{{ BaseState:get_data
function BaseState:get_data(key, default)
    local value = self.data[key]
    if value == nil then
        return default
    end
    return value
end
-- }}}

-- {{{ BaseState:clear_data
function BaseState:clear_data()
    debug.info("Clearing data for state: " .. self.name, "STATE")
    self.data = {}
end
-- }}}

-- {{{ BaseState:cleanup
function BaseState:cleanup()
    debug.info("Cleaning up state: " .. self.name, "STATE")
    self:clear_data()
end
-- }}}

-- {{{ BaseState:get_time_in_state
function BaseState:get_time_in_state()
    if self.enter_time == 0 then
        return 0
    end
    return (love and love.timer and love.timer.getTime() or 0) - self.enter_time
end
-- }}}

-- {{{ BaseState:print_debug_info
function BaseState:print_debug_info()
    debug.info("=== State Debug Info: " .. self.name .. " ===", "STATE")
    debug.info("Time in state: " .. string.format("%.2f", self:get_time_in_state()) .. "s", "STATE")
    debug.info("Data entries: " .. self:get_data_count(), "STATE")
    
    for key, value in pairs(self.data) do
        debug.info("  " .. key .. " = " .. tostring(value), "STATE")
    end
    
    debug.info("=== End State Debug Info ===", "STATE")
end
-- }}}

-- {{{ BaseState:get_data_count
function BaseState:get_data_count()
    local count = 0
    for _ in pairs(self.data) do
        count = count + 1
    end
    return count
end
-- }}}

-- {{{ BaseState:get_debug_info
function BaseState:get_debug_info()
    return {
        name = self.name,
        time_in_state = self:get_time_in_state(),
        data_count = self:get_data_count(),
        created_time = self.created_time,
        enter_time = self.enter_time
    }
end
-- }}}

return BaseState
-- }}}