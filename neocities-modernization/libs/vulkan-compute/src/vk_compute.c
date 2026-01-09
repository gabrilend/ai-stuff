/* vk_compute.c - Vulkan Compute Wrapper Implementation
 *
 * This file implements a simplified Vulkan compute interface for
 * accelerating vector operations on poem embeddings (768-dimensional).
 *
 * Architecture:
 * - Single compute queue for all operations
 * - Explicit synchronization with fences
 * - Descriptor sets per pipeline
 * - Push constants for per-dispatch parameters
 */

#include "vk_compute.h"
#include <vulkan/vulkan.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_BUFFERS 32
#define MAX_DESCRIPTOR_SETS 16

/* {{{ Internal structures
 */

typedef struct {
    VkBuffer buffer;
    VkDeviceMemory memory;
    VkDeviceSize size;
    VkComputeBufferType type;
} BufferInternal;

typedef struct {
    VkShaderModule shader;
    VkPipelineLayout layout;
    VkPipeline pipeline;
    VkDescriptorSetLayout desc_set_layout;
    VkDescriptorPool desc_pool;
    VkDescriptorSet desc_set;
    uint32_t push_constant_size;
    uint32_t num_bindings;
} PipelineInternal;

struct VkComputeContext {
    /* Vulkan core objects */
    VkInstance instance;
    VkPhysicalDevice physical_device;
    VkDevice device;
    VkQueue compute_queue;
    uint32_t compute_queue_family;

    /* Command execution */
    VkCommandPool command_pool;
    VkCommandBuffer command_buffer;
    VkFence fence;

    /* Device properties */
    VkPhysicalDeviceProperties device_properties;
    VkPhysicalDeviceMemoryProperties memory_properties;

    /* Validation */
    bool validation_enabled;
    VkDebugUtilsMessengerEXT debug_messenger;
};

struct VkComputeBuffer {
    BufferInternal internal;
};

struct VkComputePipeline {
    PipelineInternal internal;
};

/* }}} */

/* {{{ Error handling
 */

const char* vkc_get_error_string(VkComputeResult result) {
    switch (result) {
        case VKC_SUCCESS: return "Success";
        case VKC_ERROR_INIT_FAILED: return "Initialization failed";
        case VKC_ERROR_NO_SUITABLE_DEVICE: return "No suitable Vulkan device found";
        case VKC_ERROR_BUFFER_CREATION_FAILED: return "Buffer creation failed";
        case VKC_ERROR_SHADER_LOAD_FAILED: return "Shader loading failed";
        case VKC_ERROR_PIPELINE_CREATION_FAILED: return "Pipeline creation failed";
        case VKC_ERROR_COMMAND_EXECUTION_FAILED: return "Command execution failed";
        case VKC_ERROR_OUT_OF_MEMORY: return "Out of memory";
        default: return "Unknown error";
    }
}

static void check_vk_result(VkResult result, const char* operation) {
    if (result != VK_SUCCESS) {
        fprintf(stderr, "[VKC ERROR] %s failed with code %d\n", operation, result);
    }
}

/* }}} */

/* {{{ Debug messenger callback
 */

static VKAPI_ATTR VkBool32 VKAPI_CALL debug_callback(
    VkDebugUtilsMessageSeverityFlagBitsEXT severity,
    VkDebugUtilsMessageTypeFlagsEXT type,
    const VkDebugUtilsMessengerCallbackDataEXT* callback_data,
    void* user_data)
{
    (void)type;
    (void)user_data;

    if (severity >= VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT) {
        fprintf(stderr, "[VK VALIDATION] %s\n", callback_data->pMessage);
    }

    return VK_FALSE;
}

/* }}} */

/* {{{ Helper: Find memory type
 */

static uint32_t find_memory_type(VkComputeContext* ctx,
                                 uint32_t type_filter,
                                 VkMemoryPropertyFlags properties)
{
    for (uint32_t i = 0; i < ctx->memory_properties.memoryTypeCount; i++) {
        if ((type_filter & (1 << i)) &&
            (ctx->memory_properties.memoryTypes[i].propertyFlags & properties) == properties) {
            return i;
        }
    }

    fprintf(stderr, "[VKC ERROR] Failed to find suitable memory type\n");
    return UINT32_MAX;
}

