#!/usr/bin/env lua

-- Test similarity navigation integration
-- Tests complete poem page generation with real similarity data

package.path = package.path .. ';./?.lua;./libs/?.lua'

local utils = require("libs.utils")
local template_engine = require("src.html-generator.template-engine")
local url_manager = require("src.html-generator.url-manager")
local similarity_engine = require("src.html-generator.similarity-engine")

local M = {}
local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

-- {{{ function M.test_similarity_navigation
function M.test_similarity_navigation()
    utils.log_info("Testing similarity navigation integration...")
    
    -- Load poems data
    local poems_data = template_engine.load_poems_data()
    if not poems_data then
        utils.log_error("Failed to load poems data")
        return false
    end
    
    -- Ensure directory structure exists
    url_manager.create_directory_structure()
    
    -- Find a poem with similarity data
    local test_poem_id = 1  -- We know this has similarity data
    local test_poem = similarity_engine.get_poem_metadata(test_poem_id, poems_data)
    
    if not test_poem then
        utils.log_error("Test poem not found")
        return false
    end
    
    utils.log_info(string.format("Testing with poem %d (%s category)", 
                                test_poem_id, test_poem.category or "unknown"))
    
    -- Generate HTML with real similarity data
    local html = template_engine.generate_poem_html(test_poem, poems_data)
    
    if not html then
        utils.log_error("Failed to generate HTML with similarity navigation")
        return false
    end
    
    -- Validate HTML contains similarity features
    local validations = {
        {name = "Similarity list", pattern = '<ol class="similarity%-list">'},
        {name = "Exploration controls", pattern = '<div class="exploration%-controls">'},
        {name = "Random discovery link", pattern = '🎲 Discover Random Poem'},
        {name = "Category browse link", pattern = '📁 Browse All'},
        {name = "Golden collection link", pattern = '✨ Golden Poem Collection'},
        {name = "Similarity scores", pattern = 'similarity%)'}
    }
    
    local passed_validations = 0
    for _, validation in ipairs(validations) do
        if html:match(validation.pattern) then
            utils.log_info("✅ " .. validation.name .. " - FOUND")
            passed_validations = passed_validations + 1
        else
            utils.log_warn("❌ " .. validation.name .. " - MISSING")
        end
    end
    
    utils.log_info(string.format("HTML validation: %d/%d features found", 
                                passed_validations, #validations))
    
    -- Write test file
    local output_file = DIR .. "/generated-site/poems/fediverse/poem-001.html"
    local success = utils.write_file(output_file, html)
    
    if not success then
        utils.log_error("Failed to write test similarity navigation file")
        return false
    end
    
    utils.log_info("✅ Generated test file with similarity navigation: " .. output_file)
    utils.log_info(string.format("File size: %d characters", html:len()))
    
    return passed_validations >= 4  -- Require at least 4/6 features
end
-- }}}

-- {{{ function M.test_multiple_poems
function M.test_multiple_poems()
    utils.log_info("Testing similarity navigation with multiple poems...")
    
    local poems_data = template_engine.load_poems_data()
    if not poems_data then return false end
    
    -- Test poems with and without similarity data
    local test_cases = {
        {poem_id = 1, has_similarity = true},     -- Known to have similarity data
        {poem_id = 5000, has_similarity = false}  -- Likely no similarity data
    }
    
    local successful_generations = 0
    
    for i, test_case in ipairs(test_cases) do
        local poem = similarity_engine.get_poem_metadata(test_case.poem_id, poems_data)
        if poem then
            utils.log_info(string.format("Test %d: Poem %d (%s)", 
                                        i, test_case.poem_id, poem.category or "unknown"))
            
            local html = template_engine.generate_poem_html(poem, poems_data)
            
            if html then
                -- Check appropriate fallback behavior
                local has_similarity = html:match("similarity%)")
                local has_fallback = html:match("Similarity data not yet available") or 
                                   html:match("Discovering poems for you")
                
                if test_case.has_similarity and has_similarity then
                    utils.log_info("✅ Similarity data correctly used")
                    successful_generations = successful_generations + 1
                elseif not test_case.has_similarity and has_fallback then
                    utils.log_info("✅ Fallback recommendations correctly used")
                    successful_generations = successful_generations + 1
                else
                    utils.log_warn("⚠️  Unexpected behavior in recommendations")
                end
                
                -- Write test file
                local category = url_manager.get_poem_category(poem)
                local url = url_manager.generate_poem_url(test_case.poem_id, category)
                local output_file = url_manager.generate_absolute_path(url)
                utils.write_file(output_file, html)
                
            else
                utils.log_error("Failed to generate HTML for poem " .. test_case.poem_id)
            end
        else
            utils.log_warn("Poem " .. test_case.poem_id .. " not found")
        end
    end
    
    utils.log_info(string.format("Multiple poem test: %d/%d successful", 
                                successful_generations, #test_cases))
    
    return successful_generations == #test_cases
end
-- }}}

-- {{{ function M.test_similarity_engine_stats
function M.test_similarity_engine_stats()
    utils.log_info("Testing similarity engine statistics...")
    
    local stats = similarity_engine.get_similarity_stats()
    
    utils.log_info("Similarity Engine Statistics:")
    utils.log_info(string.format("  Model: %s", stats.model))
    utils.log_info(string.format("  Individual files: %d", stats.individual_files))
    utils.log_info(string.format("  Matrix exists: %s", stats.matrix_exists and "yes" or "no"))
    
    if stats.matrix_metadata then
        utils.log_info(string.format("  Matrix completeness: %.1f%%", 
                                    (stats.matrix_metadata.matrix_completeness or 0) * 100))
        utils.log_info(string.format("  Poems with embeddings: %d/%d", 
                                    stats.matrix_metadata.embedding_count,
                                    stats.matrix_metadata.total_poems))
    end
    
    -- Validation
    local has_data = stats.individual_files > 0 or stats.matrix_exists
    if has_data then
        utils.log_info("✅ Similarity data available")
        return true
    else
        utils.log_warn("⚠️  No similarity data found")
        return false
    end
end
-- }}}

-- {{{ function M.run_all_tests
function M.run_all_tests()
    utils.log_info("Running similarity navigation test suite...")
    
    local stats_test = M.test_similarity_engine_stats()
    local navigation_test = M.test_similarity_navigation()
    local multiple_test = M.test_multiple_poems()
    
    local all_passed = stats_test and navigation_test and multiple_test
    
    if all_passed then
        utils.log_info("🎉 ALL SIMILARITY NAVIGATION TESTS PASSED")
    else
        utils.log_error("❌ Some similarity navigation tests FAILED")
    end
    
    return all_passed
end
-- }}}

-- Run tests if called directly
if arg and arg[0] and arg[0]:match("test%-similarity%-navigation%.lua$") then
    local success = M.run_all_tests()
    os.exit(success and 0 or 1)
end

return M