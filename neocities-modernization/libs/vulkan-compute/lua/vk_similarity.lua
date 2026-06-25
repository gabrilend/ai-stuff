-- Lua FFI bindings for Vulkan similarity computation
-- Provides GPU-accelerated cosine similarity calculation for triangular individual files
-- Includes parallel CPU sorting while GPU continues processing

local ffi = require("ffi")
local utils = require("utils")
local dkjson = require("dkjson")

-- Load effil for parallel CPU sorting (required)
package.cpath = '/home/ritz/programming/ai-stuff/libs/lua/effil-jit/build/?.so;' .. package.cpath
local effil_ok, effil = pcall(require, 'effil')
if not effil_ok then
    error([[
effil library not found! Required for parallel CPU sorting.

Expected location: /home/ritz/programming/ai-stuff/libs/lua/effil-jit/build/effil.so

Build instructions:
  cd /home/ritz/programming/ai-stuff/libs/lua/effil-jit
  mkdir build && cd build
  cmake .. && make
]])
end

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

-- Default thread count for parallel sorting (can be overridden)
local DEFAULT_SORT_THREADS = 8

-- {{{ function create_sort_write_task
-- Creates an effil thread function for sorting and writing a similarity file
-- This runs on CPU while GPU continues computing the next poem
local function create_sort_write_task()
    return effil.thread(function(similarities_data, metadata, output_file, dir_path)
        -- Wrap in pcall to catch any errors
        local ok, err = pcall(function()
            -- Re-require modules in thread context
            package.path = dir_path .. '/libs/?.lua;' .. dir_path .. '/src/?.lua;' .. package.path
            local json = require('dkjson')

            -- Sort similarities by score (descending)
            table.sort(similarities_data, function(a, b)
                return a.similarity > b.similarity
            end)

            -- Extract sorted indices
            local sorted_indices = {}
            for _, entry in ipairs(similarities_data) do
                table.insert(sorted_indices, tonumber(entry.id))
            end

            -- Build output data
            local data = {
                metadata = metadata,
                similarities = similarities_data,
                sorted_indices = sorted_indices
            }

            -- Write file
            local file = io.open(output_file, "w")
            if file then
                file:write(json.encode(data, {indent = true}))
                file:close()
            else
                error("Failed to open file for writing: " .. output_file)
            end
        end)

        if not ok then
            -- Return error message so main thread can see it
            return false, tostring(err)
        end
        return true
    end)
end
-- }}}

