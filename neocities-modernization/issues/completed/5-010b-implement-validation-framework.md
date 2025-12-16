# Issue 010b: Implement Validation Framework

## Current Behavior
- No systematic validation of similarity scores in stored JSON files
- No verification that cached similarity data matches actual calculations
- Missing framework for testing similarity algorithm accuracy
- No automated validation reports or error detection

## Intended Behavior
- Iterative validation system that recalculates and verifies stored similarity scores
- Comprehensive validation reports with accuracy metrics and discrepancies
- Support for validating full datasets or statistical samples
- Automated detection of data corruption or calculation errors

## Suggested Implementation Steps
1. **Validation Engine**: Core system for iterating through similarity data and validating scores
2. **Data Loading**: Efficient loading and processing of similarity matrices and embeddings
3. **Comparison Logic**: Compare stored vs calculated scores with configurable tolerance
4. **Report Generation**: Detailed validation reports with statistics and error analysis
5. **Sampling System**: Support for validating representative samples of large datasets

## Technical Requirements

### **Validation Engine Architecture**
```lua
-- {{{ ValidationEngine class
local ValidationEngine = {}
ValidationEngine.__index = ValidationEngine

function ValidationEngine:new(config)
    local obj = {
        config = config or {},
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

function ValidationEngine:set_calculator(calculator)
    self.calculator = calculator
end

-- {{{ function ValidationEngine:validate_similarity_matrix
function ValidationEngine:validate_similarity_matrix(similarity_file, embeddings_file)
    if not self.calculator then
        error("Similarity calculator must be set before validation")
    end
    
    self.validation_results.start_time = os.time()
    utils.log_info(string.format("Starting validation: %s vs %s", similarity_file, embeddings_file))
    
    -- Load data
    local similarity_data = utils.load_json(similarity_file)
    local embeddings_data = utils.load_json(embeddings_file)
    
    if not similarity_data or not embeddings_data then
        error("Failed to load validation data files")
    end
    
    -- Create validation sample
    local validation_pairs = self:create_validation_sample(similarity_data, embeddings_data)
    
    utils.log_info(string.format("Validating %d similarity pairs...", #validation_pairs))
    
    -- Validate each pair
    local progress_interval = math.max(1, math.floor(#validation_pairs / 20))
    
    for i, pair in ipairs(validation_pairs) do
        if i % progress_interval == 0 and self.progress_callback then
            self.progress_callback(i, #validation_pairs)
        end
        
        self:validate_similarity_pair(pair, embeddings_data)
    end
    
    self.validation_results.end_time = os.time()
    
    return self:generate_validation_report()
end
-- }}}
```

### **Similarity Pair Validation**
```lua
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
            relative_error = difference / math.abs(stored_score)
        })
    end
end
-- }}}

-- {{{ function ValidationEngine:create_validation_sample
function ValidationEngine:create_validation_sample(similarity_data, embeddings_data)
    local all_pairs = {}
    
    -- Extract all similarity pairs from data
    for poem_a_id, similarities in pairs(similarity_data) do
        for poem_b_id, score in pairs(similarities) do
            table.insert(all_pairs, {
                poem_a = tonumber(poem_a_id),
                poem_b = tonumber(poem_b_id), 
                stored_score = tonumber(score)
            })
        end
    end
    
    utils.log_info(string.format("Found %d total similarity pairs", #all_pairs))
    
    -- Apply sampling if requested
    if self.sample_size and self.sample_size < #all_pairs then
        utils.log_info(string.format("Sampling %d pairs for validation", self.sample_size))
        
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
```

### **Report Generation System**
```lua
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
        algorithm = self.calculator.algorithm,
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
```

### **Batch Validation and Reporting**
```lua
-- {{{ function run_comprehensive_validation
function run_comprehensive_validation(similarity_files, embeddings_files, algorithms, output_dir)
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
        utils.log_info(string.format("Testing algorithm: %s", algorithm))
        
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
            
            utils.log_info(string.format("Validating file %d/%d with %s", i, #similarity_files, algorithm))
            
            local success, validation_result = pcall(function()
                return engine:validate_similarity_matrix(similarity_file, embeddings_file)
            end)
            
            if success then
                table.insert(algorithm_results.validations, validation_result)
                algorithm_results.files_validated = algorithm_results.files_validated + 1
                algorithm_results.total_accuracy = algorithm_results.total_accuracy + validation_result.statistics.accuracy_rate
                comprehensive_results.overall_statistics.successful_validations = comprehensive_results.overall_statistics.successful_validations + 1
            else
                utils.log_error(string.format("Validation failed: %s", validation_result))
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
    utils.write_json(report_file, comprehensive_results)
    
    utils.log_info(string.format("Comprehensive validation complete. Report saved: %s", report_file))
    
    return comprehensive_results
end
-- }}}
```

## Quality Assurance Criteria
- Validation engine accurately detects discrepancies in similarity scores
- Support for both full dataset and sampled validation
- Comprehensive error handling and reporting
- Performance suitable for large datasets (6,840+ poems)
- Clear, actionable validation reports

## Success Metrics
- **Accuracy Detection**: Correctly identify >99% of score discrepancies
- **Performance**: Validate 1000+ similarity pairs per minute
- **Sample Validation**: Representative sampling maintains >95% accuracy detection
- **Error Handling**: Graceful handling of missing data and calculation errors
- **Report Quality**: Clear, actionable recommendations in validation reports

## Dependencies
- Issue 010a (modular similarity calculator - required)
- Phase 2 embedding and similarity data files
- JSON data loading utilities

## Testing Strategy
1. **Accuracy Testing**: Validate with known correct/incorrect similarity scores
2. **Performance Testing**: Test with large datasets to verify scalability
3. **Error Handling**: Test with corrupted data, missing embeddings
4. **Sampling Testing**: Verify sample validation represents full dataset
5. **Integration Testing**: Test with multiple similarity algorithms

**ISSUE STATUS: COMPLETED** ✅🔍📊

**Priority**: High - Critical for ensuring similarity data integrity

## Implementation Completed

**Files Created**:
- `/src/validation-engine.lua` - Core validation framework with comprehensive validation capabilities
- `/src/test-validation-engine.lua` - Complete test suite with mock and real data testing
- `/src/run-validation.lua` - Command-line interface for running validation operations

**Features Implemented**:
- ValidationEngine class with configurable tolerance and sampling
- Support for validating stored similarity scores against recalculated values
- Comprehensive error handling for missing embeddings and calculation errors
- Statistical reporting with accuracy rates, discrepancies, and performance metrics
- Multi-algorithm validation support using the modular similarity calculator
- Interactive CLI mode with algorithm selection and file configuration
- Batch validation capabilities for multiple datasets
- Detailed recommendations based on validation results

**Testing Results**: All 5 validation framework tests pass successfully
- Basic functionality validation ✅
- Mock data validation with artificial similarity pairs ✅  
- Real project data validation with sampling ✅
- Multi-algorithm validation across 4 different algorithms ✅
- Error handling with missing calculators and malformed data ✅

**Integration**: Successfully integrates with Issue 010a (modular similarity calculator) as dependency

**Next Steps**: Ready for use in Issues 010c (validation reports) and for ongoing similarity data integrity verification