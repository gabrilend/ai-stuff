// src/027-stage-pool.c
// Stage pool implementation for random stage selection
// Scans boards/ directory, provides no-repeat cycling through stages
//
// External functions: stage_pool_create, stage_pool_destroy,
//                     stage_pool_select_random, stage_pool_reset_cycle,
//                     stage_pool_refresh, stage_pool_get_count,
//                     stage_pool_get_available_count

#define _POSIX_C_SOURCE 200809L  // For strdup

#include "026-stage-pool.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <time.h>

// =============================================================================
// Internal Helpers
// =============================================================================

// {{{ stage_pool_is_used
// Checks if a stage index has been used this cycle.
static int stage_pool_is_used(StagePool* pool, int index) {
    if (index < 0 || index >= pool->total_count) return 1;
    return (pool->used_mask & (1u << index)) != 0;
}
// }}}

// {{{ stage_pool_mark_used
// Marks a stage index as used for this cycle.
static void stage_pool_mark_used(StagePool* pool, int index) {
    if (index < 0 || index >= pool->total_count) return;
    pool->used_mask |= (1u << index);
    pool->used_count++;
}
// }}}

// {{{ stage_pool_clear_files
// Frees all file paths in the pool.
static void stage_pool_clear_files(StagePool* pool) {
    for (int i = 0; i < pool->total_count; i++) {
        if (pool->stage_files[i]) {
            free(pool->stage_files[i]);
            pool->stage_files[i] = NULL;
        }
    }
    pool->total_count = 0;
}
// }}}

// {{{ stage_pool_scan_directory
// Scans a directory for .json files and adds them to the pool.
static void stage_pool_scan_directory(StagePool* pool, const char* directory) {
    DIR* dir = opendir(directory);
    if (!dir) {
        fprintf(stderr, "WARNING: Cannot open stages directory: %s\n", directory);
        return;
    }

    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL && pool->total_count < MAX_STAGE_POOL) {
        const char* name = entry->d_name;
        size_t len = strlen(name);

        // Check for .json extension
        if (len > 5 && strcmp(name + len - 5, ".json") == 0) {
            // Build full path
            size_t path_len = strlen(directory) + len + 2;
            char* path = (char*)malloc(path_len);
            if (!path) continue;

            snprintf(path, path_len, "%s/%s", directory, name);

            pool->stage_files[pool->total_count] = path;
            pool->total_count++;

            printf("Stage pool: added %s\n", name);
        }
    }

    closedir(dir);
}
// }}}

// =============================================================================
// Pool Lifecycle
// =============================================================================

// {{{ stage_pool_create
StagePool* stage_pool_create(const char* directory) {
    StagePool* pool = (StagePool*)calloc(1, sizeof(StagePool));
    if (!pool) {
        fprintf(stderr, "ERROR: Failed to allocate stage pool\n");
        return NULL;
    }

    // Scan directory for stage files
    stage_pool_scan_directory(pool, directory);

    printf("Stage pool: %d stages available\n", pool->total_count);

    return pool;
}
// }}}

// {{{ stage_pool_destroy
void stage_pool_destroy(StagePool* pool) {
    if (!pool) return;

    stage_pool_clear_files(pool);
    free(pool);
}
// }}}

// =============================================================================
// Stage Selection
// =============================================================================

// {{{ stage_pool_select_random
const char* stage_pool_select_random(StagePool* pool) {
    if (!pool || pool->total_count == 0) {
        // Empty pool - caller should fall back to default stage
        return NULL;
    }

    // Check if all stages have been used this cycle
    if (pool->used_count >= pool->total_count) {
        printf("Stage pool: all %d stages used, resetting cycle\n", pool->total_count);
        stage_pool_reset_cycle(pool);
    }

    // Build list of available (unused) indices
    int available[MAX_STAGE_POOL];
    int available_count = 0;

    for (int i = 0; i < pool->total_count; i++) {
        if (!stage_pool_is_used(pool, i)) {
            available[available_count++] = i;
        }
    }

    if (available_count == 0) {
        // Safety: shouldn't happen after reset, but handle gracefully
        fprintf(stderr, "ERROR: Stage pool has no available stages after reset\n");
        return NULL;
    }

    // Select random from available
    int pick = rand() % available_count;
    int selected_index = available[pick];

    // Mark as used
    stage_pool_mark_used(pool, selected_index);

    printf("Stage pool: selected %s (%d/%d used)\n",
           pool->stage_files[selected_index],
           pool->used_count, pool->total_count);

    return pool->stage_files[selected_index];
}
// }}}

// {{{ stage_pool_reset_cycle
void stage_pool_reset_cycle(StagePool* pool) {
    if (!pool) return;

    pool->used_count = 0;
    pool->used_mask = 0;

    printf("Stage pool: cycle reset\n");
}
// }}}

// {{{ stage_pool_refresh
void stage_pool_refresh(StagePool* pool, const char* directory) {
    if (!pool) return;

    // Clear existing files
    stage_pool_clear_files(pool);

    // Reset used tracking
    stage_pool_reset_cycle(pool);

    // Rescan directory
    stage_pool_scan_directory(pool, directory);

    printf("Stage pool: refreshed, %d stages available\n", pool->total_count);
}
// }}}

// =============================================================================
// Pool Status
// =============================================================================

// {{{ stage_pool_get_count
int stage_pool_get_count(StagePool* pool) {
    return pool ? pool->total_count : 0;
}
// }}}

// {{{ stage_pool_get_available_count
int stage_pool_get_available_count(StagePool* pool) {
    if (!pool) return 0;
    return pool->total_count - pool->used_count;
}
// }}}
