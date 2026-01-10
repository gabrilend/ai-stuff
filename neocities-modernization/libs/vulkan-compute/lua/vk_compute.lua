-- vk_compute.lua - LuaJIT FFI bindings for Vulkan Compute Library
--
-- This module provides a Lua-friendly interface to GPU-accelerated
-- diversity sequence computation and similarity operations.
--
-- Usage:
--   local vk = require("vk_compute")
--   local ctx = vk.init()
--   local embeddings = {...}  -- Flat array of floats
--   local sequence = vk.compute_diversity_sequence(ctx, embeddings, 7797, 768, 0)
--   vk.shutdown(ctx)

local ffi = require("ffi")

-- {{{ local M = {}
local M = {}
-- }}}

-- {{{ FFI definitions
ffi.cdef[[
    // Opaque handles
    typedef struct VkComputeContext VkComputeContext;
    typedef struct VkDiversityContext VkDiversityContext;

    // Error codes
    typedef enum {
        VKC_SUCCESS = 0,
        VKC_ERROR_INIT_FAILED = -1,
        VKC_ERROR_NO_SUITABLE_DEVICE = -2,
        VKC_ERROR_BUFFER_CREATION_FAILED = -3,
        VKC_ERROR_SHADER_LOAD_FAILED = -4,
        VKC_ERROR_PIPELINE_CREATION_FAILED = -5,
        VKC_ERROR_COMMAND_EXECUTION_FAILED = -6,
        VKC_ERROR_OUT_OF_MEMORY = -7,
    } VkComputeResult;

    // Core Vulkan compute functions
    VkComputeContext* vkc_init(bool enable_validation);
    void vkc_destroy(VkComputeContext* ctx);
    const char* vkc_get_error_string(VkComputeResult result);
    const char* vkc_get_device_name(VkComputeContext* ctx);
    uint64_t vkc_get_device_memory(VkComputeContext* ctx);

    // Diversity sequence functions
    VkDiversityContext* vkd_init(VkComputeContext* ctx,
                                 const float* embeddings,
                                 uint32_t num_poems,
                                 uint32_t embedding_dim);
    VkComputeResult vkd_compute_sequence(VkDiversityContext* div_ctx,
                                         uint32_t start_poem,
                                         uint32_t* output_sequence);
    void vkd_destroy(VkDiversityContext* div_ctx);

    // Batch processing functions
    typedef struct VkDiversityBatchContext VkDiversityBatchContext;

    VkDiversityBatchContext* vkd_batch_init(VkComputeContext* ctx,
                                             const float* embeddings,
                                             uint32_t num_poems,
                                             uint32_t embedding_dim,
                                             uint32_t batch_size,
                                             const uint32_t* start_indices);
    VkComputeResult vkd_batch_step(VkDiversityBatchContext* batch_ctx,
                                    uint32_t iteration,
                                    uint32_t* selections);
    VkComputeResult vkd_batch_download_sequences(VkDiversityBatchContext* batch_ctx,
                                                  uint32_t* output_sequences);
    void vkd_batch_destroy(VkDiversityBatchContext* batch_ctx);
]]
-- }}}

-- {{{ Load shared library
local lib_path = _G.VK_COMPUTE_LIB or
                 os.getenv("VK_COMPUTE_LIB") or
                 "./libs/vulkan-compute/build/libvkcompute.so"
local vk = ffi.load(lib_path)
-- }}}

-- {{{ Error handling helper
local function check_result(result, operation)
    if result ~= 0 then
        local err_str = ffi.string(vk.vkc_get_error_string(result))
        error(string.format("%s failed: %s (code %d)", operation, err_str, tonumber(result)))
    end
end
-- }}}

-- {{{ local function init()
-- Initialize Vulkan compute context
-- Returns: Context handle (must be passed to shutdown when done)
function M.init(enable_validation)
    enable_validation = enable_validation or false
    local ctx = vk.vkc_init(enable_validation)
    if ctx == nil then
        error("Failed to initialize Vulkan context")
    end

    -- Print device info
    local device_name = ffi.string(vk.vkc_get_device_name(ctx))
    local device_memory = tonumber(vk.vkc_get_device_memory(ctx))
    print(string.format("[Vulkan] Device: %s (%.2f GB)",
                        device_name, device_memory / 1024^3))

    return ctx
end
-- }}}

