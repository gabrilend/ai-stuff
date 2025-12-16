-- Diversity chaining algorithm for creating maximally different poem sequences
-- Uses least-similar selection to build "schizophrenic" reading experiences

local DIR = DIR or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

-- Set up path for local development
if not DIR:find("^/") then
    -- Relative path mode
    package.path = './libs/?.lua;' .. package.path
    local utils = require('utils')
else
    -- Absolute path mode
    package.path = DIR .. '/libs/?.lua;' .. package.path
    local utils = require('utils')
end

local utils = require('utils')

local M = {}

-- {{{ DiversityConfig class
local DiversityConfig = {
    default_chain_length = 20,
    min_diversity_threshold = 0.0,  -- Accept any dissimilarity 
    max_chain_length = 100,
    enable_debug_logging = false
}

function DiversityConfig:new(config)
    config = config or {}
    local obj = {}
    setmetatable(obj, {__index = self})
    
    obj.chain_length = config.chain_length or self.default_chain_length
    obj.diversity_threshold = config.diversity_threshold or self.min_diversity_threshold
    obj.debug_logging = config.debug_logging or self.enable_debug_logging
    obj.max_length = math.min(config.max_length or self.max_chain_length, self.max_chain_length)
    
    -- Validate configuration
    if obj.chain_length > obj.max_length then
        obj.chain_length = obj.max_length
        utils.log_warn("Chain length reduced to maximum: " .. obj.max_length)
    end
    
    return obj
end
-- }}}

-- {{{ function find_least_similar_unused_poem
local function find_least_similar_unused_poem(current_poem_id, poems_data, similarity_data, used_poems)
    local least_similar_poem = nil
    local lowest_similarity = math.huge
    local candidates_checked = 0
    
    -- Handle both sparse and full matrix formats
    local similarities = similarity_data.similarities and 
                        similarity_data.similarities[tostring(current_poem_id)] or 
                        similarity_data[tostring(current_poem_id)] or {}
    
    for target_poem_id, similarity_score in pairs(similarities) do
        candidates_checked = candidates_checked + 1
        local target_id = tonumber(target_poem_id)
        
        -- Skip if poem is already used or doesn't exist
        if target_id and not used_poems[target_id] and poems_data[target_id] then
            -- Handle both sparse (object with similarity) and full (direct score) formats
            local score = type(similarity_score) == "table" and similarity_score.similarity or similarity_score
            
            -- Find LEAST similar (lowest score)
            if score and score < lowest_similarity then
                lowest_similarity = score
                least_similar_poem = {
                    id = target_id,
                    similarity = score,
                    title = poems_data[target_id].title or "Untitled",
                    category = poems_data[target_id].category or "unknown"
                }
            end
        end
    end
    
    -- Fallback: if we couldn't find any candidates, try exhaustive search
    if not least_similar_poem and candidates_checked == 0 then
        utils.log_warn("No similarity data found for poem " .. current_poem_id .. ", using fallback selection")
        
        -- Find any unused poem
        for poem_id, poem_data in pairs(poems_data) do
            local id = tonumber(poem_id)
            if id and not used_poems[id] and id ~= current_poem_id then
                least_similar_poem = {
                    id = id,
                    similarity = 0.0,  -- Assume maximum diversity
                    title = poem_data.title or "Untitled",
                    category = poem_data.category or "unknown"
                }
                break
            end
        end
    end
    
    return least_similar_poem
end
-- }}}