/* }}} */

/* {{{ Initialization: vkc_init
 */

VkComputeContext* vkc_init(bool enable_validation) {
    VkComputeContext* ctx = calloc(1, sizeof(VkComputeContext));
    if (!ctx) {
        return NULL;
    }

    ctx->validation_enabled = enable_validation;

    /* Create Vulkan instance */
    VkApplicationInfo app_info = {
        .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "Vulkan Compute Poetry Embeddings",
        .applicationVersion = VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "vk_compute",
        .engineVersion = VK_MAKE_VERSION(1, 0, 0),
        .apiVersion = VK_API_VERSION_1_2,
    };

    const char* validation_layers[] = {
        "VK_LAYER_KHRONOS_validation"
    };

    VkInstanceCreateInfo instance_info = {
        .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &app_info,
        .enabledLayerCount = enable_validation ? 1 : 0,
        .ppEnabledLayerNames = enable_validation ? validation_layers : NULL,
    };

    VkResult result = vkCreateInstance(&instance_info, NULL, &ctx->instance);
    if (result != VK_SUCCESS) {
        fprintf(stderr, "[VKC ERROR] Failed to create Vulkan instance: %d\n", result);
        free(ctx);
        return NULL;
    }

    /* Select physical device with compute support */
    uint32_t device_count = 0;
    vkEnumeratePhysicalDevices(ctx->instance, &device_count, NULL);

    if (device_count == 0) {
        fprintf(stderr, "[VKC ERROR] No Vulkan-capable devices found\n");
        vkDestroyInstance(ctx->instance, NULL);
        free(ctx);
        return NULL;
    }

    VkPhysicalDevice* devices = malloc(sizeof(VkPhysicalDevice) * device_count);
    vkEnumeratePhysicalDevices(ctx->instance, &device_count, devices);

    /* Find device with compute queue */
    ctx->physical_device = VK_NULL_HANDLE;
    ctx->compute_queue_family = UINT32_MAX;

    for (uint32_t i = 0; i < device_count; i++) {
        uint32_t queue_family_count = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(devices[i], &queue_family_count, NULL);

        VkQueueFamilyProperties* queue_families =
            malloc(sizeof(VkQueueFamilyProperties) * queue_family_count);
        vkGetPhysicalDeviceQueueFamilyProperties(devices[i], &queue_family_count, queue_families);

        for (uint32_t j = 0; j < queue_family_count; j++) {
            if (queue_families[j].queueFlags & VK_QUEUE_COMPUTE_BIT) {
                ctx->physical_device = devices[i];
                ctx->compute_queue_family = j;
                break;
            }
        }

        free(queue_families);

        if (ctx->physical_device != VK_NULL_HANDLE) {
            break;
        }
    }

    free(devices);

    if (ctx->physical_device == VK_NULL_HANDLE) {
        fprintf(stderr, "[VKC ERROR] No device with compute queue found\n");
        vkDestroyInstance(ctx->instance, NULL);
        free(ctx);
        return NULL;
    }

    /* Get device properties */
    vkGetPhysicalDeviceProperties(ctx->physical_device, &ctx->device_properties);
    vkGetPhysicalDeviceMemoryProperties(ctx->physical_device, &ctx->memory_properties);

    printf("[VKC] Selected device: %s\n", ctx->device_properties.deviceName);
    printf("[VKC] Compute queue family: %u\n", ctx->compute_queue_family);

    /* Create logical device */
    float queue_priority = 1.0f;
    VkDeviceQueueCreateInfo queue_info = {
        .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = ctx->compute_queue_family,
        .queueCount = 1,
        .pQueuePriorities = &queue_priority,
    };

    VkDeviceCreateInfo device_info = {
        .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &queue_info,
        .enabledLayerCount = enable_validation ? 1 : 0,
        .ppEnabledLayerNames = enable_validation ? validation_layers : NULL,
    };

    result = vkCreateDevice(ctx->physical_device, &device_info, NULL, &ctx->device);
    if (result != VK_SUCCESS) {
        fprintf(stderr, "[VKC ERROR] Failed to create logical device: %d\n", result);
        vkDestroyInstance(ctx->instance, NULL);
        free(ctx);
        return NULL;
    }

    /* Get compute queue */
    vkGetDeviceQueue(ctx->device, ctx->compute_queue_family, 0, &ctx->compute_queue);

    /* Create command pool */
    VkCommandPoolCreateInfo pool_info = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .queueFamilyIndex = ctx->compute_queue_family,
        .flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
    };

    result = vkCreateCommandPool(ctx->device, &pool_info, NULL, &ctx->command_pool);
    if (result != VK_SUCCESS) {
        fprintf(stderr, "[VKC ERROR] Failed to create command pool: %d\n", result);
        vkDestroyDevice(ctx->device, NULL);
        vkDestroyInstance(ctx->instance, NULL);
        free(ctx);
        return NULL;
    }

    /* Allocate command buffer */
    VkCommandBufferAllocateInfo alloc_info = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = ctx->command_pool,
        .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = 1,
    };

    result = vkAllocateCommandBuffers(ctx->device, &alloc_info, &ctx->command_buffer);
    if (result != VK_SUCCESS) {
        fprintf(stderr, "[VKC ERROR] Failed to allocate command buffer: %d\n", result);
        vkDestroyCommandPool(ctx->device, ctx->command_pool, NULL);
        vkDestroyDevice(ctx->device, NULL);
        vkDestroyInstance(ctx->instance, NULL);
        free(ctx);
        return NULL;
    }

    /* Create fence for synchronization */
    VkFenceCreateInfo fence_info = {
        .sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = VK_FENCE_CREATE_SIGNALED_BIT,
    };

    result = vkCreateFence(ctx->device, &fence_info, NULL, &ctx->fence);
    if (result != VK_SUCCESS) {
        fprintf(stderr, "[VKC ERROR] Failed to create fence: %d\n", result);
        vkDestroyCommandPool(ctx->device, ctx->command_pool, NULL);
        vkDestroyDevice(ctx->device, NULL);
        vkDestroyInstance(ctx->instance, NULL);
        free(ctx);
        return NULL;
    }

    printf("[VKC] Initialization complete\n");
    return ctx;
}

