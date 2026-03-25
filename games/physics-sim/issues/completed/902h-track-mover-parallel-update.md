# 902h - Parallelize Track Mover Updates

## Status: completed

## Depends on

- 902d ✓ (Track following physics)
- 902c ✓ (Mover payload detection)

## Problem

The `track_mover_manager_update()` function currently runs sequentially on a single thread, iterating over all movers one at a time. Each mover's update is independent of others (each has its own segment position and payload objects), making this an ideal parallelization candidate.

## Implementation Summary

Added parallel mover updates following the ball/particle/rotor task pattern:

### Changes to src/052-track-mover.h

1. Added `#include "003-threadpool.h"`
2. Added forward declaration for `TrackMoverManager`
3. Added `MoverTaskData` struct with mover pointer, manager reference, and dt
4. Extended `TrackMoverManager` with `task_data` array and `task_data_capacity`
5. Added function declarations:
   - `track_mover_manager_prepare_tasks(TrackMoverManager*, float dt)`
   - `track_mover_manager_submit_tasks(TrackMoverManager*, ThreadPool*)`

### Changes to src/053-track-mover.c

1. Updated `track_mover_manager_create()` to initialize task_data fields
2. Updated `track_mover_manager_destroy()` to free task_data
3. Added `mover_update_task()` - static task function for single mover
4. Added `track_mover_manager_prepare_tasks()` - allocates and populates task data
5. Added `track_mover_manager_submit_tasks()` - submits tasks to threadpool

### Changes to src/001-main.c

Updated game loop to use parallel pattern for both rotors and movers:
- All rotor and mover tasks prepared together
- All tasks submitted to threadpool together
- Single `threadpool_wait_all()` sync point before ball physics

## Thread Safety

Each mover writes to disjoint sets of lines/pegs (enforced by BFS detection in 902c). No two movers write to the same object indices, so parallel updates are safe.

## Rotor/Mover Parallelization

Since rotors and movers write to disjoint object sets (an object cannot be connected to both a rotor and a mover), both systems can run in parallel:

1. Prepare all rotor and mover tasks
2. Submit all tasks to threadpool
3. Single `wait_all()` before ball physics

This maximizes parallelism while maintaining correctness.

## Files Modified

- `src/052-track-mover.h` - Added MoverTaskData, extended TrackMoverManager
- `src/053-track-mover.c` - Added task functions, updated memory management
- `src/001-main.c` - Updated to use parallel rotor/mover pattern
