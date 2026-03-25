# 901c - Line Rotation Physics

## Status: Completed

## Parent Issue: 901 - Rotor System

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

## Implementation Complete

### Changes Made

1. Created `src/044-rotor.h` and `src/044-rotor.c` - rotor physics module
2. Added `RotorPhysics` struct for runtime rotor state with:
   - Pixel-space center position
   - Rotation speed and current angle
   - Connected line/peg indices and their original polar coordinates
3. Added `RotorManager` to manage all rotors and provide update/query interface
4. Added `RotorManager*` fields to World structure (player and adversary)
5. Integrated rotor_manager_update() in main game loop (before ball physics)
6. Added rotor_manager_create() after board data is applied
7. Added cleanup in main.c (before world_destroy)

### Key Functions

- `rotor_manager_create(world)` - Create manager with world reference
- `rotor_manager_add_from_board(manager, board, ...)` - Load rotors from BoardData
- `rotor_manager_update(manager, dt)` - Update angles and rotate connected objects
- `rotor_get_line_velocity(manager, line_index, x, y, &vx, &vy)` - Get velocity at collision point

### Physics Flow

1. `rotor_manager_update()` called each frame before ball physics
2. Updates rotor angles by `rotation_speed * dt`
3. Recalculates connected line endpoints using polar→cartesian conversion
4. Recalculates connected peg positions similarly
5. Ball physics runs with updated positions

### Deferred to Future Issues

- Ball-line velocity transfer (adding rotor momentum to ball) - defer to 901e
- Adversary board rotor loading - infrastructure exists, needs board data

### Unblocks

- 901e (Collision modes) - now has line position updates
