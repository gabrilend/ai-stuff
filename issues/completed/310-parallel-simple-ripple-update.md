# Issue 903: Parallel Simple/Ripple Update

## Current Behavior

- PARTICLE_SIMPLE and PARTICLE_RIPPLE updated sequentially
- Simple: position += velocity * dt, life -= dt
- Ripple: radius expands, life decrements
- No collision detection needed for these types

## Intended Behavior

- Simple and ripple particles update in parallel via threadpool
- Each particle task reads from current, writes to next buffer
- No inter-particle dependencies (fully parallel)
- Gravity applied to simple particles

## Suggested Implementation Steps

1. Create particle_update_task() function:
   ```c
   void particle_update_task(void* data) {
       ParticleTaskData* task = (ParticleTaskData*)data;
       Particle* current = &task->read_buffer[task->particle_index];
       Particle* next = &task->write_buffer[task->particle_index];

       // Skip inactive particles
       if (current->life <= 0) {
           next->life = 0;
           return;
       }

       // Copy current state to next
       *next = *current;

       // Update based on type
       switch (next->type) {
           case PARTICLE_SIMPLE:
               // Apply gravity and velocity
               next->vy += PARTICLE_GRAVITY * task->dt;
               next->x += next->vx * task->dt;
               next->y += next->vy * task->dt;
               break;
           case PARTICLE_RIPPLE:
               // Expand radius
               next->radius += RIPPLE_EXPAND_SPEED * task->dt;
               break;
           case PARTICLE_FRAGMENT:
               // Handled in Issue 904
               break;
       }

       // Decrement life
       next->life -= task->dt;
   }
   ```

2. Add particle_system_submit_tasks():
   - Loop through all particles
   - Submit task for each active particle (life > 0)

3. Update main loop integration:
   - Call prepare_tasks before submit
   - Call threadpool_wait_all after submit
   - Call swap_buffers after wait

## Technical Considerations

- Simple/ripple particles have no read dependencies on other particles
- Fully parallel, no synchronization needed between tasks
- Fragment handling deferred to Issue 904

## Status

Pending