/* }}} */

/* {{{ Cleanup: vkc_destroy
 */

void vkc_destroy(VkComputeContext* ctx) {
    if (!ctx) return;

    vkDeviceWaitIdle(ctx->device);

    if (ctx->fence != VK_NULL_HANDLE) {
        vkDestroyFence(ctx->device, ctx->fence, NULL);
    }

    if (ctx->command_pool != VK_NULL_HANDLE) {
        vkDestroyCommandPool(ctx->device, ctx->command_pool, NULL);
    }

    if (ctx->device != VK_NULL_HANDLE) {
        vkDestroyDevice(ctx->device, NULL);
    }

    if (ctx->instance != VK_NULL_HANDLE) {
        vkDestroyInstance(ctx->instance, NULL);
    }

    free(ctx);
    printf("[VKC] Cleanup complete\n");
}

/* }}} */

/* {{{ Device info functions
 */

const char* vkc_get_device_name(VkComputeContext* ctx) {
    return ctx ? ctx->device_properties.deviceName : "Unknown";
}

uint32_t vkc_get_max_workgroup_size(VkComputeContext* ctx) {
    return ctx ? ctx->device_properties.limits.maxComputeWorkGroupSize[0] : 0;
}

uint64_t vkc_get_device_memory(VkComputeContext* ctx) {
    if (!ctx) return 0;

    uint64_t total = 0;
    for (uint32_t i = 0; i < ctx->memory_properties.memoryHeapCount; i++) {
        if (ctx->memory_properties.memoryHeaps[i].flags & VK_MEMORY_HEAP_DEVICE_LOCAL_BIT) {
            total += ctx->memory_properties.memoryHeaps[i].size;
        }
    }
    return total;
}

/* }}} */

/* NOTE: Buffer management, pipeline management, and command execution
 * functions will be implemented in the next iteration to keep file manageable.
 * For now, these return placeholder values.
 */