-- {{{ function M.generate_maximum_diversity_chain
function M.generate_maximum_diversity_chain(starting_poem_id, poems_data, similarity_data, config)
    config = config or DiversityConfig:new()
    starting_poem_id = tonumber(starting_poem_id)
    
    if not starting_poem_id or not poems_data[starting_poem_id] then
        utils.log_error("Invalid starting poem ID: " .. tostring(starting_poem_id))
        return {}
    end
    
    local chain = {starting_poem_id}
    local used_poems = {[starting_poem_id] = true}
    local current_poem_id = starting_poem_id
    local total_diversity = 0
    local step_count = 0
    
    utils.log_info(string.format("🔗 Building diversity chain starting from poem %d (%s)", 
                                starting_poem_id, 
                                poems_data[starting_poem_id].title or "Untitled"))
    
    for i = 2, config.chain_length do
        local least_similar_poem = find_least_similar_unused_poem(
            current_poem_id, 
            poems_data, 
            similarity_data, 
            used_poems
        )
        
        if least_similar_poem then
            table.insert(chain, least_similar_poem.id)
            used_poems[least_similar_poem.id] = true
            current_poem_id = least_similar_poem.id
            step_count = step_count + 1
            total_diversity = total_diversity + (1 - least_similar_poem.similarity)  -- Higher diversity = lower similarity
            
            if config.debug_logging then
                utils.log_info(string.format("  🔗 Step %d: %d -> %d (similarity: %.3f, diversity: %.3f)", 
                                            i-1, chain[i-1], least_similar_poem.id, 
                                            least_similar_poem.similarity,
                                            1 - least_similar_poem.similarity))
            end
        else
            utils.log_warn(string.format("No more unused poems available at step %d", i))
            break
        end
    end
    
    local average_diversity = step_count > 0 and (total_diversity / step_count) or 0
    
    utils.log_info(string.format("✅ Diversity chain complete: %d poems, avg diversity: %.3f", 
                                #chain, average_diversity))
    
    return {
        chain = chain,
        metadata = {
            starting_poem_id = starting_poem_id,
            chain_length = #chain,
            target_length = config.chain_length,
            completion_rate = #chain / config.chain_length,
            average_diversity = average_diversity,
            generated_at = os.date("%Y-%m-%d %H:%M:%S")
        }
    }
end
-- }}}

-- {{{ function M.generate_multiple_diversity_chains
function M.generate_multiple_diversity_chains(poem_ids, poems_data, similarity_data, config)
    config = config or DiversityConfig:new()
    local results = {}
    local successful_chains = 0
    local total_diversity = 0
    
    utils.log_info(string.format("🔗 Generating diversity chains for %d starting poems", #poem_ids))
    
    for i, poem_id in ipairs(poem_ids) do
        local chain_result = M.generate_maximum_diversity_chain(poem_id, poems_data, similarity_data, config)
        
        if chain_result and #chain_result.chain > 1 then
            results[poem_id] = chain_result
            successful_chains = successful_chains + 1
            total_diversity = total_diversity + chain_result.metadata.average_diversity
            
            if i % 100 == 0 then
                utils.log_info(string.format("Progress: %d/%d chains generated", i, #poem_ids))
            end
        else
            utils.log_warn("Failed to generate chain for poem " .. poem_id)
        end
    end
    
    local overall_average_diversity = successful_chains > 0 and (total_diversity / successful_chains) or 0
    
    utils.log_info(string.format("✅ Batch generation complete: %d/%d successful, avg diversity: %.3f", 
                                successful_chains, #poem_ids, overall_average_diversity))
    
    return {
        chains = results,
        metadata = {
            total_requested = #poem_ids,
            successful_chains = successful_chains,
            success_rate = successful_chains / #poem_ids,
            overall_average_diversity = overall_average_diversity,
            config = config,
            generated_at = os.date("%Y-%m-%d %H:%M:%S")
        }
    }
end
-- }}}

-- {{{ function M.analyze_chain_diversity
function M.analyze_chain_diversity(chain_data, similarity_data)
    if not chain_data or not chain_data.chain or #chain_data.chain < 2 then
        return {error = "Invalid or too short chain for analysis"}
    end
    
    local chain = chain_data.chain
    local diversities = {}
    local similarities = {}
    local total_diversity = 0
    
    for i = 1, #chain - 1 do
        local current_id = tostring(chain[i])
        local next_id = tostring(chain[i + 1])
        
        -- Get similarity between consecutive poems
        local similarity_score = 0
        local current_similarities = similarity_data.similarities and 
                                   similarity_data.similarities[current_id] or 
                                   similarity_data[current_id] or {}
        
        if current_similarities[next_id] then
            similarity_score = type(current_similarities[next_id]) == "table" and 
                             current_similarities[next_id].similarity or 
                             current_similarities[next_id]
        end
        
        local diversity = 1 - similarity_score
        table.insert(diversities, diversity)
        table.insert(similarities, similarity_score)
        total_diversity = total_diversity + diversity
    end
    
    local average_diversity = #diversities > 0 and (total_diversity / #diversities) or 0
    
    -- Calculate diversity statistics
    table.sort(diversities)
    local median_diversity = #diversities > 0 and diversities[math.ceil(#diversities / 2)] or 0
    local min_diversity = #diversities > 0 and diversities[1] or 0
    local max_diversity = #diversities > 0 and diversities[#diversities] or 0
    
    return {
        chain_length = #chain,
        step_count = #diversities,
        average_diversity = average_diversity,
        median_diversity = median_diversity,
        min_diversity = min_diversity,
        max_diversity = max_diversity,
        diversities = diversities,
        similarities = similarities,
        quality_score = average_diversity -- Higher is better for diversity chains
    }
end
-- }}}

-- {{{ function M.load_similarity_data
function M.load_similarity_data(similarity_file)
    if not utils.file_exists(similarity_file) then
        utils.log_error("Similarity file not found: " .. similarity_file)
        return nil
    end
    
    utils.log_info("Loading similarity data from: " .. similarity_file)
    local similarity_data = utils.read_json_file(similarity_file)
    
    if not similarity_data then
        utils.log_error("Failed to parse similarity data")
        return nil
    end
    
    -- Detect data format
    local format = "unknown"
    local poem_count = 0
    local total_relationships = 0
    
    if similarity_data.similarities then
        format = "full_matrix"
        for poem_id, relationships in pairs(similarity_data.similarities) do
            poem_count = poem_count + 1
            for _ in pairs(relationships) do
                total_relationships = total_relationships + 1
            end
        end
    elseif similarity_data.metadata then
        format = "sparse_matrix"
        for poem_id, poem_data in pairs(similarity_data.similarities or {}) do
            poem_count = poem_count + 1
            if poem_data.top_similar then
                total_relationships = total_relationships + #poem_data.top_similar
            end
        end
    end
    
    utils.log_info(string.format("Similarity data loaded: %s format, %d poems, %d relationships", 
                                format, poem_count, total_relationships))
    
    return similarity_data
end
-- }}}

-- {{{ function M.test_diversity_algorithm
function M.test_diversity_algorithm(similarity_file, poems_file, test_poem_id, chain_length)
    test_poem_id = test_poem_id or 1
    chain_length = chain_length or 10
    
    utils.log_info("🧪 Testing diversity algorithm with poem " .. test_poem_id)
    
    -- Load data
    local similarity_data = M.load_similarity_data(similarity_file)
    if not similarity_data then return false end
    
    local poems_data = utils.read_json_file(poems_file)
    if not poems_data or not poems_data.poems then
        utils.log_error("Failed to load poems data")
        return false
    end
    
    -- Configure test
    local config = DiversityConfig:new({
        chain_length = chain_length,
        debug_logging = true
    })
    
    -- Generate test chain
    local result = M.generate_maximum_diversity_chain(test_poem_id, poems_data.poems, similarity_data, config)
    
    if result and result.chain then
        utils.log_info("✅ Test successful! Chain generated:")
        for i, poem_id in ipairs(result.chain) do
            local title = poems_data.poems[poem_id] and poems_data.poems[poem_id].title or "Unknown"
            utils.log_info(string.format("  %d. Poem %d: %s", i, poem_id, title))
        end
        
        -- Analyze chain
        local analysis = M.analyze_chain_diversity(result, similarity_data)
        if analysis.error then
            utils.log_warn("Chain analysis failed: " .. analysis.error)
        else
            utils.log_info(string.format("Chain analysis: avg diversity: %.3f, quality: %.3f", 
                                        analysis.average_diversity or 0, analysis.quality_score or 0))
        end
        
        return result
    else
        utils.log_error("❌ Test failed - no chain generated")
        return false
    end
end
-- }}}

-- Export DiversityConfig as well for external access
M.DiversityConfig = DiversityConfig

return M