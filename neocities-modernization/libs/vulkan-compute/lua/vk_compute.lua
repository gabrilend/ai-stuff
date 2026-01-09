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
        error(string.format("%s failed: %s (code %d)", operation, err_str, result))
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
--
-- Returns: Table mapping poem_id -> sequence table
function M.compute_all_diversity_sequences(ctx, embeddings, num_poems, embedding_dim, output_file)
    print(string.format("[Diversity] Computing sequences for %d poems...", num_poems))

    local sequences = {}
    local start_time = os.clock()

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
    for start_poem = 0, num_poems - 1 do
        local result = vk.vkd_compute_sequence(div_ctx, start_poem, sequence_arr)
        check_result(result, string.format("Diversity sequence for poem %d", start_poem))

        -- Convert to Lua table
        local sequence = {}
        for i = 0, num_poems - 1 do
            sequence[i + 1] = tonumber(sequence_arr[i])
        end
        sequences[start_poem] = sequence

        -- Progress update every 100 poems
        if (start_poem + 1) % 100 == 0 then
            local elapsed = os.clock() - start_time
            local rate = (start_poem + 1) / elapsed
            local remaining = (num_poems - start_poem - 1) / rate
            print(string.format("  [%d/%d] %.1f sequences/sec, ~%.1fs remaining",
                              start_poem + 1, num_poems, rate, remaining))
        end
    end

    vk.vkd_destroy(div_ctx)

    local elapsed = os.clock() - start_time
    print(string.format("[Diversity] Completed %d sequences in %.2fs (%.1f seq/s)",
                       num_poems, elapsed, num_poems / elapsed))

    -- Write to file if requested
    if output_file then
        M.write_sequences_to_file(sequences, output_file)
    end

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

    -- Write header: num_poems (4 bytes)
    f:write(string.pack("<I4", num_poems))

    -- Write each sequence
    for poem_id = 0, num_poems - 1 do
        local sequence = sequences[poem_id]
        for i = 1, #sequence do
            f:write(string.pack("<I4", sequence[i]))
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

    -- Read header
    local num_poems = string.unpack("<I4", f:read(4))

    -- Read sequences
    local sequences = {}
    for poem_id = 0, num_poems - 1 do
        local sequence = {}
        for i = 1, num_poems do
            local idx = string.unpack("<I4", f:read(4))
            sequence[i] = idx
        end
        sequences[poem_id] = sequence
    end

    f:close()
    print(string.format("[Diversity] Loaded %d sequences from %s", num_poems, input_file))
    return sequences
end
-- }}}

return M
