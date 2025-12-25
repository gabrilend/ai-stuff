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
local ollama_config = require("ollama-config")

-- Initialize asset path configuration
utils.init_assets_root(arg)

local M = {}

-- {{{ Configuration
-- Note: model_storage_name must match the existing embeddings directory casing (EmbeddingGemma_latest)
-- while model_name is what Ollama expects (embeddinggemma:latest)
local CONFIG = {
    centroids_config_file = DIR .. "/assets/centroids.json",
    model_name = "embeddinggemma:latest",
    model_storage_name = "EmbeddingGemma_latest",
    embedding_dimensions = 768,
    -- Approximate max characters before chunking is needed
    -- embeddinggemma handles ~8k tokens, roughly 32k chars, but we stay conservative
    max_content_length = 20000,
    -- Minimum content length to attempt embedding (skip if too short)
    min_content_length = 10
}
-- }}}

-- {{{ local function generate_embedding
-- Sends text to Ollama and returns the embedding vector
local function generate_embedding(text, endpoint)
    local temp_file = "/tmp/centroid_embedding_input.json"
    local payload = {
        model = CONFIG.model_name,
        input = text
    }

    local f = io.open(temp_file, "w")
    if not f then
        utils.log_error("Failed to create temporary file")
        return nil, "file_error"
    end
    f:write(dkjson.encode(payload))
    f:close()

    local cmd = string.format(
        'curl -s --connect-timeout 10 --max-time 60 "%s/api/embed" -H "Content-Type: application/json" -d @%s',
        endpoint, temp_file
    )

    local handle = io.popen(cmd)
    local result = handle:read("*a")
    local success, exit_type, exit_code = handle:close()

    os.remove(temp_file)

    if not success or exit_code ~= 0 then
        utils.log_error("Network error: curl failed with exit code " .. (exit_code or "unknown"))
        return nil, "network_error"
    end

    if not result or result:match("^%s*$") then
        utils.log_error("Empty response from API endpoint")
        return nil, "empty_response"
    end

    if result:match("curl:") or result:match("Could not resolve host") or result:match("Connection refused") then
        utils.log_error("Connection error: " .. result:gsub("\n", " "))
        return nil, "connection_error"
    end

    local parsed = dkjson.decode(result)
    if parsed and parsed.embeddings and parsed.embeddings[1] then
        local embedding = parsed.embeddings[1]
        if type(embedding) == "table" and #embedding == CONFIG.embedding_dimensions then
            return embedding, "success"
        else
            utils.log_error("Invalid embedding dimensions: expected " .. CONFIG.embedding_dimensions .. ", got " .. (#embedding or "unknown"))
            return nil, "invalid_dimensions"
        end
    else
        utils.log_error("Failed to parse API response: " .. (result:sub(1, 200) or "nil"))
        return nil, "parse_error"
    end
end
-- }}}

-- {{{ local function find_safe_split_point
-- Finds the nearest paragraph or line break to the target position
-- Never splits in the middle of a word or sentence if possible
local function find_safe_split_point(text, target_pos)
    -- Look for double newline (paragraph break) within 500 chars of target
    local search_start = math.max(1, target_pos - 500)
    local search_end = math.min(#text, target_pos + 500)
    local search_region = text:sub(search_start, search_end)

    -- Find paragraph break closest to midpoint of search region
    local para_break = search_region:find("\n\n")
    if para_break then
        return search_start + para_break
    end

    -- Fallback: find single newline
    local line_break = search_region:find("\n")
    if line_break then
        return search_start + line_break
    end

    -- Last resort: split at target position
    return target_pos
end
-- }}}

-- {{{ local function generate_embedding_with_chunking
-- Recursively chunks long text and generates embeddings for each chunk
-- Returns a list of embeddings that will be combined into an ultra-centroid
local function generate_embedding_with_chunking(text, endpoint, depth)
    depth = depth or 0
    local max_depth = 5  -- Prevent infinite recursion

    if depth > max_depth then
        utils.log_error("Maximum chunking depth exceeded - text may be too long or have no valid split points")
        return nil, "max_depth_exceeded"
    end

    -- If text is short enough, try to embed directly
    if #text <= CONFIG.max_content_length then
        local embedding, status = generate_embedding(text, endpoint)
        if embedding then
            return {embedding}, "success"
        end

        -- If embedding failed but not due to length, propagate error
        if status ~= "context_length" and status ~= "parse_error" then
            return nil, status
        end

        -- Content might still be too long for the model - try chunking
        utils.log_info("  Content may exceed model context, attempting to chunk...")
    end

    -- Text is too long - split and recurse
    local midpoint = math.floor(#text / 2)
    local split_point = find_safe_split_point(text, midpoint)

    local chunk_a = text:sub(1, split_point - 1)
    local chunk_b = text:sub(split_point)

    -- Trim whitespace from chunks
    chunk_a = chunk_a:match("^%s*(.-)%s*$") or ""
    chunk_b = chunk_b:match("^%s*(.-)%s*$") or ""

    if #chunk_a < CONFIG.min_content_length and #chunk_b < CONFIG.min_content_length then
        utils.log_error("Both chunks too short after splitting")
        return nil, "chunks_too_short"
    end

    utils.log_info(string.format("  Splitting at depth %d: chunk A = %d chars, chunk B = %d chars",
        depth, #chunk_a, #chunk_b))

    local all_embeddings = {}

    -- Process chunk A if it has content
    if #chunk_a >= CONFIG.min_content_length then
        local embeddings_a, status_a = generate_embedding_with_chunking(chunk_a, endpoint, depth + 1)
        if embeddings_a then
            for _, e in ipairs(embeddings_a) do
                table.insert(all_embeddings, e)
            end
        else
            utils.log_warn("  Failed to embed chunk A: " .. (status_a or "unknown"))
        end
    end

    -- Process chunk B if it has content
    if #chunk_b >= CONFIG.min_content_length then
        local embeddings_b, status_b = generate_embedding_with_chunking(chunk_b, endpoint, depth + 1)
        if embeddings_b then
            for _, e in ipairs(embeddings_b) do
                table.insert(all_embeddings, e)
            end
        else
            utils.log_warn("  Failed to embed chunk B: " .. (status_b or "unknown"))
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

    -- Check Ollama availability
    local endpoint = ollama_config.OLLAMA_ENDPOINT
    utils.log_info("Using Ollama endpoint: " .. endpoint)

    -- Verify endpoint is reachable
    local test_cmd = "curl -s --max-time 5 " .. endpoint .. "/api/tags > /dev/null 2>&1"
    local test_result = os.execute(test_cmd)
    if test_result ~= 0 and test_result ~= true then
        utils.log_error("Cannot reach Ollama endpoint: " .. endpoint)
        utils.log_error("Please ensure Ollama is running and accessible.")
        return nil, "ollama_unavailable"
    end

    -- Load centroids config
    local config_content, err = utils.read_file(CONFIG.centroids_config_file)
    if not config_content then
        utils.log_error("Failed to read centroids config: " .. (err or "unknown"))
        return nil, "config_read_error"
    end

    local config = dkjson.decode(config_content)
    if not config or not config.centroids then
        utils.log_error("Invalid centroids config format")
        return nil, "config_parse_error"
    end

    utils.log_info("Found " .. #config.centroids .. " centroid definition(s)")

    -- Process each centroid
    local results = {
        centroids = {},
        metadata = {
            model = CONFIG.model_name,
            dimensions = CONFIG.embedding_dimensions,
            generated_at = utils.get_timestamp(),
            source_config = CONFIG.centroids_config_file
        }
    }

    local success_count = 0
    local error_count = 0

    for i, centroid_def in ipairs(config.centroids) do
        utils.log_info(string.format("\n[%d/%d] Processing: %s", i, #config.centroids, centroid_def.name))

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
