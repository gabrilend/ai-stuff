
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

-- Set up package path to find libs
package.path = DIR .. "/libs/?.lua;" .. package.path
local dkjson = require("dkjson")
local exclusion_filter = require("exclusion-filter")

-- Issue 10-003: Load unified config from config.lua
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
local messages_backup_path = config.input_sources.messages_backup_path or "input/messages"

-- Use override path if provided (for ZIP extraction), otherwise use configured path
local source_base_path
if OVERRIDE_SOURCE then
    source_base_path = OVERRIDE_SOURCE
    print("🔄 Using temporary extraction source: " .. relative_path(source_base_path))
else
    source_base_path = DIR .. "/" .. messages_backup_path
    print("🔄 Using configured source: " .. relative_path(source_base_path))
end

-- Set up file paths (try multiple possible locations for export.json)
-- Priority: 1. source_base_path/extract/export.json (backup dir)
--           2. source_base_path/extract/export/export.json (nested backup)
--           3. DIR/input/extract/export/export.json (temp extraction from run-messages)
local file = source_base_path .. "/extract/export.json"
local file_handle = io.open(file, "r")
if not file_handle then
    file = source_base_path .. "/extract/export/export.json"
    file_handle = io.open(file, "r")
end
-- Issue 8-054: Fallback to temp extraction location (run-messages extracts to input/extract/)
if not file_handle then
    file = DIR .. "/input/extract/export/export.json"
    file_handle = io.open(file, "r")
    if file_handle then
        print("🔄 Found export.json in temp extraction: " .. relative_path(file))
    end
end
local save_location = DIR .. "/" .. messages_backup_path .. "/files"

if not file_handle then
    print(COLOR_RED .. "❌" .. COLOR_RESET .. " Error: Could not find export.json at any expected location")
    print("   Tried: " .. relative_path(source_base_path .. "/extract/export.json"))
    print("   Tried: " .. relative_path(source_base_path .. "/extract/export/export.json"))
    print("   Tried: " .. relative_path(DIR .. "/input/extract/export/export.json"))
    os.exit(1)
end

local opened_file_string = file_handle:read("*a")
io.close(file_handle)

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

-- Issue 6-031: Load poem exclusion filter
-- For messages, exclusion IDs are the message index (numeric)
local poem_exclusions = exclusion_filter.load_default(DIR)
if poem_exclusions:count("messages") > 0 then
    print(COLOR_YELLOW .. "🚫" .. COLOR_RESET .. " Messages exclusion filter: " .. poem_exclusions:count("messages") .. " entries")
end

-- {{{ Issue 8-054: Build image lookup from extract/images/ directory
-- Matrix exports store decrypted images alongside export.json
-- Matrix renames files to: {original_basename}-{M-D-YYYY} at {H-MM-SS AM/PM}.{ext}
-- We need to map both exact and prefix matches
local function build_image_lookup(extract_dir)
    local lookup = {}
    local images_dir = extract_dir .. "/images"
    local handle = io.popen('ls "' .. images_dir .. '" 2>/dev/null')
    if handle then
        for filename in handle:lines() do
            local full_path = images_dir .. "/" .. filename
            -- Exact match (unlikely but possible)
            lookup[filename] = full_path

            -- Extract original filename by removing Matrix timestamp suffix
            -- Pattern: {original}-{M-D-YYYY} at {time}.{ext} → {original}.{ext}
            local basename, ext = filename:match("^(.+)%-[%d]+%-[%d]+%-[%d]+ at .+%.([^.]+)$")
            if basename and ext then
                local original_name = basename .. "." .. ext
                lookup[original_name] = full_path
            end
        end
        handle:close()
    end
    return lookup
end

-- Build lookup from the extract directory
-- Issue 8-054: Try multiple possible image locations
-- 1. Override source (for temporary extraction)
-- 2. Persistent images directory in messages backup
-- 3. Temporary extraction directory in input/
local extract_dir = OVERRIDE_SOURCE or source_base_path
local image_lookup = build_image_lookup(extract_dir)
-- Fallback: check persistent images directory
if next(image_lookup) == nil then
    image_lookup = build_image_lookup(source_base_path)
end
-- Fallback: check input/extract/export (where run-messages puts it)
if next(image_lookup) == nil then
    image_lookup = build_image_lookup(DIR .. "/input/extract/export")
end
local image_lookup_count = 0
for _ in pairs(image_lookup) do image_lookup_count = image_lookup_count + 1 end
if image_lookup_count > 0 then
    print(COLOR_BLUE .. "ℹ️" .. COLOR_RESET .. " Found " .. image_lookup_count .. " images in extract/images/")
end
-- }}}

