/* vk_similarity.h - Vulkan-accelerated similarity matrix computation
 *
 * Provides GPU-accelerated cosine similarity calculation for poem embeddings
 * using triangular individual files format for storage efficiency.
 */

#ifndef VK_SIMILARITY_H
#define VK_SIMILARITY_H

#include "vk_compute.h"
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* {{{ Similarity computation context
 */

typedef struct VkSimilarityContext VkSimilarityContext;

/**
 * Initialize similarity computation context
 * @param ctx Vulkan compute context
 * @param embeddings All poem embeddings (num_poems × 768 floats)
 * @param num_poems Total number of poems
 * @param embedding_dim Dimension of embeddings (768)
 * @return Similarity context or NULL on error
 */
VkSimilarityContext* vks_init(VkComputeContext* ctx,
                               const float* embeddings,
                               uint32_t num_poems,
                               uint32_t embedding_dim);

/**
 * Clean up similarity computation context
 * @param sim_ctx Similarity context to destroy
 */
void vks_destroy(VkSimilarityContext* sim_ctx);

/* }}} */

/* The single-poem and sequential batch entry points were removed with Issue
 * 9-002b -- the parallel full-matrix dispatch below is the only path. */

/* {{{ Parallel full-matrix computation (Issue 9-002 original design)
 */

/**
 * Compute ALL similarities in a single GPU dispatch
 * This is the correct parallel implementation per Issue 9-002 design.
 *
 * @param sim_ctx Similarity context
 * @param output_triangular Output buffer for triangular matrix
 *                          Size: num_poems * (num_poems - 1) / 2 floats
 *                          Layout: For pair (i,j) where i<j:
 *                          index = i * num_poems - i*(i+1)/2 + (j-i-1)
 * @return VKC_SUCCESS or error code
 *
 * Performance: Single dispatch with ~173K workgroups, completes in seconds
 * vs sequential approach which takes 70+ minutes.
 */
VkComputeResult vks_compute_all_similarities_parallel(
    VkSimilarityContext* sim_ctx,
    float* output_triangular);

/**
 * Get the size of the triangular similarity matrix in floats
 * @param num_poems Number of poems
 * @return Size in floats: num_poems * (num_poems - 1) / 2
 */
static inline uint64_t vks_triangular_size(uint32_t num_poems) {
    return ((uint64_t)num_poems * (num_poems - 1)) / 2;
}

/**
 * Get the linear index for a pair (i, j) in the triangular matrix
 * @param i First poem index (must be < j)
 * @param j Second poem index (must be > i)
 * @param num_poems Total number of poems
 * @return Linear index into triangular buffer
 */
static inline uint64_t vks_triangular_index(uint32_t i, uint32_t j, uint32_t num_poems) {
    return (uint64_t)i * num_poems - ((uint64_t)i * (i + 1)) / 2 + (j - i - 1);
}

/* }}} */

/* {{{ Parallel file I/O with pthreads
 */

/**
 * Write similarity files in parallel using pthreads
 * This avoids Lua/effil serialization overhead by keeping all data in C.
 *
 * @param triangular_buffer Pre-computed triangular similarity matrix from GPU
 * @param num_poems Total number of poems
 * @param poem_indices Array mapping array index (0-based) to poem_index for each poem
 * @param poem_ids Array of poem IDs (as strings, for metadata)
 * @param output_dir Directory to write files to (e.g., "assets/embeddings/model/similarities")
 * @param num_threads Number of worker threads (1-64)
 * @return VKC_SUCCESS or error code
 *
 * File format: poem_index_{N}.json with sorted similarities
 * Uses atomic task counter - threads grab next poem index when ready
 */
VkComputeResult vks_write_similarity_files_parallel(
    const float* triangular_buffer,
    uint32_t num_poems,
    const uint32_t* poem_indices,
    const char** poem_ids,
    const char* output_dir,
    uint32_t num_threads);

/**
 * Write similarity rankings cache file in parallel
 * Generates the pre-sorted rankings cache that HTML generation uses.
 *
 * @param triangular_buffer Pre-computed triangular similarity matrix from GPU
 * @param num_poems Total number of poems
 * @param poem_indices Array mapping array index (0-based) to poem_index for each poem
 * @param cache_file Path to output cache file (e.g., "assets/.../similarity_rankings_cache.json")
 * @param num_threads Number of worker threads for parallel sorting
 * @param top_k Keep only the top-K nearest neighbours per poem (0 = keep all).
 *              Caps the on-disk JSON and the RAM table the HTML stage parses it
 *              into (Issue 10-057).
 * @return VKC_SUCCESS or error code
 *
 * Output format: JSON with rankings[poem_index] = [sorted_neighbor_indices...]
 */
VkComputeResult vks_write_rankings_cache_parallel(
    const float* triangular_buffer,
    uint32_t num_poems,
    const uint32_t* poem_indices,
    const char* cache_file,
    uint32_t num_threads,
    uint32_t top_k);

/* }}} */

#ifdef __cplusplus
}
#endif

#endif /* VK_SIMILARITY_H */
