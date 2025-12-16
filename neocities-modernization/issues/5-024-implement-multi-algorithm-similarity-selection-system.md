# Issue 024: Implement Multi-Algorithm Similarity Selection System

## Current Behavior
- Only cosine similarity algorithm available for poem comparisons
- No algorithm selection mechanism in similarity engine
- Limited to single approach for semantic similarity analysis
- Missing implementation of research-validated algorithms from Issue 5-011a

## Intended Behavior  
- Multiple similarity algorithms available for selection and comparison
- Configuration-driven algorithm selection system
- Comprehensive implementation of research-prioritized algorithms
- Performance comparison framework for algorithm evaluation
- Seamless integration with existing similarity matrix infrastructure

## Suggested Implementation Steps

### Phase 1: Core Infrastructure (Tier 1 Algorithms)
1. **Algorithm Selection Framework**: Create modular system for algorithm switching
2. **Jensen-Shannon Divergence**: Implement top-recommended algorithm
3. **Enhanced Euclidean Distance**: Add magnitude-sensitive option
4. **Configuration System**: Enable runtime algorithm selection
5. **Performance Monitoring**: Track computation time and resource usage

### Phase 2: Extended Implementation (Tier 2 Algorithms)
6. **Manhattan Distance**: Robust outlier-resistant similarity
7. **Pearson Correlation**: Pattern-based similarity detection
8. **Algorithm Comparison**: Side-by-side performance analysis
9. **Quality Validation**: Comparative accuracy assessment

### Phase 3: Advanced Research (Tier 3 Algorithms)
10. **Kullback-Leibler Divergence**: Information-theoretic approach
11. **Spearman Correlation**: Rank-based similarity analysis
12. **Soft Cosine Similarity**: Enhanced semantic awareness (premium option)
13. **Research Framework**: Experimental algorithm testing infrastructure

### Phase 4: Experimental Features (Tier 4 Algorithms)
14. **Chebyshev Distance**: Extreme difference detection
15. **Word Mover's Distance**: High-precision subset analysis
16. **Algorithm Benchmarking**: Comprehensive performance comparison
17. **Quality Assessment**: Human-validated accuracy evaluation

## Technical Architecture

### Algorithm Interface Design
```lua
-- {{{ similarity_algorithms module
local similarity_algorithms = {}

-- Core algorithm interface
function similarity_algorithms.calculate(algorithm_name, vector_a, vector_b, config)
    local algorithms = {
        ["cosine"] = calculate_cosine_similarity,
        ["jensen_shannon"] = calculate_jensen_shannon_divergence,
        ["euclidean"] = calculate_euclidean_distance,
        ["manhattan"] = calculate_manhattan_distance,
        ["pearson"] = calculate_pearson_correlation,
        ["spearman"] = calculate_spearman_correlation,
        ["kl_divergence"] = calculate_kl_divergence,
        ["soft_cosine"] = calculate_soft_cosine_similarity,
        ["chebyshev"] = calculate_chebyshev_distance,
        ["word_mover"] = calculate_word_mover_distance
    }
    
    local algorithm_func = algorithms[algorithm_name]
    if not algorithm_func then
        utils.log_error("Unknown algorithm: " .. algorithm_name)
        return nil
    end
    
    return algorithm_func(vector_a, vector_b, config)
end

-- Algorithm metadata
function similarity_algorithms.get_algorithm_info(algorithm_name)
    local algorithm_metadata = {
        ["cosine"] = {
            name = "Cosine Similarity",
            description = "Angle-based similarity, scale invariant",
            complexity = "O(n)",
            range = "[0, 1]",
            preprocessing = "L2 normalization",
            suitability = "Excellent baseline for all content"
        },
        ["jensen_shannon"] = {
            name = "Jensen-Shannon Divergence", 
            description = "Symmetric information-theoretic similarity",
            complexity = "O(n)",
            range = "[0, 1]",
            preprocessing = "Probability normalization",
            suitability = "Superior semantic distribution analysis"
        },
        -- ... additional algorithm metadata
    }
    
    return algorithm_metadata[algorithm_name]
end
-- }}}
```

