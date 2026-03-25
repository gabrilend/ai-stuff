// src/001-main.c
// Entry point for physics simulator
// Initializes raylib window, threadpool, world, and runs main game loop
//
// External functions: main

#include <raylib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>
#include "003-threadpool.h"
#include "004-world.h"
#include "006-ball.h"
#include "008-particles.h"
#include "010-upgrades.h"
#include "012-adversary.h"
#include "014-stage.h"
#include "018-expansion-anim.h"
#include "026-stage-pool.h"
#include "020-board-data.h"
#include "022-grid.h"
#include "028-portal.h"
#include "036-wrap-zones.h"
#include "038-slot-manager.h"
#include "040-spawner.h"
#include "045-zone-dispatch.h"
#include "050-material.h"  // Issue 610: material-based coloring
#include "042-polygon.h"   // Issue 837: closed polygon collision
#include "044-rotor.h"     // Issue 901c: rotor physics system
#include "052-track-mover.h" // Issues 902c, 902d: track mover physics
#include "000-config.h"    // Compile-time config

// Background color presets (issue 413)
// Index matches BACKGROUND_COLOR config value: 0=slate, 1=black, etc.
static const Color BG_COLORS[] = {
    {30, 35, 45, 255},     // 0: slate (default dark gray-blue)
    {0, 0, 0, 255},        // 1: black
    {180, 160, 130, 255},  // 2: tan (light wood)
    {25, 50, 35, 255},     // 3: felt (pool table green)
    {15, 25, 50, 255},     // 4: navy (deep blue)
    {40, 25, 45, 255},     // 5: plum (dark purple)
    {35, 35, 35, 255},     // 6: charcoal (neutral gray)
    {60, 30, 25, 255},     // 7: mahogany (dark red-brown)
};
#define BG_COLOR_COUNT (sizeof(BG_COLORS) / sizeof(BG_COLORS[0]))
#define BG_COLOR (BG_COLORS[BACKGROUND_COLOR < BG_COLOR_COUNT ? BACKGROUND_COLOR : 0])
#define PEG_COLOR (Color){180, 180, 200, 255}      // Light steel peg fill
#define PEG_OUTLINE (Color){100, 100, 120, 255}    // Darker peg outline
#define BALL_COLOR (Color){255, 180, 50, 255}      // Warm orange ball
#define BALL_HIGHLIGHT (Color){255, 220, 150, 255} // Lighter ball highlight

// Scrolling viewport constants
#define SCROLL_SPEED 120.0f   // Pixels per scroll wheel notch (tripled for faster panning)
#define SCROLL_LERP_SPEED 8.0f // Lerp factor for smooth scrolling (higher = snappier)

// Minimum window dimensions (issue 408)
// Width enforced to keep board visible; height has no minimum (user can make it short)
// 600px = typical minimum board width (10 columns * 60px cell size)
#define MIN_WINDOW_WIDTH 600
#define MIN_WINDOW_HEIGHT 100  // Minimal height, user can resize as short as they want

// {{{ typedef struct StagePurchaseContext
// Context passed to stage purchase callback
// Contains all state needed to trigger stage expansion
typedef struct StagePurchaseContext {
    World* world;
    ExpansionAnimation* anim;
    Camera2D* camera;
    BallManager* ball_manager;
    StagePool* stage_pool;  // Pool of custom stages from boards/
    WrapZones* wrap_zones;  // Wrap zones to update after expansion
    float screen_height;    // Current screen height for zone update
} StagePurchaseContext;
// }}}

// {{{ apply_board_data_to_stage
// Applies BoardData objects to a Stage.
// Converts grid-based objects to stage-relative positions.
// If flip_vertical is true, mirrors over X-axis for adversary stages (issue 1304).
static void apply_board_data_to_stage(BoardData* data, Stage* stage, int flip_vertical) {
    if (!data || !stage) return;

    // Create grid for coordinate conversion
    // Issue 1003: Use cell_width and cell_height for rectangular cell support
    Grid grid = grid_create(data->grid_cols, data->grid_rows,
                            data->cell_width, data->cell_height,
                            stage->table_x, stage->y_top);

    // Count pegs and lines
    int peg_count = 0;
    int line_count = 0;
    for (int i = 0; i < data->object_count; i++) {
        if (data->objects[i].type == OBJECT_PEG) peg_count++;
        else if (data->objects[i].type == OBJECT_LINE) line_count++;
    }

    // Allocate and populate pegs
    if (peg_count > 0) {
        if (stage->pegs) free(stage->pegs);
        stage->pegs = (Peg*)malloc(sizeof(Peg) * peg_count);
        stage->peg_count = 0;

        if (stage->pegs) {
            for (int i = 0; i < data->object_count; i++) {
                BoardObject* obj = &data->objects[i];
                if (obj->type != OBJECT_PEG) continue;

                Peg* peg = &stage->pegs[stage->peg_count];
                // Flip row for adversary stages (issue 1304)
                // Fix off-by-one: row 0 should map to row (grid_rows-1), not grid_rows (issue 1001c)
                int row = flip_vertical ? (data->grid_rows - 1 - obj->row) : obj->row;
                peg->x = grid_to_pixel_x(&grid, obj->col, row);
                peg->y = grid_to_pixel_y(&grid, obj->col, row);
                peg->radius = PEG_RADIUS;
                peg->restitution = property_to_float(obj->restitution);
                peg->friction = property_to_float(obj->friction);
                peg->point_bonus = obj->point_bonus;
                peg->color = (Color){ obj->restitution, obj->friction, obj->point_bonus, 255 };
                stage->peg_count++;
            }
        }
    }

    // Allocate and populate ramps (from lines)
    if (line_count > 0) {
        if (stage->ramps) free(stage->ramps);
        stage->ramps = (Ramp*)malloc(sizeof(Ramp) * line_count);
        stage->ramp_count = 0;

        if (stage->ramps) {
            for (int i = 0; i < data->object_count; i++) {
                BoardObject* obj = &data->objects[i];
                if (obj->type != OBJECT_LINE) continue;

                // Flip rows for adversary stages (issue 1304)
                // Fix off-by-one: proper vertical flip for lines (issue 1001c)
                int row1 = flip_vertical ? (data->grid_rows - 1 - obj->row) : obj->row;
                int row2 = flip_vertical ? (data->grid_rows - 1 - obj->end_row) : obj->end_row;
                float x1 = grid_to_pixel_x(&grid, obj->col, row1);
                float y1 = grid_to_pixel_y(&grid, obj->col, row1);
                float x2 = grid_to_pixel_x(&grid, obj->end_col, row2);
                float y2 = grid_to_pixel_y(&grid, obj->end_col, row2);

                // Create ramp from line endpoints
                stage->ramps[stage->ramp_count] = ramp_create_line(
                    x1, y1, x2, y2, obj->thickness
                );
                stage->ramp_count++;
            }
        }
    }

    printf("Applied BoardData: %d pegs, %d ramps to stage\n",
           stage->peg_count, stage->ramp_count);
}
// }}}

