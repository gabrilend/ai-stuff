# Issue 813: Fix Persistent Splash Particles

## Current Behavior

- Splash particles spawn continuously while balls are overlapping
- Creates a "fountain from nothing" effect with cone-shaped particle streams
- Particles persist long after the initial collision

## Root Cause

The collision tracking in `ball_collide_with_balls` sets `had_collision = 1.0f`
whenever balls are overlapping, regardless of whether they are actually approaching
each other. This causes splash particles to spawn every frame during the entire
overlap duration, not just on initial impact.

## Intended Behavior

- Splash particles spawn only once per collision, on initial impact
- No splash spawning while balls are merely overlapping or separating
- Minimum velocity threshold prevents micro-splashes from slow contacts

## Suggested Implementation Steps

1. Calculate relative velocity between colliding balls
2. Calculate velocity component along collision normal (vn)
3. Only flag `had_collision` when balls are approaching (vn < 0)
4. Add minimum velocity threshold (vn < -10.0f) to filter slow contacts

## Status

Complete

## Implementation Notes

Added velocity check to collision tracking in `ball_collide_with_balls`:
- Calculates relative velocity (rel_vx, rel_vy) BEFORE collision resolution
- Calculates normal component (vn = rel_v dot normal)
- Only flags collision if vn < -10.0f (approaching with meaningful speed)
- Matches the existing velocity check in `ball_resolve_ball_collision`

**Critical fix:** Velocity must be calculated BEFORE `ball_resolve_ball_collision`
is called, because collision resolution modifies ball velocities. Checking after
resolution would always see balls moving apart (vn > 0), never approaching.

Files: 007-ball.c (lines 426-446)
