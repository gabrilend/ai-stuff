#!/usr/bin/env luajit

-- {{{ wordcloud-generator.lua
-- Issue 8-043: Generate semantic word cloud page
-- Extracts words from poems, filters stop words, and creates a visual word cloud
-- where font size represents word frequency (or optionally, centroid similarity)
--
-- Usage:
--   luajit src/wordcloud-generator.lua [DIR]
--   luajit src/wordcloud-generator.lua --help
-- }}}

-- {{{ Setup
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end

local DIR = setup_dir_path(arg and arg[1])
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path

local dkjson = require("dkjson")
local utils = require("utils")
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
local CONFIG = {
    min_occurrences = wc.min_occurrences or 5,
    max_words = wc.max_words or 200,
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

    -- Sort by count (descending)
    table.sort(filtered, function(a, b) return a.count > b.count end)

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
local function calculate_font_sizes(words)
    if #words == 0 then return words end

    -- Find min and max counts
    local min_count = words[#words].count  -- Last item (lowest count)
    local max_count = words[1].count       -- First item (highest count)

    -- Calculate font size for each word
    for _, entry in ipairs(words) do
        local normalized
        if max_count == min_count then
            normalized = 0.5  -- All same frequency
        else
            normalized = (entry.count - min_count) / (max_count - min_count)
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
local function generate_poem_index(poems_data)
    if not poems_data or not poems_data.poems then
        return ""
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

    -- Order categories: fediverse, notes, messages, bluesky, then others
    local cat_order = {"fediverse", "notes", "messages", "bluesky"}
    local ordered_cats = {}
    for _, cat in ipairs(cat_order) do
        if categories[cat] then
            table.insert(ordered_cats, cat)
        end
    end
    -- Add any remaining categories
    for cat, _ in pairs(categories) do
        local found = false
        for _, c in ipairs(cat_order) do
            if c == cat then found = true; break end
        end
        if not found then
            table.insert(ordered_cats, cat)
        end
    end

    -- Generate index HTML
    local index_parts = {}
    table.insert(index_parts, [[
<hr>
<h2>Poem Index</h2>
<p>All poems organized by source category</p>
<table align="center"><tr><td>
<pre>
]])

    for _, cat in ipairs(ordered_cats) do
        local poems = categories[cat]
        table.insert(index_parts, string.format(
            "\n<b>%s</b> (%d poems)\n",
            cat:upper(), #poems
        ))
        table.insert(index_parts, string.rep("─", 60) .. "\n")

        for _, poem in ipairs(poems) do
            -- Get anchor and preview
            local anchor_id = string.format("poem-%s-%04d", cat, poem.id or 0)
            local content = poem.content or ""
            content = content:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
            local preview = content:gsub("\n", " "):sub(1, 40)
            if #content > 40 then preview = preview .. "..." end

            -- Get poem identifier
            local identifier
            if cat == "notes" and poem.source_file then
                identifier = poem.source_file
            else
                identifier = tostring(poem.id or 0)
            end

            -- Link to chronological position
            -- Note: Uses index.html for single-page or would need chrono_map for pagination
            table.insert(index_parts, string.format(
                '  <a href="chronological/index.html#%s">%s</a> - "%s"\n',
                anchor_id, identifier, preview
            ))
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
    local word_html = {}
    for _, entry in ipairs(shuffled) do
        -- Use font tag with size attribute (CSS-free)
        local bold_open, bold_close = "", ""
        if entry.font_size >= 5 then
            bold_open, bold_close = "<b>", "</b>"
        end

        -- Sanitize word for URL (lowercase, no special chars)
        local safe_word = entry.word:lower():gsub("[^%w]", "")

        -- Each word links to its similarity page
        table.insert(word_html, string.format(
            '<a href="wordcloud/%s.html"><font size="%d">%s%s%s</font></a>',
            safe_word, entry.font_size, bold_open, entry.word, bold_close
        ))
    end

    -- Generate poem index section (Issue 8-046)
    local poem_index = generate_poem_index(poems_data)

    -- Generate HTML page
    local html = string.format([[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Menu - Poetry Collection</title>
</head>
<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">

<center>
<h1>Menu</h1>
<p><a href="chronological/index.html">Chronological Index</a></p>
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
    utils.log_info("Generating word cloud...")

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
        print("Usage: luajit src/wordcloud-generator.lua [DIR]")
        print("")
        print("Generates a word cloud HTML page from the poetry collection.")
        print("Words are sized by frequency, with stop words filtered out.")
        print("")
        print("Options:")
        print("  DIR      Project directory (default: /mnt/mtwo/programming/ai-stuff/neocities-modernization)")
        print("  --help   Show this help message")
        os.exit(0)
    end

    M.main()
end
-- }}}

return M
