# 902h - Parallelize Track Mover Updates

## Status: awaiting-work

## Depends on

- 902d ✓ (Track following physics)
- 902c ✓ (Mover payload detection)

## Problem

The `track_mover_manager_update()` function currently runs sequentially on a single thread, iterating over all movers one at a time. Each mover's update is independent of others (each has its own segment position and payload objects), making this an ideal parallelization candidate.

## Current Behavior

In `src/053-track-mover.c` lines 525-570:
```c
void track_mover_manager_update(TrackMoverManager* manager, float dt) {
    for (int m = 0; m < manager->mover_count; m++) {
        MoverPhysics* mover = &manager->movers[m];
        // Advance position along segment
        // Handle segment transition if needed
        // Update world position
        // Update payload positions (connected lines/pegs)
    }
}
```

Each mover:
1. Advances position along current track segment
2. Handles segment transitions (dead-end reversal, path following)
3. Interpolates world position on segment
4. Updates all payload object positions (lines and pegs)

All operations are independent per-mover.

## Intended Behavior

Parallel mover updates following the same pattern as ball/particle/rotor systems:

1. Create `MoverTaskData` structure to hold per-task context
2. Pre-allocate task data array in `TrackMoverManager`
3. Add `track_mover_manager_prepare_tasks()` to set up task data
4. Add `track_mover_manager_submit_tasks()` to submit to threadpool
5. Task function `mover_update_task()` handles single mover
6. Main loop: prepare → submit → wait_all

## Suggested Implementation Steps

1. **Add task data structure** to `src/052-track-mover.h`:
   ```c
   typedef struct {
       MoverPhysics* mover;
       TrackMoverManager* manager;  // For segment array access
       World* world;
       float dt;
   } MoverTaskData;
   ```

2. **Extend TrackMoverManager** with task array:
   ```c
   // Add to TrackMoverManager struct:
   MoverTaskData* task_data;
   int task_data_capacity;
   ```

3. **Create mover_update_task function**:
   - Receives `void* arg` cast to `MoverTaskData*`
   - Performs position advance, segment transition, world position update
   - Calls `update_payload_positions()` for attached objects
   - Same logic as current inner loop, just on single mover

4. **Add track_mover_manager_prepare_tasks()**:
   - Ensures task_data array has capacity for mover_count
   - Populates each MoverTaskData with mover pointer, manager, world, dt

5. **Add track_mover_manager_submit_tasks()**:
   - Loops over task_data, creates Task for each
   - Submits to threadpool via `threadpool_submit()`

6. **Update main.c** integration:
   - Replace `track_mover_manager_update(track_mover_manager, dt);`
   - With: `track_mover_manager_prepare_tasks()` → `submit_tasks()` → `wait_all()`

## Thread Safety Analysis

**Safe operations (per mover):**
- Position update: writes to own MoverPhysics struct
- Segment transition: reads shared segment array (read-only)
- Payload line update: writes to unique World->lines[] indices
- Payload peg update: writes to unique World->pegs[] indices

**No conflicts because:**
- Each mover has exclusive ownership of its payload objects
- An object can only be payload for ONE mover (enforced by BFS detection)
- No two movers write to the same line/peg indices
- Segment array is read-only during updates

**Sequencing constraint:**
- Mover updates must complete BEFORE ball physics starts
- Ball physics reads line/peg positions that movers write
- Current sync point after `threadpool_wait_all()` satisfies this

## Rotor/Mover Parallelization Opportunity

Since rotors and movers write to disjoint sets of lines/pegs (an object cannot be connected to both), rotor and mover updates can run in parallel with each other:

```
rotor_manager_prepare_tasks() + track_mover_manager_prepare_tasks()
rotor_manager_submit_tasks()
track_mover_manager_submit_tasks()
threadpool_wait_all()  // Single sync point for both
// Then ball physics
```

## Files to Modify

- `src/052-track-mover.h` - Add MoverTaskData, extend TrackMoverManager
- `src/053-track-mover.c` - Add task functions, modify memory allocation
- `src/001-main.c` - Update mover update call to use task pattern

## Related Issues

- 902d - Track following physics (provides base implementation)
- 901h - Parallelize rotor updates (same pattern)
- Ball/particle parallelization (reference implementation in ball.c, particles.c)
