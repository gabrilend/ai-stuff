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
        local archive_type = detect_archive_type(file)
        if archive_type then
            table.insert(archives, {
                path = file,
                type = archive_type,
                basename = file:match("([^/]+)%.zip$")
            })
            print("📦 Found " .. archive_type .. " archive: " .. file:match("([^/]+)%.zip$"))
        else
            print("⚠️  Unknown archive type: " .. file:match("([^/]+)%.zip$"))
        end
    end
    handle:close()
    
    return archives
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
            print("✅ Extracted media_attachments directory")
        else
            -- Try alternative: extract all and filter, or list-and-extract approach (suppress verbose output)
            local alt_cmd = string.format(
                "unzip -l '%s' 2>/dev/null | grep media_attachments | awk '{print $4}' | xargs -I{} unzip -o '%s' '{}' -d '%s' >/dev/null 2>&1",
                archive_info.path, archive_info.path, extract_dir)
            os.execute(alt_cmd)
            print("✅ Extracted media_attachments directory")
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
            print("✅ Extracted notes directory/text files")
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
            print("✅ Extracted: " .. file)
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
        print("✅ Successfully extracted " .. archive_info.type .. " data from " .. archive_info.basename)
        return temp_dir
    else
        print("❌ No extractable files found in " .. archive_info.basename)
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
print("🔄 Starting ZIP archive extraction...")
print("Project directory: " .. relative_path(DIR))
print("Temporary directory: " .. relative_path(TEMP_DIR))

local archives = detect_archives(DIR .. "/input")
print("\n📊 Archive scan results:")
print("   Total ZIP files found: " .. #archives)

if #archives == 0 then
    print("❌ No valid archives found to extract")
    os.exit(1)
end

-- Extract all archives
local summary = create_extraction_summary(archives, TEMP_DIR)

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
print("✅ ZIP archive extraction completed")

if summary.extracted_archives == 0 then
    print("❌ No archives could be extracted")
    os.exit(1)
end