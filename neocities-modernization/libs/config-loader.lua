-- {{{ libs/config-loader.lua
-- Issue 10-003: Utility module to load and cache the consolidated config
-- This module provides a single entry point to access all project configuration.
-- The config is loaded once and cached for subsequent requires.
--
-- Usage:
--   local config = require("config-loader")
--   local assets_root = config.asset_paths.assets_root
--   local colors = config.semantic_colors
--
-- If scripts need to override config location:
--   local config_loader = require("config-loader")
--   config_loader.set_config_path("/custom/path/to/config.lua")
--   local config = config_loader.load()
-- }}}

local M = {}

-- {{{ Configuration
-- Default config path (relative to project root)
local DEFAULT_CONFIG_PATH = "config/main.lua"

-- Cached config table (loaded once per session)
local cached_config = nil

-- Custom config path override
local custom_config_path = nil

-- Project root detection (for relative paths)
local project_root = nil
-- }}}

-- {{{ local function detect_project_root
-- Detect project root by looking for known marker files
local function detect_project_root()
    -- Try to find project root from current script location
    local script_path = debug.getinfo(1, "S").source:sub(2)  -- Remove @ prefix

    -- If script is in libs/, go up one level
    if script_path:match("/libs/") then
        project_root = script_path:match("(.+)/libs/")
    elseif script_path:match("\\libs\\") then
        -- Windows path
        project_root = script_path:match("(.+)\\libs\\")
    end

    -- Fallback: check known project directory
    if not project_root then
        local known_paths = {
            "/mnt/mtwo/programming/ai-stuff/neocities-modernization",
            "/home/ritz/programming/ai-stuff/neocities-modernization"
        }
        for _, path in ipairs(known_paths) do
            local f = io.open(path .. "/config/main.lua", "r")
            if f then
                f:close()
                project_root = path
                break
            end
        end
    end

    return project_root
end
-- }}}

-- {{{ local function resolve_path
-- Resolve a config path to absolute path
local function resolve_path(path)
    -- If already absolute, return as-is
    if path:match("^/") or path:match("^%a:") then
        return path
    end

    -- Resolve relative to project root
    local root = project_root or detect_project_root()
    if root then
        return root .. "/" .. path
    end

    -- Fallback: return relative path and hope for the best
    return path
end
-- }}}

-- {{{ function M.set_project_root
-- Override the detected project root
function M.set_project_root(path)
    project_root = path
    -- Clear cache to force reload from new location
    cached_config = nil
end
-- }}}

-- {{{ function M.set_config_path
-- Override the default config path
function M.set_config_path(path)
    custom_config_path = path
    -- Clear cache to force reload from new path
    cached_config = nil
end
-- }}}

-- {{{ function M.load
-- Load (or return cached) configuration
function M.load()
    -- Return cached config if available
    if cached_config then
        return cached_config
    end

    -- Determine config path
    local config_path = custom_config_path or DEFAULT_CONFIG_PATH
    local absolute_path = resolve_path(config_path)

    -- Load config file
    local chunk, err = loadfile(absolute_path)
    if not chunk then
        error(string.format(
            "config-loader: Failed to load config from %s: %s",
            absolute_path, err or "unknown error"
        ))
    end

    -- Execute and cache
    local ok, result = pcall(chunk)
    if not ok then
        error(string.format(
            "config-loader: Error executing config %s: %s",
            absolute_path, result or "unknown error"
        ))
    end

    -- Validate result is a table
    if type(result) ~= "table" then
        error(string.format(
            "config-loader: Config file must return a table, got %s",
            type(result)
        ))
    end

    cached_config = result
    return cached_config
end
-- }}}

-- {{{ function M.reload
-- Force reload configuration (useful for testing or hot-reload scenarios)
function M.reload()
    cached_config = nil
    return M.load()
end
-- }}}

-- {{{ function M.get
-- Get a specific config section or value by dot-notation path
-- Example: config_loader.get("asset_paths.assets_root")
function M.get(path)
    local config = M.load()

    if not path or path == "" then
        return config
    end

    local current = config
    for segment in path:gmatch("[^%.]+") do
        if type(current) ~= "table" then
            return nil
        end
        current = current[segment]
    end

    return current
end
-- }}}

-- {{{ Metatable for direct table access
-- Allow using the module directly as a config table:
--   local config = require("config-loader")
--   local value = config.asset_paths.assets_root
setmetatable(M, {
    __index = function(_, key)
        local config = M.load()
        return config[key]
    end,
    __pairs = function(_)
        local config = M.load()
        return pairs(config)
    end,
    __ipairs = function(_)
        local config = M.load()
        return ipairs(config)
    end
})
-- }}}

return M
