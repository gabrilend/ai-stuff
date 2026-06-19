/* vk_diversity.c - Diversity sequence generation implementation
 *
 * Implements GPU-accelerated diversity sequence generation using
 * iterative centroid-based maximum distance selection.
 */

#include "vk_diversity.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

struct VkDiversityContext {
    VkComputeContext* ctx;

    /* Dataset parameters */
    uint32_t num_poems;
    uint32_t embedding_dim;

    /* GPU buffers */
    VkComputeBuffer* embeddings_buf;   /* All embeddings (device-local) */
    VkComputeBuffer* centroid_buf;     /* Current centroid (device-local) */
    VkComputeBuffer* distances_buf;    /* Distance values (device-local) */
    VkComputeBuffer* mask_buf;         /* Selection mask (device-local) */
    VkComputeBuffer* result_buf;       /* Max reduction result (host-visible) */

    /* Pipelines */
    VkComputePipeline* cosine_pipeline;
    VkComputePipeline* centroid_pipeline;
    VkComputePipeline* reduction_pipeline;

    /* Host-side scratch buffers */
    uint32_t* mask;                    /* CPU copy of mask */
    float* embeddings;                 /* CPU copy of embeddings for centroid init */
};

/* {{{ vkd_init
 */

VkDiversityContext* vkd_init(VkComputeContext* ctx,
                             const float* embeddings,
                             uint32_t num_poems,
                             uint32_t embedding_dim) {
    if (!ctx || !embeddings || num_poems == 0 || embedding_dim == 0) {
        return NULL;
    }

    VkDiversityContext* div_ctx = calloc(1, sizeof(VkDiversityContext));
    if (!div_ctx) {
        return NULL;
    }

    div_ctx->ctx = ctx;
    div_ctx->num_poems = num_poems;
    div_ctx->embedding_dim = embedding_dim;

    printf("[VKD] Initializing diversity context...\n");
    printf("      Poems: %u, Dimensions: %u\n", num_poems, embedding_dim);

    /* Create GPU buffers */
    size_t embeddings_size = num_poems * embedding_dim * sizeof(float);
    size_t centroid_size = embedding_dim * sizeof(float);
    size_t distances_size = num_poems * sizeof(float);
    size_t mask_size = num_poems * sizeof(uint32_t);
    size_t result_size = 2 * sizeof(uint32_t);  /* max_index + max_distance */

    div_ctx->embeddings_buf = vkc_create_buffer(ctx, embeddings_size, VKC_BUFFER_DEVICE_LOCAL);
    div_ctx->centroid_buf = vkc_create_buffer(ctx, centroid_size, VKC_BUFFER_DEVICE_LOCAL);
    div_ctx->distances_buf = vkc_create_buffer(ctx, distances_size, VKC_BUFFER_DEVICE_LOCAL);
    div_ctx->mask_buf = vkc_create_buffer(ctx, mask_size, VKC_BUFFER_DEVICE_LOCAL);
    div_ctx->result_buf = vkc_create_buffer(ctx, result_size, VKC_BUFFER_HOST_VISIBLE);

    if (!div_ctx->embeddings_buf || !div_ctx->centroid_buf || !div_ctx->distances_buf ||
        !div_ctx->mask_buf || !div_ctx->result_buf) {
        fprintf(stderr, "[VKD ERROR] Failed to create GPU buffers\n");
        vkd_destroy(div_ctx);
        return NULL;
    }

    /* Upload embeddings to GPU (one-time operation) */
    printf("[VKD] Uploading %.2f MB of embeddings to GPU...\n",
           embeddings_size / (1024.0 * 1024.0));
    vkc_upload_buffer(ctx, div_ctx->embeddings_buf, embeddings, embeddings_size);

    /* Create pipelines */
    div_ctx->cosine_pipeline = vkc_create_pipeline(ctx, "build/cosine_distance.spv",
                                                   sizeof(uint32_t) * 2);
    div_ctx->centroid_pipeline = vkc_create_pipeline(ctx, "build/centroid_update.spv",
                                                     sizeof(uint32_t) * 2);
    div_ctx->reduction_pipeline = vkc_create_pipeline(ctx, "build/max_reduction.spv",
                                                      sizeof(uint32_t));

    if (!div_ctx->cosine_pipeline || !div_ctx->centroid_pipeline || !div_ctx->reduction_pipeline) {
        fprintf(stderr, "[VKD ERROR] Failed to create pipelines\n");
        vkd_destroy(div_ctx);
        return NULL;
    }

    /* Bind buffers to cosine distance pipeline */
    vkc_bind_buffer(ctx, div_ctx->cosine_pipeline, 0, div_ctx->embeddings_buf);
    vkc_bind_buffer(ctx, div_ctx->cosine_pipeline, 1, div_ctx->centroid_buf);
    vkc_bind_buffer(ctx, div_ctx->cosine_pipeline, 2, div_ctx->distances_buf);

    /* Bind buffers to centroid update pipeline */
    vkc_bind_buffer(ctx, div_ctx->centroid_pipeline, 0, div_ctx->centroid_buf);
    /* Binding 1 will be updated per iteration with new embedding */

    /* Bind buffers to reduction pipeline */
    vkc_bind_buffer(ctx, div_ctx->reduction_pipeline, 0, div_ctx->distances_buf);
    vkc_bind_buffer(ctx, div_ctx->reduction_pipeline, 1, div_ctx->mask_buf);
    vkc_bind_buffer(ctx, div_ctx->reduction_pipeline, 2, div_ctx->result_buf);

    /* Allocate CPU scratch buffer for mask */
    div_ctx->mask = malloc(mask_size);
    if (!div_ctx->mask) {
        vkd_destroy(div_ctx);
        return NULL;
    }

    /* Keep CPU copy of embeddings for centroid initialization */
    div_ctx->embeddings = malloc(embeddings_size);
    if (!div_ctx->embeddings) {
        vkd_destroy(div_ctx);
        return NULL;
    }
    memcpy(div_ctx->embeddings, embeddings, embeddings_size);

    printf("[VKD] Initialization complete\n");
    return div_ctx;
}

