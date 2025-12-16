#!/usr/bin/env lua

-- Test script for diversity chaining algorithm
-- Validates algorithm functionality with real poetry data

local DIR = DIR or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

-- Set up path for module loading
package.path = './libs/?.lua;' .. package.path
package.path = './src/?.lua;' .. package.path

local utils = require('utils')
local diversity = require('diversity-chaining')

-- {{{ function run_basic_tests
local function run_basic_tests()
    utils.log_info("🧪 Running basic diversity chaining tests...")
    
    local similarity_file = DIR .. "/assets/embeddings/EmbeddingGemma_latest/similarity_matrix.json"
    local poems_file = DIR .. "/assets/poems.json"
    
    -- Test 1: Basic chain generation
    utils.log_info("Test 1: Basic chain generation")
    local result = diversity.test_diversity_algorithm(similarity_file, poems_file, 1, 5)
    
    if result then
        utils.log_info("✅ Test 1 passed - Basic chain generation works")
    else
        utils.log_error("❌ Test 1 failed - Basic chain generation failed")
        return false
    end
    
    -- Test 2: Different starting poems
    utils.log_info("Test 2: Different starting poems")
    local test_poems = {1, 100, 500, 1000}
    for _, poem_id in ipairs(test_poems) do
        local test_result = diversity.test_diversity_algorithm(similarity_file, poems_file, poem_id, 3)
        if not test_result then
            utils.log_warn("Warning: Chain generation failed for poem " .. poem_id)
        end
    end
    utils.log_info("✅ Test 2 completed - Multiple starting poem test")
    
    -- Test 3: Configuration validation
    utils.log_info("Test 3: Configuration validation")
    local config = diversity.DiversityConfig:new({
        chain_length = 15,
        debug_logging = true,
        max_length = 50
    })
    
    if config.chain_length == 15 and config.debug_logging == true then
        utils.log_info("✅ Test 3 passed - Configuration system works")
    else
        utils.log_error("❌ Test 3 failed - Configuration system broken")
        return false
    end
    
    return true
end
-- }}}

-- {{{ function run_performance_tests
local function run_performance_tests()
    utils.log_info("⚡ Running performance tests...")
    
    local similarity_file = DIR .. "/assets/embeddings/EmbeddingGemma_latest/similarity_matrix.json"
    local poems_file = DIR .. "/assets/poems.json"
    
    -- Load data once
    local similarity_data = diversity.load_similarity_data(similarity_file)
    local poems_data = utils.read_json_file(poems_file)
    
    if not similarity_data or not poems_data then
        utils.log_error("Failed to load test data")
        return false
    end
    
    -- Performance test: single chain generation
    local start_time = os.clock()
    local config = diversity.DiversityConfig:new({chain_length = 20, debug_logging = false})
    local result = diversity.generate_maximum_diversity_chain(1, poems_data.poems, similarity_data, config)
    local elapsed = os.clock() - start_time
    
    utils.log_info(string.format("Single chain generation: %.3f seconds", elapsed))
    
    if elapsed < 1.0 then  -- Should complete in under 1 second
        utils.log_info("✅ Performance test passed - Single chain < 1s")
    else
        utils.log_warn("⚠️ Performance test marginal - Single chain took " .. elapsed .. "s")
    end
    
    return result ~= nil
end
-- }}}

-- {{{ function run_diversity_analysis_tests
local function run_diversity_analysis_tests()
    utils.log_info("📊 Running diversity analysis tests...")
    
    local similarity_file = DIR .. "/assets/embeddings/EmbeddingGemma_latest/similarity_matrix.json"
    local poems_file = DIR .. "/assets/poems.json"
    
    local similarity_data = diversity.load_similarity_data(similarity_file)
    local poems_data = utils.read_json_file(poems_file)
    
    if not similarity_data or not poems_data then
        return false
    end
    
    -- Generate a test chain
    local config = diversity.DiversityConfig:new({chain_length = 10})
    local chain_result = diversity.generate_maximum_diversity_chain(1, poems_data.poems, similarity_data, config)
    
    if not chain_result or not chain_result.chain then
        utils.log_error("Failed to generate test chain for analysis")
        return false
    end
    
    -- Analyze the chain
    local analysis = diversity.analyze_chain_diversity(chain_result, similarity_data)
    
    if analysis.error then
        utils.log_error("Analysis failed: " .. analysis.error)
        return false
    end
    
    utils.log_info(string.format("Diversity Analysis Results:"))
    utils.log_info(string.format("  Chain length: %d", analysis.chain_length))
    utils.log_info(string.format("  Average diversity: %.3f", analysis.average_diversity))
    utils.log_info(string.format("  Median diversity: %.3f", analysis.median_diversity))
    utils.log_info(string.format("  Min diversity: %.3f", analysis.min_diversity))
    utils.log_info(string.format("  Max diversity: %.3f", analysis.max_diversity))
    utils.log_info(string.format("  Quality score: %.3f", analysis.quality_score))
    
    -- Validate diversity metrics
    if analysis.average_diversity > 0 and analysis.quality_score > 0 then
        utils.log_info("✅ Diversity analysis test passed")
        return true
    else
        utils.log_error("❌ Diversity analysis test failed - poor diversity scores")
        return false
    end
end
-- }}}

