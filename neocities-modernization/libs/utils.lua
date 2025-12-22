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

-- ============================================================================
-- Asset Path Configuration
-- Configurable storage for generated assets (embeddings, poems.json, etc.)
-- ============================================================================

-- Module state for cached asset configuration
local _assets_root = nil
local _assets_config_loaded = false

-- {{{ function M.parse_assets_dir
-- Parse --dir flag from command line arguments
-- @param args: table of command line arguments (default: global 'arg')
-- @return: string path if --dir found, nil otherwise
function M.parse_assets_dir(args)
    args = args or arg
    if not args then return nil end

    local i = 1
    while i <= #args do
        local arg_val = args[i]
        if arg_val == "--dir" and args[i + 1] then
            return args[i + 1]
        elseif arg_val:match("^%-%-dir=") then
            return arg_val:match("^%-%-dir=(.+)$")
        end
        i = i + 1
    end
    return nil
end
-- }}}

-- {{{ function M.load_asset_config
-- Load asset path configuration from config/asset-paths.lua
-- @return: table with assets_root key, or nil if file not found
function M.load_asset_config()
    local config_path = M.DIR .. "/config/asset-paths.lua"
    local config_func = loadfile(config_path)
    if config_func then
        local ok, config = pcall(config_func)
        if ok and type(config) == "table" then
            return config
        end
    end
    return nil
end
-- }}}

-- {{{ function M.init_assets_root
-- Initialize assets root path with priority: CLI > config > error
-- Must be called once at startup, before any asset_path() calls
-- @param cli_args: optional table of CLI arguments (default: global 'arg')
-- @return: string path to assets root, or nil on error (after printing message)
function M.init_assets_root(cli_args)
    -- Check CLI argument first (highest priority)
    local cli_dir = M.parse_assets_dir(cli_args)
    if cli_dir then
        if not M.directory_exists(cli_dir) then
            io.stderr:write("\n")
            io.stderr:write("Error: Assets directory not found: " .. cli_dir .. "\n")
            io.stderr:write("\n")
            io.stderr:write("Fix: supply valid path via --dir ~/your/assets/path\n")
            io.stderr:write("\n")
            io.stderr:write("Expected structure:\n")
            io.stderr:write("  " .. cli_dir .. "/\n")
            io.stderr:write("    poems.json\n")
            io.stderr:write("    embeddings/\n")
            io.stderr:write("      EmbeddingGemma_latest/\n")
            io.stderr:write("        embeddings.json\n")
            io.stderr:write("\n")
            return nil
        end
        _assets_root = cli_dir
        _assets_config_loaded = true
        return _assets_root
    end

    -- Try config file (second priority)
    local config = M.load_asset_config()
    if config and config.assets_root then
        if not M.directory_exists(config.assets_root) then
            io.stderr:write("\n")
            io.stderr:write("Error: Assets directory not found: " .. config.assets_root .. "\n")
            io.stderr:write("\n")
            io.stderr:write("Fix: supply path via --dir ~/your/assets/path\n")
            io.stderr:write("     or update config/asset-paths.lua\n")
            io.stderr:write("\n")
            io.stderr:write("Expected structure:\n")
            io.stderr:write("  " .. config.assets_root .. "/\n")
            io.stderr:write("    poems.json\n")
            io.stderr:write("    embeddings/\n")
            io.stderr:write("      EmbeddingGemma_latest/\n")
            io.stderr:write("        embeddings.json\n")
            io.stderr:write("\n")
            return nil
        end
        _assets_root = config.assets_root
        _assets_config_loaded = true
        return _assets_root
    end

    -- Fallback to project default (for backward compatibility during transition)
    local default_path = M.DIR .. "/assets"
    if M.directory_exists(default_path) then
        _assets_root = default_path
        _assets_config_loaded = true
        return _assets_root
    end

    -- Nothing found - error
    io.stderr:write("\n")
    io.stderr:write("Error: Assets directory not found\n")
    io.stderr:write("\n")
    io.stderr:write("Fix: supply path via --dir ~/your/assets/path\n")
    io.stderr:write("\n")
    io.stderr:write("Expected structure:\n")
    io.stderr:write("  ~/your/assets/path/\n")
    io.stderr:write("    poems.json\n")
    io.stderr:write("    embeddings/\n")
    io.stderr:write("      EmbeddingGemma_latest/\n")
    io.stderr:write("        embeddings.json\n")
    io.stderr:write("\n")
    return nil
end
-- }}}

-- {{{ function M.get_assets_root
-- Get the configured assets root path
-- Initializes from config if not already done
-- @param cli_args: optional CLI args for initialization
-- @return: string path to assets root
function M.get_assets_root(cli_args)
    if not _assets_config_loaded then
        local result = M.init_assets_root(cli_args)
        if not result then
            os.exit(1)
        end
    end
    return _assets_root
end
-- }}}

-- {{{ function M.asset_path
-- Build full path to an asset file
-- @param relative: relative path within assets (e.g., "poems.json")
-- @return: full absolute path
function M.asset_path(relative)
    return M.get_assets_root() .. "/" .. relative
end
-- }}}

-- {{{ function M.embeddings_dir
-- Get path to embeddings directory for a specific model
-- @param model_name: optional model name (default: "EmbeddingGemma_latest")
-- @return: full path to model's embeddings directory
function M.embeddings_dir(model_name)
    model_name = model_name or "EmbeddingGemma_latest"
    -- Sanitize model name for filesystem safety
    local safe_name = model_name:gsub("[^%w%-_.]", "_")
    return M.asset_path("embeddings/" .. safe_name)
end
-- }}}

-- {{{ function M.similarities_dir
-- Get path to similarities directory for a specific model
-- @param model_name: optional model name
-- @return: full path to model's similarities directory
function M.similarities_dir(model_name)
    return M.embeddings_dir(model_name) .. "/similarities"
end
-- }}}

return M