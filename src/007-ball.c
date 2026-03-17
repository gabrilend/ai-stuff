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
        manager->balls_next[i].active = 0;
        manager->balls_next[i].radius = BALL_RADIUS;

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
int ball_manager_spawn(BallManager* manager, float x, float y) {
    if (!manager) return 0;

    // Find an inactive slot in current buffer
    for (int i = 0; i < manager->capacity; i++) {
        if (!manager->balls_current[i].active) {
            Ball* ball = &manager->balls_current[i];
            ball->x = x;
            ball->y = y;

            // Random horizontal velocity in range [-SPAWN_VX_RANGE, +SPAWN_VX_RANGE]
            ball->vx = (rand() / (float)RAND_MAX - 0.5f) * SPAWN_VX_RANGE * 2.0f;

            // Initial downward velocity
            ball->vy = SPAWN_VY_INITIAL;

            ball->radius = BALL_RADIUS;
            ball->active = 1;
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

    if (!current->active) return;

    // Semi-implicit Euler integration
    // Update velocity first (using gravity)
    next->vy = current->vy + GRAVITY * dt;
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
static void ball_collide_with_pegs(Ball* ball, World* world) {
    float nx, ny, depth;
    for (int i = 0; i < world->peg_count; i++) {
        if (ball_check_peg_collision(ball, &world->pegs[i],
                                      &nx, &ny, &depth)) {
            ball_resolve_peg_collision(ball, nx, ny, depth);
        }
    }
}
// }}}

// {{{ ball_collide_with_walls
// Internal function to check and resolve collisions with screen boundaries
static void ball_collide_with_walls(Ball* ball, int screen_width,
                                     int screen_height) {
    // Left wall
    if (ball->x - ball->radius < 0) {
        ball->x = ball->radius;
        ball->vx = -ball->vx * WALL_RESTITUTION;
    }

    // Right wall
    if (ball->x + ball->radius > screen_width) {
        ball->x = screen_width - ball->radius;
        ball->vx = -ball->vx * WALL_RESTITUTION;
    }

    // Top wall (prevent escape upward)
    if (ball->y - ball->radius < 0) {
        ball->y = ball->radius;
        ball->vy = -ball->vy * WALL_RESTITUTION;
    }

    // No bottom wall - balls fall through to score zones
    (void)screen_height;  // Suppress unused parameter warning
}
// }}}

// {{{ ball_check_bounds
// Internal function to deactivate balls that fall below screen
static void ball_check_bounds(Ball* ball, int screen_height) {
    // Ball has fallen below screen
    if (ball->y - ball->radius > screen_height) {
        ball->active = 0;
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
            ball_collide_with_walls(next, world->width, world->height);
            ball_check_bounds(next, world->height);

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

    // Color palette for balls - warm and visible
    Color ball_color = (Color){255, 180, 50, 255};       // Warm orange
    Color ball_highlight = (Color){255, 220, 150, 255};  // Lighter highlight

    for (int i = 0; i < manager->capacity; i++) {
        Ball* ball = &manager->balls_current[i];
        if (ball->active) {
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

    if (manager->spawn_cooldown > 0) {
        manager->spawn_cooldown -= dt;
    }
}
// }}}

// {{{ ball_manager_can_spawn
int ball_manager_can_spawn(BallManager* manager) {
    if (!manager) return 0;

    return manager->spawn_cooldown <= 0 &&
           manager->active_count < manager->capacity;
}
// }}}

// {{{ ball_manager_reset_cooldown
void ball_manager_reset_cooldown(BallManager* manager) {
    if (!manager) return;

    manager->spawn_cooldown = SPAWN_COOLDOWN;
}
// }}}

// {{{ ball_manager_prepare_tasks
void ball_manager_prepare_tasks(BallManager* manager, World* world, float dt) {
    if (!manager) return;

    // Update task data for all balls
    // Each task data entry has immutable ball_index,
    // but buffer pointers, world, and dt change each frame
    for (int i = 0; i < manager->capacity; i++) {
        manager->task_data[i].read_buffer = manager->balls_current;
        manager->task_data[i].write_buffer = manager->balls_next;
        manager->task_data[i].world = world;
        manager->task_data[i].dt = dt;
    }
}
// }}}

// {{{ ball_update_task
void ball_update_task(void* data) {
    // Cast task data
    BallTaskData* task = (BallTaskData*)data;
    if (!task) return;

    // Initialize score_delta to 0 (no points scored yet)
    task->score_delta = 0;

    // Get ball pointers using immutable ball_index
    Ball* current = &task->read_buffer[task->ball_index];
    Ball* next = &task->write_buffer[task->ball_index];

    // Update physics (gravity, velocity, position)
    ball_update_physics(current, next, task->dt);

    // Perform collision detection and response on next buffer
    // Only if ball is still active after physics update
    if (next->active) {
        ball_collide_with_pegs(next, task->world);
        ball_collide_with_walls(next, task->world->width, task->world->height);
        ball_check_bounds(next, task->world->height);

        // Check if ball entered a score zone
        // This happens after all physics and collision updates
        if (next->active) {
            int zone_index = ball_check_zone(next, task->world);
            if (zone_index >= 0) {
                // Ball captured by zone
                // Award points and deactivate ball
                task->score_delta = task->world->zones[zone_index].points;
                next->active = 0;
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
        // Reset score_delta for next frame
        manager->task_data[i].score_delta = 0;
    }

    return total;
}
// }}}

// {{{ ball_check_zone
int ball_check_zone(Ball* ball, World* world) {
    if (!ball || !world) return -1;
    if (!ball->active) return -1;

    // Check if ball has entered the score zone area
    // ZONE_TOP_Y (560.0f) defines the top of the zone area
    if (ball->y <= ZONE_TOP_Y) return -1;

    // Ball is below the zone threshold, check which zone it's in
    // Uses ball center point (not radius) for zone detection
    for (int i = 0; i < world->zone_count; i++) {
        ScoreZone* zone = &world->zones[i];

        // Check if ball x-position is within zone boundaries
        if (ball->x >= zone->x_min && ball->x < zone->x_max) {
            return i;  // Return zone index
        }
    }

    // Ball is below zone threshold but not in any zone
    // (between zones or outside leftmost/rightmost zones)
    return -1;
}
// }}}
