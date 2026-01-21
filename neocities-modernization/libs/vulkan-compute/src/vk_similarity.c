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
#include <pthread.h>
#include <stdatomic.h>
#include <time.h>

/* {{{ Internal structures
 */

struct VkSimilarityContext {
    VkComputeContext* vk_ctx;

    // Buffers
    VkComputeBuffer* embeddings_buffer;      // All embeddings (GPU)
    VkComputeBuffer* source_embedding_buffer; // Current source embedding (GPU) - sequential mode
    VkComputeBuffer* similarities_buffer;     // Output similarities (GPU) - sequential mode
    VkComputeBuffer* full_similarities_buffer; // Full triangular output (GPU) - parallel mode

    // Pipelines
    VkComputePipeline* similarity_pipeline;      // Sequential per-poem shader
    VkComputePipeline* similarity_full_pipeline; // Parallel full-matrix shader

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

    if (sim_ctx->similarity_full_pipeline) {
        vkc_destroy_pipeline(sim_ctx->vk_ctx, sim_ctx->similarity_full_pipeline);
    }

    if (sim_ctx->similarities_buffer) {
        vkc_destroy_buffer(sim_ctx->vk_ctx, sim_ctx->similarities_buffer);
    }

    if (sim_ctx->full_similarities_buffer) {
        vkc_destroy_buffer(sim_ctx->vk_ctx, sim_ctx->full_similarities_buffer);
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

/* {{{ vks_compute_all_similarities_parallel - Compute ALL similarities in single dispatch
 *
 * This is the correct implementation per Issue 9-002 original design.
 * Uses 2D workgroups to compute all ~30M pairs in parallel.
 */

VkComputeResult vks_compute_all_similarities_parallel(
    VkSimilarityContext* sim_ctx,
    float* output_triangular) {

    if (!sim_ctx || !output_triangular) {
        return VKC_ERROR_COMMAND_EXECUTION_FAILED;
    }

    uint32_t num_poems = sim_ctx->num_poems;
    uint64_t triangular_size = ((uint64_t)num_poems * (num_poems - 1)) / 2;
    size_t buffer_size = triangular_size * sizeof(float);

    printf("[VKS PARALLEL] Computing ALL similarities in single dispatch\n");
    printf("[VKS PARALLEL] Poems: %u, Pairs: %lu (%.1f MB)\n",
           num_poems, (unsigned long)triangular_size, buffer_size / (1024.0 * 1024.0));

    // Lazy-load the parallel shader if not already loaded
    if (!sim_ctx->similarity_full_pipeline) {
        printf("[VKS PARALLEL] Loading parallel similarity shader...\n");
        sim_ctx->similarity_full_pipeline = vkc_create_pipeline(
            sim_ctx->vk_ctx,
            "libs/vulkan-compute/build/similarity_full.spv",
            sizeof(uint32_t) * 2  // Push constants: num_poems, embedding_dim
        );

        if (!sim_ctx->similarity_full_pipeline) {
            fprintf(stderr, "[VKS ERROR] Failed to load parallel similarity shader\n");
            return VKC_ERROR_SHADER_LOAD_FAILED;
        }
    }

    // Lazy-create the full output buffer if not already created
    if (!sim_ctx->full_similarities_buffer) {
        printf("[VKS PARALLEL] Allocating GPU output buffer (%.1f MB)...\n",
               buffer_size / (1024.0 * 1024.0));
        sim_ctx->full_similarities_buffer = vkc_create_buffer(
            sim_ctx->vk_ctx, buffer_size, VKC_BUFFER_DEVICE_LOCAL
        );

        if (!sim_ctx->full_similarities_buffer) {
            fprintf(stderr, "[VKS ERROR] Failed to create full similarities buffer\n");
            return VKC_ERROR_BUFFER_CREATION_FAILED;
        }
    }

    // Bind buffers to pipeline
    VkComputeResult result;

    result = vkc_bind_buffer(sim_ctx->vk_ctx, sim_ctx->similarity_full_pipeline,
                              0, sim_ctx->embeddings_buffer);
    if (result != VKC_SUCCESS) {
        fprintf(stderr, "[VKS ERROR] Failed to bind embeddings buffer\n");
        return result;
    }

    result = vkc_bind_buffer(sim_ctx->vk_ctx, sim_ctx->similarity_full_pipeline,
                              1, sim_ctx->full_similarities_buffer);
    if (result != VKC_SUCCESS) {
        fprintf(stderr, "[VKS ERROR] Failed to bind output buffer\n");
        return result;
    }

    // Prepare push constants
    uint32_t push_constants[2] = {
        num_poems,
        sim_ctx->embedding_dim
    };

    // Calculate workgroup dispatch size
    // Shader uses local_size_x=16, local_size_y=16
    // Need to cover num_poems × num_poems grid (upper triangle computed)
    uint32_t workgroups_x = (num_poems + 15) / 16;
    uint32_t workgroups_y = (num_poems + 15) / 16;

    printf("[VKS PARALLEL] Dispatching %u × %u = %u workgroups (256 threads each)\n",
           workgroups_x, workgroups_y, workgroups_x * workgroups_y);

    // Single dispatch for ALL pairs!
    result = vkc_dispatch(sim_ctx->vk_ctx, sim_ctx->similarity_full_pipeline,
                           workgroups_x, workgroups_y, 1, push_constants);
    if (result != VKC_SUCCESS) {
        fprintf(stderr, "[VKS ERROR] Failed to dispatch parallel similarity shader\n");
        return result;
    }

    printf("[VKS PARALLEL] GPU computation complete, downloading results...\n");

    // Download all results at once
    result = vkc_download_buffer(sim_ctx->vk_ctx, sim_ctx->full_similarities_buffer,
                                   output_triangular, buffer_size);
    if (result != VKC_SUCCESS) {
        fprintf(stderr, "[VKS ERROR] Failed to download similarity results\n");
        return result;
    }

    printf("[VKS PARALLEL] Download complete (%.1f MB)\n", buffer_size / (1024.0 * 1024.0));

    return VKC_SUCCESS;
}

/* }}} */

/* {{{ Parallel file I/O structures and helpers
 */

// Similarity pair for sorting
typedef struct {
    uint32_t target_index;  // poem_index of target
    float similarity;
} SimilarityPair;

// Thread context for parallel file writing
typedef struct {
    // Shared (read-only after init)
    const float* triangular_buffer;
    uint32_t num_poems;
    const uint32_t* poem_indices;
    const char** poem_ids;
    const char* output_dir;

    // Atomic task counter (shared, written atomically)
    atomic_uint* next_task;

    // Per-thread statistics
    uint32_t files_written;
    uint32_t thread_id;
} FileWriterContext;

// Comparison function for qsort (descending by similarity)
static int compare_similarity_desc(const void* a, const void* b) {
    const SimilarityPair* pa = (const SimilarityPair*)a;
    const SimilarityPair* pb = (const SimilarityPair*)b;

    // Descending order (higher similarity first)
    if (pa->similarity > pb->similarity) return -1;
    if (pa->similarity < pb->similarity) return 1;
    return 0;
}

/* }}} */

/* {{{ write_similarity_file - Write JSON file for one poem
 */

static int write_similarity_file(
    const float* triangular_buffer,
    uint32_t num_poems,
    const uint32_t* poem_indices,
    const char** poem_ids,
    const char* output_dir,
    uint32_t array_index) {

    uint32_t poem_index = poem_indices[array_index];
    const char* poem_id = poem_ids[array_index];

    // Calculate number of similarities for this poem
    // For array_index i, we need similarities to all j where j > i (upper triangle)
    // Plus we need to include similarities FROM earlier poems TO this one (lower triangle)
    // Total: (num_poems - 1) similarities per poem

    uint32_t total_sims = num_poems - 1;
    if (total_sims == 0) {
        // Single poem, create empty file
        char filepath[512];
        snprintf(filepath, sizeof(filepath), "%s/poem_index_%u.json", output_dir, poem_index);

        FILE* f = fopen(filepath, "w");
        if (!f) {
            fprintf(stderr, "[VKS FILE ERROR] Failed to open: %s\n", filepath);
            return -1;
        }

        fprintf(f, "{\n");
        fprintf(f, "  \"metadata\": {\n");
        fprintf(f, "    \"poem_id\": \"%s\",\n", poem_id);
        fprintf(f, "    \"poem_index\": %u,\n", poem_index);
        fprintf(f, "    \"total_comparisons\": 0,\n");
        fprintf(f, "    \"format\": \"triangular_upper\",\n");
        fprintf(f, "    \"method\": \"gpu_vulkan_parallel_c\"\n");
        fprintf(f, "  },\n");
        fprintf(f, "  \"similarities\": [],\n");
        fprintf(f, "  \"sorted_indices\": []\n");
        fprintf(f, "}\n");

        fclose(f);
        return 0;
    }

    // Allocate pairs array
    SimilarityPair* pairs = (SimilarityPair*)malloc(total_sims * sizeof(SimilarityPair));
    if (!pairs) {
        fprintf(stderr, "[VKS FILE ERROR] Failed to allocate pairs array\n");
        return -1;
    }

    uint32_t pair_count = 0;
    uint32_t i = array_index;

    // Extract similarities from triangular buffer
    // For each other poem j:
    //   If i < j: sim(i,j) is at triangular_index(i, j)
    //   If i > j: sim(i,j) = sim(j,i) at triangular_index(j, i)
    for (uint32_t j = 0; j < num_poems; j++) {
        if (j == i) continue;  // Skip self

        uint64_t tri_idx;
        if (i < j) {
            tri_idx = vks_triangular_index(i, j, num_poems);
        } else {
            tri_idx = vks_triangular_index(j, i, num_poems);
        }

        pairs[pair_count].target_index = poem_indices[j];
        pairs[pair_count].similarity = triangular_buffer[tri_idx];
        pair_count++;
    }

    // Sort by similarity (descending)
    qsort(pairs, pair_count, sizeof(SimilarityPair), compare_similarity_desc);

    // Write JSON file
    char filepath[512];
    snprintf(filepath, sizeof(filepath), "%s/poem_index_%u.json", output_dir, poem_index);

    FILE* f = fopen(filepath, "w");
    if (!f) {
        fprintf(stderr, "[VKS FILE ERROR] Failed to open: %s\n", filepath);
        free(pairs);
        return -1;
    }

    // Write header
    fprintf(f, "{\n");
    fprintf(f, "  \"metadata\": {\n");
    fprintf(f, "    \"poem_id\": \"%s\",\n", poem_id);
    fprintf(f, "    \"poem_index\": %u,\n", poem_index);
    fprintf(f, "    \"total_comparisons\": %u,\n", pair_count);
    fprintf(f, "    \"format\": \"full_bidirectional\",\n");
    fprintf(f, "    \"method\": \"gpu_vulkan_parallel_c\"\n");
    fprintf(f, "  },\n");

    // Write similarities array
    fprintf(f, "  \"similarities\": [\n");
    for (uint32_t k = 0; k < pair_count; k++) {
        fprintf(f, "    {\"id\": \"%u\", \"similarity\": %.8f}%s\n",
                pairs[k].target_index,
                pairs[k].similarity,
                k < pair_count - 1 ? "," : "");
    }
    fprintf(f, "  ],\n");

    // Write sorted_indices array
    fprintf(f, "  \"sorted_indices\": [");
    for (uint32_t k = 0; k < pair_count; k++) {
        fprintf(f, "%u%s", pairs[k].target_index, k < pair_count - 1 ? ", " : "");
    }
    fprintf(f, "]\n");

    fprintf(f, "}\n");

    fclose(f);
    free(pairs);

    return 0;
}

/* }}} */

/* {{{ file_writer_thread - Worker thread function
 */

static void* file_writer_thread(void* arg) {
    FileWriterContext* ctx = (FileWriterContext*)arg;

    while (1) {
        // Atomically get next task
        uint32_t task_idx = atomic_fetch_add(ctx->next_task, 1);

        // Check if we're done
        if (task_idx >= ctx->num_poems) {
            break;
        }

        // Write file for this poem
        int result = write_similarity_file(
            ctx->triangular_buffer,
            ctx->num_poems,
            ctx->poem_indices,
            ctx->poem_ids,
            ctx->output_dir,
            task_idx
        );

        if (result == 0) {
            ctx->files_written++;
        }
    }

    return NULL;
}

/* }}} */

/* {{{ vks_write_similarity_files_parallel - Main parallel writer function
 */

VkComputeResult vks_write_similarity_files_parallel(
    const float* triangular_buffer,
    uint32_t num_poems,
    const uint32_t* poem_indices,
    const char** poem_ids,
    const char* output_dir,
    uint32_t num_threads) {

    if (!triangular_buffer || !poem_indices || !poem_ids || !output_dir) {
        fprintf(stderr, "[VKS FILE ERROR] Invalid parameters\n");
        return VKC_ERROR_COMMAND_EXECUTION_FAILED;
    }

    // Clamp thread count
    if (num_threads < 1) num_threads = 1;
    if (num_threads > 64) num_threads = 64;

    printf("[VKS FILE] Writing %u similarity files with %u threads...\n", num_poems, num_threads);

    time_t start_time = time(NULL);

    // Create atomic task counter
    atomic_uint next_task = ATOMIC_VAR_INIT(0);

    // Allocate thread contexts
    FileWriterContext* contexts = (FileWriterContext*)calloc(num_threads, sizeof(FileWriterContext));
    pthread_t* threads = (pthread_t*)malloc(num_threads * sizeof(pthread_t));

    if (!contexts || !threads) {
        fprintf(stderr, "[VKS FILE ERROR] Failed to allocate thread resources\n");
        free(contexts);
        free(threads);
        return VKC_ERROR_OUT_OF_MEMORY;
    }

    // Initialize contexts and spawn threads
    for (uint32_t t = 0; t < num_threads; t++) {
        contexts[t].triangular_buffer = triangular_buffer;
        contexts[t].num_poems = num_poems;
        contexts[t].poem_indices = poem_indices;
        contexts[t].poem_ids = poem_ids;
        contexts[t].output_dir = output_dir;
        contexts[t].next_task = &next_task;
        contexts[t].files_written = 0;
        contexts[t].thread_id = t;

        int rc = pthread_create(&threads[t], NULL, file_writer_thread, &contexts[t]);
        if (rc != 0) {
            fprintf(stderr, "[VKS FILE ERROR] Failed to create thread %u: %d\n", t, rc);
            // Wait for already-created threads
            for (uint32_t i = 0; i < t; i++) {
                pthread_join(threads[i], NULL);
            }
            free(contexts);
            free(threads);
            return VKC_ERROR_COMMAND_EXECUTION_FAILED;
        }
    }

    // Wait for all threads to complete
    uint32_t total_written = 0;
    for (uint32_t t = 0; t < num_threads; t++) {
        pthread_join(threads[t], NULL);
        total_written += contexts[t].files_written;
        printf("[VKS FILE] Thread %u wrote %u files\n", t, contexts[t].files_written);
    }

    time_t end_time = time(NULL);
    double elapsed = difftime(end_time, start_time);
    double rate = elapsed > 0 ? total_written / elapsed : total_written;

    printf("[VKS FILE] ✅ Wrote %u files in %.0f seconds (%.1f files/sec)\n",
           total_written, elapsed, rate);

    free(contexts);
    free(threads);

    return VKC_SUCCESS;
}

/* }}} */

/* {{{ Cache generation structures
 */

// Per-poem sorted rankings (result of sorting)
typedef struct {
    uint32_t* sorted_indices;  // Array of poem_indices sorted by similarity
    uint32_t count;            // Number of entries (num_poems - 1)
} PoemRankings;

// Thread context for cache generation
typedef struct {
    // Shared (read-only)
    const float* triangular_buffer;
    uint32_t num_poems;
    const uint32_t* poem_indices;

    // Shared output (written by threads, each to its own slot)
    PoemRankings* all_rankings;

    // Atomic task counter
    atomic_uint* next_task;

    // Per-thread stats
    uint32_t poems_sorted;
    uint32_t thread_id;
} CacheGenContext;

/* }}} */

/* {{{ cache_gen_thread - Worker thread for cache generation
 */

static void* cache_gen_thread(void* arg) {
    CacheGenContext* ctx = (CacheGenContext*)arg;

    uint32_t total_sims = ctx->num_poems - 1;

    // Allocate thread-local pairs array (reused for each poem)
    SimilarityPair* pairs = (SimilarityPair*)malloc(total_sims * sizeof(SimilarityPair));
    if (!pairs) {
        fprintf(stderr, "[VKS CACHE ERROR] Thread %u failed to allocate pairs\n", ctx->thread_id);
        return NULL;
    }

    while (1) {
        // Atomically get next task (array index to process)
        uint32_t array_idx = atomic_fetch_add(ctx->next_task, 1);

        if (array_idx >= ctx->num_poems) {
            break;
        }

        // Extract and sort similarities for this poem
        uint32_t pair_count = 0;

        for (uint32_t j = 0; j < ctx->num_poems; j++) {
            if (j == array_idx) continue;

            uint64_t tri_idx;
            if (array_idx < j) {
                tri_idx = vks_triangular_index(array_idx, j, ctx->num_poems);
            } else {
                tri_idx = vks_triangular_index(j, array_idx, ctx->num_poems);
            }

            pairs[pair_count].target_index = ctx->poem_indices[j];
            pairs[pair_count].similarity = ctx->triangular_buffer[tri_idx];
            pair_count++;
        }

        // Sort by similarity (descending)
        qsort(pairs, pair_count, sizeof(SimilarityPair), compare_similarity_desc);

        // Allocate and fill sorted indices for this poem
        ctx->all_rankings[array_idx].sorted_indices = (uint32_t*)malloc(pair_count * sizeof(uint32_t));
        ctx->all_rankings[array_idx].count = pair_count;

        if (ctx->all_rankings[array_idx].sorted_indices) {
            for (uint32_t k = 0; k < pair_count; k++) {
                ctx->all_rankings[array_idx].sorted_indices[k] = pairs[k].target_index;
            }
            ctx->poems_sorted++;
        }
    }

    free(pairs);
    return NULL;
}

/* }}} */

/* {{{ vks_write_rankings_cache_parallel - Generate cache file with parallel sorting
 */

VkComputeResult vks_write_rankings_cache_parallel(
    const float* triangular_buffer,
    uint32_t num_poems,
    const uint32_t* poem_indices,
    const char* cache_file,
    uint32_t num_threads) {

    if (!triangular_buffer || !poem_indices || !cache_file) {
        fprintf(stderr, "[VKS CACHE ERROR] Invalid parameters\n");
        return VKC_ERROR_COMMAND_EXECUTION_FAILED;
    }

    if (num_threads < 1) num_threads = 1;
    if (num_threads > 64) num_threads = 64;

    printf("[VKS CACHE] Generating rankings cache with %u threads...\n", num_threads);
    time_t start_time = time(NULL);

    // Allocate rankings array (one entry per poem)
    PoemRankings* all_rankings = (PoemRankings*)calloc(num_poems, sizeof(PoemRankings));
    if (!all_rankings) {
        fprintf(stderr, "[VKS CACHE ERROR] Failed to allocate rankings array\n");
        return VKC_ERROR_OUT_OF_MEMORY;
    }

    // Create atomic task counter
    atomic_uint next_task = ATOMIC_VAR_INIT(0);

    // Allocate thread contexts
    CacheGenContext* contexts = (CacheGenContext*)calloc(num_threads, sizeof(CacheGenContext));
    pthread_t* threads = (pthread_t*)malloc(num_threads * sizeof(pthread_t));

    if (!contexts || !threads) {
        fprintf(stderr, "[VKS CACHE ERROR] Failed to allocate thread resources\n");
        free(all_rankings);
        free(contexts);
        free(threads);
        return VKC_ERROR_OUT_OF_MEMORY;
    }

    // Initialize and spawn threads
    for (uint32_t t = 0; t < num_threads; t++) {
        contexts[t].triangular_buffer = triangular_buffer;
        contexts[t].num_poems = num_poems;
        contexts[t].poem_indices = poem_indices;
        contexts[t].all_rankings = all_rankings;
        contexts[t].next_task = &next_task;
        contexts[t].poems_sorted = 0;
        contexts[t].thread_id = t;

        int rc = pthread_create(&threads[t], NULL, cache_gen_thread, &contexts[t]);
        if (rc != 0) {
            fprintf(stderr, "[VKS CACHE ERROR] Failed to create thread %u\n", t);
            for (uint32_t i = 0; i < t; i++) {
                pthread_join(threads[i], NULL);
            }
            free(all_rankings);
            free(contexts);
            free(threads);
            return VKC_ERROR_COMMAND_EXECUTION_FAILED;
        }
    }

    // Wait for all threads
    uint32_t total_sorted = 0;
    for (uint32_t t = 0; t < num_threads; t++) {
        pthread_join(threads[t], NULL);
        total_sorted += contexts[t].poems_sorted;
        printf("[VKS CACHE] Thread %u sorted %u poems\n", t, contexts[t].poems_sorted);
    }

    time_t sort_time = time(NULL);
    printf("[VKS CACHE] Parallel sorting complete: %u poems in %ld seconds\n",
           total_sorted, (long)(sort_time - start_time));

    // Write cache file
    printf("[VKS CACHE] Writing cache file: %s\n", cache_file);

    FILE* f = fopen(cache_file, "w");
    if (!f) {
        fprintf(stderr, "[VKS CACHE ERROR] Failed to open cache file: %s\n", cache_file);
        // Cleanup
        for (uint32_t i = 0; i < num_poems; i++) {
            free(all_rankings[i].sorted_indices);
        }
        free(all_rankings);
        free(contexts);
        free(threads);
        return VKC_ERROR_COMMAND_EXECUTION_FAILED;
    }

    // Write JSON header
    fprintf(f, "{\n");
    fprintf(f, "  \"metadata\": {\n");
    fprintf(f, "    \"total_poems\": %u,\n", num_poems);
    fprintf(f, "    \"algorithm\": \"gpu_vulkan_parallel_c\",\n");
    fprintf(f, "    \"format\": \"pre_sorted_rankings\",\n");
    fprintf(f, "    \"sort_threads\": %u,\n", num_threads);
    fprintf(f, "    \"description\": \"Pre-sorted similarity rankings for fast HTML generation\"\n");
    fprintf(f, "  },\n");

    // Write rankings
    fprintf(f, "  \"rankings\": {\n");

    for (uint32_t i = 0; i < num_poems; i++) {
        uint32_t poem_index = poem_indices[i];
        PoemRankings* rankings = &all_rankings[i];

        fprintf(f, "    \"%u\": [", poem_index);

        if (rankings->sorted_indices && rankings->count > 0) {
            for (uint32_t k = 0; k < rankings->count; k++) {
                fprintf(f, "%u", rankings->sorted_indices[k]);
                if (k < rankings->count - 1) {
                    fprintf(f, ", ");
                }
            }
        }

        fprintf(f, "]%s\n", i < num_poems - 1 ? "," : "");
    }

    fprintf(f, "  }\n");
    fprintf(f, "}\n");

    fclose(f);

    // Cleanup
    for (uint32_t i = 0; i < num_poems; i++) {
        free(all_rankings[i].sorted_indices);
    }
    free(all_rankings);
    free(contexts);
    free(threads);

    time_t end_time = time(NULL);
    printf("[VKS CACHE] ✅ Cache written in %ld seconds total\n", (long)(end_time - start_time));

    return VKC_SUCCESS;
}

/* }}} */
