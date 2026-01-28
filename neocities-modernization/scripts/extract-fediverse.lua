
-- Fediverse content extraction script
-- Parses ActivityPub JSON and extracts formatted posts with attachment metadata
--
-- ACTIVITYPUB ATTACHMENT FORMAT (Mastodon/W3C Standard):
-- Each Note object in outbox.json may contain an "attachment" array:
-- {
--   "type": "Create",
--   "object": {
--     "type": "Note",
--     "content": "<p>Post text here</p>",
--     "attachment": [
--       {
--         "type": "Document",
--         "mediaType": "image/png",           -- MIME type (image/png, image/jpeg, video/mp4, etc.)
--         "url": "https://server.com/media/files/123/456/789/original/abc123.png",
--         "name": "Alt text description",     -- User-provided alt text (may be null)
--         "blurhash": "LEHV6nWB2yk8...",      -- Blur hash for placeholder (optional)
--         "width": 1920,                      -- Image dimensions (optional)
--         "height": 1080
--       }
--     ]
--   }
-- }
--
-- URL PATH MAPPING:
-- The URL path structure maps directly to local media_attachments directory:
--   URL:   https://tech.lgbt/media/files/113/464/378/730/595/557/original/658cbf8cc6804a09.png
--   Local: input/media_attachments/files/113/464/378/730/595/557/original/658cbf8cc6804a09.png
--
-- The numeric segments (113/464/378/...) are derived from Mastodon's internal attachment ID
-- split into 3-digit chunks for filesystem distribution.

