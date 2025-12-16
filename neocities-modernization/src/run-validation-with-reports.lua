#!/usr/bin/env lua

-- Integrated Validation and Reporting CLI
-- Combines validation engine with report generation for complete validation workflow

local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

package.path = package.path .. ';' .. DIR .. '/?.lua;' .. DIR .. '/libs/?.lua'

local validation_module = require("src.validation-engine")
local report_module = require("src.report-generator")
local utils = require("libs.utils")

-- {{{ function show_usage
function show_usage()
    print("Integrated Similarity Validation and Reporting Tool")
    print("===================================================")
    print("")
    print("Usage:")
    print("  lua src/run-validation-with-reports.lua [options]")
    print("")
    print("Options:")
    print("  -h, --help              Show this help message")
    print("  -I, --interactive       Run in interactive mode")
    print("  -a, --algorithm ALGO    Similarity algorithm to use (default: cosine)")
    print("  -t, --tolerance NUM     Tolerance for similarity comparison (default: 0.001)")
    print("  -s, --sample SIZE       Sample size for validation (default: all)")
    print("  -o, --output DIR        Output directory for reports (default: ./validation_reports)")
    print("  -f, --format FORMAT     Report format: html, markdown, json (default: html)")
    print("  --similarity FILE       Similarity matrix file to validate")
    print("  --embeddings FILE       Embeddings file for recalculation")
    print("  --compare               Run comparative analysis across multiple algorithms")
    print("  --test                  Run validation and reporting tests")
    print("")
    print("Examples:")
    print("  lua src/run-validation-with-reports.lua --test")
    print("  lua src/run-validation-with-reports.lua -I")
    print("  lua src/run-validation-with-reports.lua -a cosine -f html")
    print("  lua src/run-validation-with-reports.lua --compare -f markdown")
    print("  lua src/run-validation-with-reports.lua --similarity matrix.json --embeddings embed.json")
end
-- }}}

-- {{{ function parse_arguments
function parse_arguments(args)
    local config = {
        algorithm = "cosine",
        tolerance = 0.001,
        sample_size = nil,
        output_dir = "./validation_reports",
        format = "html",
        similarity_file = nil,
        embeddings_file = nil,
        interactive = false,
        run_tests = false,
        compare_algorithms = false,
        show_help = false
    }
    
    local i = 1
    while i <= #args do
        local arg = args[i]
        
        if arg == "-h" or arg == "--help" then
            config.show_help = true
        elseif arg == "-I" or arg == "--interactive" then
            config.interactive = true
        elseif arg == "-a" or arg == "--algorithm" then
            i = i + 1
            config.algorithm = args[i] or "cosine"
        elseif arg == "-t" or arg == "--tolerance" then
            i = i + 1
            config.tolerance = tonumber(args[i]) or 0.001
        elseif arg == "-s" or arg == "--sample" then
            i = i + 1
            config.sample_size = tonumber(args[i])
        elseif arg == "-o" or arg == "--output" then
            i = i + 1
            config.output_dir = args[i] or "./validation_reports"
        elseif arg == "-f" or arg == "--format" then
            i = i + 1
            config.format = args[i] or "html"
        elseif arg == "--similarity" then
            i = i + 1
            config.similarity_file = args[i]
        elseif arg == "--embeddings" then
            i = i + 1
            config.embeddings_file = args[i]
        elseif arg == "--compare" then
            config.compare_algorithms = true
        elseif arg == "--test" then
            config.run_tests = true
        else
            print(string.format("Unknown argument: %s", arg))
            config.show_help = true
        end
        
        i = i + 1
    end
    
    return config
end
-- }}}

