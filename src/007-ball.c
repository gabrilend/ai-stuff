// src/007-ball.c
// Ball manager implementation with double-buffering support

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include "006-ball.h"
#include "004-world.h"
#include "003-threadpool.h"
#include "raylib.h"

// {{{ ball_manager_create
BallManager* ball_manager_create(int capacity) {
    BallManager* manager = (BallManager*)malloc(sizeof(BallManager));
    if (!manager) {
        fprintf(stderr, "ERROR: Failed to allocate ball manager\n");
        return NULL;
    }

    manager->capacity = capacity;
    manager->active_count = 0;
    manager->spawn_cooldown = 0.0f;
    manager->spawn_credits = 1.0f;  // Start with one credit (ready to spawn)

    // Allocate current buffer
    manager->balls_current = (Ball*)calloc(capacity, sizeof(Ball));
    if (!manager->balls_current) {
        fprintf(stderr, "ERROR: Failed to allocate current ball buffer\n");
        free(manager);
        return NULL;
    }

    // Allocate next buffer
    manager->balls_next = (Ball*)calloc(capacity, sizeof(Ball));
    if (!manager->balls_next) {
        fprintf(stderr, "ERROR: Failed to allocate next ball buffer\n");
        free(manager->balls_current);
        free(manager);
        return NULL;
    }

    // Allocate task data array for parallel processing
    manager->task_data = (BallTaskData*)calloc(capacity, sizeof(BallTaskData));
    if (!manager->task_data) {
        fprintf(stderr, "ERROR: Failed to allocate task data array\n");
        free(manager->balls_next);
        free(manager->balls_current);
        free(manager);
        return NULL;
    }

    // Initialize all balls as inactive
    for (int i = 0; i < capacity; i++) {
        manager->balls_current[i].active = 0;
        manager->balls_current[i].radius = BALL_RADIUS;
        manager->balls_current[i].gravity_dir = 1.0f;
        manager->balls_current[i].owner = OWNER_PLAYER;
        manager->balls_current[i].passed_gate = 0;
        manager->balls_next[i].active = 0;
        manager->balls_next[i].radius = BALL_RADIUS;
        manager->balls_next[i].gravity_dir = 1.0f;
        manager->balls_next[i].owner = OWNER_PLAYER;
        manager->balls_next[i].passed_gate = 0;

        // Initialize task data with immutable ball_index
        manager->task_data[i].ball_index = i;
    }

    return manager;
}
// }}}

// {{{ ball_manager_destroy
void ball_manager_destroy(BallManager* manager) {
    if (!manager) return;

    if (manager->balls_current) {
        free(manager->balls_current);
    }
    if (manager->balls_next) {
        free(manager->balls_next);
    }
    if (manager->task_data) {
        free(manager->task_data);
    }
    free(manager);
}
// }}}

// {{{ ball_manager_spawn
int ball_manager_spawn(BallManager* manager, float x, float y, float radius,
                       int owner, float gravity_dir) {
    if (!manager) return 0;

    // Clamp radius to reasonable bounds (minimum 4, maximum default)
    if (radius < 4.0f) radius = 4.0f;
    if (radius > BALL_RADIUS) radius = BALL_RADIUS;

    // Find an inactive slot in current buffer
    for (int i = 0; i < manager->capacity; i++) {
        if (!manager->balls_current[i].active) {
            Ball* ball = &manager->balls_current[i];
            ball->x = x;
            ball->y = y;

            // Random horizontal velocity in range [-SPAWN_VX_RANGE, +SPAWN_VX_RANGE]
            ball->vx = (rand() / (float)RAND_MAX - 0.5f) * SPAWN_VX_RANGE * 2.0f;

            // Initial velocity in gravity direction
            ball->vy = SPAWN_VY_INITIAL * gravity_dir;

            ball->radius = radius;
            ball->gravity_dir = gravity_dir;
            ball->health = BALL_MAX_HEALTH;
            ball->active = 1;
            ball->owner = owner;
            ball->passed_gate = 0;
            manager->active_count++;
            return 1;
        }
    }

    // No available slots
    return 0;
}
// }}}

