-- {{{ MenuState
local BaseState = require("src.systems.base_state")
local debug = require("src.utils.debug")

local MenuState = BaseState:new("menu")

-- Menu options
local menu_options = {
    {text = "Start Game", action = "start_game"},
    {text = "Unit Editor", action = "unit_editor"},
    {text = "Settings", action = "settings"},
    {text = "Quit", action = "quit"}
}

local selected_option = 1

-- {{{ MenuState:enter
function MenuState:enter()
    BaseState.enter(self)
    selected_option = 1
    debug.info("Menu state entered", "MENU")
end
-- }}}

-- {{{ MenuState:update
function MenuState:update(dt)
    BaseState.update(self, dt)
    -- Menu doesn't need complex updates
end
-- }}}

-- {{{ MenuState:draw
function MenuState:draw()
    BaseState.draw(self)
    
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Clear background
    love.graphics.clear(0.1, 0.1, 0.2)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1)
    local title = "RPG-Autobattler"
    local title_y = height * 0.2
    love.graphics.printf(title, 0, title_y, width, "center")
    
    -- Draw menu options
    local menu_start_y = height * 0.4
    local option_height = 40
    
    for i, option in ipairs(menu_options) do
        local y = menu_start_y + (i - 1) * option_height
        
        -- Highlight selected option
        if i == selected_option then
            love.graphics.setColor(1, 1, 0) -- Yellow for selected
            love.graphics.printf("> " .. option.text .. " <", 0, y, width, "center")
        else
            love.graphics.setColor(0.7, 0.7, 0.7) -- Gray for unselected
            love.graphics.printf(option.text, 0, y, width, "center")
        end
    end
    
    -- Draw instructions
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf("Use UP/DOWN arrows to navigate, ENTER to select", 0, height * 0.8, width, "center")
end
-- }}}

-- {{{ MenuState:keypressed
function MenuState:keypressed(key)
    if BaseState.keypressed(self, key) then
        return true
    end
    
    if key == "up" then
        selected_option = selected_option - 1
        if selected_option < 1 then
            selected_option = #menu_options
        end
        debug.debug("Menu selection changed to: " .. selected_option, "MENU")
        return true
    elseif key == "down" then
        selected_option = selected_option + 1
        if selected_option > #menu_options then
            selected_option = 1
        end
        debug.debug("Menu selection changed to: " .. selected_option, "MENU")
        return true
    elseif key == "return" or key == "space" then
        self:execute_selected_option()
        return true
    elseif key == "escape" then
        love.event.quit()
        return true
    end
    
    return false
end
-- }}}

-- {{{ MenuState:mousepressed
function MenuState:mousepressed(x, y, button)
    if BaseState.mousepressed(self, x, y, button) then
        return true
    end
    
    if button == 1 then -- Left click
        local height = love.graphics.getHeight()
        local menu_start_y = height * 0.4
        local option_height = 40
        
        -- Check if click is within menu area
        for i, option in ipairs(menu_options) do
            local option_y = menu_start_y + (i - 1) * option_height
            if y >= option_y and y <= option_y + option_height then
                selected_option = i
                self:execute_selected_option()
                return true
            end
        end
    end
    
    return false
end
-- }}}

-- {{{ MenuState:execute_selected_option
function MenuState:execute_selected_option()
    local option = menu_options[selected_option]
    debug.info("Executing menu option: " .. option.action, "MENU")
    
    local state_manager = require("src.systems.state_manager")
    
    if option.action == "start_game" then
        state_manager:change_state("game")
    elseif option.action == "unit_editor" then
        state_manager:change_state("editor")
    elseif option.action == "settings" then
        debug.info("Settings not implemented yet", "MENU")
    elseif option.action == "quit" then
        love.event.quit()
    end
end
-- }}}

return MenuState
-- }}}