// {{{ apply_initial_board_data
// Applies BoardData to the world's initial player pegs and ramps.
// Creates a grid based on the board's dimensions and the world's peg area.
// Returns 1 on success, 0 on failure.
static int apply_initial_board_data(BoardData* data, World* world,
                                    float peg_start_x, float peg_start_y) {
    if (!data || !world) return 0;

    // Create grid for coordinate conversion
    // Origin is at top-left of peg area
    // Issue 1003: Use cell_width and cell_height for rectangular cell support
    Grid grid = grid_create(data->grid_cols, data->grid_rows,
                            data->cell_width, data->cell_height,
                            peg_start_x, peg_start_y);

    // Count pegs and lines in board data
    int peg_count = 0;
    int line_count = 0;
    for (int i = 0; i < data->object_count; i++) {
        if (data->objects[i].type == OBJECT_PEG) peg_count++;
        else if (data->objects[i].type == OBJECT_LINE) line_count++;
    }

    // Free existing pegs
    if (world->pegs) free(world->pegs);
    world->pegs = NULL;
    world->peg_count = 0;

    // Free existing lines
    if (world->lines) free(world->lines);
    world->lines = NULL;
    world->line_count = 0;

    // Allocate and populate pegs
    if (peg_count > 0) {
        world->pegs = (Peg*)malloc(sizeof(Peg) * peg_count);
        if (!world->pegs) {
            return 0;
        }
        world->peg_count = peg_count;

        int peg_idx = 0;
        for (int i = 0; i < data->object_count; i++) {
            BoardObject* obj = &data->objects[i];
            if (obj->type != OBJECT_PEG) continue;

            Peg* peg = &world->pegs[peg_idx];
            peg->x = grid_to_pixel_x(&grid, obj->col, obj->row);
            peg->y = grid_to_pixel_y(&grid, obj->col, obj->row);
            peg->radius = PEG_RADIUS;
            peg->restitution = property_to_float(obj->restitution);
            peg->friction = property_to_float(obj->friction);
            peg->point_bonus = obj->point_bonus;
            // Issue 901f: Copy dynamic flag for crushing detection
            peg->is_dynamic = obj->is_dynamic;

            // Issue 610: Use material display color for visual consistency
            // Same approach as editor (issue 839) - both boards identical
            int mat_index = find_closest_material(obj->restitution, obj->friction, obj->point_bonus);
            peg->color = material_get_display_color(mat_index);
            peg_idx++;
        }
    }

    // Allocate and populate lines
    if (line_count > 0) {
        world->lines = (Line*)malloc(sizeof(Line) * line_count);
        if (!world->lines) {
            // Pegs were allocated, but we can continue without lines
            world->line_count = 0;
        } else {
            world->line_count = line_count;

            int line_idx = 0;
            for (int i = 0; i < data->object_count; i++) {
                BoardObject* obj = &data->objects[i];
                if (obj->type != OBJECT_LINE) continue;

                Line* line = &world->lines[line_idx];
                line->x1 = grid_to_pixel_x(&grid, obj->col, obj->row);
                line->y1 = grid_to_pixel_y(&grid, obj->col, obj->row);
                line->x2 = grid_to_pixel_x(&grid, obj->end_col, obj->end_row);
                line->y2 = grid_to_pixel_y(&grid, obj->end_col, obj->end_row);
                line->thickness = obj->thickness;
                line->restitution = property_to_float(obj->restitution);
                line->friction = property_to_float(obj->friction);
                line->point_bonus = obj->point_bonus;
                // Issue 901f: Copy dynamic flag for crushing detection
                line->is_dynamic = obj->is_dynamic;

                // Issue 610: Use material display color for visual consistency
                // Same approach as editor (issue 839) - both boards identical
                int mat_index = find_closest_material(obj->restitution, obj->friction, obj->point_bonus);
                line->color = material_get_display_color(mat_index);
                line_idx++;
            }
            printf("Created %d lines from board data\n", world->line_count);
        }
    }

    return (peg_count > 0 || line_count > 0) ? 1 : 0;
}
// }}}

// {{{ apply_adversary_board_data
// Applies BoardData to the world's adversary pegs and lines.
// Positions pegs/lines in the adversary area (below zones).
// Returns 1 on success, 0 on failure.
static int apply_adversary_board_data(BoardData* data, World* world,
                                      float peg_start_x, float peg_start_y) {
    if (!data || !world) return 0;

    // Create grid for coordinate conversion
    // Origin is at top-left of adversary peg area
    // Issue 1003: Use cell_width and cell_height for rectangular cell support
    Grid grid = grid_create(data->grid_cols, data->grid_rows,
                            data->cell_width, data->cell_height,
                            peg_start_x, peg_start_y);

    // Count pegs and lines in board data
    int peg_count = 0;
    int line_count = 0;
    for (int i = 0; i < data->object_count; i++) {
        if (data->objects[i].type == OBJECT_PEG) peg_count++;
        else if (data->objects[i].type == OBJECT_LINE) line_count++;
    }

    // Free existing adversary pegs
    if (world->adversary_pegs) free(world->adversary_pegs);
    world->adversary_pegs = NULL;
    world->adversary_peg_count = 0;

    // Free existing adversary lines
    if (world->adversary_lines) free(world->adversary_lines);
    world->adversary_lines = NULL;
    world->adversary_line_count = 0;

    // Allocate and populate pegs
    if (peg_count > 0) {
        world->adversary_pegs = (Peg*)malloc(sizeof(Peg) * peg_count);
        if (!world->adversary_pegs) {
            return 0;
        }
        world->adversary_peg_count = peg_count;

        // Issue 610: Use material-based colors (same as player board)
        // Removed red tinting - both boards now render with true material colors

        int peg_idx = 0;
        for (int i = 0; i < data->object_count; i++) {
            BoardObject* obj = &data->objects[i];
            if (obj->type != OBJECT_PEG) continue;

            Peg* peg = &world->adversary_pegs[peg_idx];
            // Flip vertically (X-axis mirror): row → (grid_rows - 1 - row)
            // This creates "opponent facing you" layout (issue 1302)
            // Fixed off-by-one: row 0 maps to row (grid_rows-1), not grid_rows (issue 1001c)
            int flipped_row = data->grid_rows - 1 - obj->row;
            peg->x = grid_to_pixel_x(&grid, obj->col, flipped_row);
            peg->y = grid_to_pixel_y(&grid, obj->col, flipped_row);
            peg->radius = PEG_RADIUS;
            peg->restitution = property_to_float(obj->restitution);
            peg->friction = property_to_float(obj->friction);
            peg->point_bonus = obj->point_bonus;
            // Issue 901f: Copy dynamic flag for crushing detection
            peg->is_dynamic = obj->is_dynamic;

            // Issue 610: Use material display color for visual consistency
            // Same approach as player board and editor (issue 839)
            int mat_index = find_closest_material(obj->restitution, obj->friction, obj->point_bonus);
            peg->color = material_get_display_color(mat_index);
            peg_idx++;
        }
    }

    // Allocate and populate lines
    if (line_count > 0) {
        world->adversary_lines = (Line*)malloc(sizeof(Line) * line_count);
        if (!world->adversary_lines) {
            world->adversary_line_count = 0;
        } else {
            world->adversary_line_count = line_count;

            // Issue 610: Use material-based colors (same as player board)
            // Removed red tinting - both boards now render with true material colors

            int line_idx = 0;
            for (int i = 0; i < data->object_count; i++) {
                BoardObject* obj = &data->objects[i];
                if (obj->type != OBJECT_LINE) continue;

                Line* line = &world->adversary_lines[line_idx];
                // Flip vertically (X-axis mirror): row → (grid_rows - 1 - row)
                // Both endpoints need flipping (issue 1302)
                // Fixed off-by-one for proper mirroring (issue 1001c)
                int flipped_row1 = data->grid_rows - 1 - obj->row;
                int flipped_row2 = data->grid_rows - 1 - obj->end_row;
                line->x1 = grid_to_pixel_x(&grid, obj->col, flipped_row1);
                line->y1 = grid_to_pixel_y(&grid, obj->col, flipped_row1);
                line->x2 = grid_to_pixel_x(&grid, obj->end_col, flipped_row2);
                line->y2 = grid_to_pixel_y(&grid, obj->end_col, flipped_row2);
                line->thickness = obj->thickness;
                line->restitution = property_to_float(obj->restitution);
                line->friction = property_to_float(obj->friction);
                line->point_bonus = obj->point_bonus;
                // Issue 901f: Copy dynamic flag for crushing detection
                line->is_dynamic = obj->is_dynamic;

                // Issue 610: Use material display color for visual consistency
                // Same approach as player board and editor (issue 839)
                int mat_index = find_closest_material(obj->restitution, obj->friction, obj->point_bonus);
                line->color = material_get_display_color(mat_index);
                line_idx++;
            }
            printf("Created %d adversary lines from board data\n", world->adversary_line_count);
        }
    }

    return (peg_count > 0 || line_count > 0) ? 1 : 0;
}
// }}}

