# Issue 905: Particle Integration and Synchronization

## Current Behavior

- Main loop calls particle_system_update_with_world() after ball physics
- Particle spawning happens from main thread after reading ball task results
- Single update function handles all particle types

## Intended Behavior

- Particle update integrates with existing threadpool workflow
- Proper synchronization between ball physics and particle physics
- Spawning from ball results writes to particle current buffer
- Particle tasks submitted after ball tasks complete

## Suggested Implementation Steps

1. Update main loop sequence:
   ```
   // Ball physics (existing)
   ball_manager_prepare_tasks()
   ball_manager_submit_tasks()
   threadpool_wait_all()

   // Spawn particles from ball results (main thread)
   for each ball task:
       if scored: particle_spawn_ripple()
       if had_collision: particle_spawn_splash()
       if died_from_damage: particle_spawn_fragments()

   // Particle physics (new)
   particle_system_prepare_tasks()
   particle_system_submit_tasks()
   threadpool_wait_all()
   particle_system_finalize_update()

   // Swap both buffers
   ball_manager_swap_buffers()
   particle_system_swap_buffers()

   // Render (reads from current buffers)
   ball_manager_render()
   particle_system_render()
   ```

2. Add particle_system_finalize_update():
   - Count active particles in next buffer
   - Update active_count for stats display

3. Ensure spawn functions write to current buffer:
   - particle_spawn_burst() → writes to particles_current
   - particle_spawn_ripple() → writes to particles_current
   - particle_spawn_splash() → writes to particles_current
   - particle_spawn_fragments() → writes to particles_current
   - Newly spawned particles appear next frame after swap

4. Handle edge case: spawning during update
   - Spawning only happens on main thread between wait_all calls
   - No concurrent spawn/update access
   - Thread-safe by design

5. Performance validation:
   - Compare frame time before/after with high particle counts
   - Test with many explosions simultaneously
   - Verify no visual glitches or missing particles

## Technical Considerations

- Ball tasks must complete before particle spawning (results needed)
- Particle tasks can run in parallel with nothing else
- Both buffer swaps happen together after all physics complete
- Render order: balls first, particles second (particles on top)

## Status

Pending