-- {{{ function interactive_mode
function interactive_mode()
    print("🔍 Interactive Validation and Reporting Mode")
    print("=============================================")
    
    -- Algorithm selection
    local algorithms = {"cosine", "euclidean", "manhattan", "angular", "pearson_correlation", "dot_product", "normalized_euclidean", "chebyshev"}
    
    print("\nSelect similarity algorithm:")
    for i, algo in ipairs(algorithms) do
        print(string.format("  %d. %s", i, algo))
    end
    io.write("Choice (1-" .. #algorithms .. ") [1]: ")
    local algo_choice = tonumber(io.read()) or 1
    local selected_algorithm = algorithms[algo_choice] or algorithms[1]
    
    -- Report format selection
    local formats = {"html", "markdown", "json"}
    print("\nSelect report format:")
    for i, format in ipairs(formats) do
        print(string.format("  %d. %s", i, format))
    end
    io.write("Choice (1-" .. #formats .. ") [1]: ")
    local format_choice = tonumber(io.read()) or 1
    local selected_format = formats[format_choice] or formats[1]
    
    -- Validation mode
    print("\nSelect validation mode:")
    print("  1. Single algorithm validation")
    print("  2. Comparative analysis (multiple algorithms)")
    io.write("Choice (1-2) [1]: ")
    local mode_choice = tonumber(io.read()) or 1
    
    local compare_algorithms = mode_choice == 2
    
    -- Tolerance setting
    io.write("Tolerance for similarity comparison [0.001]: ")
    local tolerance_input = io.read()
    local tolerance = tonumber(tolerance_input) or 0.001
    
    -- Sample size setting
    io.write("Sample size (leave empty for full validation): ")
    local sample_input = io.read()
    local sample_size = sample_input ~= "" and tonumber(sample_input) or nil
    
    -- File selection
    print("\nSelect data source:")
    print("  1. Use default project files")
    print("  2. Specify custom files")
    io.write("Choice (1-2) [1]: ")
    local file_choice = tonumber(io.read()) or 1
    
    local similarity_file, embeddings_file
    
    if file_choice == 2 then
        io.write("Similarity matrix file: ")
        similarity_file = io.read()
        io.write("Embeddings file: ")
        embeddings_file = io.read()
    else
        similarity_file = DIR .. "/assets/embeddings/EmbeddingGemma_latest/similarity_matrix.json"
        embeddings_file = DIR .. "/assets/embeddings/EmbeddingGemma_latest/embeddings.json"
    end
    
    return {
        algorithm = selected_algorithm,
        format = selected_format,
        tolerance = tolerance,
        sample_size = sample_size,
        similarity_file = similarity_file,
        embeddings_file = embeddings_file,
        output_dir = "./validation_reports",
        compare_algorithms = compare_algorithms
    }
end
-- }}}

-- {{{ function run_single_validation_with_report
function run_single_validation_with_report(config)
    print("\n🔍 Running Single Algorithm Validation with Reporting")
    print("======================================================")
    
    -- Check files exist
    if not utils.file_exists(config.similarity_file) then
        error("Similarity file not found: " .. (config.similarity_file or "none specified"))
    end
    
    if not utils.file_exists(config.embeddings_file) then
        error("Embeddings file not found: " .. (config.embeddings_file or "none specified"))
    end
    
    -- Create output directory
    os.execute("mkdir -p " .. config.output_dir)
    
    print(string.format("Configuration:"))
    print(string.format("  - Algorithm: %s", config.algorithm))
    print(string.format("  - Format: %s", config.format))
    print(string.format("  - Tolerance: %f", config.tolerance))
    print(string.format("  - Sample size: %s", config.sample_size and tostring(config.sample_size) or "full dataset"))
    print(string.format("  - Output directory: %s", config.output_dir))
    
    -- Run validation
    print("\nRunning validation...")
    local validation_result = validation_module.validate_single_file(
        config.similarity_file,
        config.embeddings_file,
        config.algorithm,
        {
            tolerance = config.tolerance,
            sample_size = config.sample_size
        }
    )
    
    -- Generate report
    print(string.format("Generating %s report...", config.format))
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local report_extension = config.format == "html" and "html" or (config.format == "json" and "json" or "md")
    local report_file = string.format("%s/validation_report_%s_%s.%s", 
                                     config.output_dir, config.algorithm, timestamp, report_extension)
    
    local generated_report = report_module.generate_single_report(validation_result, report_file, config.format)
    
    -- Print summary
    print("\n📊 Validation Results Summary")
    print("=============================")
    print(string.format("Algorithm: %s", validation_result.algorithm))
    print(string.format("Duration: %d seconds", validation_result.duration_seconds))
    print(string.format("Total comparisons: %d", validation_result.statistics.total_comparisons))
    print(string.format("Accuracy rate: %.2f%%", validation_result.statistics.accuracy_rate * 100))
    print(string.format("Performance: %.1f comparisons/sec", validation_result.performance.comparisons_per_second))
    
    print(string.format("\n📋 Report generated: %s", generated_report))
    
    return validation_result, generated_report
end
-- }}}

-- {{{ function run_comparative_validation_with_report
function run_comparative_validation_with_report(config)
    print("\n📊 Running Comparative Algorithm Analysis")
    print("=========================================")
    
    local algorithms_to_compare = {"cosine", "euclidean", "angular", "manhattan"}
    
    -- Check files exist
    if not utils.file_exists(config.similarity_file) then
        error("Similarity file not found: " .. (config.similarity_file or "none specified"))
    end
    
    if not utils.file_exists(config.embeddings_file) then
        error("Embeddings file not found: " .. (config.embeddings_file or "none specified"))
    end
    
    -- Create output directory
    os.execute("mkdir -p " .. config.output_dir)
    
    print(string.format("Configuration:"))
    print(string.format("  - Algorithms: %s", table.concat(algorithms_to_compare, ", ")))
    print(string.format("  - Format: %s", config.format))
    print(string.format("  - Tolerance: %f", config.tolerance))
    print(string.format("  - Sample size: %s", config.sample_size and tostring(config.sample_size) or "full dataset"))
    
    -- Run validation for each algorithm
    local validation_results = {}
    
    for i, algorithm in ipairs(algorithms_to_compare) do
        print(string.format("\nRunning validation %d/%d: %s", i, #algorithms_to_compare, algorithm))
        
        local validation_result = validation_module.validate_single_file(
            config.similarity_file,
            config.embeddings_file,
            algorithm,
            {
                tolerance = config.tolerance,
                sample_size = config.sample_size
            }
        )
        
        table.insert(validation_results, validation_result)
        
        print(string.format("  - %s: %.1f%% accuracy, %.1f comparisons/sec", 
              algorithm, validation_result.statistics.accuracy_rate * 100, 
              validation_result.performance.comparisons_per_second))
    end
    
    -- Generate comparative report
    print(string.format("\nGenerating comparative %s report...", config.format))
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local report_extension = config.format == "html" and "html" or (config.format == "json" and "json" or "md")
    local report_file = string.format("%s/comparative_validation_report_%s.%s", 
                                     config.output_dir, timestamp, report_extension)
    
    local generated_report = report_module.generate_comparative_report(validation_results, report_file, config.format)
    
    -- Print summary
    print("\n📊 Comparative Analysis Summary")
    print("===============================")
    
    -- Sort results by accuracy for summary
    table.sort(validation_results, function(a, b)
        return a.statistics.accuracy_rate > b.statistics.accuracy_rate
    end)
    
    print("Algorithm Rankings by Accuracy:")
    for i, result in ipairs(validation_results) do
        print(string.format("  %d. %s: %.2f%% accuracy (%.1f comp/sec)", 
              i, result.algorithm, result.statistics.accuracy_rate * 100, 
              result.performance.comparisons_per_second))
    end
    
    print(string.format("\n📋 Comparative report generated: %s", generated_report))
    
    return validation_results, generated_report
end
-- }}}

-- {{{ function run_tests
function run_tests()
    print("🧪 Running Integrated Validation and Reporting Tests")
    print("====================================================")
    
    local validation_test = require("src.test-validation-engine")
    local report_test = require("src.test-report-generator")
    
    print("\n1. Testing Validation Engine:")
    local validation_result = validation_test.main()
    
    print("\n2. Testing Report Generator:")
    local report_result = report_test.main()
    
    print("\n3. Testing Integration:")
    -- Create a quick integration test
    local mock_result = report_test.create_mock_validation_result("cosine", 0.95, 67.5)
    local test_report_file = DIR .. "/test_integration_report.html"
    
    local integration_success = pcall(function()
        return report_module.generate_single_report(mock_result, test_report_file, "html")
    end)
    
    if integration_success and utils.file_exists(test_report_file) then
        print("✅ Integration test: PASSED")
        os.remove(test_report_file)
    else
        print("❌ Integration test: FAILED")
    end
    
    local overall_success = (validation_result == 0) and (report_result == 0) and integration_success
    
    if overall_success then
        print("\n🎉 All integrated tests passed!")
        return 0
    else
        print("\n⚠️  Some tests failed")
        return 1
    end
end
-- }}}

-- {{{ function main
function main(args)
    local config = parse_arguments(args or {})
    
    if config.show_help then
        show_usage()
        return 0
    end
    
    if config.run_tests then
        return run_tests()
    end
    
    if config.interactive then
        config = interactive_mode()
    end
    
    -- Validate required parameters
    if not config.similarity_file or not config.embeddings_file then
        if not config.interactive then
            print("Error: Must specify similarity and embeddings files or use interactive mode")
            show_usage()
            return 1
        end
    end
    
    local success, result = pcall(function()
        if config.compare_algorithms then
            return run_comparative_validation_with_report(config)
        else
            return run_single_validation_with_report(config)
        end
    end)
    
    if success then
        print("\n✅ Validation and reporting completed successfully")
        return 0
    else
        print(string.format("\n❌ Validation and reporting failed: %s", result))
        return 1
    end
end
-- }}}

-- Run main if executed directly
if arg and arg[0] and arg[0]:match("run%-validation%-with%-reports%.lua$") then
    os.exit(main(arg))
end

return {
    main = main,
    run_single_validation_with_report = run_single_validation_with_report,
    run_comparative_validation_with_report = run_comparative_validation_with_report,
    interactive_mode = interactive_mode,
    parse_arguments = parse_arguments
}