### Configuration System
```json
{
  "similarity_algorithms": {
    "default_algorithm": "jensen_shannon",
    "available_algorithms": [
      "cosine",
      "jensen_shannon", 
      "euclidean",
      "manhattan",
      "pearson"
    ],
    "algorithm_configs": {
      "jensen_shannon": {
        "normalization_method": "softmax",
        "epsilon": 1e-10
      },
      "euclidean": {
        "standardization": true,
        "invert_distance": true
      },
      "soft_cosine": {
        "similarity_matrix_path": "assets/term_similarity_matrix.json",
        "cache_matrix": true
      }
    },
    "performance_monitoring": {
      "enabled": true,
      "benchmark_size": 1000,
      "report_interval": 100
    }
  }
}
```

### Algorithm Implementation Framework

#### Tier 1: Essential Algorithms (High Priority)

##### Jensen-Shannon Divergence (Top Recommendation)
```lua
-- {{{ function calculate_jensen_shannon_divergence
function calculate_jensen_shannon_divergence(vector_a, vector_b, config)
    local epsilon = config.epsilon or 1e-10
    local normalization = config.normalization_method or "softmax"
    
    -- Normalize vectors to probability distributions
    local prob_a = normalize_to_probability(vector_a, normalization, epsilon)
    local prob_b = normalize_to_probability(vector_b, normalization, epsilon)
    
    -- Calculate midpoint distribution
    local midpoint = {}
    for i = 1, #prob_a do
        midpoint[i] = 0.5 * (prob_a[i] + prob_b[i])
    end
    
    -- Calculate JS divergence
    local kl_a_mid = calculate_kl_divergence_internal(prob_a, midpoint)
    local kl_b_mid = calculate_kl_divergence_internal(prob_b, midpoint) 
    local js_divergence = 0.5 * (kl_a_mid + kl_b_mid)
    
    -- Convert divergence to similarity score
    local js_similarity = 1.0 - math.sqrt(js_divergence)
    
    return js_similarity
end
-- }}}
```

##### Enhanced Euclidean Distance
```lua
-- {{{ function calculate_euclidean_distance
function calculate_euclidean_distance(vector_a, vector_b, config)
    local standardize = config.standardization or false
    local invert = config.invert_distance or true
    
    local processed_a = standardize and standardize_vector(vector_a) or vector_a
    local processed_b = standardize and standardize_vector(vector_b) or vector_b
    
    local sum_squared_diff = 0
    for i = 1, #processed_a do
        local diff = processed_a[i] - processed_b[i]
        sum_squared_diff = sum_squared_diff + (diff * diff)
    end
    
    local distance = math.sqrt(sum_squared_diff)
    
    if invert then
        -- Convert distance to similarity score
        return 1.0 / (1.0 + distance)
    else
        return distance
    end
end
-- }}}
```

#### Tier 2: Extended Algorithms (Medium Priority)

##### Manhattan Distance (L1 Norm)
```lua
-- {{{ function calculate_manhattan_distance  
function calculate_manhattan_distance(vector_a, vector_b, config)
    local standardize = config.standardization or false
    local invert = config.invert_distance or true
    
    local processed_a = standardize and standardize_vector(vector_a) or vector_a
    local processed_b = standardize and standardize_vector(vector_b) or vector_b
    
    local sum_abs_diff = 0
    for i = 1, #processed_a do
        sum_abs_diff = sum_abs_diff + math.abs(processed_a[i] - processed_b[i])
    end
    
    if invert then
        return 1.0 / (1.0 + sum_abs_diff)
    else
        return sum_abs_diff
    end
end
-- }}}
```

