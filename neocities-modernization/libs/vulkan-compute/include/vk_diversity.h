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

#ifdef __cplusplus
}
#endif

#endif /* VK_DIVERSITY_H */
