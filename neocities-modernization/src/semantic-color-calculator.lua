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
-- Shared progress renderer (Issue 10-051 family): one animated \r bar on a TTY,
-- plain newline-terminated lines under --debug (VKC_DEBUG, so a redirected log
-- keeps the full history), and silent when piped. Replaces the old every-100
-- "[INFO] Progress:" lines that scrolled the console during a full run.
local progress = require("progress-display")

-- Issue 10-003: Load unified config from config.lua
local config_loader = require("config-loader")
config_loader.set_project_root(DIR)
local unified_config = config_loader.load()

-- Endpoint resolution goes through the shared inference-server-config module so that
-- --server=<name> and default_inference_server are honored here the same way
-- they are honored by the rest of the pipeline. Previously this file had a
-- hardcoded fallback IP that drifted from config.lua and quietly broke
-- color-embedding generation when the IP no longer pointed at a live server.
local inference_config = require("inference-server-config")
-- Issue 10-050: shared batched embedding primitive. We hand it our endpoint and
-- prompt formatter so fuzzy-computing's separate config instance is never used.
local fuzzy = require("fuzzy-computing")
-- combine_chunk_vectors: reused to mean-combine a color's association-word
-- embeddings into one centroid (same recombination used for long-poem chunks).
local text_chunking = require("text-chunking")
inference_config.set_project_root(DIR)

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

-- {{{ local function compute_color_stats
-- Per-color mean/std of cosine similarity across ALL poems, used to z-score the
-- color assignment below. Why this is needed: bare color-word embeddings suffer
-- from "hubness" -- a couple of them (yellow, green) sit slightly nearer the
-- centre of the whole poem cloud, so by raw nearest-cosine they win ~70% of all
-- poems (38% yellow + 29% green) while blue gets 2.5%. The colours are NOT
-- evenly spread anchors; they are bunched, and tiny baseline offsets decide
-- everything. Standardising each colour's similarity (subtract its mean, divide
-- by its std) makes a poem pick the colour it is most ABOVE-baseline for, which
-- balances the distribution to ~10-18% each without touching the embeddings.
local function compute_color_stats(poems_data, poem_embeddings_data, color_embeddings)
    local sums, sums2, n = {}, {}, 0
    for cname, _ in pairs(color_embeddings) do sums[cname] = 0; sums2[cname] = 0 end
    for i, poem in ipairs(poems_data.poems) do
        local e = poem_embeddings_data.embeddings[i]
        if poem.poem_index and e and e.embedding then
            n = n + 1
            for cname, cvec in pairs(color_embeddings) do
                if cvec then
                    local s = cosine_similarity(e.embedding, cvec)
                    sums[cname] = sums[cname] + s
                    sums2[cname] = sums2[cname] + s * s
                end
            end
        end
    end
    local stats = {}
    for cname, _ in pairs(color_embeddings) do
        local mean = (n > 0) and (sums[cname] / n) or 0
        local var = (n > 0) and (sums2[cname] / n - mean * mean) or 0
        stats[cname] = { mean = mean, std = math.sqrt(math.max(var, 1e-9)) }
    end
    return stats
end
-- }}}

-- {{{ function calculate_semantic_color_for_poem
-- color_stats is optional. With it, the colour is chosen by z-scored similarity
-- (hubness-corrected); without it, by raw nearest cosine (legacy behaviour). The
-- returned similarity is always the RAW cosine, so downstream displays are
-- unchanged -- only the WINNER selection is standardised.
local function calculate_semantic_color_for_poem(poem_embedding, color_embeddings, color_stats)
    local best_color = "gray"  -- Default fallback
    local best_score = -math.huge
    local best_raw = -1

    for color_name, color_embedding in pairs(color_embeddings) do
        if color_embedding then
            local similarity = cosine_similarity(poem_embedding, color_embedding)
            local score = similarity
            if color_stats and color_stats[color_name] then
                local st = color_stats[color_name]
                score = (similarity - st.mean) / st.std
            end
            if score > best_score then
                best_score = score
                best_color = color_name
                best_raw = similarity
            end
        end
    end

    return best_color, best_raw
end
-- }}}

