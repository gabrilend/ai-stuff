#!/usr/bin/env lua

-- Image discovery and cataloging system
-- Scans configured directories for supported image formats and creates metadata catalog

-- {{{ setup_dir_path
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

-- Script configuration
local DIR = setup_dir_path(arg and arg[1])

-- Load required libraries
package.path = DIR .. "/libs/?.lua;" .. package.path
local dkjson = require("dkjson")
local utils = require("utils")

-- Initialize asset path configuration (CLI --dir takes precedence over config)
utils.init_assets_root(arg)

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
local function load_config()
    local config_file = DIR .. "/config/input-sources.json"
    local file = io.open(config_file, "r")
    if not file then
        error("Could not open config file: " .. config_file)
    end
    
    local content = file:read("*a")
    file:close()
    
    local config, pos, err = dkjson.decode(content, 1, nil)
    if err then
        error("Failed to parse config file: " .. err)
    end
    
    return config.image_integration or {}
end
-- }}}

-- {{{ function get_file_size
local function get_file_size(file_path)
    local stat_cmd = string.format("stat -c %%s '%s' 2>/dev/null", file_path)
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
    local stat_cmd = string.format("stat -c %%Y '%s' 2>/dev/null", file_path)
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
    local identify_cmd = string.format("identify -format '%%wx%%h' '%s' 2>/dev/null", file_path)
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
    local hash_cmd = string.format("md5sum '%s' 2>/dev/null | cut -d' ' -f1", file_path)
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
    local check_cmd = string.format("test -d '%s'", directory)
    local exists = os.execute(check_cmd) == true or os.execute(check_cmd) == 0
    
    if not exists then
        print("⚠️  Directory not found: " .. relative_path(directory))
        return images
    end
    
    -- Find all files in directory
    local find_cmd = string.format("find '%s' -type f", directory)
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
    
    -- Generate duplicate analysis
    local hash_groups = {}
    local duplicate_count = 0
    
    for _, image in ipairs(images) do
        if image.hash then
            if not hash_groups[image.hash] then
                hash_groups[image.hash] = {}
            end
            table.insert(hash_groups[image.hash], image.relative_path)
        end
    end
    
    -- Count duplicates
    for hash, files in pairs(hash_groups) do
        if #files > 1 then
            duplicate_count = duplicate_count + (#files - 1)
        end
    end
    
    -- Generate statistics
    local stats = {
        total_images = #images,
        unique_images = #images - duplicate_count,
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
    
    for _, image in ipairs(images) do
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
    
    stats.average_size_mb = stats.total_size_mb / math.max(#images, 1)
    stats.total_size_mb = math.floor(stats.total_size_mb * 100) / 100
    stats.average_size_mb = math.floor(stats.average_size_mb * 1000) / 1000
    
    -- Create catalog structure
    local catalog = {
        metadata = {
            generated_at = os.date("%Y-%m-%dT%H:%M:%SZ"),
            total_images = #images,
            configuration = config,
            statistics = stats
        },
        images = images,
        duplicates = {}
    }
    
    -- Add duplicate information
    for hash, files in pairs(hash_groups) do
        if #files > 1 then
            table.insert(catalog.duplicates, {
                hash = hash,
                files = files,
                count = #files
            })
        end
    end
    
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
function M.show_statistics(catalog)
    local stats = catalog.metadata.statistics
    
    print("\n=== IMAGE CATALOG STATISTICS ===")
    print(string.format("Total Images: %d", stats.total_images))
    print(string.format("Unique Images: %d", stats.unique_images))
    print(string.format("Duplicate Images: %d", stats.duplicate_images))
    print(string.format("Total Size: %.2f MB", stats.total_size_mb))
    print(string.format("Average Size: %.3f MB", stats.average_size_mb))
    
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
    
    if #catalog.duplicates > 0 then
        print(string.format("\nDuplicate Groups: %d", #catalog.duplicates))
        for i, dup_group in ipairs(catalog.duplicates) do
            if i <= 3 then -- Show first 3 duplicate groups
                local rel_files = {}
                for _, f in ipairs(dup_group.files) do
                    table.insert(rel_files, relative_path(f))
                end
                print(string.format("  Group %d (%d files): %s", i, dup_group.count, table.concat(rel_files, ", ")))
            end
        end
        if #catalog.duplicates > 3 then
            print(string.format("  ... and %d more groups", #catalog.duplicates - 3))
        end
    end
end
-- }}}

-- {{{ function M.main
function M.main()
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
    
    -- Show statistics
    M.show_statistics(catalog)
    
    print("\n✅ Image integration system ready")
    return true
end
-- }}}

-- Command line execution (only when run directly, not when required as module)
if arg and arg[0] and arg[0]:match("image%-manager%.lua$") then
    M.main()
end

return M