/* vk_similarity.c - Vulkan-accelerated similarity matrix computation
 *
 * Implements GPU-accelerated cosine similarity calculation for generating
 * triangular individual similarity files.
 */

#include "vk_similarity.h"
#include "vk_compute.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* {{{ Internal structures
 */

struct VkSimilarityContext {
    VkComputeContext* vk_ctx;

    // Buffers
    VkComputeBuffer* embeddings_buffer;      // All embeddings (GPU)
    VkComputeBuffer* source_embedding_buffer; // Current source embedding (GPU)
    VkComputeBuffer* similarities_buffer;     // Output similarities (GPU)

    // Pipeline
    VkComputePipeline* similarity_pipeline;

    // Metadata
    uint32_t num_poems;
    uint32_t embedding_dim;

    // Scratch space
    float* embeddings_cpu;        // CPU copy of embeddings for source extraction
    float* similarities_scratch;  // CPU buffer for downloading results
};

/* }}} */

/* {{{ vks_init - Initialize similarity computation context
 */

VkSimilarityContext* vks_init(VkComputeContext* ctx,
                               const float* embeddings,
                               uint32_t num_poems,
                               uint32_t embedding_dim) {
    if (!ctx || !embeddings || num_poems == 0 || embedding_dim == 0) {
        fprintf(stderr, "[VKS ERROR] Invalid parameters to vks_init\n");
        return NULL;
    }

    VkSimilarityContext* sim_ctx = (VkSimilarityContext*)calloc(1, sizeof(VkSimilarityContext));
    if (!sim_ctx) {
        fprintf(stderr, "[VKS ERROR] Failed to allocate similarity context\n");
        return NULL;
    }

    sim_ctx->vk_ctx = ctx;
    sim_ctx->num_poems = num_poems;
    sim_ctx->embedding_dim = embedding_dim;

    // Calculate buffer sizes
    size_t embeddings_size = num_poems * embedding_dim * sizeof(float);
    size_t source_embedding_size = embedding_dim * sizeof(float);
    size_t max_similarities_size = (num_poems - 1) * sizeof(float); // Max output size

    // Create buffers
    sim_ctx->embeddings_buffer = vkc_create_buffer(ctx, embeddings_size, VKC_BUFFER_DEVICE_LOCAL);
    sim_ctx->source_embedding_buffer = vkc_create_buffer(ctx, source_embedding_size, VKC_BUFFER_DEVICE_LOCAL);
    sim_ctx->similarities_buffer = vkc_create_buffer(ctx, max_similarities_size, VKC_BUFFER_DEVICE_LOCAL);

    if (!sim_ctx->embeddings_buffer || !sim_ctx->source_embedding_buffer || !sim_ctx->similarities_buffer) {
        fprintf(stderr, "[VKS ERROR] Failed to create GPU buffers\n");
        vks_destroy(sim_ctx);
        return NULL;
    }

    // Upload embeddings to GPU (one-time upload)
    VkComputeResult result = vkc_upload_buffer(ctx, sim_ctx->embeddings_buffer,
                                                (void*)embeddings, embeddings_size);
    if (result != VKC_SUCCESS) {
        fprintf(stderr, "[VKS ERROR] Failed to upload embeddings: %s\n",
                vkc_get_error_string(result));
        vks_destroy(sim_ctx);
        return NULL;
    }

    // Load similarity batch shader
    sim_ctx->similarity_pipeline = vkc_create_pipeline(
        ctx,
        "libs/vulkan-compute/build/similarity_batch.spv",
        sizeof(uint32_t) * 4  // Push constants: num_poems, embedding_dim, source_index, num_targets
    );

    if (!sim_ctx->similarity_pipeline) {
        fprintf(stderr, "[VKS ERROR] Failed to load similarity shader\n");
        vks_destroy(sim_ctx);
        return NULL;
    }

    // Allocate CPU scratch space
    sim_ctx->similarities_scratch = (float*)malloc(max_similarities_size);
    if (!sim_ctx->similarities_scratch) {
        fprintf(stderr, "[VKS ERROR] Failed to allocate scratch space\n");
        vks_destroy(sim_ctx);
        return NULL;
    }

    // Keep CPU copy of embeddings for source extraction
    sim_ctx->embeddings_cpu = (float*)malloc(embeddings_size);
    if (!sim_ctx->embeddings_cpu) {
        fprintf(stderr, "[VKS ERROR] Failed to allocate CPU embeddings copy\n");
        vks_destroy(sim_ctx);
        return NULL;
    }
    memcpy(sim_ctx->embeddings_cpu, embeddings, embeddings_size);

    printf("[VKS] Initialized for %u poems × %u dimensions\n", num_poems, embedding_dim);
    printf("[VKS] Embeddings uploaded: %.2f MB\n", embeddings_size / (1024.0 * 1024.0));
    printf("[VKS] CPU copy retained: %.2f MB\n", embeddings_size / (1024.0 * 1024.0));

    return sim_ctx;
}

/* }}} */

/* {{{ vks_destroy - Clean up similarity computation context
 */

