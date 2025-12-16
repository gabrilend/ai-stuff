#!/usr/bin/env lua

-- Embedding-Based Similarity and Diversity List Generator
-- Pre-generates similarity and diversity data for modular HTML generation

package.path = package.path .. ';./?.lua;./libs/?.lua'

local utils = require("libs.utils")

local M = {}
local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

-- {{{ function generate_most_similar_lists
function M.generate_most_similar_lists(embeddings_dir, model_name)
    local model_dir = embeddings_dir .. "/" .. model_name
    local similarity_matrix_file = model_dir .. "/similarity_matrix.json"
    
    utils.log_info(string.format("Loading similarity matrix from: %s", similarity_matrix_file))
    local similarity_data = utils.read_json_file(similarity_matrix_file)
    
    if not similarity_data then
        utils.log_error("Failed to load similarity matrix")
        return false
    end
    
    local output_dir = model_dir .. "/similarity_lists/most_similar"
    os.execute("mkdir -p " .. output_dir)
    
    local total_poems = 0
    for _ in pairs(similarity_data.similarities) do
        total_poems = total_poems + 1
    end
    
    utils.log_info(string.format("Generating most similar lists for %d poems", total_poems))
    
    local processed_count = 0
    
    for poem_id, similarities in pairs(similarity_data.similarities) do
        processed_count = processed_count + 1
        
        if processed_count % 100 == 0 then
            utils.log_info(string.format("Progress: %d/%d most similar lists generated (%.1f%%)", 
                                        processed_count, total_poems, 
                                        (processed_count / total_poems) * 100))
        end
        
        -- Convert similarities to sorted list
        local similarity_list = {}
        
        -- Extract similarities from top_similar array structure
        if similarities.top_similar then
            for _, similarity_entry in ipairs(similarities.top_similar) do
                table.insert(similarity_list, {
                    poem_id = similarity_entry.id or similarity_entry.index,
                    similarity_score = similarity_entry.similarity,
                    rank = nil
                })
            end
        else
            -- Fallback: treat as direct poem_id -> score mapping
            for target_id, score in pairs(similarities) do
                if target_id ~= "poem_index" and target_id ~= "calculated_at" then
                    table.insert(similarity_list, {
                        poem_id = tonumber(target_id),
                        similarity_score = score,
                        rank = nil
                    })
                end
            end
        end
        
        -- Sort by similarity score (highest first)
        table.sort(similarity_list, function(a, b)
            return (a.similarity_score or 0) > (b.similarity_score or 0)
        end)
        
        -- Add rank information
        for i, item in ipairs(similarity_list) do
            item.rank = i
        end
        
        local output_data = {
            source_poem_id = tonumber(poem_id) or 0,
            model_name = model_name,
            generation_timestamp = os.date("%Y-%m-%dT%H:%M:%S"),
            total_similar_poems = #similarity_list,
            most_similar_poems = similarity_list
        }
        
        local output_file = string.format("%s/poem-%03d-most-similar.json", output_dir, tonumber(poem_id) or 0)
        local success = utils.write_json_file(output_file, output_data)
        
        if not success then
            utils.log_error(string.format("Failed to write most similar list for poem %s", poem_id))
            return false
        end
    end
    
    utils.log_info(string.format("Generated %d most similar lists", processed_count))
    return true
end
-- }}}

-- {{{ function generate_least_similar_chain
function M.generate_least_similar_chain(starting_poem_id, similarity_data, max_length)
    local chain = {
        {
            poem_id = starting_poem_id,
            position = 1,
            similarity_to_previous = nil,
            selection_reason = "starting_poem"
        }
    }
    
    local used_poems = {[tonumber(starting_poem_id) or 0] = true}
    local current_poem_id = starting_poem_id
    
    for position = 2, max_length do
        local least_similar = M.find_least_similar_poem(current_poem_id, similarity_data, used_poems)
        
        if not least_similar then
            break
        end
        
        table.insert(chain, {
            poem_id = least_similar.poem_id,
            position = position,
            similarity_to_previous = least_similar.similarity_score,
            selection_reason = "least_similar_to_previous"
        })
        
        used_poems[least_similar.poem_id] = true
        current_poem_id = least_similar.poem_id
    end
    
    return chain
end
-- }}}