/* {{{ Buffer management
 */

VkComputeBuffer* vkc_create_buffer(VkComputeContext* ctx, size_t size, VkComputeBufferType type) {
    if (!ctx || size == 0) return NULL;

    VkComputeBuffer* buffer = calloc(1, sizeof(VkComputeBuffer));
    if (!buffer) return NULL;

    buffer->internal.size = size;
    buffer->internal.type = type;

    /* Determine buffer usage and memory properties */
    VkBufferUsageFlags usage = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT;
    VkMemoryPropertyFlags memory_props;

    switch (type) {
        case VKC_BUFFER_DEVICE_LOCAL:
            usage |= VK_BUFFER_USAGE_TRANSFER_DST_BIT | VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
            memory_props = VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
            break;

        case VKC_BUFFER_HOST_VISIBLE:
            memory_props = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
                          VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;
            break;

        case VKC_BUFFER_STAGING:
            usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT;
            memory_props = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT |
                          VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;
            break;

        default:
            free(buffer);
            return NULL;
    }

    /* Create buffer */
    VkBufferCreateInfo buffer_info = {
        .sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = size,
        .usage = usage,
        .sharingMode = VK_SHARING_MODE_EXCLUSIVE,
    };

    VkResult result = vkCreateBuffer(ctx->device, &buffer_info, NULL, &buffer->internal.buffer);
    if (result != VK_SUCCESS) {
        fprintf(stderr, "[VKC ERROR] Failed to create buffer: %d\n", result);
        free(buffer);
        return NULL;
    }

    /* Allocate memory */
    VkMemoryRequirements mem_reqs;
    vkGetBufferMemoryRequirements(ctx->device, buffer->internal.buffer, &mem_reqs);

    uint32_t memory_type = find_memory_type(ctx, mem_reqs.memoryTypeBits, memory_props);
    if (memory_type == UINT32_MAX) {
        vkDestroyBuffer(ctx->device, buffer->internal.buffer, NULL);
        free(buffer);
        return NULL;
    }

    VkMemoryAllocateInfo alloc_info = {
        .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = mem_reqs.size,
        .memoryTypeIndex = memory_type,
    };

    result = vkAllocateMemory(ctx->device, &alloc_info, NULL, &buffer->internal.memory);
    if (result != VK_SUCCESS) {
        fprintf(stderr, "[VKC ERROR] Failed to allocate buffer memory: %d\n", result);
        vkDestroyBuffer(ctx->device, buffer->internal.buffer, NULL);
        free(buffer);
        return NULL;
    }

    /* Bind memory to buffer */
    vkBindBufferMemory(ctx->device, buffer->internal.buffer, buffer->internal.memory, 0);

    return buffer;
}

void vkc_destroy_buffer(VkComputeContext* ctx, VkComputeBuffer* buffer) {
    if (!ctx || !buffer) return;

    vkDestroyBuffer(ctx->device, buffer->internal.buffer, NULL);
    vkFreeMemory(ctx->device, buffer->internal.memory, NULL);
    free(buffer);
}

