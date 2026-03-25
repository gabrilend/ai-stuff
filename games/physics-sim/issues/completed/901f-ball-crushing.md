# 901f - Ball Stress and Crushing

## Status: Complete

## Parent Issue: 901 - Rotor System

## Problem

When a ball is trapped between a rotating structure and static geometry (or two moving structures), it should be crushed and destroyed rather than causing physics glitches.

## Implementation

### Dynamic Object Tracking

Added `is_dynamic` field to Peg and Line structs:
- `src/004-world.h:58` - Added `is_dynamic` to Peg struct
- `src/004-world.h:108` - Added `is_dynamic` to Line struct

The flag is propagated from BoardData when objects are created:
- `src/001-main.c:207-208` - Player pegs get `is_dynamic` from BoardObject
- `src/001-main.c:241-242` - Player lines get `is_dynamic` from BoardObject
- `src/001-main.c:315-316` - Adversary pegs get `is_dynamic`
- `src/001-main.c:355-356` - Adversary lines get `is_dynamic`

### Stress Accumulation

Collision functions now distinguish between static and dynamic sources:
- `ball_resolve_peg_collision()` calls `ball_accumulate_dynamic_stress()` for dynamic pegs
- `ball_collide_with_line()` calls `ball_accumulate_dynamic_stress()` for dynamic lines

The existing stress system from 221e already tracks:
- `Ball.static_stress` - harmless accumulation from static geometry
- `Ball.dynamic_stress` - dangerous accumulation from moving objects
- `CRUSH_THRESHOLD` (50.0f) - threshold for crushing

### Crushing Logic

In `ball_accumulate_dynamic_stress()` (src/007-ball.c:344-361):
```c
if (ball->dynamic_stress > CRUSH_THRESHOLD) {
    ball->active = 0;
    ball->health = 0;
    return 1;  // Ball was crushed
}
```

## Implementation Steps Completed

1. ✓ Stress tracking already in Ball struct (from 221e)
2. ✓ Added is_dynamic flag to Peg and Line structs
3. ✓ Propagate is_dynamic from BoardData to runtime objects
4. ✓ Modified collision functions to use dynamic stress for dynamic objects
5. ✓ Trigger crushing when dynamic_stress exceeds CRUSH_THRESHOLD
6. ✗ Particle effect - balls just disappear (future enhancement)

## Files Modified

- `src/004-world.h` - Added `is_dynamic` to Peg and Line structs
- `src/001-main.c` - Propagate `is_dynamic` flag when creating pegs/lines from BoardData
- `src/007-ball.c` - Modified collision functions and crushing check

## Testing

1. Create a board with a rotor and a nearby wall
2. Drop a ball between the rotating arm and the wall
3. Ball should disappear when crushed (dynamic_stress exceeds threshold)

## Future Work

- Add crushing particle effect (squish burst)
- Consider brief invulnerability after near-crush
- Track mover crushing (issue 902g) uses same system

## Notes

- Same crushing system will be used for track movers
- Dynamic stress decays each frame (DYNAMIC_STRESS_DECAY = 0.8f)
- Static stress is harmless - balls in piles won't crush each other
