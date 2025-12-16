# Issue 010a: Create Modular Similarity Calculator

## Current Behavior
- Hardcoded cosine similarity calculation in embedding system
- No support for experimenting with different similarity algorithms
- Limited flexibility for testing alternative similarity measures
- No pluggable architecture for similarity calculations

## Intended Behavior
- Modular similarity calculator supporting multiple algorithms
- Easy switching between similarity calculation methods
- Extensible framework for adding new algorithms
- Configuration-driven similarity method selection

## Suggested Implementation Steps
1. **Base Calculator Class**: Create pluggable similarity calculator architecture
2. **Core Algorithms**: Implement fundamental similarity measures (cosine, euclidean, etc.)
3. **Configuration System**: Allow runtime selection of similarity algorithms
4. **Validation Framework**: Ensure algorithm implementations are mathematically correct
5. **Performance Optimization**: Efficient implementations for high-dimensional vectors

## Technical Requirements

### **SimilarityCalculator Class Architecture**
```lua
-- {{{ SimilarityCalculator class
local SimilarityCalculator = {}
SimilarityCalculator.__index = SimilarityCalculator

function SimilarityCalculator:new(algorithm_name, config)
    local obj = {
        algorithm = algorithm_name or "cosine",
        config = config or {},
        supported_algorithms = {
            "cosine",
            "euclidean", 
            "manhattan",
            "dot_product",
            "normalized_euclidean",
            "chebyshev",
            "minkowski"
        },
        cache_enabled = config.cache_enabled or false,
        cache = {}
    }
    
    setmetatable(obj, SimilarityCalculator)
    
    -- Validate algorithm
    if not obj:is_supported(algorithm_name) then
        error(string.format("Unsupported similarity algorithm: %s", algorithm_name))
    end
    
    return obj
end

function SimilarityCalculator:is_supported(algorithm)
    for _, supported in ipairs(self.supported_algorithms) do
        if supported == algorithm then return true end
    end
    return false
end
-- }}}
```

