#!/usr/bin/env lua

-- Core flat HTML page generation system for neocities-modernization
-- Generates 13,680+ pages with similarity/diversity ranking in compiled.txt format

-- {{{ local function setup_dir_path
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

-- Script configuration - handle args properly to avoid -I interfering with DIR
local DIR = setup_dir_path()
if arg then
    for _, arg_val in ipairs(arg) do
        if arg_val ~= "-I" and not arg_val:match("^%-") then
            DIR = arg_val
            break
        end
    end
end

-- Load required libraries
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path
local utils = require("utils")
local dkjson = require("dkjson")

-- Issue 10-003: Load unified config from config.lua
local config_loader = require("config-loader")
config_loader.set_project_root(DIR)
local unified_config = config_loader.load()

-- Initialize asset path configuration (CLI --dir takes precedence over config)
utils.init_assets_root(arg)

-- Load effil for parallel processing (optional - falls back to single-threaded if unavailable)
-- CRITICAL: effil.so is a C library, must be in cpath not path
package.cpath = package.cpath .. ';/home/ritz/programming/ai-stuff/libs/lua/effil-jit/build/?.so'
local effil = nil
local has_threading = false

local success, err = pcall(function()
    effil = require('effil')
    has_threading = true
end)

local M = {}

-- Mock color assignment for testing (until we have real embeddings)
local MOCK_POEM_COLORS = {
    [1] = "blue",    -- Introduction post
    [2] = "purple",  -- Philosophy/metaphysics  
    [3] = "red",     -- Passion/energy
    [5] = "orange",  -- Programming/technical
    [4625] = "red",  -- Politics/passion
    [4626] = "gray", -- Short post
    [4624] = "green" -- Hope/future themes
}

-- Color configuration for progress bars
local COLOR_CONFIG = {
    red = "#dc3c3c",
    blue = "#3c78dc",
    green = "#3cb45a",
    purple = "#8c3cc8",
    orange = "#e68c3c",
    yellow = "#c8b428",
    gray = "#787878"
}

-- Pagination configuration defaults
-- Issue 10-003: These values are overridden by unified config (config.lua) if present
-- See Issue 8-020 for hybrid pagination strategy (45GB storage constraint)
-- Issue 9-003 Fix F: Added chronological pagination settings
local PAGINATION_CONFIG = {
    poems_per_page = 100,
    minimum_pages = 1,
    max_pages_per_poem = 15,        -- Storage constraint: limits pages to fit 45GB (Issue 8-020)
    page_number_padding = 2,
    generate_txt_exports = true,
    generate_html_archives = false,  -- Disabled: redundant with paginated pages
    chronological_paginated = false, -- Set to true to split chronological.html into multiple pages
    chronological_poems_per_page = 500  -- Poems per page when chronological_paginated is true
}

-- Storage configuration (for display purposes)
-- Issue 10-003: Loaded from unified config (config.lua) if present
local STORAGE_CONFIG = {
    limit_gb = 45,
    reserved_for_maze_gb = 0.031,
    reserved_headroom_gb = 5
}

-- Layout constants: Single source of truth for box widths and positions
-- Issue 8-037: Centralized to prevent drift between calculations
-- Issue 10-003: Values can be overridden in unified config (config.lua) "layout" section
-- Reference: All progress bars, nav boxes, and content should use these
local LAYOUT = {
    -- Total visible width for regular poems (positions 0-82)
    REGULAR_POEM_WIDTH = 83,
    -- Total visible width for golden poems: 84 chars
    -- Structure: ╔ (1) + interior (82) + ┐ (1) = 84
    GOLDEN_POEM_WIDTH = 84,
    -- Maximum text content width (80 chars + 1 space padding on left)
    TEXT_CONTENT_WIDTH = 80,

    -- Regular poem nav box positions (within 83-char line):
    -- ┌─────────┐                                                           ┌───────────┐
    -- positions: 0-10 = left box (11 chars), 11-69 = gap (59 chars), 70-82 = right box (13 chars)
    REGULAR_LEFT_BOX_WIDTH = 11,      -- ┌─────────┐
    REGULAR_RIGHT_BOX_WIDTH = 13,     -- ┌───────────┐
    REGULAR_GAP_WIDTH = 59,           -- 83 - 11 - 13 = 59
    REGULAR_LEFT_JUNCTION_POS = 10,   -- Position of ┐/┴ under left box
    REGULAR_RIGHT_JUNCTION_POS = 70,  -- Position of ┌/┴ under right box

    -- Golden poem nav box positions (within 84-char line):
    -- Structure: ║ (1) + content (80) + space (1) + │ (1) = 83 interior + corners
    GOLDEN_LEFT_BOX_WIDTH = 11,
    GOLDEN_RIGHT_BOX_WIDTH = 13,
    GOLDEN_GAP_WIDTH = 58,            -- 84 - 2 corners - 11 - 13 = 58
    GOLDEN_LEFT_JUNCTION_POS = 9,     -- Position within interior (under ┐ at full pos 10)
    GOLDEN_RIGHT_JUNCTION_POS = 70,   -- Position within interior (under ┌ at full pos 71)
}

-- {{{ function load_layout_from_config
-- Issue 10-003: Loads layout settings from unified config, with fallback to LAYOUT defaults
local function load_layout_from_config()
    local layout = unified_config.layout
    if not layout then return end

    -- Override LAYOUT values from config
    if layout.regular_poem_width then LAYOUT.REGULAR_POEM_WIDTH = layout.regular_poem_width end
    if layout.golden_poem_width then LAYOUT.GOLDEN_POEM_WIDTH = layout.golden_poem_width end
    if layout.text_content_width then LAYOUT.TEXT_CONTENT_WIDTH = layout.text_content_width end
    if layout.left_box_width then
        LAYOUT.REGULAR_LEFT_BOX_WIDTH = layout.left_box_width
        LAYOUT.GOLDEN_LEFT_BOX_WIDTH = layout.left_box_width
    end
    if layout.right_box_width then
        LAYOUT.REGULAR_RIGHT_BOX_WIDTH = layout.right_box_width
        LAYOUT.GOLDEN_RIGHT_BOX_WIDTH = layout.right_box_width
    end
    if layout.gap_width then
        LAYOUT.REGULAR_GAP_WIDTH = layout.gap_width
        LAYOUT.GOLDEN_GAP_WIDTH = layout.gap_width
    end
    if layout.left_junction_pos then LAYOUT.REGULAR_LEFT_JUNCTION_POS = layout.left_junction_pos end
    if layout.right_junction_pos then LAYOUT.REGULAR_RIGHT_JUNCTION_POS = layout.right_junction_pos end
end
-- }}}

-- Load layout from config on module initialization
load_layout_from_config()

-- Diversity cache (pre-computed GPU sequences for fast HTML generation)
-- Loaded from assets/embeddings/embeddinggemma_latest/diversity_cache.json
local DIVERSITY_CACHE = nil

-- Similarity rankings cache (pre-sorted similarity rankings for fast HTML generation)
-- Loaded from assets/embeddings/embeddinggemma_latest/similarity_rankings_cache.json
local SIMILARITY_RANKINGS_CACHE = nil

-- {{{ local function load_diversity_cache
-- Loads pre-computed diversity sequences from GPU cache (required for HTML generation)
-- Errors out if cache doesn't exist - no fallback to on-the-fly computation
local function load_diversity_cache(model_name)
    model_name = model_name or "embeddinggemma:latest"
    local model_dir = model_name:gsub(":", "_")
    local cache_file = utils.asset_path("embeddings/" .. model_dir .. "/diversity_cache.json")

    if not utils.file_exists(cache_file) then
        error(string.format([[
Diversity cache not found: %s

The diversity cache is required for HTML generation.
Generate it with: ./run.sh --generate-diversity

This takes ~1 minute with GPU (or ~42 hours with CPU using --cpu-only).
]], cache_file))
    end

    utils.log_info("Loading diversity cache from: " .. cache_file)
    local cache_data = utils.read_json_file(cache_file)

    if not cache_data then
        error("Failed to parse diversity cache JSON file")
    end

    if not cache_data.sequences then
        error("Diversity cache has invalid format (missing sequences table)")
    end

    utils.log_info(string.format("Diversity cache loaded: %d sequences (%s algorithm, %ds generation time)",
                                cache_data.metadata.total_sequences or 0,
                                cache_data.metadata.algorithm or "unknown",
                                cache_data.metadata.generation_time_seconds or 0))

    DIVERSITY_CACHE = cache_data
    return cache_data
end
-- }}}

-- {{{ local function load_similarity_rankings_cache
-- Loads pre-sorted similarity rankings from cache (required for HTML generation)
-- Errors out if cache doesn't exist - no fallback to on-the-fly sorting
local function load_similarity_rankings_cache(model_name)
    model_name = model_name or "embeddinggemma:latest"
    local model_dir = model_name:gsub(":", "_")
    local cache_file = utils.asset_path("embeddings/" .. model_dir .. "/similarity_rankings_cache.json")

    if not utils.file_exists(cache_file) then
        error(string.format([[
Similarity rankings cache not found: %s

The similarity rankings cache is required for fast HTML generation.
Generate it with: ./run.sh --generate-similarity

This is a post-processing step that pre-sorts similarity rankings.
]], cache_file))
    end

    utils.log_info("Loading similarity rankings cache from: " .. cache_file)
    local cache_data = utils.read_json_file(cache_file)

    if not cache_data then
        error("Failed to parse similarity rankings cache JSON file")
    end

    if not cache_data.rankings then
        error("Similarity rankings cache has invalid format (missing rankings table)")
    end

    -- Count rankings (for logging)
    local count = 0
    for _ in pairs(cache_data.rankings) do count = count + 1 end

    -- Validate cache is not empty (Issue: empty cache generated by standalone script)
    if count == 0 then
        error(string.format([[
Similarity rankings cache is empty (0 poems): %s

This usually means the cache was generated before similarity files existed,
or the standalone script encountered a path issue.

To fix, regenerate with: ./run.sh --generate-similarity --force

This will regenerate both similarity files AND the rankings cache.
]], cache_file))
    end

    utils.log_info(string.format("Similarity rankings cache loaded: %d poems (%s)",
                                count,
                                cache_data.metadata.algorithm or "unknown"))

    SIMILARITY_RANKINGS_CACHE = cache_data
    return cache_data
end
-- }}}

-- {{{ local function flatten_media_files
-- Issue 8-048: Flatten nested Mastodon media structure to simple output/media/ directory
-- This makes deployment to Neocities much easier (single flat directory vs 7+ levels deep)
-- Filenames are already unique (content-addressable hashes from Mastodon)
-- Called once at start of HTML generation; skips files that already exist (idempotent)
local media_flattening_done = false

local function flatten_media_files(output_dir)
    -- Skip if already done this session (idempotent)
    if media_flattening_done then
        return true
    end

    local source_dir = DIR .. "/input/media_attachments"
    local target_dir = output_dir .. "/media"

    -- Check if source directory exists
    local source_test = io.open(source_dir .. "/files", "r")
    if not source_test then
        -- No media_attachments directory - not an error, just skip
        utils.log_info("No media_attachments directory found, skipping media flattening")
        media_flattening_done = true
        return true
    end
    source_test:close()

    -- Create target directory if it doesn't exist
    os.execute('mkdir -p "' .. target_dir .. '"')

    utils.log_info("Flattening media files to: " .. target_dir)

    -- Find all media files and copy them to flat structure
    local find_cmd = string.format('find "%s" -type f 2>/dev/null', source_dir)
    local handle = io.popen(find_cmd)
    if not handle then
        utils.log_warn("Could not scan media_attachments directory")
        media_flattening_done = true
        return false
    end

    local copied = 0
    local skipped = 0
    local errors = 0

    for source_path in handle:lines() do
        -- Extract just the filename (basename)
        local filename = source_path:match("([^/]+)$")
        if filename then
            local target_path = target_dir .. "/" .. filename

            -- Check if target already exists (idempotent - skip if present)
            local exists_check = io.open(target_path, "r")
            if exists_check then
                exists_check:close()
                skipped = skipped + 1
            else
                -- Copy file to flat directory
                local cp_cmd = string.format('cp "%s" "%s" 2>/dev/null', source_path, target_path)
                local success = os.execute(cp_cmd)
                if success == 0 or success == true then
                    copied = copied + 1
                else
                    errors = errors + 1
                    utils.log_warn("Failed to copy: " .. source_path)
                end
            end
        end
    end
    handle:close()

    utils.log_info(string.format("Media flattening complete: %d copied, %d skipped (existing), %d errors",
                                copied, skipped, errors))

    media_flattening_done = true
    return errors == 0
end
-- }}}

-- {{{ local function load_pagination_config
-- Issue 10-003: Loads pagination and storage settings from unified config
-- Updated for Issue 8-020: Hybrid pagination strategy with storage constraints
-- Note: Only loads and logs once per session (idempotent)
local pagination_config_loaded = false

local function load_pagination_config()
    -- Skip if already loaded (idempotent)
    if pagination_config_loaded then
        return PAGINATION_CONFIG
    end

    -- Load pagination settings from unified config
    if unified_config.pagination then
        for key, value in pairs(unified_config.pagination) do
            if key ~= "_comment" and PAGINATION_CONFIG[key] ~= nil then
                PAGINATION_CONFIG[key] = value
            end
        end
    end

    -- Load storage settings from unified config (Issue 8-020)
    if unified_config.storage then
        for key, value in pairs(unified_config.storage) do
            if key ~= "_comment" and STORAGE_CONFIG[key] ~= nil then
                STORAGE_CONFIG[key] = value
            end
        end
    end

    utils.log_info(string.format("Loaded pagination config: %d poems/page, max %d pages (storage: %dGB limit)",
        PAGINATION_CONFIG.poems_per_page,
        PAGINATION_CONFIG.max_pages_per_poem,
        STORAGE_CONFIG.limit_gb))

    pagination_config_loaded = true
    return PAGINATION_CONFIG
end
-- }}}

-- {{{ local function calculate_page_count
-- Calculates the total number of pages needed for a given poem count
-- Returns: number of pages (always at least 1)
local function calculate_page_count(total_poems)
    local poems_per_page = PAGINATION_CONFIG.poems_per_page
    return math.ceil(total_poems / poems_per_page)
end
-- }}}

-- {{{ local function parse_pages_specification
-- Parses the --pages flag value into a list of page numbers or special value
-- Supports formats:
--   nil or "default"  → Use minimum_pages from config (usually {1})
--   "all"             → Generate all pages up to max_pages_per_poem limit
--   "N"               → Single page number, e.g., "1" → {1}, "5" → {5}
--   "N-M"             → Range of pages, e.g., "1-10" → {1,2,...,10}
-- Returns: {pages = {1,2,3,...}, is_all = boolean}
-- is_all flag indicates if we should generate all pages (respecting max_pages limit)
local function parse_pages_specification(pages_spec, total_pages_possible)
    -- Ensure pagination config is loaded
    load_pagination_config()

    -- Default: use minimum_pages from config
    if not pages_spec or pages_spec == "" or pages_spec == "default" then
        local pages = {}
        for i = 1, PAGINATION_CONFIG.minimum_pages do
            table.insert(pages, i)
        end
        return {pages = pages, is_all = false}
    end

    -- "all" means generate all pages up to max_pages_per_poem limit
    if pages_spec == "all" then
        return {pages = nil, is_all = true}  -- nil means "generate all" in context
    end

    -- Single page number: "5" → {5}
    local single_num = tonumber(pages_spec)
    if single_num then
        return {pages = {single_num}, is_all = false}
    end

    -- Range: "1-10" → {1,2,3,...,10}
    local start_page, end_page = pages_spec:match("^(%d+)%-(%d+)$")
    if start_page and end_page then
        start_page = tonumber(start_page)
        end_page = tonumber(end_page)

        if start_page and end_page and start_page <= end_page then
            local pages = {}
            for i = start_page, end_page do
                table.insert(pages, i)
            end
            return {pages = pages, is_all = false}
        else
            utils.log_error(string.format("Invalid page range: %s (start must be <= end)", pages_spec))
            return {pages = {1}, is_all = false}  -- Fallback to page 1
        end
    end

    -- Invalid format - fallback to page 1
    utils.log_error(string.format("Invalid --pages format: '%s'. Expected: 1, all, or 1-10", pages_spec))
    return {pages = {1}, is_all = false}
end
-- }}}

-- {{{ local function get_poems_for_page
-- Extracts poems for a specific page from a sorted list
-- page_num is 1-indexed
-- Returns: table of poem entries for that page
local function get_poems_for_page(sorted_poems, page_num)
    local poems_per_page = PAGINATION_CONFIG.poems_per_page
    local start_idx = ((page_num - 1) * poems_per_page) + 1
    local end_idx = math.min(start_idx + poems_per_page - 1, #sorted_poems)

    local page_poems = {}
    for i = start_idx, end_idx do
        if sorted_poems[i] then
            table.insert(page_poems, sorted_poems[i])
        end
    end

    return page_poems
end
-- }}}

-- {{{ local function get_unique_poem_filename_id
-- Generates a unique identifier for poem filenames using category prefix
-- Solves cross-category ID collisions: fediverse/0002.txt and messages/0002.txt
-- both have id=2 but become "fediverse-0002" and "messages-0002". See Issue 8-019.
-- poem: poem object with id and category fields
-- Returns: unique filename identifier like "fediverse-0002" or "messages-0767"
local function get_unique_poem_filename_id(poem)
    local category = poem.category or "unknown"
    local id = poem.id or 0
    return string.format("%s-%04d", category, id)
end
-- }}}

-- {{{ local function get_poem_anchor_id
-- Generates HTML anchor ID for linking to poems in chronological.html
-- Issue 8-030: Add chronological anchor links
-- poem: poem object with id and category fields
-- Returns: anchor ID like "poem-fediverse-0042" or "poem-messages-0767"
local function get_poem_anchor_id(poem)
    return "poem-" .. get_unique_poem_filename_id(poem)
end
-- }}}

-- {{{ local function format_page_number
-- Formats a page number with zero-padding
-- Returns: padded string like "01", "02", etc.
local function format_page_number(page_num)
    local padding = PAGINATION_CONFIG.page_number_padding
    return string.format("%0" .. padding .. "d", page_num)
end
-- }}}

-- {{{ local function generate_page_filename
-- Generates the filename for a paginated page
-- poem_id: the starting poem ID (for similarity/diversity pages)
-- page_num: 1-indexed page number
-- page_type: "similar" or "different"
-- Returns: filename like "similar/0068-01.html"
local function generate_page_filename(poem_id, page_num, page_type)
    local padded_id = string.format("%04d", poem_id)
    local padded_page = format_page_number(page_num)
    return string.format("%s/%s-%s.html", page_type, padded_id, padded_page)
end
-- }}}

-- {{{ local function generate_prev_next_navigation
-- Generates prev/next navigation links for paginated pages
-- current_page: 1-indexed current page
-- total_pages: total number of pages (may be capped by max_pages_per_poem)
-- poem_id: starting poem ID (nil for chronological)
-- page_type: "similar", "different", or "chronological"
-- total_corpus: optional - total poems in corpus (for storage context display)
-- Returns: HTML string with navigation
-- Updated for Issue 8-020: Shows storage constraint message on last page
local function generate_prev_next_navigation(current_page, total_pages, poem_id, page_type, total_corpus)
    local nav_parts = {}

    -- Calculate poem range for this page
    local poems_per_page = PAGINATION_CONFIG.poems_per_page
    local max_pages = PAGINATION_CONFIG.max_pages_per_poem
    local start_poem = ((current_page - 1) * poems_per_page) + 1
    local end_poem = math.min(current_page * poems_per_page, total_pages * poems_per_page)

    -- Check if this is a storage-constrained last page
    local is_storage_limited = (total_pages == max_pages) and (total_corpus and total_corpus > end_poem)
    local poems_shown = end_poem
    local poems_omitted = total_corpus and (total_corpus - poems_shown) or 0

    -- Header line with page info
    table.insert(nav_parts, "════════════════════════════════════════════════════════════════════════════════")

    if page_type == "chronological" then
        table.insert(nav_parts, string.format(" Page %d of %d │ Poems %d-%d",
            current_page, total_pages, start_poem, end_poem))
    else
        local padded_id = string.format("%04d", poem_id)
        if is_storage_limited then
            -- Show storage context on capped pages (Issue 8-020)
            table.insert(nav_parts, string.format(" %s to Poem %s │ Page %d of %d │ Showing top %d poems",
                page_type == "similar" and "Similar" or "Different",
                padded_id, current_page, total_pages, poems_shown))
        else
            table.insert(nav_parts, string.format(" %s to Poem %s │ Page %d of %d │ Poems %d-%d",
                page_type == "similar" and "Similar" or "Different",
                padded_id, current_page, total_pages, start_poem, end_poem))
        end
    end

    table.insert(nav_parts, "════════════════════════════════════════════════════════════════════════════════")

    -- Storage constraint notice on last page (Issue 8-020)
    if is_storage_limited and current_page == total_pages and poems_omitted > 0 then
        table.insert(nav_parts, string.format(" (%d additional poems omitted for storage constraints)",
            poems_omitted))
    end

    table.insert(nav_parts, "")

    -- Navigation links
    local nav_line = ""

    -- Previous link (left aligned)
    if current_page > 1 then
        local prev_file
        if page_type == "chronological" then
            -- Issue 8-039 Fix: Chronological pages now in subdirectory, use relative paths
            prev_file = string.format("%s.html", format_page_number(current_page - 1))
        else
            prev_file = string.format("%s-%s.html", string.format("%04d", poem_id), format_page_number(current_page - 1))
        end
        nav_line = string.format("[<a href=\"%s\">◀ Previous Page</a>]", prev_file)
    else
        nav_line = "[◀ Previous Page]"  -- Disabled
    end

    -- Calculate padding to push next link to right side
    local padding = 80 - #nav_line - 16  -- 16 chars for next link
    if padding < 0 then padding = 0 end
    nav_line = nav_line .. string.rep(" ", padding)

    -- Next link (right aligned)
    if current_page < total_pages then
        local next_file
        if page_type == "chronological" then
            -- Issue 8-039 Fix: Chronological pages now in subdirectory, use relative paths
            next_file = string.format("%s.html", format_page_number(current_page + 1))
        else
            next_file = string.format("%s-%s.html", string.format("%04d", poem_id), format_page_number(current_page + 1))
        end
        nav_line = nav_line .. string.format("[<a href=\"%s\">Next Page ▶</a>]", next_file)
    else
        nav_line = nav_line .. "[Next Page ▶]"  -- Disabled
    end

    table.insert(nav_parts, nav_line)
    table.insert(nav_parts, "────────────────────────────────────────────────────────────────────────────────")

    return table.concat(nav_parts, "\n")
end
-- }}}

-- {{{ function load_poem_colors
-- Note: Only loads and logs once per session (idempotent)
local cached_poem_colors = nil

local function load_poem_colors()
    -- Skip if already loaded (idempotent)
    if cached_poem_colors then
        return cached_poem_colors
    end

    local poem_colors_file = utils.embeddings_dir("embeddinggemma_latest") .. "/poem_colors.json"
    local poem_colors_data = utils.read_json_file(poem_colors_file)

    if poem_colors_data and poem_colors_data.poem_colors then
        -- Count actual entries dynamically (stored total_poems may be stale)
        local actual_count = 0
        for _ in pairs(poem_colors_data.poem_colors) do actual_count = actual_count + 1 end
        utils.log_info(string.format("Loaded semantic colors for %d poems", actual_count))
        cached_poem_colors = poem_colors_data.poem_colors
        return cached_poem_colors
    else
        utils.log_warn("Could not load poem colors, using mock colors")
        cached_poem_colors = MOCK_POEM_COLORS
        return cached_poem_colors
    end
end
-- }}}

-- {{{ function get_file_creation_timestamp
local function get_file_creation_timestamp(file_path)
    -- Use bash stat command to get file modification time (best approximation)
    local cmd = string.format("stat -c %%Y '%s' 2>/dev/null", file_path)
    local handle = io.popen(cmd)
    
    if handle then
        local result = handle:read("*a")
        handle:close()
        
        if result and result:match("^%d+") then
            return tonumber(result:match("^%d+"))
        end
    end
    
    return nil
end
-- }}}

-- {{{ function extract_post_date_from_poem
local function extract_post_date_from_poem(poem_data)
    -- First, try to use the creation_date metadata field (if available)
    local creation_date = poem_data.creation_date or (poem_data.metadata and poem_data.metadata.creation_date)
    if creation_date then
        -- Parse ISO 8601 format: "2023-04-20T05:22:03" or "2023-04-20T05:22:03Z"
        local year, month, day, hour, min, sec = creation_date:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
        if year and month and day then
            local parsed_time = os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour) or 0,
                min = tonumber(min) or 0,
                sec = tonumber(sec) or 0
            })
            if parsed_time then return parsed_time end
        end
        
        -- Fallback: try to extract just date part
        year, month, day = creation_date:match("(%d+)-(%d+)-(%d+)")
        if year and month and day then
            local parsed_time = os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = 0, min = 0, sec = 0
            })
            if parsed_time then return parsed_time end
        end
    end
    
    -- Fallback: Look for date patterns in poem content (legacy logic)
    local content = poem_data.content or ""
    
    -- First, try to extract YYYY-MM-DD from the very beginning (processing artifact dates)
    local year, month, day = content:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
    if year and month and day then
        return os.time({year=tonumber(year), month=tonumber(month), day=tonumber(day)})
    end
    
    -- Try to extract date from first line (other patterns)
    local date_line = content:match("^([^\n]+)")
    if date_line then        
        -- MM/DD/YYYY format  
        local month, day, year = date_line:match("(%d%d)/(%d%d)/(%d%d%d%d)")
        if month and day and year then
            return os.time({year=tonumber(year), month=tonumber(month), day=tonumber(day)})
        end
        
        -- Month DD, YYYY format (like "april 16th 2023")
        local month_name, day_num, year_num = date_line:match("(%w+)%s+(%d+)%w*%s+(%d%d%d%d)")
        if month_name and day_num and year_num then
            local month_map = {
                january=1, february=2, march=3, april=4, may=5, june=6,
                july=7, august=8, september=9, october=10, november=11, december=12
            }
            local month_num = month_map[month_name:lower()]
            if month_num then
                return os.time({year=tonumber(year_num), month=month_num, day=tonumber(day_num)})
            end
        end
    end
    
    -- Fallback to file creation time if available
    if poem_data.filepath then
        local timestamp = get_file_creation_timestamp(poem_data.filepath)
        if timestamp then
            return timestamp
        end
    end
    
    -- Final fallback to poem ID as timestamp approximation
    return poem_data.id or 0
end
-- }}}

