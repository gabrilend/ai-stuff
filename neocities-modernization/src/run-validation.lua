#!/usr/bin/env lua

-- Validation Runner Script
-- Command-line interface for running similarity data validation

local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

package.path = package.path .. ';' .. DIR .. '/?.lua;' .. DIR .. '/libs/?.lua'

local validation_module = require("src.validation-engine")
local utils = require("libs.utils")
local json = require("libs.json")

-- {{{ function show_usage
function show_usage()
    require("output").print("Similarity Validation Runner")
    require("output").print("===========================")
    require("output").print("")
    require("output").print("Usage:")
    require("output").print("  lua src/run-validation.lua [options]")
    require("output").print("")
    require("output").print("Options:")
    require("output").print("  -h, --help              Show this help message")
    require("output").print("  -I, --interactive       Run in interactive mode")
    require("output").print("  -a, --algorithm ALGO    Similarity algorithm to use (default: cosine)")
    require("output").print("  -t, --tolerance NUM     Tolerance for similarity comparison (default: 0.001)")
    require("output").print("  -s, --sample SIZE       Sample size for validation (default: all)")
    require("output").print("  -o, --output DIR        Output directory for reports (default: ./validation_reports)")
    require("output").print("  --similarity FILE       Similarity matrix file to validate")
    require("output").print("  --embeddings FILE       Embeddings file for recalculation")
    require("output").print("  --test                  Run validation engine tests")
    require("output").print("")
    require("output").print("Examples:")
    require("output").print("  lua src/run-validation.lua --test")
    require("output").print("  lua src/run-validation.lua -I")
    require("output").print("  lua src/run-validation.lua -a cosine -t 0.001 -s 1000")
    require("output").print("  lua src/run-validation.lua --similarity matrix.json --embeddings embed.json")
end
-- }}}

