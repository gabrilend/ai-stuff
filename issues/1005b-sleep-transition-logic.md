# 1307b - Sleep Transition Logic

## Status: Open

## Parent Issue: 1307 - Ball Sleep System

## Problem

Need logic to transition balls from awake→sleeping when at rest, with proper hysteresis to prevent flickering.

## Implementation

### Update Function

```c
void ball_update_sleep_state(Ball* ball) {
    if (ball->is_sleeping) {
        // Sleeping balls don't update here - wake handled separately
        return;
    }

    // Calculate current speed
    float speed = sqrtf(ball->vx * ball->vx + ball->vy * ball->vy);

    if (speed < SLEEP_VELOCITY_THRESHOLD) {
        ball->frames_at_rest++;

        if (ball->frames_at_rest >= SLEEP_FRAME_DELAY) {
            // Transition to sleep
            ball_enter_sleep(ball);
        }
    } else {
        // Moving - reset counter
        ball->frames_at_rest = 0;
    }
}

void ball_enter_sleep(Ball* ball) {
    ball->is_sleeping = 1;
    ball->pre_sleep_velocity = sqrtf(ball->vx * ball->vx + ball->vy * ball->vy);

    // Zero out velocity to prevent drift
    ball->vx = 0.0f;
    ball->vy = 0.0f;

    // Optional: snap to stable position
    // ball->x = roundf(ball->x);
    // ball->y = roundf(ball->y);
}
```

### When to Call

```c
void game_update() {
    // Physics step
    for each ball:
        if (!ball->is_sleeping) {
            apply_gravity(ball);
            update_position(ball);
            handle_collisions(ball);
        }
        ball_update_sleep_state(ball);
}
```

## Transition Diagram

```
                    velocity < threshold
    ┌─────────┐     for N frames        ┌──────────┐
    │  AWAKE  │ ──────────────────────► │ SLEEPING │
    └─────────┘                         └──────────┘
         ▲                                    │
         │         collision or               │
         │         external force             │
         └────────────────────────────────────┘
```

## Edge Cases

### Ball barely moving in circle
- Small velocity but never truly at rest
- frames_at_rest keeps resetting
- Solution: This is correct behavior - it IS moving

### Ball vibrating in place
- Alternating tiny velocities
- frames_at_rest fluctuates
- Solution: Use velocity magnitude, not components

### Ball sliding very slowly
- Takes long time to sleep
- Solution: Increase threshold or decrease delay

## Implementation Steps

1. Implement ball_update_sleep_state()
2. Implement ball_enter_sleep()
3. Call from game loop after physics
4. Test with single ball coming to rest
5. Test with pile of balls

## Files to Modify

- `src/007-ball.c` - Sleep transition functions
- `src/001-main.c` - Call sleep update in loop

## Troubleshooting

### "Ball takes too long to sleep"
- Decrease SLEEP_FRAME_DELAY (try 15-20)
- Increase SLEEP_VELOCITY_THRESHOLD (try 1.0)
- Check for micro-vibrations keeping it awake

### "Ball sleeps too quickly"
- Increase SLEEP_FRAME_DELAY (try 45-60)
- Decrease SLEEP_VELOCITY_THRESHOLD (try 0.3)

### "Ball 'pops' when entering sleep"
- Don't zero velocity if it causes position snap
- Or: zero velocity gradually over few frames
- Check position snapping isn't too aggressive

### "Pile still unstable before sleeping"
- Sleep delay may be too long
- Balls explode before reaching sleep threshold
- Need soft collision (1307d) to stabilize pre-sleep

## Notes

- SLEEP_FRAME_DELAY provides hysteresis
- Zeroing velocity prevents drift after sleep
- May need to tune thresholds based on gameplay feel
