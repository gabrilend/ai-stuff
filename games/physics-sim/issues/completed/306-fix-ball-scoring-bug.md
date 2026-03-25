# Issue 506: Fix Ball Scoring/Disappearing Bug

## Current Behavior

Balls don't disappear immediately when entering score zones. Instead, they
flash in and out of existence, repeatedly triggering:
- Particle effects (multiple bursts per ball)
- Score increments (inflating score incorrectly)

This creates visual flickering and incorrect scoring.

## Intended Behavior

When a ball enters a score zone:
1. Ball is immediately and permanently deactivated
2. Score is added exactly once
3. Particles spawn exactly once
4. Ball never reappears

## Root Cause Analysis

Likely causes:
1. Double-buffering issue: ball deactivated in next buffer but still active
   in current buffer on next frame
2. Zone detection happens before deactivation propagates
3. Race condition between scoring and buffer swap

## Suggested Implementation Steps

1. Investigate ball_update_task() and ball_check_zone() interaction
   - Verify ball is deactivated in correct buffer
   - Ensure deactivation persists across buffer swap

2. Check if deactivation in balls_next is properly preserved after swap

3. Consider alternative approaches:
   - Mark ball with "scored" flag to prevent re-scoring
   - Check if ball was active in PREVIOUS frame before scoring
   - Only score balls that transition from active to inactive

4. Add safeguard: skip zone detection for balls that scored recently
   - Could use a "just_scored" frame counter

5. Test with multiple balls scoring simultaneously

6. Verify particle spawning uses correct (single) trigger

7. Test compilation with no warnings

## Design Notes

The double-buffer system swaps pointers each frame:
- balls_current becomes balls_next
- balls_next becomes balls_current

If a ball is deactivated in balls_next, after swap it becomes balls_current.
But if the NEXT frame's balls_next still has the ball active (from previous
current), the ball could "come back".

Need to ensure both buffers are consistent when a ball is deactivated.

## Success Criteria

- Balls disappear immediately on zone entry
- Score increments exactly once per ball
- Particles spawn exactly once per ball
- No visual flickering
- Compiles with no warnings

## Related Documents

- [006-ball.h](../src/006-ball.h)
- [007-ball.c](../src/007-ball.c)

## Dependencies

- Phase 5 complete

## Implementation Notes

Found and fixed the root cause of the ball flickering/multiple scoring bug:

**Root Cause:**
The `scored` flag in BallTaskData was never reset for inactive balls. When a ball
scored and became inactive:
1. Task set `scored=1` and deactivated ball
2. `ball_manager_collect_scores()` only reset `score_delta`, not `scored`
3. Next frame: no task submitted for inactive ball
4. `scored` flag persisted as 1 forever
5. Particle loop saw `scored=1` every frame, spawning infinite particles

**Fix:**
1. Modified `ball_manager_collect_scores()` in src/007-ball.c:460
   - Now resets both `score_delta` AND `scored` for all task entries
   - Ensures inactive balls don't have stale scoring flags

2. Reordered main loop in src/001-main.c:133
   - Moved particle spawning BEFORE `ball_manager_collect_scores()`
   - Particles must spawn while `scored` and `score_delta` are still valid
   - Sequence is now: wait → spawn particles → collect scores → finalize

Compilation tested: No warnings.

### Additional Fix (Session 2)

**Problem Persisted:**
The initial fix addressed `scored` flag persistence but balls still flickered.

**True Root Cause:**
When a ball becomes inactive, no task is submitted for it on subsequent frames.
But `balls_next` retained a stale `active=1` from a previous frame. After swap:
1. Frame N: Ball scores, `next[i].active = 0`
2. Swap: `current[i] = 0`, `next[i]` has stale value (active=1 from N-1)
3. Frame N+1: No task submitted (current inactive), `next[i]` unchanged
4. Swap: `current[i] = 1` (the stale value!) - ball resurrects!
5. Frame N+2: Task submitted, ball scores AGAIN

**Fix:**
In `ball_manager_prepare_tasks()`, explicitly propagate inactive state:
```c
if (!manager->balls_current[i].active) {
    manager->balls_next[i].active = 0;
}
```

This ensures inactive balls stay inactive in both buffers, preventing resurrection.

## Status

- [x] Complete
