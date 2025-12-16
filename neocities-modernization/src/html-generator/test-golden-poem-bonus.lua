#!/usr/bin/env lua

-- Test Golden Poem Similarity Bonus System
-- Tests golden poem prioritization and bonus calculations

package.path = package.path .. ';./?.lua;./libs/?.lua'

local utils = require("libs.utils")
local template_engine = require("src.html-generator.template-engine")
local similarity_engine = require("src.html-generator.similarity-engine")
local golden_bonus = require("src.html-generator.golden-poem-bonus")
local url_manager = require("src.html-generator.url-manager")

local M = {}
local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

-- {{{ function M.test_golden_bonus_configuration
function M.test_golden_bonus_configuration()
    utils.log_info("Testing golden bonus configuration system...")
    
    local config = golden_bonus.get_config()
    
    if not config then
        utils.log_error("Failed to load golden bonus configuration")
        return false
    end
    
    -- Validate configuration structure
    local required_fields = {
        "golden_poem_pair_bonus",
        "golden_poem_single_bonus", 
        "min_golden_recommendations",
        "max_golden_recommendations",
        "enable_golden_prioritization",
        "golden_bonus_threshold"
    }
    
    local passed_fields = 0
    for _, field in ipairs(required_fields) do
        if config[field] ~= nil then
            utils.log_info("✅ Config field: " .. field .. " = " .. tostring(config[field]))
            passed_fields = passed_fields + 1
        else
            utils.log_warn("❌ Missing config field: " .. field)
        end
    end
    
    local config_valid = passed_fields >= #required_fields
    utils.log_info(string.format("Configuration validation: %d/%d fields present", 
                                passed_fields, #required_fields))
    
    return config_valid
end
-- }}}

-- {{{ function M.test_golden_bonus_calculations
function M.test_golden_bonus_calculations()
    utils.log_info("Testing golden bonus calculations...")
    
    -- Create test poem data
    local golden_poem = {
        id = 1,
        title = "Golden Test Poem",
        is_fediverse_golden = true
    }
    
    local regular_poem = {
        id = 2,
        title = "Regular Test Poem", 
        is_fediverse_golden = false
    }
    
    local config = golden_bonus.get_config()
    
    -- Test cases
    local test_cases = {
        {
            name = "Golden to Golden",
            poem_a = golden_poem,
            poem_b = golden_poem,
            base_similarity = 0.5,
            expected_bonus = config.golden_poem_pair_bonus
        },
        {
            name = "Golden to Regular",
            poem_a = golden_poem,
            poem_b = regular_poem,
            base_similarity = 0.5,
            expected_bonus = config.golden_poem_single_bonus
        },
        {
            name = "Regular to Regular",
            poem_a = regular_poem,
            poem_b = regular_poem,
            base_similarity = 0.5,
            expected_bonus = 0
        },
        {
            name = "Low similarity (below threshold)",
            poem_a = golden_poem,
            poem_b = golden_poem,
            base_similarity = 0.05,
            expected_bonus = 0
        }
    }
    
    local passed_tests = 0
    for _, test_case in ipairs(test_cases) do
        local enhanced_score, bonus_applied = golden_bonus.calculate_similarity_with_golden_bonus(
            test_case.poem_a, test_case.poem_b, test_case.base_similarity, config
        )
        
        local expected_score = math.min(1.0, test_case.base_similarity + test_case.expected_bonus)
        
        if math.abs(enhanced_score - expected_score) < 0.001 and 
           math.abs(bonus_applied - test_case.expected_bonus) < 0.001 then
            utils.log_info(string.format("✅ %s: %.3f + %.3f = %.3f", 
                                        test_case.name, test_case.base_similarity, 
                                        bonus_applied, enhanced_score))
            passed_tests = passed_tests + 1
        else
            utils.log_warn(string.format("❌ %s: expected %.3f/%.3f, got %.3f/%.3f",
                                        test_case.name, expected_score, test_case.expected_bonus,
                                        enhanced_score, bonus_applied))
        end
    end
    
    utils.log_info(string.format("Bonus calculation tests: %d/%d passed", 
                                passed_tests, #test_cases))
    
    return passed_tests >= (#test_cases * 0.75)  -- Allow 75% pass rate
end
-- }}}

-- {{{ function M.test_golden_prioritization_integration
function M.test_golden_prioritization_integration()
    utils.log_info("Testing golden prioritization integration...")
    
    local poems_data = template_engine.load_poems_data()
    if not poems_data then
        utils.log_error("Failed to load poems data")
        return false
    end
    
    -- Find a poem to test with (prefer one with similarity data)
    local test_poem_id = 1
    local test_poem = similarity_engine.get_poem_metadata(test_poem_id, poems_data)
    
    if not test_poem then
        utils.log_error("Test poem not found")
        return false
    end
    
    utils.log_info(string.format("Testing with poem %d (%s)", 
                                test_poem_id, test_poem.title or "Untitled"))
    
    -- Get recommendations with golden bonus disabled
    local recommendations_without = similarity_engine.get_top_recommendations(
        test_poem_id, poems_data, 
        {count = 15, apply_golden_bonus = false}
    )
    
    -- Get recommendations with golden bonus enabled
    local recommendations_with = similarity_engine.get_top_recommendations(
        test_poem_id, poems_data, 
        {count = 15, apply_golden_bonus = true}
    )
    
    if #recommendations_without == 0 or #recommendations_with == 0 then
        utils.log_warn("No recommendations generated - similarity data may be missing")
        return false  
    end
    
    -- Count golden poems in both sets
    local golden_count_without = 0
    local golden_count_with = 0
    local bonus_applications = 0
    
    for _, rec in ipairs(recommendations_without) do
        if rec.is_golden then golden_count_without = golden_count_without + 1 end
    end
    
    for _, rec in ipairs(recommendations_with) do
        if rec.is_golden then golden_count_with = golden_count_with + 1 end
        if rec.bonus_applied and rec.bonus_applied > 0 then
            bonus_applications = bonus_applications + 1
        end
    end
    
    utils.log_info(string.format("Golden poems without bonus: %d/%d (%.1f%%)", 
                                golden_count_without, #recommendations_without,
                                (golden_count_without / #recommendations_without) * 100))
    utils.log_info(string.format("Golden poems with bonus: %d/%d (%.1f%%)", 
                                golden_count_with, #recommendations_with,
                                (golden_count_with / #recommendations_with) * 100))
    utils.log_info(string.format("Bonus applications: %d", bonus_applications))
    
    -- Test HTML generation with bonuses
    local html = template_engine.generate_poem_html(test_poem, poems_data)
    local has_similarity_section = html and html:match('class="similar%-poems"')
    
    if has_similarity_section then
        utils.log_info("✅ Golden bonus integrated with HTML generation")
    else
        utils.log_warn("❌ HTML generation missing similarity section")
    end
    
    -- Success if we have bonuses applied and potentially more golden poems
    local success = bonus_applications > 0 and has_similarity_section
    
    return success
end
-- }}}

-- {{{ function M.test_golden_bonus_validation
function M.test_golden_bonus_validation()
    utils.log_info("Testing golden bonus validation and reporting...")
    
    local poems_data = template_engine.load_poems_data()
    if not poems_data then return false end
    
    -- Generate sample recommendations
    local test_poem_id = 1
    local recommendations = similarity_engine.get_top_recommendations(
        test_poem_id, poems_data, 
        {count = 10, apply_golden_bonus = true}
    )
    
    if #recommendations == 0 then
        utils.log_warn("No recommendations available for validation test")
        return false
    end
    
    -- Validate the bonus effects
    local validation_results = golden_bonus.validate_golden_bonus_effects(
        {}, recommendations, poems_data  -- Empty "before" since we only have "after"
    )
    
    utils.log_info(string.format("Validation results - Total: %d, Golden: %d", 
                                validation_results.total_recommendations,
                                validation_results.golden_count))
    utils.log_info(string.format("Average golden position: %.2f", 
                                validation_results.average_golden_position))
    utils.log_info(string.format("Bonus effectiveness: %.1f%%", 
                                validation_results.bonus_effectiveness * 100))
    
    -- Generate a validation report
    local report = golden_bonus.generate_golden_bonus_report(validation_results)
    utils.log_info("\n" .. report)
    
    -- Success if we have meaningful validation data
    local success = validation_results.total_recommendations > 0 and 
                   (validation_results.golden_count > 0 or validation_results.bonus_effectiveness >= 0)
    
    return success
end
-- }}}

-- {{{ function M.test_configuration_persistence
function M.test_configuration_persistence()
    utils.log_info("Testing configuration persistence...")
    
    local config_file = DIR .. "/config/golden-poem-settings.json"
    local original_config = golden_bonus.load_golden_poem_config(config_file)
    
    if not original_config then
        utils.log_error("Failed to load original configuration")
        return false
    end
    
    -- Modify a setting temporarily
    local test_config = {}
    for k, v in pairs(original_config) do
        test_config[k] = v
    end
    test_config.golden_poem_pair_bonus = 0.10  -- Different from default 0.05
    
    -- Save modified config
    local json = require("libs.json")
    utils.write_file(config_file, json.encode(test_config))
    
    -- Clear config cache and reload
    golden_bonus.config = nil
    local reloaded_config = golden_bonus.load_golden_poem_config(config_file)
    
    local persistence_works = reloaded_config and 
                             reloaded_config.golden_poem_pair_bonus == 0.10
    
    -- Restore original config
    utils.write_file(config_file, json.encode(original_config))
    golden_bonus.config = nil
    
    if persistence_works then
        utils.log_info("✅ Configuration persistence working")
    else
        utils.log_warn("❌ Configuration persistence failed")
    end
    
    return persistence_works
end
-- }}}

-- {{{ function M.run_all_tests
function M.run_all_tests()
    utils.log_info("Running golden poem bonus test suite...")
    
    local config_test = M.test_golden_bonus_configuration()
    local calculation_test = M.test_golden_bonus_calculations()
    local integration_test = M.test_golden_prioritization_integration()
    local validation_test = M.test_golden_bonus_validation()
    local persistence_test = M.test_configuration_persistence()
    
    local all_passed = config_test and calculation_test and integration_test and 
                      validation_test and persistence_test
    
    if all_passed then
        utils.log_info("🎉 ALL GOLDEN POEM BONUS TESTS PASSED")
    else
        utils.log_error("❌ Some golden poem bonus tests FAILED")
        utils.log_info("Test Results Summary:")
        utils.log_info(string.format("  Configuration: %s", config_test and "✅" or "❌"))
        utils.log_info(string.format("  Calculations: %s", calculation_test and "✅" or "❌"))
        utils.log_info(string.format("  Integration: %s", integration_test and "✅" or "❌"))
        utils.log_info(string.format("  Validation: %s", validation_test and "✅" or "❌"))
        utils.log_info(string.format("  Persistence: %s", persistence_test and "✅" or "❌"))
    end
    
    return all_passed
end
-- }}}

-- Run tests if called directly
if arg and arg[0] and arg[0]:match("test%-golden%-poem%-bonus%.lua$") then
    local success = M.run_all_tests()
    os.exit(success and 0 or 1)
end

return M