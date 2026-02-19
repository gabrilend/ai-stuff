-- {{{ sources-loader.lua
-- Issue 10-015: Unified input sources configuration loader
-- Issue 10-026: Extended with external sync support (merged external_files)
--
-- Reads from config.sources and provides iteration over source directories.
-- Also provides access to external sync information (where to pull data from).
--
-- The sources config supports multiple named directories per source type,
-- enabling deduplication and flexible input management.
--
-- Usage:
--   local loader = require("sources-loader")
--   loader.set_project_root("/path/to/project")
--
--   -- Get all directories for a source type
--   local fedi_dirs = loader.get_directories("fediverse")
--   for _, dir in ipairs(fedi_dirs) do
--       print(dir.name, dir.path)
--   end
--
--   -- Check if a source is enabled
--   if loader.is_enabled("bluesky") then ... end
--
--   -- Get source metadata
--   local src = loader.get_source("fediverse")
--   print(src.format)  -- "activitypub"
--
--   -- Get all external sync entries (Issue 10-026)
--   local syncs = loader.get_all_external_syncs()
--   for _, sync in ipairs(syncs) do
--       print(sync.name, sync.source, sync.destination)
--   end
--
--   -- Get archives for a source type
--   local archives = loader.get_archives("fediverse")
-- }}}

local M = {}

-- {{{ Module state
local project_root = nil
local config = nil
-- }}}

-- {{{ ANSI color codes for terminal output
local COLOR_GREEN = "\027[92m"
local COLOR_RED = "\027[91m"
local COLOR_YELLOW = "\027[93m"
local COLOR_RESET = "\027[0m"
-- }}}

-- {{{ set_project_root
-- Set the project root directory (required before any operations)
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
        error("sources-loader: project_root not set. Call set_project_root() first.")
    end

    local config_path = project_root .. "/config.lua"
    local ok, result = pcall(dofile, config_path)
    if not ok then
        error("sources-loader: Failed to load config.lua: " .. tostring(result))
    end

    config = result
    return config
end
-- }}}

-- {{{ local function get_sources
-- Get the sources table from config
local function get_sources()
    local cfg = load_config()
    return cfg.sources or {}
end
-- }}}

-- {{{ local function resolve_path
-- Resolve a path (make absolute if relative)
local function resolve_path(path)
    if not path then return nil end

    -- If already absolute, return as-is
    if path:sub(1, 1) == "/" then
        return path
    end

    -- Relative to project root
    return project_root .. "/" .. path
end
-- }}}

-- {{{ local function dir_exists
-- Check if a directory exists
local function dir_exists(path)
    local handle = io.popen("test -d '" .. path .. "' && echo yes || echo no")
    local result = handle:read("*l")
    handle:close()
    return result == "yes"
end
-- }}}

-- {{{ get_source
-- Get a source configuration by type name
-- Returns: table with source config or nil if not found
function M.get_source(source_type)
    local sources = get_sources()
    return sources[source_type]
end
-- }}}

-- {{{ is_enabled
-- Check if a source type is enabled
-- Returns: boolean
function M.is_enabled(source_type)
    local source = M.get_source(source_type)
    if not source then
        return false
    end
    -- Default to true if enabled field is missing
    return source.enabled ~= false
end
-- }}}

-- {{{ get_format
-- Get the format string for a source type
-- Returns: string or nil
function M.get_format(source_type)
    local source = M.get_source(source_type)
    if not source then
        return nil
    end
    return source.format
end
-- }}}

-- {{{ get_directories
-- Get all directories for a source type
-- Returns: array of { name, path, optional, description }
-- Paths are resolved to absolute paths
function M.get_directories(source_type)
    local source = M.get_source(source_type)
    if not source then
        return {}
    end

    local dirs = source.directories or {}
    local result = {}

    for _, dir in ipairs(dirs) do
        table.insert(result, {
            name = dir.name or "unnamed",
            path = resolve_path(dir.path),
            optional = dir.optional or false,
            description = dir.description or ""
        })
    end

    return result
end
-- }}}

