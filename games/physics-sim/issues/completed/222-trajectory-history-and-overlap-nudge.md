# 222 - Trajectory History and Overlap Nudge

## Status: completed

## Depends on

None - independent feature. Can be implemented in parallel with 221.

## Related Issues

- 221d (Soft collision) - complementary approaches to pile stability
- 221a (Sleep state) - trajectory useful for sleep detection
- 112 (Compile time config) - uses config.txt for constants

## Problem

Balls in piles can overlap and jitter. Need a system to:
1. Track ball trajectory history for informed physics decisions
2. Efficiently detect overlapping slow balls
3. Gently nudge overlapping balls apart using their trajectory

## Current Behavior

- No trajectory history stored
- Collision detection is per-frame only
- Overlap resolution uses instantaneous positions
- No spatial optimization for ball-ball checks

## Intended Behavior

- Each ball stores N frames of trajectory (position + velocity vectors)
- Slow balls checked for overlap using spatial hash (grid cells)
- Overlapping balls nudged apart based on trajectory history
- Configurable history size via config.txt

## Design

### Trajectory History Structure

```c
// Add to config.txt
TRAJECTORY_HISTORY_FRAMES=4

// In Ball struct
typedef struct Ball {
    // ... existing fields ...

    // Trajectory history (issue 222)
    // Circular buffer of past positions/velocities
    float history_x[TRAJECTORY_HISTORY_FRAMES];
    float history_y[TRAJECTORY_HISTORY_FRAMES];
    float history_vx[TRAJECTORY_HISTORY_FRAMES];
    float history_vy[TRAJECTORY_HISTORY_FRAMES];
    int history_index;  // Current write position (circular)
} Ball;
```

### Trajectory Update (each frame)

```c
void ball_record_trajectory(Ball* ball) {
    ball->history_x[ball->history_index] = ball->x;
    ball->history_y[ball->history_index] = ball->y;
    ball->history_vx[ball->history_index] = ball->vx;
    ball->history_vy[ball->history_index] = ball->vy;

    ball->history_index = (ball->history_index + 1) % TRAJECTORY_HISTORY_FRAMES;
}
```

### Average Trajectory Calculation (pure function)

```c
// Returns average velocity direction over history
// Useful for determining nudge direction
Vector2 ball_get_average_trajectory(Ball* ball) {
    float sum_vx = 0, sum_vy = 0;
    for (int i = 0; i < TRAJECTORY_HISTORY_FRAMES; i++) {
        sum_vx += ball->history_vx[i];
        sum_vy += ball->history_vy[i];
    }

    float avg_vx = sum_vx / TRAJECTORY_HISTORY_FRAMES;
    float avg_vy = sum_vy / TRAJECTORY_HISTORY_FRAMES;

    // Normalize
    float mag = sqrtf(avg_vx * avg_vx + avg_vy * avg_vy);
    if (mag < 0.001f) return (Vector2){0, 0};

    return (Vector2){avg_vx / mag, avg_vy / mag};
}
```

### Spatial Hashing (using existing grid)

```c
// Grid cell index for a ball position
int ball_get_grid_cell(Ball* ball, Grid* grid) {
    int col = (int)((ball->x - grid->origin_x) / grid->cell_size);
    int row = (int)((ball->y - grid->origin_y) / grid->cell_size);

    // Clamp to grid bounds
    col = (col < 0) ? 0 : (col >= grid->cols) ? grid->cols - 1 : col;
    row = (row < 0) ? 0 : (row >= grid->rows) ? grid->rows - 1 : row;

    return row * grid->cols + col;
}

// Per-cell ball lists (rebuilt each frame)
typedef struct GridCell {
    int* ball_indices;
    int count;
    int capacity;
} GridCell;

typedef struct SpatialHash {
    GridCell* cells;
    int cell_count;
    Grid* grid;
} SpatialHash;
```

### Overlap Detection (only slow balls, only adjacent cells)

