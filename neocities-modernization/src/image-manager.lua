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

-- {{{ parse_seed_from_args
-- Issue 10-058: pull the build's master seed out of the shared arg vector. run.sh
-- threads "--seed=N" (equals form, so the bare number is never mistaken for the
-- positional DIR). Both "--seed=N" and "--seed N" are accepted. Returns a number
-- or nil (nil => no master seed supplied; per-source random_seed still applies and
-- a source with neither is randomized by the system RNG, which run.sh warns about).
local function parse_seed_from_args(args)
    if not args then return nil end
    for i = 1, #args do
        local a = args[i]
        if a == "--seed" then
            return tonumber(args[i + 1])
        end
        local eq = a:match("^--seed=(.+)$")
        if eq then return tonumber(eq) end
    end
    return nil
end
-- }}}

-- Script configuration
local DIR = setup_dir_path(parse_dir_from_args(arg))
-- Issue 10-058: master seed (nil unless run.sh / the operator passed --seed).
local MASTER_SEED = parse_seed_from_args(arg)

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
-- Issue 10-030: Now returns full directory objects (not just paths) for randomization support
-- This is the "no fallbacks" design - errors if sources.images not configured
local function load_config()
    -- Get image source configuration
    local images_source = sources_loader.get_source("images")
    if not images_source then
        error("sources.images not configured in config.lua - required for image discovery")
    end

    -- Build image_directories from sources.images.directories
    -- Issue 10-030: Now returns full directory objects with randomize_order and random_seed
    local directories = sources_loader.get_directories("images")
    if #directories == 0 then
        error("sources.images.directories is empty in config.lua - no directories to scan")
    end

    -- Issue 10-030: Keep full directory objects, converting paths to relative
    local image_directories = {}
    for _, dir in ipairs(directories) do
        -- sources-loader returns absolute paths, convert to relative for consistency
        local path = dir.path
        if path:sub(1, #DIR) == DIR then
            path = path:sub(#DIR + 2)  -- Strip DIR prefix and leading slash
        end
        table.insert(image_directories, {
            name = dir.name,
            path = path,
            description = dir.description,
            -- Issue 10-030: Randomization options
            randomize_order = dir.randomize_order or false,
            random_seed = dir.random_seed
        })
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
-- Issue 10-030: Now accepts dir_config (full directory object) for randomization tracking
local function scan_directory_for_images(directory, config, dir_config)
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
                    source_directory = directory,
                    -- Issue 10-030: Track source config for randomization
                    source_name = dir_config and dir_config.name or nil,
                    source_randomize = dir_config and dir_config.randomize_order or false,
                    source_random_seed = dir_config and dir_config.random_seed or nil
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

-- {{{ local function create_seeded_rng
-- Issue 10-030: Create a seeded random number generator for reproducible randomization
-- Uses a simple linear congruential generator (LCG) for deterministic results
local function create_seeded_rng(seed)
    local state = seed
    return function()
        -- LCG parameters (same as glibc)
        state = (state * 1103515245 + 12345) % 2147483648
        return state / 2147483648
    end
end
-- }}}

-- {{{ local function derive_source_seed(master_seed, source_name)
-- Issue 10-058: turn the one build-wide master seed into a STABLE per-source seed,
-- so every randomized source gets its own reproducible order from the same master.
-- The per-source key is the source NAME (a djb2 string hash), not its position in
-- the iteration -- so the derived seed does not change if sources are reordered,
-- added, or removed. Folded to a 31-bit non-negative int to match create_seeded_rng.
local function derive_source_seed(master_seed, source_name)
    local hash = 5381
    for i = 1, #source_name do
        -- djb2: hash * 33 + byte, kept inside 31 bits each step so it never grows
        -- past Lua's exact-integer range (no precision drift across machines).
        hash = ((hash * 33) + source_name:byte(i)) % 2147483647
    end
    return (master_seed + hash) % 2147483647
end
-- }}}

-- {{{ local function apply_randomization
-- Issue 10-030: Apply randomized timestamps to images from randomized sources
local function apply_randomization(all_images)
    -- First, find the timeline range from non-randomized images
    local min_time = nil
    local max_time = nil

    for _, image in ipairs(all_images) do
        if not image.source_randomize then
            local t = image.modification_time
            if not min_time or t < min_time then min_time = t end
            if not max_time or t > max_time then max_time = t end
        end
    end

    -- If no non-randomized images, use current year as range
    if not min_time then
        local now = os.time()
        min_time = now - 365 * 24 * 60 * 60  -- One year ago
        max_time = now
    end

    local range = max_time - min_time
    if range <= 0 then range = 1 end  -- Prevent division by zero

    -- Group images by source for seeded randomization
    local source_rngs = {}
    local randomized_count = 0

    for _, image in ipairs(all_images) do
        if image.source_randomize then
            -- Get or create RNG for this source
            local source_name = image.source_name or "default"
            if not source_rngs[source_name] then
                if image.source_random_seed then
                    -- Explicit per-source seed (Issue 10-030): a deliberate override,
                    -- highest precedence -- like --seed beating config.
                    source_rngs[source_name] = create_seeded_rng(image.source_random_seed)
                elseif MASTER_SEED then
                    -- Issue 10-058: no explicit seed, so derive one deterministically
                    -- from the build's master seed + this source's name. Reproducible
                    -- by default -- the same master seed reorders this source the same
                    -- way every build, with no per-source config needed.
                    source_rngs[source_name] = create_seeded_rng(
                        derive_source_seed(MASTER_SEED, source_name))
                else
                    -- No explicit seed AND no master seed (e.g. image-manager run
                    -- standalone without --seed): fall back to the system RNG. This
                    -- is NON-reproducible; per CLAUDE.md fallback policy run.sh always
                    -- supplies --seed so the live pipeline never lands here.
                    io.stderr:write(string.format(
                        "[image-manager] WARNING: source '%s' randomized with the system RNG "
                        .. "(no per-source random_seed and no --seed master seed) -- this build's "
                        .. "image order is NOT reproducible.\n", source_name))
                    source_rngs[source_name] = math.random
                end
            end

            local rng = source_rngs[source_name]
            local random_offset = rng() * range
            image.modification_time = math.floor(min_time + random_offset)
            image.modification_date = os.date("%Y-%m-%dT%H:%M:%SZ", image.modification_time)
            image.randomized = true  -- Mark as randomized for debugging
            randomized_count = randomized_count + 1
        end
    end

    return randomized_count
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

    -- Issue 10-030: Now iterates over directory objects (not just paths)
    for _, dir_config in ipairs(config.image_directories) do
        local full_path = DIR .. "/" .. dir_config.path
        local directory_images = scan_directory_for_images(full_path, config, dir_config)

        -- Add directory images to main collection
        for _, image in ipairs(directory_images) do
            table.insert(all_images, image)
        end
    end

    -- Issue 10-030: Apply randomization before sorting
    local randomized_count = apply_randomization(all_images)
    if randomized_count > 0 then
        print(string.format("🎲 Randomized timestamps for %d images", randomized_count))
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

    -- Resolved duplicates are handled silently. The count is uninteresting
    -- to the operator and the per-group details are debug-level noise that
    -- nobody reads. If a regression ever produces wrong duplicate handling
    -- we surface it via the catalog file itself, not via stdout spam.
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