// {{{ on_stage_purchased
// Callback invoked when player purchases a stage upgrade
// Creates stage manager if needed, adds stages, expands world, starts animation
static void on_stage_purchased(void* user_data) {
    StagePurchaseContext* ctx = (StagePurchaseContext*)user_data;
    if (!ctx || !ctx->world || !ctx->anim) return;

    World* world = ctx->world;

    // Create stage manager if this is the first stage purchase
    if (!world->stages) {
        world->stages = stage_manager_create(world->table_x, world->table_width);
        if (!world->stages) {
            fprintf(stderr, "ERROR: Failed to create stage manager\n");
            return;
        }
        printf("Stage manager created\n");
    }

    // Try to select a custom stage from the pool
    const char* stage_path = NULL;
    BoardData* stage_data = NULL;
    int use_custom_stage = 0;

    if (ctx->stage_pool) {
        stage_path = stage_pool_select_random(ctx->stage_pool);
        if (stage_path) {
            stage_data = board_data_load_json(stage_path);
            if (stage_data) {
                use_custom_stage = 1;
                printf("Using custom stage: %s\n", stage_path);
            } else {
                fprintf(stderr, "WARNING: Failed to load stage %s, using fallback\n", stage_path);
            }
        }
    }

    // Calculate expansion dimensions
    float player_stage_height = use_custom_stage ?
        (float)stage_data->board_height : STAGE_2_HEIGHT;
    float adversary_stage_height = player_stage_height;  // Mirror same height
    float gate_height = 50.0f;  // Height for gate rows

    float total_expansion = player_stage_height + adversary_stage_height +
                           gate_height * 2;  // Two gate rows

    // Add player stage
    StageType stage_type = use_custom_stage ? STAGE_TYPE_CUSTOM : STAGE_TYPE_RAMPS;
    int player_idx = stage_manager_add_player_stage(world->stages, stage_type,
                                                    player_stage_height);
    if (player_idx >= 0) {
        Stage* player_stage = &world->stages->player_stages[player_idx];
        if (use_custom_stage) {
            apply_board_data_to_stage(stage_data, player_stage, 0);  // No flip
        } else {
            stage_generate_ramps_stage2(player_stage);
        }
        printf("Added player stage with %d pegs, %d ramps\n",
               player_stage->peg_count, player_stage->ramp_count);
    }

    // Add adversary stage (mirrored)
    int adv_idx = stage_manager_add_adversary_stage(world->stages, stage_type,
                                                    adversary_stage_height);
    if (adv_idx >= 0) {
        Stage* adv_stage = &world->stages->adversary_stages[adv_idx];
        if (use_custom_stage) {
            // Flip vertically for adversary (issue 1304)
            apply_board_data_to_stage(stage_data, adv_stage, 1);
        } else {
            stage_generate_ramps_stage2_mirrored(adv_stage);
        }
        printf("Added adversary stage with %d pegs, %d ramps\n",
               adv_stage->peg_count, adv_stage->ramp_count);
    }

    // Clean up stage data
    if (stage_data) {
        board_data_destroy(stage_data);
    }

    // Add gate rows between stages with 2x multiplier
    stage_manager_add_gate_row(world->stages, world->table_bottom,
                               gate_height, 7, 2);
    stage_manager_add_gate_row(world->stages, world->adversary_table_top - gate_height,
                               gate_height, 7, 2);

    // Expand the world to accommodate new stages
    world_expand_for_stages(world, player_stage_height, adversary_stage_height,
                           gate_height);

    // Handle ball positions during expansion
    float expansion_y = world->table_bottom;  // Expansion point
    ball_manager_handle_expansion(ctx->ball_manager, total_expansion, expansion_y);

    // Start the expansion animation
    float current_zoom = ctx->camera->zoom;
    float current_target_y = ctx->camera->target.y;
    expansion_animation_start(ctx->anim, total_expansion, expansion_y, 1,
                             current_zoom, current_target_y);

    // Update wrap zones to account for new world bounds
    if (ctx->wrap_zones) {
        wrap_zones_update(ctx->wrap_zones, ctx->screen_height);
    }

    printf("Stage expansion triggered: %.0f pixels total\n", total_expansion);
}
// }}}