// {{{ ball_manager_swap_buffers
void ball_manager_swap_buffers(BallManager* manager) {
    if (!manager) return;

    // Swap the buffer pointers
    Ball* temp = manager->balls_current;
    manager->balls_current = manager->balls_next;
    manager->balls_next = temp;
}
// }}}

// {{{ ball_manager_deactivate
void ball_manager_deactivate(BallManager* manager, int index) {
    if (!manager) return;
    if (index < 0 || index >= manager->capacity) return;

    if (manager->balls_current[index].active) {
        manager->balls_current[index].active = 0;
        manager->active_count--;
    }
}
// }}}

// {{{ ball_update_physics
// Internal function to update a single ball's physics
static void ball_update_physics(Ball* current, Ball* next, float dt) {
    // Copy constant properties
    next->active = current->active;
    next->radius = current->radius;
    next->gravity_dir = current->gravity_dir;
    next->health = current->health;
    next->owner = current->owner;
    next->passed_gate = current->passed_gate;

    if (!current->active) return;

    // Semi-implicit Euler integration
    // Update velocity first (using gravity in ball's direction)
    next->vy = current->vy + GRAVITY * current->gravity_dir * dt;
    next->vx = current->vx;

    // Apply damping to both velocity components
    next->vx *= DAMPING;
    next->vy *= DAMPING;

    // Update position using new velocity
    next->x = current->x + next->vx * dt;
    next->y = current->y + next->vy * dt;
}
// }}}

// {{{ ball_check_peg_collision
// Internal function to check circle-circle collision
// Returns 1 if collision detected, 0 otherwise
// Outputs collision normal and penetration depth
static int ball_check_peg_collision(Ball* ball, Peg* peg,
                                     float* nx, float* ny, float* depth) {
    float dx = ball->x - peg->x;
    float dy = ball->y - peg->y;
    float dist_sq = dx * dx + dy * dy;
    float min_dist = ball->radius + peg->radius;

    // No collision if distance >= sum of radii
    if (dist_sq >= min_dist * min_dist) return 0;

    float dist = sqrtf(dist_sq);
    if (dist < 0.001f) dist = 0.001f;  // Avoid division by zero

    // Collision normal (points from peg to ball)
    *nx = dx / dist;
    *ny = dy / dist;
    *depth = min_dist - dist;

    return 1;  // Collision detected
}
// }}}

// {{{ ball_resolve_peg_collision
// Internal function to resolve collision with a peg
// Separates ball from peg and reflects velocity
static void ball_resolve_peg_collision(Ball* ball, float nx, float ny,
                                        float depth) {
    // Separate ball from peg along collision normal
    ball->x += nx * (depth + COLLISION_BIAS);
    ball->y += ny * (depth + COLLISION_BIAS);

    // Calculate velocity component along normal
    float vn = ball->vx * nx + ball->vy * ny;

    // Only respond if moving into peg (negative means approaching)
    if (vn < 0) {
        // Reflect velocity with restitution
        // Formula: v' = v - (1 + e) * (v · n) * n
        ball->vx -= (1.0f + RESTITUTION) * vn * nx;
        ball->vy -= (1.0f + RESTITUTION) * vn * ny;
    }
}
// }}}

// {{{ ball_collide_with_pegs
// Internal function to check and resolve collisions with all pegs
// Checks both player pegs and adversary pegs
static void ball_collide_with_pegs(Ball* ball, World* world) {
    float nx, ny, depth;

    // Check player pegs
    for (int i = 0; i < world->peg_count; i++) {
        if (ball_check_peg_collision(ball, &world->pegs[i],
                                      &nx, &ny, &depth)) {
            ball_resolve_peg_collision(ball, nx, ny, depth);
        }
    }

    // Check adversary pegs
    if (world->adversary_pegs) {
        for (int i = 0; i < world->adversary_peg_count; i++) {
            if (ball_check_peg_collision(ball, &world->adversary_pegs[i],
                                          &nx, &ny, &depth)) {
                ball_resolve_peg_collision(ball, nx, ny, depth);
            }
        }
    }
}
// }}}

