-- Lua FFI bindings for Vulkan similarity computation
-- Provides GPU-accelerated cosine similarity calculation for triangular individual files
-- (Issue 10-057: the parallel CPU-sort path was removed; this module is GPU-only now,
-- so it no longer depends on effil.)

local ffi = require("ffi")
local utils = require("utils")
local dkjson = require("dkjson")

-- {{{ FFI definitions
ffi.cdef[[
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

// Opaque types
typedef struct VkComputeContext VkComputeContext;
typedef struct VkSimilarityContext VkSimilarityContext;

// vk_compute.h functions
VkComputeContext* vkc_init(bool enable_validation);
void vkc_destroy(VkComputeContext* ctx);
const char* vkc_get_error_string(VkComputeResult result);
const char* vkc_get_device_name(VkComputeContext* ctx);

// vk_similarity.h functions
VkSimilarityContext* vks_init(VkComputeContext* ctx,
                               const float* embeddings,
                               uint32_t num_poems,
                               uint32_t embedding_dim);

void vks_destroy(VkSimilarityContext* sim_ctx);

// Parallel full-matrix computation (Issue 9-002 original design)
VkComputeResult vks_compute_all_similarities_parallel(
    VkSimilarityContext* sim_ctx,
    float* output_triangular);

// Parallel file I/O with pthreads (avoids Lua serialization overhead)
VkComputeResult vks_write_similarity_files_parallel(
    const float* triangular_buffer,
    uint32_t num_poems,
    const uint32_t* poem_indices,
    const char** poem_ids,
    const char* output_dir,
    uint32_t num_threads);

// Parallel cache generation with pthreads. top_k caps how many nearest neighbours
// are stored per poem (0 = all); the cap shrinks the on-disk JSON and the RAM table
// the HTML stage parses it into (Issue 10-057).
VkComputeResult vks_write_rankings_cache_parallel(
    const float* triangular_buffer,
    uint32_t num_poems,
    const uint32_t* poem_indices,
    const char* cache_file,
    uint32_t num_threads,
    uint32_t top_k);
]]
-- }}}

-- Load Vulkan compute library
-- Use absolute path or search in current directory
local DIR = os.getenv("DIR") or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
local lib_path = DIR .. "/libs/vulkan-compute/build/libvkcompute.so"
local vklib = ffi.load(lib_path)

local M = {}

-- {{{ function triangular_size
-- Calculate size of triangular matrix (number of pairs)
local function triangular_size(num_poems)
    return (num_poems * (num_poems - 1)) / 2
end
-- }}}

-- {{{ function triangular_index
-- Get linear index for pair (i, j) where i < j
local function triangular_index(i, j, num_poems)
    return i * num_poems - (i * (i + 1)) / 2 + (j - i - 1)
end
-- }}}

