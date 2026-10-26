#!/usr/bin/env lua

-- flat-html-generator.lua: Stage 9 -- every page of the site.
--
-- WHAT IT DOES (for a CEO): draws the site from the poems and the caches the
-- earlier stages made: each poem's similar and different pages, the
-- chronological pages, the poems' plain-text exports and the word pages,
-- all as jobs for a pool of worker threads (src/poem-entry.lua draws each
-- poem), plus the explore pages. main.lua --html-only calls it in a build.
--
-- Usage: luajit src/flat-html-generator.lua [DIR] [-I]
--   DIR  project folder (default below); -I  ask before each step

-- --help: print the header above and exit, when run as a program (libs/script-help.lua)
dofile((debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./") .. "../libs/script-help.lua").handle_if_run(arg, debug.getinfo(1, "S").source:sub(2))

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
-- Issue 8-056: Shared text formatting module for whitespace preservation
local text_formatter = require("text-formatter")
-- Shared in-place progress bar (same look + TTY/--debug rules as the GPU stages)
local progress = require("progress-display")
-- Issue 9-013: render ranked image entries (pseudo-poems) as image boxes
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

-- Load effil, the threading library the page workers run on.  Where it lives
-- and how it is loaded is decided in libs/effil-loader.lua, shared with
-- run.sh's pre-flight gate (issue 10-069) so the gate tests the same file.
-- A failed load is remembered, not fatal here: a run with --threads 1 does not
-- need effil at all.  A run that asked for threads and cannot have them stops
-- where num_threads is known (issue 8-058).
local effil_loader = require("effil-loader")
local effil, effil_load_error = effil_loader.try_load()
local has_threading = effil ~= nil


local M = {}


-- {{{ COLOR_CONFIG -- the site's one progress-bar palette
-- Derived from config.lua's semantic_colors rather than restated, so the hex a
-- bar is drawn in and the hex the colour is DEFINED as cannot drift apart.
--
-- It is also exported (below), because the word-page generator kept its own
-- palette and that palette was wrong in a way nobody could see: it listed
-- red/orange/yellow/green/cyan/blue/indigo/violet/gray -- names from a generic
-- spectrum, not the seven semantic colour names this project actually assigns.
-- "purple" was absent, so every purple poem fell through to a hardcoded #888888
-- that is not even this palette's gray. Purple is the LARGEST bucket in the
-- stored distribution (17.2% of the corpus), so roughly one poem in six on every
-- word page was rendering in an off-palette grey, and the rest were rendering in
-- a different set of hexes from the chronological and similar/different pages.
--
-- One table, read from config, shared by every renderer.
local COLOR_CONFIG = {}
do
    local semantic = unified_config.semantic_colors
    if not semantic then
        error("config.lua is missing semantic_colors -- there is no palette to draw bars with")
    end
    for name, spec in pairs(semantic) do
        -- Each entry is { rgb = {...}, hex = "#rrggbb", name = "..." }. The hex is
        -- what the renderers want; a missing one is a config error, not something
        -- to paper over with a default, because a silently substituted colour is
        -- indistinguishable from a correctly-assigned one.
        if type(spec) ~= "table" or not spec.hex then
            error(string.format("config.lua semantic_colors.%s has no hex value", tostring(name)))
        end
        COLOR_CONFIG[name] = spec.hex
    end
end
-- Exported so the word-page generator draws from the same table (see above).
M.COLOR_CONFIG = COLOR_CONFIG
-- }}}

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
-- Exported so the word-page generator can dress the same frame in the same
-- colours without keeping a second copy of the palette. It renders boosts too,
-- and a private copy here is exactly how the earlier three drifted apart.
M.BOOST_COLOR_CONFIG = BOOST_COLOR_CONFIG

-- {{{ Issue 16-010: Monospace font enforcement
-- The font is now SHIPPED, not merely named. A CSS font-stack was enough on a
-- desktop where one of those faces is installed and nothing on a phone, where
-- none of them are: the generic monospace Android falls back to contains none of
-- the twenty box-drawing characters this layout is built from, so the browser
-- substituted them one glyph at a time from a proportional font and every frame
-- sheared. See src/page-head.lua and fonts/LICENSE-Hack.md.
--
-- The page-specific centering rules stay here; the font, viewport and text-size
-- rules come from the shared module so all four generators cannot disagree.
local page_head = require("page-head")

-- The one bar-and-box drawer, used by the page workers AND (since 2026-10-07,
-- Issue 8-058) by the main thread's chronological pages, whose own drifted copy
-- was removed.
local poem_bars_shared = require("poem-bars")
-- The shared drawer takes the palette from its host, once per Lua state. The
-- main thread now draws every bar and box through it (Issue 8-058), so it
-- needs the same table the workers hand theirs.
poem_bars_shared.configure(COLOR_CONFIG,
    (unified_config.layout or error("config.lua has no layout section")).text_content_width
        or error("config.lua layout.text_content_width is missing"))

-- {{{ POEM_PAGE_CSS
-- True page-centering for the poem column. The old <table align="center">
-- shrink-wrapped to its WIDEST line -- and an attached image (up to 800px) is
-- wider than the ~84-char text frame, so the cell stretched and the frames
-- hugged the left of that wide cell, landing the whole column left-of-center.
-- Fix: the cell centers its children, each <pre> is an inline-block that
-- centers as a block (text stays left-aligned inside), and media centers via
-- auto margins. Now a vertical line down the page bisects every poem AND image,
-- regardless of how wide any single image is.
-- Every <pre> is the grid's full width (page_head.frame_columns, in cells),
-- so blocks split around a picture all centre the same and their frames
-- line up; a block only as wide as its widest line used to shift.
local POEM_PAGE_CSS = [[
td { text-align: center; }
pre { display: inline-block; text-align: left; margin: 0 auto; width: ]] .. page_head.frame_columns() .. [[ch; }
img, video, audio { margin-left: auto; margin-right: auto; }]]
-- }}}

-- Poem pages all live one directory below the site root (output/similar/,
-- output/different/, output/chronological/), so the route back to the fonts is
-- always "..". A page emitted at the root must build its own head with ".".
--
-- This carries the viewport declaration as well as the stylesheet, because the
-- two are useless apart: shipping a font that renders the grid correctly does
-- nothing if the phone is still laying the page out for a 980-pixel screen and
-- then shrinking the result. Every template below drops this in immediately
-- after its <title>, so adding it in one place adds it to all of them.
local PAGE_HEAD_BLOCK = page_head.viewport_meta() .. "\n"
    .. page_head.style_block("..", POEM_PAGE_CSS)

-- The same block, safe to splice INTO a string.format template.  The stylesheet
-- says "text-size-adjust: 100%;", and string.format reads "%;" as a broken
-- placeholder and throws -- so every template that concatenated the block into
-- itself before formatting crashed (the single-threaded similar/different
-- pages, the unpaginated chronological page, the chronological redirect).
-- Doubling each % makes format print it as one.  Where the block is passed as
-- a format ARGUMENT (a %s value) the plain PAGE_HEAD_BLOCK is right: arguments
-- are not parsed for placeholders.
local PAGE_HEAD_BLOCK_IN_TEMPLATE = PAGE_HEAD_BLOCK:gsub("%%", "%%%%")
-- }}}

-- Page and storage settings. Every value comes from config.lua's `pagination`
-- and `storage` sections (filled by load_pagination_config below, at load).
-- The owner's rule (2026-10-04, Issue 10-065a): "the only place we should have
-- 'default' values is config.lua. Never in the code itself." These two tables
-- used to start out holding numbers of their own (100 poems per page, 500 per
-- chronological page, a 45 GB limit...) that config.lua then overrode; a
-- setting missing from config.lua silently fell back to the number here. Now a
-- missing setting is an error naming it.
--   PAGINATION_CONFIG fields: poems_per_page, minimum_pages,
--     page_number_padding (numbers); generate_txt_exports,
--     generate_html_archives, chronological_paginated (true/false);
--     chronological_poems_per_page (number); and max_pages_per_poem (number),
--     which is NOT a setting: compute_storage_max_pages works it out each build
--     from the storage limit and the last build's page sizes. It stays unset
--     until then, and anything that needs it before then is an error (a test
--     sets it directly).
--   STORAGE_CONFIG fields: limit_gb, reserved_for_maze_gb, reserved_headroom_gb
--     (numbers, gigabytes).
-- See Issue 8-020 for the hybrid pagination strategy (the storage quota).
local PAGINATION_CONFIG = {}
local STORAGE_CONFIG = {}

-- The settings each section must provide (Lua table of section -> list of names)
local REQUIRED_SETTINGS = {
    pagination = { "poems_per_page", "minimum_pages", "page_number_padding",
        "generate_txt_exports", "generate_html_archives",
        "chronological_paginated", "chronological_poems_per_page" },
    storage = { "limit_gb", "reserved_for_maze_gb", "reserved_headroom_gb" },
}

-- The text column's width, from config.lua layout.text_content_width: a
-- poem's line is at most this many characters, and src/poem-bars.lua draws
-- every frame from it (a wall, a space, the text, a space, a wall). The box
-- widths and junction columns that used to sit here (and in config.lua) were
-- never what the pages were drawn with, and disagreed with them (owner's
-- rule, 2026-10-25).
local LAYOUT = {
    TEXT_CONTENT_WIDTH = (unified_config.layout or error("config.lua has no layout section")).text_content_width
        or error("config.lua layout.text_content_width is missing"),
}

-- The one poem drawer (Issue 8-058): the chronological pages drawn here and
-- the similar/different pages drawn by the workers both draw each poem
-- through it. Configured with the same palettes and text width the workers
-- are handed, so the two cannot disagree.
local poem_entry = require("poem-entry")
-- the chronological pages' frame, also loaded by each worker (Issue 8-058)
local chronological_page = require("chronological-page")
poem_entry.configure({
    palette = COLOR_CONFIG,
    boost_palette = BOOST_COLOR_CONFIG,
    text_width = LAYOUT.TEXT_CONTENT_WIDTH,
})

-- Diversity cache (pre-computed GPU sequences for fast HTML generation)
-- Loaded from assets/embeddings/embeddinggemma_latest/diversity_cache.json
local DIVERSITY_CACHE = nil

-- Similarity rankings cache (pre-sorted similarity rankings for fast HTML generation)
-- Loaded from assets/embeddings/embeddinggemma_latest/similarity_rankings_cache.json
local SIMILARITY_RANKINGS_CACHE = nil

-- {{{ function M.use_similarity_rankings_for_tests
-- Hands the module a rankings table directly ({ rankings = { ["<poem_index>"] =
-- { neighbour poem_index, ... } } }), so a test can build pages from a few
-- made-up poems without the real cache file.  The site build never calls it.
function M.use_similarity_rankings_for_tests(cache_table)
    SIMILARITY_RANKINGS_CACHE = cache_table
end
-- }}}

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
    -- Before 2026-10-21 this cache held GPU positions (0 .. N-1) where the
    -- pages read poem numbers, so every "different" page showed the next
    -- poem's walk shifted by one (Issue 8-019). A cache written since says
    -- so in its metadata; an older one is refused rather than misread.
    if not (cache_data.metadata and cache_data.metadata.numbering == "poem_index") then
        error(string.format([[
Diversity cache %s holds GPU positions, not poem numbers (written before
2026-10-21), so every "different" list would be off by one.
Regenerate it: ./run.sh --generate-diversity (or a --force build).]], cache_file))
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

-- {{{ local function flatten_media_files
-- Issue 8-048: Copy every configured image into output/media/ for easy deploy.
-- TWO layouts, by species (kept in lockstep with media_href in src/poem-entry.lua):
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
            -- src/poem-entry.lua exactly, or the <img src> points at the wrong file):
            --   * art sources (path .../input/images/<source>): keep
            --     <source>/<subpath>, so two files that share a basename in
            --     different subdirs (e.g. my-art/x.png and my-art/game-design/x.png)
            --     stay distinct instead of one silently overwriting the other.
            --   * everything else (Mastodon media, content-addressed hashes):
            --     flatten to the bare basename -- already unique, and this
            --     collapses the ~7-level Mastodon nesting.
            -- No leading-^ anchor: dir.path is absolute (see above), so we match the
            -- "input/images/<rest>" tail wherever it appears -- the same tail
            -- media_href() in poem-entry extracts, keeping the two layouts identical.
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

    -- Copy every required setting from config.lua, noting each one missing so
    -- they can all be reported at once (one run tells the whole fix).
    local targets = { pagination = PAGINATION_CONFIG, storage = STORAGE_CONFIG }
    local missing = {}
    for section, names in pairs(REQUIRED_SETTINGS) do
        -- every missing setting is named in the one error below, not just the first;
        -- optional: so an absent section is read as empty here
        local source = unified_config[section] or {}
        for _, name in ipairs(names) do
            if source[name] == nil then
                missing[#missing + 1] = section .. "." .. name
            else
                targets[section][name] = source[name]
            end
        end
    end
    if #missing > 0 then
        table.sort(missing)
        error("config.lua is missing these settings the page builder needs: "
            .. table.concat(missing, ", ")
            .. ". Defaults live only in config.lua (Issue 10-065a); add them there.")
    end

    pagination_config_loaded = true
    return PAGINATION_CONFIG
end
-- }}}

-- Loaded as soon as this file is: several readers below look at these settings
-- without loading them first, and used to see the code's own numbers when they
-- did. Loading here means every reader sees config.lua's, and a config.lua that
-- lacks one stops the program at once, before any work.
load_pagination_config()

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
--   "N"               → N pages per poem: pages 1 through N, e.g. "3" → {1,2,3}
--
-- A bare number is a COUNT, the same as stages 7 and 8 read it and as run.sh's
-- help says ("pages generated per poem"). It briefly meant "only page N",
-- which made "--pages 3" write nothing but the -03 file for every poem while
-- every link on the site pointed at -01: 1.3 million broken links in one build.
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

    -- A count: "3" → {1,2,3}
    local count = tonumber(pages_spec)
    if count then
        if count < 1 or count ~= math.floor(count) then
            error(string.format("Invalid --pages count: '%s' (a whole number of pages, 1 or more)", pages_spec))
        end
        local pages = {}
        for i = 1, count do
            pages[i] = i
        end
        return {pages = pages, is_all = false}
    end

    -- Anything else is refused. Ranges ("2-5", exactly those pages) were
    -- removed 2026-10-07: never used, and a bare number is a count.
    error(string.format("Invalid --pages value: '%s'. Expected a number of pages per poem (3) or all", pages_spec))
end
-- Exposed so src/flat-html-generator.pages-count.test.lua can pin what a
-- --pages value writes, without building a site.
M.parse_pages_specification = parse_pages_specification
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

    -- No colours, no export: the page workers stop the same way. (Until
    -- 2026-10-21 this drew from seven made-up colours instead, so a missing
    -- file gave a text export that looked coloured and was not.)
    if not (poem_colors_data and poem_colors_data.poem_colors) then
        error("no poem colours in " .. poem_colors_file)
    end
    cached_poem_colors = poem_colors_data.poem_colors
    return cached_poem_colors
end
-- }}}