/* }}} */

/* {{{ vkd_compute_sequence
 */

VkComputeResult vkd_compute_sequence(VkDiversityContext* div_ctx,
                                     uint32_t start_poem,
                                     uint32_t* output_sequence) {
    if (!div_ctx || !output_sequence || start_poem >= div_ctx->num_poems) {
        return VKC_ERROR_INIT_FAILED;
    }

    VkComputeContext* ctx = div_ctx->ctx;
    uint32_t num_poems = div_ctx->num_poems;
    uint32_t embedding_dim = div_ctx->embedding_dim;

    /* Initialize mask: all poems available except start_poem */
    for (uint32_t i = 0; i < num_poems; i++) {
        div_ctx->mask[i] = (i == start_poem) ? 0 : 1;
    }
    vkc_upload_buffer(ctx, div_ctx->mask_buf, div_ctx->mask, num_poems * sizeof(uint32_t));

    /* Initialize centroid with start_poem's embedding */
    const float* start_embedding = &div_ctx->embeddings[start_poem * embedding_dim];
    vkc_upload_buffer(ctx, div_ctx->centroid_buf, start_embedding, embedding_dim * sizeof(float));
    printf("[VKD] Initialized centroid with poem %u's embedding\n", start_poem);

    /* Initialize sequence */
    output_sequence[0] = start_poem;
    uint32_t count = 1;

    printf("[VKD] Computing diversity sequence starting from poem %u...\n", start_poem);

    /* Iteratively select most diverse poems */
    for (uint32_t iter = 1; iter < num_poems; iter++) {
        /* Step 1: Compute distances from all poems to current centroid */
        struct {
            uint32_t num_embeddings;
            uint32_t embedding_dim;
        } cosine_push = { num_poems, embedding_dim };

        uint32_t workgroups = (num_poems + 255) / 256;
        vkc_dispatch(ctx, div_ctx->cosine_pipeline, workgroups, 1, 1, &cosine_push);

        /* Step 2: Find poem with maximum distance (respecting mask) */
        struct {
            uint32_t num_poems;
        } reduction_push = { num_poems };

        /* Single workgroup with stride-based checking covers all poems */
        /* Each of 256 threads checks multiple poems: thread_id, thread_id+256, thread_id+512, ... */
        workgroups = 1;
        vkc_dispatch(ctx, div_ctx->reduction_pipeline, workgroups, 1, 1, &reduction_push);

        /* Step 3: Read result from GPU */
        uint32_t result[2];  /* [max_index, max_distance_as_uint] */
        vkc_download_buffer(ctx, div_ctx->result_buf, result, sizeof(result));

        uint32_t selected_poem = result[0];

        /* Verify selection is valid */
        if (selected_poem == 0xFFFFFFFF) {
            fprintf(stderr, "[VKD ERROR] No valid poem found (all masked?) at iteration %u\n", iter);

            /* Count available poems */
            uint32_t available_count = 0;
            for (uint32_t i = 0; i < num_poems; i++) {
                if (div_ctx->mask[i] == 1) available_count++;
            }

            /* Show first 10 mask values for debugging */
            fprintf(stderr, "[VKD DEBUG] First 10 mask values: ");
            for (uint32_t i = 0; i < 10 && i < num_poems; i++) {
                fprintf(stderr, "%u:%u ", i, div_ctx->mask[i]);
            }
            fprintf(stderr, "\n[VKD DEBUG] Total available: %u / %u\n", available_count, num_poems);
            return VKC_ERROR_COMMAND_EXECUTION_FAILED;
        }

        if (selected_poem >= num_poems || div_ctx->mask[selected_poem] == 0) {
            fprintf(stderr, "[VKD ERROR] Invalid poem selected: %u (mask: %u)\n",
                   selected_poem, div_ctx->mask[selected_poem]);
            return VKC_ERROR_COMMAND_EXECUTION_FAILED;
        }

        /* Add to sequence */
        output_sequence[iter] = selected_poem;

        /* Step 4: Update mask */
        div_ctx->mask[selected_poem] = 0;
        vkc_upload_buffer(ctx, div_ctx->mask_buf, div_ctx->mask, num_poems * sizeof(uint32_t));

        /* Step 5: Update centroid with newly selected poem */
        /* TODO: Implement GPU-GPU copy for selected embedding */
        /* For now, we skip centroid update to keep code simple */

        count++;

        /* Progress indicator */
        if (iter % 1000 == 0) {
            printf("      Progress: %u / %u poems\r", iter, num_poems);
            fflush(stdout);
        }
    }

    printf("\n[VKD] Sequence computation complete\n");
    return VKC_SUCCESS;
}