-- {{{ function sort_poems_chronologically_by_dates
local function sort_poems_chronologically_by_dates(poems_data)
    local sorted_poems = {}
    
    -- Extract all poems with temporal sorting data
    for i, poem in ipairs(poems_data.poems) do
        if poem.id then
            local post_timestamp = extract_post_date_from_poem(poem)
            table.insert(sorted_poems, {
                poem = poem,
                timestamp = post_timestamp,
                sort_key = post_timestamp,
                original_index = i
            })
        end
    end
    
    -- Sort by actual temporal order
    table.sort(sorted_poems, function(a, b)
        -- If timestamps are equal, use original index as tiebreaker
        if a.sort_key == b.sort_key then
            return a.original_index < b.original_index
        end
        return a.sort_key < b.sort_key
    end)
    
    return sorted_poems
end
-- }}}

-- {{{ function calculate_chronological_progress
local function calculate_chronological_progress(poem_id, total_poems)
    -- Calculate percentage through chronological corpus
    local progress_percentage = (poem_id / total_poems) * 100

    return {
        poem_id = poem_id,
        total_poems = total_poems,
        percentage = progress_percentage,
        position = poem_id,
        quartile = math.ceil(progress_percentage / 25)
    }
end
-- }}}

-- {{{ function compute_chronological_mapping
-- Computes poem_index → {position, page_number, total_poems, total_pages}
-- Used by parallel workers to generate correct chronological links and progress bars
local function compute_chronological_mapping(poems_data, chrono_poems_per_page)
    -- Sort chronologically (same as generate_chronological_index_with_navigation)
    local sorted_poems = sort_poems_chronologically_by_dates(poems_data)
    local total_poems = #sorted_poems
    local total_pages = chrono_poems_per_page and math.ceil(total_poems / chrono_poems_per_page) or 1

    -- Build mapping
    local mapping = {}
    for position, poem_info in ipairs(sorted_poems) do
        local poem = poem_info.poem
        local poem_index = poem.poem_index
        if poem_index then
            local page_number = chrono_poems_per_page and math.ceil(position / chrono_poems_per_page) or 1
            mapping[poem_index] = {
                position = position,
                page_number = page_number,
                total_poems = total_poems,
                total_pages = total_pages
            }
        end
    end

    return mapping
end
-- }}}

-- {{{ function generate_progress_dashes
local function generate_progress_dashes(progress_info, color_name, is_golden, position, has_corner_boxes)
    -- For golden poems: 82 chars interior (+ 2 corners = 84 total)
    -- For regular poems: 83 chars total (positions 0-82)
    -- Golden poems have corner characters (╔/┐ or ╚/┘) that add 2 to the width,
    -- so interior needs to be 1 less to maintain 84-char total alignment
    local total_chars = is_golden and 82 or 83
    local progress_chars = math.floor((progress_info.percentage / 100) * total_chars)
    local remaining_chars = total_chars - progress_chars

    -- Get color information
    local hex_color = COLOR_CONFIG[color_name] or COLOR_CONFIG["gray"]

    -- For golden bottom borders with corner boxes, we need to insert junction characters
    -- Junction positions in the 82-char interior (0-indexed):
    -- - Position 9: under "similar" box ┐ (uses ╧ if in ═ section, ┴ if in ─ section)
    -- - Position 70: under "different" box ┌ (uses ╧ if in ═ section, ┴ if in ─ section)
    local LEFT_JUNCTION_POS = 9   -- After "║ similar │" (11 chars, minus corner = 10, 0-indexed = 9)
    local RIGHT_JUNCTION_POS = 70  -- Under "┌" of right box at full position 71 (interior pos 70)

    -- Junction positions for regular poems (different from golden due to no outer walls)
    -- Regular corner boxes: ┌─────────┐ (11 chars) + 59 spaces + ┌───────────┐ (13 chars) = 83 chars
    -- Inner walls at positions 10 and 70 (0-indexed)
    local REGULAR_LEFT_JUNCTION_POS = 10
    local REGULAR_RIGHT_JUNCTION_POS = 70

    local visual_output
    if is_golden and position == "bottom" and has_corner_boxes then
        -- Build progress bar with junction characters inserted
        -- We need to construct the bar character by character to insert junctions at the right spots

        -- Determine which junction character to use at each position
        -- ╧ (U+2567) - up single and horizontal double (connects to ═) - COLORED
        -- ┴ (U+2534) - up and horizontal single (connects to ─) - UNCOLORED
        local left_in_progress = LEFT_JUNCTION_POS < progress_chars
        local right_in_progress = RIGHT_JUNCTION_POS < progress_chars

        -- Build colored junctions (╧ when in progress section)
        local left_junction
        if left_in_progress then
            left_junction = string.format('<font color="%s"><b>╧</b></font>', hex_color)
        else
            left_junction = "┴"
        end

        local right_junction
        if right_in_progress then
            right_junction = string.format('<font color="%s"><b>╧</b></font>', hex_color)
        else
            right_junction = "┴"
        end

        -- Build the progress section (colored ═) and remaining section (─)
        -- We need to split around the junction positions
        local segments = {}
        local current_pos = 0

        -- Helper to add a segment with proper coloring
        local function add_segment(start_pos, end_pos)
            if end_pos <= start_pos then return end
            local seg_len = end_pos - start_pos

            -- Determine how much of this segment is progress vs remaining
            local progress_in_seg = math.max(0, math.min(seg_len, progress_chars - start_pos))
            local remaining_in_seg = seg_len - progress_in_seg

            if progress_in_seg > 0 then
                table.insert(segments, string.format('<font color="%s"><b>%s</b></font>',
                    hex_color, string.rep("═", progress_in_seg)))
            end
            if remaining_in_seg > 0 then
                table.insert(segments, string.rep("─", remaining_in_seg))
            end
        end

        -- Segment 1: from 0 to left junction (exclusive)
        add_segment(0, LEFT_JUNCTION_POS)
        -- Insert left junction (colored if ╧, plain if ┴)
        table.insert(segments, left_junction)

        -- Segment 2: from left junction + 1 to right junction (exclusive)
        add_segment(LEFT_JUNCTION_POS + 1, RIGHT_JUNCTION_POS)
        -- Insert right junction (colored if ╧, plain if ┴)
        table.insert(segments, right_junction)

        -- Segment 3: from right junction + 1 to end
        add_segment(RIGHT_JUNCTION_POS + 1, total_chars)

        local interior = table.concat(segments, "")
        -- Color the ╚ corner to match the progress bar
        local colored_corner = string.format('<font color="%s"><b>╚</b></font>', hex_color)
        visual_output = colored_corner .. interior .. "┘"

    elseif not is_golden and position == "bottom" and has_corner_boxes then
        -- Regular poem bottom border with corner characters and junctions connecting to corner boxes
        -- Structure: ╘ (pos 0) + progress bar + ┴/╧ (pos 10) + progress bar + ┴/╧ (pos 69) + progress bar + ┘ (pos 81)
        -- ╘ (U+2558) - up single and right double - closes left box, connects to ═ progress
        -- ┘ (U+2518) - light up and left - closes right box, connects to ─ remaining

        local left_in_progress = REGULAR_LEFT_JUNCTION_POS < progress_chars
        local right_in_progress = REGULAR_RIGHT_JUNCTION_POS < progress_chars

        -- Build colored junctions (╧ when in progress section, ┴ otherwise)
        local left_junction
        if left_in_progress then
            left_junction = string.format('<font color="%s"><b>╧</b></font>', hex_color)
        else
            left_junction = "┴"
        end

        local right_junction
        if right_in_progress then
            right_junction = string.format('<font color="%s"><b>╧</b></font>', hex_color)
        else
            right_junction = "┴"
        end

        -- Left corner ╘ - colored if progress > 0 (position 0 is always in progress section if any progress)
        local left_corner
        if progress_chars > 0 then
            left_corner = string.format('<font color="%s"><b>╘</b></font>', hex_color)
        else
            left_corner = "╘"
        end

        -- Right corner ┘ - always uncolored (position 82 is almost never in progress section)
        local right_corner = "┘"

        -- Build the progress bar with junctions
        local segments = {}

        -- Helper to add a segment with proper coloring
        -- Note: positions are now 1-80 since 0 and 81 are corner characters
        local function add_segment(start_pos, end_pos)
            if end_pos <= start_pos then return end
            local seg_len = end_pos - start_pos

            local progress_in_seg = math.max(0, math.min(seg_len, progress_chars - start_pos))
            local remaining_in_seg = seg_len - progress_in_seg

            if progress_in_seg > 0 then
                table.insert(segments, string.format('<font color="%s"><b>%s</b></font>',
                    hex_color, string.rep("═", progress_in_seg)))
            end
            if remaining_in_seg > 0 then
                table.insert(segments, string.rep("─", remaining_in_seg))
            end
        end

        -- Start with left corner
        table.insert(segments, left_corner)

        -- Segment 1: from 1 to left junction (exclusive) - 9 chars
        add_segment(1, REGULAR_LEFT_JUNCTION_POS)
        table.insert(segments, left_junction)

        -- Segment 2: from left junction + 1 to right junction (exclusive) - 59 chars
        add_segment(REGULAR_LEFT_JUNCTION_POS + 1, REGULAR_RIGHT_JUNCTION_POS)
        table.insert(segments, right_junction)

        -- Segment 3: from right junction + 1 to end - 1 (exclusive of right corner) - 11 chars
        add_segment(REGULAR_RIGHT_JUNCTION_POS + 1, total_chars - 1)

        -- End with right corner
        table.insert(segments, right_corner)

        -- No padding needed - content has 1-space indent for alignment
        visual_output = table.concat(segments, "")

    elseif is_golden then
        -- Golden poem top border or bottom without corner boxes
        -- Create progress visualization using equals/dash distinction
        local progress_section = string.rep("═", progress_chars)
        local remaining_section = string.rep("─", remaining_chars)

        local colored_progress = string.format(
            '<font color="%s"><b>%s</b></font>%s',
            hex_color, progress_section, remaining_section
        )

        -- Color the left corners to match the progress bar
        local colored_top_corner = string.format('<font color="%s"><b>╔</b></font>', hex_color)
        local colored_bottom_corner = string.format('<font color="%s"><b>╚</b></font>', hex_color)

        if position == "top" then
            visual_output = colored_top_corner .. colored_progress .. "┐"
        elseif position == "bottom" then
            visual_output = colored_bottom_corner .. colored_progress .. "┘"
        else
            visual_output = colored_top_corner .. colored_progress .. "┐"
        end
    else
        -- Regular poems: no padding needed - content has 1-space indent for alignment
        local progress_section = string.rep("═", progress_chars)
        local remaining_section = string.rep("─", remaining_chars)

        local colored_progress = string.format(
            '<font color="%s"><b>%s</b></font>%s',
            hex_color, progress_section, remaining_section
        )
        visual_output = colored_progress
    end

    -- Screen reader accessible version - brief format for frequent use
    local screen_reader_text
    if is_golden then
        screen_reader_text = string.format(
            'aria-label="golden poem border. %s."',
            color_name
        )
    else
        screen_reader_text = string.format(
            'aria-label="eighty dashes. %s."',
            color_name
        )
    end

    return {
        visual = visual_output,
        accessibility = screen_reader_text,
        raw_progress = progress_chars,
        raw_remaining = remaining_chars,
        color = color_name,
        percentage = progress_info.percentage,
        is_golden = is_golden or false
    }
end
-- }}}

