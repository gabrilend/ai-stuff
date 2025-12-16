#!/usr/bin/env lua

-- Test script for validation engine
-- Tests validation framework with real similarity data

local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

package.path = package.path .. ';' .. DIR .. '/?.lua;' .. DIR .. '/libs/?.lua'

local validation_module = require("src.validation-engine")
local ValidationEngine = validation_module.ValidationEngine
local similarity_module = require("src.similarity-calculator")
local SimilarityCalculator = similarity_module.SimilarityCalculator
local utils = require("libs.utils")

-- {{{ function test_validation_engine_basic
function test_validation_engine_basic()
    print("🧪 Testing Basic Validation Engine Functionality")
    print("===============================================")
    
    -- Create a mock validation engine
    local engine = ValidationEngine:new({tolerance = 0.01})
    local calculator = SimilarityCalculator:new("cosine")
    engine:set_calculator(calculator)
    
    -- Test engine creation
    if engine.tolerance == 0.01 and engine.calculator then
        print("✅ Engine creation and calculator assignment: PASSED")
    else
        print("❌ Engine creation and calculator assignment: FAILED")
        return false
    end
    
    -- Test validation results structure
    local results = engine.validation_results
    if results.total_comparisons == 0 and 
       type(results.errors) == "table" and
       type(results.discrepancies) == "table" then
        print("✅ Validation results structure: PASSED")
    else
        print("❌ Validation results structure: FAILED")
        return false
    end
    
    return true
end
-- }}}

-- {{{ function test_validation_with_mock_data
function test_validation_with_mock_data()
    print("\n🔬 Testing Validation with Mock Data")
    print("===================================")
    
    -- Create mock similarity and embedding data
    local mock_similarity_data = {
        ["1"] = {
            ["2"] = 0.85,
            ["3"] = 0.42
        },
        ["2"] = {
            ["3"] = 0.67
        }
    }
    
    local mock_embeddings_data = {
        ["1"] = {0.8, 0.6, 0.0},
        ["2"] = {0.9, 0.4, 0.1},
        ["3"] = {0.3, 0.7, 0.9}
    }
    
    -- Write mock data to temporary files
    local temp_similarity_file = DIR .. "/test_similarity.json"
    local temp_embeddings_file = DIR .. "/test_embeddings.json"
    
    utils.write_json_file(temp_similarity_file, mock_similarity_data)
    utils.write_json_file(temp_embeddings_file, mock_embeddings_data)
    
    -- Test validation
    local engine = ValidationEngine:new({tolerance = 0.1})
    local calculator = SimilarityCalculator:new("cosine")
    engine:set_calculator(calculator)
    
    local success, report = pcall(function()
        return engine:validate_similarity_matrix(temp_similarity_file, temp_embeddings_file)
    end)
    
    -- Clean up temporary files
    os.remove(temp_similarity_file)
    os.remove(temp_embeddings_file)
    
    if success and report then
        print(string.format("✅ Mock validation completed successfully"))
        print(string.format("   - Total comparisons: %d", report.statistics.total_comparisons))
        print(string.format("   - Accuracy rate: %.2f%%", report.statistics.accuracy_rate * 100))
        print(string.format("   - Duration: %d seconds", report.duration_seconds))
        return true
    else
        print(string.format("❌ Mock validation failed: %s", report or "unknown error"))
        return false
    end
end
-- }}}

-- {{{ function test_validation_with_real_data
function test_validation_with_real_data()
    print("\n📊 Testing Validation with Real Project Data")
    print("============================================")
    
    -- Check if real data files exist
    local similarity_file = DIR .. "/assets/embeddings/EmbeddingGemma_latest/similarity_matrix.json"
    local embeddings_file = DIR .. "/assets/embeddings/EmbeddingGemma_latest/embeddings.json"
    
    local similarity_exists = utils.file_exists(similarity_file)
    local embeddings_exists = utils.file_exists(embeddings_file)
    
    if not similarity_exists or not embeddings_exists then
        print("⚠️  Real data files not found, skipping real data test")
        print(string.format("   - Similarity file exists: %s", similarity_exists and "yes" or "no"))
        print(string.format("   - Embeddings file exists: %s", embeddings_exists and "yes" or "no"))
        return true  -- Not a failure, just no data available
    end
    
    print("📁 Real data files found, running validation test...")
    
    -- Test with sample of real data
    local engine = ValidationEngine:new({
        tolerance = 0.001,
        sample_size = 100  -- Small sample for testing
    })
    local calculator = SimilarityCalculator:new("cosine")
    engine:set_calculator(calculator)
    
    local success, report = pcall(function()
        return engine:validate_similarity_matrix(similarity_file, embeddings_file)
    end)
    
    if success and report then
        print(string.format("✅ Real data validation completed successfully"))
        print(string.format("   - Total comparisons: %d", report.statistics.total_comparisons))
        print(string.format("   - Accuracy rate: %.2f%%", report.statistics.accuracy_rate * 100))
        print(string.format("   - Missing embeddings: %d", report.statistics.missing_embeddings))
        print(string.format("   - Calculation errors: %d", report.errors.count))
        print(string.format("   - Discrepancies: %d", report.discrepancies.count))
        print(string.format("   - Performance: %.1f comparisons/sec", report.performance.comparisons_per_second))
        
        if #report.recommendations > 0 then
            print("   - Recommendations:")
            for i, rec in ipairs(report.recommendations) do
                print(string.format("     %d. %s", i, rec))
            end
        end
        
        return true
    else
        print(string.format("❌ Real data validation failed: %s", report or "unknown error"))
        return false
    end
end
-- }}}

