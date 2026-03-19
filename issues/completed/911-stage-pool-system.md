# 1111 - Stage Pool System

## Current Behavior

Stage expansion is hard-coded to add a specific "Stage 2" with a fixed ramp layout:

```c
// src/015-stage.c
stage_generate_ramps_stage2(stage);
```

When the player purchases a stage upgrade, they always get the same pre-defined layout.

## Intended Behavior

Create a stage pool system that:
1. Scans `boards/` directory for available stage JSON files
2. On stage purchase, randomly selects from available stages
3. Ensures no repeat until all stages have been used
4. Cycles through the pool, then reshuffles for next cycle

This integrates editor-created stages into the existing upgrade system.

## Suggested Implementation Steps

### Step 1: Define stage pool structure

```c
// src/026-stage-pool.h

#define MAX_STAGE_POOL 32

typedef struct StagePool {
    char* stage_files[MAX_STAGE_POOL];  // Paths to stage JSON files
    int total_count;                     // Total stages available
    int used_count;                      // Stages used this cycle
    int used_mask;                       // Bitmask of used stages (for small pools)

    // For larger pools, use array
    int* used_indices;                   // Indices of used stages
    int used_capacity;
} StagePool;
```

### Step 2: Implement pool initialization

```c
// src/027-stage-pool.c

#include <dirent.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

StagePool* stage_pool_create(const char* directory) {
    StagePool* pool = calloc(1, sizeof(StagePool));
    if (!pool) return NULL;

    // Seed random number generator
    srand((unsigned int)time(NULL));

    // Scan directory for .json files
    DIR* dir = opendir(directory);
    if (!dir) {
        fprintf(stderr, "WARNING: Cannot open stages directory: %s\n", directory);
        return pool;
    }

    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL && pool->total_count < MAX_STAGE_POOL) {
        const char* name = entry->d_name;
        int len = strlen(name);

        // Check for .json extension
        if (len > 5 && strcmp(name + len - 5, ".json") == 0) {
            // Build full path
            char* path = malloc(strlen(directory) + len + 2);
            sprintf(path, "%s/%s", directory, name);

            pool->stage_files[pool->total_count] = path;
            pool->total_count++;

            printf("Stage pool: added %s\n", name);
        }
    }

    closedir(dir);
    printf("Stage pool: %d stages available\n", pool->total_count);

    return pool;
}

void stage_pool_destroy(StagePool* pool) {
    if (!pool) return;

    for (int i = 0; i < pool->total_count; i++) {
        free(pool->stage_files[i]);
    }
    if (pool->used_indices) {
        free(pool->used_indices);
    }
    free(pool);
}
```

### Step 3: Implement random selection without repeat

```c
const char* stage_pool_select_random(StagePool* pool) {
    if (!pool || pool->total_count == 0) {
        fprintf(stderr, "ERROR: No stages in pool\n");
        return NULL;
    }

    // Check if all stages have been used
    if (pool->used_count >= pool->total_count) {
        printf("Stage pool: all stages used, resetting cycle\n");
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
        // Shouldn't happen after reset, but safety check
        stage_pool_reset_cycle(pool);
        return stage_pool_select_random(pool);
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
```

### Step 4: Implement used tracking

```c
static int stage_pool_is_used(StagePool* pool, int index) {
    if (pool->total_count <= 32) {
        // Use bitmask for small pools
        return (pool->used_mask & (1 << index)) != 0;
    } else {
        // Search used_indices array
        for (int i = 0; i < pool->used_count; i++) {
            if (pool->used_indices[i] == index) return 1;
        }
        return 0;
    }
}

static void stage_pool_mark_used(StagePool* pool, int index) {
    if (pool->total_count <= 32) {
        pool->used_mask |= (1 << index);
    } else {
        // Add to used_indices
        if (pool->used_count >= pool->used_capacity) {
            pool->used_capacity = pool->used_capacity ? pool->used_capacity * 2 : 8;
            pool->used_indices = realloc(pool->used_indices,
                                          pool->used_capacity * sizeof(int));
        }
        pool->used_indices[pool->used_count] = index;
    }
    pool->used_count++;
}

static void stage_pool_reset_cycle(StagePool* pool) {
    pool->used_count = 0;
    pool->used_mask = 0;
    // used_indices doesn't need clearing, used_count handles it
    printf("Stage pool: cycle reset\n");
}
```