-- {{{ Issue 8-054: Detect if content is a bare filename
-- Returns true if the body looks like just a filename (no meaningful text)
local function is_bare_filename(body)
    if not body then return false end
    -- Match: word characters, dots, hyphens, underscores followed by extension
    -- Must not contain spaces (captions have spaces)
    return body:match("^[%w%.%-_]+%.[%w]+$") ~= nil
end
-- }}}

local excluded_count = 0
local image_count = 0  -- Issue 8-054: Track image messages
local poems_json = {}
local i = 1

for key, value in pairs(data.messages) do
   -- Issue 6-031: Generate poem ID early for exclusion check
   local poem_id = string.format("%04d", i)

   -- Issue 6-031: Check exclusion filter (tombstone - leaves gap in ID sequence)
   if poem_exclusions:is_excluded("messages", poem_id) then
       excluded_count = excluded_count + 1
       i = i + 1  -- Increment to maintain ID stability (tombstoning)
       goto continue
   end

   local content = value.content.body or " "
   local msgtype = value.content.msgtype

   -- Issue 8-054: Handle media messages (m.image, m.video, m.audio, m.file)
   local attachments = nil
   if msgtype == "m.image" or msgtype == "m.video" or msgtype == "m.audio" or msgtype == "m.file" then
       local filename = value.content.body or ""
       local local_path = image_lookup[filename]

       -- Build attachment metadata (matching fediverse attachment format)
       local attachment = {
           media_type = (value.content.info and value.content.info.mimetype) or "application/octet-stream",
           width = value.content.info and value.content.info.w,
           height = value.content.info and value.content.info.h,
           alt_text = nil,  -- Matrix doesn't provide alt-text for images
           relative_path = local_path
       }
       attachments = { attachment }

       -- If the body is just a bare filename, replace with descriptive placeholder
       -- This gives the poem meaningful content for embedding generation
       if is_bare_filename(filename) then
           local media_label = "Image"
           if msgtype == "m.video" then media_label = "Video"
           elseif msgtype == "m.audio" then media_label = "Audio"
           elseif msgtype == "m.file" then media_label = "File"
           end
           content = "[" .. media_label .. ": " .. filename .. "]"
           image_count = image_count + 1
       end
   end

   -- Generate JSON format for HTML generation
   local poem_entry = {
       id = poem_id,
       category = "messages",
       source_file = "export.json",
       creation_date = generate_iso_timestamp(tonumber(value.origin_server_ts)),
       content_warning = nil,
       content = content,
       raw_content = content,  -- Messages don't have HTML markup
       metadata = generate_poem_metadata(content, value),
       attachments = attachments  -- Issue 8-054: May be nil for text-only messages
   }
   table.insert(poems_json, poem_entry)

   i = i + 1
   ::continue::
end

-- {{{ Generate JSON output for HTML generation
-- Create output directory
os.execute("mkdir -p " .. save_location)

-- Generate JSON output
local json_output = {
    poems = poems_json,
    extraction_summary = {
        total_poems = #poems_json,
        poems_excluded = excluded_count,  -- Issue 6-031: Excluded poem count
        image_messages = image_count,  -- Issue 8-054: Media message count
        by_category = { messages = #poems_json },
        content_warnings = {},  -- Messages typically don't have content warnings
        extraction_date = os.date("%Y-%m-%dT%H:%M:%SZ")
    }
}

local json_file = save_location .. "/poems.json"
local f = io.open(json_file, "w")
f:write(dkjson.encode(json_output, { indent = true }))
f:close()

print(COLOR_GREEN .. "✅" .. COLOR_RESET .. " Messages extraction complete")
print("   📄 Generated: " .. relative_path(json_file))
print("   📊 Messages processed: " .. #poems_json)
if image_count > 0 then
    print("   🖼️  Media messages: " .. image_count .. " (with attachments)")
end
if excluded_count > 0 then
    print("   🚫 Excluded: " .. excluded_count .. " (tombstoned)")
end
-- }}}

