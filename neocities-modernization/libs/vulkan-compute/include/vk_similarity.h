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

/* {{{ Single poem similarity computation
 */

/**
 * Compute similarities for one poem to all higher-indexed poems
 * (Generates data for triangular individual file format)
 *
 * @param sim_ctx Similarity context
 * @param source_poem_index Index of poem to compare from
 * @param output_similarities Array to receive similarity scores
 *                            Size: (num_poems - source_poem_index - 1) floats
 * @return VKC_SUCCESS or error code
 */
VkComputeResult vks_compute_similarities_for_poem(
    VkSimilarityContext* sim_ctx,
    uint32_t source_poem_index,
    float* output_similarities);

/* }}} */

/* {{{ Batch similarity computation
 */

/**
 * Compute similarities for all poems (full triangular matrix)
 * Results can be used to generate all triangular individual files
 *
 * @param sim_ctx Similarity context
 * @param progress_callback Optional callback for progress updates (NULL to disable)
 *                          Called with (current_poem, total_poems, user_data)
 * @param user_data User data passed to progress callback
 * @return VKC_SUCCESS or error code
 *
 * Note: This function will call the progress callback after each poem's
 * similarities are computed. The callback can be used to write individual
 * files incrementally.
 */
typedef void (*VksSimilarityProgressCallback)(uint32_t current_poem,
                                                uint32_t total_poems,
                                                const float* similarities,
                                                uint32_t num_similarities,
                                                void* user_data);

VkComputeResult vks_compute_all_similarities(
    VkSimilarityContext* sim_ctx,
    VksSimilarityProgressCallback progress_callback,
    void* user_data);

/* }}} */

#ifdef __cplusplus
}
#endif

#endif /* VK_SIMILARITY_H */