-- {{{ function wrap_single_line_80_chars
local function wrap_single_line_80_chars(line)
    -- Wrap a single line to 80 characters, preserving words
    if #line <= 80 then
        return line
    end

    local result_lines = {}
    local words = {}

    for word in line:gmatch("%S+") do
        table.insert(words, word)
    end

    local current_line = ""
    for _, word in ipairs(words) do
        if #current_line == 0 then
            current_line = word
        elseif #current_line + 1 + #word <= 80 then
            current_line = current_line .. " " .. word
        else
            table.insert(result_lines, current_line)
            current_line = word
        end
    end

    if #current_line > 0 then
        table.insert(result_lines, current_line)
    end

    return table.concat(result_lines, "\n")
end
-- }}}

-- {{{ function strip_html_tags
local function strip_html_tags(content)
    -- Strip all HTML tags and decode HTML entities for TXT export
    -- Images should be converted with render_attachment_images_txt() separately
    local result = content

    -- Strip HTML tags
    result = result:gsub("<[^>]+>", "")

    -- Decode common HTML entities
    result = result:gsub("&amp;", "&")
    result = result:gsub("&lt;", "<")
    result = result:gsub("&gt;", ">")
    result = result:gsub("&quot;", '"')
    result = result:gsub("&#39;", "'")
    result = result:gsub("&nbsp;", " ")
    result = result:gsub("&#(%d+);", function(n)
        return string.char(tonumber(n))
    end)

    -- Normalize multiple consecutive spaces/newlines
    result = result:gsub("[ \t]+", " ")
    result = result:gsub("\n[ \t]+", "\n")
    result = result:gsub("[ \t]+\n", "\n")
    result = result:gsub("\n\n\n+", "\n\n")

    return result
end
-- }}}

-- {{{ function wrap_text_80_chars
local function wrap_text_80_chars(text)
    -- Wrap text to 80 chars while preserving existing newlines (paragraph breaks)
    local input_lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(input_lines, line)
    end

    local output_lines = {}
    for _, line in ipairs(input_lines) do
        if #line == 0 then
            -- Preserve empty lines (paragraph breaks)
            table.insert(output_lines, "")
        else
            -- Wrap long lines
            local wrapped = wrap_single_line_80_chars(line)
            for wrapped_line in (wrapped .. "\n"):gmatch("(.-)\n") do
                table.insert(output_lines, wrapped_line)
            end
        end
    end

    return table.concat(output_lines, "\n")
end
-- }}}

-- {{{ function M.generate_similarity_ranked_list
-- Cache-only similarity ranking lookup (no on-the-fly sorting)
-- Requires pre-computed similarity rankings cache from: ./run.sh --generate-similarity
-- Parameter similarity_data is kept for API compatibility but not used when cache is available
function M.generate_similarity_ranked_list(starting_poem_id, poems_data, similarity_data)
    -- Verify cache is loaded
    if not SIMILARITY_RANKINGS_CACHE then
        error("Similarity rankings cache not loaded! Run: ./run.sh --generate-similarity")
    end

    if not SIMILARITY_RANKINGS_CACHE.rankings then
        error("Similarity rankings cache has invalid format (missing rankings table)")
    end

    -- Look up pre-sorted ranking for this poem
    local cached_ranking = SIMILARITY_RANKINGS_CACHE.rankings[tostring(starting_poem_id)]
    if not cached_ranking then
        error(string.format("Similarity ranking not found for poem %s in cache.", starting_poem_id))
    end

    -- Build poem index lookup for fast access
    local poem_by_index = {}
    for i, poem in ipairs(poems_data.poems) do
        if poem.poem_index then
            poem_by_index[poem.poem_index] = poem
        end
    end

    -- Initialize ranked list with starting poem
    local ranked_poems = {}
    local starting_poem = poems_data.poems[starting_poem_id]
    table.insert(ranked_poems, {
        id = starting_poem_id,
        poem = starting_poem,
        similarity = 1.0,  -- Perfect similarity to self
        rank = 1
    })

    -- Add poems in pre-sorted order from cache
    -- Cache contains poem indices already sorted by similarity (descending)
    local rank = 2
    for _, target_poem_index in ipairs(cached_ranking) do
        local poem = poem_by_index[target_poem_index]
        if poem then
            table.insert(ranked_poems, {
                id = poem.id,
                poem = poem,
                similarity = nil,  -- Not needed for display, saves memory
                rank = rank
            })
            rank = rank + 1
        end
    end

    return ranked_poems
end
-- }}}

-- {{{ function M.generate_maximum_diversity_sequence
-- Cache-only diversity sequence lookup (no on-the-fly computation)
-- Requires pre-computed GPU diversity cache from: ./run.sh --generate-diversity
function M.generate_maximum_diversity_sequence(starting_poem_id, poems_data, embeddings_data)
    -- Verify cache is loaded
    if not DIVERSITY_CACHE then
        error("Diversity cache not loaded! Run: ./run.sh --generate-diversity")
    end

    if not DIVERSITY_CACHE.sequences then
        error("Diversity cache has invalid format (missing sequences table)")
    end

    -- Look up pre-computed sequence
    local cached_sequence = DIVERSITY_CACHE.sequences[tostring(starting_poem_id)]
    if not cached_sequence then
        error(string.format("Diversity sequence not found for poem %d in cache. Cache may be corrupted or incomplete.", starting_poem_id))
    end

    -- Convert cached poem_index values to full poem objects
    -- Note: The diversity cache stores poem_index (globally unique), NOT poem.id (per-category)
    local diversity_sequence = {}
    local poem_lookup = {}

    -- Build lookup table keyed by poem_index (NOT poem.id which is per-category)
    for i, poem in ipairs(poems_data.poems) do
        if poem.poem_index then
            poem_lookup[poem.poem_index] = poem
        end
    end

    -- Convert cached sequence (contains poem_index values) to format expected by HTML generator
    for step, poem_index in ipairs(cached_sequence) do
        local poem = poem_lookup[poem_index]
        if poem then
            table.insert(diversity_sequence, {
                id = poem_index,  -- Store poem_index for consistency
                poem = poem,
                step = step
            })
        end
    end

    return diversity_sequence
end
-- }}}

-- {{{ function render_attachment_images
local function render_attachment_images(attachments)
    -- Render HTML for poem attachments (images)
    -- Returns empty string if no attachments or no image attachments
    -- Image output format designed for 80-char width aesthetic
    --
    -- ATTACHMENT STRUCTURE (from ActivityPub extraction):
    -- {
    --   media_type = "image/png",
    --   url = "https://server.com/media/files/123/456/original/abc.png",
    --   relative_path = "files/123/456/original/abc.png",
    --   alt_text = "User description" or nil,
    --   width = 1920,
    --   height = 1080
    -- }

    if not attachments or #attachments == 0 then
        return ""
    end

    local image_html = {}

    for _, attachment in ipairs(attachments) do
        -- Only process image types
        local media_type = attachment.media_type or ""
        if media_type:match("^image/") then
            -- Issue 8-048: Use flat output/media/ path structure for easier deployment
            -- Extract basename from relative_path (e.g., "files/112/.../abc.png" -> "abc.png")
            -- The convert-urls script handles conversion to production paths
            local base_path = "file:///home/ritz/programming/ai-stuff/neocities-modernization"
            local relative_path = attachment.relative_path or ""
            local basename = relative_path:match("([^/]+)$") or relative_path
            local img_src = base_path .. "/output/media/" .. basename

            -- Use alt text if available, otherwise generate generic description
            -- Issue 9-012: ActivityPub uses 'description' field for alt-text
            local alt_text = attachment.description or attachment.alt_text or "Image attachment"
            -- Issue 8-053: Normalize newlines to spaces for clean HTML attributes
            alt_text = alt_text:gsub("\n", " "):gsub("\r", "")
            -- Escape quotes in alt text for HTML attribute
            alt_text = alt_text:gsub('"', '&quot;')

            -- Build image tag with lazy loading for performance
            -- Issue 8-005 Fix: Add max-width to prevent viewport overflow
            -- display:block prevents multiple images from appearing side-by-side
            -- max-width:min(100%,800px) caps at content width (~80 chars) while being responsive
            -- width/height hints help browser reserve space before load (aspect ratio preserved)
            -- Issue 8-053: title attribute provides mouse-over tooltip for sighted users
            local img_tag
            if attachment.width and attachment.height then
                img_tag = string.format(
                    '  <img src="%s" alt="%s" title="%s" loading="lazy" width="%d" height="%d" style="display:block; max-width:min(100%%,800px); height:auto">',
                    img_src, alt_text, alt_text, attachment.width, attachment.height
                )
            else
                img_tag = string.format(
                    '  <img src="%s" alt="%s" title="%s" loading="lazy" style="display:block; max-width:min(100%%,800px); height:auto">',
                    img_src, alt_text, alt_text
                )
            end

            table.insert(image_html, img_tag)
        end
    end

    if #image_html == 0 then
        return ""
    end

    -- Issue 8-005 Fix: Close </pre> before images, reopen after
    -- Images inside <pre> don't respect max-width:100% because <pre> sizes to content
    -- By closing </pre>, images inherit width constraints from the parent <td> container
    return "\n</pre>\n" .. table.concat(image_html, "\n") .. "\n<pre>\n"
end
-- }}}

-- {{{ function render_attachment_images_txt
local function render_attachment_images_txt(attachments)
    -- Render plain text placeholders for poem attachments (images)
    -- Returns [Image: alt-text] format for TXT export
    -- Unlike render_attachment_images(), this outputs plain text, not HTML
    --
    -- This function exists because TXT exports cannot contain HTML <img> tags.
    -- Images are replaced with bracketed alt-text descriptions.

    if not attachments or #attachments == 0 then
        return ""
    end

    local image_lines = {}

    for _, attachment in ipairs(attachments) do
        -- Only process image types
        local media_type = attachment.media_type or ""
        if media_type:match("^image/") then
            -- Use alt text if available, otherwise indicate no description
            local alt_text = attachment.alt_text or "no description"

            -- Format as bracketed placeholder, wrapped at 80 chars if needed
            local placeholder = string.format("[Image: %s]", alt_text)

            -- Wrap long alt-text to 80 characters
            if #placeholder > 80 then
                placeholder = wrap_text_80_chars(placeholder)
            end

            table.insert(image_lines, placeholder)
        end
    end

    if #image_lines == 0 then
        return ""
    end

    -- Return with newline prefix/suffix for proper spacing
    return "\n" .. table.concat(image_lines, "\n") .. "\n"
end
-- }}}

