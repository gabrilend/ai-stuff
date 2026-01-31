#!/usr/bin/env lua
-- ZIP archive extraction script for content processing
-- Detects and extracts JSON data from ZIP archives for poem extraction pipeline

-- {{{ setup_dir_path
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

-- Get project directory from command line or use default
local DIR = setup_dir_path(arg and arg[1])
local TEMP_DIR = arg and arg[2] or error("Temporary directory required as second argument")

-- Set up package path to find libs
package.path = DIR .. "/libs/?.lua;" .. package.path
local dkjson = require("dkjson")

-- Issue 7-003: Load config for ignored_archives list
local config_loader = require("config-loader")
config_loader.set_project_root(DIR)
local config = config_loader.load()
local ignored_archives = (config.extraction and config.extraction.ignored_archives) or {}

-- {{{ local function is_ignored_archive
-- Check if a ZIP file should be skipped based on config.extraction.ignored_archives
local function is_ignored_archive(basename)
    for _, ignored in ipairs(ignored_archives) do
        if basename == ignored then
            return true
        end
    end
    return false
end
-- }}}

-- ANSI color codes for terminal output
local COLOR_GREEN = "\027[92m"    -- Bright green for success (✓, ✅)
local COLOR_BLUE = "\027[94m"     -- Bright blue for info (ℹ️)
local COLOR_RED = "\027[91m"      -- Bright red for errors (✗, ❌)
local COLOR_YELLOW = "\027[93m"   -- Bright yellow for warnings (⚠️)
local COLOR_RESET = "\027[0m"     -- Reset to default

-- {{{ local function get_file_mtime
-- Issue 7-005: Get file modification time for archive date comparison
local function get_file_mtime(file_path)
    local stat_cmd = string.format("stat -c %%Y '%s' 2>/dev/null", file_path)
    local handle = io.popen(stat_cmd)
    local result = handle:read("*a")
    handle:close()

    if result and result ~= "" then
        -- Wrap gsub in parens to discard second return value (count)
        local clean = (result:gsub("%s+", ""))
        return tonumber(clean) or 0
    end
    return 0
end
-- }}}

-- {{{ local function relative_path
-- Issue 7-003: Show project name instead of "./" when path equals DIR
local function relative_path(absolute_path)
    if absolute_path == DIR or absolute_path == DIR .. "/" then
        local dir_name = DIR:match("([^/]+)/?$")
        return dir_name .. "/"
    end
    if absolute_path:sub(1, #DIR) == DIR then
        local rel = absolute_path:sub(#DIR + 1)
        if rel:sub(1, 1) == "/" then rel = rel:sub(2) end
        return "./" .. rel
    end
    return absolute_path
end
-- }}}

-- {{{ function detect_archive_type
local function detect_archive_type(zip_file)
    -- Check archive contents to determine type
    local list_cmd = string.format("unzip -l '%s' 2>/dev/null", zip_file)
    local handle = io.popen(list_cmd)
    local content = handle:read("*a")
    handle:close()
    
    if content:match("outbox%.json") then
        return "fediverse"
    elseif content:match("export%.json") then
        return "messages"
    elseif content:match("notes/") or content:match("%.txt$") or content:match("%.md$") then
        -- Look for notes directory or text/markdown files
        return "notes"
    end
    
    return nil
end
-- }}}

-- {{{ function detect_archives
local function detect_archives(input_directory)
    local archives = {}
    
    print("🔍 Scanning for ZIP archives in: " .. relative_path(input_directory))

    -- Scan for ZIP files
    local find_cmd = string.format("find '%s' -name '*.zip' -type f", input_directory)
    local handle = io.popen(find_cmd)
    
    for file in handle:lines() do
        local basename = file:match("([^/]+)%.zip$")

        -- Issue 7-003: Skip archives in the ignored list (configured in config.lua)
        if is_ignored_archive(basename) then
            -- Silently skip - these are known non-content ZIPs
        else
            local archive_type = detect_archive_type(file)
            if archive_type then
                -- Issue 7-005: Store modification time for date-based selection
                local mtime = get_file_mtime(file)
                table.insert(archives, {
                    path = file,
                    type = archive_type,
                    basename = basename,
                    mtime = mtime,
                    mtime_date = os.date("%Y-%m-%d", mtime)
                })
                print("📦 Found " .. archive_type .. " archive: " .. basename .. " (" .. os.date("%Y-%m-%d", mtime) .. ")")
            else
                print(COLOR_YELLOW .. "⚠️  " .. COLOR_RESET .. "Unknown archive type: " .. basename)
            end
        end
    end
    handle:close()

    return archives
end
-- }}}

-- {{{ local function select_archives_by_type
-- Issue 7-005: Groups archives by type, sorts by mtime (newest first),
-- returns selected archives and skipped (older) archives
local function select_archives_by_type(archives)
    local by_type = {}

    -- Group by type
    for _, archive in ipairs(archives) do
        if not by_type[archive.type] then
            by_type[archive.type] = {}
        end
        table.insert(by_type[archive.type], archive)
    end

    local selected = {}
    local skipped = {}

    -- Sort each group by mtime (descending) and pick newest
    for archive_type, group in pairs(by_type) do
        table.sort(group, function(a, b) return a.mtime > b.mtime end)

        -- First (newest) is selected
        table.insert(selected, group[1])

        -- Rest are skipped (older archives)
        for i = 2, #group do
            table.insert(skipped, group[i])
        end
    end

    return selected, skipped
end
-- }}}

-- {{{ function extract_archive_data
local function extract_archive_data(archive_info, temp_base_dir)
    local temp_dir = temp_base_dir .. "/" .. archive_info.type
    local extract_dir = temp_dir .. "/extract"
    
    print("📂 Creating temporary directory: " .. relative_path(extract_dir))
    os.execute("mkdir -p " .. extract_dir)
    
    local extract_files = {}
    if archive_info.type == "fediverse" then
        extract_files = {"outbox.json"}
        -- Also extract media_attachments directory for fediverse archives
        -- Use bash to properly handle wildcard expansion for unzip (suppress verbose output)
        local media_cmd = string.format(
            "bash -c 'unzip -o \"%s\" \"media_attachments/files/*\" -d \"%s\"' >/dev/null 2>&1",
            archive_info.path, extract_dir)
        local media_result = os.execute(media_cmd)
        if media_result == 0 or media_result == true then
            print(COLOR_GREEN .. "✅" .. COLOR_RESET .. " Extracted media_attachments directory")
        else
            -- Try alternative: extract all and filter, or list-and-extract approach (suppress verbose output)
            local alt_cmd = string.format(
                "unzip -l '%s' 2>/dev/null | grep media_attachments | awk '{print $4}' | xargs -I{} unzip -o '%s' '{}' -d '%s' >/dev/null 2>&1",
                archive_info.path, archive_info.path, extract_dir)
            os.execute(alt_cmd)
            print(COLOR_GREEN .. "✅" .. COLOR_RESET .. " Extracted media_attachments directory")
        end
    elseif archive_info.type == "messages" then
        -- Matrix exports have nested directory structure
        extract_files = {"export.json", "export/export.json", "*/export.json"}  -- Try multiple patterns
    elseif archive_info.type == "notes" then
        -- Extract entire notes directory or all text files (suppress verbose output)
        local extract_cmd = string.format("unzip -j '%s' 'notes/*' -d '%s' >/dev/null 2>&1",
                                        archive_info.path, extract_dir)
        local result1 = os.execute(extract_cmd)

        -- Also try extracting top-level text files
        local extract_txt_cmd = string.format("unzip -j '%s' '*.txt' '*.md' -d '%s' >/dev/null 2>&1",
                                            archive_info.path, extract_dir)
        local result2 = os.execute(extract_txt_cmd)

        -- If either extraction worked, we're good
        if result1 == 0 or result2 == 0 then
            print(COLOR_GREEN .. "✅" .. COLOR_RESET .. " Extracted notes directory/text files")
        end

        -- Skip the normal file extraction loop for notes
        extract_files = {}
    end

    local extracted_count = 0
    for _, file in ipairs(extract_files) do
        local cmd = string.format("unzip -j '%s' '%s' -d '%s' >/dev/null 2>&1",
                                archive_info.path, file, extract_dir)
        local result = os.execute(cmd)
        if result == 0 then
            print(COLOR_GREEN .. "✅" .. COLOR_RESET .. " Extracted: " .. file)
            extracted_count = extracted_count + 1
            break  -- Stop after first successful extraction
        end
    end
    
    -- Check if any files were actually extracted to the directory
    local check_cmd = string.format("find '%s' -type f | head -1", extract_dir)
    local check_handle = io.popen(check_cmd)
    local found_file = check_handle:read("*l")
    check_handle:close()
    
    if found_file and found_file ~= "" then
        print(COLOR_GREEN .. "✅" .. COLOR_RESET .. " Successfully extracted " .. archive_info.type .. " data from " .. archive_info.basename)
        return temp_dir
    else
        print(COLOR_RED .. "❌" .. COLOR_RESET .. " No extractable files found in " .. archive_info.basename)
        return nil
    end
end
-- }}}

-- {{{ function create_extraction_summary
local function create_extraction_summary(archives, temp_base_dir)
    local summary = {
        total_archives = #archives,
        extracted_archives = 0,
        by_type = {},
        extraction_paths = {},
        timestamp = os.date("%Y-%m-%dT%H:%M:%SZ")
    }
    
    for _, archive in ipairs(archives) do
        local extraction_path = extract_archive_data(archive, temp_base_dir)
        if extraction_path then
            summary.extracted_archives = summary.extracted_archives + 1
            summary.extraction_paths[archive.type] = extraction_path
            
            if not summary.by_type[archive.type] then
                summary.by_type[archive.type] = 0
            end
            summary.by_type[archive.type] = summary.by_type[archive.type] + 1
        end
    end
    
    return summary
end
-- }}}

-- Main execution
-- Issue 7-003: Removed duplicate "Starting extraction" message (parent script already printed it)

local all_archives = detect_archives(DIR .. "/input")

if #all_archives == 0 then
    print(COLOR_RED .. "❌" .. COLOR_RESET .. " No valid archives found to extract")
    os.exit(1)
end

-- Issue 7-005: Select most recent archive per type, warn about skipped
local selected, skipped = select_archives_by_type(all_archives)

print("\n📊 Archive selection:")
print("   Total found: " .. #all_archives .. ", Selected: " .. #selected .. ", Skipped: " .. #skipped)

-- Warn about skipped archives with full yellow text
if #skipped > 0 then
    for _, archive in ipairs(skipped) do
        print(COLOR_YELLOW .. "   ⚠️  Skipped older: " .. relative_path(archive.path) ..
              " (" .. archive.mtime_date .. ")" .. COLOR_RESET)
    end
end

-- Extract only selected archives (most recent per type)
local summary = create_extraction_summary(selected, TEMP_DIR)

print("\n📋 Extraction summary:")
print("   Archives processed: " .. summary.extracted_archives .. "/" .. summary.total_archives)
for archive_type, count in pairs(summary.by_type) do
    print("   " .. archive_type .. ": " .. count .. " archive(s)")
    if summary.extraction_paths[archive_type] then
        print("   → " .. relative_path(summary.extraction_paths[archive_type]))
    end
end

-- Save extraction summary for other scripts
local summary_file = TEMP_DIR .. "/extraction-summary.json"
local f = io.open(summary_file, "w")
f:write(dkjson.encode(summary, { indent = true }))
f:close()

print("💾 Extraction summary saved: " .. relative_path(summary_file))
-- Issue 7-003: Removed redundant "extraction completed" line - summary already shows completion

if summary.extracted_archives == 0 then
    print(COLOR_RED .. "❌" .. COLOR_RESET .. " No archives could be extracted")
    os.exit(1)
end