-- {{{ get_valid_directories
-- Get directories that exist (skips missing optional, errors on missing required)
-- Returns: array of directories, or nil + error message on failure
function M.get_valid_directories(source_type)
    local dirs = M.get_directories(source_type)
    local valid = {}
    local warnings = {}

    for _, dir in ipairs(dirs) do
        if dir_exists(dir.path) then
            table.insert(valid, dir)
        elseif dir.optional then
            table.insert(warnings, string.format(
                "Optional directory '%s' not found: %s",
                dir.name, dir.path))
        else
            return nil, string.format(
                "Required directory '%s' not found: %s",
                dir.name, dir.path)
        end
    end

    return valid, warnings
end
-- }}}

-- {{{ get_source_types
-- Get all configured source type names
-- Returns: array of strings (e.g., {"fediverse", "messages", "notes", "bluesky", "images"})
function M.get_source_types()
    local sources = get_sources()
    local types = {}

    for name, _ in pairs(sources) do
        table.insert(types, name)
    end

    -- Sort for consistent ordering
    table.sort(types)
    return types
end
-- }}}

-- {{{ get_enabled_sources
-- Get all enabled source types
-- Returns: array of strings
function M.get_enabled_sources()
    local all_types = M.get_source_types()
    local enabled = {}

    for _, source_type in ipairs(all_types) do
        if M.is_enabled(source_type) then
            table.insert(enabled, source_type)
        end
    end

    return enabled
end
-- }}}

-- {{{ get_media_config
-- Get media configuration for a source type (if any)
-- Returns: table with media settings or nil
function M.get_media_config(source_type)
    local source = M.get_source(source_type)
    if not source then
        return nil
    end
    return source.media
end
-- }}}

-- {{{ validate_source
-- Validate a source configuration
-- Returns: true, nil on success; false, error_message on failure
function M.validate_source(source_type)
    local source = M.get_source(source_type)

    if not source then
        return false, "Source type not found: " .. source_type
    end

    -- Check directories exist
    if not source.directories or #source.directories == 0 then
        return false, source_type .. ": No directories configured"
    end

    -- Check each directory has required fields
    for i, dir in ipairs(source.directories) do
        if not dir.path then
            return false, string.format(
                "%s: Directory #%d missing 'path' field",
                source_type, i)
        end
    end

    return true, nil
end
-- }}}

-- {{{ validate_all
-- Validate all source configurations
-- Returns: { valid = bool, errors = {}, warnings = {} }
function M.validate_all()
    local result = {
        valid = true,
        errors = {},
        warnings = {}
    }

    local source_types = M.get_source_types()

    for _, source_type in ipairs(source_types) do
        local ok, err = M.validate_source(source_type)
        if not ok then
            result.valid = false
            table.insert(result.errors, err)
        end

        -- Check if enabled and directories exist
        if M.is_enabled(source_type) then
            local dirs, warn_or_err = M.get_valid_directories(source_type)
            if not dirs then
                -- Error (missing required directory)
                result.valid = false
                table.insert(result.errors, warn_or_err)
            elseif type(warn_or_err) == "table" then
                -- Warnings (missing optional directories)
                for _, w in ipairs(warn_or_err) do
                    table.insert(result.warnings, w)
                end
            end
        end
    end

    return result
end
-- }}}

-- {{{ print_sources
-- Print a formatted summary of configured sources
function M.print_sources()
    local source_types = M.get_source_types()

    if #source_types == 0 then
        print("No sources configured")
        return
    end

    print("Configured sources:")
    print(string.rep("-", 70))

    for _, source_type in ipairs(source_types) do
        local source = M.get_source(source_type)
        local enabled = M.is_enabled(source_type)
        local status = enabled and COLOR_GREEN .. "enabled" .. COLOR_RESET
                               or COLOR_YELLOW .. "disabled" .. COLOR_RESET

        print(string.format("  %s [%s]", source_type, status))

        if source.format then
            print(string.format("    Format: %s", source.format))
        end

        local dirs = M.get_directories(source_type)
        if #dirs > 0 then
            print("    Directories:")
            for _, dir in ipairs(dirs) do
                local exists = dir_exists(dir.path)
                local marker = exists and "✓" or "✗"
                local opt = dir.optional and " (optional)" or ""
                print(string.format("      %s %s: %s%s",
                    marker, dir.name, dir.path, opt))
            end
        end
    end
end
-- }}}

