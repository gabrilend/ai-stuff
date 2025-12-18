-- {{{ EditorState
local BaseState = require("src.systems.base_state")
local debug = require("src.utils.debug")

local EditorState = BaseState:new("editor")

-- {{{ EditorState:enter
function EditorState:enter()
    BaseState.enter(self)
    debug.info("Editor state entered", "EDITOR")
end
-- }}}

-- {{{ EditorState:exit
function EditorState:exit()
    BaseState.exit(self)
    debug.info("Editor state exited", "EDITOR")
end
-- }}}

-- {{{ EditorState:update
function EditorState:update(dt)
    BaseState.update(self, dt)
    -- Editor-specific updates would go here
end
-- }}}

-- {{{ EditorState:draw
function EditorState:draw()
    BaseState.draw(self)
    
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Clear background
    love.graphics.clear(0.2, 0.1, 0.2) -- Purple tint for editor
    
    -- Draw title
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Unit Template Editor", 0, height * 0.1, width, "center")
    
    -- Placeholder content
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf("Editor functionality will be implemented in future issues.", 0, height * 0.3, width, "center")
    love.graphics.printf("This is a placeholder state to demonstrate state management.", 0, height * 0.35, width, "center")
    
    -- Draw instructions
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.printf("Press ESC to return to menu", 0, height * 0.8, width, "center")
    love.graphics.printf("Press F5 for state debug info", 0, height * 0.85, width, "center")
    
    -- Draw debug info if enabled
    if debug.enabled then
        debug.drawDebugInfo(0, 0, 0)
    end
end
-- }}}

-- {{{ EditorState:keypressed
function EditorState:keypressed(key)
    if BaseState.keypressed(self, key) then
        return true
    end
    
    if key == "escape" then
        local state_manager = require("src.systems.state_manager")
        state_manager:change_state("menu")
        return true
    end
    
    return false
end
-- }}}

return EditorState
-- }}}