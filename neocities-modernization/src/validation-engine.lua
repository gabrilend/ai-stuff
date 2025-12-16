#!/usr/bin/env lua

-- Validation Engine for Similarity Data Integrity
-- Iterative system for validating stored similarity scores against recalculated values

package.path = package.path .. ';./?.lua;./libs/?.lua'

local utils = require("libs.utils")
local json = require("libs.json")
local similarity_module = require("src.similarity-calculator")
local SimilarityCalculator = similarity_module.SimilarityCalculator

local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

local ValidationEngine = {}
ValidationEngine.__index = ValidationEngine

-- {{{ function ValidationEngine:new
function ValidationEngine:new(config)
    config = config or {}
    local obj = {
        config = config,
        calculator = nil,  -- Will be set from modular calculator
        tolerance = config.tolerance or 0.001,
        sample_size = config.sample_size or nil,  -- nil = validate all
        progress_callback = config.progress_callback or nil,
        validation_results = {
            total_comparisons = 0,
            accurate_scores = 0,
            inaccurate_scores = 0,
            missing_embeddings = 0,
            errors = {},
            discrepancies = {},
            start_time = nil,
            end_time = nil
        }
    }
    
    setmetatable(obj, ValidationEngine)
    return obj
end
-- }}}

-- {{{ function ValidationEngine:set_calculator
function ValidationEngine:set_calculator(calculator)
    self.calculator = calculator
end
-- }}}

