# 003 - Physics System

## Overview

The physics system handles ball movement, gravity, and collisions with
pegs and boundaries. Each ball is updated independently, enabling
parallel processing.

## Constants

```c
#define GRAVITY 980.0f       // Pixels per second squared
#define BALL_RADIUS 8.0f     // Ball collision radius
#define PEG_RADIUS 12.0f     // Peg collision radius
#define RESTITUTION 0.7f     // Bounce energy retention
#define FRICTION 0.99f       // Velocity damping per frame
```

## Ball Update Function

```c
// {{{ update_ball
// The function pointer target for ball physics tasks.
// Reads from current buffer, writes to next buffer.
void update_ball(void* data) {
    BallTaskData* td = (BallTaskData*)data;
    Ball* current = &td->read_buffer[td->ball_index];
    Ball* next = &td->write_buffer[td->ball_index];

    if (!current->active) {
        *next = *current;
        return;
    }

    float dt = 1.0f / 60.0f;  // Fixed timestep

    // Apply gravity
    float vy = current->vy + GRAVITY * dt;
    float vx = current->vx;

    // Apply friction
    vx *= FRICTION;
    vy *= FRICTION;

    // Tentative new position
    float nx = current->x + vx * dt;
    float ny = current->y + vy * dt;

    // Check peg collisions
    for (int i = 0; i < td->world->peg_count; i++) {
        Peg* peg = &td->world->pegs[i];
        float dx = nx - peg->x;
        float dy = ny - peg->y;
        float dist = sqrtf(dx*dx + dy*dy);
        float min_dist = BALL_RADIUS + PEG_RADIUS;

        if (dist < min_dist) {
            // Collision response
            float overlap = min_dist - dist;
            float norm_x = dx / dist;
            float norm_y = dy / dist;

            // Push ball out of peg
            nx += norm_x * overlap;
            ny += norm_y * overlap;

            // Reflect velocity
            float dot = vx * norm_x + vy * norm_y;
            vx -= 2 * dot * norm_x;
            vy -= 2 * dot * norm_y;

            // Apply restitution
            vx *= RESTITUTION;
            vy *= RESTITUTION;
        }
    }

    // Boundary collisions
    // ... (wall bounces, bottom detection)

    // Write result
    next->x = nx;
    next->y = ny;
    next->vx = vx;
    next->vy = vy;
    next->active = current->active;
    next->radius = current->radius;
    next->color = current->color;
}
// }}}
```

## Peg Layout

Pachinko machines use a staggered peg grid:

```
    O   O   O   O   O      <- Row 0 (offset 0)
  O   O   O   O   O   O    <- Row 1 (offset half-spacing)
    O   O   O   O   O      <- Row 2 (offset 0)
  O   O   O   O   O   O    <- Row 3 (offset half-spacing)
```

```c
// {{{ generate_peg_grid
void generate_peg_grid(World* world, int rows, int cols,
                       float start_x, float start_y,
                       float spacing) {
    world->peg_count = rows * cols;
    world->pegs = malloc(sizeof(Peg) * world->peg_count);

    int idx = 0;
    for (int row = 0; row < rows; row++) {
        float offset = (row % 2 == 0) ? 0 : spacing / 2;
        for (int col = 0; col < cols; col++) {
            world->pegs[idx].x = start_x + col * spacing + offset;
            world->pegs[idx].y = start_y + row * spacing;
            world->pegs[idx].radius = PEG_RADIUS;
            idx++;
        }
    }
}
// }}}
```

## Score Zones

At the bottom, slots capture balls and award points:

```c
// {{{ typedef struct ScoreZone
typedef struct ScoreZone {
    float x_min;
    float x_max;
    int points;
} ScoreZone;
// }}}
```

Typical layout:
```
| 10 | 50 | 100 | 500 | 100 | 50 | 10 |
```

## Additional Collision Types

### Ramp Collision
Ramps are line segments with thickness. Collision uses closest-point
algorithm:

```c
// Find closest point on line segment to ball center
// If distance < ball_radius + ramp_thickness/2, collision
// Reflect velocity off the line normal
```

### Bumper Collision
Bumpers are horizontal bars at gate row boundaries. They deflect balls
with high restitution to prevent easy passage through gates.

### Screen Wrapping
Balls exiting the bottom reappear at the top (player balls) or vice
versa (adversary balls). Position, velocity, and health are preserved.

## Damage System

Balls have health that decreases on collision:
- High-speed impacts deal more damage
- Low-speed impacts (below threshold) deal minimal damage
- When health reaches zero, ball is destroyed with particle effects

```c
// Damage scales with impact velocity
float impact_speed = sqrtf(vx*vx + vy*vy);
if (impact_speed > LOW_SPEED_THRESHOLD) {
    int damage = (int)(impact_speed * DAMAGE_SCALE);
    ball->health -= damage;
}
```

## Collision Detection Optimization

For many balls, spatial partitioning improves performance:
- Grid-based broad phase
- Only check pegs in nearby cells
- Reduces O(balls * pegs) to O(balls * local_pegs)

This optimization is planned for a future phase.