-- {{{ function test_multiple_algorithms
function test_multiple_algorithms()
    print("\n🧮 Testing Multiple Similarity Algorithms")
    print("==========================================")
    
    local algorithms_to_test = {"cosine", "euclidean", "angular", "manhattan"}
    
    -- Create simple test data
    local test_data = {
        similarity = {["1"] = {["2"] = 0.85}},
        embeddings = {["1"] = {1, 0, 0}, ["2"] = {0.8, 0.6, 0}}
    }
    
    local temp_similarity_file = DIR .. "/test_algorithms_similarity.json"
    local temp_embeddings_file = DIR .. "/test_algorithms_embeddings.json"
    
    utils.write_json_file(temp_similarity_file, test_data.similarity)
    utils.write_json_file(temp_embeddings_file, test_data.embeddings)
    
    local results = {}
    
    for _, algorithm in ipairs(algorithms_to_test) do
        print(string.format("Testing algorithm: %s", algorithm))
        
        local engine = ValidationEngine:new({tolerance = 0.5})  -- Relaxed tolerance for different algorithms
        local calculator = SimilarityCalculator:new(algorithm)
        engine:set_calculator(calculator)
        
        local success, report = pcall(function()
            return engine:validate_similarity_matrix(temp_similarity_file, temp_embeddings_file)
        end)
        
        if success then
            results[algorithm] = {
                success = true,
                accuracy = report.statistics.accuracy_rate,
                comparisons = report.statistics.total_comparisons
            }
            print(string.format("  ✅ %s: %.1f%% accuracy", algorithm, report.statistics.accuracy_rate * 100))
        else
            results[algorithm] = {
                success = false,
                error = report
            }
            print(string.format("  ❌ %s: failed", algorithm))
        end
    end
    
    -- Clean up
    os.remove(temp_similarity_file)
    os.remove(temp_embeddings_file)
    
    local successful_algorithms = 0
    for _, result in pairs(results) do
        if result.success then
            successful_algorithms = successful_algorithms + 1
        end
    end
    
    print(string.format("\nMulti-algorithm test results: %d/%d algorithms successful", 
                       successful_algorithms, #algorithms_to_test))
    
    return successful_algorithms == #algorithms_to_test
end
-- }}}

-- {{{ function test_error_handling
function test_error_handling()
    print("\n🚨 Testing Error Handling")
    print("=========================")
    
    local tests_passed = 0
    local total_tests = 3
    
    -- Test 1: Missing calculator
    print("Test 1: Missing calculator")
    local engine = ValidationEngine:new()
    local success, error = pcall(function()
        engine:validate_similarity_matrix("dummy.json", "dummy.json")
    end)
    
    if not success and error:match("calculator must be set") then
        print("  ✅ Correctly detected missing calculator")
        tests_passed = tests_passed + 1
    else
        print("  ❌ Failed to detect missing calculator")
    end
    
    -- Test 2: Invalid data files
    print("Test 2: Invalid data files")
    engine:set_calculator(SimilarityCalculator:new("cosine"))
    success, error = pcall(function()
        engine:validate_similarity_matrix("nonexistent.json", "nonexistent.json")
    end)
    
    if not success then
        print("  ✅ Correctly handled missing data files")
        tests_passed = tests_passed + 1
    else
        print("  ❌ Failed to handle missing data files")
    end
    
    -- Test 3: Malformed data handling
    print("Test 3: Malformed data handling")
    
    -- Create files with malformed data
    local bad_similarity_file = DIR .. "/test_bad_similarity.json"
    local bad_embeddings_file = DIR .. "/test_bad_embeddings.json"
    
    utils.write_json_file(bad_similarity_file, {["1"] = {["2"] = "not_a_number"}})
    utils.write_json_file(bad_embeddings_file, {["1"] = {1, 2, 3}, ["2"] = "not_an_array"})
    
    success, error = pcall(function()
        return engine:validate_similarity_matrix(bad_similarity_file, bad_embeddings_file)
    end)
    
    -- Clean up
    os.remove(bad_similarity_file)
    os.remove(bad_embeddings_file)
    
    if success then
        print("  ✅ Gracefully handled malformed data")
        tests_passed = tests_passed + 1
    else
        print("  ❌ Failed to handle malformed data gracefully")
    end
    
    print(string.format("Error handling tests: %d/%d passed", tests_passed, total_tests))
    return tests_passed == total_tests
end
-- }}}

-- {{{ function main
function main()
    print("🔍 Validation Engine Test Suite")
    print("==============================\n")
    
    local tests = {
        {"Basic Functionality", test_validation_engine_basic},
        {"Mock Data Validation", test_validation_with_mock_data},
        {"Real Data Validation", test_validation_with_real_data},
        {"Multiple Algorithms", test_multiple_algorithms},
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
        print("🎉 All validation engine tests passed!")
        return 0
    else
        print("⚠️  Some tests failed - validation engine needs attention")
        return 1
    end
end
-- }}}

-- Run tests if executed directly
if arg and arg[0] and arg[0]:match("test%-validation%-engine%.lua$") then
    os.exit(main())
end

return {
    test_validation_engine_basic = test_validation_engine_basic,
    test_validation_with_mock_data = test_validation_with_mock_data,
    test_validation_with_real_data = test_validation_with_real_data,
    test_multiple_algorithms = test_multiple_algorithms,
    test_error_handling = test_error_handling,
    main = main
}