// {{{ ball_check_bumper_collision
// Internal function to check circle-circle collision with bumper
// Returns 1 if collision detected, 0 otherwise
// Outputs collision normal and penetration depth
static int ball_check_bumper_collision(Ball* ball, Bumper* bumper,
                                        float* nx, float* ny, float* depth) {
    float dx = ball->x - bumper->x;
    float dy = ball->y - bumper->y;
    float dist_sq = dx * dx + dy * dy;
    float min_dist = ball->radius + bumper->radius;

    // No collision if distance >= sum of radii
    if (dist_sq >= min_dist * min_dist) return 0;

    float dist = sqrtf(dist_sq);
    if (dist < 0.001f) dist = 0.001f;  // Avoid division by zero

    // Collision normal (points from bumper to ball)
    *nx = dx / dist;
    *ny = dy / dist;
    *depth = min_dist - dist;

    return 1;  // Collision detected
}
// }}}

// {{{ ball_resolve_bumper_collision
// Internal function to resolve collision with a bumper
// Uses very low restitution for "donk" feel - ball slides into gate
static void ball_resolve_bumper_collision(Ball* ball, float nx, float ny,
                                           float depth) {
    // Separate ball from bumper along collision normal
    ball->x += nx * (depth + COLLISION_BIAS);
    ball->y += ny * (depth + COLLISION_BIAS);

    // Calculate velocity component along normal
    float vn = ball->vx * nx + ball->vy * ny;

    // Only respond if moving into bumper (negative means approaching)
    if (vn < 0) {
        // Very low restitution - ball "sticks" briefly then slides
        // Also dampen tangential velocity to reduce sideways bounce
        ball->vx -= (1.0f + BUMPER_RESTITUTION) * vn * nx;
        ball->vy -= (1.0f + BUMPER_RESTITUTION) * vn * ny;

        // Additional damping to tangential velocity for "sticky" feel
        // This makes the ball more likely to drop straight down
        float tangent_damping = 0.7f;
        float vt = ball->vx * (-ny) + ball->vy * nx;  // Tangent component
        ball->vx -= (1.0f - tangent_damping) * vt * (-ny);
        ball->vy -= (1.0f - tangent_damping) * vt * nx;
    }
}
// }}}

// {{{ ball_collide_with_bumpers
// Internal function to check and resolve collisions with all bumpers
// Checks both player bumpers and adversary bumpers
static void ball_collide_with_bumpers(Ball* ball, World* world) {
    float nx, ny, depth;

    // Check player bumpers (top of zones)
    if (world->bumpers) {
        for (int i = 0; i < world->bumper_count; i++) {
            if (ball_check_bumper_collision(ball, &world->bumpers[i],
                                             &nx, &ny, &depth)) {
                ball_resolve_bumper_collision(ball, nx, ny, depth);
            }
        }
    }

    // Check adversary bumpers (bottom of zones)
    if (world->adversary_bumpers) {
        for (int i = 0; i < world->adversary_bumper_count; i++) {
            if (ball_check_bumper_collision(ball, &world->adversary_bumpers[i],
                                             &nx, &ny, &depth)) {
                ball_resolve_bumper_collision(ball, nx, ny, depth);
            }
        }
    }
}
// }}}

// {{{ ball_check_ball_collision
// Internal function to check circle-circle collision between two balls
// Returns 1 if collision detected, 0 otherwise
// Outputs collision normal and penetration depth
static int ball_check_ball_collision(Ball* ball_a, Ball* ball_b,
                                      float* nx, float* ny, float* depth) {
    // Skip if either ball is inactive
    if (!ball_a->active || !ball_b->active) return 0;

    float dx = ball_a->x - ball_b->x;
    float dy = ball_a->y - ball_b->y;
    float dist_sq = dx * dx + dy * dy;
    float min_dist = ball_a->radius + ball_b->radius;

    // No collision if distance >= sum of radii
    if (dist_sq >= min_dist * min_dist) return 0;

    float dist = sqrtf(dist_sq);
    if (dist < 0.001f) dist = 0.001f;  // Avoid division by zero

    // Collision normal (points from ball_b to ball_a)
    *nx = dx / dist;
    *ny = dy / dist;
    *depth = min_dist - dist;

    return 1;
}
// }}}