##### Pearson Correlation Coefficient
```lua
-- {{{ function calculate_pearson_correlation
function calculate_pearson_correlation(vector_a, vector_b, config)
    local n = #vector_a
    
    -- Calculate means
    local mean_a = calculate_mean(vector_a)
    local mean_b = calculate_mean(vector_b)
    
    -- Calculate correlation components
    local numerator = 0
    local sum_sq_a = 0
    local sum_sq_b = 0
    
    for i = 1, n do
        local diff_a = vector_a[i] - mean_a
        local diff_b = vector_b[i] - mean_b
        
        numerator = numerator + (diff_a * diff_b)
        sum_sq_a = sum_sq_a + (diff_a * diff_a)
        sum_sq_b = sum_sq_b + (diff_b * diff_b)
    end
    
    local denominator = math.sqrt(sum_sq_a * sum_sq_b)
    if denominator == 0 then
        return 0  -- No correlation possible
    end
    
    local correlation = numerator / denominator
    
    -- Convert to [0, 1] similarity range
    return (correlation + 1.0) / 2.0
end
-- }}}
```

### Performance Monitoring System
```lua
-- {{{ performance_monitoring module
local performance_monitoring = {}

function performance_monitoring.benchmark_algorithm(algorithm_name, sample_size)
    local embeddings = load_sample_embeddings(sample_size)
    local start_time = os.clock()
    local memory_before = collectgarbage("count")
    
    local total_comparisons = 0
    for i = 1, #embeddings do
        for j = i + 1, #embeddings do
            similarity_algorithms.calculate(algorithm_name, embeddings[i], embeddings[j])
            total_comparisons = total_comparisons + 1
        end
    end
    
    local end_time = os.clock()
    local memory_after = collectgarbage("count")
    
    local results = {
        algorithm = algorithm_name,
        sample_size = sample_size,
        total_comparisons = total_comparisons,
        execution_time = end_time - start_time,
        memory_usage = memory_after - memory_before,
        comparisons_per_second = total_comparisons / (end_time - start_time),
        memory_per_comparison = (memory_after - memory_before) / total_comparisons
    }
    
    return results
end

function performance_monitoring.generate_benchmark_report(results_list)
    local report = {
        benchmark_timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        algorithms_tested = {},
        performance_ranking = {},
        memory_efficiency_ranking = {},
        recommendations = {}
    }
    
    -- Sort by performance metrics and generate rankings
    table.sort(results_list, function(a, b) 
        return a.comparisons_per_second > b.comparisons_per_second 
    end)
    
    for i, result in ipairs(results_list) do
        table.insert(report.performance_ranking, {
            rank = i,
            algorithm = result.algorithm,
            comparisons_per_second = result.comparisons_per_second,
            execution_time = result.execution_time
        })
    end
    
    return report
end
-- }}}
```

### Integration Points

#### Similarity Engine Integration
```lua
-- Modify existing similarity engine to use new algorithm framework
function similarity_engine.generate_similarity_matrix(model_name, algorithm_name)
    local algorithm_config = config.similarity_algorithms.algorithm_configs[algorithm_name]
    local embeddings = load_embeddings(model_name)
    
    utils.log_info(string.format("Generating similarity matrix using %s algorithm", algorithm_name))
    
    local matrix = {}
    local total_comparisons = (#embeddings * (#embeddings - 1)) / 2
    local completed = 0
    
    for i = 1, #embeddings do
        matrix[i] = {}
        for j = 1, #embeddings do
            if i == j then
                matrix[i][j] = 1.0  -- Self-similarity
            elseif i < j then
                local similarity = similarity_algorithms.calculate(
                    algorithm_name, 
                    embeddings[i], 
                    embeddings[j], 
                    algorithm_config
                )
                matrix[i][j] = similarity
                matrix[j][i] = similarity  -- Symmetric matrix
                
                completed = completed + 1
                if completed % 1000 == 0 then
                    utils.log_info(string.format("Progress: %d/%d (%.1f%%)", 
                        completed, total_comparisons, (completed / total_comparisons) * 100))
                end
            end
        end
    end
    
    return matrix
end
```

#### HTML Generation Integration
```lua
-- Enable algorithm selection in HTML generation
function html_generator.generate_similarity_pages(algorithm_name)
    local algorithm_info = similarity_algorithms.get_algorithm_info(algorithm_name)
    local similarity_matrix = load_similarity_matrix(algorithm_name)
    
    -- Generate HTML with algorithm-specific metadata
    local template_data = {
        algorithm_name = algorithm_info.name,
        algorithm_description = algorithm_info.description,
        similarity_data = similarity_matrix,
        generation_timestamp = os.date("%Y-%m-%d %H:%M:%S")
    }
    
    return generate_html_from_template("similarity_page.html", template_data)
end
```

