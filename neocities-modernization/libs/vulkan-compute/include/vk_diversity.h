/* vk_diversity.h - High-level API for diversity sequence generation
 *
 * This header provides a simplified interface for computing diversity
 * sequences on the GPU using the Vulkan compute infrastructure.
 */

#ifndef VK_DIVERSITY_H
#define VK_DIVERSITY_H

#include "vk_compute.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque handle for diversity sequence computation session */
typedef struct VkDiversityContext VkDiversityContext;

/* Initialize diversity sequence computation
 *
 * Parameters:
 *   ctx - Vulkan compute context
 *   embeddings - All poem embeddings (num_poems * embedding_dim floats)
 *   num_poems - Number of poems
 *   embedding_dim - Dimension of embeddings (e.g., 768)
 *
 * Returns: Diversity context handle or NULL on error
 */
VkDiversityContext* vkd_init(VkComputeContext* ctx,
                             const float* embeddings,
                             uint32_t num_poems,
                             uint32_t embedding_dim);

/* Compute a single diversity sequence
 *
 * Parameters:
 *   div_ctx - Diversity context
 *   start_poem - Index of starting poem (0 to num_poems-1)
 *   output_sequence - Output buffer for sequence (num_poems indices)
 *
 * Returns: VKC_SUCCESS or error code
 */
VkComputeResult vkd_compute_sequence(VkDiversityContext* div_ctx,
                                     uint32_t start_poem,
                                     uint32_t* output_sequence);

/* Cleanup diversity context */
void vkd_destroy(VkDiversityContext* div_ctx);

/* ===========================================================================
 * Batch Processing API - Parallel computation of multiple sequences
 * ===========================================================================
 * These functions enable computing thousands of diversity sequences
 * simultaneously with GPU-side state management for optimal performance.
 */

/* Opaque handle for batch diversity computation */
typedef struct VkDiversityBatchContext VkDiversityBatchContext;

/* Initialize batch diversity computation
 *
 * Parameters:
 *   ctx - Vulkan compute context
 *   embeddings - All poem embeddings (num_poems * embedding_dim floats)
 *   num_poems - Total number of poems (e.g., 7797)
 *   embedding_dim - Embedding dimension (e.g., 768)
 *   batch_size - Number of sequences to compute in parallel (e.g., 3584)
 *   start_indices - Array of starting poem indices (batch_size elements)
 *
 * Returns: Batch context handle or NULL on error
 *
 * Note: Batch size should be <= 3584 for optimal GPU utilization
 */
VkDiversityBatchContext* vkd_batch_init(VkComputeContext* ctx,
                                         const float* embeddings,
                                         uint32_t num_poems,
                                         uint32_t embedding_dim,
                                         uint32_t batch_size,
                                         const uint32_t* start_indices);

/* Execute one iteration across all sequences in batch
 *
 * This function computes the next poem for each sequence in parallel,
 * updates centroids and masks on the GPU, and returns the selections.
 *
 * Parameters:
 *   batch_ctx - Batch context
 *   iteration - Current iteration number (0 to num_poems-1)
 *   selections - Output buffer for selected poems (batch_size elements)
 *
 * Returns: VKC_SUCCESS or error code
 */
VkComputeResult vkd_batch_step(VkDiversityBatchContext* batch_ctx,
                                uint32_t iteration,
                                uint32_t* selections);

/* Download complete sequences from GPU
 *
 * Parameters:
 *   batch_ctx - Batch context
 *   output_sequences - Output buffer (batch_size * num_poems indices)
 *
 * Returns: VKC_SUCCESS or error code
 */
VkComputeResult vkd_batch_download_sequences(VkDiversityBatchContext* batch_ctx,
                                              uint32_t* output_sequences);

/* Cleanup batch context */
void vkd_batch_destroy(VkDiversityBatchContext* batch_ctx);

#ifdef __cplusplus
}
#endif

#endif /* VK_DIVERSITY_H */
