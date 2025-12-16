#!/usr/bin/env lua

-- Quick script to regenerate the site with PDF-corrupted poems filtered out
-- This fixes the performance issue caused by embedded PDF binary data

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path
local utils = require("utils")
local flat_generator = require("flat-html-generator")

print("Loading poems data...")
local poems_data = utils.read_json_file(DIR .. "/assets/poems.json")

if not poems_data then
    print("ERROR: Could not load poems.json")
    os.exit(1)
end

print(string.format("Loaded %d poems", #poems_data.poems))

-- Filter out corrupted poems containing PDF data
local filtered_poems = {}
local pdf_poem_count = 0

for _, poem in ipairs(poems_data.poems) do
    if poem.content and (poem.content:find("%%PDF") or poem.content:find("^%PDF")) then
        pdf_poem_count = pdf_poem_count + 1
        print(string.format("Filtering out PDF-corrupted poem ID %d from category %s", 
                          poem.id, poem.category or "unknown"))
    else
        table.insert(filtered_poems, poem)
    end
end

print(string.format("Filtered out %d PDF-corrupted poems", pdf_poem_count))
print(string.format("Remaining poems: %d", #filtered_poems))

-- Update poems data with filtered list
poems_data.poems = filtered_poems

-- Load similarity data
print("Loading similarity matrix...")
local similarity_data = utils.read_json_file(DIR .. "/assets/embeddings/EmbeddingGemma_latest/similarity_matrix.json")

-- Load embeddings data
print("Loading embeddings...")
local embeddings_data = utils.read_json_file(DIR .. "/assets/embeddings/EmbeddingGemma_latest/embeddings.json")

if not similarity_data or not embeddings_data then
    print("WARNING: Could not load similarity/embedding data. Generating chronological index only...")
    -- Generate just the chronological index
    local output_dir = DIR .. "/output"
    print("Generating chronological index...")
    local result = flat_generator.generate_chronological_index_with_navigation(poems_data, output_dir)
    if result then
        print("Successfully generated chronological.html at: " .. result)
    else
        print("ERROR: Failed to generate chronological index")
    end
else
    -- Generate complete site
    print("Generating complete flat HTML collection...")
    local output_dir = DIR .. "/output"
    local results = flat_generator.generate_complete_flat_html_collection(
        poems_data, 
        similarity_data.similarities, 
        embeddings_data, 
        output_dir
    )
    
    if results then
        print("Site generation complete!")
        print(string.format("- Generated %d similarity pages", #results.similarity_pages))
        print(string.format("- Generated %d diversity pages", #results.diversity_pages))
        if results.chronological_index then
            print("- Generated chronological index: " .. results.chronological_index)
        end
        if results.instructions_page then
            print("- Generated instructions page: " .. results.instructions_page)
        end
    else
        print("ERROR: Site generation failed")
    end
end

print("\nDone! The site should now load without performance issues.")