-- {{{ function format_warning_box
local function format_warning_box(warning_text)
    -- Create simple ASCII box around content warning
    local content = wrap_text_80_chars(warning_text)
    local lines = {}
    for line in content:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    
    -- Find longest line for box width
    local max_width = 0
    for _, line in ipairs(lines) do
        max_width = math.max(max_width, #line)
    end
    
    -- Ensure minimum width and maximum of 76 chars (leave room for box borders)
    max_width = math.min(math.max(max_width, 20), 76)
    
    local boxed = {}
    table.insert(boxed, "┌" .. string.rep("─", max_width + 2) .. "┐")
    
    for _, line in ipairs(lines) do
        local padded = line .. string.rep(" ", max_width - #line)
        table.insert(boxed, "│ " .. padded .. " │")
    end
    
    table.insert(boxed, "└" .. string.rep("─", max_width + 2) .. "┘")
    
    return table.concat(boxed, "\n")
end
-- }}}

-- {{{ function escape_html
local function escape_html(text)
    -- Escape HTML special characters in poem content to prevent browser interpretation
    -- Issue 8-041: Fixes bug where poem content containing </pre> breaks page rendering
    -- IMPORTANT: Must be called BEFORE apply_markdown_formatting() so that
    -- markdown-generated HTML tags (like <em>) are NOT escaped
    -- Order matters: & must be escaped first, otherwise &lt; becomes &amp;lt;
    if not text then return "" end
    return text
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
end
-- }}}

-- {{{ function apply_markdown_formatting
local function apply_markdown_formatting(text)
    -- Handle *\*text*\* (italics with asterisks)
    text = text:gsub("%*\\%*([^%*]+)%*\\%*", "<em>*%1*</em>")

    -- Handle *text* (simple italics)
    text = text:gsub("%*([^%*]+)%*", "<em>%1</em>")

    return text
end
-- }}}

-- {{{ function is_golden_poem
local function is_golden_poem(poem)
    -- Issue 8-044: Use pre-calculated golden status from extraction metadata
    -- This correctly accounts for:
    --   - Pre-anonymization content (original @mentions preserved)
    --   - Content warning text (without "CW: " prefix)
    -- The extraction calculates this once; we use metadata as single source of truth
    if poem.metadata and poem.metadata.is_golden_poem then
        return true
    end
    return false
end
-- }}}

-- {{{ function get_poem_display_filename
local function get_poem_display_filename(poem)
    -- Returns the display filename for a poem (without extension)
    -- For notes: uses metadata.source_file (the original filename)
    -- For fediverse/messages: uses the numeric ID
    -- All categories: no .txt extension (cleaner display)
    local category = poem.category or "unknown"
    local filename

    if category == "notes" and poem.metadata and poem.metadata.source_file then
        -- Notes preserve their original descriptive filenames
        filename = poem.metadata.source_file
    else
        -- Fediverse and messages use numeric ID
        filename = tostring(poem.id or "unknown")
    end

    return category .. "/" .. filename
end
-- }}}

-- {{{ function generate_corner_box_separator
local function generate_corner_box_separator(hex_color)
    -- Generate the separator line with corner box tops for GOLDEN poems
    -- Format: ╟─────────┐                    ┌───────────┤
    -- Left box: 11 chars (╟ + 9×─ + ┐)
    -- Right box: 13 chars (┌ + 11×─ + ┤)
    -- Gap: 60 chars (spaces)
    -- Total: 84 chars
    -- The left junction ╟ is colored to match the progress bar
    local colored_junction = string.format('<font color="%s"><b>╟</b></font>', hex_color)
    local left_box = colored_junction .. string.rep("─", 9) .. "┐"
    local right_box = "┌" .. string.rep("─", 11) .. "┤"
    local gap = string.rep(" ", 60)
    return left_box .. gap .. right_box
end
-- }}}

-- {{{ function colorize_char
-- Helper to wrap a character in color tags
local function colorize_char(char, hex_color)
    if hex_color then
        return string.format('<font color="%s"><b>%s</b></font>', hex_color, char)
    end
    return char
end
-- }}}

-- {{{ function generate_regular_corner_box_top
-- Issue 8-035: Added progress_chars and hex_color for progressive colorization
local function generate_regular_corner_box_top(progress_chars, hex_color)
    -- Generate the top line of corner boxes for REGULAR poems (no side walls)
    -- Format: ┌─────────┐                    ┌───────────┐
    -- Left box: 11 chars (┌ + 9×─ + ┐) at positions 0-10
    -- Right box: 13 chars (┌ + 11×─ + ┐) at positions 70-82
    -- Gap: 59 chars (spaces) at positions 11-69
    -- Total: 83 chars

    progress_chars = progress_chars or 0

    -- Left box (positions 0-10)
    local left_parts = {}
    -- Position 0: ┌
    table.insert(left_parts, progress_chars > 0 and colorize_char("┌", hex_color) or "┌")
    -- Positions 1-9: ─────────
    for i = 1, 9 do
        table.insert(left_parts, progress_chars > i and colorize_char("─", hex_color) or "─")
    end
    -- Position 10: ┐
    table.insert(left_parts, progress_chars > 10 and colorize_char("┐", hex_color) or "┐")

    -- Gap (positions 11-69) - spaces don't need coloring
    local gap = string.rep(" ", 59)

    -- Right box (positions 70-82)
    local right_parts = {}
    -- Position 70: ┌
    table.insert(right_parts, progress_chars > 70 and colorize_char("┌", hex_color) or "┌")
    -- Positions 71-81: ───────────
    for i = 71, 81 do
        table.insert(right_parts, progress_chars > i and colorize_char("─", hex_color) or "─")
    end
    -- Position 82: ┐
    table.insert(right_parts, progress_chars > 82 and colorize_char("┐", hex_color) or "┐")

    return table.concat(left_parts) .. gap .. table.concat(right_parts)
end
-- }}}

-- {{{ function generate_regular_corner_box_bottom
local function generate_regular_corner_box_bottom()
    -- Generate the bottom line of corner boxes for REGULAR poems
    -- Format: └─────────┘                    └───────────┘
    -- Gap: 59 chars, Total: 83 chars
    local left_box = "└" .. string.rep("─", 9) .. "┘"
    local right_box = "└" .. string.rep("─", 11) .. "┘"
    local gap = string.rep(" ", 59)
    return left_box .. gap .. right_box
end
-- }}}

-- {{{ function generate_corner_box_nav_line
local function generate_corner_box_nav_line(similar_link, different_link, chronological_link, hex_color)
    -- Generate the navigation line with corner box walls for GOLDEN poems (Issue 8-030)
    -- Format: ║ similar │      chronological      │ different │
    -- Left box: ║ + space + link + space + │ = 11 chars
    -- Center text: chronological (13 chars visible) - or empty space if nil (on chronological.html)
    -- Right box: │ + space + link + space + │ = 13 chars
    -- Gaps: 2 gaps of ~23 chars each
    -- Total: 84 chars
    -- The left wall ║ is colored to match the progress bar

    -- The links contain HTML, so we need to measure visible text
    local similar_visible = similar_link:gsub("<[^>]+>", "")  -- "similar"
    local different_visible = different_link:gsub("<[^>]+>", "")  -- "different"

    -- Handle nil chronological_link (on chronological.html page, we don't show this link)
    local center_text = ""
    local center_visible_len = 0
    if chronological_link then
        center_text = chronological_link
        center_visible_len = chronological_link:gsub("<[^>]+>", ""):len()  -- "chronological" = 13 chars
    end

    -- Left box: ║ (colored) + space + similar + padding + │
    local colored_wall = string.format('<font color="%s"><b>║</b></font>', hex_color)
    local left_content_width = 9  -- space between ║ and │
    local similar_padding = left_content_width - 1 - #similar_visible  -- 1 for leading space
    local left_box = colored_wall .. " " .. similar_link .. string.rep(" ", similar_padding) .. "│"

    -- Right box: │ + space + different + padding + │
    local right_content_width = 11  -- space between │ and │
    local different_padding = right_content_width - 1 - #different_visible  -- 1 for leading space
    local right_box = "│ " .. different_link .. string.rep(" ", different_padding) .. "│"

    -- Calculate gaps: Total 84 - 11 (left) - center_visible - 13 (right) = remaining
    -- If no center text, distribute all 47+13 = 60 chars into the gaps (30 left, 30 right)
    -- If center text (13 chars), split remaining 47 into 22 left + 25 right
    local left_gap, right_gap
    if center_visible_len > 0 then
        left_gap = string.rep(" ", 22)
        right_gap = string.rep(" ", 25)
    else
        -- No chronological link - distribute 60 chars evenly (30+30)
        left_gap = string.rep(" ", 30)
        right_gap = string.rep(" ", 30)
    end

    return left_box .. left_gap .. center_text .. right_gap .. right_box
end
-- }}}

-- {{{ function generate_regular_corner_box_nav_line
-- Issue 8-035: Added progress_chars and hex_color for progressive colorization
local function generate_regular_corner_box_nav_line(similar_link, different_link, chronological_link, progress_chars, hex_color)
    -- Generate the navigation line with corner box walls for REGULAR poems (Issue 8-030)
    -- Format: │ similar │      chronological      │ different │
    -- Left box: │ + space + link + space + │ = 11 chars (positions 0-10)
    -- Center text: chronological (13 chars visible) - or empty space if nil (on chronological.html)
    -- Right box: │ + space + link + space + │ = 13 chars (positions 70-82)
    -- Gaps: 2 gaps totaling 59 chars (with 13 char center text: 23 left + 23 right)
    -- Total: 83 chars

    progress_chars = progress_chars or 0

    local similar_visible = similar_link:gsub("<[^>]+>", "")
    local different_visible = different_link:gsub("<[^>]+>", "")

    -- Handle nil chronological_link (on chronological.html page, we don't show this link)
    local center_text = ""
    local center_visible_len = 0
    if chronological_link then
        center_text = chronological_link
        center_visible_len = chronological_link:gsub("<[^>]+>", ""):len()  -- "chronological" = 13 chars
    end

    -- Left box: │ + space + similar + padding + │
    -- Wall characters at positions 0 and 10
    local left_wall = progress_chars > 0 and colorize_char("│", hex_color) or "│"
    local right_wall_of_left = progress_chars > 10 and colorize_char("│", hex_color) or "│"
    local left_content_width = 9
    local similar_padding = left_content_width - 1 - #similar_visible
    local left_box = left_wall .. " " .. similar_link .. string.rep(" ", similar_padding) .. right_wall_of_left

    -- Right box: │ + space + different + padding + │
    -- Wall characters at positions 70 and 82
    local left_wall_of_right = progress_chars > 70 and colorize_char("│", hex_color) or "│"
    local right_wall = progress_chars > 82 and colorize_char("│", hex_color) or "│"
    local right_content_width = 11
    local different_padding = right_content_width - 1 - #different_visible
    local right_box = left_wall_of_right .. " " .. different_link .. string.rep(" ", different_padding) .. right_wall

    -- Calculate gaps: Total 83 - 11 (left) - 13 (right) = 59 for gaps + center
    -- If no center text, distribute 59 chars into the gaps (29 left, 30 right)
    -- If center text (13 chars), split remaining 46 into 23 left + 23 right
    local left_gap, right_gap
    if center_visible_len > 0 then
        left_gap = string.rep(" ", 23)
        right_gap = string.rep(" ", 23)
    else
        -- No chronological link - distribute 59 chars (29+30)
        left_gap = string.rep(" ", 29)
        right_gap = string.rep(" ", 30)
    end

    return left_box .. left_gap .. center_text .. right_gap .. right_box
end
-- }}}

-- {{{ function apply_golden_poem_formatting
local function apply_golden_poem_formatting(content, is_golden, similar_link, different_link, chronological_link, hex_color)
    -- Golden poem side borders: ║ on left (colored), │ on right
    -- Interior width: 80 characters for content (with 1 space padding on each side)
    -- Format: ║ + space + 80 chars content (padded) + space + │ = 84 total
    -- The left wall ║ is colored to match the progress bar
    if not is_golden then
        return content
    end

    local CONTENT_WIDTH = 80  -- Content area between padding spaces
    local color = hex_color or "#787878"  -- Default to gray if no color provided

    -- Helper to count UTF-8 characters (not bytes)
    -- Box-drawing chars are 3 bytes each, so #str gives wrong count
    local function utf8_char_count(str)
        -- Remove UTF-8 continuation bytes (0x80-0xBF), count what remains
        return #(str:gsub("[\128-\191]", ""))
    end

    -- Split content into lines (append newline to handle last line without trailing newline)
    local lines = {}
    for line in (content .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end

    local formatted_lines = {}
    local colored_wall = string.format('<font color="%s"><b>║</b></font>', color)

    for _, line in ipairs(lines) do
        -- Calculate visible length (excluding HTML tags, counting UTF-8 chars)
        local visible_line = line:gsub("<[^>]+>", "")
        local visible_length = utf8_char_count(visible_line)

        -- Pad or handle line to fit content width
        local padded_line
        if visible_length >= CONTENT_WIDTH then
            -- Line is already at or over width - use as-is
            padded_line = line
        else
            -- Pad with spaces to reach content width
            local padding_needed = CONTENT_WIDTH - visible_length
            padded_line = line .. string.rep(" ", padding_needed)
        end

        -- Add side borders with padding: ║ (colored) content │
        table.insert(formatted_lines, colored_wall .. " " .. padded_line .. " │")
    end

    -- Add corner box navigation (separator + nav line) if links provided
    -- Issue 9-003 Fix: Only require similar and different links - chronological_link can be nil
    if similar_link and different_link then
        -- Add separator line with corner box tops: ╟─────────┐      ┌───────────┤
        table.insert(formatted_lines, generate_corner_box_separator(color))
        -- Add navigation line with corner box walls: ║ similar │ chronological │ different │
        -- chronological_link may be nil on chronological.html (shows empty space in center)
        table.insert(formatted_lines, generate_corner_box_nav_line(similar_link, different_link, chronological_link, color))
    end

    return table.concat(formatted_lines, "\n")
end
-- }}}

-- {{{ function format_content_with_warnings
local function format_content_with_warnings(text, poem_category, poem, similar_link, different_link, chronological_link, hex_color)
    -- Issue 8-041: Escape HTML special characters in poem content FIRST
    -- This prevents browser from interpreting poem content as HTML markup
    -- (e.g., a poem containing "</pre>" would otherwise close the preformatted block)
    text = escape_html(text)

    -- Apply markdown formatting AFTER escaping
    -- This allows *italics* to become <em>italics</em> while keeping
    -- literal < > & in poem content safely escaped
    text = apply_markdown_formatting(text)

    -- Check if this is a golden poem
    local is_golden = poem and is_golden_poem(poem)

    local formatted_lines = {}

    -- Issue 9-011: Display content warning from poem.content_warning field (Mastodon CW)
    -- This is separate from in-content CW: patterns - it comes from ActivityPub summary field
    if poem and poem.content_warning and poem.content_warning ~= "" then
        local cw_label = "CW: " .. poem.content_warning
        local warning_box = format_warning_box(cw_label)
        table.insert(formatted_lines, warning_box)
        table.insert(formatted_lines, "") -- First newline
        table.insert(formatted_lines, "") -- Second newline for spacing
    end

    -- Detect additional content warning patterns in text (CW:, content warning:, etc.)
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    local i = 1

    while i <= #lines do
        local line = lines[i]

        -- Check if line starts with content warning (in-content CW pattern)
        if line:lower():match("^%s*cw%s*:") or line:lower():match("^%s*content warning%s*:") then
            -- Format content warning with box
            local warning_box = format_warning_box(line)
            table.insert(formatted_lines, warning_box)
            table.insert(formatted_lines, "") -- First newline
            table.insert(formatted_lines, "") -- Second newline for spacing
        else
            -- Preserve whitespace for notes-dir poems (artistic formatting)
            if poem_category == "notes" then
                table.insert(formatted_lines, line)
            else
                -- Wrap long lines to 80 chars while preserving paragraph breaks
                local wrapped = wrap_text_80_chars(line)
                for wrapped_line in (wrapped .. "\n"):gmatch("(.-)\n") do
                    table.insert(formatted_lines, wrapped_line)
                end
            end
        end

        i = i + 1
    end

    local formatted_content = table.concat(formatted_lines, "\n")

    -- Apply golden poem box-drawing formatting (with corner box nav inside)
    if is_golden then
        formatted_content = apply_golden_poem_formatting(formatted_content, true, similar_link, different_link, chronological_link, hex_color)
    else
        -- For regular poems, add 1-space left padding to each content line
        -- Content uses 1-space indent for alignment (83 chars total width)
        local padded_lines = {}
        for line in (formatted_content .. "\n"):gmatch("(.-)\n") do
            table.insert(padded_lines, " " .. line)
        end
        formatted_content = table.concat(padded_lines, "\n")
    end

    return formatted_content, is_golden
end
-- }}}

-- {{{ function format_single_poem_with_progress_and_color
local function format_single_poem_with_progress_and_color(poem, total_poems, poem_colors)
    local formatted = ""

    -- Get semantic color for this poem (key by poem_index, NOT poem.id)
    local poem_color_data = poem_colors[poem.poem_index]
    local semantic_color = poem_color_data and poem_color_data.color or "gray"
    local hex_color = COLOR_CONFIG[semantic_color] or COLOR_CONFIG["gray"]

    -- Calculate chronological progress (using poem_index for lookup)
    local progress_info = calculate_chronological_progress(poem.poem_index, total_poems)

    -- Check if this is a golden poem (exactly 1024 characters)
    local is_golden = is_golden_poem(poem)

    -- Build navigation links for this poem (using category prefix for anchors, poem_index for paginated files)
    local unique_id = get_unique_poem_filename_id(poem)  -- For anchor IDs only (e.g. "messages-0001")
    local anchor_id = get_poem_anchor_id(poem)
    local poem_index = poem.poem_index or 0  -- Numeric ID for paginated files (e.g. 1 → "0001")

    -- Issue 8-012 Phase E: Link to paginated format (similar/0001-01.html)
    -- Issue 9-003: Use absolute file:// paths - helper script converts to production URLs
    local base_path = "file:///home/ritz/programming/ai-stuff/neocities-modernization/output"
    local similar_link = string.format("<a href='%s/similar/%04d-01.html'>similar</a>", base_path, poem_index)
    local different_link = string.format("<a href='%s/different/%04d-01.html'>different</a>", base_path, poem_index)
    -- Issue 8-039: Chronological now in subdirectory
    local chronological_link = string.format("<a href='%s/chronological/index.html#%s'>chronological</a>", base_path, anchor_id)

    -- Add file header (notes show original filename, others show numeric ID)
    formatted = formatted .. string.format(" -> file: %s\n", get_poem_display_filename(poem))

    -- Generate top progress bar separator (with golden corners if applicable)
    local top_dashes = generate_progress_dashes(progress_info, semantic_color, is_golden, "top")
    formatted = formatted .. string.format('<span %s>%s</span>',
                                          top_dashes.accessibility,
                                          top_dashes.visual)

    -- Add newline after top border for all poems
    -- Golden poems: ┐ corner needs newline before ║ content wall on next line
    -- Regular poems: progress bar needs newline before content
    formatted = formatted .. "\n"

    -- Format poem content with content warning handling and whitespace preservation
    -- Pass nav links and hex_color for golden poems
    local content_formatted = format_content_with_warnings(
        poem.content or "", poem.category, poem,
        is_golden and similar_link or nil,
        is_golden and different_link or nil,
        is_golden and chronological_link or nil,
        is_golden and hex_color or nil
    )
    formatted = formatted .. content_formatted

    -- Render attached images if present (from ActivityPub extraction)
    -- Images appear after poem content, before navigation links
    -- Issue 9-010: Images stay with their original post only (no associated_images rendering)
    if poem.attachments then
        formatted = formatted .. render_attachment_images(poem.attachments)
    end

    -- For golden poems, content already includes nav in corner boxes
    -- For regular poems, add corner-boxed navigation links (top and nav lines only, bottom connects to progress bar)
    if not is_golden then
        -- Issue 8-035: Calculate progress_chars and hex_color for nav box colorization
        local total_chars = LAYOUT.REGULAR_POEM_WIDTH
        local progress_chars = math.floor((progress_info.percentage / 100) * total_chars)
        local hex_color = COLOR_CONFIG[semantic_color]

        formatted = formatted .. "\n"
        formatted = formatted .. generate_regular_corner_box_top(progress_chars, hex_color) .. "\n"
        formatted = formatted .. generate_regular_corner_box_nav_line(similar_link, different_link, chronological_link, progress_chars, hex_color) .. "\n"
        -- No bottom line - corner boxes connect directly to progress bar via junctions
    else
        -- Golden poems: add newline after nav line (content_formatted doesn't end with newline)
        formatted = formatted .. "\n"
    end

    -- Generate bottom progress bar separator (with junctions for both golden and regular poems)
    -- The has_corner_boxes parameter enables junction characters at wall positions
    local bottom_dashes = generate_progress_dashes(progress_info, semantic_color, is_golden, "bottom", true)
    formatted = formatted .. string.format('<span %s>%s</span>\n',
                                          bottom_dashes.accessibility,
                                          bottom_dashes.visual)

    return {
        content = formatted,
        semantic_color = semantic_color,
        progress_percentage = progress_info.percentage,
        poem_id = poem.id
    }
end
-- }}}

-- {{{ function format_single_poem_with_warnings
local function format_single_poem_with_warnings(poem)
    local formatted = ""

    -- Add file header (notes show original filename, others show numeric ID)
    formatted = formatted .. string.format(" -> file: %s\n", get_poem_display_filename(poem))
    formatted = formatted .. string.rep("-", 80) .. "\n"

    -- Format poem content with content warning handling and whitespace preservation
    formatted = formatted .. format_content_with_warnings(poem.content or "", poem.category, poem)

    -- Render attached images if present
    if poem.attachments then
        formatted = formatted .. render_attachment_images(poem.attachments)
    end

    return formatted
end
-- }}}

-- {{{ function format_single_poem_80_width
local function format_single_poem_80_width(poem)
    -- Format a single poem for TXT export (80-character width, no HTML)
    -- Uses strip_html_tags() to remove HTML and render_attachment_images_txt() for images
    local formatted = ""

    -- Add file header (notes show original filename, others show numeric ID)
    formatted = formatted .. string.format(" -> file: %s\n", get_poem_display_filename(poem))
    formatted = formatted .. string.rep("-", 80) .. "\n"

    -- Strip HTML tags and format poem content to 80-character width
    local clean_content = strip_html_tags(poem.content or "")
    formatted = formatted .. wrap_text_80_chars(clean_content)

    -- Render attached images as [Image: alt-text] placeholders (not HTML)
    if poem.attachments then
        formatted = formatted .. render_attachment_images_txt(poem.attachments)
    end

    return formatted
end
-- }}}

-- {{{ function format_all_poems_with_progress_and_color
local function format_all_poems_with_progress_and_color(starting_poem, sorted_poems, total_poems, poem_colors)
    local content = ""
    
    -- Add starting poem first with progress visualization
    local formatted_starting = format_single_poem_with_progress_and_color(starting_poem, total_poems, poem_colors)
    content = content .. formatted_starting.content .. "\n\n"
    
    -- Add all other poems sorted by similarity/diversity
    for _, poem_info in ipairs(sorted_poems) do
        if poem_info.id ~= starting_poem.id then  -- Skip starting poem since we already added it
            local formatted_poem = format_single_poem_with_progress_and_color(poem_info.poem, total_poems, poem_colors)
            content = content .. formatted_poem.content .. "\n\n"
        end
    end
    
    return content
end
-- }}}

-- {{{ function format_all_poems_with_content_warnings
local function format_all_poems_with_content_warnings(starting_poem, sorted_poems)
    local content = ""
    
    -- Add starting poem first
    content = content .. format_single_poem_with_warnings(starting_poem)
    content = content .. "\n\n"
    
    -- Add all other poems sorted by similarity/diversity
    for _, poem_info in ipairs(sorted_poems) do
        if poem_info.id ~= starting_poem.id then  -- Skip starting poem since we already added it
            content = content .. format_single_poem_with_warnings(poem_info.poem)
            content = content .. "\n\n"
        end
    end
    
    return content
end
-- }}}

-- {{{ function format_all_poems_80_width
local function format_all_poems_80_width(starting_poem, sorted_poems)
    local content = ""
    
    -- Add starting poem first
    content = content .. format_single_poem_80_width(starting_poem)
    content = content .. "\n\n"
    
    -- Add all other poems sorted by similarity/diversity
    for _, poem_info in ipairs(sorted_poems) do
        if poem_info.id ~= starting_poem.id then  -- Skip starting poem since we already added it
            content = content .. format_single_poem_80_width(poem_info.poem)
            content = content .. "\n\n"
        end
    end
    
    return content
end
-- }}}

-- {{{ function M.generate_flat_poem_list_html_with_progress
function M.generate_flat_poem_list_html_with_progress(starting_poem, sorted_poems, page_type, starting_poem_id, use_progress)
    -- Template uses pure HTML without CSS
    -- Content is pre-wrapped to 80 chars, <pre> provides monospace formatting
    -- Issue 9-003 Fix: Use centered table for block centering with left-aligned text inside
    local template = [[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Poems sorted by %s to: %s</title>
</head>
<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">
<center>
<h1>Poetry Collection</h1>
<p>All poems sorted by %s to: %s</p>
</center>
<table align="center"><tr><td>
<pre>
%s
</pre>
</td></tr></table>
</body>
</html>]]
    
    local formatted_content
    
    if use_progress then
        -- Load poem colors and use enhanced formatting
        local poem_colors = load_poem_colors()
        
        -- Calculate actual total poems by finding the maximum poem ID
        -- This represents the total chronological span of the corpus
        local max_poem_id = starting_poem.id or 1
        
        for _, poem_info in ipairs(sorted_poems) do
            if poem_info.id and poem_info.id > max_poem_id then
                max_poem_id = poem_info.id
            elseif poem_info.poem and poem_info.poem.id and poem_info.poem.id > max_poem_id then
                max_poem_id = poem_info.poem.id
            end
        end
        
        local total_poems = max_poem_id
        
        formatted_content = format_all_poems_with_progress_and_color(starting_poem, sorted_poems, total_poems, poem_colors)
    else
        -- Use standard formatting with content warnings
        formatted_content = format_all_poems_with_content_warnings(starting_poem, sorted_poems)
    end
    
    local page_type_desc = (page_type == "similar") and "similarity" or "difference"
    local starting_title = starting_poem.title or ("Poem " .. starting_poem_id)
    
    return string.format(template, 
                        page_type_desc,
                        starting_title,
                        page_type_desc, 
                        starting_title,
                        formatted_content)
end
-- }}}

-- {{{ function M.generate_flat_poem_list_html
function M.generate_flat_poem_list_html(starting_poem, sorted_poems, page_type, starting_poem_id)
    -- Default to using progress bars
    return M.generate_flat_poem_list_html_with_progress(starting_poem, sorted_poems, page_type, starting_poem_id, true)
end
-- }}}

-- {{{ local function generate_download_links
-- Generates download links for full-corpus exports (.txt and .html archive)
-- poem_id: the anchor poem's ID (used for unique filename)
-- page_type: "similar" or "different"
-- Returns: HTML string with download links
local function generate_download_links(poem_id, page_type)
    -- Generate unique filename ID (with category prefix)
    local unique_id = string.format("%04d", poem_id)

    -- Full-corpus export filenames (not paginated)
    local txt_file = string.format("%s/%s.txt", page_type, unique_id)
    local html_archive_file = string.format("%s/%s-archive.html", page_type, unique_id)

    local links = {}
    table.insert(links, "Download full collection:")
    table.insert(links, string.format(' [<a href="%s">.txt</a>]', txt_file))
    table.insert(links, string.format(' [<a href="%s">.html</a>]', html_archive_file))

    return table.concat(links, " ")
end
-- }}}

-- {{{ function M.generate_paginated_poem_page_html
-- Generates a single paginated page with navigation
-- starting_poem: the anchor poem object
-- sorted_poems: full sorted list of all poems
-- page_type: "similar" or "different"
-- starting_poem_id: the anchor poem's ID
-- page_num: 1-indexed page number
-- total_pages: total number of pages (may be capped by max_pages_per_poem)
-- total_corpus: optional - total poems in full corpus (for storage context display)
-- Returns: HTML string for this specific page
-- Updated for Issue 8-020: Passes total_corpus to navigation for storage constraint messaging
function M.generate_paginated_poem_page_html(starting_poem, sorted_poems, page_type, starting_poem_id, page_num, total_pages, total_corpus)
    -- Ensure pagination config is loaded
    load_pagination_config()

    -- Get poems for this specific page
    local page_poems = get_poems_for_page(sorted_poems, page_num)

    if #page_poems == 0 then
        utils.log_warn(string.format("No poems found for page %d of %s/%d",
            page_num, page_type, starting_poem_id))
        return nil
    end

    -- Use provided total_corpus or calculate from sorted_poems
    local corpus_size = total_corpus or #sorted_poems

    -- Generate header navigation (with storage context)
    local header_nav = generate_prev_next_navigation(page_num, total_pages, starting_poem_id, page_type, corpus_size)

    -- Generate footer navigation (same as header)
    local footer_nav = generate_prev_next_navigation(page_num, total_pages, starting_poem_id, page_type, corpus_size)

    -- Load poem colors for progress bars
    local poem_colors = load_poem_colors()

    -- Calculate actual total poems (max ID in corpus)
    local max_poem_id = starting_poem.id or 1
    for _, poem_info in ipairs(sorted_poems) do
        local pid = poem_info.id or (poem_info.poem and poem_info.poem.id)
        if pid and pid > max_poem_id then
            max_poem_id = pid
        end
    end
    local corpus_total = max_poem_id

    -- Format the poems for this page
    local formatted_content = format_all_poems_with_progress_and_color(
        starting_poem, page_poems, corpus_total, poem_colors)

    -- Build the page
    local page_type_desc = (page_type == "similar") and "similarity" or "difference"
    local starting_title = starting_poem.title or ("Poem " .. starting_poem_id)
    local padded_id = string.format("%04d", starting_poem_id)

    -- Generate download links for full-corpus exports
    local download_links = generate_download_links(starting_poem_id, page_type)

    -- Issue 9-003 Fix: Use centered table for block centering with left-aligned text inside
    local template = [[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Poems sorted by %s to: %s (Page %d of %d)</title>
</head>
<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">
<center>
<h1>Poetry Collection</h1>
<p>Poems sorted by %s to: %s</p>
<p>%s</p>
</center>
<table align="center"><tr><td>
<pre>
%s

%s

%s
</pre>
</td></tr></table>
</body>
</html>]]

    return string.format(template,
        page_type_desc, starting_title, page_num, total_pages,
        page_type_desc, starting_title,
        download_links,
        header_nav,
        formatted_content,
        footer_nav)
end
-- }}}

-- {{{ function M.generate_all_paginated_pages_for_poem
-- Generates all paginated pages for a single poem's similarity or diversity ordering
-- starting_poem: the anchor poem object
-- sorted_poems: full sorted list of all poems
-- page_type: "similar" or "different"
-- starting_poem_id: the anchor poem's ID
-- output_dir: base output directory
-- pages_to_generate: optional - which pages to generate (nil = use config limits, or {1,2,3} for specific pages)
-- Returns: table with generated file paths and stats
-- Updated for Issue 8-020: Respects max_pages_per_poem storage constraint
function M.generate_all_paginated_pages_for_poem(starting_poem, sorted_poems, page_type, starting_poem_id, output_dir, pages_to_generate)
    -- Ensure pagination config is loaded
    load_pagination_config()

    local total_poems = #sorted_poems
    local total_pages_possible = calculate_page_count(total_poems)

    -- Apply max_pages_per_poem limit (Issue 8-020: 45GB storage constraint)
    local max_pages = PAGINATION_CONFIG.max_pages_per_poem
    local total_pages = math.min(total_pages_possible, max_pages)

    local results = {
        files_generated = {},
        total_pages = total_pages,
        total_pages_possible = total_pages_possible,  -- Before storage limit
        poems_per_page = PAGINATION_CONFIG.poems_per_page,
        poem_id = starting_poem_id,
        storage_limited = (total_pages < total_pages_possible)  -- Indicates if pages were capped
    }

    -- Determine which pages to generate
    local pages = pages_to_generate
    if not pages then
        -- Generate pages 1 through max_pages (respecting storage limit)
        pages = {}
        for i = 1, total_pages do
            table.insert(pages, i)
        end
    end

    -- Ensure output directory exists
    local page_dir = output_dir .. "/" .. page_type
    os.execute("mkdir -p " .. page_dir)

    -- Generate each requested page (respecting max_pages limit)
    for _, page_num in ipairs(pages) do
        if page_num <= total_pages then
            local html = M.generate_paginated_poem_page_html(
                starting_poem, sorted_poems, page_type, starting_poem_id,
                page_num, total_pages, total_poems)  -- Pass total_poems for storage context

            if html then
                local filename = generate_page_filename(starting_poem_id, page_num, page_type)
                local filepath = output_dir .. "/" .. filename

                if utils.write_file(filepath, html) then
                    table.insert(results.files_generated, filepath)
                end
            end
        end
    end

    return results
end
-- }}}

-- {{{ function M.get_pagination_config
-- Exposes pagination configuration for external scripts
-- Returns: PAGINATION_CONFIG table
function M.get_pagination_config()
    load_pagination_config()
    return PAGINATION_CONFIG
end
-- }}}

-- {{{ function M.get_storage_config
-- Exposes storage configuration for external scripts (Issue 8-020)
-- Returns: STORAGE_CONFIG table
function M.get_storage_config()
    load_pagination_config()  -- This also loads storage config
    return STORAGE_CONFIG
end
-- }}}

-- {{{ function M.calculate_page_count
-- Exposes page count calculation for external scripts
-- Returns: number of pages needed for given poem count
function M.calculate_page_count(total_poems)
    load_pagination_config()
    return calculate_page_count(total_poems)
end
-- }}}

-- {{{ local function generate_chronological_page_navigation
-- Issue 8-039: Files now in chronological/ subdirectory, use simpler relative paths
local function generate_chronological_page_navigation(current_page, total_pages)
    -- Generate pagination navigation for chronological pages
    -- Format: [« First] [‹ Prev] Page X of Y [Next ›] [Last »]
    -- Issue 8-039: Using relative paths within chronological/ directory (01.html, not chronological-01.html)
    if total_pages <= 1 then
        return ""
    end

    local nav_parts = {}

    -- First page link
    if current_page > 1 then
        table.insert(nav_parts, "<a href='01.html'>« First</a>")
    else
        table.insert(nav_parts, "« First")
    end

    -- Previous page link
    if current_page > 1 then
        table.insert(nav_parts, string.format("<a href='%02d.html'>‹ Prev</a>", current_page - 1))
    else
        table.insert(nav_parts, "‹ Prev")
    end

    -- Current page indicator
    table.insert(nav_parts, string.format("Page %d of %d", current_page, total_pages))

    -- Next page link
    if current_page < total_pages then
        table.insert(nav_parts, string.format("<a href='%02d.html'>Next ›</a>", current_page + 1))
    else
        table.insert(nav_parts, "Next ›")
    end

    -- Last page link
    if current_page < total_pages then
        table.insert(nav_parts, string.format("<a href='%02d.html'>Last »</a>", total_pages))
    else
        table.insert(nav_parts, "Last »")
    end

    -- Issue 8-052: Use Unicode box-drawing vertical for consistent HTML output
    return table.concat(nav_parts, " │ ")
end
-- }}}

-- {{{ function M.generate_chronological_index_with_navigation
-- Issue 9-003: chrono_per_page parameter allows CLI override of poems per page
function M.generate_chronological_index_with_navigation(poems_data, output_dir, chrono_per_page)
    -- Load pagination config for chronological settings (Issue 9-003 Fix F)
    load_pagination_config()

    local chronological_paginated = PAGINATION_CONFIG.chronological_paginated or false
    local poems_per_page = PAGINATION_CONFIG.chronological_poems_per_page or 500

    -- CLI override for chrono_per_page (Issue 9-003)
    if chrono_per_page and type(chrono_per_page) == "number" and chrono_per_page > 0 then
        utils.log_info(string.format("CLI override: chronological poems per page = %d (was %d)", chrono_per_page, poems_per_page))
        poems_per_page = chrono_per_page
        -- Also enable pagination if a CLI override is provided
        chronological_paginated = true
    end

    -- Sort poems chronologically (by actual post dates)
    local sorted_poems_with_timestamps = sort_poems_chronologically_by_dates(poems_data)
    local total_poems = #sorted_poems_with_timestamps

    -- Calculate pagination
    local total_pages = chronological_paginated and math.ceil(total_poems / poems_per_page) or 1
    if total_pages < 1 then total_pages = 1 end

    utils.log_info(string.format("Generating chronological HTML for %d poems (%d pages, %d poems/page)...",
        total_poems, total_pages, chronological_paginated and poems_per_page or total_poems))
    local generation_start = os.time()

    -- Load poem colors for progress bars
    local poem_colors = load_poem_colors()

    os.execute("mkdir -p " .. output_dir)

    local files_written = {}

    for page_num = 1, total_pages do
        -- Calculate poem range for this page
        local start_idx = (page_num - 1) * poems_per_page + 1
        local end_idx = chronological_paginated and math.min(page_num * poems_per_page, total_poems) or total_poems

        -- Generate page navigation
        local page_nav = generate_chronological_page_navigation(page_num, total_pages)
        local page_nav_html = page_nav ~= "" and string.format("<p>%s</p>", page_nav) or ""

        -- Template with optional pagination navigation
        -- Issue 9-003 Fix: Use centered table for block centering with left-aligned text inside
        local template
        if chronological_paginated and total_pages > 1 then
            template = string.format([[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Poetry Collection - Chronological Order (Page %d of %d)</title>
</head>
<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">
<center>
<h1>Poetry Collection</h1>
<p>Poems in true chronological order by post date</p>
%s
<p><a href="file:///home/ritz/programming/ai-stuff/neocities-modernization/output/wordcloud.html">Menu</a></p>
</center>
<table align="center"><tr><td>
<pre>
%%s
</pre>
</td></tr></table>
<center>%s</center>
</body>
</html>]], page_num, total_pages, page_nav_html, page_nav_html)
        else
            template = [[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Poetry Collection - Chronological Order</title>
</head>
<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">
<center>
<h1>Poetry Collection</h1>
<p>All poems in true chronological order by post date</p>
<p><a href="file:///home/ritz/programming/ai-stuff/neocities-modernization/output/wordcloud.html">Menu</a></p>
</center>
<table align="center"><tr><td>
<pre>
%s
</pre>
</td></tr></table>
</body>
</html>]]
        end

        -- Generate content for this page
        local content = ""
        for i = start_idx, end_idx do
            local poem_info = sorted_poems_with_timestamps[i]
            local poem = poem_info.poem
            local poem_id = poem.poem_index

            -- Progress output every 100 poems
            if i % 100 == 0 or i == total_poems then
                local elapsed = os.time() - generation_start
                local rate = i / math.max(elapsed, 1)
                local eta = (total_poems - i) / math.max(rate, 1)
                local progress_msg = string.format("\r   Processing poem %d/%d (%.1f%%) - %.1f poems/sec, ETA: %ds",
                    i, total_poems, (i / total_poems) * 100, rate, eta)
                io.write(progress_msg .. string.rep(" ", math.max(0, 80 - #progress_msg)))
                io.flush()
            end

            -- Calculate chronological progress based on temporal position (not ID)
            local temporal_progress = (i / total_poems) * 100
            local progress_info = {
                poem_id = poem_id,
                total_poems = total_poems,
                percentage = temporal_progress,
                position = i,
                temporal_index = i
            }

            local poem_color_data = poem_colors[poem_id]
            local semantic_color = poem_color_data and poem_color_data.color or "gray"
            local is_golden = is_golden_poem(poem)
            local anchor_id = get_poem_anchor_id(poem)
            local poem_index = poem.poem_index or 0

            -- Add HTML anchor
            content = content .. string.format('<span id="%s"></span>', anchor_id)
            content = content .. string.format(" -> file: %s\n", get_poem_display_filename(poem))

            -- Navigation links (absolute paths for consistency)
            -- Issue 9-003: Use absolute file:// paths - helper script converts to production URLs
            local base_path = "file:///home/ritz/programming/ai-stuff/neocities-modernization/output"
            local similar_link = string.format("<a href='%s/similar/%04d-01.html'>similar</a>", base_path, poem_index)
            local different_link = string.format("<a href='%s/different/%04d-01.html'>different</a>", base_path, poem_index)
            local chronological_link = nil  -- Issue 9-003 Fix C: No chronological link on chronological pages

            -- Generate top progress bar
            local top_dashes = generate_progress_dashes(progress_info, semantic_color, is_golden, "top")
            content = content .. string.format('<span %s>%s</span>\n',
                                              top_dashes.accessibility,
                                              top_dashes.visual)

            -- Add poem content
            local hex_color = COLOR_CONFIG[semantic_color] or COLOR_CONFIG["gray"]
            local formatted_content = format_content_with_warnings(
                poem.content or "", poem.category, poem,
                is_golden and similar_link or nil,
                is_golden and different_link or nil,
                is_golden and chronological_link or nil,
                is_golden and hex_color or nil
            )
            content = content .. formatted_content

            -- Add images if present
            -- Issue 9-010: Images stay with their original post only (no associated_images rendering)
            if poem.attachments and #poem.attachments > 0 then
                content = content .. render_attachment_images(poem.attachments)
            end

            -- Add navigation box for regular poems
            if not is_golden then
                -- Issue 8-035: Calculate progress_chars for nav box colorization
                local total_chars = LAYOUT.REGULAR_POEM_WIDTH
                local progress_chars = math.floor((progress_info.percentage / 100) * total_chars)

                content = content .. "\n"
                content = content .. generate_regular_corner_box_top(progress_chars, hex_color) .. "\n"
                content = content .. generate_regular_corner_box_nav_line(similar_link, different_link, chronological_link, progress_chars, hex_color) .. "\n"
            else
                content = content .. "\n"
            end

            -- Generate bottom progress bar
            local bottom_dashes = generate_progress_dashes(progress_info, semantic_color, is_golden, "bottom", true)
            content = content .. string.format('<span %s>%s</span>\n\n',
                                              bottom_dashes.accessibility,
                                              bottom_dashes.visual)
        end

        -- Write page file
        -- Issue 8-039: Files now in chronological/ subdirectory
        local final_html = string.format(template, content)
        local chrono_dir = output_dir .. "/chronological"
        os.execute(string.format('mkdir -p "%s"', chrono_dir))

        local output_file
        if chronological_paginated and total_pages > 1 then
            -- Paginated: chronological/01.html, chronological/02.html, etc.
            output_file = string.format("%s/%02d.html", chrono_dir, page_num)
        else
            -- Single page: chronological/index.html (for clean URL)
            output_file = chrono_dir .. "/index.html"
        end

        local success = utils.write_file(output_file, final_html)
        if success then
            table.insert(files_written, output_file)
        else
            utils.log_error("Failed to write: " .. output_file)
        end
    end

    io.write("\n")
    local total_elapsed = os.time() - generation_start
    utils.log_info(string.format("Chronological HTML generation complete: %d poems, %d pages in %d seconds",
        total_poems, total_pages, total_elapsed))

    -- Issue 8-039: For paginated chronological, create index.html redirect within the subdirectory
    if chronological_paginated and total_pages > 1 then
        local chrono_dir = output_dir .. "/chronological"
        local redirect_html = [[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta http-equiv="refresh" content="0;url=01.html">
<title>Redirecting...</title>
</head>
<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">
<p>Redirecting to <a href="01.html">01.html</a>...</p>
</body>
</html>]]
        utils.write_file(chrono_dir .. "/index.html", redirect_html)
        utils.log_info("✓ chronological/index.html created (redirect to 01.html)")
    end

    return files_written[1]
end
-- }}}

-- {{{ function M.generate_simple_discovery_instructions
function M.generate_simple_discovery_instructions(output_dir)
    -- Issue 9-003 Fix: Use centered table for block centering with left-aligned text inside
    local template = [[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Poetry Collection - How to Explore</title>
</head>
<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">
<center>
<h1>Poetry Collection - Exploration Guide</h1>
</center>
<table align="center"><tr><td>
<pre>
%s
</pre>
</td></tr></table>
</body>
</html>]]
    
    local instructions = wrap_text_80_chars([[
Welcome to the Poetry Collection.

This collection contains all poems with two ways to explore:

1. SIMILARITY EXPLORATION:
   Click "similar" next to any poem to see all other poems ranked by
   how similar they are to that poem. Most similar poems appear first.

2. DIFFERENCE EXPLORATION:
   Click "different" next to any poem to see all other poems ranked by
   maximum difference (most contrasting) from that poem. Creates surprising
   reading experiences by showing contrasting content.

Start from the main chronological index to browse all poems.
Every poem has both "similar" and "different" links for exploration.

Each exploration method shows ALL poems in the collection, just sorted
differently based on your chosen starting point.

The "similar" pages help you find more of what resonates with you.
The "different" pages help you discover unexpected contrasts and new perspectives.
]])
    
    local final_html = string.format(template, instructions)
    local output_file = output_dir .. "/explore.html"
    
    return utils.write_file(output_file, final_html) and output_file or nil
end
-- }}}

-- {{{ function generate_txt_file_header
local function generate_txt_file_header(title, total_poems)
    -- Generate a consistent header for TXT export files
    -- Matches the compiled.txt aesthetic with 80-character width
    local separator = string.rep("=", 80)
    local header = separator .. "\n"

    -- Center the title
    local padding = math.floor((80 - #title) / 2)
    header = header .. string.rep(" ", padding) .. title .. "\n"

    header = header .. separator .. "\n"
    header = header .. string.format("Total poems: %d\n", total_poems)
    header = header .. string.format("Generated: %s\n", os.date("%Y-%m-%d %H:%M:%S"))
    header = header .. separator .. "\n\n"

    return header
end
-- }}}

-- {{{ function generate_similarity_txt_file
function generate_similarity_txt_file(starting_poem, sorted_poems, output_file)
    -- Generate TXT export for similarity-sorted poems
    -- Includes file header with metadata and all poems formatted at 80-char width
    local title = string.format("POEMS SORTED BY SIMILARITY TO POEM %s", starting_poem.id or "?")
    local header = generate_txt_file_header(title, #sorted_poems + 1)
    local poems_content = format_all_poems_80_width(starting_poem, sorted_poems)
    local content = header .. poems_content
    return utils.write_file(output_file, content) and output_file or nil
end
-- }}}

-- {{{ function generate_similarity_html_archive
function generate_similarity_html_archive(starting_poem, sorted_poems, output_file)
    -- Generate HTML archive for similarity-sorted poems (full corpus with images)
    -- Unlike paginated pages, this is a single file with ALL poems
    -- Use poem_index (globally unique) for consistency
    local html = M.generate_flat_poem_list_html(starting_poem, sorted_poems, "similar", starting_poem.poem_index)
    return utils.write_file(output_file, html) and output_file or nil
end
-- }}}

-- {{{ function generate_diversity_txt_file
function generate_diversity_txt_file(starting_poem, sorted_poems, output_file)
    -- Generate TXT export for diversity-sorted poems
    -- Includes file header with metadata and all poems formatted at 80-char width
    local title = string.format("POEMS SORTED BY DIVERSITY FROM POEM %s", starting_poem.poem_index or "?")
    local header = generate_txt_file_header(title, #sorted_poems + 1)
    local poems_content = format_all_poems_80_width(starting_poem, sorted_poems)
    local content = header .. poems_content
    return utils.write_file(output_file, content) and output_file or nil
end
-- }}}

-- {{{ function generate_diversity_html_archive
function generate_diversity_html_archive(starting_poem, sorted_poems, output_file)
    -- Generate HTML archive for diversity-sorted poems (full corpus with images)
    -- Unlike paginated pages, this is a single file with ALL poems
    -- Use poem_index (globally unique) for consistency
    local html = M.generate_flat_poem_list_html(starting_poem, sorted_poems, "different", starting_poem.poem_index)
    return utils.write_file(output_file, html) and output_file or nil
end
-- }}}

-- {{{ function M.generate_chronological_txt_file
function M.generate_chronological_txt_file(poems_data, output_file)
    -- Generate TXT export for all poems in chronological order
    -- Uses actual post dates for sorting (not poem IDs)
    -- Includes file header with metadata and all poems formatted at 80-char width

    -- Sort poems chronologically by actual post dates
    local sorted_poems = sort_poems_chronologically_by_dates(poems_data)
    local total_poems = #sorted_poems

    -- Generate header
    local title = "POEMS IN CHRONOLOGICAL ORDER"
    local header = generate_txt_file_header(title, total_poems)

    -- Generate content for each poem
    local content = header
    for i, poem_info in ipairs(sorted_poems) do
        content = content .. format_single_poem_80_width(poem_info.poem)
        content = content .. "\n\n"
    end

    return utils.write_file(output_file, content) and output_file or nil
end
-- }}}

-- {{{ function M.generate_complete_flat_html_collection
-- Generates all similarity and diversity pages for the entire corpus
-- poems_data: full poems dataset
-- similarity_data: similarity matrix
-- embeddings_data: poem embeddings (for diversity calculation)
-- output_dir: base output directory
-- pages_spec: (optional) --pages flag value: nil/"default", "all", "1", "1-10" (Phase D: Issue 8-012)
-- poems_per_page: (optional) CLI override for poems per page (Issue 8-022)
-- num_threads: (optional) number of parallel threads (default: 1 = single-threaded)
-- chrono_per_page: (optional) CLI override for chronological poems per page (Issue 9-003)
function M.generate_complete_flat_html_collection(poems_data, similarity_data, embeddings_data, output_dir, pages_spec, poems_per_page, num_threads, chrono_per_page)
    -- Load diversity cache for fast HTML generation (Issue: diversity generation taking 42+ hours)
    -- Cache provides instant lookup of pre-computed GPU diversity sequences
    load_diversity_cache()

    -- Load similarity rankings cache for fast HTML generation
    -- Cache provides instant lookup of pre-sorted similarity rankings (no O(n log n) sorting per poem)
    load_similarity_rankings_cache()

    -- Load pagination config first
    load_pagination_config()

    -- Issue 8-048: Flatten media files to output/media/ for easier deployment
    -- Must happen before HTML generation so paths resolve correctly
    flatten_media_files(output_dir)

    -- Apply CLI override for poems_per_page if provided (Issue 8-022)
    if poems_per_page and type(poems_per_page) == "number" and poems_per_page > 0 then
        utils.log_info(string.format("CLI override: Using %d poems per page (config: %d)",
                                    poems_per_page, PAGINATION_CONFIG.poems_per_page))
        PAGINATION_CONFIG.poems_per_page = poems_per_page
    end

    -- Count poems with valid poem_index (globally unique identifier)
    -- Note: poem.id is per-category and NOT unique across categories
    -- poem_index is the globally unique identifier used by embeddings/similarity
    local valid_poems = {}
    for i, poem in ipairs(poems_data.poems) do
        if poem.poem_index then
            valid_poems[poem.poem_index] = poem
        end
    end

    local total_poems = 0
    for _ in pairs(valid_poems) do
        total_poems = total_poems + 1
    end

    -- Parse pages specification (Phase D: Issue 8-012)
    local pages_config = parse_pages_specification(pages_spec, nil)  -- total_pages not known yet
    local use_pagination = true  -- Always use pagination now (Phase D)

    if pages_config.is_all then
        utils.log_info(string.format("Generating complete collection with pagination (all pages up to max_pages limit): %d poems",
                                    total_poems))
    elseif pages_config.pages then
        utils.log_info(string.format("Generating complete collection with pagination (pages %s): %d poems",
                                    table.concat(pages_config.pages, ", "), total_poems))
    end

    local results = {
        similarity_pages = {},
        diversity_pages = {},
        chronological_index = nil,
        txt_files = {},
        html_archives = {},
        instructions_page = nil
    }

    -- Normalize num_threads
    num_threads = num_threads or 1
    if num_threads < 1 then num_threads = 1 end

    -- Build ordered list of poem indices for batch distribution
    local poem_indices = {}
    for poem_index, _ in pairs(valid_poems) do
        table.insert(poem_indices, poem_index)
    end
    table.sort(poem_indices)  -- Ensure consistent ordering across runs

    -- Check if parallel processing is available and requested
    local use_parallel = num_threads > 1 and has_threading and effil

    if use_parallel then
        -- {{{ Parallel processing with effil threads
        utils.log_info(string.format("Using parallel processing with %d threads", num_threads))

        -- Create progress channel for thread communication
        local progress_channel = effil.channel()

        -- Split poem indices into batches (round-robin for load balancing)
        local batches = {}
        for t = 1, num_threads do
            batches[t] = {}
        end
        for i, poem_index in ipairs(poem_indices) do
            local thread_id = ((i - 1) % num_threads) + 1
            table.insert(batches[thread_id], poem_index)
        end

        -- Issue 9-003 Fix D: Compute chronological mapping for full formatting
        -- This allows workers to generate correct progress bars and chronological links
        local chrono_poems_per_page_config = PAGINATION_CONFIG.chronological_poems_per_page or 500
        local chronological_paginated = PAGINATION_CONFIG.chronological_paginated or false

        -- Issue 9-003: Apply CLI override for chronological poems per page
        local effective_chrono_per_page = chrono_poems_per_page_config
        if chrono_per_page and type(chrono_per_page) == "number" and chrono_per_page > 0 then
            utils.log_info(string.format("CLI override: parallel worker chrono mapping uses %d poems/page (was %d)", chrono_per_page, effective_chrono_per_page))
            effective_chrono_per_page = chrono_per_page
            chronological_paginated = true  -- Enable pagination if CLI override provided
        end

        utils.log_info("Computing chronological mapping for full formatting...")
        local chrono_mapping = compute_chronological_mapping(poems_data, chronological_paginated and effective_chrono_per_page or nil)
        utils.log_info(string.format("Chronological mapping computed for %d poems", #poem_indices))

        -- Prepare shared config for threads (serializable data only)
        local thread_config = {
            dir = DIR,
            output_dir = output_dir,
            pages_is_all = pages_config.is_all,
            pages_list = pages_config.pages,
            poems_per_page = PAGINATION_CONFIG.poems_per_page,
            generate_html_archives = PAGINATION_CONFIG.generate_html_archives,
            generate_txt_exports = PAGINATION_CONFIG.generate_txt_exports,
            -- Issue 9-003 Fix D: Full formatting data
            chrono_mapping = chrono_mapping,
            chrono_paginated = chronological_paginated
        }

        -- Create and launch worker threads
        local threads = {}
        local start_time = os.time()

        for thread_id, batch in pairs(batches) do
            -- effil.thread creates a new Lua state that runs the function
            local thread_func = effil.thread(function(batch_indices, config, tid, prog_channel)
                -- Set up package paths in thread context
                package.path = config.dir .. "/libs/?.lua;" .. config.dir .. "/src/?.lua;" .. package.path

                -- Load required modules in thread context
                local t_utils = require('utils')
                local t_dkjson = require('dkjson')
                t_utils.init_assets_root({config.dir})

                -- Load data files (each thread loads independently - files are in disk cache)
                local poems_file = t_utils.asset_path("poems.json")
                local poems_data = t_utils.read_json_file(poems_file)
                if not poems_data then
                    error("Thread " .. tid .. ": Failed to load poems.json")
                end

                -- Build poem lookup by poem_index
                local poem_lookup = {}
                for i, poem in ipairs(poems_data.poems) do
                    if poem.poem_index then
                        poem_lookup[poem.poem_index] = poem
                    end
                end

                -- Load caches
                local diversity_cache_file = t_utils.embeddings_dir("embeddinggemma_latest") .. "/diversity_cache.json"
                local diversity_cache = t_utils.read_json_file(diversity_cache_file)
                if not diversity_cache or not diversity_cache.sequences then
                    error("Thread " .. tid .. ": Failed to load diversity_cache.json")
                end

                local similarity_cache_file = t_utils.embeddings_dir("embeddinggemma_latest") .. "/similarity_rankings_cache.json"
                local similarity_cache = t_utils.read_json_file(similarity_cache_file)
                if not similarity_cache or not similarity_cache.rankings then
                    error("Thread " .. tid .. ": Failed to load similarity_rankings_cache.json")
                end

                -- Load poem colors
                local poem_colors_file = t_utils.embeddings_dir("embeddinggemma_latest") .. "/poem_colors.json"
                local poem_colors_data = t_utils.read_json_file(poem_colors_file)
                local poem_colors = poem_colors_data and poem_colors_data.poem_colors or {}

                -- Color config for progress bars
                local color_config = {
                    red = "#dc3c3c", blue = "#3c78dc", green = "#3cb45a",
                    purple = "#8c3cc8", orange = "#e68c3c", yellow = "#c8b428", gray = "#787878"
                }

                -- Local helper: Get unique filename ID for poem
                local function get_unique_id(poem)
                    local cat_prefix = (poem.category or "unknown"):sub(1, 1):lower()
                    local id_num = poem.id or poem.poem_index or 0
                    return string.format("%s-%04d", cat_prefix, id_num)
                end

                -- {{{ Local helper: Get source path for poem identification in ranking headers
                -- Issue 8-036: Returns human-readable source path for each category
                local function get_source_path(poem)
                    local category = poem.category or "unknown"
                    if category == "notes" and poem.metadata and poem.metadata.source_file then
                        -- Notes show original descriptive filename
                        return "notes/" .. poem.metadata.source_file
                    elseif category == "bluesky" then
                        -- Bluesky uses # notation
                        return "bluesky#" .. (poem.id or 0)
                    elseif category == "fediverse" then
                        -- Fediverse shows category/id
                        return "fediverse/" .. (poem.id or 0)
                    elseif category == "messages" then
                        -- Messages shows category/id
                        return "messages/" .. (poem.id or 0)
                    else
                        return category .. "/" .. (poem.id or poem.poem_index or 0)
                    end
                end
                -- }}}

                -- {{{ Local helper: Check if poem is golden (exactly 1024 chars when posted)
                -- Issue 8-044: Use pre-calculated metadata as single source of truth
                local function is_golden_poem(poem)
                    if poem.metadata and poem.metadata.is_golden_poem then
                        return true
                    end
                    return false
                end
                -- }}}

                -- Local helper: Build poem lookup by poem_index for ranking conversion
                local function build_poem_by_index()
                    local lookup = {}
                    for i, poem in ipairs(poems_data.poems) do
                        if poem.poem_index then
                            lookup[poem.poem_index] = poem
                        end
                    end
                    return lookup
                end
                local poem_by_index = build_poem_by_index()

                -- Local helper: Convert similarity ranking to poem objects
                local function get_similarity_ranking(source_poem_index)
                    local cached_ranking = similarity_cache.rankings[tostring(source_poem_index)]
                    if not cached_ranking then return {} end
                    local result = {}
                    for i, neighbor_index in ipairs(cached_ranking) do
                        local neighbor_poem = poem_by_index[neighbor_index]
                        if neighbor_poem then
                            table.insert(result, {
                                poem = neighbor_poem,
                                rank = i
                            })
                        end
                    end
                    return result
                end

                -- Local helper: Convert diversity sequence to poem objects
                local function get_diversity_sequence(source_poem_index)
                    local cached_seq = diversity_cache.sequences[tostring(source_poem_index)]
                    if not cached_seq then return {} end
                    local result = {}
                    for step, neighbor_index in ipairs(cached_seq) do
                        local neighbor_poem = poem_by_index[neighbor_index]
                        if neighbor_poem then
                            table.insert(result, {
                                id = neighbor_index,
                                poem = neighbor_poem,
                                step = step
                            })
                        end
                    end
                    return result
                end

                -- Local helper: Format single poem with full formatting (Issue 9-003 Fix D)
                -- Includes progress bars, navigation box, and chronological page links
                -- Issue 8-044: Added golden poem formatting support
                local function format_poem_entry(poem, poem_colors_tbl, clr_config, chrono_map, chrono_paged)
                    local poem_idx = poem.poem_index
                    local poem_color_data = poem_colors_tbl[poem_idx]
                    local semantic_color = poem_color_data and poem_color_data.color or "gray"
                    local hex_color = clr_config[semantic_color] or clr_config["gray"]

                    -- Issue 8-044: Check if this is a golden poem
                    local is_golden = is_golden_poem(poem)

                    -- Get chronological position from mapping
                    local chrono_info = chrono_map[poem_idx] or {position = 1, page_number = 1, total_poems = 1, total_pages = 1}
                    local progress_pct = (chrono_info.position / chrono_info.total_poems) * 100

                    -- Calculate progress bar chars
                    -- Golden: 82 interior chars + 2 corners = 84 total
                    -- Regular: 83 chars total (no corners on top bar)
                    local total_bar_chars = is_golden and 82 or 83
                    local progress_chars = math.floor((progress_pct / 100) * total_bar_chars)
                    local remaining_chars = total_bar_chars - progress_chars

                    -- Build progress bar with color
                    -- Issue 8-044: Golden poems get ╔ corner + bar + ┐ corner
                    local progress_section = string.rep("═", progress_chars)
                    local remaining_section = string.rep("─", remaining_chars)
                    local colored_progress
                    if is_golden then
                        -- Golden: ╔═══════════────────────┐ (84 chars total)
                        local left_corner = string.format('<font color="%s"><b>╔</b></font>', hex_color)
                        colored_progress = left_corner .. string.format('<font color="%s"><b>%s</b></font>%s',
                            hex_color, progress_section, remaining_section) .. "┐"
                    else
                        colored_progress = string.format('<font color="%s"><b>%s</b></font>%s',
                            hex_color, progress_section, remaining_section)
                    end

                    -- Navigation links (absolute paths for local testing)
                    -- Issue 9-003 Fix: Use absolute file:// paths - helper script converts to production URLs
                    local base_path = "file:///home/ritz/programming/ai-stuff/neocities-modernization/output"
                    local similar_link = string.format("<a href='%s/similar/%04d-01.html'>similar</a>", base_path, poem_idx)
                    local different_link = string.format("<a href='%s/different/%04d-01.html'>different</a>", base_path, poem_idx)
                    -- Issue 8-030 Fix: Must match chronological page anchors (full category name, not first letter)
                    -- Chronological uses get_poem_anchor_id() → get_unique_poem_filename_id() → "category-NNNN"
                    local anchor_id = string.format("poem-%s-%04d", poem.category or "unknown", poem.id or 0)

                    -- Issue 8-039: Chronological link points to subdirectory
                    local chrono_link
                    if chrono_paged and chrono_info.total_pages > 1 then
                        -- Paginated: chronological/01.html, chronological/02.html, etc.
                        chrono_link = string.format("<a href='%s/chronological/%02d.html#%s'>chronological</a>",
                            base_path, chrono_info.page_number, anchor_id)
                    else
                        -- Single page: chronological/index.html
                        chrono_link = string.format("<a href='%s/chronological/index.html#%s'>chronological</a>", base_path, anchor_id)
                    end

                    -- Wrap content to 80 chars while preserving paragraph breaks
                    -- Also handle content warnings (CW: or content warning:)
                    local content = poem.content or ""

                    -- Issue 8-041: Escape HTML special characters in poem content
                    -- Prevents browser from interpreting poem content as HTML markup
                    -- (e.g., a poem containing "</pre>" would otherwise close the preformatted block)
                    -- Order: & first, then < and > (otherwise &lt; becomes &amp;lt;)
                    content = content:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")

                    local wrapped_lines = {}

                    -- Issue 9-011: Display content warning from poem.content_warning field (Mastodon CW)
                    -- This is separate from in-content CW: patterns - it comes from ActivityPub summary field
                    if poem.content_warning and poem.content_warning ~= "" then
                        -- Build box around ActivityPub content warning
                        local cw_display = "CW: " .. poem.content_warning
                        local box_width = math.min(math.max(#cw_display, 20), 76)
                        local padded_cw = cw_display .. string.rep(" ", box_width - #cw_display)
                        table.insert(wrapped_lines, " ┌" .. string.rep("─", box_width + 2) .. "┐")
                        table.insert(wrapped_lines, " │ " .. padded_cw .. " │")
                        table.insert(wrapped_lines, " └" .. string.rep("─", box_width + 2) .. "┘")
                        table.insert(wrapped_lines, "")  -- Empty line after CW
                        table.insert(wrapped_lines, "")  -- Second empty line for spacing
                    end

                    -- Check for content warning at start
                    local cw_text = nil
                    local main_content = content
                    local cw_match = content:match("^%s*[Cc][Ww]%s*:(.-)[\n\r]")
                    if not cw_match then
                        cw_match = content:match("^%s*[Cc]ontent [Ww]arning%s*:(.-)[\n\r]")
                    end
                    if cw_match then
                        cw_text = cw_match:match("^%s*(.-)%s*$")  -- trim whitespace
                        -- Remove the CW line from main content
                        main_content = content:gsub("^%s*[Cc][Ww]%s*:[^\n\r]*[\n\r]?", "")
                        main_content = main_content:gsub("^%s*[Cc]ontent [Ww]arning%s*:[^\n\r]*[\n\r]?", "")
                    end

                    -- If there's a content warning, format it in a box
                    if cw_text and #cw_text > 0 then
                        -- Build simple box around CW
                        local cw_display = "CW: " .. cw_text
                        local box_width = math.min(math.max(#cw_display, 20), 76)
                        local padded_cw = cw_display .. string.rep(" ", box_width - #cw_display)
                        table.insert(wrapped_lines, " ┌" .. string.rep("─", box_width + 2) .. "┐")
                        table.insert(wrapped_lines, " │ " .. padded_cw .. " │")
                        table.insert(wrapped_lines, " └" .. string.rep("─", box_width + 2) .. "┘")
                        table.insert(wrapped_lines, "")  -- Empty line after CW
                    end

                    -- Split main content by paragraph breaks (single newlines)
                    local paragraphs = {}
                    for para in (main_content .. "\n"):gmatch("(.-)\n") do
                        table.insert(paragraphs, para)
                    end

                    -- Wrap each paragraph separately
                    for p_idx, paragraph in ipairs(paragraphs) do
                        if paragraph == "" then
                            -- Preserve empty lines (paragraph breaks)
                            table.insert(wrapped_lines, "")
                        else
                            -- Word-wrap this paragraph
                            local current_line = ""
                            for word in paragraph:gmatch("%S+") do
                                if #current_line + #word + 1 <= 80 then
                                    current_line = current_line .. (current_line ~= "" and " " or "") .. word
                                else
                                    if current_line ~= "" then table.insert(wrapped_lines, " " .. current_line) end
                                    current_line = word
                                end
                            end
                            if current_line ~= "" then table.insert(wrapped_lines, " " .. current_line) end
                        end
                    end

                    -- Issue 8-044: Apply golden side borders to content lines
                    -- Golden poems get ║ (colored) on left and │ on right
                    -- Total width: ║ (1) + space (1) + 80 chars content + space (1) + │ (1) = 84 total
                    if is_golden then
                        local golden_lines = {}
                        local colored_wall = string.format('<font color="%s"><b>║</b></font>', hex_color)
                        local CONTENT_WIDTH = 80

                        -- Helper to count UTF-8 characters (not bytes)
                        -- Box-drawing chars are 3 bytes each, so #str gives wrong count
                        local function utf8_char_count(str)
                            -- Remove UTF-8 continuation bytes (0x80-0xBF), count what remains
                            return #(str:gsub("[\128-\191]", ""))
                        end

                        for _, line in ipairs(wrapped_lines) do
                            -- Strip the leading space that word-wrap added (we'll add our own)
                            local content = line:match("^%s*(.*)$") or line

                            -- Calculate visible length (excluding HTML tags, counting UTF-8 chars)
                            local visible_content = content:gsub("<[^>]+>", "")
                            local visible_length = utf8_char_count(visible_content)

                            -- Pad content to 80 chars
                            local padded_content
                            if visible_length >= CONTENT_WIDTH then
                                padded_content = content
                            else
                                local padding_needed = CONTENT_WIDTH - visible_length
                                padded_content = content .. string.rep(" ", padding_needed)
                            end

                            -- Add side borders: ║ + space + 80 chars + space + │ = 84 total
                            table.insert(golden_lines, colored_wall .. " " .. padded_content .. " │")
                        end
                        wrapped_lines = golden_lines
                    end

                    -- Build navigation box matching reference implementation
                    -- Regular poem structure: 83 chars total (positions 0-82)
                    -- ┌─────────┐ (11 chars) + 59 spaces + ┌───────────┐ (13 chars) = 83 chars

                    -- Issue 8-035: Helper to colorize box characters based on progress
                    local function color_char(char, pos)
                        if progress_chars > pos then
                            return string.format('<font color="%s"><b>%s</b></font>', hex_color, char)
                        end
                        return char
                    end

                    -- Build nav_top and nav_mid
                    -- Issue 8-044: Golden poems use different box characters
                    local nav_top, nav_mid

                    if is_golden then
                        -- Golden nav box: 84 chars total
                        -- ╟─────────┐ (11 chars) + gap (60) + ┌───────────┤ (13 chars) = 84 total
                        -- Left box ends at position 10, right box starts at position 71
                        local colored_corner = string.format('<font color="%s"><b>╟</b></font>', hex_color)
                        local left_sep = colored_corner
                        for i = 1, 9 do
                            left_sep = left_sep .. color_char("─", i)
                        end
                        left_sep = left_sep .. color_char("┐", 10)

                        -- Right separator: positions 71-83 for 84-char total width
                        local right_sep = color_char("┌", 71)
                        for i = 72, 82 do
                            right_sep = right_sep .. color_char("─", i)
                        end
                        right_sep = right_sep .. color_char("┤", 83)

                        -- Gap: 84 - 11 (left) - 13 (right) = 60 chars
                        nav_top = left_sep .. string.rep(" ", 60) .. right_sep

                        -- Golden nav line: ║ similar │ + gap + chronological + gap + │ different │
                        -- Note: nav line uses │ on right end (not ┤ which is only for separator)
                        local colored_wall = string.format('<font color="%s"><b>║</b></font>', hex_color)
                        local right_wall_of_left = color_char("│", 10)
                        local left_wall_of_right = color_char("│", 71)
                        local right_end = color_char("│", 83)  -- │ not ┤ for nav line

                        -- Gap calculation: 60 total gap - 14 (chronological link) = 46, split: 23 + 23
                        nav_mid = colored_wall .. " " .. similar_link .. " " .. right_wall_of_left .. string.rep(" ", 23) .. chrono_link .. string.rep(" ", 23) .. left_wall_of_right .. " " .. different_link .. " " .. right_end
                    else
                        -- Regular: ┌─────────┐ + gap + ┌───────────┐
                        local left_top = {}
                        table.insert(left_top, color_char("┌", 0))
                        for i = 1, 9 do
                            table.insert(left_top, color_char("─", i))
                        end
                        table.insert(left_top, color_char("┐", 10))

                        local right_top = {}
                        table.insert(right_top, color_char("┌", 70))
                        for i = 71, 81 do
                            table.insert(right_top, color_char("─", i))
                        end
                        table.insert(right_top, color_char("┐", 82))

                        nav_top = table.concat(left_top) .. string.rep(" ", 59) .. table.concat(right_top)

                        -- Regular nav line: │ similar │ + gap + chronological + gap + │ different │
                        local left_wall = color_char("│", 0)
                        local right_wall_of_left = color_char("│", 10)
                        local left_wall_of_right = color_char("│", 70)
                        local right_wall = color_char("│", 82)

                        nav_mid = left_wall .. " " .. similar_link .. " " .. right_wall_of_left .. string.rep(" ", 23) .. chrono_link .. string.rep(" ", 23) .. left_wall_of_right .. " " .. different_link .. " " .. right_wall
                    end

                    -- Bottom line with progress bar and junction characters
                    -- Structure: ╘═════════╧═══════════════════════════════════════════════════════════╧═══════════┘
                    -- Golden: 82 interior + 2 corners = 84 total, junctions at 9 and 70
                    -- Regular: 83 total, junctions at 10 and 70
                    local TOTAL_CHARS = is_golden and 82 or 83
                    local LEFT_JUNCTION = is_golden and 9 or 10
                    local RIGHT_JUNCTION = is_golden and 70 or 70  -- Golden: interior pos 70 = full pos 71

                    local left_in_progress = LEFT_JUNCTION < progress_chars
                    local right_in_progress = RIGHT_JUNCTION < progress_chars

                    -- Build junction characters (colored ╧ when in progress, plain ┴ otherwise)
                    local left_junction = left_in_progress
                        and string.format('<font color="%s"><b>╧</b></font>', hex_color)
                        or "┴"
                    local right_junction = right_in_progress
                        and string.format('<font color="%s"><b>╧</b></font>', hex_color)
                        or "┴"

                    -- Build bottom line segments around junctions
                    local function build_segment(start_pos, end_pos)
                        if end_pos <= start_pos then return "" end
                        local seg_len = end_pos - start_pos
                        local progress_in_seg = math.max(0, math.min(seg_len, progress_chars - start_pos))
                        local remaining_in_seg = seg_len - progress_in_seg
                        local result = ""
                        if progress_in_seg > 0 then
                            result = result .. string.format('<font color="%s"><b>%s</b></font>', hex_color, string.rep("═", progress_in_seg))
                        end
                        if remaining_in_seg > 0 then
                            result = result .. string.rep("─", remaining_in_seg)
                        end
                        return result
                    end

                    -- Issue 8-044: Golden poems use ╚ corner, regular use ╘
                    local corner_char = is_golden and "╚" or "╘"
                    local colored_corner = string.format('<font color="%s"><b>%s</b></font>', hex_color, corner_char)
                    -- Issue 8-037 Fix: Corrected segment positions to match main scope
                    -- Segment 1: positions 1 to LEFT_JUNCTION-1 (9 chars, corner is pos 0)
                    -- Segment 2: positions LEFT_JUNCTION+1 to RIGHT_JUNCTION-1 (59 chars)
                    -- Segment 3: positions RIGHT_JUNCTION+1 to TOTAL_CHARS-2 (11 chars, ┘ is pos 82)
                    local bottom_line = colored_corner
                        .. build_segment(1, LEFT_JUNCTION)
                        .. left_junction
                        .. build_segment(LEFT_JUNCTION + 1, RIGHT_JUNCTION)
                        .. right_junction
                        .. build_segment(RIGHT_JUNCTION + 1, TOTAL_CHARS - 1)
                        .. "┘"

                    -- Build formatted output
                    local output = {}
                    table.insert(output, colored_progress)  -- Top progress bar (golden: 84 chars, regular: 83 chars)
                    table.insert(output, table.concat(wrapped_lines, "\n"))  -- Content with preserved newlines

                    -- Issue 8-040: Render attached images if present (from ActivityPub extraction)
                    -- Images appear after poem content, before navigation links
                    -- Must be inline since worker thread can't access main scope functions
                    local base_path = "file:///home/ritz/programming/ai-stuff/neocities-modernization"

                    -- Helper function to render a list of attachments
                    -- Issue 8-005 Fix: Images rendered outside <pre> for proper max-width behavior
                    -- display:block prevents side-by-side, max-width:min(100%,800px) caps width
                    local function render_attachments(attachments)
                        if not attachments then return false end
                        local has_images = false
                        for _, attachment in ipairs(attachments) do
                            local media_type = attachment.media_type or ""
                            if media_type:match("^image/") then
                                -- Issue 8-048: Use flat output/media/ path structure
                                local relative_path = attachment.relative_path or ""
                                local basename = relative_path:match("([^/]+)$") or relative_path
                                local img_src = base_path .. "/output/media/" .. basename
                                -- Issue 8-053: Complete fallback chain matching Location 1 and 3
                                local alt_text = attachment.description or attachment.alt_text or "Image attachment"
                                -- Issue 8-053: Normalize newlines to spaces for clean HTML attributes
                                alt_text = alt_text:gsub("\n", " "):gsub("\r", "")
                                -- Escape quotes in alt text
                                alt_text = alt_text:gsub('"', '&quot;')
                                -- Issue 8-053: title attribute provides mouse-over tooltip
                                local img_tag = string.format(
                                    '  <img src="%s" alt="%s" title="%s" loading="lazy" style="display:block; max-width:min(100%%,800px); height:auto"',
                                    img_src, alt_text, alt_text
                                )
                                -- Add dimensions if available
                                if attachment.width and attachment.height then
                                    img_tag = img_tag .. string.format(' width="%d" height="%d"', attachment.width, attachment.height)
                                end
                                img_tag = img_tag .. '>'
                                table.insert(output, img_tag)
                                has_images = true
                            end
                        end
                        return has_images
                    end

                    -- Check if we have any images to render
                    -- Issue 9-010: Images stay with their original post only (no associated_images rendering)
                    local has_any_images = false
                    local image_attachments = {}
                    if poem.attachments and #poem.attachments > 0 then
                        for _, att in ipairs(poem.attachments) do
                            if (att.media_type or ""):match("^image/") then
                                table.insert(image_attachments, att)
                                has_any_images = true
                            end
                        end
                    end

                    -- If there are images, close </pre>, render them, reopen <pre>
                    -- display:block prevents side-by-side, max-width:min(100%,800px) caps width
                    if has_any_images then
                        table.insert(output, "</pre>")
                        for _, attachment in ipairs(image_attachments) do
                            -- Issue 8-048: Use flat output/media/ path structure
                            local relative_path = attachment.relative_path or ""
                            local basename = relative_path:match("([^/]+)$") or relative_path
                            local img_src = base_path .. "/output/media/" .. basename
                            local alt_text = attachment.description or attachment.alt_text or "Image attachment"
                            -- Issue 8-053: Normalize newlines to spaces for clean HTML attributes
                            alt_text = alt_text:gsub("\n", " "):gsub("\r", "")
                            alt_text = alt_text:gsub('"', '&quot;')
                            -- Issue 8-053: title attribute provides mouse-over tooltip
                            local img_tag = string.format(
                                '  <img src="%s" alt="%s" title="%s" loading="lazy" style="display:block; max-width:min(100%%,800px); height:auto"',
                                img_src, alt_text, alt_text
                            )
                            if attachment.width and attachment.height then
                                img_tag = img_tag .. string.format(' width="%d" height="%d"', attachment.width, attachment.height)
                            end
                            img_tag = img_tag .. '>'
                            table.insert(output, img_tag)
                        end
                        table.insert(output, "<pre>")
                    end

                    table.insert(output, nav_top)  -- Nav box top (golden: 84, regular: 83 chars)
                    table.insert(output, nav_mid)  -- Nav box middle
                    table.insert(output, bottom_line)  -- Bottom with junctions

                    return table.concat(output, "\n")
                end

                -- Local helper: Generate paginated HTML page
                -- Issue 9-003 Fix D: Added chrono_map and chrono_paged for full formatting
                local function generate_page(poem, sorted_list, page_type, page_num, poems_per_pg, out_dir, chrono_map, chrono_paged)
                    local start_idx = (page_num - 1) * poems_per_pg + 1
                    local end_idx = math.min(start_idx + poems_per_pg - 1, #sorted_list)
                    if start_idx > #sorted_list then return nil end

                    local type_label = page_type == "similar" and "similarity" or "diversity"
                    local poem_idx_str = string.format("%04d", poem.poem_index or 0)
                    local filename = string.format("%s/%s/%s-%02d.html", out_dir, page_type, poem_idx_str, page_num)

                    -- Build HTML content with full formatting
                    -- Issue 9-003 Fix: Use centered table for block centering with left-aligned text inside
                    local html_parts = {
                        '<!DOCTYPE html><html><head><meta charset="UTF-8">',
                        '<title>Poems by ' .. type_label .. ' to poem ' .. poem_idx_str .. ' (page ' .. page_num .. ')</title>',
                        '</head><body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF"><table align="center"><tr><td><pre>'
                    }

                    -- Add anchor poem with full formatting
                    table.insert(html_parts, "=== ANCHOR POEM ===\n")
                    table.insert(html_parts, format_poem_entry(poem, poem_colors, color_config, chrono_map, chrono_paged))
                    table.insert(html_parts, "\n\n=== " .. type_label:upper() .. " RANKED ===\n\n")

                    -- Add poems for this page with full formatting
                    for i = start_idx, end_idx do
                        local entry = sorted_list[i]
                        local entry_poem = entry.poem
                        if entry_poem then
                            -- Issue 8-036: Add poem source path to ranking header
                            local source_path = get_source_path(entry_poem)
                            table.insert(html_parts, string.format("--- #%d %s ---\n", i, source_path))
                            table.insert(html_parts, format_poem_entry(entry_poem, poem_colors, color_config, chrono_map, chrono_paged))
                            table.insert(html_parts, "\n\n")
                        end
                    end

                    table.insert(html_parts, '</pre></td></tr></table></body></html>')

                    -- Write file
                    local dir_path = filename:match("(.*/)")
                    os.execute('mkdir -p "' .. dir_path .. '"')
                    local f = io.open(filename, "w")
                    if f then
                        f:write(table.concat(html_parts))
                        f:close()
                        return filename
                    end
                    return nil
                end

                -- Process batch
                local similarity_count = 0
                local diversity_count = 0
                local processed = 0

                for _, poem_index in ipairs(batch_indices) do
                    local poem = poem_lookup[poem_index]
                    if poem then
                        local unique_id = get_unique_id(poem)

                        -- Get rankings from caches
                        local similar_ranking = get_similarity_ranking(poem_index)
                        local diverse_sequence = get_diversity_sequence(poem_index)

                        -- Generate similarity pages (page 1 only, respecting config)
                        -- Issue 9-003 Fix D: Pass chrono_mapping and chrono_paginated for full formatting
                        local max_pages = config.pages_is_all and 1 or (config.pages_list and #config.pages_list or 1)
                        for page_num = 1, max_pages do
                            local page_file = generate_page(poem, similar_ranking, "similar", page_num, config.poems_per_page, config.output_dir, config.chrono_mapping, config.chrono_paginated)
                            if page_file then similarity_count = similarity_count + 1 end
                        end

                        -- Generate diversity pages
                        for page_num = 1, max_pages do
                            local page_file = generate_page(poem, diverse_sequence, "different", page_num, config.poems_per_page, config.output_dir, config.chrono_mapping, config.chrono_paginated)
                            if page_file then diversity_count = diversity_count + 1 end
                        end

                        processed = processed + 1

                        -- Report progress every 50 poems
                        if processed % 50 == 0 then
                            prog_channel:push(tid, processed)
                        end
                    end
                end

                -- Final progress report
                prog_channel:push(tid, processed)

                return similarity_count, diversity_count, processed
            end)

            -- Launch thread with its batch
            threads[thread_id] = thread_func(batch, thread_config, thread_id, progress_channel)
        end

        -- Monitor progress by counting files in output directories
        -- This is simpler and more accurate than thread synchronization
        local similar_dir = output_dir .. "/similar"
        local different_dir = output_dir .. "/different"

        -- Helper: count HTML files in a directory
        local function count_html_files(dir)
            local handle = io.popen('find "' .. dir .. '" -name "*.html" 2>/dev/null | wc -l')
            if handle then
                local count = tonumber(handle:read("*a")) or 0
                handle:close()
                return count
            end
            return 0
        end

        -- Capture initial file counts (from previous runs)
        local initial_similar = count_html_files(similar_dir)
        local initial_different = count_html_files(different_dir)
        local initial_total = initial_similar + initial_different
        if initial_total > 0 then
            utils.log_info(string.format("Note: %d existing files found (will show NEW files only)", initial_total))
        end

        -- Expected NEW files (2 per poem: similarity + diversity)
        local expected_total = total_poems * 2  -- 1 similarity page + 1 diversity page per poem

        -- Wait for all threads to complete with file-based progress updates
        local all_done = false
        local last_count = 0
        while not all_done do
            all_done = true
            for tid, thread in pairs(threads) do
                local status = thread:status()
                if status ~= "completed" and status ~= "failed" then
                    all_done = false
                end
            end

            if not all_done then
                -- Count files in output directories (subtract initial to show NEW files only)
                local similar_files = count_html_files(similar_dir) - initial_similar
                local different_files = count_html_files(different_dir) - initial_different
                local total_files = similar_files + different_files

                -- Calculate rate based on NEW files only
                local elapsed = os.time() - start_time
                local rate = elapsed > 0 and (total_files / elapsed) or 0
                local remaining = expected_total - total_files
                local eta = rate > 0 and math.floor(remaining / rate) or 0

                -- Show progress with NEW file counts and percentage
                local pct = (total_files / expected_total) * 100
                io.write(string.format("\r   [%d threads] %d/%d NEW files (%.1f%%) | %d similar + %d different | %.1f files/sec | ETA: %ds    ",
                    num_threads, total_files, expected_total, pct, similar_files, different_files, rate, eta))
                io.flush()

                -- Brief pause between progress checks (1 second)
                os.execute("sleep 1")
            end
        end

        -- Final count (NEW files only)
        local final_similar = count_html_files(similar_dir) - initial_similar
        local final_different = count_html_files(different_dir) - initial_different
        io.write(string.format("\r   [%d threads] Complete: %d NEW similar + %d NEW different = %d files                    \n",
            num_threads, final_similar, final_different, final_similar + final_different))

        -- Collect results from all threads
        -- Note: effil thread:get() returns the thread function's return values directly
        local total_similarity = 0
        local total_diversity = 0
        local total_processed = 0

        for tid, thread in pairs(threads) do
            local status = thread:status()
            if status == "completed" then
                local sim_count, div_count, proc_count = thread:get()
                total_similarity = total_similarity + (sim_count or 0)
                total_diversity = total_diversity + (div_count or 0)
                total_processed = total_processed + (proc_count or 0)
            elseif status == "failed" then
                local err = thread:get()
                utils.log_error(string.format("Thread %d failed: %s", tid, tostring(err)))
            else
                utils.log_warn(string.format("Thread %d in unexpected state: %s", tid, status))
            end
        end

        local elapsed = os.time() - start_time
        utils.log_info(string.format("Parallel generation complete: %d poems in %ds (%.1f poems/sec)",
            total_processed, elapsed, total_processed / math.max(elapsed, 1)))

        -- Update results counts (we don't have individual filenames in parallel mode)
        for i = 1, total_similarity do table.insert(results.similarity_pages, "parallel") end
        for i = 1, total_diversity do table.insert(results.diversity_pages, "parallel") end
        -- }}} End parallel processing

    else
        -- {{{ Sequential processing (original code path)
        if num_threads > 1 and not has_threading then
            utils.log_warn("Parallel processing requested but effil not available, using single thread")
        end

        -- Generate similarity and diversity pages for each poem
        -- Note: Loop variable is poem_index (globally unique) not poem.id (per-category)
        local progress_count = 0
        for poem_index, poem_data in pairs(valid_poems) do
            progress_count = progress_count + 1

            if progress_count % 100 == 0 then
                utils.log_info(string.format("Progress: %d/%d poems processed (%.1f%%)",
                                            progress_count, total_poems,
                                            (progress_count / total_poems) * 100))
            end

            -- Generate unique filename identifier (category prefix for cross-category uniqueness)
            local unique_id = get_unique_poem_filename_id(poem_data)

            -- Generate similarity ranking (cache is keyed by poem_index)
            local similar_ranking = M.generate_similarity_ranked_list(poem_index, poems_data, similarity_data)

            -- Phase D (Issue 8-012): Use paginated generation
            -- Note: Pagination uses poem_index (numeric) for file naming (similar/0001-01.html)
            local pagination_result = M.generate_all_paginated_pages_for_poem(
                poem_data,
                similar_ranking,
                "similar",
                poem_data.poem_index,  -- Use numeric poem_index for pagination filenames
                output_dir,
                pages_config.is_all and nil or pages_config.pages  -- nil means "all pages"
            )

            if pagination_result and pagination_result.files_generated then
                for _, file in ipairs(pagination_result.files_generated) do
                    table.insert(results.similarity_pages, file)
                end
            end

            -- Generate TXT version (full corpus export - not paginated)
            local similar_txt = generate_similarity_txt_file(poem_data, similar_ranking,
                                                           string.format("%s/similar/%s.txt", output_dir, unique_id))
            if similar_txt then
                table.insert(results.txt_files, similar_txt)
            end

            -- Generate HTML archive version (full corpus export with images - not paginated)
            if PAGINATION_CONFIG.generate_html_archives then
                local similar_archive = generate_similarity_html_archive(poem_data, similar_ranking,
                                                               string.format("%s/similar/%s-archive.html", output_dir, unique_id))
                if similar_archive then
                    table.insert(results.html_archives, similar_archive)
                end
            end

            -- Generate diversity pages (cache is keyed by poem_index)
            local diverse_sequence = M.generate_maximum_diversity_sequence(poem_index, poems_data, embeddings_data)

            -- Phase D (Issue 8-012): Use paginated generation for diversity pages too
            -- Note: Pagination uses poem_index (numeric) for file naming (different/0001-01.html)
            local diversity_pagination_result = M.generate_all_paginated_pages_for_poem(
                poem_data,
                diverse_sequence,
                "different",
                poem_data.poem_index,  -- Use numeric poem_index for pagination filenames
                output_dir,
                pages_config.is_all and nil or pages_config.pages  -- nil means "all pages"
            )

            if diversity_pagination_result and diversity_pagination_result.files_generated then
                for _, file in ipairs(diversity_pagination_result.files_generated) do
                    table.insert(results.diversity_pages, file)
                end
            end

            -- Generate TXT version (full corpus export - not paginated)
            local diverse_txt = generate_diversity_txt_file(poem_data, diverse_sequence,
                                                          string.format("%s/different/%s.txt", output_dir, unique_id))
            if diverse_txt then
                table.insert(results.txt_files, diverse_txt)
            end

            -- Generate HTML archive version (full corpus export with images - not paginated)
            if PAGINATION_CONFIG.generate_html_archives then
                local diverse_archive = generate_diversity_html_archive(poem_data, diverse_sequence,
                                                              string.format("%s/different/%s-archive.html", output_dir, unique_id))
                if diverse_archive then
                    table.insert(results.html_archives, diverse_archive)
                end
            end
        end
        -- }}} End sequential processing
    end
    
    -- Note: Chronological index and explore.html are generated by main.lua before this function
    -- to avoid duplicate work. We only generate the TXT export here.

    -- Generate chronological TXT export (not generated elsewhere)
    local chrono_txt_file = output_dir .. "/chronological.txt"
    local chrono_txt = M.generate_chronological_txt_file(poems_data, chrono_txt_file)
    if chrono_txt then
        table.insert(results.txt_files, chrono_txt)
        results.chronological_txt = chrono_txt
    end
    
    local html_archive_count = results.html_archives and #results.html_archives or 0
    utils.log_info(string.format("Generation complete: %d similarity pages, %d diversity pages, %d txt files, %d html archives",
                                #results.similarity_pages, #results.diversity_pages, #results.txt_files, html_archive_count))
    
    return results
end
-- }}}

-- {{{ function M.main
function M.main(interactive_mode)
    if interactive_mode then
        print("Flat HTML Generator - Interactive Mode")
        print("1. Generate complete flat HTML collection")
        print("2. Generate chronological index only")
        print("3. Generate instructions page only")
        print("4. Test single similarity page")
        print("5. Test single difference page")
        io.write("Select option (1-5): ")
        local choice = io.read()
        
        local poems_file = utils.asset_path("poems.json")
        local similarity_file = utils.embeddings_dir("embeddinggemma_latest") .. "/similarity_matrix.json"
        local embeddings_file = utils.embeddings_dir("embeddinggemma_latest") .. "/embeddings.json"
        local output_dir = DIR .. "/output"
        
        if choice == "1" then
            utils.log_info("Loading data files...")
            local poems_data = utils.read_json_file(poems_file)
            local similarity_data = utils.read_json_file(similarity_file)
            local embeddings_data = utils.read_json_file(embeddings_file)
            
            if poems_data and similarity_data and embeddings_data then
                M.generate_complete_flat_html_collection(poems_data, similarity_data.similarities, embeddings_data, output_dir)
            else
                utils.log_error("Failed to load required data files")
            end
        elseif choice == "2" then
            local poems_data = utils.read_json_file(poems_file)
            if poems_data then
                M.generate_chronological_index_with_navigation(poems_data, output_dir)
                M.generate_chronological_txt_file(poems_data, output_dir .. "/chronological.txt")
                utils.log_info("Generated chronological/index.html and chronological.txt")
            end
        elseif choice == "3" then
            M.generate_simple_discovery_instructions(output_dir)
        elseif choice == "4" then
            io.write("Enter poem ID for similarity test: ")
            local poem_id = tonumber(io.read())
            if poem_id then
                local poems_data = utils.read_json_file(poems_file)
                local similarity_data = utils.read_json_file(similarity_file)
                
                if poems_data and similarity_data then
                    local poem_data = nil
                    for _, poem in ipairs(poems_data.poems) do
                        if poem.id == poem_id then
                            poem_data = poem
                            break
                        end
                    end
                    
                    if poem_data then
                        local ranking = M.generate_similarity_ranked_list(poem_id, poems_data, similarity_data.similarities)
                        local html = M.generate_flat_poem_list_html(poem_data, ranking, "similar", poem_id)
                        local test_file = string.format("%s/test_similar_%03d.html", output_dir, poem_id)
                        os.execute("mkdir -p " .. output_dir)
                        utils.write_file(test_file, html)
                        utils.log_info("Test file written: " .. test_file)
                    end
                end
            end
        elseif choice == "5" then
            io.write("Enter poem ID for difference test: ")
            local poem_id = tonumber(io.read())
            if poem_id then
                local poems_data = utils.read_json_file(poems_file)
                local embeddings_data = utils.read_json_file(embeddings_file)

                if poems_data and embeddings_data then
                    local poem_data = nil
                    for _, poem in ipairs(poems_data.poems) do
                        if poem.id == poem_id then
                            poem_data = poem
                            break
                        end
                    end

                    if poem_data then
                        local sequence = M.generate_maximum_diversity_sequence(poem_id, poems_data, embeddings_data)
                        local html = M.generate_flat_poem_list_html(poem_data, sequence, "different", poem_id)
                        local test_file = string.format("%s/test_different_%03d.html", output_dir, poem_id)
                        os.execute("mkdir -p " .. output_dir)
                        utils.write_file(test_file, html)
                        utils.log_info("Test file written: " .. test_file)
                    end
                end
            end
        end
    else
        utils.log_info("Use -I flag for interactive mode")
    end
end
-- }}}

-- Command line execution (only when run directly, not when require()'d)
-- arg[0] contains the script name - check if it matches this file
if arg and arg[0] and arg[0]:match("flat%-html%-generator%.lua$") then
    -- Check for interactive flag
    local interactive = false
    for _, arg_val in ipairs(arg) do
        if arg_val == "-I" then
            interactive = true
            break
        end
    end

    M.main(interactive)
end

return M