VkComputeResult vkc_upload_buffer(VkComputeContext* ctx, VkComputeBuffer* buffer,
                                  const void* data, size_t size) {
    if (!ctx || !buffer || !data || size == 0) {
        return VKC_ERROR_BUFFER_CREATION_FAILED;
    }

    if (size > buffer->internal.size) {
        fprintf(stderr, "[VKC ERROR] Upload size exceeds buffer size\n");
        return VKC_ERROR_BUFFER_CREATION_FAILED;
    }

    /* For host-visible buffers, map and copy directly */
    if (buffer->internal.type == VKC_BUFFER_HOST_VISIBLE ||
        buffer->internal.type == VKC_BUFFER_STAGING) {
        void* mapped;
        VkResult result = vkMapMemory(ctx->device, buffer->internal.memory, 0, size, 0, &mapped);
        if (result != VK_SUCCESS) {
            fprintf(stderr, "[VKC ERROR] Failed to map buffer memory: %d\n", result);
            return VKC_ERROR_BUFFER_CREATION_FAILED;
        }

        memcpy(mapped, data, size);
        vkUnmapMemory(ctx->device, buffer->internal.memory);
        return VKC_SUCCESS;
    }

    /* For device-local buffers, use staging buffer */
    VkComputeBuffer* staging = vkc_create_buffer(ctx, size, VKC_BUFFER_STAGING);
    if (!staging) {
        return VKC_ERROR_BUFFER_CREATION_FAILED;
    }

    /* Upload to staging buffer */
    VkComputeResult upload_result = vkc_upload_buffer(ctx, staging, data, size);
    if (upload_result != VKC_SUCCESS) {
        vkc_destroy_buffer(ctx, staging);
        return upload_result;
    }

    /* Copy from staging to device buffer */
    VkCommandBufferBeginInfo begin_info = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };

    vkBeginCommandBuffer(ctx->command_buffer, &begin_info);

    VkBufferCopy copy_region = {
        .srcOffset = 0,
        .dstOffset = 0,
        .size = size,
    };

    vkCmdCopyBuffer(ctx->command_buffer, staging->internal.buffer,
                    buffer->internal.buffer, 1, &copy_region);

    vkEndCommandBuffer(ctx->command_buffer);

    /* Submit and wait */
    VkSubmitInfo submit_info = {
        .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1,
        .pCommandBuffers = &ctx->command_buffer,
    };

    vkResetFences(ctx->device, 1, &ctx->fence);
    vkQueueSubmit(ctx->compute_queue, 1, &submit_info, ctx->fence);
    vkWaitForFences(ctx->device, 1, &ctx->fence, VK_TRUE, UINT64_MAX);

    vkc_destroy_buffer(ctx, staging);
    return VKC_SUCCESS;
}

VkComputeResult vkc_download_buffer(VkComputeContext* ctx, VkComputeBuffer* buffer,
                                    void* data, size_t size) {
    if (!ctx || !buffer || !data || size == 0) {
        return VKC_ERROR_BUFFER_CREATION_FAILED;
    }

    if (size > buffer->internal.size) {
        fprintf(stderr, "[VKC ERROR] Download size exceeds buffer size\n");
        return VKC_ERROR_BUFFER_CREATION_FAILED;
    }

    /* For host-visible buffers, map and copy directly */
    if (buffer->internal.type == VKC_BUFFER_HOST_VISIBLE ||
        buffer->internal.type == VKC_BUFFER_STAGING) {
        void* mapped;
        VkResult result = vkMapMemory(ctx->device, buffer->internal.memory, 0, size, 0, &mapped);
        if (result != VK_SUCCESS) {
            fprintf(stderr, "[VKC ERROR] Failed to map buffer memory: %d\n", result);
            return VKC_ERROR_BUFFER_CREATION_FAILED;
        }

        memcpy(data, mapped, size);
        vkUnmapMemory(ctx->device, buffer->internal.memory);
        return VKC_SUCCESS;
    }

    /* For device-local buffers, use staging buffer */
    VkComputeBuffer* staging = vkc_create_buffer(ctx, size, VKC_BUFFER_STAGING);
    if (!staging) {
        return VKC_ERROR_BUFFER_CREATION_FAILED;
    }

    /* Copy from device buffer to staging */
    VkCommandBufferBeginInfo begin_info = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };

    vkBeginCommandBuffer(ctx->command_buffer, &begin_info);

    VkBufferCopy copy_region = {
        .srcOffset = 0,
        .dstOffset = 0,
        .size = size,
    };

    vkCmdCopyBuffer(ctx->command_buffer, buffer->internal.buffer,
                    staging->internal.buffer, 1, &copy_region);

    vkEndCommandBuffer(ctx->command_buffer);

    /* Submit and wait */
    VkSubmitInfo submit_info = {
        .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1,
        .pCommandBuffers = &ctx->command_buffer,
    };

    vkResetFences(ctx->device, 1, &ctx->fence);
    vkQueueSubmit(ctx->compute_queue, 1, &submit_info, ctx->fence);
    vkWaitForFences(ctx->device, 1, &ctx->fence, VK_TRUE, UINT64_MAX);

    /* Download from staging buffer */
    VkComputeResult download_result = vkc_download_buffer(ctx, staging, data, size);
    vkc_destroy_buffer(ctx, staging);

    return download_result;
}

