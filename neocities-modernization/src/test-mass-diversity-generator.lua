#!/usr/bin/env lua

-- Test script for mass diversity page generation system
-- Validates batch generation, HTML output, and file organization

local DIR = DIR or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

-- Set up path for module loading
package.path = './libs/?.lua;' .. package.path
package.path = './src/?.lua;' .. package.path

local utils = require('utils')
local mass_generator = require('mass-diversity-generator')

-- {{{ function read_file
local function read_file(filepath)
    local file = io.open(filepath, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end
-- }}}

-- {{{ function run_basic_generation_tests
local function run_basic_generation_tests()
    utils.log_info("🧪 Running basic mass generation tests...")
    
    local similarity_file = DIR .. "/assets/embeddings/embeddinggemma_latest/similarity_matrix.json"
    local poems_file = DIR .. "/assets/poems.json"
    local test_output_dir = "/tmp/diversity_test_output"
    
    -- Clean test directory
    os.execute("rm -rf " .. test_output_dir)
    os.execute("mkdir -p " .. test_output_dir)
    
    -- Test 1: Small batch generation (5 poems)
    utils.log_info("Test 1: Small batch generation")
    local result = mass_generator.test_mass_generation(similarity_file, poems_file, test_output_dir, 5)
    
    if result then
        utils.log_info(string.format("✅ Test 1 passed - Generated %d pages with %.1f%% success rate", 
                                    result.total_pages, result.success_rate * 100))
    else
        utils.log_error("❌ Test 1 failed - Small batch generation failed")
        return false
    end
    
    -- Test 2: Check HTML file structure
    utils.log_info("Test 2: HTML file validation")
    local sample_file = test_output_dir .. "/poems/diversity/by-category/fediverse/poem-001.html"
    if utils.file_exists(sample_file) then
        local content = read_file(sample_file)
        if content and content:find("<!DOCTYPE html>") and content:find("Diversity Chain:") then
            utils.log_info("✅ Test 2 passed - HTML structure valid")
        else
            utils.log_error("❌ Test 2 failed - Invalid HTML structure")
            return false
        end
    else
        utils.log_warn("⚠️ Test 2 skipped - No sample file found")
    end
    
    -- Test 3: Directory structure validation
    utils.log_info("Test 3: Directory structure validation")
    local diversity_dir = test_output_dir .. "/poems/diversity"
    local index_file = diversity_dir .. "/index.html"
    local category_dir = diversity_dir .. "/by-category"
    
    if utils.file_exists(index_file) and utils.file_exists(category_dir) then
        utils.log_info("✅ Test 3 passed - Directory structure correct")
    else
        utils.log_error("❌ Test 3 failed - Missing directory structure")
        return false
    end
    
    return true
end
-- }}}

-- {{{ function run_performance_tests
local function run_performance_tests()
    utils.log_info("⚡ Running performance tests...")
    
    local similarity_file = DIR .. "/assets/embeddings/embeddinggemma_latest/similarity_matrix.json"
    local poems_file = DIR .. "/assets/poems.json"
    local test_output_dir = "/tmp/diversity_perf_test"
    
    -- Clean test directory
    os.execute("rm -rf " .. test_output_dir)
    os.execute("mkdir -p " .. test_output_dir)
    
    -- Performance test: 25 poems (5 batches)
    local start_time = os.clock()
    local result = mass_generator.test_mass_generation(similarity_file, poems_file, test_output_dir, 25)
    local elapsed = os.clock() - start_time
    
    if result then
        local rate = result.total_pages / elapsed
        utils.log_info(string.format("Performance results: %d pages in %.2f seconds (%.1f pages/sec)", 
                                    result.total_pages, elapsed, rate))
        
        if rate > 5.0 then  -- Should generate at least 5 pages per second
            utils.log_info("✅ Performance test passed - Generation rate > 5 pages/sec")
        else
            utils.log_warn("⚠️ Performance test marginal - Rate below 5 pages/sec")
        end
        
        return result
    else
        utils.log_error("❌ Performance test failed")
        return false
    end
end
-- }}}

-- {{{ function run_html_validation_tests
local function run_html_validation_tests()
    utils.log_info("📄 Running HTML validation tests...")
    
    local similarity_file = DIR .. "/assets/embeddings/embeddinggemma_latest/similarity_matrix.json"
    local poems_file = DIR .. "/assets/poems.json"
    local test_output_dir = "/tmp/diversity_html_test"
    
    -- Clean and generate test pages
    os.execute("rm -rf " .. test_output_dir)
    os.execute("mkdir -p " .. test_output_dir)
    
    local result = mass_generator.test_mass_generation(similarity_file, poems_file, test_output_dir, 10)
    
    if not result then
        utils.log_error("❌ HTML validation test failed - No pages generated")
        return false
    end
    
    -- Test HTML structure elements
    local test_passed = true
    local files_checked = 0
    
    for _, page in ipairs(result.pages) do
        if files_checked >= 3 then break end  -- Check first 3 files
        
        if utils.file_exists(page.file) then
            local content = read_file(page.file)
            
            -- Check required HTML elements
            local checks = {
                ["DOCTYPE"] = content:find("<!DOCTYPE html>"),
                ["title"] = content:find("<title>Diversity Chain:"),
                ["navigation"] = content:find("nav class=\"breadcrumb\""),
                ["chain"] = content:find("diversity%-chain"),
                ["styles"] = content:find("<style>"),
                ["responsive"] = content:find("@media")
            }
            
            for check_name, found in pairs(checks) do
                if not found then
                    utils.log_error(string.format("❌ HTML validation failed - Missing %s in %s", 
                                                 check_name, page.file))
                    test_passed = false
                end
            end
            
            files_checked = files_checked + 1
        end
    end
    
    if test_passed then
        utils.log_info(string.format("✅ HTML validation passed - %d files checked", files_checked))
        return true
    else
        utils.log_error("❌ HTML validation failed")
        return false
    end
end
-- }}}

-- {{{ function run_batch_processing_tests
local function run_batch_processing_tests()
    utils.log_info("🔄 Running batch processing tests...")
    
    local similarity_file = DIR .. "/assets/embeddings/embeddinggemma_latest/similarity_matrix.json"
    local poems_file = DIR .. "/assets/poems.json"
    
    -- Load data for batch testing
    local similarity_data = require('diversity-chaining').load_similarity_data(similarity_file)
    local poems_data = utils.read_json_file(poems_file)
    
    if not similarity_data or not poems_data then
        utils.log_error("❌ Batch processing test failed - Could not load data")
        return false
    end
    
    -- Create test batch with first 10 poems
    local test_batch = {}
    local count = 0
    for poem_id, poem_data in pairs(poems_data.poems) do
        if count >= 10 then break end
        table.insert(test_batch, {id = tonumber(poem_id), data = poem_data})
        count = count + 1
    end
    
    -- Test batch processing
    local test_output_dir = "/tmp/diversity_batch_test"
    os.execute("rm -rf " .. test_output_dir)
    os.execute("mkdir -p " .. test_output_dir)
    
    local config = require('diversity-chaining').DiversityConfig:new({
        chain_length = 3,  -- Short chains for testing
        debug_logging = false
    })
    
    local start_time = os.clock()
    local batch_results = mass_generator.generate_diversity_batch(
        test_batch, similarity_data, test_output_dir, poems_data, config
    )
    local elapsed = os.clock() - start_time
    
    if #batch_results > 0 then
        utils.log_info(string.format("✅ Batch processing passed: %d/%d poems processed in %.2f seconds", 
                                    #batch_results, #test_batch, elapsed))
        
        -- Verify files were created
        local files_created = 0
        for _, result in ipairs(batch_results) do
            if utils.file_exists(result.file) then
                files_created = files_created + 1
            end
        end
        
        if files_created == #batch_results then
            utils.log_info("✅ All batch files created successfully")
            return true
        else
            utils.log_error(string.format("❌ Only %d/%d batch files created", 
                                         files_created, #batch_results))
            return false
        end
    else
        utils.log_error("❌ Batch processing test failed - No results")
        return false
    end
end
-- }}}

-- {{{ function main
local function main()
    utils.log_info("🏭 Starting Mass Diversity Generator Tests")
    utils.log_info("=" .. string.rep("=", 50))
    
    local tests = {
        {"Basic Generation", run_basic_generation_tests},
        {"Performance", run_performance_tests},
        {"HTML Validation", run_html_validation_tests},
        {"Batch Processing", run_batch_processing_tests}
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
        utils.log_info("🎉 All tests passed! Mass diversity generator is ready.")
        return true
    else
        utils.log_error("❌ Some tests failed. Generator needs review.")
        return false
    end
end
-- }}}

-- Run tests if executed directly
if arg and arg[0] and arg[0]:match("test%-mass%-diversity%-generator%.lua$") then
    local success = main()
    os.exit(success and 0 or 1)
end

return {
    main = main,
    run_basic_generation_tests = run_basic_generation_tests,
    run_performance_tests = run_performance_tests,
    run_html_validation_tests = run_html_validation_tests,
    run_batch_processing_tests = run_batch_processing_tests
}