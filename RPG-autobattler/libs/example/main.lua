-- Example Love2D project using the installed libraries
-- This demonstrates how to properly load and use LuaSocket and dkjson

-- Libraries are automatically loaded when using run-local-love.sh
-- If running with system Love2D, uncomment and modify the paths below:
--[[
local libs_path = "../"
package.path = libs_path .. "luasocket/?.lua;" .. 
               libs_path .. "luasocket/socket/?.lua;" .. 
               libs_path .. "dkjson/?.lua;" .. 
               package.path

package.cpath = libs_path .. "luasocket/?.so;" .. 
                libs_path .. "luasocket/socket/?.so;" .. 
                libs_path .. "luasocket/mime/?.so;" .. 
                package.cpath
--]]

-- Load the libraries
local socket = require("socket")
local json = require("dkjson")

-- Game state
local game_state = {
    message = "Libraries loaded successfully!",
    socket_info = "",
    json_test = "",
    time_elapsed = 0
}

function love.load()
    love.window.setTitle("RPG-Autobattler Library Test")
    
    -- Test LuaSocket
    local tcp_socket = socket.tcp()
    if tcp_socket then
        game_state.socket_info = "LuaSocket " .. socket._VERSION .. " - TCP socket created successfully"
        tcp_socket:close()
    else
        game_state.socket_info = "LuaSocket failed to create TCP socket"
    end
    
    -- Test dkjson
    local test_data = {
        game = "RPG-Autobattler",
        libraries = {"Love2D", "LuaSocket", "dkjson"},
        status = "ready",
        timestamp = os.time()
    }
    
    local json_string = json.encode(test_data)
    local decoded_data = json.decode(json_string)
    
    if decoded_data and decoded_data.game == "RPG-Autobattler" then
        game_state.json_test = "dkjson encoding/decoding successful"
    else
        game_state.json_test = "dkjson test failed"
    end
end

function love.update(dt)
    game_state.time_elapsed = game_state.time_elapsed + dt
end

function love.draw()
    love.graphics.setColor(1, 1, 1)  -- White text
    
    -- Draw title
    love.graphics.print("RPG-Autobattler Library Test", 20, 20)
    
    -- Draw library status
    love.graphics.print("Status:", 20, 60)
    love.graphics.print(game_state.message, 20, 80)
    
    -- Draw LuaSocket info
    love.graphics.print("LuaSocket:", 20, 120)
    love.graphics.print(game_state.socket_info, 20, 140)
    
    -- Draw dkjson info
    love.graphics.print("dkjson:", 20, 180)
    love.graphics.print(game_state.json_test, 20, 200)
    
    -- Draw runtime info
    love.graphics.print("Time elapsed: " .. string.format("%.1f", game_state.time_elapsed) .. "s", 20, 240)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 20, 260)
    
    -- Draw instructions
    love.graphics.print("Press SPACE to test socket creation", 20, 300)
    love.graphics.print("Press J to test JSON encoding", 20, 320)
    love.graphics.print("Press ESCAPE to quit", 20, 340)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "space" then
        -- Test socket creation
        local tcp = socket.tcp()
        local udp = socket.udp()
        if tcp and udp then
            game_state.socket_info = "Fresh sockets created at " .. string.format("%.1f", game_state.time_elapsed) .. "s"
            tcp:close()
            udp:close()
        else
            game_state.socket_info = "Socket creation failed"
        end
    elseif key == "j" then
        -- Test JSON encoding with current time
        local test_data = {
            action = "key_pressed",
            key = "j",
            time = game_state.time_elapsed,
            random = math.random(1000)
        }
        local encoded = json.encode(test_data)
        local decoded = json.decode(encoded)
        if decoded and decoded.action == "key_pressed" then
            game_state.json_test = "JSON test at " .. string.format("%.1f", decoded.time) .. "s (random: " .. decoded.random .. ")"
        else
            game_state.json_test = "JSON encoding failed"
        end
    end
end