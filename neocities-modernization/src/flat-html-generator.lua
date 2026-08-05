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
-- Issue 8-056: Shared text formatting module for whitespace preservation
local text_formatter = require("text-formatter")
-- Shared in-place progress bar (same look + TTY/--debug rules as the GPU stages)
local progress = require("progress-display")
-- Issue 9-013: render ranked image entries (pseudo-poems) as image boxes
local image_render = require("image-render")
-- Issue 11-005: the explore pages read their prose from editable input/pages/*.txt
-- files; this fills the {MARKER} placeholders with the live numbers.
local page_template = require("page-template")

-- Issue 10-003: Load unified config from config.lua
local config_loader = require("config-loader")
config_loader.set_project_root(DIR)
local unified_config = config_loader.load()

-- inference-server-config tells us which embedding model the rest of the pipeline is
-- pointed at. We use it to derive the cache-directory name in the two
-- diversity/similarity loader fallbacks below; previously those defaulted
-- to "embeddinggemma:latest" as a literal string, which silently broke
-- after a model swap.
local inference_config = require("inference-server-config")
inference_config.set_project_root(DIR)

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

-- Issue 10-034: Orchestrator message types for lazy loading parallel HTML generation
-- Main thread acts as cache server, sending 80KB work slices instead of workers loading 700MB
local MSG_REQUEST_WORK = "get_work"   -- Worker → Main: "give me a poem to process"
local MSG_WORK_SLICE = "work"         -- Main → Worker: poem_index + rankings
local MSG_WORK_DONE = "done"          -- Worker → Main: "finished poem X"
local MSG_SHUTDOWN = "shutdown"       -- Main → Worker: "no more work, exit"

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

-- Issue 8-057: Boost visual formatting color scheme
-- Based on /notes/boost post image style.png design reference
local BOOST_COLOR_CONFIG = {
    arrow = "#dc3c3c",      -- Red/Magenta: ◀─ and ─▶ arrows, [BOOST] label
    outer_frame = "#3c78dc", -- Blue/Navy: ╔═╗║╚═╝ outer frame
    inner_box = "#2aa198",   -- Teal/Cyan: ┌─┐│└─┘ inner content box
    content_text = "#c8b428" -- Yellow: The actual boosted text content
}

-- The boost frame is drawn by ONE shared module so the main + worker + word-page
-- copies cannot drift (they had: misaligned walls, wrong junction columns, ▢
-- corruption). See src/boost-bars.lua + src/boost-bars.test.lua.
local boost_bars = require("boost-bars")
boost_bars.configure(BOOST_COLOR_CONFIG)

-- {{{ Issue 16-010: Monospace font enforcement
-- Font stack prioritizes Hack Nerd Font (user's preference), then falls back
-- to other popular monospace fonts for consistent rendering across browsers.
-- Uses CSS font-stack approach (no external font files required).
local FONT_STYLE = [[
<style>
body, pre {
    font-family: 'Hack Nerd Font', 'Hack', 'Fira Code', 'JetBrains Mono',
                 'Cascadia Code', 'Consolas', 'Monaco', 'Liberation Mono',
                 'Courier New', monospace;
}
/* True page-centering for the poem column. The old <table align="center">
   shrink-wrapped to its WIDEST line -- and an attached image (up to 800px) is
   wider than the ~84-char text frame, so the cell stretched and the frames
   hugged the left of that wide cell, landing the whole column left-of-center.
   Fix: the cell centers its children, each <pre> is an inline-block that
   centers as a block (text stays left-aligned inside), and media centers via
   auto margins. Now a vertical line down the page bisects every poem AND image,
   regardless of how wide any single image is. */
td { text-align: center; }
pre { display: inline-block; text-align: left; margin: 0 auto; }
img, video, audio { margin-left: auto; margin-right: auto; }
</style>
]]
-- }}}

-- Pagination configuration defaults
-- Issue 10-003: These values are overridden by unified config (config.lua) if present
-- See Issue 8-020 for hybrid pagination strategy (45GB storage constraint)
-- Issue 9-003 Fix F: Added chronological pagination settings
local PAGINATION_CONFIG = {
    poems_per_page = 100,
    minimum_pages = 1,
    -- COMPUTED per build by compute_storage_max_pages (Issue 10-057), not a config
    -- value. This placeholder is only the operative value if that computation is
    -- skipped (e.g. a caller that loads pagination just for chronological mapping);
    -- kept finite so %d logging and math.min() stay well-defined.
    max_pages_per_poem = 9999,
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
    REGULAR_POEM_WIDTH = 82,
    -- Total visible width for golden poems: 84 chars
    -- Structure: ╔ (1) + interior (82) + ┐ (1) = 84
    GOLDEN_POEM_WIDTH = 84,
    -- Maximum text content width (80 chars by default +1 space padding on left and +1 on right)
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
    -- Issue 8-055: Fixed junction positions to align ╧/┴ under ┐/┌ corners
    GOLDEN_LEFT_JUNCTION_POS = 10,    -- Same as regular (left box ┐ at position 10)
    GOLDEN_RIGHT_JUNCTION_POS = 71,   -- Regular + 1 (right box ┌ at position 71 due to wider golden)
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
    model_name = model_name or inference_config.get_selected_model()
    local model_dir = model_name:gsub(":", "_")
    -- Issue 10-054: diversity stays on disk (embeddings_dir_disk).
    local cache_file = utils.embeddings_dir_disk(model_name) .. "/diversity_cache.json"

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

    DIVERSITY_CACHE = cache_data
    return cache_data
end
-- }}}

-- {{{ local function load_similarity_rankings_cache
-- Loads pre-sorted similarity rankings from cache (required for HTML generation)
-- Errors out if cache doesn't exist - no fallback to on-the-fly sorting
local function load_similarity_rankings_cache(model_name)
    model_name = model_name or inference_config.get_selected_model()
    local model_dir = model_name:gsub(":", "_")
    -- Issue 10-054: similarity ranking cache is movable (embeddings_dir, RAM).
    local cache_file = utils.embeddings_dir(model_name) .. "/similarity_rankings_cache.json"

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

    SIMILARITY_RANKINGS_CACHE = cache_data
    return cache_data
end
-- }}}

