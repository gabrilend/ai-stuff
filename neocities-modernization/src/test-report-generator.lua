#!/usr/bin/env lua

-- Test script for report generator
-- Tests all report formats and comparative analysis functionality

local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

package.path = package.path .. ';' .. DIR .. '/?.lua;' .. DIR .. '/libs/?.lua'

local report_module = require("src.report-generator")
local ReportGenerator = report_module.ReportGenerator
local utils = require("libs.utils")

-- {{{ function create_mock_validation_result
function create_mock_validation_result(algorithm, accuracy_rate, comparisons_per_second)
    return {
        algorithm = algorithm or "cosine",
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        duration_seconds = 15,
        statistics = {
            total_comparisons = 1000,
            accurate_scores = math.floor((accuracy_rate or 0.95) * 1000),
            inaccurate_scores = math.floor((1 - (accuracy_rate or 0.95)) * 1000),
            missing_embeddings = 2,
            accuracy_rate = accuracy_rate or 0.95,
            error_rate = 1 - (accuracy_rate or 0.95),
            tolerance = 0.001
        },
        performance = {
            comparisons_per_second = comparisons_per_second or 67.5,
            avg_comparison_time_ms = 1000 / (comparisons_per_second or 67.5)
        },
        discrepancies = {
            count = math.floor((1 - (accuracy_rate or 0.95)) * 1000),
            samples = {
                {
                    poem_a = 123,
                    poem_b = 456,
                    stored_score = 0.85,
                    calculated_score = 0.82,
                    difference = 0.03,
                    relative_error = 0.035
                },
                {
                    poem_a = 789,
                    poem_b = 101,
                    stored_score = 0.42,
                    calculated_score = 0.45,
                    difference = 0.03,
                    relative_error = 0.071
                }
            },
            max_difference = 0.05,
            avg_difference = 0.025
        },
        errors = {
            count = 2,
            by_type = {
                missing_embedding = 2
            },
            samples = {
                {
                    type = "missing_embedding",
                    poem_a = 999,
                    poem_b = 888,
                    missing = "poem_a"
                }
            }
        },
        recommendations = {
            "Excellent accuracy rate. Stored similarity data appears reliable.",
            "2 missing embeddings found. Update embedding data or clean similarity matrix."
        }
    }
end
-- }}}

