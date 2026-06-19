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
-- socket.gettime() is sub-second wall-clock time. We use it instead of
-- os.clock() because the diversity loop spends most of its CPU thread
-- blocked in vkWaitForFences (the GPU is busy, the CPU is sleeping),
-- and os.clock() only counts time the process was actually scheduled —
-- so it under-reports the elapsed time by orders of magnitude and makes
-- the iter/sec line claim impossible speeds.
local socket = require("socket")
local wall_clock = socket.gettime

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
                                             const uint16_t* embeddings_fp16,
                                             uint32_t num_poems,
                                             uint32_t embedding_dim,
                                             uint32_t batch_size,
                                             const uint32_t* start_indices);
    VkComputeResult vkd_batch_compute_chunk(VkDiversityBatchContext* batch_ctx,
                                             uint32_t start_slot,
                                             uint32_t slot_count);
    VkComputeResult vkd_batch_download_sequences(VkDiversityBatchContext* batch_ctx,
                                                  uint32_t* output_sequences);
    void vkd_batch_destroy(VkDiversityBatchContext* batch_ctx);

    // FP16 conversion helpers. The bulk FP32 -> FP16 routine is used to
    // produce the on-disk embeddings_fp16.bin cache file from the FP32
    // embeddings.json.
    void vkc_fp32_to_fp16(const float* src, uint16_t* dst, uint32_t count);
    float vkc_fp16_to_fp32(uint16_t bits);
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

