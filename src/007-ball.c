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
#include "014-stage.h"
#include "016-ramp.h"
#include "028-portal.h"
#include "036-wrap-zones.h"
#include "045-zone-dispatch.h"
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
    // NOTE: spawn_credits moved to Spawner struct (issue 1309)

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
        // Sleep system (issue 221a): newly spawned balls start awake
        manager->balls_current[i].is_sleeping = 0;
        manager->balls_current[i].frames_at_rest = 0;
        manager->balls_current[i].pre_sleep_velocity = 0.0f;
        // Zone dispatch fields (issue 318)
        manager->balls_current[i].pending_score = 0;
        manager->balls_current[i].score_x = 0.0f;
        manager->balls_current[i].score_y = 0.0f;

        manager->balls_next[i].active = 0;
        manager->balls_next[i].radius = BALL_RADIUS;
        manager->balls_next[i].gravity_dir = 1.0f;
        manager->balls_next[i].owner = OWNER_PLAYER;
        manager->balls_next[i].passed_gate = 0;
        // Sleep system (issue 221a)
        manager->balls_next[i].is_sleeping = 0;
        manager->balls_next[i].frames_at_rest = 0;
        manager->balls_next[i].pre_sleep_velocity = 0.0f;
        // Zone dispatch fields (issue 318)
        manager->balls_next[i].pending_score = 0;
        manager->balls_next[i].score_x = 0.0f;
        manager->balls_next[i].score_y = 0.0f;

        // Initialize task data with immutable ball_index
        manager->task_data[i].ball_index = i;
    }

    // Initialize random ball colors (issue 1301)
    // Generate random hue for player, complementary hue for adversary
    float player_hue = (float)(rand() % 360);
    float adversary_hue = fmodf(player_hue + 180.0f, 360.0f);

    // Player colors: random hue, high saturation, good brightness
    Color pc = ColorFromHSV(player_hue, 0.8f, 0.95f);
    Color ph = ColorFromHSV(player_hue, 0.4f, 1.0f);  // Lighter highlight

    // Adversary colors: complementary hue
    Color ac = ColorFromHSV(adversary_hue, 0.8f, 0.95f);
    Color ah = ColorFromHSV(adversary_hue, 0.4f, 1.0f);  // Lighter highlight

    // Store colors as RGBA byte arrays
    manager->player_color[0] = pc.r; manager->player_color[1] = pc.g;
    manager->player_color[2] = pc.b; manager->player_color[3] = pc.a;
    manager->player_highlight[0] = ph.r; manager->player_highlight[1] = ph.g;
    manager->player_highlight[2] = ph.b; manager->player_highlight[3] = ph.a;
    manager->adversary_color[0] = ac.r; manager->adversary_color[1] = ac.g;
    manager->adversary_color[2] = ac.b; manager->adversary_color[3] = ac.a;
    manager->adversary_highlight[0] = ah.r; manager->adversary_highlight[1] = ah.g;
    manager->adversary_highlight[2] = ah.b; manager->adversary_highlight[3] = ah.a;

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
            ball->portal_cooldown = 0;  // Start with no portal cooldown
            // Sleep system (issue 221a): spawned balls start awake with full velocity
            ball->is_sleeping = 0;
            ball->frames_at_rest = 0;
            ball->pre_sleep_velocity = 0.0f;
            // Zone dispatch fields (issue 318): no pending score at spawn
            ball->pending_score = 0;
            ball->score_x = 0.0f;
            ball->score_y = 0.0f;
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
// Sleep system (issue 221a): sleeping balls skip gravity and position updates
static void ball_update_physics(Ball* current, Ball* next, float dt) {
    // Copy constant properties
    next->active = current->active;
    next->radius = current->radius;
    next->gravity_dir = current->gravity_dir;
    next->health = current->health;
    next->owner = current->owner;
    next->passed_gate = current->passed_gate;
    next->portal_cooldown = current->portal_cooldown;
    // Sleep system (issue 221a): copy sleep state
    next->is_sleeping = current->is_sleeping;
    next->frames_at_rest = current->frames_at_rest;
    next->pre_sleep_velocity = current->pre_sleep_velocity;

    if (!current->active) return;

    // Sleep system (issue 221a): sleeping balls don't move or accelerate
    // They maintain position but can still receive collision forces
    if (current->is_sleeping) {
        next->x = current->x;
        next->y = current->y;
        next->vx = 0.0f;
        next->vy = 0.0f;
        return;
    }

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

// {{{ ball_update_sleep_tracking
// Internal function to track frames at rest for sleep system (issue 221a)
// Called each frame after collision resolution to update sleep tracking state.
// Does NOT transition to sleep - that's handled by issue 221b.
// Returns current speed for use by caller.
static float ball_update_sleep_tracking(Ball* ball) {
    if (!ball || !ball->active) return 0.0f;

    float speed = sqrtf(ball->vx * ball->vx + ball->vy * ball->vy);

    if (speed < SLEEP_VELOCITY_THRESHOLD) {
        // Ball is at rest - increment counter
        ball->frames_at_rest++;
    } else {
        // Ball is moving - reset counter
        ball->frames_at_rest = 0;
    }

    return speed;
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
// Separates ball from peg and reflects velocity using peg's properties
// Low-speed impacts: zero restitution, near-zero friction (slide instead of bounce)
static void ball_resolve_peg_collision(Ball* ball, Peg* peg, float nx, float ny,
                                        float depth) {
    // Separate ball from peg along collision normal
    ball->x += nx * (depth + COLLISION_BIAS);
    ball->y += ny * (depth + COLLISION_BIAS);

    // Calculate velocity component along normal
    float vn = ball->vx * nx + ball->vy * ny;

    // Only respond if moving into peg (negative means approaching)
    if (vn < 0) {
        // Check closing speed for velocity-dependent response
        float closing_speed = -vn;
        float restitution, friction;

        if (closing_speed < LOW_SPEED_THRESHOLD) {
            // Low-speed impact: no bounce, minimal friction (encourages sliding)
            restitution = 0.0f;
            friction = LOW_SPEED_FRICTION;
        } else {
            // Normal impact: use peg's properties
            restitution = (peg->restitution > 0.001f) ? peg->restitution : RESTITUTION;
            friction = peg->friction;
        }

        // Reflect velocity with restitution
        // Formula: v' = v - (1 + e) * (v · n) * n
        ball->vx -= (1.0f + restitution) * vn * nx;
        ball->vy -= (1.0f + restitution) * vn * ny;

        // Apply friction to tangential velocity
        if (friction > 0.001f) {
            // Tangent is perpendicular to normal
            float tx = -ny;
            float ty = nx;
            float vt = ball->vx * tx + ball->vy * ty;  // Tangential velocity
            float friction_factor = 1.0f - friction * 0.5f;  // Scale friction effect
            ball->vx -= vt * tx * (1.0f - friction_factor);
            ball->vy -= vt * ty * (1.0f - friction_factor);
        }
    }
}
// }}}

// {{{ ball_collide_with_pegs
// Internal function to check and resolve collisions with all pegs
// Checks both player pegs and adversary pegs
// Uses per-peg restitution and friction properties
static void ball_collide_with_pegs(Ball* ball, World* world) {
    float nx, ny, depth;

    // Check player pegs
    for (int i = 0; i < world->peg_count; i++) {
        Peg* peg = &world->pegs[i];
        if (ball_check_peg_collision(ball, peg, &nx, &ny, &depth)) {
            ball_resolve_peg_collision(ball, peg, nx, ny, depth);
        }
    }

    // Check adversary pegs
    if (world->adversary_pegs) {
        for (int i = 0; i < world->adversary_peg_count; i++) {
            Peg* peg = &world->adversary_pegs[i];
            if (ball_check_peg_collision(ball, peg, &nx, &ny, &depth)) {
                ball_resolve_peg_collision(ball, peg, nx, ny, depth);
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
// Low-speed impacts: zero restitution (no bounce at all)
static void ball_resolve_bumper_collision(Ball* ball, float nx, float ny,
                                           float depth) {
    // Separate ball from bumper along collision normal
    ball->x += nx * (depth + COLLISION_BIAS);
    ball->y += ny * (depth + COLLISION_BIAS);

    // Calculate velocity component along normal
    float vn = ball->vx * nx + ball->vy * ny;

    // Only respond if moving into bumper (negative means approaching)
    if (vn < 0) {
        // Check closing speed for velocity-dependent response
        float closing_speed = -vn;
        float restitution = (closing_speed < LOW_SPEED_THRESHOLD) ? 0.0f : BUMPER_RESTITUTION;

        // Apply restitution
        ball->vx -= (1.0f + restitution) * vn * nx;
        ball->vy -= (1.0f + restitution) * vn * ny;

        // Additional damping to tangential velocity for "sticky" feel
        // Skip for low-speed impacts (let them slide freely)
        if (closing_speed >= LOW_SPEED_THRESHOLD) {
            float tangent_damping = 0.7f;
            float vt = ball->vx * (-ny) + ball->vy * nx;  // Tangent component
            ball->vx -= (1.0f - tangent_damping) * vt * (-ny);
            ball->vy -= (1.0f - tangent_damping) * vt * nx;
        }
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

// {{{ ball_collide_with_ramps
// Internal function to check and resolve collisions with ramps in stage manager
// Checks both player stages and adversary stages for ramp obstacles
static void ball_collide_with_ramps(Ball* ball, World* world) {
    // Only check if stage manager exists (stages have been purchased)
    if (!world->stages) return;

    StageManager* stages = world->stages;
    float penetration, contact_x, contact_y;

    // Check player stage ramps
    for (int s = 0; s < stages->player_stage_count; s++) {
        Stage* stage = &stages->player_stages[s];
        if (stage->type != STAGE_TYPE_RAMPS || !stage->ramps) continue;

        for (int r = 0; r < stage->ramp_count; r++) {
            if (ramp_check_collision(ball, &stage->ramps[r],
                                     &penetration, &contact_x, &contact_y)) {
                ramp_resolve_collision(ball, &stage->ramps[r], penetration);
            }
        }
    }

    // Check adversary stage ramps
    for (int s = 0; s < stages->adversary_stage_count; s++) {
        Stage* stage = &stages->adversary_stages[s];
        if (stage->type != STAGE_TYPE_RAMPS || !stage->ramps) continue;

        for (int r = 0; r < stage->ramp_count; r++) {
            if (ramp_check_collision(ball, &stage->ramps[r],
                                     &penetration, &contact_x, &contact_y)) {
                ramp_resolve_collision(ball, &stage->ramps[r], penetration);
            }
        }
    }
}
// }}}

// {{{ line_closest_point
// Finds the closest point on a line segment to a given point
static void line_closest_point(float px, float py,
                               float x1, float y1, float x2, float y2,
                               float* out_x, float* out_y) {
    float dx = px - x1;
    float dy = py - y1;
    float sx = x2 - x1;
    float sy = y2 - y1;
    float seg_len_sq = sx * sx + sy * sy;

    if (seg_len_sq < 0.0001f) {
        *out_x = x1;
        *out_y = y1;
        return;
    }

    float t = (dx * sx + dy * sy) / seg_len_sq;
    if (t < 0.0f) t = 0.0f;
    if (t > 1.0f) t = 1.0f;

    *out_x = x1 + t * sx;
    *out_y = y1 + t * sy;
}
// }}}

// {{{ ball_collide_with_line
// Checks and resolves collision between ball and a single line
// Low-speed impacts: zero restitution, near-zero friction (slide instead of bounce)
static void ball_collide_with_line(Ball* ball, Line* line) {
    if (!ball || !line) return;

    // Find closest point on line segment to ball center
    float px, py;
    line_closest_point(ball->x, ball->y,
                       line->x1, line->y1, line->x2, line->y2,
                       &px, &py);

    // Calculate distance from ball center to closest point
    float dx = ball->x - px;
    float dy = ball->y - py;
    float dist_sq = dx * dx + dy * dy;

    // Collision radius includes line thickness
    float collision_radius = ball->radius + line->thickness / 2.0f;

    if (dist_sq < collision_radius * collision_radius) {
        float dist = sqrtf(dist_sq);
        float penetration = collision_radius - dist;

        // Calculate collision normal
        float nx, ny;
        if (dist < 0.0001f) {
            // Ball center on line - use line perpendicular
            float lx = line->x2 - line->x1;
            float ly = line->y2 - line->y1;
            float len = sqrtf(lx * lx + ly * ly);
            if (len > 0.0001f) {
                nx = -ly / len;
                ny = lx / len;
            } else {
                nx = 0;
                ny = -1;
            }
        } else {
            nx = dx / dist;
            ny = dy / dist;
        }

        // Push ball out
        ball->x += nx * penetration;
        ball->y += ny * penetration;

        // Calculate velocity component along normal
        float dot_normal = ball->vx * nx + ball->vy * ny;

        // Only resolve if ball is moving into the line
        if (dot_normal < 0) {
            // Check closing speed for velocity-dependent response
            float closing_speed = -dot_normal;
            float restitution;

            if (closing_speed < LOW_SPEED_THRESHOLD) {
                // Low-speed impact: no bounce, minimal friction (encourages sliding)
                restitution = 0.0f;
                // Note: line friction is already low by default, so we don't override it
            } else {
                // Normal impact: use line's restitution
                restitution = line->restitution;
            }

            // Remove normal component with restitution
            float bounce_factor = 1.0f + restitution;
            ball->vx -= bounce_factor * dot_normal * nx;
            ball->vy -= bounce_factor * dot_normal * ny;
        }
    }
}
// }}}

// {{{ ball_collide_with_lines
// Internal function to check and resolve collisions with lines in world
// Checks both player lines and adversary lines
static void ball_collide_with_lines(Ball* ball, World* world) {
    if (!world) return;

    // Check player lines
    if (world->lines) {
        for (int i = 0; i < world->line_count; i++) {
            ball_collide_with_line(ball, &world->lines[i]);
        }
    }

    // Check adversary lines
    if (world->adversary_lines) {
        for (int i = 0; i < world->adversary_line_count; i++) {
            ball_collide_with_line(ball, &world->adversary_lines[i]);
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
    // Null check for safety
    if (!ball_a || !ball_b) return 0;

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

// {{{ ball_resolve_pile_collision
// Soft collision for slow-moving balls (issue 221d)
// Uses position-based separation instead of velocity impulses.
// This prevents energy from being added to piles of stationary balls.
// Only applies response to ball_a (caller handles ball_b separately).
static void ball_resolve_pile_collision(Ball* ball_a, Ball* ball_b,
                                         float nx, float ny, float depth) {
    if (!ball_a || !ball_b) return;

    // Soft push using position adjustment, not velocity
    // Split separation between both balls (each moves half)
    float push = depth * PILE_PUSH_FACTOR * 0.5f;

    ball_a->x += nx * push;
    ball_a->y += ny * push;

    // No velocity change - this is the key difference from standard collision
    // Velocity naturally drains via damping, allowing pile to settle
}
// }}}

// {{{ ball_resolve_ball_collision
// Internal function to resolve collision between two balls
// Only applies response to ball_a (caller handles ball_b separately)
// Cross-board collisions (player vs adversary) deal damage
// Routes to soft or standard collision based on ball speeds (issue 221d)
static void ball_resolve_ball_collision(Ball* ball_a, Ball* ball_b,
                                         float nx, float ny, float depth) {
    // Null check for safety
    if (!ball_a || !ball_b) return;

    // Calculate speeds for routing decision (issue 221d)
    float speed_a = sqrtf(ball_a->vx * ball_a->vx + ball_a->vy * ball_a->vy);
    float speed_b = sqrtf(ball_b->vx * ball_b->vx + ball_b->vy * ball_b->vy);
    float max_speed = (speed_a > speed_b) ? speed_a : speed_b;

    // Both balls nearly stationary - use soft collision (issue 221d)
    // This prevents pile explosions from accumulated impulses
    if (max_speed < SOFT_COLLISION_THRESHOLD) {
        ball_resolve_pile_collision(ball_a, ball_b, nx, ny, depth);
        return;
    }

    // Standard collision with position separation and velocity impulse
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
        float closing_speed = -vn;

        // Check if this is a cross-board collision (player vs adversary)
        if (ball_a->owner != ball_b->owner) {
            // Calculate damage based on closing speed (velocity along collision normal)
            // Head-on collisions deal full damage, glancing blows deal little/none
            // Only deal damage above threshold (gentle bumps are harmless)
            if (closing_speed > DAMAGE_SPEED_THRESHOLD) {
                float effective_speed = closing_speed - DAMAGE_SPEED_THRESHOLD;
                float damage = effective_speed * DAMAGE_VELOCITY_SCALE;
                ball_a->health -= damage;
            }
        }

        // Blend between soft and standard collision for intermediate speeds (issue 221d)
        // This provides smooth transition instead of jarring behavior change
        float blend = 1.0f;  // 1.0 = full standard collision
        if (max_speed < BLEND_THRESHOLD) {
            // Linear blend: 0 at SOFT_COLLISION_THRESHOLD, 1 at BLEND_THRESHOLD
            blend = (max_speed - SOFT_COLLISION_THRESHOLD) /
                    (BLEND_THRESHOLD - SOFT_COLLISION_THRESHOLD);
            if (blend < 0.0f) blend = 0.0f;
            if (blend > 1.0f) blend = 1.0f;
        }

        // Velocity-dependent restitution: low-speed impacts don't bounce
        float restitution = (closing_speed < LOW_SPEED_THRESHOLD) ? 0.0f : RESTITUTION;

        // Equal mass elastic collision: swap velocity components along normal
        // For ball_a, we add the impulse; ball_b will be handled by its own task
        // Scale impulse by blend factor for smooth transition (issue 221d)
        float impulse = -(1.0f + restitution) * vn * blend;
        ball_a->vx += impulse * nx;
        ball_a->vy += impulse * ny;
    }
}
// }}}

// {{{ ball_collide_with_balls
// Internal function to check and resolve collisions with other balls
// Tracks cross-owner collisions for splash and explosion effects
// collision_out: array of 9 floats:
//   [0] had_collision, [1] x, [2] y, [3] tangent_x, [4] tangent_y,
//   [5] death_nx, [6] death_ny, [7] this_approach, [8] other_approach
static void ball_collide_with_balls(Ball* ball, int ball_index,
                                     Ball* read_buffer, int capacity,
                                     float* collision_out) {
    // Null and bounds check for safety
    if (!ball || !read_buffer || capacity <= 0) return;
    if (ball_index < 0 || ball_index >= capacity) return;

    float nx, ny, depth;

    // Initialize collision output
    if (collision_out) {
        collision_out[0] = 0.0f;  // had_collision
        collision_out[7] = 0.0f;  // this_approach (for dominance tracking)
        collision_out[8] = 0.0f;  // other_approach
    }

    // Track strongest cross-owner collision for explosion direction
    float strongest_closing = 0.0f;

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

            // Track cross-owner collisions
            if (collision_out && ball->owner != other->owner && vn < -10.0f) {
                // Track splash collision (first one, lower index only)
                if (collision_out[0] == 0.0f && ball_index < i) {
                    collision_out[0] = 1.0f;  // had_collision
                    collision_out[1] = (ball->x + other->x) * 0.5f;  // x
                    collision_out[2] = (ball->y + other->y) * 0.5f;  // y
                    collision_out[3] = -ny;  // tangent_x
                    collision_out[4] = nx;   // tangent_y
                }

                // Track strongest collision for explosion direction
                // (used if ball dies from accumulated damage)
                float closing = -vn;  // Positive closing speed
                if (closing > strongest_closing) {
                    strongest_closing = closing;
                    collision_out[5] = nx;   // death_nx (points toward this ball)
                    collision_out[6] = ny;   // death_ny

                    // Calculate individual approach speeds for dominance
                    // Normal points from other to this ball
                    // This ball's approach = how fast we're moving toward other
                    float this_approach = -(current_ball->vx * nx + current_ball->vy * ny);
                    // Other ball's approach = how fast they're moving toward us
                    float other_approach = other->vx * nx + other->vy * ny;

                    collision_out[7] = this_approach;
                    collision_out[8] = other_approach;
                }
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
    // Only applies to player balls - adversary balls pass through to wrap zones
    // Use wrap zone top if available, otherwise fall back to spawn position
    // This allows wrapped balls to fall from the top zone into the viewable area
    if (ball->gravity_dir > 0) {
        float top_wall;
        if (world->wrap_zones) {
            // Top wall is at top of the top wrap zone
            top_wall = world->wrap_zones->top_zone_y;
        } else {
            // Fallback: above spawn point
            top_wall = SPAWN_Y - BALL_RADIUS - 20.0f;
        }
        if (ball->y - ball->radius < top_wall) {
            ball->y = top_wall + ball->radius;
            ball->vy = -ball->vy * WALL_RESTITUTION;
        }
    }

    // No bottom wall - balls fall through to score zones (player balls)
    // No top wall for adversary balls - they pass through to despawn
}
// }}}

// NOTE: ball_check_bounds removed - wrapping now handled by WrapZones system
// See 036-wrap-zones.h and wrap_zones_check_ball() for dynamic wrap zone implementation

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
            ball_collide_with_ramps(next, world);
            ball_collide_with_lines(next, world);
            ball_collide_with_walls(next, world);

            // Check wrap zones for ball teleportation at screen edges
            if (world->wrap_zones) {
                wrap_zones_check_ball(world->wrap_zones, next);
            }

            // Sleep system (issue 221a): update frames_at_rest tracking
            ball_update_sleep_tracking(next);

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

    // Unpack stored colors (issue 1301 - random complementary colors)
    Color player_color = {manager->player_color[0], manager->player_color[1],
                          manager->player_color[2], manager->player_color[3]};
    Color player_highlight = {manager->player_highlight[0], manager->player_highlight[1],
                              manager->player_highlight[2], manager->player_highlight[3]};
    Color adversary_color = {manager->adversary_color[0], manager->adversary_color[1],
                             manager->adversary_color[2], manager->adversary_color[3]};
    Color adversary_highlight = {manager->adversary_highlight[0], manager->adversary_highlight[1],
                                 manager->adversary_highlight[2], manager->adversary_highlight[3]};

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

// NOTE: Spawn cooldown functions removed (issue 1309)
// Spawn credits now managed by Spawner struct in 040-spawner.h
// Removed: ball_manager_update_cooldown, ball_manager_can_spawn,
//          ball_manager_reset_cooldown, ball_manager_spawn_blocked

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
        ball_collide_with_ramps(next, task->world);
        ball_collide_with_lines(next, task->world);

        // Track cross-owner ball collisions for splash particles and explosion direction
        float collision_info[9] = {0};
        ball_collide_with_balls(next, task->ball_index,
                               task->read_buffer, task->capacity, collision_info);

        // Copy splash collision info to task data
        if (collision_info[0] > 0.5f) {
            task->had_collision = 1;
            task->collision_x = collision_info[1];
            task->collision_y = collision_info[2];
            task->collision_tx = collision_info[3];
            task->collision_ty = collision_info[4];
        }

        ball_collide_with_walls(next, task->world);

        // Zone dispatch system (issue 318)
        // When zone_grid is active, use unified dispatch for wrap zones and scoring
        // This replaces separate wrap_zones_check_ball and ball_check_zone calls
        if (task->world->zone_grid) {
            // Reset pending_score before dispatch
            next->pending_score = 0;

            // Dispatch handles: background (reset passed_gate), gates (scoring),
            // wrap zones (teleportation), walls (reflection)
            zone_dispatch(next, task->world->zone_grid);
        } else {
            // Fallback: Check wrap zones for ball teleportation at screen edges
            if (task->world->wrap_zones) {
                wrap_zones_check_ball(task->world->wrap_zones, next);
            }
        }

        // Check portals for teleportation
        // Decrement cooldown each frame, then check for entry
        if (next->portal_cooldown > 0) {
            next->portal_cooldown--;
        }

        if (task->world->portals && next->active) {
            float teleport_x, teleport_y;
            if (portal_manager_check_ball(task->world->portals, next,
                                          &teleport_x, &teleport_y)) {
                // Teleport ball to exit position
                next->x = teleport_x;
                next->y = teleport_y;
                // Set cooldown to prevent immediate re-entry
                next->portal_cooldown = PORTAL_COOLDOWN_FRAMES;
            }
        }

        // Sleep system (issue 221a): update frames_at_rest tracking
        // Called after all collisions resolved so velocity is final for this frame
        ball_update_sleep_tracking(next);

        // Check if ball died from cross-board collision damage
        if (next->active && next->health <= 0) {
            task->died_from_damage = 1;
            task->death_pos_x = next->x;
            task->death_pos_y = next->y;
            task->death_vx = next->vx;
            task->death_vy = next->vy;

            // Copy explosion direction info
            task->death_nx = collision_info[5];
            task->death_ny = collision_info[6];
            // Dominant if our approach speed >= other's approach speed
            task->death_was_dominant = (collision_info[7] >= collision_info[8]) ? 1 : 0;

            next->active = 0;
        }

        // Check if ball entered a score zone
        // This happens after all physics and collision updates
        // Balls pass through gates (don't deactivate) for adversary mode
        // passed_gate flag prevents double-scoring
        if (next->active) {
            if (task->world->zone_grid) {
                // Zone dispatch system (issue 318): scoring set via pending_score
                // zone_dispatch already called above, which set pending_score if in gate
                if (next->pending_score > 0) {
                    task->score_delta = next->pending_score;
                    task->scored = 1;
                    task->score_pos_x = next->score_x;
                    task->score_pos_y = next->score_y;
                    // passed_gate already set by zone handler
                }
            } else {
                // Fallback: old zone checking system
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
    if (!world->zones || world->zone_count <= 0) return -1;

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

// {{{ ball_manager_handle_expansion
void ball_manager_handle_expansion(BallManager* manager, float offset,
                                   float expansion_y_start) {
    if (!manager || offset == 0.0f) return;

    // Shift all active balls that are below the expansion point
    // This keeps balls in their correct relative position in the world
    for (int i = 0; i < manager->capacity; i++) {
        // Shift in current buffer
        if (manager->balls_current[i].active &&
            manager->balls_current[i].y > expansion_y_start) {
            manager->balls_current[i].y += offset;
        }

        // Shift in next buffer (may have pending updates)
        if (manager->balls_next[i].active &&
            manager->balls_next[i].y > expansion_y_start) {
            manager->balls_next[i].y += offset;
        }
    }
}
// }}}
