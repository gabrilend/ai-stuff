// src/041-spawner.c
// Unified spawner implementation
// Pure functions first, effectful functions second

#include <math.h>
#include "040-spawner.h"
#include "006-ball.h"
#include "raylib.h"

// ============================================================================
// PURE FUNCTIONS
// ============================================================================

// {{{ spawner_accumulate
float spawner_accumulate(float current_credits, float rate, float dt, float max_credits) {
    float new_credits = current_credits + rate * dt;
    if (new_credits > max_credits) {
        new_credits = max_credits;
    }
    return new_credits;
}
// }}}

// {{{ spawner_is_blocked
int spawner_is_blocked(float x, float y, float radius,
                       Ball* balls, int count, int owner_filter) {
    float min_dist = radius * 3.0f;  // Safety margin to prevent physics issues
    float min_dist_sq = min_dist * min_dist;

    for (int i = 0; i < count; i++) {
        Ball* ball = &balls[i];
        if (!ball->active) continue;

        // Filter by owner if specified (-1 means check all)
        if (owner_filter >= 0 && ball->owner != owner_filter) continue;

        float dx = ball->x - x;
        float dy = ball->y - y;
        float dist_sq = dx * dx + dy * dy;

        if (dist_sq < min_dist_sq) {
            return 1;  // Blocked
        }
    }
    return 0;  // Clear
}
// }}}

// {{{ spawner_oscillate
float spawner_oscillate(float current_x, float direction, float speed, float dt,
                        float min_x, float max_x, float* out_new_direction) {
    float new_x = current_x + speed * direction * dt;
    float new_direction = direction;

    // Bounce off boundaries
    if (new_x < min_x) {
        new_x = min_x;
        new_direction = 1.0f;  // Move right
    }
    if (new_x > max_x) {
        new_x = max_x;
        new_direction = -1.0f;  // Move left
    }

    if (out_new_direction) {
        *out_new_direction = new_direction;
    }
    return new_x;
}
// }}}

// ============================================================================
// EFFECTFUL FUNCTIONS
// ============================================================================

// {{{ spawner_create
Spawner spawner_create(float x, float y, float rate, int owner, float gravity_dir) {
    Spawner spawner = {0};
    spawner.x = x;
    spawner.y = y;
    spawner.credits = (owner == OWNER_PLAYER) ? 1.0f : 0.0f;  // Player starts ready
    spawner.rate = rate;
    spawner.owner = owner;
    spawner.gravity_dir = gravity_dir;
    spawner.spawn_count = 0;
    spawner.direction = 1.0f;  // Start moving right
    spawner.move_speed = 120.0f;  // Default speed

    // Default colors (will be overwritten by spawner_set_colors)
    spawner.color_dim[0] = 60;
    spawner.color_dim[1] = 60;
    spawner.color_dim[2] = 60;
    spawner.color_dim[3] = 150;
    spawner.color_bright[0] = 200;
    spawner.color_bright[1] = 200;
    spawner.color_bright[2] = 200;
    spawner.color_bright[3] = 220;

    return spawner;
}
// }}}

// {{{ spawner_set_colors
void spawner_set_colors(Spawner* spawner,
                        unsigned char dim_r, unsigned char dim_g,
                        unsigned char dim_b, unsigned char dim_a,
                        unsigned char bright_r, unsigned char bright_g,
                        unsigned char bright_b, unsigned char bright_a) {
    if (!spawner) return;
    spawner->color_dim[0] = dim_r;
    spawner->color_dim[1] = dim_g;
    spawner->color_dim[2] = dim_b;
    spawner->color_dim[3] = dim_a;
    spawner->color_bright[0] = bright_r;
    spawner->color_bright[1] = bright_g;
    spawner->color_bright[2] = bright_b;
    spawner->color_bright[3] = bright_a;
}
// }}}

// {{{ spawner_set_bounds
void spawner_set_bounds(Spawner* spawner, float min_x, float max_x, float move_speed) {
    if (!spawner) return;
    spawner->min_x = min_x;
    spawner->max_x = max_x;
    spawner->move_speed = move_speed;
}
// }}}

