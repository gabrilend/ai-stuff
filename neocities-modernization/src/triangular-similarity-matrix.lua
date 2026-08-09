#!/usr/bin/env luajit

-- [DEPRECATED / DEAD CODE / PRUNE CANDIDATE] -- whole file. Issue 10-060.
--
-- Nothing references this module. Verified 2026-08-08 by grepping every entry
-- point the project has -- Lua `require`s, the inline `luajit -e` blocks inside
-- the .sh scripts, and run.sh's stage dispatch -- across the entire tree. The
-- only hits for the name are a SIMILARLY-NAMED FUNCTION living inside
-- src/similarity-engine.lua (`calculate_triangular_similarity_matrix`), which is
-- a different thing and is itself marked dead there.
--
-- Superseded by the GPU similarity path (Issue 10-057), which removed the CPU
-- route entirely: run.sh now hard-errors when libvkcompute.so is missing rather
-- than falling back to CPU code like this.
--
-- Before deleting, re-run that same exhaustive grep. Issue 10-060 records why
-- that matters: a previous cleanup deleted similarity-engine.lua as "CPU
-- similarity code" without noticing it was ALSO the embedding generator, and the
-- next full regeneration failed at stage 6.
--
-- Original description follows.
--
-- Triangular Similarity Matrix Generator (Issue 5-025)
-- Generates space-efficient triangular similarity matrix
-- Only stores upper triangle: for i < j, store matrix[i][j]
-- Exploits symmetry: similarity(A,B) = similarity(B,A)
-- Storage reduction: ~50% (30.4M entries instead of 60.8M)

local DIR = DIR or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
package.path = DIR .. '/libs/?.lua;' .. package.path

local utils = require('utils')
local dkjson = require('dkjson')

local M = {}

