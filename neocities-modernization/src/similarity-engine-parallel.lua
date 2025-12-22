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
-- Add TUI menu library path
package.path = package.path .. ';/home/ritz/programming/ai-stuff/scripts/libs/?.lua'
-- Add dkjson path for menu library
package.path = package.path .. ';/home/ritz/programming/ai-stuff/libs/lua/?.lua'
-- CRITICAL: effil.so is a C library, must be in cpath not path
-- The original bug put .so in package.path which caused "unexpected symbol near char(127)"
package.cpath = package.cpath .. ';/home/ritz/programming/ai-stuff/libs/lua/effil-jit/build/?.so'

local utils = require('utils')
local dkjson = require('dkjson')

-- Initialize asset path configuration (CLI --dir takes precedence over config)
utils.init_assets_root(arg)

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

-- {{{ Signal handling for graceful Ctrl+C interruption
-- Uses LuaJIT FFI to install SIGINT handler and provide native sleep
local ffi = require("ffi")
ffi.cdef[[
    typedef void (*sighandler_t)(int);
    sighandler_t signal(int signum, sighandler_t handler);

    // Native sleep functions - avoids subprocess that eats Ctrl+C signals
    int usleep(unsigned int usec);
    unsigned int sleep(unsigned int seconds);
]]

local SIGINT = 2  -- Standard POSIX signal number for Ctrl+C
local interrupted = false

-- Signal handler callback - sets flag when Ctrl+C is pressed
local function on_interrupt(sig)
    interrupted = true
end

-- Install the signal handler (must keep reference to prevent GC)
local interrupt_handler = ffi.cast("sighandler_t", on_interrupt)
ffi.C.signal(SIGINT, interrupt_handler)

-- Helper to check if interrupted
local function is_interrupted()
    return interrupted
end

-- Helper to reset interrupt flag (for reuse)
local function reset_interrupt()
    interrupted = false
end

-- {{{ function native_sleep
-- Native sleep using FFI - doesn't spawn subprocess, allows Ctrl+C to work
-- Accepts fractional seconds (e.g., 0.5 for 500ms)
local function native_sleep(seconds)
    if seconds <= 0 then return end
    local usec = math.floor(seconds * 1000000)
    ffi.C.usleep(usec)
end
-- }}}
-- }}}

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
    -- Use configured assets path instead of bare relative path
    return utils.get_assets_root() .. "/embeddings/" .. safe_model_name .. "/similarities/"
end
-- }}}

-- {{{ function get_poem_similarity_file
local function get_poem_similarity_file(output_dir, poem_id, poem_index)
    local filename = poem_id and ("poem_" .. poem_id .. ".json") or ("poem_index_" .. poem_index .. ".json")
    return output_dir .. filename
end
-- }}}