-- {{{ local function shutdown()
-- Cleanup Vulkan resources
function M.shutdown(ctx)
    if ctx ~= nil then
        vk.vkc_destroy(ctx)
    end
end
-- }}}

-- {{{ local function compute_diversity_sequence()
-- Compute a diversity sequence starting from a given poem
--
-- Parameters:
--   ctx - Vulkan compute context from init()
--   embeddings - Flat Lua table of floats (num_poems * embedding_dim)
--   num_poems - Number of poems
--   embedding_dim - Dimension of embeddings (e.g., 768)
--   start_poem - Index of starting poem (0-indexed)
--
-- Returns: Lua table of poem indices representing the diversity sequence
function M.compute_diversity_sequence(ctx, embeddings, num_poems, embedding_dim, start_poem)
    -- Convert Lua table to C float array
    local embeddings_arr = ffi.new("float[?]", num_poems * embedding_dim)
    for i = 1, num_poems * embedding_dim do
        embeddings_arr[i - 1] = embeddings[i]
    end

    -- Initialize diversity context
    local div_ctx = vk.vkd_init(ctx, embeddings_arr, num_poems, embedding_dim)
    if div_ctx == nil then
        error("Failed to initialize diversity context")
    end

    -- Allocate output sequence buffer
    local sequence_arr = ffi.new("uint32_t[?]", num_poems)

    -- Compute sequence
    local result = vk.vkd_compute_sequence(div_ctx, start_poem, sequence_arr)
    check_result(result, "Diversity sequence computation")

    -- Convert C array to Lua table
    local sequence = {}
    for i = 0, num_poems - 1 do
        sequence[i + 1] = tonumber(sequence_arr[i])
    end

    -- Cleanup diversity context
    vk.vkd_destroy(div_ctx)

    return sequence
end
-- }}}

