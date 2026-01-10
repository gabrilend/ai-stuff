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
local lib_path = "libs/vulkan-compute/build/libvkcompute.so"
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

    -- Generate similarities for each poem
    local start_time = os.time()
    for i = 0, num_poems - 1 do
        local poem_id = embeddings_data.embeddings[i + 1].id
        local output_file = string.format("%s/poem_%d.json", output_dir, poem_id)

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
                    poem_index = i,
                    total_comparisons = 0,
                    range = string.format("%d-%d", poem_id + 1, poem_id),
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
            print(string.format("[GPU SIMILARITY ERROR] Poem %d failed: %s", poem_id, error_str))
            goto continue
        end

        -- Build similarities array
        local similarities = {}
        for j = 0, num_targets - 1 do
            local target_id = embeddings_data.embeddings[i + j + 2].id
            table.insert(similarities, {
                id = tostring(target_id),
                similarity = output_similarities[j]
            })
        end

        -- Write JSON file
        local data = {
            metadata = {
                poem_id = tostring(poem_id),
                poem_index = i,
                total_comparisons = num_targets,
                range = string.format("%d-%d", poem_id + 1, 7797),
                format = "triangular_upper",
                calculated_at = os.date("%Y-%m-%d %H:%M:%S"),
                method = "gpu_vulkan"
            },
            similarities = similarities
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

    -- Cleanup
    vklib.vks_destroy(sim_ctx)
    vklib.vkc_destroy(vk_ctx)

    return true
end
-- }}}

return M
