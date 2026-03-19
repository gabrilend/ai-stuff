# 902g - Track Mover Ball Interaction and Crushing

## Status: Open

## Parent Issue: 902 - Track Mover System

## Problem

Mover payload objects need to interact with balls, including pushing them and crushing them when trapped.

## Ball-Payload Collision

Payload objects (lines, pegs attached to mover) should:
1. Collide with balls normally
2. Transfer mover velocity to balls on collision
3. Push balls in direction of mover travel

### Velocity Transfer

When ball collides with moving payload:
```c
void ball_payload_collision(Ball* ball, PayloadObject* obj, TrackMover* mover) {
    // Get mover velocity
    Vector2 mover_vel = get_mover_velocity(mover);

    // Normal collision response
    Vector2 collision_normal = calculate_collision_normal(ball, obj);
    reflect_ball_velocity(ball, collision_normal);

    // Add mover velocity component
    ball->vx += mover_vel.x * PUSH_FACTOR;
    ball->vy += mover_vel.y * PUSH_FACTOR;
}
```

## Crushing

Same crushing mechanics as rotor (issue 1305f):
- Ball trapped between mover payload and static geometry
- Stress accumulates while trapped
- Ball destroyed when stress exceeds threshold

## Pass-Through for Static Objects

Same as rotor (issue 1305e):
- Payload passes through static (non-connected) objects
- Only balls experience collisions with payload
- Prevents mover getting stuck on board geometry

## Pushing Balls

Primary use case: clearing clogs
- Mover payload acts as "pusher" or "bucket"
- Can sweep balls out of stuck positions
- Creates dynamic gameplay

### Example Pusher Shape

```
    ___________
   |           |   <- Flat pusher attached to mover
   |___________|
        |
        |   <- Track
        |
```

## Implementation Steps

1. Reuse collision mode logic from rotor system
2. Implement mover velocity calculation
3. Add velocity transfer to ball collision
4. Integrate crushing mechanics (share with 1305f)
5. Test pushing behavior
6. Test crushing behavior

## Files to Modify

- `src/007-ball.c` - Collision with moving payload
- `src/0XX-track.c` - Mover velocity calculation

## Notes

- Shares significant code with rotor ball interaction
- Consider extracting "dynamic object" collision utility
- Pushing is the main gameplay purpose of movers
