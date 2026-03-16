// src/001-main.c
// Entry point for physics simulator
// Initializes raylib window, threadpool, and runs main game loop

#include <raylib.h>
#include <stdio.h>

// {{{ main
int main(void) {
    const int screen_width = 800;
    const int screen_height = 600;

    // Initialize raylib window
    InitWindow(screen_width, screen_height, "Physics Simulator - Pachinko");
    SetTargetFPS(60);

    // Main loop
    while (!WindowShouldClose()) {
        // Render
        BeginDrawing();
        ClearBackground(DARKGRAY);

        // Draw title text
        DrawText("Physics Simulator - Pachinko", 10, 10, 20, LIGHTGRAY);
        DrawText("Press ESC to exit", 10, screen_height - 30, 16, GRAY);

        EndDrawing();
    }

    // Cleanup
    CloseWindow();

    return 0;
}
// }}}