/* }}} */

/* {{{ Helper: Load SPIR-V shader
 */

static VkShaderModule load_shader_module(VkComputeContext* ctx, const char* path) {
    FILE* file = fopen(path, "rb");
    if (!file) {
        fprintf(stderr, "[VKC ERROR] Failed to open shader file: %s\n", path);
        return VK_NULL_HANDLE;
    }

    /* Get file size */
    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    fseek(file, 0, SEEK_SET);

    if (file_size <= 0 || file_size % 4 != 0) {
        fprintf(stderr, "[VKC ERROR] Invalid SPIR-V file size: %ld\n", file_size);
        fclose(file);
        return VK_NULL_HANDLE;
    }

    /* Read shader code */
    uint32_t* code = malloc(file_size);
    if (!code) {
        fclose(file);
        return VK_NULL_HANDLE;
    }

    size_t bytes_read = fread(code, 1, file_size, file);
    fclose(file);

    if (bytes_read != (size_t)file_size) {
        fprintf(stderr, "[VKC ERROR] Failed to read shader file\n");
        free(code);
        return VK_NULL_HANDLE;
    }

    /* Create shader module */
    VkShaderModuleCreateInfo module_info = {
        .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = file_size,
        .pCode = code,
    };

    VkShaderModule shader_module;
    VkResult result = vkCreateShaderModule(ctx->device, &module_info, NULL, &shader_module);

    free(code);

    if (result != VK_SUCCESS) {
        fprintf(stderr, "[VKC ERROR] Failed to create shader module: %d\n", result);
        return VK_NULL_HANDLE;
    }

    return shader_module;
}

/* }}} */

/* {{{ Pipeline management
 */

