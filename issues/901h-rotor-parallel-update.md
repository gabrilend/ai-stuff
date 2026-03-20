# 901h - Parallelize Rotor Updates

## Status: awaiting-work

## Depends on

- 901c ✓ (Line rotation physics)
- 901d ✓ (Connected object detection)

## Problem

The `rotor_manager_update()` function currently runs sequentially on a single thread, iterating over all rotors one at a time. With many rotors on a board, this becomes a bottleneck. Each rotor's update is mathematically independent of others (each has its own connected objects), making this an ideal parallelization candidate.

## Current Behavior

In `src/044-rotor.c` lines 237-294:
```c
void rotor_manager_update(RotorManager* manager, float dt) {
    for (int r = 0; r < manager->rotor_count; r++) {
        RotorPhysics* rotor = &manager->rotors[r];
        // Update angle
        rotor->current_angle += rotor->rotation_speed * dt;
        // Update connected line positions (inner loop)
        // Update connected peg positions (inner loop)
    }
}
```

Each rotor:
1. Updates its angle
2. Iterates over connected lines, computing new positions via polar-to-cartesian
3. Iterates over connected pegs, computing new positions

All operations are independent per-rotor.

## Intended Behavior

Parallel rotor updates following the same pattern as ball/particle systems:

1. Create `RotorTaskData` structure to hold per-task context
2. Pre-allocate task data array in `RotorManager`
3. Add `rotor_manager_prepare_tasks()` to set up task data
4. Add `rotor_manager_submit_tasks()` to submit to threadpool
5. Task function `rotor_update_task()` handles single rotor
6. Main loop: prepare → submit → wait_all

## Suggested Implementation Steps

1. **Add task data structure** to `src/044-rotor.h`:
   ```c
   typedef struct {
       RotorPhysics* rotor;
       World* world;
       float dt;
   } RotorTaskData;
   ```

2. **Extend RotorManager** with task array:
   ```c
   // Add to RotorManager struct:
   RotorTaskData* task_data;
   int task_data_capacity;
   ```

3. **Create rotor_update_task function**:
   - Receives `void* arg` cast to `RotorTaskData*`
   - Performs angle update and connected object position updates
   - Same logic as current inner loop, just on single rotor

4. **Add rotor_manager_prepare_tasks()**:
   - Ensures task_data array has capacity for rotor_count
   - Populates each RotorTaskData with rotor pointer, world, dt

5. **Add rotor_manager_submit_tasks()**:
   - Loops over task_data, creates Task for each
   - Submits to threadpool via `threadpool_submit()`

6. **Update main.c** integration:
   - Replace `rotor_manager_update(rotor_manager, dt);`
   - With: `rotor_manager_prepare_tasks()` → `submit_tasks()` → `wait_all()`

## Thread Safety Analysis

**Safe operations (per rotor):**
- Angle update: writes to own RotorPhysics struct
- Line position update: writes to unique World->lines[] indices (connected_line_indices)
- Peg position update: writes to unique World->pegs[] indices (connected_peg_indices)

**No conflicts because:**
- Each rotor has exclusive ownership of its connected objects
- An object can only be connected to ONE rotor (enforced by BFS detection)
- No two rotors write to the same line/peg indices

**Sequencing constraint:**
- Rotor updates must complete BEFORE ball physics starts
- Ball physics reads line/peg positions that rotors write
- Current sync point after `threadpool_wait_all()` satisfies this

## Files to Modify

- `src/044-rotor.h` - Add RotorTaskData, extend RotorManager
- `src/044-rotor.c` - Add task functions, modify memory allocation
- `src/001-main.c` - Update rotor update call to use task pattern

## Related Issues

- 901c - Line rotation physics (provides base implementation)
- 902h - Parallelize track mover updates (same pattern)
- Ball/particle parallelization (reference implementation in ball.c, particles.c)
