/* test_cosine.c - Test cosine distance shader against CPU reference
 *
 * Validates that the GPU cosine distance computation matches CPU results
 * for 768-dimensional poem embeddings.
 */

#include "include/vk_compute.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

#define EMBEDDING_DIM 768
#define NUM_EMBEDDINGS 7793  /* Test with real dataset size */
#define TOLERANCE 0.0001f    /* Floating-point comparison tolerance */

/* {{{ CPU reference implementation
 */

/* CPU cosine distance calculation (reference implementation) */
float cpu_cosine_distance(const float* embedding, const float* centroid, int dim) {
    float dot_product = 0.0f;
    float norm_embedding = 0.0f;
    float norm_centroid = 0.0f;

    for (int i = 0; i < dim; i++) {
        dot_product += embedding[i] * centroid[i];
        norm_embedding += embedding[i] * embedding[i];
        norm_centroid += centroid[i] * centroid[i];
    }

    float norm_product = sqrtf(norm_embedding) * sqrtf(norm_centroid);

    if (norm_product == 0.0f) {
        return 0.0f;
    }

    float similarity = dot_product / norm_product;
    return 1.0f - similarity;
}

/* Calculate all distances on CPU */
void cpu_calculate_distances(const float* embeddings,
                             const float* centroid,
                             float* distances,
                             int num_embeddings,
                             int embedding_dim) {
    for (int i = 0; i < num_embeddings; i++) {
        const float* emb = &embeddings[i * embedding_dim];
        distances[i] = cpu_cosine_distance(emb, centroid, embedding_dim);
    }
}

/* }}} */

/* {{{ Test data generation
 */

/* Generate random embedding data */
void generate_test_embeddings(float* embeddings, int num_embeddings, int dim) {
    for (int i = 0; i < num_embeddings * dim; i++) {
        /* Random values between -1.0 and 1.0 */
        embeddings[i] = ((float)rand() / RAND_MAX) * 2.0f - 1.0f;
    }
}

/* Generate random centroid */
void generate_test_centroid(float* centroid, int dim) {
    for (int i = 0; i < dim; i++) {
        centroid[i] = ((float)rand() / RAND_MAX) * 2.0f - 1.0f;
    }
}

/* }}} */

