// src/001-main.c
// Entry point for physics simulator
// Initializes raylib window, threadpool, world, and runs main game loop
//
// External functions: main

#include <raylib.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#include "003-threadpool.h"
#include "004-world.h"
#include "006-ball.h"
#include "008-particles.h"

// Visual constants - Color palette for cohesive visual design
#define BG_COLOR (Color){30, 30, 40, 255}          // Dark blue-gray background
#define PEG_COLOR (Color){180, 180, 200, 255}      // Light steel peg fill
#define PEG_OUTLINE (Color){100, 100, 120, 255}    // Darker peg outline
#define BALL_COLOR (Color){255, 180, 50, 255}      // Warm orange ball
#define BALL_HIGHLIGHT (Color){255, 220, 150, 255} // Lighter ball highlight

// Scrolling viewport constants
#define SCROLL_SPEED 40.0f    // Pixels per scroll wheel notch

// {{{ main
int main(void) {
    const int screen_width = 800;  // Fixed horizontal size
    int screen_height = 600;       // Will be adjusted to monitor

    // Seed random number generator for ball spawning
    srand((unsigned int)time(NULL));

    printf("Physics Simulator - Initializing...\n");

    // Initialize threadpool with detected optimal thread count
    int thread_count = get_optimal_thread_count();
    ThreadPool* pool = threadpool_create(thread_count, 64);
    if (!pool) {
        fprintf(stderr, "ERROR: Failed to create threadpool\n");
        return 1;
    }
    printf("Threadpool created: %d workers (auto-detected), 64 queue capacity\n",
           thread_count);

    // Initialize raylib window with resizable flag
    // Start with default size, then resize based on monitor detection
    SetConfigFlags(FLAG_WINDOW_RESIZABLE);
    InitWindow(screen_width, screen_height, "Physics Simulator - Pachinko");
    SetTargetFPS(60);

    // Detect monitor size and scale window vertically
    // Works on X11 (i3, dwm) and Wayland (sway) via raylib abstraction
    int monitor = GetCurrentMonitor();
    int monitor_height = GetMonitorHeight(monitor);
    int monitor_width = GetMonitorWidth(monitor);
    printf("Detected monitor %d: %dx%d\n", monitor, monitor_width, monitor_height);

    // Scale window height to 90% of monitor height (leave room for panels/bars)
    // Keep width fixed at 800 as requested
    screen_height = (int)(monitor_height * 0.9f);
    SetWindowSize(screen_width, screen_height);
    printf("Window resized to: %dx%d\n", screen_width, screen_height);

    // World height matches window height (no scrolling needed when full-screen)
    // Can still scroll if world is made larger than window
    int world_height_pixels = screen_height;
    World* world = world_create(screen_width, world_height_pixels);
    if (!world) {
        fprintf(stderr, "ERROR: Failed to create world\n");
        threadpool_destroy(pool);
        CloseWindow();
        return 1;
    }
    printf("World created: %dx%d\n", screen_width, world_height_pixels);

    // Generate peg grid dynamically based on world height
    // Calculate rows to fill available vertical space
    float peg_spacing = 60.0f;
    float peg_start_y = 80.0f;
    float zone_height = 40.0f;
    float bottom_margin = 20.0f;  // Space between last peg row and zones

    // Available space for pegs: world_height - top - zones - margin
    float available_height = world_height_pixels - peg_start_y - zone_height - bottom_margin;
    int peg_rows = (int)(available_height / peg_spacing);
    if (peg_rows < 5) peg_rows = 5;    // Minimum 5 rows
    if (peg_rows > 30) peg_rows = 30;  // Maximum 30 rows

    int peg_cols = 8;
    float peg_start_x = (screen_width - (peg_cols * peg_spacing)) / 2.0f;
    world_generate_pegs(world, peg_rows, peg_cols, peg_start_x, peg_start_y, peg_spacing);
    printf("Generated peg grid: %d rows, %d cols (scaled to window)\n", peg_rows, peg_cols);

    // Generate score zones (7 zones at bottom of world)
    world_generate_zones(world, 7, zone_height);
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

    // Create particle system
    ParticleSystem* particle_system = particle_system_create(256);
    if (!particle_system) {
        fprintf(stderr, "ERROR: Failed to create particle system\n");
        ball_manager_destroy(ball_manager);
        world_destroy(world);
        threadpool_destroy(pool);
        CloseWindow();
        return 1;
    }
    printf("Particle system created: 256 capacity\n");

    // Initialize scrolling viewport
    // World height can be larger than screen for scrollable areas
    float world_height = (float)world_height_pixels;  // Larger than screen enables scrolling
    float viewport_offset_y = 0.0f;             // Current scroll position

    // Setup 2D camera for viewport scrolling
    // Camera centers on viewport position, allowing scroll without
    // modifying individual render positions
    Camera2D camera = { 0 };
    camera.offset = (Vector2){ (float)screen_width / 2.0f,
                               (float)screen_height / 2.0f };
    camera.target = (Vector2){ (float)screen_width / 2.0f,
                               (float)screen_height / 2.0f };
    camera.rotation = 0.0f;
    camera.zoom = 1.0f;
    printf("Viewport initialized: %.0fx%.0f world, scrollable\n",
           (float)screen_width, world_height);

    // Main loop
    printf("Entering main loop...\n");
    printf("Press SPACE to spawn balls, SCROLL to pan view\n");
    while (!WindowShouldClose()) {
        // Get delta time for physics
        float dt = GetFrameTime();

        // Update spawn cooldown
        ball_manager_update_cooldown(ball_manager, dt);

        // Update particle system
        particle_system_update(particle_system, dt);

        // Handle ball spawning input
        // Check cooldown AND that no balls are blocking the spawn area
        // Spawn blocking prevents physics issues when balls overlap at spawn
        if (IsKeyDown(KEY_SPACE) && ball_manager_can_spawn(ball_manager) &&
            !ball_manager_spawn_blocked(ball_manager, SPAWN_X, SPAWN_Y)) {
            ball_manager_spawn(ball_manager, SPAWN_X, SPAWN_Y);
            ball_manager_reset_cooldown(ball_manager);
        }

        // Handle reset input (R key)
        if (IsKeyPressed(KEY_R)) {
            // Reset score
            world->score = 0;

            // Deactivate all balls
            for (int i = 0; i < ball_manager->capacity; i++) {
                ball_manager->balls_current[i].active = 0;
                ball_manager->balls_next[i].active = 0;
            }
            ball_manager->active_count = 0;
        }

        // Handle scroll wheel for viewport panning
        float scroll = GetMouseWheelMove();
        if (scroll != 0.0f) {
            viewport_offset_y -= scroll * SCROLL_SPEED;

            // Clamp viewport to valid range
            // Minimum: can't scroll above top of world
            if (viewport_offset_y < 0.0f) {
                viewport_offset_y = 0.0f;
            }
            // Maximum: can't scroll below bottom of world
            float max_offset = world_height - (float)screen_height;
            if (max_offset < 0.0f) max_offset = 0.0f;
            if (viewport_offset_y > max_offset) {
                viewport_offset_y = max_offset;
            }

            // Update camera target to reflect scroll position
            camera.target.y = (float)screen_height / 2.0f + viewport_offset_y;
        }

        // Parallel ball physics update with performance timing
        // Sequence: prepare → submit → wait → spawn particles → collect scores → finalize → swap
        double physics_start = GetTime();
        ball_manager_prepare_tasks(ball_manager, world, dt);
        ball_manager_submit_tasks(ball_manager, pool);
        threadpool_wait_all(pool);

        // Spawn particle bursts for balls that scored this frame
        // Must happen BEFORE collect_scores because it resets scored/score_delta
        for (int i = 0; i < ball_manager->capacity; i++) {
            BallTaskData* task = &ball_manager->task_data[i];
            if (task->scored) {
                // Choose particle color based on point value
                Color particle_color;
                if (task->score_delta >= 500) {
                    particle_color = GOLD;
                } else if (task->score_delta >= 100) {
                    particle_color = GREEN;
                } else if (task->score_delta >= 50) {
                    particle_color = BLUE;
                } else {
                    particle_color = GRAY;
                }

                // Spawn burst of 12 particles at score position
                particle_spawn_burst(particle_system, task->score_pos_x,
                                   task->score_pos_y, 12, particle_color);
            }
        }

        // Collect scores and reset scoring fields
        int points = ball_manager_collect_scores(ball_manager);
        world->score += points;

        // Update high score if current score exceeds it
        if (world->score > world->high_score) {
            world->high_score = world->score;
        }

        ball_manager_finalize_update(ball_manager);
        ball_manager_swap_buffers(ball_manager);
        double physics_end = GetTime();
        double physics_ms = (physics_end - physics_start) * 1000.0;

        // Render
        BeginDrawing();
        ClearBackground(BG_COLOR);

        // Begin camera mode for world elements (scrollable)
        // All world elements are rendered in camera space
        BeginMode2D(camera);

        // Draw world elements (in camera space - scrollable)
        world_render_pegs(world);
        world_render_zones(world);

        // Draw spawn point indicator (pulsing circle)
        float pulse = sinf((float)GetTime() * 4.0f) * 0.5f + 0.5f;  // Oscillates 0-1
        unsigned char alpha = (unsigned char)(pulse * 150.0f + 50.0f);  // Range: 50-200
        DrawCircleLines((int)SPAWN_X, (int)SPAWN_Y, 15.0f,
                       (Color){255, 255, 255, alpha});

        // Draw cooldown indicator (arc around spawn point)
        if (ball_manager->spawn_cooldown > 0) {
            float cooldown_ratio = ball_manager->spawn_cooldown / SPAWN_COOLDOWN;
            float end_angle = 360.0f * (1.0f - cooldown_ratio);
            DrawRing((Vector2){SPAWN_X, SPAWN_Y}, 18.0f, 20.0f,
                    0, end_angle, 32, (Color){255, 100, 100, 200});
        }

        // Draw balls
        ball_manager_render(ball_manager);

        // Draw particles (after balls, before UI)
        particle_system_render(particle_system);

        // End camera mode - UI elements below are screen-fixed
        EndMode2D();

        // Draw title with semi-transparent background (fixed to screen)
        DrawRectangle(5, 5, 360, 30, (Color){0, 0, 0, 100});
        DrawText("Physics Simulator - Pachinko", 10, 10, 20, LIGHTGRAY);

        // Draw score panel (left side)
        DrawRectangle(5, screen_height - 120, 180, 115, (Color){0, 0, 0, 150});
        char score_text[64];
        sprintf(score_text, "Score: %d", world->score);
        DrawText(score_text, 10, screen_height - 115, 18, WHITE);

        sprintf(score_text, "High: %d", world->high_score);
        DrawText(score_text, 10, screen_height - 92, 16, GOLD);

        char ball_text[64];
        sprintf(ball_text, "Balls: %d", ball_manager->active_count);
        DrawText(ball_text, 10, screen_height - 68, 16, WHITE);

        // Draw performance statistics
        char perf_text[64];
        sprintf(perf_text, "FPS: %d", GetFPS());
        DrawText(perf_text, 10, screen_height - 44, 14, LIGHTGRAY);

        sprintf(perf_text, "Physics: %.2f ms", physics_ms);
        DrawText(perf_text, 10, screen_height - 26, 14, LIGHTGRAY);

        sprintf(perf_text, "Threads: %d", pool->thread_count);
        DrawText(perf_text, 10, screen_height - 8, 14, LIGHTGRAY);

        // Draw controls panel (right side)
        DrawRectangle(screen_width - 205, screen_height - 110, 200, 105,
                     (Color){0, 0, 0, 150});
        DrawText("Controls:", screen_width - 200, screen_height - 105, 16, LIGHTGRAY);
        DrawText("SPACE - Spawn ball", screen_width - 200, screen_height - 83, 14, WHITE);
        DrawText("SCROLL - Pan view", screen_width - 200, screen_height - 65, 14, WHITE);
        DrawText("R - Reset game", screen_width - 200, screen_height - 47, 14, WHITE);
        DrawText("ESC - Exit", screen_width - 200, screen_height - 29, 14, WHITE);
        DrawText("Hold SPACE for more!", screen_width - 200, screen_height - 10, 12, GRAY);

        EndDrawing();
    }

    // Cleanup
    printf("Shutting down...\n");
    CloseWindow();
    printf("Raylib window closed\n");

    particle_system_destroy(particle_system);
    printf("Particle system destroyed\n");

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