```c
#define SLOW_BALL_THRESHOLD 5.0f   // Only check balls moving slower than this
#define OVERLAP_RADIUS_MULT 2.0f   // Check within 2x ball radius

void check_slow_ball_overlaps(BallManager* manager, SpatialHash* hash) {
    for (int i = 0; i < manager->capacity; i++) {
        Ball* ball = &manager->balls_current[i];
        if (!ball->active) continue;

        // Only check slow balls
        float speed = sqrtf(ball->vx * ball->vx + ball->vy * ball->vy);
        if (speed > SLOW_BALL_THRESHOLD) continue;

        int cell = ball_get_grid_cell(ball, hash->grid);

        // Check this cell and 8 adjacent cells
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                int neighbor_cell = cell + dy * hash->grid->cols + dx;
                if (neighbor_cell < 0 || neighbor_cell >= hash->cell_count) continue;

                // Check all balls in this cell
                GridCell* gc = &hash->cells[neighbor_cell];
                for (int j = 0; j < gc->count; j++) {
                    int other_idx = gc->ball_indices[j];
                    if (other_idx <= i) continue;  // Avoid duplicate pairs

                    Ball* other = &manager->balls_current[other_idx];
                    check_and_nudge_pair(ball, other);
                }
            }
        }
    }
}
```

### Nudge Logic

```c
#define NUDGE_STRENGTH 0.5f

void check_and_nudge_pair(Ball* a, Ball* b) {
    float dx = b->x - a->x;
    float dy = b->y - a->y;
    float dist_sq = dx * dx + dy * dy;

    float overlap_dist = BALL_RADIUS * OVERLAP_RADIUS_MULT;
    if (dist_sq >= overlap_dist * overlap_dist) return;  // Not overlapping

    float dist = sqrtf(dist_sq);
    if (dist < 0.001f) {
        // Balls exactly on top of each other - use trajectory to separate
        Vector2 traj_a = ball_get_average_trajectory(a);
        Vector2 traj_b = ball_get_average_trajectory(b);

        // Push opposite to each ball's trajectory
        a->x -= traj_a.x * NUDGE_STRENGTH;
        a->y -= traj_a.y * NUDGE_STRENGTH;
        b->x -= traj_b.x * NUDGE_STRENGTH;
        b->y -= traj_b.y * NUDGE_STRENGTH;
    } else {
        // Push along separation axis, weighted by trajectory
        float nx = dx / dist;
        float ny = dy / dist;

        float overlap = overlap_dist - dist;
        float push = overlap * NUDGE_STRENGTH * 0.5f;

        a->x -= nx * push;
        a->y -= ny * push;
        b->x += nx * push;
        b->y += ny * push;
    }
}
```

## Config Values

Add to config.txt (issue 112):
```
TRAJECTORY_HISTORY_FRAMES=4
SLOW_BALL_THRESHOLD=5
OVERLAP_RADIUS_MULT=2
NUDGE_STRENGTH=0.5
```

## Implementation Steps

1. Add TRAJECTORY_HISTORY_FRAMES to config.txt
2. Add trajectory history fields to Ball struct
3. Implement ball_record_trajectory() called each frame
4. Implement ball_get_average_trajectory() pure function
5. Create SpatialHash structure using existing Grid
6. Implement spatial hash rebuild each frame
7. Implement check_slow_ball_overlaps() with adjacent cell checks
8. Implement check_and_nudge_pair() with trajectory-informed nudge
9. Call overlap check after physics update, before render
10. Test with pile of balls - should settle without jitter

## Files to Modify

- `config.txt` - Add trajectory/nudge constants
- `src/006-ball.h` - Add history fields to Ball struct
- `src/007-ball.c` - Add trajectory recording and averaging
- `src/022-grid.h` - Add SpatialHash structure (or new file)
- `src/023-grid.c` - Implement spatial hash functions
- `src/001-main.c` - Call overlap check in game loop

## Performance Notes

- Spatial hash rebuild: O(n) per frame
- Overlap checks: O(n * k) where k = average balls per cell neighborhood (~9 cells)
- With 1024 balls spread across 12x20=240 cells, ~4 balls per cell average
- Checking ~36 pairs per ball vs 1024 = 97% reduction in comparisons

