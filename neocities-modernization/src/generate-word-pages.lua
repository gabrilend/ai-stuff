#!/usr/bin/env luajit

-- {{{ generate-word-pages.lua
-- Issue 8-043: Generate similarity pages for word cloud words
-- Issue 8-043b: Separated into two stages for proper pipeline integration
--
-- For each word in the word cloud, generates a page showing poems ranked by
-- their semantic similarity to that word's embedding.
--
-- Modes:
--   --embeddings-only   Stage 6: Generate word embeddings (expensive, via the inference server)
--   --html-only         Stage 9: Generate HTML pages (fast, uses cached embeddings)
--   (no flag)           Both stages (backward compatible)
--
-- Word Count Options:
--   --all               Include all words (no max_words limit)
--   --words N           Set maximum words to process (default: 200 from config)
--
-- Usage:
--   luajit src/generate-word-pages.lua [DIR] [--embeddings-only|--html-only] [--all|--words N]
--   luajit src/generate-word-pages.lua --help
-- }}}

-- {{{ Setup
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end

-- {{{ parse_args
-- Parse arguments, extracting DIR, mode flags, and word/page count options
local function parse_args(args)
    local dir = nil
    local mode = "both"  -- default: both embeddings and HTML
    local all_words = false
    local max_words = nil  -- nil means use config default
    local poems_per_page = nil  -- Issue 8-050d: nil means use config default
    local chrono_per_page = nil  -- nil means fall back to config (never a literal)
    local i = 1

    while i <= #(args or {}) do
        local a = args[i]
        if a == "--embeddings-only" then
            mode = "embeddings"
            i = i + 1
        elseif a == "--html-only" then
            mode = "html"
            i = i + 1
        elseif a == "--help" or a == "-h" then
            mode = "help"
            i = i + 1
        elseif a == "--all" then
            all_words = true
            i = i + 1
        elseif a == "--words" then
            -- Accept "all" as a synonym for --all (the two flags are combined).
            if args[i + 1] == "all" then all_words = true else max_words = tonumber(args[i + 1]) end
            i = i + 2
        elseif a:match("^--words=") then
            local v = a:match("^--words=(.+)$")
            if v == "all" then all_words = true else max_words = tonumber(v) end
            i = i + 1
        -- Issue 8-050d: Parse poems-per-page argument
        elseif a == "--poems-per-page" then
            poems_per_page = tonumber(args[i + 1])
            i = i + 2
        elseif a:match("^--poems%-per%-page=") then
            poems_per_page = tonumber(a:match("^--poems%-per%-page=(.+)$"))
            i = i + 1
        -- Issue 10-036: chronological page size, threaded from run.sh so the
        -- word-page "chronological" links paginate identically to the actual
        -- chronological pages (this is a separate process from the one that
        -- built them). nil means fall back to config, never to a literal.
        elseif a == "--chrono-per-page" then
            chrono_per_page = tonumber(args[i + 1])
            i = i + 2
        elseif a:match("^--chrono%-per%-page=") then
            chrono_per_page = tonumber(a:match("^--chrono%-per%-page=(.+)$"))
            i = i + 1
        elseif a:sub(1, 1) ~= "-" then
            dir = a
            i = i + 1
        else
            -- Skip unknown flags
            i = i + 1
        end
    end

    return dir, mode, all_words, max_words, poems_per_page, chrono_per_page
end
-- }}}

local parsed_dir, RUN_MODE, CLI_ALL_WORDS, CLI_MAX_WORDS, CLI_POEMS_PER_PAGE, CLI_CHRONO_PER_PAGE = parse_args(arg)
local DIR = setup_dir_path(parsed_dir)
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path

local dkjson = require("dkjson")
local utils = require("utils")
local inference_config = require("inference-server-config")
-- Issue 10-050: shared batched embedding primitive (endpoint + prompt formatter
-- threaded in so fuzzy-computing's separate config instance is never consulted).
local fuzzy = require("fuzzy-computing")

-- Issue 10-003: Load unified config from config.lua
local config_loader = require("config-loader")
config_loader.set_project_root(DIR)
local unified_config = config_loader.load()
-- Shared box/bar drawing so word-cloud poem pages can't drift from the
-- similar/different + chronological pages (they had a third, divergent copy).
local poem_bars = require("poem-bars")
-- Shared chronological mapping (sort order + page numbers + timeline progress).
-- Reused here so the word-page "chronological" links resolve to the SAME page
-- and anchor the chronological pages actually emit (Issue 10-049 follow-up).
local flat_html = require("flat-html-generator")

utils.init_assets_root(arg)
-- }}}

local M = {}

-- {{{ Configuration
-- Determine effective max_words: CLI --all > CLI --words > config
local wc = unified_config.word_cloud or {}
local effective_max_words
if CLI_ALL_WORDS then
    effective_max_words = math.huge  -- No limit
elseif CLI_MAX_WORDS then
    effective_max_words = CLI_MAX_WORDS
else
    effective_max_words = wc.max_words or 200
end

-- Issue 8-050d: Determine effective poems_per_page: CLI > config > default
local effective_poems_per_page = CLI_POEMS_PER_PAGE or wc.poems_per_page or 50

-- {{{ resolve_chrono_per_page()
-- Chronological page size for the "chronological" poem links: the build's
-- --chrono-per-page if given, else the config value (which hard-errors if the
-- key is missing). No literal fallback -- a wrong size sends every link to the
-- wrong page, so an absent value is an error, not a guess (Issue 10-036).
local function resolve_chrono_per_page()
    return CLI_CHRONO_PER_PAGE or flat_html.default_chrono_per_page()
end
-- }}}

-- The model name lives in config.lua / --server / --model. Resolving it
-- here through inference-server-config means a model swap propagates to this script
-- automatically; we no longer need to remember to update a hardcoded string.
inference_config.set_project_root(DIR)
local CONFIG = {
    model_name = inference_config.get_selected_model(),
    max_poems_per_page = 100,        -- Poems per word page
    max_pages_per_word = 1,          -- For now, just one page per word
    word_embeddings_file = "word_embeddings.json",
    poems_per_word_page = effective_poems_per_page,  -- Issue 8-050d: configurable via CLI/config
    max_words = effective_max_words, -- Max words to process (from CLI or config)
}
-- }}}

-- {{{ local function cosine_similarity
local function cosine_similarity(vec1, vec2)
    if not vec1 or not vec2 or #vec1 ~= #vec2 then
        return 0
    end

    local dot_product = 0
    local norm1 = 0
    local norm2 = 0

    for i = 1, #vec1 do
        dot_product = dot_product + (vec1[i] * vec2[i])
        norm1 = norm1 + (vec1[i] * vec1[i])
        norm2 = norm2 + (vec2[i] * vec2[i])
    end

    norm1 = math.sqrt(norm1)
    norm2 = math.sqrt(norm2)

    if norm1 == 0 or norm2 == 0 then
        return 0
    end

    return dot_product / (norm1 * norm2)
end
-- }}}

-- {{{ local function load_word_embeddings_cache
local function load_word_embeddings_cache()
    local cache_file = utils.embeddings_dir() .. "/" .. CONFIG.word_embeddings_file
    local data = utils.read_json_file(cache_file)
    return data and data.embeddings or {}
end
-- }}}

-- {{{ local function save_word_embeddings_cache
local function save_word_embeddings_cache(embeddings)
    local cache_file = utils.embeddings_dir() .. "/" .. CONFIG.word_embeddings_file
    local data = {
        embeddings = embeddings,
        model = CONFIG.model_name,
        generated = os.date("%Y-%m-%d %H:%M:%S"),
        count = 0
    }
    for _ in pairs(embeddings) do data.count = data.count + 1 end

    return utils.write_json_file(cache_file, data)
end
-- }}}

-- {{{ local function load_color_embeddings
-- Issue 8-050a: Load color embeddings for semantic color assignment
local function load_color_embeddings()
    local color_file = utils.embeddings_dir() .. "/color_embeddings.json"
    local data = utils.read_json_file(color_file)
    return data and data.embeddings or nil
end
-- }}}

-- {{{ local function compute_nearest_color
-- Issue 8-050a: Find the nearest color to a word embedding using cosine similarity
local function compute_nearest_color(word_embedding, color_embeddings)
    if not word_embedding or not color_embeddings then
        return "gray", 0
    end

    local best_color = "gray"
    local best_sim = -1

    for color_name, color_embedding in pairs(color_embeddings) do
        local sim = cosine_similarity(word_embedding, color_embedding)
        if sim > best_sim then
            best_sim = sim
            best_color = color_name
        end
    end

    return best_color, best_sim
end
-- }}}

-- {{{ local function load_word_colors_cache
-- Issue 8-050a: Load cached word colors
local function load_word_colors_cache()
    local cache_file = utils.embeddings_dir() .. "/word_colors.json"
    local data = utils.read_json_file(cache_file)
    if data and data.word_colors then
        -- Convert array to lookup table for easy access
        local lookup = {}
        for _, entry in ipairs(data.word_colors) do
            lookup[entry.word] = entry
        end
        return lookup
    end
    return {}
end
-- }}}

-- {{{ local function save_word_colors_cache
-- Issue 8-050a: Save word colors to cache
local function save_word_colors_cache(word_colors_array)
    local cache_file = utils.embeddings_dir() .. "/word_colors.json"
    local data = {
        word_colors = word_colors_array,
        model = CONFIG.model_name,
        generated = os.date("%Y-%m-%d %H:%M:%S"),
        count = #word_colors_array
    }
    return utils.write_json_file(cache_file, data)
end
-- }}}

-- {{{ local function compute_word_colors
-- Issue 8-050a: Compute semantic colors for all word embeddings
local function compute_word_colors(word_embeddings)
    local color_embeddings = load_color_embeddings()
    if not color_embeddings then
        utils.log_warn("No color embeddings found - skipping word color computation")
        return nil
    end

    local word_colors = {}
    local count = 0
    for word, embedding in pairs(word_embeddings) do
        local best_color, best_sim = compute_nearest_color(embedding, color_embeddings)
        table.insert(word_colors, {
            word = word,
            color = best_color,
            similarity = best_sim
        })
        count = count + 1
    end

    -- Sort by word for consistent output
    table.sort(word_colors, function(a, b) return a.word < b.word end)

    utils.log_info(string.format("Computed semantic colors for %d words", count))
    return word_colors
end
-- }}}

-- {{{ local function balanced_color_select
-- Issue 8-050b: Selects N poems using cumulative-similarity-balanced round-robin
-- Ensures roughly equal color representation while maintaining word relevance
-- Uses cumulative totals to prevent high-affinity colors from dominating
local function balanced_color_select(candidates, color_embeddings, color_names, N)
    -- Phase 2: Compute color affinities for each candidate
    for _, candidate in ipairs(candidates) do
        local best_color = "gray"
        local best_color_sim = -1
        candidate.color_sims = {}
        for _, color_name in ipairs(color_names) do
            local color_emb = color_embeddings[color_name]
            if color_emb then
                local sim = cosine_similarity(color_emb, candidate.embedding)
                candidate.color_sims[color_name] = sim
                if sim > best_color_sim then
                    best_color_sim = sim
                    best_color = color_name
                end
            end
        end
        candidate.best_color = best_color
        candidate.best_color_sim = best_color_sim
    end

    -- Phase 3: Build color buckets (sorted by word_similarity descending)
    local buckets = {}
    for _, color_name in ipairs(color_names) do
        buckets[color_name] = {}
    end
    for _, candidate in ipairs(candidates) do
        table.insert(buckets[candidate.best_color], candidate)
    end
    for _, color_name in ipairs(color_names) do
        table.sort(buckets[color_name], function(a, b)
            return a.word_similarity > b.word_similarity
        end)
    end

    -- Phase 4: Balanced round-robin selection
    -- Give priority to colors with lowest cumulative color-similarity totals
    local cumulative = {}
    local bucket_idx = {}  -- next pick index per color
    for _, color_name in ipairs(color_names) do
        cumulative[color_name] = 0
        bucket_idx[color_name] = 1
    end

    local selected = {}
    while #selected < N do
        -- Find color with lowest cumulative score that still has candidates
        local pick_color = nil
        local lowest_cum = math.huge
        local most_remaining = -1
        for _, color_name in ipairs(color_names) do
            local remaining = #buckets[color_name] - bucket_idx[color_name] + 1
            if remaining > 0 then
                local cum = cumulative[color_name]
                -- Tiebreak: prefer color with more remaining candidates
                if cum < lowest_cum or (cum == lowest_cum and remaining > most_remaining) then
                    lowest_cum = cum
                    pick_color = color_name
                    most_remaining = remaining
                end
            end
        end

        if not pick_color then break end  -- all buckets exhausted

        -- Pop top candidate from this color's bucket
        local idx = bucket_idx[pick_color]
        local poem = buckets[pick_color][idx]
        bucket_idx[pick_color] = idx + 1

        -- Track cumulative color similarity (high-affinity colors "spend" budget faster)
        cumulative[pick_color] = cumulative[pick_color] + poem.best_color_sim

        table.insert(selected, poem)
    end

    return selected
end
-- }}}

-- {{{ local function compute_centroid
-- Issue 8-050e: Compute the centroid (average embedding) of selected poems
-- Returns nil if no valid embeddings found
local function compute_centroid(poems, poem_lookup)
    if not poems or #poems == 0 then return nil end

    -- Find dimension from first valid embedding
    local dim = nil
    for _, entry in ipairs(poems) do
        local poem_id = tostring(entry.poem and entry.poem.poem_index)
        local emb = poem_lookup[poem_id]
        if emb then
            dim = #emb
            break
        end
    end
    if not dim then return nil end

    -- Initialize centroid to zeros
    local centroid = {}
    for d = 1, dim do centroid[d] = 0 end

    -- Sum embeddings of selected poems
    local count = 0
    for _, entry in ipairs(poems) do
        local poem_id = tostring(entry.poem and entry.poem.poem_index)
        local emb = poem_lookup[poem_id]
        if emb then
            for d = 1, dim do centroid[d] = centroid[d] + emb[d] end
            count = count + 1
        end
    end

    if count == 0 then return nil end

    -- Average
    for d = 1, dim do centroid[d] = centroid[d] / count end

    return centroid
end
-- }}}

-- {{{ local function find_closest_poem_to_centroid
-- Issue 8-050e: Find the poem whose embedding is closest to the given centroid
-- Returns poem data or nil if no match found
local function find_closest_poem_to_centroid(centroid, poem_lookup, poems_by_index)
    if not centroid then return nil end

    local best_poem = nil
    local best_similarity = -1

    for poem_id_str, poem_embedding in pairs(poem_lookup) do
        local sim = cosine_similarity(centroid, poem_embedding)
        if sim > best_similarity then
            best_similarity = sim
            best_poem = poems_by_index[tonumber(poem_id_str)]
        end
    end

    return best_poem
end
-- }}}

-- {{{ local function get_word_list
-- Extracts word list from poems (same logic as wordcloud-generator)
local function get_word_list(poems_data, stop_words, min_occurrences, max_words, min_word_length)
    local word_counts = {}

    for _, poem in ipairs(poems_data.poems or {}) do
        local content = poem.content or ""
        for word in content:gmatch("[%w]+") do
            local normalized = word:lower()
            if #normalized >= min_word_length
               and not stop_words[normalized]
               and not normalized:match("^%d+$") then
                word_counts[normalized] = (word_counts[normalized] or 0) + 1
            end
        end
    end

    -- Filter and sort
    local filtered = {}
    for word, count in pairs(word_counts) do
        if count >= min_occurrences then
            table.insert(filtered, {word = word, count = count})
        end
    end
    -- Sort by count descending, with an ALPHABETICAL tiebreaker. The tiebreak
    -- is load-bearing, not cosmetic: `filtered` is built by iterating a Lua
    -- hash (pairs), whose order differs from process to process, and
    -- table.sort is not stable. Without a deterministic tiebreak, two separate
    -- runs (stage 6 generating embeddings, the HTML stage consuming them) sort
    -- ties differently, so the max_words cutoff keeps DIFFERENT words each run
    -- -- which is exactly how a word ends up in the HTML list with no
    -- embedding ("Missing embedding for word X"). Sorting ties by word makes
    -- the cutoff identical across processes, closing that gap.
    table.sort(filtered, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.word < b.word
    end)

    -- Limit to max_words
    local result = {}
    for i = 1, math.min(#filtered, max_words) do
        result[i] = filtered[i].word
    end

    return result
end
-- }}}

-- {{{ local function load_stop_words
-- Issue 10-003: Load stop words from embedded config.word_cloud.stop_words array
local function load_stop_words()
    local stop_words = {}
    local wc = unified_config.word_cloud or {}
    for _, word in ipairs(wc.stop_words or {}) do
        stop_words[word:lower()] = true
    end
    return stop_words
end
-- }}}

-- {{{ local function build_poem_embeddings_lookup
local function build_poem_embeddings_lookup(embeddings_data)
    local lookup = {}
    if not embeddings_data or not embeddings_data.embeddings then
        return lookup
    end

    for _, entry in ipairs(embeddings_data.embeddings) do
        if entry.id and entry.embedding then
            lookup[tostring(entry.id)] = entry.embedding
        end
    end

    return lookup
end
-- }}}

-- {{{ local function format_poem_for_word_page
-- Issue 8-043c: Format poem entry using same box-drawing style as similar/different pages
-- Issue 10-036: Added chrono_page_map for correct per-poem pagination links
-- Uses CHRONOLOGICAL position for progress bar (same as similar/different pages)
-- This helps users orient themselves in the timeline/story
local function format_poem_for_word_page(poem, rank, similarity, poem_colors, color_config, chrono_map, chrono_page_map)
    local poem_idx = poem.poem_index or 0

    -- Get semantic color for this poem (default to gray)
    local poem_color_data = poem_colors and poem_colors[poem_idx]
    local semantic_color = poem_color_data and poem_color_data.color or "gray"
    local hex_color = color_config and color_config[semantic_color] or "#888888"

    -- Check if golden poem (metadata-based detection)
    local is_golden = poem.metadata and poem.metadata.is_golden_poem

    -- Use CHRONOLOGICAL position for progress bar (not similarity score)
    -- This matches similar/different pages and helps orient the reader in the story
    -- Issue 8-045: Use timeline_progress (time-based) instead of position-based
    local chrono_info = chrono_map and chrono_map[poem_idx] or {position = 1, total_poems = 1, timeline_progress = 50}
    local progress_pct = chrono_info.timeline_progress or ((chrono_info.position / chrono_info.total_poems) * 100)

    -- Calculate progress bar chars
    -- Regular: 83 chars total, Golden: 82 interior + 2 corners = 84 total
    local total_bar_chars = is_golden and 82 or 83
    local progress_chars = math.floor((progress_pct / 100) * total_bar_chars)
    local remaining_chars = total_bar_chars - progress_chars

    -- Top progress bar from the shared poem-bars module (canonical geometry,
    -- same as the similar/different + chronological pages).
    poem_bars.configure(color_config)
    local colored_progress = poem_bars.progress_dashes(
        { percentage = progress_pct }, semantic_color, is_golden, "top", false).visual

    -- Navigation links
    local base_path = "file:///home/ritz/programming/ai-stuff/neocities-modernization/output"
    local similar_link = string.format("<a href='%s/similar/%04d-01.html'>similar</a>", base_path, poem_idx)
    local different_link = string.format("<a href='%s/different/%04d-01.html'>different</a>", base_path, poem_idx)
    -- Anchor must match the spans the chronological pages emit, which are
    -- get_poem_anchor_id() = "poem-<poem_index>". The old "poem-CATEGORY-ID"
    -- form never matched any anchor, so the chronological link landed at the
    -- top of the page instead of the poem.
    local anchor_id = string.format("poem-%d", poem_idx)
    -- Issue 10-036: Use chrono_page_map for correct paginated link (index.html is redirect that loses anchors)
    local chrono_page = chrono_page_map and chrono_page_map[poem_idx] or "01"
    local chrono_link = string.format("<a href='%s/chronological/%s.html#%s'>chronological</a>", base_path, chrono_page, anchor_id)

    -- Word-wrap content to 80 chars
    local content = poem.content or ""
    content = content:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")

    local wrapped_lines = {}

    -- Handle content warning from poem.content_warning (ActivityPub CW)
    if poem.content_warning and poem.content_warning ~= "" then
        local cw_display = "CW: " .. poem.content_warning
        local box_width = math.min(math.max(#cw_display, 20), 76)
        local padded_cw = cw_display .. string.rep(" ", box_width - #cw_display)
        table.insert(wrapped_lines, " ┌" .. string.rep("─", box_width + 2) .. "┐")
        table.insert(wrapped_lines, " │ " .. padded_cw .. " │")
        table.insert(wrapped_lines, " └" .. string.rep("─", box_width + 2) .. "┘")
        table.insert(wrapped_lines, "")
        table.insert(wrapped_lines, "")
    end

    -- Handle in-content CW: patterns
    local main_content = content
    local cw_match = content:match("^%s*[Cc][Ww]%s*:(.-)[\n\r]")
    if not cw_match then
        cw_match = content:match("^%s*[Cc]ontent [Ww]arning%s*:(.-)[\n\r]")
    end
    if cw_match then
        local cw_text = cw_match:match("^%s*(.-)%s*$")
        main_content = content:gsub("^%s*[Cc][Ww]%s*:[^\n\r]*[\n\r]?", "")
        main_content = main_content:gsub("^%s*[Cc]ontent [Ww]arning%s*:[^\n\r]*[\n\r]?", "")
        if cw_text and #cw_text > 0 then
            local cw_display = "CW: " .. cw_text
            local box_width = math.min(math.max(#cw_display, 20), 76)
            local padded_cw = cw_display .. string.rep(" ", box_width - #cw_display)
            table.insert(wrapped_lines, " ┌" .. string.rep("─", box_width + 2) .. "┐")
            table.insert(wrapped_lines, " │ " .. padded_cw .. " │")
            table.insert(wrapped_lines, " └" .. string.rep("─", box_width + 2) .. "┘")
            table.insert(wrapped_lines, "")
        end
    end

    -- Word-wrap paragraphs
    for para in (main_content .. "\n"):gmatch("(.-)\n") do
        if para == "" then
            table.insert(wrapped_lines, "")
        else
            local current_line = ""
            for word in para:gmatch("%S+") do
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

    -- Apply golden side borders if needed
    if is_golden then
        local golden_lines = {}
        local colored_wall = string.format('<font color="%s"><b>║</b></font>', hex_color)
        local CONTENT_WIDTH = 80

        local function utf8_char_count(str)
            return #(str:gsub("[\128-\191]", ""))
        end

        for _, line in ipairs(wrapped_lines) do
            local line_content = line:match("^%s*(.*)$") or line
            local visible_content = line_content:gsub("<[^>]+>", "")
            local visible_length = utf8_char_count(visible_content)
            local padded_content
            if visible_length >= CONTENT_WIDTH then
                padded_content = line_content
            else
                padded_content = line_content .. string.rep(" ", CONTENT_WIDTH - visible_length)
            end
            table.insert(golden_lines, colored_wall .. " " .. padded_content .. " │")
        end
        wrapped_lines = golden_lines
    end

    -- Helper to colorize box characters based on progress
    local function color_char(char, pos)
        if progress_chars > pos then
            return string.format('<font color="%s"><b>%s</b></font>', hex_color, char)
        end
        return char
    end

    -- Navigation box + bottom bar from the shared poem-bars module. The old
    -- inline copy had drifted (golden junctions at 9/70 instead of 10/71), which
    -- is exactly why word-cloud golden poems were mangled.
    local nav_top, nav_mid
    if is_golden then
        nav_top = poem_bars.golden_corner_box_separator(hex_color, progress_chars)
        nav_mid = poem_bars.golden_corner_box_nav_line(similar_link, different_link, chrono_link, hex_color, progress_chars)
    else
        nav_top = poem_bars.corner_box_top(progress_chars, hex_color)
        nav_mid = poem_bars.corner_box_nav_line(similar_link, different_link, chrono_link, progress_chars, hex_color)
    end

    local bottom_line = poem_bars.progress_dashes(
        { percentage = progress_pct }, semantic_color, is_golden, "bottom", true).visual

    -- Generate poem identifier (same format as similar/different pages)
    -- Format: " -> file: fediverse/1234" or " -> file: notes/myfile"
    local category = poem.category or "unknown"
    local filename
    if category == "notes" and poem.metadata and poem.metadata.source_file then
        filename = poem.metadata.source_file
    else
        filename = tostring(poem.id or "unknown")
    end
    local poem_identifier = " -> file: " .. category .. "/" .. filename

    -- Build final output
    local output = {}
    table.insert(output, colored_progress)
    if is_golden then
        -- The header (" -> file:") and the blank line below it belong INSIDE the
        -- golden box, with the same ║ ... │ walls as every other line, so the box
        -- has consistent borders and uniform line width (no special-spaced gap).
        local function golden_line(content)
            local visible = content:gsub("<[^>]+>", "")
            local vlen = #(visible:gsub("[\128-\191]", ""))
            local padded = content .. string.rep(" ", math.max(0, 80 - vlen))
            return string.format('<font color="%s"><b>║</b></font> %s │', hex_color, padded)
        end
        table.insert(output, golden_line((poem_identifier:gsub("^%s+", ""))))
        table.insert(output, golden_line(""))
    else
        table.insert(output, poem_identifier)
        table.insert(output, "")
    end
    table.insert(output, table.concat(wrapped_lines, "\n"))
    table.insert(output, nav_top)
    table.insert(output, nav_mid)
    table.insert(output, bottom_line)

    return table.concat(output, "\n")
end
-- }}}

-- {{{ local function generate_word_page
-- Generates HTML page for a single word showing similar poems
-- Issue 8-043c: Now uses same box-drawing format as similar/different pages
-- Issue 8-050c: Word color shown in header, per-poem colors for progress bars
-- Issue 8-050e: Chronological link points to centroid-based location in timeline
-- Issue 10-036: Added chrono_page_map for correct per-poem pagination links
-- Progress bar shows CHRONOLOGICAL position (not similarity) to orient readers
local function generate_word_page(word, ranked_poems, output_dir, poems_per_page, poem_colors, color_config, chrono_map, word_hex_color, chrono_center_link, chrono_page_map)
    local safe_word = word:lower():gsub("[^%w]", "")
    local output_file = output_dir .. "/wordcloud/" .. safe_word .. ".html"

    -- Ensure directory exists
    os.execute('mkdir -p "' .. output_dir .. '/wordcloud"')

    -- Take top N poems
    local top_poems = {}
    for i = 1, math.min(poems_per_page, #ranked_poems) do
        top_poems[i] = ranked_poems[i]
    end

    -- Issue 8-050c: Use word's semantic color for header (default to gray if not provided)
    local header_color = word_hex_color or "#888888"

    -- Issue 8-050e: Use centroid-based chronological link if provided, else default
    local base_path = "file:///home/ritz/programming/ai-stuff/neocities-modernization/output"
    local chrono_link = chrono_center_link or (base_path .. "/chronological/index.html")

    -- Generate HTML
    -- Issue 16-010: Added font style for Hack Nerd Font font-stack
    -- Same centering CSS the similar/different/chronological pages use: each
    -- <pre> centers as an inline-block (text stays left), so the poem column
    -- lands on the page centerline even when an attached image is wider.
    local font_style = [[<style>body, pre { font-family: 'Hack Nerd Font', 'Hack', 'Fira Code', 'JetBrains Mono', 'Cascadia Code', 'Consolas', 'Monaco', 'Liberation Mono', 'Courier New', monospace; }
td { text-align: center; } pre { display: inline-block; text-align: left; margin: 0 auto; } img, video, audio { margin-left: auto; margin-right: auto; }</style>]]
    local html_parts = {}
    table.insert(html_parts, string.format([[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Poems similar to: %s</title>
%s</head>
<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">
<center>
<h1>Poems similar to: <i><font color="%s">%s</font></i></h1>
<p>Top %d poems ranked by semantic similarity (progress bar shows chronological position)</p>
<!-- Issue 16-010: Changed main.html to wordcloud.html (main.html doesn't exist) -->
<p><a href="%s/wordcloud.html">Menu</a> │ <a href="%s">Chronological</a></p>
</center>
<hr>
<table align="center"><tr><td>
<pre>
]], word, font_style, header_color, word, #top_poems, base_path, chrono_link))

    -- Add ranked poems using box-drawing format
    -- Issue 10-036: Pass chrono_page_map for correct per-poem pagination links
    for i, entry in ipairs(top_poems) do
        local formatted = format_poem_for_word_page(entry.poem, i, entry.similarity, poem_colors, color_config, chrono_map, chrono_page_map)
        table.insert(html_parts, formatted)
        table.insert(html_parts, "\n")
    end

    table.insert(html_parts, [[</pre>
</td></tr></table>
</body>
</html>
]])

    local html = table.concat(html_parts)
    return utils.write_file(output_file, html)
end
-- }}}

-- {{{ function M.generate_word_embeddings
-- Issue 8-043b: Stage 6 - Generate word embeddings only (expensive operation)
-- Called during embedding generation stage of the pipeline
function M.generate_word_embeddings(options)
    options = options or {}

    -- Check inference server availability
    -- Issue 10-017: Use build_host_url() instead of deprecated OLLAMA_ENDPOINT
    local endpoint = inference_config.build_host_url()
    utils.log_info("Using inference endpoint: " .. endpoint)

    -- Load poems for word extraction
    local poems_file = utils.asset_path("poems.json")
    local poems_data = utils.read_json_file(poems_file)
    if not poems_data then
        utils.log_error("Could not load poems.json")
        return nil
    end

    -- Get word list (using CONFIG.max_words from CLI or config)
    local stop_words = load_stop_words()
    local words = get_word_list(poems_data, stop_words, 5, CONFIG.max_words, 3)
    utils.log_info(string.format("Processing %d words", #words))

    -- Load cached word embeddings
    local word_embeddings = load_word_embeddings_cache()
    local cache_hits = 0
    local cache_misses = 0

    -- Issue 10-050: collect the words missing from cache, then embed them all in
    -- one batched + (sub-)batched call instead of one curl per word. Words are
    -- single tokens so chunking is a no-op; embed_texts_with_chunking still
    -- splits the request into BATCH_SIZE-sized round trips. endpoint + prompt
    -- formatter are passed so the prefix matches the poem embeddings (required
    -- for the word-to-poem cosine comparison to be meaningful).
    local missing = {}
    for _, word in ipairs(words) do
        if not word_embeddings[word] then
            missing[#missing + 1] = word
        end
    end
    cache_hits = #words - #missing

    if #missing > 0 then
        utils.log_info(string.format("Embedding %d missing words (batched)...", #missing))
        local vectors = fuzzy.embed_texts_with_chunking(missing, CONFIG.model_name, {
            endpoint = endpoint,
            format_fn = inference_config.format_embedding_prompt
        })
        if vectors then
            for k, word in ipairs(missing) do
                local embedding = vectors[k]
                if embedding and type(embedding) == "table" and #embedding > 0 then
                    word_embeddings[word] = embedding
                    cache_misses = cache_misses + 1
                    -- Periodic checkpoint so a crash mid-run keeps prior work.
                    if cache_misses % 50 == 0 then
                        save_word_embeddings_cache(word_embeddings)
                    end
                else
                    utils.log_warn(string.format("Failed to embed word '%s'", word))
                end
            end
        else
            utils.log_warn("Batch word embedding failed (inference server unreachable?)")
        end
    end

    -- Save final cache
    save_word_embeddings_cache(word_embeddings)
    utils.log_info(string.format("Word embeddings: %d cached, %d newly generated", cache_hits, cache_misses))

    -- Issue 8-050a: Compute and save semantic colors for all words
    local word_colors = compute_word_colors(word_embeddings)
    if word_colors then
        save_word_colors_cache(word_colors)
        utils.log_info(string.format("Saved semantic colors for %d words to word_colors.json", #word_colors))
    end

    return cache_hits + cache_misses
end
-- }}}

-- {{{ function M.generate_word_html
-- Issue 8-043b: Stage 9 - Generate HTML pages only (requires existing embeddings)
-- Issue 8-043c: Now uses box-drawing format with semantic colors
-- Called during HTML generation stage of the pipeline
function M.generate_word_html(options)
    options = options or {}
    local output_dir = options.output_dir or (DIR .. "/output")

    -- Load poems
    local poems_file = utils.asset_path("poems.json")
    local poems_data = utils.read_json_file(poems_file)
    if not poems_data then
        utils.log_error("Could not load poems.json")
        return nil
    end

    -- Load poem embeddings
    local embeddings_file = utils.embeddings_dir() .. "/embeddings.json"
    local embeddings_data = utils.read_json_file(embeddings_file)
    if not embeddings_data then
        utils.log_error("Could not load poem embeddings - run --generate-embeddings first")
        return nil
    end
    local poem_lookup = build_poem_embeddings_lookup(embeddings_data)

    -- Load word embeddings (must exist from Stage 6)
    local word_embeddings = load_word_embeddings_cache()
    local word_count = 0
    for _ in pairs(word_embeddings) do word_count = word_count + 1 end

    if word_count == 0 then
        utils.log_error("No word embeddings found - run --embeddings-only first")
        return nil
    end
    utils.log_info(string.format("Loaded %d word embeddings", word_count))

    -- Issue 8-043c: Load poem colors for semantic coloring
    -- Issue 10-034: Fixed path - poem_colors.json is in embeddings directory, not assets root
    local poem_colors_file = utils.embeddings_dir() .. "/poem_colors.json"
    local poem_colors_data = utils.read_json_file(poem_colors_file)
    -- poem_colors.json stores a plain ARRAY whose position IS the poem_index
    -- (entries carry color/similarity but NO poem_index field). flat-html
    -- reads it positionally (poem_colors[poem_index]); we must do the same.
    -- The old code keyed on entry.poem_index -- always nil -- so the table came
    -- out empty and every word-page progress bar fell back to gray. Reading the
    -- array directly is what makes those bars match the similar/different pages.
    local poem_colors = (poem_colors_data and poem_colors_data.poem_colors) or {}
    if not (poem_colors_data and poem_colors_data.poem_colors) then
        utils.log_warn("No poem colors found - using default gray")
    end

    -- Issue 8-050a: Load word colors for per-word semantic coloring
    local word_colors = load_word_colors_cache()
    local word_color_count = 0
    for _ in pairs(word_colors) do word_color_count = word_color_count + 1 end
    if word_color_count == 0 then
        utils.log_warn("No word colors found - run --embeddings-only to generate them")
    end

    -- Issue 8-050b: Load color embeddings for balanced color selection
    local color_embeddings = load_color_embeddings()
    local use_balanced_selection = color_embeddings ~= nil
    if not use_balanced_selection then
        utils.log_warn("No color embeddings found - using pure similarity ranking")
    end

    -- Issue 8-050b: Get ordered color names from config
    local color_names = unified_config.color_names
        or {"red", "blue", "green", "purple", "orange", "yellow", "gray"}

    -- Issue 8-043c: Load color configuration from unified config
    local color_config = unified_config.colors or {
        red = "#FF6B6B",
        orange = "#FFA94D",
        yellow = "#FFE066",
        green = "#69DB7C",
        cyan = "#38D9A9",
        blue = "#74C0FC",
        indigo = "#748FFC",
        violet = "#DA77F2",
        gray = "#868E96"
    }

    -- Issue 8-043c: Compute chronological mapping for progress bars
    -- This maps poem_index → {position, total_poems} for timeline orientation
    -- Issue 8-050e: Also builds chrono_page_map for centroid-based navigation
    local chrono_map = {}
    local chrono_page_map = {}  -- poem_index → page string ("01", "02", etc.)
    do
        -- Reuse the chronological-page generator's OWN mapping instead of a second
        -- inline copy. The old copy sorted by the raw creation_date string with no
        -- tiebreaker and a 500/page default, so it disagreed with the actual
        -- chronological pagination (timestamp sort + original-index tiebreaker +
        -- config page size) -> links jumped to the wrong page and never scrolled.
        -- The page size comes from resolve_chrono_per_page() (the build's
        -- --chrono-per-page, else config). It MUST match what the chronological
        -- pages were built with; a wrong size is exactly what broke these links,
        -- so an absent value hard-errors rather than guessing (Issue 10-036).
        local per_page = resolve_chrono_per_page()
        local mapping = flat_html.compute_chronological_mapping(poems_data, per_page)
        local total_poems = 0
        for poem_index, info in pairs(mapping) do
            chrono_map[poem_index] = {
                position = info.position,
                total_poems = info.total_poems,
                -- Carry the time-based progress so the word-page bars match the
                -- similar/different/chronological pages exactly (not position-based).
                timeline_progress = info.timeline_progress,
            }
            chrono_page_map[poem_index] = string.format("%02d", info.page_number)
            total_poems = info.total_poems
        end
        utils.log_info(string.format("Built chronological mapping for %d poems (%d per page, shared)", total_poems, per_page))
    end

    -- Build poem index lookup
    local poems_by_index = {}
    for _, poem in ipairs(poems_data.poems) do
        if poem.poem_index then
            poems_by_index[poem.poem_index] = poem
        end
    end

    -- Get word list (same as embedding generation to ensure consistency)
    local stop_words = load_stop_words()
    local words = get_word_list(poems_data, stop_words, 5, CONFIG.max_words, 3)

    -- Generate pages for each word
    local pages_generated = 0
    for i, word in ipairs(words) do
        local word_embedding = word_embeddings[word]
        if word_embedding then
            io.write(string.format("\rGenerating word page %d/%d: %s          ", i, #words, word))
            io.flush()

            -- Issue 8-050b: Build candidate pool with embeddings preserved
            -- Phase 1: Rank ALL poems by word similarity
            local candidates = {}
            for poem_id_str, poem_embedding in pairs(poem_lookup) do
                local poem_id = tonumber(poem_id_str)
                local poem = poems_by_index[poem_id]
                if poem and poem_embedding then
                    local word_sim = cosine_similarity(word_embedding, poem_embedding)
                    table.insert(candidates, {
                        poem = poem,
                        embedding = poem_embedding,
                        word_similarity = word_sim,
                        similarity = word_sim  -- for generate_word_page compatibility
                    })
                end
            end

            -- Sort by word similarity (descending)
            table.sort(candidates, function(a, b)
                return a.word_similarity > b.word_similarity
            end)

            -- Issue 8-050b (revised): relevance first, THEN color spread.
            -- The page always shows the top-N MOST RELEVANT poems by similarity;
            -- balanced_color_select is handed exactly those N (not a 7N pool),
            -- so it keeps the whole relevant set and only REORDERS it to spread
            -- the colors across the page. The earlier 7N-pool version let color
            -- balancing DISPLACE strong matches with weaker color-diverse ones,
            -- which is why a "god" search surfaced unrelated poems.
            local ranked_poems
            if use_balanced_selection then
                local pool_size = math.min(#candidates, CONFIG.poems_per_word_page)
                local pool = {}
                for j = 1, pool_size do pool[j] = candidates[j] end

                -- Reorder the top-N relevant poems for color spread (keeps all N).
                ranked_poems = balanced_color_select(
                    pool, color_embeddings, color_names, CONFIG.poems_per_word_page)
            else
                -- Fallback: pure similarity ranking (no color data available)
                ranked_poems = candidates
            end

            -- Issue 8-050c: Get word's semantic color for header
            local word_color_entry = word_colors[word]
            local word_semantic_color = word_color_entry and word_color_entry.color or "gray"
            local word_hex_color = color_config and color_config[word_semantic_color] or "#888888"

            -- Issue 8-050e: Compute centroid-based chronological link
            local chrono_center_link = nil
            do
                -- Compute centroid of selected poems
                local centroid = compute_centroid(ranked_poems, poem_lookup)
                if centroid then
                    -- Find the poem closest to the centroid
                    local center_poem = find_closest_poem_to_centroid(centroid, poem_lookup, poems_by_index)
                    if center_poem and center_poem.poem_index then
                        -- Anchor must match the spans the chronological pages emit:
                        -- get_poem_anchor_id() = "poem-<poem_index>". The old
                        -- "poem-CATEGORY-ID" form matched no anchor, so this top
                        -- "chronological" link landed at the page top, not the poem.
                        local anchor_id = string.format("poem-%d", center_poem.poem_index)
                        -- Get chronological page for this poem
                        -- Issue 10-036: Use "01" fallback instead of "index" (redirect loses anchors)
                        local chrono_page = chrono_page_map[center_poem.poem_index] or "01"
                        -- Build full link
                        local base_path = "file:///home/ritz/programming/ai-stuff/neocities-modernization/output"
                        chrono_center_link = string.format("%s/chronological/%s.html#%s",
                            base_path, chrono_page, anchor_id)
                    end
                end
            end

            -- Generate page with semantic colors and chronological position
            -- Issue 10-036: Pass chrono_page_map for correct per-poem pagination links
            if generate_word_page(word, ranked_poems, output_dir, CONFIG.poems_per_word_page, poem_colors, color_config, chrono_map, word_hex_color, chrono_center_link, chrono_page_map) then
                pages_generated = pages_generated + 1
            end
        else
            utils.log_warn(string.format("Missing embedding for word '%s', skipping", word))
        end
    end
    print("")  -- Newline after progress

    utils.log_info(string.format("Generated %d word similarity pages in %s/wordcloud/", pages_generated, output_dir))
    return pages_generated
end
-- }}}

-- {{{ function M.generate_word_pages
-- Backward compatible: generates both embeddings and HTML (original behavior)
function M.generate_word_pages(options)
    options = options or {}

    -- Stage 1: Generate embeddings
    local embed_count = M.generate_word_embeddings(options)
    if not embed_count then
        return nil
    end

    -- Stage 2: Generate HTML
    return M.generate_word_html(options)
end
-- }}}

-- {{{ function M.main
function M.main(mode)
    mode = mode or RUN_MODE

    if mode == "embeddings" then
        return M.generate_word_embeddings()
    elseif mode == "html" then
        return M.generate_word_html()
    else
        return M.generate_word_pages()
    end
end
-- }}}

-- {{{ Command line execution
if arg and #arg >= 0 and debug.getinfo(3) == nil then
    if RUN_MODE == "help" then
        print("Usage: luajit src/generate-word-pages.lua [DIR] [OPTIONS]")
        print("")
        print("Generates similarity pages for word cloud words.")
        print("For each word, creates a page showing poems ranked by semantic similarity.")
        print("")
        print("Options:")
        print("  DIR               Project directory (default: /mnt/mtwo/programming/ai-stuff/neocities-modernization)")
        print("  --embeddings-only Generate word embeddings only (Stage 6 - expensive)")
        print("  --html-only       Generate HTML pages only (Stage 9 - fast, requires embeddings)")
        print("  --all             Include all words (no max_words limit)")
        print("  --words N         Set maximum words to process (default: 200 from config)")
        print("  --help            Show this help message")
        print("")
        print("Pipeline Integration (Issue 8-043b):")
        print("  Stage 6 (Embeddings): luajit src/generate-word-pages.lua --embeddings-only")
        print("  Stage 9 (HTML):       luajit src/generate-word-pages.lua --html-only")
        print("")
        print("Without flags, runs both stages (backward compatible).")
        os.exit(0)
    end

    M.main()
end
-- }}}

return M
