// src/004-world.h
// World state data structures and API for pachinko machine
// Defines pegs, score zones, and overall world state

#ifndef WORLD_H
#define WORLD_H

// Physics constants
#define PEG_RADIUS 12.0f
#define DEFAULT_PEG_ROWS 10
#define DEFAULT_PEG_COLS 8
#define DEFAULT_PEG_SPACING 60.0f

// {{{ typedef struct Peg
// Peg represents a single collision peg in the pachinko machine.
// Pegs are arranged in a staggered grid pattern.
typedef struct Peg {
    float x, y;        // Position in pixels
    float radius;      // Collision radius
} Peg;
// }}}

// {{{ typedef struct ScoreZone
// ScoreZone represents a scoring slot at the bottom of the board.
// Balls landing in a zone add points to the player's score.
typedef struct ScoreZone {
    float x_min;       // Left edge of zone
    float x_max;       // Right edge of zone
    int points;        // Point value for this zone
} ScoreZone;
// }}}

// {{{ typedef struct World
// World contains all state for the pachinko machine.
// This includes the peg grid, score zones, and current score.
typedef struct World {
    int width, height; // Screen dimensions
    Peg* pegs;         // Array of pegs
    int peg_count;     // Number of pegs
    ScoreZone* zones;  // Array of score zones
    int zone_count;    // Number of zones
    int score;         // Current player score
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

#endif // WORLD_H
