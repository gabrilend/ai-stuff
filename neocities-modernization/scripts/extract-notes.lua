-- Notes content extraction script
-- Processes text files from notes directory and extracts formatted content

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
local OVERRIDE_SOURCE = arg and arg[2] -- Optional override for temporary extraction

-- Set up package path to find libs
package.path = DIR .. "/libs/?.lua;" .. package.path
local dkjson = require("dkjson")
local exclusion_filter = require("exclusion-filter")

-- Issue 10-003: Load unified config from config/main.lua
local config_loader = require("config-loader")
config_loader.set_project_root(DIR)
local config = config_loader.load()

-- ANSI color codes for terminal output
local COLOR_GREEN = "\027[92m"    -- Bright green for success (✓, ✅)
local COLOR_BLUE = "\027[94m"     -- Bright blue for info (ℹ️)
local COLOR_RED = "\027[91m"      -- Bright red for errors (✗, ❌)
local COLOR_YELLOW = "\027[93m"   -- Bright yellow for warnings (⚠️)
local COLOR_RESET = "\027[0m"     -- Reset to default

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

-- Load configuration from unified config
local notes_backup_path = config.input_sources.notes_source_path or "input/notes"

-- Use override path if provided (for ZIP extraction), otherwise use configured path
local source_base_path
if OVERRIDE_SOURCE then
    source_base_path = OVERRIDE_SOURCE
    print("🔄 Using temporary extraction source: " .. relative_path(source_base_path))
else
    source_base_path = DIR .. "/" .. notes_backup_path
    print("🔄 Using configured source: " .. relative_path(source_base_path))
end

-- Set up paths
local notes_dir = source_base_path
local save_location = DIR .. "/" .. notes_backup_path .. "/files"

-- {{{ function shell_escape
local function shell_escape(str)
    -- Escape single quotes for shell: ' becomes '\''
    -- This ends the quote, adds an escaped quote, and starts a new quote
    return "'" .. str:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ function get_file_mtime
local function get_file_mtime(file_path)
    -- Use stat command to get modification time
    local stat_cmd = string.format("stat -c %%Y %s 2>/dev/null", shell_escape(file_path))
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

    -- Fallback to current time if stat fails
    return os.time()
end
-- }}}

-- {{{ function format_iso_date
local function format_iso_date(timestamp)
    if type(timestamp) ~= "number" then
        timestamp = os.time()
    end
    return os.date("%Y-%m-%dT%H:%M:%SZ", timestamp)
end
-- }}}

-- {{{ function generate_poem_metadata
local function generate_poem_metadata(content, file_path)
    local mtime = get_file_mtime(file_path)
    
    local metadata = {
        character_count = string.len(content),
        word_count = select(2, content:gsub("%S+", "")),
        has_content_warning = false,  -- Notes typically don't have explicit CW
        extraction_timestamp = os.date("%Y-%m-%dT%H:%M:%SZ"),
        source_file = file_path:match("([^/]+)$"), -- Just filename
        file_modification_time = format_iso_date(mtime)
    }
    
    return metadata
end
-- }}}

-- {{{ function is_valid_note_file
local function is_valid_note_file(file_path)
    -- Skip hidden files, backup files, and directories
    local filename = file_path:match("([^/]+)$")
    if not filename then return false end
    
    -- Skip hidden files (starting with .)
    if filename:match("^%.") then return false end
    
    -- Skip backup files (.un~, .swp, etc.)
    if filename:match("%.un~$") or filename:match("%.swp$") then return false end

    -- Skip JSON files (including our own output)
    if filename:match("%.json$") then return false end

    -- Skip directories (check if it's a regular file)
    local file_handle = io.open(file_path, "r")
    if not file_handle then return false end
    file_handle:close()

    return true
end
-- }}}

print("📝 Starting notes extraction from: " .. relative_path(notes_dir))

-- Issue 6-031: Load poem exclusion filter
-- For notes, exclusion IDs are filenames (without extension)
local poem_exclusions = exclusion_filter.load_default(DIR)
if poem_exclusions:count("notes") > 0 then
    print(COLOR_YELLOW .. "🚫" .. COLOR_RESET .. " Notes exclusion filter: " .. poem_exclusions:count("notes") .. " entries")
end

local excluded_count = 0

-- Scan notes directory for files (exclude files/ subdirectory to avoid reading our own output)
local find_cmd = string.format("find %s -type f -not -path '*/files/*'", shell_escape(notes_dir))
local find_handle = io.popen(find_cmd)

local poems_json = {}
local i = 1

for file_path in find_handle:lines() do
    if is_valid_note_file(file_path) then
        local filename = file_path:match("([^/]+)$")

        -- Issue 6-031: Notes use filename (without extension) as exclusion ID
        -- This matches the human-readable format in config/excluded-poems.txt
        local note_id = filename:match("(.+)%..+$") or filename
        if poem_exclusions:is_excluded("notes", note_id) then
            excluded_count = excluded_count + 1
            goto continue
        end

        -- Read file content
        local file_handle = io.open(file_path, "r")
        if file_handle then
            local content = file_handle:read("*a")
            file_handle:close()

            -- Clean up content (remove excessive whitespace)
            content = content:gsub("\n\n+", "\n\n") -- Reduce multiple newlines
            content = content:gsub("^%s+", ""):gsub("%s+$", "") -- Trim whitespace

            if content and content ~= "" then
                local mtime = get_file_mtime(file_path)
                
                -- Generate JSON format for HTML generation
                local poem_entry = {
                    id = string.format("%04d", i),
                    category = "notes",
                    source_file = filename,
                    creation_date = format_iso_date(mtime),
                    content_warning = nil, -- Notes typically don't have CW
                    content = content,
                    raw_content = content, -- Notes don't have markup
                    metadata = generate_poem_metadata(content, file_path)
                }
                table.insert(poems_json, poem_entry)
                i = i + 1
            end
        end
    end

    ::continue::
end

find_handle:close()

-- {{{ Generate JSON output for HTML generation
-- Create output directory
os.execute("mkdir -p " .. shell_escape(save_location))

-- Generate JSON output
local json_output = {
    poems = poems_json,
    extraction_summary = {
        total_poems = #poems_json,
        poems_excluded = excluded_count,  -- Issue 6-031: Excluded poem count
        by_category = { notes = #poems_json },
        content_warnings = {},  -- Notes typically don't have content warnings
        extraction_date = os.date("%Y-%m-%dT%H:%M:%SZ")
    }
}

local json_file = save_location .. "/poems.json"
local f = io.open(json_file, "w")
f:write(dkjson.encode(json_output, { indent = true }))
f:close()

print(COLOR_GREEN .. "✅" .. COLOR_RESET .. " Notes extraction complete")
print("   📄 Generated: " .. relative_path(json_file))
print("   📊 Notes processed: " .. #poems_json)
if excluded_count > 0 then
    print("   🚫 Excluded: " .. excluded_count .. " (tombstoned)")
end
-- }}}