### **Core Similarity Algorithms**
```lua
-- {{{ function SimilarityCalculator:calculate
function SimilarityCalculator:calculate(embedding_a, embedding_b)
    -- Input validation
    if not embedding_a or not embedding_b then
        error("Both embeddings must be provided")
    end
    
    if #embedding_a ~= #embedding_b then
        error(string.format("Embedding dimensions must match: %d vs %d", #embedding_a, #embedding_b))
    end
    
    -- Cache lookup (if enabled)
    local cache_key = nil
    if self.cache_enabled then
        cache_key = self:generate_cache_key(embedding_a, embedding_b)
        if self.cache[cache_key] then
            return self.cache[cache_key]
        end
    end
    
    -- Calculate similarity based on algorithm
    local result = nil
    
    if self.algorithm == "cosine" then
        result = self:cosine_similarity(embedding_a, embedding_b)
    elseif self.algorithm == "euclidean" then
        result = self:euclidean_similarity(embedding_a, embedding_b)
    elseif self.algorithm == "manhattan" then
        result = self:manhattan_similarity(embedding_a, embedding_b)
    elseif self.algorithm == "dot_product" then
        result = self:dot_product_similarity(embedding_a, embedding_b)
    elseif self.algorithm == "normalized_euclidean" then
        result = self:normalized_euclidean_similarity(embedding_a, embedding_b)
    elseif self.algorithm == "chebyshev" then
        result = self:chebyshev_similarity(embedding_a, embedding_b)
    elseif self.algorithm == "minkowski" then
        result = self:minkowski_similarity(embedding_a, embedding_b, self.config.p or 2)
    else
        error("Algorithm implementation not found: " .. self.algorithm)
    end
    
    -- Cache result (if enabled)
    if self.cache_enabled and cache_key then
        self.cache[cache_key] = result
    end
    
    return result
end
-- }}}

-- {{{ function SimilarityCalculator:cosine_similarity
function SimilarityCalculator:cosine_similarity(vec_a, vec_b)
    local dot_product = 0
    local magnitude_a = 0
    local magnitude_b = 0
    
    for i = 1, #vec_a do
        dot_product = dot_product + (vec_a[i] * vec_b[i])
        magnitude_a = magnitude_a + (vec_a[i] * vec_a[i])
        magnitude_b = magnitude_b + (vec_b[i] * vec_b[i])
    end
    
    magnitude_a = math.sqrt(magnitude_a)
    magnitude_b = math.sqrt(magnitude_b)
    
    if magnitude_a == 0 or magnitude_b == 0 then
        return 0  -- Handle zero vectors
    end
    
    return dot_product / (magnitude_a * magnitude_b)
end
-- }}}

-- {{{ function SimilarityCalculator:euclidean_similarity
function SimilarityCalculator:euclidean_similarity(vec_a, vec_b)
    local sum_squared_diff = 0
    
    for i = 1, #vec_a do
        local diff = vec_a[i] - vec_b[i]
        sum_squared_diff = sum_squared_diff + (diff * diff)
    end
    
    local euclidean_distance = math.sqrt(sum_squared_diff)
    
    -- Convert distance to similarity (closer = more similar)
    -- Using 1 / (1 + distance) transformation
    return 1 / (1 + euclidean_distance)
end
-- }}}

-- {{{ function SimilarityCalculator:manhattan_similarity
function SimilarityCalculator:manhattan_similarity(vec_a, vec_b)
    local sum_abs_diff = 0
    
    for i = 1, #vec_a do
        sum_abs_diff = sum_abs_diff + math.abs(vec_a[i] - vec_b[i])
    end
    
    -- Convert Manhattan distance to similarity
    return 1 / (1 + sum_abs_diff)
end
-- }}}

-- {{{ function SimilarityCalculator:minkowski_similarity
function SimilarityCalculator:minkowski_similarity(vec_a, vec_b, p)
    p = p or 2  -- Default to Euclidean (p=2)
    
    if p == math.huge then
        -- Chebyshev distance (L∞)
        return self:chebyshev_similarity(vec_a, vec_b)
    end
    
    local sum_powered_diff = 0
    
    for i = 1, #vec_a do
        local diff = math.abs(vec_a[i] - vec_b[i])
        sum_powered_diff = sum_powered_diff + math.pow(diff, p)
    end
    
    local minkowski_distance = math.pow(sum_powered_diff, 1/p)
    
    -- Convert distance to similarity
    return 1 / (1 + minkowski_distance)
end
-- }}}
```

### **Configuration and Factory System**
```lua
-- {{{ SimilarityConfig class
local SimilarityConfig = {
    algorithms = {
        cosine = {
            name = "Cosine Similarity",
            description = "Measures angle between vectors, good for high-dimensional text embeddings",
            suitable_for = {"text", "embeddings", "sparse_vectors"}
        },
        euclidean = {
            name = "Euclidean Distance", 
            description = "Measures straight-line distance between vectors",
            suitable_for = {"dense_vectors", "continuous_features"}
        },
        manhattan = {
            name = "Manhattan Distance",
            description = "Sum of absolute differences, robust to outliers",
            suitable_for = {"discrete_features", "outlier_resistant"}
        }
    }
}

function SimilarityConfig:get_algorithm_info(algorithm)
    return self.algorithms[algorithm]
end

function SimilarityConfig:list_algorithms()
    local list = {}
    for name, info in pairs(self.algorithms) do
        table.insert(list, {name = name, info = info})
    end
    return list
end
-- }}}

-- {{{ SimilarityFactory class
local SimilarityFactory = {}

function SimilarityFactory:create_calculator(algorithm, config)
    local calculator = SimilarityCalculator:new(algorithm, config)
    
    -- Add algorithm-specific optimizations
    if algorithm == "cosine" and config.normalize_inputs then
        calculator.preprocess = function(self, vector)
            return self:normalize_vector(vector)
        end
    end
    
    return calculator
end

function SimilarityFactory:create_batch_calculator(algorithm, config)
    -- Create calculator optimized for batch operations
    local calculator = self:create_calculator(algorithm, config)
    calculator.batch_mode = true
    calculator.cache_enabled = true
    
    return calculator
end
-- }}}
```

