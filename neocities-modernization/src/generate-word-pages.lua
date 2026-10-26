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
--   --words N           Set maximum words to process
--   --yes, -y           Take config.lua's default for any value not given
--
-- Issue 10-065a: a value left off the command line is asked for, with
-- config.lua's default in brackets; Enter takes it. Started by run.sh, or with
-- nobody at the keyboard, a missing value is an error instead.
--
-- Usage:
--   luajit src/generate-word-pages.lua [DIR] [--embeddings-only|--html-only] [--all|--words N]
--   luajit src/generate-word-pages.lua --help
-- }}}

-- --help: print the header above and exit, when run as a program (libs/script-help.lua)
dofile((debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./") .. "../libs/script-help.lua").handle_if_run(arg, debug.getinfo(1, "S").source:sub(2))

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
    local max_words = nil  -- nil means not given: asked for, or --yes (Issue 10-065a)
    local poems_per_page = nil  -- Issue 8-050d; nil means not given: asked for, or --yes (10-065a)
    local chrono_per_page = nil  -- nil means fall back to config (never a literal)
    -- Which embedding space to read. nil means "whatever run.sh's notepad or
    -- config.lua says"; a value here overrides both (see the --model branch).
    local model = nil
    local server = nil
    local threads = nil  -- Issue 10-035: page workers; nil means not given: asked for
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
        -- Issue 10-065, same trap as --dir above: these take a VALUE, and the
        -- branch below claims any token not starting with "-" as the project
        -- directory. Left unconsumed, `--model embeddinggemma-300m` made
        -- "embeddinggemma-300m" the project root; package.path was built from it
        -- and the script died unable to find its own JSON library.
        --
        -- They are HONOURED, not merely swallowed. Under run.sh the choice
        -- arrives on the shared notepad in RAM and this stage reads it there, but
        -- that notepad lives in /tmp and does not survive a reboot -- so a
        -- standalone run afterwards silently resolves config.lua's default
        -- instead, which on this project is a different model with a months-old
        -- embeddings file. Accepting the flag and ignoring it would leave the
        -- operator no way to say which model they meant.
        elseif a == "--model" then
            model = args[i + 1]; i = i + 2
        elseif a:match("^%-%-model=") then
            model = a:match("^%-%-model=(.+)$"); i = i + 1
        elseif a == "--threads" then
            threads = tonumber(args[i + 1]); i = i + 2
        elseif a == "--server" then
            server = args[i + 1]; i = i + 2
        elseif a:match("^%-%-server=") then
            server = a:match("^%-%-server=(.+)$"); i = i + 1
        elseif a:sub(1, 1) ~= "-" then
            dir = a
            i = i + 1
        else
            -- Skip unknown flags (value-less ones; a flag that TAKES a value
            -- needs its own branch above, or its value lands in `dir`).
            i = i + 1
        end
    end

    return dir, mode, all_words, max_words, poems_per_page, chrono_per_page, model, server, threads
end
-- }}}

local parsed_dir, RUN_MODE, CLI_ALL_WORDS, CLI_MAX_WORDS, CLI_POEMS_PER_PAGE, CLI_CHRONO_PER_PAGE,
      CLI_MODEL, CLI_SERVER, CLI_THREADS = parse_args(arg)
local DIR = setup_dir_path(parsed_dir)
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. DIR .. "/libs/vulkan-compute/lua/?.lua;" .. package.path

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
-- Issue 10-065: the shared progress renderer, so this stage's bar obeys the same
-- rules as every other stage's -- animated on a TTY, newline-terminated lines
-- under --debug, silent when piped. It used to hand-roll a "\r" line instead;
-- see the loop below for what that cost.
local progress = require("progress-display")
-- Shared chronological mapping (sort order + page numbers + timeline progress).
-- Reused here so the word-page "chronological" links resolve to the SAME page
-- and anchor the chronological pages actually emit (Issue 10-049 follow-up).
local flat_html = require("flat-html-generator")
-- How the chronological pages name their files, so a link from here lands
-- on the page that holds the poem. (The pages themselves are drawn by the
-- page workers through src/word-page.lua, Issue 10-035.)
local chronological_page = require("chronological-page")
-- How this project prepares vectors before comparing them, and the note that
-- says which preparation a cache was built with (libs/embedding-space.lua).
local embedding_space = require("embedding-space")

