#!/usr/bin/env luajit
-- menu-runner.lua - Standalone menu runner for bash integration
-- Reads JSON config from file (passed as argument), runs interactive menu.
-- Usage: luajit menu-runner.lua /path/to/config.json

-- Add current directory and shared libs to package path
local script_path = arg[0]:match("(.*/)")
if script_path then
    package.path = script_path .. "?.lua;" .. package.path
end
-- Add ai-stuff/libs/lua for dkjson
package.path = "/home/ritz/programming/ai-stuff/libs/lua/?.lua;" .. package.path

local json = require("dkjson")
local menu = require("menu")

-- {{{ Main
local function main()
    -- Get config file path from command line
    local config_file = arg[1]
    if not config_file then
        io.stderr:write("Usage: luajit menu-runner.lua <config.json>\n")
        os.exit(1)
    end

    -- Read JSON config from file
    local f = io.open(config_file, "r")
    if not f then
        io.stderr:write("Error: Cannot open config file: " .. config_file .. "\n")
        os.exit(1)
    end
    local input = f:read("*a")
    f:close()

    if not input or input == "" then
        io.stderr:write("Error: Empty config file\n")
        os.exit(1)
    end

    -- Parse JSON
    local ok, config = pcall(json.decode, input)
    if not ok then
        io.stderr:write("Error parsing JSON: " .. tostring(config) .. "\n")
        os.exit(1)
    end

    -- Initialize and run menu
    local success, err = pcall(function()
        menu.init(config)
        local action, values = menu.run()
        menu.cleanup()

        -- Output results as JSON
        local result = {
            action = action,
            values = values
        }
        print(json.encode(result))
    end)

    if not success then
        -- Make sure to cleanup terminal even on error
        pcall(menu.cleanup)
        io.stderr:write("Error: " .. tostring(err) .. "\n")
        os.exit(1)
    end
end
-- }}}

main()
