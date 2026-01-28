#!/usr/bin/env luajit

-- {{{ generate-word-pages.lua
-- Issue 8-043: Generate similarity pages for word cloud words
-- Issue 8-043b: Separated into two stages for proper pipeline integration
--
-- For each word in the word cloud, generates a page showing poems ranked by
-- their semantic similarity to that word's embedding.
--
-- Modes:
--   --embeddings-only   Stage 6: Generate word embeddings (expensive, via Ollama)
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
            max_words = tonumber(args[i + 1])
            i = i + 2
        elseif a:match("^--words=") then
            max_words = tonumber(a:match("^--words=(.+)$"))
            i = i + 1
        -- Issue 8-050d: Parse poems-per-page argument
        elseif a == "--poems-per-page" then
            poems_per_page = tonumber(args[i + 1])
            i = i + 2
        elseif a:match("^--poems%-per%-page=") then
            poems_per_page = tonumber(a:match("^--poems%-per%-page=(.+)$"))
            i = i + 1
        elseif a:sub(1, 1) ~= "-" then
            dir = a
            i = i + 1
        else
            -- Skip unknown flags
            i = i + 1
        end
    end

    return dir, mode, all_words, max_words, poems_per_page
end
-- }}}

local parsed_dir, RUN_MODE, CLI_ALL_WORDS, CLI_MAX_WORDS, CLI_POEMS_PER_PAGE = parse_args(arg)
local DIR = setup_dir_path(parsed_dir)
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path

local dkjson = require("dkjson")
local utils = require("utils")
local ollama_config = require("ollama-config")

-- Issue 10-003: Load unified config from config.lua
local config_loader = require("config-loader")
config_loader.set_project_root(DIR)
local unified_config = config_loader.load()

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

