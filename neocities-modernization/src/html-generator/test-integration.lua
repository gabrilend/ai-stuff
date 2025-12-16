#!/usr/bin/env lua

-- Integration test for URL structure and template system
-- Tests complete poem page generation with proper URLs

package.path = package.path .. ';./?.lua;./libs/?.lua'

local utils = require("libs.utils")
local template_engine = require("src.html-generator.template-engine")
local url_manager = require("src.html-generator.url-manager")
local golden_collection = require("src.html-generator.golden-collection-generator")

local M = {}

-- {{{ function M.test_poem_page_generation
function M.test_poem_page_generation()
    utils.log_info("Testing integrated poem page generation...")
    
    -- Load poem data
    local poems_data = template_engine.load_poems_data()
    if not poems_data then
        utils.log_error("Failed to load poems data")
        return false
    end
    
    -- Find test poems from different categories
    local test_poems = {}
    local categories_found = {}
    
    for _, poem in ipairs(poems_data.poems) do
        if poem.id and poem.content and poem.content:len() > 10 then
            local category = poem.category or "unknown"
            if not categories_found[category] then
                table.insert(test_poems, poem)
                categories_found[category] = true
            end
        end
        
        if #test_poems >= 3 then
            break
        end
    end
    
    if #test_poems == 0 then
        utils.log_error("No suitable test poems found")
        return false
    end
    
    local category_names = {}
    for category, _ in pairs(categories_found) do
        table.insert(category_names, category)
    end
    
    utils.log_info(string.format("Found %d test poems from categories: %s", 
                                #test_poems, 
                                table.concat(category_names, ", ")))
    
    -- Generate pages for each test poem
    local generated_files = {}
    
    for i, poem in ipairs(test_poems) do
        utils.log_info(string.format("Generating page %d/%d: Poem %s (%s)", 
                                    i, #test_poems, poem.id, poem.category or "unknown"))
        
        -- Determine category and URL
        local category = url_manager.get_poem_category(poem)
        local poem_url = url_manager.generate_poem_url(poem.id, category)
        local absolute_path = url_manager.generate_absolute_path(poem_url)
        
        -- Generate mock similarity data
        local mock_similar_poems = {
            {id = poem.id + 1, title = "Test Similar Poem A", url = url_manager.generate_poem_url(poem.id + 1, category), score = 0.89, is_golden = false},
            {id = poem.id + 2, title = "Test Similar Poem B", url = url_manager.generate_poem_url(poem.id + 2, category), score = 0.76, is_golden = true},
            {id = poem.id + 3, title = "Test Similar Poem C", url = url_manager.generate_poem_url(poem.id + 3, category), score = 0.68, is_golden = false}
        }
        
        -- Generate HTML
        local html = template_engine.generate_poem_html(poem, mock_similar_poems)
        if not html then
            utils.log_error("Failed to generate HTML for poem " .. poem.id)
            return false
        end
        
        -- Write file
        local success = utils.write_file(absolute_path, html)
        if not success then
            utils.log_error("Failed to write poem page: " .. absolute_path)
            return false
        end
        
        table.insert(generated_files, {
            poem_id = poem.id,
            category = category,
            url = poem_url,
            absolute_path = absolute_path,
            file_size = html:len()
        })
        
        utils.log_info(string.format("✅ Generated: %s (%d chars)", poem_url, html:len()))
    end
    
    -- Validate generated files
    utils.log_info("Validating generated files...")
    for _, file_info in ipairs(generated_files) do
        if not utils.file_exists(file_info.absolute_path) then
            utils.log_error("Generated file missing: " .. file_info.absolute_path)
            return false
        end
        
        local content = utils.read_file(file_info.absolute_path)
        if not content or content:len() == 0 then
            utils.log_error("Generated file is empty: " .. file_info.absolute_path)
            return false
        end
        
        -- Check for proper HTML structure
        if not content:match("<!DOCTYPE html>") or not content:match("<title>") then
            utils.log_error("Generated file missing HTML structure: " .. file_info.absolute_path)
            return false
        end
        
        utils.log_info(string.format("✅ Validated: %s", file_info.url))
    end
    
    utils.log_info(string.format("🎉 Integration test PASSED - Generated %d poem pages", #generated_files))
    
    -- Print summary
    utils.log_info("Generated files summary:")
    for _, file_info in ipairs(generated_files) do
        utils.log_info(string.format("  - Poem %s (%s): %s", 
                                    file_info.poem_id, 
                                    file_info.category, 
                                    file_info.url))
    end
    
    return true
end
-- }}}

-- {{{ function M.test_url_consistency
function M.test_url_consistency()
    utils.log_info("Testing URL consistency across systems...")
    
    local test_cases = {
        {poem_id = 42, category = "fediverse", expected = "poems/fediverse/poem-042.html"},
        {poem_id = 123, category = "messages", expected = "poems/messages/poem-123.html"},
        {poem_id = 7, category = "golden", expected = "poems/golden/poem-007.html"}
    }
    
    for i, test_case in ipairs(test_cases) do
        local generated_url = url_manager.generate_poem_url(test_case.poem_id, test_case.category)
        if generated_url ~= test_case.expected then
            utils.log_error(string.format("URL consistency test %d failed: expected %s, got %s", 
                                         i, test_case.expected, generated_url))
            return false
        end
        utils.log_info(string.format("✅ URL consistency test %d passed: %s", i, generated_url))
    end
    
    utils.log_info("🎉 URL consistency tests PASSED")
    return true
end
-- }}}

-- {{{ function M.test_golden_collection_integration
function M.test_golden_collection_integration()
    utils.log_info("Testing golden collection integration...")
    
    -- Load poem data
    local poems_data = template_engine.load_poems_data()
    if not poems_data then
        utils.log_error("Failed to load poems data")
        return false
    end
    
    -- Generate golden collection pages
    local collection_results = golden_collection.generate_all_golden_collection_pages(
        poems_data, {}, "/mnt/mtwo/programming/ai-stuff/neocities-modernization/generated-site")
    
    if not collection_results then
        utils.log_error("Failed to generate golden collection pages")
        return false
    end
    
    -- Validate collection results
    local validation_results = {
        index_generated = collection_results.index ~= nil,
        has_golden_poems = collection_results.golden_count > 0,
        browsing_pages_generated = (collection_results.similarity_browser ~= nil and 
                                  collection_results.chronological_browser ~= nil and
                                  collection_results.random_page ~= nil)
    }
    
    utils.log_info(string.format("Golden collection generated with %d golden poems", 
                                collection_results.golden_count or 0))
    
    local passed_validations = 0
    for test_name, passed in pairs(validation_results) do
        if passed then
            utils.log_info(string.format("✅ %s: passed", test_name))
            passed_validations = passed_validations + 1
        else
            utils.log_warn(string.format("❌ %s: failed", test_name))
        end
    end
    
    utils.log_info(string.format("Golden collection integration: %d/%d validations passed", 
                                passed_validations, 3))
    
    return passed_validations >= 2
end
-- }}}

-- {{{ function M.run_all_integration_tests
function M.run_all_integration_tests()
    utils.log_info("Running integration test suite...")
    
    -- Ensure directory structure exists
    local dir_success = url_manager.create_directory_structure()
    if not dir_success then
        utils.log_error("Failed to create directory structure")
        return false
    end
    
    -- Run tests
    local url_test_passed = M.test_url_consistency()
    local generation_test_passed = M.test_poem_page_generation()
    local golden_collection_passed = M.test_golden_collection_integration()
    
    local all_passed = url_test_passed and generation_test_passed and golden_collection_passed
    
    utils.log_info("\nIntegration Test Results:")
    utils.log_info(string.format("  URL consistency: %s", url_test_passed and "✅" or "❌"))
    utils.log_info(string.format("  Poem page generation: %s", generation_test_passed and "✅" or "❌"))
    utils.log_info(string.format("  Golden collection integration: %s", golden_collection_passed and "✅" or "❌"))
    
    if all_passed then
        utils.log_info("\n🎉 ALL INTEGRATION TESTS PASSED")
    else
        utils.log_error("\n❌ Some integration tests FAILED")
    end
    
    return all_passed
end
-- }}}

-- Run tests if called directly
if arg and arg[0] and arg[0]:match("test%-integration%.lua$") then
    local success = M.run_all_integration_tests()
    os.exit(success and 0 or 1)
end

return M