// {{{ ball_resolve_ball_collision
// Internal function to resolve collision between two balls
// Only applies response to ball_a (caller handles ball_b separately)
// Cross-board collisions (player vs adversary) use 2x impulse strength
static void ball_resolve_ball_collision(Ball* ball_a, Ball* ball_b,
                                         float nx, float ny, float depth) {
    // Each ball moves half the penetration distance
    ball_a->x += nx * (depth * 0.5f + COLLISION_BIAS);
    ball_a->y += ny * (depth * 0.5f + COLLISION_BIAS);

    // Calculate relative velocity
    float rel_vx = ball_a->vx - ball_b->vx;
    float rel_vy = ball_a->vy - ball_b->vy;

    // Velocity component along collision normal
    float vn = rel_vx * nx + rel_vy * ny;

    // Only respond if balls are approaching
    if (vn < 0) {
        // Check if this is a cross-board collision (player vs adversary)
        if (ball_a->owner != ball_b->owner) {
            // Calculate damage based on closing speed (velocity along collision normal)
            // Head-on collisions deal full damage, glancing blows deal little/none
            // vn is negative when approaching, so use -vn for positive damage
            float closing_speed = -vn;
            float damage = closing_speed * DAMAGE_VELOCITY_SCALE;
            ball_a->health -= damage;
        }

        // Equal mass elastic collision: swap velocity components along normal
        // For ball_a, we add the impulse; ball_b will be handled by its own task
        float impulse = -(1.0f + RESTITUTION) * vn;
        ball_a->vx += impulse * nx;
        ball_a->vy += impulse * ny;
    }
}
// }}}

// {{{ ball_collide_with_balls
// Internal function to check and resolve collisions with other balls
// Tracks cross-owner collisions for splash particle effects
// collision_out: array of 5 floats [had_collision, x, y, tangent_x, tangent_y]
static void ball_collide_with_balls(Ball* ball, int ball_index,
                                     Ball* read_buffer, int capacity,
                                     float* collision_out) {
    float nx, ny, depth;

    // Initialize collision output
    if (collision_out) {
        collision_out[0] = 0.0f;  // had_collision
    }

    // Check collision with all other active balls
    // To avoid double-processing, we check against all balls
    // Each ball task handles its own response
    for (int i = 0; i < capacity; i++) {
        if (i == ball_index) continue;  // Skip self

        Ball* other = &read_buffer[i];
        if (ball_check_ball_collision(ball, other, &nx, &ny, &depth)) {
            // Use READ buffer velocities for both balls to compare same time point
            // (write buffer has gravity applied, read buffer is last frame)
            Ball* current_ball = &read_buffer[ball_index];
            float rel_vx = current_ball->vx - other->vx;
            float rel_vy = current_ball->vy - other->vy;
            float vn = rel_vx * nx + rel_vy * ny;

            ball_resolve_ball_collision(ball, other, nx, ny, depth);

            // Track cross-owner collision for splash effect
            // Only track when ball_index < i to avoid double-detection
            // (both balls detect same collision; only lower index spawns splash)
            // Only track if balls were actually approaching with meaningful velocity
            if (collision_out && collision_out[0] == 0.0f &&
                ball_index < i &&
                ball->owner != other->owner && vn < -10.0f) {
                collision_out[0] = 1.0f;  // had_collision
                // Collision point is midpoint between ball centers
                collision_out[1] = (ball->x + other->x) * 0.5f;  // x
                collision_out[2] = (ball->y + other->y) * 0.5f;  // y
                // Tangent is perpendicular to normal
                collision_out[3] = -ny;  // tangent_x
                collision_out[4] = nx;   // tangent_y
            }
        }
    }
}
// }}}