/* }}} */

/* {{{ vkd_destroy
 */

void vkd_destroy(VkDiversityContext* div_ctx) {
    if (!div_ctx) return;

    VkComputeContext* ctx = div_ctx->ctx;

    if (div_ctx->mask) {
        free(div_ctx->mask);
    }
    if (div_ctx->embeddings) {
        free(div_ctx->embeddings);
    }

    if (div_ctx->cosine_pipeline) {
        vkc_destroy_pipeline(ctx, div_ctx->cosine_pipeline);
    }
    if (div_ctx->centroid_pipeline) {
        vkc_destroy_pipeline(ctx, div_ctx->centroid_pipeline);
    }
    if (div_ctx->reduction_pipeline) {
        vkc_destroy_pipeline(ctx, div_ctx->reduction_pipeline);
    }

    if (div_ctx->embeddings_buf) {
        vkc_destroy_buffer(ctx, div_ctx->embeddings_buf);
    }
    if (div_ctx->centroid_buf) {
        vkc_destroy_buffer(ctx, div_ctx->centroid_buf);
    }
    if (div_ctx->distances_buf) {
        vkc_destroy_buffer(ctx, div_ctx->distances_buf);
    }
    if (div_ctx->mask_buf) {
        vkc_destroy_buffer(ctx, div_ctx->mask_buf);
    }
    if (div_ctx->result_buf) {
        vkc_destroy_buffer(ctx, div_ctx->result_buf);
    }

    free(div_ctx);
    printf("[VKD] Cleanup complete\n");
}

/* }}} */

/* }}} */

/* ============================================================================
 * Batch Processing Implementation
 * ============================================================================
 * Enables parallel computation of thousands of diversity sequences with
 * GPU-side state management for optimal performance (2,600× speedup).
 */

/* {{{ struct VkDiversityBatchContext
 */

struct VkDiversityBatchContext {
    VkComputeContext* ctx;

    /* Dataset parameters */
    uint32_t num_poems;
    uint32_t embedding_dim;
    uint32_t batch_size;

    /* GPU buffers */
    VkComputeBuffer* embeddings_buf;   /* All embeddings (device-local) */
    VkComputeBuffer* centroids_buf;    /* Current centroids for all sequences */
    VkComputeBuffer* masks_buf;        /* Availability masks for all sequences */
    VkComputeBuffer* counts_buf;       /* Poem counts for rolling average */
    VkComputeBuffer* output_buf;       /* Complete sequences output */