-- {{{ local function compute_all_diversity_sequences()
-- Compute diversity sequences for all poems
--
-- Parameters:
--   ctx - Vulkan compute context
--   embeddings - Flat Lua table of floats
--   num_poems - Number of poems
--   embedding_dim - Dimension of embeddings
--   output_file - Optional file path to write sequences
--   start_from - Optional poem index to resume from (default: 0)
--
-- Returns: Table mapping poem_id -> sequence table
function M.compute_all_diversity_sequences(ctx, embeddings, num_poems, embedding_dim, output_file, start_from)
    start_from = start_from or 0
    print(string.format("[Diversity] Computing sequences for %d poems (starting from %d)...",
                       num_poems, start_from))

    local sequences = {}
    local start_time = os.clock()

    -- Open output file for incremental writing if specified
    local out_file = nil
    if output_file then
        -- Check if file exists for resume
        local existing = io.open(output_file, "rb")
        if existing and start_from == 0 then
            print("[Diversity] Warning: Output file exists, will overwrite")
            existing:close()
            out_file = io.open(output_file, "wb")
            -- Write header: num_poems (4 bytes)
            local header = ffi.new("uint32_t[1]", num_poems)
            out_file:write(ffi.string(header, 4))
        elseif existing then
            print(string.format("[Diversity] Resuming: appending to existing file"))
            existing:close()
            out_file = io.open(output_file, "ab")  -- Append mode
        else
            out_file = io.open(output_file, "wb")
            -- Write header: num_poems (4 bytes)
            local header = ffi.new("uint32_t[1]", num_poems)
            out_file:write(ffi.string(header, 4))
        end

        if not out_file then
            error("Failed to open output file: " .. output_file)
        end
    end

    -- Convert embeddings once
    local embeddings_arr = ffi.new("float[?]", num_poems * embedding_dim)
    for i = 1, num_poems * embedding_dim do
        embeddings_arr[i - 1] = embeddings[i]
    end

    -- Initialize diversity context once
    local div_ctx = vk.vkd_init(ctx, embeddings_arr, num_poems, embedding_dim)
    if div_ctx == nil then
        error("Failed to initialize diversity context")
    end

    local sequence_arr = ffi.new("uint32_t[?]", num_poems)

    -- Compute sequence for each poem
    for start_poem = start_from, num_poems - 1 do
        local result = vk.vkd_compute_sequence(div_ctx, start_poem, sequence_arr)
        check_result(result, string.format("Diversity sequence for poem %d", start_poem))

        -- Convert to Lua table
        local sequence = {}
        for i = 0, num_poems - 1 do
            sequence[i + 1] = tonumber(sequence_arr[i])
        end
        sequences[start_poem] = sequence

        -- Write sequence to file immediately if file is open
        if out_file then
            out_file:write(ffi.string(sequence_arr, num_poems * 4))
            -- Flush every 10 sequences to ensure progress is saved
            if (start_poem + 1) % 10 == 0 then
                out_file:flush()
            end
        end

        -- Progress update every 100 poems
        if (start_poem + 1 - start_from) % 100 == 0 or start_poem == num_poems - 1 then
            local elapsed = os.clock() - start_time
            local computed = start_poem + 1 - start_from
            local rate = computed / elapsed
            local remaining = (num_poems - start_poem - 1) / rate
            local eta_hours = remaining / 3600
            print(string.format("  [%d/%d] %.2f seq/sec, ETA: %.1fh (%.0fs)",
                              start_poem + 1, num_poems, rate, eta_hours, remaining))
        end
    end

    vk.vkd_destroy(div_ctx)

    -- Close output file if open
    if out_file then
        out_file:close()
        print(string.format("[Diversity] Wrote sequences to: %s", output_file))
    end

    local elapsed = os.clock() - start_time
    local computed = num_poems - start_from
    print(string.format("[Diversity] Completed %d sequences in %.2fs (%.2f seq/s)",
                       computed, elapsed, computed / elapsed))

    return sequences
end
-- }}}

-- {{{ local function write_sequences_to_file()
-- Write diversity sequences to file in binary format
function M.write_sequences_to_file(sequences, output_file)
    local f = io.open(output_file, "wb")
    if not f then
        error("Failed to open output file: " .. output_file)
    end

    local num_poems = #sequences

    -- Write header: num_poems (4 bytes) using FFI
    local header = ffi.new("uint32_t[1]", num_poems)
    f:write(ffi.string(header, 4))

    -- Write each sequence
    for poem_id = 0, num_poems - 1 do
        local sequence = sequences[poem_id]
        for i = 1, #sequence do
            local value = ffi.new("uint32_t[1]", sequence[i])
            f:write(ffi.string(value, 4))
        end
    end

    f:close()
    print(string.format("[Diversity] Wrote sequences to %s", output_file))
end
-- }}}

-- {{{ local function load_sequences_from_file()
-- Load diversity sequences from binary file
function M.load_sequences_from_file(input_file)
    local f = io.open(input_file, "rb")
    if not f then
        error("Failed to open input file: " .. input_file)
    end

    -- Read header using FFI
    local header_data = f:read(4)
    local header = ffi.cast("uint32_t*", header_data)
    local num_poems = tonumber(header[0])

    -- Read sequences
    local sequences = {}
    for poem_id = 0, num_poems - 1 do
        local sequence = {}
        for i = 1, num_poems do
            local data = f:read(4)
            local value = ffi.cast("uint32_t*", data)
            sequence[i] = tonumber(value[0])
        end
        sequences[poem_id] = sequence
    end

    f:close()
    print(string.format("[Diversity] Loaded %d sequences from %s", num_poems, input_file))
    return sequences
end
-- }}}