-- {{{ setup_dir_path
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

-- {{{ parse_args
-- Parse command line arguments for DIR, source override, and boost inclusion
local function parse_args(args)
    local dir = nil
    local source_override = nil
    local include_boosts = nil  -- nil means use config default
    local i = 1

    while i <= #(args or {}) do
        local a = args[i]
        if a == "--include-boosts" then
            include_boosts = true
            i = i + 1
        elseif a == "--no-boosts" then
            include_boosts = false
            i = i + 1
        elseif not a:match("^%-") then
            -- Positional arguments: first is DIR, second is source override
            if not dir then
                dir = a
            else
                source_override = a
            end
            i = i + 1
        else
            i = i + 1
        end
    end

    return dir, source_override, include_boosts
end
-- }}}

-- Get project directory and options from command line
local parsed_dir, OVERRIDE_SOURCE, CLI_INCLUDE_BOOSTS = parse_args(arg)
local DIR = setup_dir_path(parsed_dir)

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
local fediverse_backup_path = config.input_sources.fediverse_backup_path or "input/fediverse"

-- Privacy configuration from unified config
-- CLI flags --include-boosts/--no-boosts override config value
local function get_include_boosts()
    if CLI_INCLUDE_BOOSTS ~= nil then
        return CLI_INCLUDE_BOOSTS
    end
    return config.privacy.include_boosts or false
end

-- {{{ local function load_boost_content_cache
-- Load scraped boost content cache from assets/boost-content-cache.json
-- Returns a table mapping URI -> cached content data
local boost_content_cache = nil
local function load_boost_content_cache()
    if boost_content_cache then
        return boost_content_cache
    end

    local cache_path = DIR .. "/assets/boost-content-cache.json"
    local file = io.open(cache_path, "r")
    if not file then
        boost_content_cache = {}
        return boost_content_cache
    end

    local content = file:read("*a")
    file:close()

    local data, pos, err = dkjson.decode(content)
    if err or not data or not data.entries then
        boost_content_cache = {}
        return boost_content_cache
    end

    boost_content_cache = data.entries
    local count = 0
    for _ in pairs(boost_content_cache) do count = count + 1 end
    print("   📥 Loaded boost content cache: " .. count .. " entries")
    return boost_content_cache
end
-- }}}

local privacy_config = {
    mode = config.privacy.mode or "clean",
    anonymization_prefix = config.privacy.anonymization_prefix or "user-",
    include_boosts = get_include_boosts(),
    preserve_original_length = config.privacy.preserve_original_length or true,
    store_anonymization_map = config.privacy.store_anonymization_map or false,
    local_server_domain = config.privacy.local_server_domain or "tech.lgbt",
    debug_anonymization = false  -- Debug flag, not in config
}

-- Log boost inclusion status
if privacy_config.include_boosts then
    print("📤 Including fediverse boosts in extraction (CLI flag or config)")
end

-- Use override path if provided (for ZIP extraction), otherwise use configured path
local source_base_path
if OVERRIDE_SOURCE then
    source_base_path = OVERRIDE_SOURCE
    print("🔄 Using temporary extraction source: " .. relative_path(source_base_path))
else
    source_base_path = DIR .. "/" .. fediverse_backup_path
    print("🔄 Using configured source: " .. relative_path(source_base_path))
end

-- Set up file paths - check if we're already in extract directory
local file
if source_base_path:match("extract$") then
    file = source_base_path .. "/outbox.json"
else
    file = source_base_path .. "/extract/outbox.json"
end
local save_location = DIR .. "/" .. fediverse_backup_path .. "/files"

-- Load and parse ActivityPub data
print("🔄 Loading ActivityPub data from: " .. relative_path(file))
local opened_file = io.open(file, "r")
if not opened_file then
    print(COLOR_RED .. "❌" .. COLOR_RESET .. " Error: Could not open file " .. file)
    print("   Make sure the file exists and is readable")
    os.exit(1)
end

local opened_file_string = opened_file:read("*a")
opened_file:close()

local data = dkjson.decode(opened_file_string)
if not data then
    print(COLOR_RED .. "❌" .. COLOR_RESET .. " Error: Could not parse JSON data from " .. file)
    os.exit(1)
end

print(COLOR_GREEN .. "✅" .. COLOR_RESET .. " Loaded ActivityPub data: " .. (data.totalItems or #data.orderedItems) .. " activities")

-- Issue 6-031: Load poem exclusion filter
-- Excluded poems leave gaps in the ID sequence (tombstoning) to preserve stable anchor links
local poem_exclusions = exclusion_filter.load_default(DIR)
if poem_exclusions:count() > 0 then
    print(COLOR_YELLOW .. "🚫" .. COLOR_RESET .. " Exclusion filter loaded: " .. poem_exclusions:summary())
end

-- Privacy system variables
local user_anonymization_map = {}
local user_counter = 1

-- {{{ function normalize_username
local function normalize_username(username)
    -- Strip ID paths and normalize username variations for consistent mapping
    -- Remove paths like "/111978500472309702" from usernames
    local normalized = username:gsub("/[0-9]+", "")
    
    -- Handle specific username variations - map shorter forms to longer canonical forms
    -- This is based on observed patterns in the fediverse data
    local username_mappings = {
        ["wyatt"] = "wyatt8740",  -- Map @wyatt to @wyatt8740 for consistency
        -- Add other mappings here as needed
    }
    
    -- Apply username mapping if one exists
    if username_mappings[normalized] then
        normalized = username_mappings[normalized]
    end
    
    return normalized
end
-- }}}

-- {{{ function anonymize_mention
local function anonymize_mention(username, server)
    -- Normalize username to handle variations and ID paths
    local normalized_username = normalize_username(username)
    
    -- Debug logging to track anonymization mappings
    if privacy_config.debug_anonymization then
        io.stderr:write(string.format("DEBUG: anonymize_mention: '%s' -> '%s' @ '%s'\n", 
            username, normalized_username, server or "local"))
    end
    
    -- IMPORTANT: Consider users with same username on different servers as the same person
    -- This handles server migrations and cross-server mentions of the same person
    -- We only use the username for mapping, ignoring the server domain entirely
    local map_key = normalized_username  -- Just username, no server
    
    if not user_anonymization_map[map_key] then
        user_anonymization_map[map_key] = privacy_config.anonymization_prefix .. user_counter
        user_counter = user_counter + 1
        if privacy_config.debug_anonymization then
            io.stderr:write(string.format("  -> New mapping: %s = %s\n", map_key, user_anonymization_map[map_key]))
        end
    end
    return user_anonymization_map[map_key]
end
-- }}}

-- {{{ function process_mentions_for_privacy
local function process_mentions_for_privacy(content, privacy_mode)
    if privacy_mode ~= "clean" then
        return content, content -- Return original for dirty mode
    end
    
    local original_content = content
    local processed_content = content
    
    -- Handle HTML mention markup: <span class="h-card">...<a href="https://server/@user">@<span>user</span></a></span>
    processed_content = processed_content:gsub('<span class="h%-card"[^>]*>.-<a href="[^"]*://([^/"]+)/@([^"/?"]*)[^"]*"[^>]*>@<span>([^<]*)</span></a></span>', function(server, user, display_user)
        -- Use the URL username (user) which is more reliable than display text
        -- The URL contains the actual username, display might be shortened
        -- Extract only the username part, not any path segments or IDs after it
        return "@" .. anonymize_mention(user, server)
    end)
    
    -- Handle simpler HTML mentions: <a href="https://server/users/user" class="u-url mention">@<span>user</span></a>
    processed_content = processed_content:gsub('<a href="[^"]*://([^/"]+)/users/([^"/?"]*)[^"]*"[^>]*>@<span>([^<]*)</span></a>', function(server, user, display_user)
        -- Use the URL username (user) which is more reliable than display text
        -- Extract only the username part, not any path segments after it
        return "@" .. anonymize_mention(user, server)
    end)
    
    -- 6-027a Patterns: Handle plain text mentions as specified in sub-issue
    -- Pattern 1: Full mentions @user@domain.com  
    processed_content = processed_content:gsub("@([%w%.%-_]+)@([%w%.%-]+%.%w+)", function(user, server)
        return "@" .. anonymize_mention(user, server)
    end)
    
    -- Pattern 2: Multiple usernames at start - handle sequences like "@user1 @user2 @user3 content"
    -- This pattern handles multiple consecutive mentions at the beginning
    while processed_content:match("^@[%w%.%-_]+%s+@") do
        processed_content = processed_content:gsub("^@([%w%.%-_]+)(%s+)", function(user, space)
            return "@" .. anonymize_mention(user, nil) .. space
        end)
    end
    
    -- Pattern 3: Single username at start (after multiple handling)
    processed_content = processed_content:gsub("^@([%w%.%-_]+)%s", function(user)
        return "@" .. anonymize_mention(user, nil) .. " "
    end)
    
    -- Pattern 4: Local mentions @user (same server, followed by whitespace)
    processed_content = processed_content:gsub("@([%w%.%-_]+)%s", function(user)
        return "@" .. anonymize_mention(user, nil) .. " "
    end)
    
    -- Pattern 5: @user at end of content (no trailing space)
    processed_content = processed_content:gsub("@([%w%.%-_]+)$", function(user)
        return "@" .. anonymize_mention(user, nil)
    end)
    
    -- Pattern 6: Catch any remaining @username patterns in the middle of text
    -- This catches mentions followed by punctuation or other non-space characters
    processed_content = processed_content:gsub("@([%w%.%-_]+)([^%w%.%-_@])", function(user, following_char)
        return "@" .. anonymize_mention(user, nil) .. following_char
    end)
    
    return processed_content, original_content
end
-- }}}

-- {{{ function categorize_activity
local function categorize_activity(activity)
    if activity.type == "Create" and activity.object and activity.object.type == "Note" then
        return "original_post", activity.object
    elseif activity.type == "Announce" then
        return "boost", activity.object
    else
        return "unknown", nil
    end
end
-- }}}

-- {{{ function extract_boost_content
local function extract_boost_content(announce_activity)
    local boosted_object = announce_activity.object

    -- If object is URI, check cache for scraped content first
    if type(boosted_object) == "string" then
        local cache = load_boost_content_cache()
        local cached = cache[boosted_object]

        if cached and cached.content then
            -- Use cached scraped content instead of placeholder
            -- The cached content is HTML that will be processed by clean_html later
            return {
                type = "cached_external_boost",
                uri = boosted_object,
                boost_timestamp = announce_activity.published,
                content = cached.content,
                content_warning = cached.summary,  -- CW from original post
                sensitive = cached.sensitive,
                original_published = cached.published,
                original_author = cached.attributed_to,
                metadata = {
                    is_boost = true,
                    boost_type = "cached_external",
                    original_uri = boosted_object,
                    boost_date = announce_activity.published,
                    scraped_at = cached.scraped_at,
                    original_author = cached.attributed_to
                }
            }
        end

        -- No cache entry - fall back to placeholder
        return {
            type = "external_boost",
            uri = boosted_object,
            boost_timestamp = announce_activity.published,
            content = "External post: " .. boosted_object,
            metadata = {
                is_boost = true,
                boost_type = "external",
                original_uri = boosted_object,
                boost_date = announce_activity.published
            }
        }
    end
    
    -- If object is embedded, extract full content
    if type(boosted_object) == "table" and boosted_object.content then
        return {
            type = "embedded_boost", 
            content = boosted_object.content,
            original_author = boosted_object.attributedTo,
            boost_timestamp = announce_activity.published,
            original_timestamp = boosted_object.published,
            metadata = {
                is_boost = true,
                boost_type = "embedded",
                original_author = boosted_object.attributedTo,
                boost_date = announce_activity.published,
                original_date = boosted_object.published
            }
        }
    end
    
    return nil
end
-- }}}

-- {{{ local function clean_html
local function clean_html(content)
    -- Clean HTML markup to get plain text (what Mastodon counts)
    local clean = content:gsub("<p>", "\n\n")
    -- Issue 6-032: Handle all BR tag variants (<br>, <br/>, <br />)
    -- Mastodon uses XHTML-style <br /> which was causing words to run together
    clean = clean:gsub("<br%s*/?>", "\n")
    clean = clean:gsub("&amp;", "&")
    clean = clean:gsub("&#39;", "'")
    clean = clean:gsub("&quot;", "\"")
    clean = clean:gsub("&lt;", "<")
    clean = clean:gsub("&gt;", ">")
    clean = clean:gsub("\\\"", "\"")
    clean = clean:gsub(" _^", "^_^")
    clean = clean:gsub("^^_^", "^_^")
    clean = clean:gsub("<[^>]+>", "")
    clean = clean:gsub("^\n+", ""):gsub("\n+$", "") -- Trim newlines
    return clean
end
-- }}}

-- {{{ function process_fediverse_content
local function process_fediverse_content(raw_content, cw, privacy_mode)
   if not raw_content then return nil end

   -- Process mentions for privacy BEFORE HTML cleaning to preserve structure
   local privacy_processed_content, original_content = process_mentions_for_privacy(raw_content, privacy_mode)

   -- Clean HTML for display content (after anonymization)
   local clean_content = clean_html(privacy_processed_content)

   -- Clean HTML for golden poem calculation (before anonymization, preserves @mentions)
   local golden_poem_content = clean_html(original_content)

   return {
       content = clean_content,
       raw_content = raw_content,
       original_content = original_content,
       golden_poem_content = golden_poem_content,  -- HTML-cleaned, pre-anonymization (for 1024 char count)
       content_warning = (cw and cw ~= "") and cw or nil,
       privacy_applied = (privacy_mode == "clean")
   }
end
-- }}}

-- {{{ function extract_date
local function extract_date(timestamp)
  return timestamp and timestamp:match("(%d%d%d%d%-%d%d%-%d%d)") or "0000-00-00"
end
-- }}}

-- {{{ function extract_full_date
local function extract_full_date(timestamp)
    if timestamp then
        return timestamp:match("(%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d)") or timestamp
    end
    return os.date("%Y-%m-%dT%H:%M:%S")
end
-- }}}

-- {{{ function generate_poem_metadata
local function generate_poem_metadata(content, cw, source_data, golden_poem_content)
    -- Golden poem calculation: HTML-cleaned content (before anonymization) + content warning text
    -- This matches what Mastodon counts: text content + @mentions + CW text
    local golden_content = golden_poem_content or content
    local golden_poem_length = string.len(golden_content)

    -- Add content warning text to golden poem calculation (exclude "CW: " prefix as per 6-027)
    if cw and cw ~= "" then
        golden_poem_length = golden_poem_length + string.len(cw)
    end

    local metadata = {
        character_count = string.len(content), -- Display content length (post-privacy)
        golden_poem_character_count = golden_poem_length, -- For golden poem qualification (1024 chars)
        is_golden_poem = (golden_poem_length == 1024),
        word_count = select(2, content:gsub("%S+", "")),
        has_content_warning = (cw and cw ~= ""),
        extraction_timestamp = os.date("%Y-%m-%dT%H:%M:%SZ")
    }

    if source_data and source_data.published then
        metadata.creation_date = extract_full_date(source_data.published)
    end

    return metadata
end
-- }}}

-- {{{ function extract_attachments
local function extract_attachments(content_object)
    -- Extract media attachment metadata from ActivityPub Note object
    -- Returns nil if no attachments, or array of attachment metadata
    if not content_object.attachment then
        return nil
    end

    local attachments = {}
    for _, attachment in ipairs(content_object.attachment) do
        -- Only process Document type attachments (images, videos, etc.)
        if attachment.type == "Document" and attachment.url then
            -- Extract the relative path from the URL
            -- URL format: https://server.com/media/files/123/456/789/original/filename.ext
            -- We extract: files/123/456/789/original/filename.ext
            local relative_path = attachment.url:match("/files/(.+)$")
            if relative_path then
                relative_path = "files/" .. relative_path
            end

            local attachment_entry = {
                media_type = attachment.mediaType,
                url = attachment.url,
                relative_path = relative_path,
                alt_text = attachment.name,  -- May be nil if no alt text provided
                width = attachment.width,
                height = attachment.height,
                blurhash = attachment.blurhash
            }
            table.insert(attachments, attachment_entry)
        end
    end

    if #attachments > 0 then
        return attachments
    end
    return nil
end
-- }}}

local poems_json = {}
local boost_count = 0
local original_count = 0
local attachment_count = 0
local excluded_count = 0  -- Issue 6-031: Track excluded poems

print("🔄 Processing activities with privacy mode: " .. privacy_config.mode)
print("🔄 Include boosts: " .. tostring(privacy_config.include_boosts))

for key, activity in pairs(data.orderedItems) do
    local activity_type, content_object = categorize_activity(activity)

    -- Issue 6-031: Generate poem ID early for exclusion check
    -- IDs are assigned before exclusion filter runs, preserving stable anchors
    local poem_id = string.format("%04d", key)

    if activity_type == "original_post" then
        -- Issue 6-031: Check exclusion filter (tombstone - leaves gap in ID sequence)
        if poem_exclusions:is_excluded("fediverse", poem_id) then
            excluded_count = excluded_count + 1
            goto continue
        end

        -- Process original posts (Create activities)
        local cw = content_object.summary or ""
        local content = content_object.content

        -- Process content with privacy settings
        local processed_content = process_fediverse_content(content, cw, privacy_config.mode)
        if processed_content then
            local poem_entry = {
                id = poem_id,
                category = "fediverse",
                source_file = "outbox.json",
                creation_date = extract_full_date(activity.published),
                content_warning = processed_content.content_warning,
                content = processed_content.content,
                raw_content = processed_content.raw_content,
                metadata = generate_poem_metadata(processed_content.content, cw, activity, processed_content.golden_poem_content)
            }

            -- Add privacy metadata
            if processed_content.privacy_applied then
                poem_entry.metadata.privacy_mode = privacy_config.mode
                poem_entry.metadata.mentions_anonymized = true
                if privacy_config.preserve_original_length then
                    poem_entry.metadata.original_character_count = string.len(processed_content.original_content)
                end
            end

            -- Extract media attachments from the Note object
            -- Attachments contain image/video URLs that map to local media_attachments directory
            local attachments = extract_attachments(content_object)
            if attachments then
                poem_entry.attachments = attachments
                poem_entry.metadata.has_attachments = true
                poem_entry.metadata.attachment_count = #attachments
                attachment_count = attachment_count + #attachments
            end

            table.insert(poems_json, poem_entry)
            original_count = original_count + 1
        end
        
    elseif activity_type == "boost" and privacy_config.include_boosts then
        -- Issue 6-031: Check exclusion filter for boosts too
        if poem_exclusions:is_excluded("fediverse", poem_id) then
            excluded_count = excluded_count + 1
            goto continue
        end

        -- Process boosted content when enabled
        local boost_content = extract_boost_content(activity)
        if boost_content then
            -- Apply privacy processing to boost content too
            local processed_boost = process_fediverse_content(boost_content.content, "", privacy_config.mode)
            if processed_boost then
                local boost_entry = {
                    id = poem_id,
                    category = "fediverse_boost",
                    source_file = "outbox.json",
                    creation_date = extract_full_date(activity.published),
                    content = processed_boost.content,
                    raw_content = processed_boost.raw_content,
                    metadata = boost_content.metadata
                }
                
                -- Add privacy metadata for boosts
                if processed_boost.privacy_applied then
                    boost_entry.metadata.privacy_mode = privacy_config.mode
                    boost_entry.metadata.mentions_anonymized = true
                end
                
                table.insert(poems_json, boost_entry)
                boost_count = boost_count + 1
            end
        end
    end

    ::continue::
end

-- {{{ Generate JSON output for HTML generation
-- Create output directory
os.execute("mkdir -p " .. save_location)

-- Count posts with attachments for statistics
local posts_with_attachments = 0
for _, poem in ipairs(poems_json) do
    if poem.attachments then
        posts_with_attachments = posts_with_attachments + 1
    end
end

-- Generate JSON output
local json_output = {
    poems = poems_json,
    extraction_summary = {
        total_poems = #poems_json,
        original_posts = original_count,
        boosted_posts = boost_count,
        poems_excluded = excluded_count,  -- Issue 6-031: Excluded poem count
        by_category = {
            fediverse = original_count,
            fediverse_boost = boost_count
        },
        content_warnings = {},
        extraction_date = os.date("%Y-%m-%dT%H:%M:%SZ"),
        privacy_settings = {
            mode = privacy_config.mode,
            include_boosts = privacy_config.include_boosts,
            mentions_anonymized = (privacy_config.mode == "clean"),
            anonymization_prefix = privacy_config.anonymization_prefix
        },
        attachment_statistics = {
            total_attachments = attachment_count,
            posts_with_attachments = posts_with_attachments
        }
    }
}

-- Collect unique content warnings
local cw_set = {}
for _, poem in ipairs(poems_json) do
    if poem.content_warning then
        cw_set[poem.content_warning] = true
    end
end
for cw, _ in pairs(cw_set) do
    table.insert(json_output.extraction_summary.content_warnings, cw)
end

local json_file = save_location .. "/poems.json"
local f = io.open(json_file, "w")
f:write(dkjson.encode(json_output, { indent = true }))
f:close()

print(COLOR_GREEN .. "✅" .. COLOR_RESET .. " Fediverse extraction complete")
print("   📄 Generated: " .. relative_path(json_file))
print("   📊 Total posts processed: " .. #poems_json)
print("   📝 Original posts: " .. original_count)
print("   🔄 Boosted posts: " .. boost_count)
if excluded_count > 0 then
    print("   🚫 Excluded posts: " .. excluded_count .. " (tombstoned)")
end
print("   🖼️  Attachments found: " .. attachment_count .. " in " .. posts_with_attachments .. " posts")
print("   🚨 Content warnings: " .. #json_output.extraction_summary.content_warnings)
print("   🔒 Privacy mode: " .. privacy_config.mode)
if privacy_config.mode == "clean" then
    print("   🎭 Mentions anonymized: " .. user_counter - 1 .. " users")
end
-- }}}