-- {{{ function generate_color_embeddings
-- endpoint is optional: nil means "ask inference-server-config for the active server",
-- which is the right behavior for almost all callers. The parameter exists
-- so that test harnesses or one-off scripts can target a specific server
-- without having to mutate inference-server-config's module-local selection.
--
-- Each color's embedding is the MEAN of the embeddings of its association words
-- (config.color_associations), giving a richer "essence" anchor than the bare
-- color word. color_associations is optional: without it (or for a color missing
-- from it) we fall back to embedding the bare color name, so old callers keep
-- working. Words are embedded in one batched request per color via the shared
-- primitive; endpoint + prompt formatter are passed so this file's config
-- instance stays authoritative (matching prefixes are essential so colors and
-- poems land in the same embedding space). Mean (not length-weighted) combine:
-- every association word should count equally regardless of its spelling length.
function M.generate_color_embeddings(color_names, model_name, endpoint, color_associations)
    local color_embeddings = {}
    model_name = model_name or inference_config.get_selected_model()
    endpoint = endpoint or inference_config.build_host_url()

    utils.log_info(string.format("Generating embeddings for %d colors using model: %s", #color_names, model_name))

    for _, color_name in ipairs(color_names) do
        local words = (color_associations and color_associations[color_name]) or { color_name }
        local vectors, err = fuzzy.get_embeddings_batch(
            words, model_name, endpoint, inference_config.format_embedding_prompt)
        if not vectors then
            utils.log_error(string.format("Color embedding batch failed for %s: %s", color_name, tostring(err)))
        else
            -- keep only the well-formed vectors, then mean-combine into a centroid
            local vecs = {}
            for i = 1, #words do
                if type(vectors[i]) == "table" and #vectors[i] > 0 then vecs[#vecs + 1] = vectors[i] end
            end
            if #vecs > 0 then
                color_embeddings[color_name] = text_chunking.combine_chunk_vectors(vecs, nil, "mean")
                utils.log_info(string.format("Color %s: centroid from %d/%d association words (dim %d)",
                    color_name, #vecs, #words, #color_embeddings[color_name]))
            else
                utils.log_error("No association embeddings for color: " .. color_name)
            end
        end
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
    -- Note: Use poem.poem_index (globally unique) not poem.id (per-category, NOT unique)
    for i, poem in ipairs(poems_data.poems) do
        if poem.poem_index and poem_embeddings_data.embeddings[i] and poem_embeddings_data.embeddings[i].embedding then
            total_poems = total_poems + 1
        end
    end

    utils.log_info(string.format("Computing semantic colors for %d poems", total_poems))

    -- Hubness correction: gather each colour's similarity distribution across all
    -- poems first, so the assignment below can z-score it (see compute_color_stats).
    -- This is what stops two "magnet" colours from swallowing ~70% of the poems.
    local color_stats = compute_color_stats(poems_data, poem_embeddings_data, color_embeddings)

    for i, poem in ipairs(poems_data.poems) do
        if poem.poem_index and poem_embeddings_data.embeddings[i] and poem_embeddings_data.embeddings[i].embedding then
            local color, similarity = calculate_semantic_color_for_poem(
                poem_embeddings_data.embeddings[i].embedding,
                color_embeddings,
                color_stats
            )

            -- Key by poem_index (globally unique across all categories)
            poem_colors[poem.poem_index] = {
                color = color,
                similarity = similarity,
                calculated_at = os.date("%Y-%m-%d %H:%M:%S")
            }

            processed_count = processed_count + 1

            -- Animate a single progress line instead of printing one every 100.
            -- Throttle by mode: under --debug (verbose) keep it sparse at every
            -- 100 so the durable log stays readable; on a live TTY redraw the bar
            -- more often (every 25) for smooth motion. The suffix shows the most
            -- recent poem's assigned color, as the old line did.
            local step = (progress.mode() == 2) and 100 or 25
            if processed_count % step == 0 then
                progress.update("   🎨 Semantic colors", processed_count, total_poems,
                    string.format("poem_index %d = %s", poem.poem_index, color))
            end
        end
    end
    -- Final frame at the true count (the throttle above can stop short of it),
    -- then close the animated line so later output starts on a fresh row.
    progress.update("   🎨 Semantic colors", processed_count, total_poems, "done")
    progress.finish()
    
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
        
        -- Issue 10-003: Use unified config instead of semantic-colors.json
        local poems_file = utils.asset_path("poems.json")
        local embeddings_file = utils.embeddings_dir() .. "/embeddings.json"
        local color_embeddings_file = utils.embeddings_dir() .. "/color_embeddings.json"
        local poem_colors_file = utils.embeddings_dir() .. "/poem_colors.json"

        -- Color configuration from unified config
        local color_config = {
            color_names = unified_config.color_names,
            semantic_colors = unified_config.semantic_colors
        }
        if not color_config.color_names then
            utils.log_error("Failed to load color_names from unified config")
            return
        end
        
        if choice == "1" or choice == "3" then
            print("Generating color embeddings...")
            local color_embeddings = M.generate_color_embeddings(
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