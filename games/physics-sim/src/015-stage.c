// src/015-stage.c
// Stage system implementation
// Manages dynamic board expansion with multiple stage types

#include "014-stage.h"
#include "006-ball.h"
#include <raylib.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

// Initial capacity for dynamic arrays
#define INITIAL_STAGE_CAPACITY 4
#define INITIAL_GATE_ROW_CAPACITY 8

// Bumper radius (matches BUMPER_RADIUS in ball.h)
#define BUMPER_RADIUS 10.0f

// =============================================================================
// StageManager functions
// =============================================================================

// {{{ stage_manager_create
StageManager* stage_manager_create(float table_x, float table_width) {
    StageManager* manager = (StageManager*)malloc(sizeof(StageManager));
    if (!manager) {
        fprintf(stderr, "ERROR: Failed to allocate stage manager\n");
        return NULL;
    }

    // Initialize player stages
    manager->player_stages = (Stage*)malloc(sizeof(Stage) * INITIAL_STAGE_CAPACITY);
    if (!manager->player_stages) {
        fprintf(stderr, "ERROR: Failed to allocate player stages array\n");
        free(manager);
        return NULL;
    }
    manager->player_stage_count = 0;
    manager->player_stage_capacity = INITIAL_STAGE_CAPACITY;

    // Initialize adversary stages
    manager->adversary_stages = (Stage*)malloc(sizeof(Stage) * INITIAL_STAGE_CAPACITY);
    if (!manager->adversary_stages) {
        fprintf(stderr, "ERROR: Failed to allocate adversary stages array\n");
        free(manager->player_stages);
        free(manager);
        return NULL;
    }
    manager->adversary_stage_count = 0;
    manager->adversary_stage_capacity = INITIAL_STAGE_CAPACITY;

    // Initialize gate rows
    manager->gate_rows = (GateRow*)malloc(sizeof(GateRow) * INITIAL_GATE_ROW_CAPACITY);
    if (!manager->gate_rows) {
        fprintf(stderr, "ERROR: Failed to allocate gate rows array\n");
        free(manager->adversary_stages);
        free(manager->player_stages);
        free(manager);
        return NULL;
    }
    manager->gate_row_count = 0;
    manager->gate_row_capacity = INITIAL_GATE_ROW_CAPACITY;

    // Store table dimensions
    manager->table_x = table_x;
    manager->table_width = table_width;

    return manager;
}
// }}}

// {{{ stage_manager_destroy
void stage_manager_destroy(StageManager* manager) {
    if (!manager) return;

    // Cleanup and free player stages
    if (manager->player_stages) {
        for (int i = 0; i < manager->player_stage_count; i++) {
            stage_cleanup(&manager->player_stages[i]);
        }
        free(manager->player_stages);
    }

    // Cleanup and free adversary stages
    if (manager->adversary_stages) {
        for (int i = 0; i < manager->adversary_stage_count; i++) {
            stage_cleanup(&manager->adversary_stages[i]);
        }
        free(manager->adversary_stages);
    }

    // Cleanup and free gate rows
    if (manager->gate_rows) {
        for (int i = 0; i < manager->gate_row_count; i++) {
            gate_row_cleanup(&manager->gate_rows[i]);
        }
        free(manager->gate_rows);
    }

    free(manager);
}
// }}}

// {{{ stage_manager_add_player_stage
int stage_manager_add_player_stage(StageManager* manager, StageType type,
                                   float height) {
    if (!manager) return -1;

    // Grow array if needed
    if (manager->player_stage_count >= manager->player_stage_capacity) {
        int new_capacity = manager->player_stage_capacity * 2;
        Stage* new_stages = (Stage*)realloc(manager->player_stages,
                                            sizeof(Stage) * new_capacity);
        if (!new_stages) {
            fprintf(stderr, "ERROR: Failed to grow player stages array\n");
            return -1;
        }
        manager->player_stages = new_stages;
        manager->player_stage_capacity = new_capacity;
    }

    // Calculate y_top based on existing stages
    // New stages go below existing ones
    float y_top = 0.0f;
    if (manager->player_stage_count > 0) {
        Stage* last = &manager->player_stages[manager->player_stage_count - 1];
        y_top = last->y_bottom;
    }

    // Initialize the new stage
    int index = manager->player_stage_count;
    stage_init(&manager->player_stages[index], type, y_top, height,
               manager->table_x, manager->table_width);
    manager->player_stage_count++;

    return index;
}
// }}}