// {{{ ball_collide_with_walls
// Internal function to check and resolve collisions with table boundaries
// Uses table bounds (guard rails) instead of screen edges
static void ball_collide_with_walls(Ball* ball, World* world) {
    // Left rail (table left edge)
    float left_wall = world->table_x;
    if (ball->x - ball->radius < left_wall) {
        ball->x = left_wall + ball->radius;
        ball->vx = -ball->vx * WALL_RESTITUTION;
    }

    // Right rail (table right edge)
    float right_wall = world->table_x + world->table_width;
    if (ball->x + ball->radius > right_wall) {
        ball->x = right_wall - ball->radius;
        ball->vx = -ball->vx * WALL_RESTITUTION;
    }

    // Top boundary (prevent player balls from escaping upward)
    // Only applies to player balls - adversary balls pass through to despawn
    // Must be above SPAWN_Y so balls can spawn without hitting the wall
    if (ball->gravity_dir > 0) {
        float top_wall = SPAWN_Y - BALL_RADIUS - 20.0f;  // Y=22, well above spawn
        if (ball->y - ball->radius < top_wall) {
            ball->y = top_wall + ball->radius;
            ball->vy = -ball->vy * WALL_RESTITUTION;
        }
    }

    // No bottom wall - balls fall through to score zones (player balls)
    // No top wall for adversary balls - they pass through to despawn
}
// }}}

// {{{ ball_check_bounds
// Internal function to deactivate balls that exit the play area
// Balls despawn one screen height + buffer past the board edges
// This ensures they're fully off-screen before despawning
static void ball_check_bounds(Ball* ball, World* world) {
    float screen_height = (float)world->height;

    if (ball->gravity_dir > 0) {
        // Player ball moving downward - destroy one screen past adversary board
        float bottom_bound = world->adversary_table_bottom + screen_height + DESPAWN_BUFFER;
        if (ball->y - ball->radius > bottom_bound) {
            ball->active = 0;
        }
    } else {
        // Adversary ball moving upward - destroy one screen above player board
        float top_bound = world->table_top - screen_height - DESPAWN_BUFFER;
        if (ball->y + ball->radius < top_bound) {
            ball->active = 0;
        }
    }
}
// }}}

// {{{ ball_manager_update
void ball_manager_update(BallManager* manager, World* world, float dt) {
    if (!manager) return;

    // Reset active count
    manager->active_count = 0;

    for (int i = 0; i < manager->capacity; i++) {
        Ball* current = &manager->balls_current[i];
        Ball* next = &manager->balls_next[i];

        // Update physics
        ball_update_physics(current, next, dt);

        // Perform collision detection and response on next buffer
        if (next->active) {
            ball_collide_with_pegs(next, world);
            ball_collide_with_bumpers(next, world);
            ball_collide_with_walls(next, world);
            ball_check_bounds(next, world);

            // Count active balls
            if (next->active) {
                manager->active_count++;
            }
        }
    }
}
// }}}

// {{{ ball_manager_render
void ball_manager_render(BallManager* manager) {
    if (!manager) return;

    // Color palettes for player and adversary balls
    Color player_color = (Color){255, 180, 50, 255};        // Warm orange
    Color player_highlight = (Color){255, 220, 150, 255};   // Lighter highlight
    Color adversary_color = (Color){255, 80, 80, 255};      // Red
    Color adversary_highlight = (Color){255, 150, 150, 255}; // Light red

    for (int i = 0; i < manager->capacity; i++) {
        Ball* ball = &manager->balls_current[i];
        if (ball->active) {
            // Select color based on ball owner
            Color ball_color = (ball->owner == OWNER_ADVERSARY) ?
                               adversary_color : player_color;
            Color ball_highlight = (ball->owner == OWNER_ADVERSARY) ?
                                   adversary_highlight : player_highlight;

            // Draw main ball circle
            DrawCircle(
                (int)ball->x,
                (int)ball->y,
                ball->radius,
                ball_color
            );

            // Draw highlight circle for 3D sphere illusion
            // Offset toward top-left to simulate light source
            float highlight_radius = ball->radius * 0.4f;
            float highlight_offset_x = ball->radius * -0.3f;
            float highlight_offset_y = ball->radius * -0.3f;
            DrawCircle(
                (int)(ball->x + highlight_offset_x),
                (int)(ball->y + highlight_offset_y),
                highlight_radius,
                ball_highlight
            );
        }
    }
}
// }}}

