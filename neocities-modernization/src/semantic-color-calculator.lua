#!/usr/bin/env lua

-- Semantic color calculation system for neocities-modernization
-- Generates color embeddings and precomputes poem-to-color mappings

-- {{{ local function setup_dir_path
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

-- Script configuration - handle args properly to avoid -I interfering with DIR
local DIR = setup_dir_path()
if arg then
    for _, arg_val in ipairs(arg) do
        if arg_val ~= "-I" and not arg_val:match("^%-") then
            DIR = arg_val
            break
        end
    end
end

-- Load required libraries
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path
local utils = require("utils")
local dkjson = require("dkjson")

-- Initialize asset path configuration (CLI --dir takes precedence over config)
utils.init_assets_root(arg)

local M = {}

-- {{{ function cosine_similarity
local function cosine_similarity(vec1, vec2)
    -- Calculate cosine similarity between two vectors
    if #vec1 ~= #vec2 then
        error("Vectors must have same dimension")
    end
    
    local dot_product = 0
    local norm1 = 0
    local norm2 = 0
    
    for i = 1, #vec1 do
        dot_product = dot_product + (vec1[i] * vec2[i])
        norm1 = norm1 + (vec1[i] * vec1[i])
        norm2 = norm2 + (vec2[i] * vec2[i])
    end
    
    norm1 = math.sqrt(norm1)
    norm2 = math.sqrt(norm2)
    
    if norm1 == 0 or norm2 == 0 then
        return 0.0
    end
    
    return dot_product / (norm1 * norm2)
end
-- }}}

-- {{{ function calculate_semantic_color_for_poem
local function calculate_semantic_color_for_poem(poem_embedding, color_embeddings)
    local best_color = "gray"  -- Default fallback
    local highest_similarity = -1
    
    -- Direct comparison between poem embedding and color word embeddings
    for color_name, color_embedding in pairs(color_embeddings) do
        if color_embedding then
            local similarity = cosine_similarity(poem_embedding, color_embedding)
            if similarity > highest_similarity then
                highest_similarity = similarity
                best_color = color_name
            end
        end
    end
    
    return best_color, highest_similarity
end
-- }}}

-- {{{ function generate_single_embedding
local function generate_single_embedding(text, model_name, endpoint)
    endpoint = endpoint or "http://192.168.0.115:10265"
    model_name = model_name or "embeddinggemma:latest"
    
    -- Use curl to call Ollama API directly
    local cmd = string.format(
        "curl -s -X POST %s/api/embeddings -H 'Content-Type: application/json' -d '{\"model\": \"%s\", \"prompt\": \"%s\"}'",
        endpoint, model_name, text
    )
    
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    
    if result and result ~= "" then
        local parsed = dkjson.decode(result)
        if parsed and parsed.embedding then
            return parsed.embedding
        else
            utils.log_error("No embedding in response for: " .. text)
            utils.log_debug("Response: " .. result:sub(1, 200))
        end
    else
        utils.log_error("No response from Ollama for: " .. text)
    end
    
    return nil
end
-- }}}

-- {{{ function generate_color_embeddings_using_ollama
function M.generate_color_embeddings_using_ollama(color_names, model_name)
    local color_embeddings = {}
    model_name = model_name or "embeddinggemma:latest"
    
    utils.log_info(string.format("Generating embeddings for %d colors using model: %s", #color_names, model_name))
    
    for _, color_name in ipairs(color_names) do
        -- Simple: just generate embedding for the color word itself
        -- "green" means whatever "green" means - no additional context needed
        local embedding = generate_single_embedding(color_name, model_name)
        
        if embedding then
            color_embeddings[color_name] = embedding
            utils.log_info(string.format("Generated embedding for color: %s (dim: %d)", 
                                        color_name, #embedding))
        else
            utils.log_error("Failed to generate embedding for color: " .. color_name)
        end
        
        -- Small delay to avoid overwhelming the API
        os.execute("sleep 0.5")
    end
    
    return color_embeddings
end
-- }}}

-- {{{ function precompute_poem_colors
function M.precompute_poem_colors(poems_data, poem_embeddings_data, color_embeddings, output_file)
    -- Calculate all poem-to-color mappings at compile time
    local poem_colors = {}
    local processed_count = 0
    local total_poems = 0
    
    -- Count total poems for progress tracking
    for i, poem in ipairs(poems_data.poems) do
        if poem.id and poem_embeddings_data.embeddings[i] and poem_embeddings_data.embeddings[i].embedding then
            total_poems = total_poems + 1
        end
    end
    
    utils.log_info(string.format("Computing semantic colors for %d poems", total_poems))
    
    for i, poem in ipairs(poems_data.poems) do
        if poem.id and poem_embeddings_data.embeddings[i] and poem_embeddings_data.embeddings[i].embedding then
            local color, similarity = calculate_semantic_color_for_poem(
                poem_embeddings_data.embeddings[i].embedding,
                color_embeddings
            )
            
            poem_colors[poem.id] = {
                color = color,
                similarity = similarity,
                calculated_at = os.date("%Y-%m-%d %H:%M:%S")
            }
            
            processed_count = processed_count + 1
            
            if processed_count % 100 == 0 then
                utils.log_info(string.format("Progress: %d/%d poems processed (%.1f%%) - Latest: poem %d = %s", 
                                            processed_count, total_poems, 
                                            (processed_count / total_poems) * 100,
                                            poem.id, color))
            end
        end
    end
    
    -- Save to file for use during HTML generation
    local output_data = {
        poem_colors = poem_colors,
        generated_at = os.date("%Y-%m-%d %H:%M:%S"),
        total_poems = processed_count,
        model_used = poem_embeddings_data.model_name or "unknown",
        color_count = 0
    }
    
    -- Count colors used
    local color_counts = {}
    for _, poem_color in pairs(poem_colors) do
        color_counts[poem_color.color] = (color_counts[poem_color.color] or 0) + 1
    end
    output_data.color_distribution = color_counts
    
    utils.write_json_file(output_file, output_data)
    
    utils.log_info(string.format("Precomputed colors for %d poems", processed_count))
    utils.log_info("Color distribution:")
    for color, count in pairs(color_counts) do
        utils.log_info(string.format("  %s: %d poems (%.1f%%)", color, count, (count / processed_count) * 100))
    end
    
    return poem_colors, output_data
end
-- }}}

-- {{{ function M.main
function M.main(interactive_mode)
    if interactive_mode then
        print("Semantic Color Calculator - Interactive Mode")
        print("1. Generate color embeddings only")
        print("2. Precompute poem colors (requires existing embeddings)")
        print("3. Generate color embeddings + precompute poem colors")
        print("4. Test color calculation on single poem")
        io.write("Select option (1-4): ")
        local choice = io.read()
        
        local color_config_file = DIR .. "/config/semantic-colors.json"
        local poems_file = utils.asset_path("poems.json")
        local embeddings_file = utils.embeddings_dir("embeddinggemma_latest") .. "/embeddings.json"
        local color_embeddings_file = utils.embeddings_dir("embeddinggemma_latest") .. "/color_embeddings.json"
        local poem_colors_file = utils.embeddings_dir("embeddinggemma_latest") .. "/poem_colors.json"
        
        -- Load color configuration
        local color_config = utils.read_json_file(color_config_file)
        if not color_config then
            utils.log_error("Failed to load color configuration from: " .. color_config_file)
            return
        end
        
        if choice == "1" or choice == "3" then
            print("Generating color embeddings...")
            local color_embeddings = M.generate_color_embeddings_using_ollama(
                color_config.color_names, 
                "embeddinggemma:latest"
            )
            
            -- Save color embeddings
            if next(color_embeddings) then
                local color_embeddings_data = {
                    embeddings = color_embeddings,
                    generated_at = os.date("%Y-%m-%d %H:%M:%S"),
                    model_name = "embeddinggemma:latest",
                    color_count = #color_config.color_names
                }
                utils.write_json_file(color_embeddings_file, color_embeddings_data)
                utils.log_info("Color embeddings saved to: " .. color_embeddings_file)
            else
                utils.log_error("No color embeddings generated")
                return
            end
        end
        
        if choice == "2" or choice == "3" then
            print("Loading poem embeddings...")
            local poems_data = utils.read_json_file(poems_file)
            local embeddings_data = utils.read_json_file(embeddings_file)
            
            -- Load color embeddings (either just generated or existing)
            local color_embeddings_data = utils.read_json_file(color_embeddings_file)
            
            if poems_data and embeddings_data and color_embeddings_data then
                print("Precomputing poem colors...")
                M.precompute_poem_colors(
                    poems_data,
                    embeddings_data, 
                    color_embeddings_data.embeddings,
                    poem_colors_file
                )
                utils.log_info("Poem colors saved to: " .. poem_colors_file)
            else
                utils.log_error("Failed to load required data files")
            end
        elseif choice == "4" then
            io.write("Enter poem ID to test: ")
            local poem_id = tonumber(io.read())
            if poem_id then
                -- Load all required data
                local poems_data = utils.read_json_file(poems_file)
                local embeddings_data = utils.read_json_file(embeddings_file)
                local color_embeddings_data = utils.read_json_file(color_embeddings_file)
                
                if poems_data and embeddings_data and color_embeddings_data then
                    -- Find the poem
                    local poem_data = nil
                    local poem_embedding = nil
                    
                    for i, poem in ipairs(poems_data.poems) do
                        if poem.id == poem_id then
                            poem_data = poem
                            if embeddings_data.embeddings[i] then
                                poem_embedding = embeddings_data.embeddings[i].embedding
                            end
                            break
                        end
                    end
                    
                    if poem_data and poem_embedding then
                        local color, similarity = calculate_semantic_color_for_poem(
                            poem_embedding,
                            color_embeddings_data.embeddings
                        )
                        
                        print(string.format("Poem %d (%s):", poem_id, poem_data.category or "unknown"))
                        print("Content preview:", poem_data.content:sub(1, 100) .. "...")
                        print(string.format("Semantic color: %s (similarity: %.3f)", color, similarity))
                        
                        -- Show all color similarities
                        print("All color similarities:")
                        for color_name, color_embedding in pairs(color_embeddings_data.embeddings) do
                            local sim = cosine_similarity(poem_embedding, color_embedding)
                            print(string.format("  %s: %.3f", color_name, sim))
                        end
                    else
                        print("Could not find poem or embedding for ID:", poem_id)
                    end
                end
            end
        end
    else
        utils.log_info("Use -I flag for interactive mode")
    end
end
-- }}}

-- Command line execution
if arg then
    -- Check for interactive flag
    local interactive = false
    for _, arg_val in ipairs(arg) do
        if arg_val == "-I" then
            interactive = true
            break
        end
    end
    
    M.main(interactive)
end

return M