-- {{{ local function media_href
-- Where a file lives under output/media/, url-encoded for an <img src>/href.
-- Art images (path under input/images/<source>/...) KEEP their source + subdir
-- structure -- their human basenames collide (e.g. my-art/x.png vs
-- my-art/game-design/x.png) and a flat output/media/<basename> would let one
-- overwrite the other. Mastodon attachments (hashes, NOT under input/images/)
-- keep just the basename. This MUST match flatten_media_files' target layout and
-- image-render.lua's copy of this rule, or the src points at the wrong file.
-- Slashes preserved; space / ? / # / % percent-encoded.
local function media_href(path)
    path = path or ""
    local sub = path:match("input/images/(.+)$") or (path:match("([^/]+)$") or path)
    return (sub:gsub("[^%w%-%._~/]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end
-- }}}

-- {{{ local function flatten_media_files
-- Issue 8-048: Copy every configured image into output/media/ for easy deploy.
-- TWO layouts, by species (kept in lockstep with media_href in the renderers):
--   * Mastodon media: collapse the ~7-level content-addressed nesting to the
--     bare hash basename (output/media/abc.png) -- unique already.
--   * Art images (input/images/<source>/...): keep <source>/<subpath>
--     (output/media/my-art/game-design/x.png), because human-given basenames
--     collide across subdirs and a flat layout silently dropped the duplicates.
-- Called once at start of HTML generation; skips files that already exist (idempotent)
local media_flattening_done = false

local function flatten_media_files(output_dir)
    -- Skip if already done this session (idempotent)
    if media_flattening_done then
        return true
    end

    -- The configured image sources are the source of truth for where to
    -- look. Each entry has an internal project-relative path (where the
    -- sync script drops files) and may also have an external source path
    -- (where the operator's actual files live on the wider file system).
    -- We prefer the internal path when present, and fall back to the
    -- external source so a configured-but-not-yet-synced entry still
    -- contributes media. A configured entry that is missing from both
    -- is a warning, not a fatal error — operators may legitimately
    -- declare more sources than are populated at any given moment.
    local sources_loader = require("sources-loader")
    sources_loader.set_project_root(DIR)
    local image_dirs = sources_loader.get_directories_with_external("images")

    if not image_dirs or #image_dirs == 0 then
        utils.log_warn("No image sources configured in sources.images.directories; skipping media flattening")
        media_flattening_done = true
        return true
    end

    local target_dir = output_dir .. "/media"
    os.execute('mkdir -p "' .. target_dir .. '"')

    local copied = 0
    local skipped = 0
    local errors = 0
    local sources_used = 0

    for _, dir in ipairs(image_dirs) do
        -- sources-loader's resolve_path already returns an ABSOLUTE path (it
        -- prepends the project root to relative config entries), so use dir.path
        -- directly. Prepending DIR again produced a doubled "/root//root/..." path
        -- that never resolved, so every source looked "missing" -- which the
        -- mandatory-source check below then turned into a fatal stage-9 failure.
        local internal_path = dir.path
        local external_path = dir.external and dir.external.source or nil
        local resolved_path = nil

        local internal_test = io.open(internal_path, "r")
        if internal_test then
            internal_test:close()
            resolved_path = internal_path
        elseif external_path then
            local external_test = io.open(external_path, "r")
            if external_test then
                external_test:close()
                resolved_path = external_path
            end
        end

        if not resolved_path then
            -- Every configured image source is mandatory (the "optional" concept was
            -- removed): a missing source means media we expected to ship is absent,
            -- so we fail loudly here rather than silently skip it. Fix it by running
            -- the sync/extraction that populates the path, or remove the source from
            -- config.lua if it is genuinely gone.
            error(string.format(
                "Image source '%s' not found at internal '%s'%s -- every source is required; sync/extract it or remove it from config.lua",
                dir.name or "(unnamed)",
                dir.path or "(no path)",
                external_path and (" or external '" .. external_path .. "'") or ""))
        else
            sources_used = sources_used + 1

            -- Find every file under the resolved source and place it under
            -- output/media/. TWO species, two layouts (must match media_href in
            -- the renderers exactly, or the <img src> points at the wrong file):
            --   * art sources (path .../input/images/<source>): keep
            --     <source>/<subpath>, so two files that share a basename in
            --     different subdirs (e.g. my-art/x.png and my-art/game-design/x.png)
            --     stay distinct instead of one silently overwriting the other.
            --   * everything else (Mastodon media, content-addressed hashes):
            --     flatten to the bare basename -- already unique, and this
            --     collapses the ~7-level Mastodon nesting.
            -- No leading-^ anchor: dir.path is absolute (see above), so we match the
            -- "input/images/<rest>" tail wherever it appears -- the same tail
            -- media_href() extracts in the renderers, keeping the two layouts identical.
            local ns_prefix = dir.path and dir.path:match("input/images/(.+)$") or nil
            local find_cmd = string.format('find "%s" -type f', resolved_path)
            local handle = io.popen(find_cmd)
            if handle then
                for source_path in handle:lines() do
                    -- this file's path within its own source dir (art subdirs kept)
                    local within = source_path:sub(#resolved_path + 2)
                    local target_sub
                    if ns_prefix then
                        target_sub = ns_prefix .. "/" .. within
                    else
                        target_sub = source_path:match("([^/]+)$")
                    end
                    if target_sub and target_sub ~= "" then
                        local target_path = target_dir .. "/" .. target_sub
                        local exists_check = io.open(target_path, "r")
                        if exists_check then
                            exists_check:close()
                            skipped = skipped + 1
                        else
                            -- create the subdirectory before copying (art paths
                            -- now nest one or more levels under output/media/)
                            local parent = target_path:match("^(.*)/[^/]+$")
                            if parent then os.execute('mkdir -p "' .. parent .. '"') end
                            local cp_cmd = string.format('cp "%s" "%s"', source_path, target_path)
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
            else
                utils.log_warn("Could not scan image source: " .. resolved_path)
            end
        end
    end

    utils.log_info(string.format(
        "Media flattening: %d sources used | %d copied, %d skipped, %d errors",
        sources_used, copied, skipped, errors))

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

    pagination_config_loaded = true
    return PAGINATION_CONFIG
end
-- }}}

-- {{{ local function compute_storage_max_pages
-- Issue 10-057 follow-up: derive how many similar/different pages per poem fit the
-- storage quota instead of freezing a guess in config. Everything is MEASURED from
-- the last build's output on disk -- a self-correcting validator, not an estimate:
--   budget          = storage.limit_gb (the Neocities quota; the one real config fact)
--   avg_page_size   = bytes of output/similar / number of those page files
--   per_page_level  = avg_page_size x num_poems x 2 (each poem gets one similar AND
--                     one different page per page-level)
--   fixed           = everything else already in output/ (media, wordcloud, chrono,
--                     gallery) -- does NOT grow with the page count
--   max_pages       = floor((budget - fixed) / per_page_level)
-- Pages reference images via <img src>, so a page on disk is text; the picture bytes
-- are the single output/media cost, folded into `fixed`. Measurements use du/find
-- (read-only) with block-rounded bytes -- conservative (rounds the cap DOWN, the safe
-- direction for a quota). First build (no pages to measure): warn and DO NOT cap; the
-- next build measures real sizes and applies the cap.
local function compute_storage_max_pages(output_dir, num_poems)
    local function popen_num(cmd)
        local h = io.popen(cmd)
        if not h then return nil end
        local out = h:read("*a"); h:close()
        return tonumber((out or ""):match("(%d+)"))
    end
    local function dir_bytes(path)
        return popen_num(string.format("du -s --block-size=1 %q", path)) or 0
    end

    local sim_dir = output_dir .. "/similar"
    local diff_dir = output_dir .. "/different"
    local page_count = popen_num(string.format("find %q -maxdepth 1 -name '*.html' | wc -l", sim_dir)) or 0
    if page_count == 0 or num_poems == 0 then
        -- First build: nothing to measure yet. Fall back to the NATURAL maximum (every
        -- other poem could fill pages), i.e. effectively uncapped, and warn. A finite
        -- value keeps %d logging and the math.min() cap well-defined; the next build
        -- measures real page sizes and applies the storage cap.
        local per_page = PAGINATION_CONFIG.poems_per_page
        local natural_max = math.max(1, math.ceil(num_poems / (per_page > 0 and per_page or 1)))
        utils.log_warn("Storage page cap: no pages in " .. sim_dir .. " to measure -- "
            .. "generating UNCAPPED this build (natural max " .. natural_max
            .. " pages/poem); re-run to apply the measured cap.")
        return natural_max
    end

    local sim_bytes = dir_bytes(sim_dir)
    local avg_page = sim_bytes / page_count
    local per_page_level = avg_page * num_poems * 2
    local fixed = math.max(0, dir_bytes(output_dir) - sim_bytes - dir_bytes(diff_dir))
    local budget = STORAGE_CONFIG.limit_gb * 1e9  -- decimal GB; conservative vs GiB

    local max_pages = math.floor((budget - fixed) / per_page_level)
    if max_pages < 1 then max_pages = 1 end

    utils.log_info(string.format(
        "Storage page cap (measured): %d page(s)/poem -- budget %dGB, fixed output %.1fGB, "
        .. "%.0fKB/page x %d poems x 2 sides", max_pages, STORAGE_CONFIG.limit_gb,
        fixed / 1e9, avg_page / 1000, num_poems))
    return max_pages
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
-- Issue 16-006: Changed to use poem_index for simpler, machine-readable format
--               Old format: "poem-fediverse-0042" (leaked category info)
--               New format: "poem-4625" (just the unique poem_index)
-- poem: poem object with poem_index field
-- Returns: anchor ID like "poem-4625"
local function get_poem_anchor_id(poem)
    local poem_index = poem.poem_index or 0
    return string.format("poem-%d", poem_index)
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

    local poem_colors_file = utils.embeddings_dir() .. "/poem_colors.json"
    local poem_colors_data = utils.read_json_file(poem_colors_file)

    if poem_colors_data and poem_colors_data.poem_colors then
        -- Count actual entries dynamically (stored total_poems may be stale)
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
-- Computes poem_index → {position, page_number, total_poems, total_pages, timeline_progress}
-- Used by parallel workers to generate correct chronological links and progress bars
-- Issue 8-045: Added timeline_progress for time-based progress bar calculation
local function compute_chronological_mapping(poems_data, chrono_poems_per_page)
    -- Sort chronologically (same as generate_chronological_index_with_navigation)
    local sorted_poems = sort_poems_chronologically_by_dates(poems_data)
    local total_poems = #sorted_poems
    local total_pages = chrono_poems_per_page and math.ceil(total_poems / chrono_poems_per_page) or 1

    -- Issue 8-045: Calculate timeline bounds for time-based progress
    -- sorted_poems[i].timestamp contains Unix timestamp from extract_post_date_from_poem()
    local first_timestamp = sorted_poems[1] and sorted_poems[1].timestamp or 0
    local last_timestamp = sorted_poems[total_poems] and sorted_poems[total_poems].timestamp or 0
    local timeline_span = last_timestamp - first_timestamp
    -- Avoid division by zero if all poems have same timestamp
    if timeline_span <= 0 then timeline_span = 1 end

    -- Build mapping
    local mapping = {}
    for position, poem_info in ipairs(sorted_poems) do
        local poem = poem_info.poem
        local poem_index = poem.poem_index
        if poem_index then
            local page_number = chrono_poems_per_page and math.ceil(position / chrono_poems_per_page) or 1
            -- Issue 8-045: Calculate timeline progress as percentage of time elapsed
            local poem_timestamp = poem_info.timestamp or first_timestamp
            local timeline_progress = ((poem_timestamp - first_timestamp) / timeline_span) * 100
            mapping[poem_index] = {
                position = position,
                page_number = page_number,
                total_poems = total_poems,
                total_pages = total_pages,
                timeline_progress = timeline_progress  -- Issue 8-045: time-based progress
            }
        end
    end

    return mapping
end
-- }}}

-- Exported so the word-cloud pages reuse this EXACT chronological mapping (same
-- timestamp sort + original-index tiebreaker + page size). A divergent inline
-- copy in generate-word-pages sorted by the raw creation_date string with no
-- tiebreaker and its own page-size default, so it computed different page
-- numbers -> "chronological" links pointed at pages the poem wasn't on and never
-- scrolled. One mapping, one answer.
M.compute_chronological_mapping = compute_chronological_mapping
-- {{{ function M.default_chrono_per_page()
-- The chronological page size, from config. There is no compiled-in fallback on
-- purpose: a runtime --chrono-per-page override is the OTHER legitimate source
-- (callers prefer that and use this only when no override was given), and if the
-- config key is somehow missing that is a broken config we want to hear about,
-- not paper over with a silent default that would mis-paginate every poem link.
function M.default_chrono_per_page()
    -- Pull config.lua's pagination overrides into PAGINATION_CONFIG first, so the
    -- default reflects the CONFIG FILE (where --chrono-per-page's default lives),
    -- not the bare source-table placeholder. Idempotent; safe to call anywhere.
    load_pagination_config()
    local value = PAGINATION_CONFIG.chronological_poems_per_page
    if not value then
        error("config is missing chronological_poems_per_page; chronological "
            .. "pagination size is required (pass --chrono-per-page or set it "
            .. "in the pagination config)")
    end
    return value
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
    -- Issue 8-055: Fixed junction positions to align ╧/┴ under ┐/┌ corners
    -- Junction positions in the 82-char interior (0-indexed):
    -- - Position 10: under "similar" box ┐ (same as regular poems)
    -- - Position 71: under "different" box ┌ (regular + 1 due to wider golden poem)
    local LEFT_JUNCTION_POS = 10   -- Same as regular: left box ┐ at position 10
    local RIGHT_JUNCTION_POS = 71  -- Regular + 1: right box ┌ at position 71 (golden is 1 char wider)

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

        -- Bugfix: this copy started at 0 and ended at total_chars, landing the
        -- left junction one column too far right (col 11) and the right one a
        -- dash short -- so the bottom bar did not line up under the nav-box
        -- corners. Start at 1 and end at total_chars+1 to match poem-bars (the
        -- word pages, which were correct): 9 dashes before the left junction so
        -- it sits at column 10, 11 after the right junction. Width is unchanged.
        -- Segment 1: corner ╚ is column 0, so the first dash runs 1..left junction
        add_segment(1, LEFT_JUNCTION_POS)
        -- Insert left junction (colored if ╧, plain if ┴)
        table.insert(segments, left_junction)

        -- Segment 2: from left junction + 1 to right junction (exclusive)
        add_segment(LEFT_JUNCTION_POS + 1, RIGHT_JUNCTION_POS)
        -- Insert right junction (colored if ╧, plain if ┴)
        table.insert(segments, right_junction)

        -- Segment 3: from right junction + 1 to the far corner (exclusive of ┘)
        add_segment(RIGHT_JUNCTION_POS + 1, total_chars + 1)

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
    -- Issue 10-025: Skip anchor poem (GPU cache stores source poem as first entry)
    for step, poem_index in ipairs(cached_sequence) do
        if poem_index ~= starting_poem_id then
            local poem = poem_lookup[poem_index]
            if poem then
                table.insert(diversity_sequence, {
                    id = poem_index,  -- Store poem_index for consistency
                    poem = poem,
                    step = step
                })
            end
        end
    end

    return diversity_sequence
end
-- }}}

-- {{{ function render_attachment_images
-- Issue 8-049: Renamed conceptually to render all media types (images, audio, video)
-- Function name kept for backwards compatibility with existing call sites
local function render_attachment_images(attachments)
    -- Render HTML for poem attachments (images, audio, video)
    -- Returns empty string if no attachments or no renderable attachments
    -- Media output format designed for 80-char width aesthetic
    --
    -- ATTACHMENT STRUCTURE (from ActivityPub extraction):
    -- {
    --   media_type = "image/png" or "audio/mpeg" or "video/mp4",
    --   url = "https://server.com/media/files/123/456/original/abc.png",
    --   relative_path = "files/123/456/original/abc.png",
    --   alt_text = "User description" or nil,
    --   width = 1920,   -- images/video only
    --   height = 1080   -- images/video only
    -- }

    if not attachments or #attachments == 0 then
        return ""
    end

    local media_html = {}
    -- "up to the site root" -- these attachments render on poem pages, which sit
    -- one level below output/ (output/similar/, output/different/, ...), so a
    -- "../" prefix reaches the root. Document-relative: resolves the same opened
    -- locally from any folder or served on the site, so no path conversion step.
    local base_path = ".."

    for _, attachment in ipairs(attachments) do
        local media_type = attachment.media_type or ""
        -- Issue 8-048: media lives at output/media/<source>/<subpath> (see
        -- flatten_media_files); media_href keeps art's source+subdir structure so
        -- same-named pieces don't collide. "../media/" reaches it from a poem page.
        local relative_path = attachment.relative_path or ""
        -- media_href namespaces art by source+subdir (collision-safe) and
        -- url-encodes; Mastodon hashes collapse to the bare name. Matches where
        -- flatten_media_files placed the file.
        local media_src = base_path .. "/media/" .. media_href(relative_path)

        if media_type:match("^image/") then
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
                    media_src, alt_text, alt_text, attachment.width, attachment.height
                )
            else
                img_tag = string.format(
                    '  <img src="%s" alt="%s" title="%s" loading="lazy" style="display:block; max-width:min(100%%,800px); height:auto">',
                    media_src, alt_text, alt_text
                )
            end
            table.insert(media_html, img_tag)

        elseif media_type:match("^audio/") then
            -- Issue 8-049: Audio playback support
            -- controls: Shows play/pause, volume, seek bar
            -- preload="metadata": Only loads duration/metadata initially for performance
            local audio_tag = string.format(
                '  <audio controls preload="metadata" style="display:block; max-width:100%%">\n' ..
                '    <source src="%s" type="%s">\n' ..
                '    Your browser does not support the audio element.\n' ..
                '  </audio>',
                media_src, media_type
            )
            table.insert(media_html, audio_tag)

        elseif media_type:match("^video/") then
            -- Issue 8-049: Video playback support
            -- controls: Shows play/pause, volume, seek bar, fullscreen
            -- preload="metadata": Only loads poster frame initially for performance
            -- max-width caps at content width while being responsive
            local video_tag
            if attachment.width and attachment.height then
                video_tag = string.format(
                    '  <video controls preload="metadata" width="%d" height="%d" style="display:block; max-width:min(100%%,800px); height:auto">\n' ..
                    '    <source src="%s" type="%s">\n' ..
                    '    Your browser does not support the video element.\n' ..
                    '  </video>',
                    attachment.width, attachment.height, media_src, media_type
                )
            else
                video_tag = string.format(
                    '  <video controls preload="metadata" style="display:block; max-width:min(100%%,800px); height:auto">\n' ..
                    '    <source src="%s" type="%s">\n' ..
                    '    Your browser does not support the video element.\n' ..
                    '  </video>',
                    media_src, media_type
                )
            end
            table.insert(media_html, video_tag)
        end
    end

    if #media_html == 0 then
        return ""
    end

    -- Issue 8-005 Fix: Close </pre> before media, reopen after
    -- Media inside <pre> don't respect max-width:100% because <pre> sizes to content
    -- By closing </pre>, media inherit width constraints from the parent <td> container
    return "\n</pre>\n" .. table.concat(media_html, "\n") .. "\n<pre>\n"
end
-- }}}

-- {{{ function render_attachment_images_txt
-- Issue 8-049: Now handles all media types (images, audio, video)
local function render_attachment_images_txt(attachments)
    -- Render plain text placeholders for poem attachments (images, audio, video)
    -- Returns [Image: alt-text], [Audio: filename], [Video: filename] format for TXT export
    -- Unlike render_attachment_images(), this outputs plain text, not HTML
    --
    -- This function exists because TXT exports cannot contain HTML media tags.
    -- Media are replaced with bracketed descriptions.

    if not attachments or #attachments == 0 then
        return ""
    end

    local media_lines = {}

    for _, attachment in ipairs(attachments) do
        local media_type = attachment.media_type or ""
        local placeholder

        if media_type:match("^image/") then
            -- Use alt text if available, otherwise indicate no description
            local alt_text = attachment.description or attachment.alt_text or "no description"
            placeholder = string.format("[Image: %s]", alt_text)

        elseif media_type:match("^audio/") then
            -- Issue 8-049: Audio placeholder
            local basename = (attachment.relative_path or ""):match("([^/]+)$") or "audio file"
            placeholder = string.format("[Audio: %s]", basename)

        elseif media_type:match("^video/") then
            -- Issue 8-049: Video placeholder
            local basename = (attachment.relative_path or ""):match("([^/]+)$") or "video file"
            placeholder = string.format("[Video: %s]", basename)
        end

        if placeholder then
            -- Wrap long text to 80 characters
            if #placeholder > 80 then
                placeholder = wrap_text_80_chars(placeholder)
            end
            table.insert(media_lines, placeholder)
        end
    end

    if #media_lines == 0 then
        return ""
    end

    -- Return with newline prefix/suffix for proper spacing
    return "\n" .. table.concat(media_lines, "\n") .. "\n"
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
        -- Strip NUL and other C0 control bytes that occasionally ride along in
        -- source poem text (a stray \0 in one post is what made a chronological
        -- page read as "binary" and could make a browser choke on it). Keep the
        -- legitimate whitespace controls: tab (\9), newline (\10), CR (\13).
        :gsub("[%z\1-\8\11\12\14-\31]", "")
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

-- {{{ function is_boost_poem
local function is_boost_poem(poem)
    -- Issue 8-057: Detect boosted/shared posts for visual formatting
    -- Boosts are reshared content from other fediverse users
    -- boost_type can be: "cached_external", "external", or "embedded"
    if poem.metadata and poem.metadata.is_boost then
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
        -- Issue 8-055: Also decode HTML entities for accurate width counting
        -- e.g., &gt; is 4 bytes but displays as 1 character (>)
        local visible_length = text_formatter.calculate_visible_width(line)

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

-- {{{ Issue 8-057: Boost Visual Formatting Functions
-- Boosts use nested frames: outer blue frame + inner teal content box with
-- asymmetric arrows (◀═ top-left, ─▶ bottom-right) and a floating [BOOST] label.
-- ALL geometry now lives in src/boost-bars.lua (shared, unit-tested) -- the old
-- generate_boost_* helpers were removed because three drifting copies produced
-- misaligned walls, wrong junction columns, and ▢ corruption. This path keeps
-- only the thin assembler below.

-- {{{ function apply_boost_poem_formatting
local function apply_boost_poem_formatting(content, progress_percent, similar_link, different_link, chronological_link)
    -- Issue 8-057: nested frame formatting for boosts, drawn by the shared
    -- boost-bars module (single source of truth for every render path). We just
    -- split the pre-wrapped content into lines; the module owns all geometry.
    local lines = {}
    for line in (content .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    local include_nav = (similar_link and different_link) and true or false
    return boost_bars.format_boost(
        lines, progress_percent, similar_link, different_link, chronological_link, include_nav)
end
-- }}}

-- }}} End Issue 8-057: Boost Visual Formatting Functions

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
    -- Issue 10-021: Use text_formatter.format_poem_lines to preserve empty lines (paragraph breaks)
    local lines = text_formatter.format_poem_lines(text)

    for _, line in ipairs(lines) do
        -- Check if line starts with content warning (in-content CW pattern)
        if line:lower():match("^%s*cw%s*:") or line:lower():match("^%s*content warning%s*:") then
            -- Format content warning with box
            local warning_box = format_warning_box(line)
            table.insert(formatted_lines, warning_box)
            table.insert(formatted_lines, "") -- First newline
            table.insert(formatted_lines, "") -- Second newline for spacing
        else
            -- Issue 10-021: Wrap long lines while preserving leading whitespace
            -- This replaces 8-056's no-wrap approach with whitespace-aware wrapping
            local wrapped = text_formatter.wrap_preserving_indent(line, 80)
            for _, wrapped_line in ipairs(wrapped) do
                table.insert(formatted_lines, wrapped_line)
            end
        end
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

-- One warning per process, not per poem. The check that needs announcing lives
-- inside the per-poem formatter, and a full build formats roughly 700,000
-- entries -- warning at each one would bury the message it is trying to deliver.
local chrono_fallback_warned = false

-- {{{ local function warn_chrono_fallback_once
-- Announces that a chronological link could not be aimed at a real page number.
-- The reason string names WHICH way the mapping failed, so the caller that
-- dropped it can be found without re-deriving this whole path.
local function warn_chrono_fallback_once(reason)
    if chrono_fallback_warned then return end
    chrono_fallback_warned = true
    utils.log_warn(string.format(
        "chronological links fell back to chronological/index.html (%s) - " ..
        "the #poem anchor is lost across that redirect, so every link lands at " ..
        "the top of the chronological view instead of at its poem", reason))
end
-- }}}

-- {{{ function format_single_poem_with_progress_and_color
-- Issue 10-036: Added chrono_mapping for correct paginated chronological links
-- chrono_paginated: whether the chronological view was split into numbered pages.
--   It cannot be read from PAGINATION_CONFIG here, because --chrono-per-page
--   turns pagination on at runtime without touching the config table.
local function format_single_poem_with_progress_and_color(poem, total_poems, poem_colors, chrono_mapping, chrono_paginated)
    -- Issue 9-013: a ranked IMAGE entry (pseudo-poem) renders as an image box,
    -- not a poem. Inert until inject_pseudo_poems tags/append image entries.
    if poem.is_image then
        return image_render.format_image_entry(poem)
    end

    local formatted = ""

    -- Get semantic color for this poem (key by poem_index, NOT poem.id)
    local poem_color_data = poem_colors[poem.poem_index]
    local semantic_color = poem_color_data and poem_color_data.color or "gray"
    local hex_color = COLOR_CONFIG[semantic_color] or COLOR_CONFIG["gray"]

    -- Calculate chronological progress (using poem_index for lookup)
    local progress_info = calculate_chronological_progress(poem.poem_index, total_poems)

    -- Check if this is a golden poem (exactly 1024 characters)
    local is_golden = is_golden_poem(poem)

    -- Issue 8-057: Check if this is a boost (reshared content from another author)
    local is_boost = is_boost_poem(poem)

    -- Build navigation links for this poem (using category prefix for anchors, poem_index for paginated files)
    local unique_id = get_unique_poem_filename_id(poem)  -- For anchor IDs only (e.g. "messages-0001")
    local anchor_id = get_poem_anchor_id(poem)
    local poem_index = poem.poem_index or 0  -- Numeric ID for paginated files (e.g. 1 → "0001")

    -- Issue 8-012 Phase E: Link to paginated format (similar/0001-01.html)
    -- Issue 9-003: Use absolute file:// paths - helper script converts to production URLs
    local base_path = ".."
    local similar_link = string.format("<a href='%s/similar/%04d-01.html'>similar</a>", base_path, poem_index)
    local different_link = string.format("<a href='%s/different/%04d-01.html'>different</a>", base_path, poem_index)
    -- Issue 8-039: Chronological now in subdirectory
    -- Issue 10-036: the link must name the chronological page that actually holds
    -- this poem, and TWO facts decide that filename -- both have to reach here:
    --   chrono_mapping   poem_index -> {page_number, total_pages, ...}
    --   chrono_paginated whether the view was split into numbered pages at all
    -- Paginated builds write chronological/NN.html; unpaginated builds write only
    -- chronological/index.html. That branch is the one in
    -- generate_chronological_index_with_navigation, and this link has to agree
    -- with it or it names a file that was never written.
    --
    -- The old code guessed "01" whenever the mapping was absent. That guess is
    -- how a full build shipped 694,530 links all pointing at chronological page
    -- 1: this sequential path ran with chrono_mapping = nil, so every poem on
    -- every similar/different page claimed to live among the first 88 poems.
    -- A guess that is silently wrong for 99% of a corpus is worse than a stop,
    -- so the fallback now goes to index.html -- the one file guaranteed to exist
    -- in BOTH modes -- and says out loud that it gave up the anchor.
    local chrono_info = chrono_mapping and chrono_mapping[poem_index]
    local chronological_link
    if chrono_info and chrono_paginated and (chrono_info.total_pages or 1) > 1 then
        chronological_link = string.format("<a href='%s/chronological/%02d.html#%s'>chronological</a>",
            base_path, chrono_info.page_number, anchor_id)
    else
        -- Unpaginated with a real mapping is the correct, quiet case: index.html
        -- IS the whole chronological view, and the anchor resolves inside it.
        if not chrono_mapping then
            warn_chrono_fallback_once("no chronological mapping reached this generator")
        elseif not chrono_info then
            warn_chrono_fallback_once(string.format(
                "poem_index %d is absent from the chronological mapping", poem_index))
        end
        chronological_link = string.format("<a href='%s/chronological/index.html#%s'>chronological</a>",
            base_path, anchor_id)
    end

    -- Add file header (notes show original filename, others show numeric ID)
    formatted = formatted .. string.format(" -> file: %s\n", get_poem_display_filename(poem))
    -- Issue 9-013: text+image posts get a direct "image.png" link below the
    -- header. (Image entries never reach here -- they return early above.)
    local img_link = image_render.text_image_link(poem)
    if img_link ~= "" then formatted = formatted .. " " .. img_link .. "\n" end

    -- Issue 8-057: Boost formatting - uses complete nested frame with arrows and [BOOST] label
    -- Boost formatting replaces all standard elements (top bar, content, nav, bottom bar)
    if is_boost then
        -- Escape HTML and apply markdown to content
        local text = escape_html(poem.content or "")

        -- Issue 10-037: Defensive fallback for blank boost content
        -- If content is empty, display the original URI or diagnostic message
        if text == "" or text:match("^%s*$") then
            local original_uri = poem.metadata and poem.metadata.original_uri
            if original_uri then
                text = "External post: " .. escape_html(original_uri)
            else
                text = "(Boost content unavailable)"
            end
        end

        -- Issue 10-039: Make external boost URLs clickable
        -- Pattern: "External post: https://..." -> wrap URL in anchor tag
        local external_pattern = "^External post: (https?://[^%s]+)$"
        local external_url = text:match(external_pattern)
        if external_url then
            -- Wrap the URL across box lines (boost content width) instead of
            -- letting it overflow the box; each line links to the full URL.
            text = text_formatter.wrap_external_url("External post: ", external_url, boost_bars.CONTENT_WIDTH)
        else
            -- Issue 10-041: Wrap long embedded content to fit the boost box.
            -- Only wrap non-external-post content (external posts keep URLs intact)
            local BOOST_CONTENT_WIDTH = boost_bars.CONTENT_WIDTH
            local wrapped_lines = {}
            for line in (text .. "\n"):gmatch("(.-)\n") do
                local wrapped = text_formatter.wrap_preserving_indent(line, BOOST_CONTENT_WIDTH)
                for _, wrapped_line in ipairs(wrapped) do
                    table.insert(wrapped_lines, wrapped_line)
                end
            end
            text = table.concat(wrapped_lines, "\n")
        end

        text = apply_markdown_formatting(text)

        -- Calculate progress as decimal (0-1) for boost functions
        local progress_percent = progress_info.percentage / 100

        -- Apply complete boost formatting (includes all frame elements)
        local boost_formatted = apply_boost_poem_formatting(
            text, progress_percent, similar_link, different_link, chronological_link
        )
        formatted = formatted .. boost_formatted .. "\n"

        -- Render attached images after boost frame
        if poem.attachments then
            formatted = formatted .. render_attachment_images(poem.attachments)
        end

        return {
            content = formatted,
            semantic_color = semantic_color,
            progress_percentage = progress_info.percentage,
            poem_id = poem.id
        }
    end

    -- Standard formatting for golden and regular poems
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
-- Issue 10-036: Added chrono_mapping for correct paginated chronological links
local function format_all_poems_with_progress_and_color(starting_poem, sorted_poems, total_poems, poem_colors, chrono_mapping, chrono_paginated)
    local content = ""

    -- Add starting poem first with progress visualization
    local formatted_starting = format_single_poem_with_progress_and_color(starting_poem, total_poems, poem_colors, chrono_mapping, chrono_paginated)
    content = content .. formatted_starting.content .. "\n\n"

    -- Add all other poems sorted by similarity/diversity
    for _, poem_info in ipairs(sorted_poems) do
        if poem_info.id ~= starting_poem.id then  -- Skip starting poem since we already added it
            local formatted_poem = format_single_poem_with_progress_and_color(poem_info.poem, total_poems, poem_colors, chrono_mapping, chrono_paginated)
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
-- Issue 10-036: Added chrono_mapping for correct paginated chronological links
function M.generate_flat_poem_list_html_with_progress(starting_poem, sorted_poems, page_type, starting_poem_id, use_progress, chrono_mapping, chrono_paginated)
    -- Template uses pure HTML without CSS (except Issue 16-010 font-stack)
    -- Content is pre-wrapped to 80 chars, <pre> provides monospace formatting
    -- Issue 9-003 Fix: Use centered table for block centering with left-aligned text inside
    -- Issue 16-010: Added FONT_STYLE for Hack Nerd Font font-stack
    local template = [[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Poems sorted by %s to: %s</title>
]] .. FONT_STYLE .. [[</head>
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

        -- Issue 10-036: Pass chrono_mapping for correct paginated chronological links
        formatted_content = format_all_poems_with_progress_and_color(starting_poem, sorted_poems, total_poems, poem_colors, chrono_mapping, chrono_paginated)
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
-- Issue 10-036: Added chrono_mapping for correct paginated chronological links
function M.generate_flat_poem_list_html(starting_poem, sorted_poems, page_type, starting_poem_id, chrono_mapping, chrono_paginated)
    -- Default to using progress bars
    return M.generate_flat_poem_list_html_with_progress(starting_poem, sorted_poems, page_type, starting_poem_id, true, chrono_mapping, chrono_paginated)
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
-- chrono_mapping: optional - poem_index → {page_number, ...} for correct chronological links
-- Returns: HTML string for this specific page
-- Updated for Issue 8-020: Passes total_corpus to navigation for storage constraint messaging
-- Issue 10-036: Added chrono_mapping for correct paginated chronological links
function M.generate_paginated_poem_page_html(starting_poem, sorted_poems, page_type, starting_poem_id, page_num, total_pages, total_corpus, chrono_mapping, chrono_paginated)
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
    -- Issue 10-036: Pass chrono_mapping for correct paginated chronological links
    local formatted_content = format_all_poems_with_progress_and_color(
        starting_poem, page_poems, corpus_total, poem_colors, chrono_mapping, chrono_paginated)

    -- Build the page
    local page_type_desc = (page_type == "similar") and "similarity" or "difference"
    local starting_title = starting_poem.title or ("Poem " .. starting_poem_id)
    local padded_id = string.format("%04d", starting_poem_id)

    -- Generate download links for full-corpus exports
    local download_links = generate_download_links(starting_poem_id, page_type)

    -- Issue 9-003 Fix: Use centered table for block centering with left-aligned text inside
    -- Issue 16-010: Added FONT_STYLE for Hack Nerd Font font-stack
    local template = [[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Poems sorted by %s to: %s (Page %d of %d)</title>
]] .. FONT_STYLE .. [[</head>
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
-- chrono_mapping: poem_index -> {page_number, total_pages, ...}; see Issue 10-036
-- chrono_paginated: whether the chronological view was split into numbered pages
-- Returns: table with generated file paths and stats
-- Updated for Issue 8-020: Respects max_pages_per_poem storage constraint
-- Issue 10-036 (regression): these last two parameters did not exist, so the
-- sequential path -- the ONLY path that runs now that effil is gone -- had no way
-- to tell the formatter which chronological page a poem sits on. Every link fell
-- to the "01" guess. They are threaded, not read from config, because
-- --chrono-per-page enables pagination at runtime without touching the config.
function M.generate_all_paginated_pages_for_poem(starting_poem, sorted_poems, page_type, starting_poem_id, output_dir, pages_to_generate, chrono_mapping, chrono_paginated)
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
                page_num, total_pages, total_poems,  -- Pass total_poems for storage context
                chrono_mapping, chrono_paginated)    -- Issue 10-036: aim the chronological links at real pages

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

    -- Apply CLI override if provided. Pagination is enabled either by config
    -- or by the operator supplying --chrono-per-page.
    if chrono_per_page and type(chrono_per_page) == "number" and chrono_per_page > 0 then
        poems_per_page = chrono_per_page
        chronological_paginated = true
    end

    utils.log_info(string.format("Chronological pagination: %d poems/page", poems_per_page))

    -- Sort poems chronologically (by actual post dates)
    local sorted_poems_with_timestamps = sort_poems_chronologically_by_dates(poems_data)
    local total_poems = #sorted_poems_with_timestamps

    -- Issue 8-045: Calculate timeline bounds for time-based progress bars
    local first_timestamp = sorted_poems_with_timestamps[1] and sorted_poems_with_timestamps[1].timestamp or 0
    local last_timestamp = sorted_poems_with_timestamps[total_poems] and sorted_poems_with_timestamps[total_poems].timestamp or 0
    local timeline_span = last_timestamp - first_timestamp
    if timeline_span <= 0 then timeline_span = 1 end  -- Avoid division by zero

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
        -- Issue 16-010: Added FONT_STYLE for Hack Nerd Font font-stack
        local template
        if chronological_paginated and total_pages > 1 then
            template = string.format([[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Poetry Collection - Chronological Order (Page %d of %d)</title>
%s</head>
<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">
<center>
<h1>Poetry Collection</h1>
<p>Poems in true chronological order by post date</p>
%s
<p><a href="../wordcloud.html">Menu</a></p>
</center>
<table align="center"><tr><td>
<pre>
%%s
</pre>
</td></tr></table>
<center>%s</center>
</body>
</html>]], page_num, total_pages, FONT_STYLE, page_nav_html, page_nav_html)
        else
            template = [[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Poetry Collection - Chronological Order</title>
]] .. FONT_STYLE .. [[</head>
<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">
<center>
<h1>Poetry Collection</h1>
<p>All poems in true chronological order by post date</p>
<p><a href="../wordcloud.html">Menu</a></p>
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

            -- Issue 8-045: Calculate chronological progress based on actual timestamp
            -- This shows temporal position in the author's timeline, not just poem count
            local poem_timestamp = poem_info.timestamp or first_timestamp
            local timeline_progress = ((poem_timestamp - first_timestamp) / timeline_span) * 100
            local progress_info = {
                poem_id = poem_id,
                total_poems = total_poems,
                percentage = timeline_progress,  -- Issue 8-045: time-based, not position-based
                position = i,
                temporal_index = i
            }

            local poem_color_data = poem_colors[poem_id]
            local semantic_color = poem_color_data and poem_color_data.color or "gray"
            local is_golden = is_golden_poem(poem)
            local is_boost = is_boost_poem(poem)  -- Issue 10-040: Check for boosts
            local anchor_id = get_poem_anchor_id(poem)
            local poem_index = poem.poem_index or 0

            -- Add HTML anchor
            content = content .. string.format('<span id="%s"></span>', anchor_id)
            content = content .. string.format(" -> file: %s\n", get_poem_display_filename(poem))

            -- Navigation links (absolute paths for consistency)
            -- Issue 9-003: Use absolute file:// paths - helper script converts to production URLs
            local base_path = ".."
            local similar_link = string.format("<a href='%s/similar/%04d-01.html'>similar</a>", base_path, poem_index)
            local different_link = string.format("<a href='%s/different/%04d-01.html'>different</a>", base_path, poem_index)
            local chronological_link = nil  -- Issue 9-003 Fix C: No chronological link on chronological pages

            -- Issue 10-040: Apply boost formatting consistently on chronological pages
            -- Uses same boost box styling as similar/different pages
            if is_boost then
                -- Escape HTML and apply markdown to content
                local text = escape_html(poem.content or "")

                -- Issue 10-037: Defensive fallback for blank boost content
                if text == "" or text:match("^%s*$") then
                    local original_uri = poem.metadata and poem.metadata.original_uri
                    if original_uri then
                        text = "External post: " .. escape_html(original_uri)
                    else
                        text = "(Boost content unavailable)"
                    end
                end

                -- Issue 10-039: Make external boost URLs clickable
                local external_pattern = "^External post: (https?://[^%s]+)$"
                local external_url = text:match(external_pattern)
                if external_url then
                    -- Wrap the URL across box lines instead of overflowing.
                    text = text_formatter.wrap_external_url("External post: ", external_url, boost_bars.CONTENT_WIDTH)
                else
                    -- Issue 10-041: Wrap long embedded content to fit boost box
                    local BOOST_CONTENT_WIDTH = boost_bars.CONTENT_WIDTH
                    local wrapped_lines = {}
                    for line in (text .. "\n"):gmatch("(.-)\n") do
                        local wrapped = text_formatter.wrap_preserving_indent(line, BOOST_CONTENT_WIDTH)
                        for _, wrapped_line in ipairs(wrapped) do
                            table.insert(wrapped_lines, wrapped_line)
                        end
                    end
                    text = table.concat(wrapped_lines, "\n")
                end

                text = apply_markdown_formatting(text)

                -- Calculate progress as decimal (0-1) for boost functions
                local progress_decimal = progress_info.percentage / 100

                -- Apply complete boost formatting (includes all frame elements)
                local boost_formatted = apply_boost_poem_formatting(
                    text, progress_decimal, similar_link, different_link, chronological_link
                )
                content = content .. boost_formatted .. "\n"

                -- Render attached images after boost frame
                if poem.attachments then
                    content = content .. render_attachment_images(poem.attachments)
                end
            else
                -- Standard formatting for golden and regular poems
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
            end

            -- Generate bottom progress bar (skip for boosts - they have their own bottom border)
            if not is_boost then
                local bottom_dashes = generate_progress_dashes(progress_info, semantic_color, is_golden, "bottom", true)
                content = content .. string.format('<span %s>%s</span>\n\n',
                                                  bottom_dashes.accessibility,
                                                  bottom_dashes.visual)
            else
                content = content .. "\n"  -- Just add spacing between poems
            end
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

-- {{{ function explore_page_shell()
-- Shared HTML shell for the explore pages: black background, monospace, the
-- corrected centered-<pre> layout. Returns the full document for a title +
-- heading + pre-formatted body.
local function explore_page_shell(title, heading, body)
    return string.format([[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>%s</title>
]] .. FONT_STYLE .. [[</head>
<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">
<center>
<h1>%s</h1>
</center>
<table align="center"><tr><td>
<pre>
%s
</pre>
</td></tr></table>
</body>
</html>]], title, heading, body)
end
-- }}}

-- {{{ function corpus_stats()
-- Gather the live numbers both explore pages render from, so nothing is
-- hard-coded (stale figures are worse than no figures). Reads only poems_data
-- (the small 12MB file) -- never the 662MB similarity matrix -- so it is cheap.
local function corpus_stats(poems_data)
    local poems = (poems_data and poems_data.poems) or {}
    local stats = {
        total = #poems,
        sources = {},          -- category -> count
        source_order = {},     -- source names, most-poems first
        image_only = 0,
        min_date = nil, max_date = nil,
        per_year = {}, year_order = {},
        length_hist = {}, length_labels = {},  -- length-distribution buckets
    }
    -- Length buckets (characters). The last bucket is open-ended.
    local edges = {0, 100, 250, 500, 1000, 2000}
    for i = 1, #edges do
        stats.length_hist[i] = 0
        if i < #edges then
            stats.length_labels[i] = string.format("%d-%d", edges[i], edges[i + 1] - 1)
        else
            stats.length_labels[i] = string.format("%d+", edges[i])
        end
    end
    for _, p in ipairs(poems) do
        local cat = p.category or "unknown"
        stats.sources[cat] = (stats.sources[cat] or 0) + 1
        if p.is_image_only then stats.image_only = stats.image_only + 1 end
        local d = p.creation_date
        if d and d ~= "" then
            if not stats.min_date or d < stats.min_date then stats.min_date = d end
            if not stats.max_date or d > stats.max_date then stats.max_date = d end
            local year = d:sub(1, 4)
            if year:match("^%d%d%d%d$") then
                stats.per_year[year] = (stats.per_year[year] or 0) + 1
            end
        end
        -- Place the poem in its length bucket (last edge is open-ended).
        local len = p.length or #(p.content or "")
        local bucket = #edges
        for i = 1, #edges - 1 do
            if len < edges[i + 1] then bucket = i; break end
        end
        stats.length_hist[bucket] = stats.length_hist[bucket] + 1
    end
    for cat in pairs(stats.sources) do stats.source_order[#stats.source_order + 1] = cat end
    table.sort(stats.source_order, function(a, b) return stats.sources[a] > stats.sources[b] end)
    for year in pairs(stats.per_year) do stats.year_order[#stats.year_order + 1] = year end
    table.sort(stats.year_order)
    return stats
end
-- }}}

-- {{{ function ascii_bar_row()
-- One labelled monospace bar: "<label padded> | ████····  <count>". Fits the
-- site's no-JS, monospace aesthetic (same idiom as the poem progress bars).
local function ascii_bar_row(label, count, max_count, bar_width, label_width)
    local filled = (max_count > 0) and math.floor((count / max_count) * bar_width + 0.5) or 0
    if filled > bar_width then filled = bar_width end
    local bar = string.rep("█", filled) .. string.rep("·", bar_width - filled)
    return string.format("%-" .. label_width .. "s | %s  %d", label, bar, count)
end
-- }}}

-- {{{ function M.generate_simple_discovery_instructions
-- Back-compat shim: callers that pass only output_dir still work (boosts/golden
-- counts simply won't appear without the corpus). Prefer passing poems_data.
function M.generate_simple_discovery_instructions(output_dir, poems_data)
    M.generate_explore_page(output_dir, poems_data)
    M.generate_explore_math_page(output_dir, poems_data)
    return output_dir .. "/explore.html"
end
-- }}}

-- {{{ function M.generate_explore_page()
-- explore.html -- the welcome / map: orientation + live corpus stats + every
-- navigation mode + links to the deeper-math page and (placeholder) the source
-- browser (Issue 10-052). Data/view split: corpus_stats() computes, this renders.
function M.generate_explore_page(output_dir, poems_data)
    local s = corpus_stats(poems_data)

    -- The per-source list is a LOOP over the corpus, so it stays rendered here
    -- and is handed to the template as one ready-made block (Issue 11-005: prose
    -- and scalars live in the editable file; loops stay in code).
    local source_rows = {}
    for _, cat in ipairs(s.source_order) do
        source_rows[#source_rows + 1] = string.format("    %-22s %d", cat, s.sources[cat])
    end

    -- The scalar facts that only make sense when they exist use page_template.OMIT,
    -- which drops the whole template line -- matching the old "only add this line
    -- when there is a date / an image-only count" conditionals, with no blank gap.
    local values = {
        TOTAL_POEMS  = s.total,
        SOURCE_COUNT = #s.source_order,
        MIN_DATE     = (s.min_date and s.max_date) and s.min_date:sub(1, 10) or page_template.OMIT,
        MAX_DATE     = (s.min_date and s.max_date) and s.max_date:sub(1, 10) or page_template.OMIT,
        IMAGE_ONLY_COUNT = (s.image_only > 0) and s.image_only or page_template.OMIT,
        SOURCE_LIST  = table.concat(source_rows, "\n"),
    }

    local template_path = DIR .. "/input/pages/explore.txt"
    local body, err = page_template.render_file(template_path, values)
    -- A broken template (typo'd marker, missing file) is a real error worth
    -- halting on -- a half-filled page is worse than a loud failure (no fallbacks).
    if not body then error("generate_explore_page: " .. tostring(err)) end
    -- The template file ends with a newline; the page shell adds its own, so trim
    -- trailing newlines to keep the centered <pre> block from gaining a blank tail.
    body = body:gsub("\n+$", "")

    local html = explore_page_shell(
        "Poetry Collection - Explore", "Poetry Collection - Explore", body)
    local output_file = output_dir .. "/explore.html"
    return utils.write_file(output_file, html) and output_file or nil
end
-- }}}

-- {{{ function M.generate_explore_math_page()
-- explore-2.html -- the deeper math: how the semantic engine works, explained
-- honestly, with REAL corpus-shape charts (per-source, length, over-time) drawn
-- as monospace bars. Similarity-distribution charts need the 662MB matrix that
-- is deliberately not loaded here, so they are noted as a future addition.
function M.generate_explore_math_page(output_dir, poems_data)
    local s = corpus_stats(poems_data)
    local BAR = 40

    -- Each histogram is a LOOP over the corpus, so they stay rendered here and are
    -- handed to the template as ready-made blocks (Issue 11-005). ascii_bar_row
    -- draws one labelled monospace bar.

    -- Poems-per-source bars.
    local max_src = 0
    for _, c in ipairs(s.source_order) do if s.sources[c] > max_src then max_src = s.sources[c] end end
    local source_bars = {}
    for _, cat in ipairs(s.source_order) do
        source_bars[#source_bars + 1] = "    " .. ascii_bar_row(cat, s.sources[cat], max_src, BAR, 20)
    end

    -- Poem-length bars.
    local max_len_bucket = 0
    for _, v in ipairs(s.length_hist) do if v > max_len_bucket then max_len_bucket = v end end
    local length_bars = {}
    for i, label in ipairs(s.length_labels) do
        length_bars[#length_bars + 1] = "    " .. ascii_bar_row(label, s.length_hist[i], max_len_bucket, BAR, 20)
    end

    -- Poems-per-year is a whole conditional section (blank line + heading + bars).
    -- When the corpus has no dated poems it becomes OMIT, dropping the section's
    -- template line entirely -- the same guard the inline version used.
    local year_section
    if #s.year_order > 0 then
        local year_lines = { "", "  Poems per year:" }
        local max_year = 0
        for _, y in ipairs(s.year_order) do if s.per_year[y] > max_year then max_year = s.per_year[y] end end
        for _, y in ipairs(s.year_order) do
            year_lines[#year_lines + 1] = "    " .. ascii_bar_row(y, s.per_year[y], max_year, BAR, 20)
        end
        year_section = table.concat(year_lines, "\n")
    else
        year_section = page_template.OMIT
    end

    -- The embedding-model name comes from the live inference config rather than a
    -- baked-in string, so it can never drift from the model the pipeline actually
    -- used (per the "reference a source, don't hard-code figures" convention).
    local values = {
        EMBEDDING_MODEL = inference_config.get_selected_model(),
        TOTAL_POEMS = s.total,
        SOURCE_BARS = table.concat(source_bars, "\n"),
        LENGTH_BARS = table.concat(length_bars, "\n"),
        YEAR_SECTION = year_section,
    }

    local template_path = DIR .. "/input/pages/explore-math.txt"
    local body, err = page_template.render_file(template_path, values)
    if not body then error("generate_explore_math_page: " .. tostring(err)) end
    body = body:gsub("\n+$", "")

    local html = explore_page_shell(
        "Poetry Collection - The Math", "How the Similarity Works", body)
    local output_file = output_dir .. "/explore-2.html"
    return utils.write_file(output_file, html) and output_file or nil
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
-- Issue 10-036: Added chrono_mapping for correct paginated chronological links
function generate_similarity_html_archive(starting_poem, sorted_poems, output_file, chrono_mapping, chrono_paginated)
    -- Generate HTML archive for similarity-sorted poems (full corpus with images)
    -- Unlike paginated pages, this is a single file with ALL poems
    -- Use poem_index (globally unique) for consistency
    local html = M.generate_flat_poem_list_html(starting_poem, sorted_poems, "similar", starting_poem.poem_index, chrono_mapping, chrono_paginated)
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
-- Issue 10-036: Added chrono_mapping for correct paginated chronological links
function generate_diversity_html_archive(starting_poem, sorted_poems, output_file, chrono_mapping, chrono_paginated)
    -- Generate HTML archive for diversity-sorted poems (full corpus with images)
    -- Unlike paginated pages, this is a single file with ALL poems
    -- Use poem_index (globally unique) for consistency
    local html = M.generate_flat_poem_list_html(starting_poem, sorted_poems, "different", starting_poem.poem_index, chrono_mapping, chrono_paginated)
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

    -- Apply CLI override if provided. The honest summary below is logged
    -- whether or not an override was supplied — what the operator wants to
    -- see is "what value am I actually using," not "which knob set it."
    if poems_per_page and type(poems_per_page) == "number" and poems_per_page > 0 then
        PAGINATION_CONFIG.poems_per_page = poems_per_page
    end

    -- Issue 10-057 follow-up: the storage ceiling on pages-per-poem is MEASURED from
    -- the budget and the last build's actual page sizes, not frozen in config (the old
    -- literal 15 would have shipped ~66GB into a 45GB quota). Self-corrects each build.
    PAGINATION_CONFIG.max_pages_per_poem =
        compute_storage_max_pages(output_dir, #(poems_data.poems or {}))

    -- Issue 10-057: both neighbour caches may be capped to the top-K poems per poem
    -- (each stamps the K it was built with). If this run asks for more pages than that
    -- K can fill, a poem would silently get fewer pages than --pages requested. Fail
    -- loudly with the exact regen command instead of under-generating. A stamp of 0
    -- (or no stamp -- an older, uncapped cache) means "keep all", always enough.
    do
        local per_page = PAGINATION_CONFIG.poems_per_page
        local pages
        if not pages_spec or pages_spec == "" or pages_spec == "default" then
            pages = PAGINATION_CONFIG.minimum_pages
        elseif pages_spec == "all" then
            pages = PAGINATION_CONFIG.max_pages_per_poem
        else
            pages = tonumber(pages_spec)
                or tonumber(tostring(pages_spec):match("(%d+)$"))
                or PAGINATION_CONFIG.minimum_pages
        end
        local needed_k = pages * per_page
        local function check_cache(cache, label, regen_flag)
            local meta = cache and cache.metadata
            local stored_k = meta and tonumber(meta.top_k) or 0
            if stored_k > 0 and stored_k < needed_k then
                error(string.format(
                    "%s cache holds only top-%d per poem, but this run needs %d (%d page(s) "
                    .. "x %d poems/page). Regenerate it for these settings: ./run.sh %s "
                    .. "--pages %d --poems-per-page %d",
                    label, stored_k, needed_k, pages, per_page, regen_flag, pages, per_page))
            end
        end
        check_cache(SIMILARITY_RANKINGS_CACHE, "Similarity", "--generate-similarity")
        check_cache(DIVERSITY_CACHE, "Diversity", "--generate-diversity")
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

    -- Report the pages-per-poem THIS run will actually generate, not the storage
    -- ceiling. The orchestrator worker generates #pages_config.pages pages per poem
    -- (one page by default); the old banner printed the 15-page storage cap
    -- unconditionally, which read as "generating 15 pages" when it generates 1.
    -- The cap is still shown, clearly labelled as a ceiling, for context.
    local pages_per_poem = pages_config.is_all
        and PAGINATION_CONFIG.max_pages_per_poem
        or (pages_config.pages and #pages_config.pages or 1)
    utils.log_info(string.format(
        "Similarity/diversity pagination: %d poems/page, %d page(s) per poem (storage ceiling: %d pages, %dGB)",
        PAGINATION_CONFIG.poems_per_page,
        pages_per_poem,
        PAGINATION_CONFIG.max_pages_per_poem,
        STORAGE_CONFIG.limit_gb))

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

    -- Issue 10-057 (Piece 1, wired): clamp the worker count to what fits in free RAM
    -- before spawning. After the cache cap (Fix B) the fixed cost is small, so on a
    -- roomy machine this is a no-op -- but it is the guard rail that keeps a big corpus
    -- or a small box out of swap, and it logs the estimate either way.
    if num_threads > 1 then
        local budget = require("memory-budgeter")
        local model = inference_config.get_selected_model()
        -- fixed: the two neighbour caches the orchestrator holds resident (file size x
        -- ~2.5 for the parsed Lua table) plus the ~12MB poems data already in RAM.
        local sim_file = utils.embeddings_dir(model) .. "/similarity_rankings_cache.json"
        local div_file = utils.embeddings_dir_disk(model) .. "/diversity_cache.json"
        local fixed = ((budget.file_size_bytes(sim_file) or 0)
            + (budget.file_size_bytes(div_file) or 0)) * 2.5 + 12e6
        -- per worker: an effil Lua state (~25MB) plus the one page it builds at a time.
        num_threads = budget.fit_threads({
            pool = "ram", fixed = fixed, per_thread = 30e6,
            want = num_threads, label = "HTML",
        })
    end

    -- Build ordered list of poem indices for batch distribution
    local poem_indices = {}
    for poem_index, _ in pairs(valid_poems) do
        table.insert(poem_indices, poem_index)
    end
    table.sort(poem_indices)  -- Ensure consistent ordering across runs

    -- Issue 10-036: Compute chrono_mapping before parallel/sequential split so both paths can use it
    local chronological_paginated = PAGINATION_CONFIG.chronological_paginated
    local chrono_poems_per_page_config = PAGINATION_CONFIG.chronological_poems_per_page or 500
    local effective_chrono_per_page = chrono_poems_per_page_config
    if chrono_per_page and type(chrono_per_page) == "number" and chrono_per_page > 0 then
        effective_chrono_per_page = chrono_per_page
        chronological_paginated = true
    end
    local chrono_mapping = compute_chronological_mapping(poems_data, chronological_paginated and effective_chrono_per_page or nil)

    -- Check if parallel processing is available and requested
    local use_parallel = num_threads > 1 and has_threading and effil

    if use_parallel then
        -- {{{ Parallel processing with effil threads (Issue 10-034: Orchestrator pattern)
        -- Main thread acts as cache server, sending 80KB work slices instead of workers loading 700MB
        utils.log_info(string.format("Using parallel processing with %d threads (orchestrator mode)", num_threads))

        -- Issue 10-034: Create channels for orchestrator communication
        -- Workers request work → main sends slices → workers report completion
        local work_request_channel = effil.channel()  -- Workers → Main: work requests + completions
        local work_response_channels = {}              -- Main → Worker[i]: work slices or shutdown
        for t = 1, num_threads do
            work_response_channels[t] = effil.channel()
        end

        -- Issue 10-034: Build work queue (all poem indices that need processing)
        local work_queue = {}
        for _, poem_index in ipairs(poem_indices) do
            table.insert(work_queue, poem_index)
        end
        local total_work = #work_queue

        -- Issue 10-036: chrono_mapping is now computed before parallel/sequential split
        -- (see Issue 9-003 Fix D for original rationale)

        -- Prepare shared config for threads (serializable data only)
        local thread_config = {
            dir = DIR,
            output_dir = output_dir,
            -- Issue 9-013: where the worker finds the image pseudo-poem manifest
            image_manifest_path = utils.embeddings_dir() .. "/image-manifest.json",
            pages_is_all = pages_config.is_all,
            pages_list = pages_config.pages,
            poems_per_page = PAGINATION_CONFIG.poems_per_page,
            generate_html_archives = PAGINATION_CONFIG.generate_html_archives,
            generate_txt_exports = PAGINATION_CONFIG.generate_txt_exports,
            -- Issue 9-003 Fix D: Full formatting data
            chrono_mapping = chrono_mapping,
            chrono_paginated = chronological_paginated,
            -- Issue 8-055: Pass layout constants to worker threads for consistency
            layout = {
                golden_poem_width = LAYOUT.GOLDEN_POEM_WIDTH or 84,
                regular_poem_width = LAYOUT.REGULAR_POEM_WIDTH or 82,
                text_content_width = LAYOUT.TEXT_CONTENT_WIDTH or 80,
                golden_left_junction = LAYOUT.GOLDEN_LEFT_JUNCTION_POS or 10,
                golden_right_junction = LAYOUT.GOLDEN_RIGHT_JUNCTION_POS or 71,
                regular_left_junction = LAYOUT.REGULAR_LEFT_JUNCTION_POS or 10,
                regular_right_junction = LAYOUT.REGULAR_RIGHT_JUNCTION_POS or 70
            }
        }

        -- Create and launch worker threads
        local threads = {}
        local start_time = os.time()

        -- Issue 10-034: Launch workers that request work from orchestrator
        for thread_id = 1, num_threads do
            -- effil.thread creates a new Lua state that runs the function
            -- Workers receive work slices via channels instead of loading full caches
            local thread_func = effil.thread(function(config, tid, request_channel, response_channel)
                -- Set up package paths in thread context
                package.path = config.dir .. "/libs/?.lua;" .. config.dir .. "/src/?.lua;" .. package.path

                -- Load required modules in thread context
                local t_utils = require('utils')
                local t_dkjson = require('dkjson')
                -- Issue 8-056: Shared text formatting module for whitespace preservation
                local t_text_formatter = require('text-formatter')
                -- Shared box/bar drawing (canonical geometry) so this worker copy
                -- can't drift from the main thread's bars. See poem-bars.lua.
                local t_poem_bars = require('poem-bars')
                -- Issue 9-013: fold ranked image pseudo-poems into this worker's
                -- poem list so it draws them instead of dropping unknown indices.
                local t_image_render = require('image-render')
                t_utils.init_assets_root({config.dir})

                -- Load data files (each thread loads independently - files are in disk cache)
                local poems_file = t_utils.asset_path("poems.json")
                local poems_data = t_utils.read_json_file(poems_file)
                if not poems_data then
                    error("Thread " .. tid .. ": Failed to load poems.json")
                end
                t_image_render.inject_pseudo_poems(poems_data,
                    t_image_render.load_manifest(config.image_manifest_path, t_utils.read_json_file))

                -- Build poem lookup by poem_index
                local poem_lookup = {}
                for i, poem in ipairs(poems_data.poems) do
                    if poem.poem_index then
                        poem_lookup[poem.poem_index] = poem
                    end
                end

                -- Issue 10-034: Caches NOT loaded here - orchestrator sends work slices
                -- This saves 700MB RAM per worker thread

                -- Load poem colors (small file: ~900KB, acceptable per-worker)
                local poem_colors_file = t_utils.embeddings_dir() .. "/poem_colors.json"
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

                -- {{{ Local helper: Check if poem is a boost (Issue 8-057)
                local function is_boost_poem(poem)
                    if poem.metadata and poem.metadata.is_boost then
                        return true
                    end
                    return false
                end
                -- }}}

                -- Issue 8-057: Boost color configuration for worker thread
                local BOOST_COLORS = {
                    arrow = "#dc3c3c",      -- Red: ◀═ and ─▶ arrows, [BOOST] label
                    outer_frame = "#3c78dc", -- Blue: ╔═╗║╚═╝ outer frame
                    inner_box = "#2aa198",   -- Teal: ┌─┐│└─┘ inner content box
                    content_text = "#c8b428" -- Yellow: boosted text content
                }

                -- Same shared boost-frame module the main thread uses; require()
                -- reloads it fresh in this isolated worker state (only live
                -- closures can't cross states, plain modules reload from disk).
                local t_boost_bars = require('boost-bars')
                t_boost_bars.configure(BOOST_COLORS)

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

                -- Issue 10-034: Convert similarity ranking (raw indices) to poem objects
                -- ranking_data is an array of poem indices received from orchestrator
                local function convert_similarity_ranking(ranking_data, source_poem_index)
                    if not ranking_data then return {} end
                    local result = {}
                    for i, neighbor_index in ipairs(ranking_data) do
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

                -- Issue 10-034: Convert diversity sequence (raw indices) to poem objects
                -- sequence_data is an array of poem indices received from orchestrator
                -- Issue 10-025: Skip anchor poem (GPU cache stores source poem as first entry)
                local function convert_diversity_sequence(sequence_data, source_poem_index)
                    if not sequence_data then return {} end
                    local result = {}
                    for step, neighbor_index in ipairs(sequence_data) do
                        if neighbor_index ~= source_poem_index then
                            local neighbor_poem = poem_by_index[neighbor_index]
                            if neighbor_poem then
                                table.insert(result, {
                                    id = neighbor_index,
                                    poem = neighbor_poem,
                                    step = step
                                })
                            end
                        end
                    end
                    return result
                end

                -- {{{ Issue 8-057: Boost formatting functions for worker thread

                -- Worker: apply complete boost formatting. All geometry lives in
                -- the shared boost-bars module (top/inner/content/nav/bottom +
                -- the asymmetric fill-frontier right edge). The worker only splits
                -- the pre-wrapped content into lines; txt_fmt is unused now that
                -- the module owns visible-width padding.
                local function worker_apply_boost_formatting(content, progress_percent, similar_link, different_link, chronological_link, txt_fmt)
                    local lines = {}
                    for line in (content .. "\n"):gmatch("(.-)\n") do
                        table.insert(lines, line)
                    end
                    local include_nav = (similar_link and different_link) and true or false
                    return t_boost_bars.format_boost(
                        lines, progress_percent, similar_link, different_link, chronological_link, include_nav)
                end
                -- }}} End Issue 8-057: Boost formatting functions

                -- Local helper: Format single poem with full formatting (Issue 9-003 Fix D)
                -- Includes progress bars, navigation box, and chronological page links
                -- Issue 8-044: Added golden poem formatting support
                -- Issue 8-057: Added boost formatting support
                local function format_poem_entry(poem, poem_colors_tbl, clr_config, chrono_map, chrono_paged)
                    -- Issue 9-013: a ranked IMAGE entry draws as an image box, not a poem.
                    if poem.is_image then
                        return t_image_render.format_image_entry(poem)
                    end
                    local poem_idx = poem.poem_index
                    local poem_color_data = poem_colors_tbl[poem_idx]
                    local semantic_color = poem_color_data and poem_color_data.color or "gray"
                    local hex_color = clr_config[semantic_color] or clr_config["gray"]
                    -- Hand the shared bar module this state's palette (idempotent).
                    t_poem_bars.configure(clr_config)

                    -- Issue 8-044: Check if this is a golden poem
                    local is_golden = is_golden_poem(poem)

                    -- Issue 8-057: Check if this is a boost and handle with special formatting
                    local is_boost = is_boost_poem(poem)

                    -- Get chronological position from mapping
                    local chrono_info = chrono_map[poem_idx] or {position = 1, page_number = 1, total_poems = 1, total_pages = 1, timeline_progress = 50}
                    -- Issue 8-045: Use timeline_progress (time-based) instead of position-based
                    -- Shows actual temporal position in the author's timeline, not just poem count
                    local progress_pct = chrono_info.timeline_progress or ((chrono_info.position / chrono_info.total_poems) * 100)

                    -- Calculate progress bar chars
                    -- Golden: 82 interior chars + 2 corners = 84 total
                    -- Regular: 83 chars total (no corners on top bar)
                    local total_bar_chars = is_golden and 82 or 83
                    local progress_chars = math.floor((progress_pct / 100) * total_bar_chars)
                    local remaining_chars = total_bar_chars - progress_chars

                    -- Top bar from the shared poem-bars module (canonical 83
                    -- regular / 84 golden). progress_chars above is still used to
                    -- progressively colour the regular nav corner boxes below.
                    local colored_progress = t_poem_bars.progress_dashes(
                        { percentage = progress_pct }, semantic_color, is_golden, "top", false).visual

                    -- Navigation links (absolute paths for local testing)
                    -- Issue 9-003 Fix: Use absolute file:// paths - helper script converts to production URLs
                    local base_path = ".."
                    local similar_link = string.format("<a href='%s/similar/%04d-01.html'>similar</a>", base_path, poem_idx)
                    local different_link = string.format("<a href='%s/different/%04d-01.html'>different</a>", base_path, poem_idx)
                    -- Issue 16-006: Use poem_index for simpler, machine-readable anchor format
                    -- Old format: "poem-fediverse-0042" (leaked category info)
                    -- New format: "poem-4625" (just the unique poem_index)
                    local anchor_id = string.format("poem-%d", poem.poem_index or 0)

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

                    -- Issue 8-057: Handle boost poems with special nested frame formatting
                    -- Boosts return early with their complete formatting (arrows, [BOOST] label, nested frames)
                    if is_boost then
                        local boost_content = poem.content or ""
                        -- Escape HTML in content
                        boost_content = boost_content:gsub("[%z\1-\8\11\12\14-\31]", ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")

                        -- Issue 10-037: Defensive fallback for blank boost content (worker thread)
                        -- If content is empty, display the original URI or diagnostic message
                        if boost_content == "" or boost_content:match("^%s*$") then
                            local original_uri = poem.metadata and poem.metadata.original_uri
                            if original_uri then
                                -- Escape HTML in URI
                                local safe_uri = original_uri:gsub("[%z\1-\8\11\12\14-\31]", ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
                                boost_content = "External post: " .. safe_uri
                            else
                                boost_content = "(Boost content unavailable)"
                            end
                        end

                        -- Issue 10-039: Make external boost URLs clickable (worker thread)
                        -- Pattern: "External post: https://..." -> wrap URL in anchor tag
                        local external_pattern = "^External post: (https?://[^%s]+)$"
                        local external_url = boost_content:match(external_pattern)
                        if external_url then
                            -- Wrap the URL across box lines instead of overflowing.
                            boost_content = t_text_formatter.wrap_external_url("External post: ", external_url, t_boost_bars.CONTENT_WIDTH)
                        else
                            -- Issue 10-041: Wrap long embedded content to fit the boost box.
                            -- Only wrap non-external-post content (external posts keep URLs intact)
                            local BOOST_CONTENT_WIDTH = t_boost_bars.CONTENT_WIDTH
                            local wrapped_lines = {}
                            for line in (boost_content .. "\n"):gmatch("(.-)\n") do
                                local wrapped = t_text_formatter.wrap_preserving_indent(line, BOOST_CONTENT_WIDTH)
                                for _, wrapped_line in ipairs(wrapped) do
                                    table.insert(wrapped_lines, wrapped_line)
                                end
                            end
                            boost_content = table.concat(wrapped_lines, "\n")
                        end

                        -- Calculate progress as decimal (0-1)
                        local progress_decimal = progress_pct / 100

                        -- Apply boost formatting with all frame elements
                        local boost_formatted = worker_apply_boost_formatting(
                            boost_content, progress_decimal,
                            similar_link, different_link, chrono_link,
                            t_text_formatter
                        )

                        -- Build output including any attached media
                        local output = { boost_formatted }

                        -- Handle media attachments for boosts (same logic as regular poems)
                        local media_base = ".."
                        local has_media = false
                        local media_atts = {}
                        if poem.attachments and #poem.attachments > 0 then
                            for _, att in ipairs(poem.attachments) do
                                local mt = att.media_type or ""
                                if mt:match("^image/") or mt:match("^audio/") or mt:match("^video/") then
                                    table.insert(media_atts, att)
                                    has_media = true
                                end
                            end
                        end

                        if has_media then
                            table.insert(output, "</pre>")
                            for _, att in ipairs(media_atts) do
                                local rpath = att.relative_path or ""
                                -- media_href: namespace art by source+subdir,
                                -- url-encode (this is the path that previously
                                -- emitted the raw broken "...TROUBLE-U-?...png"
                                -- link on the similarity pages); Mastodon stays flat.
                                local media_src = "../media/" .. media_href(rpath)
                                local media_type = att.media_type or "image/png"
                                if media_type:match("^image/") then
                                    local alt = att.description and att.description ~= "" and att.description or "Image attachment"
                                    if att.width and att.height then
                                        table.insert(output, string.format(
                                            '  <img src="%s" alt="%s" loading="lazy" width="%d" height="%d" style="display:block; max-width:min(100%%,800px); height:auto">',
                                            media_src, alt, att.width, att.height
                                        ))
                                    else
                                        table.insert(output, string.format(
                                            '  <img src="%s" alt="%s" loading="lazy" style="display:block; max-width:min(100%%,800px); height:auto">',
                                            media_src, alt
                                        ))
                                    end
                                elseif media_type:match("^audio/") then
                                    table.insert(output, string.format(
                                        '  <audio controls preload="metadata" style="display:block; max-width:100%%">\n' ..
                                        '    <source src="%s" type="%s">\n' ..
                                        '    Your browser does not support the audio element.\n' ..
                                        '  </audio>',
                                        media_src, media_type
                                    ))
                                elseif media_type:match("^video/") then
                                    if att.width and att.height then
                                        table.insert(output, string.format(
                                            '  <video controls preload="metadata" width="%d" height="%d" style="display:block; max-width:min(100%%,800px); height:auto">\n' ..
                                            '    <source src="%s" type="%s">\n' ..
                                            '    Your browser does not support the video element.\n' ..
                                            '  </video>',
                                            att.width, att.height, media_src, media_type
                                        ))
                                    else
                                        table.insert(output, string.format(
                                            '  <video controls preload="metadata" style="display:block; max-width:min(100%%,800px); height:auto">\n' ..
                                            '    <source src="%s" type="%s">\n' ..
                                            '    Your browser does not support the video element.\n' ..
                                            '  </video>',
                                            media_src, media_type
                                        ))
                                    end
                                end
                            end
                            table.insert(output, "<pre>")
                        end

                        return table.concat(output, "\n")
                    end

                    -- Standard formatting for golden and regular (non-boost) poems
                    -- Wrap content to 80 chars while preserving paragraph breaks
                    -- Also handle content warnings (CW: or content warning:)
                    local content = poem.content or ""

                    -- Issue 8-041: Escape HTML special characters in poem content
                    -- Prevents browser from interpreting poem content as HTML markup
                    -- (e.g., a poem containing "</pre>" would otherwise close the preformatted block)
                    -- Order: & first, then < and > (otherwise &lt; becomes &amp;lt;)
                    content = content:gsub("[%z\1-\8\11\12\14-\31]", ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")

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

                    -- Issue 8-056: Preserve whitespace for ALL categories
                    -- Poetry is artistic content - author's spacing must be respected
                    -- Use shared text-formatter module for consistent behavior with main thread
                    local content_lines = t_text_formatter.format_poem_content(main_content)
                    for _, line in ipairs(content_lines) do
                        table.insert(wrapped_lines, line)
                    end

                    -- Issue 8-044: Apply golden side borders to content lines
                    -- Golden poems get ║ (colored) on left and │ on right
                    -- Total width: ║ (1) + space (1) + 80 chars content + space (1) + │ (1) = 84 total
                    if is_golden then
                        local golden_lines = {}
                        local colored_wall = string.format('<font color="%s"><b>║</b></font>', hex_color)
                        -- Issue 8-055: Use config layout values instead of hardcoded 80
                        local CONTENT_WIDTH = config.layout and config.layout.text_content_width or 80

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
                            -- Issue 8-055: Also decode HTML entities for accurate width counting
                            -- e.g., &gt; is 4 bytes but displays as 1 character (>)
                            local visible_length = t_text_formatter.calculate_visible_width(content)

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
                    -- Nav top + line come from the shared poem-bars module so this
                    -- worker can't drift from the main thread (the whole point of
                    -- the de-dup). Golden nav box dashes are not progress-tinted,
                    -- which now matches the chronological (main-rendered) golden
                    -- poems exactly.
                    local nav_top, nav_mid
                    if is_golden then
                        nav_top = t_poem_bars.golden_corner_box_separator(hex_color, progress_chars)
                        nav_mid = t_poem_bars.golden_corner_box_nav_line(similar_link, different_link, chrono_link, hex_color, progress_chars)
                    else
                        nav_top = t_poem_bars.corner_box_top(progress_chars, hex_color)
                        nav_mid = t_poem_bars.corner_box_nav_line(similar_link, different_link, chrono_link, progress_chars, hex_color)
                    end

                    -- Bottom line: delegate to the shared poem-bars module so this
                    -- worker cannot drift from the main thread's canonical geometry.
                    -- The old inline copy used the 82-char CONTENT width as the BAR
                    -- width, so the bar ended one column short of the nav boxes (and
                    -- an earlier version produced 88-char bars with doubled ╧╧).
                    -- progress_dashes is correct for both regular (83) and golden
                    -- (84) and seats the junctions under the corner-box walls.
                    local bottom_line = t_poem_bars.progress_dashes(
                        { percentage = progress_pct }, semantic_color, is_golden, "bottom", true).visual

                    -- Build formatted output
                    local output = {}
                    table.insert(output, colored_progress)  -- Top progress bar (golden: 84 chars, regular: 83 chars)
                    table.insert(output, table.concat(wrapped_lines, "\n"))  -- Content with preserved newlines

                    -- Issue 8-040: Render attached images if present (from ActivityPub extraction)
                    -- Images appear after poem content, before navigation links
                    -- Must be inline since worker thread can't access main scope functions
                    local base_path = ".."

                    -- Issue 8-049: Check if we have any media to render (images, audio, video)
                    -- Issue 9-010: Media stays with their original post only (no associated_images rendering)
                    local has_any_media = false
                    local media_attachments = {}
                    if poem.attachments and #poem.attachments > 0 then
                        for _, att in ipairs(poem.attachments) do
                            local mt = att.media_type or ""
                            if mt:match("^image/") or mt:match("^audio/") or mt:match("^video/") then
                                table.insert(media_attachments, att)
                                has_any_media = true
                            end
                        end
                    end

                    -- If there are media attachments, close </pre>, render them, reopen <pre>
                    -- Issue 8-005 Fix: Media rendered outside <pre> for proper max-width behavior
                    -- display:block prevents side-by-side, max-width:min(100%,800px) caps width
                    if has_any_media then
                        table.insert(output, "</pre>")
                        for _, attachment in ipairs(media_attachments) do
                            -- Issue 8-048: Use flat output/media/ path structure
                            local relative_path = attachment.relative_path or ""
                            -- media_href: namespace art by source+subdir (collision-
                            -- safe) + url-encode; Mastodon hashes stay flat.
                            local media_src = base_path .. "/media/" .. media_href(relative_path)
                            local media_type = attachment.media_type or ""

                            if media_type:match("^image/") then
                                local alt_text = attachment.description or attachment.alt_text or "Image attachment"
                                -- Issue 8-053: Normalize newlines to spaces for clean HTML attributes
                                alt_text = alt_text:gsub("\n", " "):gsub("\r", "")
                                alt_text = alt_text:gsub('"', '&quot;')
                                -- Issue 8-053: title attribute provides mouse-over tooltip
                                local img_tag = string.format(
                                    '  <img src="%s" alt="%s" title="%s" loading="lazy" style="display:block; max-width:min(100%%,800px); height:auto"',
                                    media_src, alt_text, alt_text
                                )
                                if attachment.width and attachment.height then
                                    img_tag = img_tag .. string.format(' width="%d" height="%d"', attachment.width, attachment.height)
                                end
                                img_tag = img_tag .. '>'
                                table.insert(output, img_tag)

                            elseif media_type:match("^audio/") then
                                -- Issue 8-049: Audio playback support
                                local audio_tag = string.format(
                                    '  <audio controls preload="metadata" style="display:block; max-width:100%%">\n' ..
                                    '    <source src="%s" type="%s">\n' ..
                                    '    Your browser does not support the audio element.\n' ..
                                    '  </audio>',
                                    media_src, media_type
                                )
                                table.insert(output, audio_tag)

                            elseif media_type:match("^video/") then
                                -- Issue 8-049: Video playback support
                                local video_tag
                                if attachment.width and attachment.height then
                                    video_tag = string.format(
                                        '  <video controls preload="metadata" width="%d" height="%d" style="display:block; max-width:min(100%%,800px); height:auto">\n' ..
                                        '    <source src="%s" type="%s">\n' ..
                                        '    Your browser does not support the video element.\n' ..
                                        '  </video>',
                                        attachment.width, attachment.height, media_src, media_type
                                    )
                                else
                                    video_tag = string.format(
                                        '  <video controls preload="metadata" style="display:block; max-width:min(100%%,800px); height:auto">\n' ..
                                        '    <source src="%s" type="%s">\n' ..
                                        '    Your browser does not support the video element.\n' ..
                                        '  </video>',
                                        media_src, media_type
                                    )
                                end
                                table.insert(output, video_tag)
                            end
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
                    -- Issue 16-010: Added inline font style for Hack Nerd Font font-stack
                    local font_style = [[<style>body, pre { font-family: 'Hack Nerd Font', 'Hack', 'Fira Code', 'JetBrains Mono', 'Cascadia Code', 'Consolas', 'Monaco', 'Liberation Mono', 'Courier New', monospace; }</style>]]
                    local html_parts = {
                        '<!DOCTYPE html><html><head><meta charset="UTF-8">',
                        '<title>Poems by ' .. type_label .. ' to poem ' .. poem_idx_str .. ' (page ' .. page_num .. ')</title>',
                        font_style,
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
                            -- Issue 9-013: text+image posts get a direct "image.png"
                            -- link below their header (image entries are skipped --
                            -- their title already deep-links into the gallery).
                            if not entry_poem.is_image then
                                local img_link = t_image_render.text_image_link(entry_poem)
                                if img_link ~= "" then
                                    table.insert(html_parts, " " .. img_link .. "\n")
                                end
                            end
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

                -- Issue 10-034: Orchestrator request/response loop
                -- Workers request work, receive slices, generate pages, report completion
                local similarity_count = 0
                local diversity_count = 0
                local processed = 0

                while true do
                    -- Request work from orchestrator
                    request_channel:push({
                        type = "get_work",
                        worker_id = tid
                    })

                    -- Wait for response (blocks until data available)
                    local work = response_channel:pop()

                    if not work then
                        -- Channel closed or error
                        break
                    end

                    if work.type == "shutdown" then
                        -- No more work, exit loop
                        break
                    end

                    if work.type == "work" then
                        local poem_index = work.poem_index
                        local poem = poem_lookup[poem_index]

                        if poem then
                            -- Convert raw index arrays to poem objects using data from orchestrator
                            local similar_ranking = convert_similarity_ranking(work.similarity_ranking, poem_index)
                            local diverse_sequence = convert_diversity_sequence(work.diversity_sequence, poem_index)

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

                            -- Report completion to orchestrator
                            request_channel:push({
                                type = "done",
                                worker_id = tid,
                                poem_index = poem_index
                            })
                        end
                    end
                end

                return similarity_count, diversity_count, processed
            end)

            -- Launch thread with channels for orchestrator communication
            threads[thread_id] = thread_func(thread_config, thread_id, work_request_channel, work_response_channels[thread_id])
        end

        -- Issue 10-034: Orchestrator loop - serves work slices to workers
        -- Main thread holds caches, sends ~80KB slices instead of workers loading 700MB

        -- Track work state
        local work_queue_idx = 1           -- Next poem index to assign
        local completed_count = 0           -- Number of poems completed
        local workers_active = num_threads  -- Number of workers still running
        local workers_shutdown = {}         -- Track which workers have been told to shut down
        for t = 1, num_threads do
            workers_shutdown[t] = false
        end

        -- Get references to caches loaded in main thread (lines 3092-3096)
        -- DIVERSITY_CACHE and SIMILARITY_RANKINGS_CACHE are module-level variables
        local similarity_cache = SIMILARITY_RANKINGS_CACHE
        local diversity_cache = DIVERSITY_CACHE

        -- Progress tracking
        local last_progress_time = os.time()
        local progress_interval = 1  -- Update progress every 1 second

        -- Orchestrator main loop: process requests until all work done and all workers shut down
        while workers_active > 0 do
            -- Non-blocking receive with short timeout (100ms)
            local msg = work_request_channel:pop(100)

            if msg then
                if msg.type == "get_work" then
                    local worker_id = msg.worker_id

                    if work_queue_idx <= total_work then
                        -- Get next poem index from queue
                        local poem_index = work_queue[work_queue_idx]
                        work_queue_idx = work_queue_idx + 1

                        -- Extract work slice from caches (~80KB: similarity ranking + diversity sequence)
                        local similarity_ranking = similarity_cache.rankings[tostring(poem_index)]
                        local diversity_sequence = diversity_cache.sequences[tostring(poem_index)]

                        -- Send work slice to worker
                        work_response_channels[worker_id]:push({
                            type = "work",
                            poem_index = poem_index,
                            similarity_ranking = similarity_ranking,
                            diversity_sequence = diversity_sequence
                        })
                    else
                        -- No more work - tell worker to shut down
                        if not workers_shutdown[worker_id] then
                            work_response_channels[worker_id]:push({
                                type = "shutdown"
                            })
                            workers_shutdown[worker_id] = true
                            workers_active = workers_active - 1
                        end
                    end

                elseif msg.type == "done" then
                    -- Worker completed a poem
                    completed_count = completed_count + 1
                end
            end

            -- Update progress display periodically
            local now = os.time()
            if now - last_progress_time >= progress_interval then
                last_progress_time = now

                local elapsed = now - start_time
                local rate = elapsed > 0 and (completed_count / elapsed) or 0
                local remaining = total_work - completed_count
                local eta = rate > 0 and math.floor(remaining / rate) or 0
                local pct = (completed_count / total_work) * 100

                -- Show orchestrator progress as the shared bar. The rate, ETA,
                -- and remaining queue depth ride along as the suffix.
                local label = string.format("   [%d threads]", num_threads)
                local suffix = string.format("%.1f poems/sec | ETA: %ds | Queue: %d",
                    rate, eta, total_work - work_queue_idx + 1)
                progress.update(label, completed_count, total_work, suffix)
            end
        end

        -- Close the animated bar, then print a plain completion summary so it
        -- survives in logs (the bar itself is suppressed when piped/quiet).
        progress.finish()
        local elapsed = os.time() - start_time
        print(string.format("   [%d threads] Complete: %d poems in %ds (%.1f poems/sec)",
            num_threads, completed_count, elapsed, completed_count / math.max(elapsed, 1)))

        -- Wait for all threads to fully complete and collect results
        local total_similarity = 0
        local total_diversity = 0
        local total_processed = 0

        for tid, thread in pairs(threads) do
            -- Wait for thread completion (may already be done)
            local status = thread:wait()
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

            -- Animate one progress line; throttle sparser under --debug (verbose).
            local step = (progress.mode() == 2) and 100 or 25
            if progress_count % step == 0 then
                progress.update("   📄 HTML pages", progress_count, total_poems)
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
                pages_config.is_all and nil or pages_config.pages,  -- nil means "all pages"
                -- Issue 10-036: the mapping computed above must travel with the
                -- work, or the formatter guesses chronological page 01 for every
                -- poem. It was in scope here all along and simply not handed over.
                chrono_mapping,
                chronological_paginated
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
            -- Issue 10-036: Pass chrono_mapping for correct paginated chronological links
            if PAGINATION_CONFIG.generate_html_archives then
                local similar_archive = generate_similarity_html_archive(poem_data, similar_ranking,
                                                               string.format("%s/similar/%s-archive.html", output_dir, unique_id), chrono_mapping, chronological_paginated)
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
                pages_config.is_all and nil or pages_config.pages,  -- nil means "all pages"
                -- Issue 10-036: same mapping, same reason as the "similar" call above.
                chrono_mapping,
                chronological_paginated
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
            -- Issue 10-036: Pass chrono_mapping for correct paginated chronological links
            if PAGINATION_CONFIG.generate_html_archives then
                local diverse_archive = generate_diversity_html_archive(poem_data, diverse_sequence,
                                                              string.format("%s/different/%s-archive.html", output_dir, unique_id), chrono_mapping, chronological_paginated)
                if diverse_archive then
                    table.insert(results.html_archives, diverse_archive)
                end
            end
        end
        -- }}} End sequential processing
        progress.finish()
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
        local similarity_file = utils.embeddings_dir() .. "/similarity_matrix.json"
        local embeddings_file = utils.embeddings_dir() .. "/embeddings.json"
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
                        -- Issue 10-036: nil chrono_mapping here on purpose -- interactive test, not the
                        -- site build. The formatter warns once and falls back to
                        -- chronological/index.html, which exists in both modes.
                        local html = M.generate_flat_poem_list_html(poem_data, ranking, "similar", poem_id, nil)
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
                        -- Issue 10-036: nil chrono_mapping here on purpose -- interactive test, not the
                        -- site build. The formatter warns once and falls back to
                        -- chronological/index.html, which exists in both modes.
                        local html = M.generate_flat_poem_list_html(poem_data, sequence, "different", poem_id, nil)
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
