-- Load debug module
local debug = require("src.utils.debug")

-- Load state management system
local StateManager = require("src.systems.state_manager")
local MenuState = require("src.systems.menu_state")
local GameState = require("src.systems.game_state")
local EditorState = require("src.systems.editor_state")

-- Global game configuration
local gameConfig = {
    version = "0.1.0",
    title = "RPG-Autobattler"
}

-- {{{ love.errorhandler
function love.errorhandler(msg)
    debug.error("Fatal error occurred: " .. tostring(msg), "MAIN")
    local trace = debug.traceback and debug.traceback() or "Stack trace not available"
    debug.error("Stack trace: " .. trace, "MAIN")
    
    -- Attempt to save error log
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local errorLog = string.format("Error at %s: %s\nStack trace:\n%s", 
        os.date("%Y-%m-%d %H:%M:%S"), 
        tostring(msg), 
        trace
    )
    
    if love.filesystem then
        love.filesystem.write("error_" .. timestamp .. ".log", errorLog)
    end
    
    -- Show error screen
    local function draw()
        love.graphics.clear(0.1, 0.1, 0.2)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("A fatal error has occurred:", 50, 50, love.graphics.getWidth() - 100)
        love.graphics.printf(tostring(msg), 50, 80, love.graphics.getWidth() - 100)
        love.graphics.printf("Error log saved. Press ESC to quit.", 50, 120, love.graphics.getWidth() - 100)
    end
    
    return function()
        love.event.pump()
        for name, a, b, c, d, e, f in love.event.poll() do
            if name == "quit" or (name == "keypressed" and a == "escape") then
                return 1
            end
        end
        draw()
        love.graphics.present()
        love.timer.sleep(0.1)
    end
end
-- }}}

-- {{{ love.load
function love.load()
    -- Game initialization
    love.window.setTitle(gameConfig.title .. " v" .. gameConfig.version)
    love.graphics.setBackgroundColor(0, 0, 0)
    
    debug.info(gameConfig.title .. " v" .. gameConfig.version .. " loaded successfully", "MAIN")
    debug.info("Love2D version: " .. table.concat({love.getVersion()}, "."), "MAIN")
    debug.info("Platform: " .. love.system.getOS(), "MAIN")
    
    -- Initialize state system
    debug.info("Initializing state management system", "MAIN")
    StateManager:add_state("menu", MenuState)
    StateManager:add_state("game", GameState)
    StateManager:add_state("editor", EditorState)
    
    -- Start with menu state
    StateManager:change_state("menu")
    debug.info("State system initialized, starting with menu state", "MAIN")
end
-- }}}

-- {{{ love.update
function love.update(dt)
    -- Route update to current state
    StateManager:update(dt)
end
-- }}}

-- {{{ love.draw
function love.draw()
    -- Route draw to current state
    StateManager:draw()
    
    -- Draw global debug information overlay
    if debug.enabled then
        local state_info = StateManager:get_debug_info()
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print("State: " .. state_info.current_state, love.graphics.getWidth() - 150, 10)
        love.graphics.print("States: " .. state_info.state_count, love.graphics.getWidth() - 150, 25)
    end
end
-- }}}


-- {{{ love.keypressed
function love.keypressed(key)
    debug.debug("Key pressed: " .. key, "MAIN")
    
    -- Handle global debug keys first
    if key == "f1" then
        debug.toggle()
        return
    elseif key == "f2" then
        debug.toggleFPS()
        return
    elseif key == "f3" then
        debug.toggleCoordinates()
        return
    elseif key == "f4" then
        debug.toggleMemory()
        return
    elseif key == "f12" then
        debug.takeScreenshot()
        return
    end
    
    -- Route to current state (state can handle ESC for quit if appropriate)
    if not StateManager:keypressed(key) then
        -- If state didn't handle the key, check for global actions
        if key == "escape" then
            debug.info("Global quit requested by user", "MAIN")
            love.event.quit()
        end
    end
end
-- }}}

-- {{{ love.mousepressed
function love.mousepressed(x, y, button)
    debug.debug("Mouse button " .. button .. " pressed at (" .. x .. ", " .. y .. ")", "MAIN")
    StateManager:mousepressed(x, y, button)
end
-- }}}

-- {{{ love.mousereleased
function love.mousereleased(x, y, button)
    debug.debug("Mouse button " .. button .. " released at (" .. x .. ", " .. y .. ")", "MAIN")
    StateManager:mousereleased(x, y, button)
end
-- }}}

-- {{{ love.mousemoved
function love.mousemoved(x, y, dx, dy)
    StateManager:mousemoved(x, y, dx, dy)
end
-- }}}

-- {{{ love.quit
function love.quit()
    -- Cleanup before exit
    debug.info("Game shutting down...", "MAIN")
    
    -- Cleanup state system
    StateManager:cleanup()
    
    debug.info("Cleanup completed", "MAIN")
    return false -- Allow the game to quit
end
-- }}}