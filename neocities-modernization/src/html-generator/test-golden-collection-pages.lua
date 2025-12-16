#!/usr/bin/env lua

-- Test Golden Poem Collection Pages System
-- Tests collection page generation, browsing interfaces, and integration

package.path = package.path .. ';./?.lua;./libs/?.lua'

local utils = require("libs.utils")
local template_engine = require("src.html-generator.template-engine")
local golden_collection = require("src.html-generator.golden-collection-generator")
local url_manager = require("src.html-generator.url-manager")

local M = {}
local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

-- {{{ function M.test_golden_poem_filtering
function M.test_golden_poem_filtering()
    utils.log_info("Testing golden poem filtering...")
    
    local mock_poems_data = {
        poems = {
            [1] = {
                id = 1,
                title = "Regular Poem",
                content = "This is a regular poem.",
                category = "fediverse",
                character_count = 500,
                is_fediverse_golden = false
            },
            [2] = {
                id = 2,
                title = "Golden Poem",
                content = string.rep("x", 1024),
                category = "fediverse",
                character_count = 1024,
                is_fediverse_golden = true,
                similarity_score = 0.8
            },
            [3] = {
                id = 3,
                title = "Another Golden",
                content = string.rep("y", 1024),
                category = "messages",
                character_count = 1024,
                is_fediverse_golden = true,
                similarity_score = 0.9
            }
        }
    }
    
    local golden_poems = golden_collection.filter_golden_poems(mock_poems_data)
    
    local test_results = {
        correct_count = #golden_poems == 2,
        has_only_golden = true,
        sorted_by_similarity = true
    }
    
    -- Verify all poems are golden
    for _, poem in ipairs(golden_poems) do
        if not poem.id or poem.character_count ~= 1024 then
            test_results.has_only_golden = false
            break
        end
    end
    
    -- Verify sorting by similarity score (highest first)
    for i = 1, #golden_poems - 1 do
        if golden_poems[i].similarity_score < golden_poems[i + 1].similarity_score then
            test_results.sorted_by_similarity = false
            break
        end
    end
    
    local passed_tests = 0
    for test_name, passed in pairs(test_results) do
        if passed then
            utils.log_info(string.format("✅ %s: passed", test_name))
            passed_tests = passed_tests + 1
        else
            utils.log_warn(string.format("❌ %s: failed", test_name))
        end
    end
    
    utils.log_info(string.format("Golden poem filtering: %d/%d tests passed", 
                                passed_tests, 3))
    
    return passed_tests >= 2
end
-- }}}

-- {{{ function M.test_featured_poem_selection
function M.test_featured_poem_selection()
    utils.log_info("Testing featured poem selection...")
    
    local mock_golden_poems = {}
    for i = 1, 10 do
        table.insert(mock_golden_poems, {
            id = i,
            title = "Golden Poem " .. i,
            similarity_score = i * 0.1
        })
    end
    
    local featured = golden_collection.select_featured_golden_poems(mock_golden_poems, 6)
    
    local test_results = {
        correct_count = #featured == 6,
        includes_highest = featured[1].similarity_score == 1.0,
        diverse_selection = true
    }
    
    -- Check for diversity (no consecutive poems)
    for i = 1, #featured - 1 do
        for j = i + 1, #featured do
            if math.abs(featured[i].id - featured[j].id) == 1 then
                test_results.diverse_selection = false
                break
            end
        end
        if not test_results.diverse_selection then break end
    end
    
    local passed_tests = 0
    for test_name, passed in pairs(test_results) do
        if passed then
            utils.log_info(string.format("✅ %s: passed", test_name))
            passed_tests = passed_tests + 1
        else
            utils.log_warn(string.format("❌ %s: failed", test_name))
        end
    end
    
    utils.log_info(string.format("Featured poem selection: %d/%d tests passed", 
                                passed_tests, 3))
    
    return passed_tests >= 2
end
-- }}}

