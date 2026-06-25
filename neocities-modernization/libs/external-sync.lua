-- {{{ external-sync.lua
-- Issue 10-003b: Centralized external file syncing module
-- Issue 10-026: Now reads from sources-loader (unified config)
--
-- Reads external sync info from config.sources via sources-loader.
-- Falls back to config.external_files for backward compatibility.
--
-- All external file pulling should go through this module.
-- No hardcoded external paths should exist in scripts.
--
-- Usage:
--   local sync = require("external-sync")
--   sync.set_project_root("/path/to/project")
--   sync.sync_all()                  -- Sync all sources
--   sync.sync_by_name("bluesky-car") -- Sync specific source
--   sync.list_sources()              -- List configured sources
-- }}}

local M = {}

-- {{{ Module state
local project_root = nil
local config = nil
local verbose = true
local sources_loader = nil  -- Issue 10-026: lazy-loaded sources-loader
-- }}}

-- {{{ ANSI color codes for terminal output
local COLOR_GREEN = "\027[92m"
local COLOR_BLUE = "\027[94m"
local COLOR_RED = "\027[91m"
local COLOR_YELLOW = "\027[93m"
local COLOR_RESET = "\027[0m"
-- }}}

-- {{{ set_project_root
-- Set the project root directory (required before any operations)
function M.set_project_root(path)
    project_root = path
    config = nil  -- Reset config when root changes
    -- Issue 10-026: Also initialize sources-loader
    if not sources_loader then
        local ok, loader = pcall(require, "sources-loader")
        if ok then
            sources_loader = loader
        end
    end
    if sources_loader then
        sources_loader.set_project_root(path)
    end
end
-- }}}

-- {{{ set_verbose
-- Enable or disable verbose output
function M.set_verbose(enabled)
    verbose = enabled
end
-- }}}

-- {{{ local function log
-- Print a message if verbose mode is enabled
local function log(msg)
    if verbose then
        print(msg)
    end
end
-- }}}

-- {{{ local function log_success
local function log_success(msg)
    if verbose then
        print(COLOR_GREEN .. msg .. COLOR_RESET)
    end
end
-- }}}

-- {{{ local function log_error
local function log_error(msg)
    io.stderr:write(COLOR_RED .. msg .. COLOR_RESET .. "\n")
end
-- }}}

-- {{{ local function log_warning
local function log_warning(msg)
    if verbose then
        print(COLOR_YELLOW .. msg .. COLOR_RESET)
    end
end
-- }}}

-- {{{ local function load_config
-- Load config.lua if not already loaded
local function load_config()
    if config then
        return config
    end

    if not project_root then
        error("external-sync: project_root not set. Call set_project_root() first.")
    end

    local config_path = project_root .. "/config.lua"
    local ok, result = pcall(dofile, config_path)
    if not ok then
        error("external-sync: Failed to load config.lua: " .. tostring(result))
    end

    config = result
    return config
end
-- }}}

-- {{{ local function get_external_files
-- Issue 10-026: Get external sync entries, preferring sources-loader
-- Falls back to config.external_files for backward compatibility
local function get_external_files()
    -- Try sources-loader first (unified config)
    if sources_loader then
        local syncs = sources_loader.get_all_external_syncs()
        if #syncs > 0 then
            return syncs
        end
    end

    -- Fall back to legacy external_files section
    local cfg = load_config()
    local legacy = cfg.external_files or {}
    -- Add is_archive field for compatibility (detect by .zip extension)
    for _, entry in ipairs(legacy) do
        if entry.is_archive == nil then
            entry.is_archive = entry.source and entry.source:match("%.zip$") ~= nil
        end
    end
    return legacy
end
-- }}}

-- {{{ local function path_exists
-- Check if a path exists (file or directory)
local function path_exists(path)
    local handle = io.popen("test -e '" .. path .. "' && echo yes || echo no")
    local result = handle:read("*l")
    handle:close()
    return result == "yes"
end
-- }}}

-- {{{ local function is_directory
-- Check if a path is a directory (vs a file)
local function is_directory(path)
    local handle = io.popen("test -d '" .. path .. "' && echo yes || echo no")
    local result = handle:read("*l")
    handle:close()
    return result == "yes"
end
-- }}}

-- {{{ local function count_files
-- Count files in a directory (returns 1 for a single file)
local function count_files(path)
    if not path_exists(path) then
        return 0
    end
    if not is_directory(path) then
        return 1  -- Single file
    end
    local handle = io.popen("find '" .. path .. "' -type f 2>/dev/null | wc -l")
    local result = handle:read("*l")
    handle:close()
    return tonumber(result) or 0
end
-- }}}

-- {{{ local function run_rsync
-- Run rsync to sync source to destination
-- Handles both files and directories
-- Returns: success (bool), files_synced (number)
local function run_rsync(source_path, dest_path, options)
    options = options or {}

    -- Build rsync command
    local rsync_opts = "-a"  -- Archive mode (preserves permissions, timestamps, etc.)

    if not options.overwrite then
        rsync_opts = rsync_opts .. " --ignore-existing"
    end

    -- Ensure destination directory exists
    os.execute("mkdir -p '" .. dest_path .. "'")

    -- Count files before
    local before_count = count_files(dest_path)

    local cmd
    if is_directory(source_path) then
        -- Directory: trailing slash on source means "contents of"
        cmd = string.format("rsync %s '%s/' '%s/' 2>/dev/null",
            rsync_opts, source_path, dest_path)
    else
        -- File: copy file into destination directory (no trailing slash on source)
        cmd = string.format("rsync %s '%s' '%s/' 2>/dev/null",
            rsync_opts, source_path, dest_path)
    end
    local result = os.execute(cmd)

    -- Count files after
    local after_count = count_files(dest_path)
    local files_synced = after_count - before_count

    -- os.execute returns different values in different Lua versions
    local success = (result == 0) or (result == true)

    return success, files_synced
end
-- }}}

