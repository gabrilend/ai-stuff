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
-- }}}

local M = {}

-- {{{ Configuration
-- Default values, can be overridden by config/input-sources.json
local CONFIG = {
    min_occurrences = 5,          -- Minimum times a word must appear
    max_words = 200,              -- Maximum words to display
    font_size_min = 1,            -- Smallest font size (HTML font tag: 1-7)
    font_size_max = 7,            -- Largest font size
    min_word_length = 3,          -- Ignore words shorter than this
    output_file = "wordcloud.html",
    stop_words_file = "config/stop-words.txt"
}

-- {{{ load_config_from_json
local function load_config_from_json()
    local config_path = DIR .. "/config/input-sources.json"
    local file = io.open(config_path, "r")
    if not file then
        utils.log_warn("Config file not found, using defaults: " .. config_path)
        return
    end

    local content = file:read("*a")
    file:close()

    local config_data, _, err = dkjson.decode(content)
    if not config_data then
        utils.log_warn("Failed to parse config: " .. (err or "unknown error"))
        return
    end

    -- Override defaults with config values if present
    local wc = config_data.word_cloud
    if wc then
        if wc.min_occurrences then CONFIG.min_occurrences = wc.min_occurrences end
        if wc.max_words then CONFIG.max_words = wc.max_words end
        if wc.font_size_min then CONFIG.font_size_min = wc.font_size_min end
        if wc.font_size_max then CONFIG.font_size_max = wc.font_size_max end
        if wc.min_word_length then CONFIG.min_word_length = wc.min_word_length end
        if wc.output_file then CONFIG.output_file = wc.output_file end
        if wc.stop_words_file then CONFIG.stop_words_file = wc.stop_words_file end
        utils.log_info("Loaded word cloud config from input-sources.json")
    end
end
-- }}}

-- Load config on module initialization
load_config_from_json()
-- }}}

-- {{{ load_stop_words
local function load_stop_words()
    local stop_words = {}
    local file_path = DIR .. "/" .. CONFIG.stop_words_file

    local file = io.open(file_path, "r")
    if not file then
        utils.log_warn("Stop words file not found: " .. file_path)
        return stop_words
    end

    for line in file:lines() do
        -- Skip empty lines and comments
        local word = line:match("^%s*(%S+)%s*$")
        if word and not word:match("^#") then
            stop_words[word:lower()] = true
        end
    end
    file:close()

    local count = 0
    for _ in pairs(stop_words) do count = count + 1 end
    utils.log_info(string.format("Loaded %d stop words", count))

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

-- {{{ generate_wordcloud_html
local function generate_wordcloud_html(words, output_dir)
    -- Shuffle words for visual variety (not just sorted by size)
    local shuffled = {}
    for i, w in ipairs(words) do shuffled[i] = w end

    -- Fisher-Yates shuffle
    math.randomseed(os.time())
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    -- Generate word spans
    local word_html = {}
    for _, entry in ipairs(shuffled) do
        -- Use font tag with size attribute (CSS-free)
        local bold_open, bold_close = "", ""
        if entry.font_size >= 5 then
            bold_open, bold_close = "<b>", "</b>"
        end

        table.insert(word_html, string.format(
            '<font size="%d">%s%s%s</font>',
            entry.font_size, bold_open, entry.word, bold_close
        ))
    end

    -- Generate HTML page
    local html = string.format([[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Word Cloud - Poetry Collection</title>
</head>
<body bgcolor="#1a1a2e" text="#ffffff" link="#6cb4ee" vlink="#9370db" alink="#ff6b6b">

<center>
<h1>Word Cloud</h1>
<p>Words sized by frequency across %d poems</p>
<p><a href="chronological/index.html">Back to Chronological Index</a></p>
<hr>
<p>
%s
</p>
<hr>
<p><i>%d unique words shown (minimum %d occurrences)</i></p>
</center>

</body>
</html>]], #words > 0 and words[1].total_poems or 0,
    table.concat(word_html, " &nbsp; "),
    #shuffled, CONFIG.min_occurrences)

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

    -- Generate HTML
    return generate_wordcloud_html(words, output_dir)
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