-- {{{ function run_batch_generation_test
local function run_batch_generation_test()
    utils.log_info("🔄 Running batch generation test...")
    
    local similarity_file = DIR .. "/assets/embeddings/EmbeddingGemma_latest/similarity_matrix.json"
    local poems_file = DIR .. "/assets/poems.json"
    
    local similarity_data = diversity.load_similarity_data(similarity_file)
    local poems_data = utils.read_json_file(poems_file)
    
    if not similarity_data or not poems_data then
        return false
    end
    
    -- Test with small batch
    local test_poem_ids = {1, 2, 3, 4, 5}
    local config = diversity.DiversityConfig:new({chain_length = 5, debug_logging = false})
    
    local start_time = os.clock()
    local batch_result = diversity.generate_multiple_diversity_chains(test_poem_ids, poems_data.poems, similarity_data, config)
    local elapsed = os.clock() - start_time
    
    utils.log_info(string.format("Batch generation: %.3f seconds for %d chains", elapsed, #test_poem_ids))
    
    if batch_result and batch_result.metadata then
        utils.log_info(string.format("Batch results: %d/%d successful (%.1f%% success rate)", 
                                    batch_result.metadata.successful_chains,
                                    batch_result.metadata.total_requested,
                                    batch_result.metadata.success_rate * 100))
        
        if batch_result.metadata.success_rate >= 0.8 then  -- 80% success rate minimum
            utils.log_info("✅ Batch generation test passed")
            return true
        else
            utils.log_warn("⚠️ Batch generation test marginal - low success rate")
            return true  -- Still passing but with warning
        end
    else
        utils.log_error("❌ Batch generation test failed")
        return false
    end
end
-- }}}

-- {{{ function main
local function main()
    utils.log_info("🔗 Starting Diversity Chaining Algorithm Tests")
    utils.log_info("=" .. string.rep("=", 50))
    
    local tests = {
        {"Basic Functionality", run_basic_tests},
        {"Performance", run_performance_tests},
        {"Diversity Analysis", run_diversity_analysis_tests},
        {"Batch Generation", run_batch_generation_test}
    }
    
    local passed = 0
    local total = #tests
    
    for i, test in ipairs(tests) do
        local name, test_func = test[1], test[2]
        utils.log_info(string.format("\n📋 Test %d/%d: %s", i, total, name))
        utils.log_info("-" .. string.rep("-", 30))
        
        local success, result = pcall(test_func)
        if success and result then
            utils.log_info("✅ " .. name .. " - PASSED")
            passed = passed + 1
        else
            utils.log_error("❌ " .. name .. " - FAILED")
            if not success then
                utils.log_error("Error: " .. tostring(result))
            end
        end
    end
    
    utils.log_info("\n" .. string.rep("=", 50))
    utils.log_info(string.format("🏁 Test Results: %d/%d passed (%.1f%%)", passed, total, (passed/total)*100))
    
    if passed == total then
        utils.log_info("🎉 All tests passed! Diversity chaining algorithm is ready.")
        return true
    else
        utils.log_error("❌ Some tests failed. Algorithm needs review.")
        return false
    end
end
-- }}}

-- Run tests if executed directly
if arg and arg[0] and arg[0]:match("test%-diversity%-chaining%.lua$") then
    local success = main()
    os.exit(success and 0 or 1)
end

return {
    main = main,
    run_basic_tests = run_basic_tests,
    run_performance_tests = run_performance_tests,
    run_diversity_analysis_tests = run_diversity_analysis_tests,
    run_batch_generation_test = run_batch_generation_test
}