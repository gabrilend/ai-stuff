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
-- Usage:
--   luajit src/generate-word-pages.lua [DIR] [--embeddings-only|--html-only]
--   luajit src/generate-word-pages.lua --help
-- }}}

-- {{{ Setup
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end

-- Parse arguments, extracting DIR and mode flags
local function parse_args(args)
    local dir = nil
    local mode = "both"  -- default: both embeddings and HTML

    for i = 1, #(args or {}) do
        local a = args[i]
        if a == "--embeddings-only" then
            mode = "embeddings"
        elseif a == "--html-only" then
            mode = "html"
        elseif a == "--help" or a == "-h" then
            mode = "help"
        elseif a:sub(1, 1) ~= "-" then
            dir = a
        end
    end

    return dir, mode
end

local parsed_dir, RUN_MODE = parse_args(arg)
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
local CONFIG = {
    model_name = "embeddinggemma:latest",
    max_poems_per_page = 100,        -- Poems per word page
    max_pages_per_word = 1,          -- For now, just one page per word
    word_embeddings_file = "word_embeddings.json",
    poems_per_word_page = 50,        -- Show top 50 most similar poems
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

-- {{{ local function generate_word_page
-- Generates HTML page for a single word showing similar poems
local function generate_word_page(word, ranked_poems, output_dir, poems_per_page)
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
<p>Top %d poems ranked by semantic similarity</p>
<p><a href="../wordcloud.html">Back to Word Cloud</a> | <a href="../chronological/index.html">Chronological</a></p>
</center>
<hr>
<table align="center"><tr><td>
<pre>
]], word, word, #top_poems))

    -- Add ranked poems
    for i, entry in ipairs(top_poems) do
        local poem = entry.poem
        local content = poem.content or ""
        -- Escape HTML
        content = content:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")

        -- Truncate long poems
        if #content > 500 then
            content = content:sub(1, 497) .. "..."
        end

        -- Get navigation links
        local poem_index = poem.poem_index or 0
        local base_path = "file:///home/ritz/programming/ai-stuff/neocities-modernization/output"
        local similar_link = string.format('<a href="%s/similar/%04d-01.html">similar</a>', base_path, poem_index)
        local different_link = string.format('<a href="%s/different/%04d-01.html">different</a>', base_path, poem_index)
        local anchor_id = string.format("poem-%s-%04d", poem.category or "unknown", poem.id or 0)
        local chrono_link = string.format('<a href="%s/chronological/index.html#%s">chronological</a>', base_path, anchor_id)

        table.insert(html_parts, string.format(
[[
────────────────────────────────────────────────────────────────────────────────
                           --- #%d (%.3f) ---

%s

                     %s | %s | %s
]], i, entry.similarity, content, similar_link, chrono_link, different_link))
    end

    table.insert(html_parts, [[
────────────────────────────────────────────────────────────────────────────────
</pre>
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

    -- Get word list
    local stop_words = load_stop_words()
    local words = get_word_list(poems_data, stop_words, 5, 200, 3)
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

    return cache_hits + cache_misses
end
-- }}}

-- {{{ function M.generate_word_html
-- Issue 8-043b: Stage 9 - Generate HTML pages only (requires existing embeddings)
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

    -- Build poem index lookup
    local poems_by_index = {}
    for _, poem in ipairs(poems_data.poems) do
        if poem.poem_index then
            poems_by_index[poem.poem_index] = poem
        end
    end

    -- Get word list (same as embedding generation to ensure consistency)
    local stop_words = load_stop_words()
    local words = get_word_list(poems_data, stop_words, 5, 200, 3)

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

            -- Generate page
            if generate_word_page(word, ranked_poems, output_dir, CONFIG.poems_per_word_page) then
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
