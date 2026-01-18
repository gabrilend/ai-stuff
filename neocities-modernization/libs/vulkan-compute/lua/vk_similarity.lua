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

VkComputeResult vks_compute_similarities_for_poem(
    VkSimilarityContext* sim_ctx,
    uint32_t source_poem_index,
    float* output_similarities);
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
            return true
        end
        return false
    end)
end
-- }}}

-- {{{ function M.generate_similarity_matrix_gpu
-- Generate similarity matrix using GPU, outputting triangular individual files
-- @param embeddings_file: Path to embeddings.json
-- @param model_name: Model name for output directory
-- @param force: Force regeneration even if files exist
-- @return success: boolean
function M.generate_similarity_matrix_gpu(embeddings_file, model_name, force)
    print("[GPU SIMILARITY] Starting GPU-accelerated similarity generation")
    print("[GPU SIMILARITY] Embeddings file: " .. embeddings_file)

    -- Load embeddings
    local embeddings_data = utils.read_json_file(embeddings_file)
    if not embeddings_data or not embeddings_data.embeddings then
        print("[GPU SIMILARITY ERROR] Failed to load embeddings")
        return false
    end

    local num_poems = #embeddings_data.embeddings
    local embedding_dim = #embeddings_data.embeddings[1].embedding
    print(string.format("[GPU SIMILARITY] Loaded %d poems × %d dimensions", num_poems, embedding_dim))

    -- Convert embeddings to flat C array
    local flat_embeddings = ffi.new("float[?]", num_poems * embedding_dim)
    for i, poem in ipairs(embeddings_data.embeddings) do
        local base = (i - 1) * embedding_dim
        for j, val in ipairs(poem.embedding) do
            flat_embeddings[base + j - 1] = val
        end
    end

    -- Initialize Vulkan context
    print("[GPU SIMILARITY] Initializing Vulkan context...")
    local vk_ctx = vklib.vkc_init(false)  -- Disable validation for performance
    if vk_ctx == nil then
        print("[GPU SIMILARITY ERROR] Failed to initialize Vulkan context")
        return false
    end

    local device_name = ffi.string(vklib.vkc_get_device_name(vk_ctx))
    print("[GPU SIMILARITY] GPU device: " .. device_name)

    -- Initialize similarity context
    print("[GPU SIMILARITY] Initializing similarity computation...")
    local sim_ctx = vklib.vks_init(vk_ctx, flat_embeddings, num_poems, embedding_dim)
    if sim_ctx == nil then
        print("[GPU SIMILARITY ERROR] Failed to initialize similarity context")
        vklib.vkc_destroy(vk_ctx)
        return false
    end

    -- Prepare output directory
    local model_dir = model_name:gsub(":", "_")
    local output_dir = "assets/embeddings/" .. model_dir .. "/similarities"
    os.execute("mkdir -p " .. output_dir)

    -- Accumulate bidirectional similarity data in RAM for cache generation
    -- Structure: full_similarities[poem_index] = {{target_index, similarity}, ...}
    local full_similarities = {}
    for idx = 1, num_poems do
        local emb = embeddings_data.embeddings[idx]
        if emb.poem_index then
            full_similarities[emb.poem_index] = {}
        end
    end

    -- Thread pool for parallel CPU sorting (while GPU continues)
    local sort_threads = {}
    local max_sort_threads = DEFAULT_SORT_THREADS
    local sort_task_func = create_sort_write_task()

    print(string.format("[GPU SIMILARITY] Parallel sorting enabled (%d CPU threads)", max_sort_threads))

    -- Helper to wait for threads if pool is full
    local function manage_thread_pool()
        while #sort_threads >= max_sort_threads do
            local oldest = table.remove(sort_threads, 1)
            oldest:wait()
        end
    end

    -- Generate similarities for each poem
    local start_time = os.time()
    for i = 0, num_poems - 1 do
        local embedding = embeddings_data.embeddings[i + 1]

        -- Require poem_index field (no fallback)
        if not embedding.poem_index then
            error(string.format(
                "[GPU SIMILARITY ERROR] Embedding at index %d missing poem_index field.\n" ..
                "This means embeddings.json was generated before issue 8-019.\n" ..
                "Remedy: Regenerate embeddings with: ./run.sh --generate-embeddings --force",
                i + 1
            ))
        end

        local poem_index = embedding.poem_index
        local poem_id = embedding.id  -- Keep for display purposes
        local output_file = string.format("%s/poem_index_%d.json", output_dir, poem_index)

        -- Skip if file exists and not forcing
        if not force and utils.file_exists(output_file) then
            goto continue
        end

        local num_targets = num_poems - i - 1
        if num_targets == 0 then
            -- Last poem has no targets, create empty file
            local data = {
                metadata = {
                    poem_id = tostring(poem_id),
                    poem_index = poem_index,
                    total_comparisons = 0,
                    range = string.format("%d-%d", poem_index + 1, poem_index),
                    format = "triangular_upper",
                    calculated_at = os.date("%Y-%m-%d %H:%M:%S"),
                    method = "gpu_vulkan"
                },
                similarities = {}
            }
            utils.write_json_file(output_file, data)
            goto continue
        end

        -- Allocate output buffer
        local output_similarities = ffi.new("float[?]", num_targets)

        -- Compute similarities
        local result = vklib.vks_compute_similarities_for_poem(sim_ctx, i, output_similarities)
        if result ~= 0 then
            local error_str = ffi.string(vklib.vkc_get_error_string(result))
            print(string.format("[GPU SIMILARITY ERROR] Poem_index %d (id %d) failed: %s", poem_index, poem_id, error_str))
            goto continue
        end

        -- Build similarities array
        local similarities = {}
        for j = 0, num_targets - 1 do
            local target_embedding = embeddings_data.embeddings[i + j + 2]

            -- Require poem_index field (no fallback)
            if not target_embedding.poem_index then
                error(string.format(
                    "[GPU SIMILARITY ERROR] Target embedding at index %d missing poem_index field.\n" ..
                    "Remedy: Regenerate embeddings with: ./run.sh --generate-embeddings --force",
                    i + j + 2
                ))
            end

            local target_index = target_embedding.poem_index
            local sim_value = output_similarities[j]

            table.insert(similarities, {
                id = tostring(target_index),  -- Use poem_index for unique identification
                similarity = sim_value
            })

            -- Accumulate bidirectionally for full rankings cache
            table.insert(full_similarities[poem_index], {target_index, sim_value})
            table.insert(full_similarities[target_index], {poem_index, sim_value})
        end

        -- Build metadata for file
        local metadata = {
            poem_id = tostring(poem_id),
            poem_index = poem_index,
            total_comparisons = num_targets,
            range = string.format("%d-%d", poem_index + 1, num_poems),
            format = "triangular_upper",
            calculated_at = os.date("%Y-%m-%d %H:%M:%S"),
            method = "gpu_vulkan"
        }

        -- Dispatch sorting/writing to CPU thread (GPU continues immediately)
        manage_thread_pool()  -- Ensure pool isn't full
        local thread = sort_task_func(similarities, metadata, output_file, DIR)
        table.insert(sort_threads, thread)

        -- Progress indicator
        if (i + 1) % 100 == 0 then
            local elapsed = os.time() - start_time
            local rate = (i + 1) / elapsed
            local remaining = (num_poems - i - 1) / rate
            print(string.format("[GPU SIMILARITY] Progress: %d/%d (%.1f%%), ETA: %.1f min",
                i + 1, num_poems, ((i + 1) / num_poems) * 100, remaining / 60))
        end

        ::continue::
    end

    local total_time = os.time() - start_time
    print(string.format("[GPU SIMILARITY] ✅ GPU Complete! %d poems in %.1f min (%.2f poems/sec)",
        num_poems, total_time / 60, num_poems / total_time))

    -- Cleanup GPU resources (done with GPU, CPU threads may still be sorting)
    vklib.vks_destroy(sim_ctx)
    vklib.vkc_destroy(vk_ctx)

    -- Wait for remaining sorting threads to complete
    if #sort_threads > 0 then
        print(string.format("[GPU SIMILARITY] Waiting for %d sorting threads to complete...", #sort_threads))
        for _, thread in ipairs(sort_threads) do
            thread:wait()
        end
        print("[GPU SIMILARITY] ✅ All sorting threads complete")
    end

    -- Generate sorted rankings cache (parallel CPU sorting)
    print(string.format("[GPU SIMILARITY] Generating sorted rankings cache (%d threads)...", max_sort_threads))
    local cache_start = os.time()

    -- Collect poem indices into batches for parallel processing
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
    for _, thread in ipairs(cache_threads) do
        local count = thread:get()
        total_sorted = total_sorted + count
    end
    print(string.format("[GPU SIMILARITY] Sorted %d poem rankings in parallel", total_sorted))

    -- Convert effil.table to regular Lua table for JSON serialization
    local rankings_lua = {}
    for k, v in pairs(rankings) do
        -- Convert effil array to Lua array
        local arr = {}
        for _, item in ipairs(v) do
            table.insert(arr, item)
        end
        rankings_lua[k] = arr
    end

    -- Write cache file
    local cache_file = "assets/embeddings/" .. model_dir .. "/similarity_rankings_cache.json"
    local cache_data = {
        metadata = {
            total_poems = num_poems,
            generated_at = os.date("%Y-%m-%d %H:%M:%S"),
            algorithm = "gpu_vulkan_parallel_sorted",
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