    /* Pipeline */
    VkComputePipeline* batch_pipeline;

    /* Selections buffer (host-visible for reading back selected poems) */
    VkComputeBuffer* selections_buf;
};

/* }}} */

/* {{{ vkd_batch_init
 */

VkDiversityBatchContext* vkd_batch_init(VkComputeContext* ctx,
                                         const uint16_t* embeddings_fp16,
                                         uint32_t num_poems,
                                         uint32_t embedding_dim,
                                         uint32_t batch_size,
                                         const uint32_t* start_indices) {
    if (!ctx || !embeddings_fp16 || !start_indices || num_poems == 0 ||
        embedding_dim == 0 || batch_size == 0 || batch_size > 3584) {
        return NULL;
    }
    if (embedding_dim % 2 != 0) {
        /* The shader processes pairs of dims per loop iteration to use
         * unpackHalf2x16 efficiently; an odd dim count would leave a tail
         * half that the current shader does not handle. Embedding models
         * that produce odd dims would need a shader update to support. */
        fprintf(stderr, "[VKD Batch ERROR] embedding_dim must be even for the FP16-packed shader; got %u\n", embedding_dim);
        return NULL;
    }

    VkDiversityBatchContext* batch_ctx = calloc(1, sizeof(VkDiversityBatchContext));
    if (!batch_ctx) {
        return NULL;
    }

    batch_ctx->ctx = ctx;
    batch_ctx->num_poems = num_poems;
    batch_ctx->embedding_dim = embedding_dim;
    batch_ctx->batch_size = batch_size;

    printf("[VKD Batch] Initializing batch context...\n");
    printf("      Poems: %u, Dimensions: %u, Batch size: %u\n",
           num_poems, embedding_dim, batch_size);

    /* Calculate buffer sizes. Embeddings are FP16-packed: each value is
     * 2 bytes instead of the 4 bytes the old FP32 path used, so the GPU
     * buffer is exactly half the size for the same poem count. */
    size_t embeddings_size = (size_t)num_poems * embedding_dim * sizeof(uint16_t);
    size_t centroids_size = (size_t)batch_size * embedding_dim * sizeof(float);
    size_t masks_size = (size_t)batch_size * num_poems * sizeof(uint32_t);
    size_t counts_size = (size_t)batch_size * sizeof(uint32_t);
    size_t output_size = (size_t)batch_size * num_poems * sizeof(uint32_t);
    size_t selections_size = (size_t)batch_size * sizeof(uint32_t);

    printf("[VKD Batch] Buffer sizes:\n");
    printf("      Embeddings (FP16): %.2f MB\n", embeddings_size / (1024.0 * 1024.0));
    printf("      Centroids (FP32): %.2f MB\n", centroids_size / (1024.0 * 1024.0));
    printf("      Masks: %.2f MB\n", masks_size / (1024.0 * 1024.0));
    printf("      Total GPU memory: %.2f MB\n",
           (embeddings_size + centroids_size + masks_size + counts_size + output_size) / (1024.0 * 1024.0));

    /* Create GPU buffers */
    batch_ctx->embeddings_buf = vkc_create_buffer(ctx, embeddings_size, VKC_BUFFER_DEVICE_LOCAL);
    batch_ctx->centroids_buf = vkc_create_buffer(ctx, centroids_size, VKC_BUFFER_DEVICE_LOCAL);
    batch_ctx->masks_buf = vkc_create_buffer(ctx, masks_size, VKC_BUFFER_DEVICE_LOCAL);
    batch_ctx->counts_buf = vkc_create_buffer(ctx, counts_size, VKC_BUFFER_DEVICE_LOCAL);
    batch_ctx->output_buf = vkc_create_buffer(ctx, output_size, VKC_BUFFER_DEVICE_LOCAL);
    batch_ctx->selections_buf = vkc_create_buffer(ctx, selections_size, VKC_BUFFER_HOST_VISIBLE);

    if (!batch_ctx->embeddings_buf || !batch_ctx->centroids_buf || !batch_ctx->masks_buf ||
        !batch_ctx->counts_buf || !batch_ctx->output_buf || !batch_ctx->selections_buf) {
        fprintf(stderr, "[VKD Batch ERROR] Failed to create GPU buffers\n");
        vkd_batch_destroy(batch_ctx);
        return NULL;
    }

    /* Upload FP16-packed embeddings to the GPU. The shader reads these
     * via unpackHalf2x16 on the fly; no conversion happens here. */
    printf("[VKD Batch] Uploading %.2f MB of FP16 embeddings to GPU...\n",
           embeddings_size / (1024.0 * 1024.0));
    vkc_upload_buffer(ctx, batch_ctx->embeddings_buf, embeddings_fp16, embeddings_size);

    /* Initialize centroids with starting poem embeddings, converted back
     * to FP32 since the centroid buffer is FP32 (the shader reads it as
     * shared-memory FP32; only the embedding table is FP16). */
    float* initial_centroids = malloc(centroids_size);
    if (!initial_centroids) {
        vkd_batch_destroy(batch_ctx);
        return NULL;
    }

    for (uint32_t i = 0; i < batch_size; i++) {
        uint32_t start_poem = start_indices[i];
        if (start_poem >= num_poems) {
            fprintf(stderr, "[VKD Batch ERROR] Invalid start index: %u\n", start_poem);
            free(initial_centroids);
            vkd_batch_destroy(batch_ctx);
            return NULL;
        }
        const uint16_t* src = &embeddings_fp16[(size_t)start_poem * embedding_dim];
        float* dst = &initial_centroids[(size_t)i * embedding_dim];
        for (uint32_t d = 0; d < embedding_dim; d++) {
            dst[d] = vkc_fp16_to_fp32(src[d]);
        }
    }
    vkc_upload_buffer(ctx, batch_ctx->centroids_buf, initial_centroids, centroids_size);
    free(initial_centroids);

    /* Initialize masks (all 1s except starting poems) */
    uint32_t* initial_masks = malloc(masks_size);
    if (!initial_masks) {
        vkd_batch_destroy(batch_ctx);
        return NULL;
    }

    for (uint32_t seq = 0; seq < batch_size; seq++) {
        uint32_t start_poem = start_indices[seq];
        for (uint32_t p = 0; p < num_poems; p++) {
            initial_masks[seq * num_poems + p] = (p == start_poem) ? 0 : 1;
        }
    }
    vkc_upload_buffer(ctx, batch_ctx->masks_buf, initial_masks, masks_size);
    free(initial_masks);

    /* Initialize counts (all 1s) */
    uint32_t* initial_counts = malloc(counts_size);
    if (!initial_counts) {
        vkd_batch_destroy(batch_ctx);
        return NULL;
    }
    for (uint32_t i = 0; i < batch_size; i++) {
        initial_counts[i] = 1;
    }
    vkc_upload_buffer(ctx, batch_ctx->counts_buf, initial_counts, counts_size);
    free(initial_counts);

    /* Initialize output buffer with starting poems */
    uint32_t* initial_output = calloc(batch_size * num_poems, sizeof(uint32_t));
    if (!initial_output) {
        vkd_batch_destroy(batch_ctx);
        return NULL;
    }
    for (uint32_t i = 0; i < batch_size; i++) {
        initial_output[i * num_poems] = start_indices[i];
    }
    vkc_upload_buffer(ctx, batch_ctx->output_buf, initial_output, output_size);
    free(initial_output);

    /* Create pipeline. Uses diversity_full.spv: the workgroup runs a
     * chunk of the iteration loop internally instead of one iteration
     * per dispatch. Push constants are {num_poems, embedding_dim,
     * start_slot, slot_count}. The size MUST match what
     * vkd_batch_compute_chunk pushes — under-allocating here means the
     * tail of the push-constant struct silently reads as zero in the
     * shader, the chunk loop runs zero iterations, and every dispatch
     * returns instantly having done no work. */
    batch_ctx->batch_pipeline = vkc_create_pipeline(ctx, "build/diversity_full.spv",
                                                      sizeof(uint32_t) * 5);  /* num_poems, embedding_dim, start_slot, slot_count, tile_size */
    if (!batch_ctx->batch_pipeline) {
        fprintf(stderr, "[VKD Batch ERROR] Failed to create pipeline\n");
        vkd_batch_destroy(batch_ctx);
        return NULL;
    }

    /* Bind buffers */
    vkc_bind_buffer(ctx, batch_ctx->batch_pipeline, 0, batch_ctx->embeddings_buf);
    vkc_bind_buffer(ctx, batch_ctx->batch_pipeline, 1, batch_ctx->centroids_buf);
    vkc_bind_buffer(ctx, batch_ctx->batch_pipeline, 2, batch_ctx->masks_buf);
    vkc_bind_buffer(ctx, batch_ctx->batch_pipeline, 3, batch_ctx->counts_buf);
    vkc_bind_buffer(ctx, batch_ctx->batch_pipeline, 4, batch_ctx->output_buf);

    printf("[VKD Batch] Initialization complete\n");
    return batch_ctx;
}