## Quality Assurance Framework

### Algorithm Validation Tests
```lua
-- {{{ algorithm_validation module
local algorithm_validation = {}

function algorithm_validation.test_algorithm_properties(algorithm_name)
    local test_results = {
        algorithm = algorithm_name,
        symmetry_test = false,
        self_similarity_test = false,
        triangle_inequality_test = false,
        range_test = false,
        stability_test = false
    }
    
    -- Generate test vectors
    local test_vectors = generate_test_embedding_vectors(10)
    
    -- Test symmetry: d(a,b) = d(b,a)
    test_results.symmetry_test = test_symmetry(algorithm_name, test_vectors)
    
    -- Test self-similarity: d(a,a) = 1.0 (for similarity) or 0.0 (for distance)
    test_results.self_similarity_test = test_self_similarity(algorithm_name, test_vectors)
    
    -- Test numerical stability
    test_results.stability_test = test_numerical_stability(algorithm_name, test_vectors)
    
    -- Test output range
    test_results.range_test = test_output_range(algorithm_name, test_vectors)
    
    return test_results
end

function algorithm_validation.poetry_quality_assessment(algorithm_name, sample_size)
    local assessment = {
        algorithm = algorithm_name,
        sample_size = sample_size,
        thematic_clustering = 0.0,
        cross_category_discovery = 0.0,
        stylistic_sensitivity = 0.0,
        diversity_detection = 0.0,
        overall_quality_score = 0.0
    }
    
    -- Load curated test set with known similarity relationships
    local test_poems = load_poetry_test_set(sample_size)
    
    -- Evaluate thematic clustering accuracy
    assessment.thematic_clustering = evaluate_thematic_clustering(algorithm_name, test_poems)
    
    -- Evaluate cross-category discovery capability  
    assessment.cross_category_discovery = evaluate_cross_category_discovery(algorithm_name, test_poems)
    
    -- Evaluate stylistic sensitivity
    assessment.stylistic_sensitivity = evaluate_stylistic_sensitivity(algorithm_name, test_poems)
    
    -- Evaluate diversity detection
    assessment.diversity_detection = evaluate_diversity_detection(algorithm_name, test_poems)
    
    -- Calculate overall quality score
    assessment.overall_quality_score = (
        assessment.thematic_clustering * 0.4 +
        assessment.cross_category_discovery * 0.3 +
        assessment.stylistic_sensitivity * 0.2 +
        assessment.diversity_detection * 0.1
    )
    
    return assessment
end
-- }}}
```

## Success Metrics

### Implementation Completeness
- **Tier 1**: 4 core algorithms implemented with full configuration support
- **Tier 2**: 2-3 additional algorithms with comparative analysis framework  
- **Tier 3**: Advanced research algorithms with experimental validation
- **Configuration**: Complete algorithm selection and tuning system

### Performance Benchmarks
- **Computation Time**: All Tier 1 algorithms complete 7,355-poem matrix in <2 hours
- **Memory Efficiency**: Peak memory usage <1GB for standard algorithms
- **Quality Metrics**: 10-20% improvement in poetry similarity detection over cosine-only baseline
- **Scalability**: Linear scaling performance for datasets up to 50,000 poems

### Quality Validation
- **Algorithmic Properties**: All algorithms pass symmetry, stability, and range tests
- **Poetry-Specific Accuracy**: >80% accuracy in curated similarity assessment
- **Cross-Category Performance**: Effective discovery across fediverse/messages/notes categories
- **User Experience**: Intuitive algorithm selection with clear performance trade-offs

## Dependencies

### Required Infrastructure
- **Issue 5-011a**: Similarity algorithms research (completed) ✅
- **Phase 2**: Embedding generation and similarity matrix infrastructure ✅
- **Phase 3**: HTML generation system for algorithm comparison pages ✅
- **Existing**: Current cosine similarity implementation as baseline ✅