void vks_destroy(VkSimilarityContext* sim_ctx) {
    if (!sim_ctx) return;

    if (sim_ctx->embeddings_cpu) {
        free(sim_ctx->embeddings_cpu);
    }

    if (sim_ctx->similarities_scratch) {
        free(sim_ctx->similarities_scratch);
    }

    if (sim_ctx->similarity_pipeline) {
        vkc_destroy_pipeline(sim_ctx->vk_ctx, sim_ctx->similarity_pipeline);
    }

    if (sim_ctx->similarities_buffer) {
        vkc_destroy_buffer(sim_ctx->vk_ctx, sim_ctx->similarities_buffer);
    }

    if (sim_ctx->source_embedding_buffer) {
        vkc_destroy_buffer(sim_ctx->vk_ctx, sim_ctx->source_embedding_buffer);
    }

    if (sim_ctx->embeddings_buffer) {
        vkc_destroy_buffer(sim_ctx->vk_ctx, sim_ctx->embeddings_buffer);
    }

    free(sim_ctx);
}

/* }}} */

/* {{{ vks_compute_similarities_for_poem - Compute similarities for one poem
 */

VkComputeResult vks_compute_similarities_for_poem(
    VkSimilarityContext* sim_ctx,
    uint32_t source_poem_index,
    float* output_similarities) {

    if (!sim_ctx || !output_similarities) {
        return VKC_ERROR_COMMAND_EXECUTION_FAILED;
    }

    if (source_poem_index >= sim_ctx->num_poems - 1) {
        // Last poem has no higher-indexed poems to compare to
        return VKC_SUCCESS;
    }

    // Calculate number of target poems (all poems with index > source_poem_index)
    uint32_t num_targets = sim_ctx->num_poems - source_poem_index - 1;

    // Extract source embedding from CPU copy
    const float* source_embedding = sim_ctx->embeddings_cpu +
                                     (source_poem_index * sim_ctx->embedding_dim);

    // Upload source embedding to GPU
    VkComputeResult result = vkc_upload_buffer(
        sim_ctx->vk_ctx,
        sim_ctx->source_embedding_buffer,
        source_embedding,
        sim_ctx->embedding_dim * sizeof(float)
    );

    if (result != VKC_SUCCESS) {
        fprintf(stderr, "[VKS ERROR] Failed to upload source embedding\n");
        return result;
    }

    // Bind buffers
    result = vkc_bind_buffer(sim_ctx->vk_ctx, sim_ctx->similarity_pipeline, 0, sim_ctx->embeddings_buffer);
    if (result != VKC_SUCCESS) return result;

    result = vkc_bind_buffer(sim_ctx->vk_ctx, sim_ctx->similarity_pipeline, 1, sim_ctx->source_embedding_buffer);
    if (result != VKC_SUCCESS) return result;

    result = vkc_bind_buffer(sim_ctx->vk_ctx, sim_ctx->similarity_pipeline, 2, sim_ctx->similarities_buffer);
    if (result != VKC_SUCCESS) return result;

    // Prepare push constants
    uint32_t push_constants[4] = {
        sim_ctx->num_poems,
        sim_ctx->embedding_dim,
        source_poem_index,
        num_targets
    };

    // Dispatch compute shader with push constants
    uint32_t workgroups_x = (num_targets + 255) / 256; // 256 threads per workgroup
    result = vkc_dispatch(sim_ctx->vk_ctx, sim_ctx->similarity_pipeline,
                           workgroups_x, 1, 1, push_constants);
    if (result != VKC_SUCCESS) {
        fprintf(stderr, "[VKS ERROR] Failed to dispatch similarity shader\n");
        return result;
    }

    // Download results
    result = vkc_download_buffer(sim_ctx->vk_ctx, sim_ctx->similarities_buffer,
                                   output_similarities, num_targets * sizeof(float));
    if (result != VKC_SUCCESS) {
        fprintf(stderr, "[VKS ERROR] Failed to download similarities\n");
        return result;
    }

    return VKC_SUCCESS;
}

/* }}} */

/* {{{ vks_compute_all_similarities - Compute similarities for all poems
 */

VkComputeResult vks_compute_all_similarities(
    VkSimilarityContext* sim_ctx,
    VksSimilarityProgressCallback progress_callback,
    void* user_data) {

    if (!sim_ctx) {
        return VKC_ERROR_COMMAND_EXECUTION_FAILED;
    }

    printf("[VKS] Computing similarities for %u poems...\n", sim_ctx->num_poems);

    for (uint32_t i = 0; i < sim_ctx->num_poems; i++) {
        uint32_t num_targets = sim_ctx->num_poems - i - 1;

        // Skip last poem (no targets)
        if (num_targets == 0) {
            if (progress_callback) {
                progress_callback(i, sim_ctx->num_poems, NULL, 0, user_data);
            }
            continue;
        }

        // Compute similarities for this poem
        VkComputeResult result = vks_compute_similarities_for_poem(
            sim_ctx, i, sim_ctx->similarities_scratch
        );

        if (result != VKC_SUCCESS) {
            fprintf(stderr, "[VKS ERROR] Failed to compute similarities for poem %u\n", i);
            return result;
        }

        // Call progress callback
        if (progress_callback) {
            progress_callback(i, sim_ctx->num_poems,
                              sim_ctx->similarities_scratch,
                              num_targets, user_data);
        }

        // Progress indicator
        if ((i + 1) % 100 == 0) {
            float percent = ((float)(i + 1) / sim_ctx->num_poems) * 100.0f;
            printf("[VKS] Progress: %u/%u (%.1f%%)\n", i + 1, sim_ctx->num_poems, percent);
        }
    }

    printf("[VKS] Completed similarity computation for all poems\n");
    return VKC_SUCCESS;
}

/* }}} */