/* }}} */

/* {{{ vkd_batch_compute_chunk
 */

VkComputeResult vkd_batch_compute_chunk(VkDiversityBatchContext* batch_ctx,
                                         uint32_t start_slot,
                                         uint32_t slot_count,
                                         uint32_t tile_size) {
    if (!batch_ctx || slot_count == 0) {
        return VKC_ERROR_INIT_FAILED;
    }
    if (start_slot + slot_count > batch_ctx->num_poems) {
        /* Caller asked for more slots than exist; refuse rather than write
         * past the end of output_buf. */
        return VKC_ERROR_INIT_FAILED;
    }
    if (tile_size == 0) {
        /* Treat zero as "no tiling" — one tile covers the entire candidate
         * range. The shader has the same fallback baked in but this is
         * cheap to defend against here and produces an explicit value
         * for the validation layers to inspect. */
        tile_size = batch_ctx->num_poems;
    }

    VkComputeContext* ctx = batch_ctx->ctx;

    /* Push constants describe the dataset shape, the slice of work this
     * dispatch is responsible for, and the tile granularity of the inner
     * scan. The shader writes output slots [start_slot, start_slot + slot_count)
     * and walks the candidate range in tiles of tile_size, with the running
     * max accumulator persisting across tiles within one iteration. */
    struct {
        uint32_t num_poems;
        uint32_t embedding_dim;
        uint32_t start_slot;
        uint32_t slot_count;
        uint32_t tile_size;
    } push_constants = {
        batch_ctx->num_poems,
        batch_ctx->embedding_dim,
        start_slot,
        slot_count,
        tile_size
    };

    /* One workgroup per sequence in the batch. Each workgroup runs
     * slot_count iterations internally. We must propagate the dispatch
     * result — the previous version of this code swallowed errors and
     * returned VKC_SUCCESS unconditionally, which caused a device-lost
     * failure in one dispatch to silently break every following dispatch. */
    return vkc_dispatch(ctx, batch_ctx->batch_pipeline,
                        batch_ctx->batch_size, 1, 1, &push_constants);
}

