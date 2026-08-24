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
        -- Issue 10-065: consume "--dir PATH" as a PAIR. This parser does not use
        -- the value (utils.init_assets_root reads --dir out of `arg` itself), but
        -- it must still swallow it: the branch below claims any token that does
        -- not start with "-" as the positional project directory, so an
        -- unconsumed PATH would silently REPLACE the project root -- and since
        -- package.path is built from that root, the program would then fail to
        -- find its own libraries. Skipping a flag is not the same as skipping a
        -- flag and its argument.
        elseif a == "--dir" then
            i = i + 2
        elseif a:sub(1, 1) ~= "-" then
            dir = a
            i = i + 1
        else
            -- Skip unknown flags (value-less ones; a flag that TAKES a value
            -- needs its own branch above, or its value lands in `dir`).
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
-- Issue 10-065: the shared progress renderer, so this stage's bar obeys the same
-- rules as every other stage's -- animated on a TTY, newline-terminated lines
-- under --debug, silent when piped. It used to hand-roll a "\r" line instead;
-- see the loop below for what that cost.
local progress = require("progress-display")
-- Shared chronological mapping (sort order + page numbers + timeline progress).
-- Reused here so the word-page "chronological" links resolve to the SAME page
-- and anchor the chronological pages actually emit (Issue 10-049 follow-up).
local flat_html = require("flat-html-generator")
-- Shared boost frame + text wrapping, so a reshared post looks the same here as
-- it does on the chronological and similar/different pages. Word pages used to
-- render boosts as plain poems, which is the only place on the site where the
-- frame went missing.
local boost_bars = require("boost-bars")
local text_formatter = require("text-formatter")
-- One owner for what every page's <head> contains (viewport, shipped font,
-- text-size lock). Four generators used to keep four copies of the font stack
-- and none of them declared a viewport.
local page_head = require("page-head")

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