// {{{ stage_manager_add_adversary_stage
int stage_manager_add_adversary_stage(StageManager* manager, StageType type,
                                      float height) {
    if (!manager) return -1;

    // Grow array if needed
    if (manager->adversary_stage_count >= manager->adversary_stage_capacity) {
        int new_capacity = manager->adversary_stage_capacity * 2;
        Stage* new_stages = (Stage*)realloc(manager->adversary_stages,
                                            sizeof(Stage) * new_capacity);
        if (!new_stages) {
            fprintf(stderr, "ERROR: Failed to grow adversary stages array\n");
            return -1;
        }
        manager->adversary_stages = new_stages;
        manager->adversary_stage_capacity = new_capacity;
    }

    // Calculate y_top based on existing stages
    // Adversary stages also stack downward in y-coordinates (visually below)
    float y_top = 0.0f;
    if (manager->adversary_stage_count > 0) {
        Stage* last = &manager->adversary_stages[manager->adversary_stage_count - 1];
        y_top = last->y_bottom;
    }

    // Initialize the new stage
    int index = manager->adversary_stage_count;
    stage_init(&manager->adversary_stages[index], type, y_top, height,
               manager->table_x, manager->table_width);
    manager->adversary_stage_count++;

    return index;
}
// }}}

// {{{ stage_manager_add_gate_row
int stage_manager_add_gate_row(StageManager* manager, float y_top,
                               float height, int zone_count, int multiplier) {
    if (!manager) return -1;

    // Grow array if needed
    if (manager->gate_row_count >= manager->gate_row_capacity) {
        int new_capacity = manager->gate_row_capacity * 2;
        GateRow* new_rows = (GateRow*)realloc(manager->gate_rows,
                                              sizeof(GateRow) * new_capacity);
        if (!new_rows) {
            fprintf(stderr, "ERROR: Failed to grow gate rows array\n");
            return -1;
        }
        manager->gate_rows = new_rows;
        manager->gate_row_capacity = new_capacity;
    }

    // Initialize the new gate row
    int index = manager->gate_row_count;
    gate_row_init(&manager->gate_rows[index], y_top, height,
                  manager->table_x, manager->table_width,
                  zone_count, multiplier);
    manager->gate_row_count++;

    return index;
}
// }}}

// {{{ stage_manager_get_total_height
float stage_manager_get_total_height(StageManager* manager) {
    if (!manager) return 0.0f;

    float total = 0.0f;

    // Sum player stage heights
    for (int i = 0; i < manager->player_stage_count; i++) {
        total += manager->player_stages[i].height;
    }

    // Sum adversary stage heights
    for (int i = 0; i < manager->adversary_stage_count; i++) {
        total += manager->adversary_stages[i].height;
    }

    // Sum gate row heights
    for (int i = 0; i < manager->gate_row_count; i++) {
        total += manager->gate_rows[i].height;
    }

    return total;
}
// }}}

// =============================================================================
// Stage functions
// =============================================================================

// {{{ stage_init
void stage_init(Stage* stage, StageType type, float y_top, float height,
                float table_x, float table_width) {
    if (!stage) return;

    stage->type = type;
    stage->y_top = y_top;
    stage->y_bottom = y_top + height;
    stage->height = height;
    stage->table_x = table_x;
    stage->table_width = table_width;

    // Initialize obstacle arrays as empty
    stage->pegs = NULL;
    stage->peg_count = 0;
    stage->ramps = NULL;
    stage->ramp_count = 0;
}
// }}}

// {{{ stage_cleanup
void stage_cleanup(Stage* stage) {
    if (!stage) return;

    if (stage->pegs) {
        free(stage->pegs);
        stage->pegs = NULL;
    }
    stage->peg_count = 0;

    if (stage->ramps) {
        free(stage->ramps);
        stage->ramps = NULL;
    }
    stage->ramp_count = 0;
}
// }}}

