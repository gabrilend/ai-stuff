#!/usr/bin/env lua

-- Test Golden Poem Visual Indicators System
-- Tests visual styling, accessibility, and integration across different devices

package.path = package.path .. ';./?.lua;./libs/?.lua'

local utils = require("libs.utils")
local template_engine = require("src.html-generator.template-engine")
local similarity_engine = require("src.html-generator.similarity-engine")
local golden_indicators = require("src.html-generator.golden-poem-indicators")
local url_manager = require("src.html-generator.url-manager")

local M = {}
local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

-- {{{ function M.test_golden_indicator_generation
function M.test_golden_indicator_generation()
    utils.log_info("Testing golden indicator generation...")
    
    local golden_poem = {
        id = 1,
        title = "Test Golden Poem",
        is_fediverse_golden = true,
        character_count = 1024,
        content = "Test content..."
    }
    
    local regular_poem = {
        id = 2,
        title = "Test Regular Poem",
        is_fediverse_golden = false,
        character_count = 500,
        content = "Test content..."
    }
    
    local test_cases = {
        {name = "Full golden badge", poem = golden_poem, display_type = "full"},
        {name = "Compact golden indicator", poem = golden_poem, display_type = "compact"},
        {name = "List golden indicator", poem = golden_poem, display_type = "list"},
        {name = "Icon only", poem = golden_poem, display_type = "icon"},
        {name = "Regular poem (no indicator)", poem = regular_poem, display_type = "full"}
    }
    
    local passed_tests = 0
    
    for _, test in ipairs(test_cases) do
        local indicator = golden_indicators.generate_golden_indicator(test.poem, test.display_type)
        
        local should_have_content = test.poem.is_fediverse_golden and test.display_type ~= "invalid"
        local has_content = indicator and indicator ~= ""
        
        if should_have_content == has_content then
            utils.log_info(string.format("✅ %s: %s", 
                                        test.name, 
                                        has_content and "generated correctly" or "correctly empty"))
            passed_tests = passed_tests + 1
            
            -- Check for accessibility features in full badge
            if test.display_type == "full" and has_content then
                local has_aria = indicator:match('aria%-label=') ~= nil
                local has_screen_reader = indicator:match('class="sr%-only"') ~= nil
                local has_role = indicator:match('role="') ~= nil
                
                if has_aria and has_screen_reader and has_role then
                    utils.log_info("  ✅ Accessibility features present")
                else
                    utils.log_warn("  ⚠️ Some accessibility features missing")
                end
            end
        else
            utils.log_warn(string.format("❌ %s: unexpected result", test.name))
        end
    end
    
    utils.log_info(string.format("Golden indicator generation: %d/%d tests passed", 
                                passed_tests, #test_cases))
    
    return passed_tests >= (#test_cases * 0.8)
end
-- }}}

-- {{{ function M.test_character_count_display
function M.test_character_count_display()
    utils.log_info("Testing character count display...")
    
    local test_poems = {
        {
            name = "Golden poem with exact count",
            poem = {character_count = 1024, is_fediverse_golden = true},
            expected_class = "character-count golden"
        },
        {
            name = "Regular poem",
            poem = {character_count = 500, is_fediverse_golden = false},
            expected_class = "character-count"
        },
        {
            name = "Poem with no count",
            poem = {is_fediverse_golden = false},
            expected_empty = true
        }
    }
    
    local passed_tests = 0
    
    for _, test in ipairs(test_poems) do
        local display = golden_indicators.generate_character_count_display(test.poem)
        
        if test.expected_empty then
            if display == "" then
                utils.log_info(string.format("✅ %s: correctly empty", test.name))
                passed_tests = passed_tests + 1
            else
                utils.log_warn(string.format("❌ %s: should be empty", test.name))
            end
        else
            local has_correct_class = display:match(test.expected_class:gsub("%-", "%%-")) ~= nil
            local has_count = display:match(tostring(test.poem.character_count)) ~= nil
            
            if has_correct_class and has_count then
                utils.log_info(string.format("✅ %s: correct styling and count", test.name))
                passed_tests = passed_tests + 1
            else
                utils.log_warn(string.format("❌ %s: incorrect styling or count", test.name))
            end
        end
    end
    
    utils.log_info(string.format("Character count display: %d/%d tests passed", 
                                passed_tests, #test_poems))
    
    return passed_tests >= (#test_poems * 0.8)
end
-- }}}

-- {{{ function M.test_similarity_list_enhancement
function M.test_similarity_list_enhancement()
    utils.log_info("Testing similarity list enhancement...")
    
    local mock_recommendations = {
        {id = 1, title = "Regular Poem 1", url = "poems/test/1.html", score = 0.9, is_golden = false},
        {id = 2, title = "Golden Poem 1", url = "poems/test/2.html", score = 0.85, is_golden = true},
        {id = 3, title = "Regular Poem 2", url = "poems/test/3.html", score = 0.8, is_golden = false},
        {id = 4, title = "Golden Poem 2", url = "poems/test/4.html", score = 0.75, is_golden = true}
    }
    
    local enhanced_html = golden_indicators.enhance_similarity_list_with_golden(mock_recommendations)
    
    -- Validate the enhanced HTML
    local validation = {
        has_golden_classes = enhanced_html:match('class="golden%-poem"') ~= nil,
        has_golden_icons = enhanced_html:match('✨') ~= nil,
        has_aria_labels = enhanced_html:match('aria%-label=') ~= nil,
        has_similarity_scores = enhanced_html:match('similarity%)') ~= nil,
        has_all_poems = true
    }
    
    -- Check that all poems are represented
    for _, rec in ipairs(mock_recommendations) do
        if not enhanced_html:match(rec.title) then
            validation.has_all_poems = false
            break
        end
    end
    
    local passed_checks = 0
    for check_name, passed in pairs(validation) do
        if passed then
            utils.log_info(string.format("✅ %s: passed", check_name))
            passed_checks = passed_checks + 1
        else
            utils.log_warn(string.format("❌ %s: failed", check_name))
        end
    end
    
    utils.log_info(string.format("Similarity list enhancement: %d/%d checks passed", 
                                passed_checks, 5))
    
    return passed_checks >= 4
end
-- }}}

-- {{{ function M.test_full_page_integration
function M.test_full_page_integration()
    utils.log_info("Testing full page integration with golden indicators...")
    
    local poems_data = template_engine.load_poems_data()
    if not poems_data then
        utils.log_error("Failed to load poems data")
        return false
    end
    
    -- Create a test golden poem
    local test_poem = {
        id = 999,
        title = "Test Golden Integration Poem",
        content = "This is a test poem for golden indicator integration. " .. string.rep("x", 900),
        category = "fediverse",
        is_fediverse_golden = true,
        character_count = 1024
    }
    
    -- Ensure directory structure exists
    url_manager.create_directory_structure()
    
    -- Generate HTML with golden indicators
    local html = template_engine.generate_poem_html(test_poem, poems_data)
    
    if not html then
        utils.log_error("Failed to generate HTML with golden indicators")
        return false
    end
    
    -- Validate the complete HTML
    local validation = golden_indicators.validate_golden_poem_indicators(html)
    
    utils.log_info("HTML validation results:")
    for _, check in ipairs(validation.checks) do
        local status = check.passed and "✅" or "❌"
        utils.log_info(string.format("  %s %s", status, check.name))
    end
    
    if #validation.warnings > 0 then
        utils.log_info("Warnings:")
        for _, warning in ipairs(validation.warnings) do
            utils.log_warn("  ⚠️ " .. warning)
        end
    end
    
    utils.log_info(string.format("Overall validation score: %.1f%% (%s)", 
                                validation.score * 100,
                                validation.valid and "PASSED" or "FAILED"))
    
    -- Write test file
    local output_file = DIR .. "/generated-site/poems/fediverse/poem-999-golden-test.html"
    local success = utils.write_file(output_file, html)
    
    if success then
        utils.log_info("✅ Generated golden indicator test file: " .. output_file)
        utils.log_info(string.format("File size: %d characters", html:len()))
    end
    
    return validation.valid and success
end
-- }}}

-- {{{ function M.test_responsive_design_compatibility
function M.test_responsive_design_compatibility()
    utils.log_info("Testing responsive design compatibility...")
    
    local poems_data = template_engine.load_poems_data()
    if not poems_data then return false end
    
    -- Create test golden poem
    local test_poem = {
        id = 998,
        title = "Mobile Golden Test",
        content = "Mobile responsive test content.",
        is_fediverse_golden = true,
        character_count = 1024,
        category = "fediverse"
    }
    
    local html = template_engine.generate_poem_html(test_poem, poems_data)
    if not html then return false end
    
    -- Check for responsive CSS features
    local responsive_features = {
        mobile_optimizations = html:match("@media %(max%-width: 479px%)") ~= nil,
        tablet_styles = html:match("@media %(min%-width: 768px%)") ~= nil,
        desktop_styles = html:match("@media %(min%-width: 1024px%)") ~= nil,
        high_contrast = html:match("@media %(prefers%-contrast: high%)") ~= nil,
        reduced_motion = html:match("@media %(prefers%-reduced%-motion: reduce%)") ~= nil,
        golden_mobile_optimizations = html:match("golden%-badge.*padding: 0%.5rem") ~= nil
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
    
    utils.log_info(string.format("Responsive design features: %d/%d present", 
                                passed_features, 6))
    
    return passed_features >= 4  -- Require at least 4/6 features
end
-- }}}

-- {{{ function M.test_accessibility_compliance
function M.test_accessibility_compliance()
    utils.log_info("Testing accessibility compliance...")
    
    local poems_data = template_engine.load_poems_data()
    if not poems_data then return false end
    
    local test_poem = {
        id = 997,
        title = "Accessibility Test Poem",
        content = "Test content for accessibility validation.",
        is_fediverse_golden = true,
        character_count = 1024,
        category = "fediverse"
    }
    
    local html = template_engine.generate_poem_html(test_poem, poems_data)
    if not html then return false end
    
    -- Check accessibility features
    local a11y_features = {
        lang_attribute = html:match('<html lang="en">') ~= nil,
        aria_labels = html:match('aria%-label=') ~= nil,
        role_attributes = html:match('role="') ~= nil,
        screen_reader_content = html:match('class="sr%-only"') ~= nil,
        focus_indicators = html:match(':focus') ~= nil,
        semantic_html = html:match('<main') ~= nil and html:match('<nav') ~= nil,
        alt_text_equivalent = html:match('aria%-hidden="true"') ~= nil
    }
    
    local passed_a11y = 0
    for feature_name, present in pairs(a11y_features) do
        if present then
            utils.log_info(string.format("✅ %s: compliant", feature_name))
            passed_a11y = passed_a11y + 1
        else
            utils.log_warn(string.format("❌ %s: missing", feature_name))
        end
    end
    
    utils.log_info(string.format("Accessibility compliance: %d/%d features present", 
                                passed_a11y, 7))
    
    return passed_a11y >= 5  -- Require 5/7 accessibility features
end
-- }}}

-- {{{ function M.run_all_tests
function M.run_all_tests()
    utils.log_info("Running golden poem visual indicators test suite...")
    
    local indicator_test = M.test_golden_indicator_generation()
    local character_test = M.test_character_count_display()
    local list_test = M.test_similarity_list_enhancement()
    local integration_test = M.test_full_page_integration()
    local responsive_test = M.test_responsive_design_compatibility()
    local accessibility_test = M.test_accessibility_compliance()
    
    local all_passed = indicator_test and character_test and list_test and 
                      integration_test and responsive_test and accessibility_test
    
    utils.log_info("\nTest Results Summary:")
    utils.log_info(string.format("  Golden indicator generation: %s", indicator_test and "✅" or "❌"))
    utils.log_info(string.format("  Character count display: %s", character_test and "✅" or "❌"))
    utils.log_info(string.format("  Similarity list enhancement: %s", list_test and "✅" or "❌"))
    utils.log_info(string.format("  Full page integration: %s", integration_test and "✅" or "❌"))
    utils.log_info(string.format("  Responsive design: %s", responsive_test and "✅" or "❌"))
    utils.log_info(string.format("  Accessibility compliance: %s", accessibility_test and "✅" or "❌"))
    
    if all_passed then
        utils.log_info("\n🎉 ALL GOLDEN POEM VISUAL INDICATOR TESTS PASSED")
    else
        utils.log_error("\n❌ Some golden poem visual indicator tests FAILED")
    end
    
    return all_passed
end
-- }}}

-- Run tests if called directly
if arg and arg[0] and arg[0]:match("test%-golden%-visual%-indicators%.lua$") then
    local success = M.run_all_tests()
    os.exit(success and 0 or 1)
end

return M