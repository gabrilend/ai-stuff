// src/030-editor-main.c
// Standalone board editor entry point
// Creates boards for the physics-sim game without running the full game
//
// Usage: bin/board-editor [--advanced | -a] [filename.json]
// Flags:
//   --advanced, -a  Start in advanced mode (raw RGB editing instead of material presets)

#include <stdio.h>
#include <string.h>
#include "raylib.h"
#include "031-editor-app.h"
#include "000-config.h"

// {{{ parse_args
// Parses command line arguments for flags and filename.
// Parameters:
//   argc: Argument count
//   argv: Argument values
//   out_advanced: Set to 1 if --advanced or -a flag found
//   out_filename: Set to filename if provided (NULL otherwise)
static void parse_args(int argc, char* argv[], int* out_advanced, const char** out_filename) {
    *out_advanced = EDITOR_ADVANCED_MODE;  // Default from config
    *out_filename = NULL;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--advanced") == 0 || strcmp(argv[i], "-a") == 0) {
            *out_advanced = 1;
        } else if (argv[i][0] != '-') {
            // Assume it's a filename if not a flag
            *out_filename = argv[i];
        }
    }
}
// }}}

// {{{ main
int main(int argc, char* argv[]) {
    // Parse command line arguments
    int advanced_mode;
    const char* load_filename;
    parse_args(argc, argv, &advanced_mode, &load_filename);

    // Initialize window
    int screen_width = 1280;
    int screen_height = 800;

    SetConfigFlags(FLAG_WINDOW_RESIZABLE);
    InitWindow(screen_width, screen_height, "Board Editor - Physics Simulator");
    SetTargetFPS(60);
    SetExitKey(0);  // Disable ESC-to-quit, handle manually

    // Set minimum window size (issue 408)
    // Editor needs extra width for tool panels on the sides
    // 800px = board width (~600) + left/right panel space (~200)
    SetWindowMinSize(800, 100);
    printf("Minimum window size set: 800x100\n");

    printf("Board Editor starting...\n");
    printf("Mode: %s\n", advanced_mode ? "Advanced (raw RGB)" : "Standard (material presets)");

    // Create editor application
    EditorApp* app = editor_app_create(screen_width, screen_height);
    if (!app) {
        fprintf(stderr, "ERROR: Failed to create editor app\n");
        CloseWindow();
        return 1;
    }

    // Set advanced mode from command line (issue 839)
    editor_app_set_advanced_mode(app, advanced_mode);

    printf("Editor app created\n");

    // Load file from command line if provided
    if (load_filename) {
        printf("Loading board: %s\n", load_filename);
        if (editor_app_load(app, load_filename)) {
            printf("Board loaded successfully\n");
        } else {
            fprintf(stderr, "WARNING: Failed to load %s, starting with empty board\n", load_filename);
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