-- {{{ local function format_duration
-- Pretty-print a wall-clock duration in seconds as either "Hh Mm", "Mm Ss",
-- or "Ss" depending on magnitude. Used for ETAs in long progress loops where
-- the bare-seconds number is hard to grasp.
local function format_duration(seconds)
    if seconds < 60 then
        return string.format("%.0fs", seconds)
    elseif seconds < 3600 then
        return string.format("%dm %02ds", math.floor(seconds / 60), math.floor(seconds) % 60)
    else
        return string.format("%dh %02dm",
                             math.floor(seconds / 3600),
                             math.floor((seconds % 3600) / 60))
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
-- embeddings_fp16 is now a uint16_t FFI buffer of length num_poems *
-- embedding_dim, holding FP16-packed values in row-major order. The
-- wrapper script is responsible for producing this buffer (typically
-- by reading a cached embeddings_fp16.bin file). We no longer accept
-- a Lua-table flat array because the per-element copy loop into an
-- FFI float[?] was a measurable bottleneck on ~20 million floats, and
-- the new path uses ffi.copy from a binary file straight into the
-- target buffer instead.
function M.compute_all_diversity_sequences_batched(ctx, embeddings_fp16, num_poems, embedding_dim, output_file, batch_size)
    batch_size = batch_size or 3584

    print(string.format("[Diversity Batch] Computing sequences for %d poems (batch size: %d, FP16 storage)...",
                       num_poems, batch_size))

    local start_time = wall_clock()
    local all_sequences = {}

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

        -- Initialize batch context with the FP16 embedding buffer directly.
        local batch_ctx = vk.vkd_batch_init(ctx, embeddings_fp16, num_poems, embedding_dim,
                                             current_batch_size, start_indices)
        if batch_ctx == nil then
            error("Failed to initialize batch context")
        end

        -- Chunked GPU dispatch with adaptive chunk sizing.
        --
        -- Why chunks: a single dispatch covering all num_poems-1 iterations
        -- runs long enough to trip the kernel GPU watchdog (typically
        -- 2 s on Wayland / 10 s on Xorg), at which point Vulkan reports
        -- VK_ERROR_DEVICE_LOST and the rest of the run is dead.
        --
        -- Why adaptive: per-iteration cost depends on the dataset size,
        -- GPU model, residency, and how much display work is competing
        -- for the GPU right now. Hardcoding a chunk size that's safe
        -- everywhere makes the common case much slower than it needs to
        -- be. Instead, we run a small probe dispatch first to measure
        -- actual iter-time on this run, then size all subsequent chunks
        -- to fit comfortably under a target wall-clock budget per chunk.
        --
        -- The probe is one extra dispatch per batch, rounding error in
        -- a ~100-chunk batch. The first chunk is intentionally tiny so a
        -- pathologically slow GPU still survives it.
        local PROBE_ITERS = 10            -- size of the warm-up probe
        local TARGET_CHUNK_SECONDS = 1.5  -- aim for this much GPU work per dispatch
        local SAFETY_FACTOR = 0.6         -- pad below the measured ceiling so jitter doesn't trip the watchdog

        local total_iters = num_poems - 1
        local batch_start_time = wall_clock()

        -- Probe: small dispatch, time it
        local probe_start = wall_clock()
        local result = vk.vkd_batch_compute_chunk(batch_ctx, 1, PROBE_ITERS)
        check_result(result, string.format(
            "Batch compute-chunk probe dispatch (slots [1, %d))", 1 + PROBE_ITERS))
        local probe_elapsed = wall_clock() - probe_start
        local iter_seconds = probe_elapsed / PROBE_ITERS
        local chunk_size = math.max(1, math.floor(
            (TARGET_CHUNK_SECONDS * SAFETY_FACTOR) / iter_seconds))

        local remaining = total_iters - PROBE_ITERS
        local num_chunks_est = math.ceil(remaining / chunk_size) + 1  -- +1 for the probe
        print(string.format(
            "  Probe: %d iters in %.3fs (%.1f iter/sec) -> chunk_size = %d (~%d more chunks)",
            PROBE_ITERS, probe_elapsed, PROBE_ITERS / probe_elapsed, chunk_size,
            num_chunks_est - 1))
        io.stdout:flush()

        -- Progress reporting: print at chunk 1, every 10th chunk, and the
        -- last one. Anything else is log spam on a multi-thousand-chunk
        -- run. We also keep a rolling EMA of iter rate to compute an ETA
        -- that adapts as conditions change.
        local PRINT_EVERY = 10
        local ema_iter_rate = nil
        local EMA_ALPHA = 0.2  -- new sample weight; 1 = no smoothing
        local total_chunks = num_chunks_est - 1

        local slot = 1 + PROBE_ITERS
        local chunk_idx = 1
        while slot <= total_iters do
            local this_chunk = math.min(chunk_size, total_iters - slot + 1)
            local chunk_start = wall_clock()

            result = vk.vkd_batch_compute_chunk(batch_ctx, slot, this_chunk)
            check_result(result, string.format(
                "Batch compute-chunk dispatch (chunk %d, slots [%d, %d))",
                chunk_idx, slot, slot + this_chunk))

            local chunk_elapsed = wall_clock() - chunk_start
            local total_done = slot + this_chunk - 1
            local sample_rate = this_chunk / chunk_elapsed

            if ema_iter_rate == nil then
                ema_iter_rate = sample_rate
            else
                ema_iter_rate = EMA_ALPHA * sample_rate + (1 - EMA_ALPHA) * ema_iter_rate
            end

            local is_last = (slot + this_chunk - 1) >= total_iters
            if chunk_idx == 1 or chunk_idx % PRINT_EVERY == 0 or is_last then
                local remaining_iters = total_iters - total_done
                local eta_seconds = remaining_iters / ema_iter_rate
                print(string.format(
                    "  [chunk %d/%d] %d iters in %.2fs (%.1f iter/sec, total %d/%d, ETA %s)",
                    chunk_idx, total_chunks, this_chunk, chunk_elapsed,
                    sample_rate, total_done, total_iters,
                    format_duration(eta_seconds)))
                io.stdout:flush()
            end

            slot = slot + this_chunk
            chunk_idx = chunk_idx + 1
        end

        local batch_compute_elapsed = wall_clock() - batch_start_time
        print(string.format("  GPU finished %d iterations in %.2fs (%.2f iter/sec average)",
                          total_iters, batch_compute_elapsed,
                          total_iters / batch_compute_elapsed))
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

        local batch_elapsed = wall_clock() - batch_start_time
        print(string.format("[Batch %d/%d] Completed in %.2fs (%.2f seq/s)",
                           batch_num, num_batches, batch_elapsed, current_batch_size / batch_elapsed))
    end

    local total_elapsed = wall_clock() - start_time
    print(string.format("\n[Diversity Batch] Completed ALL %d sequences in %.2fs (%.2f seq/s)",
                       num_poems, total_elapsed, num_poems / total_elapsed))

    -- Write to file if requested
    if output_file then
        M.write_sequences_to_file(all_sequences, output_file)
    end

    return all_sequences
end
-- }}}

-- {{{ FP16 conversion: thin wrappers around the C helpers
-- Exposed on M so the wrapper script can convert FP32 -> FP16 without
-- needing its own ffi.load. The C helpers are private to this module
-- otherwise (the FFI library object `vk` is module-local).
function M.fp32_to_fp16(src, dst, count)
    return vk.vkc_fp32_to_fp16(src, dst, count)
end

function M.fp16_to_fp32(bits)
    return vk.vkc_fp16_to_fp32(bits)
end
-- }}}

return M
