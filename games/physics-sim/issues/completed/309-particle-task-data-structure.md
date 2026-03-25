# Issue 902: ParticleTaskData Structure

## Current Behavior

- No task data structure for particles
- Update logic embedded in single update function
- All state accessed directly during iteration

## Intended Behavior

- ParticleTaskData struct encapsulates per-particle update info
- Pre-allocated array avoids malloc during gameplay
- Contains read/write buffer pointers, world reference, delta time
- Enables submission to threadpool

## Suggested Implementation Steps

1. Define ParticleTaskData in 008-particles.h:
   ```c
   typedef struct ParticleTaskData {
       int particle_index;       // Index into particle arrays
       Particle* read_buffer;    // Current state (read-only)
       Particle* write_buffer;   // Next state (write target)
       World* world;             // For fragment collision detection
       float dt;                 // Delta time
   } ParticleTaskData;
   ```

2. Add task_data array to ParticleSystem struct:
   - `ParticleTaskData* task_data`
   - Allocated at creation time

3. Update particle_system_create():
   - Allocate task_data array (capacity elements)
   - Initialize particle_index for each (immutable)

4. Update particle_system_destroy():
   - Free task_data array

5. Add particle_system_prepare_tasks():
   - Set read_buffer, write_buffer, world, dt for each task
   - Propagate inactive state from current to next
   - Similar to ball_manager_prepare_tasks()

## Technical Considerations

- Task data is lightweight (few pointers + float)
- particle_index is immutable, set once at creation
- Other fields update each frame before submission

## Status

Pending
