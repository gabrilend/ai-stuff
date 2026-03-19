# 220 - Velocity-Dependent Restitution

## Status: Complete

## Problem

Balls quiver in buckets and low-speed areas due to constant restitution causing tiny bounces each frame. The gravity assist system (added to help balls slide along lines) is not physically realistic.

## Solution

Implement velocity-dependent collision response:
- Below a threshold closing speed (~75 px/sec): restitution = 0, friction = near-zero
- Above threshold: normal restitution and friction

This achieves:
1. Balls settle naturally in buckets without quivering
2. Low-speed impacts slide instead of bouncing
3. High-speed impacts retain normal bounce behavior
4. More physically realistic collision response

## Implementation

- Add `LOW_SPEED_THRESHOLD` (75 px/sec) and `LOW_SPEED_FRICTION` (0.05) constants
- Update `ball_resolve_peg_collision` to check closing speed
- Update `ball_collide_with_line` to check closing speed, remove gravity assist
- Update `ball_resolve_bumper_collision` to check closing speed
- Update `ball_resolve_ball_collision` to check closing speed
- Remove `TERMINAL_VELOCITY` constant (only used by gravity assist)

## Files Modified

- `src/006-ball.h` - Add new constants, remove TERMINAL_VELOCITY
- `src/007-ball.c` - Update all collision functions

## Related Issues

- Replaces gravity assist from line collisions
