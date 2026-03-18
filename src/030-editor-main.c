// src/030-editor-main.c
// Standalone board editor entry point
// Creates boards for the physics-sim game without running the full game
//
// Usage: bin/board-editor [filename.json]

#include <stdio.h>
#include <string.h>
#include "raylib.h"
#include "031-editor-app.h"

// {{{ main
int main(int argc, char* argv[]) {
    // Initialize window
    int screen_width = 1280;
    int screen_height = 800;

    SetConfigFlags(FLAG_WINDOW_RESIZABLE);
    InitWindow(screen_width, screen_height, "Board Editor - Physics Simulator");
    SetTargetFPS(60);
    SetExitKey(0);  // Disable ESC-to-quit, handle manually

    printf("Board Editor starting...\n");

    // Create editor application
    EditorApp* app = editor_app_create(screen_width, screen_height);
    if (!app) {
        fprintf(stderr, "ERROR: Failed to create editor app\n");
        CloseWindow();
        return 1;
    }
    printf("Editor app created\n");

    // Load file from command line if provided
    if (argc > 1) {
        printf("Loading board: %s\n", argv[1]);
        if (editor_app_load(app, argv[1])) {
            printf("Board loaded successfully\n");
        } else {
            fprintf(stderr, "WARNING: Failed to load %s, starting with empty board\n", argv[1]);
        }
    }

    // Main loop
    printf("Entering main loop...\n");
    printf("Controls: 1-4 = tools, TAB = mode, S = save, L = load, ESC = quit\n");

    while (!WindowShouldClose()) {
        // Handle window resize
        if (IsWindowResized()) {
            screen_width = GetScreenWidth();
            screen_height = GetScreenHeight();
            editor_app_resize(app, screen_width, screen_height);
        }

        // Update editor state
        editor_app_update(app);

        // Check for quit request
        if (editor_app_should_quit(app)) {
            break;
        }

        // Render
        BeginDrawing();
        ClearBackground((Color){30, 30, 40, 255});
        editor_app_render(app);
        EndDrawing();
    }

    // Cleanup
    printf("Shutting down...\n");
    editor_app_destroy(app);
    CloseWindow();
    printf("Editor closed\n");

    return 0;
}
// }}}
