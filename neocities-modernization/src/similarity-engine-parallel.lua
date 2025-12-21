#!/usr/bin/env lua

-- {{{ Parallel Similarity Engine with Individual Poem Files
-- This implementation creates individual JSON files per poem containing
-- similarities to ALL other poems, with multithreading and resume capability
-- }}}

-- Ensure we're running from the correct directory
if not io.open("libs/utils.lua", "r") and not io.open("../libs/utils.lua", "r") then
    print("ERROR: This script must be run from the project root directory:")
    print("  cd /mnt/mtwo/programming/ai-stuff/neocities-modernization/")
    print("  lua src/similarity-engine-parallel.lua -I")
    print("")
    print("Current directory doesn't contain libs/utils.lua")
    os.exit(1)
end

-- Add paths for both project root and src/ directory execution
package.path = package.path .. ';./libs/?.lua;./src/?.lua;../libs/?.lua;../src/?.lua'
-- CRITICAL: effil.so is a C library, must be in cpath not path
-- The original bug put .so in package.path which caused "unexpected symbol near char(127)"
package.cpath = package.cpath .. ';/home/ritz/programming/ai-stuff/libs/lua/effil-jit/build/?.so'

local utils = require('utils')
local dkjson = require('dkjson')

-- Load effil for true multithreading - REQUIRED for parallel processing
local effil = nil
local has_threading = false

local success, err = pcall(function()
    effil = require('effil')
    has_threading = true
    utils.log_info("✅ Effil threading library loaded successfully")
end)

if not success or not has_threading then
    utils.log_error("❌ CRITICAL ERROR: Effil threading library is required but not available")
    utils.log_error("")
    utils.log_error("This is a PARALLEL similarity engine that requires multithreading capability.")
    utils.log_error("Without effil, processing 6,641 poems would take 8+ hours sequentially.")
    utils.log_error("")
    utils.log_error("SOLUTION:")
    utils.log_error("1. Install effil threading library:")
    utils.log_error("   luarocks install effil")
    utils.log_error("")
    utils.log_error("2. Or use the original single-threaded engine:")
    utils.log_error("   lua src/similarity-engine.lua -I")
    utils.log_error("")
    utils.log_error("Expected effil location: /home/ritz/programming/ai-stuff/libs/lua/effil-jit/build/effil.so")
    utils.log_error("Error details: " .. (err or "module not found"))
    os.exit(1)
end

local M = {}

-- {{{ function cosine_similarity
local function cosine_similarity(vec1, vec2)
    if #vec1 ~= #vec2 then
        error("Vector dimensions must match")
    end
    
    local dot_product = 0
    local norm_a = 0
    local norm_b = 0
    
    for i = 1, #vec1 do
        dot_product = dot_product + vec1[i] * vec2[i]
        norm_a = norm_a + vec1[i] * vec1[i]
        norm_b = norm_b + vec2[i] * vec2[i]
    end
    
    norm_a = math.sqrt(norm_a)
    norm_b = math.sqrt(norm_b)
    
    if norm_a == 0 or norm_b == 0 then
        return 0
    end
    
    return dot_product / (norm_a * norm_b)
end
-- }}}

-- {{{ function get_cpu_count
local function get_cpu_count()
    local handle = io.popen("nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4")
    local result = handle:read("*a")
    handle:close()
    return tonumber(result:match("%d+")) or 4
end
-- }}}

-- {{{ function get_similarity_output_dir
local function get_similarity_output_dir(model_name)
    local safe_model_name = model_name:gsub("[^%w._-]", "_")
    return "assets/embeddings/" .. safe_model_name .. "/similarities/"
end
-- }}}

-- {{{ function get_poem_similarity_file
local function get_poem_similarity_file(output_dir, poem_id, poem_index)
    local filename = poem_id and ("poem_" .. poem_id .. ".json") or ("poem_index_" .. poem_index .. ".json")
    return output_dir .. filename
end
-- }}}

