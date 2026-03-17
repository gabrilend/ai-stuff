# Issue 405: Create Performance Benchmark

## Current Behavior

No performance measurement infrastructure exists. Cannot verify that
parallel processing provides a speedup over sequential processing.
No way to compare different thread counts.

## Intended Behavior

Performance benchmarking system that measures:
- Frame time (milliseconds per frame)
- Physics update time (excluding rendering)
- Ball count vs performance curve
- Comparison between sequential and parallel modes

Display performance statistics in the application window and/or
console output for analysis.

## Suggested Implementation Steps

1. Add timing fields to BallManager or create separate stats struct:
   ```c
   typedef struct PhysicsStats {
       double physics_time_ms;    // Time for physics update
       double avg_physics_time;   // Rolling average
       int frame_count;           // Frames for averaging
   } PhysicsStats;
   ```

2. Implement timing measurement in main loop:
   ```c
   // Before physics
   double start = GetTime();  // raylib high-precision timer

   // Physics update (parallel)
   ball_manager_prepare_tasks(...);
   ball_manager_submit_tasks(...);
   threadpool_wait_all(...);
   ball_manager_finalize_update(...);
   ball_manager_swap_buffers(...);

   // After physics
   double end = GetTime();
   double physics_ms = (end - start) * 1000.0;
   ```

3. Add performance display to screen:
   ```c
   char perf_text[64];
   sprintf(perf_text, "Physics: %.2f ms", physics_ms);
   DrawText(perf_text, 10, screen_height - 70, 16, WHITE);

   sprintf(perf_text, "FPS: %d", GetFPS());
   DrawText(perf_text, 10, screen_height - 90, 16, WHITE);
   ```

4. Add thread count display:
   ```c
   sprintf(perf_text, "Threads: %d", pool->thread_count);
   DrawText(perf_text, 10, screen_height - 110, 16, WHITE);
   ```

5. Optional: Add sequential mode toggle for comparison:
   - Key press to toggle between parallel and sequential
   - Display current mode on screen
   - Compare physics times between modes

6. Optional: Console output for benchmarking:
   - Print stats every N frames
   - Allow running headless for pure timing tests

7. Update documentation with benchmark results

## Design Notes

Timing approach:
- GetTime() returns seconds as double
- Multiply by 1000 for milliseconds
- Rolling average smooths per-frame variance
- Measure only physics, not rendering

Expected results:
- Sequential: ~constant time regardless of thread count
- Parallel: time decreases with more threads (up to a point)
- Overhead crossover: parallel faster above ~N balls

Performance targets:
- 256 balls at 60fps = 16.67ms total frame budget
- Physics should use <8ms of that budget
- Parallel should show improvement with >50 balls

Benchmark methodology:
- Spawn consistent number of balls
- Measure steady-state (after balls spread out)
- Average over 60+ frames for stable readings

## Success Criteria

- Physics update time displayed on screen
- FPS counter displayed
- Thread count displayed
- Ball count already displayed (from Phase 3)
- Parallel mode shows improvement over sequential
- Stable 60fps with 256 balls
- No performance regressions from instrumentation

## Related Documents

- [001-main.c](../src/001-main.c)
- [004-raylib-integration.md](../docs/004-raylib-integration.md)

## Dependencies

- Issue 404 (parallel integration complete) - Required

## Status

- [ ] Pending
