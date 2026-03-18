// src/004-world.h
// World state data structures and API for pachinko machine
// Defines pegs, score zones, and overall world state

#ifndef WORLD_H
#define WORLD_H

#include "raylib.h"

// Forward declaration for stage system (defined in 014-stage.h)
typedef struct StageManager StageManager;

// Forward declaration for portal system (defined in 028-portal.h)
typedef struct PortalManager PortalManager;

// Forward declaration for ramp (defined in 016-ramp.h)
typedef struct Ramp Ramp;

// Forward declaration for wrap zones (defined in 036-wrap-zones.h)
typedef struct WrapZones WrapZones;

// Physics constants
#define PEG_RADIUS 12.0f
#define DEFAULT_PEG_ROWS 10
#define DEFAULT_PEG_COLS 8
#define DEFAULT_PEG_SPACING 60.0f

// Default peg physics (pre-RGB system values)
#define DEFAULT_PEG_RESTITUTION 0.7f
#define DEFAULT_PEG_FRICTION 0.2f

// {{{ typedef struct Peg
// Peg represents a single collision peg in the pachinko machine.
// RGB properties control physics behavior and visual color.
typedef struct Peg {
    float x, y;           // Position in pixels
    float radius;         // Collision radius

    // Physics properties (RGB encoded)
    float restitution;    // Bounciness (0.0-1.0)
    float friction;       // Surface grip (0.0-1.0)
    int point_bonus;      // Points awarded on hit

    // Visual color (derived from properties)
    Color color;
} Peg;
// }}}

// {{{ typedef struct ScoreZone
// ScoreZone represents a scoring slot on the board.
// Balls entering a zone's bounds add points to the player's score.
// Zones can be placed anywhere, allowing for multiple gate rows.
typedef struct ScoreZone {
    float x_min;       // Left edge of zone
    float x_max;       // Right edge of zone
    float y_min;       // Top edge of zone
    float y_max;       // Bottom edge of zone
    int points;        // Point value for this zone
} ScoreZone;
// }}}

// {{{ typedef struct Bumper
// Bumper represents a low-restitution collision point at gate dividers.
// Bumpers cause balls to "donk" softly and slide into gates rather than
// bouncing chaotically. Placed at the top of each gate divider.
typedef struct Bumper {
    float x, y;        // Position in pixels (center of bumper)
    float radius;      // Collision radius
} Bumper;
// }}}

// {{{ typedef struct World
// World contains all state for the pachinko machine.
// This includes the peg grid, score zones, and current score.
// Table bounds define the playable area (may be smaller than screen).
// With adversary mode, there are two boards sharing the same gates.
typedef struct World {
    int width, height;     // Screen/window dimensions

    // Player board (top)
    Peg* pegs;             // Array of player pegs
    int peg_count;         // Number of player pegs
    Ramp* ramps;           // Array of player ramps (from JSON lines)
    int ramp_count;        // Number of player ramps
    ScoreZone* zones;      // Array of score zones (shared)
    int zone_count;        // Number of zones
    Bumper* bumpers;       // Array of gate bumpers (top of zones)
    int bumper_count;      // Number of bumpers (top)
    int score;             // Current player score
    int high_score;        // Session high score

    // Adversary board (bottom, mirrored)
    Peg* adversary_pegs;           // Array of adversary pegs
    int adversary_peg_count;       // Number of adversary pegs
    Ramp* adversary_ramps;         // Array of adversary ramps (from JSON lines)
    int adversary_ramp_count;      // Number of adversary ramps
    Bumper* adversary_bumpers;     // Array of gate bumpers (bottom of zones)
    int adversary_bumper_count;    // Number of bumpers (bottom)

    // Table bounds - the actual playable area
    // Table is centered horizontally when window is wider than table
    float table_x;         // Left edge of table (for centering)
    float table_width;     // Width of table (fixed, e.g., 800px)
    float table_top;       // Top of player table (where player pegs start)
    float table_bottom;    // Bottom of player table / top of zones

    // Adversary bounds (below zones)
    float adversary_table_top;     // Top of adversary table (bottom of zones)
    float adversary_table_bottom;  // Bottom of adversary table (where adversary pegs end)

    // Stage expansion system (NULL until first stage upgrade purchased)
    // When active, stages manages additional board sections and gate rows
    StageManager* stages;

    // Portal system (NULL if no portals defined)
    PortalManager* portals;

    // Wrap zones for ball teleportation at screen edges (NULL until created)
    WrapZones* wrap_zones;

    // Expansion tracking for dynamic world growth
    float total_height;        // Current total world height (updated on expansion)
    float expansion_offset;    // Accumulated vertical shift from expansions
} World;
// }}}

// {{{ world_create
// Creates and initializes a new world with the given dimensions.
// Returns NULL on allocation failure.
//
// Parameters:
//   width: Screen width in pixels
//   height: Screen height in pixels
//
// Returns:
//   World pointer on success, NULL on failure
World* world_create(int width, int height);
// }}}