// {{{ main
int main(int argc, char* argv[]) {
    (void)argc;
    (void)argv;

    int screen_width = 800;  // Initial horizontal size (updated on resize)
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
    SetExitKey(0);  // Disable default ESC-to-quit, we handle it manually

    // Set minimum window size to prevent board from going off-screen (issue 408)
    // Note: Tiled WMs (i3, sway) may override this, which is expected behavior
    // for power users who know what they're doing
    SetWindowMinSize(MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT);
    printf("Minimum window size set: %dx%d\n", MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT);

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

    // Zone height for gates (used by world_generate_zones)
    float zone_height = SLOT_GATE_HEIGHT;

    // Create stage pool early for random first board selection (issue 1209)
    // This also provides the pool for stage purchase callbacks later
    StagePool* stage_pool = stage_pool_create(STAGE_POOL_DIRECTORY);
    if (stage_pool) {
        printf("Stage pool initialized with %d stages\n", stage_pool_get_count(stage_pool));
    }

    // Load a random board from the pool (issue 1216 - JSON boards are required)
    // All boards come from JSON files in boards/ directory
    BoardData* initial_board = NULL;

    if (!stage_pool || stage_pool_get_count(stage_pool) == 0) {
        fprintf(stderr, "ERROR: No boards found in boards/ directory\n");
        world_destroy(world);
        threadpool_destroy(pool);
        CloseWindow();
        return 1;
    }

    const char* board_path = stage_pool_select_random(stage_pool);
    if (!board_path) {
        fprintf(stderr, "ERROR: Failed to select random board\n");
        world_destroy(world);
        threadpool_destroy(pool);
        CloseWindow();
        return 1;
    }

    initial_board = board_data_load_json(board_path);
    if (!initial_board) {
        fprintf(stderr, "ERROR: Failed to load board: %s\n", board_path);
        world_destroy(world);
        threadpool_destroy(pool);
        CloseWindow();
        return 1;
    }
    printf("Selected random initial board: %s\n", board_path);

    // Calculate table dimensions from board (issue 1220, 1003)
    // Board fills entire table - pegs at edges align with guard rails
    // Issue 1003: Use pre-computed board_width which accounts for cell_width
    float table_width = (float)initial_board->board_width;

    // Create slot manager - single source of truth for vertical positioning (issue 1221)
    // Centers table horizontally in window
    float table_x = ((float)screen_width - table_width) / 2.0f;
    SlotManager* slot_manager = slot_manager_create(table_x, table_width);
    if (!slot_manager) {
        fprintf(stderr, "ERROR: Failed to create slot manager\n");
        board_data_destroy(initial_board);
        world_destroy(world);
        threadpool_destroy(pool);
        CloseWindow();
        return 1;
    }
    slot_manager_print_debug(slot_manager);

    // Get positions from slot manager
    float peg_start_y = slot_manager->player_board_top;

    // Set world table bounds from slot manager
    world->table_x = slot_manager->table_x;
    world->table_width = slot_manager->table_width;
    world->table_top = slot_manager->player_board_top;
    world->table_bottom = slot_manager->player_board_bottom;
    world->adversary_table_top = slot_manager->adversary_board_top;
    world->adversary_table_bottom = slot_manager->adversary_board_bottom;
    printf("Table bounds from slot manager: x=%.0f, width=%.0f, top=%.0f, bottom=%.0f\n",
           world->table_x, world->table_width, world->table_top, world->table_bottom);
    printf("Adversary bounds: top=%.0f, bottom=%.0f\n",
           world->adversary_table_top, world->adversary_table_bottom);

    // Apply the board data to the world
    // Board starts at table_x and peg_start_y from slot manager
    if (!apply_initial_board_data(initial_board, world, world->table_x, peg_start_y)) {
        fprintf(stderr, "ERROR: Failed to apply board data\n");
        slot_manager_destroy(slot_manager);
        board_data_destroy(initial_board);
        world_destroy(world);
        threadpool_destroy(pool);
        CloseWindow();
        return 1;
    }
    printf("Applied board: %d pegs\n", world->peg_count);

    // Create rotor manager for physics (issue 901c)
    // Must be created after apply_initial_board_data sets up lines/pegs
    world->rotor_manager = rotor_manager_create(world);
    if (world->rotor_manager && initial_board->rotor_count > 0) {
        // Issue 1003: Pass cell_width and cell_height for rectangular cells
        int rotors_added = rotor_manager_add_from_board(
            world->rotor_manager, initial_board,
            world->table_x, peg_start_y,
            initial_board->cell_width, initial_board->cell_height);
        printf("Rotor manager: %d rotors loaded\n", rotors_added);
    }

    // Create track mover manager for physics (issues 902c, 902d)
    // Must be created after apply_initial_board_data sets up lines/pegs
    world->track_mover_manager = track_mover_manager_create(world);
    if (world->track_mover_manager && initial_board->track_mover_count > 0) {
        // Issue 1003: Pass cell_width and cell_height for rectangular cell support
        int movers_added = track_mover_manager_add_from_board(
            world->track_mover_manager, initial_board,
            world->table_x, peg_start_y,
            initial_board->cell_width, initial_board->cell_height);
        printf("Track mover manager: %d movers loaded\n", movers_added);
    }

    // Generate score zones (7 zones spanning table width)
    world_generate_zones(world, 7, zone_height);
    printf("Generated score zones: 7 zones\n");

    // Generate gate bumpers (low-restitution caps on zone dividers)
    world_generate_bumpers(world);
    printf("Generated gate bumpers: %d bumpers\n", world->bumper_count);

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
    ParticleSystem* particle_system = particle_system_create(MAX_PARTICLES);
    if (!particle_system) {
        fprintf(stderr, "ERROR: Failed to create particle system\n");
        ball_manager_destroy(ball_manager);
        world_destroy(world);
        threadpool_destroy(pool);
        CloseWindow();
        return 1;
    }
    printf("Particle system created: 256 capacity\n");

    // Create upgrade manager
    UpgradeManager* upgrade_manager = upgrade_manager_create();
    if (!upgrade_manager) {
        fprintf(stderr, "ERROR: Failed to create upgrade manager\n");
        particle_system_destroy(particle_system);
        ball_manager_destroy(ball_manager);
        world_destroy(world);
        threadpool_destroy(pool);
        CloseWindow();
        return 1;
    }
    printf("Upgrade manager created\n");

    // Apply the same board to adversary (mirrored position below zones)
    // Adversary board position comes from slot manager (issue 1221)
    {
        float adv_start_y = slot_manager->adversary_board_top;

        // Board starts at table_x and adv_start_y from slot manager
        if (!apply_adversary_board_data(initial_board, world, world->table_x, adv_start_y)) {
            fprintf(stderr, "ERROR: Failed to apply adversary board data\n");
            slot_manager_destroy(slot_manager);
            board_data_destroy(initial_board);
            world_destroy(world);
            threadpool_destroy(pool);
            CloseWindow();
            return 1;
        }
        printf("Applied adversary board at y=%.0f: %d pegs\n", adv_start_y, world->adversary_peg_count);

        // Create adversary polygon manager (issue 837)
        // Must be done before board_data_destroy while we still have BoardData
        // Issue 1003: Use pre-computed board dimensions
        world->adversary_polygon_manager = polygon_manager_create(
            (float)initial_board->board_width,
            (float)initial_board->board_height
        );
        if (world->adversary_polygon_manager) {
            // Issue 1003: Pass cell_width and cell_height for rectangular cells
            polygon_manager_rebuild_offset(
                world->adversary_polygon_manager, initial_board,
                initial_board->cell_width, initial_board->cell_height,
                world->table_x, adv_start_y
            );
            printf("Adversary polygon manager: %d polygons\n",
                   world->adversary_polygon_manager->polygon_count);
        }
    }

    // Create player polygon manager (issue 837)
    // Must be done before board_data_destroy while we still have BoardData
    // Issue 1003: Use pre-computed board dimensions
    world->polygon_manager = polygon_manager_create(
        (float)initial_board->board_width,
        (float)initial_board->board_height
    );
    if (world->polygon_manager) {
        // Issue 1003: Pass cell_width and cell_height for rectangular cells
        polygon_manager_rebuild_offset(
            world->polygon_manager, initial_board,
            initial_board->cell_width, initial_board->cell_height,
            world->table_x, peg_start_y
        );
        printf("Player polygon manager: %d polygons\n",
               world->polygon_manager->polygon_count);
    }

    // Clean up board data
    board_data_destroy(initial_board);
    initial_board = NULL;

    world_generate_adversary_bumpers(world);
    printf("Generated adversary bumpers: %d\n", world->adversary_bumper_count);

    // Create adversary AI
    // Spawn position comes from slot manager via world->adversary_table_bottom
    Adversary* adversary = adversary_create(world);
    if (!adversary) {
        fprintf(stderr, "ERROR: Failed to create adversary\n");
        slot_manager_destroy(slot_manager);
        upgrade_manager_destroy(upgrade_manager);
        particle_system_destroy(particle_system);
        ball_manager_destroy(ball_manager);
        world_destroy(world);
        threadpool_destroy(pool);
        CloseWindow();
        return 1;
    }
    printf("Adversary AI created: spawn_y=%.0f\n", adversary->spawner.y);

    // Initialize expansion animation system
    // Used when purchasing new stages to animate world expansion
    ExpansionAnimation expansion_anim;
    expansion_animation_init(&expansion_anim);
    printf("Expansion animation initialized\n");

    // Create wrap zones for ball teleportation at screen edges
    WrapZones* wrap_zones = wrap_zones_create(world, (float)screen_height);
    if (!wrap_zones) {
        fprintf(stderr, "ERROR: Failed to create wrap zones\n");
        adversary_destroy(adversary);
        upgrade_manager_destroy(upgrade_manager);
        particle_system_destroy(particle_system);
        ball_manager_destroy(ball_manager);
        world_destroy(world);
        threadpool_destroy(pool);
        CloseWindow();
        return 1;
    }
    // Attach wrap zones to world so ball physics can access them
    world->wrap_zones = wrap_zones;
    printf("Wrap zones created\n");

    // Create zone dispatch grid (issue 318)
    // Maps grid cells to zone types for unified zone handling
    // Issue 1003: Uses separate cell_width and cell_height for rectangular cells
    ZoneGrid* zone_grid = zone_grid_create(
        world->table_x,           // Origin X (left edge of table)
        world->table_top,         // Origin Y (top of player area)
        DEFAULT_GRID_CELL_WIDTH,  // Cell width (BOARD_WIDTH / cols)
        DEFAULT_GRID_CELL_HEIGHT, // Cell height (BOARD_HEIGHT / rows)
        DEFAULT_GRID_COLS,
        ZONE_GRID_MAX_ROWS,       // Max rows to accommodate expansion
        world
    );
    if (zone_grid) {
        // Set up initial gate row at the zone position
        // Convert zone Y position to grid row (use cell_height for Y calculations)
        int gate_row = (int)((world->table_bottom - world->table_top) / DEFAULT_GRID_CELL_HEIGHT);
        zone_grid_set_gate_row(zone_grid, gate_row, 0);  // No multiplier initially

        world->zone_grid = zone_grid;
        printf("Zone dispatch grid created: %d cols, %d max rows, gate row %d\n",
               DEFAULT_GRID_COLS, ZONE_GRID_MAX_ROWS, gate_row);
    } else {
        printf("WARNING: Zone grid creation failed, using fallback zone system\n");
        world->zone_grid = NULL;
    }

    // Initialize scrolling viewport
    // World height can be larger than screen for scrollable areas
    float world_height = (float)world_height_pixels;  // Larger than screen enables scrolling
    float viewport_offset_y = 0.0f;             // Current scroll position
    float viewport_target_y = 0.0f;             // Target scroll position (lerped toward)

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

    // Stage pool was created earlier for random first board selection (issue 1209)
    // It is reused here for the stage purchase callback system

    // Set up stage purchase callback context
    // This connects the upgrade system to the stage expansion system
    // Must be done after camera is created since we pass a pointer to it
    StagePurchaseContext stage_ctx = {
        .world = world,
        .anim = &expansion_anim,
        .camera = &camera,
        .ball_manager = ball_manager,
        .stage_pool = stage_pool,
        .wrap_zones = wrap_zones,
        .screen_height = (float)screen_height
    };
    upgrade_manager_set_stage_callback(upgrade_manager, on_stage_purchased, &stage_ctx);
    printf("Stage purchase callback configured\n");

    // Auto-spawn toggle state
    int auto_spawn = 0;

    // UI visibility toggle (issue 407)
    // Press H to hide/show score panel and controls panel
    int ui_visible = 1;

    // Velocity debug overlay toggle (issue 903)
    // Press F10 to show/hide velocity statistics overlay
    int show_velocity_debug = 0;
    int frame_counter = 0;  // Frame counter for velocity stats

    // Player spawner - unified spawn system (issue 1309)
    // Position controlled via mouse/keyboard, spawner handles credits and rendering
    float player_spawn_y = slot_manager_get_player_spawn_y(slot_manager);
    Spawner player_spawner = spawner_create(
        world->table_x + world->table_width / 2.0f,  // Start at table center
        player_spawn_y,
        SPAWN_RATE,  // Base rate from ball.h
        OWNER_PLAYER,
        1.0f  // Gravity down
    );
    // Set player reticle colors (cyan scheme)
    spawner_set_colors(&player_spawner, 60, 80, 100, 150, 100, 200, 255, 220);
    // Set spawn bounds for clamping
    float spawn_margin = BALL_RADIUS + 5.0f;
    spawner_set_bounds(&player_spawner,
        world->table_x + spawn_margin,
        world->table_x + world->table_width - spawn_margin,
        200.0f  // Nudge speed for keyboard
    );

    // Toggle-based mouse control: click to enable/disable mouse tracking
    // Default state: frozen (player must click to enable mouse control)
    int mouse_controls_reticle = 0;  // 0 = frozen, 1 = follows mouse

    // Main loop
    printf("Entering main loop...\n");
    printf("Press SPACE to spawn balls, A to toggle auto-spawn, SCROLL to pan view\n");
    printf("Click to toggle mouse aim, LEFT/RIGHT arrows to nudge spawn point\n");
    printf("Press Q to quit, ESC closes menus first\n");
    int should_quit = 0;
    while (!should_quit) {
        // Get delta time for physics
        float dt = GetFrameTime();

        // Update player spawner credits (base rate via spawner_update)
        // Pass NULL controller - position handled manually below for input flexibility
        spawner_update(&player_spawner, NULL, NULL, dt);

        // Add bonus spawn credits from upgrades (issue 1309)
        float spawn_rate_bonus = upgrade_get_spawn_rate_bonus(upgrade_manager);
        if (spawn_rate_bonus > 0.0f) {
            player_spawner.credits = spawner_accumulate(
                player_spawner.credits, spawn_rate_bonus, dt, MAX_SPAWN_CREDITS);
        }

        // Particle system now updated in parallel after ball physics
        // (see particle_system_prepare_tasks/submit_tasks/finalize/swap below)

        // Handle spawn point movement - toggle-based mouse control
        // Toggle mouse control on left click (when menu is closed)
        if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON) && !upgrade_manager->menu_open) {
            mouse_controls_reticle = !mouse_controls_reticle;
        }

        // Mouse tracking (only when enabled via toggle)
        if (mouse_controls_reticle) {
            Vector2 mouse_screen = { (float)GetMouseX(), (float)GetMouseY() };
            Vector2 mouse_world = GetScreenToWorld2D(mouse_screen, camera);
            player_spawner.x = mouse_world.x;
        }

        // Arrow keys always work (independent of mouse toggle)
        if (IsKeyDown(KEY_LEFT)) {
            player_spawner.x -= player_spawner.move_speed * dt;
        }
        if (IsKeyDown(KEY_RIGHT)) {
            player_spawner.x += player_spawner.move_speed * dt;
        }

        // Clamp spawn position to table bounds
        if (player_spawner.x < player_spawner.min_x) player_spawner.x = player_spawner.min_x;
        if (player_spawner.x > player_spawner.max_x) player_spawner.x = player_spawner.max_x;

        // Handle auto-spawn toggle (A key) - only when menu is closed
        if (IsKeyPressed(KEY_A) && !upgrade_manager->menu_open) {
            auto_spawn = !auto_spawn;
            printf("Auto-spawn: %s\n", auto_spawn ? "ON" : "OFF");
        }

        // Handle adversary spawn toggle (P key) - issue 507
        // When paused, adversary credits accumulate but no balls spawn
        if (IsKeyPressed(KEY_P) && !upgrade_manager->menu_open) {
            adversary_toggle_spawning(adversary);
        }

        // Handle UI visibility toggle (H key) - issue 407
        // Hides score panel and controls panel for clean screenshots/recording
        if (IsKeyPressed(KEY_H) && !upgrade_manager->menu_open) {
            ui_visible = !ui_visible;
            printf("UI: %s\n", ui_visible ? "visible" : "hidden");
        }

        // Handle velocity debug toggle (F10 key) - issue 903
        // Shows velocity statistics overlay for debugging tunneling
        if (IsKeyPressed(KEY_F10)) {
            show_velocity_debug = !show_velocity_debug;
            printf("Velocity debug: %s\n", show_velocity_debug ? "ON" : "OFF");
            if (show_velocity_debug) {
                velocity_stats_reset();  // Reset stats when enabling
            }
        }

        // Handle upgrade menu input (returns 1 if ESC was consumed)
        int esc_consumed = upgrade_manager_handle_input(upgrade_manager, &world->score);

        // Handle quit: Q always quits, ESC quits only if not consumed by menu
        if (IsKeyPressed(KEY_Q)) {
            should_quit = 1;
        }
        if (IsKeyPressed(KEY_ESCAPE) && !esc_consumed) {
            should_quit = 1;
        }
        // Also quit if window close button clicked
        if (WindowShouldClose()) {
            should_quit = 1;
        }

        // Update adversary AI (moves reticle, spawns enemy balls)
        adversary_update(adversary, world, ball_manager, dt);

        // NOTE: Ball spawning moved to after physics/buffer swap
        // This ensures balls appear at spawn position on first frame

        // Handle window resize - update screen size and camera (issue 1216)
        // JSON boards are preserved; only dynamic elements (zones, bumpers) are updated
        if (IsWindowResized()) {
            screen_height = GetScreenHeight();
            screen_width = GetScreenWidth();

            // Update world dimensions
            world->width = screen_width;
            world->height = screen_height;

            // Recalculate table centering via slot manager (issue 1221)
            // Only table_x changes on resize, vertical positions stay the same
            float old_table_x = slot_manager->table_x;
            float new_table_x = ((float)screen_width - table_width) / 2.0f;
            slot_manager_update_table_x(slot_manager, new_table_x);
            world->table_x = new_table_x;

            // Shift pegs, lines, and spawn point by table_x delta (issue 1220)
            // Keeps them anchored to guard rails, not window
            float dx = new_table_x - old_table_x;
            if (dx != 0.0f) {
                for (int i = 0; i < world->peg_count; i++) {
                    world->pegs[i].x += dx;
                }
                for (int i = 0; i < world->line_count; i++) {
                    world->lines[i].x1 += dx;
                    world->lines[i].x2 += dx;
                }
                for (int i = 0; i < world->adversary_peg_count; i++) {
                    world->adversary_pegs[i].x += dx;
                }
                for (int i = 0; i < world->adversary_line_count; i++) {
                    world->adversary_lines[i].x1 += dx;
                    world->adversary_lines[i].x2 += dx;
                }
                // Shift player spawner position to stay anchored to table
                player_spawner.x += dx;
                player_spawner.min_x += dx;
                player_spawner.max_x += dx;

                // Shift all active balls to maintain relative position (issue 1001h)
                // Without this, balls stay at old X while pegs move, breaking physics
                for (int i = 0; i < ball_manager->capacity; i++) {
                    if (ball_manager->balls_current[i].active) {
                        ball_manager->balls_current[i].x += dx;
                        ball_manager->balls_next[i].x += dx;
                    }
                }

                // Shift active particles for visual continuity (issue 1001h)
                for (int i = 0; i < particle_system->capacity; i++) {
                    if (particle_system->particles_current[i].life > 0) {
                        particle_system->particles_current[i].x += dx;
                        particle_system->particles_next[i].x += dx;
                    }
                }

                // Shift polygon fill vertices (issue 1001f)
                // Without this, polygon fills stay at old positions after resize
                if (world->polygon_manager) {
                    for (int p = 0; p < world->polygon_manager->polygon_count; p++) {
                        Polygon* poly = &world->polygon_manager->polygons[p];
                        for (int v = 0; v < poly->vertex_count; v++) {
                            poly->vertices[v].x += dx;
                        }
                        poly->centroid.x += dx;
                    }
                }
                if (world->adversary_polygon_manager) {
                    for (int p = 0; p < world->adversary_polygon_manager->polygon_count; p++) {
                        Polygon* poly = &world->adversary_polygon_manager->polygons[p];
                        for (int v = 0; v < poly->vertex_count; v++) {
                            poly->vertices[v].x += dx;
                        }
                        poly->centroid.x += dx;
                    }
                }
            }

            // Regenerate dynamic elements (gates are not part of JSON boards)
            world_generate_zones(world, 7, zone_height);
            world_generate_bumpers(world);
            world_generate_adversary_bumpers(world);

            // Reset adversary position after resize
            adversary_reset(adversary, world);

            // Update camera offset to match new screen center
            camera.offset = (Vector2){ (float)screen_width / 2.0f,
                                       (float)screen_height / 2.0f };

            // Clamp viewport offset and target to new valid range
            // TEMP: Disabled for debugging (issue 1220 followup)
            // float min_offset = world->table_top - (float)screen_height;
            // float max_offset = world->adversary_table_bottom;
            // if (viewport_target_y < min_offset) viewport_target_y = min_offset;
            // if (viewport_target_y > max_offset) viewport_target_y = max_offset;
            // if (viewport_offset_y < min_offset) viewport_offset_y = min_offset;
            // if (viewport_offset_y > max_offset) viewport_offset_y = max_offset;

            // Update camera target
            camera.target = (Vector2){ (float)screen_width / 2.0f,
                                       (float)screen_height / 2.0f + viewport_offset_y };

            // Update wrap zones for new screen size
            wrap_zones_update(wrap_zones, (float)screen_height);
            stage_ctx.screen_height = (float)screen_height;

            // Update zone grid origin to match new table position (issue 1001f)
            // Without this, zone dispatch uses stale coordinates after resize
            if (zone_grid) {
                zone_grid->origin_x = world->table_x;
            }

            printf("Window resized: %dx%d, table_x=%.0f\n",
                   screen_width, screen_height, world->table_x);
        }

        // Handle reset input (R key)
        if (IsKeyPressed(KEY_R)) {
            // Reset scores (issue 609)
            world->score = 0;
            world->adversary_score = 0;

            // Deactivate all balls
            for (int i = 0; i < ball_manager->capacity; i++) {
                ball_manager->balls_current[i].active = 0;
                ball_manager->balls_next[i].active = 0;
            }
            ball_manager->active_count = 0;

            // Reset adversary spawn position
            adversary_reset(adversary, world);
        }

        // Handle scroll wheel for viewport panning
        // Scroll wheel updates target, actual position lerps toward it
        float scroll = GetMouseWheelMove();
        if (scroll != 0.0f) {
            viewport_target_y -= scroll * SCROLL_SPEED;

            // Clamp target to valid range
            // TEMP: Disabled for debugging (issue 1220 followup)
            // float min_offset = world->table_top - (float)screen_height;
            // float max_offset = world->adversary_table_bottom;
            // if (viewport_target_y < min_offset) viewport_target_y = min_offset;
            // if (viewport_target_y > max_offset) viewport_target_y = max_offset;
        }

        // Smooth scroll lerping - runs every frame for gentle movement
        // Lerp formula: current += (target - current) * speed * dt
        float scroll_diff = viewport_target_y - viewport_offset_y;
        if (fabsf(scroll_diff) > 0.1f) {
            viewport_offset_y += scroll_diff * SCROLL_LERP_SPEED * dt;
        } else {
            // Snap to target when close enough to avoid endless tiny movements
            viewport_offset_y = viewport_target_y;
        }

        // Update camera target to reflect scroll position
        camera.target.y = (float)screen_height / 2.0f + viewport_offset_y;

        // Update expansion animation if active
        // Animation controls camera zoom and may pause physics
        int expansion_completed = expansion_animation_update(&expansion_anim, dt);
        if (expansion_animation_is_active(&expansion_anim)) {
            // Apply animated camera zoom and offset
            expansion_animation_apply_camera(&expansion_anim, &camera);
        }
        if (expansion_completed) {
            // Animation just finished - world expansion already applied at start
            // Physics resumes automatically (physics_paused flag cleared)
        }

        // Skip physics update when expansion animation is active
        // Balls freeze in place during animation for visual clarity
        double physics_ms = 0.0;  // Initialize before potential skip
        if (expansion_anim.physics_paused) {
            // Still need to render, but skip physics
            goto skip_physics;
        }

        // Update rotor and mover physics before ball collision (issues 901h, 902h)
        // Both systems update in parallel since they write to disjoint object sets
        // Prepare tasks for all rotor/mover managers
        if (world->rotor_manager) {
            rotor_manager_prepare_tasks(world->rotor_manager, dt);
        }
        if (world->adversary_rotor_manager) {
            rotor_manager_prepare_tasks(world->adversary_rotor_manager, dt);
        }
        if (world->track_mover_manager) {
            track_mover_manager_prepare_tasks(world->track_mover_manager, dt);
        }
        if (world->adversary_track_mover_manager) {
            track_mover_manager_prepare_tasks(world->adversary_track_mover_manager, dt);
        }

        // Submit all rotor/mover tasks to threadpool
        if (world->rotor_manager) {
            rotor_manager_submit_tasks(world->rotor_manager, pool);
        }
        if (world->adversary_rotor_manager) {
            rotor_manager_submit_tasks(world->adversary_rotor_manager, pool);
        }
        if (world->track_mover_manager) {
            track_mover_manager_submit_tasks(world->track_mover_manager, pool);
        }
        if (world->adversary_track_mover_manager) {
            track_mover_manager_submit_tasks(world->adversary_track_mover_manager, pool);
        }

        // Wait for all rotor/mover updates to complete before ball physics
        threadpool_wait_all(pool);

        // Parallel ball physics update with performance timing
        // Sequence: prepare → submit → wait → spawn particles → collect scores → finalize → swap
        double physics_start = GetTime();
        ball_manager_prepare_tasks(ball_manager, world, dt);
        ball_manager_submit_tasks(ball_manager, pool);
        threadpool_wait_all(pool);

        // Spawn particle bursts for balls that scored this frame
        // Must happen BEFORE collect_scores because it resets scored/score_delta
        // Only process task data for balls that were active this frame
        // (prevents stale task_data from spawning particles for dead balls)
        for (int i = 0; i < ball_manager->capacity; i++) {
            // Skip balls that weren't active at start of frame
            if (!ball_manager->balls_current[i].active) continue;

            BallTaskData* task = &ball_manager->task_data[i];

            // Issue 319: Get ball color for particle effects
            // Use owner to select player or adversary color
            Ball* ball = &ball_manager->balls_current[i];
            unsigned char* ball_rgba = (ball->owner == OWNER_PLAYER)
                ? ball_manager->player_color
                : ball_manager->adversary_color;
            Color ball_color = (Color){ball_rgba[0], ball_rgba[1], ball_rgba[2], ball_rgba[3]};

            if (task->scored) {
                // Ripple color based on gate/zone point value (not ball color)
                // Matches the visual color of the scoring zone
                Color ripple_color;
                if (task->score_delta >= 500) {
                    ripple_color = GOLD;
                } else if (task->score_delta >= 100) {
                    ripple_color = GREEN;
                } else if (task->score_delta >= 50) {
                    ripple_color = BLUE;
                } else {
                    ripple_color = GRAY;
                }

                // Spawn ripple effect at gate position (halo pulse)
                particle_spawn_ripple(particle_system, task->score_pos_x,
                                     task->score_pos_y, ripple_color);
            }

            // Spawn explosion fragments for balls destroyed by cross-board damage
            if (task->died_from_damage) {
                // Fragment direction based on collision dominance:
                // - Dominant ball (higher closing speed) = projectile hitting wall
                //   → explodes away from impact point (FRAG_AWAY)
                // - Non-dominant ball (lower closing speed) = wall being hit
                //   → shatters along impact tangent (FRAG_TANGENT)
                FragmentMode frag_mode = task->death_was_dominant ? FRAG_AWAY : FRAG_TANGENT;
                // Issue 319: Use ball color for explosion fragments
                particle_spawn_fragments(particle_system, task->death_pos_x,
                                        task->death_pos_y, task->death_vx,
                                        task->death_vy, ball_color, frag_mode,
                                        task->death_nx, task->death_ny);
            }

            // Spawn splash for cross-owner ball collisions (skip if ball exploded)
            if (task->had_collision && !task->died_from_damage) {
                // Issue 319: Use ball color for splash particles
                particle_spawn_splash(particle_system, task->collision_x,
                                     task->collision_y, task->collision_tx,
                                     task->collision_ty, ball_color);
            }
        }

        // Parallel particle physics update
        // Particles spawned above are now in particles_current, will be updated
        particle_system_prepare_tasks(particle_system, world, dt);
        particle_system_submit_tasks(particle_system, pool);
        threadpool_wait_all(pool);
        particle_system_finalize_update(particle_system);
        particle_system_swap_buffers(particle_system);

        // Collect scores separated by owner (issue 609)
        int player_points, adversary_points;
        ball_manager_collect_scores_split(ball_manager, &player_points, &adversary_points);
        world->score += player_points;
        world->adversary_score += adversary_points;

        // Update high score if current player score exceeds it
        if (world->score > world->high_score) {
            world->high_score = world->score;
        }

        // Issue 222: Check for overlapping slow balls and nudge them apart
        // Uses spatial hash for efficient neighbor lookup after physics update
        ball_manager_check_slow_overlaps(ball_manager);

        ball_manager_finalize_update(ball_manager);

        // Record velocity statistics for debugging (issue 903)
        // Functions implemented in src/007-ball.c
        if (show_velocity_debug) {
            frame_counter++;
            ball_manager_record_velocity_stats(ball_manager, frame_counter, dt, SLOT_GATE_HEIGHT);
        }

        ball_manager_swap_buffers(ball_manager);
        // Wrap zone checking now happens in ball physics (see ball_physics_task)

        double physics_end = GetTime();
        physics_ms = (physics_end - physics_start) * 1000.0;

        // Handle ball spawning input (after buffer swap so balls render at spawn position)
        // spawner_try_spawn checks credits, blocking, and capacity internally
        // Auto-spawn acts like SPACE is held down
        // Spawning paused while upgrade menu is open (issue 1309)
        if (!upgrade_manager->menu_open && (IsKeyDown(KEY_SPACE) || auto_spawn)) {
            // Calculate ball radius with upgrade modifier
            float ball_radius = BALL_RADIUS + upgrade_get_ball_radius_modifier(upgrade_manager);
            spawner_try_spawn(&player_spawner, ball_manager, ball_radius);
        }

    skip_physics:  // Label for expansion animation physics skip
        // Render
        BeginDrawing();
        ClearBackground(BG_COLOR);

        // Begin camera mode for world elements (scrollable)
        // All world elements are rendered in camera space
        BeginMode2D(camera);

        // Draw world elements (in camera space - scrollable)
        world_render_rails(world);

        // Draw polygon fills behind other board objects (issue 837)
        if (world->polygon_manager) {
            polygon_manager_render_all(world->polygon_manager);
        }
        if (world->adversary_polygon_manager) {
            polygon_manager_render_all(world->adversary_polygon_manager);
        }

        world_render_pegs(world);
        world_render_lines(world);
        world_render_zones(world);
        world_render_bumpers(world);

        // Draw adversary board elements
        world_render_adversary_pegs(world);
        world_render_adversary_lines(world);
        world_render_adversary_bumpers(world);
        adversary_render(adversary);

        // Draw stage expansion content (if stages have been purchased)
        if (world->stages) {
            stage_manager_render_all(world->stages);
        }

        // Draw portals (if any defined)
        if (world->portals) {
            portal_manager_render(world->portals);
        }

        // Draw player spawner reticle (issue 1309 - unified spawner system)
        spawner_render(&player_spawner);

        // Draw balls
        ball_manager_render(ball_manager);

        // Draw particles (after balls, before UI)
        particle_system_render(particle_system);

        // Draw wrap zone debug visualization (in world space)
        wrap_zones_render_debug(wrap_zones);

        // Editor overlay now renders in screen space, not world space

        // End camera mode - UI elements below are screen-fixed
        EndMode2D();

        // UI visibility toggle (issue 407)
        // Press H to hide score panel and controls panel for clean screenshots
        if (ui_visible) {
            // Draw title with semi-transparent background (fixed to screen)
            DrawRectangle(5, 5, 360, 30, (Color){0, 0, 0, 100});
            DrawText("Physics Simulator - Pachinko", 10, 10, 20, LIGHTGRAY);

            // Draw score panel (top-left, below title)
            // Issue 609: Show both player and adversary scores
            DrawRectangle(5, 40, 180, 135, (Color){0, 0, 0, 150});
            char score_text[64];

            // Player score in blue
            sprintf(score_text, "YOU: %d", world->score);
            DrawText(score_text, 10, 45, 18, SKYBLUE);

            // Adversary score in orange
            sprintf(score_text, "THEM: %d", world->adversary_score);
            DrawText(score_text, 10, 68, 18, ORANGE);

            // High score
            sprintf(score_text, "High: %d", world->high_score);
            DrawText(score_text, 10, 91, 16, GOLD);

            char ball_text[64];
            sprintf(ball_text, "Balls: %d", ball_manager->active_count);
            DrawText(ball_text, 10, 112, 16, WHITE);

            // Draw performance statistics
            char perf_text[64];
            sprintf(perf_text, "FPS: %d", GetFPS());
            DrawText(perf_text, 10, 136, 14, LIGHTGRAY);

            sprintf(perf_text, "Physics: %.2f ms", physics_ms);
            DrawText(perf_text, 10, 154, 14, LIGHTGRAY);

            sprintf(perf_text, "Threads: %d", pool->thread_count);
            DrawText(perf_text, 10, 172, 14, LIGHTGRAY);

            // Draw controls panel (top-right, below title)
            // Moved from bottom to top so gates/zones area is unobstructed
            DrawRectangle(screen_width - 205, 40, 200, 160,
                         (Color){0, 0, 0, 150});
            DrawText("Controls:", screen_width - 200, 45, 16, LIGHTGRAY);
            DrawText("CLICK - Toggle mouse aim", screen_width - 200, 65, 14, WHITE);
            DrawText("SPACE - Spawn ball", screen_width - 200, 81, 14, WHITE);
            DrawText("A - Toggle auto-spawn", screen_width - 200, 97, 14, WHITE);
            DrawText("TAB - Upgrades", screen_width - 200, 113, 14, WHITE);
            DrawText("SCROLL - Pan view", screen_width - 200, 129, 14, WHITE);
            DrawText("H - Hide UI", screen_width - 200, 145, 14, WHITE);
            DrawText("R - Reset game", screen_width - 200, 161, 14, WHITE);
            DrawText("ESC - Exit", screen_width - 200, 177, 14, WHITE);
            // Status indicators
            if (auto_spawn) {
                DrawText("[AUTO-SPAWN]", screen_width - 200, 195, 12, GREEN);
            }
            if (mouse_controls_reticle) {
                DrawText("[MOUSE AIM]", screen_width - 100, 195, 12, SKYBLUE);
            }
        }

        // Draw upgrade menu overlay (if open)
        upgrade_manager_render(upgrade_manager, world->score,
                              screen_width, screen_height);

        // Draw velocity debug overlay (issue 903)
        // Functions implemented in src/007-ball.c
        if (show_velocity_debug) {
            const VelocityStats* vstats = velocity_stats_get();
            int vy = 220;

            DrawRectangle(5, vy - 5, 220, 140, (Color){0, 0, 0, 180});
            DrawText("Velocity Stats (F10)", 10, vy, 14, YELLOW);
            vy += 20;

            char vtext[64];
            sprintf(vtext, "Max Speed: %.0f px/s", vstats->max_speed);
            DrawText(vtext, 10, vy, 12, WHITE);
            vy += 16;

            sprintf(vtext, "Max Vy: %.0f px/s", fabsf(vstats->max_vy));
            DrawText(vtext, 10, vy, 12, WHITE);
            vy += 16;

            sprintf(vtext, "Safe Threshold: %.0f px/s", MAX_SAFE_SPEED);
            DrawText(vtext, 10, vy, 12, GRAY);
            vy += 16;

            sprintf(vtext, "Gate Entry Avg: %.0f px/s", vstats->avg_gate_entry_speed);
            DrawText(vtext, 10, vy, 12, WHITE);
            vy += 16;

            sprintf(vtext, "Gate Entry Max: %.0f px/s", vstats->max_gate_entry_speed);
            DrawText(vtext, 10, vy, 12, WHITE);
            vy += 16;

            sprintf(vtext, "Potential Tunnels: %d", vstats->potential_tunnels);
            Color tunnel_color = vstats->potential_tunnels > 0 ? RED : GREEN;
            DrawText(vtext, 10, vy, 12, tunnel_color);
            vy += 16;

            sprintf(vtext, "Frames: %d", vstats->total_frames);
            DrawText(vtext, 10, vy, 12, GRAY);
        }

        EndDrawing();
    }

    // Cleanup
    printf("Shutting down...\n");
    CloseWindow();
    printf("Raylib window closed\n");

    adversary_destroy(adversary);
    printf("Adversary destroyed\n");

    wrap_zones_destroy(wrap_zones);
    printf("Wrap zones destroyed\n");

    // Zone grid destruction (issue 318)
    if (zone_grid) {
        zone_grid_destroy(zone_grid);
        printf("Zone dispatch grid destroyed\n");
    }

    stage_pool_destroy(stage_pool);
    printf("Stage pool destroyed\n");

    upgrade_manager_destroy(upgrade_manager);
    printf("Upgrade manager destroyed\n");

    particle_system_destroy(particle_system);
    printf("Particle system destroyed\n");

    ball_manager_destroy(ball_manager);
    printf("Ball manager destroyed\n");

    slot_manager_destroy(slot_manager);
    printf("Slot manager destroyed\n");

    // Rotor managers must be destroyed before world (issue 901c)
    // They hold references to world's line/peg arrays
    if (world->rotor_manager) {
        rotor_manager_destroy(world->rotor_manager);
        printf("Rotor manager destroyed\n");
    }
    if (world->adversary_rotor_manager) {
        rotor_manager_destroy(world->adversary_rotor_manager);
        printf("Adversary rotor manager destroyed\n");
    }

    // Track mover managers must be destroyed before world (issues 902c, 902d)
    // They hold references to world's line/peg arrays
    if (world->track_mover_manager) {
        track_mover_manager_destroy(world->track_mover_manager);
        printf("Track mover manager destroyed\n");
    }
    if (world->adversary_track_mover_manager) {
        track_mover_manager_destroy(world->adversary_track_mover_manager);
        printf("Adversary track mover manager destroyed\n");
    }

    world_destroy(world);
    printf("World destroyed\n");

    threadpool_destroy(pool);
    printf("Threadpool destroyed\n");

    printf("Clean shutdown complete\n");
    return 0;
}
// }}}
