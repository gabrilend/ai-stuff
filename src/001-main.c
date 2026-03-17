// src/001-main.c
// Entry point for physics simulator
// Initializes raylib window, threadpool, world, and runs main game loop
//
// External functions: main

#include <raylib.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "003-threadpool.h"
#include "004-world.h"
#include "006-ball.h"

// {{{ main
int main(void) {
    const int screen_width = 800;
    const int screen_height = 600;

    // Seed random number generator for ball spawning
    srand((unsigned int)time(NULL));

    printf("Physics Simulator - Initializing...\n");

    // Initialize threadpool
    // Using 4 worker threads and queue capacity of 64
    ThreadPool* pool = threadpool_create(4, 64);
    if (!pool) {
        fprintf(stderr, "ERROR: Failed to create threadpool\n");
        return 1;
    }
    printf("Threadpool created: 4 workers, 64 queue capacity\n");

    // Initialize raylib window
    InitWindow(screen_width, screen_height, "Physics Simulator - Pachinko");
    SetTargetFPS(60);
    printf("Raylib window initialized: %dx%d @ 60fps\n", screen_width, screen_height);

    // Create world
    World* world = world_create(screen_width, screen_height);
    if (!world) {
        fprintf(stderr, "ERROR: Failed to create world\n");
        threadpool_destroy(pool);
        CloseWindow();
        return 1;
    }
    printf("World created: %dx%d\n", screen_width, screen_height);

    // Generate peg grid (10 rows, 8 cols, centered)
    float peg_spacing = 60.0f;
    int peg_rows = 10;
    int peg_cols = 8;
    float peg_start_x = (screen_width - (peg_cols * peg_spacing)) / 2.0f;
    float peg_start_y = 80.0f;
    world_generate_pegs(world, peg_rows, peg_cols, peg_start_x, peg_start_y, peg_spacing);
    printf("Generated peg grid: %d rows, %d cols\n", peg_rows, peg_cols);

    // Generate score zones (7 zones, 40 pixels high)
    world_generate_zones(world, 7, 40.0f);
    printf("Generated score zones: 7 zones\n");

    // Create ball manager
    BallManager* ball_manager = ball_manager_create(MAX_BALLS);
    if (!ball_manager) {
        fprintf(stderr, "ERROR: Failed to create ball manager\n");
        world_destroy(world);
        threadpool_destroy(pool);
        CloseWindow();
        return 1;
    }
    printf("Ball manager created: %d capacity\n", MAX_BALLS);

    // Main loop
    printf("Entering main loop...\n");
    printf("Press SPACE to spawn balls\n");
    while (!WindowShouldClose()) {
        // Get delta time for physics
        float dt = GetFrameTime();

        // Update spawn cooldown
        ball_manager_update_cooldown(ball_manager, dt);

        // Handle ball spawning input
        if (IsKeyDown(KEY_SPACE) && ball_manager_can_spawn(ball_manager)) {
            ball_manager_spawn(ball_manager, SPAWN_X, SPAWN_Y);
            ball_manager_reset_cooldown(ball_manager);
        }

        // Parallel ball physics update
        // Sequence: prepare → submit → wait → finalize → swap
        ball_manager_prepare_tasks(ball_manager, world, dt);
        ball_manager_submit_tasks(ball_manager, pool);
        threadpool_wait_all(pool);
        ball_manager_finalize_update(ball_manager);
        ball_manager_swap_buffers(ball_manager);

        // Render
        BeginDrawing();
        ClearBackground(DARKGRAY);

        // Draw title text
        DrawText("Physics Simulator - Pachinko", 10, 10, 20, LIGHTGRAY);

        // Draw world elements
        world_render_pegs(world);
        world_render_zones(world);

        // Draw balls
        ball_manager_render(ball_manager);

        // Draw score, ball count, and instructions
        char score_text[64];
        sprintf(score_text, "Score: %d", world->score);
        DrawText(score_text, 10, screen_height - 30, 16, WHITE);

        char ball_text[64];
        sprintf(ball_text, "Balls: %d", ball_manager->active_count);
        DrawText(ball_text, 10, screen_height - 50, 16, WHITE);

        DrawText("Press SPACE to spawn balls", screen_width - 220, screen_height - 50, 16, GRAY);
        DrawText("Press ESC to exit", screen_width - 150, screen_height - 30, 16, GRAY);

        EndDrawing();
    }

    // Cleanup
    printf("Shutting down...\n");
    CloseWindow();
    printf("Raylib window closed\n");

    ball_manager_destroy(ball_manager);
    printf("Ball manager destroyed\n");

    world_destroy(world);
    printf("World destroyed\n");

    threadpool_destroy(pool);
    printf("Threadpool destroyed\n");

    printf("Clean shutdown complete\n");
    return 0;
}
// }}}