-- {{{ sync_source
-- Sync a single external source entry
-- Returns: { success = bool, name = string, files_synced = number, message = string }
function M.sync_source(source_entry)
    if not project_root then
        error("external-sync: project_root not set. Call set_project_root() first.")
    end

    local name = source_entry.name or "unnamed"
    local source_path = source_entry.source
    local destination = source_entry.destination

    -- Validate required fields
    if not source_path then
        return {
            success = false,
            name = name,
            files_synced = 0,
            message = "Missing 'source' field"
        }
    end

    -- destination can be empty string "" (meaning input/ root), but not nil
    if destination == nil then
        return {
            success = false,
            name = name,
            files_synced = 0,
            message = "Missing 'destination' field"
        }
    end

    -- Build full destination path (relative to input/)
    -- Empty destination "" means input/ directory itself
    local full_dest = project_root .. "/input"
    if destination ~= "" then
        full_dest = full_dest .. "/" .. destination
    end

    -- Every external source is mandatory (the "optional" concept was removed): a
    -- missing source is a hard failure so we notice and fix it, rather than quietly
    -- shipping without that data.
    if not path_exists(source_path) then
        return {
            success = false,
            name = name,
            files_synced = 0,
            message = "Required source not found: " .. source_path
        }
    end

    -- Run rsync
    local success, files_synced = run_rsync(source_path, full_dest, {
        overwrite = false  -- Don't overwrite existing files
    })

    if success then
        return {
            success = true,
            name = name,
            files_synced = files_synced,
            message = files_synced > 0
                and string.format("Synced %d new files", files_synced)
                or "Up to date"
        }
    else
        return {
            success = false,
            name = name,
            files_synced = 0,
            message = "rsync failed"
        }
    end
end
-- }}}

-- {{{ sync_by_name
-- Sync a specific source by name
-- Returns: result table or nil if not found
function M.sync_by_name(name)
    local sources = get_external_files()

    for _, source in ipairs(sources) do
        if source.name == name then
            local result = M.sync_source(source)

            -- Log result
            if result.success then
                if result.skipped then
                    log_warning("⚠️  " .. name .. ": " .. result.message)
                else
                    log_success("✅ " .. name .. ": " .. result.message)
                end
            else
                log_error("❌ " .. name .. ": " .. result.message)
            end

            return result
        end
    end

    log_error("❌ Source not found: " .. name)
    return nil
end
-- }}}

-- {{{ sync_all
-- Sync all configured external sources
-- Returns: { total = n, synced = n, skipped = n, failed = n, results = {} }
function M.sync_all()
    local sources = get_external_files()
    local results = {
        total = #sources,
        synced = 0,
        skipped = 0,
        failed = 0,
        results = {}
    }

    if #sources == 0 then
        log("📁 No external sources configured")
        return results
    end

    log("📁 Syncing " .. #sources .. " external sources...")

    for _, source in ipairs(sources) do
        local result = M.sync_source(source)
        table.insert(results.results, result)

        if result.success then
            if result.skipped then
                results.skipped = results.skipped + 1
                log_warning("   ⚠️  " .. result.name .. ": " .. result.message)
            else
                results.synced = results.synced + 1
                log_success("   ✅ " .. result.name .. ": " .. result.message)
            end
        else
            results.failed = results.failed + 1
            log_error("   ❌ " .. result.name .. ": " .. result.message)
        end
    end

    -- Summary
    if results.failed > 0 then
        log_error(string.format("📁 Sync complete: %d synced, %d skipped, %d FAILED",
            results.synced, results.skipped, results.failed))
    else
        log_success(string.format("📁 Sync complete: %d synced, %d skipped",
            results.synced, results.skipped))
    end

    return results
end
-- }}}

-- {{{ list_sources
-- List all configured external sources
-- Returns: array of { name, source, destination }
function M.list_sources()
    local sources = get_external_files()
    local list = {}

    for _, source in ipairs(sources) do
        table.insert(list, {
            name = source.name or "unnamed",
            source = source.source or "",
            destination = source.destination or ""
        })
    end

    return list
end
-- }}}

-- {{{ print_sources
-- Print a formatted list of configured sources
function M.print_sources()
    local sources = M.list_sources()

    if #sources == 0 then
        print("No external sources configured")
        return
    end

    print("External sources (" .. #sources .. "):")
    print(string.rep("-", 70))

    for _, source in ipairs(sources) do
        print(string.format("  %s", source.name))
        print(string.format("    FROM: %s", source.source))
        -- Show "input/" for empty destination, otherwise "input/{dest}"
        local dest_display = source.destination == "" and "input/" or ("input/" .. source.destination)
        print(string.format("    TO:   %s", dest_display))
    end
end
-- }}}

-- {{{ has_failures
-- Check if sync_all result has any failures (for exit code)
function M.has_failures(results)
    return results.failed > 0
end
-- }}}

return M
