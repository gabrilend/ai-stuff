-- {{{ GameState
local BaseState = require("src.systems.base_state")
local debug = require("src.utils.debug")
local TutorialSystem = require("src.systems.tutorial_system")
local Vector2 = require("src.utils.vector2")

local GameState = BaseState:new("game")

-- Import existing game logic functions (will integrate from main.lua)
local inputState = {
    mouseX = 0,
    mouseY = 0,
    clickHistory = {},
    inputHistory = {},
    maxHistorySize = 10
}

local gameState = {
    frameCount = 0,
    backgroundColor = {0, 0, 0},
    frameTime = 0,
    tutorialActive = true,
    gamePaused = true
}

-- {{{ GameState:enter
function GameState:enter()
    BaseState.enter(self)
    debug.info("Game state entered", "GAME")
    
    -- Initialize game-specific state
    gameState.frameCount = 0
    inputState.clickHistory = {}
    inputState.inputHistory = {}
    gameState.tutorialActive = true
    gameState.gamePaused = true
    
    -- Set background color
    love.graphics.setBackgroundColor(gameState.backgroundColor[1], gameState.backgroundColor[2], gameState.backgroundColor[3])
    
    -- Initialize tutorial system with simple renderer
    local simple_renderer = {
        draw_rectangle = function(self, x, y, w, h, color, mode)
            love.graphics.setColor(color)
            love.graphics.rectangle(mode or "fill", x, y, w, h)
        end,
        draw_circle = function(self, x, y, radius, color, mode)
            love.graphics.setColor(color)
            love.graphics.circle(mode or "fill", x, y, radius)
        end,
        draw_line = function(self, x1, y1, x2, y2, color, width)
            love.graphics.setColor(color)
            love.graphics.setLineWidth(width or 1)
            love.graphics.line(x1, y1, x2, y2)
        end,
        draw_text = function(self, text, x, y, color)
            love.graphics.setColor(color)
            love.graphics.print(text, x, y)
        end,
        draw_arrow = function(self, x1, y1, x2, y2, color, width, arrowhead_size)
            -- Draw line
            love.graphics.setColor(color)
            love.graphics.setLineWidth(width or 2)
            love.graphics.line(x1, y1, x2, y2)
            
            -- Draw arrowhead
            local angle = math.atan2(y2 - y1, x2 - x1)
            local size = arrowhead_size or 8
            local arrow_angle = math.pi / 6
            
            local ax1 = x2 - size * math.cos(angle - arrow_angle)
            local ay1 = y2 - size * math.sin(angle - arrow_angle)
            local ax2 = x2 - size * math.cos(angle + arrow_angle)
            local ay2 = y2 - size * math.sin(angle + arrow_angle)
            
            love.graphics.line(x2, y2, ax1, ay1)
            love.graphics.line(x2, y2, ax2, ay2)
        end
    }
    
    self.tutorial_system = TutorialSystem:new(simple_renderer)
    self:setup_tutorial()
end
-- }}}

-- {{{ GameState:exit
function GameState:exit()
    BaseState.exit(self)
    debug.info("Game state exited", "GAME")
end
-- }}}

-- {{{ GameState:update
function GameState:update(dt)
    BaseState.update(self, dt)
    
    -- Start performance monitoring
    debug.startFrame()
    
    -- Update tutorial system
    if self.tutorial_system then
        self.tutorial_system:update(dt)
    end
    
    -- Only update game logic if not paused by tutorial
    if not gameState.gamePaused then
        gameState.frameCount = gameState.frameCount + 1
        
        if gameState.frameCount % 60 == 0 then
            debug.debug("Game update - Frame: " .. gameState.frameCount, "GAME")
        end
    end
    
    -- End performance monitoring
    gameState.frameTime = debug.endFrame()
end
-- }}}

-- {{{ GameState:draw
function GameState:draw()
    BaseState.draw(self)
    
    -- Draw test pattern (from main.lua)
    self:drawTestPattern()
    
    -- Draw UI text
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Game State - RPG-Autobattler", 10, 10)
    love.graphics.print("Controls: ESC=menu, F1-F4=debug, SPACE=bg, R=reset", 10, 30)
    
    -- Draw click history circles
    self:drawClickHistory()
    
    -- Draw debug information
    if debug.enabled then
        debug.drawDebugInfo(inputState.mouseX, inputState.mouseY, gameState.frameTime)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Frame: " .. gameState.frameCount, 10, 85)
        love.graphics.print("Clicks: " .. #inputState.clickHistory, 10, 100)
        
        self:drawInputHistory()
    end
    
    -- Draw tutorial overlay
    if self.tutorial_system and gameState.tutorialActive then
        self.tutorial_system:draw()
    end
end
-- }}}

-- {{{ GameState:drawTestPattern
function GameState:drawTestPattern()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Central rectangle (represents future game area)
    love.graphics.setColor(0.2, 0.2, 0.8) -- Blue
    local rectWidth = 400
    local rectHeight = 300
    local rectX = (width - rectWidth) / 2
    local rectY = (height - rectHeight) / 2
    love.graphics.rectangle("line", rectX, rectY, rectWidth, rectHeight)
    
    -- Corner circles (test shape rendering)
    love.graphics.setColor(1, 0, 0) -- Red
    love.graphics.circle("fill", 50, 50, 30) -- Top-left
    
    love.graphics.setColor(0, 1, 0) -- Green
    love.graphics.circle("fill", width - 50, 50, 30) -- Top-right
    
    love.graphics.setColor(1, 1, 0) -- Yellow
    love.graphics.circle("fill", 50, height - 50, 30) -- Bottom-left
    
    love.graphics.setColor(1, 0, 1) -- Magenta
    love.graphics.circle("fill", width - 50, height - 50, 30) -- Bottom-right
    
    -- Diagonal lines (test line rendering)
    love.graphics.setColor(0, 1, 1) -- Cyan
    love.graphics.setLineWidth(3)
    love.graphics.line(0, 0, width, height) -- Top-left to bottom-right
    love.graphics.line(width, 0, 0, height) -- Top-right to bottom-left
    
    -- Center cross
    love.graphics.setColor(1, 1, 1) -- White
    love.graphics.setLineWidth(2)
    love.graphics.line(width/2, 0, width/2, height) -- Vertical
    love.graphics.line(0, height/2, width, height/2) -- Horizontal
    
    -- Reset line width
    love.graphics.setLineWidth(1)
end
-- }}}

-- {{{ GameState:drawClickHistory
function GameState:drawClickHistory()
    for i, click in ipairs(inputState.clickHistory) do
        local alpha = 1 - (i - 1) / inputState.maxHistorySize
        if click.button == 1 then
            love.graphics.setColor(1, 0, 0, alpha) -- Red for left click
        elseif click.button == 2 then
            love.graphics.setColor(0, 1, 0, alpha) -- Green for right click
        else
            love.graphics.setColor(0, 0, 1, alpha) -- Blue for other clicks
        end
        love.graphics.circle("fill", click.x, click.y, 15)
    end
end
-- }}}

-- {{{ GameState:drawInputHistory
function GameState:drawInputHistory()
    love.graphics.setColor(1, 1, 1)
    for i, input in ipairs(inputState.inputHistory) do
        local y = 120 + (i - 1) * 15
        love.graphics.print(input, 10, y)
    end
end
-- }}}

-- {{{ GameState:addToInputHistory
function GameState:addToInputHistory(text)
    table.insert(inputState.inputHistory, 1, text)
    if #inputState.inputHistory > inputState.maxHistorySize then
        table.remove(inputState.inputHistory)
    end
end
-- }}}

-- {{{ GameState:keypressed
function GameState:keypressed(key)
    if BaseState.keypressed(self, key) then
        return true
    end
    
    -- Tutorial system handles input first when active
    if self.tutorial_system and gameState.tutorialActive then
        if self.tutorial_system:handle_input(key) then
            -- Check if tutorial completed
            if not self.tutorial_system:is_active() then
                gameState.tutorialActive = false
                gameState.gamePaused = false
                debug.info("Tutorial completed, game unpaused", "GAME")
            end
            return true
        end
    end
    
    -- Only handle game input if not paused by tutorial
    if gameState.gamePaused then
        return true
    end
    
    self:addToInputHistory("Key: " .. key)
    debug.debug("Key pressed in game: " .. key, "GAME")
    
    if key == "escape" then
        local state_manager = require("src.systems.state_manager")
        state_manager:change_state("menu")
        return true
    elseif key == "space" then
        -- Test action - change background color
        gameState.backgroundColor = {math.random(), math.random(), math.random()}
        love.graphics.setBackgroundColor(gameState.backgroundColor[1], gameState.backgroundColor[2], gameState.backgroundColor[3])
        local colorStr = string.format("%.2f,%.2f,%.2f", gameState.backgroundColor[1], gameState.backgroundColor[2], gameState.backgroundColor[3])
        self:addToInputHistory("BG Color: " .. colorStr)
        debug.info("Background color changed to: " .. colorStr, "GAME")
        return true
    elseif key == "r" then
        -- Reset test state
        gameState.backgroundColor = {0, 0, 0}
        love.graphics.setBackgroundColor(0, 0, 0)
        inputState.clickHistory = {}
        inputState.inputHistory = {}
        self:addToInputHistory("Reset state")
        debug.info("Game state reset", "GAME")
        return true
    elseif key == "t" then
        -- Restart tutorial
        self:setup_tutorial()
        gameState.tutorialActive = true
        gameState.gamePaused = true
        debug.info("Tutorial restarted", "GAME")
        return true
    end
    
    return false
end
-- }}}

-- {{{ GameState:mousepressed
function GameState:mousepressed(x, y, button)
    if BaseState.mousepressed(self, x, y, button) then
        return true
    end
    
    -- Tutorial system handles input first when active
    if self.tutorial_system and gameState.tutorialActive then
        -- Mouse clicks advance tutorial
        if self.tutorial_system:handle_input("space") then
            -- Check if tutorial completed
            if not self.tutorial_system:is_active() then
                gameState.tutorialActive = false
                gameState.gamePaused = false
                debug.info("Tutorial completed, game unpaused", "GAME")
            end
            return true
        end
    end
    
    -- Only handle game input if not paused by tutorial
    if gameState.gamePaused then
        return true
    end
    
    local clickInfo = {x = x, y = y, button = button}
    
    -- Add to click history
    table.insert(inputState.clickHistory, 1, clickInfo)
    if #inputState.clickHistory > inputState.maxHistorySize then
        table.remove(inputState.clickHistory)
    end
    
    -- Add to input history
    local buttonName = button == 1 and "Left" or (button == 2 and "Right" or "Button" .. button)
    self:addToInputHistory("Click: " .. buttonName .. " at " .. x .. "," .. y)
    debug.debug("Mouse " .. buttonName .. " click at (" .. x .. ", " .. y .. ")", "GAME")
    
    if button == 2 then
        -- Right click - clear nearest click circle
        self:clearNearestClick(x, y)
    end
    
    return true
end
-- }}}

-- {{{ GameState:mousemoved
function GameState:mousemoved(x, y, dx, dy)
    if BaseState.mousemoved(self, x, y, dx, dy) then
        return true
    end
    
    inputState.mouseX = x
    inputState.mouseY = y
    return false
end
-- }}}

-- {{{ GameState:clearNearestClick
function GameState:clearNearestClick(x, y)
    local nearestIndex = nil
    local minDistance = math.huge
    local nearestClick = nil
    
    for i, click in ipairs(inputState.clickHistory) do
        local distance = math.sqrt((click.x - x)^2 + (click.y - y)^2)
        if distance < minDistance then
            minDistance = distance
            nearestIndex = i
            nearestClick = click
        end
    end
    
    if nearestIndex and minDistance < 50 then -- Within 50 pixels
        table.remove(inputState.clickHistory, nearestIndex)
        self:addToInputHistory("Cleared click at " .. nearestClick.x .. "," .. nearestClick.y)
    end
end
-- }}}

-- {{{ GameState:setup_tutorial
function GameState:setup_tutorial()
    if not self.tutorial_system then
        return
    end
    
    self.tutorial_system:clear_steps()
    
    -- Step 1: Welcome and overview
    self.tutorial_system:add_step(
        "Welcome to RPG Autobattler Test",
        "This tutorial will guide you through the game interface and test elements. Click or press SPACE to continue through each step.",
        Vector2:new(love.graphics.getWidth()/2, love.graphics.getHeight()/2),
        "down",
        "Click anywhere or press SPACE to continue"
    )
    
    -- Step 2: Title and header
    self.tutorial_system:add_step(
        "Game Title",
        "This shows the current game state and title. The test environment displays 'Game State - RPG-Autobattler' to indicate you're in the test mode.",
        Vector2:new(150, 10),
        "down",
        "Click or press SPACE for next"
    )
    
    -- Step 3: Control instructions
    self.tutorial_system:add_step(
        "Control Instructions",
        "These are the basic controls available. ESC returns to menu, F1-F4 toggle debug info, SPACE changes background, R resets the test state.",
        Vector2:new(250, 30),
        "down",
        "Click or press SPACE for next"
    )
    
    -- Step 4: Central blue rectangle
    self.tutorial_system:add_step(
        "Game Area",
        "This blue rectangle represents the main game area where the RPG autobattler action will take place. It's currently a placeholder for the battlefield.",
        Vector2:new(love.graphics.getWidth()/2, love.graphics.getHeight()/2),
        "down",
        "Click or press SPACE for next"
    )
    
    -- Step 5: Corner circles - Red
    self.tutorial_system:add_step(
        "Red Corner Circle",
        "These colored circles test shape rendering capabilities. This red circle is in the top-left corner and tests the fill circle drawing function.",
        Vector2:new(50, 50),
        "right",
        "Click or press SPACE for next"
    )
    
    -- Step 6: Corner circles - Green
    self.tutorial_system:add_step(
        "Green Corner Circle", 
        "The green circle in the top-right tests color rendering and positioning accuracy. Each corner uses different colors to verify the rendering system.",
        Vector2:new(love.graphics.getWidth() - 50, 50),
        "left",
        "Click or press SPACE for next"
    )
    
    -- Step 7: Diagonal lines
    self.tutorial_system:add_step(
        "Diagonal Lines",
        "These cyan diagonal lines test line drawing capabilities and screen-spanning geometry. They connect opposite corners to test coordinate systems.",
        Vector2:new(love.graphics.getWidth()/2, love.graphics.getHeight()/4),
        "down",
        "Click or press SPACE for next"
    )
    
    -- Step 8: Center cross
    self.tutorial_system:add_step(
        "Center Cross",
        "The white cross marks the exact center of the screen and tests horizontal/vertical line drawing. This helps verify coordinate accuracy.",
        Vector2:new(love.graphics.getWidth()/2, love.graphics.getHeight()/2),
        "up",
        "Click or press SPACE for next"
    )
    
    -- Step 9: Click interaction
    self.tutorial_system:add_step(
        "Click Testing",
        "You can click anywhere on the screen to create colored circles. Left clicks create red circles, right clicks remove nearby circles. This tests mouse input handling.",
        Vector2:new(love.graphics.getWidth()/2, love.graphics.getHeight() * 0.7),
        "up",
        "Try clicking! Then press SPACE for next"
    )
    
    -- Step 10: Debug information
    self.tutorial_system:add_step(
        "Debug Information",
        "Press F1 to toggle debug information display. This shows performance data, frame count, click count, and input history for testing purposes.",
        Vector2:new(100, 100),
        "right",
        "Try pressing F1! Then SPACE for next"
    )
    
    -- Step 11: Interactive controls
    self.tutorial_system:add_step(
        "Interactive Controls",
        "Try the interactive controls: SPACE changes background color, R resets everything, F1-F4 toggle different debug modes. These test various game systems.",
        Vector2:new(love.graphics.getWidth()/2, love.graphics.getHeight() * 0.8),
        "up",
        "Try the controls! Then SPACE to finish"
    )
    
    -- Step 12: Tutorial complete
    self.tutorial_system:add_step(
        "Tutorial Complete!",
        "You've learned about all the test elements. The tutorial will now end and you can freely interact with the test environment. Press T at any time to restart this tutorial.",
        Vector2:new(love.graphics.getWidth()/2, love.graphics.getHeight()/2),
        "down",
        "Press SPACE to start testing!"
    )
    
    -- Start the tutorial
    self.tutorial_system:start_tutorial()
    debug.info("Tutorial setup complete with " .. #self.tutorial_system.tutorial_steps .. " steps", "GAME")
end
-- }}}

return GameState
-- }}}