-- {{{ function M.load_similarities_from_files
-- Load existing similarity files and reconstruct full similarity table for cache generation
-- @param similarities_dir: Path to directory containing similarity files
-- @param embeddings_data: Embeddings data with poem_index information
-- @return full_similarities: Table mapping poem_index -> {{target_index, similarity}, ...}
function M.load_similarities_from_files(similarities_dir, embeddings_data)
    print(string.format("[GPU SIMILARITY] Loading similarity files from: %s", similarities_dir))

    -- Build full similarity map: poem_index -> {{target_index, similarity}, ...}
    local full_similarities = {}
    local files_processed = 0
    local start_time = os.time()

    -- Initialize empty arrays for all poems
    for _, emb in ipairs(embeddings_data.embeddings) do
        if emb.poem_index then
            full_similarities[emb.poem_index] = {}
        end
    end

    -- Find similarity files (prefer poem_index_*.json format)
    local handle = io.popen(string.format("find '%s' -maxdepth 1 -name 'poem_index_*.json' 2>/dev/null", similarities_dir))
    local files = {}
    for line in handle:lines() do
        table.insert(files, line)
    end
    handle:close()

    -- Fall back to legacy poem_*.json if no poem_index files found
    if #files == 0 then
        handle = io.popen(string.format("find '%s' -maxdepth 1 -name 'poem_*.json' ! -name 'poem_index_*' 2>/dev/null", similarities_dir))
        for line in handle:lines() do
            table.insert(files, line)
        end
        handle:close()
        if #files > 0 then
            print(string.format("[GPU SIMILARITY] Using legacy poem_*.json files (%d found)", #files))
        end
    else
        print(string.format("[GPU SIMILARITY] Using poem_index_*.json files (%d found)", #files))
    end

    if #files == 0 then
        print("[GPU SIMILARITY ERROR] No similarity files found in: " .. similarities_dir)
        return nil
    end

    local total_files = #files

    -- Process each similarity file
    for _, filepath in ipairs(files) do
        local data = utils.read_json_file(filepath)
        if data and data.metadata and data.similarities then
            local source_index = data.metadata.poem_index

            -- Skip files without poem_index
            if source_index then
                -- Process each similarity entry
                for _, entry in ipairs(data.similarities) do
                    local target_index = tonumber(entry.id)
                    local similarity = entry.similarity

                    if target_index and similarity then
                        -- Store bidirectionally (symmetric matrix)
                        table.insert(full_similarities[source_index], {target_index, similarity})
                        if full_similarities[target_index] then
                            table.insert(full_similarities[target_index], {source_index, similarity})
                        end
                    end
                end

                files_processed = files_processed + 1

                if files_processed % 500 == 0 then
                    local elapsed = os.time() - start_time
                    local rate = files_processed / math.max(elapsed, 1)
                    print(string.format("[GPU SIMILARITY] Loading: %d/%d files (%.1f%%), %.1f files/sec",
                                      files_processed, total_files,
                                      (files_processed / total_files) * 100, rate))
                end
            end
        end
    end

    local elapsed = os.time() - start_time
    print(string.format("[GPU SIMILARITY] Loaded %d similarity files in %d seconds", files_processed, elapsed))

    return full_similarities
end
-- }}}

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
        -- Cache missing or empty, need to regenerate
        print("[GPU SIMILARITY] Cache missing or empty, regenerating from existing files...")
        local full_similarities = M.load_similarities_from_files(output_dir, embeddings_data)
        if full_similarities then
            return M.generate_rankings_cache(full_similarities, num_poems, model_dir, num_threads or 8)
        end
        error("[GPU SIMILARITY ERROR] Failed to load existing similarity files")
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

-- {{{ function M.generate_rankings_cache
-- Generate pre-sorted rankings cache from full_similarities table
function M.generate_rankings_cache(full_similarities, num_poems, model_dir, max_sort_threads)
    print(string.format("[GPU SIMILARITY] Generating sorted rankings cache (%d threads)...", max_sort_threads))
    local cache_start = os.time()

    -- Collect poem indices
    local poem_indices = {}
    for poem_index, _ in pairs(full_similarities) do
        table.insert(poem_indices, poem_index)
    end

    -- Create shared results table
    local rankings = effil.table()

    -- Create thread function for cache sorting
    local cache_sort_task = effil.thread(function(batch_indices, similarities_data, results_table)
        local count = 0
        for _, poem_index in ipairs(batch_indices) do
            local sim_list = similarities_data[poem_index]
            if sim_list then
                -- Sort by similarity descending
                table.sort(sim_list, function(a, b)
                    return a[2] > b[2]
                end)

                -- Extract sorted poem indices
                local sorted_ids = {}
                for _, entry in ipairs(sim_list) do
                    table.insert(sorted_ids, entry[1])
                end

                results_table[tostring(poem_index)] = sorted_ids
                count = count + 1
            end
        end
        return count
    end)

    -- Distribute work across threads
    local cache_threads = {}
    local batch_size = math.ceil(#poem_indices / max_sort_threads)

    for t = 1, max_sort_threads do
        local start_idx = (t - 1) * batch_size + 1
        local end_idx = math.min(t * batch_size, #poem_indices)

        if start_idx <= #poem_indices then
            local batch = {}
            for i = start_idx, end_idx do
                table.insert(batch, poem_indices[i])
            end

            local thread = cache_sort_task(batch, full_similarities, rankings)
            table.insert(cache_threads, thread)
        end
    end

    -- Wait for all cache sorting threads
    local total_sorted = 0
    for i, thread in ipairs(cache_threads) do
        local status, count = thread:wait()
        if status == "completed" and count then
            total_sorted = total_sorted + count
        end
    end
    print(string.format("[GPU SIMILARITY] Sorted %d poem rankings in parallel", total_sorted))

    -- Convert effil.table to regular Lua table
    local rankings_lua = {}
    for k, v in pairs(rankings) do
        local arr = {}
        for _, item in ipairs(v) do
            table.insert(arr, item)
        end
        rankings_lua[k] = arr
    end

    -- Write cache file
    local cache_file = utils.embeddings_dir(model_dir) .. "/similarity_rankings_cache.json"
    local cache_data = {
        metadata = {
            total_poems = num_poems,
            generated_at = os.date("%Y-%m-%d %H:%M:%S"),
            algorithm = "gpu_vulkan_parallel_single_dispatch",
            format = "pre_sorted_rankings",
            sort_threads = max_sort_threads,
            description = "Pre-sorted similarity rankings for fast HTML generation"
        },
        rankings = rankings_lua
    }

    utils.write_json_file(cache_file, cache_data)

    local cache_time = os.time() - cache_start
    print(string.format("[GPU SIMILARITY] ✅ Rankings cache saved in %d seconds: %s", cache_time, cache_file))

    return true
end
-- }}}

return M
