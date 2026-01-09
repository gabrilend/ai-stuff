/* test_buffers.c - Test buffer upload/download operations
 *
 * Verifies that the library can create buffers and transfer data.
 */

#include "include/vk_compute.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define BUFFER_SIZE (1024 * sizeof(float))  /* 1KB test buffer */

int main(void) {
    printf("=== Vulkan Buffer Test ===\n\n");

    /* Initialize */
    VkComputeContext* ctx = vkc_init(false);
    if (!ctx) {
        fprintf(stderr, "ERROR: Failed to initialize Vulkan\n");
        return 1;
    }

    /* Create test data */
    float* input_data = malloc(BUFFER_SIZE);
    float* output_data = malloc(BUFFER_SIZE);

    for (size_t i = 0; i < BUFFER_SIZE / sizeof(float); i++) {
        input_data[i] = (float)i * 0.1f;
    }

    printf("[TEST 1] Device-local buffer upload/download\n");

    /* Create device-local buffer */
    VkComputeBuffer* device_buffer = vkc_create_buffer(ctx, BUFFER_SIZE,
                                                        VKC_BUFFER_DEVICE_LOCAL);
    if (!device_buffer) {
        fprintf(stderr, "ERROR: Failed to create device buffer\n");
        vkc_destroy(ctx);
        return 1;
    }

    /* Upload data */
    VkComputeResult result = vkc_upload_buffer(ctx, device_buffer, input_data, BUFFER_SIZE);
    if (result != VKC_SUCCESS) {
        fprintf(stderr, "ERROR: Failed to upload buffer: %s\n", vkc_get_error_string(result));
        vkc_destroy_buffer(ctx, device_buffer);
        vkc_destroy(ctx);
        return 1;
    }

    printf("  Uploaded %zu bytes to device buffer\n", BUFFER_SIZE);

    /* Download data */
    result = vkc_download_buffer(ctx, device_buffer, output_data, BUFFER_SIZE);
    if (result != VKC_SUCCESS) {
        fprintf(stderr, "ERROR: Failed to download buffer: %s\n", vkc_get_error_string(result));
        vkc_destroy_buffer(ctx, device_buffer);
        vkc_destroy(ctx);
        return 1;
    }

    printf("  Downloaded %zu bytes from device buffer\n", BUFFER_SIZE);

    /* Verify data */
    bool verified = true;
    for (size_t i = 0; i < BUFFER_SIZE / sizeof(float); i++) {
        if (fabs(input_data[i] - output_data[i]) > 0.0001f) {
            fprintf(stderr, "ERROR: Data mismatch at index %zu: %.3f != %.3f\n",
                    i, input_data[i], output_data[i]);
            verified = false;
            break;
        }
    }

    if (verified) {
        printf("  [SUCCESS] Data verified correctly\n");
    } else {
        fprintf(stderr, "  [FAILED] Data verification failed\n");
        vkc_destroy_buffer(ctx, device_buffer);
        vkc_destroy(ctx);
        return 1;
    }

    vkc_destroy_buffer(ctx, device_buffer);

    printf("\n[TEST 2] Host-visible buffer operations\n");

    /* Create host-visible buffer */
    VkComputeBuffer* host_buffer = vkc_create_buffer(ctx, BUFFER_SIZE,
                                                      VKC_BUFFER_HOST_VISIBLE);
    if (!host_buffer) {
        fprintf(stderr, "ERROR: Failed to create host buffer\n");
        vkc_destroy(ctx);
        return 1;
    }

    /* Upload and download */
    result = vkc_upload_buffer(ctx, host_buffer, input_data, BUFFER_SIZE);
    if (result != VKC_SUCCESS) {
        fprintf(stderr, "ERROR: Failed to upload to host buffer\n");
        vkc_destroy_buffer(ctx, host_buffer);
        vkc_destroy(ctx);
        return 1;
    }

    result = vkc_download_buffer(ctx, host_buffer, output_data, BUFFER_SIZE);
    if (result != VKC_SUCCESS) {
        fprintf(stderr, "ERROR: Failed to download from host buffer\n");
        vkc_destroy_buffer(ctx, host_buffer);
        vkc_destroy(ctx);
        return 1;
    }

    /* Verify */
    verified = true;
    for (size_t i = 0; i < BUFFER_SIZE / sizeof(float); i++) {
        if (fabs(input_data[i] - output_data[i]) > 0.0001f) {
            verified = false;
            break;
        }
    }

    if (verified) {
        printf("  [SUCCESS] Host-visible buffer works correctly\n");
    } else {
        fprintf(stderr, "  [FAILED] Host buffer verification failed\n");
        vkc_destroy_buffer(ctx, host_buffer);
        vkc_destroy(ctx);
        return 1;
    }

    vkc_destroy_buffer(ctx, host_buffer);

    /* Cleanup */
    free(input_data);
    free(output_data);
    vkc_destroy(ctx);

    printf("\n[SUCCESS] All buffer tests passed!\n");
    return 0;
}
