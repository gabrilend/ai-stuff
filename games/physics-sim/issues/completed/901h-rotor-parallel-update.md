# 901h - Parallelize Rotor Updates

## Status: completed

## Depends on

- 901c ✓ (Line rotation physics)
- 901d ✓ (Connected object detection)

## Problem

The `rotor_manager_update()` function currently runs sequentially on a single thread, iterating over all rotors one at a time. With many rotors on a board, this becomes a bottleneck. Each rotor's update is mathematically independent of others (each has its own connected objects), making this an ideal parallelization candidate.

## Implementation Summary

Added parallel rotor updates following the ball/particle task pattern:

### Changes to src/044-rotor.h

1. Added `#include "003-threadpool.h"`
2. Added `RotorTaskData` struct with rotor pointer, world reference, and dt
3. Extended `RotorManager` with `task_data` array and `task_data_capacity`
4. Added function declarations:
   - `rotor_manager_prepare_tasks(RotorManager*, float dt)`
   - `rotor_manager_submit_tasks(RotorManager*, ThreadPool*)`

### Changes to src/044-rotor.c

1. Updated `rotor_manager_create()` to initialize task_data fields
2. Updated `rotor_manager_destroy()` to free task_data
3. Added `rotor_update_task()` - static task function for single rotor
4. Added `rotor_manager_prepare_tasks()` - allocates and populates task data
5. Added `rotor_manager_submit_tasks()` - submits tasks to threadpool

### Changes to src/001-main.c

Updated game loop to use parallel pattern:
```c
// Prepare all rotor/mover tasks
rotor_manager_prepare_tasks(world->rotor_manager, dt);
rotor_manager_prepare_tasks(world->adversary_rotor_manager, dt);
track_mover_manager_prepare_tasks(world->track_mover_manager, dt);
track_mover_manager_prepare_tasks(world->adversary_track_mover_manager, dt);

// Submit all tasks
rotor_manager_submit_tasks(world->rotor_manager, pool);
rotor_manager_submit_tasks(world->adversary_rotor_manager, pool);
track_mover_manager_submit_tasks(world->track_mover_manager, pool);
track_mover_manager_submit_tasks(world->adversary_track_mover_manager, pool);

// Single sync point before ball physics
threadpool_wait_all(pool);
```

## Thread Safety

Each rotor writes to disjoint sets of lines/pegs (enforced by BFS detection in 901d). No two rotors write to the same object indices, so parallel updates are safe.

## Files Modified

- `src/044-rotor.h` - Added RotorTaskData, extended RotorManager
- `src/044-rotor.c` - Added task functions, updated memory management
- `src/001-main.c` - Updated to use parallel rotor/mover pattern
