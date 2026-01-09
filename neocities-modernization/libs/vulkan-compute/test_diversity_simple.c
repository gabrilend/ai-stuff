/* test_diversity_simple.c - Simple test of diversity sequence generation
 *
 * Tests the diversity sequence algorithm with a small dataset.
 * NOTE: This is a simplified test - the full algorithm needs centroid updates.
 */

#include "include/vk_diversity.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define EMBEDDING_DIM 768
#define NUM_POEMS 100
#define START_POEM 0

/* Generate test embeddings with some structure */
void generate_structured_embeddings(float* embeddings, int num_poems, int dim) {
    for (int i = 0; i < num_poems; i++) {
        for (int d = 0; d < dim; d++) {
            /* Make embeddings somewhat clustered */
            float base = (float)i / num_poems;
            float variation = ((float)rand() / RAND_MAX - 0.5f) * 0.1f;
            embeddings[i * dim + d] = base + variation;
        }
    }
}

int main(void) {
    printf("=== Diversity Sequence Test ===\n\n");
    printf("Configuration:\n");
    printf("  Poems: %d\n", NUM_POEMS);
    printf("  Dimensions: %d\n", EMBEDDING_DIM);
    printf("  Start poem: %d\n", START_POEM);

    srand(42);

    /* Generate test data */
    printf("\n[1] Generating test embeddings...\n");
    float* embeddings = malloc(NUM_POEMS * EMBEDDING_DIM * sizeof(float));
    if (!embeddings) {
        fprintf(stderr, "ERROR: Memory allocation failed\n");
        return 1;
    }

    generate_structured_embeddings(embeddings, NUM_POEMS, EMBEDDING_DIM);
    printf("    [OK] Generated %d embeddings\n", NUM_POEMS);

    /* Initialize Vulkan */
    printf("\n[2] Initializing Vulkan...\n");
    VkComputeContext* ctx = vkc_init(false);
    if (!ctx) {
        fprintf(stderr, "ERROR: Failed to initialize Vulkan\n");
        free(embeddings);
        return 1;
    }
    printf("    [OK] Vulkan initialized\n");

    /* Initialize diversity context */
    printf("\n[3] Initializing diversity context...\n");
    VkDiversityContext* div_ctx = vkd_init(ctx, embeddings, NUM_POEMS, EMBEDDING_DIM);
    if (!div_ctx) {
        fprintf(stderr, "ERROR: Failed to initialize diversity context\n");
        vkc_destroy(ctx);
        free(embeddings);
        return 1;
    }

    /* Compute diversity sequence */
    printf("\n[4] Computing diversity sequence...\n");
    uint32_t* sequence = malloc(NUM_POEMS * sizeof(uint32_t));
    if (!sequence) {
        fprintf(stderr, "ERROR: Memory allocation failed\n");
        vkd_destroy(div_ctx);
        vkc_destroy(ctx);
        free(embeddings);
        return 1;
    }

    VkComputeResult result = vkd_compute_sequence(div_ctx, START_POEM, sequence);
    if (result != VKC_SUCCESS) {
        fprintf(stderr, "ERROR: Diversity sequence computation failed\n");
        free(sequence);
        vkd_destroy(div_ctx);
        vkc_destroy(ctx);
        free(embeddings);
        return 1;
    }

    /* Verify sequence */
    printf("\n[5] Verifying sequence...\n");
    bool valid = true;

    /* Check that sequence starts with start_poem */
    if (sequence[0] != START_POEM) {
        fprintf(stderr, "    ERROR: Sequence doesn't start with start_poem\n");
        valid = false;
    }

    /* Check that all poems appear exactly once */
    uint8_t* seen = calloc(NUM_POEMS, sizeof(uint8_t));
    for (int i = 0; i < NUM_POEMS; i++) {
        uint32_t poem_id = sequence[i];
        if (poem_id >= NUM_POEMS) {
            fprintf(stderr, "    ERROR: Invalid poem ID: %u\n", poem_id);
            valid = false;
            break;
        }
        if (seen[poem_id]) {
            fprintf(stderr, "    ERROR: Duplicate poem ID: %u\n", poem_id);
            valid = false;
            break;
        }
        seen[poem_id] = 1;
    }

    free(seen);

    if (valid) {
        printf("    [OK] Sequence is valid\n");
        printf("\n    First 10 poems in sequence:\n");
        for (int i = 0; i < 10 && i < NUM_POEMS; i++) {
            printf("      [%d] → poem %u\n", i, sequence[i]);
        }
    } else {
        printf("    [FAILED] Sequence validation failed\n");
    }

    /* Cleanup */
    printf("\n[6] Cleaning up...\n");
    free(sequence);
    free(embeddings);
    vkd_destroy(div_ctx);
    vkc_destroy(ctx);

    if (valid) {
        printf("\n[SUCCESS] Diversity sequence test passed!\n");
        printf("\nNOTE: This is a simplified test. Full algorithm requires centroid updates.\n");
        return 0;
    } else {
        printf("\n[FAILED] Test failed\n");
        return 1;
    }
}
