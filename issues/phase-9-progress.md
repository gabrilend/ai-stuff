# Phase 9 Progress

## Phase Goal

Particle system parallelization. Move particle updates to the threadpool
architecture using double-buffering, matching the ball physics pattern.

## Issues

| ID  | Description                        | Status   |
|-----|------------------------------------|---------|| 901 | Particle system double-buffering   | Complete |
| 902 | ParticleTaskData structure         | Complete |
| 903 | Parallel simple/ripple update      | Complete |
| 904 | Parallel fragment collision        | Complete |
| 905 | Integration and synchronization    | Complete |

## Progress Summary

**Completed:** 5/5 issues (100%)
**Phase 9:** Complete

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

## Implementation Log

### Issues 901-905 - Particle System Parallelization (Complete)

Implemented complete parallel particle system matching ball physics architecture:

**Issue 901 - Double-Buffering:**
- ParticleSystem now has `particles_current` and `particles_next` arrays
- Spawn functions write to current buffer (visible immediately)
- Update tasks read from current, write to next
- `particle_system_swap_buffers()` swaps pointers after update

**Issue 902 - ParticleTaskData:**
- Pre-allocated task data array at system creation
- Contains: particle_index (immutable), read/write buffer pointers, world, dt
- Avoids runtime allocation during gameplay

**Issue 903 - Parallel Simple/Ripple Update:**
- `particle_update_task()` handles all particle types
- Simple particles: gravity + velocity integration
- Ripple particles: radius expansion
- Each particle task writes only to its own slot in next buffer

**Issue 904 - Parallel Fragment Collision:**
- Fragment collision with pegs/bumpers runs in parallel
- World data is read-only (thread-safe)
- Corkscrew motion, trail updates, wall bounces all in task

**Issue 905 - Integration:**
- Main loop sequence: ball physics → spawn particles → particle physics
- `particle_system_prepare_tasks()` sets up task data, propagates inactive state
- `particle_system_submit_tasks()` submits active particles to threadpool
- `threadpool_wait_all()` synchronizes before finalize/swap

Files: 008-particles.h, 009-particles.c, 001-main.c
