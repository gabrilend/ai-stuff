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
    local i = 1
    while i <= #(args or {}) do
        local a = args[i]
        if a == "--all" then
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
        elseif not a:match("^%-") then
            -- Positional argument (DIR)
            dir = a
            i = i + 1
        else
            -- Skip unknown flags
            i = i + 1
        end
    end
    return dir, all_words, max_words
end
-- }}}

local provided_dir, CLI_ALL_WORDS, CLI_MAX_WORDS = parse_args(arg)
local DIR = setup_dir_path(provided_dir)
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
            lookup[entry.word] = entry.color
        end
        utils.log_info(string.format("Loaded %d word colors from cache", #data.word_colors))
        return lookup
    end
    utils.log_warn("No word colors found - words will display in default color")
    return {}
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
    -- numbers match exactly -- the old inline copy sorted by the raw
    -- creation_date string with no tiebreaker and its own page-size default, so
    -- it disagreed and links jumped to the wrong page.
    local chrono_page_map = {}
    do
        local per_page = flat_html.default_chrono_per_page()
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
    local index_parts = {}
    table.insert(index_parts, [[
<hr>
<h2>Poem Index</h2>
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

    -- Fisher-Yates shuffle
    math.randomseed(os.time())
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
            -- Issue 16-010: Look up semantic color for this word
            local semantic_color = word_colors[safe_word] or "gray"
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
<html>
<head>
<meta charset="UTF-8">
<title>Menu - Poetry Collection</title>
%s</head>
<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">]], font_style) .. string.format([[

<center>
<h1>Menu</h1>
<p><a href="explore.html">Explore</a> │ <a href="chronological/index.html">Chronological Index</a> │ <a href="gallery/index.html">Gallery</a></p>
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
        print("Usage: luajit src/wordcloud-generator.lua [DIR] [--all] [--words N]")
        print("")
        print("Generates a word cloud HTML page from the poetry collection.")
        print("Words are sized by frequency, with stop words filtered out.")
        print("")
        print("Options:")
        print("  DIR        Project directory (default: /mnt/mtwo/programming/ai-stuff/neocities-modernization)")
        print("  --all      Include all words (no max_words limit)")
        print("  --words N  Set maximum words to display (default: 200 from config)")
        print("  --help     Show this help message")
        os.exit(0)
    end

    M.main()
end
-- }}}

return M
