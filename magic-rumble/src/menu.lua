local Button = {}
Button.__index = Button

function Button:new(x, y, width, height, text, callback)
    local button = {
        x = x,
        y = y,
        width = width,
        height = height,
        text = text,
        callback = callback,
        hovered = false
    }
    setmetatable(button, Button)
    return button
end

function Button:draw()
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

function Button:isPointInside(x, y)
    return x >= self.x and x <= self.x + self.width and 
           y >= self.y and y <= self.y + self.height
end

function Button:click()
    if self.callback then
        self.callback()
    end
end

local play_button
local quit_button

function menu_init()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local buttonWidth = 200
    local buttonHeight = 50
    local buttonSpacing = 20
    
    local startX = (screenWidth - buttonWidth) / 2
    local startY = (screenHeight - (buttonHeight * 2 + buttonSpacing)) / 2
    
    play_button = Button:new(startX, startY, buttonWidth, buttonHeight, 
                           "Play Game", function()
        gamestate = "game"
        drawables = {}
        game_init()
    end)
    
    quit_button = Button:new(startX, startY + buttonHeight + buttonSpacing, 
                           buttonWidth, buttonHeight, "Quit", function()
        love.event.quit()
    end)
    
    drawables = {play_button, quit_button}
end

function menu_update(dt)
    local mouseX, mouseY = love.mouse.getPosition()
    
    play_button.hovered = play_button:isPointInside(mouseX, mouseY)
    quit_button.hovered = quit_button:isPointInside(mouseX, mouseY)
end

function menu_mousepressed(x, y, button)
    if button == 1 then
        if play_button:isPointInside(x, y) then
            play_button:click()
        elseif quit_button:isPointInside(x, y) then
            quit_button:click()
        end
    end
end