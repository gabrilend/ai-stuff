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

-- Load configuration or use defaults
local config_file = DIR .. "/config/input-sources.json"

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

local notes_backup_path = "input/notes"
if io.open(config_file, "r") then
    local config_handle = io.open(config_file, "r")
    local config_content = config_handle:read("*a")
    config_handle:close()
    
    local config_data = dkjson.decode(config_content)
    if config_data and config_data.input_sources and config_data.input_sources.notes_source_path then
        notes_backup_path = config_data.input_sources.notes_source_path
    end
end

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
    
    -- Skip directories (check if it's a regular file)
    local file_handle = io.open(file_path, "r")
    if not file_handle then return false end
    file_handle:close()
    
    return true
end
-- }}}

print("📝 Starting notes extraction from: " .. relative_path(notes_dir))

-- Scan notes directory for files
local find_cmd = string.format("find %s -type f", shell_escape(notes_dir))
local find_handle = io.popen(find_cmd)

local poems_json = {}
local i = 1

for file_path in find_handle:lines() do
    if is_valid_note_file(file_path) then
        -- Read file content
        local file_handle = io.open(file_path, "r")
        if file_handle then
            local content = file_handle:read("*a")
            file_handle:close()
            
            -- Clean up content (remove excessive whitespace)
            content = content:gsub("\n\n+", "\n\n") -- Reduce multiple newlines
            content = content:gsub("^%s+", ""):gsub("%s+$", "") -- Trim whitespace
            
            if content and content ~= "" then
                local filename = file_path:match("([^/]+)$")
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
        by_category = { notes = #poems_json },
        content_warnings = {},  -- Notes typically don't have content warnings
        extraction_date = os.date("%Y-%m-%dT%H:%M:%SZ")
    }
}

local json_file = save_location .. "/poems.json"
local f = io.open(json_file, "w")
f:write(dkjson.encode(json_output, { indent = true }))
f:close()

print("✅ Notes extraction complete")
print("   📄 Generated: " .. relative_path(json_file))
print("   📊 Notes processed: " .. #poems_json)
-- }}}