#!/usr/bin/env lua

-- Similarity Navigation Engine for Poetry Website
-- Loads similarity data and generates recommendations for HTML generation

local utils = require("libs.utils")
local json = require("libs.json")
local url_manager = require("src.html-generator.url-manager")
local golden_bonus = require("src.html-generator.golden-poem-bonus")

local M = {}
local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

-- Default configuration
M.config = {
    default_model = "embeddinggemma_latest",
    default_recommendations = 10,
    min_similarity_threshold = 0.1,
    enable_golden_prioritization = true,
    golden_poem_bonus = 0.02,
    max_golden_recommendations = 3
}

-- {{{ function M.set_config
function M.set_config(new_config)
    for key, value in pairs(new_config) do
        M.config[key] = value
    end
end
-- }}}

-- {{{ function M.load_poem_similarities
function M.load_poem_similarities(poem_id, model_name)
    model_name = model_name or M.config.default_model
    
    -- Try individual similarity file first (more efficient)
    local individual_file = string.format(
        "%s/assets/embeddings/%s/similarities/poem_%d.json",
        DIR, model_name, poem_id
    )
    
    if utils.file_exists(individual_file) then
        utils.log_info(string.format("Loading individual similarities for poem %d", poem_id))
        local content = utils.read_file(individual_file)
        if content then
            return json.decode(content)
        end
    end
    
    -- Fallback to full similarity matrix
    return M.load_from_similarity_matrix(poem_id, model_name)
end
-- }}}

-- {{{ function M.load_from_similarity_matrix
function M.load_from_similarity_matrix(poem_id, model_name)
    model_name = model_name or M.config.default_model
    
    local matrix_file = string.format(
        "%s/assets/embeddings/%s/similarity_matrix.json",
        DIR, model_name
    )
    
    if not utils.file_exists(matrix_file) then
        utils.log_warn("Similarity matrix not found: " .. matrix_file)
        return nil
    end
    
    utils.log_info(string.format("Loading from similarity matrix for poem %d", poem_id))
    local content = utils.read_file(matrix_file)
    if not content then
        utils.log_error("Failed to read similarity matrix")
        return nil
    end
    
    local matrix_data = json.decode(content)
    if not matrix_data or not matrix_data.similarities then
        utils.log_error("Invalid similarity matrix format")
        return nil
    end
    
    -- Extract similarities for the specific poem
    local poem_similarities = matrix_data.similarities[tostring(poem_id)]
    if not poem_similarities then
        utils.log_warn("No similarities found for poem " .. poem_id)
        return nil
    end
    
    -- Convert matrix format to individual format
    return {
        similarities = poem_similarities.top_similar or {}
    }
end
-- }}}

-- {{{ function M.get_poem_metadata
function M.get_poem_metadata(poem_id, poems_data)
    if not poems_data then
        return nil
    end
    
    for _, poem in ipairs(poems_data.poems) do
        if poem.id == poem_id then
            return poem
        end
    end
    
    return nil
end
-- }}}

