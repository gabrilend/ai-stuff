// src/013-adversary.c
// Adversary AI implementation
// Controls enemy ball spawning with oscillating reticle movement

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "012-adversary.h"
#include "004-world.h"
#include "006-ball.h"
#include "raylib.h"

// {{{ adversary_create
Adversary* adversary_create(World* world) {
    if (!world) return NULL;

    Adversary* adversary = (Adversary*)malloc(sizeof(Adversary));
    if (!adversary) {
        fprintf(stderr, "ERROR: Failed to allocate adversary\n");
        return NULL;
    }

    // Initialize spawn position below adversary board (balls float UP)
    // Offset matches player's 100px gap from top peg (peg_start_y - SPAWN_Y)
    adversary->spawn_x = world->table_x + world->table_width / 2.0f;
    adversary->spawn_y = world->adversary_table_bottom + ADVERSARY_SPAWN_Y_OFFSET;
    adversary->spawn_direction = 1.0f;  // Start moving right
    adversary->spawn_credits = 0.0f;    // Start with no credits
    adversary->spawn_rate = ADVERSARY_SPAWN_RATE;
    adversary->move_speed = ADVERSARY_MOVE_SPEED;
    adversary->spawn_count = 0;         // Track spawns for color phase (issue 1303)

    return adversary;
}
// }}}

// {{{ adversary_destroy
void adversary_destroy(Adversary* adversary) {
    if (!adversary) return;
    free(adversary);
}
// }}}

// {{{ adversary_update
void adversary_update(Adversary* adversary, World* world,
                      BallManager* ball_manager, float dt) {
    if (!adversary || !world || !ball_manager) return;

    // Update spawn_y in case world bounds changed (resize)
    adversary->spawn_y = world->adversary_table_bottom + ADVERSARY_SPAWN_Y_OFFSET;

    // Move reticle horizontally
    adversary->spawn_x += adversary->move_speed * adversary->spawn_direction * dt;

    // Bounce off table edges
    float margin = BALL_RADIUS + 5.0f;
    float min_x = world->table_x + margin;
    float max_x = world->table_x + world->table_width - margin;

    if (adversary->spawn_x < min_x) {
        adversary->spawn_x = min_x;
        adversary->spawn_direction = 1.0f;  // Move right
    }
    if (adversary->spawn_x > max_x) {
        adversary->spawn_x = max_x;
        adversary->spawn_direction = -1.0f;  // Move left
    }

    // Accumulate spawn credits
    adversary->spawn_credits += adversary->spawn_rate * dt;
    if (adversary->spawn_credits > MAX_SPAWN_CREDITS) {
        adversary->spawn_credits = MAX_SPAWN_CREDITS;
    }

    // Attempt to spawn if we have credits
    if (adversary->spawn_credits >= 1.0f) {
        // Check if spawn area is clear - only check OTHER adversary balls
        // Player balls passing through shouldn't block adversary spawn
        int blocked = 0;
        for (int i = 0; i < ball_manager->capacity; i++) {
            Ball* ball = &ball_manager->balls_current[i];
            if (!ball->active) continue;
            if (ball->owner != OWNER_ADVERSARY) continue;  // Ignore player balls

            float dx = ball->x - adversary->spawn_x;
            float dy = ball->y - adversary->spawn_y;
            float dist_sq = dx * dx + dy * dy;
            float min_dist = ball->radius * 1.5f + BALL_RADIUS;

            if (dist_sq < min_dist * min_dist) {
                blocked = 1;
                break;
            }
        }

        if (!blocked && ball_manager->active_count < ball_manager->capacity) {
            // Spawn adversary ball with reversed gravity (-1.0)
            ball_manager_spawn(ball_manager, adversary->spawn_x, adversary->spawn_y,
                             BALL_RADIUS, OWNER_ADVERSARY, -1.0f);
            adversary->spawn_credits -= 1.0f;
            adversary->spawn_count++;  // Track for color phase (issue 1303)
        }
    }
}
// }}}

// {{{ adversary_render
void adversary_render(Adversary* adversary) {
    if (!adversary) return;

    // Draw spawn reticle (red-tinted to contrast with player's cyan)
    float pulse = sinf((float)GetTime() * 4.0f) * 0.5f + 0.5f;
    unsigned char alpha = (unsigned char)(pulse * 150.0f + 50.0f);

    DrawCircleLines((int)adversary->spawn_x, (int)adversary->spawn_y, 15.0f,
                   (Color){255, 150, 150, alpha});

    // Draw cooldown indicator
    // Uses spawn_credits fractional part for continuous progress
    // Colors invert on each spawn for visual continuity (issue 1303)
    // - Odd spawn count: dim background, bright progress (fills up)
    // - Even spawn count: bright background, dim progress (appears to empty)
    int inverted = adversary->spawn_count % 2;
    float credits_frac = adversary->spawn_credits - (int)adversary->spawn_credits;

    // Define color palette for adversary reticle (red scheme)
    Color dim_red = (Color){80, 60, 60, 150};
    Color bright_red = (Color){255, 150, 150, 220};

    // Swap colors based on phase for seamless visual continuity
    Color bg_color = inverted ? bright_red : dim_red;
    Color arc_color = inverted ? dim_red : bright_red;

    // Background ring (full circle)
    DrawRing((Vector2){adversary->spawn_x, adversary->spawn_y}, 18.0f, 20.0f,
            0, 360, 32, bg_color);

    // Progress arc - always shows fractional progress toward next credit
    float arc_degrees = 360.0f * credits_frac;
    DrawRing((Vector2){adversary->spawn_x, adversary->spawn_y}, 18.0f, 20.0f,
            -90, -90 + arc_degrees, 32, arc_color);
}
// }}}

// {{{ adversary_reset
void adversary_reset(Adversary* adversary, World* world) {
    if (!adversary || !world) return;

    adversary->spawn_x = world->table_x + world->table_width / 2.0f;
    adversary->spawn_y = world->adversary_table_bottom + ADVERSARY_SPAWN_Y_OFFSET;
    adversary->spawn_direction = 1.0f;
    adversary->spawn_credits = 0.0f;
}
// }}}