local CONFIG = {
    model_name = "embeddinggemma:latest",
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

-- {{{ local function generate_single_embedding
-- Generates embedding for a single word via Ollama
local function generate_single_embedding(word, endpoint)
    local temp_file = "/tmp/word_embedding_input.json"
    local payload = {
        model = CONFIG.model_name,
        prompt = word
    }

    -- Write request payload
    local file = io.open(temp_file, "w")
    if not file then
        return nil, "failed_to_write_temp"
    end
    file:write(dkjson.encode(payload))
    file:close()

    -- Call Ollama
    local cmd = string.format(
        'curl -s -X POST "%s/api/embeddings" -H "Content-Type: application/json" -d @%s 2>/dev/null',
        endpoint, temp_file
    )

    local handle = io.popen(cmd)
    if not handle then
        return nil, "failed_to_call_ollama"
    end

    local response = handle:read("*a")
    handle:close()

    -- Parse response
    local data = dkjson.decode(response)
    if not data or not data.embedding then
        return nil, "invalid_response"
    end

    return data.embedding, "success"
end
-- }}}

-- {{{ local function load_word_embeddings_cache
local function load_word_embeddings_cache()
    local cache_file = utils.embeddings_dir("embeddinggemma_latest") .. "/" .. CONFIG.word_embeddings_file
    local data = utils.read_json_file(cache_file)
    return data and data.embeddings or {}
end
-- }}}

-- {{{ local function save_word_embeddings_cache
local function save_word_embeddings_cache(embeddings)
    local cache_file = utils.embeddings_dir("embeddinggemma_latest") .. "/" .. CONFIG.word_embeddings_file
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
    local color_file = utils.embeddings_dir("embeddinggemma_latest") .. "/color_embeddings.json"
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
    local cache_file = utils.embeddings_dir("embeddinggemma_latest") .. "/word_colors.json"
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
    local cache_file = utils.embeddings_dir("embeddinggemma_latest") .. "/word_colors.json"
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
    table.sort(filtered, function(a, b) return a.count > b.count end)

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
-- Uses CHRONOLOGICAL position for progress bar (same as similar/different pages)
-- This helps users orient themselves in the timeline/story
local function format_poem_for_word_page(poem, rank, similarity, poem_colors, color_config, chrono_map)
    local poem_idx = poem.poem_index or 0

    -- Get semantic color for this poem (default to gray)
    local poem_color_data = poem_colors and poem_colors[poem_idx]
    local semantic_color = poem_color_data and poem_color_data.color or "gray"
    local hex_color = color_config and color_config[semantic_color] or "#888888"

    -- Check if golden poem (metadata-based detection)
    local is_golden = poem.metadata and poem.metadata.is_golden_poem

    -- Use CHRONOLOGICAL position for progress bar (not similarity score)
    -- This matches similar/different pages and helps orient the reader in the story
    local chrono_info = chrono_map and chrono_map[poem_idx] or {position = 1, total_poems = 1}
    local progress_pct = (chrono_info.position / chrono_info.total_poems) * 100

    -- Calculate progress bar chars
    -- Regular: 83 chars total, Golden: 82 interior + 2 corners = 84 total
    local total_bar_chars = is_golden and 82 or 83
    local progress_chars = math.floor((progress_pct / 100) * total_bar_chars)
    local remaining_chars = total_bar_chars - progress_chars

    -- Build top progress bar with color
    local progress_section = string.rep("═", progress_chars)
    local remaining_section = string.rep("─", remaining_chars)
    local colored_progress
    if is_golden then
        local left_corner = string.format('<font color="%s"><b>╔</b></font>', hex_color)
        colored_progress = left_corner .. string.format('<font color="%s"><b>%s</b></font>%s',
            hex_color, progress_section, remaining_section) .. "┐"
    else
        colored_progress = string.format('<font color="%s"><b>%s</b></font>%s',
            hex_color, progress_section, remaining_section)
    end

    -- Navigation links
    local base_path = "file:///home/ritz/programming/ai-stuff/neocities-modernization/output"
    local similar_link = string.format("<a href='%s/similar/%04d-01.html'>similar</a>", base_path, poem_idx)
    local different_link = string.format("<a href='%s/different/%04d-01.html'>different</a>", base_path, poem_idx)
    local anchor_id = string.format("poem-%s-%04d", poem.category or "unknown", poem.id or 0)
    local chrono_link = string.format("<a href='%s/chronological/index.html#%s'>chronological</a>", base_path, anchor_id)

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

    -- Build navigation box
    local nav_top, nav_mid
    if is_golden then
        -- Golden: 84 chars total
        local colored_corner = string.format('<font color="%s"><b>╟</b></font>', hex_color)
        local left_sep = colored_corner
        for i = 1, 9 do left_sep = left_sep .. color_char("─", i) end
        left_sep = left_sep .. color_char("┐", 10)

        local right_sep = color_char("┌", 71)
        for i = 72, 82 do right_sep = right_sep .. color_char("─", i) end
        right_sep = right_sep .. color_char("┤", 83)

        nav_top = left_sep .. string.rep(" ", 60) .. right_sep

        local colored_wall = string.format('<font color="%s"><b>║</b></font>', hex_color)
        local right_wall_of_left = color_char("│", 10)
        local left_wall_of_right = color_char("│", 71)
        local right_end = color_char("│", 83)
        nav_mid = colored_wall .. " " .. similar_link .. " " .. right_wall_of_left .. string.rep(" ", 23) .. chrono_link .. string.rep(" ", 23) .. left_wall_of_right .. " " .. different_link .. " " .. right_end
    else
        -- Regular: 83 chars total
        local left_top = {}
        table.insert(left_top, color_char("┌", 0))
        for i = 1, 9 do table.insert(left_top, color_char("─", i)) end
        table.insert(left_top, color_char("┐", 10))

        local right_top = {}
        table.insert(right_top, color_char("┌", 70))
        for i = 71, 81 do table.insert(right_top, color_char("─", i)) end
        table.insert(right_top, color_char("┐", 82))

        nav_top = table.concat(left_top) .. string.rep(" ", 59) .. table.concat(right_top)

        local left_wall = color_char("│", 0)
        local right_wall_of_left = color_char("│", 10)
        local left_wall_of_right = color_char("│", 70)
        local right_wall = color_char("│", 82)
        nav_mid = left_wall .. " " .. similar_link .. " " .. right_wall_of_left .. string.rep(" ", 23) .. chrono_link .. string.rep(" ", 23) .. left_wall_of_right .. " " .. different_link .. " " .. right_wall
    end

    -- Build bottom progress bar with junction characters
    local TOTAL_CHARS = is_golden and 82 or 83
    local LEFT_JUNCTION = is_golden and 9 or 10
    local RIGHT_JUNCTION = is_golden and 70 or 70

    local left_junction = (LEFT_JUNCTION < progress_chars)
        and string.format('<font color="%s"><b>╧</b></font>', hex_color) or "┴"
    local right_junction = (RIGHT_JUNCTION < progress_chars)
        and string.format('<font color="%s"><b>╧</b></font>', hex_color) or "┴"

    local function build_segment(start_pos, end_pos)
        if end_pos <= start_pos then return "" end
        local seg_len = end_pos - start_pos
        local progress_in_seg = math.max(0, math.min(seg_len, progress_chars - start_pos))
        local remaining_in_seg = seg_len - progress_in_seg
        local result = ""
        if progress_in_seg > 0 then
            result = result .. string.format('<font color="%s"><b>%s</b></font>', hex_color, string.rep("═", progress_in_seg))
        end
        if remaining_in_seg > 0 then
            result = result .. string.rep("─", remaining_in_seg)
        end
        return result
    end

    local corner_char = is_golden and "╚" or "╘"
    local colored_corner = string.format('<font color="%s"><b>%s</b></font>', hex_color, corner_char)
    local bottom_line = colored_corner
        .. build_segment(1, LEFT_JUNCTION)
        .. left_junction
        .. build_segment(LEFT_JUNCTION + 1, RIGHT_JUNCTION)
        .. right_junction
        .. build_segment(RIGHT_JUNCTION + 1, TOTAL_CHARS - 1)
        .. "┘"

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
    table.insert(output, poem_identifier)
    table.insert(output, "")
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
-- Progress bar shows CHRONOLOGICAL position (not similarity) to orient readers
local function generate_word_page(word, ranked_poems, output_dir, poems_per_page, poem_colors, color_config, chrono_map)
    local safe_word = word:lower():gsub("[^%w]", "")
    local output_file = output_dir .. "/wordcloud/" .. safe_word .. ".html"

    -- Ensure directory exists
    os.execute('mkdir -p "' .. output_dir .. '/wordcloud"')

    -- Take top N poems
    local top_poems = {}
    for i = 1, math.min(poems_per_page, #ranked_poems) do
        top_poems[i] = ranked_poems[i]
    end

    -- Generate HTML
    local html_parts = {}
    table.insert(html_parts, string.format([[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Poems similar to: %s</title>
</head>
<body bgcolor="#000000" text="#FFFFFF" link="#6699FF" vlink="#9966FF">
<center>
<h1>Poems similar to: <i>%s</i></h1>
<p>Top %d poems ranked by semantic similarity (progress bar shows chronological position)</p>
<p><a href="file:///home/ritz/programming/ai-stuff/neocities-modernization/output/wordcloud.html">Back to Word Cloud</a> │ <a href="file:///home/ritz/programming/ai-stuff/neocities-modernization/output/chronological/index.html">Chronological</a></p>
</center>
<hr>
<table align="center"><tr><td>
<pre>
]], word, word, #top_poems))

    -- Add ranked poems using box-drawing format
    for i, entry in ipairs(top_poems) do
        local formatted = format_poem_for_word_page(entry.poem, i, entry.similarity, poem_colors, color_config, chrono_map)
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

    -- Check Ollama availability
    local endpoint = ollama_config.OLLAMA_ENDPOINT
    utils.log_info("Using Ollama endpoint: " .. endpoint)

    -- Load poems for word extraction
    local poems_file = utils.asset_path("poems.json")
    local poems_data = utils.read_json_file(poems_file)
    if not poems_data then
        utils.log_error("Could not load poems.json")
        return nil
    end
    utils.log_info(string.format("Loaded %d poems", #poems_data.poems))

    -- Get word list (using CONFIG.max_words from CLI or config)
    local stop_words = load_stop_words()
    local words = get_word_list(poems_data, stop_words, 5, CONFIG.max_words, 3)
    utils.log_info(string.format("Processing %d words", #words))

    -- Load cached word embeddings
    local word_embeddings = load_word_embeddings_cache()
    local cache_hits = 0
    local cache_misses = 0

    -- Generate embeddings for missing words
    for i, word in ipairs(words) do
        if not word_embeddings[word] then
            io.write(string.format("\rGenerating word embedding %d/%d: %s          ", i, #words, word))
            io.flush()

            local embedding, status = generate_single_embedding(word, endpoint)
            if embedding then
                word_embeddings[word] = embedding
                cache_misses = cache_misses + 1

                -- Save cache periodically
                if cache_misses % 10 == 0 then
                    save_word_embeddings_cache(word_embeddings)
                end
            else
                utils.log_warn(string.format("Failed to embed word '%s': %s", word, status or "unknown"))
            end
        else
            cache_hits = cache_hits + 1
        end
    end
    print("")  -- Newline after progress

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
    utils.log_info(string.format("Loaded %d poems", #poems_data.poems))

    -- Load poem embeddings
    local embeddings_file = utils.embeddings_dir("embeddinggemma_latest") .. "/embeddings.json"
    local embeddings_data = utils.read_json_file(embeddings_file)
    if not embeddings_data then
        utils.log_error("Could not load poem embeddings - run --generate-embeddings first")
        return nil
    end
    local poem_lookup = build_poem_embeddings_lookup(embeddings_data)
    utils.log_info("Built poem embeddings lookup")

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
    local poem_colors_file = utils.asset_path("poem_colors.json")
    local poem_colors_data = utils.read_json_file(poem_colors_file)
    local poem_colors = {}
    if poem_colors_data and poem_colors_data.poem_colors then
        for _, entry in ipairs(poem_colors_data.poem_colors) do
            if entry.poem_index then
                poem_colors[entry.poem_index] = entry
            end
        end
        utils.log_info(string.format("Loaded semantic colors for %d poems", #poem_colors_data.poem_colors))
    else
        utils.log_warn("No poem colors found - using default gray")
    end

    -- Issue 8-050a: Load word colors for per-word semantic coloring
    local word_colors = load_word_colors_cache()
    local word_color_count = 0
    for _ in pairs(word_colors) do word_color_count = word_color_count + 1 end
    if word_color_count > 0 then
        utils.log_info(string.format("Loaded semantic colors for %d words", word_color_count))
    else
        utils.log_warn("No word colors found - run --embeddings-only to generate them")
    end

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
    local chrono_map = {}
    do
        -- Sort poems chronologically by creation_date
        local sorted_poems = {}
        for _, poem in ipairs(poems_data.poems) do
            table.insert(sorted_poems, poem)
        end
        table.sort(sorted_poems, function(a, b)
            local date_a = a.creation_date or ""
            local date_b = b.creation_date or ""
            return date_a < date_b
        end)

        local total_poems = #sorted_poems
        for position, poem in ipairs(sorted_poems) do
            if poem.poem_index then
                chrono_map[poem.poem_index] = {
                    position = position,
                    total_poems = total_poems
                }
            end
        end
        utils.log_info(string.format("Built chronological mapping for %d poems", total_poems))
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

            -- Compute similarity to all poems
            local ranked_poems = {}
            for poem_id_str, poem_embedding in pairs(poem_lookup) do
                local poem_id = tonumber(poem_id_str)
                local poem = poems_by_index[poem_id]
                if poem and poem_embedding then
                    local similarity = cosine_similarity(word_embedding, poem_embedding)
                    table.insert(ranked_poems, {
                        poem = poem,
                        similarity = similarity
                    })
                end
            end

            -- Sort by similarity (descending)
            table.sort(ranked_poems, function(a, b)
                return a.similarity > b.similarity
            end)

            -- Generate page with semantic colors and chronological position
            if generate_word_page(word, ranked_poems, output_dir, CONFIG.poems_per_word_page, poem_colors, color_config, chrono_map) then
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