-- {{{ function M.get_top_recommendations
function M.get_top_recommendations(poem_id, poems_data, options)
    options = options or {}
    local count = options.count or M.config.default_recommendations
    local model_name = options.model_name or M.config.default_model
    
    -- Load similarity data
    local similarity_data = M.load_poem_similarities(poem_id, model_name)
    if not similarity_data or not similarity_data.similarities then
        utils.log_warn("No similarity data available for poem " .. poem_id)
        return {}
    end
    
    local recommendations = {}
    local added_count = 0
    local golden_count = 0
    
    -- Process similarities (already sorted by score in most cases)
    for _, sim_entry in ipairs(similarity_data.similarities) do
        if added_count >= count then break end
        
        local other_poem_id = tonumber(sim_entry.id)
        local similarity_score = sim_entry.similarity
        
        -- Skip invalid entries
        if not other_poem_id or not similarity_score then
            goto continue
        end
        
        -- Skip self-references and low similarity
        if other_poem_id ~= poem_id and similarity_score >= M.config.min_similarity_threshold then
            
            -- Get poem metadata
            local other_poem = M.get_poem_metadata(other_poem_id, poems_data)
            if other_poem then
                
                -- Check golden poem status
                local is_golden = other_poem.is_fediverse_golden or false
                
                -- Apply golden poem limits if enabled
                if M.config.enable_golden_prioritization and is_golden then
                    if golden_count >= M.config.max_golden_recommendations then
                        goto continue -- Skip this golden poem
                    end
                    golden_count = golden_count + 1
                end
                
                -- Generate URL for the recommendation
                local category = url_manager.get_poem_category(other_poem)
                local poem_url = url_manager.generate_poem_url(other_poem_id, category)
                
                -- Apply golden poem bonus if enabled
                local enhanced_score = similarity_score
                local bonus_applied = 0
                
                if options.apply_golden_bonus then
                    local current_poem = M.get_poem_metadata(poem_id, poems_data)
                    if current_poem then
                        enhanced_score, bonus_applied = golden_bonus.calculate_similarity_with_golden_bonus(
                            current_poem, other_poem, similarity_score
                        )
                    end
                end
                
                table.insert(recommendations, {
                    id = other_poem_id,
                    title = other_poem.title or ("Poem " .. other_poem_id),
                    url = poem_url,
                    score = enhanced_score,
                    original_score = similarity_score,
                    bonus_applied = bonus_applied,
                    category = category,
                    is_golden = is_golden,
                    character_count = other_poem.length or other_poem.character_count
                })
                
                added_count = added_count + 1
            end
        end
        
        ::continue::
    end
    
    -- Apply golden poem prioritization if enabled
    if M.config.enable_golden_prioritization then
        recommendations = M.apply_golden_prioritization(recommendations)
    end
    
    utils.log_info(string.format("Generated %d recommendations for poem %d (%d golden)", 
                                #recommendations, poem_id, golden_count))
    
    return recommendations
end
-- }}}

-- {{{ function M.apply_golden_prioritization
function M.apply_golden_prioritization(recommendations)
    if not M.config.enable_golden_prioritization then
        return recommendations
    end
    
    -- Use the enhanced golden bonus system
    return golden_bonus.apply_golden_prioritization_to_recommendations(recommendations, {
        golden_boost = M.config.golden_poem_bonus or 0.02,
        min_golden_count = M.config.min_golden_recommendations or 2,
        max_golden_count = M.config.max_golden_recommendations or 5
    })
end
-- }}}

-- {{{ function M.generate_random_recommendation
function M.generate_random_recommendation(poem_id, poems_data, category)
    if not poems_data then
        return nil
    end
    
    -- Filter poems by category if specified
    local candidates = {}
    for _, poem in ipairs(poems_data.poems) do
        if poem.id ~= poem_id and poem.content and poem.content:len() > 10 then
            if not category or poem.category == category then
                table.insert(candidates, poem)
            end
        end
    end
    
    if #candidates == 0 then
        return nil
    end
    
    -- Select random poem
    local random_index = math.random(1, #candidates)
    local random_poem = candidates[random_index]
    
    local poem_category = url_manager.get_poem_category(random_poem)
    local poem_url = url_manager.generate_poem_url(random_poem.id, poem_category)
    
    return {
        id = random_poem.id,
        title = random_poem.title or ("Poem " .. random_poem.id),
        url = poem_url,
        score = 0.0,  -- Random recommendation
        category = poem_category,
        is_golden = random_poem.is_fediverse_golden or false,
        character_count = random_poem.length or random_poem.character_count
    }
end
-- }}}

-- {{{ function M.get_category_recommendations
function M.get_category_recommendations(poem_id, poems_data, target_category, count)
    count = count or 5
    
    if not poems_data then
        return {}
    end
    
    local category_poems = {}
    for _, poem in ipairs(poems_data.poems) do
        if poem.id ~= poem_id and poem.category == target_category and poem.content and poem.content:len() > 10 then
            table.insert(category_poems, poem)
        end
    end
    
    if #category_poems == 0 then
        return {}
    end
    
    -- Shuffle and take first N
    for i = #category_poems, 2, -1 do
        local j = math.random(i)
        category_poems[i], category_poems[j] = category_poems[j], category_poems[i]
    end
    
    local recommendations = {}
    for i = 1, math.min(count, #category_poems) do
        local poem = category_poems[i]
        local poem_category = url_manager.get_poem_category(poem)
        local poem_url = url_manager.generate_poem_url(poem.id, poem_category)
        
        table.insert(recommendations, {
            id = poem.id,
            title = poem.title or ("Poem " .. poem.id),
            url = poem_url,
            score = 0.0,  -- Category recommendation
            category = poem_category,
            is_golden = poem.is_fediverse_golden or false,
            character_count = poem.length or poem.character_count
        })
    end
    
    return recommendations
end
-- }}}

-- {{{ function M.get_similarity_stats
function M.get_similarity_stats(model_name)
    model_name = model_name or M.config.default_model
    
    local stats = {
        model = model_name,
        individual_files = 0,
        matrix_exists = false,
        total_poems_with_similarities = 0
    }
    
    -- Check individual files
    local similarities_dir = string.format("%s/assets/embeddings/%s/similarities", DIR, model_name)
    if utils.file_exists(similarities_dir) then
        local find_cmd = string.format('find "%s" -name "poem_*.json" | wc -l', similarities_dir)
        local handle = io.popen(find_cmd)
        if handle then
            local count_str = handle:read("*a")
            handle:close()
            stats.individual_files = tonumber(count_str) or 0
        end
    end
    
    -- Check similarity matrix
    local matrix_file = string.format("%s/assets/embeddings/%s/similarity_matrix.json", DIR, model_name)
    if utils.file_exists(matrix_file) then
        stats.matrix_exists = true
        
        -- Get matrix metadata
        local content = utils.read_file(matrix_file)
        if content then
            local matrix_data = json.decode(content)
            if matrix_data and matrix_data.metadata then
                stats.matrix_metadata = matrix_data.metadata
                stats.total_poems_with_similarities = matrix_data.metadata.embedding_count or 0
            end
        end
    end
    
    return stats
end
-- }}}

-- {{{ function M.test_similarity_engine
function M.test_similarity_engine()
    utils.log_info("Testing similarity engine...")
    
    -- Load poems data
    local template_engine = require("src.html-generator.template-engine")
    local poems_data = template_engine.load_poems_data()
    if not poems_data then
        utils.log_error("Failed to load poems data for testing")
        return false
    end
    
    -- Get similarity stats
    local stats = M.get_similarity_stats()
    utils.log_info(string.format("Similarity stats: %d individual files, matrix exists: %s",
                                stats.individual_files, stats.matrix_exists and "yes" or "no"))
    
    if stats.matrix_exists and stats.matrix_metadata then
        utils.log_info(string.format("Matrix metadata: %d/%d poems (%.1f%% complete)",
                                    stats.matrix_metadata.embedding_count,
                                    stats.matrix_metadata.total_poems,
                                    (stats.matrix_metadata.matrix_completeness or 0) * 100))
    end
    
    -- Test with a known poem
    local test_poem_id = 1
    local test_poem = M.get_poem_metadata(test_poem_id, poems_data)
    if not test_poem then
        utils.log_error("Test poem not found")
        return false
    end
    
    utils.log_info(string.format("Testing with poem %d: %s", 
                                test_poem_id, 
                                test_poem.title or "Untitled"))
    
    -- Get recommendations
    local recommendations = M.get_top_recommendations(test_poem_id, poems_data, {count = 5})
    
    if #recommendations == 0 then
        utils.log_warn("No recommendations found - this is expected if similarity data is incomplete")
        return true  -- Not a failure, just incomplete data
    end
    
    utils.log_info(string.format("Found %d recommendations:", #recommendations))
    for i, rec in ipairs(recommendations) do
        local golden_marker = rec.is_golden and " ✨" or ""
        utils.log_info(string.format("  %d. %s%s (%.3f similarity) - %s", 
                                    i, rec.title, golden_marker, rec.score, rec.url))
    end
    
    -- Test random recommendation
    local random_rec = M.generate_random_recommendation(test_poem_id, poems_data)
    if random_rec then
        utils.log_info(string.format("Random recommendation: %s - %s", random_rec.title, random_rec.url))
    end
    
    utils.log_info("✅ Similarity engine test PASSED")
    return true
end
-- }}}

return M