-- A poem's date, as a Unix time, from the one module that reads dates
-- (src/poem-dates.lua): the extractor numbers poems by it (Issue 8-019), the
-- chronological pages order them by it.
local poem_dates = require("poem-dates")
local extract_post_date_from_poem = poem_dates.timestamp

-- {{{ function sort_poems_chronologically_by_dates
local function sort_poems_chronologically_by_dates(poems_data)
    local sorted_poems = {}
    
    -- Extract all poems with temporal sorting data
    for i, poem in ipairs(poems_data.poems) do
        if poem.id then
            local post_timestamp = extract_post_date_from_poem(poem)
            -- Issue 8-045: a poem with no date has no place on the timeline;
            -- the build stops rather than invent one.  run.sh's pre-flight
            -- gate (10-069) checks every poem before any stage runs.
            if not post_timestamp then
                error(string.format("poem %s (%s, id %s) has no date: no creation_date, "
                    .. "no date in its first line, no file to read one from",
                    tostring(poem.poem_index), tostring(poem.category), tostring(poem.id)))
            end
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
            -- Issue 8-045: Calculate timeline progress as percentage of time elapsed.
            -- Every entry has a timestamp: the sort refuses poems without one.
            local poem_timestamp = poem_info.timestamp
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

-- {{{ local function worker_config()
-- What every page worker is handed when it starts (plain values only: a worker
-- is its own Lua state). Callers add the fields their jobs need.
--   dir, output_dir      : strings, the project and the site folder
--   image_manifest_path  : string, the picture pseudo-poem manifest (Issue 9-013)
--   embeddings_dir       : string, the selected model's folder (poem colours)
--   palette, boost_palette : the colour tables from config.lua (Issue 8-058)
--   layout               : the widths the drawer needs
--   page_head            : string, the shared <head> lines
local function worker_config(output_dir)
    return {
        dir = DIR,
        output_dir = output_dir,
        image_manifest_path = utils.embeddings_dir() .. "/image-manifest.json",
        -- the selected model's folder, named here because a worker cannot
        -- see which model this program was told to use
        embeddings_dir = utils.embeddings_dir(),
        palette = COLOR_CONFIG,
        boost_palette = BOOST_COLOR_CONFIG,
        layout = { text_content_width = LAYOUT.TEXT_CONTENT_WIDTH },
        page_head = PAGE_HEAD_BLOCK,
    }
end
-- }}}

-- {{{ local function run_page_workers()
-- Builds pages on a pool of worker threads (Issue 10-034's orchestrator,
-- shared by every page type since Issue 8-058). This program keeps the job
-- list and the big neighbour caches; each worker asks for a job, gets just
-- what that job needs, writes its pages and asks again.
-- num_threads : number of workers, 1 or more (one thread is one worker: the
--               single-threaded builder, a drifted copy, is gone)
-- config      : table from worker_config(), plus job-specific fields
-- jobs        : list of
--   { kind = "poems", poem_index = n }  -- that poem's similar + different pages
--   { kind = "chrono_page", page_num = n, total_pages = n, total_poems = n,
--     entries = { { poem = <a poem from the caller's poems>, progress_pct = number }, ... } }
--   { kind = "word_page", word = string, header_color = "#rrggbb", centre_link = string,
--     entries = { { poem = <a poem from the caller's poems>, progress_pct = number, chrono_file = "03.html" }, ... } }
--     -- one word-cloud word's page (Issue 10-035); the poems are already
--     -- chosen and ordered by src/generate-word-pages.lua, and carried in
--     -- the job as the chronological jobs carry theirs (this worker's own
--     -- copy has the gallery pictures folded in, which draws an image-only
--     -- post as a picture box)
-- returns     : { similar = n, different = n, poems = n, chrono_pages = n, text_files = n, word_pages = n }
local function run_page_workers(num_threads, config, jobs)
    if not has_threading then
        -- Errors, not fallbacks (owner, 2026-09-22): there is no other builder
        error("the threading library (effil) did not load: " .. tostring(effil_load_error))
    end
    local total_work = #jobs
    utils.log_info(string.format("Building pages on %d worker thread(s): %d job(s)", num_threads, total_work))
    -- Workers -> this program: requests and completions; this program ->
    -- worker i: its next job, or shutdown
    local work_request_channel = effil.channel()
    local work_response_channels = {}
    for t = 1, num_threads do
        work_response_channels[t] = effil.channel()
    end

    local threads = {}
    local start_time = os.time()
    for thread_id = 1, num_threads do
        local thread_func = effil.thread(function(config, tid, request_channel, response_channel)
            -- Set up package paths in thread context
            package.path = config.dir .. "/libs/?.lua;" .. config.dir .. "/src/?.lua;" .. package.path

            -- Load required modules in thread context
            local t_utils = require('utils')
            local t_dkjson = require('dkjson')
            -- Issue 8-056: Shared text formatting module for whitespace preservation
            local t_text_formatter = require('text-formatter')
            -- The one poem drawer every page type uses (Issue 8-058). It
            -- loads the bar, boost and text modules itself; the palette
            -- and widths come from the main program in config, so this
            -- worker draws with exactly the colours config.lua holds.
            -- config arrives as effil's shared tables, not Lua tables;
            -- effil.dump copies one into a plain table the drawer can read.
            local t_poem_entry = require('poem-entry')
            local t_effil = require('effil')
            t_poem_entry.configure({
                palette = t_effil.dump(config.palette),
                boost_palette = t_effil.dump(config.boost_palette),
                text_width = config.layout.text_content_width,
            })
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

            -- Load poem colors (small file: ~900KB, acceptable per-worker).
            -- From the folder the main program names (config.embeddings_dir):
            -- a worker is its own Lua state and does not see which model the
            -- main program was told to use, so resolving the folder here could
            -- pick a different model's colours (found by the 8-058 render).
            -- A missing file stops the worker: every poem would draw grey.
            local poem_colors_file = config.embeddings_dir .. "/poem_colors.json"
            local poem_colors_data = t_utils.read_json_file(poem_colors_file)
            if not (poem_colors_data and poem_colors_data.poem_colors) then
                error("Thread " .. tid .. ": no poem colours in " .. poem_colors_file)
            end
            local poem_colors = poem_colors_data.poem_colors


            -- The ranked pages and their text exports, drawn by one module
            -- (src/ranked-page.lua) that the tests call too (Issue 8-058).
            local t_ranked_page = require('ranked-page')
            local t_effil_for_ctx = require('effil')
            -- {{{ local function ranked_ctx()
            -- What every ranked page needs about the wider collection (see the
            -- module's header for each field). Built on the first poem job:
            -- a pool that only builds chronological pages is never handed the
            -- ranking settings.
            local page_ctx = false
            local function ranked_ctx()
                if not page_ctx then
                    page_ctx = {
                        colors = poem_colors,
                        chrono_map = t_effil_for_ctx.dump(config.chrono_mapping),
                        chrono_paged = config.chrono_paginated,
                        poems_per_page = config.poems_per_page,
                        head_block = PAGE_HEAD_BLOCK,
                    }
                end
                return page_ctx
            end
            -- }}}

            -- {{{ local function write_file()
            local function write_file(filename, text)
                os.execute('mkdir -p "' .. filename:match("(.*/)") .. '"')
                local f = io.open(filename, "w")
                if not f then error("could not write " .. filename) end
                f:write(text)
                f:close()
            end
            -- }}}

            -- Messages arrive as effil's shared tables; effil.dump makes a plain
            -- Lua table of one, so the job can be read like any other table.
            local t_effil = require('effil')
            -- The chronological pages' frame (Issue 8-058): head, navigation,
            -- the line above each poem, file names.
            local t_chrono_page = require('chronological-page')
            -- Every address by the poem's source key (Issue 8-019).
            local t_poem_address = require('poem-address')

            -- {{{ local function build_chrono_page()
            -- One chronological page: each poem's header line and entry, in
            -- the order given, inside the page frame. No chronological link on a
            -- chronological page (Issue 9-003 Fix C).
            -- The job carries its poems, exactly as the caller loaded them: a
            -- caller may have filtered poems.json (regenerate-clean-site drops
            -- PDF-damaged poems) or built its own (the tests), and this
            -- worker's own copy is the file on disk, with gallery pictures
            -- folded in for the ranked lists (Issue 9-013).
            local function build_chrono_page(work)
                local parts = {}
                for _, e in ipairs(work.entries) do
                    local poem = e.poem
                    local color_data = poem_colors[poem.poem_index]
                    parts[#parts + 1] = t_chrono_page.entry_header(poem)
                    parts[#parts + 1] = t_poem_entry.format_entry(poem, {
                        color_name = color_data and color_data.color or "gray",
                        progress_pct = e.progress_pct,
                        similar_link = t_poem_address.list_link(poem, "similar"),
                        different_link = t_poem_address.list_link(poem, "different"),
                        chrono_link = false,
                    })
                    parts[#parts + 1] = "\n\n"
                end
                -- Issue 8-013: the whole view as one text file, offered on
                -- every page (written by the main program, chronological.txt)
                parts[#parts + 1] = string.format(
                    " download every poem as text: <a href='../chronological.txt'>chronological.txt</a> (%d poems)\n",
                    work.total_poems)
                local html = t_chrono_page.page_html(work.page_num, work.total_pages,
                    config.page_head, table.concat(parts))
                local dir_path = config.output_dir .. "/chronological"
                os.execute('mkdir -p "' .. dir_path .. '"')
                local file = dir_path .. "/" .. t_chrono_page.file_name(work.page_num, work.total_pages)
                local f = io.open(file, "w")
                if not f then error("could not write " .. file) end
                f:write(html)
                f:close()
            end
            -- }}}

            -- The word pages' frame and entry (Issue 10-035).
            local t_word_page = require('word-page')


            -- {{{ local function build_word_page()
            -- One word's page: its poems, in the order given, each with its
            -- file line and entry, inside the word-page frame. The poems come
            -- in the job, as the caller loaded them (see run_page_workers).
            local function build_word_page(work)
                local parts = {}
                for _, e in ipairs(work.entries) do
                    local poem = e.poem
                    local color_data = poem_colors[poem.poem_index]
                    parts[#parts + 1] = t_word_page.entry(poem,
                        color_data and color_data.color or "gray", e.progress_pct, e.chrono_file)
                    parts[#parts + 1] = "\n"
                end
                write_file(config.output_dir .. "/wordcloud/" .. t_word_page.file_name(work.word),
                    t_word_page.page_html(work.word, work.header_color, work.centre_link,
                        #work.entries, table.concat(parts)))
            end
            -- }}}

            -- {{{ local function build_poem_pages()
            -- One poem's similar and different pages, and their text exports
            -- when exports are on (config.lua pagination.generate_txt_exports,
            -- Issue 8-013), from the ranked lists this program sends (about
            -- 80 KB; Issue 10-034).
            local function build_poem_pages(work, counts)
                local poem_index = work.poem_index
                local poem = poem_lookup[poem_index]
                if not poem then
                    error("poem " .. tostring(poem_index) .. " is not in poems.json")
                end
                -- {{{ local function build_list()
                local function build_list(ranking, page_type)
                    -- a poem with no ranking: the caches were made without it
                    -- (it arrived after the embeddings); stop rather than write
                    -- a poem whose pages every other page links to but nobody wrote
                    if not ranking then
                        error(string.format("poem %d has no %s ranking in the caches", poem_index, page_type))
                    end
                    local list = t_ranked_page.ranked_list(ranking, poem_index, poem_lookup)
                    local pages, count, total_pages = t_ranked_page.plan(list,
                        config.pages_is_all and "all" or config.pages_list,
                        config.poems_per_page, config.max_pages_per_poem)
                    local download = config.txt_exports
                        and { file = t_poem_address.text_file(poem), count = count } or false
                    local written = 0
                    for _, page_num in ipairs(pages) do
                        local html = t_ranked_page.page_html(poem, list, page_type, page_num,
                            total_pages, download, ranked_ctx())
                        -- a page past the end of the list is not written
                        if html then
                            write_file(string.format("%s/%s/%s", config.output_dir,
                                page_type, t_poem_address.page_file(poem, page_num)), html)
                            written = written + 1
                        end
                    end
                    if config.txt_exports and count > 0 then
                        write_file(string.format("%s/%s/%s", config.output_dir, page_type, t_poem_address.text_file(poem)),
                            t_ranked_page.text_export(poem, list, page_type, count, ranked_ctx()))
                        counts.text_files = counts.text_files + 1
                    end
                    return written
                end
                -- }}}
                counts.similar = counts.similar + build_list(work.similarity_ranking, "similar")
                counts.different = counts.different + build_list(work.diversity_sequence, "different")
                counts.poems = counts.poems + 1
            end
            -- }}}

            -- ask for a job, do it, report it, until told to stop
            local counts = { similar = 0, different = 0, poems = 0, chrono_pages = 0, text_files = 0, word_pages = 0 }
            while true do
                request_channel:push({ type = "get_work", worker_id = tid })
                local work = response_channel:pop()
                -- {{{ dispatch on the kind of job
                if not work or work.type == "shutdown" then
                    -- no job: the channel closed, or all work is handed out
                    break
                end
                work = t_effil.dump(work)
                if work.type == "poems" then
                    build_poem_pages(work, counts)
                elseif work.type == "chrono_page" then
                    build_chrono_page(work)
                    counts.chrono_pages = counts.chrono_pages + 1
                elseif work.type == "word_page" then
                    build_word_page(work)
                    counts.word_pages = counts.word_pages + 1
                else
                    error("unknown job type: " .. tostring(work.type))
                end
                -- }}}
                request_channel:push({ type = "done", worker_id = tid })
            end
            return counts.similar, counts.different, counts.poems, counts.chrono_pages, counts.text_files, counts.word_pages
        end)
        threads[thread_id] = thread_func(config, thread_id, work_request_channel, work_response_channels[thread_id])
    end

    -- {{{ hand out jobs until every worker has been told to stop
    local work_queue_idx = 1
    local completed_count = 0
    local workers_active = num_threads
    local workers_shutdown = {}
    local last_progress_time = os.time()
    while workers_active > 0 do
        local msg = work_request_channel:pop(100)   -- wait up to 100 ms
        if msg and msg.type == "get_work" then
            local worker_id = msg.worker_id
            if work_queue_idx <= total_work then
                local job = jobs[work_queue_idx]
                work_queue_idx = work_queue_idx + 1
                -- {{{ build the message for this job
                if job.kind == "poems" then
                    -- the poem's two ranked lists, sliced from the caches here
                    local key = tostring(job.poem_index)
                    work_response_channels[worker_id]:push({
                        type = "poems",
                        poem_index = job.poem_index,
                        similarity_ranking = SIMILARITY_RANKINGS_CACHE.rankings[key],
                        diversity_sequence = DIVERSITY_CACHE.sequences[key],
                    })
                elseif job.kind == "chrono_page" then
                    work_response_channels[worker_id]:push({
                        type = "chrono_page",
                        page_num = job.page_num,
                        total_pages = job.total_pages,
                        total_poems = job.total_poems,
                        entries = job.entries,
                    })
                elseif job.kind == "word_page" then
                    work_response_channels[worker_id]:push({
                        type = "word_page",
                        word = job.word,
                        header_color = job.header_color,
                        centre_link = job.centre_link,
                        entries = job.entries,
                    })
                else
                    error("unknown job kind: " .. tostring(job.kind))
                end
                -- }}}
            elseif not workers_shutdown[worker_id] then
                -- no jobs left: this worker stops
                work_response_channels[worker_id]:push({ type = "shutdown" })
                workers_shutdown[worker_id] = true
                workers_active = workers_active - 1
            end
        elseif msg and msg.type == "done" then
            completed_count = completed_count + 1
        end

        local now = os.time()
        if now - last_progress_time >= 1 then
            last_progress_time = now
            -- A worker that raised an error stops asking for work, and this
            -- loop would wait for it forever. Once a second, look for a failed
            -- worker and stop the run with its error (Issue 8-045).
            for tid, worker in pairs(threads) do
                local status, worker_err, worker_stack = worker:status()
                if status == "failed" then
                    progress.finish()
                    utils.log_error(string.format("HTML worker %d failed: %s", tid, tostring(worker_err)))
                    if worker_stack then io.stderr:write(tostring(worker_stack), "\n") end
                    os.exit(1)
                end
            end
            local elapsed = now - start_time
            local rate = elapsed > 0 and (completed_count / elapsed) or 0
            local eta = rate > 0 and math.floor((total_work - completed_count) / rate) or 0
            progress.update(string.format("   [%d threads]", num_threads), completed_count, total_work,
                string.format("%.1f jobs/sec | ETA: %ds | Queue: %d", rate, eta, total_work - work_queue_idx + 1))
        end
    end
    -- }}}
    progress.finish()
    local elapsed = os.time() - start_time
    require("output").print(string.format("   [%d threads] Complete: %d jobs in %ds (%.1f jobs/sec)",
        num_threads, completed_count, elapsed, completed_count / math.max(elapsed, 1)))

    -- {{{ collect each worker's counts; one that did not finish stops the run
    local totals = { similar = 0, different = 0, poems = 0, chrono_pages = 0, text_files = 0, word_pages = 0 }
    for tid, thread in pairs(threads) do
        local status, worker_err = thread:wait()
        if status ~= "completed" then
            -- a worker that did not finish built only part of its share
            utils.log_error(string.format("HTML worker %d ended as '%s': %s",
                tid, tostring(status), tostring(worker_err)))
            os.exit(1)
        end
        local sim, diff, poems, chrono, texts, words = thread:get()
        totals.similar = totals.similar + sim
        totals.different = totals.different + diff
        totals.poems = totals.poems + poems
        totals.chrono_pages = totals.chrono_pages + chrono
        totals.text_files = totals.text_files + texts
        totals.word_pages = totals.word_pages + words
    end
    -- }}}
    return totals
end
-- }}}

-- {{{ function M.generate_word_pages_on_workers
-- Draws the word-cloud word pages on the page workers (Issue 10-035).
-- jobs        : list of { word, header_color, centre_link, entries } as
--               run_page_workers takes for kind "word_page" (kind is set here)
-- output_dir  : the site folder; pages go to output_dir/wordcloud/
-- num_threads : worker threads, 1 or more
-- returns     : the number of pages written
function M.generate_word_pages_on_workers(jobs, output_dir, num_threads)
    if type(num_threads) ~= "number" or num_threads < 1 then
        error("generate_word_pages_on_workers: num_threads must be 1 or more (got " .. tostring(num_threads) .. ")")
    end
    for _, job in ipairs(jobs) do job.kind = "word_page" end
    local totals = run_page_workers(num_threads, worker_config(output_dir), jobs)
    if totals.word_pages ~= #jobs then
        error(string.format("word pages: %d asked for, %d written", #jobs, totals.word_pages))
    end
    return totals.word_pages
end
-- }}}

-- {{{ function M.generate_chronological_index_with_navigation
-- Writes the chronological pages: every poem in date order, a page at a time,
-- each page built by a worker thread (Issue 8-058; they used to be built here,
-- one long string at a time, which took ~33 s for 9 pages).
-- poems_data      : the loaded poems.json
-- output_dir      : the site folder
-- chrono_per_page : number of poems per page, or nil for config.lua's value
--                   (Issue 9-003); a number also turns pagination on
-- num_threads     : number of worker threads, 1 or more
-- returns         : the path of the first page written
function M.generate_chronological_index_with_navigation(poems_data, output_dir, chrono_per_page, num_threads)
    if type(num_threads) ~= "number" or num_threads < 1 then
        error("generate_chronological_index_with_navigation needs a worker count of 1 or more; got "
            .. tostring(num_threads))
    end
    -- Load pagination config for chronological settings (Issue 9-003 Fix F)
    load_pagination_config()
    local chronological_paginated = PAGINATION_CONFIG.chronological_paginated
    local poems_per_page = PAGINATION_CONFIG.chronological_poems_per_page
    -- a per-page count from the command line overrides config and turns
    -- pagination on
    if chrono_per_page and type(chrono_per_page) == "number" and chrono_per_page > 0 then
        poems_per_page = chrono_per_page
        chronological_paginated = true
    end

    -- Sort poems chronologically (by actual post dates)
    local sorted = sort_poems_chronologically_by_dates(poems_data)
    local total_poems = #sorted
    -- Issue 8-045: progress bars show how far through the writing timeline a
    -- poem was written, by date, not by its place in the list
    local first_timestamp = sorted[1] and sorted[1].timestamp or 0
    local last_timestamp = sorted[total_poems] and sorted[total_poems].timestamp or 0
    local timeline_span = last_timestamp - first_timestamp
    if timeline_span <= 0 then timeline_span = 1 end  -- one date: avoid dividing by zero

    local total_pages = chronological_paginated and math.ceil(total_poems / poems_per_page) or 1
    if total_pages < 1 then total_pages = 1 end
    local per_page = chronological_paginated and poems_per_page or total_poems
    utils.log_info(string.format("Chronological pages: %d poems, %d page(s), %d poems/page",
        total_poems, total_pages, per_page))

    -- {{{ one job per page: its poems, in order, each with its timeline progress
    local jobs = {}
    for page_num = 1, total_pages do
        local entries = {}
        local start_idx = (page_num - 1) * per_page + 1
        for i = start_idx, math.min(page_num * per_page, total_poems) do
            local info = sorted[i]
            local stamp = info.timestamp or first_timestamp
            entries[#entries + 1] = {
                poem = info.poem,
                progress_pct = ((stamp - first_timestamp) / timeline_span) * 100,
            }
        end
        jobs[#jobs + 1] = { kind = "chrono_page", page_num = page_num,
            total_pages = total_pages, total_poems = total_poems, entries = entries }
    end
    -- }}}

    local done = run_page_workers(num_threads, worker_config(output_dir), jobs)
    if done.chrono_pages ~= total_pages then
        error(string.format("chronological pages: %d of %d written", done.chrono_pages, total_pages))
    end

    -- Issue 8-039: a paginated view gets chronological/index.html as a redirect
    -- to its first page
    local chrono_dir = output_dir .. "/chronological"
    if total_pages > 1 then
        if not utils.write_file(chrono_dir .. "/index.html", chronological_page.redirect_html()) then
            error("could not write " .. chrono_dir .. "/index.html")
        end
        utils.log_info("✓ chronological/index.html created (redirect to 01.html)")
    end
    return chrono_dir .. "/" .. chronological_page.file_name(1, total_pages)
end
-- }}}
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
]] .. PAGE_HEAD_BLOCK_IN_TEMPLATE .. [[</head>
]] .. require("page-theme").body_tag() .. [[
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

-- {{{ function M.generate_chronological_txt_file
-- Every poem in date order as one text file (Issue 8-013), drawn as on the
-- chronological pages but as plain text: each poem's file line and its frame,
-- no navigation boxes, no links, pictures as their descriptions. No time
-- stamp, so the same poems write the same bytes. Returns output_file.
function M.generate_chronological_txt_file(poems_data, output_file)
    local sorted = sort_poems_chronologically_by_dates(poems_data)
    local total = #sorted
    -- Issue 8-045: progress by date through the writing timeline, as the pages
    local first_timestamp = sorted[1] and sorted[1].timestamp or 0
    local last_timestamp = sorted[total] and sorted[total].timestamp or 0
    local span = last_timestamp - first_timestamp
    if span <= 0 then span = 1 end  -- one date: avoid dividing by zero
    local poem_colors = load_poem_colors()
    local parts = {
        "Poems in chronological order, by post date\n",
        string.format("%d poems\n\n", total),
    }
    for _, info in ipairs(sorted) do
        local poem = info.poem
        local color_data = poem_colors[poem.poem_index]
        parts[#parts + 1] = table.concat(text_formatter.wrap_file_header(" -> file: ",
            chronological_page.display_filename(poem), 80), "\n") .. "\n"
        parts[#parts + 1] = poem_entry.format_entry(poem, {
            color_name = color_data and color_data.color or "gray",
            progress_pct = (((info.timestamp or first_timestamp) - first_timestamp) / span) * 100,
            similar_link = "", different_link = "", chrono_link = false,
            plain = true,
        })
        parts[#parts + 1] = "\n\n"
    end
    if not utils.write_file(output_file, table.concat(parts)) then
        error("could not write " .. output_file)
    end
    return output_file
end
-- }}}
-- }}}

-- {{{ function M.generate_complete_flat_html_collection
-- Generates all similarity and diversity pages for the entire corpus
-- poems_data: full poems dataset
-- similarity_data: similarity matrix
-- embeddings_data: poem embeddings (for diversity calculation)
-- output_dir: base output directory
-- pages_spec: (optional) --pages flag value: nil/"default", "all", or a page count such as "3" (Phase D: Issue 8-012)
-- poems_per_page: (optional) CLI override for poems per page (Issue 8-022)
-- num_threads: (required) number of worker threads, 1 or more (Issue 10-065a: no default in code)
-- chrono_per_page: (optional) CLI override for chronological poems per page (Issue 9-003)
-- anchor_indices: (optional) list of poem_index numbers. Given, only these
--   poems get similar/different pages; every poem in poems_data still takes
--   its place on the timeline and in the ranked lists. Used by
--   scripts/render-page-sample to draw a sample of the site (Issue 8-058);
--   a build passes nothing and every poem gets its pages.
function M.generate_complete_flat_html_collection(poems_data, similarity_data, embeddings_data, output_dir, pages_spec, poems_per_page, num_threads, chrono_per_page, anchor_indices)
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
            -- A count of pages per poem. (The second guess that read the last
            -- number of a range, and the quiet fall back to minimum_pages,
            -- went with ranges on 2026-10-07: an unreadable value is refused.)
            pages = tonumber(pages_spec)
                or error(string.format("Invalid --pages value: '%s'. Expected a number of pages per poem (3) or all", tostring(pages_spec)))
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
    -- anchors given: only those poems get pages (each must exist); none given:
    -- every poem does
    local wanted = nil
    if anchor_indices then
        wanted = {}
        for _, idx in ipairs(anchor_indices) do wanted[idx] = true end
    end
    for i, poem in ipairs(poems_data.poems) do
        if poem.poem_index and (not wanted or wanted[poem.poem_index]) then
            valid_poems[poem.poem_index] = poem
        end
    end
    if wanted then
        for idx in pairs(wanted) do
            if not valid_poems[idx] then
                error("anchor poem " .. tostring(idx) .. " is not in poems_data")
            end
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

    -- The worker count is a required input (a whole number, 1 or more). It used
    -- to fall back to 1 here, and a 0 or negative count was quietly raised to 1;
    -- under Issue 10-065a a program that starts this asks for or is given it.
    if type(num_threads) ~= "number" or num_threads < 1 or num_threads ~= math.floor(num_threads) then
        error("generate_complete_flat_html_collection needs a worker count of 1 or more; got "
            .. tostring(num_threads))
    end

    -- Issue 8-058: threads were asked for and the threading library would not
    -- load.  This used to log a warning and quietly build every page on the
    -- single-threaded path -- a separate copy of the page code that had drifted
    -- (wrong progress bars, anchor poem printed twice).  Stop instead, and say
    -- why.  run.sh's pre-flight gate (issue 10-069) makes the same check before
    -- any stage runs, so a normal build never gets this far with a bad library.
    if num_threads > 1 and not has_threading then
        utils.log_error("Threads were requested (" .. num_threads .. ") but the threading "
            .. "library (effil) did not load: " .. tostring(effil_load_error))
        utils.log_error("Fix the library, or run with --threads 1 on purpose.")
        os.exit(1)
    end

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
    local chrono_poems_per_page_config = PAGINATION_CONFIG.chronological_poems_per_page
    local effective_chrono_per_page = chrono_poems_per_page_config
    if chrono_per_page and type(chrono_per_page) == "number" and chrono_per_page > 0 then
        effective_chrono_per_page = chrono_per_page
        chronological_paginated = true
    end
    local chrono_mapping = compute_chronological_mapping(poems_data, chronological_paginated and effective_chrono_per_page or nil)

    -- Issue 8-058: every page is built by the worker pool; one thread is one
    -- worker. (The single-threaded builder was a separate, drifted copy of
    -- the page code, reached with --threads 1 and, quietly, whenever the
    -- memory guard lowered the worker count to one.)
    local jobs = {}
    for _, poem_index in ipairs(poem_indices) do
        jobs[#jobs + 1] = { kind = "poems", poem_index = poem_index }
    end
    local config = worker_config(output_dir)
    config.pages_is_all = pages_config.is_all
    -- "--pages N" is pages 1..N (parse_pages_specification); "all" is decided
    -- per list inside the worker
    config.pages_list = pages_config.pages or {}
    config.poems_per_page = PAGINATION_CONFIG.poems_per_page
    -- Issue 10-036: "--pages all" stops at this storage cap (8-020)
    config.max_pages_per_poem = PAGINATION_CONFIG.max_pages_per_poem
    -- Issue 9-003 Fix D: where each poem sits on the timeline and its page
    config.chrono_mapping = chrono_mapping
    config.chrono_paginated = chronological_paginated
    -- Issue 8-013: each list's text export, and the download line on its pages
    config.txt_exports = PAGINATION_CONFIG.generate_txt_exports
    local done = run_page_workers(num_threads, config, jobs)
    for i = 1, done.similar do table.insert(results.similarity_pages, "parallel") end
    for i = 1, done.different do table.insert(results.diversity_pages, "parallel") end
    if config.txt_exports then
        utils.log_info(string.format("Text exports written: %d (one per list)", done.text_files))
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
-- The page builder run on its own (-I). One poem's test pages are drawn by
-- src/main.lua's "Test one poem's pages", or scripts/render-page-sample
-- --anchor N; the menu items here that drew them with the old one-thread
-- builder went with it (Issue 8-058).
function M.main(interactive_mode)
    if interactive_mode then
        require("output").print("Flat HTML Generator - Interactive Mode")
        require("output").print("1. Generate complete flat HTML collection")
        require("output").print("2. Generate chronological index only")
        require("output").print("3. Generate instructions page only")
        io.write("Select option (1-3): ")
        local choice = io.read()

        local poems_file = utils.asset_path("poems.json")
        local output_dir = DIR .. "/output"

        -- {{{ local function ask_threads()
        -- the pages are built by worker threads (Issue 8-058): ask how many
        local function ask_threads()
            io.write("How many worker threads? ")
            return tonumber(io.read()) or error("a thread count is a whole number of 1 or more")
        end
        -- }}}

        if choice == "1" then
            utils.log_info("Loading data files...")
            local poems_data = utils.read_json_file(poems_file) or error("poems.json did not load: " .. poems_file)
            -- the workers read the ranking caches themselves; nothing else is passed
            M.generate_complete_flat_html_collection(poems_data, nil, nil, output_dir, nil, nil, ask_threads())
        elseif choice == "2" then
            local poems_data = utils.read_json_file(poems_file) or error("poems.json did not load: " .. poems_file)
            M.generate_chronological_index_with_navigation(poems_data, output_dir, nil, ask_threads())
            M.generate_chronological_txt_file(poems_data, output_dir .. "/chronological.txt")
            utils.log_info("Generated chronological/index.html and chronological.txt")
        elseif choice == "3" then
            M.generate_simple_discovery_instructions(output_dir)
        else
            error("unknown menu choice: " .. tostring(choice))
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
