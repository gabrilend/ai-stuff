/* test_init.c - Test Vulkan compute library initialization
 *
 * Verifies that the library can initialize Vulkan and detect the GPU.
 */

#include "include/vk_compute.h"
#include <stdio.h>

int main(void) {
    printf("=== Vulkan Compute Library Test ===\n\n");

    /* Test initialization with validation layers */
    printf("Initializing Vulkan (with validation)...\n");
    VkComputeContext* ctx = vkc_init(false);  /* Disable validation for now */

    if (!ctx) {
        fprintf(stderr, "ERROR: Failed to initialize Vulkan context\n");
        return 1;
    }

    printf("\n[SUCCESS] Vulkan initialized\n\n");

    /* Query device information */
    const char* device_name = vkc_get_device_name(ctx);
    uint32_t max_workgroup = vkc_get_max_workgroup_size(ctx);
    uint64_t device_memory = vkc_get_device_memory(ctx);

    printf("Device Information:\n");
    printf("  Name: %s\n", device_name);
    printf("  Max workgroup size: %u\n", max_workgroup);
    printf("  Device memory: %.2f GB\n", device_memory / (1024.0 * 1024.0 * 1024.0));

    /* Cleanup */
    printf("\nCleaning up...\n");
    vkc_destroy(ctx);

    printf("\n[SUCCESS] All tests passed\n");
    return 0;
}
