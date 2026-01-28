#!/usr/bin/env lua

-- Boost Content Scraper
-- ====================
-- This script fetches the actual content of external fediverse boost URIs.
-- It respects rate limits (1 second between requests, 2 seconds for same domain)
-- and caches results to avoid re-scraping. Output is saved to assets/boost-content-cache.json
-- for use by extract-fediverse.lua during poem extraction.
--
-- Usage:
--   lua scripts/scrape-boost-content.lua [DIR] [--force]
--
-- The --force flag will re-scrape URIs even if they are already cached.

-- {{{ local function setup_dir_path
local function setup_dir_path(provided_dir)
    -- Return provided dir if it's a valid path (not a flag)
    if provided_dir and not provided_dir:match("^%-%-") then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

-- Script configuration
local DIR = setup_dir_path(arg and arg[1])
local FORCE_RESCRAPE = false
local DRY_RUN = false
local MAX_SCRAPE = nil  -- Limit number of URIs to scrape (for testing)

-- Parse arguments
for i = 1, #arg do
    if arg[i] == "--force" then
        FORCE_RESCRAPE = true
    elseif arg[i] == "--dry-run" then
        DRY_RUN = true
    elseif arg[i]:match("^--max=(%d+)$") then
        MAX_SCRAPE = tonumber(arg[i]:match("^--max=(%d+)$"))
    end
end

-- Load required libraries
package.path = DIR .. "/libs/?.lua;" .. package.path
local dkjson = require("dkjson")

-- Configuration
local CONFIG = {
    -- Rate limiting
    delay_between_requests = 1.0,     -- seconds between any two requests
    delay_same_domain = 2.0,          -- additional delay when hitting same domain consecutively
    request_timeout = 10,             -- curl timeout in seconds

    -- File paths
    poems_json_path = DIR .. "/input/fediverse/files/poems.json",
    cache_path = DIR .. "/assets/boost-content-cache.json",

    -- HTTP settings
    user_agent = "NeocitiesModernization/1.0 (Fediverse content aggregator for poetry project)",
    accept_header = "application/activity+json",

    -- Retry settings
    max_retries = 2,
    retry_delay = 3.0,
}

-- {{{ local function read_json_file
local function read_json_file(path)
    local file = io.open(path, "r")
    if not file then
        return nil, "Could not open file: " .. path
    end
    local content = file:read("*a")
    file:close()

    local data, pos, err = dkjson.decode(content)
    if err then
        return nil, "JSON parse error: " .. tostring(err)
    end
    return data
end
-- }}}

-- {{{ local function write_json_file
local function write_json_file(path, data)
    local json_str = dkjson.encode(data, { indent = true })
    local file = io.open(path, "w")
    if not file then
        return false, "Could not write file: " .. path
    end
    file:write(json_str)
    file:close()
    return true
end
-- }}}

-- {{{ local function extract_domain
local function extract_domain(uri)
    -- Extract domain from URI like https://mastodon.social/users/foo/statuses/123
    local domain = uri:match("https?://([^/]+)")
    return domain
end
-- }}}

-- {{{ local function sleep
local function sleep(seconds)
    -- Use os.execute with sleep command since Lua doesn't have native sleep
    -- Convert to milliseconds for more precision
    local ms = math.floor(seconds * 1000)
    os.execute("sleep " .. (ms / 1000))
end
-- }}}

-- {{{ local function fetch_activitypub_json
local function fetch_activitypub_json(uri)
    -- Fetch ActivityPub JSON representation of a URI
    -- Returns: {success=bool, data=table or nil, error=string or nil, status_code=int}

    -- Build curl command with proper headers for ActivityPub
    -- We escape the URI and use proper quoting
    local escaped_uri = uri:gsub("'", "'\\''")
    local cmd = string.format(
        "curl -s -w '\\n%%{http_code}' --max-time %d " ..
        "-H 'Accept: %s' " ..
        "-H 'User-Agent: %s' " ..
        "'%s' 2>&1",
        CONFIG.request_timeout,
        CONFIG.accept_header,
        CONFIG.user_agent,
        escaped_uri
    )

    local handle = io.popen(cmd)
    local output = handle:read("*a")
    handle:close()

    -- Parse output - last line is status code
    local lines = {}
    for line in output:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    if #lines < 1 then
        return { success = false, error = "Empty response", status_code = 0 }
    end

    -- Last line is HTTP status code
    local status_code = tonumber(lines[#lines]) or 0

    -- Everything except last line is the body
    table.remove(lines)
    local body = table.concat(lines, "\n")

    -- Check status code
    if status_code ~= 200 then
        return {
            success = false,
            error = "HTTP " .. status_code,
            status_code = status_code
        }
    end

    -- Parse JSON
    local data, pos, err = dkjson.decode(body)
    if err then
        return {
            success = false,
            error = "JSON parse error: " .. tostring(err),
            status_code = status_code
        }
    end

    return { success = true, data = data, status_code = status_code }
end
-- }}}

-- {{{ local function extract_content_from_activitypub
local function extract_content_from_activitypub(ap_data)
    -- Extract relevant fields from ActivityPub Note object
    -- Returns: {content, summary (CW), sensitive, published, attributedTo}

    if not ap_data then
        return nil, "No data provided"
    end

    -- The content field contains HTML
    local content = ap_data.content
    if not content then
        -- Try contentMap (localized content)
        if ap_data.contentMap then
            -- Get first available content
            for lang, text in pairs(ap_data.contentMap) do
                content = text
                break
            end
        end
    end

    if not content then
        return nil, "No content field found"
    end

    return {
        content = content,                    -- HTML content
        summary = ap_data.summary,            -- Content warning (may be nil)
        sensitive = ap_data.sensitive or false,
        published = ap_data.published,
        attributed_to = ap_data.attributedTo, -- Author URI (for anonymization reference)
        type = ap_data.type,                  -- Usually "Note"
    }
end
-- }}}

-- {{{ local function load_cache
local function load_cache()
    local cache = read_json_file(CONFIG.cache_path)
    if not cache then
        return {
            metadata = {
                created = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                last_updated = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                version = 1
            },
            entries = {},
            errors = {}
        }
    end
    return cache
end
-- }}}

-- {{{ local function save_cache
local function save_cache(cache)
    cache.metadata.last_updated = os.date("!%Y-%m-%dT%H:%M:%SZ")
    return write_json_file(CONFIG.cache_path, cache)
end
-- }}}

-- {{{ local function get_external_boost_uris
local function get_external_boost_uris()
    -- Read poems.json and extract all external boost URIs
    local poems_data = read_json_file(CONFIG.poems_json_path)
    if not poems_data then
        return nil, "Could not read poems.json"
    end

    local uris = {}
    for _, poem in ipairs(poems_data.poems or {}) do
        if poem.metadata and poem.metadata.boost_type == "external" then
            local uri = poem.metadata.original_uri
            if uri then
                table.insert(uris, uri)
            end
        end
    end

    return uris
end
-- }}}

-- {{{ local function scrape_boosts
local function scrape_boosts()
    print("=== Boost Content Scraper ===")
    print("Project directory: " .. DIR)
    print("Force rescrape: " .. tostring(FORCE_RESCRAPE))
    print("Dry run: " .. tostring(DRY_RUN))
    if MAX_SCRAPE then
        print("Max URIs to scrape: " .. MAX_SCRAPE)
    end
    print("")

    -- Load existing cache
    local cache = load_cache()

    -- Count existing entries
    local existing_count = 0
    for _ in pairs(cache.entries or {}) do
        existing_count = existing_count + 1
    end
    print("Existing cache entries: " .. existing_count)

    -- Get list of URIs to scrape
    local uris, err = get_external_boost_uris()
    if not uris then
        print("ERROR: " .. err)
        return false
    end
    print("Found " .. #uris .. " external boost URIs in poems.json")
    print("")

    -- Filter to URIs not yet cached (unless force rescrape)
    local to_scrape = {}
    local skipped = 0
    for _, uri in ipairs(uris) do
        if FORCE_RESCRAPE or not cache.entries[uri] then
            table.insert(to_scrape, uri)
        else
            skipped = skipped + 1
        end
    end

    print("URIs already cached: " .. skipped)
    print("URIs to scrape: " .. #to_scrape)

    -- Apply max scrape limit
    if MAX_SCRAPE and #to_scrape > MAX_SCRAPE then
        print("Limiting to first " .. MAX_SCRAPE .. " URIs")
        local limited = {}
        for i = 1, MAX_SCRAPE do
            limited[i] = to_scrape[i]
        end
        to_scrape = limited
    end

    print("")

    if #to_scrape == 0 then
        print("Nothing to scrape - all URIs already cached!")
        return true
    end

    -- Sort URIs by domain for better rate limiting efficiency
    table.sort(to_scrape, function(a, b)
        return extract_domain(a) < extract_domain(b)
    end)

    -- Dry run: just show what would be scraped
    if DRY_RUN then
        print("=== DRY RUN - Would scrape these URIs ===")
        local domains = {}
        for _, uri in ipairs(to_scrape) do
            local domain = extract_domain(uri)
            domains[domain] = (domains[domain] or 0) + 1
            print("  " .. uri)
        end
        print("")
        print("=== Domains to contact ===")
        local domain_list = {}
        for domain, count in pairs(domains) do
            table.insert(domain_list, {domain = domain, count = count})
        end
        table.sort(domain_list, function(a, b) return a.count > b.count end)
        for _, d in ipairs(domain_list) do
            print(string.format("  %3d URIs from %s", d.count, d.domain))
        end
        print("")
        print("Estimated time: " .. math.ceil(#to_scrape * CONFIG.delay_between_requests / 60) .. " minutes")
        return true
    end

    -- Scrape each URI
    local last_domain = nil
    local success_count = 0
    local error_count = 0
    local start_time = os.time()

    for i, uri in ipairs(to_scrape) do
        local domain = extract_domain(uri)

        -- Rate limiting
        if i > 1 then
            local delay = CONFIG.delay_between_requests
            if domain == last_domain then
                delay = delay + CONFIG.delay_same_domain
            end
            sleep(delay)
        end

        -- Progress indicator
        io.write(string.format("[%d/%d] %s ... ", i, #to_scrape, uri:sub(1, 60)))
        io.flush()

        -- Fetch with retries
        local result = nil
        for attempt = 1, CONFIG.max_retries do
            result = fetch_activitypub_json(uri)
            if result.success then
                break
            end
            if attempt < CONFIG.max_retries then
                io.write("retry " .. attempt .. " ... ")
                io.flush()
                sleep(CONFIG.retry_delay)
            end
        end

        if result.success then
            -- Extract content
            local content_data, extract_err = extract_content_from_activitypub(result.data)
            if content_data then
                cache.entries[uri] = {
                    scraped_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    content = content_data.content,
                    summary = content_data.summary,
                    sensitive = content_data.sensitive,
                    published = content_data.published,
                    attributed_to = content_data.attributed_to,
                    type = content_data.type
                }
                success_count = success_count + 1
                print("OK")
            else
                cache.errors[uri] = {
                    attempted_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                    error = extract_err or "Unknown extraction error"
                }
                error_count = error_count + 1
                print("EXTRACT ERROR: " .. (extract_err or "unknown"))
            end
        else
            cache.errors[uri] = {
                attempted_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
                error = result.error,
                status_code = result.status_code
            }
            error_count = error_count + 1
            print("ERROR: " .. result.error)
        end

        last_domain = domain

        -- Save cache periodically (every 10 successful scrapes)
        if success_count > 0 and success_count % 10 == 0 then
            save_cache(cache)
        end
    end

    -- Final save
    save_cache(cache)

    -- Summary
    local elapsed = os.time() - start_time
    print("")
    print("=== Scraping Complete ===")
    print("Scraped: " .. success_count .. " URIs")
    print("Errors: " .. error_count .. " URIs")
    print("Time: " .. elapsed .. " seconds")
    print("Cache saved to: " .. CONFIG.cache_path)

    return true
end
-- }}}

-- Run scraper
scrape_boosts()
