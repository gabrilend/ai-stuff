// src/014-stage.h
// Stage system for dynamic board expansion
// Allows multiple stages per player/adversary with different obstacle types

#ifndef STAGE_H
#define STAGE_H

#include "004-world.h"
#include "016-ramp.h"

// Stage 2 constants
#define STAGE_2_HEIGHT 200.0f
#define STAGE_2_RAMP_COUNT 8
#define STAGE_2_RAMP_WIDTH 120.0f
#define STAGE_2_RAMP_HEIGHT 40.0f

// {{{ StageType enum
// Defines the type of obstacles in a stage
typedef enum StageType {
    STAGE_TYPE_PEGS,    // Standard peg grid (stage 1)
    STAGE_TYPE_RAMPS,   // Horizontal ramps (stage 2)
    STAGE_TYPE_CUSTOM,  // Custom stage loaded from JSON
    STAGE_TYPE_COUNT
} StageType;
// }}}

// {{{ typedef struct Stage
// Stage represents a discrete section of the board with its own obstacles.
// Each stage has a type determining what obstacles it contains.
// Stages are stacked vertically and separated by gate rows.
typedef struct Stage {
    StageType type;
    float y_top;           // Top of this stage
    float y_bottom;        // Bottom of this stage
    float height;          // Stage height in pixels
    float table_x;         // Left edge of stage (same as world table_x)
    float table_width;     // Width of stage (same as world table_width)

    // Stage-specific obstacles (only one type populated per stage)
    Peg* pegs;             // Pegs (if STAGE_TYPE_PEGS)
    int peg_count;

    Ramp* ramps;           // Ramps (if STAGE_TYPE_RAMPS)
    int ramp_count;
} Stage;
// }}}

// {{{ typedef struct GateRow
// GateRow represents a row of scoring gates between stages.
// Each gate row has its own value multiplier.
typedef struct GateRow {
    float y_top;           // Top edge of gate row
    float y_bottom;        // Bottom edge of gate row
    float height;          // Gate row height

    ScoreZone* zones;      // Score zones for this row
    int zone_count;

    Bumper* bumpers_top;   // Bumpers on top edge (for balls falling down)
    Bumper* bumpers_bottom;// Bumpers on bottom edge (for balls rising up)
    int bumper_count;

    int value_multiplier;  // 1, 2, 3, etc. applied to base point values
} GateRow;
// }}}

// {{{ typedef struct StageManager
// StageManager tracks all stages and gate rows for both player and adversary.
// Created when first stage expansion is purchased.
typedef struct StageManager {
    // Player stages (grow downward from original board)
    Stage* player_stages;
    int player_stage_count;
    int player_stage_capacity;

    // Adversary stages (grow upward, visually below player stages)
    Stage* adversary_stages;
    int adversary_stage_count;
    int adversary_stage_capacity;

    // Gate rows (between stages)
    GateRow* gate_rows;
    int gate_row_count;
    int gate_row_capacity;

    // Table dimensions (copied from world for convenience)
    float table_x;
    float table_width;
} StageManager;
// }}}

// =============================================================================
// StageManager functions
// =============================================================================

// {{{ stage_manager_create
// Creates an empty stage manager ready to receive stages.
// Returns NULL on allocation failure.
StageManager* stage_manager_create(float table_x, float table_width);
// }}}

// {{{ stage_manager_destroy
// Destroys a stage manager and all contained stages/gates.
void stage_manager_destroy(StageManager* manager);
// }}}

// {{{ stage_manager_add_player_stage
// Adds a new stage below the player's existing stages.
// Returns the new stage index, or -1 on failure.
int stage_manager_add_player_stage(StageManager* manager, StageType type,
                                   float height);
// }}}

// {{{ stage_manager_add_adversary_stage
// Adds a new stage above the adversary's existing stages.
// Returns the new stage index, or -1 on failure.
int stage_manager_add_adversary_stage(StageManager* manager, StageType type,
                                      float height);
// }}}

// {{{ stage_manager_add_gate_row
// Adds a gate row at the specified y position.
// Returns the new gate row index, or -1 on failure.
int stage_manager_add_gate_row(StageManager* manager, float y_top,
                               float height, int zone_count, int multiplier);
// }}}

// {{{ stage_manager_get_total_height
// Returns the total height of all stages and gate rows.
float stage_manager_get_total_height(StageManager* manager);
// }}}

// =============================================================================
// Stage functions
// =============================================================================

// {{{ stage_init
// Initializes a stage with the given type and bounds.
void stage_init(Stage* stage, StageType type, float y_top, float height,
                float table_x, float table_width);
// }}}

// {{{ stage_cleanup
// Frees resources owned by a stage (pegs, ramps arrays).
void stage_cleanup(Stage* stage);
// }}}

// {{{ stage_generate_pegs
// Generates a staggered peg grid for a STAGE_TYPE_PEGS stage.
void stage_generate_pegs(Stage* stage, int rows, int cols, float spacing);
// }}}

// {{{ stage_render
// Renders a stage's obstacles (pegs or ramps).
void stage_render(Stage* stage);
// }}}

// {{{ stage_generate_ramps_stage2
// Generates the ramp layout for stage 2 (player version).
// Creates a converging pattern that funnels balls toward center.
void stage_generate_ramps_stage2(Stage* stage);
// }}}

// {{{ stage_generate_ramps_stage2_mirrored
// Generates the ramp layout for stage 2 (adversary version).
// Same layout as player but mirrored for upward ball travel.
void stage_generate_ramps_stage2_mirrored(Stage* stage);
// }}}

// =============================================================================
// GateRow functions
// =============================================================================

// {{{ gate_row_init
// Initializes a gate row with zones and bumpers.
void gate_row_init(GateRow* row, float y_top, float height,
                   float table_x, float table_width,
                   int zone_count, int multiplier);
// }}}

// {{{ gate_row_cleanup
// Frees resources owned by a gate row.
void gate_row_cleanup(GateRow* row);
// }}}

// {{{ gate_row_render
// Renders a gate row (zones and bumpers).
void gate_row_render(GateRow* row);
// }}}

// Forward declaration for Ball (defined in 006-ball.h)
typedef struct Ball Ball;

// {{{ gate_row_check_ball_score
// Checks if a ball is within a gate row's scoring zone.
// Returns the zone's point value if ball is in a zone, 0 otherwise.
//
// Parameters:
//   row: GateRow to check
//   ball: Ball to check
//
// Returns:
//   Point value if ball is in a zone (includes multiplier), 0 otherwise
int gate_row_check_ball_score(GateRow* row, Ball* ball);
// }}}

// {{{ stage_manager_check_ball_score
// Checks if a ball scores through any gate row managed by the stage manager.
// Returns the total points scored (from first gate row hit).
//
// Parameters:
//   manager: StageManager containing gate rows
//   ball: Ball to check
//
// Returns:
//   Point value if ball is in any gate zone, 0 otherwise
int stage_manager_check_ball_score(StageManager* manager, Ball* ball);
// }}}

// {{{ stage_manager_render_all
// Renders all stages and gate rows managed by the stage manager.
void stage_manager_render_all(StageManager* manager);
// }}}

#endif // STAGE_H
