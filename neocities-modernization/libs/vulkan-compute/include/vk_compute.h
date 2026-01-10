/* vk_compute.h - Vulkan Compute Wrapper for Poetry Embedding Operations
 *
 * This library provides a simplified interface to Vulkan compute shaders
 * for accelerating vector operations on poem embeddings.
 *
 * Design Goals:
 * - Minimal boilerplate for compute-only operations
 * - LuaJIT FFI-friendly C interface
 * - Automatic resource management
 * - Validation layer support for debugging
 */

#ifndef VK_COMPUTE_H
#define VK_COMPUTE_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque handle types */
typedef struct VkComputeContext VkComputeContext;
typedef struct VkComputeBuffer VkComputeBuffer;
typedef struct VkComputePipeline VkComputePipeline;

/* Error codes */
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

/* Buffer types */
typedef enum {
    VKC_BUFFER_DEVICE_LOCAL,    /* GPU-only memory (fastest) */
    VKC_BUFFER_HOST_VISIBLE,    /* CPU-GPU shared memory */
    VKC_BUFFER_STAGING,         /* Temporary transfer buffer */
} VkComputeBufferType;

/* Initialization and cleanup */
VkComputeContext* vkc_init(bool enable_validation);
void vkc_destroy(VkComputeContext* ctx);
const char* vkc_get_error_string(VkComputeResult result);

/* Device information */
const char* vkc_get_device_name(VkComputeContext* ctx);
uint32_t vkc_get_max_workgroup_size(VkComputeContext* ctx);
uint64_t vkc_get_device_memory(VkComputeContext* ctx);

/* Buffer management */
VkComputeBuffer* vkc_create_buffer(VkComputeContext* ctx,
                                   size_t size,
                                   VkComputeBufferType type);
void vkc_destroy_buffer(VkComputeContext* ctx, VkComputeBuffer* buffer);

/* Data transfer */
VkComputeResult vkc_upload_buffer(VkComputeContext* ctx,
                                  VkComputeBuffer* buffer,
                                  const void* data,
                                  size_t size);
VkComputeResult vkc_download_buffer(VkComputeContext* ctx,
                                    VkComputeBuffer* buffer,
                                    void* data,
                                    size_t size);

/* Shader and pipeline management */
VkComputePipeline* vkc_create_pipeline(VkComputeContext* ctx,
                                       const char* shader_path,
                                       uint32_t push_constant_size);
void vkc_destroy_pipeline(VkComputeContext* ctx, VkComputePipeline* pipeline);

/* Descriptor binding */
VkComputeResult vkc_bind_buffer(VkComputeContext* ctx,
                                VkComputePipeline* pipeline,
                                uint32_t binding,
                                VkComputeBuffer* buffer);

/* Command execution */
VkComputeResult vkc_dispatch(VkComputeContext* ctx,
                             VkComputePipeline* pipeline,
                             uint32_t group_count_x,
                             uint32_t group_count_y,
                             uint32_t group_count_z,
                             const void* push_constants);

/* Synchronization */
VkComputeResult vkc_wait_idle(VkComputeContext* ctx);

#ifdef __cplusplus
}
#endif

#endif /* VK_COMPUTE_H */
