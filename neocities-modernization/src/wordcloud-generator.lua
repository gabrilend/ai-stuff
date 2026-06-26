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
--   --all      Include all words (no max_words limit)
--   --words N  Set maximum words to display (default: 200 from config)
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
    local max_words = nil  -- nil means use config default
    local chrono_per_page = nil  -- nil means fall back to config (never to a literal)
    local seed = nil  -- Issue 10-058: master seed for the shuffle; nil => auto at startup
    local i = 1
    while i <= #(args or {}) do
        local a = args[i]
        if a == "--all" then
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
        elseif not a:match("^%-") then
            -- Positional argument (DIR)
            dir = a
            i = i + 1
        else
            -- Skip unknown flags
            i = i + 1
        end
    end
    return dir, all_words, max_words, chrono_per_page, seed
end
-- }}}

local provided_dir, CLI_ALL_WORDS, CLI_MAX_WORDS, CLI_CHRONO_PER_PAGE, CLI_SEED = parse_args(arg)
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
-- Shared chronological mapping so the poem-ID jump links here resolve to the
-- SAME paginated page the chronological pages emit (a third inline copy used to
-- drift -- see Issue 10-049 follow-up).
local flat_html = require("flat-html-generator")
utils.init_assets_root(arg)

-- Issue 10-003: Load unified config from config.lua
local config_loader = require("config-loader")
config_loader.set_project_root(DIR)
local unified_config = config_loader.load()

-- {{{ resolve_chrono_per_page()
-- The chronological page size used to map each poem ID to the page it lives on.
-- Two legitimate sources, in order: the --chrono-per-page the build passed us,
-- else the config value (default_chrono_per_page, which itself hard-errors if
-- the config key is missing). There is deliberately no literal fallback -- a
-- wrong size sends every poem link to the wrong page, so an absent value is an
-- error, not a guess.
local function resolve_chrono_per_page()
    return CLI_CHRONO_PER_PAGE or flat_html.default_chrono_per_page()
end
-- }}}
-- }}}

local M = {}