int main(void) {
    printf("=== Cosine Distance Shader Test ===\n\n");
    printf("Configuration:\n");
    printf("  Embedding dimension: %d\n", EMBEDDING_DIM);
    printf("  Number of embeddings: %d\n", NUM_EMBEDDINGS);
    printf("  Total data: %.2f MB\n",
           (NUM_EMBEDDINGS * EMBEDDING_DIM * sizeof(float)) / (1024.0f * 1024.0f));

    /* Seed RNG for reproducible tests */
    srand(42);

    /* Allocate test data */
    printf("\n[1] Generating test data...\n");
    float* embeddings = malloc(NUM_EMBEDDINGS * EMBEDDING_DIM * sizeof(float));
    float* centroid = malloc(EMBEDDING_DIM * sizeof(float));
    float* cpu_distances = malloc(NUM_EMBEDDINGS * sizeof(float));
    float* gpu_distances = malloc(NUM_EMBEDDINGS * sizeof(float));

    if (!embeddings || !centroid || !cpu_distances || !gpu_distances) {
        fprintf(stderr, "ERROR: Memory allocation failed\n");
        return 1;
    }

    generate_test_embeddings(embeddings, NUM_EMBEDDINGS, EMBEDDING_DIM);
    generate_test_centroid(centroid, EMBEDDING_DIM);
    printf("    [OK] Generated %d random embeddings\n", NUM_EMBEDDINGS);

    /* CPU reference calculation */
    printf("\n[2] Computing distances on CPU...\n");
    clock_t cpu_start = clock();
    cpu_calculate_distances(embeddings, centroid, cpu_distances,
                           NUM_EMBEDDINGS, EMBEDDING_DIM);
    clock_t cpu_end = clock();
    double cpu_time = ((double)(cpu_end - cpu_start)) / CLOCKS_PER_SEC * 1000.0;
    printf("    [OK] CPU time: %.2f ms\n", cpu_time);

    /* Initialize Vulkan */
    printf("\n[3] Initializing Vulkan...\n");
    VkComputeContext* ctx = vkc_init(false);
    if (!ctx) {
        fprintf(stderr, "ERROR: Failed to initialize Vulkan\n");
        return 1;
    }
    printf("    [OK] Device: %s\n", vkc_get_device_name(ctx));

    /* Create GPU buffers */
    printf("\n[4] Creating GPU buffers...\n");
    VkComputeBuffer* embeddings_buf = vkc_create_buffer(ctx,
                                                        NUM_EMBEDDINGS * EMBEDDING_DIM * sizeof(float),
                                                        VKC_BUFFER_DEVICE_LOCAL);
    VkComputeBuffer* centroid_buf = vkc_create_buffer(ctx,
                                                      EMBEDDING_DIM * sizeof(float),
                                                      VKC_BUFFER_DEVICE_LOCAL);
    VkComputeBuffer* distances_buf = vkc_create_buffer(ctx,
                                                       NUM_EMBEDDINGS * sizeof(float),
                                                       VKC_BUFFER_DEVICE_LOCAL);

    if (!embeddings_buf || !centroid_buf || !distances_buf) {
        fprintf(stderr, "ERROR: Failed to create GPU buffers\n");
        vkc_destroy(ctx);
        return 1;
    }
    printf("    [OK] Created 3 buffers\n");

    /* Upload data to GPU */
    printf("\n[5] Uploading data to GPU...\n");
    vkc_upload_buffer(ctx, embeddings_buf, embeddings,
                     NUM_EMBEDDINGS * EMBEDDING_DIM * sizeof(float));
    vkc_upload_buffer(ctx, centroid_buf, centroid,
                     EMBEDDING_DIM * sizeof(float));
    printf("    [OK] Uploaded %.2f MB\n",
           ((NUM_EMBEDDINGS * EMBEDDING_DIM + EMBEDDING_DIM) * sizeof(float)) / (1024.0f * 1024.0f));

    /* Create pipeline */
    printf("\n[6] Loading cosine distance shader...\n");

    /* Push constants structure */
    struct {
        uint32_t num_embeddings;
        uint32_t embedding_dim;
    } push_constants = {
        .num_embeddings = NUM_EMBEDDINGS,
        .embedding_dim = EMBEDDING_DIM,
    };

    VkComputePipeline* pipeline = vkc_create_pipeline(ctx,
                                                       "build/cosine_distance.spv",
                                                       sizeof(push_constants));
    if (!pipeline) {
        fprintf(stderr, "ERROR: Failed to create pipeline\n");
        vkc_destroy_buffer(ctx, embeddings_buf);
        vkc_destroy_buffer(ctx, centroid_buf);
        vkc_destroy_buffer(ctx, distances_buf);
        vkc_destroy(ctx);
        return 1;
    }
    printf("    [OK] Pipeline created\n");

    /* Bind buffers */
    printf("\n[7] Binding buffers to pipeline...\n");
    vkc_bind_buffer(ctx, pipeline, 0, embeddings_buf);
    vkc_bind_buffer(ctx, pipeline, 1, centroid_buf);
    vkc_bind_buffer(ctx, pipeline, 2, distances_buf);
    printf("    [OK] Buffers bound\n");

    /* Dispatch shader */
    printf("\n[8] Dispatching compute shader...\n");
    uint32_t workgroup_count = (NUM_EMBEDDINGS + 255) / 256;
    printf("    Workgroups: %u (256 threads each)\n", workgroup_count);

    clock_t gpu_start = clock();
    VkComputeResult result = vkc_dispatch(ctx, pipeline, workgroup_count, 1, 1,
                                         &push_constants);
    clock_t gpu_end = clock();

    if (result != VKC_SUCCESS) {
        fprintf(stderr, "ERROR: Failed to dispatch shader\n");
        vkc_destroy_pipeline(ctx, pipeline);
        vkc_destroy_buffer(ctx, embeddings_buf);
        vkc_destroy_buffer(ctx, centroid_buf);
        vkc_destroy_buffer(ctx, distances_buf);
        vkc_destroy(ctx);
        return 1;
    }

    double gpu_time = ((double)(gpu_end - gpu_start)) / CLOCKS_PER_SEC * 1000.0;
    printf("    [OK] GPU time: %.2f ms\n", gpu_time);
    printf("    Speedup: %.2fx\n", cpu_time / gpu_time);

    /* Download results */
    printf("\n[9] Downloading results from GPU...\n");
    vkc_download_buffer(ctx, distances_buf, gpu_distances,
                       NUM_EMBEDDINGS * sizeof(float));
    printf("    [OK] Downloaded %d distance values\n", NUM_EMBEDDINGS);

    /* Compare results */
    printf("\n[10] Comparing CPU vs GPU results...\n");
    int mismatches = 0;
    float max_error = 0.0f;
    float total_error = 0.0f;

    for (int i = 0; i < NUM_EMBEDDINGS; i++) {
        float error = fabsf(cpu_distances[i] - gpu_distances[i]);
        total_error += error;

        if (error > max_error) {
            max_error = error;
        }

        if (error > TOLERANCE) {
            if (mismatches < 5) {
                printf("    MISMATCH [%d]: CPU=%.6f, GPU=%.6f, error=%.6f\n",
                       i, cpu_distances[i], gpu_distances[i], error);
            }
            mismatches++;
        }
    }

    float avg_error = total_error / NUM_EMBEDDINGS;

    printf("\n    Results:\n");
    printf("      Matches: %d / %d\n", NUM_EMBEDDINGS - mismatches, NUM_EMBEDDINGS);
    printf("      Average error: %.8f\n", avg_error);
    printf("      Max error: %.8f\n", max_error);
    printf("      Tolerance: %.8f\n", TOLERANCE);

    bool passed = (mismatches == 0);

    if (passed) {
        printf("\n    [SUCCESS] All results match within tolerance!\n");
    } else {
        printf("\n    [FAILED] %d mismatches found\n", mismatches);
    }

    /* Print sample values */
    printf("\n    Sample values:\n");
    for (int i = 0; i < 5 && i < NUM_EMBEDDINGS; i++) {
        printf("      [%d] CPU: %.6f, GPU: %.6f\n",
               i, cpu_distances[i], gpu_distances[i]);
    }

    /* Cleanup */
    printf("\n[11] Cleaning up...\n");
    free(embeddings);
    free(centroid);
    free(cpu_distances);
    free(gpu_distances);
    vkc_destroy_pipeline(ctx, pipeline);
    vkc_destroy_buffer(ctx, embeddings_buf);
    vkc_destroy_buffer(ctx, centroid_buf);
    vkc_destroy_buffer(ctx, distances_buf);
    vkc_destroy(ctx);

    if (passed) {
        printf("\n[SUCCESS] Cosine distance shader validated!\n");
        return 0;
    } else {
        printf("\n[FAILED] Validation failed\n");
        return 1;
    }
}

/* }}} */