### Optional Enhancements  
- **Issue 5-016**: Full similarity matrix storage (for performance comparison) ✅
- **Issue 5-010b**: Validation framework (for quality assessment) ✅
- **Phase 6**: Enhanced visualization for algorithm comparison results

## Testing Strategy

### Development Testing
1. **Unit Testing**: Individual algorithm mathematical correctness
2. **Integration Testing**: Algorithm framework with existing similarity engine
3. **Performance Testing**: Computational efficiency and memory usage analysis
4. **Quality Testing**: Poetry-specific accuracy assessment

### Production Validation
1. **A/B Testing**: Algorithm comparison with existing cosine similarity baseline
2. **User Feedback**: Qualitative assessment of recommendation improvements
3. **Statistical Analysis**: Quantitative similarity accuracy measurements
4. **Long-term Monitoring**: Performance and quality tracking over time

## Implementation Phases

### Phase 1: Foundation (2-3 weeks)
- Algorithm selection framework
- Jensen-Shannon Divergence implementation
- Basic configuration system
- Performance monitoring infrastructure

### Phase 2: Core Expansion (2-3 weeks)  
- Euclidean and Manhattan distance algorithms
- Pearson correlation implementation
- Algorithm comparison framework
- Quality validation system

### Phase 3: Advanced Features (3-4 weeks)
- Experimental algorithms (KL divergence, Spearman correlation)
- Soft Cosine Similarity (premium feature)
- Comprehensive benchmarking system
- Documentation and user guides

### Phase 4: Research and Optimization (2-3 weeks)
- Performance optimization for large datasets
- Advanced algorithms (WMD, BERT Score) for research
- Algorithm ensemble methods
- Future research framework

## Risk Mitigation

### Technical Risks
- **Algorithm Complexity**: Start with simple algorithms, gradually add sophisticated ones
- **Performance Issues**: Implement performance monitoring from day one
- **Numerical Stability**: Comprehensive testing with edge cases and validation
- **Integration Complexity**: Modular design ensures compatibility with existing systems

### Project Risks
- **Scope Creep**: Strict tier-based implementation prevents feature bloat
- **Performance Regression**: Maintain cosine similarity as fallback option
- **Quality Degradation**: Extensive validation framework ensures quality maintenance
- **User Adoption**: Gradual rollout with clear algorithm selection guidance

## Metadata

- **Priority**: Low (non-blocking enhancement)
- **Estimated Time**: 8-12 weeks for complete implementation (all tiers)
- **Dependencies**: All required dependencies already satisfied
- **Category**: Enhancement - Similarity Algorithm Research
- **Blocking**: None - this is an enhancement that doesn't block other development
- **Phase**: 5 (Advanced Discovery & Optimization)

## Related Issues
- **Issue 5-011a**: Similarity algorithms research (completed) ✅
- **Issue 5-016**: Full similarity matrix storage (performance optimization)
- **Issue 5-010**: Validation framework (quality assurance)
- **Issue 8-002**: Multi-threaded HTML generation (cache dependency)
- **Future**: Algorithm-specific visualization and user interface enhancements

## Cache Invalidation Note

**IMPORTANT**: When implementing new similarity algorithms, the following cached assets must be regenerated:

1. **`diversity_cache.json`** - Pre-computed diversity sequences for "different" pages
   - Location: `assets/embeddings/EmbeddingGemma_latest/diversity_cache.json`
   - Regenerate with: `scripts/precompute-diversity-sequences`
   - ~42 hour computation time

2. **`similarity_matrix.json`** - Pre-computed similarity scores for "similar" pages
   - Location: `assets/embeddings/EmbeddingGemma_latest/similarity_matrix.json`
   - Must be regenerated with new algorithm

The diversity sequences are computed using cosine distance from embeddings. If the distance metric changes, the orderings will differ and cached sequences become invalid.

**ISSUE STATUS: READY FOR IMPLEMENTATION** 🔬📊

**Priority**: Low - Enhancement feature that provides valuable research capabilities and improved similarity detection without blocking other development work. Can be implemented incrementally across multiple development cycles.