// {{{ stage_generate_pegs
void stage_generate_pegs(Stage* stage, int rows, int cols, float spacing) {
    if (!stage || rows <= 0 || cols <= 0) return;

    // Free existing pegs
    if (stage->pegs) {
        free(stage->pegs);
    }

    // Allocate peg array
    stage->peg_count = rows * cols;
    stage->pegs = (Peg*)malloc(sizeof(Peg) * stage->peg_count);

    if (!stage->pegs) {
        fprintf(stderr, "ERROR: Failed to allocate stage peg array\n");
        stage->peg_count = 0;
        return;
    }

    // Calculate grid positioning
    float peg_grid_width = cols * spacing;
    float start_x = stage->table_x + (stage->table_width - peg_grid_width) / 2.0f;
    float start_y = stage->y_top + spacing / 2.0f;  // Small margin at top

    // Generate staggered grid
    int idx = 0;
    for (int row = 0; row < rows; row++) {
        // Odd rows get half-spacing offset for staggered pattern
        float offset = (row % 2 == 0) ? 0.0f : spacing / 2.0f;

        for (int col = 0; col < cols; col++) {
            stage->pegs[idx].x = start_x + col * spacing + offset;
            stage->pegs[idx].y = start_y + row * spacing;
            stage->pegs[idx].radius = PEG_RADIUS;
            idx++;
        }
    }
}
// }}}

// {{{ stage_render
void stage_render(Stage* stage) {
    if (!stage) return;

    // Render based on stage type
    if (stage->type == STAGE_TYPE_PEGS && stage->pegs) {
        // Peg rendering (same style as world_render_pegs)
        Color peg_color = (Color){180, 180, 200, 255};
        Color peg_outline = (Color){100, 100, 120, 255};

        for (int i = 0; i < stage->peg_count; i++) {
            DrawCircle((int)stage->pegs[i].x, (int)stage->pegs[i].y,
                       stage->pegs[i].radius, peg_color);
            DrawCircleLines((int)stage->pegs[i].x, (int)stage->pegs[i].y,
                           stage->pegs[i].radius, peg_outline);
        }
    }
    else if (stage->type == STAGE_TYPE_RAMPS && stage->ramps) {
        // Render each ramp
        for (int i = 0; i < stage->ramp_count; i++) {
            ramp_render(&stage->ramps[i]);
        }
    }
}
// }}}

// {{{ stage_generate_ramps_stage2
void stage_generate_ramps_stage2(Stage* stage) {
    if (!stage) return;

    // Free existing ramps
    if (stage->ramps) {
        free(stage->ramps);
    }

    // Allocate ramp array
    stage->ramp_count = STAGE_2_RAMP_COUNT;
    stage->ramps = (Ramp*)malloc(sizeof(Ramp) * stage->ramp_count);
    if (!stage->ramps) {
        fprintf(stderr, "ERROR: Failed to allocate stage 2 ramps\n");
        stage->ramp_count = 0;
        return;
    }

    float table_x = stage->table_x;
    float table_width = stage->table_width;
    float center_x = table_x + table_width / 2.0f;
    float y = stage->y_top + 20.0f;

    // Row 1: Outer catchers (2 ramps pointing inward)
    // Left ramp catches balls on left edge, pushes them right
    stage->ramps[0] = ramp_create(
        table_x + 30.0f, y,
        STAGE_2_RAMP_WIDTH, STAGE_2_RAMP_HEIGHT,
        RAMP_RIGHT
    );
    // Right ramp catches balls on right edge, pushes them left
    stage->ramps[1] = ramp_create(
        table_x + table_width - 30.0f - STAGE_2_RAMP_WIDTH, y,
        STAGE_2_RAMP_WIDTH, STAGE_2_RAMP_HEIGHT,
        RAMP_LEFT
    );

    y += 60.0f;

    // Row 2: Inner redirectors (2 ramps creating crossing pattern)
    stage->ramps[2] = ramp_create(
        center_x - STAGE_2_RAMP_WIDTH - 20.0f, y,
        STAGE_2_RAMP_WIDTH, STAGE_2_RAMP_HEIGHT,
        RAMP_LEFT
    );
    stage->ramps[3] = ramp_create(
        center_x + 20.0f, y,
        STAGE_2_RAMP_WIDTH, STAGE_2_RAMP_HEIGHT,
        RAMP_RIGHT
    );

    y += 60.0f;

    // Row 3: Zigzag (4 smaller ramps creating alternating pattern)
    float spacing = table_width / 5.0f;
    float small_width = 80.0f;
    float small_height = 30.0f;

    stage->ramps[4] = ramp_create(
        table_x + spacing * 0.5f, y,
        small_width, small_height, RAMP_RIGHT
    );
    stage->ramps[5] = ramp_create(
        table_x + spacing * 1.5f, y,
        small_width, small_height, RAMP_LEFT
    );
    stage->ramps[6] = ramp_create(
        table_x + spacing * 2.5f, y,
        small_width, small_height, RAMP_RIGHT
    );
    stage->ramps[7] = ramp_create(
        table_x + spacing * 3.5f, y,
        small_width, small_height, RAMP_LEFT
    );

    // Center drop zone is empty - balls fall through naturally
}
// }}}

