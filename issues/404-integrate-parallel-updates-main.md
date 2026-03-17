# Issue 404: Integrate Parallel Updates in Main Loop

## Current Behavior

Main loop uses sequential ball_manager_update():
```c
while (!WindowShouldClose()) {
    float dt = GetFrameTime();
    ball_manager_update_cooldown(ball_manager, dt);

    if (IsKeyDown(KEY_SPACE) && ball_manager_can_spawn(ball_manager)) {
        ball_manager_spawn(ball_manager, SPAWN_X, SPAWN_Y);
        ball_manager_reset_cooldown(ball_manager);
    }

    ball_manager_update(ball_manager, world, dt);  // Sequential
    ball_manager_swap_buffers(ball_manager);

    // Render...
}
```

The threadpool is created but never used for ball physics.

## Intended Behavior

Main loop uses parallel ball updates via threadpool:
```c
while (!WindowShouldClose()) {
    float dt = GetFrameTime();
    ball_manager_update_cooldown(ball_manager, dt);

    if (IsKeyDown(KEY_SPACE) && ball_manager_can_spawn(ball_manager)) {
        ball_manager_spawn(ball_manager, SPAWN_X, SPAWN_Y);
        ball_manager_reset_cooldown(ball_manager);
    }

    // Parallel ball physics
    ball_manager_prepare_tasks(ball_manager, world, dt);
    ball_manager_submit_tasks(ball_manager, pool);
    threadpool_wait_all(pool);
    ball_manager_finalize_update(ball_manager);
    ball_manager_swap_buffers(ball_manager);

    // Render...
}
```

## Suggested Implementation Steps

1. Modify src/001-main.c includes:
   - Ensure all required headers are included (already should be)

2. Replace ball_manager_update() call with parallel sequence:
   ```c
   // Parallel ball physics update
   ball_manager_prepare_tasks(ball_manager, world, dt);
   ball_manager_submit_tasks(ball_manager, pool);
   threadpool_wait_all(pool);
   ball_manager_finalize_update(ball_manager);
   ball_manager_swap_buffers(ball_manager);
   ```

3. Verify threadpool passes to ball manager functions:
   - pool variable already exists in main()
   - Pass to ball_manager_submit_tasks()

4. Keep sequential fallback for debugging (optional):
   - Could add #ifdef PARALLEL_PHYSICS
   - Or command-line flag to toggle
   - For now, just use parallel path

5. Test with various ball counts:
   - Single ball
   - 10 balls
   - 100 balls
   - MAX_BALLS (256)

6. Verify visual behavior unchanged:
   - Balls fall under gravity
   - Balls bounce off pegs
   - Balls bounce off walls
   - Balls deactivate off-screen

7. Update any relevant comments in main.c

8. Test compilation with no warnings

## Design Notes

Why this integration pattern:
- Minimal changes to main loop structure
- Clear separation of phases (prepare, submit, wait, finalize, swap)
- Easy to toggle between parallel and sequential for debugging

Timing considerations:
- prepare_tasks: O(capacity) - fast
- submit_tasks: O(active_count) - one submit per active ball
- wait_all: blocks until all tasks complete
- finalize_update: O(capacity) - counts active balls
- swap_buffers: O(1) - pointer swap

Spawning during parallel phase:
- Spawning happens BEFORE prepare_tasks
- New balls included in current frame's parallel update
- No race condition: main thread has exclusive access before submit

## Success Criteria

- Main loop uses parallel ball physics
- Threadpool processes ball updates
- Visual behavior identical to sequential version
- No crashes, deadlocks, or race conditions
- Works with 0 balls (empty case)
- Works with MAX_BALLS (stress test)
- Compiles with no warnings

## Related Documents

- [001-main.c](../src/001-main.c)
- [002-threadpool-design.md](../docs/002-threadpool-design.md)

## Dependencies

- Issue 401 (BallTaskData structure) - Required
- Issue 402 (ball_update_task function) - Required
- Issue 403 (synchronization functions) - Required

## Status

- [ ] Pending
