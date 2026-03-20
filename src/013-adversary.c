// src/013-adversary.c
// Adversary AI implementation
// Uses unified Spawner system with AI controller (issue 1309)

#include <stdio.h>
#include <stdlib.h>
#include "raylib.h"
#include "012-adversary.h"
#include "004-world.h"
#include "006-ball.h"

// {{{ adversary_create
Adversary* adversary_create(World* world) {
    if (!world) return NULL;

    Adversary* adversary = (Adversary*)malloc(sizeof(Adversary));
    if (!adversary) {
        fprintf(stderr, "ERROR: Failed to allocate adversary\n");
        return NULL;
    }

    // Initialize spawn position below adversary board (balls float UP)
    float spawn_y = world->adversary_table_bottom + ADVERSARY_SPAWN_Y_OFFSET;
    float center_x = world->table_x + world->table_width / 2.0f;

    // Create spawner with same rate as player for fairness (issue 1309)
    adversary->spawner = spawner_create(
        center_x,
        spawn_y,
        SPAWN_RATE,  // Same rate as player (was ADVERSARY_SPAWN_RATE = 1.3f)
        OWNER_ADVERSARY,
        -1.0f  // Gravity up (balls float upward)
    );

    // Set adversary reticle colors (red scheme)
    spawner_set_colors(&adversary->spawner, 80, 60, 60, 150, 255, 150, 150, 220);

    // Set spawn bounds for oscillation
    float margin = BALL_RADIUS + 5.0f;
    spawner_set_bounds(&adversary->spawner,
        world->table_x + margin,
        world->table_x + world->table_width - margin,
        ADVERSARY_MOVE_SPEED
    );

    // Enable spawning by default (issue 507)
    adversary->spawning_enabled = 1;

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
    adversary->spawner.y = world->adversary_table_bottom + ADVERSARY_SPAWN_Y_OFFSET;

    // Update bounds in case table moved
    float margin = BALL_RADIUS + 5.0f;
    adversary->spawner.min_x = world->table_x + margin;
    adversary->spawner.max_x = world->table_x + world->table_width - margin;

    // Update spawner with AI track controller (handles credits and oscillation)
    // Credits accumulate regardless of spawning_enabled state (issue 507)
    spawner_update(&adversary->spawner, controller_ai_track, NULL, dt);

    // Only spawn if spawning is enabled (issue 507)
    // When paused, credits accumulate but no balls spawn
    if (adversary->spawning_enabled) {
        spawner_try_spawn(&adversary->spawner, ball_manager, BALL_RADIUS);
    }
}
// }}}

// {{{ adversary_render
void adversary_render(Adversary* adversary) {
    if (!adversary) return;
    spawner_render(&adversary->spawner);

    // Show paused indicator when spawning is disabled (issue 507)
    if (!adversary->spawning_enabled) {
        float x = adversary->spawner.x;
        float y = adversary->spawner.y - 25;
        const char* text = "[PAUSED]";
        int text_width = MeasureText(text, 14);
        DrawText(text, (int)(x - text_width / 2), (int)y, 14, YELLOW);
    }
}
// }}}

// {{{ adversary_reset
void adversary_reset(Adversary* adversary, World* world) {
    if (!adversary || !world) return;

    float spawn_y = world->adversary_table_bottom + ADVERSARY_SPAWN_Y_OFFSET;
    float center_x = world->table_x + world->table_width / 2.0f;

    spawner_reset(&adversary->spawner, center_x, spawn_y);

    // Update bounds
    float margin = BALL_RADIUS + 5.0f;
    adversary->spawner.min_x = world->table_x + margin;
    adversary->spawner.max_x = world->table_x + world->table_width - margin;
}
// }}}

// {{{ adversary_toggle_spawning
int adversary_toggle_spawning(Adversary* adversary) {
    if (!adversary) return 0;
    adversary->spawning_enabled = !adversary->spawning_enabled;
    printf("Adversary spawning: %s\n",
           adversary->spawning_enabled ? "ENABLED" : "PAUSED");
    return adversary->spawning_enabled;
}
// }}}

// {{{ adversary_is_spawning_enabled
int adversary_is_spawning_enabled(Adversary* adversary) {
    if (!adversary) return 0;
    return adversary->spawning_enabled;
}
// }}}