-- {{{ function M.generate_similarity_matrix_gpu_parallel
-- Generate similarity matrix using TRUE parallel GPU computation
-- This is the correct implementation per Issue 9-002 original design.
-- Computes ALL ~30M pairs in a SINGLE GPU dispatch (seconds, not hours)
--
-- @param embeddings_file: Path to embeddings.json
-- @param model_name: Model name for output directory
-- @param force: Force regeneration even if files exist
-- @param num_threads: Number of CPU threads for parallel file writing
-- @param top_k: keep only the top-K nearest neighbours per poem in the rankings
--               cache (nil/0 = keep all). Caps disk + HTML-stage RAM (Issue 10-057).
-- @return success: boolean
function M.generate_similarity_matrix_gpu_parallel(embeddings_file, model_name, force, num_threads, top_k)
    print("[GPU SIMILARITY] Embeddings file: " .. embeddings_file)
    print(string.format("[GPU SIMILARITY] Force regeneration: %s", tostring(force)))

    -- Load embeddings
    local embeddings_data = utils.read_json_file(embeddings_file)
    if not embeddings_data or not embeddings_data.embeddings then
        error("[GPU SIMILARITY ERROR] Failed to load embeddings")
    end

    local num_poems = #embeddings_data.embeddings
    -- Validate embeddings array is non-empty before accessing first element
    -- Empty arrays occur when embedding generation failed (network errors, etc.)
    if num_poems == 0 then
        local reason = embeddings_data.metadata and embeddings_data.metadata.termination_reason or "unknown"
        local mode = embeddings_data.metadata and embeddings_data.metadata.processing_mode or "unknown"
        error(string.format(
            "[GPU SIMILARITY ERROR] Embeddings array is empty (0 poems).\n" ..
            "  Processing mode: %s\n" ..
            "  Termination reason: %s\n" ..
            "  Remedy: Regenerate embeddings with: ./run.sh --generate-embeddings --force\n" ..
            "  Ensure the inference server is running: ./scripts/start-llamacpp-server.sh",
            mode, reason
        ))
    end
    local embedding_dim = #embeddings_data.embeddings[1].embedding
    print(string.format("[GPU SIMILARITY] Loaded %d poems × %d dimensions", num_poems, embedding_dim))

    -- Prepare output directory.
    -- Issue 10-054: similarities are a movable cache -> embeddings_dir() (RAM).
    -- This was the last writer still hardcoding a (relative!) disk path: it wrote
    -- to assets/ and freshness-checked assets/, so with caches in RAM it skipped
    -- to the stale disk copy and never populated RAM -- the broken-site bug.
    local model_dir = model_name:gsub(":", "_")
    local output_dir = utils.embeddings_dir(model_name) .. "/similarities"
    os.execute("mkdir -p " .. output_dir)

    -- Check if we can skip (files already exist and not forcing)
    local first_file = string.format("%s/poem_index_1.json", output_dir)
    local last_file = string.format("%s/poem_index_%d.json", output_dir, num_poems)
    if not force and utils.file_exists(first_file) and utils.file_exists(last_file) then
        print("[GPU SIMILARITY] Similarity files already exist, checking cache...")
        local cache_file = utils.embeddings_dir(model_dir) .. "/similarity_rankings_cache.json"
        if utils.file_exists(cache_file) then
            local cache_data = utils.read_json_file(cache_file)
            if cache_data and cache_data.rankings then
                local cache_count = 0
                for _ in pairs(cache_data.rankings) do cache_count = cache_count + 1 end
                if cache_count > 0 then
                    print(string.format("[GPU SIMILARITY] ⏭️  All files and cache exist (%d poems), skipping", cache_count))
                    return true
                end
            end
        end
        -- Cache missing or empty: fall through to the GPU regeneration below. The old
        -- Lua effil rebuild was removed (Issue 10-057) -- it sorted on the CPU AND
        -- bypassed the top-K cap, so it would silently rewrite a full-size cache. The
        -- GPU path rebuilds the cache capped, which is the only route we keep.
        print("[GPU SIMILARITY] Cache missing or empty, regenerating on the GPU...")
    end

    -- Convert embeddings to flat C array
    print("[GPU SIMILARITY] Preparing embeddings for GPU...")
    local flat_embeddings = ffi.new("float[?]", num_poems * embedding_dim)
    for i, poem in ipairs(embeddings_data.embeddings) do
        local base = (i - 1) * embedding_dim
        for j, val in ipairs(poem.embedding) do
            flat_embeddings[base + j - 1] = val
        end
    end

    -- Initialize Vulkan context
    print("[GPU SIMILARITY] Initializing Vulkan context...")
    -- vkc_init prints the chosen GPU once ("[VKC] Selected device: ..."), so
    -- we no longer echo a second "GPU device" line from here.
    local vk_ctx = vklib.vkc_init(false)  -- Disable validation for performance
    if vk_ctx == nil then
        error("[GPU SIMILARITY ERROR] Failed to initialize Vulkan context")
    end

    -- Initialize similarity context
    local sim_ctx = vklib.vks_init(vk_ctx, flat_embeddings, num_poems, embedding_dim)
    if sim_ctx == nil then
        vklib.vkc_destroy(vk_ctx)
        error("[GPU SIMILARITY ERROR] Failed to initialize similarity context")
    end

    -- Allocate output buffer for triangular matrix
    local tri_size = triangular_size(num_poems)
    print(string.format("[GPU SIMILARITY] Allocating triangular buffer: %d pairs (%.1f MB)",
                       tri_size, tri_size * 4 / 1024 / 1024))
    local triangular_output = ffi.new("float[?]", tri_size)

    -- SINGLE DISPATCH - compute ALL similarities at once!
    local start_time = os.time()

    local result = vklib.vks_compute_all_similarities_parallel(sim_ctx, triangular_output)
    if result ~= 0 then
        local error_str = ffi.string(vklib.vkc_get_error_string(result))
        vklib.vks_destroy(sim_ctx)
        vklib.vkc_destroy(vk_ctx)
        error("[GPU SIMILARITY ERROR] Parallel computation failed: " .. error_str)
    end

    local gpu_time = os.time() - start_time
    print(string.format("[GPU SIMILARITY] ✅ GPU computation complete in %d seconds!", gpu_time))

    -- Cleanup GPU resources (we have all data in RAM now)
    vklib.vks_destroy(sim_ctx)
    vklib.vkc_destroy(vk_ctx)

    -- Prepare C arrays for parallel file writing
    -- The C function handles all file I/O with pthreads (no Lua serialization
    -- overhead) and prints its own "[VKS FILE] Wrote N files ..." timing line.
    local max_sort_threads = num_threads or 8

    print("[GPU SIMILARITY] Preparing C arrays for parallel file writing...")

    -- Build poem_index array (0-based array index -> poem_index)
    local poem_indices_c = ffi.new("uint32_t[?]", num_poems)
    for idx = 1, num_poems do
        local emb = embeddings_data.embeddings[idx]
        if not emb.poem_index then
            error(string.format("[GPU SIMILARITY ERROR] Embedding at index %d missing poem_index", idx))
        end
        poem_indices_c[idx - 1] = emb.poem_index
    end

    -- Build poem_ids array (strings for metadata)
    -- Note: We need to keep the Lua strings alive during the C call
    local poem_ids_lua = {}
    local poem_ids_c = ffi.new("const char*[?]", num_poems)
    for idx = 1, num_poems do
        local emb = embeddings_data.embeddings[idx]
        poem_ids_lua[idx] = tostring(emb.id)
        poem_ids_c[idx - 1] = poem_ids_lua[idx]
    end

    -- Call C function to write files in parallel using pthreads
    -- This keeps all data in C memory - no Lua serialization needed
    print(string.format("[GPU SIMILARITY] Writing %d files with %d pthreads (C parallel I/O)...", num_poems, max_sort_threads))

    local result = vklib.vks_write_similarity_files_parallel(
        triangular_output,
        num_poems,
        poem_indices_c,
        poem_ids_c,
        output_dir,
        max_sort_threads
    )

    if result ~= 0 then
        local error_str = ffi.string(vklib.vkc_get_error_string(result))
        error("[GPU SIMILARITY ERROR] Parallel file writing failed: " .. error_str)
    end

    -- Generate rankings cache using C parallel implementation
    -- This avoids the O(n²) Lua extraction and effil serialization overhead.
    -- The C side prints its own "[VKS CACHE] Generating rankings cache ..." line.
    local cache_file = utils.embeddings_dir(model_dir) .. "/similarity_rankings_cache.json"

    local cache_result = vklib.vks_write_rankings_cache_parallel(
        triangular_output,
        num_poems,
        poem_indices_c,
        cache_file,
        max_sort_threads,
        top_k or 0   -- 0 = keep all (backward compatible)
    )

    if cache_result ~= 0 then
        local error_str = ffi.string(vklib.vkc_get_error_string(cache_result))
        error("[GPU SIMILARITY ERROR] Cache generation failed: " .. error_str)
    end

    print("[GPU SIMILARITY] ✅ All similarity generation complete!")
    return true
end
-- }}}

return M
