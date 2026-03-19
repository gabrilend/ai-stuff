# 1307c - Wake Conditions

## Status: Open

## Parent Issue: 1307 - Ball Sleep System

## Problem

Sleeping balls need to wake up when something disturbs them, but not wake up from their own weight or other sleeping balls.

## Wake Triggers

| Trigger | Should Wake? | Notes |
|---------|--------------|-------|
| Awake ball collision | YES | Primary wake source |
| Sleeping ball collision | NO | Two sleeping balls stay asleep |
| Rotor/mover collision | YES | Dynamic objects always wake |
| External force (portal) | YES | Teleportation wakes |
| Gravity | NO | Sleeping = no gravity |
| Ground/wall contact | NO | Static geometry doesn't wake |

## Implementation

### Wake Function

```c
void ball_wake(Ball* ball) {
    if (!ball->is_sleeping) return;

    ball->is_sleeping = 0;
    ball->frames_at_rest = 0;

    // Ball is now awake but has zero velocity
    // Gravity will start acting next frame
}

void ball_wake_with_impulse(Ball* ball, float impulse_x, float impulse_y) {
    ball_wake(ball);
    ball->vx += impulse_x;
    ball->vy += impulse_y;
}
```

### Collision Wake Check

```c
void handle_ball_ball_collision(Ball* a, Ball* b) {
    // Both sleeping - no collision at all
    if (a->is_sleeping && b->is_sleeping) {
        return;
    }

    // One awake, one sleeping - wake the sleeping one
    if (a->is_sleeping && !b->is_sleeping) {
        ball_wake_with_impulse(a, /* impulse from b */);
    }
    if (b->is_sleeping && !a->is_sleeping) {
        ball_wake_with_impulse(b, /* impulse from a */);
    }

    // Normal collision response
    resolve_collision(a, b);
}
```

### Cascade Wake (Optional)

When a ball wakes, should it wake neighbors?

```c
#define WAKE_RADIUS 1.5f  // Ball diameters

void ball_wake_cascade(Ball* ball, Ball* all_balls, int count) {
    ball_wake(ball);

    // Wake nearby sleeping balls
    for (int i = 0; i < count; i++) {
        Ball* other = &all_balls[i];
        if (other == ball) continue;
        if (!other->is_sleeping) continue;

        float dx = other->x - ball->x;
        float dy = other->y - ball->y;
        float dist = sqrtf(dx*dx + dy*dy);

        if (dist < WAKE_RADIUS * BALL_RADIUS * 2) {
            ball_wake(other);  // Don't cascade further to prevent chain reaction
        }
    }
}
```

## Dynamic Object Wake

```c
void handle_ball_rotor_collision(Ball* ball, Rotor* rotor) {
    // Always wake - dynamic objects disturb everything
    ball_wake(ball);

    // Apply rotor velocity
    Vector2 rotor_vel = get_rotor_velocity_at_point(rotor, ball->x, ball->y);
    ball->vx += rotor_vel.x;
    ball->vy += rotor_vel.y;

    // Track as dynamic stress (for crushing)
    ball->dynamic_stress += calculate_stress(rotor_vel);
}
```

## Implementation Steps

1. Implement ball_wake() and ball_wake_with_impulse()
2. Modify ball-ball collision to check sleep states
3. Add wake trigger for dynamic objects
4. Optional: implement cascade wake for realism
5. Test: drop ball on sleeping pile

## Files to Modify

- `src/007-ball.c` - Wake functions, collision modifications

## Troubleshooting

### "Sleeping balls wake for no reason"
- Check gravity isn't being applied
- Check no phantom collisions
- Verify static geometry doesn't trigger wake

### "Awake ball passes through sleeping pile"
- Sleeping balls must still be collision targets
- Only skip sleep-to-sleep collisions
- Check collision detection order

### "Cascade wake causes chain explosion"
- Cascade waking too many balls
- Reduce WAKE_RADIUS
- Or: remove cascade entirely, wake only direct contacts

### "Ball wakes but doesn't move"
- Wake gives zero velocity by default
- Impulse from collision should provide velocity
- Check impulse calculation

### "Pile wakes one ball at a time slowly"
- This might be desired behavior (realistic)
- If too slow, enable cascade wake
- Or: wake all touching balls instantly

## Notes

- Conservative approach: only wake direct collision contacts
- Aggressive approach: cascade wake with radius
- Start conservative, add cascade if piles feel "sticky"
