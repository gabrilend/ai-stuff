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

-- {{{ local function build_mock_store
-- Write a miniature similarity store in the CURRENT shape: one file per poem
-- under <root>/similarities/, plus the embeddings.json they were derived from.
--
-- Scores are COMPUTED here, in the same centred space the pipeline uses, rather
-- than written as constants. Hardcoded expectations would need recomputing by
-- hand whenever the vector preparation changes -- and the last time it changed,
-- nobody noticed these fixtures at all. Deriving them means the fixture tracks
-- the real definition of "correct".
--
-- corrupt: when true, one score is pushed far outside any sane tolerance, so a
--          test can confirm the validator actually fails when it should.
-- returns: similarities directory path, embeddings file path
local function build_mock_store(root, vectors, corrupt)
    local embedding_space = require("embedding-space")

    local entries = {}
    local indices = {}
    for idx in pairs(vectors) do indices[#indices + 1] = idx end
    table.sort(indices)
    for _, idx in ipairs(indices) do
        entries[#entries + 1] = { poem_index = idx, id = idx, embedding = vectors[idx] }
    end

    local mean = embedding_space.corpus_mean(entries)
    local centred = {}
    for _, idx in ipairs(indices) do
        centred[idx] = embedding_space.centered(vectors[idx], mean)
    end

    local function cosine(a, b)
        local dot, na, nb = 0, 0, 0
        for i = 1, #a do
            dot = dot + a[i] * b[i]; na = na + a[i] * a[i]; nb = nb + b[i] * b[i]
        end
        if na == 0 or nb == 0 then return 0 end
        return dot / (math.sqrt(na) * math.sqrt(nb))
    end

    local sim_dir = root .. "/similarities"
    os.execute("rm -rf " .. root)
    os.execute("mkdir -p " .. sim_dir)

    local first = indices[1]
    local second = indices[2]
    for _, idx in ipairs(indices) do
        local sims = {}
        for _, other in ipairs(indices) do
            if other ~= idx then
                local score = cosine(centred[idx], centred[other])
                if corrupt and idx == first and other == second then
                    score = score + 0.5
                end
                sims[#sims + 1] = { id = tostring(other), similarity = score }
            end
        end
        utils.write_json_file(string.format("%s/poem_index_%d.json", sim_dir, idx), {
            metadata = { poem_id = tostring(idx), poem_index = idx,
                         total_comparisons = #sims, format = "full_bidirectional" },
            similarities = sims,
        })
    end

    local emb_file = root .. "/embeddings.json"
    utils.write_json_file(emb_file, { embeddings = entries })
    return sim_dir, emb_file
end
-- }}}

-- {{{ function test_validation_with_mock_data
-- Three rounds: an honest store validates clean, a corrupted one is caught, and
-- the retired single-file path is refused with an explanation.
function test_validation_with_mock_data()
    print("\n🔬 Testing Validation with Mock Data")
    print("===================================")

    local vectors = {
        [1] = {0.8, 0.6, 0.0},
        [2] = {0.9, 0.4, 0.1},
        [3] = {0.3, 0.7, 0.9},
        [4] = {0.1, 0.2, 0.8},
    }
    local root = DIR .. "/tmp/validation-engine-test"
    local passed = true

    local sim_dir, emb_file = build_mock_store(root, vectors, false)
    local engine = ValidationEngine:new({tolerance = 0.001})
    engine:set_calculator(SimilarityCalculator:new("cosine"))
    local ok, report = pcall(function()
        return engine:validate_similarity_matrix(sim_dir, emb_file)
    end)
    if ok and report and report.statistics.total_comparisons > 0
       and report.statistics.accuracy_rate > 0.99 then
        print(string.format("✅ Honest store validates clean (%d comparisons, %.2f%%)",
            report.statistics.total_comparisons, report.statistics.accuracy_rate * 100))
    else
        print(string.format("❌ Honest store did NOT validate clean: %s", tostring(report)))
        passed = false
    end

    -- A validator that cannot fail is not a validator.
    sim_dir, emb_file = build_mock_store(root, vectors, true)
    local engine2 = ValidationEngine:new({tolerance = 0.001})
    engine2:set_calculator(SimilarityCalculator:new("cosine"))
    local ok2, report2 = pcall(function()
        return engine2:validate_similarity_matrix(sim_dir, emb_file)
    end)
    if ok2 and report2 and report2.statistics.inaccurate_scores > 0 then
        print(string.format("✅ Corrupted score detected (%d discrepancies)",
            report2.statistics.inaccurate_scores))
    else
        print("❌ Corrupted score was NOT detected")
        passed = false
    end

    local engine3 = ValidationEngine:new({tolerance = 0.001})
    engine3:set_calculator(SimilarityCalculator:new("cosine"))
    local ok3, err3 = pcall(function()
        return engine3:validate_similarity_matrix(root .. "/similarity_matrix.json", emb_file)
    end)
    if (not ok3) and tostring(err3):find("retired") then
        print("✅ Retired single-file path refused with an explanation")
    else
        print("❌ Retired single-file path was not refused clearly")
        passed = false
    end

    os.execute("rm -rf " .. root)
    return passed
end
-- }}}

-- {{{ function test_validation_with_real_data
function test_validation_with_real_data()
    print("\n📊 Testing Validation with Real Project Data")
    print("============================================")
    
    -- Check if real data files exist
    -- Selected model's directory. "similarities" is a DIRECTORY of one file per
    -- poem; the single-file matrix named here previously was retired in Issue
    -- 8-033 and nothing has written it since.
    local model_dir = require("utils").embeddings_dir()
    local similarity_file = model_dir .. "/similarities"
    local embeddings_file = model_dir .. "/embeddings.json"
    
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
-- Every scoring algorithm should at least RUN against a current-shape store and
-- return a report. Accuracy is deliberately NOT asserted: the stored scores are
-- cosine, so euclidean or manhattan disagreeing with them is correct behaviour
-- rather than a fault. What is tested is that no algorithm chokes on the storage
-- format -- which is exactly what happened when the format changed underneath
-- this file and nobody ran it.
function test_multiple_algorithms()
    print("\n🧮 Testing Multiple Similarity Algorithms")
    print("==========================================")

    local algorithms_to_test = {"cosine", "euclidean", "angular", "manhattan"}
    local vectors = {
        [1] = {1.0, 0.0, 0.0},
        [2] = {0.8, 0.6, 0.0},
        [3] = {0.2, 0.4, 0.9},
    }
    local root = DIR .. "/tmp/validation-algorithms-test"
    local sim_dir, emb_file = build_mock_store(root, vectors, false)

    local ran = 0
    for _, algorithm in ipairs(algorithms_to_test) do
        local engine = ValidationEngine:new({tolerance = 0.5})
        engine:set_calculator(SimilarityCalculator:new(algorithm))
        local success, report = pcall(function()
            return engine:validate_similarity_matrix(sim_dir, emb_file)
        end)
        if success and report and report.statistics.total_comparisons > 0 then
            ran = ran + 1
            print(string.format("  ✅ %s: ran, %d comparisons, %.1f%% agreement with stored cosine",
                algorithm, report.statistics.total_comparisons,
                report.statistics.accuracy_rate * 100))
        else
            print(string.format("  ❌ %s: failed -- %s", algorithm, tostring(report)))
        end
    end

    os.execute("rm -rf " .. root)
    print(string.format("\nMulti-algorithm test results: %d/%d algorithms ran",
        ran, #algorithms_to_test))
    return ran == #algorithms_to_test
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
    -- A directory path, so the missing-calculator error is what surfaces rather
    -- than the retired-single-file refusal (both are errors; this test is about
    -- which one).
    local success, error = pcall(function()
        engine:validate_similarity_matrix(DIR .. "/tmp/no-such-store/similarities", "dummy.json")
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
        engine:validate_similarity_matrix(DIR .. "/tmp/no-such-store/similarities",
                                          DIR .. "/tmp/no-such-store/embeddings.json")
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
    
    -- A store shaped correctly but holding nonsense: the score is a string and
    -- one embedding is not an array. The engine should survive reading it.
    local bad_dir = DIR .. "/tmp/validation-bad-store/similarities"
    os.execute("rm -rf " .. DIR .. "/tmp/validation-bad-store")
    os.execute("mkdir -p " .. bad_dir)
    utils.write_json_file(bad_dir .. "/poem_index_1.json", {
        metadata = { poem_index = 1, poem_id = "1", total_comparisons = 1 },
        similarities = { { id = "2", similarity = "not_a_number" } },
    })
    utils.write_json_file(bad_embeddings_file, { embeddings = {
        { poem_index = 1, id = 1, embedding = {1, 2, 3} },
        { poem_index = 2, id = 2, embedding = {1, 2, 3} },
    }})
    bad_similarity_file = bad_dir
    
    success, error = pcall(function()
        return engine:validate_similarity_matrix(bad_similarity_file, bad_embeddings_file)
    end)
    
    -- Clean up. The similarity side is a DIRECTORY now, so os.remove cannot
    -- take it -- it would fail silently and leave the fixture behind for the
    -- next run to trip over.
    os.execute("rm -rf " .. DIR .. "/tmp/validation-bad-store")
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