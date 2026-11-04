-- vk_cross.lua: the cosine of every vector in one set against every vector in
-- another, on the GPU in one dispatch (Issue 10-035: every word-cloud word
-- against every poem). Built from the library's general pieces -- a buffer,
-- an upload, a shader, a dispatch, a download -- and the shader
-- similarity_cross.comp; no C of its own.
--
-- Scores come back in single precision. The word pages use them to choose
-- each word's best few hundred poems, then score those exactly on the CPU,
-- so a page never depends on the GPU's rounding.

local ffi = require("ffi")

local M = {}

-- {{{ declarations
-- Each declared on its own and only if missing: vk_compute.lua and
-- vk_similarity.lua declare some of the same names, and LuaJIT refuses a
-- second declaration of a name in the same process.
local declarations = {
    "typedef struct VkComputeContext VkComputeContext;",
    "typedef struct VkComputeBuffer VkComputeBuffer;",
    "typedef struct VkComputePipeline VkComputePipeline;",
    "VkComputeContext* vkc_init(bool enable_validation);",
    "void vkc_destroy(VkComputeContext* ctx);",
    "const char* vkc_get_error_string(int result);",
    "VkComputeBuffer* vkc_create_buffer(VkComputeContext* ctx, size_t size, int type);",
    "void vkc_destroy_buffer(VkComputeContext* ctx, VkComputeBuffer* buffer);",
    "int vkc_upload_buffer(VkComputeContext* ctx, VkComputeBuffer* buffer, const void* data, size_t size);",
    "int vkc_download_buffer(VkComputeContext* ctx, VkComputeBuffer* buffer, void* data, size_t size);",
    "VkComputePipeline* vkc_create_pipeline(VkComputeContext* ctx, const char* shader_path, uint32_t push_constant_size);",
    "void vkc_destroy_pipeline(VkComputeContext* ctx, VkComputePipeline* pipeline);",
    "int vkc_bind_buffer(VkComputeContext* ctx, VkComputePipeline* pipeline, uint32_t binding, VkComputeBuffer* buffer);",
    "int vkc_dispatch(VkComputeContext* ctx, VkComputePipeline* pipeline, uint32_t x, uint32_t y, uint32_t z, const void* push_constants);",
}
for _, d in ipairs(declarations) do
    -- a name already declared (by another module in this process) is fine;
    -- the declarations above match the library's header
    pcall(ffi.cdef, d)
end
-- }}}

local DEVICE_LOCAL = 0   -- VKC_BUFFER_DEVICE_LOCAL in vk_compute.h
local SUCCESS = 0        -- VKC_SUCCESS

-- {{{ local function library()
-- The compiled library and shader live under DIR/libs/vulkan-compute/build
-- (made by its Makefile).
local function library(dir)
    return ffi.load(dir .. "/libs/vulkan-compute/build/libvkcompute.so")
end
-- }}}

-- {{{ local function pack()
-- A list of Lua vectors (arrays of numbers, all of length dim) as one flat
-- float array, row after row.
local function pack(vectors, dim)
    local flat = ffi.new("float[?]", #vectors * dim)
    for i, v in ipairs(vectors) do
        if #v ~= dim then
            error(string.format("vk_cross: vector %d has %d parts, expected %d", i, #v, dim))
        end
        local base = (i - 1) * dim
        for j = 1, dim do flat[base + j - 1] = v[j] end
    end
    return flat
end
-- }}}

-- {{{ function M.cosine_table
-- dir     : the project folder (finds the library and the shader)
-- a, b    : lists of vectors (Lua arrays of numbers, one length throughout)
-- returns : a function score(i, j) giving the cosine of a[i] and b[j]
--           (1-based), read from the downloaded table; the table stays
--           alive as long as the function does.
-- Errors on any GPU failure: the build has no slower path to fall back on.
function M.cosine_table(dir, a, b)
    if #a == 0 or #b == 0 then
        error("vk_cross: both sets need at least one vector")
    end
    local dim = #a[1]
    local vk = library(dir)
    local ctx = vk.vkc_init(false)
    if ctx == nil then error("vk_cross: no Vulkan device (the GPU is needed for this step)") end

    local resources = {}
    -- {{{ local function check()
    local function check(result, what)
        if result ~= SUCCESS then
            error("vk_cross: " .. what .. " failed: " .. ffi.string(vk.vkc_get_error_string(result)))
        end
    end
    -- }}}
    -- {{{ local function cleanup()
    local function cleanup()
        if resources.pipeline then vk.vkc_destroy_pipeline(ctx, resources.pipeline) end
        for _, name in ipairs({ "a", "b", "out" }) do
            if resources[name] then vk.vkc_destroy_buffer(ctx, resources[name]) end
        end
        vk.vkc_destroy(ctx)
    end
    -- }}}

    local ok, result = pcall(function()
        local num_a, num_b = #a, #b
        local a_flat, b_flat = pack(a, dim), pack(b, dim)
        local a_size = num_a * dim * ffi.sizeof("float")
        local b_size = num_b * dim * ffi.sizeof("float")
        local out_size = num_a * num_b * ffi.sizeof("float")
        resources.a = vk.vkc_create_buffer(ctx, a_size, DEVICE_LOCAL)
        resources.b = vk.vkc_create_buffer(ctx, b_size, DEVICE_LOCAL)
        resources.out = vk.vkc_create_buffer(ctx, out_size, DEVICE_LOCAL)
        if resources.a == nil or resources.b == nil or resources.out == nil then
            error("vk_cross: could not make the GPU buffers")
        end
        check(vk.vkc_upload_buffer(ctx, resources.a, a_flat, a_size), "upload of set A")
        check(vk.vkc_upload_buffer(ctx, resources.b, b_flat, b_size), "upload of set B")
        resources.pipeline = vk.vkc_create_pipeline(ctx,
            dir .. "/libs/vulkan-compute/build/similarity_cross.spv", 3 * ffi.sizeof("uint32_t"))
        if resources.pipeline == nil then
            error("vk_cross: could not load similarity_cross.spv (make -C libs/vulkan-compute shaders)")
        end
        check(vk.vkc_bind_buffer(ctx, resources.pipeline, 0, resources.a), "binding set A")
        check(vk.vkc_bind_buffer(ctx, resources.pipeline, 1, resources.b), "binding set B")
        check(vk.vkc_bind_buffer(ctx, resources.pipeline, 2, resources.out), "binding the scores")
        local push = ffi.new("uint32_t[3]", num_a, num_b, dim)
        -- 16 x 16 workgroups: x over set B, y over set A (see the shader)
        check(vk.vkc_dispatch(ctx, resources.pipeline,
            math.ceil(num_b / 16), math.ceil(num_a / 16), 1, push), "the dispatch")
        local scores = ffi.new("float[?]", num_a * num_b)
        check(vk.vkc_download_buffer(ctx, resources.out, scores, out_size), "download of the scores")
        return scores
    end)
    cleanup()
    if not ok then error(result, 0) end

    local scores, num_b = result, #b
    return function(i, j)
        return scores[(i - 1) * num_b + (j - 1)]
    end
end
-- }}}

return M