### Step 5: Integrate with stage purchase system

```c
// In main.c or upgrades callback

static void on_stage_purchased(void* user_data) {
    GameState* game = (GameState*)user_data;

    // Select random stage from pool
    const char* stage_path = stage_pool_select_random(game->stage_pool);
    if (!stage_path) {
        fprintf(stderr, "ERROR: No stage available\n");
        return;
    }

    // Load stage data
    BoardData* stage_data = board_data_load_json(stage_path);
    if (!stage_data) {
        fprintf(stderr, "ERROR: Failed to load stage: %s\n", stage_path);
        return;
    }

    // Add to world
    int stage_index = stage_manager_add_player_stage(
        game->world->stages,
        STAGE_TYPE_CUSTOM,
        stage_data->board_height
    );

    if (stage_index >= 0) {
        Stage* new_stage = &game->world->stages->player_stages[stage_index];
        board_data_apply_to_stage(stage_data, new_stage);
    }

    board_data_destroy(stage_data);

    // Trigger expansion animation
    expansion_anim_start(game->expansion_anim);
}
```

### Step 6: Add fallback for empty pool

```c
const char* stage_pool_select_random(StagePool* pool) {
    if (!pool || pool->total_count == 0) {
        // Fallback: return NULL and let caller generate default stage
        printf("Stage pool: empty, using fallback\n");
        return NULL;
    }

    // ... rest of selection logic
}

// In caller:
const char* stage_path = stage_pool_select_random(game->stage_pool);
if (!stage_path) {
    // Use default hard-coded stage
    stage_generate_ramps_stage2(new_stage);
} else {
    BoardData* data = board_data_load_json(stage_path);
    // ... load from JSON
}
```

### Step 7: Hot-reload support (optional)

```c
void stage_pool_refresh(StagePool* pool, const char* directory) {
    // Clear existing files
    for (int i = 0; i < pool->total_count; i++) {
        free(pool->stage_files[i]);
        pool->stage_files[i] = NULL;
    }
    pool->total_count = 0;

    // Reset used tracking
    stage_pool_reset_cycle(pool);

    // Rescan directory
    // ... same logic as stage_pool_create
}
```

## Pool Behavior

| Scenario | Behavior |
|----------|----------|
| First purchase | Random stage from pool |
| Subsequent purchase | Random from remaining unused |
| All stages used | Reset cycle, start fresh random |
| Empty boards/ folder | Fall back to hard-coded stage |
| File load error | Skip that file, try another |

## Files to Create

- `src/026-stage-pool.h` - StagePool structure and API
- `src/027-stage-pool.c` - Pool implementation

## Files to Modify

- `src/001-main.c` - Initialize pool, update stage purchase callback
- `src/011-upgrades.c` - May need to adjust stage upgrade behavior

## Testing

1. Create 3 stage files in boards/
2. Purchase first stage - should pick random
3. Purchase second stage - should pick from remaining 2
4. Purchase third stage - should get last one
5. Purchase fourth stage - cycle resets, picks random again
6. Delete all files from boards/ - should fall back to default
7. Add new file during gameplay, call refresh - should be available

## Related Issues

- 1103-board-loader.md (loads stage JSON)
- 1108-board-save.md (creates stage files)
- Phase 10 stage system (integration point)

## Implementation Notes (Complete)

**Status:** Complete

**Files Created:**
- src/026-stage-pool.h - StagePool structure and API
- src/027-stage-pool.c - Pool implementation with directory scanning

**Files Modified:**
- src/001-main.c - Integrated pool with stage purchase callback
- src/014-stage.h - Added STAGE_TYPE_CUSTOM
- src/016-ramp.h - Added ramp_create_line() for line-based ramps
- src/017-ramp.c - Implemented ramp_create_line()

**Key Features:**
1. Scans boards/ directory for .json stage files on startup
2. Random stage selection with no-repeat cycling
3. Automatic cycle reset when all stages used
4. Fallback to hardcoded ramp stage if pool is empty
5. apply_board_data_to_stage() converts BoardData to Stage pegs/ramps
6. Custom stages support both pegs and line obstacles

**Pool Behavior:**
- Empty pool: Falls back to default ramp stage
- 1-32 stages: Uses bitmask for efficient used tracking
- Cycle complete: Automatically resets for fresh random selection