// {{{ stage_generate_ramps_stage2_mirrored
void stage_generate_ramps_stage2_mirrored(Stage* stage) {
    if (!stage) return;

    // Free existing ramps
    if (stage->ramps) {
        free(stage->ramps);
    }

    // Allocate ramp array
    stage->ramp_count = STAGE_2_RAMP_COUNT;
    stage->ramps = (Ramp*)malloc(sizeof(Ramp) * stage->ramp_count);
    if (!stage->ramps) {
        fprintf(stderr, "ERROR: Failed to allocate stage 2 mirrored ramps\n");
        stage->ramp_count = 0;
        return;
    }

    float table_x = stage->table_x;
    float table_width = stage->table_width;
    float center_x = table_x + table_width / 2.0f;

    // For adversary, balls travel upward so we position ramps from bottom
    // and reverse the directions
    float y = stage->y_bottom - 20.0f - STAGE_2_RAMP_HEIGHT;

    // Row 1 (bottom for adversary): Outer catchers with reversed directions
    // These catch balls coming up from below
    stage->ramps[0] = ramp_create(
        table_x + 30.0f, y,
        STAGE_2_RAMP_WIDTH, STAGE_2_RAMP_HEIGHT,
        RAMP_LEFT  // Reversed from player
    );
    stage->ramps[1] = ramp_create(
        table_x + table_width - 30.0f - STAGE_2_RAMP_WIDTH, y,
        STAGE_2_RAMP_WIDTH, STAGE_2_RAMP_HEIGHT,
        RAMP_RIGHT  // Reversed from player
    );

    y -= 60.0f;

    // Row 2: Inner redirectors (reversed)
    stage->ramps[2] = ramp_create(
        center_x - STAGE_2_RAMP_WIDTH - 20.0f, y,
        STAGE_2_RAMP_WIDTH, STAGE_2_RAMP_HEIGHT,
        RAMP_RIGHT  // Reversed
    );
    stage->ramps[3] = ramp_create(
        center_x + 20.0f, y,
        STAGE_2_RAMP_WIDTH, STAGE_2_RAMP_HEIGHT,
        RAMP_LEFT   // Reversed
    );

    y -= 60.0f;

    // Row 3: Zigzag (reversed directions)
    float spacing = table_width / 5.0f;
    float small_width = 80.0f;
    float small_height = 30.0f;

    stage->ramps[4] = ramp_create(
        table_x + spacing * 0.5f, y,
        small_width, small_height, RAMP_LEFT   // Reversed
    );
    stage->ramps[5] = ramp_create(
        table_x + spacing * 1.5f, y,
        small_width, small_height, RAMP_RIGHT  // Reversed
    );
    stage->ramps[6] = ramp_create(
        table_x + spacing * 2.5f, y,
        small_width, small_height, RAMP_LEFT   // Reversed
    );
    stage->ramps[7] = ramp_create(
        table_x + spacing * 3.5f, y,
        small_width, small_height, RAMP_RIGHT  // Reversed
    );
}
// }}}