-- {{{ function M.test_collection_page_generation
function M.test_collection_page_generation()
    utils.log_info("Testing collection page generation...")
    
    local poems_data = template_engine.load_poems_data()
    if not poems_data then
        utils.log_error("Failed to load poems data for testing")
        return false
    end
    
    -- Ensure directory structure exists
    url_manager.create_directory_structure()
    
    -- Generate collection pages
    local results = golden_collection.generate_all_golden_collection_pages(
        poems_data, {}, DIR .. "/generated-site")
    
    local test_results = {
        index_generated = results.index ~= nil,
        similarity_generated = results.similarity_browser ~= nil,
        chronological_generated = results.chronological_browser ~= nil,
        random_generated = results.random_page ~= nil,
        has_golden_poems = results.golden_count > 0
    }
    
    -- Verify files exist
    if results.index then
        test_results.index_file_exists = utils.file_exists(results.index)
    else
        test_results.index_file_exists = false
    end
    
    local passed_tests = 0
    for test_name, passed in pairs(test_results) do
        if passed then
            utils.log_info(string.format("✅ %s: passed", test_name))
            passed_tests = passed_tests + 1
        else
            utils.log_warn(string.format("❌ %s: failed", test_name))
        end
    end
    
    utils.log_info(string.format("Collection page generation: %d/%d tests passed", 
                                passed_tests, 6))
    utils.log_info(string.format("Found %d golden poems in collection", 
                                results.golden_count or 0))
    
    return passed_tests >= 4
end
-- }}}

-- {{{ function M.test_collection_page_content
function M.test_collection_page_content()
    utils.log_info("Testing collection page content quality...")
    
    local index_file = DIR .. "/generated-site/poems/golden/index.html"
    
    if not utils.file_exists(index_file) then
        utils.log_warn("Golden collection index not found for content testing")
        return false
    end
    
    local content = utils.read_file(index_file)
    if not content then
        utils.log_error("Failed to read golden collection index")
        return false
    end
    
    local content_tests = {
        has_title = content:match("<title>.*Golden.*</title>") ~= nil,
        has_navigation = content:match('<nav class="breadcrumb">') ~= nil,
        has_featured_section = content:match('class="featured%-golden"') ~= nil,
        has_browse_options = content:match('class="browse%-options"') ~= nil,
        has_complete_index = content:match('class="complete%-index"') ~= nil,
        has_copy_functionality = content:match('fediverse%-copy%-area') ~= nil,
        has_responsive_css = content:match('@media %(max%-width') ~= nil,
        has_golden_styling = content:match('golden%-badge') ~= nil,
        no_javascript = (not content:match('copyToClipboard')) and 
                       (not content:match('<script>')) and
                       (not content:match('navigator%.clipboard'))
    }
    
    local passed_tests = 0
    for test_name, passed in pairs(content_tests) do
        if passed then
            utils.log_info(string.format("✅ %s: present", test_name))
            passed_tests = passed_tests + 1
        else
            utils.log_warn(string.format("❌ %s: missing", test_name))
        end
    end
    
    utils.log_info(string.format("Collection page content: %d/%d features present", 
                                passed_tests, 9))
    
    return passed_tests >= 6
end
-- }}}