VkComputePipeline* vkc_create_pipeline(VkComputeContext* ctx, const char* shader_path,
                                       uint32_t push_constant_size) {
    if (!ctx || !shader_path) return NULL;

    VkComputePipeline* pipeline = calloc(1, sizeof(VkComputePipeline));
    if (!pipeline) return NULL;

    pipeline->internal.push_constant_size = push_constant_size;
    pipeline->internal.num_bindings = MAX_DESCRIPTOR_SETS;

    /* Load shader module */
    pipeline->internal.shader = load_shader_module(ctx, shader_path);
    if (pipeline->internal.shader == VK_NULL_HANDLE) {
        free(pipeline);
        return NULL;
    }

    /* Create descriptor set layout (supports up to MAX_DESCRIPTOR_SETS storage buffers) */
    VkDescriptorSetLayoutBinding bindings[MAX_DESCRIPTOR_SETS];
    for (uint32_t i = 0; i < MAX_DESCRIPTOR_SETS; i++) {
        bindings[i].binding = i;
        bindings[i].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        bindings[i].descriptorCount = 1;
        bindings[i].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
        bindings[i].pImmutableSamplers = NULL;
    }

    VkDescriptorSetLayoutCreateInfo layout_info = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = MAX_DESCRIPTOR_SETS,
        .pBindings = bindings,
    };

    VkResult result = vkCreateDescriptorSetLayout(ctx->device, &layout_info, NULL,
                                                   &pipeline->internal.desc_set_layout);
    if (result != VK_SUCCESS) {
        vkDestroyShaderModule(ctx->device, pipeline->internal.shader, NULL);
        free(pipeline);
        return NULL;
    }

    /* Create pipeline layout with push constants */
    VkPushConstantRange push_constant_range = {
        .stageFlags = VK_SHADER_STAGE_COMPUTE_BIT,
        .offset = 0,
        .size = push_constant_size,
    };

    VkPipelineLayoutCreateInfo pipeline_layout_info = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 1,
        .pSetLayouts = &pipeline->internal.desc_set_layout,
        .pushConstantRangeCount = push_constant_size > 0 ? 1 : 0,
        .pPushConstantRanges = push_constant_size > 0 ? &push_constant_range : NULL,
    };

    result = vkCreatePipelineLayout(ctx->device, &pipeline_layout_info, NULL,
                                    &pipeline->internal.layout);
    if (result != VK_SUCCESS) {
        vkDestroyDescriptorSetLayout(ctx->device, pipeline->internal.desc_set_layout, NULL);
        vkDestroyShaderModule(ctx->device, pipeline->internal.shader, NULL);
        free(pipeline);
        return NULL;
    }

    /* Create compute pipeline */
    VkPipelineShaderStageCreateInfo shader_stage_info = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
        .stage = VK_SHADER_STAGE_COMPUTE_BIT,
        .module = pipeline->internal.shader,
        .pName = "main",
    };

    VkComputePipelineCreateInfo pipeline_info = {
        .sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
        .stage = shader_stage_info,
        .layout = pipeline->internal.layout,
    };

    result = vkCreateComputePipelines(ctx->device, VK_NULL_HANDLE, 1, &pipeline_info,
                                      NULL, &pipeline->internal.pipeline);
    if (result != VK_SUCCESS) {
        vkDestroyPipelineLayout(ctx->device, pipeline->internal.layout, NULL);
        vkDestroyDescriptorSetLayout(ctx->device, pipeline->internal.desc_set_layout, NULL);
        vkDestroyShaderModule(ctx->device, pipeline->internal.shader, NULL);
        free(pipeline);
        return NULL;
    }

    /* Create descriptor pool */
    VkDescriptorPoolSize pool_size = {
        .type = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        .descriptorCount = MAX_DESCRIPTOR_SETS,
    };

    VkDescriptorPoolCreateInfo pool_info = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .poolSizeCount = 1,
        .pPoolSizes = &pool_size,
        .maxSets = 1,
    };

    result = vkCreateDescriptorPool(ctx->device, &pool_info, NULL,
                                    &pipeline->internal.desc_pool);
    if (result != VK_SUCCESS) {
        vkDestroyPipeline(ctx->device, pipeline->internal.pipeline, NULL);
        vkDestroyPipelineLayout(ctx->device, pipeline->internal.layout, NULL);
        vkDestroyDescriptorSetLayout(ctx->device, pipeline->internal.desc_set_layout, NULL);
        vkDestroyShaderModule(ctx->device, pipeline->internal.shader, NULL);
        free(pipeline);
        return NULL;
    }

    /* Allocate descriptor set */
    VkDescriptorSetAllocateInfo alloc_info = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = pipeline->internal.desc_pool,
        .descriptorSetCount = 1,
        .pSetLayouts = &pipeline->internal.desc_set_layout,
    };

    result = vkAllocateDescriptorSets(ctx->device, &alloc_info,
                                      &pipeline->internal.desc_set);
    if (result != VK_SUCCESS) {
        vkDestroyDescriptorPool(ctx->device, pipeline->internal.desc_pool, NULL);
        vkDestroyPipeline(ctx->device, pipeline->internal.pipeline, NULL);
        vkDestroyPipelineLayout(ctx->device, pipeline->internal.layout, NULL);
        vkDestroyDescriptorSetLayout(ctx->device, pipeline->internal.desc_set_layout, NULL);
        vkDestroyShaderModule(ctx->device, pipeline->internal.shader, NULL);
        free(pipeline);
        return NULL;
    }

    return pipeline;
}

void vkc_destroy_pipeline(VkComputeContext* ctx, VkComputePipeline* pipeline) {
    if (!ctx || !pipeline) return;

    vkDestroyDescriptorPool(ctx->device, pipeline->internal.desc_pool, NULL);
    vkDestroyPipeline(ctx->device, pipeline->internal.pipeline, NULL);
    vkDestroyPipelineLayout(ctx->device, pipeline->internal.layout, NULL);
    vkDestroyDescriptorSetLayout(ctx->device, pipeline->internal.desc_set_layout, NULL);
    vkDestroyShaderModule(ctx->device, pipeline->internal.shader, NULL);
    free(pipeline);
}