// {{{ world_destroy
// Destroys a world and frees all associated resources.
//
// Parameters:
//   world: World instance to destroy
void world_destroy(World* world);
// }}}

// {{{ world_generate_pegs
// Generates a staggered peg grid in the world.
// Frees any existing pegs before allocating new ones.
//
// Parameters:
//   world: World instance
//   rows: Number of peg rows
//   cols: Number of pegs per row
//   start_x: Starting x position for grid
//   start_y: Starting y position for grid
//   spacing: Distance between pegs in pixels
void world_generate_pegs(World* world, int rows, int cols,
                         float start_x, float start_y, float spacing);
// }}}

// {{{ world_render_pegs
// Renders all pegs in the world as light gray circles.
//
// Parameters:
//   world: World instance
void world_render_pegs(World* world);
// }}}

// {{{ world_generate_zones
// Generates score zones at the bottom of the world.
// Frees any existing zones before allocating new ones.
//
// Parameters:
//   world: World instance
//   zone_count: Number of score zones to create
//   zone_height: Height of each zone in pixels
void world_generate_zones(World* world, int zone_count, float zone_height);
// }}}

// {{{ world_render_zones
// Renders all score zones with colored backgrounds and point values.
//
// Parameters:
//   world: World instance
void world_render_zones(World* world);
// }}}

// {{{ world_set_table_bounds
// Sets the table bounds for centering and collision.
// Call after generating pegs and zones to update bounds.
//
// Parameters:
//   world: World instance
//   table_width: Fixed width of table (typically 800px)
//   table_top: Y position of top of table (peg start)
//   zone_height: Height of zones at bottom
void world_set_table_bounds(World* world, float table_width,
                            float table_top, float zone_height);
// }}}

// {{{ world_render_rails
// Renders guard rails on the sides of the table.
// Rails prevent balls from falling off the table edges.
//
// Parameters:
//   world: World instance
void world_render_rails(World* world);
// }}}

// {{{ world_generate_bumpers
// Generates gate bumpers at the top of each zone divider.
// Bumpers are low-restitution collision points that cause balls
// to donk softly and slide into gates.
// Call after world_generate_zones() to ensure zone bounds are set.
//
// Parameters:
//   world: World instance
void world_generate_bumpers(World* world);
// }}}

// {{{ world_render_bumpers
// Renders all gate bumpers with distinct visual style.
// Bumpers appear as soft, cushion-like caps on zone dividers.
//
// Parameters:
//   world: World instance
void world_render_bumpers(World* world);
// }}}

// {{{ world_generate_adversary_pegs
// Generates adversary peg grid below the zones (mirrored from player).
// Call after world_set_table_bounds() and world_generate_zones().
//
// Parameters:
//   world: World instance
//   rows: Number of peg rows
//   cols: Number of pegs per row
//   spacing: Distance between pegs in pixels
void world_generate_adversary_pegs(World* world, int rows, int cols, float spacing);
// }}}

// {{{ world_render_adversary_pegs
// Renders all adversary pegs with distinct visual style.
// Adversary pegs are dimmer/redder than player pegs.
//
// Parameters:
//   world: World instance
void world_render_adversary_pegs(World* world);
// }}}

// {{{ world_generate_adversary_bumpers
// Generates gate bumpers at the bottom of each zone divider.
// These are the adversary-side bumpers (mirrored from player).
//
// Parameters:
//   world: World instance
void world_generate_adversary_bumpers(World* world);
// }}}

// {{{ world_render_adversary_bumpers
// Renders all adversary gate bumpers.
//
// Parameters:
//   world: World instance
void world_render_adversary_bumpers(World* world);
// }}}

// {{{ world_render_ramps
// Renders all player ramps from JSON board.
//
// Parameters:
//   world: World instance
void world_render_ramps(World* world);
// }}}

// {{{ world_render_adversary_ramps
// Renders all adversary ramps from JSON board.
//
// Parameters:
//   world: World instance
void world_render_adversary_ramps(World* world);
// }}}

// =============================================================================
// World expansion functions (for dynamic stage system)
// =============================================================================

// {{{ world_expand_for_stages
// Expands the world vertically to accommodate new stages.
// Shifts adversary content downward to make room.
//
// Parameters:
//   world: World instance
//   player_stage_height: Height of new player stage
//   adversary_stage_height: Height of new adversary stage
//   gate_height: Height of each new gate row
void world_expand_for_stages(World* world, float player_stage_height,
                             float adversary_stage_height, float gate_height);
// }}}

// {{{ world_shift_adversary_content
// Shifts all adversary content (pegs, bumpers, bounds) by the given offset.
// Used during world expansion to make room for new stages.
//
// Parameters:
//   world: World instance
//   offset: Vertical offset to shift (positive = downward)
void world_shift_adversary_content(World* world, float offset);
// }}}

// {{{ world_shift_zones
// Shifts the shared gate zones by the given offset.
// Used during world expansion.
//
// Parameters:
//   world: World instance
//   offset: Vertical offset to shift (positive = downward)
void world_shift_zones(World* world, float offset);
// }}}

#endif // WORLD_H
