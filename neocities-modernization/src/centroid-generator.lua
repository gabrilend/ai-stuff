#!/usr/bin/env lua

-- Centroid Generator
-- Generates custom embedding centroids from user-defined source files and keywords.
-- These centroids serve as alternative starting points for similarity/diversity exploration,
-- allowing users to discover poems by mood or theme rather than by existing poem.
--
-- The generator reads assets/centroids.json, embeds each centroid's combined content,
-- and outputs the results to assets/embeddings/{model}/centroids.json for use by
-- the HTML generator.

-- {{{ local function setup_dir_path
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

-- Script configuration
local DIR = setup_dir_path()

-- Load required libraries
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path
local utils = require("utils")
local dkjson = require("dkjson")
local inference_config = require("inference-server-config")
-- Issue 10-050: shared chunker + batched embedding primitive replace this file's
-- own recursive binary-split chunker and per-chunk curl. endpoint + prompt
-- formatter are threaded in so fuzzy-computing's separate config instance is
-- never consulted for server selection.
local fuzzy = require("fuzzy-computing")
local text_chunking = require("text-chunking")

-- Issue 10-003: Load unified config from config.lua
local config_loader = require("config-loader")
config_loader.set_project_root(DIR)
local unified_config = config_loader.load()

-- Initialize asset path configuration
utils.init_assets_root(arg)

local M = {}

-- {{{ Configuration
-- Issue 10-003: centroids now loaded from unified config
-- model_name is the GGUF-style identifier the inference server expects (e.g. qwen3-embedding:4b).
-- model_storage_name is its sanitized-for-filesystem form (e.g. qwen3-embedding_4b).
-- embedding_dimensions is read from the loaded embeddings.json metadata so a
-- model swap doesn't require code changes; this CONFIG.dimensions is only
-- used as a sanity hint for log lines.
local _selected_model = inference_config.get_selected_model()
local CONFIG = {
    model_name = _selected_model,
    model_storage_name = _selected_model:gsub("[^%w%-_.]", "_"),
    embedding_dimensions = nil,  -- resolved at runtime from embeddings.json metadata
    max_content_length = 20000,
    min_content_length = 10
}
-- }}}

-- {{{ local function generate_embedding_with_chunking
-- Issue 10-050: embeds a centroid's combined text and returns the LIST of its
-- per-chunk vectors (calculate_ultra_centroid below folds them into one
-- normalized centroid). This replaced three things at once: a bespoke single-
-- input curl (generate_embedding), a paragraph/line split-point finder
-- (find_safe_split_point), and a recursive binary chunker. All three are now the
-- shared chunker (text-chunking.lua) plus ONE batched request covering every
-- chunk of the centroid. The `depth` parameter is kept for call-site
-- compatibility but is no longer used (chunking is no longer recursive here).
local function generate_embedding_with_chunking(text, endpoint, depth)
    -- Exact token-aware chunking (Issue 10-050): size each chunk by the model's
    -- real tokenizer (via /tokenize) so it fits the context with no truncation,
    -- exactly as the poem path does. Raises if /tokenize is unreachable — no
    -- silent fallback, since the embed call would fail next anyway.
    local count_fn = fuzzy.make_token_counter(endpoint)
    local max_tokens = fuzzy.embedding_chunk_budget(endpoint, inference_config.format_embedding_prompt)
    local chunks = text_chunking.chunk_text_by_tokens(text, count_fn, max_tokens)
    if #chunks == 0 then
        utils.log_error("Centroid text produced no chunks (empty after preprocessing)")
        return nil, "empty_text"
    end

    -- All chunks of this centroid embed in one request. endpoint + prompt
    -- formatter are passed so the centroid shares the poems' embedding space.
    local vectors, err = fuzzy.get_embeddings_batch(
        chunks, CONFIG.model_name, endpoint, inference_config.format_embedding_prompt)
    if not vectors then
        utils.log_error("Centroid embedding batch failed: " .. tostring(err))
        return nil, err or "batch_failed"
    end

    local all_embeddings = {}
    for i = 1, #chunks do
        local v = vectors[i]
        if type(v) == "table" and #v > 0 then
            table.insert(all_embeddings, v)
            -- Learn the model's dimension from the first real vector (matches
            -- the old behavior; CONFIG.embedding_dimensions is a logging hint).
            if not CONFIG.embedding_dimensions then
                CONFIG.embedding_dimensions = #v
            end
        else
            utils.log_warn(string.format("  Missing vector for centroid chunk %d/%d", i, #chunks))
        end
    end

    if #all_embeddings == 0 then
        return nil, "no_embeddings_generated"
    end
    return all_embeddings, "success"
end
-- }}}

-- {{{ local function calculate_ultra_centroid
-- Combines multiple chunk embeddings into a single normalized centroid
local function calculate_ultra_centroid(chunk_embeddings)
    if not chunk_embeddings or #chunk_embeddings == 0 then
        return nil
    end

    -- If only one embedding, just normalize and return it
    if #chunk_embeddings == 1 then
        local embedding = chunk_embeddings[1]
        local magnitude = 0
        for i = 1, #embedding do
            magnitude = magnitude + embedding[i] * embedding[i]
        end
        magnitude = math.sqrt(magnitude)

        local normalized = {}
        for i = 1, #embedding do
            normalized[i] = embedding[i] / magnitude
        end
        return normalized
    end

    local dim = #chunk_embeddings[1]
    local centroid = {}

    -- Initialize with zeros
    for i = 1, dim do
        centroid[i] = 0
    end

    -- Sum all chunk embeddings
    -- Note: Division by count before normalization is unnecessary because
    -- normalization rescales to unit length regardless of input magnitude.
    -- See Issue 9-003 for mathematical proof of cosine scale-invariance.
    for _, embedding in ipairs(chunk_embeddings) do
        for i = 1, dim do
            centroid[i] = centroid[i] + embedding[i]
        end
    end

    -- Normalize to unit length (makes any prior scaling irrelevant)
    local magnitude = 0
    for i = 1, dim do
        magnitude = magnitude + centroid[i] * centroid[i]
    end
    magnitude = math.sqrt(magnitude)

    if magnitude > 0 then
        for i = 1, dim do
            centroid[i] = centroid[i] / magnitude
        end
    end

    return centroid
end
-- }}}

-- {{{ local function load_source_files
-- Reads and concatenates content from source file paths
local function load_source_files(file_paths)
    local contents = {}

    for _, filepath in ipairs(file_paths or {}) do
        local content, err = utils.read_file(filepath)
        if content then
            table.insert(contents, content)
            utils.log_info("  Loaded source file: " .. filepath .. " (" .. #content .. " chars)")
        else
            utils.log_warn("  Could not load source file: " .. filepath .. " - " .. (err or "unknown error"))
        end
    end

    return table.concat(contents, "\n\n")
end
-- }}}

-- {{{ local function build_centroid_text
-- Combines source file contents and keywords into a single text for embedding
local function build_centroid_text(centroid_def)
    local parts = {}

    -- Add source file contents
    local file_content = load_source_files(centroid_def.source_files)
    if #file_content > 0 then
        table.insert(parts, file_content)
    end

    -- Add keywords as natural phrases
    if centroid_def.keywords and #centroid_def.keywords > 0 then
        local keywords_text = table.concat(centroid_def.keywords, "\n")
        table.insert(parts, keywords_text)
    end

    return table.concat(parts, "\n\n")
end
-- }}}

-- {{{ local function generate_centroid_embedding
-- Main function to generate a single centroid's embedding
local function generate_centroid_embedding(centroid_def, endpoint)
    utils.log_info("Processing centroid: " .. centroid_def.name)

    -- Build combined text
    local combined_text = build_centroid_text(centroid_def)

    if #combined_text < CONFIG.min_content_length then
        utils.log_error("  Combined content too short (" .. #combined_text .. " chars) - need at least " .. CONFIG.min_content_length)
        return nil, "content_too_short"
    end

    utils.log_info("  Combined content: " .. #combined_text .. " chars")

    -- Generate embeddings (with chunking if needed)
    local chunk_embeddings, status = generate_embedding_with_chunking(combined_text, endpoint)

    if not chunk_embeddings then
        utils.log_error("  Failed to generate embeddings: " .. (status or "unknown"))
        return nil, status
    end

    utils.log_info("  Generated " .. #chunk_embeddings .. " chunk embedding(s)")

    -- Calculate ultra-centroid
    local centroid_vector = calculate_ultra_centroid(chunk_embeddings)

    if not centroid_vector then
        utils.log_error("  Failed to calculate ultra-centroid")
        return nil, "centroid_calculation_failed"
    end

    utils.log_info("  Ultra-centroid calculated successfully")

    return {
        name = centroid_def.name,
        description = centroid_def.description,
        output_slug = centroid_def.output_slug,
        embedding = centroid_vector,
        chunk_count = #chunk_embeddings,
        content_length = #combined_text,
        generated_at = utils.get_timestamp()
    }, "success"
end
-- }}}

-- {{{ function M.generate_all_centroids
-- Processes all centroids defined in the config file
function M.generate_all_centroids(options)
    options = options or {}

    -- Check inference server availability
    local endpoint = inference_config.build_host_url()
    utils.log_info("Using inference endpoint: " .. endpoint)

    -- Verify endpoint is reachable. /v1/models is llama.cpp's OpenAI-
    -- compatible liveness probe (was /api/tags under Ollama).
    local test_cmd = "curl -s --max-time 5 " .. endpoint .. "/v1/models > /dev/null 2>&1"
    local test_result = os.execute(test_cmd)
    if test_result ~= 0 and test_result ~= true then
        utils.log_error("Cannot reach the inference endpoint: " .. endpoint)
        utils.log_error("Please ensure the inference server is running and accessible.")
        return nil, "inference_unavailable"
    end

    -- Issue 10-003: Load centroids from unified config instead of assets/centroids.json
    local centroids_list = unified_config.centroids
    if not centroids_list or #centroids_list == 0 then
        utils.log_error("No centroids defined in config.lua")
        return nil, "config_parse_error"
    end

    utils.log_info("Found " .. #centroids_list .. " centroid definition(s)")

    -- Process each centroid
    local results = {
        centroids = {},
        metadata = {
            model = CONFIG.model_name,
            dimensions = CONFIG.embedding_dimensions,
            generated_at = utils.get_timestamp(),
            source_config = "config.lua"
        }
    }

    local success_count = 0
    local error_count = 0

    for i, centroid_def in ipairs(centroids_list) do
        utils.log_info(string.format("\n[%d/%d] Processing: %s", i, #centroids_list, centroid_def.name))

        local result, status = generate_centroid_embedding(centroid_def, endpoint)

        if result then
            results.centroids[centroid_def.output_slug] = result
            success_count = success_count + 1
        else
            error_count = error_count + 1
            utils.log_error("  Skipping centroid due to error: " .. (status or "unknown"))
        end
    end

    utils.log_info(string.format("\nGeneration complete: %d succeeded, %d failed", success_count, error_count))

    -- Determine output path
    -- Use model_storage_name to match existing directory structure
    local assets_root = utils.get_assets_root()
    local output_dir = assets_root .. "/embeddings/" .. CONFIG.model_storage_name
    os.execute("mkdir -p " .. output_dir)

    local output_file = output_dir .. "/centroids.json"

    -- Save results
    local json_output = dkjson.encode(results, {indent = true})
    local write_success, write_err = utils.write_file(output_file, json_output)

    if not write_success then
        utils.log_error("Failed to save centroids: " .. (write_err or "unknown"))
        return nil, "write_error"
    end

    utils.log_info("Centroids saved to: " .. output_file)

    return results, "success"
end
-- }}}

-- {{{ Main execution
if arg and arg[0] and arg[0]:match("centroid%-generator%.lua$") then
    utils.log_info("=== Centroid Generator ===")
    utils.log_info("Generating custom mood/theme centroids for exploration pages")
    utils.log_info("")

    local results, status = M.generate_all_centroids()

    if results then
        utils.log_info("\n=== Summary ===")
        local count = 0
        for slug, data in pairs(results.centroids) do
            count = count + 1
            utils.log_info(string.format("  %s: %s (%d chunks)", slug, data.name, data.chunk_count))
        end
        utils.log_info(string.format("Total: %d centroids generated", count))
    else
        utils.log_error("Centroid generation failed: " .. (status or "unknown"))
        os.exit(1)
    end
end
-- }}}

return M