VkComputeResult vkc_bind_buffer(VkComputeContext* ctx, VkComputePipeline* pipeline,
                                uint32_t binding, VkComputeBuffer* buffer) {
    if (!ctx || !pipeline || !buffer) {
        return VKC_ERROR_PIPELINE_CREATION_FAILED;
    }

    if (binding >= MAX_DESCRIPTOR_SETS) {
        fprintf(stderr, "[VKC ERROR] Binding index %u exceeds maximum %d\n",
                binding, MAX_DESCRIPTOR_SETS);
        return VKC_ERROR_PIPELINE_CREATION_FAILED;
    }

    VkDescriptorBufferInfo buffer_info = {
        .buffer = buffer->internal.buffer,
        .offset = 0,
        .range = VK_WHOLE_SIZE,
    };

    VkWriteDescriptorSet descriptor_write = {
        .sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dstSet = pipeline->internal.desc_set,
        .dstBinding = binding,
        .dstArrayElement = 0,
        .descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        .descriptorCount = 1,
        .pBufferInfo = &buffer_info,
    };

    vkUpdateDescriptorSets(ctx->device, 1, &descriptor_write, 0, NULL);

    return VKC_SUCCESS;
}

VkComputeResult vkc_dispatch(VkComputeContext* ctx, VkComputePipeline* pipeline,
                             uint32_t x, uint32_t y, uint32_t z,
                             const void* push_constants) {
    if (!ctx || !pipeline) {
        return VKC_ERROR_COMMAND_EXECUTION_FAILED;
    }

    /* Begin command buffer */
    VkCommandBufferBeginInfo begin_info = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };

    VkResult result = vkBeginCommandBuffer(ctx->command_buffer, &begin_info);
    if (result != VK_SUCCESS) {
        fprintf(stderr, "[VKC ERROR] Failed to begin command buffer: %d\n", result);
        return VKC_ERROR_COMMAND_EXECUTION_FAILED;
    }

    /* Bind pipeline */
    vkCmdBindPipeline(ctx->command_buffer, VK_PIPELINE_BIND_POINT_COMPUTE,
                      pipeline->internal.pipeline);

    /* Bind descriptor sets */
    vkCmdBindDescriptorSets(ctx->command_buffer, VK_PIPELINE_BIND_POINT_COMPUTE,
                           pipeline->internal.layout, 0, 1,
                           &pipeline->internal.desc_set, 0, NULL);

    /* Push constants if provided */
    if (push_constants && pipeline->internal.push_constant_size > 0) {
        vkCmdPushConstants(ctx->command_buffer, pipeline->internal.layout,
                          VK_SHADER_STAGE_COMPUTE_BIT, 0,
                          pipeline->internal.push_constant_size, push_constants);
    }

    /* Dispatch compute shader */
    vkCmdDispatch(ctx->command_buffer, x, y, z);

    /* End command buffer */
    result = vkEndCommandBuffer(ctx->command_buffer);
    if (result != VK_SUCCESS) {
        fprintf(stderr, "[VKC ERROR] Failed to end command buffer: %d\n", result);
        return VKC_ERROR_COMMAND_EXECUTION_FAILED;
    }

    /* Submit command buffer */
    VkSubmitInfo submit_info = {
        .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1,
        .pCommandBuffers = &ctx->command_buffer,
    };

    vkResetFences(ctx->device, 1, &ctx->fence);
    result = vkQueueSubmit(ctx->compute_queue, 1, &submit_info, ctx->fence);
    if (result != VK_SUCCESS) {
        fprintf(stderr, "[VKC ERROR] Failed to submit command buffer: %d\n", result);
        return VKC_ERROR_COMMAND_EXECUTION_FAILED;
    }

    /* Wait for completion */
    result = vkWaitForFences(ctx->device, 1, &ctx->fence, VK_TRUE, UINT64_MAX);
    if (result != VK_SUCCESS) {
        fprintf(stderr, "[VKC ERROR] Failed to wait for fence: %d\n", result);
        return VKC_ERROR_COMMAND_EXECUTION_FAILED;
    }

    return VKC_SUCCESS;
}

VkComputeResult vkc_wait_idle(VkComputeContext* ctx) {
    if (!ctx) return VKC_ERROR_INIT_FAILED;
    vkDeviceWaitIdle(ctx->device);
    return VKC_SUCCESS;
}

/* }}} */