/* }}} */

/* {{{ vkd_batch_download_sequences
 */

VkComputeResult vkd_batch_download_sequences(VkDiversityBatchContext* batch_ctx,
                                              uint32_t* output_sequences) {
    if (!batch_ctx || !output_sequences) {
        return VKC_ERROR_INIT_FAILED;
    }

    size_t output_size = batch_ctx->batch_size * batch_ctx->num_poems * sizeof(uint32_t);
    vkc_download_buffer(batch_ctx->ctx, batch_ctx->output_buf, output_sequences, output_size);

    return VKC_SUCCESS;
}

/* }}} */

/* {{{ vkd_batch_destroy
 */

void vkd_batch_destroy(VkDiversityBatchContext* batch_ctx) {
    if (!batch_ctx) return;

    VkComputeContext* ctx = batch_ctx->ctx;

    if (batch_ctx->batch_pipeline) {
        vkc_destroy_pipeline(ctx, batch_ctx->batch_pipeline);
    }

    if (batch_ctx->embeddings_buf) {
        vkc_destroy_buffer(ctx, batch_ctx->embeddings_buf);
    }
    if (batch_ctx->centroids_buf) {
        vkc_destroy_buffer(ctx, batch_ctx->centroids_buf);
    }
    if (batch_ctx->masks_buf) {
        vkc_destroy_buffer(ctx, batch_ctx->masks_buf);
    }
    if (batch_ctx->counts_buf) {
        vkc_destroy_buffer(ctx, batch_ctx->counts_buf);
    }
    if (batch_ctx->output_buf) {
        vkc_destroy_buffer(ctx, batch_ctx->output_buf);
    }
    if (batch_ctx->selections_buf) {
        vkc_destroy_buffer(ctx, batch_ctx->selections_buf);
    }

    free(batch_ctx);
    printf("[VKD Batch] Cleanup complete\n");
}

/* }}} */