// =============================================================================
// GateRow functions
// =============================================================================

// {{{ gate_row_init
void gate_row_init(GateRow* row, float y_top, float height,
                   float table_x, float table_width,
                   int zone_count, int multiplier) {
    if (!row || zone_count <= 0) return;

    row->y_top = y_top;
    row->y_bottom = y_top + height;
    row->height = height;
    row->value_multiplier = multiplier;

    // Allocate zones
    row->zone_count = zone_count;
    row->zones = (ScoreZone*)malloc(sizeof(ScoreZone) * zone_count);
    if (!row->zones) {
        fprintf(stderr, "ERROR: Failed to allocate gate row zones\n");
        row->zone_count = 0;
        return;
    }

    // Default point values (symmetric pattern)
    int base_points[] = {10, 50, 100, 500, 100, 50, 10};
    float zone_width = table_width / zone_count;

    for (int i = 0; i < zone_count; i++) {
        row->zones[i].x_min = table_x + i * zone_width;
        row->zones[i].x_max = table_x + (i + 1) * zone_width;
        row->zones[i].y_min = y_top;
        row->zones[i].y_max = y_top + height;

        // Apply multiplier to base points
        if (zone_count == 7) {
            row->zones[i].points = base_points[i] * multiplier;
        } else {
            int distance_from_center = (zone_count / 2) - i;
            if (distance_from_center < 0) distance_from_center = -distance_from_center;
            row->zones[i].points = (zone_count - distance_from_center) * 100 * multiplier;
        }
    }

    // Allocate bumpers (zone_count - 1 dividers)
    row->bumper_count = zone_count - 1;
    row->bumpers_top = (Bumper*)malloc(sizeof(Bumper) * row->bumper_count);
    row->bumpers_bottom = (Bumper*)malloc(sizeof(Bumper) * row->bumper_count);

    if (!row->bumpers_top || !row->bumpers_bottom) {
        fprintf(stderr, "ERROR: Failed to allocate gate row bumpers\n");
        if (row->bumpers_top) free(row->bumpers_top);
        if (row->bumpers_bottom) free(row->bumpers_bottom);
        row->bumpers_top = NULL;
        row->bumpers_bottom = NULL;
        row->bumper_count = 0;
        return;
    }

    // Generate bumpers at each zone divider
    for (int i = 0; i < row->bumper_count; i++) {
        float divider_x = row->zones[i].x_max;

        // Top bumpers (for balls falling down)
        row->bumpers_top[i].x = divider_x;
        row->bumpers_top[i].y = y_top;
        row->bumpers_top[i].radius = BUMPER_RADIUS;

        // Bottom bumpers (for balls rising up)
        row->bumpers_bottom[i].x = divider_x;
        row->bumpers_bottom[i].y = y_top + height;
        row->bumpers_bottom[i].radius = BUMPER_RADIUS;
    }
}
// }}}

// {{{ gate_row_cleanup
void gate_row_cleanup(GateRow* row) {
    if (!row) return;

    if (row->zones) {
        free(row->zones);
        row->zones = NULL;
    }
    row->zone_count = 0;

    if (row->bumpers_top) {
        free(row->bumpers_top);
        row->bumpers_top = NULL;
    }
    if (row->bumpers_bottom) {
        free(row->bumpers_bottom);
        row->bumpers_bottom = NULL;
    }
    row->bumper_count = 0;
}
// }}}

