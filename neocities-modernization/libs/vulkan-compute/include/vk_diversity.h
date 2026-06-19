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
 * Embeddings are FP16, packed two per uint, with low 16 bits = value at
 * even-index dim and high 16 bits = value at odd-index dim. Caller is
 * responsible for the FP32 -> FP16 conversion via vkc_fp32_to_fp16().
 * embedding_dim MUST be even (true for 768 and 2560; check before calling).
 *
 * Parameters:
 *   ctx - Vulkan compute context
 *   embeddings_fp16 - All poem embeddings, FP16 packed:
 *                     (num_poems * embedding_dim / 2) uints, i.e.
 *                     (num_poems * embedding_dim * 2) bytes.
 *   num_poems - Total number of poems (e.g., 7797)
 *   embedding_dim - Embedding dimension; must be even (e.g., 768, 2560)
 *   batch_size - Number of sequences to compute in parallel (e.g., 3584)
 *   start_indices - Array of starting poem indices (batch_size elements)
 *
 * Returns: Batch context handle or NULL on error
 *
 * Note: Batch size should be <= 3584 for optimal GPU utilization
 */
VkDiversityBatchContext* vkd_batch_init(VkComputeContext* ctx,
                                         const uint16_t* embeddings_fp16,
                                         uint32_t num_poems,
                                         uint32_t embedding_dim,
                                         uint32_t batch_size,
                                         const uint32_t* start_indices);

/* Run a chunk of diversity-sequence iterations on the GPU.
 *
 * Each workgroup advances its sequence by `slot_count` slots, starting at
 * output slot `start_slot`. Centroid + count + mask state persists in the
 * shared storage buffers between calls, so a subsequent call with
 * start_slot = start_slot + slot_count resumes exactly where this one
 * left off.
 *
 * The chunked design exists because attempting to compute every iteration
 * in a single dispatch trips the kernel GPU watchdog (~10 seconds on
 * Linux+NVIDIA with an active display). Calling this in a loop with a
 * chunk size that yields under ~1-2 seconds of GPU work per call avoids
 * that and still amortizes per-dispatch overhead nearly perfectly
 * compared to the old per-iteration approach (8358 dispatches per batch).
 *
 * Parameters:
 *   batch_ctx  - Batch context
 *   start_slot - First output-sequence slot to write (1 on the first call;
 *                slot 0 is the seed, written by vkd_batch_init)
 *   slot_count - How many slots to write in this call
 *   tile_size  - Number of candidate poems per L2-friendly tile in the
 *                inner scan. Pass batch_ctx->num_poems (or 0) for the
 *                non-tiled baseline; pass a smaller value to enable the
 *                9-014 tiling optimization. A reasonable derivation is
 *                floor(L2_BYTES * 0.85 / (embedding_dim * 2)) since each
 *                FP16-packed candidate is embedding_dim * 2 bytes.
 *
 * Returns: VKC_SUCCESS, or the error code from the underlying dispatch
 *          (e.g. VKC_ERROR_COMMAND_EXECUTION_FAILED on device-lost). The
 *          caller is responsible for stopping the loop and reporting on
 *          any non-success return.
 */
VkComputeResult vkd_batch_compute_chunk(VkDiversityBatchContext* batch_ctx,
                                         uint32_t start_slot,
                                         uint32_t slot_count,
                                         uint32_t tile_size);

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
