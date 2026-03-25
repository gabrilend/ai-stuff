// src/026-stage-pool.h
// Stage pool for random stage selection from boards/ directory
// Provides no-repeat cycling through available stages

#ifndef STAGE_POOL_H
#define STAGE_POOL_H

// =============================================================================
// Constants
// =============================================================================

#define MAX_STAGE_POOL 32
#define STAGE_POOL_DIRECTORY "boards"

// =============================================================================
// Data Structures
// =============================================================================

// {{{ typedef struct StagePool
// StagePool manages a collection of stage JSON files for random selection.
// Ensures no stage repeats until all have been used, then cycles.
typedef struct StagePool {
    char* stage_files[MAX_STAGE_POOL];  // Paths to stage JSON files
    int total_count;                     // Total stages available
    int used_count;                      // Stages used this cycle
    unsigned int used_mask;              // Bitmask of used stages (for pools <= 32)
} StagePool;
// }}}

// =============================================================================
// Pool Lifecycle
// =============================================================================

// {{{ stage_pool_create
// Creates a stage pool by scanning the given directory for .json files.
// Returns NULL on allocation failure. Pool may be empty if no files found.
StagePool* stage_pool_create(const char* directory);
// }}}

// {{{ stage_pool_destroy
// Frees all memory associated with the stage pool.
void stage_pool_destroy(StagePool* pool);
// }}}

// =============================================================================
// Stage Selection
// =============================================================================

// {{{ stage_pool_select_random
// Selects a random stage from the pool that hasn't been used this cycle.
// When all stages have been used, resets the cycle and picks fresh.
// Returns the full path to the stage JSON file, or NULL if pool is empty.
// The returned string is owned by the pool - do not free it.
const char* stage_pool_select_random(StagePool* pool);
// }}}

// {{{ stage_pool_reset_cycle
// Resets the used tracking, allowing all stages to be selected again.
// Called automatically when all stages have been used.
void stage_pool_reset_cycle(StagePool* pool);
// }}}

// {{{ stage_pool_refresh
// Rescans the directory for stage files.
// Use after adding/removing files at runtime.
void stage_pool_refresh(StagePool* pool, const char* directory);
// }}}

// =============================================================================
// Pool Status
// =============================================================================

// {{{ stage_pool_get_count
// Returns the total number of stages in the pool.
int stage_pool_get_count(StagePool* pool);
// }}}

// {{{ stage_pool_get_available_count
// Returns the number of stages not yet used this cycle.
int stage_pool_get_available_count(StagePool* pool);
// }}}

#endif // STAGE_POOL_H