-- {{{ function parse_arguments
function parse_arguments(args)
    local config = {
        algorithm = "cosine",
        tolerance = 0.001,
        sample_size = nil,
        output_dir = "./validation_reports",
        similarity_file = nil,
        embeddings_file = nil,
        interactive = false,
        run_tests = false,
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
        elseif arg == "--similarity" then
            i = i + 1
            config.similarity_file = args[i]
        elseif arg == "--embeddings" then
            i = i + 1
            config.embeddings_file = args[i]
        elseif arg == "--test" then
            config.run_tests = true
        else
            require("output").print(string.format("Unknown argument: %s", arg))
            config.show_help = true
        end
        
        i = i + 1
    end
    
    return config
end
-- }}}

-- {{{ function interactive_mode
function interactive_mode()
    require("output").print("🔍 Interactive Validation Mode")
    require("output").print("==============================")
    
    -- Algorithm selection
    local algorithms = {"cosine", "euclidean", "manhattan", "angular", "pearson_correlation", "dot_product", "normalized_euclidean", "chebyshev"}
    
    require("output").print("\nSelect similarity algorithm:")
    for i, algo in ipairs(algorithms) do
        require("output").print(string.format("  %d. %s", i, algo))
    end
    io.write("Choice (1-" .. #algorithms .. ") [1]: ")
    local algo_choice = tonumber(io.read()) or 1
    local selected_algorithm = algorithms[algo_choice] or algorithms[1]
    
    -- Tolerance setting
    io.write("Tolerance for similarity comparison [0.001]: ")
    local tolerance_input = io.read()
    local tolerance = tonumber(tolerance_input) or 0.001
    
    -- Sample size setting
    io.write("Sample size (leave empty for full validation): ")
    local sample_input = io.read()
    local sample_size = sample_input ~= "" and tonumber(sample_input) or nil
    
    -- File selection
    require("output").print("\nSelect validation mode:")
    require("output").print("  1. Use default project files")
    require("output").print("  2. Specify custom files")
    io.write("Choice (1-2) [1]: ")
    local file_choice = tonumber(io.read()) or 1
    
    local similarity_file, embeddings_file
    
    if file_choice == 2 then
        io.write("Similarity matrix file: ")
        similarity_file = io.read()
        io.write("Embeddings file: ")
        embeddings_file = io.read()
    else
        -- The selected model's directory, resolved rather than typed.
        --
        -- "similarities" is a DIRECTORY of one file per poem, not a file. The
        -- single-file matrix this used to name was retired in Issue 8-033 and
        -- nothing has written it since, so the default pointed at something that
        -- could never be there.
        local model_dir = require("utils").embeddings_dir()
        similarity_file = model_dir .. "/similarities"
        embeddings_file = model_dir .. "/embeddings.json"
    end
    
    return {
        algorithm = selected_algorithm,
        tolerance = tolerance,
        sample_size = sample_size,
        similarity_file = similarity_file,
        embeddings_file = embeddings_file,
        output_dir = "./validation_reports"
    }
end
-- }}}

-- {{{ function run_validation
function run_validation(config)
    require("output").print("\n🔍 Starting Validation Process")
    require("output").print("==============================")
    
    -- Check files exist
    if not utils.file_exists(config.similarity_file) then
        error("Similarity file not found: " .. (config.similarity_file or "none specified"))
    end
    
    if not utils.file_exists(config.embeddings_file) then
        error("Embeddings file not found: " .. (config.embeddings_file or "none specified"))
    end
    
    -- Create output directory
    os.execute("mkdir -p " .. config.output_dir)
    
    require("output").print(string.format("Configuration:"))
    require("output").print(string.format("  - Algorithm: %s", config.algorithm))
    require("output").print(string.format("  - Tolerance: %f", config.tolerance))
    require("output").print(string.format("  - Sample size: %s", config.sample_size and tostring(config.sample_size) or "full dataset"))
    require("output").print(string.format("  - Similarity file: %s", config.similarity_file))
    require("output").print(string.format("  - Embeddings file: %s", config.embeddings_file))
    require("output").print(string.format("  - Output directory: %s", config.output_dir))
    
    -- Run validation
    local report = validation_module.validate_single_file(
        config.similarity_file,
        config.embeddings_file,
        config.algorithm,
        {
            tolerance = config.tolerance,
            sample_size = config.sample_size
        }
    )
    
    -- Save detailed report
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local report_file = string.format("%s/validation_report_%s_%s.json", 
                                     config.output_dir, config.algorithm, timestamp)
    
    utils.write_json_file(report_file, report)
    
    -- Print summary
    require("output").print("\n📊 Validation Results Summary")
    require("output").print("=============================")
    require("output").print(string.format("Algorithm: %s", report.algorithm))
    require("output").print(string.format("Duration: %d seconds", report.duration_seconds))
    require("output").print(string.format("Total comparisons: %d", report.statistics.total_comparisons))
    require("output").print(string.format("Accuracy rate: %.2f%%", report.statistics.accuracy_rate * 100))
    require("output").print(string.format("Missing embeddings: %d", report.statistics.missing_embeddings))
    require("output").print(string.format("Calculation errors: %d", report.errors.count))
    require("output").print(string.format("Discrepancies: %d", report.discrepancies.count))
    require("output").print(string.format("Performance: %.1f comparisons/sec", report.performance.comparisons_per_second))
    
    if report.discrepancies.max_difference then
        require("output").print(string.format("Maximum discrepancy: %.6f", report.discrepancies.max_difference))
    end
    
    require("output").print(string.format("\nDetailed report saved: %s", report_file))
    
    if #report.recommendations > 0 then
        require("output").print("\nRecommendations:")
        for i, rec in ipairs(report.recommendations) do
            require("output").print(string.format("  %d. %s", i, rec))
        end
    end
    
    return report
end
-- }}}

-- {{{ function run_tests
function run_tests()
    local test_module = require("src.test-validation-engine")
    return test_module.main()
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
            require("output").print("Error: Must specify similarity and embeddings files or use interactive mode")
            show_usage()
            return 1
        end
    end
    
    local success, result = pcall(function()
        return run_validation(config)
    end)
    
    if success then
        require("output").print("\n✅ Validation completed successfully")
        return 0
    else
        require("output").print(string.format("\n❌ Validation failed: %s", result))
        return 1
    end
end
-- }}}

-- Run main if executed directly
if arg and arg[0] and arg[0]:match("run%-validation%.lua$") then
    os.exit(main(arg))
end

return {
    main = main,
    run_validation = run_validation,
    interactive_mode = interactive_mode,
    parse_arguments = parse_arguments
}