-- {{{ function count_completed_poems
-- Parallel validation of existing similarity files
-- Uses effil threads to validate files in parallel with per-thread progress
-- @param output_dir: directory containing similarity files
-- @param total_poems: total number of poems (unused, kept for compatibility)
-- @param requested_threads: optional thread count (defaults to CPU count)
local function count_completed_poems(output_dir, total_poems, requested_threads)
    local completed = 0
    local completed_poems = {}

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

    -- Get list of all files to validate
    local all_files = {}
    local list_handle = io.popen("find '" .. output_dir .. "' -name 'poem_*.json' 2>/dev/null")
    if list_handle then
        for filepath in list_handle:lines() do
            table.insert(all_files, filepath)
        end
        list_handle:close()
    end

    local total_files = #all_files
    if total_files == 0 then
        return 0, completed_poems
    end

    utils.log_info("Found " .. total_files .. " files to validate...")

    -- Determine thread count (use requested, or default to CPU count)
    local cpu_count = get_cpu_count()
    local thread_count = requested_threads or cpu_count
    thread_count = math.min(thread_count, total_files)  -- Don't use more threads than files

    -- Split files into batches
    local files_per_thread = math.ceil(total_files / thread_count)
    local batches = {}
    for t = 1, thread_count do
        local start_idx = (t - 1) * files_per_thread + 1
        local end_idx = math.min(t * files_per_thread, total_files)
        if start_idx <= total_files then
            local batch = {}
            for i = start_idx, end_idx do
                table.insert(batch, all_files[i])
            end
            batches[t] = batch
        end
    end

    -- Create progress channel
    local progress_channel = effil.channel()

    -- Create validation threads
    local threads = {}
    local batch_sizes = {}

    for thread_id, batch in pairs(batches) do
        batch_sizes[thread_id] = #batch

        local thread_func = effil.thread(function(file_batch, thread_id, prog_channel)
            -- Load required modules in thread context
            package.path = package.path .. ';./libs/?.lua;./src/?.lua'
            local dkjson = require('libs.dkjson')

            local valid_count = 0
            local valid_files = {}
            local corrupted = {}
            local checked = 0

            for _, filepath in ipairs(file_batch) do
                local filename = filepath:match("([^/]+)%.json$")
                if filename then
                    -- Read and validate file
                    local file = io.open(filepath, "r")
                    if file then
                        local content = file:read("*a")
                        file:close()

                        local ok, file_data = pcall(dkjson.decode, content)
                        if ok and file_data and file_data.metadata and file_data.similarities and
                           file_data.metadata.total_comparisons and
                           #file_data.similarities == file_data.metadata.total_comparisons then
                            -- File is valid
                            valid_count = valid_count + 1
                            table.insert(valid_files, filename)
                        else
                            -- File is corrupted
                            table.insert(corrupted, filepath)
                        end
                    end
                end

                checked = checked + 1
                -- Send progress update
                prog_channel:push(thread_id, checked)
            end

            return valid_count, valid_files, corrupted
        end)

        threads[thread_id] = thread_func(batch, thread_id, progress_channel)
    end

    -- Progress display
    local thread_progress = {}
    for tid = 1, thread_count do
        thread_progress[tid] = 0
    end
    local first_display = true
    local start_time = os.time()

    local function drain_channel()
        while true do
            local tid, count = progress_channel:pop(0)
            if tid == nil then break end
            thread_progress[tid] = count
        end
    end

    local function display_progress()
        drain_channel()

        -- Move cursor up to overwrite previous display
        -- After initial blank lines: cursor is on line N+2, need to move up N+1
        -- After subsequent displays: cursor is on summary line, need to move up N
        -- Also add \r to go to column 1 (cursor up doesn't change column position)
        if first_display then
            io.write(string.format("\027[%dA\r", thread_count + 1))
            first_display = false
        else
            io.write(string.format("\027[%dA\r", thread_count))
        end

        local total_done = 0
        local total_size = 0

        for tid = 1, thread_count do
            local done = thread_progress[tid] or 0
            local size = batch_sizes[tid] or 0
            total_done = total_done + done
            total_size = total_size + size

            local pct = (done / math.max(size, 1)) * 100
            local bar_width = 20
            local filled = math.floor((done / math.max(size, 1)) * bar_width)
            local bar = string.rep("#", filled) .. string.rep("-", bar_width - filled)
            io.write(string.format("\r  Thread %2d: [%s] %4d/%4d (%5.1f%%)\027[K\n",
                tid, bar, done, size, pct))
        end

        local elapsed = os.time() - start_time
        local rate = total_done / math.max(elapsed, 1)
        local total_pct = (total_done / math.max(total_size, 1)) * 100
        io.write(string.format("\r  --- Total: %d/%d (%.1f%%) | %.1f files/s\027[K",
            total_done, total_size, total_pct, rate))
        io.flush()
    end

    -- Print initial blank lines (thread_count + 1 for summary)
    for _ = 1, thread_count + 1 do
        print("")
    end

    -- Poll progress while threads run
    local all_done = false
    while not all_done do
        display_progress()
        all_done = true
        for _, task in pairs(threads) do
            local status = task:status()
            if status ~= "completed" and status ~= "failed" then
                all_done = false
            end
        end
        if not all_done then
            native_sleep(0.2)
        end
    end

    -- Final display
    display_progress()
    print("")  -- newline after progress

    -- Collect results
    local total_valid = 0
    local all_corrupted = {}

    for thread_id, task in pairs(threads) do
        local valid_count, valid_files, corrupted = task:get()
        if valid_count then
            total_valid = total_valid + valid_count
            for _, filename in ipairs(valid_files) do
                completed_poems[filename] = true
            end
            for _, filepath in ipairs(corrupted) do
                table.insert(all_corrupted, filepath)
            end
        end
    end

    -- Remove corrupted files
    if #all_corrupted > 0 then
        utils.log_warn("Removing " .. #all_corrupted .. " corrupted files...")
        for _, filepath in ipairs(all_corrupted) do
            os.remove(filepath)
        end
    end

    return total_valid, completed_poems
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
    -- Uses native FFI sleep to allow Ctrl+C to work properly
    if sleep_duration > 0 then
        native_sleep(sleep_duration)
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
-- @param embeddings_file: path to embeddings JSON file
-- @param model_name: model name for output directory
-- @param sleep_duration: delay between poems for thermal management (default 0.5)
-- @param force_regenerate: if true, delete and recreate all files
-- @param requested_threads: optional thread count (defaults to CPU count)
function M.calculate_similarity_matrix_parallel(embeddings_file, model_name, sleep_duration, force_regenerate, requested_threads)
    sleep_duration = sleep_duration or 0.5
    force_regenerate = force_regenerate or false

    -- Determine thread count (use requested, or default to CPU count)
    local cpu_count = get_cpu_count()
    local thread_count = requested_threads or cpu_count

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

    -- Check for existing work (resume capability) - use same thread count
    local completed_count, completed_poems = count_completed_poems(output_dir, #valid_embeddings, thread_count)

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

    -- Limit thread count to remaining work
    thread_count = math.min(thread_count, #remaining_poems)

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

        -- Track batch sizes for progress display
        local batch_sizes = {}
        local total_to_process = 0
        for thread_id, batch in pairs(batches) do
            batch_sizes[thread_id] = #batch
            total_to_process = total_to_process + #batch
        end

        -- Create shared channel for progress updates from threads
        -- Channel allows threads to send (thread_id, progress) messages to main thread
        local progress_channel = effil.channel()

        -- Create thread pool and tasks
        local threads = {}
        local tasks = {}

        for thread_id, batch in pairs(batches) do
            -- Create thread function with channel for progress reporting
            local thread_func = effil.thread(function(batch_data, all_embeddings_data, output_dir, sleep_duration, thread_id, prog_channel)
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
                
                -- State codes for channel messages (negative = state, positive = progress count)
                local STATE_RESTING = -1
                local STATE_PROCESSING = -2

                -- Process poems in this thread
                local processed = 0
                local errors = 0

                for _, poem_data in ipairs(batch_data) do
                    -- Signal that we're now processing
                    prog_channel:push(thread_id, STATE_PROCESSING)

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
                                -- Send progress update through channel
                                prog_channel:push(thread_id, processed)
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
                    
                    -- Temperature control: signal resting state before sleep
                    if sleep_duration > 0 then
                        prog_channel:push(thread_id, STATE_RESTING)
                        os.execute("sleep " .. sleep_duration)
                    end
                end

                return processed, errors
            end)
            
            -- Start thread (progress reported via channel)
            local task = thread_func(batch, valid_embeddings, output_dir, sleep_duration, thread_id, progress_channel)
            threads[thread_id] = task
            tasks[thread_id] = thread_id
        end

        -- Per-thread progress tracking via channel messages
        -- Each thread sends (thread_id, processed_count) after each poem
        -- State codes: -1 = resting, -2 = processing, >=0 = progress count
        local STATE_RESTING = -1
        local STATE_PROCESSING = -2
        local thread_progress = {}
        local thread_state = {}  -- "processing" or "resting"
        for tid = 1, thread_count do
            thread_progress[tid] = 0
            thread_state[tid] = "processing"  -- assume processing initially
        end
        local first_display = true

        -- ANSI color codes for terminal display
        local COLOR_GREEN = "\027[32m"   -- processing
        local COLOR_CYAN = "\027[36m"    -- resting
        local COLOR_RESET = "\027[0m"

        local function drain_channel()
            -- Read all available messages from channel (non-blocking)
            -- Messages are either state updates (negative) or progress counts (>=0)
            while true do
                local tid, value = progress_channel:pop(0)  -- timeout=0 for non-blocking
                if tid == nil then break end
                if value == STATE_RESTING then
                    thread_state[tid] = "resting"
                elseif value == STATE_PROCESSING then
                    thread_state[tid] = "processing"
                else
                    -- Progress count update
                    thread_progress[tid] = value
                end
            end
        end

        local function display_progress()
            drain_channel()

            -- Move cursor up to overwrite previous display
            -- After initial blank lines: cursor is on line N+2, need to move up N+1
            -- After subsequent displays: cursor is on summary line, need to move up N
            -- Also add \r to go to column 1 (cursor up doesn't change column position)
            if first_display then
                io.write(string.format("\027[%dA\r", thread_count + 1))
                first_display = false
            else
                io.write(string.format("\027[%dA\r", thread_count))
            end

            local total_done = 0
            local total_size = 0

            -- Print each thread's progress on its own line with color coding
            -- Green = processing, Cyan = resting (with indicator)
            for tid = 1, thread_count do
                local done = thread_progress[tid] or 0
                local size = batch_sizes[tid] or 0
                local state = thread_state[tid] or "processing"
                total_done = total_done + done
                total_size = total_size + size

                local pct = (done / math.max(size, 1)) * 100
                local bar_width = 20
                local filled = math.floor((done / math.max(size, 1)) * bar_width)
                local bar = string.rep("#", filled) .. string.rep("-", bar_width - filled)

                -- Choose color based on thread state
                local color = (state == "resting") and COLOR_CYAN or COLOR_GREEN
                local suffix = (state == "resting") and " (resting)" or ""

                io.write(string.format("\r  %sThread %2d: [%s] %4d/%4d (%5.1f%%)%s%s\027[K\n",
                    color, tid, bar, done, size, pct, suffix, COLOR_RESET))
            end

            -- Summary line (use ASCII characters for compatibility)
            local elapsed = os.time() - start_time
            local rate = total_done / math.max(elapsed, 1)
            local eta = (total_size - total_done) / math.max(rate, 0.01)
            local total_pct = (total_done / math.max(total_size, 1)) * 100
            io.write(string.format("\r  --- Total: %d/%d (%.1f%%) | %.2f/s | ETA: %ds\027[K",
                total_done, total_size, total_pct, rate, math.floor(eta)))
            io.flush()
        end

        -- Wait for all threads to complete with progress updates
        utils.log_info("⏳ Waiting for " .. thread_count .. " threads to complete...")
        utils.log_info("💡 Press Ctrl+C to gracefully stop (threads will finish current poem)")
        -- Print initial blank lines for progress display area (thread_count + 1 for summary)
        for _ = 1, thread_count + 1 do
            print("")
        end

        -- Poll progress while threads are running (check for Ctrl+C interrupt)
        local all_done = false
        local was_interrupted = false
        while not all_done do
            display_progress()

            -- Check for Ctrl+C interrupt
            if is_interrupted() then
                was_interrupted = true
                -- Move below progress display before printing message
                io.write("\n")
                utils.log_warn("⚠️ Ctrl+C detected! Waiting for threads to finish current poem...")
                break
            end

            all_done = true
            for thread_id, task in pairs(threads) do
                local status = task:status()
                if status ~= "completed" and status ~= "failed" then
                    all_done = false
                end
            end
            if not all_done then
                native_sleep(0.5)
            end
        end
        print("") -- newline after progress

        -- If interrupted, wait briefly for threads to finish their current work
        if was_interrupted then
            utils.log_info("⏳ Giving threads 5 seconds to complete current work...")
            native_sleep(5)
        end

        for thread_id, task in pairs(threads) do
            local status, processed, errors = task:get(0)  -- Non-blocking get with timeout=0
            if status then
                total_processed = total_processed + processed
                total_errors = total_errors + errors
                utils.log_info("Thread " .. thread_id .. " completed: " .. processed .. " processed, " .. errors .. " errors")
            elseif was_interrupted then
                -- Thread may still be running - that's ok, we'll count files later
                utils.log_info("Thread " .. thread_id .. ": interrupted (partial results saved)")
            else
                utils.log_error("Thread " .. thread_id .. " failed: " .. tostring(processed))
                total_errors = total_errors + 1
            end
        end

        -- Reset interrupt flag for potential future runs
        reset_interrupt()
    
    local end_time = os.time()
    local total_time = end_time - start_time

    -- Final verification
    local final_completed_count = count_completed_poems(output_dir, #valid_embeddings)

    if was_interrupted then
        utils.log_info("⏸️ Similarity calculation interrupted by user")
    else
        utils.log_info("🎉 Similarity calculation completed!")
    end
    utils.log_info("⏱️ Total time: " .. total_time .. " seconds")
    utils.log_info("📁 Output directory: " .. output_dir)
    utils.log_info("✅ Completed similarity files: " .. final_completed_count .. "/" .. #valid_embeddings)
    utils.log_info("📊 Processing results: " .. total_processed .. " processed, " .. total_errors .. " errors")

    if final_completed_count == #valid_embeddings then
        utils.log_info("🎯 All poem similarities successfully calculated!")
        return true
    else
        local missing = #valid_embeddings - final_completed_count
        if was_interrupted then
            utils.log_info("💡 Run again to resume - already-completed files will be skipped")
        else
            utils.log_warn("⚠️ " .. missing .. " poem similarities are missing")
        end
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
        -- Load TUI menu library
        local menu_ok, menu = pcall(require, "menu")
        local tui_ok, tui = pcall(require, "tui")

        if not menu_ok or not tui_ok then
            -- Fallback to simple text menu if TUI not available
            utils.log_warn("TUI menu not available, using text mode")
            return M.main_text_mode()
        end

        -- Get CPU count for default thread value
        local cpu_count = get_cpu_count()

        -- Build menu configuration
        local config = {
            title = "Parallel Similarity Engine",
            subtitle = "Generate full similarity rankings for all poems",
            sections = {
                {
                    id = "action",
                    title = "Action",
                    type = "single",
                    items = {
                        {
                            id = "calculate",
                            label = "Calculate similarity matrix (parallel)",
                            type = "checkbox",
                            value = "1",
                            description = "Generate individual similarity files for all poems",
                            shortcut = "c"
                        },
                        {
                            id = "check_status",
                            label = "Check calculation status",
                            type = "checkbox",
                            value = "0",
                            description = "View progress of similarity file generation",
                            shortcut = "s"
                        }
                    }
                },
                {
                    id = "options",
                    title = "Options",
                    type = "multi",
                    items = {
                        {
                            id = "force",
                            label = "Force regenerate",
                            type = "checkbox",
                            value = "0",
                            description = "Delete and recreate all existing similarity files",
                            shortcut = "f"
                        },
                        {
                            id = "sleep",
                            label = "Sleep duration (sec)",
                            type = "flag",
                            value = "0.5",
                            config = "6",  -- Width of input field (separate from value)
                            description = "Delay between poems for thermal management (e.g. 0.5)",
                            flag = "--sleep"
                        },
                        {
                            id = "threads",
                            label = "Thread count",
                            type = "flag",
                            value = tostring(cpu_count),
                            config = "3",
                            description = "Number of parallel threads (detected " .. cpu_count .. " CPUs)",
                            flag = "--threads"
                        },
                        {
                            id = "model",
                            label = "Embedding model",
                            type = "text",
                            value = "embeddinggemma:latest",
                            description = "Model used for embeddings (stored in assets/embeddings/)"
                        }
                    }
                },
                {
                    id = "run",
                    title = "",
                    type = "single",
                    items = {
                        {
                            id = "run_action",
                            label = "[Run]",
                            type = "action",
                            value = "",
                            description = "Execute selected action with current options"
                        }
                    }
                }
            },
            -- Only enable some options when "calculate" is selected
            dependencies = {
                {
                    item_id = "force",
                    depends_on = "calculate",
                    required_values = {"1"},
                    invert = false,
                    reason = "Only available for Calculate action"
                },
                {
                    item_id = "sleep",
                    depends_on = "calculate",
                    required_values = {"1"},
                    invert = false,
                    reason = "Only available for Calculate action"
                }
                -- Note: threads is available for both actions (validation uses it too)
            }
        }

        -- Run TUI menu
        local action, values
        local success, err = pcall(function()
            menu.init(config)
            action, values = menu.run()
            menu.cleanup()
        end)

        if not success then
            pcall(menu.cleanup)
            utils.log_error("Menu error: " .. tostring(err))
            return false
        end

        -- Handle quit
        if action == "quit" then
            utils.log_info("Cancelled by user")
            return true
        end

        -- Execute selected action
        local thread_count = tonumber(values.threads) or cpu_count

        if values.calculate == "1" then
            local force = values.force == "1"
            local sleep_duration = tonumber(values.sleep) or 0.5
            local model = values.model or "embeddinggemma:latest"
            if model == "" then model = "embeddinggemma:latest" end

            local safe_model = model:gsub("[^%w._-]", "_")
            -- Use configured assets path instead of bare relative path
            local embeddings_file = utils.get_assets_root() .. "/embeddings/" .. safe_model .. "/embeddings.json"

            if not utils.file_exists(embeddings_file) then
                utils.log_error("Embeddings file not found: " .. embeddings_file)
                return false
            end

            return M.calculate_similarity_matrix_parallel(embeddings_file, model, sleep_duration, force, thread_count)

        elseif values.check_status == "1" then
            local model = values.model or "embeddinggemma:latest"
            if model == "" then model = "embeddinggemma:latest" end

            local output_dir = get_similarity_output_dir(model)
            utils.log_info("Checking " .. output_dir .. " ...")

            -- Quick count first (no validation)
            local quick_count_handle = io.popen("find '" .. output_dir .. "' -name 'poem_*.json' 2>/dev/null | wc -l")
            local quick_count = 0
            if quick_count_handle then
                quick_count = tonumber(quick_count_handle:read("*a")) or 0
                quick_count_handle:close()
            end
            utils.log_info("Found " .. quick_count .. " similarity files (validating...)")

            local completed_count = count_completed_poems(output_dir, 0, thread_count)

            utils.log_info("✅ Valid similarity files: " .. completed_count .. "/" .. quick_count)
        else
            utils.log_info("No action selected")
        end
    end

    return true
end
-- }}}

-- {{{ function M.main_text_mode
-- Fallback text-based menu when TUI is not available
function M.main_text_mode()
    local cpu_count = get_cpu_count()

    utils.log_info("=== Parallel Similarity Engine (Text Mode) ===")
    print("1. Calculate similarity matrix (parallel)")
    print("2. Check similarity calculation status")
    print("q. Quit")
    io.write("Select option: ")
    io.flush()

    local choice = io.read()

    if choice == "q" or choice == "Q" then
        utils.log_info("Cancelled by user")
        return true
    elseif choice == "1" then
        io.write("Force regenerate existing files? (y/N): ")
        io.flush()
        local force = (io.read() or ""):lower() == "y"

        io.write("Sleep duration per poem (default 0.5s): ")
        io.flush()
        local sleep_input = io.read()
        local sleep_duration = tonumber(sleep_input) or 0.5

        io.write("Thread count (default " .. cpu_count .. " detected CPUs): ")
        io.flush()
        local thread_input = io.read()
        local thread_count = tonumber(thread_input) or cpu_count

        io.write("Embedding model (default: embeddinggemma:latest): ")
        io.flush()
        local model = io.read() or ""
        if model == "" then model = "embeddinggemma:latest" end

        local safe_model = model:gsub("[^%w._-]", "_")
        -- Use configured assets path instead of bare relative path
        local embeddings_file = utils.get_assets_root() .. "/embeddings/" .. safe_model .. "/embeddings.json"

        if not utils.file_exists(embeddings_file) then
            utils.log_error("Embeddings file not found: " .. embeddings_file)
            return false
        end

        return M.calculate_similarity_matrix_parallel(embeddings_file, model, sleep_duration, force, thread_count)

    elseif choice == "2" then
        io.write("Thread count for validation (default " .. cpu_count .. " detected CPUs): ")
        io.flush()
        local thread_input = io.read()
        local thread_count = tonumber(thread_input) or cpu_count

        io.write("Embedding model (default: embeddinggemma:latest): ")
        io.flush()
        local model = io.read() or ""
        if model == "" then model = "embeddinggemma:latest" end

        local output_dir = get_similarity_output_dir(model)
        utils.log_info("Checking " .. output_dir .. " ...")

        -- Quick count first (no validation)
        local quick_count_handle = io.popen("find '" .. output_dir .. "' -name 'poem_*.json' 2>/dev/null | wc -l")
        local quick_count = 0
        if quick_count_handle then
            quick_count = tonumber(quick_count_handle:read("*a")) or 0
            quick_count_handle:close()
        end
        utils.log_info("Found " .. quick_count .. " similarity files (validating...)")

        local completed_count = count_completed_poems(output_dir, 0, thread_count)

        utils.log_info("✅ Valid similarity files: " .. completed_count .. "/" .. quick_count)
    end

    return true
end
-- }}}

if arg and arg[0]:match("similarity%-engine%-parallel%.lua$") then
    M.main()
end

return M