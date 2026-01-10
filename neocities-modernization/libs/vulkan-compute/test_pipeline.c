/* test_pipeline.c - Test complete compute pipeline
 *
 * Tests shader loading, pipeline creation, buffer binding, and dispatch.
 */

#include "include/vk_compute.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define NUM_ELEMENTS 1024

int main(void) {
    printf("=== Vulkan Pipeline Test ===\n\n");

    /* Initialize Vulkan */
    printf("[1] Initializing Vulkan...\n");
    VkComputeContext* ctx = vkc_init(false);
    if (!ctx) {
        fprintf(stderr, "ERROR: Failed to initialize Vulkan\n");
        return 1;
    }
    printf("    [OK] Vulkan initialized\n");

    /* Create test data */
    printf("\n[2] Creating test data (%d floats)...\n", NUM_ELEMENTS);
    float* input_data = malloc(NUM_ELEMENTS * sizeof(float));
    float* output_data = calloc(NUM_ELEMENTS, sizeof(float));

    for (size_t i = 0; i < NUM_ELEMENTS; i++) {
        input_data[i] = (float)i;
    }
    printf("    [OK] Input: [0.0, 1.0, 2.0, ... %d.0]\n", NUM_ELEMENTS - 1);

    /* Create GPU buffers */
    printf("\n[3] Creating GPU buffers...\n");
    VkComputeBuffer* input_buffer = vkc_create_buffer(ctx,
                                                      NUM_ELEMENTS * sizeof(float),
                                                      VKC_BUFFER_DEVICE_LOCAL);
    VkComputeBuffer* output_buffer = vkc_create_buffer(ctx,
                                                        NUM_ELEMENTS * sizeof(float),
                                                        VKC_BUFFER_DEVICE_LOCAL);

    if (!input_buffer || !output_buffer) {
        fprintf(stderr, "ERROR: Failed to create buffers\n");
        vkc_destroy(ctx);
        return 1;
    }
    printf("    [OK] Created input and output buffers\n");

    /* Upload input data */
    printf("\n[4] Uploading data to GPU...\n");
    VkComputeResult result = vkc_upload_buffer(ctx, input_buffer, input_data,
                                               NUM_ELEMENTS * sizeof(float));
    if (result != VKC_SUCCESS) {
        fprintf(stderr, "ERROR: Failed to upload input data\n");
        vkc_destroy_buffer(ctx, input_buffer);
        vkc_destroy_buffer(ctx, output_buffer);
        vkc_destroy(ctx);
        return 1;
    }
    printf("    [OK] Uploaded %zu bytes\n", NUM_ELEMENTS * sizeof(float));

    /* Create compute pipeline */
    printf("\n[5] Loading shader and creating pipeline...\n");
    VkComputePipeline* pipeline = vkc_create_pipeline(ctx,
                                                       "build/test_multiply.spv",
                                                       sizeof(uint32_t));

    if (!pipeline) {
        fprintf(stderr, "ERROR: Failed to create pipeline\n");
        vkc_destroy_buffer(ctx, input_buffer);
        vkc_destroy_buffer(ctx, output_buffer);
        vkc_destroy(ctx);
        return 1;
    }
    printf("    [OK] Pipeline created from test_multiply.spv\n");

    /* Bind buffers to pipeline */
    printf("\n[6] Binding buffers to pipeline...\n");
    result = vkc_bind_buffer(ctx, pipeline, 0, input_buffer);
    if (result != VKC_SUCCESS) {
        fprintf(stderr, "ERROR: Failed to bind input buffer\n");
        vkc_destroy_pipeline(ctx, pipeline);
        vkc_destroy_buffer(ctx, input_buffer);
        vkc_destroy_buffer(ctx, output_buffer);
        vkc_destroy(ctx);
        return 1;
    }

    result = vkc_bind_buffer(ctx, pipeline, 1, output_buffer);
    if (result != VKC_SUCCESS) {
        fprintf(stderr, "ERROR: Failed to bind output buffer\n");
        vkc_destroy_pipeline(ctx, pipeline);
        vkc_destroy_buffer(ctx, input_buffer);
        vkc_destroy_buffer(ctx, output_buffer);
        vkc_destroy(ctx);
        return 1;
    }
    printf("    [OK] Buffers bound to bindings 0 and 1\n");

    /* Dispatch compute shader */
    printf("\n[7] Dispatching compute shader...\n");
    uint32_t push_constant = NUM_ELEMENTS;
    uint32_t workgroup_count = (NUM_ELEMENTS + 255) / 256;

    printf("    Workgroups: %u (256 threads each)\n", workgroup_count);
    printf("    Push constant: count=%u\n", push_constant);

    result = vkc_dispatch(ctx, pipeline, workgroup_count, 1, 1, &push_constant);
    if (result != VKC_SUCCESS) {
        fprintf(stderr, "ERROR: Failed to dispatch shader: %s\n",
                vkc_get_error_string(result));
        vkc_destroy_pipeline(ctx, pipeline);
        vkc_destroy_buffer(ctx, input_buffer);
        vkc_destroy_buffer(ctx, output_buffer);
        vkc_destroy(ctx);
        return 1;
    }
    printf("    [OK] Shader executed successfully\n");

    /* Download results */
    printf("\n[8] Downloading results from GPU...\n");
    result = vkc_download_buffer(ctx, output_buffer, output_data,
                                  NUM_ELEMENTS * sizeof(float));
    if (result != VKC_SUCCESS) {
        fprintf(stderr, "ERROR: Failed to download output data\n");
        vkc_destroy_pipeline(ctx, pipeline);
        vkc_destroy_buffer(ctx, input_buffer);
        vkc_destroy_buffer(ctx, output_buffer);
        vkc_destroy(ctx);
        return 1;
    }
    printf("    [OK] Downloaded %zu bytes\n", NUM_ELEMENTS * sizeof(float));

    /* Verify results */
    printf("\n[9] Verifying results...\n");
    bool all_correct = true;
    int error_count = 0;

    for (size_t i = 0; i < NUM_ELEMENTS; i++) {
        float expected = input_data[i] * 2.0f;
        if (fabs(output_data[i] - expected) > 0.0001f) {
            if (error_count < 5) {
                fprintf(stderr, "    MISMATCH at index %zu: expected %.1f, got %.1f\n",
                        i, expected, output_data[i]);
            }
            all_correct = false;
            error_count++;
        }
    }

    if (all_correct) {
        printf("    [SUCCESS] All %d values correct!\n", NUM_ELEMENTS);
        printf("    Sample results: [0.0, 2.0, 4.0, ... %d.0]\n",
               (NUM_ELEMENTS - 1) * 2);
    } else {
        fprintf(stderr, "    [FAILED] %d errors found\n", error_count);
    }

    /* Cleanup */
    printf("\n[10] Cleaning up...\n");
    free(input_data);
    free(output_data);
    vkc_destroy_pipeline(ctx, pipeline);
    vkc_destroy_buffer(ctx, input_buffer);
    vkc_destroy_buffer(ctx, output_buffer);
    vkc_destroy(ctx);

    if (all_correct) {
        printf("\n[SUCCESS] Pipeline test passed!\n");
        return 0;
    } else {
        printf("\n[FAILED] Pipeline test failed\n");
        return 1;
    }
}
