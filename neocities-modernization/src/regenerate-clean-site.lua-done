#!/usr/bin/env lua

-- Quick script to regenerate the site with PDF-corrupted poems filtered out
-- This fixes the performance issue caused by embedded PDF binary data

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path
local utils = require("utils")
local flat_generator = require("flat-html-generator")

-- Initialize asset path configuration (CLI --dir takes precedence over config)
utils.init_assets_root(arg)

require("output").print("Loading poems data...")
local poems_data = utils.read_json_file(utils.asset_path("poems.json"))

if not poems_data then
    require("output").print("ERROR: Could not load poems.json")
    os.exit(1)
end

require("output").print(string.format("Loaded %d poems", #poems_data.poems))

-- Filter out corrupted poems containing PDF data
local filtered_poems = {}
local pdf_poem_count = 0

for _, poem in ipairs(poems_data.poems) do
    if poem.content and (poem.content:find("%%PDF") or poem.content:find("^%PDF")) then
        pdf_poem_count = pdf_poem_count + 1
        require("output").print(string.format("Filtering out PDF-corrupted poem ID %d from category %s", 
                          poem.id, poem.category or "unknown"))
    else
        table.insert(filtered_poems, poem)
    end
end

require("output").print(string.format("Filtered out %d PDF-corrupted poems", pdf_poem_count))
require("output").print(string.format("Remaining poems: %d", #filtered_poems))

-- Update poems data with filtered list
poems_data.poems = filtered_poems

-- Load similarity data
require("output").print("Loading similarity matrix...")
local similarity_data = utils.read_json_file(utils.embeddings_dir() .. "/similarity_matrix.json")

-- Load embeddings data
require("output").print("Loading embeddings...")
local embeddings_data = utils.read_json_file(utils.embeddings_dir() .. "/embeddings.json")

if not similarity_data or not embeddings_data then
    require("output").print("WARNING: Could not load similarity/embedding data. Generating chronological index only...")
    -- Generate just the chronological index (HTML and TXT)
    local output_dir = DIR .. "/output"
    require("output").print("Generating chronological index...")
    -- the pages are built by worker threads (Issue 8-058); the count is the
    -- second argument, required
    local threads = tonumber(arg[2]) or error("usage: regenerate-clean-site.lua DIR THREADS")
    local result = flat_generator.generate_chronological_index_with_navigation(poems_data, output_dir, nil, threads)
    if result then
        require("output").print("Successfully generated chronological.html at: " .. result)
    else
        require("output").print("ERROR: Failed to generate chronological HTML index")
    end
    local txt_result = flat_generator.generate_chronological_txt_file(poems_data, output_dir .. "/chronological.txt")
    if txt_result then
        require("output").print("Successfully generated chronological.txt at: " .. txt_result)
    else
        require("output").print("ERROR: Failed to generate chronological TXT export")
    end
else
    -- Generate complete site
    require("output").print("Generating complete flat HTML collection...")
    local output_dir = DIR .. "/output"
    local results = flat_generator.generate_complete_flat_html_collection(
        poems_data, 
        similarity_data.similarities, 
        embeddings_data, 
        output_dir
    )
    
    if results then
        require("output").print("Site generation complete!")
        require("output").print(string.format("- Generated %d similarity pages", #results.similarity_pages))
        require("output").print(string.format("- Generated %d diversity pages", #results.diversity_pages))
        if results.chronological_index then
            require("output").print("- Generated chronological index: " .. results.chronological_index)
        end
        if results.chronological_txt then
            require("output").print("- Generated chronological TXT: " .. results.chronological_txt)
        end
        if results.instructions_page then
            require("output").print("- Generated instructions page: " .. results.instructions_page)
        end
    else
        require("output").print("ERROR: Site generation failed")
    end
end

require("output").print("\nDone! The site should now load without performance issues.")
