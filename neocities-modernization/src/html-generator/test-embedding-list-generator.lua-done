#!/usr/bin/env lua

-- Test Embedding List Generator System
-- Validates similarity and diversity list generation

package.path = package.path .. ';./?.lua;./libs/?.lua'

local utils = require("libs.utils")
local embedding_generator = require("src.html-generator.embedding-list-generator")

local M = {}
local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

-- {{{ function M.test_embedding_list_generation
function M.test_embedding_list_generation()
    utils.log_info("Testing embedding list generation...")
    
    local embeddings_dir = DIR .. "/assets/embeddings"
    local model_name = "embeddinggemma_latest"
    
    -- Test generation
    local success = embedding_generator.generate_all_embedding_lists(embeddings_dir, model_name, {
        chain_length = 10  -- Shorter for testing
    })
    
    if success then
        utils.log_info("✅ Embedding list generation: PASSED")
        
        -- Validate output files exist
        local most_similar_dir = embeddings_dir .. "/" .. model_name .. "/similarity_lists/most_similar"
        local diversity_dir = embeddings_dir .. "/" .. model_name .. "/similarity_lists/diversity_chains"
        
        -- Check sample files
        local sample_files = {
            most_similar_dir .. "/poem-001-most-similar.json",
            diversity_dir .. "/poem-001-diversity-chain.json"
        }
        
        local files_valid = 0
        for _, file_path in ipairs(sample_files) do
            if utils.file_exists(file_path) then
                local data = utils.read_json_file(file_path)
                if data then
                    files_valid = files_valid + 1
                    utils.log_info(string.format("✅ Sample file valid: %s", file_path))
                end
            end
        end
        
        utils.log_info(string.format("Sample validation: %d/%d files valid", files_valid, #sample_files))
        return files_valid >= 1
    else
        utils.log_error("❌ Embedding list generation: FAILED")
        return false
    end
end
-- }}}

-- {{{ function M.run_all_tests
function M.run_all_tests()
    utils.log_info("Running embedding list generator test suite...")
    
    local generation_test = M.test_embedding_list_generation()
    
    if generation_test then
        utils.log_info("🎉 ALL EMBEDDING LIST GENERATOR TESTS PASSED")
    else
        utils.log_error("❌ Some embedding list generator tests FAILED")
    end
    
    return generation_test
end
-- }}}

-- Run tests if called directly
if arg and arg[0] and arg[0]:match("test%-embedding%-list%-generator%.lua$") then
    local success = M.run_all_tests()
    os.exit(success and 0 or 1)
end

return M