-- {{{ function ValidationEngine:validate_similarity_matrix
function ValidationEngine:validate_similarity_matrix(similarity_file, embeddings_file)
    if not self.calculator then
        error("Similarity calculator must be set before validation")
    end
    
    self.validation_results.start_time = os.time()
    print(string.format("Starting validation: %s vs %s", similarity_file, embeddings_file))
    
    -- Load data
    local similarity_data = utils.read_json_file(similarity_file)
    local embeddings_data = utils.read_json_file(embeddings_file)
    
    if not similarity_data or not embeddings_data then
        error("Failed to load validation data files")
    end
    
    -- Create validation sample
    local validation_pairs = self:create_validation_sample(similarity_data, embeddings_data)
    
    print(string.format("Validating %d similarity pairs...", #validation_pairs))
    
    -- Validate each pair
    local progress_interval = math.max(1, math.floor(#validation_pairs / 20))
    
    for i, pair in ipairs(validation_pairs) do
        if i % progress_interval == 0 then
            print(string.format("Progress: %d/%d (%.1f%%)", i, #validation_pairs, (i/#validation_pairs)*100))
            if self.progress_callback then
                self.progress_callback(i, #validation_pairs)
            end
        end
        
        self:validate_similarity_pair(pair, embeddings_data)
    end
    
    self.validation_results.end_time = os.time()
    
    return self:generate_validation_report()
end
-- }}}

-- {{{ function ValidationEngine:validate_similarity_pair
function ValidationEngine:validate_similarity_pair(pair, embeddings_data)
    local poem_a_id, poem_b_id, stored_score = pair.poem_a, pair.poem_b, pair.stored_score
    
    self.validation_results.total_comparisons = self.validation_results.total_comparisons + 1
    
    -- Get embeddings
    local embedding_a = embeddings_data[tostring(poem_a_id)]
    local embedding_b = embeddings_data[tostring(poem_b_id)]
    
    if not embedding_a or not embedding_b then
        self.validation_results.missing_embeddings = self.validation_results.missing_embeddings + 1
        table.insert(self.validation_results.errors, {
            type = "missing_embedding",
            poem_a = poem_a_id,
            poem_b = poem_b_id,
            missing = not embedding_a and "poem_a" or "poem_b"
        })
        return
    end
    
    -- Calculate actual similarity
    local success, calculated_score = pcall(function()
        return self.calculator:calculate(embedding_a, embedding_b)
    end)
    
    if not success then
        table.insert(self.validation_results.errors, {
            type = "calculation_error",
            poem_a = poem_a_id,
            poem_b = poem_b_id,
            error = calculated_score  -- This will contain the error message
        })
        return
    end
    
    -- Compare scores
    local difference = math.abs(calculated_score - stored_score)
    
    if difference <= self.tolerance then
        self.validation_results.accurate_scores = self.validation_results.accurate_scores + 1
    else
        self.validation_results.inaccurate_scores = self.validation_results.inaccurate_scores + 1
        table.insert(self.validation_results.discrepancies, {
            poem_a = poem_a_id,
            poem_b = poem_b_id,
            stored_score = stored_score,
            calculated_score = calculated_score,
            difference = difference,
            relative_error = math.abs(stored_score) > 0 and (difference / math.abs(stored_score)) or 0
        })
    end
end
-- }}}

-- {{{ function ValidationEngine:create_validation_sample
function ValidationEngine:create_validation_sample(similarity_data, embeddings_data)
    local all_pairs = {}
    
    -- Extract all similarity pairs from data
    for poem_a_id, similarities in pairs(similarity_data) do
        if type(similarities) == "table" then
            for poem_b_id, score in pairs(similarities) do
                table.insert(all_pairs, {
                    poem_a = tonumber(poem_a_id),
                    poem_b = tonumber(poem_b_id), 
                    stored_score = tonumber(score)
                })
            end
        end
    end
    
    print(string.format("Found %d total similarity pairs", #all_pairs))
    
    -- Apply sampling if requested
    if self.sample_size and self.sample_size < #all_pairs then
        print(string.format("Sampling %d pairs for validation", self.sample_size))
        
        -- Random sampling
        local sampled_pairs = {}
        local used_indices = {}
        
        math.randomseed(os.time())
        
        while #sampled_pairs < self.sample_size do
            local random_index = math.random(1, #all_pairs)
            if not used_indices[random_index] then
                table.insert(sampled_pairs, all_pairs[random_index])
                used_indices[random_index] = true
            end
        end
        
        return sampled_pairs
    else
        return all_pairs
    end
end
-- }}}

-- {{{ function ValidationEngine:generate_validation_report
function ValidationEngine:generate_validation_report()
    local results = self.validation_results
    local duration = results.end_time - results.start_time
    
    -- Calculate statistics
    local accuracy_rate = results.total_comparisons > 0 and 
                         (results.accurate_scores / results.total_comparisons) or 0
    
    local error_rate = results.total_comparisons > 0 and
                      (results.inaccurate_scores / results.total_comparisons) or 0
    
    local report = {
        algorithm = self.calculator and self.calculator.algorithm or "unknown",
        timestamp = os.date("%Y-%m-%d %H:%M:%S", results.start_time),
        duration_seconds = duration,
        statistics = {
            total_comparisons = results.total_comparisons,
            accurate_scores = results.accurate_scores,
            inaccurate_scores = results.inaccurate_scores,
            missing_embeddings = results.missing_embeddings,
            accuracy_rate = accuracy_rate,
            error_rate = error_rate,
            tolerance = self.tolerance
        },
        performance = {
            comparisons_per_second = duration > 0 and (results.total_comparisons / duration) or 0,
            avg_comparison_time_ms = duration > 0 and (duration * 1000 / results.total_comparisons) or 0
        },
        discrepancies = {
            count = #results.discrepancies,
            samples = self:get_worst_discrepancies(10),
            max_difference = self:get_max_discrepancy(),
            avg_difference = self:get_average_discrepancy()
        },
        errors = {
            count = #results.errors,
            by_type = self:group_errors_by_type(),
            samples = results.errors
        },
        recommendations = self:generate_recommendations()
    }
    
    return report
end
-- }}}

-- {{{ function ValidationEngine:get_worst_discrepancies
function ValidationEngine:get_worst_discrepancies(limit)
    local sorted_discrepancies = {}
    for _, disc in ipairs(self.validation_results.discrepancies) do
        table.insert(sorted_discrepancies, disc)
    end
    
    -- Sort by difference (highest first)
    table.sort(sorted_discrepancies, function(a, b)
        return a.difference > b.difference
    end)
    
    local result = {}
    for i = 1, math.min(limit, #sorted_discrepancies) do
        table.insert(result, sorted_discrepancies[i])
    end
    
    return result
end
-- }}}

-- {{{ function ValidationEngine:get_max_discrepancy
function ValidationEngine:get_max_discrepancy()
    local max_diff = 0
    for _, disc in ipairs(self.validation_results.discrepancies) do
        if disc.difference > max_diff then
            max_diff = disc.difference
        end
    end
    return max_diff > 0 and max_diff or nil
end
-- }}}

-- {{{ function ValidationEngine:get_average_discrepancy
function ValidationEngine:get_average_discrepancy()
    if #self.validation_results.discrepancies == 0 then
        return nil
    end
    
    local total_diff = 0
    for _, disc in ipairs(self.validation_results.discrepancies) do
        total_diff = total_diff + disc.difference
    end
    
    return total_diff / #self.validation_results.discrepancies
end
-- }}}

-- {{{ function ValidationEngine:group_errors_by_type
function ValidationEngine:group_errors_by_type()
    local grouped = {}
    for _, error in ipairs(self.validation_results.errors) do
        if not grouped[error.type] then
            grouped[error.type] = 0
        end
        grouped[error.type] = grouped[error.type] + 1
    end
    return grouped
end
-- }}}

-- {{{ function ValidationEngine:generate_recommendations
function ValidationEngine:generate_recommendations()
    local results = self.validation_results
    local recommendations = {}
    
    local accuracy_rate = results.total_comparisons > 0 and 
                         (results.accurate_scores / results.total_comparisons) or 0
    
    if accuracy_rate < 0.95 then
        table.insert(recommendations, "Low accuracy rate detected. Consider investigating calculation differences or updating stored similarity data.")
    end
    
    if results.missing_embeddings > 0 then
        table.insert(recommendations, string.format("%d missing embeddings found. Update embedding data or clean similarity matrix.", results.missing_embeddings))
    end
    
    if #results.errors > 0 then
        table.insert(recommendations, string.format("%d calculation errors occurred. Check embedding data quality and calculator implementation.", #results.errors))
    end
    
    local max_diff = self:get_max_discrepancy()
    if max_diff and max_diff > 0.1 then
        table.insert(recommendations, string.format("Maximum discrepancy of %.4f detected. Consider tightening tolerance or investigating calculation method.", max_diff))
    end
    
    if accuracy_rate > 0.99 then
        table.insert(recommendations, "Excellent accuracy rate. Stored similarity data appears reliable.")
    end
    
    return recommendations
end
-- }}}

-- {{{ function run_comprehensive_validation
local function run_comprehensive_validation(similarity_files, embeddings_files, algorithms, output_dir)
    local comprehensive_results = {
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        algorithms_tested = {},
        overall_statistics = {
            total_files = #similarity_files,
            total_algorithms = #algorithms,
            successful_validations = 0,
            failed_validations = 0
        },
        file_results = {}
    }
    
    for _, algorithm in ipairs(algorithms) do
        print(string.format("Testing algorithm: %s", algorithm))
        
        local calculator = SimilarityCalculator:new(algorithm, {cache_enabled = true})
        local engine = ValidationEngine:new({
            tolerance = 0.001,
            sample_size = 1000  -- Sample for large datasets
        })
        engine:set_calculator(calculator)
        
        local algorithm_results = {
            algorithm = algorithm,
            files_validated = 0,
            total_accuracy = 0,
            validations = {}
        }
        
        for i, similarity_file in ipairs(similarity_files) do
            local embeddings_file = embeddings_files[i]
            
            print(string.format("Validating file %d/%d with %s", i, #similarity_files, algorithm))
            
            local success, validation_result = pcall(function()
                return engine:validate_similarity_matrix(similarity_file, embeddings_file)
            end)
            
            if success then
                table.insert(algorithm_results.validations, validation_result)
                algorithm_results.files_validated = algorithm_results.files_validated + 1
                algorithm_results.total_accuracy = algorithm_results.total_accuracy + validation_result.statistics.accuracy_rate
                comprehensive_results.overall_statistics.successful_validations = comprehensive_results.overall_statistics.successful_validations + 1
            else
                print(string.format("Validation failed: %s", validation_result))
                comprehensive_results.overall_statistics.failed_validations = comprehensive_results.overall_statistics.failed_validations + 1
            end
        end
        
        -- Calculate average accuracy for algorithm
        algorithm_results.average_accuracy = algorithm_results.files_validated > 0 and 
                                           (algorithm_results.total_accuracy / algorithm_results.files_validated) or 0
        
        table.insert(comprehensive_results.algorithms_tested, algorithm_results)
    end
    
    -- Generate comprehensive report
    local report_file = output_dir .. "/validation_comprehensive_report.json"
    utils.write_json_file(report_file, comprehensive_results)
    
    print(string.format("Comprehensive validation complete. Report saved: %s", report_file))
    
    return comprehensive_results
end
-- }}}

-- {{{ function create_validation_engine
local function create_validation_engine(config)
    return ValidationEngine:new(config)
end
-- }}}

-- {{{ function validate_single_file
local function validate_single_file(similarity_file, embeddings_file, algorithm, config)
    local calculator = SimilarityCalculator:new(algorithm or "cosine", {})
    local engine = ValidationEngine:new(config or {})
    engine:set_calculator(calculator)
    
    return engine:validate_similarity_matrix(similarity_file, embeddings_file)
end
-- }}}

return {
    ValidationEngine = ValidationEngine,
    run_comprehensive_validation = run_comprehensive_validation,
    create_validation_engine = create_validation_engine,
    validate_single_file = validate_single_file
}