utils.init_assets_root(arg)
-- }}}

local M = {}

-- {{{ Configuration
local wc = unified_config.word_cloud or error("config.lua has no word_cloud section")
-- Issue 10-065a: a value missing from the command line is asked for (config.lua's
-- value offered in brackets), taken from config.lua with a notice under --yes,
-- or an error when run.sh started this program or nobody is at the keyboard.
-- Each is settled where it is first USED, not at load: stage 6 runs this
-- program in --embeddings-only mode, which never needs a page size, and must
-- not stop to ask for one; --help must not ask anything either.
local ask = require("ask-for-value")
local ACCEPT_DEFAULTS = ask.wants_defaults(arg)
-- Declared here, filled in below: the settle functions that follow must refer
-- to this same table (a later `local CONFIG` would be a different variable to
-- them, and they would write into an undefined global instead).
local CONFIG

-- {{{ settle_word_count()
-- How many words get pages: --all / --words, else asked. Both modes need it
-- (the embeddings and the pages must cover the same words). Settled once.
local function settle_word_count()
    if CONFIG.max_words then
        return CONFIG.max_words
    end
    local answer = ask.resolve({
        flag = "--words",
        question = "How many words get word pages? (a number, or \"all\")",
        kind = "count_or_all",
        given = CLI_ALL_WORDS and "all" or CLI_MAX_WORDS,
        default = wc.max_words,
        default_source = "config.lua word_cloud.max_words",
        accept_defaults = ACCEPT_DEFAULTS,
    })
    -- "all" means no limit
    CONFIG.max_words = (answer == "all") and math.huge or answer
    return CONFIG.max_words
end
-- }}}

-- {{{ settle_threads()
-- Issue 10-035: how many page workers draw the word pages: --threads, else
-- asked (no default: run.sh passes the build's one thread count). Only the
-- page-writing mode needs it. Settled once.
local settled_threads = nil
local function settle_threads()
    if settled_threads then
        return settled_threads
    end
    settled_threads = ask.resolve({
        flag = "--threads",
        question = "How many worker threads?",
        kind = "count",
        given = CLI_THREADS,
        default = nil,
        default_source = nil,
        accept_defaults = ACCEPT_DEFAULTS,
    })
    return settled_threads
end
-- }}}

-- {{{ settle_poems_per_page()
-- Issue 8-050d: poems listed on each word page: --poems-per-page, else asked.
-- Only the page-writing mode needs it. Settled once.
local function settle_poems_per_page()
    if CONFIG.poems_per_word_page then
        return CONFIG.poems_per_word_page
    end
    CONFIG.poems_per_word_page = ask.resolve({
        flag = "--poems-per-page",
        question = "How many poems on each word page?",
        kind = "count",
        given = CLI_POEMS_PER_PAGE,
        default = wc.poems_per_page,
        default_source = "config.lua word_cloud.poems_per_page",
        accept_defaults = ACCEPT_DEFAULTS,
    })
    return CONFIG.poems_per_word_page
end
-- }}}

-- {{{ resolve_chrono_per_page()
-- Chronological page size for the "chronological" poem links: the build's
-- --chrono-per-page, else asked with the config value offered. Never a literal
-- -- a wrong size sends every link to the wrong page (Issue 10-036). Settled once.
local settled_chrono_per_page = nil
local function resolve_chrono_per_page()
    if settled_chrono_per_page then
        return settled_chrono_per_page
    end
    -- the config value is the offered default; a config without one offers none
    local has_default, config_default = pcall(flat_html.default_chrono_per_page)
    settled_chrono_per_page = ask.resolve({
        flag = "--chrono-per-page",
        question = "How many poems per chronological page?",
        kind = "count",
        given = CLI_CHRONO_PER_PAGE,
        default = has_default and config_default or nil,
        default_source = "config.lua pagination.chronological_poems_per_page",
        accept_defaults = ACCEPT_DEFAULTS,
    })
    return settled_chrono_per_page
end
-- }}}

-- The model name lives in config.lua / --server / --model. Resolving it
-- here through inference-server-config means a model swap propagates to this script
-- automatically; we no longer need to remember to update a hardcoded string.
inference_config.set_project_root(DIR)
-- A --server/--model typed on THIS command wins over the run notepad and over
-- config.lua, in that order of authority. Applied before anything asks which
-- model is selected, because embeddings_dir() is derived from that answer and a
-- late change would leave earlier readers pointing at a different directory.
if CLI_SERVER then inference_config.set_selected_server(CLI_SERVER) end
if CLI_MODEL then inference_config.set_selected_model(CLI_MODEL) end
CONFIG = {
    model_name = inference_config.get_selected_model(),
    max_poems_per_page = 100,        -- Poems per word page
    max_pages_per_word = 1,          -- For now, just one page per word
    word_embeddings_file = "word_embeddings.json",
    -- Issue 10-065a: these two start unset and are filled by settle_word_count()
    -- and settle_poems_per_page() when the mode that needs them begins
    poems_per_word_page = nil,
    max_words = nil,
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

-- {{{ local function ordered_keys
-- A table's keys in a fixed order: numbers (and number-like strings such as
-- "17") by value, then anything else by its text. Every walk whose order can
-- change a page goes through this. A plain pairs() walk visits keys in hash
-- order, which differs from one run to the next, and it changed pages two
-- ways: two identical posts tie on similarity and the sort kept whichever came
-- first, and the averages subtracted before comparing were summed in a
-- different order each run, so their last decimals moved and near-ties
-- flipped. The same code drew 13 of 60 word pages differently on two runs
-- (found 2026-10-21, Issue 8-058's before/after check).
local function ordered_keys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local na, nb = tonumber(a), tonumber(b)
        if na and nb then
            if na ~= nb then return na < nb end
            return tostring(a) < tostring(b)
        end
        if na or nb then return na ~= nil end  -- numbers before words
        return tostring(a) < tostring(b)
    end)
    return keys
end
-- }}}

-- {{{ local function more_similar_first
-- The ranking order for word-page candidates: higher similarity first; equal
-- similarity (two copies of one post) by poem number, so a tie is decided the
-- same way every run.
local function more_similar_first(a, b)
    if a.word_similarity ~= b.word_similarity then
        return a.word_similarity > b.word_similarity
    end
    return a.poem.poem_index < b.poem.poem_index
end
-- }}}

-- {{{ local function shortlist
-- Which poems to score exactly for one word, from the GPU's single-precision
-- scores (Issue 10-035). Keeps every poem whose GPU score is within MARGIN
-- of the keep-th best GPU score. A GPU score differs from the exact one by
-- about a millionth (libs/vk-cross.test.lua), far less than half the margin,
-- so every poem that belongs in the exact top `keep` -- ties included -- is
-- kept, and the page is the same as scoring every poem exactly.
-- score_of(r) : the GPU score of candidate r, r = 1..count
-- returns     : list of candidate numbers r, ascending
local SHORTLIST_MARGIN = 1e-4
local function shortlist(score_of, count, keep)
    local rows = {}
    if keep >= count then
        for r = 1, count do rows[r] = r end
        return rows
    end
    local sorted = {}
    for r = 1, count do sorted[r] = score_of(r) end
    table.sort(sorted)                                   -- ascending
    local threshold = sorted[count - keep + 1] - SHORTLIST_MARGIN
    for r = 1, count do
        if score_of(r) >= threshold then rows[#rows + 1] = r end
    end
    return rows
end
-- }}}

-- {{{ local function compute_corpus_mean
-- The direction every poem vector shares, from the shared module so that the
-- word pages, the similarity matrix and the diversity cache all subtract the
-- SAME thing. Three private copies of this arithmetic would be three chances to
-- drift, and a drift here is invisible: each page would still be complete and
-- ordered, just ordered against a slightly different centre.
--
-- Adapts the lookup (keyed by poem_index) into the array-of-records shape the
-- shared function takes, rather than duplicating the averaging.
local function compute_corpus_mean(poem_lookup)
    local entries = {}
    -- summed in poem order, so the average is the same to the last bit each run
    for _, key in ipairs(ordered_keys(poem_lookup)) do
        entries[#entries + 1] = { embedding = poem_lookup[key] }
    end
    local mean, detail = embedding_space.corpus_mean(entries)
    if not mean then
        -- detail carries the reason. The nil it returns then stops the ranking
        -- outright: cosine_across_populations refuses to compare without both
        -- averages rather than reverting to the uncentred measurement.
        utils.log_error("Could not centre the embedding space: " .. tostring(detail))
        return nil
    end
    return mean
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
    -- equal similarity: by colour name, so a tie goes the same way every run
    table.sort(ranking, function(a, b)
        if a.similarity ~= b.similarity then return a.similarity > b.similarity end
        return a.color < b.color
    end)
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

-- {{{ local function spread_colors_across_page
-- Rearranges an already-chosen, already-ranked list so the seven semantic
-- colours alternate down the page instead of arriving in clumps.
--
-- It does NOT choose who appears. The caller hands over exactly the top N by
-- similarity and gets back the same N; only their order changes. An earlier
-- version of this (Issue 8-050b) picked FROM a larger pool, which let colour
-- balancing displace strong matches with weaker colour-diverse ones -- a search
-- for "god" surfaced unrelated poems. Selection and presentation are kept apart
-- here for that reason.
--
-- The colour is READ from poem_colors.json, never recomputed. That table is
-- built from the colour ANCHORS -- each one the mean of a hand-written
-- association list (red = fire, blood, passion, rage...) rather than the bare
-- colour word -- and then z-scored, so a poem takes the colour it sits furthest
-- ABOVE that colour's baseline for. Both halves matter. Comparing against the
-- bare word "red" gives a generic point that swallows a third of everything
-- (config.lua records that experiment). And comparing without the z-score turns
-- the contest into a measurement of genericness rather than meaning: rank the
-- seven anchors by closeness to the AVERAGE poem and you have predicted their
-- raw win rates almost exactly -- on the model in use, purple sits nearest at
-- cosine 0.9242 and wins 48.2% of the corpus, red sits furthest at 0.8992 and
-- wins 4.3%. The stored z-scored verdict is even instead: 12.1% to 17.2%.
--
-- So: anchors from wordlists, standardised by z-score, computed once, read here.
--
-- Method: stratified spacing, not a round-robin. A round-robin deals one poem
-- per colour per cycle, which drains the small buckets first and leaves the tail
-- of the page a solid run of whatever colour was most plentiful. Instead each
-- colour's poems are spaced evenly across the FULL page length in proportion to
-- how many there are -- a colour holding 8 of 333 slots appears about every 42
-- positions, one holding 131 appears about every 2.5 -- so no colour clumps at
-- either end. Within a colour the more relevant poem still comes first.
local function spread_colors_across_page(ranked, poem_colors)
    local n = #ranked
    if n < 2 then return ranked end

    -- Bucket by stored colour, preserving the incoming (relevance) order.
    local buckets, order = {}, {}
    for _, entry in ipairs(ranked) do
        local idx = entry.poem and entry.poem.poem_index
        local stored = idx and poem_colors and poem_colors[idx]
        -- No stored colour means the bar renders gray, so bucket it as gray too;
        -- the two must agree or the page disperses on a colour nobody can see.
        local color = (stored and stored.color) or "gray"
        if not buckets[color] then
            buckets[color] = {}
            order[#order + 1] = color
        end
        table.insert(buckets[color], entry)
    end

    -- One colour only: spacing is a no-op, and doing the work would just risk
    -- perturbing an order that is already correct.
    if #order < 2 then return ranked end

    -- Give every poem a target position on a 0..n scale. The j-th of m poems in
    -- a colour lands at (j - 0.5) * n / m -- the midpoint of its share -- which
    -- is what spaces each colour evenly over the whole page regardless of m.
    local placed = {}
    for _, color in ipairs(order) do
        local bucket = buckets[color]
        local m = #bucket
        for j, entry in ipairs(bucket) do
            placed[#placed + 1] = {
                entry = entry,
                target = (j - 0.5) * n / m,
                -- Tie-break by relevance so that when two colours want the same
                -- slot, the better match takes it. Without this the winner would
                -- depend on table iteration order, which is not stable in Lua and
                -- would make two builds of the same data differ.
                rank = entry.word_similarity or 0,
                -- and when two are equally relevant (copies of one post), by
                -- poem number
                index = entry.poem.poem_index,
            }
        end
    end

    table.sort(placed, function(a, b)
        if a.target ~= b.target then return a.target < b.target end
        if a.rank ~= b.rank then return a.rank > b.rank end
        return a.index < b.index
    end)

    local out = {}
    for i, p in ipairs(placed) do out[i] = p.entry end
    return out
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
-- Issue 8-050e: the poem whose (raw) vector is closest to the centroid, the
-- page's link into the timeline.
-- prepared_poems: the run's candidate list, in poem order, each row carrying
--   its raw vector (embedding) and that vector's sum of squares (raw_sq),
--   worked out once per run (Issue 10-035: the lengths and the key order used
--   to be redone for every word). Only poems can win; a picture's stand-in
--   vector is not a candidate, since it has no chronological place to link.
-- The arithmetic is cosine_similarity's, in the same order, so the result is
-- the same to the last bit; on a tie the lowest poem number stays the best.
local function find_closest_poem_to_centroid(centroid, prepared_poems)
    local best_poem = nil
    local best_similarity = -1
    local dim = #centroid
    for _, row in ipairs(prepared_poems) do
        local emb = row.embedding
        local sim = 0
        if #emb == dim then
            local dot, n1 = 0, 0
            for i = 1, dim do
                dot = dot + (centroid[i] * emb[i])
                n1 = n1 + (centroid[i] * centroid[i])
            end
            local norm1, norm2 = math.sqrt(n1), math.sqrt(row.raw_sq)
            if norm1 ~= 0 and norm2 ~= 0 then
                sim = dot / (norm1 * norm2)
            end
        end
        if sim > best_similarity then
            best_similarity = sim
            best_poem = row.poem
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
    local wc = unified_config.word_cloud or error("config.lua has no word_cloud section")
    -- optional: absent means no stop words beyond the built-in short-word rule
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

-- The order rules, for src/generate-word-pages.order.test.lua.
M.ordered_keys = ordered_keys
M.more_similar_first = more_similar_first
M.spread_colors_across_page = spread_colors_across_page
M.shortlist = shortlist

-- {{{ function M.generate_word_embeddings
-- Issue 8-043b: Stage 6 - Generate word embeddings only (expensive operation)
-- Called during embedding generation stage of the pipeline
function M.generate_word_embeddings(options)
    options = options or {}
    -- Issue 10-065a: the word list needs its size before anything else
    settle_word_count()

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
    -- Issue 10-065a: settle every value this mode uses before any work starts,
    -- so a question never interrupts a half-finished run
    settle_word_count()
    settle_poems_per_page()
    resolve_chrono_per_page()
    local num_threads = settle_threads()
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

    -- {{{ Issue 8-019: the vectors and colours must be in this run's numbering
    -- Both are filed by poem number, and numbers are counted fresh on every
    -- extraction; one made under another numbering would put the wrong
    -- poems on a word's page. Stop if either differs from the poem list.
    -- Checked on a build (options.check_numbering, set by main()); a trial
    -- render (scripts/render-page-sample) draws from whatever caches exist.
    if options.check_numbering then
        local numbering_stamp = require("numbering-stamp")
        local numbering = numbering_stamp.of_poems(poems_data)
        if numbering_stamp.of_embeddings(embeddings_data) ~= numbering then
            error("embeddings.json was made under another numbering of the poems; rerun stage 6 (--force-stage 6)")
        end
        numbering_stamp.check(utils.embeddings_dir() .. "/poem_colors.json", numbering, "poem colours", "stage 6 (--force-stage 6)")
    end
    -- }}}

    -- The direction every embedding shares, subtracted before any comparison.
    --
    -- The model does not spread its output over the whole sphere. Measured on
    -- the selected model (nomic-embed-text-v1.5), the average of all poem vectors
    -- has length 0.766 while the vectors themselves have length 1.0 -- so roughly
    -- three quarters of every poem vector is one direction common to all of them,
    -- and cosine similarity spends most of its resolution measuring that shared
    -- part instead of the meaning.
    --
    -- It is a property of the model, not of these poems: isolated dictionary
    -- words carry a STRONGER shared component than the poems do (0.829), and the
    -- mean direction of the words agrees with the mean direction of the poems to
    -- cosine 0.940 despite being an entirely different population of text.
    --
    -- Poem-against-poem comparison survives it, because the offset is near
    -- constant WITHIN one population and shifts every score alike. Word-against-
    -- poem does not: the word side carries 0.829 and the poem side 0.766, so the
    -- offset differs across the comparison and distorts the ordering. That is
    -- why this correction lives here and not in the similar/different pages.
    --
    -- Re-measure with scripts/measure-embedding-spread after any model change --
    -- these numbers are properties of the model in use, and the first set taken
    -- for this comment came from a directory that was not the selected model.
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

    -- The words' own average, subtracted from each word before ranking (the
    -- poems are centred on theirs). A lone word sits at a different offset from
    -- the poems; centring it on the poem average left that difference in every
    -- word and sent all 7,290 pages to the same short posts. See
    -- cosine_across_populations in libs/embedding-space.lua.
    local word_entries = {}
    -- summed in word order, so the average is the same to the last bit each run
    for _, word in ipairs(ordered_keys(word_embeddings)) do
        word_entries[#word_entries + 1] = { embedding = word_embeddings[word] }
    end
    local word_mean, word_mean_detail = embedding_space.corpus_mean(word_entries)
    if not word_mean then
        -- Refused rather than degraded: without it every word page reverts to
        -- the one-offset ranking this replaced, and still looks complete.
        error("Could not average the word embeddings: " .. tostring(word_mean_detail))
    end

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
    -- No colours, no pages: the other pages stop the same way. (This used
    -- to warn and draw every poem grey, a page that looks finished.)
    if not (poem_colors_data and poem_colors_data.poem_colors) then
        error("no poem colours in " .. poem_colors_file)
    end
    local poem_colors = poem_colors_data.poem_colors

    -- Issue 8-050a: Load word colors for per-word semantic coloring
    local word_colors = load_word_colors_cache()
    local word_color_count = 0
    for _ in pairs(word_colors) do word_color_count = word_color_count + 1 end
    -- No word colours, no pages: every heading would be grey. They come from
    -- the word-cloud stage (--embeddings-only).
    if word_color_count == 0 then
        error("no word colours found; run the word-cloud stage (--embeddings-only) first")
    end

    -- No colour embeddings are loaded here any more. Poem colours are READ from
    -- poem_colors.json above, already z-scored; re-deriving them from the anchors
    -- at display time is what let this page disagree with its own progress bars.
    -- The anchors are still loaded where they belong -- by the routine that
    -- assigns each WORD its colour, which has no precomputed table to read from.

    -- Issue 8-043c: Load color configuration from unified config
    -- The site's one palette, shared with the chronological and
    -- similar/different pages and derived there from config.lua's
    -- semantic_colors. This page used to keep its own copy, and that copy listed
    -- a generic spectrum -- red, orange, yellow, green, cyan, blue, indigo,
    -- violet, gray -- rather than the seven names the colour calculator actually
    -- assigns. "purple" was missing entirely, so every purple poem rendered in a
    -- hardcoded off-palette grey; purple is the biggest bucket in the stored
    -- distribution, so that was about one poem in six. The others rendered in
    -- hexes no other page type used.
    local color_config = flat_html.COLOR_CONFIG

    -- Issue 8-043c: Compute chronological mapping for progress bars
    -- This maps poem_index → {position, total_poems} for timeline orientation
    -- Issue 8-050e: the page number also gives the centroid-based link
    local chrono_map = {}
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
                -- which chronological page holds it, and how many there are
                -- (chronological_page.file_name turns these into "03.html")
                page_number = info.page_number,
                total_pages = info.total_pages,
            }
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

    -- Every poem that can appear on a word page, centred on the poem average
    -- once for the whole run, in poem order (Issue 10-035: it used to be
    -- re-centred for every word). A vector with no poem in poems.json (a
    -- gallery picture's stand-in) is not a candidate.
    local prepared_poems = {}
    for _, poem_index_str in ipairs(ordered_keys(poem_lookup)) do
        local poem = poems_by_index[tonumber(poem_index_str)]
        local poem_embedding = poem_lookup[poem_index_str]
        if poem and poem_embedding then
            local raw_sq = 0
            for i = 1, #poem_embedding do
                raw_sq = raw_sq + (poem_embedding[i] * poem_embedding[i])
            end
            prepared_poems[#prepared_poems + 1] = {
                poem = poem,
                embedding = poem_embedding,
                raw_sq = raw_sq,  -- for the centre-poem search
                prepared = embedding_space.centre_once(poem_embedding, corpus_mean),
            }
        end
    end

    -- Get word list (same as embedding generation to ensure consistency)
    local stop_words = load_stop_words()
    local words = get_word_list(poems_data, stop_words, 5, CONFIG.max_words, 3)

    -- Generate pages for each word
    -- Each word's page is planned here (which poems, in which order, the
    -- heading colour, the centre link) and drawn by the page workers, the
    -- same pool that draws every other page (Issue 10-035).
    local jobs = {}

    -- {{{ every word against every poem, at once, on the GPU (Issue 10-035)
    -- Each word centred on the word average once; the GPU scores all words
    -- against all prepared poems in one dispatch. Each word then scores
    -- only its shortlist exactly (see shortlist).
    local prepared_words = {}
    for i, word in ipairs(words) do
        local word_embedding = word_embeddings[word]
        if not word_embedding then
            -- The word list and the word embeddings come from the same
            -- settings (--words, the stop list); a word without a vector means
            -- the embeddings were made for a different list. Stop rather than
            -- ship a word cloud whose words lead nowhere (it used to warn and
            -- skip the word).
            error(string.format("word page: no embedding for word '%s'; rerun the word-cloud stage (--embeddings-only) with the same --words", word))
        end
        prepared_words[i] = embedding_space.centre_once(word_embedding, word_mean)
    end
    local gpu_score
    do
        local a, b = {}, {}
        for i, w in ipairs(prepared_words) do a[i] = w.v end
        for r, row in ipairs(prepared_poems) do b[r] = row.prepared.v end
        gpu_score = require("vk_cross").cosine_table(DIR, a, b)
        utils.log_info(string.format("Scored %d words against %d poems on the GPU", #a, #b))
    end
    -- }}}

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

        do

            -- Rank every poem against the word, each centred on its own
            -- population's average so neither kind of text's habitual offset
            -- can outvote the meaning. Both were centred once, above; the
            -- GPU's scores pick the shortlist, scored here exactly.
            local word_prepared = prepared_words[i]
            local candidates = {}
            local rows = shortlist(function(r) return gpu_score(i, r) end,
                #prepared_poems, CONFIG.poems_per_word_page)
            for k, r in ipairs(rows) do
                local row = prepared_poems[r]
                local word_sim = embedding_space.cosine_centred(word_prepared, row.prepared)
                candidates[k] = {
                    poem = row.poem,
                    embedding = row.embedding,
                    word_similarity = word_sim,
                }
            end

            -- Most relevant first, then spread the colours across that page.
            --
            -- The selection is pure relevance: the top N by similarity, nothing
            -- displaced. Only the ORDER of those N is rearranged, so that walking
            -- down the page shows a changing colour rather than a long run of one.
            -- This is a word-page treatment only; the similar/different pages
            -- deliberately stay in strict similarity order.
            table.sort(candidates, more_similar_first)
            local top_n = {}
            for j = 1, math.min(#candidates, CONFIG.poems_per_word_page) do
                top_n[j] = candidates[j]
            end
            local ranked_poems = spread_colors_across_page(top_n, poem_colors)

            -- Issue 8-050c: Get word's semantic color for header
            -- A word with no colour recorded, or a colour the palette lacks,
            -- stops the build: the word-colour cache is older than the word
            -- list (rerun the word-cloud stage, --embeddings-only). It used to
            -- draw the heading in a grey outside the palette.
            local word_color_entry = word_colors[word]
                or error("word page: '" .. word .. "' has no colour in word_colors.json; run the word-cloud stage (--embeddings-only)")
            local word_hex_color = color_config[word_color_entry.color]
                or error("word page: '" .. word .. "' has colour '" .. tostring(word_color_entry.color) .. "', which config.lua's palette lacks")

            -- Issue 8-050e: the page's link into the timeline, at the poem
            -- nearest the centre of the page's poems. Every page has poems with
            -- vectors, so there is always a centre and a nearest poem; a page
            -- without one stops the build (it used to link to the top of the
            -- chronological view instead).
            local chrono_center_link
            do
                local centroid = compute_centroid(ranked_poems, poem_lookup)
                    or error("word page: '" .. word .. "' has no poems with vectors to take a centre of")
                local center_poem = find_closest_poem_to_centroid(centroid, prepared_poems)
                    or error("word page: '" .. word .. "': no poem is nearest its centre")
                -- Anchor must match the spans the chronological pages emit:
                -- get_poem_anchor_id() = "poem-<poem_index>". The old
                -- "poem-CATEGORY-ID" form matched no anchor, so this top
                -- "chronological" link landed at the page top, not the poem.
                local anchor_id = require("poem-address").anchor(center_poem)  -- Issue 8-019
                -- The chronological page that holds it, named as those
                -- pages name themselves. Every poem is on the timeline;
                -- one that is not stops the build (10-036: a guessed
                -- page sent readers to the wrong place).
                local center_info = chrono_map[center_poem.poem_index]
                    or error("word page: centre poem " .. center_poem.poem_index .. " is not in the chronological map")
                chrono_center_link = string.format("../chronological/%s#%s",
                    chronological_page.file_name(center_info.page_number, center_info.total_pages), anchor_id)
            end

            -- The page's job: its first poems_per_word_page poems in this
            -- order, each with its place on the timeline (8-045) and the
            -- chronological page that holds it.
            local entries = {}
            for k = 1, math.min(CONFIG.poems_per_word_page, #ranked_poems) do
                local poem = ranked_poems[k].poem
                local index = poem.poem_index
                local info = chrono_map[index]
                if not info then
                    -- a poem with no place on the timeline has no bar and no page to link
                    error("word page: poem " .. tostring(index) .. " is not in the chronological map")
                end
                entries[k] = {
                    poem = poem,
                    progress_pct = info.timeline_progress,
                    chrono_file = chronological_page.file_name(info.page_number, info.total_pages),
                }
            end
            jobs[#jobs + 1] = {
                word = word,
                header_color = word_hex_color,
                centre_link = chrono_center_link,
                entries = entries,
            }
        end
    end
    -- Close the animated line. progress.finish() is a no-op in verbose and quiet
    -- modes, unlike the bare print("") this replaced, which emitted a stray blank
    -- line into every piped log.
    progress.finish()

    local pages_generated = flat_html.generate_word_pages_on_workers(jobs, output_dir, num_threads)
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
        return M.generate_word_html({ check_numbering = true })
    else
        return M.generate_word_pages({ check_numbering = true })
    end
end
-- }}}

-- {{{ Command line execution
if arg and #arg >= 0 and debug.getinfo(3) == nil then
    if RUN_MODE == "help" then
        require("output").print("Usage: luajit src/generate-word-pages.lua [DIR] [OPTIONS]")
        require("output").print("")
        require("output").print("Generates similarity pages for word cloud words.")
        require("output").print("For each word, creates a page showing poems ranked by semantic similarity.")
        require("output").print("")
        require("output").print("Options:")
        require("output").print("  DIR               Project directory (default: /mnt/mtwo/programming/ai-stuff/neocities-modernization)")
        require("output").print("  --embeddings-only Generate word embeddings only (Stage 6 - expensive)")
        require("output").print("  --html-only       Generate HTML pages only (Stage 9 - fast, requires embeddings)")
        require("output").print("  --all             Include all words (no max_words limit)")
        require("output").print("  --words N         Set maximum words to process (default: 200 from config)")
        require("output").print("  --yes, -y         Take config.lua's default for any value not given")
        require("output").print("  --help            Show this help message")
        require("output").print("")
        require("output").print("A value not given is asked for, with config.lua's default in brackets;")
        require("output").print("Enter takes it. Started by run.sh, or with no one at the keyboard, a")
        require("output").print("missing value is an error instead.")
        require("output").print("")
        require("output").print("Pipeline Integration (Issue 8-043b):")
        require("output").print("  Stage 6 (Embeddings): luajit src/generate-word-pages.lua --embeddings-only")
        require("output").print("  Stage 9 (HTML):       luajit src/generate-word-pages.lua --html-only")
        require("output").print("")
        require("output").print("Without flags, runs both stages (backward compatible).")
        os.exit(0)
    end

    -- start, end and any stopping error go to the run's log (Issue 10-075)
    require("output").guard("generate-word-pages.lua", M.main)
end
-- }}}

return M
