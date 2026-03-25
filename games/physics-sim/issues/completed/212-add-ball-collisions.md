# Issue 508: Add Ball-to-Ball Collisions

## Current Behavior

Balls only collide with:
- Pegs (circle-circle collision)
- Walls (boundary collision)

Balls pass through each other, which looks unrealistic and breaks
physics immersion.

Additionally, balls can spawn on top of each other if the spawner
is triggered rapidly, causing physics glitches.

## Intended Behavior

1. Ball-to-ball collisions:
   - Balls bounce off each other realistically
   - Elastic collision response
   - Both balls affected by collision

2. Spawn blocking:
   - Don't spawn new balls if any ball is within spawner bounds
   - Prevents overlapping balls at spawn point
   - Prevents physics glitches from interpenetration

## Suggested Implementation Steps

1. Add ball-to-ball collision detection in ball_update_task():
   - Check distance between ball and all other active balls
   - Use circle-circle collision (similar to peg collision)

2. Implement collision response:
   - Calculate collision normal
   - Apply impulse to both balls (equal and opposite)
   - Separate balls to prevent overlap

3. Thread safety consideration:
   - Read from read_buffer (other balls' positions)
   - Write only to own ball in write_buffer
   - May need to handle same collision from both balls' perspectives

4. Add spawn blocking logic:
   - Check if any ball is within spawn radius
   - Return early from ball_manager_spawn() if blocked
   - Use larger detection radius than ball radius (safety margin)

5. Create helper function:
   ```c
   int ball_manager_spawn_blocked(BallManager* manager);
   ```

6. Update spawn input handling to check spawn_blocked

7. Test with many balls

8. Test compilation with no warnings

## Design Notes

Ball-to-ball collision is O(n²) per ball, which could be expensive.
Options:
- Accept O(n²) for now (256 balls max = 65536 checks)
- Optimize later with spatial partitioning if needed

For collision response, use same physics as peg collision but
apply to both balls. Each ball handles its own response.

Spawn blocking radius should be larger than ball radius to prevent
immediate collision after spawning.

## Success Criteria

- Balls bounce off each other
- No balls overlap significantly
- Spawner blocked when balls nearby
- Physics remains stable
- Performance acceptable (60fps with 100+ balls)
- Compiles with no warnings

## Related Documents

- [006-ball.h](../src/006-ball.h)
- [007-ball.c](../src/007-ball.c)

## Dependencies

- Issue 506 (ball bug fix should be first)

## Status

- [x] Complete

## Implementation Log

### Ball-to-Ball Collision System

Added three static functions to src/007-ball.c:

1. `ball_check_ball_collision()` - Detects circle-circle collision between two balls,
   returns collision normal and penetration depth.

2. `ball_resolve_ball_collision()` - Applies impulse-based collision response to the
   first ball only (each ball handles its own response from its own task).

3. `ball_collide_with_balls()` - Iterates through all other balls and handles
   collisions, called from ball_update_task().

Added `capacity` field to BallTaskData struct so each task knows total ball count
for the O(n) collision check loop.

### Spawn Blocking System

Added `ball_manager_spawn_blocked()` function that checks if any active ball is
within 3x ball radius of the spawn point. This prevents overlapping balls at spawn.

Updated main.c spawn logic to check both `ball_manager_can_spawn()` (cooldown/capacity)
and `!ball_manager_spawn_blocked()` before allowing spawn.

### Thread Safety

Each ball only writes to its own position in write_buffer. Collision reads from
read_buffer (immutable during frame). Both balls in a collision pair handle their
own response independently, which is correct for elastic collisions.
