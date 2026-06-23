-- Triangular Similarity Access Utility
-- Provides transparent access to triangular individual similarity files
-- Handles symmetric lookup: similarity(A,B) = similarity(B,A)
-- Storage format: each file contains only pairs where this_id < other_id

local utils = require('utils')
local dkjson = require('dkjson')

local M = {}

-- File cache to avoid repeated I/O during batch operations
local file_cache = {}
local MAX_CACHE_SIZE = 100
local cache_hits = 0
local cache_misses = 0

-- {{{ function M.get_similarity
-- @param poem_a: first poem ID
-- @param poem_b: second poem ID
-- @param embeddings_dir: optional directory path (default: derived from the currently selected inference model via inference-server-config)
-- @return similarity score (0.0 to 1.0)
function M.get_similarity(poem_a, poem_b, embeddings_dir)
    -- Handle self-similarity
    if poem_a == poem_b then
        return 1.0
    end

    -- Ensure triangular ordering (min_id < max_id)
    local min_id = math.min(tonumber(poem_a), tonumber(poem_b))
    local max_id = math.max(tonumber(poem_a), tonumber(poem_b))

    -- Default embeddings directory
    embeddings_dir = embeddings_dir or require("inference-server-config").get_selected_model():gsub("[^%w%-_.]", "_")

    -- Build file path for the smaller ID
    local file_path = string.format(
        "assets/embeddings/%s/similarities/poem_%d.json",
        embeddings_dir, min_id
    )

    -- Load file (with caching disabled for thread safety)
    local file_data = utils.read_json_file(file_path)
    if not file_data or not file_data.similarities then
        return 0.0
    end

    -- Search for the larger ID in the similarities array
    for _, entry in ipairs(file_data.similarities) do
        if tonumber(entry.id) == max_id then
            return entry.similarity
        end
    end

    -- Not found (shouldn't happen with complete data)
    return 0.0
end
-- }}}

-- {{{ function M.get_similarity_cached
-- Cached version for batch operations (NOT thread-safe)
-- @param poem_a: first poem ID
-- @param poem_b: second poem ID
-- @param embeddings_dir: optional directory path
-- @return similarity score (0.0 to 1.0)
function M.get_similarity_cached(poem_a, poem_b, embeddings_dir)
    if poem_a == poem_b then
        return 1.0
    end

    local min_id = math.min(tonumber(poem_a), tonumber(poem_b))
    local max_id = math.max(tonumber(poem_a), tonumber(poem_b))

    embeddings_dir = embeddings_dir or require("inference-server-config").get_selected_model():gsub("[^%w%-_.]", "_")

    -- Check cache first
    local cache_key = string.format("%s:%d", embeddings_dir, min_id)

    if not file_cache[cache_key] then
        -- Cache miss - load file
        cache_misses = cache_misses + 1

        local file_path = string.format(
            "assets/embeddings/%s/similarities/poem_%d.json",
            embeddings_dir, min_id
        )

        file_cache[cache_key] = utils.read_json_file(file_path)

        -- Evict oldest entry if cache full (simple FIFO)
        local cache_size = 0
        for _ in pairs(file_cache) do cache_size = cache_size + 1 end

        if cache_size > MAX_CACHE_SIZE then
            local oldest_key = next(file_cache)
            file_cache[oldest_key] = nil
        end
    else
        cache_hits = cache_hits + 1
    end

    local file_data = file_cache[cache_key]
    if not file_data or not file_data.similarities then
        return 0.0
    end

    -- Search for similarity
    for _, entry in ipairs(file_data.similarities) do
        if tonumber(entry.id) == max_id then
            return entry.similarity
        end
    end

    return 0.0
end
-- }}}

-- {{{ function M.get_all_similarities_for_poem
-- Get all similarities for a specific poem (collects from triangular storage)
-- This requires reading multiple files:
--   1. This poem's file (for higher IDs)
--   2. All lower-ID files that may reference this poem
-- @param poem_id: the poem to get similarities for
-- @param all_poem_ids: list of all valid poem IDs in corpus
-- @param embeddings_dir: optional directory path
-- @return array of {id, similarity} sorted by similarity (descending)
function M.get_all_similarities_for_poem(poem_id, all_poem_ids, embeddings_dir)
    poem_id = tonumber(poem_id)
    embeddings_dir = embeddings_dir or require("inference-server-config").get_selected_model():gsub("[^%w%-_.]", "_")

    local similarities = {}

    -- 1. Load this poem's file (contains similarities to higher IDs)
    local my_file_path = string.format(
        "assets/embeddings/%s/similarities/poem_%d.json",
        embeddings_dir, poem_id
    )

    local my_file = utils.read_json_file(my_file_path)
    if my_file and my_file.similarities then
        for _, entry in ipairs(my_file.similarities) do
            table.insert(similarities, {
                id = tonumber(entry.id),
                similarity = entry.similarity
            })
        end
    end

    -- 2. Check all lower-ID files for references to this poem
    for _, other_id in ipairs(all_poem_ids) do
        other_id = tonumber(other_id)
        if other_id < poem_id then
            local their_file_path = string.format(
                "assets/embeddings/%s/similarities/poem_%d.json",
                embeddings_dir, other_id
            )

            local their_file = utils.read_json_file(their_file_path)
            if their_file and their_file.similarities then
                for _, entry in ipairs(their_file.similarities) do
                    if tonumber(entry.id) == poem_id then
                        table.insert(similarities, {
                            id = other_id,
                            similarity = entry.similarity
                        })
                        break
                    end
                end
            end
        end
    end

    -- Sort by similarity (descending)
    table.sort(similarities, function(a, b)
        return a.similarity > b.similarity
    end)

    return similarities
end
-- }}}

-- {{{ function M.clear_cache
-- Clear the file cache (useful between operations or for memory management)
function M.clear_cache()
    file_cache = {}
    cache_hits = 0
    cache_misses = 0
end
-- }}}

-- {{{ function M.get_cache_stats
-- Get cache performance statistics
-- @return table with {hits, misses, hit_rate, cache_size}
function M.get_cache_stats()
    local cache_size = 0
    for _ in pairs(file_cache) do cache_size = cache_size + 1 end

    local total_requests = cache_hits + cache_misses
    local hit_rate = total_requests > 0 and (cache_hits / total_requests) or 0

    return {
        hits = cache_hits,
        misses = cache_misses,
        hit_rate = hit_rate,
        cache_size = cache_size,
        max_cache_size = MAX_CACHE_SIZE
    }
end
-- }}}

return M
