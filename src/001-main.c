// src/001-main.c
// Entry point for physics simulator
// Initializes raylib window, threadpool, and runs main game loop
//
// External functions: main

#include <raylib.h>
#include <stdio.h>
#include "003-threadpool.h"

// {{{ main
int main(void) {
    const int screen_width = 800;
    const int screen_height = 600;

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

    // Main loop
    printf("Entering main loop...\n");
    while (!WindowShouldClose()) {
        // Physics updates would be submitted to threadpool here
        // (Phase 3 will implement ball physics)

        // Render
        BeginDrawing();
        ClearBackground(DARKGRAY);

        // Draw title text
        DrawText("Physics Simulator - Pachinko", 10, 10, 20, LIGHTGRAY);
        DrawText("Press ESC to exit", 10, screen_height - 30, 16, GRAY);
        DrawText("Phase 1 Complete: Infrastructure Ready", 10, 40, 16, GREEN);

        EndDrawing();
    }

    // Cleanup
    printf("Shutting down...\n");
    CloseWindow();
    printf("Raylib window closed\n");

    threadpool_destroy(pool);
    printf("Threadpool destroyed\n");

    printf("Clean shutdown complete\n");
    return 0;
}
// }}}
