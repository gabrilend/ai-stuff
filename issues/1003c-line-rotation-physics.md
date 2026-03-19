# 1305c - Line Rotation Physics

## Status: Open

## Parent Issue: 1305 - Rotor System

## Problem

Need to update line positions each frame based on rotor rotation, and handle ball collisions with moving lines.

## Implementation

### Rotation Update

Each frame:
1. Update rotor angle: `angle += speed * delta_time`
2. For each connected object:
   - Calculate new position: `x = center_x + distance * cos(angle + relative_angle)`
   - Calculate new position: `y = center_y + distance * sin(angle + relative_angle)`
   - For lines: update both endpoints based on their relative positions

### Ball Collision with Moving Lines

Two approaches:

**Approach A: Swept Collision**
- Calculate line position at frame start and end
- Sweep ball through time, detect intersection with line sweep area
- More accurate but complex

**Approach B: Velocity Transfer**
- Treat moving line as having velocity at collision point
- Transfer some velocity to ball on collision
- Simpler, may have tunneling at high speeds

### Angular Velocity at Collision Point

When ball hits rotating line:
- Point on line has tangential velocity: `v = omega * radius`
- Direction perpendicular to line from center
- Add this velocity component to collision response

## Implementation Steps

1. Add rotor_update() function called each physics frame
2. Calculate new positions for all connected objects
3. Update collision data structures with new positions
4. Modify ball-line collision to account for line velocity
5. Test with various rotation speeds

## Files to Modify

- `src/0XX-rotor.c` - Rotation update logic
- `src/007-ball.c` - Collision response with moving lines
- `src/001-main.c` - Call rotor_update in physics loop

## Notes

- May need to run rotor update before ball physics
- Consider caching sin/cos values per rotor per frame
- High-speed rotation may need smaller timesteps
