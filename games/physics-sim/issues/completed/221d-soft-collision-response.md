# 221d - Soft Collision Response for Piles

## Status: completed

## Depends on

None - implemented independently. Works in conjunction with 221a-c sleep system.

## Parent Issue: 221 - Ball Sleep System

## Problem

Even before balls sleep, pile instability occurs because standard collision response adds energy. Need softer response when balls are nearly stationary.

## The Energy Problem

Standard collision:
```
overlap detected → apply impulse → ball gains velocity → repeat
```

In a pile, many overlaps exist simultaneously. Each collision resolution adds energy, leading to explosion.

## Solution: Position-Based Separation

Instead of velocity impulses, gently push balls apart:

```c
void resolve_pile_collision(Ball* a, Ball* b) {
    float dx = b->x - a->x;
    float dy = b->y - a->y;
    float dist = sqrtf(dx*dx + dy*dy);
    float min_dist = BALL_RADIUS * 2;

    if (dist >= min_dist) return;  // No overlap

    float overlap = min_dist - dist;

    // Normalize direction
    float nx = dx / dist;
    float ny = dy / dist;

    // Soft push - position adjustment, not velocity
    float push_factor = 0.3f;  // Gentle (0.0 to 1.0)
    float push = overlap * push_factor * 0.5f;  // Split between both balls

    a->x -= nx * push;
    a->y -= ny * push;
    b->x += nx * push;
    b->y += ny * push;
}
```

## When to Use Soft vs Standard Collision

```c
void handle_ball_ball_collision(Ball* a, Ball* b) {
    // Both sleeping - skip entirely
    if (a->is_sleeping && b->is_sleeping) {
        return;
    }

    // Both nearly stationary - soft collision
    float speed_a = sqrtf(a->vx*a->vx + a->vy*a->vy);
    float speed_b = sqrtf(b->vx*b->vx + b->vy*b->vy);

    if (speed_a < SOFT_COLLISION_THRESHOLD && speed_b < SOFT_COLLISION_THRESHOLD) {
        resolve_pile_collision(a, b);
        return;
    }

    // One or both moving fast - standard bouncy collision
    resolve_standard_collision(a, b);
}
```

## Hybrid Approach

Blend between soft and standard based on velocity:

```c
void resolve_collision_blended(Ball* a, Ball* b) {
    float max_speed = fmaxf(
        sqrtf(a->vx*a->vx + a->vy*a->vy),
        sqrtf(b->vx*b->vx + b->vy*b->vy)
    );

    // Blend factor: 0 = pure soft, 1 = pure standard
    float blend = fminf(max_speed / BLEND_THRESHOLD, 1.0f);

    if (blend < 0.1f) {
        resolve_pile_collision(a, b);
    } else if (blend > 0.9f) {
        resolve_standard_collision(a, b);
    } else {
        // Blend both responses
        resolve_pile_collision(a, b);      // Position adjustment
        resolve_standard_collision_damped(a, b, 1.0f - blend);  // Reduced impulse
    }
}
```

## Constants

```c
#define SOFT_COLLISION_THRESHOLD 2.0f    // Below this, use soft collision
#define BLEND_THRESHOLD 5.0f             // Full standard collision above this
#define PILE_PUSH_FACTOR 0.3f            // How fast to separate (0.1 to 0.5)
```

## Implementation Steps

1. Implement resolve_pile_collision() with position-based separation
2. Add velocity check in collision handler
3. Route to appropriate collision type
4. Test with pile building up
5. Tune PILE_PUSH_FACTOR for natural settling

## Files to Modify

- `src/007-ball.c` - Add soft collision, modify collision routing

## Troubleshooting

### "Balls still explode before sleeping"
- SOFT_COLLISION_THRESHOLD too low
- Try 3.0 or 4.0
- Or: always use soft collision for pile situations

### "Balls separate too slowly, overlap visible"
- PILE_PUSH_FACTOR too low
- Try 0.5 or higher
- Balance: too high = jittery, too low = overlapping

### "Balls jitter in pile"
- PILE_PUSH_FACTOR too high
- Overshooting separation
- Try 0.2 or lower

### "Fast ball doesn't bounce off pile"
- Soft collision being used incorrectly
- Check velocity threshold logic
- Fast ball should trigger standard collision

### "Pile looks 'mushy' or unnatural"
- Position-based separation is visible
- Reduce push factor
- Add slight damping to velocity

## Notes

- Soft collision is key to pre-sleep stability
- Without it, balls may explode before sleep threshold
- Works in conjunction with sleep system, not replacement
- Consider: soft collision might be enough without sleep for small piles

## Implementation Notes (2026-03-19)

### Changes Made

1. **src/006-ball.h**:
   - Added soft collision constants: `SOFT_COLLISION_THRESHOLD`, `BLEND_THRESHOLD`, `PILE_PUSH_FACTOR`

2. **src/007-ball.c**:
   - Added `ball_resolve_pile_collision()` function for position-based separation
   - Modified `ball_resolve_ball_collision()` to route between soft and standard collision
   - Implemented velocity-based blending for smooth transition between modes

### Design Decisions

- Soft collision uses position-based separation only (no velocity impulses)
- Speed threshold of 2.0 px/s for pure soft collision
- Blend threshold of 5.0 px/s for transition to full standard collision
- Linear blending between thresholds scales impulse magnitude
- Push factor of 0.3 provides gentle separation without jitter

### Blocking Bug Fix

Also fixed compilation errors in zone-dispatch.h/c (issue 318):
- Renamed ZoneType to DispatchZoneType to avoid conflict with board-data.h
- Added missing #include <stdint.h> for uint8_t type