-- {{{ Configuration
-- Issue 10-003: Load word_cloud config from unified config (including embedded stop_words)
local wc = unified_config.word_cloud or {}

-- Determine max_words: CLI --all > CLI --words > config
local effective_max_words
if CLI_ALL_WORDS then
    effective_max_words = math.huge  -- No limit
elseif CLI_MAX_WORDS then
    effective_max_words = CLI_MAX_WORDS
else
    effective_max_words = wc.max_words or 200
end

local CONFIG = {
    min_occurrences = wc.min_occurrences or 5,
    max_words = effective_max_words,
    font_size_min = wc.font_size_min or 1,
    font_size_max = wc.font_size_max or 7,
    min_word_length = wc.min_word_length or 3,
    output_file = wc.output_file or "wordcloud.html"
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
-- Issue 16-010: Load word colors from embeddings directory for colorized word cloud display
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
            chrono_page_map[poem_index] = string.format("%02d", info.page_number)
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
            local pidx = poem.poem_index or 0
            local anchor_id = string.format("poem-%d", pidx)
            local page_str = chrono_page_map[pidx] or "01"
            local id_str = tostring(poem.id or 0)

            -- Keep column alignment with leading spaces, but place them OUTSIDE
            -- the <a> so the clickable target is just the number (e.g. "46"),
            -- not "   46". The spaces are monospaced inside <pre>, so the
            -- columns still line up.
            local pad = string.rep(" ", math.max(0, 4 - #id_str))
            local link = pad .. string.format(
                '<a href="chronological/%s.html#%s">%s</a>',
                page_str, anchor_id, id_str)
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
    -- Timestamp + word count in the name: successive builds accumulate instead of
    -- overwriting, and the count tells "all words" (7082) from a default (200) at a
    -- glance. No spaces, so the plain mkdir/io paths handle it.
    local stamp = os.date("%Y-%m-%d_%H-%M-%S")
    local archive_file = string.format("%s/wordcloud-%s-%dwords.html",
        archive_dir, stamp, word_count)
    if not utils.write_file(archive_file, html) then
        error("Failed to archive word cloud to: " .. archive_file)
    end
    utils.log_info("Archived word cloud: " .. archive_file)
end
-- }}}

-- {{{ generate_wordcloud_html
local function generate_wordcloud_html(words, output_dir, poems_data)
    -- Issue 16-010: Load word colors and color configuration for colorized display
    local word_colors = load_word_colors()
    local color_config = unified_config.colors or {
        red = "#FF6B6B",
        orange = "#FFA94D",
        yellow = "#FFE066",
        green = "#69DB7C",
        blue = "#74C0FC",
        purple = "#DA77F2",
        gray = "#868E96"
    }

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
    -- Issue 16-010: Words are now colored by their semantic color
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
        local hex_color = "#868E96"  -- neutral gray for the long tail
        if is_significant then
            bold_open, bold_close = "<b>", "</b>"
            -- Issue 16-010: Look up this word's semantic color. Large words never
            -- render gray (gray belongs to the de-emphasised small words), so we take
            -- the strongest NON-gray color from the word's full color ranking.
            local semantic_color = top_nongray_color(word_colors[safe_word]) or "gray"
            hex_color = color_config[semantic_color] or "#868E96"
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
    -- Issue 16-010: Added font style for Hack Nerd Font font-stack
    -- Same centering CSS as the poem pages: the <pre> poem-ID list centers as an
    -- inline-block (text stays left) so it sits on the page centerline.
    local font_style = [[<style>body, pre { font-family: 'Hack Nerd Font', 'Hack', 'Fira Code', 'JetBrains Mono', 'Cascadia Code', 'Consolas', 'Monaco', 'Liberation Mono', 'Courier New', monospace; }
td { text-align: center; } pre { display: inline-block; text-align: left; margin: 0 auto; } img, video, audio { margin-left: auto; margin-right: auto; }</style>]]
    local html = string.format([[<!DOCTYPE html>
<!-- Issue 10-058: word order shuffled with master seed %d. Re-run with
     --seed %d (or set randomization.seed in config.lua) to reproduce this exact
     word cloud. The canonical record is output/generation-metadata.json. -->
<html>
<head>
<meta charset="UTF-8">
<title>Menu - Poetry Collection</title>
%s</head>
<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">]], MASTER_SEED, MASTER_SEED, font_style) .. string.format([[

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
        -- Keep a dated copy of this build's cloud in archive/wordclouds/.
        archive_wordcloud(html, #words)
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

    local output_dir = DIR .. "/output"
    return M.generate_wordcloud(poems_data, output_dir)
end
-- }}}

-- {{{ Command line execution
if arg and #arg >= 0 and debug.getinfo(3) == nil then
    if arg[1] == "--help" or arg[1] == "-h" then
        print("Usage: luajit src/wordcloud-generator.lua [DIR] [--all] [--words N] [--chrono-per-page N] [--seed N]")
        print("")
        print("Generates a word cloud HTML page from the poetry collection.")
        print("Words are sized by frequency, with stop words filtered out.")
        print("")
        print("Options:")
        print("  DIR                  Project directory (default: /mnt/mtwo/programming/ai-stuff/neocities-modernization)")
        print("  --all                Include all words (no max_words limit)")
        print("  --chrono-per-page N  Chronological page size; MUST match the value the")
        print("                       chronological pages were built with, or poem links")
        print("                       point at the wrong page. Defaults to the config value.")
        print("  --words N  Set maximum words to display (default: 200 from config)")
        print("  --seed N             Master seed for the word shuffle (Issue 10-058).")
        print("                       Same seed => identical word order. Normally passed")
        print("                       by run.sh; if omitted a seed is auto-generated and")
        print("                       logged to stderr.")
        print("  --help     Show this help message")
        os.exit(0)
    end

    M.main()
end
-- }}}

return M
