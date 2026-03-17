# Issue 904: Parallel Fragment Collision

## Current Behavior

- Fragment particles check collision with pegs and bumpers
- Sequential iteration over all pegs/bumpers per fragment
- Corkscrew motion calculated each frame
- Trail points updated sequentially

## Intended Behavior

- Fragment collision detection runs in parallel with other particles
- Each fragment task checks against world pegs/bumpers (read-only)
- Corkscrew offset calculated per-task
- Trail points written to next buffer

## Suggested Implementation Steps

1. Extend particle_update_task() for PARTICLE_FRAGMENT:
   ```c
   case PARTICLE_FRAGMENT:
       // Apply gravity
       next->vy += FRAGMENT_GRAVITY * task->dt;

       // Apply corkscrew motion if enabled
       if (next->corkscrew) {
           // Calculate perpendicular offset
           float speed = sqrtf(next->vx * next->vx + next->vy * next->vy);
           if (speed > 0.001f) {
               float perp_x = -next->vy / speed;
               float perp_y = next->vx / speed;
               float offset = sinf(next->corkscrew_phase) * CORKSCREW_AMPLITUDE;
               next->x += perp_x * offset * task->dt * CORKSCREW_FREQUENCY;
               next->y += perp_y * offset * task->dt * CORKSCREW_FREQUENCY;
               next->corkscrew_phase += CORKSCREW_FREQUENCY * task->dt;
           }
       }

       // Update position
       next->x += next->vx * task->dt;
       next->y += next->vy * task->dt;

       // Update rotation
       next->angle += next->angular_vel * task->dt;

       // Collision with pegs (read-only world access)
       fragment_collide_with_pegs(next, task->world);
       fragment_collide_with_bumpers(next, task->world);
       fragment_collide_with_walls(next, task->world);

       // Update trail
       fragment_update_trail(next, task->dt);
       break;
   ```

2. Implement fragment collision helpers:
   - fragment_collide_with_pegs() - bounce off pegs
   - fragment_collide_with_bumpers() - bounce off bumpers
   - fragment_collide_with_walls() - bounce off table edges
   - All read from world (immutable), write to next particle

3. Implement fragment_update_trail():
   - Copy trail points from current to next
   - Add new point when trail_timer expires
   - Circular buffer with trail_head index

## Technical Considerations

- World pegs/bumpers are read-only during update (thread-safe)
- Fragments don't collide with each other (no inter-particle deps)
- Fragments don't collide with balls (one-way visual effect)
- Trail array is per-particle (no shared state)

## Status

Pending
