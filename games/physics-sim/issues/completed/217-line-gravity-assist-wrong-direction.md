# 217 - Line Gravity Assist Wrong Direction

## Status: Complete

## Current Behavior

When a ball slides on a diagonal line, the gravity assist sometimes pushes the ball upward instead of downward. This causes balls to suddenly reverse direction and shoot up the line at high speed.

The gravity assist direction is based on the line's coordinate order (x1,y1 → x2,y2), not the actual downhill direction. If a line was drawn "upward" in the editor (y1 > y2), the gravity assist vector points UP.

## Intended Behavior

The gravity assist should always push balls in the downhill direction:
- Player balls: downhill = positive Y (toward bottom of screen)
- Adversary balls: downhill = negative Y (toward top of screen, since they have inverted gravity)

## Root Cause

In `src/007-ball.c:478-487`:
```c
float lx = line->x2 - line->x1;
float ly = line->y2 - line->y1;
// ... uses (lx, ly) directly without checking if it points downhill
```

## Suggested Implementation Steps

1. Calculate line tangent vector
2. Check if tangent points in the ball's "downhill" direction (based on ball owner)
3. If not, negate the tangent to point downhill
4. Apply gravity assist along corrected tangent

## Files Modified

- `src/007-ball.c` - ball_collide_with_line function

## Implementation

Added logic to check if the line tangent points in the ball's downhill direction.
Uses `ball->gravity_dir` to determine downhill:
- Player balls: `gravity_dir = +1.0`, downhill = positive Y
- Adversary balls: `gravity_dir = -1.0`, downhill = negative Y

If `ty * ball->gravity_dir < 0`, the tangent points uphill, so we negate it before applying the gravity assist.

```c
// If tangent points against gravity (uphill), flip it
if (ty * ball->gravity_dir < 0) {
    tx = -tx;
    ty = -ty;
}
```

## Related Issues

- 1217 - Unify line and ramp abstraction
