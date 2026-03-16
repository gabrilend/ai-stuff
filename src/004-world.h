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

#endif // WORLD_H
