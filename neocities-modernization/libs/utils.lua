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

    -- Issue 10-065: index-based loop, so "--dir PATH" can be consumed as a pair.
    -- Same reasoning as parse_cli_args above: --dir names the ASSETS root and is
    -- read by init_assets_root(); letting its value fall through to the bare-token
    -- branch would set dir_override, which callers assign to the PROJECT root.
    -- Fixed here pre-emptively -- this function has the same shape as the one
    -- that broke stage 3, and nothing currently passes it --dir only by luck.
    args = args or {}
    local i = 1
    while i <= #args do
        local a = args[i]
        if a == "-I" then
            interactive = true
        elseif a == "--dir" then
            i = i + 1  -- skip the flag's value; it is not a project root
        elseif a:match("^%-%-dir=") then
            -- Nothing to skip: the value rides on the same token.
        elseif not a:match("^%-") then
            -- Non-flag argument, treat as directory override
            dir_override = a
        end
        i = i + 1
    end

    return interactive, dir_override
end
-- }}}

-- {{{ function M.parse_cli_args
-- Comprehensive CLI argument parser for main.lua
-- Returns a table with all parsed options for selective stage execution
-- Supports: stage flags (--parse-only, --validate-only, etc.), config (--force, --threads)
-- Phase D (Issue 8-012): Added --pages flag for pagination control
function M.parse_cli_args(args)
    local options = {
        interactive = false,
        dir_override = nil,
        -- Stage flags (when set, only run specified stages)
        parse_only = false,
        validate_only = false,
        catalog_only = false,
        html_only = false,
        -- Config flags
        force = false,
        verbose = false,  -- Issue 10-015a: Verbose output for detailed statistics
        threads = nil,
        pages = nil,  -- Phase D (Issue 8-012): Pagination control ("1", "all", "1-10")
        poems_per_page = nil,  -- Issue 8-022: Poems per page override
        chrono_per_page = nil,  -- Issue 9-003: Chronological poems per page override
        seed = nil,  -- Issue 10-058: build master seed (threaded to randomizers)
    }

    local i = 1
    while i <= #(args or {}) do
        local arg = args[i]

        if arg == "-I" or arg == "--interactive" then
            options.interactive = true
        elseif arg == "--parse-only" then
            options.parse_only = true
        elseif arg == "--validate-only" then
            options.validate_only = true
        elseif arg == "--catalog-only" then
            options.catalog_only = true
        elseif arg == "--html-only" then
            options.html_only = true
        elseif arg == "--force" then
            options.force = true
        elseif arg == "--verbose" or arg == "-v" then
            options.verbose = true
        elseif arg == "--threads" and args[i + 1] then
            options.threads = tonumber(args[i + 1])
            i = i + 1
        elseif arg:match("^--threads=") then
            options.threads = tonumber(arg:match("^--threads=(%d+)"))
        elseif arg == "--pages" and args[i + 1] then
            options.pages = args[i + 1]  -- String value: "1", "all", "1-10"
            i = i + 1
        elseif arg:match("^--pages=") then
            options.pages = arg:match("^--pages=(.+)")  -- String value: "1", "all", "1-10"
        elseif arg == "--poems-per-page" and args[i + 1] then
            options.poems_per_page = tonumber(args[i + 1])  -- Numeric value: 100, 200, etc.
            i = i + 1
        elseif arg:match("^--poems%-per%-page=") then
            options.poems_per_page = tonumber(arg:match("^--poems%-per%-page=(%d+)"))
        elseif arg == "--chrono-per-page" and args[i + 1] then
            options.chrono_per_page = tonumber(args[i + 1])  -- Issue 9-003: Chronological poems per page
            i = i + 1
        elseif arg:match("^--chrono%-per%-page=") then
            options.chrono_per_page = tonumber(arg:match("^--chrono%-per%-page=(%d+)"))
        -- Issue 10-058: consume --seed (both forms) so the bare numeric value is
        -- never swallowed by the dir-override branch below (which would point the
        -- build at a nonexistent directory named after the seed).
        elseif arg == "--seed" and args[i + 1] then
            options.seed = tonumber(args[i + 1])
            i = i + 1
        elseif arg:match("^--seed=") then
            options.seed = tonumber(arg:match("^--seed=(%d+)"))
        -- Issue 10-065: consume "--dir PATH" as a PAIR.
        --
        -- The value is deliberately DISCARDED here. --dir names the ASSETS root
        -- and is read by init_assets_root(), which parses `arg` itself; it must
        -- never become dir_override, which main.lua assigns to DIR -- the
        -- PROJECT root. Those are different directories and conflating them
        -- breaks path resolution downstream.
        --
        -- What went wrong without this: the old comment below said "--dir
        -- handled elsewhere", and the parser did skip the FLAG -- but not its
        -- VALUE. The path then fell through to the bare-token branch and became
        -- dir_override, so main.lua set the project root to the assets
        -- directory. Stage 3 then looked for input/ and compiled.txt underneath
        -- assets/ and reported "No valid input found". Same shape of bug as the
        -- three child parsers fixed alongside this one: skipping a flag is not
        -- the same as skipping a flag and its argument.
        elseif arg == "--dir" then
            i = i + 1
        elseif arg:match("^%-%-dir=") then
            -- Nothing to skip: the value rides on the same token.
        elseif not arg:match("^%-") then
            -- Non-flag argument, treat as directory override (the PROJECT root)
            options.dir_override = arg
        end
        -- Skip remaining unknown flags. A flag that TAKES a value needs its own
        -- branch above, or its value lands in dir_override.

        i = i + 1
    end

    return options
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
    -- Issue 7-003: If path equals base_dir, show project name instead of "./"
    base_dir = base_dir or M.DIR
    if absolute_path == base_dir or absolute_path == base_dir .. "/" then
        -- Return the directory name (e.g., "neocities-modernization/")
        local dir_name = base_dir:match("([^/]+)/?$")
        return dir_name .. "/"
    end
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
-- Issue 10-003: Load asset path configuration from unified config (config.lua)
-- @return: table with assets_root key, or nil if config not found
function M.load_asset_config()
    -- Use config-loader to get asset_paths from unified config
    local ok, config_loader = pcall(require, "config-loader")
    if ok and config_loader then
        config_loader.set_project_root(M.DIR)
        local config = config_loader.load()
        if config and config.asset_paths then
            return config.asset_paths
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
            io.stderr:write("      <model-name>/\n")
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
            io.stderr:write("     or update asset_paths.assets_root in config.lua\n")
            io.stderr:write("\n")
            io.stderr:write("Expected structure:\n")
            io.stderr:write("  " .. config.assets_root .. "/\n")
            io.stderr:write("    poems.json\n")
            io.stderr:write("    embeddings/\n")
            io.stderr:write("      <model-name>/\n")
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
    io.stderr:write("      <model-name>/\n")
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
-- Get path to embeddings directory for the named model, or for the currently
-- configured default model when called with no argument.
--
-- Centralizing the model -> directory mapping here means a model switch in
-- config.lua propagates automatically to every caller, instead of requiring
-- a hunt through ~30 hardcoded "embeddinggemma_latest" string literals.
-- @param model_name: optional. nil means "ask inference-server-config which model is
--                    currently selected and use that"; pass an explicit
--                    string only if you need a different model's directory.
-- @return: full path to that model's embeddings directory
-- WHERE THE CACHES LIVE, and the history of that answer.
--
-- Now: on DISK, under assets/embeddings/<model>/. Both this function and
-- embeddings_dir_disk() resolve there.
--
-- Issue 10-054 moved the movable, regenerable caches into RAM
-- (tmp/shared-memory/, the /dev/shm tier) to spare SSD write endurance, keeping
-- only diversity_cache.json on disk because it is the expensive one to
-- recompute. It removed the earlier CACHE_IN_RAM on/off flag rather than
-- flipping it, on the reasoning that one unconditional location cannot desync
-- the way a half-applied switch had twice before.
--
-- Issue 10-065 (question 10) then found the fact that decision was missing.
-- "RAM until reboot" was not true on this host: elogind runs with RemoveIPC at
-- its default of yes, which deletes every IPC object a user owns -- POSIX shared
-- memory, i.e. the contents of /dev/shm -- when that user's LAST LOGIN SESSION
-- ends. Closing the last terminal is enough. (/tmp is not an IPC object, which
-- is why the exec tier survives when the shared-memory tier does not.)
--
-- Observed: /dev/shm/neocities-modernization was emptied overnight on a machine
-- with two days of uptime, taking a 120 MB embeddings.json with it.
--
-- So the caches were being discarded per SESSION, not per reboot, and the
-- ~20-minute rebuild (per .stage-timings) was being paid that often. Reversed
-- accordingly: see the note on embeddings_dir below.
--
-- The rule is unchanged in shape, only in destination: movable caches ->
-- embeddings_dir(); the one that must never be volatile -> embeddings_dir_disk().
local function safe_model(model_name)
    if not model_name then
        model_name = require("inference-server-config").get_selected_model()
    end
    -- Sanitize model name for filesystem safety (e.g. embeddinggemma:latest -> embeddinggemma_latest)
    return model_name:gsub("[^%w%-_.]", "_")
end

-- REVERSED 2026-08-08 (Issue 10-065, question 11): this returns the DISK path
-- again. It read "M.DIR .. /tmp/shared-memory/cache/embeddings/ .." -- the RAM
-- tier -- from Issue 10-054 until the finding in question 10 undercut the
-- premise that change rested on.
--
-- 10-054 traded durability for SSD write endurance, on the understanding that
-- what it gave up was survival across a REBOOT. That was wrong about this host.
-- elogind runs here with RemoveIPC at its default of yes, so /dev/shm is emptied
-- when the operator's last login session ends -- closing the last terminal is
-- enough. The caches were not surviving until the next reboot; they were
-- surviving until the next logout, and a 20-minute rebuild (per .stage-timings)
-- was being paid per session rather than per reboot. A cache with that lifetime
-- is a per-session scratch buffer, and paying twenty minutes an evening to avoid
-- roughly 4 GB of writes per full regeneration is the wrong side of the trade.
--
-- The reversal is one line ONLY because 10-054 did the hard part: it routed
-- every reader AND every writer of a movable cache through this function (that
-- was the work its own history records as failing twice before it stuck). With
-- one resolution point, moving the tier is changing one return value. The value
-- of that centralization is exactly this -- that the decision it encodes can be
-- revisited cheaply when the facts change.
function M.embeddings_dir(model_name)
    return M.asset_path("embeddings/" .. safe_model(model_name))
end
-- }}}

-- {{{ function M.embeddings_dir_disk
-- The on-DISK embeddings dir (assets/). Kept as a SEPARATE function even though
-- it now returns exactly what embeddings_dir() returns, because the distinction
-- it draws is real and worth keeping legible: its callers
-- (diversity_cache.json, in flat-html-generator, main.lua and
-- pipeline-validator) are the ones that must NEVER be moved to volatile storage,
-- whatever embeddings_dir does next. Collapsing them would erase the record of
-- which caches are cheap to lose and which are not -- and that record is the
-- thing that made the reversal above safe to reason about.
function M.embeddings_dir_disk(model_name)
    return M.asset_path("embeddings/" .. safe_model(model_name))
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