// {{{ spawner_update
void spawner_update(Spawner* spawner, SpawnerController controller,
                    void* controller_data, float dt) {
    if (!spawner) return;

    // Accumulate spawn credits
    spawner->credits = spawner_accumulate(
        spawner->credits, spawner->rate, dt, MAX_SPAWN_CREDITS);

    // Update position via controller (if provided)
    if (controller) {
        controller(spawner, controller_data, dt);
    }
}
// }}}

// {{{ spawner_try_spawn
int spawner_try_spawn(Spawner* spawner, BallManager* manager, float ball_radius) {
    if (!spawner || !manager) return 0;

    // Need at least 1.0 credits to spawn
    if (spawner->credits < 1.0f) return 0;

    // Check if spawn area is blocked (only by same-owner balls)
    if (spawner_is_blocked(spawner->x, spawner->y, ball_radius,
                           manager->balls_current, manager->capacity,
                           spawner->owner)) {
        return 0;
    }

    // Check capacity
    if (manager->active_count >= manager->capacity) return 0;

    // Spawn the ball
    int success = ball_manager_spawn(manager, spawner->x, spawner->y,
                                     ball_radius, spawner->owner,
                                     spawner->gravity_dir);
    if (success) {
        spawner->credits -= 1.0f;
        spawner->spawn_count++;
    }
    return success;
}
// }}}

// {{{ spawner_render
void spawner_render(Spawner* spawner) {
    if (!spawner) return;

    // Pulsing reticle crosshairs
    float pulse = sinf((float)GetTime() * 4.0f) * 0.5f + 0.5f;
    unsigned char alpha = (unsigned char)(pulse * 150.0f + 50.0f);

    Color reticle_color = {
        spawner->color_bright[0],
        spawner->color_bright[1],
        spawner->color_bright[2],
        alpha
    };

    DrawCircleLines((int)spawner->x, (int)spawner->y, 15.0f, reticle_color);

    // Cooldown progress ring
    // Colors invert on each spawn for visual continuity (issue 1303)
    // - Odd spawn count: dim background, bright progress (fills up)
    // - Even spawn count: bright background, dim progress (appears to empty)
    int inverted = spawner->spawn_count % 2;
    float credits_frac = spawner->credits - (int)spawner->credits;

    Color dim_color = {
        spawner->color_dim[0],
        spawner->color_dim[1],
        spawner->color_dim[2],
        spawner->color_dim[3]
    };
    Color bright_color = {
        spawner->color_bright[0],
        spawner->color_bright[1],
        spawner->color_bright[2],
        spawner->color_bright[3]
    };

    // Swap colors based on phase for seamless visual continuity
    Color bg_color = inverted ? bright_color : dim_color;
    Color arc_color = inverted ? dim_color : bright_color;

    // Background ring (full circle)
    DrawRing((Vector2){spawner->x, spawner->y}, 18.0f, 20.0f,
            0, 360, 32, bg_color);

    // Progress arc - shows fractional progress toward next credit
    float arc_degrees = 360.0f * credits_frac;
    DrawRing((Vector2){spawner->x, spawner->y}, 18.0f, 20.0f,
            -90, -90 + arc_degrees, 32, arc_color);
}
// }}}

// {{{ spawner_reset
void spawner_reset(Spawner* spawner, float center_x, float y) {
    if (!spawner) return;
    spawner->x = center_x;
    spawner->y = y;
    spawner->credits = (spawner->owner == OWNER_PLAYER) ? 1.0f : 0.0f;
    spawner->direction = 1.0f;
    spawner->spawn_count = 0;
}
// }}}

// ============================================================================
// CONTROLLER FUNCTIONS
// ============================================================================

// {{{ controller_ai_track
void controller_ai_track(Spawner* spawner, void* data, float dt) {
    (void)data;  // Unused
    if (!spawner) return;

    spawner->x = spawner_oscillate(
        spawner->x, spawner->direction, spawner->move_speed, dt,
        spawner->min_x, spawner->max_x, &spawner->direction);
}
// }}}