-- {{{ function test_html_report_generation
function test_html_report_generation()
    print("🌐 Testing HTML Report Generation")
    print("================================")
    
    local generator = ReportGenerator:new({format = "html"})
    local mock_result = create_mock_validation_result("cosine", 0.95, 67.5)
    
    local output_file = DIR .. "/test_html_report.html"
    
    local success, result = pcall(function()
        return generator:generate_validation_report(mock_result, output_file)
    end)
    
    if success and utils.file_exists(output_file) then
        -- Check that HTML file contains expected content
        local content = utils.read_file(output_file)
        
        local checks = {
            content:match("<!DOCTYPE html>") and "HTML doctype",
            content:match("Similarity Validation Report") and "Title",
            content:match("cosine") and "Algorithm name",
            content:match("95%.0%%") and "Accuracy percentage",
            content:match("1000") and "Total comparisons",
            content:match("67%.5") and "Performance metrics"
        }
        
        local passed_checks = 0
        for _, check in ipairs(checks) do
            if check then
                passed_checks = passed_checks + 1
            end
        end
        
        -- Clean up
        os.remove(output_file)
        
        if passed_checks == #checks then
            print("✅ HTML report generation: PASSED")
            print(string.format("   - All %d content checks passed", #checks))
            return true
        else
            print(string.format("❌ HTML report generation: FAILED - %d/%d content checks passed", passed_checks, #checks))
            return false
        end
    else
        print(string.format("❌ HTML report generation: FAILED - %s", result or "file not created"))
        return false
    end
end
-- }}}

-- {{{ function test_markdown_report_generation
function test_markdown_report_generation()
    print("\n📝 Testing Markdown Report Generation")
    print("====================================")
    
    local generator = ReportGenerator:new({format = "markdown"})
    local mock_result = create_mock_validation_result("euclidean", 0.88, 45.2)
    
    local output_file = DIR .. "/test_markdown_report.md"
    
    local success, result = pcall(function()
        return generator:generate_validation_report(mock_result, output_file)
    end)
    
    if success and utils.file_exists(output_file) then
        local content = utils.read_file(output_file)
        
        local checks = {
            content:match("# 🔍 Similarity Validation Report") and "Markdown header",
            content:match("%*%*Algorithm:%*%* euclidean") and "Algorithm info",
            content:match("88%.0%%") and "Accuracy percentage",
            content:match("## 📊 Validation Overview") and "Overview section",
            content:match("## ⚡ Performance Metrics") and "Performance section",
            content:match("```") and "Code blocks for performance data"
        }
        
        local passed_checks = 0
        for _, check in ipairs(checks) do
            if check then
                passed_checks = passed_checks + 1
            end
        end
        
        -- Clean up
        os.remove(output_file)
        
        if passed_checks == #checks then
            print("✅ Markdown report generation: PASSED")
            print(string.format("   - All %d content checks passed", #checks))
            return true
        else
            print(string.format("❌ Markdown report generation: FAILED - %d/%d content checks passed", passed_checks, #checks))
            return false
        end
    else
        print(string.format("❌ Markdown report generation: FAILED - %s", result or "file not created"))
        return false
    end
end
-- }}}

-- {{{ function test_json_report_generation
function test_json_report_generation()
    print("\n🔧 Testing JSON Report Generation")
    print("=================================")
    
    local generator = ReportGenerator:new({format = "json"})
    local mock_result = create_mock_validation_result("angular", 0.92, 55.8)
    
    local output_file = DIR .. "/test_json_report.json"
    
    local success, result = pcall(function()
        return generator:generate_validation_report(mock_result, output_file)
    end)
    
    if success and utils.file_exists(output_file) then
        -- Try to parse the JSON to verify it's valid
        local json_data = utils.read_json_file(output_file)
        
        if json_data and json_data.algorithm == "angular" and 
           json_data.statistics and json_data.statistics.accuracy_rate == 0.92 then
            print("✅ JSON report generation: PASSED")
            print("   - Valid JSON structure")
            print("   - Contains expected data")
            
            -- Clean up
            os.remove(output_file)
            return true
        else
            print("❌ JSON report generation: FAILED - invalid JSON structure or data")
            os.remove(output_file)
            return false
        end
    else
        print(string.format("❌ JSON report generation: FAILED - %s", result or "file not created"))
        return false
    end
end
-- }}}

-- {{{ function test_comparative_report_generation
function test_comparative_report_generation()
    print("\n📊 Testing Comparative Report Generation")
    print("========================================")
    
    -- Create multiple mock validation results
    local validation_results = {
        create_mock_validation_result("cosine", 0.95, 67.5),
        create_mock_validation_result("euclidean", 0.88, 45.2),
        create_mock_validation_result("angular", 0.92, 55.8),
        create_mock_validation_result("manhattan", 0.85, 72.1)
    }
    
    local generator = ReportGenerator:new({format = "markdown"})
    local output_file = DIR .. "/test_comparative_report.md"
    
    local success, result = pcall(function()
        return generator:generate_comparative_report(validation_results, output_file)
    end)
    
    if success and utils.file_exists(output_file) then
        local content = utils.read_file(output_file)
        
        local checks = {
            content:match("# 📊 Comparative Algorithm Validation Report") and "Comparative header",
            content:match("cosine") and "Contains cosine algorithm",
            content:match("euclidean") and "Contains euclidean algorithm", 
            content:match("95%.0%%") and "Contains cosine accuracy",
            content:match("## 🏆 Algorithm Rankings") and "Rankings section",
            content:match("## 💡 Recommendations") and "Recommendations section"
        }
        
        local passed_checks = 0
        for _, check in ipairs(checks) do
            if check then
                passed_checks = passed_checks + 1
            end
        end
        
        -- Clean up
        os.remove(output_file)
        
        if passed_checks == #checks then
            print("✅ Comparative report generation: PASSED")
            print(string.format("   - All %d content checks passed", #checks))
            print("   - Successfully compared 4 algorithms")
            return true
        else
            print(string.format("❌ Comparative report generation: FAILED - %d/%d content checks passed", passed_checks, #checks))
            return false
        end
    else
        print(string.format("❌ Comparative report generation: FAILED - %s", result or "file not created"))
        return false
    end
end
-- }}}

-- {{{ function test_report_customization
function test_report_customization()
    print("\n⚙️ Testing Report Customization Options")
    print("=======================================")
    
    local mock_result = create_mock_validation_result("pearson_correlation", 0.78, 33.4)
    
    -- Test with details disabled
    local generator_no_details = ReportGenerator:new({
        format = "html",
        include_details = false,
        include_recommendations = false
    })
    
    local output_file = DIR .. "/test_no_details_report.html"
    
    local success, result = pcall(function()
        return generator_no_details:generate_validation_report(mock_result, output_file)
    end)
    
    if success and utils.file_exists(output_file) then
        local content = utils.read_file(output_file)
        
        -- Should NOT contain discrepancy details or recommendations
        local no_discrepancies = not content:match("Worst Discrepancies")
        local no_recommendations = not content:match("Recommendations")
        local has_basic_stats = content:match("78%.0%%")  -- Should still have basic stats
        
        -- Clean up
        os.remove(output_file)
        
        if no_discrepancies and no_recommendations and has_basic_stats then
            print("✅ Report customization: PASSED")
            print("   - Successfully excluded details and recommendations")
            print("   - Maintained basic statistics")
            return true
        else
            print("❌ Report customization: FAILED")
            print(string.format("   - No discrepancies: %s", no_discrepancies and "✓" or "✗"))
            print(string.format("   - No recommendations: %s", no_recommendations and "✓" or "✗"))
            print(string.format("   - Has basic stats: %s", has_basic_stats and "✓" or "✗"))
            return false
        end
    else
        print(string.format("❌ Report customization: FAILED - %s", result or "file not created"))
        return false
    end
end
-- }}}

-- {{{ function test_error_handling
function test_error_handling()
    print("\n🚨 Testing Report Generator Error Handling")
    print("==========================================")
    
    local tests_passed = 0
    local total_tests = 3
    
    -- Test 1: Invalid format
    print("Test 1: Invalid format")
    local generator_bad_format = ReportGenerator:new({format = "invalid_format"})
    local mock_result = create_mock_validation_result()
    
    local success, error = pcall(function()
        generator_bad_format:generate_validation_report(mock_result, "/tmp/test.txt")
    end)
    
    if not success and error:match("Unsupported report format") then
        print("  ✅ Correctly detected invalid format")
        tests_passed = tests_passed + 1
    else
        print("  ❌ Failed to detect invalid format")
    end
    
    -- Test 2: Missing validation result data
    print("Test 2: Missing validation result data")
    local generator = ReportGenerator:new({format = "html"})
    
    success, error = pcall(function()
        generator:generate_validation_report({}, DIR .. "/test_empty_result.html")
    end)
    
    if success then  -- Should handle gracefully with defaults
        print("  ✅ Gracefully handled missing data")
        tests_passed = tests_passed + 1
        -- Clean up if file was created
        if utils.file_exists(DIR .. "/test_empty_result.html") then
            os.remove(DIR .. "/test_empty_result.html")
        end
    else
        print("  ❌ Failed to handle missing data gracefully")
    end
    
    -- Test 3: Invalid output path
    print("Test 3: Invalid output path")
    success, error = pcall(function()
        generator:generate_validation_report(mock_result, "/nonexistent/directory/report.html")
    end)
    
    if not success then
        print("  ✅ Correctly detected invalid output path")
        tests_passed = tests_passed + 1
    else
        print("  ❌ Failed to detect invalid output path")
    end
    
    print(string.format("Error handling tests: %d/%d passed", tests_passed, total_tests))
    return tests_passed == total_tests
end
-- }}}

-- {{{ function test_template_substitution
function test_template_substitution()
    print("\n🔧 Testing Template Variable Substitution")
    print("=========================================")
    
    local generator = ReportGenerator:new({format = "html"})
    local mock_result = create_mock_validation_result("dot_product", 0.93, 41.7)
    
    -- Test template substitution directly
    local template = "Algorithm: {ALGORITHM}, Accuracy: {ACCURACY_PERCENT}%, Speed: {COMPARISONS_PER_SEC}"
    local substituted = generator:substitute_template_vars(template, mock_result)
    
    local expected = "Algorithm: dot_product, Accuracy: 93.0%, Speed: 41.7"
    
    if substituted == expected then
        print("✅ Template substitution: PASSED")
        print(string.format("   - Input: %s", template))
        print(string.format("   - Output: %s", substituted))
        return true
    else
        print("❌ Template substitution: FAILED")
        print(string.format("   - Expected: %s", expected))
        print(string.format("   - Got: %s", substituted))
        return false
    end
end
-- }}}

-- {{{ function main
function main()
    print("📊 Report Generator Test Suite")
    print("==============================\n")
    
    local tests = {
        {"HTML Report Generation", test_html_report_generation},
        {"Markdown Report Generation", test_markdown_report_generation},
        {"JSON Report Generation", test_json_report_generation},
        {"Comparative Report Generation", test_comparative_report_generation},
        {"Report Customization", test_report_customization},
        {"Template Substitution", test_template_substitution},
        {"Error Handling", test_error_handling}
    }
    
    local passed_tests = 0
    local total_tests = #tests
    
    for i, test in ipairs(tests) do
        local test_name, test_func = test[1], test[2]
        
        local success, result = pcall(test_func)
        
        if success and result then
            passed_tests = passed_tests + 1
            print(string.format("\n✅ %s: PASSED", test_name))
        else
            print(string.format("\n❌ %s: FAILED - %s", test_name, result or "unknown error"))
        end
    end
    
    print(string.format("\n\n📊 Final Results: %d/%d tests passed", passed_tests, total_tests))
    
    if passed_tests == total_tests then
        print("🎉 All report generator tests passed!")
        return 0
    else
        print("⚠️  Some tests failed - report generator needs attention")
        return 1
    end
end
-- }}}

-- Run tests if executed directly
if arg and arg[0] and arg[0]:match("test%-report%-generator%.lua$") then
    os.exit(main())
end

return {
    test_html_report_generation = test_html_report_generation,
    test_markdown_report_generation = test_markdown_report_generation,
    test_json_report_generation = test_json_report_generation,
    test_comparative_report_generation = test_comparative_report_generation,
    test_report_customization = test_report_customization,
    test_template_substitution = test_template_substitution,
    test_error_handling = test_error_handling,
    main = main,
    create_mock_validation_result = create_mock_validation_result
}