// {{{ ball_manager_update_cooldown
void ball_manager_update_cooldown(BallManager* manager, float dt) {
    if (!manager) return;

    // Accumulate spawn credits over time (capped)
    // Credits accumulate even when spawn is blocked, saving for later
    manager->spawn_credits += SPAWN_RATE * dt;
    if (manager->spawn_credits > MAX_SPAWN_CREDITS) {
        manager->spawn_credits = MAX_SPAWN_CREDITS;
    }

    // Update visual cooldown indicator
    if (manager->spawn_cooldown > 0) {
        manager->spawn_cooldown -= dt;
    }
}
// }}}

// {{{ ball_manager_can_spawn
int ball_manager_can_spawn(BallManager* manager) {
    if (!manager) return 0;

    // Check credits (>= 1.0 means can spawn) and capacity
    return manager->spawn_credits >= 1.0f &&
           manager->active_count < manager->capacity;
}
// }}}

// {{{ ball_manager_reset_cooldown
void ball_manager_reset_cooldown(BallManager* manager) {
    if (!manager) return;

    // Consume one credit for spawning
    manager->spawn_credits -= 1.0f;
    if (manager->spawn_credits < 0.0f) {
        manager->spawn_credits = 0.0f;
    }

    // Reset visual cooldown indicator
    manager->spawn_cooldown = SPAWN_COOLDOWN;
}
// }}}

// {{{ ball_manager_spawn_blocked
// Checks circular distance from reticle center (spawn_x, spawn_y).
// Balls with initial horizontal velocity will quickly exit the blocking zone,
// allowing the next ball to spawn - no need to wait for vertical clearance.
int ball_manager_spawn_blocked(BallManager* manager, float spawn_x, float spawn_y) {
    if (!manager) return 0;

    for (int i = 0; i < manager->capacity; i++) {
        Ball* ball = &manager->balls_current[i];
        if (!ball->active) continue;

        // Dynamic margin based on ball radius (supports future size upgrades)
        // 1.5x ball radius is minimum clearance to prevent overlap
        float spawn_margin = ball->radius * 1.5f;

        // Circular distance check centered on reticle position
        // Balls moving left/right exit blocking zone quickly via horizontal distance
        float dx = ball->x - spawn_x;
        float dy = ball->y - spawn_y;
        float dist_sq = dx * dx + dy * dy;
        float min_dist = spawn_margin + ball->radius;

        if (dist_sq < min_dist * min_dist) {
            return 1;  // Spawn is blocked by ball within reticle zone
        }
    }

    return 0;  // Spawn area is clear
}
// }}}

// {{{ ball_manager_prepare_tasks
void ball_manager_prepare_tasks(BallManager* manager, World* world, float dt) {
    if (!manager) return;

    // Update task data for all balls
    // Each task data entry has immutable ball_index,
    // but buffer pointers, world, dt, and capacity change each frame
    for (int i = 0; i < manager->capacity; i++) {
        manager->task_data[i].read_buffer = manager->balls_current;
        manager->task_data[i].write_buffer = manager->balls_next;
        manager->task_data[i].world = world;
        manager->task_data[i].dt = dt;
        manager->task_data[i].capacity = manager->capacity;

        // CRITICAL: Propagate inactive state from current to next buffer
        // When a ball is inactive, no task is submitted for it. Without this,
        // balls_next retains a stale active=1 from a previous frame. After
        // the next swap, this stale state becomes balls_current, causing
        // the ball to "resurrect" and trigger scoring/particles again.
        if (!manager->balls_current[i].active) {
            manager->balls_next[i].active = 0;
        }
    }
}
// }}}

