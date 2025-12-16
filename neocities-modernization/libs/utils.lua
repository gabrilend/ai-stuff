#!/usr/bin/env lua

-- Project-wide utility library
-- Common functions for file I/O, logging, and configuration management

local M = {}

-- {{{ local function setup_dir_path
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

-- Module configuration
M.DIR = setup_dir_path()

-- {{{ function M.log_info
function M.log_info(message)
    print(string.format("[INFO] %s", message))
end
-- }}}

-- {{{ function M.log_warn
function M.log_warn(message)
    print(string.format("[WARN] %s", message))
end
-- }}}

-- {{{ function M.log_error
function M.log_error(message)
    print(string.format("[ERROR] %s", message))
end
-- }}}

-- {{{ function M.file_exists
function M.file_exists(filepath)
    local file = io.open(filepath, "r")
    if file then
        file:close()
        return true
    end
    return false
end
-- }}}

-- {{{ function M.read_file
function M.read_file(filepath)
    local file = io.open(filepath, "r")
    if not file then
        return nil, "Could not open file: " .. filepath
    end
    
    local content = file:read("*all")
    file:close()
    return content
end
-- }}}

-- {{{ function M.write_file
function M.write_file(filepath, content)
    local file = io.open(filepath, "w")
    if not file then
        return false, "Could not create file: " .. filepath
    end
    
    file:write(content)
    file:close()
    return true
end
-- }}}

-- {{{ function M.get_timestamp
function M.get_timestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end
-- }}}

-- {{{ function M.ensure_directory
function M.ensure_directory(dirpath)
    local cmd = "mkdir -p " .. dirpath
    local result = os.execute(cmd)
    return result == 0 or result == true
end
-- }}}

-- {{{ function M.get_project_paths
function M.get_project_paths(base_dir)
    base_dir = base_dir or M.DIR
    return {
        root = base_dir,
        src = base_dir .. "/src",
        libs = base_dir .. "/libs", 
        assets = base_dir .. "/assets",
        docs = base_dir .. "/docs",
        notes = base_dir .. "/notes",
        issues = base_dir .. "/issues"
    }
end
-- }}}

-- {{{ function M.parse_interactive_args
function M.parse_interactive_args(args)
    local interactive = false
    local dir_override = nil
    
    for i, arg in ipairs(args or {}) do
        if arg == "-I" then
            interactive = true
        elseif not arg:match("^%-") then
            -- Non-flag argument, treat as directory override
            dir_override = arg
        end
    end
    
    return interactive, dir_override
end
-- }}}

-- {{{ function M.show_menu
function M.show_menu(title, options)
    print("\n=== " .. title .. " ===")
    for i, option in ipairs(options) do
        print(string.format("%d. %s", i, option))
    end
    io.write("Select option (1-" .. #options .. "): ")
    local choice = tonumber(io.read())
    
    if choice and choice >= 1 and choice <= #options then
        return choice
    else
        print("Invalid choice")
        return nil
    end
end
-- }}}

-- {{{ function M.confirm_action
function M.confirm_action(message)
    io.write(message .. " (y/N): ")
    local response = io.read():lower()
    return response == "y" or response == "yes"
end
-- }}}

-- {{{ function M.read_json_file
function M.read_json_file(filepath)
    package.path = M.DIR .. "/libs/?.lua;" .. package.path
    local dkjson = require("dkjson")
    local content = M.read_file(filepath)
    if content then
        local data, pos, err = dkjson.decode(content, 1, nil)
        if err then
            M.log_error("JSON decode error in " .. filepath .. ": " .. err)
            return nil
        end
        return data
    end
    return nil
end
-- }}}

-- {{{ function M.write_json_file
function M.write_json_file(filepath, data)
    package.path = M.DIR .. "/libs/?.lua;" .. package.path
    local dkjson = require("dkjson")
    local json_string = dkjson.encode(data, { indent = true })
    if json_string then
        return M.write_file(filepath, json_string)
    else
        M.log_error("Failed to encode JSON data for " .. filepath)
        return false
    end
end
-- }}}

-- {{{ function M.directory_exists
function M.directory_exists(dirpath)
    local cmd = "[ -d '" .. dirpath .. "' ]"
    local result = os.execute(cmd)
    return result == 0 or result == true
end
-- }}}

-- {{{ function M.get_file_mtime
function M.get_file_mtime(filepath)
    local stat_cmd = string.format("stat -c %%Y '%s' 2>/dev/null", filepath)
    local handle = io.popen(stat_cmd)
    if handle then
        local result = handle:read("*a")
        handle:close()
        if result and result ~= "" then
            local clean_result = result:gsub("%s+", "")
            local timestamp = tonumber(clean_result)
            return timestamp
        end
    end
    return nil
end
-- }}}

-- {{{ function M.get_working_directory
function M.get_working_directory()
    local handle = io.popen("pwd")
    if handle then
        local result = handle:read("*l")
        handle:close()
        return result or M.DIR
    end
    return M.DIR
end
-- }}}

-- {{{ function M.relative_path
function M.relative_path(absolute_path, base_dir)
    -- Convert absolute path to relative path for cleaner output
    -- If path starts with base_dir, replace with "./"
    base_dir = base_dir or M.DIR
    if absolute_path:sub(1, #base_dir) == base_dir then
        local relative = absolute_path:sub(#base_dir + 1)
        if relative:sub(1, 1) == "/" then
            relative = relative:sub(2)
        end
        return "./" .. relative
    end
    return absolute_path
end
-- }}}

return M