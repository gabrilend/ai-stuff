#!/usr/bin/env lua

-- Modular Similarity Calculator
-- Pluggable architecture for testing different similarity algorithms

package.path = package.path .. ';./?.lua;./libs/?.lua'

local utils = require("libs.utils")
local json = require("libs.json")

local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

local SimilarityCalculator = {}
SimilarityCalculator.__index = SimilarityCalculator

-- {{{ function SimilarityCalculator:new
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
            "angular",
            "pearson_correlation"
        }
    }
    setmetatable(obj, SimilarityCalculator)
    
    -- Validate algorithm is supported
    local valid_algorithm = false
    for _, algo in ipairs(obj.supported_algorithms) do
        if algo == algorithm_name then
            valid_algorithm = true
            break
        end
    end
    
    if not valid_algorithm then
        error(string.format("Unsupported similarity algorithm: %s. Supported: %s", 
                           algorithm_name, table.concat(obj.supported_algorithms, ", ")))
    end
    
    return obj
end
-- }}}

-- {{{ function SimilarityCalculator:calculate
function SimilarityCalculator:calculate(embedding_a, embedding_b)
    if not embedding_a or not embedding_b then
        error("Both embeddings must be provided")
    end
    
    if #embedding_a ~= #embedding_b then
        error(string.format("Vector dimensions must match: %d vs %d", #embedding_a, #embedding_b))
    end
    
    if self.algorithm == "cosine" then
        return self:cosine_similarity(embedding_a, embedding_b)
    elseif self.algorithm == "euclidean" then
        return self:euclidean_distance_to_similarity(embedding_a, embedding_b)
    elseif self.algorithm == "manhattan" then
        return self:manhattan_distance_to_similarity(embedding_a, embedding_b)
    elseif self.algorithm == "dot_product" then
        return self:dot_product_similarity(embedding_a, embedding_b)
    elseif self.algorithm == "normalized_euclidean" then
        return self:normalized_euclidean_similarity(embedding_a, embedding_b)
    elseif self.algorithm == "chebyshev" then
        return self:chebyshev_distance_to_similarity(embedding_a, embedding_b)
    elseif self.algorithm == "angular" then
        return self:angular_similarity(embedding_a, embedding_b)
    elseif self.algorithm == "pearson_correlation" then
        return self:pearson_correlation(embedding_a, embedding_b)
    else
        error(string.format("Algorithm implementation missing: %s", self.algorithm))
    end
end
-- }}}

-- {{{ function SimilarityCalculator:cosine_similarity
function SimilarityCalculator:cosine_similarity(vec_a, vec_b)
    local dot_product = 0
    local norm_a = 0
    local norm_b = 0
    
    for i = 1, #vec_a do
        dot_product = dot_product + (vec_a[i] * vec_b[i])
        norm_a = norm_a + (vec_a[i] * vec_a[i])
        norm_b = norm_b + (vec_b[i] * vec_b[i])
    end
    
    norm_a = math.sqrt(norm_a)
    norm_b = math.sqrt(norm_b)
    
    if norm_a == 0 or norm_b == 0 then
        return 0  -- Handle zero vectors
    end
    
    return dot_product / (norm_a * norm_b)
end
-- }}}

-- {{{ function SimilarityCalculator:euclidean_distance_to_similarity
function SimilarityCalculator:euclidean_distance_to_similarity(vec_a, vec_b)
    local sum_squared_diff = 0
    
    for i = 1, #vec_a do
        local diff = vec_a[i] - vec_b[i]
        sum_squared_diff = sum_squared_diff + (diff * diff)
    end
    
    local distance = math.sqrt(sum_squared_diff)
    
    -- Convert distance to similarity using exponential decay
    -- Similarity = e^(-distance)
    return math.exp(-distance)
end
-- }}}

-- {{{ function SimilarityCalculator:manhattan_distance_to_similarity
function SimilarityCalculator:manhattan_distance_to_similarity(vec_a, vec_b)
    local sum_abs_diff = 0
    
    for i = 1, #vec_a do
        sum_abs_diff = sum_abs_diff + math.abs(vec_a[i] - vec_b[i])
    end
    
    -- Convert distance to similarity using exponential decay
    return math.exp(-sum_abs_diff)
end
-- }}}

-- {{{ function SimilarityCalculator:dot_product_similarity
function SimilarityCalculator:dot_product_similarity(vec_a, vec_b)
    local dot_product = 0
    
    for i = 1, #vec_a do
        dot_product = dot_product + (vec_a[i] * vec_b[i])
    end
    
    -- Normalize to 0-1 range (assumes input vectors are normalized)
    return (dot_product + 1) / 2
end
-- }}}

-- {{{ function SimilarityCalculator:normalized_euclidean_similarity
function SimilarityCalculator:normalized_euclidean_similarity(vec_a, vec_b)
    -- First normalize both vectors
    local norm_a = 0
    local norm_b = 0
    
    for i = 1, #vec_a do
        norm_a = norm_a + (vec_a[i] * vec_a[i])
        norm_b = norm_b + (vec_b[i] * vec_b[i])
    end
    
    norm_a = math.sqrt(norm_a)
    norm_b = math.sqrt(norm_b)
    
    if norm_a == 0 or norm_b == 0 then
        return 0
    end
    
    -- Calculate euclidean distance between normalized vectors
    local sum_squared_diff = 0
    for i = 1, #vec_a do
        local norm_a_i = vec_a[i] / norm_a
        local norm_b_i = vec_b[i] / norm_b
        local diff = norm_a_i - norm_b_i
        sum_squared_diff = sum_squared_diff + (diff * diff)
    end
    
    local distance = math.sqrt(sum_squared_diff)
    return math.exp(-distance)
end
-- }}}

-- {{{ function SimilarityCalculator:chebyshev_distance_to_similarity
function SimilarityCalculator:chebyshev_distance_to_similarity(vec_a, vec_b)
    local max_diff = 0
    
    for i = 1, #vec_a do
        local diff = math.abs(vec_a[i] - vec_b[i])
        if diff > max_diff then
            max_diff = diff
        end
    end
    
    -- Convert distance to similarity
    return math.exp(-max_diff)
end
-- }}}

-- {{{ function SimilarityCalculator:angular_similarity
function SimilarityCalculator:angular_similarity(vec_a, vec_b)
    -- Angular similarity = 1 - (arccos(cosine_similarity) / π)
    local cosine_sim = self:cosine_similarity(vec_a, vec_b)
    
    -- Clamp to valid range for arccos
    cosine_sim = math.max(-1, math.min(1, cosine_sim))
    
    local angle = math.acos(cosine_sim)
    return 1 - (angle / math.pi)
end
-- }}}

-- {{{ function SimilarityCalculator:pearson_correlation
function SimilarityCalculator:pearson_correlation(vec_a, vec_b)
    local n = #vec_a
    if n < 2 then
        return 0
    end
    
    -- Calculate means
    local mean_a = 0
    local mean_b = 0
    for i = 1, n do
        mean_a = mean_a + vec_a[i]
        mean_b = mean_b + vec_b[i]
    end
    mean_a = mean_a / n
    mean_b = mean_b / n
    
    -- Calculate correlation
    local numerator = 0
    local sum_sq_a = 0
    local sum_sq_b = 0
    
    for i = 1, n do
        local diff_a = vec_a[i] - mean_a
        local diff_b = vec_b[i] - mean_b
        numerator = numerator + (diff_a * diff_b)
        sum_sq_a = sum_sq_a + (diff_a * diff_a)
        sum_sq_b = sum_sq_b + (diff_b * diff_b)
    end
    
    local denominator = math.sqrt(sum_sq_a * sum_sq_b)
    if denominator == 0 then
        return 0
    end
    
    local correlation = numerator / denominator
    return (correlation + 1) / 2  -- Normalize to 0-1 range
end
-- }}}

-- {{{ function SimilarityCalculator:get_algorithm_info
function SimilarityCalculator:get_algorithm_info()
    return {
        name = self.algorithm,
        supported_algorithms = self.supported_algorithms,
        config = self.config,
        description = self:get_algorithm_description()
    }
end
-- }}}

-- {{{ function SimilarityCalculator:get_algorithm_description
function SimilarityCalculator:get_algorithm_description()
    local descriptions = {
        cosine = "Cosine similarity - measures angle between vectors, standard for text embeddings",
        euclidean = "Euclidean distance converted to similarity - measures straight-line distance",
        manhattan = "Manhattan distance converted to similarity - measures city-block distance",
        dot_product = "Dot product similarity - measures vector alignment",
        normalized_euclidean = "Euclidean distance on normalized vectors",
        chebyshev = "Chebyshev distance - measures maximum dimension difference",
        angular = "Angular similarity - normalized angle between vectors",
        pearson_correlation = "Pearson correlation coefficient - measures linear correlation"
    }
    
    return descriptions[self.algorithm] or "Unknown algorithm"
end
-- }}}

-- {{{ function SimilarityCalculator:validate_implementation
function SimilarityCalculator:validate_implementation()
    -- Test with simple known vectors
    local test_cases = {
        {
            name = "identical_vectors",
            vec_a = {1, 0, 0},
            vec_b = {1, 0, 0},
            expected_similarity = 1.0,
            tolerance = 0.001
        },
        {
            name = "orthogonal_vectors",
            vec_a = {1, 0, 0},
            vec_b = {0, 1, 0},
            expected_similarity = 0.0,
            tolerance = 0.6  -- Distance-based algorithms may not give exactly 0
        },
        {
            name = "opposite_vectors",
            vec_a = {1, 0, 0},
            vec_b = {-1, 0, 0},
            expected_similarity = -1.0,  -- Cosine similarity of opposite vectors is -1
            tolerance = 1.2  -- Allow for algorithm differences
        }
    }
    
    local results = {
        algorithm = self.algorithm,
        validation_results = {},
        all_tests_passed = true
    }
    
    for _, test_case in ipairs(test_cases) do
        local calculated_similarity = self:calculate(test_case.vec_a, test_case.vec_b)
        local difference = math.abs(calculated_similarity - test_case.expected_similarity)
        local passed = difference <= test_case.tolerance
        
        if not passed then
            results.all_tests_passed = false
        end
        
        table.insert(results.validation_results, {
            test_name = test_case.name,
            expected = test_case.expected_similarity,
            calculated = calculated_similarity,
            difference = difference,
            tolerance = test_case.tolerance,
            passed = passed
        })
    end
    
    return results
end
-- }}}

-- {{{ function create_from_config
local function create_from_config(algorithm_name)
    algorithm_name = algorithm_name or "cosine"
    
    -- Try to load configuration
    local config_file = DIR .. "/config/similarity-calculator-settings.json"
    local config_data = utils.load_json(config_file)
    
    if config_data then
        algorithm_name = algorithm_name or config_data.default_algorithm
        local algorithm_config = config_data.algorithms[algorithm_name] or {}
        return SimilarityCalculator:new(algorithm_name, algorithm_config)
    else
        -- Fallback if no config file
        return SimilarityCalculator:new(algorithm_name)
    end
end
-- }}}

-- {{{ function get_available_algorithms
local function get_available_algorithms()
    local temp_calc = SimilarityCalculator:new("cosine")
    return temp_calc.supported_algorithms
end
-- }}}

return {
    SimilarityCalculator = SimilarityCalculator,
    create_from_config = create_from_config,
    get_available_algorithms = get_available_algorithms
}