-- {{{ local function compute_corpus_mean
-- Averages every poem embedding into one vector: the direction they all share.
-- Returns nil for an empty corpus, which callers treat as "skip the correction"
-- rather than as an error, since a corpus of zero poems has no mean to speak of.
local function compute_corpus_mean(poem_lookup)
    local mean, dims, n = nil, 0, 0
    for _, emb in pairs(poem_lookup) do
        if type(emb) == "table" and #emb > 0 then
            if not mean then
                dims = #emb
                mean = {}
                for i = 1, dims do mean[i] = 0 end
            end
            -- A vector of a different length than the first one cannot be summed
            -- into the same mean; that means two models' output got mixed into
            -- one file, which is worth stopping over rather than averaging past.
            if #emb ~= dims then
                utils.log_error(string.format(
                    "Embedding dimension mismatch: expected %d, found %d -- embeddings.json mixes models",
                    dims, #emb))
                return nil
            end
            for i = 1, dims do mean[i] = mean[i] + emb[i] end
            n = n + 1
        end
    end
    if not mean or n == 0 then return nil end
    for i = 1, dims do mean[i] = mean[i] / n end
    return mean
end
-- }}}

-- {{{ local function centered
-- Subtracts the shared direction from a vector, leaving only what distinguishes
-- it. Returns the vector untouched when there is no mean to subtract, so a
-- missing corpus mean degrades to the old behaviour instead of to zeros.
local function centered(vec, mean)
    if not mean or not vec or #vec ~= #mean then
        return vec
    end
    local out = {}
    for i = 1, #vec do out[i] = vec[i] - mean[i] end
    return out
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

-- {{{ local function compute_color_ranking
-- Issue 8-050a: Rank EVERY palette color for a word by cosine similarity, strongest
-- first. ranking[1] is the word's semantic color (same as the old "nearest color").
-- Storing the whole ranking -- not just the winner -- is cheap and future-proof: the
-- word cloud reads it to pick each large word's strongest NON-gray color (large
-- words must never render gray, which is reserved for the de-emphasised small ones)
-- without recomputing embeddings, and the rest is there if a later feature wants it.
-- Returns an array of { color = name, similarity = sim }, sorted descending.
local function compute_color_ranking(word_embedding, color_embeddings)
    if not word_embedding or not color_embeddings then
        return {}
    end

    local ranking = {}
    for color_name, color_embedding in pairs(color_embeddings) do
        ranking[#ranking + 1] = {
            color = color_name,
            similarity = cosine_similarity(word_embedding, color_embedding),
        }
    end
    table.sort(ranking, function(a, b) return a.similarity > b.similarity end)
    return ranking
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
        -- Hard error, not a silent skip (author's call): the color embeddings are
        -- produced by the semantic-color stage and MUST exist by the time word
        -- colors are computed. Skipping just shipped colorless words while hiding
        -- a real upstream problem (e.g. the cache written to a path this reader
        -- does not look at -- see the CACHE_IN_RAM desync, Issue 10-054).
        error("word color computation needs color embeddings, but "
            .. utils.embeddings_dir() .. "/color_embeddings.json was not found. "
            .. "The semantic-color stage must run before this AND must write where "
            .. "this reads. (Poem coloring regenerates them when absent; word "
            .. "coloring could be unified to do the same instead of erroring.)")
    end

    local word_colors = {}
    local count = 0
    for word, embedding in pairs(word_embeddings) do
        local ranking = compute_color_ranking(embedding, color_embeddings)
        -- ranking[1] is the winner (gray is a valid winner here -- the word pages and
        -- other consumers keep using `color`). The full ranking rides along in
        -- `colors` so the word cloud can choose a non-gray color for large words.
        local best = ranking[1] or { color = "gray", similarity = 0 }
        table.insert(word_colors, {
            word = word,
            color = best.color,
            similarity = best.similarity,
            colors = ranking
        })
        count = count + 1
    end

    -- Sort by word for consistent output
    table.sort(word_colors, function(a, b) return a.word < b.word end)

    utils.log_info(string.format("Computed semantic colors for %d words", count))
    return word_colors
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
-- Keyed by poem_index -- the GLOBAL identifier -- never by id.
--
-- `id` restarts at 1 inside every source category, so five poems share id=1
-- (bluesky/1, fediverse/48, fediverse_boost/6025, messages/6483, notes/8041).
-- Keying on it did two silent kinds of damage: last-write-wins threw away 2,418
-- of 8,415 embeddings, and the survivors were then read back through a table
-- keyed on poem_index, so each score was printed against a DIFFERENT poem than
-- the one it was computed from. A word page for "linux" led with a poem about
-- publishing etiquette because it had inherited poem 7421's score -- 7421 being
-- "oh see yeah now it's running on linux", the true second-best match.
--
-- The damage was invisible because a collision looks exactly like a hit: no nil,
-- no warning, a full page of plausible poems in descending score order. It also
-- capped the reachable corpus at the largest id (6458), so `messages` and
-- `notes` could never appear on any word page at all -- 2,662 of 8,510 poems
-- were all the word cloud could ever show.
--
-- See Issue 8-019, which established poem_index for exactly this reason.
local function build_poem_embeddings_lookup(embeddings_data)
    local lookup = {}
    if not embeddings_data or not embeddings_data.embeddings then
        return lookup
    end

    local skipped = 0
    for _, entry in ipairs(embeddings_data.embeddings) do
        if entry.poem_index and entry.embedding then
            lookup[tostring(entry.poem_index)] = entry.embedding
        else
            -- An embedding with no poem_index cannot be attached to a poem at
            -- all. Count it and say so rather than dropping it quietly -- the
            -- quiet drop is what hid the collision bug for as long as it did.
            skipped = skipped + 1
        end
    end
    if skipped > 0 then
        utils.log_warn(string.format(
            "%d embeddings had no poem_index and were skipped -- regenerate embeddings (Issue 8-019)",
            skipped))
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
    local base_path = ".."
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

    -- Which source file this poem came from, shown above every entry so a reader
    -- can find the original. Computed HERE, above the boost branch, because that
    -- branch returns early -- when this lived further down, boosts on word pages
    -- came out with no source line at all while every other page type had one.
    -- Format: " -> file: fediverse/1234" or " -> file: notes/myfile".
    local category = poem.category or "unknown"
    local filename
    if category == "notes" and poem.metadata and poem.metadata.source_file then
        filename = poem.metadata.source_file
    else
        filename = tostring(poem.id or "unknown")
    end
    local poem_identifier = " -> file: " .. category .. "/" .. filename

    -- A boost is a reshared post, and it gets its own nested frame: red arrows
    -- into the corners, a blue outer wall, a teal inner box, the borrowed text in
    -- yellow (Issue 8-057). Word pages used to skip this entirely -- this file
    -- contained no mention of boosts at all -- so a reshare rendered as an
    -- ordinary poem showing the raw "External post: <url>" placeholder, with the
    -- URL not even clickable, while the same poem on a chronological page showed
    -- the framed, cached content. The frame is drawn by the shared module rather
    -- than redrawn here, which is the whole point of that module existing:
    -- three hand-copied versions had already drifted into misaligned walls.
    if poem.metadata and poem.metadata.is_boost then
        local text = (poem.content or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")

        -- An empty boost means the scrape never captured the original. Say which
        -- post is missing rather than printing an empty frame.
        if text == "" or text:match("^%s*$") then
            local original_uri = poem.metadata.original_uri
            if original_uri then
                text = "External post: " .. original_uri:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
            else
                text = "(Boost content unavailable)"
            end
        end

        -- An uncached boost is just a link. Wrap it ACROSS the box lines with
        -- every line anchored to the whole URL, so a long address stays inside
        -- the frame and stays clickable instead of overflowing the right wall.
        local external_url = text:match("^External post: (https?://[^%s]+)$")
        if external_url then
            text = text_formatter.wrap_external_url(
                "External post: ", external_url, boost_bars.CONTENT_WIDTH)
        else
            local rewrapped = {}
            for line in (text .. "\n"):gmatch("(.-)\n") do
                for _, w in ipairs(text_formatter.wrap_preserving_indent(line, boost_bars.CONTENT_WIDTH)) do
                    table.insert(rewrapped, w)
                end
            end
            text = table.concat(rewrapped, "\n")
        end

        local boost_lines = {}
        for line in (text .. "\n"):gmatch("(.-)\n") do
            table.insert(boost_lines, line)
        end

        boost_bars.configure(flat_html.BOOST_COLOR_CONFIG)
        -- Source line first, then the frame -- the same order the chronological
        -- pages use, so a boost reads identically wherever it is encountered.
        return poem_identifier .. "\n" .. boost_bars.format_boost(
            boost_lines, progress_pct / 100,
            similar_link, different_link, chrono_link, true) .. "\n"
    end

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
    local base_path = ".."
    local chrono_link = chrono_center_link or (base_path .. "/chronological/index.html")

    -- Generate HTML.
    -- The <head> -- charset, mobile viewport, shipped monospace font, text-size
    -- lock -- comes from the shared page-head module, so this page cannot drift
    -- away from the similar/different/chronological pages the way it had.
    -- Same centering CSS those pages use: each <pre> centers as an inline-block
    -- (text stays left), so the poem column lands on the page centerline even
    -- when an attached image is wider.
    local head = page_head.head({
        title = "Poems similar to: " .. word,
        base_path = base_path,
        extra_css = "td { text-align: center; } pre { display: inline-block; text-align: left; margin: 0 auto; }\n"
                 .. "img, video, audio { margin-left: auto; margin-right: auto; }",
    })
    local html_parts = {}
    table.insert(html_parts, string.format([[<!DOCTYPE html>
<html>
%s
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
]], head, header_color, word, #top_poems, base_path, chrono_link))

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
        -- Issue 10-065: this is minutes of network round trips with nothing on
        -- screen -- the longest silent stretch in the pipeline. The batch
        -- embedder now takes a progress callback, invoked once per request, so
        -- the wait has a bar like every other stage. Throttling is unnecessary
        -- here: a callback fires per REQUEST (dozens to hundreds of words each),
        -- not per word, so the redraw rate is already low.
        local vectors = fuzzy.embed_texts_with_chunking(missing, CONFIG.model_name, {
            endpoint = endpoint,
            format_fn = inference_config.format_embedding_prompt,
            on_progress = function(done, total)
                progress.update("   🔡 Word embeddings", done, total)
            end
        })
        progress.finish()
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

    -- The direction every embedding shares, subtracted before any comparison.
    --
    -- The model does not spread its output over the whole sphere. Measured on
    -- this corpus, the average of all poem vectors has length 0.827 while the
    -- vectors themselves have length 1.0 -- so about 83% of every poem vector is
    -- one direction common to all of them, and cosine similarity spends most of
    -- its resolution measuring that shared part instead of the meaning. It is a
    -- property of the model, not of these poems: single dictionary words carry
    -- an even stronger shared component (0.947), and the mean directions of the
    -- poems, the single words and the colour anchors all agree to cosine 0.94+.
    --
    -- Poem-against-poem comparison survives it, because the offset is near
    -- constant WITHIN one population and shifts every score alike. Word-against-
    -- poem does not: the word side carries 0.947 and the poem side 0.827, so the
    -- offset differs across the comparison and distorts the ordering. That is
    -- why this correction lives here and not in the similar/different pages.
    --
    -- Effect on poems that literally contain their word: ranks 1601 -> 59,
    -- 3795 -> 151, 7015 -> 347. Score spread widens from 0.090 to 0.164.
    local corpus_mean = compute_corpus_mean(poem_lookup)

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

    -- No colour embeddings are loaded here any more. Poem colours are READ from
    -- poem_colors.json above, already z-scored; re-deriving them from the anchors
    -- at display time is what let this page disagree with its own progress bars.
    -- The anchors are still loaded where they belong -- by the routine that
    -- assigns each WORD its colour, which has no precomputed table to read from.

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
        -- Issue 10-065: update OUTSIDE the has-an-embedding test below, so the
        -- bar tracks position in the word list rather than only the words that
        -- happened to produce a page -- otherwise it stalls silently through any
        -- run of words with no embedding.
        --
        -- Replaces a hand-rolled io.write("\r...") that bypassed this library.
        -- Three things were wrong with that. It emitted NO newlines, so under
        -- --debug -- where stdout is a pipe to scripts/fsync-logger, which reads
        -- line by line -- a whole run's progress accumulated into one enormous
        -- unterminated line instead of the durable per-line history --debug
        -- exists to produce. It drew unconditionally when piped, where every
        -- other stage stays quiet. And it looked nothing like the other bars.
        local step = (progress.mode() == 2) and 100 or 25
        if i % step == 0 or i == #words then
            progress.update("   🔤 Word pages", i, #words, word)
        end

        local word_embedding = word_embeddings[word]
        if word_embedding then

            -- Rank every poem against the word, both sides mean-centered so the
            -- shared direction described above cannot outvote the meaning.
            local centered_word = centered(word_embedding, corpus_mean)
            local candidates = {}
            for poem_index_str, poem_embedding in pairs(poem_lookup) do
                local poem_index = tonumber(poem_index_str)
                local poem = poems_by_index[poem_index]
                if poem and poem_embedding then
                    local word_sim = cosine_similarity(
                        centered_word, centered(poem_embedding, corpus_mean))
                    table.insert(candidates, {
                        poem = poem,
                        embedding = poem_embedding,
                        word_similarity = word_sim,
                        similarity = word_sim  -- for generate_word_page compatibility
                    })
                end
            end

            -- Sorted by similarity, and SHOWN in that order.
            --
            -- A colour round-robin used to reorder the top N here (Issue 8-050b)
            -- to spread the seven semantic colours down the page. It is gone, for
            -- two reasons.
            --
            -- One: it made the page disagree with its own heading. The reader was
            -- told "ranked by semantic similarity" and shown the 53rd-best match
            -- in slot 3 and the 251st in slot 8, while the second-best waited
            -- until slot 10.
            --
            -- Two: the colours it sorted on were not the site's colours. It
            -- re-derived each poem's colour by nearest raw cosine to the colour
            -- anchors, while poem_colors.json -- which draws the very progress
            -- bars on this page -- holds a z-scored, hubness-corrected verdict.
            -- The two disagreed on a third of the page. Raw nearness is not a
            -- contest about meaning: ranking the seven anchors by closeness to
            -- the AVERAGE poem reproduces their win rates almost exactly
            -- (purple sits nearest and takes 30.9% of the corpus, orange sits
            -- furthest and takes 3.9%), so the round-robin was spreading the
            -- page across a measurement of genericness.
            --
            -- The colour variety survives without it: each poem's bar is still
            -- drawn in its own stored colour, and that colour is now the same one
            -- the rest of the site uses.
            table.sort(candidates, function(a, b)
                return a.word_similarity > b.word_similarity
            end)
            local ranked_poems = candidates

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
                        local base_path = ".."
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
    -- Close the animated line. progress.finish() is a no-op in verbose and quiet
    -- modes, unlike the bare print("") this replaced, which emitted a stray blank
    -- line into every piped log.
    progress.finish()

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
