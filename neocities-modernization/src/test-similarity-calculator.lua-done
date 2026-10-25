#!/usr/bin/env lua

-- Test script for modular similarity calculator
-- Validates mathematical correctness and algorithm functionality

local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

package.path = package.path .. ';' .. DIR .. '/?.lua;' .. DIR .. '/libs/?.lua'

local similarity_module = require("src.similarity-calculator")
local SimilarityCalculator = similarity_module.SimilarityCalculator
local utils = require("libs.utils")

-- {{{ function test_all_algorithms
function test_all_algorithms()
    print("🧪 Testing Modular Similarity Calculator")
    print("========================================")
    
    local calculator = SimilarityCalculator:new("cosine")
    local algorithms = calculator.supported_algorithms
    
    local overall_results = {
        total_algorithms = #algorithms,
        passed_algorithms = 0,
        failed_algorithms = 0,
        algorithm_results = {}
    }
    
    for _, algorithm in ipairs(algorithms) do
        print(string.format("\n📊 Testing Algorithm: %s", algorithm))
        print(string.format("Description: %s", ""))
        
        local calc = SimilarityCalculator:new(algorithm)
        print(string.format("Description: %s", calc:get_algorithm_description()))
        
        local validation_result = calc:validate_implementation()
        overall_results.algorithm_results[algorithm] = validation_result
        
        if validation_result.all_tests_passed then
            overall_results.passed_algorithms = overall_results.passed_algorithms + 1
            print("✅ All validation tests PASSED")
        else
            overall_results.failed_algorithms = overall_results.failed_algorithms + 1
            print("❌ Some validation tests FAILED")
        end
        
        -- Show detailed test results
        for _, test_result in ipairs(validation_result.validation_results) do
            local status = test_result.passed and "✅" or "❌"
            print(string.format("  %s %s: expected %.4f, got %.4f (diff: %.4f)", 
                               status, test_result.test_name, 
                               test_result.expected, test_result.calculated, 
                               test_result.difference))
        end
    end
    
    return overall_results
end
-- }}}

-- {{{ function test_realistic_embeddings
function test_realistic_embeddings()
    print("\n\n🔬 Testing with Realistic Embedding Vectors")
    print("==========================================")
    
    -- Create some realistic-looking embedding vectors
    local poem_about_love = {0.8, 0.1, 0.6, -0.2, 0.4, 0.9, -0.1, 0.3}
    local poem_about_nature = {0.2, 0.7, -0.3, 0.8, 0.1, 0.4, 0.6, -0.2}
    local similar_love_poem = {0.7, 0.2, 0.5, -0.1, 0.3, 0.8, 0.0, 0.4}
    
    local test_algorithms = {"cosine", "euclidean", "angular", "pearson_correlation"}
    
    print("Test vectors:")
    print(string.format("Love poem 1:    %s", table.concat(poem_about_love, ", ")))
    print(string.format("Nature poem:    %s", table.concat(poem_about_nature, ", ")))  
    print(string.format("Love poem 2:    %s", table.concat(similar_love_poem, ", ")))
    
    for _, algorithm in ipairs(test_algorithms) do
        local calc = SimilarityCalculator:new(algorithm)
        
        local love1_nature = calc:calculate(poem_about_love, poem_about_nature)
        local love1_love2 = calc:calculate(poem_about_love, similar_love_poem)
        
        print(string.format("\n%s Algorithm:", algorithm))
        print(string.format("  Love1 <-> Nature:  %.4f", love1_nature))
        print(string.format("  Love1 <-> Love2:   %.4f", love1_love2))
        
        if love1_love2 > love1_nature then
            print("  ✅ Similar poems have higher similarity (expected)")
        else
            print("  ⚠️  Similar poems have lower similarity (unexpected)")
        end
    end
end
-- }}}

-- {{{ function test_error_handling
function test_error_handling()
    print("\n\n🚨 Testing Error Handling")
    print("========================")
    
    local tests = {
        {
            name = "Unsupported algorithm",
            test_func = function()
                SimilarityCalculator:new("nonexistent_algorithm")
            end
        },
        {
            name = "Mismatched vector dimensions",
            test_func = function()
                local calc = SimilarityCalculator:new("cosine")
                calc:calculate({1, 2, 3}, {1, 2})  -- Different lengths
            end
        },
        {
            name = "Nil embedding",
            test_func = function()
                local calc = SimilarityCalculator:new("cosine")
                calc:calculate(nil, {1, 2, 3})
            end
        }
    }
    
    for _, test in ipairs(tests) do
        local success, error_message = pcall(test.test_func)
        if success then
            print(string.format("❌ %s: Expected error but got success", test.name))
        else
            print(string.format("✅ %s: Correctly caught error - %s", test.name, error_message))
        end
    end
end
-- }}}

-- {{{ function main
function main()
    local overall_results = test_all_algorithms()
    test_realistic_embeddings()
    test_error_handling()
    
    print("\n\n📊 Overall Results Summary")
    print("=========================")
    print(string.format("Total algorithms tested: %d", overall_results.total_algorithms))
    print(string.format("Algorithms passed: %d", overall_results.passed_algorithms))
    print(string.format("Algorithms failed: %d", overall_results.failed_algorithms))
    
    if overall_results.failed_algorithms == 0 then
        print("\n🎉 All similarity algorithms working correctly!")
        return 0
    else
        print("\n⚠️  Some algorithms need attention")
        return 1
    end
end
-- }}}

-- Run tests if executed directly
if arg and arg[0] and arg[0]:match("test%-similarity%-calculator%.lua$") then
    os.exit(main())
end

return {
    test_all_algorithms = test_all_algorithms,
    test_realistic_embeddings = test_realistic_embeddings,
    test_error_handling = test_error_handling,
    main = main
}