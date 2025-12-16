-- Pause Menu for Magic Rumble

-- We need to use the Button class from menu.lua
-- For now, let's create a simple button implementation
local PauseButton = {}
PauseButton.__index = PauseButton

function PauseButton:new(x, y, width, height, text, callback)
    local button = {
        x = x,
        y = y,
        width = width,
        height = height,
        text = text,
        callback = callback,
        hovered = false
    }
    setmetatable(button, PauseButton)
    return button
end

function PauseButton:draw()
    local lightColor = {0.8, 0.8, 0.8}
    local darkColor = {0.4, 0.4, 0.4}
    local fillColor = {0.6, 0.6, 0.6}
    
    if self.hovered then
        fillColor = {0.7, 0.7, 0.7}
    end
    
    love.graphics.setColor(fillColor)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    
    love.graphics.setColor(lightColor)
    love.graphics.line(self.x, self.y, self.x + self.width, self.y)
    love.graphics.line(self.x, self.y, self.x, self.y + self.height)
    
    love.graphics.setColor(darkColor)
    love.graphics.line(self.x + self.width, self.y, 
                      self.x + self.width, self.y + self.height)
    love.graphics.line(self.x, self.y + self.height, 
                      self.x + self.width, self.y + self.height)
    
    love.graphics.setColor(1, 1, 1)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(self.text)
    local textHeight = font:getHeight()
    love.graphics.print(self.text, 
                       self.x + (self.width - textWidth) / 2,
                       self.y + (self.height - textHeight) / 2)
end

function PauseButton:isPointInside(x, y)
    return x >= self.x and x <= self.x + self.width and 
           y >= self.y and y <= self.y + self.height
end

function PauseButton:click()
    if self.callback then
        self.callback()
    end
end

local resume_button
local quit_button
local pause_menu_visible = false
local pause_overlay_alpha = 0

function pause_menu_init()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local buttonWidth = 200
    local buttonHeight = 50
    local buttonSpacing = 20
    
    local startX = (screenWidth - buttonWidth) / 2
    local startY = (screenHeight - (buttonHeight * 2 + buttonSpacing)) / 2
    
    resume_button = PauseButton:new(startX, startY, buttonWidth, buttonHeight, 
                                   "Resume Game", function()
        pause_menu_hide()
    end)
    
    quit_button = PauseButton:new(startX, startY + buttonHeight + buttonSpacing, 
                                 buttonWidth, buttonHeight, "Quit to Main Menu", function()
        pause_menu_hide()
        gamestate = "menu"
        menu_init()
    end)
    
    pause_menu_visible = false
    pause_overlay_alpha = 0
end

function pause_menu_toggle()
    if pause_menu_visible then
        pause_menu_hide()
    else
        pause_menu_show()
    end
end

function pause_menu_show()
    pause_menu_visible = true
    pause_overlay_alpha = 0
end

function pause_menu_hide()
    pause_menu_visible = false
    pause_overlay_alpha = 0
end

function pause_menu_is_visible()
    return pause_menu_visible
end

function pause_menu_update(dt)
    if pause_menu_visible then
        -- Fade in overlay
        pause_overlay_alpha = math.min(1.0, pause_overlay_alpha + dt * 4)
        
        -- Update button hover states
        local mouseX, mouseY = love.mouse.getPosition()
        resume_button.hovered = resume_button:isPointInside(mouseX, mouseY)
        quit_button.hovered = quit_button:isPointInside(mouseX, mouseY)
    else
        -- Fade out overlay
        pause_overlay_alpha = math.max(0, pause_overlay_alpha - dt * 6)
    end
end

function pause_menu_draw()
    if pause_overlay_alpha > 0 then
        -- Draw dimmed background
        love.graphics.setColor(0, 0, 0, 0.6 * pause_overlay_alpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        
        if pause_menu_visible then
            -- Draw menu background
            local screenWidth = love.graphics.getWidth()
            local screenHeight = love.graphics.getHeight()
            local menuWidth = 300
            local menuHeight = 200
            local menuX = (screenWidth - menuWidth) / 2
            local menuY = (screenHeight - menuHeight) / 2
            
            love.graphics.setColor(0.3, 0.3, 0.3, 0.9 * pause_overlay_alpha)
            love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight)
            
            love.graphics.setColor(1, 1, 1, pause_overlay_alpha)
            love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight)
            
            -- Draw title
            love.graphics.setColor(1, 1, 1, pause_overlay_alpha)
            local font = love.graphics.getFont()
            local titleText = "Game Paused"
            local titleWidth = font:getWidth(titleText)
            love.graphics.print(titleText, menuX + (menuWidth - titleWidth) / 2, menuY + 30)
            
            -- Draw buttons with alpha
            local old_color = {love.graphics.getColor()}
            resume_button:draw()
            quit_button:draw()
        end
    end
end

function pause_menu_mousepressed(x, y, button)
    if not pause_menu_visible then
        return false
    end
    
    if button == 1 then
        if resume_button:isPointInside(x, y) then
            resume_button:click()
            return true
        elseif quit_button:isPointInside(x, y) then
            quit_button:click()
            return true
        end
    end
    
    return false  -- Didn't handle the click
end

function pause_menu_keypressed(key)
    if key == "escape" then
        pause_menu_toggle()
        return true
    end
    
    return false  -- Didn't handle the key
end