## Relationship to Other Issues

- **221d (Soft Collision)**: Complementary - this handles slow ball overlap, 221d handles collision response
- **221a (Sleep State)**: Trajectory history useful for sleep detection (stationary for N frames)
- **221e (Stress Distinction)**: Trajectory can help identify dynamic vs static pressure

## Troubleshooting

### "Balls still overlap"
- OVERLAP_RADIUS_MULT too low (try 2.5)
- NUDGE_STRENGTH too weak (try 1.0)
- Spatial hash not checking all neighbors

### "Balls jitter rapidly"
- NUDGE_STRENGTH too high
- Nudging balls back into overlap
- Need to check both balls are slow

### "Performance worse than before"
- Spatial hash rebuild too expensive
- Pre-allocate cell arrays, don't malloc per frame
- Check cell capacity isn't growing unbounded

### "Trajectory direction wrong"
- History buffer not recording correctly
- Circular buffer index wrapping issue
- Check history_index increments after write

## Notes

- Trajectory history has many uses beyond nudging
- Could visualize as motion blur or trails
- Could predict collisions for better response
- Spatial hash useful for other optimizations too

## Implementation Notes (2026-03-19)

### Phase 1 Complete: Trajectory History Foundation

1. **config.txt**:
   - Added `TRAJECTORY_HISTORY_FRAMES=4`

2. **src/006-ball.h**:
   - Added trajectory constants: `SLOW_BALL_THRESHOLD`, `OVERLAP_RADIUS_MULT`, `NUDGE_STRENGTH`
   - Added Ball struct fields: `history_x[]`, `history_y[]`, `history_vx[]`, `history_vy[]`, `history_index`

3. **src/007-ball.c**:
   - Updated `ball_manager_create()` to initialize trajectory history in both buffers
   - Updated `ball_manager_spawn()` to initialize history at spawn position/velocity
   - Updated `ball_update_physics()` to copy trajectory history during double-buffering
   - Added `ball_record_trajectory()` to record state each frame
   - Added `ball_get_average_trajectory()` for computing average movement direction
   - Called trajectory recording in both `ball_manager_update()` and `ball_update_task()`

### Phase 2 Complete: Spatial Hash and Nudging (2026-03-19)

1. **src/006-ball.h**:
   - Added `SpatialHashCell` struct with fixed-size ball_indices array
   - Added `SpatialHash` struct with grid parameters and cell array
   - Added spatial hash constants: `SPATIAL_HASH_CELL_SIZE`, `SPATIAL_HASH_COLS`, `SPATIAL_HASH_ROWS`, `SPATIAL_HASH_MAX_PER_CELL`
   - Added `SpatialHash*` to BallManager struct
   - Added `ball_manager_check_slow_overlaps()` declaration

2. **src/007-ball.c**:
   - Added `spatial_hash_create()` - allocates hash grid
   - Added `spatial_hash_destroy()` - frees hash grid
   - Added `spatial_hash_clear()` - resets cell counts
   - Added `spatial_hash_get_cell_index()` - converts position to cell
   - Added `spatial_hash_add_ball()` - adds ball to appropriate cell
   - Added `check_and_nudge_pair()` - nudges overlapping slow balls using trajectory
   - Added `ball_manager_check_slow_overlaps()` - rebuilds hash and checks neighbors
   - Updated `ball_manager_create()` to create spatial hash
   - Updated `ball_manager_destroy()` to free spatial hash

3. **src/001-main.c**:
   - Added call to `ball_manager_check_slow_overlaps()` after physics update

### Implementation Summary

- Spatial hash provides O(n) rebuild and O(n*k) overlap checks (k = balls per neighborhood)
- Only slow balls (speed < SLOW_BALL_THRESHOLD=5) are added to hash and checked
- Adjacent 9 cells checked for each slow ball
- Overlapping balls nudged apart along separation axis
- Coincident balls (same position) use trajectory history to determine push direction
- Cell size (32px) optimized for 2x overlap radius (16px) lookups