-- {{{ function find_least_similar_poem
function M.find_least_similar_poem(current_poem_id, similarity_data, used_poems)
    local current_similarities = similarity_data.similarities[tostring(current_poem_id)]
    
    if not current_similarities then
        return nil
    end
    
    local least_similar_poem = nil
    local lowest_similarity = math.huge
    
    -- Handle both top_similar array structure and direct mapping
    local similarities_to_check = current_similarities.top_similar or current_similarities
    
    if current_similarities.top_similar then
        -- Array structure with similarity entries
        for _, similarity_entry in ipairs(similarities_to_check) do
            local target_id = similarity_entry.id or similarity_entry.index
            local similarity_score = similarity_entry.similarity
            
            if not used_poems[target_id] then
                if similarity_score < lowest_similarity then
                    lowest_similarity = similarity_score
                    least_similar_poem = {
                        poem_id = target_id,
                        similarity_score = similarity_score
                    }
                end
            end
        end
    else
        -- Direct poem_id -> score mapping
        for target_poem_id, similarity_score in pairs(similarities_to_check) do
            if target_poem_id ~= "poem_index" and target_poem_id ~= "calculated_at" then
                local target_id = tonumber(target_poem_id)
                
                if not used_poems[target_id] then
                    if similarity_score < lowest_similarity then
                        lowest_similarity = similarity_score
                        least_similar_poem = {
                            poem_id = target_id,
                            similarity_score = similarity_score
                        }
                    end
                end
            end
        end
    end
    
    return least_similar_poem
end
-- }}}

-- {{{ function generate_diversity_chain_lists
function M.generate_diversity_chain_lists(embeddings_dir, model_name, chain_length)
    chain_length = chain_length or 20
    
    local model_dir = embeddings_dir .. "/" .. model_name
    local similarity_matrix_file = model_dir .. "/similarity_matrix.json"
    
    utils.log_info(string.format("Loading similarity matrix from: %s", similarity_matrix_file))
    local similarity_data = utils.read_json_file(similarity_matrix_file)
    
    if not similarity_data then
        utils.log_error("Failed to load similarity data")
        return false
    end
    
    local output_dir = model_dir .. "/similarity_lists/diversity_chains"
    os.execute("mkdir -p " .. output_dir)
    
    local total_poems = 0
    for _ in pairs(similarity_data.similarities) do
        total_poems = total_poems + 1
    end
    
    utils.log_info(string.format("Generating diversity chains for %d poems", total_poems))
    
    local processed_count = 0
    
    for starting_poem_id, _ in pairs(similarity_data.similarities) do
        processed_count = processed_count + 1
        
        if processed_count % 50 == 0 then
            utils.log_info(string.format("Progress: %d/%d diversity chains generated (%.1f%%)", 
                                        processed_count, total_poems, 
                                        (processed_count / total_poems) * 100))
        end
        
        local diversity_chain = M.generate_least_similar_chain(
            tonumber(starting_poem_id), 
            similarity_data, 
            chain_length
        )
        
        local output_data = {
            starting_poem_id = tonumber(starting_poem_id) or 0,
            model_name = model_name,
            generation_timestamp = os.date("%Y-%m-%dT%H:%M:%S"),
            chain_length = #diversity_chain,
            target_chain_length = chain_length,
            diversity_chain = diversity_chain
        }
        
        local output_file = string.format("%s/poem-%03d-diversity-chain.json", output_dir, tonumber(starting_poem_id) or 0)
        local success = utils.write_json_file(output_file, output_data)
        
        if not success then
            utils.log_error(string.format("Failed to write diversity chain for poem %s", starting_poem_id))
            return false
        end
    end
    
    utils.log_info(string.format("Generated %d diversity chain lists", processed_count))
    return true
end
-- }}}

-- {{{ function generate_all_embedding_lists
function M.generate_all_embedding_lists(embeddings_dir, model_name, options)
    options = options or {}
    local chain_length = options.chain_length or 20
    
    utils.log_info(string.format("Generating all embedding lists for model: %s", model_name))
    
    -- Generate most similar lists
    local similar_success = M.generate_most_similar_lists(embeddings_dir, model_name)
    if not similar_success then
        utils.log_error("Failed to generate most similar lists")
        return false
    end
    
    -- Generate diversity chain lists
    local diversity_success = M.generate_diversity_chain_lists(embeddings_dir, model_name, chain_length)
    if not diversity_success then
        utils.log_error("Failed to generate diversity chain lists")
        return false
    end
    
    utils.log_info("Successfully generated all embedding lists")
    return true
end
-- }}}

return M