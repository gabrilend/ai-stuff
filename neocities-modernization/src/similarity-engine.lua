#!/usr/bin/env lua

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
local poem_extractor = require("poem-extractor")

local M = {}

-- {{{ Model configurations
local embedding_models = {
    ["embeddinggemma:latest"] = {
        dimensions = 768,
        endpoint_path = "/api/embed",
        timeout = 30
    },
    ["text-embedding-ada-002"] = {
        dimensions = 1536,
        endpoint_path = "/v1/embeddings",
        timeout = 60
    },
    ["all-MiniLM-L6-v2"] = {
        dimensions = 384,
        endpoint_path = "/api/embed",
        timeout = 20
    }
}
-- }}}

-- {{{ local function get_model_storage_path
local function get_model_storage_path(base_dir, model_name)
    -- Sanitize model name for filesystem
    local safe_model_name = model_name:gsub("[^%w%-_.]", "_")
    local model_dir = base_dir .. "/embeddings/" .. safe_model_name
    
    -- Create directory if it doesn't exist
    os.execute("mkdir -p " .. model_dir)
    
    return {
        embeddings = model_dir .. "/embeddings.json",
        similarity_matrix = model_dir .. "/similarity_matrix.json",
        metadata = model_dir .. "/metadata.json"
    }
end
-- }}}

-- {{{ local function cosine_similarity
local function cosine_similarity(vec1, vec2)
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
        return 0
    end
    
    return dot_product / (norm1 * norm2)
end
-- }}}

