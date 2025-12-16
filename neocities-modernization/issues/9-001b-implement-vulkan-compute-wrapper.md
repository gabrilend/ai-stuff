# Issue 9-001b: Implement Core Vulkan Compute Wrapper

## Parent Issue
9-001: Implement Vulkan Compute Infrastructure

## Current Behavior
No Vulkan wrapper exists.

## Intended Behavior
Clean C library that handles Vulkan boilerplate and exposes simple compute dispatch API.

## Implementation Steps

### Step 1: Core Initialization
- [ ] Create VkInstance with validation layers (debug) or without (release)
- [ ] Select physical device (GTX 1080 Ti)
- [ ] Find compute queue family
- [ ] Create logical device and compute queue

### Step 2: Memory Management
- [ ] Implement buffer creation (device-local and host-visible)
- [ ] Implement staging buffer pattern for uploads/downloads
- [ ] Create memory allocation helper

### Step 3: Shader Pipeline
- [ ] Load SPIR-V from file
- [ ] Create compute pipeline
- [ ] Create descriptor set layout and pool
- [ ] Bind buffers to descriptors

### Step 4: Command Execution
- [ ] Create command pool and command buffer
- [ ] Record dispatch commands
- [ ] Submit and wait for completion
- [ ] Implement fence-based synchronization

### Step 5: API Design
```c
// Proposed API
typedef struct VkComputeContext VkComputeContext;

VkComputeContext* vkc_init(void);
void vkc_destroy(VkComputeContext* ctx);

// Buffer operations
VkBuffer vkc_create_buffer(VkComputeContext* ctx, size_t size, bool device_local);
void vkc_upload_buffer(VkComputeContext* ctx, VkBuffer buf, void* data, size_t size);
void vkc_download_buffer(VkComputeContext* ctx, VkBuffer buf, void* data, size_t size);

// Shader operations
VkPipeline vkc_load_shader(VkComputeContext* ctx, const char* spv_path);
void vkc_dispatch(VkComputeContext* ctx, VkPipeline pipeline,
                  uint32_t x, uint32_t y, uint32_t z);
```

## Quality Assurance Criteria

- [ ] Initialization succeeds with validation layers
- [ ] Buffer upload/download round-trips correctly
- [ ] Simple compute shader executes without errors
- [ ] Resource cleanup is complete (no leaks)
- [ ] Validation layers report no errors

## Dependencies

- 9-001a (Vulkan environment setup)

---

**ISSUE STATUS: OPEN**

**Created**: 2025-12-14

**Phase**: 9 (GPU Acceleration)

**Priority**: High (blocking 9-001c)
