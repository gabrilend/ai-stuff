# Issue 901: Particle System Double-Buffering

## Current Behavior

- ParticleSystem has single `particles` array
- Updates modify particles in-place during iteration
- Single-threaded, runs on main thread
- No read/write separation

## Intended Behavior

- ParticleSystem has `particles_current` and `particles_next` arrays
- Read from current buffer, write to next buffer during update
- Swap buffers after all updates complete
- Enables safe parallel reads from current state

## Suggested Implementation Steps

1. Modify ParticleSystem struct in 008-particles.h:
   - Replace `Particle* particles` with `Particle* particles_current`
   - Add `Particle* particles_next`
   - Keep `capacity` and `active_count`

2. Update particle_system_create() in 009-particles.c:
   - Allocate both buffers (2x memory)
   - Initialize both to inactive (life = 0)

3. Update particle_system_destroy():
   - Free both buffers

4. Add particle_system_swap_buffers():
   - Swap current/next pointers
   - Similar to ball_manager_swap_buffers()

5. Update spawn functions to write to current buffer:
   - Spawning happens between frames, writes to current
   - This matches ball spawning pattern

6. Update render to read from current buffer:
   - No change needed if already using `particles`
   - Just rename to `particles_current`

## Technical Considerations

- Memory doubles from N to 2N particles
- Spawn functions write to current (visible immediately)
- Update tasks read current, write next
- Inactive state must propagate (like ball resurrection fix)

## Status

Pending