-- {{{ iterate_directories
-- Iterate over all valid directories for a source type, calling a function for each
-- Skips optional missing directories, errors on required missing
-- callback(dir) receives { name, path, optional, description }
-- Returns: true on success, false + error on failure
function M.iterate_directories(source_type, callback)
    if not M.is_enabled(source_type) then
        return true  -- Not enabled, nothing to do
    end

    local dirs, err = M.get_valid_directories(source_type)
    if not dirs then
        return false, err
    end

    for _, dir in ipairs(dirs) do
        callback(dir)
    end

    return true
end
-- }}}

-- {{{ get_directories_with_external
-- Issue 10-026: Get directories including external sync information
-- Returns: array of { name, path, optional, description, external }
-- external is { source = "...", destination = "..." } or nil
function M.get_directories_with_external(source_type)
    local source = M.get_source(source_type)
    if not source then
        return {}
    end

    local dirs = source.directories or {}
    local result = {}

    for _, dir in ipairs(dirs) do
        local entry = {
            name = dir.name or "unnamed",
            path = resolve_path(dir.path),
            optional = dir.optional or false,
            description = dir.description or "",
            external = nil
        }

        -- Include external sync info if present
        -- external.source is where to pull from
        -- destination is derived from path (strip "input/" prefix)
        if dir.external and dir.external.source then
            local dest = dir.path or ""
            -- Strip "input/" prefix if present to get destination relative to input/
            if dest:sub(1, 6) == "input/" then
                dest = dest:sub(7)
            end
            entry.external = {
                source = dir.external.source,
                destination = dest
            }
        end

        table.insert(result, entry)
    end

    return result
end
-- }}}

-- {{{ get_archives
-- Issue 10-026: Get archive entries for a source type
-- Archives are ZIP files that need extraction rather than rsync
-- Returns: array of { name, source, extract_to }
function M.get_archives(source_type)
    local source = M.get_source(source_type)
    if not source then
        return {}
    end

    local archives = source.archives or {}
    local result = {}

    for _, archive in ipairs(archives) do
        table.insert(result, {
            name = archive.name or "unnamed",
            source = archive.source,
            extract_to = resolve_path(archive.extract_to or "input")
        })
    end

    return result
end
-- }}}

-- {{{ get_all_external_syncs
-- Issue 10-026: Get ALL external sync entries across all sources
-- Returns data in external_files-compatible format for backward compatibility
-- Returns: array of { name, source, destination, optional, is_archive }
function M.get_all_external_syncs()
    local sources = get_sources()
    local result = {}

    for source_type, source in pairs(sources) do
        -- Collect directory-based syncs (rsync)
        if source.directories then
            for _, dir in ipairs(source.directories) do
                if dir.external and dir.external.source then
                    local dest = dir.path or ""
                    -- Strip "input/" prefix for destination
                    if dest:sub(1, 6) == "input/" then
                        dest = dest:sub(7)
                    end
                    table.insert(result, {
                        name = dir.name or "unnamed",
                        source = dir.external.source,
                        destination = dest,
                        optional = dir.optional or false,
                        is_archive = false,
                        source_type = source_type
                    })
                end
            end
        end

        -- Collect archive-based syncs (unzip)
        if source.archives then
            for _, archive in ipairs(source.archives) do
                local dest = archive.extract_to or "input"
                -- Strip "input/" prefix for destination
                if dest:sub(1, 6) == "input/" then
                    dest = dest:sub(7)
                end
                -- Empty string means extract to input/ root
                if dest == "input" then
                    dest = ""
                end
                table.insert(result, {
                    name = archive.name or "unnamed",
                    source = archive.source,
                    destination = dest,
                    optional = archive.optional or false,
                    is_archive = true,
                    source_type = source_type
                })
            end
        end
    end

    return result
end
-- }}}

-- {{{ has_external_syncs
-- Issue 10-026: Check if any source has external sync configuration
-- Returns: boolean
function M.has_external_syncs()
    local syncs = M.get_all_external_syncs()
    return #syncs > 0
end
-- }}}

return M
