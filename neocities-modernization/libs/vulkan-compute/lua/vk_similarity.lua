-- Lua FFI bindings for Vulkan similarity computation
-- Provides GPU-accelerated cosine similarity calculation for triangular individual files

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

        -- Sort similarities by score (descending) for sorted_indices field
        table.sort(similarities, function(a, b)
            return a.similarity > b.similarity
        end)

        -- Extract sorted indices for fast HTML generation
        local sorted_indices = {}
        for _, entry in ipairs(similarities) do
            table.insert(sorted_indices, tonumber(entry.id))
        end

        -- Write JSON file with sorted_indices for fast HTML generation
        local data = {
            metadata = {
                poem_id = tostring(poem_id),
                poem_index = poem_index,
                total_comparisons = num_targets,
                range = string.format("%d-%d", poem_index + 1, num_poems),
                format = "triangular_upper",
                calculated_at = os.date("%Y-%m-%d %H:%M:%S"),
                method = "gpu_vulkan"
            },
            similarities = similarities,
            sorted_indices = sorted_indices  -- Pre-sorted poem indices for fast lookup
        }
        utils.write_json_file(output_file, data)

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
    print(string.format("[GPU SIMILARITY] ✅ Complete! Generated %d files in %.1f min (%.2f poems/sec)",
        num_poems, total_time / 60, num_poems / total_time))

    -- Cleanup GPU resources
    vklib.vks_destroy(sim_ctx)
    vklib.vkc_destroy(vk_ctx)

    -- Generate sorted rankings cache (while data is still in RAM)
    print("[GPU SIMILARITY] Generating sorted similarity rankings cache...")
    local cache_start = os.time()

    local rankings = {}
    local poems_sorted = 0
    for poem_index, sim_list in pairs(full_similarities) do
        -- Sort by similarity descending
        table.sort(sim_list, function(a, b)
            return a[2] > b[2]
        end)

        -- Extract just the sorted poem indices (similarity values not needed at runtime)
        local sorted_ids = {}
        for _, entry in ipairs(sim_list) do
            table.insert(sorted_ids, entry[1])
        end

        rankings[tostring(poem_index)] = sorted_ids
        poems_sorted = poems_sorted + 1

        if poems_sorted % 1000 == 0 then
            print(string.format("[GPU SIMILARITY] Sorted rankings: %d/%d poems", poems_sorted, num_poems))
        end
    end

    -- Write cache file
    local cache_file = "assets/embeddings/" .. model_dir .. "/similarity_rankings_cache.json"
    local cache_data = {
        metadata = {
            total_poems = num_poems,
            generated_at = os.date("%Y-%m-%d %H:%M:%S"),
            algorithm = "gpu_vulkan_sorted",
            format = "pre_sorted_rankings",
            description = "Pre-sorted similarity rankings for fast HTML generation"
        },
        rankings = rankings
    }

    utils.write_json_file(cache_file, cache_data)

    local cache_time = os.time() - cache_start
    print(string.format("[GPU SIMILARITY] ✅ Rankings cache saved in %d seconds: %s", cache_time, cache_file))

    return true
end
-- }}}

return M