-- {{{ local function compute_all_diversity_sequences_batched()
-- Compute diversity sequences using batch parallel processing (2,600× faster)
--
-- Parameters:
--   ctx - Vulkan compute context
--   embeddings - Flat Lua table of floats
--   num_poems - Number of poems
--   embedding_dim - Dimension of embeddings
--   output_file - File path to write sequences
--   batch_size - Optional batch size (default: 3584)
--
-- Returns: Table mapping poem_id -> sequence table
function M.compute_all_diversity_sequences_batched(ctx, embeddings, num_poems, embedding_dim, output_file, batch_size)
    batch_size = batch_size or 3584

    print(string.format("[Diversity Batch] Computing sequences for %d poems (batch size: %d)...",
                       num_poems, batch_size))

    local start_time = os.clock()
    local all_sequences = {}

    -- Convert embeddings once
    local embeddings_arr = ffi.new("float[?]", num_poems * embedding_dim)
    for i = 1, num_poems * embedding_dim do
        embeddings_arr[i - 1] = embeddings[i]
    end

    -- Process in batches
    local num_batches = math.ceil(num_poems / batch_size)

    for batch_num = 1, num_batches do
        local batch_start = (batch_num - 1) * batch_size
        local batch_end = math.min(batch_start + batch_size - 1, num_poems - 1)
        local current_batch_size = batch_end - batch_start + 1

        print(string.format("\n[Batch %d/%d] Processing poems %d-%d (%d sequences)",
                           batch_num, num_batches, batch_start, batch_end, current_batch_size))

        -- Create start indices for this batch
        local start_indices = ffi.new("uint32_t[?]", current_batch_size)
        for i = 0, current_batch_size - 1 do
            start_indices[i] = batch_start + i
        end

        -- Initialize batch context
        local batch_ctx = vk.vkd_batch_init(ctx, embeddings_arr, num_poems, embedding_dim,
                                             current_batch_size, start_indices)
        if batch_ctx == nil then
            error("Failed to initialize batch context")
        end

        -- Run iterations
        local batch_start_time = os.clock()
        print(string.format("  Starting %d iterations...", num_poems - 1))
        io.stdout:flush()

        for iteration = 1, num_poems - 1 do
            local result = vk.vkd_batch_step(batch_ctx, iteration, nil)
            check_result(result, string.format("Batch step iteration %d", iteration))

            -- Progress update every 100 iterations
            if iteration % 100 == 0 or iteration == 1 or iteration == num_poems - 1 then
                local elapsed = os.clock() - batch_start_time
                local rate = iteration / elapsed
                local remaining = (num_poems - iteration) / rate
                print(string.format("  [%d/%d] %.2f iter/sec, ETA: %.1fs (elapsed: %.1fs)",
                                  iteration, num_poems, rate, remaining, elapsed))
                io.stdout:flush()
            end
        end
        print(string.format("  All %d iterations complete!", num_poems - 1))
        io.stdout:flush()

        -- Download sequences for this batch
        local batch_sequences_arr = ffi.new("uint32_t[?]", current_batch_size * num_poems)
        local result = vk.vkd_batch_download_sequences(batch_ctx, batch_sequences_arr)
        check_result(result, "Download batch sequences")

        -- Convert to Lua tables
        for i = 0, current_batch_size - 1 do
            local poem_id = batch_start + i
            local sequence = {}
            for j = 0, num_poems - 1 do
                sequence[j + 1] = tonumber(batch_sequences_arr[i * num_poems + j])
            end
            all_sequences[poem_id] = sequence
        end

        -- Cleanup batch
        vk.vkd_batch_destroy(batch_ctx)

        local batch_elapsed = os.clock() - batch_start_time
        print(string.format("[Batch %d/%d] Completed in %.2fs (%.2f seq/s)",
                           batch_num, num_batches, batch_elapsed, current_batch_size / batch_elapsed))
    end

    local total_elapsed = os.clock() - start_time
    print(string.format("\n[Diversity Batch] Completed ALL %d sequences in %.2fs (%.2f seq/s)",
                       num_poems, total_elapsed, num_poems / total_elapsed))

    -- Write to file if requested
    if output_file then
        M.write_sequences_to_file(all_sequences, output_file)
    end

    return all_sequences
end
-- }}}

return M
