# Issue 815: Directional Explosion Fragments

## Current Behavior

- When balls explode, fragments radiate outward in all directions
- Both balls in a collision explode the same way
- No visual distinction between "projectile" and "wall" in collision

## Intended Behavior

Explosion direction based on relative collision strength:

**"Wall" ball (lower closing speed):**
- Shatters along impact tangent in both directions
- Like glass cracking where it was struck
- Fragments spread perpendicular to impact direction

**"Projectile" ball (higher closing speed):**
- Explodes outward away from impact point
- Like a ball splattering against a surface
- Fragments continue in original travel direction

## Technical Approach

1. Track collision info for damage deaths:
   - Store collision normal and tangent in BallTaskData
   - Track whether this ball was "dominant" (higher closing speed)

2. Modify particle_spawn_fragments:
   - Add direction mode parameter (FRAG_RADIAL, FRAG_TANGENT, FRAG_AWAY)
   - FRAG_RADIAL: current behavior (360° spread)
   - FRAG_TANGENT: fragments along tangent (±90° from tangent, both directions)
   - FRAG_AWAY: fragments in hemisphere away from collision point

3. Main loop passes appropriate mode based on collision dominance

## Suggested Implementation Steps

1. Add to BallTaskData:
   - death_nx, death_ny: collision normal at death
   - death_dominant: 1 if this ball had higher closing speed

2. In ball_collide_with_balls, when tracking collision:
   - Store normal direction
   - Compare closing speeds to determine dominance

3. Add FragmentMode enum to particles.h

4. Update particle_spawn_fragments signature:
   - Add normal_x, normal_y parameters
   - Add FragmentMode parameter

5. Implement directional fragment spawning:
   - FRAG_TANGENT: angles clustered around ±90° from normal
   - FRAG_AWAY: angles in hemisphere opposite to normal

## Status

Complete

## Implementation Notes

### Changes to BallTaskData (006-ball.h)
- Added `death_nx`, `death_ny`: collision normal at death
- Added `death_was_dominant`: 1 if this ball had higher closing speed

### Changes to ball_collide_with_balls (007-ball.c)
- Extended `collision_out` array from 5 to 9 floats
- Tracks strongest collision normal and individual approach speeds
- Calculates dominance by comparing `this_approach` vs `other_approach`

### Changes to ball_update_task (007-ball.c)
- Copies death normal and dominance info to task data for main loop

### Changes to particles.h
- Added `FragmentMode` enum (FRAG_RADIAL, FRAG_TANGENT, FRAG_AWAY)
- Updated `particle_spawn_fragments` signature with mode and normal params

### Changes to particle_spawn_fragments (009-particles.c)
- FRAG_TANGENT: Fragments alternate sides along tangent direction (±45° spread)
- FRAG_AWAY: Fragments distributed across 180° hemisphere in normal direction
- FRAG_RADIAL: Original 360° spread behavior preserved

### Changes to main.c
- Determines FragmentMode from `death_was_dominant` flag
- Dominant ball → FRAG_AWAY (projectile splatters)
- Non-dominant ball → FRAG_TANGENT (wall shatters)
