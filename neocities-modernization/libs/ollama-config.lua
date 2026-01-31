-- {{{ ollama-config.lua
-- Issue 10-017: Ollama server configuration loader.
-- Reads server definitions from config.lua and provides API for server selection.
--
-- Usage:
--   local ollama = require("ollama-config")
--   ollama.set_project_root("/path/to/project")  -- Required before other calls
--
--   -- Get servers
--   local servers = ollama.get_servers()
--   local server = ollama.get_server_by_name("gpu-server")
--   local default = ollama.get_default_server()
--
--   -- Build URL
--   local url = ollama.build_host_url(server)  -- "http://192.168.0.115:10265"
--
--   -- Validate connection
--   local ok, msg = ollama.validate_server(server)
-- }}}

local M = {}

-- {{{ Module state
local project_root = nil
local config = nil
local selected_server = nil  -- CLI override
local selected_model = nil   -- CLI override
-- }}}

-- {{{ set_project_root
-- Set the project root directory (required before loading config)
function M.set_project_root(path)
    project_root = path
    config = nil  -- Reset config when root changes
end
-- }}}

-- {{{ local function load_config
-- Load config.lua if not already loaded
local function load_config()
    if config then
        return config
    end

    if not project_root then
        -- Try to detect from package.path
        local path = package.path:match("([^;]+)/libs/%?%.lua")
        if path then
            project_root = path
        else
            -- Fallback default
            project_root = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
        end
    end

    local config_path = project_root .. "/config.lua"
    local ok, result = pcall(dofile, config_path)
    if not ok then
        -- Config not available, use empty
        config = {}
        return config
    end

    config = result
    return config
end
-- }}}

-- {{{ get_servers
-- Get all configured Ollama servers
-- Returns array of server objects, or default fallback if none configured
function M.get_servers()
    local cfg = load_config()
    local servers = cfg.ollama_servers

    if servers and #servers > 0 then
        return servers
    end

    -- Fallback default if no servers configured
    return {
        {
            name = "local",
            description = "Local Ollama instance (fallback)",
            host = "localhost",
            port = 11434,
            model = "nomic-embed-text"
        }
    }
end
-- }}}

-- {{{ get_server_by_name
-- Get a specific server by name
-- Returns server object or nil if not found
function M.get_server_by_name(name)
    if not name then return nil end

    for _, server in ipairs(M.get_servers()) do
        if server.name == name then
            return server
        end
    end

    return nil
end
-- }}}

-- {{{ get_default_server
-- Get the default server (from config or first in list)
function M.get_default_server()
    local cfg = load_config()

    -- Check for configured default
    if cfg.default_ollama_server then
        local server = M.get_server_by_name(cfg.default_ollama_server)
        if server then
            return server
        end
    end

    -- Fall back to first server in list
    local servers = M.get_servers()
    return servers[1]
end
-- }}}

-- {{{ get_selected_server
-- Get the currently selected server (CLI override > default)
function M.get_selected_server()
    if selected_server then
        local server = M.get_server_by_name(selected_server)
        if server then
            return server
        end
        -- Warning: selected server not found, fall through to default
        io.stderr:write("Warning: Ollama server '" .. selected_server .. "' not found, using default\n")
    end

    return M.get_default_server()
end
-- }}}

-- {{{ set_selected_server
-- Set the selected server name (from CLI --ollama flag)
function M.set_selected_server(name)
    selected_server = name
end
-- }}}

-- {{{ get_selected_model
-- Get the currently selected model (CLI override > server default)
function M.get_selected_model()
    if selected_model then
        return selected_model
    end

    local server = M.get_selected_server()
    return server and server.model or "nomic-embed-text"
end
-- }}}

-- {{{ set_selected_model
-- Set the selected model (from CLI --model flag)
function M.set_selected_model(model)
    selected_model = model
end
-- }}}

-- {{{ build_host_url
-- Build the full URL for a server
-- Returns URL string like "http://192.168.0.115:10265"
function M.build_host_url(server)
    if not server then
        server = M.get_selected_server()
    end

    local host = server.host or "localhost"
    local port = server.port or 11434

    return string.format("http://%s:%d", host, port)
end
-- }}}

-- {{{ validate_server
-- Check if a server is reachable
-- Returns: success (bool), message (string)
function M.validate_server(server)
    if not server then
        server = M.get_selected_server()
    end

    local url = M.build_host_url(server) .. "/api/tags"
    local cmd = string.format("curl -s -o /dev/null -w '%%{http_code}' --max-time 3 '%s' 2>/dev/null", url)

    local handle = io.popen(cmd)
    local status = handle:read("*a")
    handle:close()

    status = status:gsub("%s+", "")  -- Trim whitespace

    if status == "200" then
        return true, "Server is reachable"
    elseif status == "000" then
        return false, "Connection timeout - server unreachable"
    else
        return false, "Server returned HTTP " .. status
    end
end
-- }}}

-- {{{ list_servers
-- Print a formatted list of available servers
function M.list_servers()
    local servers = M.get_servers()
    local default = M.get_default_server()

    print("Available Ollama servers:")
    print(string.rep("-", 70))

    for _, server in ipairs(servers) do
        local is_default = (server.name == default.name)
        local default_marker = is_default and " (default)" or ""
        local url = M.build_host_url(server)

        print(string.format("  %s%s", server.name, default_marker))
        print(string.format("    %s", server.description or ""))
        print(string.format("    URL: %s", url))
        print(string.format("    Model: %s", server.model or "nomic-embed-text"))

        if server.available_models and #server.available_models > 0 then
            print(string.format("    Available models: %s", table.concat(server.available_models, ", ")))
        end
        print("")
    end
end
-- }}}

return M
