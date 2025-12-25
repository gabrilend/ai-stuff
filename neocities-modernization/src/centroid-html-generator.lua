#!/usr/bin/env lua

-- Centroid HTML Generator
-- Generates exploration pages based on user-defined centroid embeddings.
-- Each centroid gets a similarity page (poems most like that mood) and
-- a diversity page (poems least like that mood).
--
-- This module extends the flat-html-generator with centroid-based navigation.

-- {{{ local function setup_dir_path
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

-- Script configuration
local DIR = setup_dir_path()

-- Load required libraries
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path
local utils = require("utils")
local dkjson = require("dkjson")

local M = {}

-- {{{ local function cosine_similarity
-- Calculates cosine similarity between two embedding vectors
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

-- {{{ function M.load_centroids
-- Loads generated centroid embeddings from the embeddings directory
function M.load_centroids(model_name)
    model_name = model_name or "embeddinggemma_latest"
    local centroids_file = utils.embeddings_dir(model_name) .. "/centroids.json"

    local content, err = utils.read_file(centroids_file)
    if not content then
        utils.log_warn("Could not load centroids: " .. (err or "file not found"))
        utils.log_warn("Run centroid-generator.lua first to create centroid embeddings")
        return nil
    end

    local data = dkjson.decode(content)
    if not data or not data.centroids then
        utils.log_error("Invalid centroids file format")
        return nil
    end

    local count = 0
    for _ in pairs(data.centroids) do count = count + 1 end
    utils.log_info(string.format("Loaded %d centroid embeddings", count))

    return data
end
-- }}}

-- {{{ local function build_embeddings_lookup
-- Converts the array-format embeddings to a lookup table by poem ID
local function build_embeddings_lookup(embeddings_data)
    local lookup = {}

    if not embeddings_data or not embeddings_data.embeddings then
        return lookup
    end

    -- Handle array format: [{id: 1, embedding: [...]}, {id: 2, embedding: [...]}, ...]
    if type(embeddings_data.embeddings) == "table" then
        for _, entry in ipairs(embeddings_data.embeddings) do
            if entry.id and entry.embedding then
                lookup[tostring(entry.id)] = entry.embedding
            end
        end
    end

    return lookup
end
-- }}}

-- {{{ function M.generate_centroid_similarity_ranking
-- Ranks all poems by their similarity to a centroid embedding
function M.generate_centroid_similarity_ranking(centroid_data, poems_data, embeddings_data)
    local centroid_embedding = centroid_data.embedding

    if not centroid_embedding then
        utils.log_error("Centroid has no embedding: " .. (centroid_data.name or "unknown"))
        return nil
    end

    -- Build lookup table from array-format embeddings
    local embeddings_lookup = build_embeddings_lookup(embeddings_data)

    local ranked_poems = {}

    -- Calculate similarity for each poem
    for poem_id, poem in ipairs(poems_data.poems) do
        if poem.id then
            local poem_embedding = embeddings_lookup[tostring(poem.id)]

            local similarity = 0
            if poem_embedding and type(poem_embedding) == "table" and #poem_embedding > 0 then
                similarity = cosine_similarity(centroid_embedding, poem_embedding)
            end

            table.insert(ranked_poems, {
                id = poem.id,
                poem = poem,
                similarity = similarity
            })
        end
    end

    -- Sort by similarity (descending = most similar first)
    table.sort(ranked_poems, function(a, b)
        return a.similarity > b.similarity
    end)

    -- Add rank numbers
    for i, poem_info in ipairs(ranked_poems) do
        poem_info.rank = i
    end

    return ranked_poems
end
-- }}}

-- {{{ function M.generate_centroid_diversity_ranking
-- Ranks all poems by their diversity from a centroid (least similar first)
function M.generate_centroid_diversity_ranking(centroid_data, poems_data, embeddings_data)
    -- Get similarity ranking first
    local ranked_poems = M.generate_centroid_similarity_ranking(centroid_data, poems_data, embeddings_data)

    if not ranked_poems then
        return nil
    end

    -- Reverse the order (least similar first)
    local reversed = {}
    for i = #ranked_poems, 1, -1 do
        table.insert(reversed, ranked_poems[i])
    end

    -- Re-assign rank numbers
    for i, poem_info in ipairs(reversed) do
        poem_info.rank = i
        -- Convert similarity to "diversity" score (1 - similarity)
        poem_info.diversity = 1 - poem_info.similarity
    end

    return reversed
end
-- }}}

-- {{{ local function generate_centroid_header
-- Creates the header section for centroid pages
local function generate_centroid_header(centroid_data, page_type, total_poems)
    local title = string.format("%s - %s exploration",
        centroid_data.name,
        page_type == "similar" and "Similar" or "Different")

    local description = centroid_data.description or ""

    local header = string.format([[<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>%s</title>
</head>
<body>
<pre>
================================================================================
                              %s
================================================================================

Theme: %s
Description: %s
Mode: %s poems %s
Total poems: %d

Navigation: <a href="../chronological.html">chronological</a> | <a href="../explore.html">explore</a> | <a href="../centroid/">all moods</a>
This page: <a href="%s-similar.html">similar</a> | <a href="%s-different.html">different</a>

================================================================================

]],
        title,
        string.upper(centroid_data.name),
        centroid_data.name,
        description,
        page_type == "similar" and "most" or "least",
        page_type == "similar" and "like this mood" or "like this mood",
        total_poems,
        centroid_data.output_slug,
        centroid_data.output_slug
    )

    return header
end
-- }}}

-- {{{ local function generate_centroid_footer
local function generate_centroid_footer()
    return [[
================================================================================
                                 END OF COLLECTION
================================================================================
</pre>
</body>
</html>
]]
end
-- }}}

-- {{{ local function format_poem_for_centroid_page
-- Formats a single poem entry for the centroid page
local function format_poem_for_centroid_page(poem_info, page_type)
    local poem = poem_info.poem
    local content = poem.content or poem.text or "[No content]"

    -- Clean up content
    content = content:gsub("\r\n", "\n"):gsub("\r", "\n")

    local score_label = page_type == "similar" and "similarity" or "diversity"
    local score = page_type == "similar" and poem_info.similarity or poem_info.diversity

    local entry = string.format([[
--------------------------------------------------------------------------------
#%d | Poem %s | %s: %.4f
--------------------------------------------------------------------------------
<a href="../similar/%03d.html">[similar]</a> <a href="../different/%03d.html">[different]</a>

%s

]],
        poem_info.rank,
        poem.id,
        score_label,
        score or 0,
        poem.id,
        poem.id,
        content
    )

    return entry
end
-- }}}

-- {{{ function M.generate_centroid_html_page
-- Generates a complete HTML page for a centroid (similar or different)
function M.generate_centroid_html_page(centroid_data, ranked_poems, page_type)
    local parts = {}

    -- Header
    table.insert(parts, generate_centroid_header(centroid_data, page_type, #ranked_poems))

    -- Poem entries
    for _, poem_info in ipairs(ranked_poems) do
        table.insert(parts, format_poem_for_centroid_page(poem_info, page_type))
    end

    -- Footer
    table.insert(parts, generate_centroid_footer())

    return table.concat(parts)
end
-- }}}

-- {{{ function M.generate_centroid_index_page
-- Generates an index page listing all available mood centroids
function M.generate_centroid_index_page(centroids_data)
    local parts = {}

    table.insert(parts, [[<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Mood Exploration - Centroids</title>
</head>
<body>
<pre>
================================================================================
                            MOOD-BASED EXPLORATION
================================================================================

Browse poems by emotional tone or thematic cluster. Each mood has two views:
- Similar: poems that resonate with this mood
- Different: poems that contrast with this mood

Navigation: <a href="../chronological.html">chronological</a> | <a href="../explore.html">explore</a>

================================================================================
                              AVAILABLE MOODS
================================================================================

]])

    -- Sort centroids by name for consistent ordering
    local sorted_slugs = {}
    for slug, _ in pairs(centroids_data.centroids) do
        table.insert(sorted_slugs, slug)
    end
    table.sort(sorted_slugs)

    for _, slug in ipairs(sorted_slugs) do
        local centroid = centroids_data.centroids[slug]
        local entry = string.format([[
--- %s ---
%s

  <a href="%s-similar.html">[similar poems]</a>  <a href="%s-different.html">[different poems]</a>

]],
            string.upper(centroid.name),
            centroid.description or "",
            slug,
            slug
        )
        table.insert(parts, entry)
    end

    table.insert(parts, [[
================================================================================
                              ABOUT MOOD CENTROIDS
================================================================================

These mood pages are generated from custom "centroid" embeddings - semantic
fingerprints created by combining keywords and source texts that represent
each mood. When you visit a mood's "similar" page, you see all poems ranked
by how closely they match that emotional signature.

To add new moods, edit: assets/centroids.json
Then run: lua src/centroid-generator.lua

================================================================================
</pre>
</body>
</html>
]])

    return table.concat(parts)
end
-- }}}

-- {{{ function M.generate_all_centroid_pages
-- Main function to generate all centroid-based HTML pages
function M.generate_all_centroid_pages(poems_data, embeddings_data, output_dir)
    local model_name = "embeddinggemma_latest"

    -- Load centroids
    local centroids_data = M.load_centroids(model_name)
    if not centroids_data then
        utils.log_warn("No centroids available - skipping centroid page generation")
        return nil
    end

    -- Create output directory
    local centroid_dir = output_dir .. "/centroid"
    os.execute("mkdir -p " .. centroid_dir)

    local results = {
        similar_pages = {},
        different_pages = {},
        index_page = nil
    }

    -- Generate pages for each centroid
    for slug, centroid_data in pairs(centroids_data.centroids) do
        utils.log_info(string.format("Generating centroid pages: %s", centroid_data.name))

        -- Generate similarity ranking
        local similar_ranking = M.generate_centroid_similarity_ranking(
            centroid_data, poems_data, embeddings_data)

        if similar_ranking then
            -- Generate similar page
            local similar_html = M.generate_centroid_html_page(centroid_data, similar_ranking, "similar")
            local similar_file = centroid_dir .. "/" .. slug .. "-similar.html"

            if utils.write_file(similar_file, similar_html) then
                table.insert(results.similar_pages, similar_file)
                utils.log_info(string.format("  Created: %s-similar.html", slug))
            end

            -- Generate different page (reverse order)
            local different_ranking = M.generate_centroid_diversity_ranking(
                centroid_data, poems_data, embeddings_data)

            if different_ranking then
                local different_html = M.generate_centroid_html_page(centroid_data, different_ranking, "different")
                local different_file = centroid_dir .. "/" .. slug .. "-different.html"

                if utils.write_file(different_file, different_html) then
                    table.insert(results.different_pages, different_file)
                    utils.log_info(string.format("  Created: %s-different.html", slug))
                end
            end
        else
            utils.log_warn(string.format("  Could not generate ranking for: %s", centroid_data.name))
        end
    end

    -- Generate index page
    local index_html = M.generate_centroid_index_page(centroids_data)
    local index_file = centroid_dir .. "/index.html"

    if utils.write_file(index_file, index_html) then
        results.index_page = index_file
        utils.log_info("Created: centroid/index.html")
    end

    utils.log_info(string.format("Centroid generation complete: %d similar, %d different pages",
        #results.similar_pages, #results.different_pages))

    return results
end
-- }}}

-- {{{ Main execution
if arg and arg[0] and arg[0]:match("centroid%-html%-generator%.lua$") then
    utils.log_info("=== Centroid HTML Generator ===")
    utils.log_info("Generating mood-based exploration pages")
    utils.log_info("")

    -- Load poems data
    local poems_file = utils.get_assets_root() .. "/poems.json"
    local poems_content = utils.read_file(poems_file)
    if not poems_content then
        utils.log_error("Could not load poems.json")
        os.exit(1)
    end
    local poems_data = dkjson.decode(poems_content)

    -- Load embeddings data
    local embeddings_file = utils.embeddings_dir("embeddinggemma_latest") .. "/embeddings.json"
    local embeddings_content = utils.read_file(embeddings_file)
    if not embeddings_content then
        utils.log_error("Could not load embeddings.json")
        os.exit(1)
    end
    local embeddings_data = dkjson.decode(embeddings_content)

    -- Generate pages
    local output_dir = DIR .. "/output"
    local results = M.generate_all_centroid_pages(poems_data, embeddings_data, output_dir)

    if results then
        utils.log_info("\n=== Summary ===")
        utils.log_info(string.format("Similar pages: %d", #results.similar_pages))
        utils.log_info(string.format("Different pages: %d", #results.different_pages))
        utils.log_info(string.format("Index page: %s", results.index_page and "created" or "failed"))
    else
        utils.log_error("Centroid page generation failed")
        os.exit(1)
    end
end
-- }}}

return M
