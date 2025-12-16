# Issue 9-001e: Create Lua/C Integration Layer

## Parent Issue
9-001: Implement Vulkan Compute Infrastructure

## Current Behavior
No integration between Lua scripts and Vulkan compute.

## Intended Behavior
Lua scripts can invoke GPU compute operations seamlessly, either via LuaJIT FFI or subprocess communication.

## Implementation Options

### Option A: LuaJIT FFI (Recommended)
Direct function calls from Lua to C library.

```lua
local ffi = require("ffi")
ffi.cdef[[
    typedef struct VkComputeContext VkComputeContext;

    VkComputeContext* vkc_init(void);
    void vkc_destroy(VkComputeContext* ctx);

    void vkc_upload_embeddings(VkComputeContext* ctx,
                                float* embeddings,
                                uint32_t num_embeddings,
                                uint32_t embedding_dim);

    void vkc_compute_diversity_sequence(VkComputeContext* ctx,
                                         uint32_t start_poem,
                                         uint32_t* output_sequence);

    void vkc_compute_similarity_matrix(VkComputeContext* ctx,
                                        float* output_matrix);
]]

local vkc = ffi.load("vulkan_compute")
```

**Pros**: Low overhead, direct memory sharing
**Cons**: LuaJIT-only, requires careful memory management

### Option B: Subprocess with JSON
Lua spawns C binary, communicates via stdin/stdout.

```lua
local handle = io.popen("./vulkan-compute diversity-sequence --start 123", "r")
local result = handle:read("*a")
handle:close()
local sequence = dkjson.decode(result)
```

**Pros**: Works with any Lua, isolated process
**Cons**: Serialization overhead, process spawn cost

## Implementation Steps

### Step 1: Define Interface
- [ ] List all operations needed from Lua
- [ ] Design clean API that hides Vulkan complexity
- [ ] Define data formats (arrays, matrices)

### Step 2: Implement FFI Wrapper (Option A)
- [ ] Create `libs/vulkan-compute/lua/vk_compute.lua`
- [ ] Load shared library via ffi.load
- [ ] Wrap C functions with Lua-friendly API
- [ ] Handle array conversions (Lua table ↔ C array)

### Step 3: Create Lua Module
```lua
-- libs/vulkan-compute/lua/vk_compute.lua
local M = {}

function M.init()
    -- Initialize Vulkan context
end

function M.upload_embeddings(embeddings_table)
    -- Convert Lua table to C array, upload
end

function M.compute_diversity_sequence(start_poem_id)
    -- Dispatch GPU computation, return sequence as Lua table
end

function M.compute_similarity_matrix()
    -- Compute full similarity matrix, return as nested Lua tables
end

function M.shutdown()
    -- Cleanup Vulkan resources
end

return M
```

### Step 4: Integration Test
- [ ] Load module from existing Lua scripts
- [ ] Verify embeddings upload correctly
- [ ] Compare GPU results to CPU reference
- [ ] Profile overhead of Lua ↔ C boundary

## Quality Assurance Criteria

- [ ] Module loads without errors
- [ ] Embeddings transfer correctly
- [ ] Results match CPU implementation
- [ ] No memory leaks across multiple operations
- [ ] Works with existing script structure

## Dependencies

- 9-001d (Diversity sequence GPU algorithm)

---

**ISSUE STATUS: OPEN**

**Created**: 2025-12-14

**Phase**: 9 (GPU Acceleration)

**Priority**: Medium