-- {{{ local function generate_embedding
local function generate_embedding(text, endpoint)
    -- Create a temporary file to avoid shell escaping issues
    local temp_file = "/tmp/embedding_input.json"
    local payload = {
        model = "embeddinggemma:latest",
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
        'curl -s --connect-timeout 10 --max-time 30 "%s/api/embed" -H "Content-Type: application/json" -d @%s',
        endpoint, temp_file
    )
    
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    local success, exit_type, exit_code = handle:close()
    
    -- Clean up temp file
    os.remove(temp_file)
    
    -- Check for network/connection errors
    if not success or exit_code ~= 0 then
        utils.log_error("Network error: curl failed with exit code " .. (exit_code or "unknown"))
        return nil, "network_error"
    end
    
    -- Check for empty or invalid response
    if not result or result:match("^%s*$") then
        utils.log_error("Empty response from API endpoint")
        return nil, "empty_response"
    end
    
    -- Check for curl error messages
    if result:match("curl:") or result:match("Could not resolve host") or result:match("Connection refused") then
        utils.log_error("Connection error: " .. result:gsub("\n", " "))
        return nil, "connection_error"
    end
    
    local parsed = dkjson.decode(result)
    if parsed and parsed.embeddings and parsed.embeddings[1] then
        -- Validate embedding dimensions
        local embedding = parsed.embeddings[1]
        if type(embedding) == "table" and #embedding == 768 then
            return embedding, "success"
        else
            utils.log_error("Invalid embedding dimensions: " .. (#embedding or "unknown"))
            return nil, "invalid_dimensions"
        end
    else
        utils.log_error("Failed to parse API response: " .. (result:sub(1, 200) or "nil"))
        return nil, "parse_error"
    end
end
-- }}}

-- {{{ local function table_length
local function table_length(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end
-- }}}

-- {{{ local function generate_random_embedding
-- Generates a random 768-dimensional embedding for empty poems
-- Seeded by poem_id for reproducibility
local function generate_random_embedding(poem_id, dimension)
    dimension = dimension or 768

    -- Seed with poem_id for reproducibility
    local seed = type(poem_id) == "number" and poem_id or 12345
    math.randomseed(seed)

    local embedding = {}
    local norm = 0

    -- Generate random values
    for i = 1, dimension do
        embedding[i] = math.random() * 2 - 1  -- Range: -1 to 1
        norm = norm + embedding[i] * embedding[i]
    end

    -- Normalize to unit vector for consistent similarity calculations
    norm = math.sqrt(norm)
    if norm > 0 then
        for i = 1, dimension do
            embedding[i] = embedding[i] / norm
        end
    end

    return embedding
end
-- }}}

-- {{{ local network_error_config
local network_error_config = {
    max_consecutive_errors = 5,     -- Max consecutive network errors before abort
    max_total_errors = 20,          -- Max total network errors in session
    initial_retry_delay = 2,        -- Initial delay in seconds
    max_retry_delay = 60,           -- Maximum delay in seconds
    backoff_multiplier = 2          -- Exponential backoff multiplier
}
-- }}}

-- {{{ function migrate_legacy_cache
function migrate_legacy_cache(legacy_file, target_model_dir)
    if utils.file_exists(legacy_file) then
        utils.log_info("Migrating legacy cache to model-specific storage...")
        
        local backup_file = legacy_file .. ".legacy_backup"
        os.rename(legacy_file, backup_file)
        
        local legacy_data = utils.read_json_file(backup_file)
        if legacy_data then
            utils.write_json_file(target_model_dir .. "/embeddings.json", legacy_data)
            utils.log_info("Legacy cache migrated successfully")
        end
    end
end
-- }}}

-- {{{ function M.list_available_models
function M.list_available_models()
    utils.log_info("Available Embedding Models:")
    for model_name, config in pairs(embedding_models) do
        utils.log_info("  " .. model_name .. " (" .. config.dimensions .. " dims)")
    end
    return embedding_models
end
-- }}}

-- {{{ function M.get_model_status
function M.get_model_status(base_output_dir, model_name)
    model_name = model_name or "embeddinggemma:latest"
    local storage_paths = get_model_storage_path(base_output_dir, model_name)
    
    if utils.file_exists(storage_paths.embeddings) then
        local data = utils.read_json_file(storage_paths.embeddings)
        if data and data.embeddings then
            local count = 0
            for _ in pairs(data.embeddings) do
                count = count + 1
            end
            return {
                exists = true,
                count = count,
                location = storage_paths.embeddings,
                metadata = data.metadata
            }
        end
    end
    
    return {
        exists = false,
        count = 0,
        location = storage_paths.embeddings
    }
end
-- }}}

-- {{{ function M.show_all_model_status
function M.show_all_model_status(base_output_dir)
    utils.log_info("Available Embedding Models:")
    for model_name, config in pairs(embedding_models) do
        local status = M.get_model_status(base_output_dir, model_name)
        if status.exists then
            local completion_rate = status.metadata and status.metadata.completion_rate or 0
            utils.log_info("  " .. model_name .. " (" .. config.dimensions .. " dims) - " .. 
                          status.count .. " cached embeddings (" .. 
                          string.format("%.1f%%", completion_rate * 100) .. ")")
        else
            utils.log_info("  " .. model_name .. " (" .. config.dimensions .. " dims) - No cache found")
        end
    end
end
-- }}}

-- {{{ function M.generate_all_embeddings
function M.generate_all_embeddings(poems_file, base_output_dir, endpoint, incremental, model_name)
    endpoint = endpoint or ollama_config.OLLAMA_ENDPOINT
    incremental = incremental ~= false -- Default to true
    model_name = model_name or "embeddinggemma:latest"
    
    -- Get model-specific configuration
    local model_config = embedding_models[model_name]
    if not model_config then
        utils.log_error("Unknown embedding model: " .. model_name)
        return false
    end
    
    -- Generate model-specific file paths
    local storage_paths = get_model_storage_path(base_output_dir, model_name)
    local output_file = storage_paths.embeddings
    
    utils.log_info("Using embedding model: " .. model_name)
    utils.log_info("Storage location: " .. output_file)
    utils.log_info("Expected dimensions: " .. model_config.dimensions)
    
    -- Handle legacy cache migration
    local legacy_cache = base_output_dir .. "/embeddings.json" 
    if utils.file_exists(legacy_cache) and output_file ~= legacy_cache then
        migrate_legacy_cache(legacy_cache, base_output_dir .. "/embeddings/" .. model_name:gsub("[^%w%-_.]", "_"))
    end
    
    utils.log_info("Loading poems from: " .. poems_file)
    local poems_data = utils.read_json_file(poems_file)
    if not poems_data or not poems_data.poems then
        utils.log_error("Failed to load poems from " .. poems_file)
        return false
    end
    local poems = poems_data.poems
    
    -- Load existing embeddings if incremental mode enabled
    local existing_embeddings = {}
    local embeddings_data = {
        metadata = {
            total_poems = #poems,
            embedding_model = "embeddinggemma:latest",
            embedding_dimension = 768,
            generated_at = os.date("%Y-%m-%d %H:%M:%S"),
            endpoint = endpoint,
            incremental_update = incremental
        },
        embeddings = {}
    }
    
    if incremental and utils.file_exists(output_file) then
        utils.log_info("Incremental mode: Loading existing embeddings...")
        local existing_data = utils.read_json_file(output_file)
        if existing_data and existing_data.embeddings then
            -- Handle both array and object formats for existing embeddings
            if type(existing_data.embeddings) == "table" then
                if existing_data.embeddings[1] then
                    -- Array format (old format)
                    for i, emb in ipairs(existing_data.embeddings) do
                        if emb.id then
                            existing_embeddings[emb.id] = emb
                        end
                    end
                else
                    -- Object format (current format) - key-value pairs by index
                    for poem_index, emb in pairs(existing_data.embeddings) do
                        -- Store by poem index for efficient lookup
                        existing_embeddings[tonumber(poem_index)] = emb
                    end
                end
            end
            
            -- Preserve existing metadata
            if existing_data.metadata then
                embeddings_data.metadata.original_generated_at = existing_data.metadata.generated_at
                embeddings_data.metadata.previous_total = existing_data.metadata.total_poems
            end
            
            utils.log_info("Found " .. table_length(existing_embeddings) .. " existing embeddings")
        end
    end
    
    -- Count poems that need processing
    local poems_to_process = {}
    local skipped_count = 0
    local retry_count = 0
    local retry_reasons = {}
    
    for i, poem in ipairs(poems) do
        -- Only skip if embedding is valid AND dimensions are correct
        if incremental and existing_embeddings[i] and 
           existing_embeddings[i].embedding and
           type(existing_embeddings[i].embedding) == "table" and 
           #existing_embeddings[i].embedding == model_config.dimensions then
            -- Skip: valid embedding found
            embeddings_data.embeddings[i] = existing_embeddings[i]
            skipped_count = skipped_count + 1
        else
            -- Re-process: no embedding, invalid embedding, or error state
            table.insert(poems_to_process, {index = i, poem = poem})
            
            -- Track retry reasons for reporting
            if incremental and existing_embeddings[i] then
                if existing_embeddings[i].error then
                    retry_count = retry_count + 1
                    local error_type = existing_embeddings[i].error
                    retry_reasons[error_type] = (retry_reasons[error_type] or 0) + 1
                elseif existing_embeddings[i].embedding then
                    -- Invalid embedding dimensions
                    retry_count = retry_count + 1
                    retry_reasons["invalid_dimensions"] = (retry_reasons["invalid_dimensions"] or 0) + 1
                end
            end
        end
    end
    
    if incremental then
        utils.log_info("Incremental processing summary:")
        utils.log_info("  Total poems: " .. #poems)
        utils.log_info("  Valid existing embeddings: " .. skipped_count)
        
        -- Enhanced retry reporting
        if retry_count > 0 then
            local retry_details = {}
            for error_type, count in pairs(retry_reasons) do
                table.insert(retry_details, error_type .. ": " .. count)
            end
            utils.log_info("  Error entries to retry: " .. retry_count .. " (" .. table.concat(retry_details, ", ") .. ")")
        end
        
        local new_poems = #poems_to_process - retry_count
        if new_poems > 0 then
            utils.log_info("  New poems to process: " .. new_poems)
        end
        
        utils.log_info("  Processing queue: " .. #poems_to_process .. " poems" .. 
                      (retry_count > 0 and (" (" .. new_poems .. " new + " .. retry_count .. " retries)") or ""))
        utils.log_info("  Processing savings: " .. string.format("%.1f%%", (skipped_count / #poems) * 100))
        
        if #poems_to_process == 0 then
            utils.log_info("✅ All embeddings already exist and are valid!")
            embeddings_data.metadata.completed_embeddings = skipped_count
            embeddings_data.metadata.completion_rate = 1.0
            embeddings_data.metadata.processing_mode = "no_update_needed"
            return utils.write_json_file(output_file, embeddings_data)
        end
    else
        utils.log_info("Full regeneration mode: Processing all " .. #poems .. " poems...")
        for i, poem in ipairs(poems) do
            table.insert(poems_to_process, {index = i, poem = poem})
        end
    end
    
    local batch_size = 10
    local completed = skipped_count -- Start with existing embeddings
    
    -- Network error tracking
    local consecutive_errors = 0
    local total_errors = 0
    local current_delay = network_error_config.initial_retry_delay
    
    -- Write initial progress state (just counts, no timing)
    local user = os.getenv("USER") or "ritz"  -- fallback to ritz
    local progress_file = "/tmp/embedding_progress_" .. user .. ".txt"
    local initial_progress = string.format("%d,%d", completed, #poems)
    local pf = io.open(progress_file, "w")
    if pf then
        pf:write(initial_progress)
        pf:close()
    end
    
    for i = 1, #poems_to_process, batch_size do
        local batch_end = math.min(i + batch_size - 1, #poems_to_process)
        utils.log_info(string.format("Processing batch %d-%d of %d new/updated poems...", i, batch_end, #poems_to_process))
        
        for j = i, batch_end do
            local poem_data = poems_to_process[j]
            local poem = poem_data.poem
            local poem_index = poem_data.index
            local poem_text = poem_extractor.extract_pure_poem_content(poem.content)
            
            if poem_text == "" then
                -- Generate random embedding for empty poems to place them semi-randomly
                utils.log_info("Empty poem content for ID: " .. (poem.id or "unknown") .. " - generating random embedding")
                local random_embedding = generate_random_embedding(poem.id, model_config.dimensions)
                embeddings_data.embeddings[poem_index] = {
                    id = poem.id,
                    embedding = random_embedding,
                    content_length = 0,
                    is_random = true,  -- Flag indicating this is a synthetic embedding
                    generated_at = os.date("%Y-%m-%d %H:%M:%S"),
                    updated_at = os.date("%Y-%m-%d %H:%M:%S")
                }
                completed = completed + 1
            else
                utils.log_info("Generating embedding for poem " .. poem_index .. " (ID: " .. (poem.id or "unknown") .. ")")
                
                local embedding, error_type = generate_embedding(poem_text, endpoint)
                
                if embedding then
                    -- Success: save valid embedding and reset error counters
                    embeddings_data.embeddings[poem_index] = {
                        id = poem.id,
                        embedding = embedding,
                        content_length = #poem_text,
                        generated_at = os.date("%Y-%m-%d %H:%M:%S"),
                        updated_at = incremental and os.date("%Y-%m-%d %H:%M:%S") or nil
                    }
                    completed = completed + 1
                    consecutive_errors = 0  -- Reset on success
                    current_delay = network_error_config.initial_retry_delay  -- Reset delay
                    
                    -- Write simple progress for bash script monitoring (just counts)
                    local user = os.getenv("USER") or "ritz"  -- fallback to ritz
                    local progress_file = "/tmp/embedding_progress_" .. user .. ".txt"
                    local progress_data = string.format("%d,%d", completed, #poems)
                    local pf = io.open(progress_file, "w")
                    if pf then
                        pf:write(progress_data)
                        pf:close()
                    end
                elseif error_type == "network_error" or error_type == "connection_error" or error_type == "empty_response" then
                    -- Network errors: implement retry logic with exponential backoff
                    consecutive_errors = consecutive_errors + 1
                    total_errors = total_errors + 1
                    
                    utils.log_warn(string.format("Network error %d/%d for poem %d: %s", 
                                                consecutive_errors, network_error_config.max_consecutive_errors, 
                                                poem_index, error_type))
                    
                    if consecutive_errors >= network_error_config.max_consecutive_errors then
                        utils.log_error("❌ NETWORK ERROR THRESHOLD EXCEEDED")
                        utils.log_error("")
                        utils.log_error("Processing terminated due to persistent network connectivity issues:")
                        utils.log_error("  • Consecutive errors: " .. consecutive_errors .. "/" .. network_error_config.max_consecutive_errors .. " (threshold exceeded)")
                        utils.log_error("  • Total session errors: " .. total_errors .. "/" .. network_error_config.max_total_errors)
                        utils.log_error("  • Poems processed before termination: " .. completed .. "/" .. #poems)
                        utils.log_error("  • Last attempted poem: " .. poem_index)
                        utils.log_error("")
                        utils.log_error("The embedding cache has been preserved.")
                        utils.log_error("Restart the process when network connectivity is restored.")
                        
                        -- Save progress before termination
                        embeddings_data.metadata.completed_embeddings = completed
                        embeddings_data.metadata.completion_rate = completed / #poems
                        embeddings_data.metadata.processing_mode = "terminated_network_error"
                        embeddings_data.metadata.termination_reason = "consecutive_network_errors"
                        embeddings_data.metadata.last_error_count = consecutive_errors
                        utils.write_json_file(output_file, embeddings_data)
                        
                        return false
                    elseif total_errors >= network_error_config.max_total_errors then
                        utils.log_error("❌ TOTAL ERROR LIMIT EXCEEDED")
                        utils.log_error("Too many network errors in this session: " .. total_errors .. "/" .. network_error_config.max_total_errors)
                        return false
                    else
                        -- Retry with exponential backoff
                        utils.log_info("Retrying in " .. current_delay .. " seconds...")
                        os.execute("sleep " .. current_delay)
                        current_delay = math.min(current_delay * network_error_config.backoff_multiplier, 
                                               network_error_config.max_retry_delay)
                        
                        -- Don't save to cache, allow retry
                        j = j - 1  -- Retry this poem
                    end
                else
                    -- Non-critical errors: save error record to prevent retrying
                    embeddings_data.embeddings[poem_index] = {
                        id = poem.id,
                        embedding = nil,
                        error = error_type,
                        updated_at = os.date("%Y-%m-%d %H:%M:%S")
                    }
                    utils.log_warn("Non-critical error for poem " .. poem_index .. ": " .. error_type)
                end
            end
            
            -- Small delay to avoid overwhelming the API
            os.execute("sleep 0.1")
        end
        
        -- Save progress periodically
        if i % 100 == 1 or batch_end == #poems_to_process then
            local new_completed = completed - skipped_count
            utils.log_info("Saving progress... (" .. new_completed .. " new + " .. skipped_count .. " existing = " .. completed .. " total)")
            if not utils.write_json_file(output_file, embeddings_data) then
                utils.log_error("Failed to save embeddings to " .. output_file)
                return false
            end
        end
    end
    
    embeddings_data.metadata.completed_embeddings = completed
    embeddings_data.metadata.completion_rate = completed / #poems
    embeddings_data.metadata.new_embeddings = completed - skipped_count
    embeddings_data.metadata.reused_embeddings = skipped_count
    embeddings_data.metadata.processing_mode = incremental and "incremental" or "full_regeneration"
    
    -- Add timing data for progress bar calculations using rolling average algorithm
    embeddings_data.metadata.timing = {
        average_generation_time = timing_data.average_generation_time,
        processed_count = timing_data.processed_count
    }
    
    utils.log_info("Embedding generation complete!")
    if incremental then
        utils.log_info("Incremental processing results:")
        utils.log_info("  New embeddings generated: " .. (completed - skipped_count))
        utils.log_info("  Existing embeddings reused: " .. skipped_count)
        utils.log_info("  Total embeddings: " .. completed .. " out of " .. #poems)
        utils.log_info("  Time savings: " .. string.format("%.1f%%", (skipped_count / #poems) * 100))
    else
        utils.log_info("Full regeneration results:")
        utils.log_info("  Successfully generated " .. completed .. " out of " .. #poems .. " embeddings")
    end
    utils.log_info("Completion rate: " .. string.format("%.1f%%", (completed / #poems) * 100))
    
    return utils.write_json_file(output_file, embeddings_data)
end
-- }}}

-- {{{ function validate_similarity_matrix_currency
local function validate_similarity_matrix_currency(similarity_file, embeddings_file, poems_file)
    if not utils.file_exists(similarity_file) then
        return {valid = false, reason = "no_matrix_found"}
    end
    
    local similarity_data = utils.read_json_file(similarity_file)
    local embeddings_data = utils.read_json_file(embeddings_file)
    local poems_data = utils.read_json_file(poems_file)
    
    if not similarity_data or not similarity_data.metadata then
        return {valid = false, reason = "no_metadata"}
    end
    
    local total_poems = #poems_data.poems
    
    -- Count current valid embeddings
    local current_embeddings = 0
    if embeddings_data and embeddings_data.embeddings then
        for _, emb in pairs(embeddings_data.embeddings) do
            if emb.embedding and #emb.embedding > 0 then
                current_embeddings = current_embeddings + 1
            end
        end
    end
    
    local matrix_embeddings = similarity_data.metadata.embedding_count or 0
    
    if current_embeddings ~= matrix_embeddings then
        return {
            valid = false, 
            reason = "embedding_count_mismatch",
            current_count = current_embeddings,
            matrix_count = matrix_embeddings,
            difference = current_embeddings - matrix_embeddings
        }
    end
    
    if not similarity_data.metadata.is_complete then
        return {
            valid = false,
            reason = "incomplete_dataset",
            completeness = similarity_data.metadata.matrix_completeness or 0,
            missing_embeddings = total_poems - current_embeddings
        }
    end
    
    return {valid = true, metadata = similarity_data.metadata}
end
-- }}}

-- {{{ function M.calculate_similarity_matrix
function M.calculate_similarity_matrix(embeddings_file, output_file, top_n, force_regenerate)
    top_n = top_n or 10
    force_regenerate = force_regenerate or false
    
    -- Need poems file for validation
    local poems_file = "assets/poems.json"
    
    -- Validate existing matrix unless forced to regenerate
    if not force_regenerate then
        local validation = validate_similarity_matrix_currency(output_file, embeddings_file, poems_file)
        if validation.valid then
            utils.log_info("✅ Existing similarity matrix is current and complete")
            return true
        else
            utils.log_warn("⚠️  Similarity matrix validation failed: " .. validation.reason)
            if validation.reason == "embedding_count_mismatch" then
                utils.log_info("   Current embeddings: " .. validation.current_count)
                utils.log_info("   Matrix embeddings: " .. validation.matrix_count)
                utils.log_info("   Difference: " .. validation.difference)
            elseif validation.reason == "incomplete_dataset" then
                utils.log_info("   Completeness: " .. string.format("%.1f%%", validation.completeness * 100))
                utils.log_info("   Missing embeddings: " .. validation.missing_embeddings)
            end
            utils.log_info("🗑️  Removing stale similarity matrix...")
            os.remove(output_file)
        end
    end
    
    utils.log_info("Loading embeddings from: " .. embeddings_file)
    local embeddings_data = utils.read_json_file(embeddings_file)
    if not embeddings_data or not embeddings_data.embeddings then
        utils.log_error("Failed to load embeddings from " .. embeddings_file)
        return false
    end
    
    local embeddings = embeddings_data.embeddings
    local valid_embeddings = {}
    
    -- Filter out invalid embeddings
    for i, item in ipairs(embeddings) do
        if item.embedding and #item.embedding > 0 then
            table.insert(valid_embeddings, {
                index = i,
                id = item.id,
                embedding = item.embedding
            })
        end
    end
    
    -- Load poems data to get actual total count
    local poems_data = utils.read_json_file(poems_file)
    local total_poems = poems_data and #poems_data.poems or #embeddings
    
    -- Calculate completeness metrics
    local embedding_count = #valid_embeddings
    local matrix_completeness = embedding_count / total_poems
    local is_complete = embedding_count == total_poems
    
    -- Warn about incomplete datasets
    if not is_complete then
        utils.log_warn("⚠️  WARNING: Incomplete dataset detected")
        utils.log_info("   Embeddings: " .. embedding_count .. " / " .. total_poems .. " poems (" .. string.format("%.1f%%", matrix_completeness * 100) .. " complete)")
        utils.log_info("   Missing: " .. (total_poems - embedding_count) .. " poems will not appear in recommendations")
        utils.log_info("")
        utils.log_info("   For complete recommendations, generate embeddings for all poems first")
    end
    
    utils.log_info("Calculating similarity matrix for " .. #valid_embeddings .. " valid embeddings...")
    
    local similarity_data = {
        metadata = {
            generated_at = os.date("%Y-%m-%d %H:%M:%S"),
            model_name = embeddings_data.metadata and embeddings_data.metadata.embedding_model or "unknown",
            total_poems = total_poems,
            embedding_count = embedding_count,
            matrix_completeness = matrix_completeness,
            is_complete = is_complete,
            top_n = top_n,
            algorithm = "cosine_similarity"
        },
        similarities = {}
    }
    
    local total_comparisons = #valid_embeddings * (#valid_embeddings - 1) / 2
    local completed_comparisons = 0
    
    for i = 1, #valid_embeddings do
        local poem_a = valid_embeddings[i]
        local similarities_for_poem = {}
        
        utils.log_info(string.format("Processing poem %d/%d (ID: %s)", i, #valid_embeddings, poem_a.id or "unknown"))
        
        for j = 1, #valid_embeddings do
            if i ~= j then
                local poem_b = valid_embeddings[j]
                local similarity = cosine_similarity(poem_a.embedding, poem_b.embedding)
                
                table.insert(similarities_for_poem, {
                    id = poem_b.id,
                    index = poem_b.index,
                    similarity = similarity
                })
                
                if j > i then
                    completed_comparisons = completed_comparisons + 1
                end
            end
        end
        
        -- Sort by similarity (highest first) and keep only top N
        table.sort(similarities_for_poem, function(a, b) return a.similarity > b.similarity end)
        
        local top_similarities = {}
        for k = 1, math.min(top_n, #similarities_for_poem) do
            table.insert(top_similarities, similarities_for_poem[k])
        end
        
        local poem_key = poem_a.id or ("poem_" .. poem_a.index)
        similarity_data.similarities[poem_key] = {
            poem_index = poem_a.index,
            top_similar = top_similarities,
            calculated_at = os.date("%Y-%m-%d %H:%M:%S")
        }
        
        -- Save progress periodically
        if i % 50 == 0 or i == #valid_embeddings then
            local progress = (completed_comparisons / total_comparisons) * 100
            utils.log_info(string.format("Progress: %.1f%% (%d/%d comparisons)", progress, completed_comparisons, total_comparisons))
            
            if not utils.write_json_file(output_file, similarity_data) then
                utils.log_error("Failed to save similarity matrix to " .. output_file)
                return false
            end
        end
    end
    
    utils.log_info("Similarity matrix calculation complete!")
    utils.log_info("Calculated similarities for " .. #valid_embeddings .. " poems")
    utils.log_info("Total comparisons: " .. total_comparisons)
    
    return true
end
-- }}}

-- {{{ function M.calculate_full_similarity_matrix
function M.calculate_full_similarity_matrix(embeddings_file, output_file, force_regenerate)
    force_regenerate = force_regenerate or false
    
    -- Need poems file for validation
    local poems_file = "assets/poems.json"
    
    -- Check if full matrix already exists and is current
    if not force_regenerate and utils.file_exists(output_file) then
        local existing_data = utils.read_json_file(output_file)
        if existing_data and existing_data.metadata and existing_data.metadata.is_complete then
            utils.log_info("✅ Full similarity matrix already exists and is complete")
            return true
        end
    end
    
    utils.log_info("🔍 Generating FULL similarity matrix (all poem pairs)...")
    utils.log_info("⚠️  This will generate ALL 47.1M comparisons (no symmetry optimization) and may take 4-8 hours")
    
    -- Load embeddings
    local embeddings_data = utils.read_json_file(embeddings_file)
    if not embeddings_data or not embeddings_data.embeddings then
        utils.log_error("Failed to load embeddings from " .. embeddings_file)
        return false
    end
    
    local embeddings = embeddings_data.embeddings
    local valid_embeddings = {}
    
    -- Filter out invalid embeddings
    for _, embedding in ipairs(embeddings) do
        if embedding.embedding and #embedding.embedding > 0 and embedding.id then
            table.insert(valid_embeddings, embedding)
        end
    end
    
    if #valid_embeddings == 0 then
        utils.log_error("No valid embeddings found")
        return false
    end
    
    utils.log_info(string.format("Processing %d poems for full similarity matrix", #valid_embeddings))
    
    local total_comparisons = #valid_embeddings * #valid_embeddings
    local completed_comparisons = 0
    local start_time = os.time()
    
    -- Initialize full similarity matrix
    local similarity_data = {
        metadata = {
            is_complete = true,
            total_poems = #valid_embeddings,
            matrix_size = total_comparisons,
            algorithm = "cosine_similarity",
            model_name = embeddings_data.metadata.embedding_model or "unknown",
            generated_at = os.date("%Y-%m-%d %H:%M:%S"),
            embedding_count = #valid_embeddings
        },
        similarities = {}
    }
    
    -- Generate COMPLETE similarity matrix (calculate ALL comparisons for maximum accuracy)
    for i = 1, #valid_embeddings do
        local poem_a = valid_embeddings[i]
        local poem_a_id = tostring(poem_a.id)
        similarity_data.similarities[poem_a_id] = {}
        
        utils.log_info(string.format("Processing poem %d/%d (ID: %s)", i, #valid_embeddings, poem_a_id))
        
        for j = 1, #valid_embeddings do
            local poem_b = valid_embeddings[j]
            local poem_b_id = tostring(poem_b.id)
            
            if i == j then
                -- Self-similarity is always 1.0
                similarity_data.similarities[poem_a_id][poem_b_id] = 1.0
            else
                -- Calculate similarity for EVERY comparison (no symmetry optimization)
                -- This ensures maximum accuracy by computing each comparison independently
                local similarity = cosine_similarity(poem_a.embedding, poem_b.embedding)
                -- Round to 4 decimal places for storage efficiency
                local rounded_similarity = math.floor(similarity * 10000) / 10000
                
                similarity_data.similarities[poem_a_id][poem_b_id] = rounded_similarity
            end
            
            completed_comparisons = completed_comparisons + 1
        end
        
        -- Progressive saving every 100 poems to prevent data loss
        if i % 100 == 0 or i == #valid_embeddings then
            local progress = (completed_comparisons / total_comparisons) * 100
            local elapsed_time = os.time() - start_time
            local rate = completed_comparisons / elapsed_time
            local estimated_remaining = (total_comparisons - completed_comparisons) / rate
            
            utils.log_info(string.format("Progress: %.2f%% (%d/%d comparisons)", 
                          progress, completed_comparisons, total_comparisons))
            utils.log_info(string.format("Rate: %.0f comparisons/sec, Est. remaining: %.0f minutes", 
                          rate, estimated_remaining / 60))
            
            if not utils.write_json_file(output_file, similarity_data) then
                utils.log_error("Failed to save similarity matrix to " .. output_file)
                return false
            end
            utils.log_info("✅ Progress saved to disk")
        end
        
        -- Memory management: force garbage collection periodically
        if i % 500 == 0 then
            collectgarbage("collect")
        end
    end
    
    -- Final save with completion timestamp
    similarity_data.metadata.completed_at = os.date("%Y-%m-%d %H:%M:%S")
    similarity_data.metadata.generation_time_seconds = os.time() - start_time
    
    if not utils.write_json_file(output_file, similarity_data) then
        utils.log_error("Failed to save final similarity matrix")
        return false
    end
    
    utils.log_info("🎉 Full similarity matrix generation complete!")
    utils.log_info(string.format("Total comparisons: %d", total_comparisons))
    utils.log_info(string.format("Generation time: %.1f minutes", (os.time() - start_time) / 60))
    utils.log_info(string.format("Matrix saved to: %s", output_file))
    
    return true
end
-- }}}

-- {{{ function M.calculate_triangular_similarity_matrix
function M.calculate_triangular_similarity_matrix(embeddings_file, output_file, force_regenerate)
    utils.log_info("🔍 Generating TRIANGULAR similarity matrix (optimized storage)...")
    
    -- Check if output already exists and not forcing regeneration
    if not force_regenerate and utils.file_exists(output_file) then
        utils.log_info("Triangular similarity matrix already exists. Use force_regenerate=true to recreate.")
        return true
    end
    
    local embeddings_data = utils.read_json_file(embeddings_file)
    if not embeddings_data or not embeddings_data.embeddings then
        utils.log_error("Failed to load embeddings file: " .. embeddings_file)
        return false
    end
    
    local embeddings = embeddings_data.embeddings
    local poems = {}
    
    -- Filter out invalid embeddings (same as full matrix function)
    for _, embedding in ipairs(embeddings) do
        if embedding.embedding and #embedding.embedding > 0 and embedding.id then
            table.insert(poems, embedding)
        end
    end
    
    if #poems == 0 then
        utils.log_error("No valid embeddings found")
        return false
    end
    
    utils.log_info("Processing " .. #poems .. " poems for triangular similarity matrix")
    
    -- Calculate storage requirements
    local total_unique_pairs = (#poems * (#poems - 1)) / 2
    utils.log_info(string.format("⚠️  This will generate %d unique comparisons (50%% reduction from full matrix)", total_unique_pairs))
    utils.log_info("⚠️  Expected storage: ~50% reduction from full matrix size")
    
    local similarity_data = {
        metadata = {
            matrix_size = total_unique_pairs,
            total_poems = #poems,
            model_name = embeddings_data.model_name,
            algorithm = "cosine_similarity", 
            embedding_count = #poems,
            generated_at = os.date("%Y-%m-%d %H:%M:%S"),
            is_complete = true,
            storage_format = "triangular_upper"
        },
        similarities = {}
    }
    
    local start_time = os.time()
    local completed = 0
    
    -- Generate upper triangular matrix only (i < j)
    for i = 1, #poems do
        local poem_a = poems[i]
        similarity_data.similarities[tostring(poem_a.id)] = {}
        
        -- Only calculate similarities for j > i (upper triangle)
        for j = i + 1, #poems do
            local poem_b = poems[j]
            
            local similarity = cosine_similarity(poem_a.embedding, poem_b.embedding)
            similarity_data.similarities[tostring(poem_a.id)][tostring(poem_b.id)] = 
                math.floor(similarity * 10000) / 10000  -- 4 decimal precision
            
            completed = completed + 1
            
            -- Progress reporting every 10000 comparisons
            if completed % 10000 == 0 then
                local progress_percent = (completed / total_unique_pairs) * 100
                local elapsed = os.time() - start_time
                local rate = completed / elapsed
                local remaining_time = (total_unique_pairs - completed) / rate / 60
                
                utils.log_info(string.format("Progress: %.2f%% (%d/%d comparisons)", 
                    progress_percent, completed, total_unique_pairs))
                utils.log_info(string.format("Rate: %.0f comparisons/sec, Est. remaining: %.1f minutes", 
                    rate, remaining_time))
            end
        end
        
        -- Progressive saving every 100 poems
        if i % 100 == 0 then
            utils.write_json_file(output_file, similarity_data)
            utils.log_info(string.format("✅ Progress saved to disk (poem %d/%d)", i, #poems))
        end
        
        -- Garbage collection every 500 poems
        if i % 500 == 0 then
            collectgarbage()
            utils.log_info(string.format("🗑️ Memory cleanup completed (poem %d/%d)", i, #poems))
        end
    end
    
    -- Final save
    if not utils.write_json_file(output_file, similarity_data) then
        utils.log_error("Failed to save triangular similarity matrix")
        return false
    end
    
    utils.log_info("✅ TRIANGULAR similarity matrix generation completed!")
    utils.log_info(string.format("Total unique comparisons: %d", total_unique_pairs))
    utils.log_info(string.format("Generation time: %.1f minutes", (os.time() - start_time) / 60))
    utils.log_info(string.format("Matrix saved to: %s", output_file))
    utils.log_info("📊 Storage optimized: ~50% reduction from full matrix")
    
    return true
end
-- }}}

-- {{{ function M.get_similarity_triangular
function M.get_similarity_triangular(matrix, id1, id2)
    -- Handle diagonal (self-similarity)
    if id1 == id2 then return 1.0 end
    
    -- Ensure consistent ordering for triangle lookup (min_id -> max_id)
    local min_id = math.min(tonumber(id1), tonumber(id2))
    local max_id = math.max(tonumber(id1), tonumber(id2))
    
    -- Look up in upper triangle
    if matrix.similarities[tostring(min_id)] and 
       matrix.similarities[tostring(min_id)][tostring(max_id)] then
        return matrix.similarities[tostring(min_id)][tostring(max_id)]
    end
    
    -- Fallback (should not happen with complete matrix)
    utils.log_warning(string.format("Similarity not found for poems %s and %s", id1, id2))
    return 0.0
end
-- }}}

-- {{{ function M.get_all_similarities_for_poem_triangular
function M.get_all_similarities_for_poem_triangular(matrix, poem_id, poem_ids)
    local similarities = {}
    
    for _, other_id in ipairs(poem_ids) do
        if other_id ~= poem_id then
            local score = M.get_similarity_triangular(matrix, poem_id, other_id)
            table.insert(similarities, {
                target_id = other_id,
                score = score
            })
        end
    end
    
    -- Sort by similarity score (descending)
    table.sort(similarities, function(a, b) 
        return a.score > b.score 
    end)
    
    return similarities
end
-- }}}

-- {{{ function M.generate_similarity_report
function M.generate_similarity_report(similarity_file, poems_file, output_file)
    utils.log_info("Generating similarity analysis report...")
    
    local similarity_data = utils.read_json_file(similarity_file)
    local poems_data = utils.read_json_file(poems_file)
    
    if not similarity_data or not poems_data then
        utils.log_error("Failed to load required data files")
        return false
    end
    
    local report = {
        metadata = {
            generated_at = os.date("%Y-%m-%d %H:%M:%S"),
            total_poems = #poems_data,
            poems_with_similarities = 0,
            average_similarity = 0,
            max_similarity = 0,
            min_similarity = 1
        },
        statistics = {},
        sample_similarities = {}
    }
    
    local total_similarity = 0
    local similarity_count = 0
    
    for poem_id, data in pairs(similarity_data.similarities) do
        report.metadata.poems_with_similarities = report.metadata.poems_with_similarities + 1
        
        if data.top_similar and #data.top_similar > 0 then
            local max_sim = data.top_similar[1].similarity
            local min_sim = data.top_similar[#data.top_similar].similarity
            
            report.metadata.max_similarity = math.max(report.metadata.max_similarity, max_sim)
            report.metadata.min_similarity = math.min(report.metadata.min_similarity, min_sim)
            
            for _, sim in ipairs(data.top_similar) do
                total_similarity = total_similarity + sim.similarity
                similarity_count = similarity_count + 1
            end
            
            -- Add sample for high-similarity pairs
            if max_sim > 0.8 then
                table.insert(report.sample_similarities, {
                    poem_a_id = poem_id,
                    poem_b_id = data.top_similar[1].id,
                    similarity = max_sim
                })
            end
        end
    end
    
    if similarity_count > 0 then
        report.metadata.average_similarity = total_similarity / similarity_count
    end
    
    utils.log_info("Similarity analysis complete!")
    utils.log_info("Poems with similarities: " .. report.metadata.poems_with_similarities)
    utils.log_info("Average similarity: " .. string.format("%.3f", report.metadata.average_similarity))
    utils.log_info("Similarity range: " .. string.format("%.3f - %.3f", report.metadata.min_similarity, report.metadata.max_similarity))
    
    return utils.write_json_file(output_file, report)
end
-- }}}

-- {{{ function M.generate_all_model_similarity_matrices
function M.generate_all_model_similarity_matrices(base_output_dir, min_completeness, use_full_matrix)
    min_completeness = min_completeness or 0.8  -- 80% minimum completeness
    use_full_matrix = use_full_matrix or false  -- Default to sparse matrices
    
    utils.log_info("🔄 Generating similarity matrices for all eligible models...")
    utils.log_info("⚙️ Minimum completeness required: " .. (min_completeness * 100) .. "%")
    utils.log_info("📊 Matrix type: " .. (use_full_matrix and "FULL (all comparisons)" or "SPARSE (top-N)"))
    
    local models = M.list_available_models()
    local results = {}
    local eligible_count = 0
    local total_poems = 6860  -- Known total poem count
    
    -- First pass: check eligibility
    for model_name, config in pairs(models) do
        local status = M.get_model_status(base_output_dir, model_name)
        
        if status.exists then
            local completeness = status.count / total_poems
            
            if completeness >= min_completeness then
                eligible_count = eligible_count + 1
                utils.log_info("✅ " .. model_name .. " (" .. string.format("%.1f%% complete, %d poems)", completeness * 100, status.count) .. ")")
            else
                utils.log_warn("⚠️ Skipping " .. model_name .. 
                             " (only " .. string.format("%.1f%% complete, %d poems)", completeness * 100, status.count) .. ")")
            end
        else
            utils.log_info("❌ No embeddings found for " .. model_name)
        end
    end
    
    if eligible_count == 0 then
        utils.log_warn("No models meet the minimum completeness requirement")
        return {}
    end
    
    utils.log_info("📈 Processing " .. eligible_count .. " eligible models")
    
    local current_model = 0
    
    -- Second pass: generate matrices
    for model_name, config in pairs(models) do
        local status = M.get_model_status(base_output_dir, model_name)
        
        if status.exists then
            local completeness = status.count / total_poems
            
            if completeness >= min_completeness then
                current_model = current_model + 1
                
                utils.log_info(string.format("🔄 [%d/%d] Processing %s", current_model, eligible_count, model_name))
                
                local storage_paths = get_model_storage_path(base_output_dir, model_name)
                local matrix_file = use_full_matrix and 
                                   storage_paths.similarity_matrix:gsub("%.json$", "_full.json") or 
                                   storage_paths.similarity_matrix
                
                local start_time = os.time()
                local success
                
                if use_full_matrix then
                    success = M.calculate_full_similarity_matrix(
                        storage_paths.embeddings, 
                        matrix_file,
                        false  -- Don't force regenerate unless needed
                    )
                else
                    success = M.calculate_similarity_matrix(
                        storage_paths.embeddings, 
                        matrix_file
                    )
                end
                
                local generation_time = os.time() - start_time
                
                results[model_name] = {
                    success = success,
                    completeness = completeness,
                    embedding_count = status.count,
                    matrix_file = matrix_file,
                    generation_time = generation_time,
                    matrix_type = use_full_matrix and "full" or "sparse"
                }
                
                if success then
                    utils.log_info(string.format("✅ Matrix generation complete for %s (took %d seconds)", model_name, generation_time))
                else
                    utils.log_error("❌ Matrix generation failed for " .. model_name)
                end
            else
                results[model_name] = {
                    success = false,
                    reason = "insufficient_completeness",
                    completeness = completeness,
                    embedding_count = status.count,
                    required_completeness = min_completeness
                }
            end
        else
            results[model_name] = {
                success = false,
                reason = "no_embeddings",
                completeness = 0,
                embedding_count = 0
            }
        end
    end
    
    -- Summary report
    local successful_models = 0
    local skipped_models = 0
    local failed_models = 0
    
    for model_name, result in pairs(results) do
        if result.success then
            successful_models = successful_models + 1
        elseif result.reason then
            skipped_models = skipped_models + 1
        else
            failed_models = failed_models + 1
        end
    end
    
    utils.log_info("📊 Generation Summary:")
    utils.log_info("  ✅ Successful: " .. successful_models .. " models")
    utils.log_info("  ⚠️ Skipped: " .. skipped_models .. " models") 
    utils.log_info("  ❌ Failed: " .. failed_models .. " models")
    
    return results
end
-- }}}

-- {{{ function M.compare_model_similarities
function M.compare_model_similarities(poem_id, base_output_dir, models, use_full_matrix)
    use_full_matrix = use_full_matrix or false
    models = models or {}
    
    -- If no models specified, use all available models
    if #models == 0 then
        local available_models = M.list_available_models()
        for model_name, _ in pairs(available_models) do
            table.insert(models, model_name)
        end
    end
    
    utils.log_info("🔍 Comparing similarities for poem " .. poem_id .. " across models")
    
    local comparisons = {}
    
    for _, model_name in ipairs(models) do
        local storage_paths = get_model_storage_path(base_output_dir, model_name)
        local matrix_file = use_full_matrix and 
                           storage_paths.similarity_matrix:gsub("%.json$", "_full.json") or 
                           storage_paths.similarity_matrix
        
        if utils.file_exists(matrix_file) then
            -- For now, generate basic similarity data - this would integrate with recommendation system
            comparisons[model_name] = {
                matrix_available = true,
                matrix_type = use_full_matrix and "full" or "sparse",
                matrix_file = matrix_file
            }
            utils.log_info("✅ " .. model_name .. " - Matrix available")
        else
            comparisons[model_name] = {
                matrix_available = false,
                reason = "matrix_not_found"
            }
            utils.log_info("❌ " .. model_name .. " - Matrix not found")
        end
    end
    
    return comparisons
end
-- }}}

-- {{{ function M.get_multi_model_status
function M.get_multi_model_status(base_output_dir)
    utils.log_info("📊 Per-Model Similarity Matrix Status:")
    
    local models = M.list_available_models()
    local total_poems = 6860
    local status_summary = {}
    
    for model_name, config in pairs(models) do
        local status = M.get_model_status(base_output_dir, model_name)
        local storage_paths = get_model_storage_path(base_output_dir, model_name)
        
        local sparse_matrix_exists = utils.file_exists(storage_paths.similarity_matrix)
        local full_matrix_file = storage_paths.similarity_matrix:gsub("%.json$", "_full.json")
        local full_matrix_exists = utils.file_exists(full_matrix_file)
        
        local completeness = status.exists and (status.count / total_poems) or 0
        
        utils.log_info("  " .. model_name .. " (" .. config.dimensions .. " dims)")
        
        if status.exists then
            utils.log_info(string.format("    ✅ Embeddings: %d/%d (%.1f%%)", 
                         status.count, total_poems, completeness * 100))
        else
            utils.log_info("    ❌ Embeddings: 0/" .. total_poems .. " (0%)")
        end
        
        if sparse_matrix_exists then
            utils.log_info("    ✅ Sparse Matrix: Generated")
        else
            utils.log_info("    ❌ Sparse Matrix: Not generated")
        end
        
        if full_matrix_exists then
            utils.log_info("    ✅ Full Matrix: Generated")
        else
            utils.log_info("    ❌ Full Matrix: Not generated")
        end
        
        if completeness < 0.8 then
            local needed = math.ceil((0.8 * total_poems) - status.count)
            utils.log_info("    🔄 Recommendation: Complete " .. needed .. " more embeddings")
        end
        
        status_summary[model_name] = {
            dimensions = config.dimensions,
            embedding_count = status.count,
            completeness = completeness,
            sparse_matrix_exists = sparse_matrix_exists,
            full_matrix_exists = full_matrix_exists,
            eligible_for_generation = completeness >= 0.8
        }
    end
    
    return status_summary
end
-- }}}

-- {{{ function M.main
function M.main(interactive_mode)
    if interactive_mode then
        utils.log_info("=== Similarity Engine Interactive Mode ===")
        print("1. Generate embeddings for all poems")
        print("2. Calculate similarity matrix (sparse, top-N)")
        print("3. Calculate FULL similarity matrix (all pairs)")
        print("4. Generate similarity analysis report")
        print("5. Run complete pipeline")
        print("6. Generate matrices for ALL eligible models")
        print("7. Show multi-model status")
        print("8. Compare model similarities")
        io.write("Select option (1-8): ")
        local choice = io.read()
        
        if choice == "1" then
            local poems_file = DIR .. "/assets/poems.json"
            local base_output_dir = DIR .. "/assets"
            io.write("Use incremental processing? (Y/n): ")
            local incremental_choice = io.read()
            local incremental = not (incremental_choice:lower() == "n" or incremental_choice:lower() == "no")
            io.write("Embedding model (default: EmbeddingGemma:latest): ")
            local model_input = io.read()
            local model_name = model_input ~= "" and model_input or "embeddinggemma:latest"
            M.generate_all_embeddings(poems_file, base_output_dir, nil, incremental, model_name)
        elseif choice == "2" then
            io.write("Embedding model (default: EmbeddingGemma:latest): ")
            local model_input = io.read()
            local model_name = model_input ~= "" and model_input or "embeddinggemma:latest"
            local base_output_dir = DIR .. "/assets"
            local storage_paths = get_model_storage_path(base_output_dir, model_name)
            local embeddings_file = storage_paths.embeddings
            local output_file = storage_paths.similarity_matrix
            M.calculate_similarity_matrix(embeddings_file, output_file)
        elseif choice == "3" then
            io.write("Embedding model (default: EmbeddingGemma:latest): ")
            local model_input = io.read()
            local model_name = model_input ~= "" and model_input or "embeddinggemma:latest"
            local base_output_dir = DIR .. "/assets"
            local storage_paths = get_model_storage_path(base_output_dir, model_name)
            local embeddings_file = storage_paths.embeddings
            local output_file = storage_paths.similarity_matrix:gsub("%.json$", "_full.json")
            
            utils.log_info("⚠️  FULL matrix generation will take 2-4 hours and create ~100MB file")
            io.write("Continue? (y/N): ")
            local confirm = io.read()
            if confirm:lower() == "y" or confirm:lower() == "yes" then
                M.calculate_full_similarity_matrix(embeddings_file, output_file, false)
            else
                utils.log_info("Full matrix generation cancelled")
            end
        elseif choice == "4" then
            local similarity_file = DIR .. "/assets/similarity-matrix.json"
            local poems_file = DIR .. "/assets/poems.json"
            local output_file = DIR .. "/assets/similarity-report.json"
            M.generate_similarity_report(similarity_file, poems_file, output_file)
        elseif choice == "5" then
            utils.log_info("Running complete similarity engine pipeline...")
            local poems_file = DIR .. "/assets/poems.json"
            local base_output_dir = DIR .. "/assets"
            local similarity_file = DIR .. "/assets/similarity-matrix.json"
            local report_file = DIR .. "/assets/similarity-report.json"
            
            if M.generate_all_embeddings(poems_file, base_output_dir) then
                local storage_paths = get_model_storage_path(base_output_dir, "embeddinggemma:latest")
                local embeddings_file = storage_paths.embeddings
                if M.calculate_similarity_matrix(embeddings_file, similarity_file) then
                    M.generate_similarity_report(similarity_file, poems_file, report_file)
                    utils.log_info("✅ Complete pipeline executed successfully!")
                else
                    utils.log_error("Pipeline failed at similarity matrix calculation")
                end
            else
                utils.log_error("Pipeline failed at embedding generation")
            end
        elseif choice == "6" then
            local base_output_dir = DIR .. "/assets"
            io.write("Matrix type - (s)parse or (f)ull? (default: sparse): ")
            local matrix_type = io.read()
            local use_full_matrix = matrix_type:lower():sub(1,1) == "f"
            
            io.write("Minimum completeness percentage (default: 80): ")
            local completeness_input = io.read()
            local min_completeness = tonumber(completeness_input) or 80
            min_completeness = min_completeness / 100  -- Convert percentage to decimal
            
            local results = M.generate_all_model_similarity_matrices(base_output_dir, min_completeness, use_full_matrix)
            utils.log_info("Multi-model generation complete. Results available in similarity engine.")
        elseif choice == "7" then
            local base_output_dir = DIR .. "/assets"
            M.get_multi_model_status(base_output_dir)
        elseif choice == "8" then
            io.write("Poem ID to compare: ")
            local poem_id = tonumber(io.read())
            local base_output_dir = DIR .. "/assets"
            io.write("Use (s)parse or (f)ull matrices? (default: sparse): ")
            local matrix_type = io.read()
            local use_full_matrix = matrix_type:lower():sub(1,1) == "f"
            
            local results = M.compare_model_similarities(poem_id, base_output_dir, {}, use_full_matrix)
            utils.log_info("Model comparison complete.")
        else
            print("Invalid choice")
        end
    else
        -- Default: run similarity analysis on existing data
        utils.log_info("Running similarity engine analysis...")
        local similarity_file = DIR .. "/assets/similarity-matrix.json"
        local poems_file = DIR .. "/assets/poems.json"
        local report_file = DIR .. "/assets/similarity-report.json"
        
        if utils.file_exists(similarity_file) then
            M.generate_similarity_report(similarity_file, poems_file, report_file)
        else
            utils.log_info("No similarity matrix found. Use interactive mode (-I) to generate embeddings and similarities.")
        end
    end
end
-- }}}

-- {{{ function M.flush_embeddings_cache
function M.flush_embeddings_cache(output_file, flush_type, backup)
    flush_type = flush_type or "all"  -- "all", "errors", "model_specific"
    backup = backup ~= false          -- Default to true
    
    if not utils.file_exists(output_file) then
        utils.log_info("No cache file found at: " .. output_file)
        return true
    end
    
    -- Get file info for reporting
    local file_size = os.execute("du -h '" .. output_file .. "' 2>/dev/null") and 
                     io.popen("du -h '" .. output_file .. "' | cut -f1"):read("*l") or "unknown"
    
    utils.log_info("Cache flush operation: " .. flush_type)
    utils.log_info("Target file: " .. output_file)
    utils.log_info("File size: " .. file_size)
    
    if backup then
        local backup_file = output_file .. ".backup." .. os.date("%Y%m%d_%H%M%S")
        
        -- Use Lua file operations for better cross-platform compatibility
        local source_file = io.open(output_file, "rb")
        if not source_file then
            utils.log_error("Failed to open source file for backup")
            return false
        end
        
        local content = source_file:read("*a")
        source_file:close()
        
        local backup_dest = io.open(backup_file, "wb")
        if not backup_dest then
            utils.log_error("Failed to create backup file: " .. backup_file)
            return false
        end
        
        backup_dest:write(content)
        backup_dest:close()
        
        utils.log_info("Backup created: " .. backup_file)
    end
    
    if flush_type == "all" then
        -- Complete cache flush
        local remove_result = os.remove(output_file)
        if remove_result then
            utils.log_info("✅ Complete embedding cache flushed")
            return true
        else
            utils.log_error("Failed to remove cache file")
            return false
        end
        
    elseif flush_type == "errors" then
        -- Flush only error entries, keep valid embeddings
        local existing_data = utils.read_json_file(output_file)
        if not existing_data or not existing_data.embeddings then
            utils.log_warn("No embeddings data found in cache file")
            return true
        end
        
        local clean_embeddings = {}
        local removed_count = 0
        local kept_count = 0
        
        for i, emb in pairs(existing_data.embeddings) do
            if emb.embedding and type(emb.embedding) == "table" and #emb.embedding == 768 then
                -- Keep valid embeddings
                clean_embeddings[i] = emb
                kept_count = kept_count + 1
            else
                -- Remove error entries
                removed_count = removed_count + 1
            end
        end
        
        existing_data.embeddings = clean_embeddings
        
        -- Update metadata
        if existing_data.metadata then
            existing_data.metadata.completed_embeddings = kept_count
            existing_data.metadata.last_flush_operation = {
                type = "errors_only",
                timestamp = os.date("%Y-%m-%d %H:%M:%S"),
                removed_entries = removed_count,
                kept_entries = kept_count
            }
        end
        
        local write_success = utils.write_json_file(output_file, existing_data)
        if write_success then
            utils.log_info("✅ Error entries flushed: " .. removed_count .. " entries removed, " .. kept_count .. " kept")
            return true
        else
            utils.log_error("Failed to write cleaned cache file")
            return false
        end
        
    else
        utils.log_error("Unknown flush type: " .. flush_type)
        return false
    end
end
-- }}}

-- Command line execution
if arg then
    local interactive_mode = false
    for i, arg_val in ipairs(arg) do
        if arg_val == "-I" then
            interactive_mode = true
            break
        end
    end
    
    M.main(interactive_mode)
end

return M