-- {{{ function count_completed_poems
local function count_completed_poems(output_dir, total_poems)
    local completed = 0
    local completed_poems = {}
    local corrupted_files = {}
    
    if not utils.directory_exists(output_dir) then
        return 0, completed_poems
    end
    
    -- Clean up any temporary files from interrupted runs
    local cleanup_handle = io.popen("find '" .. output_dir .. "' -name '*.tmp' 2>/dev/null")
    if cleanup_handle then
        for temp_file in cleanup_handle:lines() do
            utils.log_warn("Cleaning up temporary file: " .. temp_file)
            os.remove(temp_file)
        end
        cleanup_handle:close()
    end
    
    -- Validate existing similarity files and detect corruption
    local list_handle = io.popen("find '" .. output_dir .. "' -name 'poem_*.json' 2>/dev/null")
    if list_handle then
        for filepath in list_handle:lines() do
            local filename = filepath:match("([^/]+)%.json$")
            if filename then
                -- Validate file integrity
                local file_data = utils.read_json_file(filepath)
                if file_data and file_data.metadata and file_data.similarities and 
                   file_data.metadata.total_comparisons and 
                   #file_data.similarities == file_data.metadata.total_comparisons then
                    -- File is valid and complete
                    completed_poems[filename] = true
                    completed = completed + 1
                else
                    -- File is corrupted or incomplete
                    utils.log_warn("Corrupted similarity file detected: " .. filepath)
                    corrupted_files[filepath] = true
                    os.remove(filepath)
                end
            end
        end
        list_handle:close()
    end
    
    if #corrupted_files > 0 then
        utils.log_info("Removed " .. #corrupted_files .. " corrupted similarity files")
    end
    
    return completed, completed_poems
end
-- }}}

-- {{{ function calculate_poem_similarities
local function calculate_poem_similarities(poem_data, all_embeddings, output_file, sleep_duration)
    local similarities = {}
    
    utils.log_info("Calculating similarities for poem " .. (poem_data.id or poem_data.index) .. " against " .. #all_embeddings .. " poems")
    
    for j = 1, #all_embeddings do
        local other_poem = all_embeddings[j]
        
        -- Skip self-comparison
        if poem_data.index ~= other_poem.index then
            local similarity = cosine_similarity(poem_data.embedding, other_poem.embedding)
            
            table.insert(similarities, {
                id = other_poem.id,
                index = other_poem.index,
                similarity = similarity
            })
        end
    end
    
    -- Sort by similarity (highest first) - ALL similarities, not just top N
    table.sort(similarities, function(a, b) return a.similarity > b.similarity end)
    
    -- Create comprehensive similarity data for this poem
    local poem_similarity_data = {
        metadata = {
            poem_id = poem_data.id,
            poem_index = poem_data.index,
            total_comparisons = #similarities,
            calculated_at = os.date("%Y-%m-%d %H:%M:%S"),
            algorithm = "cosine_similarity"
        },
        similarities = similarities
    }
    
    -- Write individual poem similarity file
    if not utils.write_json_file(output_file, poem_similarity_data) then
        utils.log_error("Failed to write similarity file: " .. output_file)
        return false
    end
    
    -- Temperature control - sleep to prevent overheating
    if sleep_duration > 0 then
        os.execute("sleep " .. sleep_duration)
    end
    
    return true
end
-- }}}

-- {{{ function process_poem_batch
local function process_poem_batch(batch_poems, all_embeddings, output_dir, sleep_duration, thread_id)
    local processed = 0
    local errors = 0
    
    utils.log_info("Thread " .. thread_id .. ": Processing " .. #batch_poems .. " poems")
    
    for _, poem_data in ipairs(batch_poems) do
        local output_file = get_poem_similarity_file(output_dir, poem_data.id, poem_data.index)
        
        local success = calculate_poem_similarities(poem_data, all_embeddings, output_file, sleep_duration)
        
        if success then
            processed = processed + 1
            utils.log_info("Thread " .. thread_id .. ": Completed poem " .. (poem_data.id or poem_data.index) .. " (" .. processed .. "/" .. #batch_poems .. ")")
        else
            errors = errors + 1
            utils.log_error("Thread " .. thread_id .. ": Failed to process poem " .. (poem_data.id or poem_data.index))
        end
    end
    
    utils.log_info("Thread " .. thread_id .. ": Completed batch - " .. processed .. " processed, " .. errors .. " errors")
    return processed, errors
end
-- }}}

-- {{{ function M.calculate_similarity_matrix_parallel
function M.calculate_similarity_matrix_parallel(embeddings_file, model_name, sleep_duration, force_regenerate)
    sleep_duration = sleep_duration or 0.5
    force_regenerate = force_regenerate or false
    
    -- Load embeddings
    utils.log_info("Loading embeddings from: " .. embeddings_file)
    local embeddings_data = utils.read_json_file(embeddings_file)
    if not embeddings_data or not embeddings_data.embeddings then
        utils.log_error("Failed to load embeddings from " .. embeddings_file)
        return false
    end
    
    -- Filter valid embeddings
    local valid_embeddings = {}
    for i, item in pairs(embeddings_data.embeddings) do
        if item.embedding and #item.embedding > 0 then
            table.insert(valid_embeddings, {
                index = i,
                id = item.id,
                embedding = item.embedding
            })
        end
    end
    
    utils.log_info("Found " .. #valid_embeddings .. " valid embeddings for similarity calculation")
    
    -- Setup output directory
    local output_dir = get_similarity_output_dir(model_name)
    if not utils.directory_exists(output_dir) then
        os.execute("mkdir -p '" .. output_dir .. "'")
        utils.log_info("Created similarity output directory: " .. output_dir)
    end
    
    -- Check for existing work (resume capability)
    local completed_count, completed_poems = count_completed_poems(output_dir, #valid_embeddings)
    
    if not force_regenerate and completed_count > 0 then
        utils.log_info("Found " .. completed_count .. " existing similarity files")
        
        if completed_count == #valid_embeddings then
            utils.log_info("✅ All poem similarities already calculated!")
            return true
        else
            utils.log_info("📄 Resuming from existing progress: " .. completed_count .. "/" .. #valid_embeddings .. " completed")
        end
    elseif force_regenerate then
        utils.log_info("🗑️ Force regenerate enabled - clearing existing similarity files")
        os.execute("rm -f '" .. output_dir .. "poem_*.json' 2>/dev/null")
        completed_poems = {}
        completed_count = 0
    end
    
    -- Filter out already completed poems
    local remaining_poems = {}
    for _, poem_data in ipairs(valid_embeddings) do
        local filename = poem_data.id and ("poem_" .. poem_data.id) or ("poem_index_" .. poem_data.index)
        if not completed_poems[filename] then
            table.insert(remaining_poems, poem_data)
        end
    end
    
    utils.log_info("Remaining poems to process: " .. #remaining_poems)
    
    if #remaining_poems == 0 then
        utils.log_info("✅ All poem similarities are up to date!")
        return true
    end
    
    -- Get CPU count and calculate optimal thread count
    local cpu_count = get_cpu_count()
    local thread_count = math.min(cpu_count, #remaining_poems)
    
    utils.log_info("🧵 Using " .. thread_count .. " threads (detected " .. cpu_count .. " CPUs)")
    utils.log_info("⏱️ Sleep duration per poem: " .. sleep_duration .. " seconds")
    
    -- Divide work among threads
    local poems_per_thread = math.ceil(#remaining_poems / thread_count)
    local batches = {}
    
    for t = 1, thread_count do
        local start_idx = (t - 1) * poems_per_thread + 1
        local end_idx = math.min(t * poems_per_thread, #remaining_poems)
        
        if start_idx <= #remaining_poems then
            local batch = {}
            for i = start_idx, end_idx do
                table.insert(batch, remaining_poems[i])
            end
            batches[t] = batch
            utils.log_info("Thread " .. t .. ": " .. #batch .. " poems (indices " .. start_idx .. "-" .. end_idx .. ")")
        end
    end
    
    -- Process batches using effil threading if available, otherwise sequential
    utils.log_info("🚀 Starting similarity calculation...")
    local start_time = os.time()
    
    local total_processed = 0
    local total_errors = 0
    
    -- Process batches using effil multithreading (effil is required, verified at startup)
    utils.log_info("🧵 Using effil multithreading with " .. thread_count .. " threads")
        
        -- Create thread pool and tasks
        local threads = {}
        local tasks = {}
        
        for thread_id, batch in pairs(batches) do
            -- Create thread function
            local thread_func = effil.thread(function(batch_data, all_embeddings_data, output_dir, sleep_duration, thread_id)
                -- Load required modules in thread context
                package.path = package.path .. ';./libs/?.lua;./src/?.lua'
                local utils = require('utils')
                local dkjson = require('libs.dkjson')
                
                -- Cosine similarity function
                local function cosine_similarity(vec1, vec2)
                    if #vec1 ~= #vec2 then
                        error("Vector dimensions must match")
                    end
                    
                    local dot_product = 0
                    local norm_a = 0
                    local norm_b = 0
                    
                    for i = 1, #vec1 do
                        dot_product = dot_product + vec1[i] * vec2[i]
                        norm_a = norm_a + vec1[i] * vec1[i]
                        norm_b = norm_b + vec2[i] * vec2[i]
                    end
                    
                    norm_a = math.sqrt(norm_a)
                    norm_b = math.sqrt(norm_b)
                    
                    if norm_a == 0 or norm_b == 0 then
                        return 0
                    end
                    
                    return dot_product / (norm_a * norm_b)
                end
                
                -- Process poems in this thread
                local processed = 0
                local errors = 0
                
                for _, poem_data in ipairs(batch_data) do
                    local similarities = {}
                    
                    -- Calculate similarities to all other poems
                    for j = 1, #all_embeddings_data do
                        local other_poem = all_embeddings_data[j]
                        
                        if poem_data.index ~= other_poem.index then
                            local similarity = cosine_similarity(poem_data.embedding, other_poem.embedding)
                            
                            table.insert(similarities, {
                                id = other_poem.id,
                                index = other_poem.index,
                                similarity = similarity
                            })
                        end
                    end
                    
                    -- Sort by similarity (highest first)
                    table.sort(similarities, function(a, b) return a.similarity > b.similarity end)
                    
                    -- Create similarity data
                    local poem_similarity_data = {
                        metadata = {
                            poem_id = poem_data.id,
                            poem_index = poem_data.index,
                            total_comparisons = #similarities,
                            calculated_at = os.date("%Y-%m-%d %H:%M:%S"),
                            algorithm = "cosine_similarity"
                        },
                        similarities = similarities
                    }
                    
                    -- Atomic write: use temporary file + rename to prevent partial files
                    local filename = poem_data.id and ("poem_" .. poem_data.id .. ".json") or ("poem_index_" .. poem_data.index .. ".json")
                    local output_file = output_dir .. filename
                    local temp_file = output_dir .. filename .. ".tmp"
                    
                    local json_string = dkjson.encode(poem_similarity_data, { indent = true })
                    if json_string then
                        -- Write to temporary file first
                        local file = io.open(temp_file, "w")
                        if file then
                            file:write(json_string)
                            file:close()
                            
                            -- Atomic rename: only after complete write
                            local rename_success = os.rename(temp_file, output_file)
                            if rename_success then
                                processed = processed + 1
                            else
                                errors = errors + 1
                                os.remove(temp_file) -- cleanup failed temp file
                            end
                        else
                            errors = errors + 1
                        end
                    else
                        errors = errors + 1
                    end
                    
                    -- Temperature control
                    if sleep_duration > 0 then
                        os.execute("sleep " .. sleep_duration)
                    end
                end
                
                return processed, errors
            end)
            
            -- Start thread
            local task = thread_func(batch, valid_embeddings, output_dir, sleep_duration, thread_id)
            threads[thread_id] = task
            tasks[thread_id] = thread_id
        end
        
        -- Wait for all threads to complete
        utils.log_info("⏳ Waiting for " .. #tasks .. " threads to complete...")
        
        for thread_id, task in pairs(threads) do
            local status, processed, errors = task:get()
            if status then
                total_processed = total_processed + processed
                total_errors = total_errors + errors
                utils.log_info("Thread " .. thread_id .. " completed: " .. processed .. " processed, " .. errors .. " errors")
            else
                utils.log_error("Thread " .. thread_id .. " failed: " .. tostring(processed))
                total_errors = total_errors + 1
            end
        end
    
    local end_time = os.time()
    local total_time = end_time - start_time
    
    -- Final verification
    local final_completed_count = count_completed_poems(output_dir, #valid_embeddings)
    
    utils.log_info("🎉 Similarity calculation completed!")
    utils.log_info("⏱️ Total time: " .. total_time .. " seconds")
    utils.log_info("📁 Output directory: " .. output_dir)
    utils.log_info("✅ Completed similarity files: " .. final_completed_count .. "/" .. #valid_embeddings)
    utils.log_info("📊 Processing results: " .. total_processed .. " processed, " .. total_errors .. " errors")
    
    if final_completed_count == #valid_embeddings then
        utils.log_info("🎯 All poem similarities successfully calculated!")
        return true
    else
        local missing = #valid_embeddings - final_completed_count
        utils.log_warn("⚠️ " .. missing .. " poem similarities are missing")
        return false
    end
end
-- }}}

-- {{{ function M.process_poem_batch_external
function M.process_poem_batch_external(batch_poems, all_embeddings, output_dir, sleep_duration, thread_id)
    return process_poem_batch(batch_poems, all_embeddings, output_dir, sleep_duration, thread_id)
end
-- }}}

-- {{{ function M.main
function M.main()
    if arg and arg[1] == "-I" then
        utils.log_info("=== Parallel Similarity Engine ===")
        print("1. Calculate similarity matrix (parallel)")
        print("2. Check similarity calculation status")
        print("Select option (1-2): ")
        
        local choice = io.read()
        
        if choice == "1" then
            print("Force regenerate existing files? (y/N): ")
            local force = io.read():lower() == "y"
            
            print("Sleep duration per poem (default 0.5s): ")
            local sleep_input = io.read()
            local sleep_duration = tonumber(sleep_input) or 0.5
            
            print("Embedding model (default: embeddinggemma:latest): ")
            local model = io.read()
            if model == "" then model = "embeddinggemma:latest" end
            
            local safe_model = model:gsub("[^%w._-]", "_")
            local embeddings_file = "assets/embeddings/" .. safe_model .. "/embeddings.json"
            
            if not utils.file_exists(embeddings_file) then
                utils.log_error("Embeddings file not found: " .. embeddings_file)
                return false
            end
            
            return M.calculate_similarity_matrix_parallel(embeddings_file, model, sleep_duration, force)
            
        elseif choice == "2" then
            print("Embedding model (default: embeddinggemma:latest): ")
            local model = io.read()
            if model == "" then model = "embeddinggemma:latest" end
            
            local output_dir = get_similarity_output_dir(model)
            local completed_count = count_completed_poems(output_dir, 0)
            
            utils.log_info("Similarity files in " .. output_dir .. ": " .. completed_count)
        end
    end
    
    return true
end
-- }}}

if arg and arg[0]:match("similarity%-engine%-parallel%.lua$") then
    M.main()
end

return M