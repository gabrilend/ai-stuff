-- {{{ debug module
local debug = {}

-- Debug configuration
debug.enabled = true
debug.show_fps = true
debug.show_coordinates = true
debug.show_memory = true
debug.show_performance = true
debug.log_level = "info"  -- error, warn, info, debug
debug.log_to_file = false

-- Internal state
local startTime = love and love.timer and love.timer.getTime() or 0
local frameStartTime = 0
local logLevels = {
    error = 1,
    warn = 2,
    info = 3,
    debug = 4
}

-- {{{ debug.setLogLevel
function debug.setLogLevel(level)
    if logLevels[level] then
        debug.log_level = level
    end
end
-- }}}

-- {{{ debug.log
function debug.log(level, message, module)
    if not debug.enabled then return end
    
    local levelNum = logLevels[level] or 4
    local currentLevelNum = logLevels[debug.log_level] or 4
    
    if levelNum <= currentLevelNum then
        local currentTime = love and love.timer and love.timer.getTime() or 0
        local timestamp = string.format("%.3f", currentTime - startTime)
        local moduleStr = module and string.format("[%s] ", module) or ""
        local logMsg = string.format("[%s] %s%s%s", 
            timestamp, 
            level:upper(), 
            moduleStr, 
            message
        )
        
        print(logMsg)
        
        if debug.log_to_file then
            -- TODO: Implement file logging
        end
    end
end
-- }}}

-- {{{ debug.error
function debug.error(message, module)
    debug.log("error", message, module)
end
-- }}}

-- {{{ debug.warn
function debug.warn(message, module)
    debug.log("warn", message, module)
end
-- }}}

-- {{{ debug.info
function debug.info(message, module)
    debug.log("info", message, module)
end
-- }}}

-- {{{ debug.debug
function debug.debug(message, module)
    debug.log("debug", message, module)
end
-- }}}

-- {{{ debug.startFrame
function debug.startFrame()
    frameStartTime = love and love.timer and love.timer.getTime() or 0
end
-- }}}

-- {{{ debug.endFrame
function debug.endFrame()
    if debug.show_performance and love and love.timer then
        local frameTime = (love.timer.getTime() - frameStartTime) * 1000
        return frameTime
    end
    return 0
end
-- }}}

-- {{{ debug.drawFPS
function debug.drawFPS(x, y)
    if debug.enabled and debug.show_fps and love and love.graphics and love.timer then
        x = x or 10
        y = y or 10
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("FPS: " .. love.timer.getFPS(), x, y)
        return 15 -- Height used for next element
    end
    return 0
end
-- }}}

-- {{{ debug.drawCoordinates
function debug.drawCoordinates(mouseX, mouseY, x, y)
    if debug.enabled and debug.show_coordinates and love and love.graphics then
        x = x or 10
        y = y or 25
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format("Mouse: %d, %d", mouseX or 0, mouseY or 0), x, y)
        return 15 -- Height used for next element
    end
    return 0
end
-- }}}

-- {{{ debug.drawMemory
function debug.drawMemory(x, y)
    if debug.enabled and debug.show_memory and love and love.graphics then
        x = x or 10
        y = y or 40
        local memKB = collectgarbage("count")
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format("Memory: %.1f KB", memKB), x, y)
        return 15 -- Height used for next element
    end
    return 0
end
-- }}}

-- {{{ debug.drawPerformance
function debug.drawPerformance(frameTime, x, y)
    if debug.enabled and debug.show_performance and frameTime and love and love.graphics then
        x = x or 10
        y = y or 55
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(string.format("Frame: %.2f ms", frameTime), x, y)
        return 15 -- Height used for next element
    end
    return 0
end
-- }}}

-- {{{ debug.drawDebugInfo
function debug.drawDebugInfo(mouseX, mouseY, frameTime)
    if not debug.enabled then return end
    
    local y = 10
    y = y + debug.drawFPS(10, y)
    y = y + debug.drawCoordinates(mouseX, mouseY, 10, y)
    y = y + debug.drawMemory(10, y)
    y = y + debug.drawPerformance(frameTime, 10, y)
end
-- }}}

-- {{{ debug.toggle
function debug.toggle()
    debug.enabled = not debug.enabled
    debug.info("Debug mode: " .. tostring(debug.enabled), "DEBUG")
end
-- }}}

-- {{{ debug.toggleFPS
function debug.toggleFPS()
    debug.show_fps = not debug.show_fps
    debug.info("FPS display: " .. tostring(debug.show_fps), "DEBUG")
end
-- }}}

-- {{{ debug.toggleCoordinates
function debug.toggleCoordinates()
    debug.show_coordinates = not debug.show_coordinates
    debug.info("Coordinates display: " .. tostring(debug.show_coordinates), "DEBUG")
end
-- }}}

-- {{{ debug.toggleMemory
function debug.toggleMemory()
    debug.show_memory = not debug.show_memory
    debug.info("Memory display: " .. tostring(debug.show_memory), "DEBUG")
end
-- }}}

-- {{{ debug.takeScreenshot
function debug.takeScreenshot()
    if not debug.enabled or not love or not love.graphics or not love.filesystem then return end
    
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local filename = "screenshot_" .. timestamp .. ".png"
    local screenshot = love.graphics.newScreenshot()
    local data = screenshot:encode("png")
    
    if love.filesystem.write(filename, data) then
        debug.info("Screenshot saved: " .. filename, "DEBUG")
    else
        debug.error("Failed to save screenshot: " .. filename, "DEBUG")
    end
end
-- }}}

-- {{{ debug.getInfo
function debug.getInfo()
    return {
        enabled = debug.enabled,
        fps = love and love.timer and love.timer.getFPS() or 0,
        memory_kb = collectgarbage("count"),
        version = love and love.getVersion and table.concat({love.getVersion()}, ".") or "unknown",
        platform = love and love.system and love.system.getOS() or "unknown",
        time_running = love and love.timer and (love.timer.getTime() - startTime) or 0
    }
end
-- }}}

return debug
-- }}}