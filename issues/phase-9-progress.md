# Phase 9 Progress

## Phase Goal

Particle system parallelization. Move particle updates to the threadpool
architecture using double-buffering, matching the ball physics pattern.

## Issues

| ID  | Description                        | Status  |
|-----|------------------------------------|---------|
| 901 | Particle system double-buffering   | Pending |
| 902 | ParticleTaskData structure         | Pending |
| 903 | Parallel simple/ripple update      | Pending |
| 904 | Parallel fragment collision        | Pending |
| 905 | Integration and synchronization    | Pending |

## Progress Summary

**Completed:** 0/5 issues (0%)
**Phase 9:** In Progress

## Notes

The current particle system is single-threaded, running on the main thread
after ball physics complete. With high particle counts (explosions, many
collisions), this becomes a bottleneck.

**Current architecture:**
- ParticleSystem holds single particle array
- `particle_system_update_with_world()` iterates sequentially
- Fragment particles check collision with all pegs/bumpers each frame

**Target architecture:**
- Double-buffered particle arrays (particles_current, particles_next)
- Pre-allocated ParticleTaskData array
- One task per active particle submitted to threadpool
- Fragment collision detection runs in parallel
- Main thread waits, then swaps buffers

Success is measured by:
- No visual changes to particle behavior
- Reduced frame time with high particle counts
- Thread-safe particle spawning from ball task results

## Dependencies

Phase 8 must be complete (particle effects overhaul provides the system to parallelize).
