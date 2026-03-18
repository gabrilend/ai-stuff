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

// Visual constants - Color palette for cohesive visual design
#define BG_COLOR (Color){30, 30, 40, 255}          // Dark blue-gray background
#define PEG_COLOR (Color){180, 180, 200, 255}      // Light steel peg fill
#define PEG_OUTLINE (Color){100, 100, 120, 255}    // Darker peg outline
#define BALL_COLOR (Color){255, 180, 50, 255}      // Warm orange ball
#define BALL_HIGHLIGHT (Color){255, 220, 150, 255} // Lighter ball highlight

// Scrolling viewport constants
#define SCROLL_SPEED 120.0f   // Pixels per scroll wheel notch (tripled for faster panning)
#define SCROLL_LERP_SPEED 8.0f // Lerp factor for smooth scrolling (higher = snappier)

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
static void apply_board_data_to_stage(BoardData* data, Stage* stage) {
    if (!data || !stage) return;

    // Create grid for coordinate conversion
    Grid grid = grid_create(data->grid_cols, data->grid_rows, (float)data->cell_size,
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
                peg->x = grid_to_pixel_x(&grid, obj->col, obj->row);
                peg->y = grid_to_pixel_y(&grid, obj->col, obj->row);
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

                float x1 = grid_to_pixel_x(&grid, obj->col, obj->row);
                float y1 = grid_to_pixel_y(&grid, obj->col, obj->row);
                float x2 = grid_to_pixel_x(&grid, obj->end_col, obj->end_row);
                float y2 = grid_to_pixel_y(&grid, obj->end_col, obj->end_row);

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
    Grid grid = grid_create(data->grid_cols, data->grid_rows, (float)data->cell_size,
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

        // Default player peg color (light steel)
        Color default_color = (Color){180, 180, 200, 255};

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

            // Use default color if no custom properties, otherwise tint based on properties
            if (obj->restitution == DEFAULT_RESTITUTION &&
                obj->friction == DEFAULT_FRICTION &&
                obj->point_bonus == DEFAULT_POINT_BONUS) {
                peg->color = default_color;
            } else {
                // Tint based on RGB properties
                int red = 140 + (obj->restitution * 115 / 255);
                int green = 140 + (obj->friction * 60 / 255);
                int blue = 140 + (obj->point_bonus * 115 / 255);
                peg->color = (Color){(unsigned char)red, (unsigned char)green,
                                     (unsigned char)blue, 255};
            }
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

            // Default line color (warm orange)
            Color default_line_color = (Color){255, 160, 80, 255};

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

                // Use default color if no custom properties, otherwise tint
                if (obj->restitution == DEFAULT_RESTITUTION &&
                    obj->friction == DEFAULT_FRICTION &&
                    obj->point_bonus == DEFAULT_POINT_BONUS) {
                    line->color = default_line_color;
                } else {
                    // Tint based on RGB properties
                    int red = 180 + (obj->restitution * 75 / 255);
                    int green = 100 + (obj->friction * 60 / 255);
                    int blue = 40 + (obj->point_bonus * 40 / 255);
                    line->color = (Color){(unsigned char)red, (unsigned char)green,
                                          (unsigned char)blue, 255};
                }
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
    Grid grid = grid_create(data->grid_cols, data->grid_rows, (float)data->cell_size,
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

        // Default adversary peg color (reddish steel)
        Color default_color = (Color){180, 140, 140, 255};

        int peg_idx = 0;
        for (int i = 0; i < data->object_count; i++) {
            BoardObject* obj = &data->objects[i];
            if (obj->type != OBJECT_PEG) continue;

            Peg* peg = &world->adversary_pegs[peg_idx];
            peg->x = grid_to_pixel_x(&grid, obj->col, obj->row);
            peg->y = grid_to_pixel_y(&grid, obj->col, obj->row);
            peg->radius = PEG_RADIUS;
            peg->restitution = property_to_float(obj->restitution);
            peg->friction = property_to_float(obj->friction);
            peg->point_bonus = obj->point_bonus;

            // Use default adversary color if no custom properties, otherwise tint
            if (obj->restitution == DEFAULT_RESTITUTION &&
                obj->friction == DEFAULT_FRICTION &&
                obj->point_bonus == DEFAULT_POINT_BONUS) {
                peg->color = default_color;
            } else {
                // Reddish tint based on RGB properties
                int red = 160 + (obj->restitution * 95 / 255);
                int green = 100 + (obj->friction * 40 / 255);
                int blue = 100 + (obj->point_bonus * 55 / 255);
                peg->color = (Color){(unsigned char)red, (unsigned char)green,
                                     (unsigned char)blue, 255};
            }
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

            // Default adversary line color (reddish orange)
            Color default_line_color = (Color){220, 120, 80, 255};

            int line_idx = 0;
            for (int i = 0; i < data->object_count; i++) {
                BoardObject* obj = &data->objects[i];
                if (obj->type != OBJECT_LINE) continue;

                Line* line = &world->adversary_lines[line_idx];
                line->x1 = grid_to_pixel_x(&grid, obj->col, obj->row);
                line->y1 = grid_to_pixel_y(&grid, obj->col, obj->row);
                line->x2 = grid_to_pixel_x(&grid, obj->end_col, obj->end_row);
                line->y2 = grid_to_pixel_y(&grid, obj->end_col, obj->end_row);
                line->thickness = obj->thickness;
                line->restitution = property_to_float(obj->restitution);
                line->friction = property_to_float(obj->friction);
                line->point_bonus = obj->point_bonus;

                // Use default color if no custom properties, otherwise tint
                if (obj->restitution == DEFAULT_RESTITUTION &&
                    obj->friction == DEFAULT_FRICTION &&
                    obj->point_bonus == DEFAULT_POINT_BONUS) {
                    line->color = default_line_color;
                } else {
                    // Reddish tint based on RGB properties
                    int red = 180 + (obj->restitution * 75 / 255);
                    int green = 80 + (obj->friction * 40 / 255);
                    int blue = 40 + (obj->point_bonus * 40 / 255);
                    line->color = (Color){(unsigned char)red, (unsigned char)green,
                                          (unsigned char)blue, 255};
                }
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
            apply_board_data_to_stage(stage_data, player_stage);
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
            // For adversary, apply same data but mirrored vertically
            // (simplified: just use same layout for now)
            apply_board_data_to_stage(stage_data, adv_stage);
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

    // Table dimensions - fixed width, dynamic height
    float table_width = 800.0f;  // Fixed table width
    float peg_start_y = 150.0f;  // Large gap from spawn (SPAWN_Y=50) for ball clearance
    float zone_height = 40.0f;

    // Set table bounds (centers table horizontally in window)
    world_set_table_bounds(world, table_width, peg_start_y, zone_height);
    printf("Table bounds: x=%.0f, width=%.0f, top=%.0f, bottom=%.0f\n",
           world->table_x, world->table_width, world->table_top, world->table_bottom);

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

    // Apply the board data to the world (centered in table)
    float board_width = initial_board->grid_cols * initial_board->cell_size;
    float board_start_x = world->table_x + (table_width - board_width) / 2.0f;

    if (!apply_initial_board_data(initial_board, world, board_start_x, peg_start_y)) {
        fprintf(stderr, "ERROR: Failed to apply board data\n");
        board_data_destroy(initial_board);
        world_destroy(world);
        threadpool_destroy(pool);
        CloseWindow();
        return 1;
    }
    printf("Applied board: %d pegs\n", world->peg_count);

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
    // Adversary uses identical layout to player, just positioned below the gates
    {
        float adv_board_width = initial_board->grid_cols * initial_board->cell_size;
        float adv_board_start_x = world->table_x + (table_width - adv_board_width) / 2.0f;
        float adv_start_y = world->zones[0].y_max + 50.0f;  // Margin below zones

        // Calculate adversary board height for table bounds
        float adv_board_height = initial_board->grid_rows * initial_board->cell_size;

        // Set adversary table bounds
        world->adversary_table_top = world->zones[0].y_max;
        world->adversary_table_bottom = world->adversary_table_top + adv_board_height + 100.0f;

        if (!apply_adversary_board_data(initial_board, world, adv_board_start_x, adv_start_y)) {
            fprintf(stderr, "ERROR: Failed to apply adversary board data\n");
            board_data_destroy(initial_board);
            world_destroy(world);
            threadpool_destroy(pool);
            CloseWindow();
            return 1;
        }
        printf("Applied adversary board (mirrored): %d pegs\n", world->adversary_peg_count);
    }

    // Clean up board data
    board_data_destroy(initial_board);
    initial_board = NULL;

    world_generate_adversary_bumpers(world);
    printf("Generated adversary bumpers: %d\n", world->adversary_bumper_count);

    // Create adversary AI
    Adversary* adversary = adversary_create(world);
    if (!adversary) {
        fprintf(stderr, "ERROR: Failed to create adversary\n");
        upgrade_manager_destroy(upgrade_manager);
        particle_system_destroy(particle_system);
        ball_manager_destroy(ball_manager);
        world_destroy(world);
        threadpool_destroy(pool);
        CloseWindow();
        return 1;
    }
    printf("Adversary AI created\n");

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

    // Spawn point position - single source of truth for spawn location
    // spawn_x is movable via mouse/keyboard, spawn_y is fixed
    float spawn_x = SPAWN_X;  // Start at center (movable)
    float spawn_y = SPAWN_Y;  // Fixed vertical position
    float spawn_nudge_speed = 200.0f;  // Pixels per second for keyboard control
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

        // Update spawn cooldown (base rate)
        ball_manager_update_cooldown(ball_manager, dt);

        // Add bonus spawn credits from upgrades
        float spawn_rate_bonus = upgrade_get_spawn_rate_bonus(upgrade_manager);
        if (spawn_rate_bonus > 0.0f) {
            ball_manager->spawn_credits += spawn_rate_bonus * dt;
            if (ball_manager->spawn_credits > MAX_SPAWN_CREDITS) {
                ball_manager->spawn_credits = MAX_SPAWN_CREDITS;
            }
        }

        // Particle system now updated in parallel after ball physics
        // (see particle_system_prepare_tasks/submit_tasks/finalize/swap below)

        // Handle spawn point movement - toggle-based mouse control
        // Calculate spawn bounds (keep ball radius away from rails)
        float spawn_margin = BALL_RADIUS + 5.0f;
        float spawn_min_x = world->table_x + spawn_margin;
        float spawn_max_x = world->table_x + world->table_width - spawn_margin;

        // Toggle mouse control on left click (when menu is closed)
        if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON) && !upgrade_manager->menu_open) {
            mouse_controls_reticle = !mouse_controls_reticle;
        }

        // Mouse tracking (only when enabled via toggle)
        if (mouse_controls_reticle) {
            Vector2 mouse_screen = { (float)GetMouseX(), (float)GetMouseY() };
            Vector2 mouse_world = GetScreenToWorld2D(mouse_screen, camera);
            spawn_x = mouse_world.x;
        }

        // Arrow keys always work (independent of mouse toggle)
        if (IsKeyDown(KEY_LEFT)) {
            spawn_x -= spawn_nudge_speed * dt;
        }
        if (IsKeyDown(KEY_RIGHT)) {
            spawn_x += spawn_nudge_speed * dt;
        }

        // Clamp spawn_x to table bounds
        if (spawn_x < spawn_min_x) spawn_x = spawn_min_x;
        if (spawn_x > spawn_max_x) spawn_x = spawn_max_x;

        // Handle auto-spawn toggle (A key) - only when menu is closed
        if (IsKeyPressed(KEY_A) && !upgrade_manager->menu_open) {
            auto_spawn = !auto_spawn;
            printf("Auto-spawn: %s\n", auto_spawn ? "ON" : "OFF");
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

            // Recalculate table centering (width stays fixed at 800)
            world_set_table_bounds(world, table_width, peg_start_y, zone_height);

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
            float min_offset = world->table_top - (float)screen_height;
            float max_offset = world->adversary_table_bottom;
            if (viewport_target_y < min_offset) viewport_target_y = min_offset;
            if (viewport_target_y > max_offset) viewport_target_y = max_offset;
            if (viewport_offset_y < min_offset) viewport_offset_y = min_offset;
            if (viewport_offset_y > max_offset) viewport_offset_y = max_offset;

            // Update camera target
            camera.target = (Vector2){ (float)screen_width / 2.0f,
                                       (float)screen_height / 2.0f + viewport_offset_y };

            // Update wrap zones for new screen size
            wrap_zones_update(wrap_zones, (float)screen_height);
            stage_ctx.screen_height = (float)screen_height;

            printf("Window resized: %dx%d, table_x=%.0f\n",
                   screen_width, screen_height, world->table_x);
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

            // Reset adversary spawn position
            adversary_reset(adversary, world);
        }

        // Handle scroll wheel for viewport panning
        // Scroll wheel updates target, actual position lerps toward it
        float scroll = GetMouseWheelMove();
        if (scroll != 0.0f) {
            viewport_target_y -= scroll * SCROLL_SPEED;

            // Clamp target to valid range
            float min_offset = world->table_top - (float)screen_height;
            float max_offset = world->adversary_table_bottom;
            if (viewport_target_y < min_offset) viewport_target_y = min_offset;
            if (viewport_target_y > max_offset) viewport_target_y = max_offset;
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
            if (task->scored) {
                // Choose ripple color based on point value
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
                particle_spawn_fragments(particle_system, task->death_pos_x,
                                        task->death_pos_y, task->death_vx,
                                        task->death_vy, MAGENTA, frag_mode,
                                        task->death_nx, task->death_ny);
            }

            // Spawn splash for cross-owner ball collisions (skip if ball exploded)
            if (task->had_collision && !task->died_from_damage) {
                // Small tangent splash at collision point
                Color splash_color = (Color){255, 200, 100, 255};  // Warm spark
                particle_spawn_splash(particle_system, task->collision_x,
                                     task->collision_y, task->collision_tx,
                                     task->collision_ty, splash_color);
            }
        }

        // Parallel particle physics update
        // Particles spawned above are now in particles_current, will be updated
        particle_system_prepare_tasks(particle_system, world, dt);
        particle_system_submit_tasks(particle_system, pool);
        threadpool_wait_all(pool);
        particle_system_finalize_update(particle_system);
        particle_system_swap_buffers(particle_system);

        // Collect scores and reset scoring fields
        int points = ball_manager_collect_scores(ball_manager);
        world->score += points;

        // Update high score if current score exceeds it
        if (world->score > world->high_score) {
            world->high_score = world->score;
        }

        ball_manager_finalize_update(ball_manager);
        ball_manager_swap_buffers(ball_manager);
        // Wrap zone checking now happens in ball physics (see ball_physics_task)

        double physics_end = GetTime();
        physics_ms = (physics_end - physics_start) * 1000.0;

        // Handle ball spawning input (after buffer swap so balls render at spawn position)
        // Check cooldown AND that no balls are blocking the spawn area
        // Spawn blocking prevents physics issues when balls overlap at spawn
        // Auto-spawn acts like SPACE is held down
        // Uses movable spawn_x position, fixed spawn_y height
        // Spawning paused while upgrade menu is open
        if (!upgrade_manager->menu_open &&
            (IsKeyDown(KEY_SPACE) || auto_spawn) && ball_manager_can_spawn(ball_manager) &&
            !ball_manager_spawn_blocked(ball_manager, spawn_x, spawn_y)) {
            // Calculate ball radius with upgrade modifier
            float ball_radius = BALL_RADIUS + upgrade_get_ball_radius_modifier(upgrade_manager);
            ball_manager_spawn(ball_manager, spawn_x, spawn_y, ball_radius,
                             OWNER_PLAYER, 1.0f);  // Player ball, gravity down
            ball_manager_reset_cooldown(ball_manager);
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

        // Draw spawn point indicator (pulsing circle at movable position)
        float pulse = sinf((float)GetTime() * 4.0f) * 0.5f + 0.5f;  // Oscillates 0-1
        unsigned char alpha = (unsigned char)(pulse * 150.0f + 50.0f);  // Range: 50-200
        DrawCircleLines((int)spawn_x, (int)spawn_y, 15.0f,
                       (Color){255, 255, 255, alpha});

        // Draw cooldown indicator (ring around spawn point)
        // Uses spawn_credits fractional part for continuous progress
        // Colors invert on each spawn for visual continuity (issue 1119)
        // - Odd phases: dim background, bright progress (fills up)
        // - Even phases: bright background, dim progress (appears to empty)
        int spawn_phase = (int)ball_manager->spawn_credits;
        int inverted = spawn_phase % 2;
        float credits_frac = ball_manager->spawn_credits - spawn_phase;

        // Define color palette for player reticle
        Color dim_cyan = (Color){60, 80, 100, 150};
        Color bright_cyan = (Color){100, 200, 255, 220};

        // Swap colors based on phase for seamless visual continuity
        Color bg_color = inverted ? bright_cyan : dim_cyan;
        Color arc_color = inverted ? dim_cyan : bright_cyan;

        // Background ring (full circle)
        DrawRing((Vector2){spawn_x, spawn_y}, 18.0f, 20.0f,
                0, 360, 32, bg_color);

        // Progress arc - always shows fractional progress toward next credit
        float arc_degrees = 360.0f * credits_frac;
        DrawRing((Vector2){spawn_x, spawn_y}, 18.0f, 20.0f,
                -90, -90 + arc_degrees, 32, arc_color);

        // Draw balls
        ball_manager_render(ball_manager);

        // Draw particles (after balls, before UI)
        particle_system_render(particle_system);

        // Draw wrap zone debug visualization (in world space)
        wrap_zones_render_debug(wrap_zones);

        // Editor overlay now renders in screen space, not world space

        // End camera mode - UI elements below are screen-fixed
        EndMode2D();

        // Draw title with semi-transparent background (fixed to screen)
        DrawRectangle(5, 5, 360, 30, (Color){0, 0, 0, 100});
        DrawText("Physics Simulator - Pachinko", 10, 10, 20, LIGHTGRAY);

        // Draw score panel (top-left, below title)
        // Moved from bottom to top so gates/zones area is unobstructed
        DrawRectangle(5, 40, 180, 115, (Color){0, 0, 0, 150});
        char score_text[64];
        sprintf(score_text, "Score: %d", world->score);
        DrawText(score_text, 10, 45, 18, WHITE);

        sprintf(score_text, "High: %d", world->high_score);
        DrawText(score_text, 10, 68, 16, GOLD);

        char ball_text[64];
        sprintf(ball_text, "Balls: %d", ball_manager->active_count);
        DrawText(ball_text, 10, 92, 16, WHITE);

        // Draw performance statistics
        char perf_text[64];
        sprintf(perf_text, "FPS: %d", GetFPS());
        DrawText(perf_text, 10, 116, 14, LIGHTGRAY);

        sprintf(perf_text, "Physics: %.2f ms", physics_ms);
        DrawText(perf_text, 10, 134, 14, LIGHTGRAY);

        sprintf(perf_text, "Threads: %d", pool->thread_count);
        DrawText(perf_text, 10, 152, 14, LIGHTGRAY);

        // Draw controls panel (top-right, below title)
        // Moved from bottom to top so gates/zones area is unobstructed
        DrawRectangle(screen_width - 205, 40, 200, 150,
                     (Color){0, 0, 0, 150});
        DrawText("Controls:", screen_width - 200, 45, 16, LIGHTGRAY);
        DrawText("CLICK - Toggle mouse aim", screen_width - 200, 65, 14, WHITE);
        DrawText("SPACE - Spawn ball", screen_width - 200, 81, 14, WHITE);
        DrawText("A - Toggle auto-spawn", screen_width - 200, 97, 14, WHITE);
        DrawText("TAB - Upgrades", screen_width - 200, 113, 14, WHITE);
        DrawText("SCROLL - Pan view", screen_width - 200, 129, 14, WHITE);
        DrawText("R - Reset game", screen_width - 200, 145, 14, WHITE);
        DrawText("ESC - Exit", screen_width - 200, 161, 14, WHITE);
        // Status indicators
        if (auto_spawn) {
            DrawText("[AUTO-SPAWN]", screen_width - 200, 179, 12, GREEN);
        }
        if (mouse_controls_reticle) {
            DrawText("[MOUSE AIM]", screen_width - 100, 179, 12, SKYBLUE);
        }

        // Draw upgrade menu overlay (if open)
        upgrade_manager_render(upgrade_manager, world->score,
                              screen_width, screen_height);

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

    stage_pool_destroy(stage_pool);
    printf("Stage pool destroyed\n");

    upgrade_manager_destroy(upgrade_manager);
    printf("Upgrade manager destroyed\n");

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