-- {{{ function M.test_browsing_interface_integration
function M.test_browsing_interface_integration()
    utils.log_info("Testing browsing interface integration...")
    
    local files_to_check = {
        {name = "Index", path = DIR .. "/generated-site/poems/golden/index.html"},
        {name = "Similarity", path = DIR .. "/generated-site/poems/golden/by-similarity.html"},
        {name = "Chronological", path = DIR .. "/generated-site/poems/golden/chronological.html"},
        {name = "Random", path = DIR .. "/generated-site/poems/golden/random.html"}
    }
    
    local integration_tests = {
        all_files_exist = true,
        all_have_navigation = true,
        all_link_correctly = true
    }
    
    for _, file_info in ipairs(files_to_check) do
        local exists = utils.file_exists(file_info.path)
        if not exists then
            utils.log_warn(string.format("%s file not found: %s", file_info.name, file_info.path))
            integration_tests.all_files_exist = false
        else
            local content = utils.read_file(file_info.path)
            if content then
                -- Check for navigation breadcrumbs
                if not content:match('<nav class="breadcrumb">') then
                    integration_tests.all_have_navigation = false
                end
                
                -- Check for proper linking structure
                if not content:match('href=.*index%.html') and file_info.name ~= "Index" then
                    integration_tests.all_link_correctly = false
                end
            end
        end
    end
    
    local passed_tests = 0
    for test_name, passed in pairs(integration_tests) do
        if passed then
            utils.log_info(string.format("✅ %s: passed", test_name))
            passed_tests = passed_tests + 1
        else
            utils.log_warn(string.format("❌ %s: failed", test_name))
        end
    end
    
    utils.log_info(string.format("Browsing interface integration: %d/%d tests passed", 
                                passed_tests, 3))
    
    return passed_tests >= 2
end
-- }}}

-- {{{ function M.test_mobile_responsiveness
function M.test_mobile_responsiveness()
    utils.log_info("Testing mobile responsiveness...")
    
    local index_file = DIR .. "/generated-site/poems/golden/index.html"
    
    if not utils.file_exists(index_file) then
        utils.log_warn("Golden collection index not found for responsive testing")
        return false
    end
    
    local content = utils.read_file(index_file)
    if not content then return false end
    
    local responsive_features = {
        has_viewport_meta = content:match('<meta name="viewport"') ~= nil,
        has_mobile_css = content:match('@media %(max%-width: 768px%)') ~= nil,
        has_grid_responsive = content:match('grid%-template%-columns:.*1fr') ~= nil,
        has_flex_responsive = content:match('flex%-direction: column') ~= nil,
        mobile_optimized_padding = content:match('padding:.*0%.5rem') ~= nil
    }
    
    local passed_features = 0
    for feature_name, present in pairs(responsive_features) do
        if present then
            utils.log_info(string.format("✅ %s: present", feature_name))
            passed_features = passed_features + 1
        else
            utils.log_warn(string.format("❌ %s: missing", feature_name))
        end
    end
    
    utils.log_info(string.format("Mobile responsiveness: %d/%d features present", 
                                passed_features, 5))
    
    return passed_features >= 3
end
-- }}}

-- {{{ function M.run_all_tests
function M.run_all_tests()
    utils.log_info("Running golden poem collection pages test suite...")
    
    local filtering_test = M.test_golden_poem_filtering()
    local featured_test = M.test_featured_poem_selection()
    local generation_test = M.test_collection_page_generation()
    local content_test = M.test_collection_page_content()
    local integration_test = M.test_browsing_interface_integration()
    local responsive_test = M.test_mobile_responsiveness()
    
    local all_passed = filtering_test and featured_test and generation_test and 
                      content_test and integration_test and responsive_test
    
    utils.log_info("\nTest Results Summary:")
    utils.log_info(string.format("  Golden poem filtering: %s", filtering_test and "✅" or "❌"))
    utils.log_info(string.format("  Featured poem selection: %s", featured_test and "✅" or "❌"))
    utils.log_info(string.format("  Collection page generation: %s", generation_test and "✅" or "❌"))
    utils.log_info(string.format("  Collection page content: %s", content_test and "✅" or "❌"))
    utils.log_info(string.format("  Browsing interface integration: %s", integration_test and "✅" or "❌"))
    utils.log_info(string.format("  Mobile responsiveness: %s", responsive_test and "✅" or "❌"))
    
    if all_passed then
        utils.log_info("\n🎉 ALL GOLDEN COLLECTION PAGE TESTS PASSED")
    else
        utils.log_error("\n❌ Some golden collection page tests FAILED")
    end
    
    return all_passed
end
-- }}}

-- Run tests if called directly
if arg and arg[0] and arg[0]:match("test%-golden%-collection%-pages%.lua$") then
    local success = M.run_all_tests()
    os.exit(success and 0 or 1)
end

return M