### **Validation and Testing Framework**
```lua
-- {{{ function validate_similarity_algorithm
function validate_similarity_algorithm(calculator)
    local tests = {
        {
            name = "Identity Test",
            test_func = function()
                local vec = {1, 2, 3, 4, 5}
                local similarity = calculator:calculate(vec, vec)
                return math.abs(similarity - 1.0) < 0.0001  -- Should be 1.0 for identical vectors
            end
        },
        {
            name = "Symmetry Test", 
            test_func = function()
                local vec_a = {1, 2, 3}
                local vec_b = {4, 5, 6}
                local sim_ab = calculator:calculate(vec_a, vec_b)
                local sim_ba = calculator:calculate(vec_b, vec_a)
                return math.abs(sim_ab - sim_ba) < 0.0001  -- Should be symmetric
            end
        },
        {
            name = "Range Test",
            test_func = function()
                local vec_a = {1, 0, 0}
                local vec_b = {0, 1, 0}
                local similarity = calculator:calculate(vec_a, vec_b)
                return similarity >= -1 and similarity <= 1  -- Should be in valid range
            end
        }
    }
    
    local results = {
        algorithm = calculator.algorithm,
        passed = 0,
        failed = 0,
        tests = {}
    }
    
    for _, test in ipairs(tests) do
        local success, result = pcall(test.test_func)
        local test_result = {
            name = test.name,
            passed = success and result,
            error = not success and result or nil
        }
        
        table.insert(results.tests, test_result)
        
        if test_result.passed then
            results.passed = results.passed + 1
        else
            results.failed = results.failed + 1
        end
    end
    
    return results
end
-- }}}
```

## Quality Assurance Criteria
- All similarity algorithms pass mathematical validation tests
- Modular architecture supports easy algorithm addition
- Performance is acceptable for high-dimensional vectors (768+ dimensions)
- Configuration system allows runtime algorithm selection
- Comprehensive unit test coverage for all algorithms

## Success Metrics
- **Algorithm Coverage**: 7+ similarity algorithms implemented
- **Validation**: 100% of algorithms pass mathematical correctness tests
- **Performance**: Calculate similarity in <1ms for 768-dimensional vectors
- **Modularity**: Add new algorithm in <50 lines of code
- **Configuration**: Runtime algorithm switching without restart

## Dependencies
- Phase 2 embedding infrastructure (for vector data)
- Mathematical validation requirements

## Testing Strategy
1. **Mathematical Validation**: Test algorithm correctness with known inputs
2. **Performance Testing**: Benchmark calculation speed with realistic data
3. **Edge Case Testing**: Handle zero vectors, different dimensions, extreme values
4. **Integration Testing**: Test with real embedding data from Phase 2
5. **Configuration Testing**: Verify algorithm switching and configuration options

**ISSUE STATUS: COMPLETED** ✅⚙️🔢

**Priority**: High - Foundation for similarity validation and algorithm research

## Implementation Completed

**Files Created**:
- `/src/similarity-calculator.lua` - Modular similarity calculator with 8 algorithms
- `/src/test-similarity-calculator.lua` - Comprehensive test suite
- `/config/similarity-calculator-settings.json` - Configuration system

**Algorithms Implemented**:
- Cosine similarity (default, standard for text embeddings)
- Euclidean distance converted to similarity 
- Manhattan distance converted to similarity
- Angular similarity (normalized angle between vectors)
- Pearson correlation coefficient
- Dot product similarity
- Normalized euclidean similarity 
- Chebyshev distance converted to similarity

**Testing Results**: All 8 algorithms pass mathematical validation tests

**Next Steps**: Ready for use in Issues 010b (validation framework) and 011a (algorithm research)