-- {{{ local function cosine_similarity
local function cosine_similarity(vec1, vec2)
    if not vec1 or not vec2 or #vec1 == 0 or #vec2 == 0 then
        return 0.0
    end

    if #vec1 ~= #vec2 then
        utils.log_error(string.format("Vector dimension mismatch: %d vs %d", #vec1, #vec2))
        return 0.0
    end

    local dot_product = 0.0
    local norm1 = 0.0
    local norm2 = 0.0

    for i = 1, #vec1 do
        dot_product = dot_product + (vec1[i] * vec2[i])
        norm1 = norm1 + (vec1[i] * vec1[i])
        norm2 = norm2 + (vec2[i] * vec2[i])
    end

    local magnitude = math.sqrt(norm1) * math.sqrt(norm2)
    if magnitude == 0 then
        return 0.0
    end

    return dot_product / magnitude
end
-- }}}

-- {{{ function M.generate_triangular_matrix
-- @param embeddings_file: path to embeddings JSON file
-- @param output_file: path to write triangular matrix JSON
-- @param force_regenerate: if true, overwrite existing file
-- @param progress_callback: optional function(current, total) for progress updates
-- @return success boolean, stats table
function M.generate_triangular_matrix(embeddings_file, output_file, force_regenerate, progress_callback)
    force_regenerate = force_regenerate or false

    -- Check if matrix already exists
    if not force_regenerate and utils.file_exists(output_file) then
        local existing_data = utils.read_json_file(output_file)
        if existing_data and existing_data.metadata and existing_data.metadata.is_complete then
            utils.log_info("✅ Triangular similarity matrix already exists and is complete")
            return true, {exists = true}
        end
    end

    utils.log_info("🔺 Generating triangular similarity matrix...")
    utils.log_info("   Algorithm: Upper triangle only (i < j)")
    utils.log_info("   Storage optimization: ~50% size reduction via symmetry")

    -- Load embeddings
    local embeddings_data = utils.read_json_file(embeddings_file)
    if not embeddings_data or not embeddings_data.embeddings then
        utils.log_error("Failed to load embeddings from " .. embeddings_file)
        return false, {error = "embeddings_load_failed"}
    end

    local embeddings = embeddings_data.embeddings
    local valid_embeddings = {}

    -- Filter and index embeddings by ID
    for _, embedding in ipairs(embeddings) do
        if embedding.embedding and #embedding.embedding > 0 and embedding.id then
            valid_embeddings[tonumber(embedding.id)] = embedding
        end
    end

    if next(valid_embeddings) == nil then
        utils.log_error("No valid embeddings found")
        return false, {error = "no_valid_embeddings"}
    end

    -- Get sorted poem IDs for consistent ordering
    local poem_ids = {}
    for id, _ in pairs(valid_embeddings) do
        table.insert(poem_ids, id)
    end
    table.sort(poem_ids)

    local num_poems = #poem_ids
    local total_comparisons = (num_poems * (num_poems - 1)) / 2  -- Upper triangle only
    local completed_comparisons = 0
    local start_time = os.time()

    utils.log_info(string.format("Processing %d poems for triangular matrix", num_poems))
    utils.log_info(string.format("Total comparisons: %.1fM (vs %.1fM for full matrix)",
        total_comparisons / 1000000, (num_poems * num_poems) / 1000000))

    -- Initialize triangular matrix
    local triangular_matrix = {
        metadata = {
            is_complete = true,
            total_poems = num_poems,
            matrix_type = "upper_triangular",
            total_comparisons = total_comparisons,
            algorithm = "cosine_similarity",
            model_name = embeddings_data.metadata.embedding_model or "unknown",
            generated_at = os.date("%Y-%m-%d %H:%M:%S"),
            storage_optimization = "50% reduction via symmetry"
        },
        similarities = {}
    }

    -- Generate ONLY upper triangle (i < j)
    for i = 1, num_poems do
        local poem_i_id = poem_ids[i]
        local poem_i = valid_embeddings[poem_i_id]
        triangular_matrix.similarities[tostring(poem_i_id)] = {}

        -- Progress indicator (carriage return overwrites)
        io.write(string.format("\r[INFO] Processing poem %d/%d (ID: %d)          ",
            i, num_poems, poem_i_id))
        io.flush()

        -- Only calculate for j > i (upper triangle)
        for j = i + 1, num_poems do
            local poem_j_id = poem_ids[j]
            local poem_j = valid_embeddings[poem_j_id]

            -- Calculate similarity
            local similarity = cosine_similarity(poem_i.embedding, poem_j.embedding)
            -- Round to 4 decimal places for storage efficiency
            local rounded_similarity = math.floor(similarity * 10000) / 10000

            triangular_matrix.similarities[tostring(poem_i_id)][tostring(poem_j_id)] = rounded_similarity
            completed_comparisons = completed_comparisons + 1
        end

        -- Progressive saving every 100 poems to prevent data loss
        if i % 100 == 0 then
            local elapsed = os.time() - start_time
            local rate = completed_comparisons / elapsed
            local remaining = (total_comparisons - completed_comparisons) / rate
            local progress_pct = (completed_comparisons / total_comparisons) * 100

            print()  -- Newline after the carriage-return line
            utils.log_info(string.format("Progress: %.2f%% (%.1fM/%.1fM comparisons)",
                progress_pct, completed_comparisons / 1000000, total_comparisons / 1000000))
            utils.log_info(string.format("Rate: %d comparisons/sec, Est. remaining: %d minutes",
                math.floor(rate), math.floor(remaining / 60)))

            -- Write intermediate checkpoint
            utils.write_json_file(output_file, triangular_matrix)
            utils.log_info("✅ Progress saved to disk")

            -- Call progress callback if provided
            if progress_callback then
                progress_callback(completed_comparisons, total_comparisons)
            end
        end
    end

    -- Final save
    print()  -- Newline after last carriage-return
    local success = utils.write_json_file(output_file, triangular_matrix)

    if success then
        local elapsed = os.time() - start_time
        utils.log_info("✅ Triangular similarity matrix generated successfully!")
        utils.log_info(string.format("Total comparisons: %.1fM", completed_comparisons / 1000000))
        utils.log_info(string.format("Time elapsed: %d minutes", math.floor(elapsed / 60)))
        utils.log_info(string.format("Output: %s", output_file))

        return true, {
            comparisons = completed_comparisons,
            poems = num_poems,
            elapsed_seconds = elapsed,
            output_file = output_file
        }
    else
        utils.log_error("Failed to write triangular matrix file")
        return false, {error = "write_failed"}
    end
end
-- }}}

-- {{{ function M.lookup_similarity
-- Lookup similarity from triangular matrix (handles symmetry)
-- @param matrix: triangular matrix data structure
-- @param id1: first poem ID
-- @param id2: second poem ID
-- @return similarity score (0.0 to 1.0)
function M.lookup_similarity(matrix, id1, id2)
    id1 = tostring(id1)
    id2 = tostring(id2)

    -- Handle self-similarity
    if id1 == id2 then
        return 1.0
    end

    -- Ensure consistent ordering for triangle lookup
    local min_id = id1
    local max_id = id2
    if tonumber(id1) > tonumber(id2) then
        min_id = id2
        max_id = id1
    end

    -- Look up in upper triangle
    if matrix.similarities and matrix.similarities[min_id] and matrix.similarities[min_id][max_id] then
        return matrix.similarities[min_id][max_id]
    end

    -- Fallback (should not happen with complete matrix)
    return 0.0
end
-- }}}

-- {{{ function M.get_all_similarities_for_poem
-- Get all similarities for a specific poem from triangular matrix
-- @param matrix: triangular matrix data structure
-- @param poem_id: the poem ID to get similarities for
-- @param all_poem_ids: list of all poem IDs in the matrix
-- @return array of {id, similarity} sorted by similarity (descending)
function M.get_all_similarities_for_poem(matrix, poem_id, all_poem_ids)
    local similarities = {}

    for _, other_id in ipairs(all_poem_ids) do
        if other_id ~= poem_id then
            local score = M.lookup_similarity(matrix, poem_id, other_id)
            table.insert(similarities, {id = other_id, similarity = score})
        end
    end

    -- Sort by similarity (descending)
    table.sort(similarities, function(a, b)
        return a.similarity > b.similarity
    end)

    return similarities
end
-- }}}

-- Command line execution
if arg and arg[0] then
    local embeddings_file = arg[1] or "assets/embeddings/embeddinggemma_latest/embeddings.json"
    local output_file = arg[2] or "assets/embeddings/embeddinggemma_latest/similarity_matrix_triangular.json"
    local force = arg[3] == "--force"

    print("Triangular Similarity Matrix Generator")
    print("Input:  " .. embeddings_file)
    print("Output: " .. output_file)
    print("Force:  " .. tostring(force))
    print()

    local success, stats = M.generate_triangular_matrix(embeddings_file, output_file, force)
    os.exit(success and 0 or 1)
end

return M
