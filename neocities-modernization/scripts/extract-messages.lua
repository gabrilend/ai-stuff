
-- Messages content extraction script
-- Parses exported message JSON and extracts formatted content

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

local messages_backup_path = "input/messages"
if io.open(config_file, "r") then
    local config_handle = io.open(config_file, "r")
    local config_content = config_handle:read("*a")
    config_handle:close()
    
    local config_data = dkjson.decode(config_content)
    if config_data and config_data.input_sources and config_data.input_sources.messages_backup_path then
        messages_backup_path = config_data.input_sources.messages_backup_path
    end
end

-- Use override path if provided (for ZIP extraction), otherwise use configured path
local source_base_path
if OVERRIDE_SOURCE then
    source_base_path = OVERRIDE_SOURCE
    print("🔄 Using temporary extraction source: " .. relative_path(source_base_path))
else
    source_base_path = DIR .. "/" .. messages_backup_path
    print("🔄 Using configured source: " .. relative_path(source_base_path))
end

-- Set up file paths (try export.json first, fallback to export/export.json)
local file = source_base_path .. "/extract/export.json"
if not io.open(file, "r") then
    file = source_base_path .. "/extract/export/export.json"
end
local save_location = DIR .. "/" .. messages_backup_path .. "/files"

local opened_file = io.open(file, "r")
local opened_file_string = opened_file:read("*a")
io.close(opened_file)

local data = dkjson.decode(opened_file_string)
local messages = {}

-- {{{ function format_date
local function format_date(timestamp)
   if type(timestamp) ~= "number" then
      print("Warning: Invalid timestamp, using current time.")
      timestamp = os.time()
   end
   return os.date("%Y-%m-%d %H:%M:%S", timestamp)
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

-- {{{ function generate_timestamp
local function generate_timestamp(timestamp)
   if timestamp then
      timestamp = math.floor(timestamp / 1000)  -- Convert ms → s
   else
      timestamp = os.time()  -- Fallback
   end
   return format_date(timestamp)
end
-- }}}

-- {{{ function generate_iso_timestamp
local function generate_iso_timestamp(timestamp)
   if timestamp then
      timestamp = math.floor(timestamp / 1000)  -- Convert ms → s
   else
      timestamp = os.time()  -- Fallback
   end
   return format_iso_date(timestamp)
end
-- }}}

-- {{{ function generate_poem_metadata
local function generate_poem_metadata(content, source_data)
    local metadata = {
        character_count = string.len(content),
        word_count = select(2, content:gsub("%S+", "")),
        has_content_warning = false,  -- Messages typically don't have CW
        extraction_timestamp = os.date("%Y-%m-%dT%H:%M:%SZ")
    }
    
    if source_data and source_data.origin_server_ts then
        metadata.creation_date = generate_iso_timestamp(tonumber(source_data.origin_server_ts))
    end
    
    return metadata
end
-- }}}

local poems_json = {}
local i = 1

for key, value in pairs(data.messages) do
   local content = value.content.body or " "
   
   -- Generate JSON format for HTML generation
   local poem_entry = {
       id = string.format("%04d", i),
       category = "messages",
       source_file = "export.json",
       creation_date = generate_iso_timestamp(tonumber(value.origin_server_ts)),
       content_warning = nil,
       content = content,
       raw_content = content,  -- Messages don't have HTML markup
       metadata = generate_poem_metadata(content, value)
   }
   table.insert(poems_json, poem_entry)
   
   i = i + 1
end

-- {{{ Generate JSON output for HTML generation
-- Create output directory
os.execute("mkdir -p " .. save_location)

-- Generate JSON output
local json_output = {
    poems = poems_json,
    extraction_summary = {
        total_poems = #poems_json,
        by_category = { messages = #poems_json },
        content_warnings = {},  -- Messages typically don't have content warnings
        extraction_date = os.date("%Y-%m-%dT%H:%M:%SZ")
    }
}

local json_file = save_location .. "/poems.json"
local f = io.open(json_file, "w")
f:write(dkjson.encode(json_output, { indent = true }))
f:close()

print("✅ Messages extraction complete")
print("   📄 Generated: " .. relative_path(json_file))
print("   📊 Messages processed: " .. #poems_json)
-- }}}

