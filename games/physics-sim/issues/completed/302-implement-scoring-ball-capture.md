# Issue 502: Implement Scoring and Ball Capture

## Current Behavior

Ball zone detection exists (Issue 501), but no scoring occurs. Balls that
enter zones continue moving and eventually deactivate off-screen. The
world->score field exists but is never incremented.

## Intended Behavior

When a ball enters a score zone:
1. Ball is deactivated (captured by zone)
2. Zone point value is added to world->score
3. Score display updates automatically (already showing world->score)

The scoring must be thread-safe since ball updates happen in parallel.

## Suggested Implementation Steps

1. Add atomic or mutex-protected score update mechanism:
   - Option A: Use atomic increment (simple, lock-free)
   - Option B: Accumulate per-task, sum after parallel phase
   - Recommendation: Option B (cleaner, no atomics needed)

2. Add score_delta field to BallTaskData:
   ```c
   typedef struct BallTaskData {
       // ... existing fields ...
       int score_delta;  // Points scored during this task
   } BallTaskData;
   ```

3. Modify ball_update_task() to check zones and set score_delta:
   - Call ball_check_zone() after physics/collisions
   - If zone detected: deactivate ball, set score_delta to zone points
   - If no zone: score_delta = 0

4. Create ball_manager_collect_scores() function:
   ```c
   // {{{ ball_manager_collect_scores
   // Collects score deltas from all tasks after parallel phase.
   // Call after threadpool_wait_all() and before finalize_update().
   // Returns total points scored this frame.
   //
   // Parameters:
   //   manager: BallManager instance
   //
   // Returns:
   //   Total points scored this frame
   int ball_manager_collect_scores(BallManager* manager);
   // }}}
   ```

5. Update main loop to collect and apply scores:
   ```c
   threadpool_wait_all(pool);
   int points = ball_manager_collect_scores(ball_manager);
   world->score += points;
   ball_manager_finalize_update(ball_manager);
   ```

6. Update src/006-ball.h with new field and function

7. Update src/006-ball.info.md documentation

8. Test compilation with no warnings

## Design Notes

Why accumulate then sum:
- Avoids atomic operations in hot path
- Each task writes only to its own score_delta
- Single-threaded sum after parallel phase
- Clean separation of concerns

Score update timing:
- Happens after wait_all() (all tasks complete)
- Before finalize_update() (count active balls)
- Before swap_buffers() (prepare for render)

Ball deactivation in zone:
- Set ball->active = 0 in ball_update_task()
- finalize_update() will count correctly (ball inactive)
- No separate deactivation needed

Zone point values (from Phase 2):
- Center zones: higher points (100, 200)
- Edge zones: lower points (10, 25, 50)
- Already defined in world_generate_zones()

## Success Criteria

- Balls are captured when entering score zones
- Correct point values added to world->score
- Score display updates in real-time
- Thread-safe (no race conditions)
- Works with parallel ball processing
- Compiles with no warnings

## Related Documents

- [004-world.h](../src/004-world.h)
- [006-ball.h](../src/006-ball.h)
- [007-ball.c](../src/007-ball.c)

## Dependencies

- Issue 501 (Score zone detection) - Required

## Implementation Notes

Implemented scoring system with thread-safe score accumulation:

1. Added score_delta field to BallTaskData in src/006-ball.h:57
   - Each task tracks points scored independently
   - Initialized to 0 at start of ball_update_task()

2. Modified ball_update_task() in src/007-ball.c:350
   - Initializes score_delta to 0 each frame
   - Calls ball_check_zone() after physics and collisions
   - Sets score_delta to zone points when ball captured
   - Deactivates ball when captured (next->active = 0)

3. Implemented ball_manager_collect_scores() in src/007-ball.c:412
   - Sums all score_delta values from task data
   - Resets score_delta to 0 for next frame
   - Thread-safe: called after threadpool_wait_all()

4. Updated main loop in src/001-main.c:95
   - Calls ball_manager_collect_scores() after wait_all()
   - Adds collected points to world->score
   - Sequence: prepare → submit → wait → collect scores → finalize → swap

5. Updated documentation in src/006-ball.info.md:156
   - Added ball_manager_collect_scores() API documentation
   - Updated BallTaskData documentation with score_delta field
   - Documented thread-safety guarantees

Thread-safe design: Each task writes only to its own score_delta field during
parallel execution. Main thread sums all deltas after synchronization point
(threadpool_wait_all). No atomics or locks needed.

Score display updates automatically since world->score is used in render loop.
Balls are captured and removed when they land in zones.

Compilation tested: No warnings.

## Status

- [x] Complete