// {{{ ball_update_task
void ball_update_task(void* data) {
    // Cast task data
    BallTaskData* task = (BallTaskData*)data;
    if (!task) return;

    // Initialize scoring, death, and collision tracking fields
    task->score_delta = 0;
    task->scored = 0;
    task->died_from_damage = 0;
    task->had_collision = 0;

    // Get ball pointers using immutable ball_index
    Ball* current = &task->read_buffer[task->ball_index];
    Ball* next = &task->write_buffer[task->ball_index];

    // Update physics (gravity, velocity, position)
    ball_update_physics(current, next, task->dt);

    // Perform collision detection and response on next buffer
    // Only if ball is still active after physics update
    if (next->active) {
        ball_collide_with_pegs(next, task->world);
        ball_collide_with_bumpers(next, task->world);

        // Track cross-owner ball collisions for splash particles
        float collision_info[5] = {0};
        ball_collide_with_balls(next, task->ball_index,
                               task->read_buffer, task->capacity, collision_info);

        // Copy collision info to task data
        if (collision_info[0] > 0.5f) {
            task->had_collision = 1;
            task->collision_x = collision_info[1];
            task->collision_y = collision_info[2];
            task->collision_tx = collision_info[3];
            task->collision_ty = collision_info[4];
        }

        ball_collide_with_walls(next, task->world);
        ball_check_bounds(next, task->world);

        // Check if ball died from cross-board collision damage
        if (next->active && next->health <= 0) {
            task->died_from_damage = 1;
            task->death_pos_x = next->x;
            task->death_pos_y = next->y;
            task->death_vx = next->vx;
            task->death_vy = next->vy;
            next->active = 0;
        }

        // Check if ball entered a score zone
        // This happens after all physics and collision updates
        // Balls pass through gates (don't deactivate) for adversary mode
        // passed_gate flag prevents double-scoring
        if (next->active) {
            int zone_index = ball_check_zone(next, task->world);
            if (zone_index >= 0 && !next->passed_gate) {
                // Ball entered zone for first time - award points
                task->score_delta = task->world->zones[zone_index].points;
                task->scored = 1;
                task->score_pos_x = next->x;
                task->score_pos_y = next->y;
                next->passed_gate = 1;  // Mark as scored, ball continues through
            }
        }
    }
}
// }}}

// {{{ ball_manager_submit_tasks
void ball_manager_submit_tasks(BallManager* manager, ThreadPool* pool) {
    if (!manager || !pool) return;

    // Submit tasks for all active balls
    // Frame update sequence:
    // 1. ball_manager_prepare_tasks()  - Set up task data
    // 2. ball_manager_submit_tasks()   - Submit to threadpool (this function)
    // 3. threadpool_wait_all()         - Wait for completion
    // 4. ball_manager_finalize_update() - Count active balls
    // 5. ball_manager_swap_buffers()   - Swap for rendering

    for (int i = 0; i < manager->capacity; i++) {
        // Only submit tasks for active balls
        if (manager->balls_current[i].active) {
            threadpool_submit(pool, ball_update_task, &manager->task_data[i]);
        }
    }
}
// }}}

// {{{ ball_manager_finalize_update
void ball_manager_finalize_update(BallManager* manager) {
    if (!manager) return;

    // Count active balls in write buffer
    // Called after threadpool_wait_all() ensures all tasks complete
    // Memory barrier from mutex unlock ensures all writes are visible
    int count = 0;
    for (int i = 0; i < manager->capacity; i++) {
        if (manager->balls_next[i].active) {
            count++;
        }
    }

    manager->active_count = count;
}
// }}}

// {{{ ball_manager_collect_scores
int ball_manager_collect_scores(BallManager* manager) {
    if (!manager) return 0;

    // Sum all score deltas from task data
    // Called after threadpool_wait_all() ensures all tasks complete
    // Each task writes only to its own score_delta, so this is thread-safe
    int total = 0;
    for (int i = 0; i < manager->capacity; i++) {
        total += manager->task_data[i].score_delta;
        // Reset scoring and death tracking fields for next frame
        // Critical: must reset flags here because inactive balls
        // don't have tasks submitted, so their flags would persist forever
        manager->task_data[i].score_delta = 0;
        manager->task_data[i].scored = 0;
        manager->task_data[i].died_from_damage = 0;
    }

    return total;
}
// }}}

// {{{ ball_check_zone
int ball_check_zone(Ball* ball, World* world) {
    if (!ball || !world) return -1;
    if (!ball->active) return -1;

    // Check each zone's actual bounds
    // This allows zones to be placed anywhere on the board
    for (int i = 0; i < world->zone_count; i++) {
        ScoreZone* zone = &world->zones[i];

        // Check if ball center is within zone boundaries (x and y)
        if (ball->x >= zone->x_min && ball->x < zone->x_max &&
            ball->y >= zone->y_min && ball->y < zone->y_max) {
            return i;  // Return zone index
        }
    }

    // Ball not in any zone
    return -1;
}
// }}}