// {{{ gate_row_render
void gate_row_render(GateRow* row) {
    if (!row || !row->zones) return;

    // Render zones
    for (int i = 0; i < row->zone_count; i++) {
        ScoreZone* zone = &row->zones[i];
        float zone_width = zone->x_max - zone->x_min;
        float zone_height = zone->y_max - zone->y_min;

        // Choose color based on point value (accounting for multiplier)
        Color zone_color;
        int display_points = zone->points;
        if (display_points >= 500 * row->value_multiplier) {
            zone_color = GOLD;
        } else if (display_points >= 100 * row->value_multiplier) {
            zone_color = GREEN;
        } else if (display_points >= 50 * row->value_multiplier) {
            zone_color = BLUE;
        } else {
            zone_color = GRAY;
        }

        // Brighten colors for multiplied gates
        if (row->value_multiplier > 1) {
            zone_color.r = (unsigned char)(zone_color.r + (255 - zone_color.r) * 0.3f);
            zone_color.g = (unsigned char)(zone_color.g + (255 - zone_color.g) * 0.3f);
            zone_color.b = (unsigned char)(zone_color.b + (255 - zone_color.b) * 0.3f);
        }

        DrawRectangle((int)zone->x_min, (int)zone->y_min,
                     (int)zone_width, (int)zone_height, zone_color);
        DrawRectangleLines((int)zone->x_min, (int)zone->y_min,
                          (int)zone_width, (int)zone_height, DARKGRAY);

        // Draw point value
        char text[16];
        sprintf(text, "%d", zone->points);
        int text_width = MeasureText(text, 20);
        float text_x = zone->x_min + zone_width / 2 - text_width / 2;
        float text_y = zone->y_min + zone_height / 2 - 10;
        DrawText(text, (int)text_x, (int)text_y, 20, WHITE);
    }

    // Render bumpers
    Color bumper_color = (Color){80, 140, 140, 255};
    Color bumper_outline = (Color){60, 100, 100, 255};

    // Top bumpers
    if (row->bumpers_top) {
        for (int i = 0; i < row->bumper_count; i++) {
            DrawCircle((int)row->bumpers_top[i].x, (int)row->bumpers_top[i].y,
                       row->bumpers_top[i].radius, bumper_color);
            DrawCircleLines((int)row->bumpers_top[i].x, (int)row->bumpers_top[i].y,
                           row->bumpers_top[i].radius, bumper_outline);
        }
    }

    // Bottom bumpers
    if (row->bumpers_bottom) {
        for (int i = 0; i < row->bumper_count; i++) {
            DrawCircle((int)row->bumpers_bottom[i].x, (int)row->bumpers_bottom[i].y,
                       row->bumpers_bottom[i].radius, bumper_color);
            DrawCircleLines((int)row->bumpers_bottom[i].x, (int)row->bumpers_bottom[i].y,
                           row->bumpers_bottom[i].radius, bumper_outline);
        }
    }
}
// }}}

// {{{ gate_row_check_ball_score
int gate_row_check_ball_score(GateRow* row, Ball* ball) {
    if (!row || !ball || !row->zones) return 0;
    if (!ball->active) return 0;

    // Check if ball center is within any zone of this row
    for (int i = 0; i < row->zone_count; i++) {
        ScoreZone* zone = &row->zones[i];

        if (ball->x >= zone->x_min && ball->x < zone->x_max &&
            ball->y >= zone->y_min && ball->y < zone->y_max) {
            // Ball is in this zone - return points (already includes multiplier)
            return zone->points;
        }
    }

    return 0;
}
// }}}

// {{{ stage_manager_check_ball_score
int stage_manager_check_ball_score(StageManager* manager, Ball* ball) {
    if (!manager || !ball) return 0;
    if (!ball->active) return 0;

    // Check each gate row for scoring
    for (int i = 0; i < manager->gate_row_count; i++) {
        int points = gate_row_check_ball_score(&manager->gate_rows[i], ball);
        if (points > 0) {
            return points;  // Return first gate row score
        }
    }

    return 0;
}
// }}}

// {{{ stage_manager_render_all
void stage_manager_render_all(StageManager* manager) {
    if (!manager) return;

    // Render player stages
    for (int i = 0; i < manager->player_stage_count; i++) {
        stage_render(&manager->player_stages[i]);
    }

    // Render all gate rows
    for (int i = 0; i < manager->gate_row_count; i++) {
        gate_row_render(&manager->gate_rows[i]);
    }

    // Render adversary stages
    for (int i = 0; i < manager->adversary_stage_count; i++) {
        stage_render(&manager->adversary_stages[i]);
    }
}
// }}}
