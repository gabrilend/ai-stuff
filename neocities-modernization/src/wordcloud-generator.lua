#!/usr/bin/env luajit

-- {{{ wordcloud-generator.lua
-- Issue 8-043: Generate semantic word cloud page
-- Extracts words from poems, filters stop words, and creates a visual word cloud
-- where font size represents word frequency (or optionally, centroid similarity)
--
-- Usage:
--   luajit src/wordcloud-generator.lua [DIR] [--all] [--words N]
--   luajit src/wordcloud-generator.lua --help
--
-- Options:
--   --all               Include all words (no max_words limit)
--   --words N           Set maximum words to display
--   --chrono-per-page N Poems per chronological page (for the poem links)
--   --yes, -y           Take the default for any value not given, without asking
--
-- Issue 10-065a: a value left off the command line is asked for, with its
-- default from config.lua in brackets ("How many words in the word cloud?
-- [200]"); Enter takes it. --yes takes every default and says which. Started by
-- run.sh, or with nobody at the keyboard, a missing value is an error instead.
-- }}}

-- {{{ Setup
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end

-- {{{ parse_args
-- Parse command line arguments for DIR and word cloud options
local function parse_args(args)
    local dir = nil
    local all_words = false
    local max_words = nil  -- nil means not given: asked for, or --yes (Issue 10-065a)
    local chrono_per_page = nil  -- nil means fall back to config (never to a literal)
    local seed = nil  -- Issue 10-058: master seed for the shuffle; nil => auto at startup
    -- Which embedding space to read the word colours from. nil defers to run.sh's
    -- notepad, then config.lua; a value here overrides both.
    local model = nil
    local server = nil
    local out = nil  -- --out FOLDER: a trial run (see the --help text)
    local i = 1
    while i <= #(args or {}) do
        local a = args[i]
        if a == "--out" then
            out = args[i + 1] or error("--out needs a folder")
            i = i + 2
        elseif a == "--all" then
            all_words = true
            i = i + 1
        elseif a == "--seed" then
            -- Issue 10-058: the build's master seed, threaded from run.sh so the
            -- word order is reproducible. Both "--seed N" and "--seed=N" forms.
            seed = tonumber(args[i + 1])
            i = i + 2
        elseif a:match("^--seed=") then
            seed = tonumber(a:match("^--seed=(.+)$"))
            i = i + 1
        elseif a == "--words" then
            -- Accept "all" as a synonym for --all (the two flags are combined).
            if args[i + 1] == "all" then all_words = true else max_words = tonumber(args[i + 1]) end
            i = i + 2
        elseif a:match("^--words=") then
            local v = a:match("^--words=(.+)$")
            if v == "all" then all_words = true else max_words = tonumber(v) end
            i = i + 1
        elseif a == "--chrono-per-page" then
            -- The chronological page size the SAME build used, threaded from
            -- run.sh so this separate process paginates poem links identically.
            chrono_per_page = tonumber(args[i + 1])
            i = i + 2
        elseif a:match("^--chrono%-per%-page=") then
            chrono_per_page = tonumber(a:match("=(.+)$"))
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
        -- Same trap as --dir above (Issue 10-065): these carry a VALUE, and the
        -- branch below claims any bare token as the project directory -- so an
        -- unconsumed model name became the project root and package.path was
        -- built from it. Consumed AND honoured: the run notepad that normally
        -- carries this choice lives in /tmp and does not survive a reboot, after
        -- which a standalone run silently resolves config.lua's default instead.
        elseif a == "--model" then
            model = args[i + 1]; i = i + 2
        elseif a:match("^%-%-model=") then
            model = a:match("^%-%-model=(.+)$"); i = i + 1
        elseif a == "--server" then
            server = args[i + 1]; i = i + 2
        elseif a:match("^%-%-server=") then
            server = a:match("^%-%-server=(.+)$"); i = i + 1
        elseif not a:match("^%-") then
            -- Positional argument (DIR)
            dir = a
            i = i + 1
        else
            -- Skip unknown flags (value-less ones; a flag that TAKES a value
            -- needs its own branch above, or its value lands in `dir`).
            i = i + 1
        end
    end
    return dir, all_words, max_words, chrono_per_page, seed, model, server, out
end
-- }}}

-- {{{ --help
-- Answered before anything else runs: the word count is settled at startup and
-- may ask a question (Issue 10-065a), which a request for help must not trigger.
-- Plain print, not the run log: help is for the person at the terminal, and
-- it runs before package.path can find libs/.
if arg[1] == "--help" or arg[1] == "-h" then
    print("Usage: luajit src/wordcloud-generator.lua [DIR] [--all] [--words N] [--chrono-per-page N] [--seed N] [--yes]")
    print("")
    print("Generates a word cloud HTML page from the poetry collection.")
    print("Words are sized by frequency, with stop words filtered out.")
    print("")
    print("Options:")
    print("  DIR                  Project directory (default: /mnt/mtwo/programming/ai-stuff/neocities-modernization)")
    print("  --all                Include all words (no max_words limit)")
    print("  --words N            Maximum words to display")
    print("  --chrono-per-page N  Chronological page size; MUST match the value the")
    print("                       chronological pages were built with, or poem links")
    print("                       point at the wrong page.")
    print("  --seed N             Master seed for the word shuffle (Issue 10-058).")
    print("                       Same seed => identical word order. Normally passed")
    print("                       by run.sh; if omitted a seed is auto-generated and")
    print("                       logged to stderr.")
    print("  --yes, -y            Take config.lua's default for any value not given")
    print("  --out FOLDER         A trial run: write wordcloud.html into FOLDER, not")
    print("                       the site, and keep no record in archive/wordclouds/")
    print("                       (that record is for builds)")
    print("  --help               Show this help message")
    print("")
    print("A value not given is asked for, with config.lua's default in brackets;")
    print("Enter takes it. Started by run.sh, or with no one at the keyboard, a")
    print("missing value is an error instead.")
    os.exit(0)
end
-- }}}

local provided_dir, CLI_ALL_WORDS, CLI_MAX_WORDS, CLI_CHRONO_PER_PAGE, CLI_SEED,
      CLI_MODEL, CLI_SERVER, CLI_OUT = parse_args(arg)
local DIR = setup_dir_path(provided_dir)

-- {{{ Issue 10-058: resolve + apply the master seed ONCE at startup
-- The word shuffle used to call math.randomseed(os.time()) inside the shuffle on
-- every invocation -- non-reproducible (the seed was never recorded) and, because
-- os.time() has 1-second resolution, two shuffles in the same second drew the SAME
-- "random" order. Now the seed is resolved once here and the shuffle just consumes
-- the already-seeded stream.
--   --seed N  => run.sh passes the build's recorded master seed (the normal path).
--   no flag   => standalone run: invent a seed from the clock mixed with the PID
--                (so back-to-back same-second runs differ) and LOG it, since here
--                there is no run.sh to record it to generation-metadata.json.
local MASTER_SEED = CLI_SEED
if not MASTER_SEED then
    -- LuaJIT has no portable getpid(), so for the per-process entropy that keeps
    -- two same-second runs from drawing the same seed we use the hex address of a
    -- fresh table -- distinct per process like a PID would be. Mixed with the
    -- 1-second clock and folded into a 31-bit non-negative int (run.sh's range).
    local process_unique_bits = tonumber(tostring({}):match("0x(%x+)") or "0", 16) or 0
    MASTER_SEED = (os.time() * 100000 + process_unique_bits) % 2147483647
    io.stderr:write(string.format(
        "[wordcloud] no --seed given; using auto seed %d (pass --seed N to reproduce)\n",
        MASTER_SEED))
end
math.randomseed(MASTER_SEED)
-- }}}
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path

local dkjson = require("dkjson")
local utils = require("utils")
-- Issue 10-065a: settles a value missing from the command line (ask, --yes, or error)
local ask = require("ask-for-value")
local ACCEPT_DEFAULTS = ask.wants_defaults(arg)
-- Shared <head> contents: viewport, the shipped monospace font, the text-size
-- lock. One owner, so this menu cannot drift from the poem pages.
local page_head = require("page-head")
-- Shared chronological mapping so the poem-ID jump links here resolve to the
-- SAME paginated page the chronological pages emit (a third inline copy used to
-- drift -- see Issue 10-049 follow-up).
local flat_html = require("flat-html-generator")
utils.init_assets_root(arg)

-- Issue 10-003: Load unified config from config.lua
local config_loader = require("config-loader")
config_loader.set_project_root(DIR)
local unified_config = config_loader.load()

-- A --server/--model typed on THIS command outranks the run notepad and
-- config.lua. Applied before anything reads word_colors.json, whose directory is
-- derived from the selected model.
local inference_config = require("inference-server-config")
inference_config.set_project_root(DIR)
if CLI_SERVER then inference_config.set_selected_server(CLI_SERVER) end
if CLI_MODEL then inference_config.set_selected_model(CLI_MODEL) end

-- {{{ resolve_chrono_per_page()
-- The chronological page size used to map each poem ID to the page it lives on.
-- Two legitimate sources, in order: the --chrono-per-page the build passed us,
-- else the config value (default_chrono_per_page, which itself hard-errors if
-- the config key is missing). There is deliberately no literal fallback -- a
-- wrong size sends every poem link to the wrong page, so an absent value is an
-- error, not a guess.
--
-- Issue 10-065a: when --chrono-per-page is absent the config value is offered as
-- the default and confirmed (asked, or taken by --yes with a notice), never
-- applied silently. Settled once and remembered, since several pages use it.
local settled_chrono_per_page = nil
local function resolve_chrono_per_page()
    if settled_chrono_per_page then
        return settled_chrono_per_page
    end
    -- the config value is the offered default; a config without one simply
    -- offers none (the question is still asked, with no brackets)
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
-- }}}

local M = {}

-- {{{ Configuration
-- Issue 10-003: Load word_cloud config from unified config (including embedded stop_words)
local wc = unified_config.word_cloud or error("config.lua has no word_cloud section")

-- How many words the cloud shows: --all / --words from the command line, or
-- (Issue 10-065a) asked, offering config.lua's word_cloud.max_words as the
-- default. This program always draws the cloud, so the value is always needed
-- and is settled here, at startup.
local cli_words = CLI_ALL_WORDS and "all" or CLI_MAX_WORDS
local words_answer = ask.resolve({
    flag = "--words",
    question = "How many words in the word cloud? (a number, or \"all\")",
    kind = "count_or_all",
    given = cli_words,
    default = wc.max_words,
    default_source = "config.lua word_cloud.max_words",
    accept_defaults = ACCEPT_DEFAULTS,
})
-- "all" means no limit
local effective_max_words = (words_answer == "all") and math.huge or words_answer

-- every value from config.lua's word_cloud section; a missing one is an
-- error (Issue 10-071: defaults live only in config.lua)
local function setting(key)
    local value = wc[key]
    if value == nil then error("config.lua word_cloud." .. key .. " is missing") end
    return value
end
local CONFIG = {
    min_occurrences = setting("min_occurrences"),
    max_words = effective_max_words,
    font_size_min = setting("font_size_min"),
    font_size_max = setting("font_size_max"),
    min_word_length = setting("min_word_length"),
    output_file = setting("output_file"),
}
-- }}}

-- {{{ load_stop_words
-- Issue 10-003: Load stop words from embedded config.word_cloud.stop_words array
local function load_stop_words()
    local stop_words = {}

    -- Load from config (array of words)
    local config_stop_words = wc.stop_words or {}
    for _, word in ipairs(config_stop_words) do
        stop_words[word:lower()] = true
    end

    local count = 0
    for _ in pairs(stop_words) do count = count + 1 end
    utils.log_info(string.format("Loaded %d stop words from config", count))

    return stop_words
end
-- }}}

-- {{{ load_word_colors
-- Issue 16-011: Load word colors from embeddings directory for colorized word cloud display
local function load_word_colors()
    local cache_file = utils.embeddings_dir() .. "/word_colors.json"
    local data = utils.read_json_file(cache_file)
    if data and data.word_colors then
        local lookup = {}
        for _, entry in ipairs(data.word_colors) do
            -- Keep the WHOLE entry (best `.color` plus the full `.colors` ranking),
            -- so the renderer can pick a large word's strongest non-gray color.
            lookup[entry.word] = entry
        end
        utils.log_info(string.format("Loaded %d word colors from cache", #data.word_colors))
        return lookup
    end
    utils.log_warn("No word colors found - words will display in default color")
    return {}
end
-- }}}

-- {{{ top_nongray_color()
-- The word cloud colors LARGE words by meaning but must never render them gray --
-- gray is reserved for the de-emphasised small words below the size threshold. Each
-- word's color entry carries the full palette ranking (strongest first); walk it for
-- the strongest color that is not gray. With six non-gray colors there is always one;
-- the trailing fallbacks only guard a missing entry or a pre-`colors` cache (an old
-- word_colors.json without the ranking, until it is regenerated). Returns a color
-- NAME or nil.
local function top_nongray_color(entry)
    if entry and entry.colors then
        for _, c in ipairs(entry.colors) do
            if c.color ~= "gray" then return c.color end
        end
    end
    -- No ranking available: fall back to the single best color (may be gray).
    return entry and entry.color or nil
end
-- }}}

-- {{{ extract_words_from_poems
local function extract_words_from_poems(poems, stop_words)
    local word_counts = {}
    local total_words = 0

    for _, poem in ipairs(poems) do
        local content = poem.content or ""

        -- Extract words (alphanumeric sequences)
        for word in content:gmatch("[%w]+") do
            local normalized = word:lower()

            -- Filter: minimum length, not a stop word, not a number
            if #normalized >= CONFIG.min_word_length
               and not stop_words[normalized]
               and not normalized:match("^%d+$") then
                word_counts[normalized] = (word_counts[normalized] or 0) + 1
                total_words = total_words + 1
            end
        end
    end

    local unique_count = 0
    for _ in pairs(word_counts) do unique_count = unique_count + 1 end
    utils.log_info(string.format("Extracted %d total words, %d unique",
        total_words, unique_count))

    return word_counts
end
-- }}}

-- {{{ filter_and_sort_words
local function filter_and_sort_words(word_counts)
    local filtered = {}

    -- Filter by minimum occurrences
    for word, count in pairs(word_counts) do
        if count >= CONFIG.min_occurrences then
            table.insert(filtered, {word = word, count = count})
        end
    end

    -- Sort by count (descending), tie-broken alphabetically. The tiebreak
    -- keeps the max_words cutoff deterministic across processes -- the same
    -- reason as generate-word-pages.lua's get_word_list. Without it, the
    -- wordcloud and the word-embedding/word-page stages can disagree on which
    -- boundary words make the cut, producing words with pages but no embedding.
    table.sort(filtered, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.word < b.word
    end)

    -- Limit to max_words
    local result = {}
    for i = 1, math.min(#filtered, CONFIG.max_words) do
        result[i] = filtered[i]
    end

    utils.log_info(string.format("Filtered to %d words (min occurrences: %d)",
        #result, CONFIG.min_occurrences))

    return result
end
-- }}}

-- {{{ calculate_font_sizes
-- Issue 8-043c: Use logarithmic scaling for more gradual font size variation
-- Word frequencies follow Zipf's law (power law), so linear scaling clusters
-- most words at the minimum size. Log scaling spreads them more evenly.
local function calculate_font_sizes(words)
    if #words == 0 then return words end

    -- Find min and max counts
    local min_count = words[#words].count  -- Last item (lowest count)
    local max_count = words[1].count       -- First item (highest count)

    -- Calculate font size for each word using logarithmic scaling
    for _, entry in ipairs(words) do
        local normalized
        if max_count == min_count then
            normalized = 0.5  -- All same frequency
        else
            -- Log scaling: compresses high values, spreads low values
            -- Add 1 to avoid log(0), shift so min_count maps to 0
            local log_range = math.log(max_count - min_count + 1)
            local log_value = math.log(entry.count - min_count + 1)
            normalized = log_value / log_range
        end

        -- Map to font size range (1-7)
        entry.font_size = math.floor(CONFIG.font_size_min +
            normalized * (CONFIG.font_size_max - CONFIG.font_size_min) + 0.5)
    end

    return words
end
-- }}}

-- {{{ local function generate_poem_index
-- Issue 8-046: Generate poem index section showing all poems by category
-- Issue 6-031: Uses poem.id (not sequential index) to respect tombstones -
--              excluded poems leave gaps in the ID sequence, they don't shift other IDs
-- Issue 8-043c: Simplified format - just poem IDs, multiple per line
local function generate_poem_index(poems_data)
    if not poems_data or not poems_data.poems then
        return ""
    end

    -- Issue 10-036: poem_index -> chronological page map so each index entry
    -- links to the correct paginated page (and anchor), not always page 1.
    -- Uses the chronological-page generator's OWN mapping (shared) so the page
    -- numbers match exactly. The page SIZE comes from resolve_chrono_per_page()
    -- (the build's --chrono-per-page, else config) -- guessing it wrong is what
    -- sent links to the wrong page; an absent size is a hard error, not a guess.
    local chrono_page_map = {}
    do
        local per_page = resolve_chrono_per_page()
        local mapping = flat_html.compute_chronological_mapping(poems_data, per_page)
        for poem_index, info in pairs(mapping) do
            -- named as the chronological pages name themselves ("03.html",
            -- or "index.html" for a one-page view)
            chrono_page_map[poem_index] = require("chronological-page").file_name(info.page_number, info.total_pages)
        end
    end

    -- Group poems by category
    local categories = {}
    for _, poem in ipairs(poems_data.poems) do
        local cat = poem.category or "unknown"
        if not categories[cat] then
            categories[cat] = {}
        end
        table.insert(categories[cat], poem)
    end

    -- Sort poems within each category by ID
    for _, poems in pairs(categories) do
        table.sort(poems, function(a, b)
            return (a.id or 0) < (b.id or 0)
        end)
    end

    -- Issue 8-051: Order categories by ascending poem count (smallest first)
    -- Removes the need for a hardcoded category list — new sources auto-sort
    local ordered_cats = {}
    for cat, _ in pairs(categories) do
        table.insert(ordered_cats, cat)
    end
    table.sort(ordered_cats, function(a, b)
        return #categories[a] < #categories[b]
    end)

    -- Generate index HTML - simplified format with multiple IDs per line
    -- Issue 10-055 (Feature G): the #poem-index anchor lets the source browser's
    -- "output/" entry deep-link straight to this list, so every generated output
    -- page is reachable from one place without the browser having to enumerate
    -- the tens of thousands of similar/different/chronological pages itself.
    local index_parts = {}
    table.insert(index_parts, [[
<hr>
<h2 id="poem-index">Poem Index</h2>
<p>Click any poem ID to jump to its chronological position</p>
<table align="center"><tr><td>
<pre>
]])

    local IDS_PER_LINE = 10  -- Show 10 poem IDs per line

    for _, cat in ipairs(ordered_cats) do
        local poems = categories[cat]
        table.insert(index_parts, string.format(
            "\n<b>%s</b> (%d poems)\n",
            cat:upper(), #poems
        ))

        -- Build lines of poem IDs
        local line_ids = {}
        for i, poem in ipairs(poems) do
            -- Issue 10-036: anchor + page target the poem's true chronological
            -- position. Chronological pages emit <span id="poem-<poem_index>">
            -- and are paginated, so link to chronological/<NN>.html#poem-<index>
            -- instead of index.html (a redirect that drops the anchor -> page 1)
            -- and instead of the old "poem-CATEGORY-ID" anchor that matched
            -- nothing.
            -- Issue 8-019: the anchor is the poem's source key; a poem with
            -- no place on the timeline stops the page (it used to guess page
            -- 01)
            local pidx = poem.poem_index
            local anchor_id = require("poem-address").anchor(poem)
            local page_file = chrono_page_map[pidx]
                or error("word cloud: poem " .. anchor_id .. " is not on the chronological pages")
            local id_str = tostring(poem.id or 0)

            -- Keep column alignment with leading spaces, but place them OUTSIDE
            -- the <a> so the clickable target is just the number (e.g. "46"),
            -- not "   46". The spaces are monospaced inside <pre>, so the
            -- columns still line up.
            local pad = string.rep(" ", math.max(0, 4 - #id_str))
            local link = pad .. string.format(
                '<a href="chronological/%s#%s">%s</a>',
                page_file, anchor_id, id_str)
            table.insert(line_ids, link)

            -- Output line when we reach IDS_PER_LINE or end of poems
            if #line_ids >= IDS_PER_LINE or i == #poems then
                table.insert(index_parts, "  " .. table.concat(line_ids, " ") .. "\n")
                line_ids = {}
            end
        end
    end

    table.insert(index_parts, [[
</pre>
</td></tr></table>
]])

    return table.concat(index_parts)
end
-- }}}

-- {{{ archive_wordcloud()
-- Keep a permanent, timestamped copy of every word cloud we generate. The live
-- page (output/wordcloud.html) is overwritten on every build, so without this the
-- history of how the cloud changes over time -- which words rise and fall, how the
-- "all words" cloud differs from the default -- would be lost. The archive lives
-- OUTSIDE output/ (under archive/wordclouds/) on purpose: it is a local record, not
-- something deployed to the site. A failed archive write is a hard error, not a
-- shrug -- if we meant to keep a copy and couldn't, we want to know.
local function archive_wordcloud(html, word_count)
    local archive_dir = DIR .. "/archive/wordclouds"
    utils.ensure_directory(archive_dir)
    -- Timestamp + word count + seed in the name: successive builds accumulate
    -- instead of overwriting, the count tells "all words" (7082) from a default
    -- (200) at a glance, and the seed means an old cloud can be re-made exactly
    -- (run.sh --seed N) by reading its filename, without opening the file
    -- (Issue 10-058). Copies made before the seed was added lack the "-seedN"
    -- part; their seed is in the comment at the top of the file. No spaces, so
    -- the plain mkdir/io paths handle it.
    local stamp = os.date("%Y-%m-%d_%H-%M-%S")
    local archive_file = string.format("%s/wordcloud-%s-%dwords-seed%d.html",
        archive_dir, stamp, word_count, MASTER_SEED)
    if not utils.write_file(archive_file, html) then
        error("Failed to archive word cloud to: " .. archive_file)
    end
    utils.log_info("Archived word cloud: " .. archive_file)
end
-- }}}

-- {{{ generate_wordcloud_html
local function generate_wordcloud_html(words, output_dir, poems_data)
    -- Issue 16-011: Load word colors and color configuration for colorized display
    local word_colors = load_word_colors()
    -- config.lua semantic_colors: the site's one palette, shared with the
    -- progress bars, so a red word and a red bar mean the same thing
    local palette = unified_config.semantic_colors or error("config.lua has no semantic_colors section")
    -- {{{ local function hex_of()
    local function hex_of(name)
        local entry = palette[name]
        if not entry or not entry.hex then error("config.lua semantic_colors." .. tostring(name) .. ".hex is missing") end
        return entry.hex
    end
    -- }}}

    -- Shuffle words for visual variety (not just sorted by size)
    local shuffled = {}
    for i, w in ipairs(words) do shuffled[i] = w end

    -- Fisher-Yates shuffle. Issue 10-058: the RNG was seeded ONCE at startup from
    -- the resolved master seed (MASTER_SEED) -- do NOT re-seed here. Re-seeding per
    -- call from os.time() (the old behaviour) was non-reproducible AND, at 1-second
    -- clock resolution, gave two same-second builds the identical "random" order.
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    -- Generate word spans with links to similar pages
    -- Issue 8-043: Each word links to wordcloud/{word}.html showing poems similar to that word
    -- Issue 16-011: Words are now colored by their semantic color
    local word_html = {}
    for _, entry in ipairs(shuffled) do
        -- Sanitize word for URL (lowercase, no special chars)
        local safe_word = entry.word:lower():gsub("[^%w]", "")

        -- Significance threshold: only the larger words carry their semantic
        -- color. font_size >= 5 is the same cutoff that bolds a word (~the top
        -- 65% of the 1-7 size range), so emphasis and color move together.
        -- Smaller words render in neutral gray, making color a signal of
        -- significance rather than visual noise on every word.
        local is_significant = entry.font_size >= 5
        local bold_open, bold_close = "", ""
        local hex_color = hex_of("gray")  -- neutral gray for the long tail
        if is_significant then
            bold_open, bold_close = "<b>", "</b>"
            -- Issue 16-011: Look up this word's semantic color. Large words never
            -- render gray (gray belongs to the de-emphasised small words), so we take
            -- the strongest NON-gray color from the word's full color ranking.
            local semantic_color = top_nongray_color(word_colors[safe_word]) or "gray"
            hex_color = hex_of(semantic_color)
        end

        -- Each word links to its similarity page, colored by semantic meaning
        table.insert(word_html, string.format(
            '<a href="wordcloud/%s.html"><font size="%d" color="%s">%s%s%s</font></a>',
            safe_word, entry.font_size, hex_color, bold_open, entry.word, bold_close
        ))
    end

    -- Generate poem index section (Issue 8-046)
    local poem_index = generate_poem_index(poems_data)

    -- Generate HTML page
    -- Issue 16-010: shared head block -- viewport + shipped monospace font.
    -- Base path is "." because this menu is written to the site ROOT, unlike the
    -- poem pages one directory below; getting that wrong 404s the font and drops
    -- the page silently back to whatever monospace the device happens to own.
    -- Same centering CSS as the poem pages: the <pre> poem-ID list centers as an
    -- inline-block (text stays left) so it sits on the page centerline.
    local head_block = page_head.style_block(".",
        "td { text-align: center; } pre { display: inline-block; text-align: left; margin: 0 auto; }\n"
        .. "img, video, audio { margin-left: auto; margin-right: auto; }")
    local html = string.format([[<!DOCTYPE html>
<!-- Issue 10-058: word order shuffled with master seed %d. Re-run with
     --seed %d to reproduce this exact word cloud. (Issue 10-065 removed the
     config.lua route; --seed is the only one.) -->
<!-- The run record, output/generation-metadata.json, should name the same seed.
     Issue 10-058 found a build where it did not; this comment is the one written
     by the run that actually made the page. -->
<html>
<head>
<meta charset="UTF-8">
%s
<title>Menu - Poetry Collection</title>
%s</head>
<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">]], MASTER_SEED, MASTER_SEED, page_head.viewport_meta(), head_block) .. string.format([[

<center>
<h1>Menu</h1>
<p><a href="explore.html">Explore</a> │ <a href="chronological/01.html">Chronological</a> │ <a href="gallery/index.html">Gallery</a></p>
<hr>
<h2>Word Cloud</h2>
<p>Words sized by frequency across %d poems (click to explore similar poems)</p>
<p>
%s
</p>
<p><i>%d unique words shown (minimum %d occurrences)</i></p>
%s
</center>

</body>
</html>]], #words > 0 and words[1].total_poems or 0,
    table.concat(word_html, " &nbsp; "),
    #shuffled, CONFIG.min_occurrences,
    poem_index)

    -- Write file
    local output_file = output_dir .. "/" .. CONFIG.output_file
    local success = utils.write_file(output_file, html)

    if success then
        utils.log_info("Generated: " .. output_file)
        -- Keep a dated copy of this build's cloud in archive/wordclouds/ --
        -- a build's, not a trial's (--out): a test that ran the generator
        -- would otherwise add records of clouds nobody published.
        if not CLI_OUT then
            archive_wordcloud(html, #words)
        end
        return output_file
    else
        utils.log_error("Failed to write: " .. output_file)
        return nil
    end
end
-- }}}

-- {{{ function M.generate_wordcloud
function M.generate_wordcloud(poems_data, output_dir)
    -- Load stop words
    local stop_words = load_stop_words()

    -- Extract words from poems
    local poems = poems_data.poems or {}
    local word_counts = extract_words_from_poems(poems, stop_words)

    -- Filter and sort
    local words = filter_and_sort_words(word_counts)

    -- Calculate font sizes
    words = calculate_font_sizes(words)

    -- Add metadata for HTML generation
    if #words > 0 then
        words[1].total_poems = #poems
    end

    -- Generate HTML (pass poems_data for poem index - Issue 8-046)
    return generate_wordcloud_html(words, output_dir, poems_data)
end
-- }}}

-- {{{ function M.main
function M.main()
    -- Load poems
    local poems_file = utils.asset_path("poems.json")
    local poems_data = utils.read_json_file(poems_file)

    if not poems_data then
        utils.log_error("Could not load poems.json")
        return nil
    end

    -- --out: a trial run writes into its own folder, not the site
    local output_dir = CLI_OUT or (DIR .. "/output")
    if CLI_OUT then utils.ensure_directory(output_dir) end  -- the site folder is made by run.sh (in RAM)
    return M.generate_wordcloud(poems_data, output_dir)
end
-- }}}

-- {{{ Command line execution
if arg and #arg >= 0 and debug.getinfo(3) == nil then

    -- start, end and any stopping error go to the run's log (Issue 10-075)
    require("output").guard("wordcloud-generator.lua", M.main)
end
-- }}}

return M
