#!/usr/bin/env lua

-- Image discovery and cataloging system
-- Scans configured directories for supported image formats and creates metadata catalog

-- {{{ setup_dir_path
local function setup_dir_path(provided_dir)
    -- Skip if provided_dir is a flag (starts with -)
    if provided_dir and provided_dir:sub(1, 1) ~= "-" then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

-- {{{ parse_dir_from_args
-- Parse arguments to extract directory path, skipping flags like --verbose
local function parse_dir_from_args(args)
    if not args then return nil end
    for i = 1, #args do
        local a = args[i]
        -- Skip flags (start with -)
        if a and a:sub(1, 1) ~= "-" then
            return a
        end
    end
    return nil
end
-- }}}

-- Script configuration
local DIR = setup_dir_path(parse_dir_from_args(arg))

-- Load required libraries
package.path = DIR .. "/libs/?.lua;" .. package.path
local dkjson = require("dkjson")
local utils = require("utils")

-- Issue 10-003: Load unified config from config.lua
local config_loader = require("config-loader")
config_loader.set_project_root(DIR)
local unified_config = config_loader.load()

-- Issue 10-015a: Load sources configuration for multi-directory support
local sources_loader = require("sources-loader")
sources_loader.set_project_root(DIR)

-- Initialize asset path configuration (CLI --dir takes precedence over config)
utils.init_assets_root(arg)

-- ANSI color codes for terminal output
local COLOR_YELLOW = "\027[93m"   -- Bright yellow for warnings
local COLOR_RESET = "\027[0m"

-- {{{ local function shell_escape
-- Escape single quotes in paths for safe shell execution
-- e.g., "Sant'Azraphel.png" -> "Sant'\''Azraphel.png"
local function shell_escape(path)
    return path:gsub("'", "'\\''")
end
-- }}}

-- {{{ local function relative_path
local function relative_path(absolute_path)
    if absolute_path:sub(1, #DIR) == DIR then
        local rel = absolute_path:sub(#DIR + 1)
        if rel:sub(1, 1) == "/" then rel = rel:sub(2) end
        return "./" .. rel
    end
    return absolute_path
end
-- }}}

local M = {}

-- {{{ function load_config
-- Issue 10-015a: Use sources-loader for image directories (replaces input_sources dependency)
-- This is the "no fallbacks" design - errors if sources.images not configured
local function load_config()
    -- Get image source configuration
    local images_source = sources_loader.get_source("images")
    if not images_source then
        error("sources.images not configured in config.lua - required for image discovery")
    end

    -- Build image_directories from sources.images.directories
    local directories = sources_loader.get_directories("images")
    if #directories == 0 then
        error("sources.images.directories is empty in config.lua - no directories to scan")
    end

    -- Extract just the paths (relative to project root, will be prefixed with DIR later)
    local image_directories = {}
    for _, dir in ipairs(directories) do
        -- sources-loader returns absolute paths, convert to relative for consistency
        local path = dir.path
        if path:sub(1, #DIR) == DIR then
            path = path:sub(#DIR + 2)  -- Strip DIR prefix and leading slash
        end
        table.insert(image_directories, path)
    end

    -- Build config from sources.images settings (with image_integration fallbacks for display settings)
    local display_config = unified_config.image_integration or {}
    local config = {
        enabled = sources_loader.is_enabled("images"),
        image_directories = image_directories,
        -- Use sources.images settings, fall back to image_integration for legacy compat
        supported_formats = images_source.supported_formats or display_config.supported_formats or {"png", "jpg", "jpeg", "gif", "webp", "svg"},
        max_file_size_mb = images_source.max_file_size_mb or display_config.max_file_size_mb or 10,
        -- Keep display settings from image_integration
        output_path = display_config.output_path,
        catalog_file = display_config.catalog_file
    }

    return config
end
-- }}}

-- {{{ function get_file_size
local function get_file_size(file_path)
    local stat_cmd = string.format("stat -c %%s '%s' 2>/dev/null", shell_escape(file_path))
    local handle = io.popen(stat_cmd)
    local result = handle:read("*a")
    handle:close()
    
    if result and result ~= "" then
        local clean_result = result:gsub("%s+", "")
        local size = tonumber(clean_result)
        if size then
            return size
        end
    end
    
    return 0
end
-- }}}

-- {{{ function get_file_mtime
local function get_file_mtime(file_path)
    local stat_cmd = string.format("stat -c %%Y '%s' 2>/dev/null", shell_escape(file_path))
    local handle = io.popen(stat_cmd)
    local result = handle:read("*a")
    handle:close()
    
    if result and result ~= "" then
        local clean_result = result:gsub("%s+", "")
        local timestamp = tonumber(clean_result)
        if timestamp then
            return timestamp
        end
    end
    
    return os.time()
end
-- }}}

-- {{{ function extract_image_dimensions
local function extract_image_dimensions(file_path)
    -- Try to use imagemagick's identify command
    local identify_cmd = string.format("identify -format '%%wx%%h' '%s' 2>/dev/null", shell_escape(file_path))
    local handle = io.popen(identify_cmd)
    local result = handle:read("*a")
    handle:close()
    
    if result and result ~= "" then
        local width, height = result:match("(%d+)x(%d+)")
        if width and height then
            return tonumber(width), tonumber(height)
        end
    end
    
    -- Fallback: return unknown dimensions
    return nil, nil
end
-- }}}

-- {{{ function generate_image_hash
local function generate_image_hash(file_path)
    -- Generate MD5 hash for duplicate detection
    local hash_cmd = string.format("md5sum '%s' 2>/dev/null | cut -d' ' -f1", shell_escape(file_path))
    local handle = io.popen(hash_cmd)
    local result = handle:read("*a")
    handle:close()
    
    if result and result ~= "" then
        return result:gsub("%s+", "")
    end
    
    return nil
end
-- }}}

-- {{{ function is_supported_format
local function is_supported_format(file_path, supported_formats)
    local extension = file_path:match("%.([^%.]+)$")
    if not extension then
        return false
    end
    
    extension = extension:lower()
    for _, format in ipairs(supported_formats) do
        if extension == format:lower() then
            return true
        end
    end
    
    return false
end
-- }}}

-- {{{ function scan_directory_for_images
local function scan_directory_for_images(directory, config)
    local images = {}
    
    print("🔍 Scanning directory: " .. relative_path(directory))
    
    -- Check if directory exists
    local check_cmd = string.format("test -d '%s'", shell_escape(directory))
    local exists = os.execute(check_cmd) == true or os.execute(check_cmd) == 0
    
    if not exists then
        print("⚠️  Directory not found: " .. relative_path(directory))
        return images
    end
    
    -- Find all files in directory
    local find_cmd = string.format("find '%s' -type f", shell_escape(directory))
    local handle = io.popen(find_cmd)
    
    local processed_count = 0
    local skipped_count = 0
    
    for file_path in handle:lines() do
        if is_supported_format(file_path, config.supported_formats) then
            local file_size = get_file_size(file_path)
            local max_size = (config.max_file_size_mb or 10) * 1024 * 1024
            
            if file_size <= max_size then
                local width, height = extract_image_dimensions(file_path)
                local file_hash = generate_image_hash(file_path)
                local mtime = get_file_mtime(file_path)
                
                local image_entry = {
                    file_path = file_path,
                    relative_path = file_path:gsub("^" .. DIR .. "/", ""),
                    filename = file_path:match("([^/]+)$"),
                    extension = file_path:match("%.([^%.]+)$"):lower(),
                    size_bytes = file_size,
                    size_mb = math.floor(file_size / 1024 / 1024 * 100) / 100,
                    width = width,
                    height = height,
                    aspect_ratio = (width and height) and (width / height) or nil,
                    hash = file_hash,
                    modification_time = mtime,
                    modification_date = os.date("%Y-%m-%dT%H:%M:%SZ", mtime),
                    source_directory = directory
                }
                
                table.insert(images, image_entry)
                processed_count = processed_count + 1
            else
                skipped_count = skipped_count + 1
            end
        end
    end
    
    handle:close()
    
    print(string.format("   📄 Processed: %d images", processed_count))
    if skipped_count > 0 then
        print(string.format("   ⏩ Skipped: %d images (size/format)", skipped_count))
    end
    
    return images
end
-- }}}

-- {{{ function M.discover_images
function M.discover_images()
    print("🖼️  Starting image discovery...")
    
    local config = load_config()
    if not config.enabled then
        print("❌ Image integration disabled in configuration")
        return {}
    end
    
    local all_images = {}
    
    for _, directory in ipairs(config.image_directories) do
        local full_path = DIR .. "/" .. directory
        local directory_images = scan_directory_for_images(full_path, config)
        
        -- Add directory images to main collection
        for _, image in ipairs(directory_images) do
            table.insert(all_images, image)
        end
    end
    
    -- Sort by modification time (newest first)
    table.sort(all_images, function(a, b)
        return a.modification_time > b.modification_time
    end)
    
    print(string.format("✅ Image discovery complete: %d images found", #all_images))
    return all_images
end
-- }}}

-- {{{ function M.generate_catalog
function M.generate_catalog(images, output_file)
    local config = load_config()

    -- Create assets directory if it doesn't exist (use configured path)
    local assets_dir = utils.get_assets_root()
    os.execute("mkdir -p " .. assets_dir)

    -- Generate duplicate analysis - group by hash with full image data
    local hash_groups = {}

    for _, image in ipairs(images) do
        if image.hash then
            if not hash_groups[image.hash] then
                hash_groups[image.hash] = {}
            end
            table.insert(hash_groups[image.hash], image)
        end
    end

    -- Resolve duplicates by keeping only the newest file from each group
    -- Also track which duplicates were resolved for reporting
    local resolved_duplicates = {}
    local kept_hashes = {}  -- Track which images to keep
    local duplicate_count = 0

    for hash, group in pairs(hash_groups) do
        if #group > 1 then
            -- Sort group by modification_time descending (newest first)
            table.sort(group, function(a, b)
                return (a.modification_time or 0) > (b.modification_time or 0)
            end)

            -- Keep the newest file (first after sorting)
            kept_hashes[hash] = group[1].file_path

            -- Track resolved duplicates for reporting
            local removed_paths = {}
            for i = 2, #group do
                table.insert(removed_paths, group[i].relative_path)
                duplicate_count = duplicate_count + 1
            end

            table.insert(resolved_duplicates, {
                hash = hash,
                kept = group[1].relative_path,
                removed = removed_paths,
                count = #group
            })
        else
            -- Only one file with this hash - keep it
            kept_hashes[hash] = group[1].file_path
        end
    end

    -- Filter images to only include kept files (newest from each duplicate group)
    local filtered_images = {}
    for _, image in ipairs(images) do
        if not image.hash then
            -- No hash - can't detect duplicates, keep it
            table.insert(filtered_images, image)
        elseif kept_hashes[image.hash] == image.file_path then
            -- This is the kept file from the duplicate group
            table.insert(filtered_images, image)
        end
        -- Otherwise skip - it's a duplicate that was resolved
    end

    -- Report duplicate resolution
    if duplicate_count > 0 then
        print(string.format("🔄 Resolved %d duplicates (kept newest of each group)", duplicate_count))
    end
    
    -- Generate statistics (using filtered_images which has duplicates removed)
    local stats = {
        total_images = #images,  -- Original count before filtering
        unique_images = #filtered_images,  -- After duplicate resolution
        duplicate_images = duplicate_count,
        total_size_mb = 0,
        average_size_mb = 0,
        format_distribution = {},
        size_distribution = {
            small = 0,    -- < 100KB
            medium = 0,   -- 100KB - 1MB
            large = 0     -- > 1MB
        },
        resolution_distribution = {
            low = 0,      -- < 500px width
            medium = 0,   -- 500-1500px width  
            high = 0      -- > 1500px width
        }
    }
    
    -- Calculate stats using filtered (de-duplicated) images
    for _, image in ipairs(filtered_images) do
        -- Size statistics
        stats.total_size_mb = stats.total_size_mb + (image.size_mb or 0)

        -- Format distribution
        local ext = image.extension or "unknown"
        stats.format_distribution[ext] = (stats.format_distribution[ext] or 0) + 1

        -- Size distribution
        local size_mb = image.size_mb or 0
        if size_mb < 0.1 then
            stats.size_distribution.small = stats.size_distribution.small + 1
        elseif size_mb < 1 then
            stats.size_distribution.medium = stats.size_distribution.medium + 1
        else
            stats.size_distribution.large = stats.size_distribution.large + 1
        end

        -- Resolution distribution
        local width = image.width or 0
        if width < 500 then
            stats.resolution_distribution.low = stats.resolution_distribution.low + 1
        elseif width < 1500 then
            stats.resolution_distribution.medium = stats.resolution_distribution.medium + 1
        else
            stats.resolution_distribution.high = stats.resolution_distribution.high + 1
        end
    end

    stats.average_size_mb = stats.total_size_mb / math.max(#filtered_images, 1)
    stats.total_size_mb = math.floor(stats.total_size_mb * 100) / 100
    stats.average_size_mb = math.floor(stats.average_size_mb * 1000) / 1000
    
    -- Create catalog structure (uses filtered_images with duplicates resolved)
    local catalog = {
        metadata = {
            generated_at = os.date("%Y-%m-%dT%H:%M:%SZ"),
            total_images = #images,  -- Original count before filtering
            unique_images = #filtered_images,  -- After duplicate resolution
            configuration = config,
            statistics = stats
        },
        images = filtered_images,  -- De-duplicated image list
        resolved_duplicates = resolved_duplicates  -- Record of what was deduplicated
    }
    
    -- Write catalog to file (use configured assets path)
    local catalog_path = output_file or utils.asset_path("image-catalog.json")
    local file = io.open(catalog_path, "w")
    if not file then
        error("Could not create catalog file: " .. catalog_path)
    end
    
    file:write(dkjson.encode(catalog, { indent = true }))
    file:close()
    
    print("📄 Generated catalog: " .. relative_path(catalog_path))
    return catalog
end
-- }}}

-- {{{ function M.show_statistics
-- Issue 10-015a: Added verbose parameter - detailed stats only show when verbose=true
-- Summary (always shown): total, unique, duplicates count, size
-- Detailed (verbose only): format distribution, size distribution, resolution distribution
-- Warnings (always shown): duplicate groups
function M.show_statistics(catalog, verbose)
    local stats = catalog.metadata.statistics

    print("\n=== IMAGE CATALOG STATISTICS ===")
    print(string.format("Total Images: %d", stats.total_images))
    print(string.format("Unique Images: %d", stats.unique_images))
    print(string.format("Duplicate Images: %d", stats.duplicate_images))
    print(string.format("Total Size: %.2f MB", stats.total_size_mb))
    print(string.format("Average Size: %.3f MB", stats.average_size_mb))

    -- Detailed statistics only shown when verbose flag is set
    if verbose then
        print("\nFormat Distribution:")
        for format, count in pairs(stats.format_distribution) do
            print(string.format("  %s: %d images", format, count))
        end

        print("\nSize Distribution:")
        print(string.format("  Small (<100KB): %d images", stats.size_distribution.small))
        print(string.format("  Medium (100KB-1MB): %d images", stats.size_distribution.medium))
        print(string.format("  Large (>1MB): %d images", stats.size_distribution.large))

        print("\nResolution Distribution:")
        print(string.format("  Low (<500px): %d images", stats.resolution_distribution.low))
        print(string.format("  Medium (500-1500px): %d images", stats.resolution_distribution.medium))
        print(string.format("  High (>1500px): %d images", stats.resolution_distribution.high))
    end

    -- Show resolved duplicates (informational, not warnings - duplicates are now handled)
    local resolved = catalog.resolved_duplicates or {}
    if #resolved > 0 then
        print(string.format("\n✅ Resolved %d duplicate groups (kept newest):", #resolved))
        if verbose then
            for i, dup_group in ipairs(resolved) do
                local removed_str = table.concat(dup_group.removed, ", ")
                print(string.format("  Group %d: kept %s, removed: %s",
                    i, relative_path(dup_group.kept), removed_str))
            end
        else
            print("   (use --verbose to see details)")
        end
    end
end
-- }}}

-- {{{ function M.main
-- Issue 10-015a: Added verbose parameter for detailed statistics output
function M.main(verbose)
    print("🖼️  Image Integration System")
    print("Project Directory: " .. relative_path(DIR))

    -- Discover all images
    local images = M.discover_images()

    if #images == 0 then
        print("❌ No images found in configured directories")
        return false
    end

    -- Generate catalog
    local catalog = M.generate_catalog(images)

    -- Show statistics (detailed distribution only when verbose=true)
    M.show_statistics(catalog, verbose)

    print("\n✅ Image integration system ready")
    return true
end
-- }}}

-- Command line execution (only when run directly, not when required as module)
if arg and arg[0] and arg[0]:match("image%-manager%.lua$") then
    -- Issue 10-015a: Parse --verbose/-v flag for detailed statistics
    local verbose = false
    for i = 1, #arg do
        if arg[i] == "--verbose" or arg[i] == "-v" then
            verbose = true
            break
        end
    end
    M.main(verbose)
end

return M