// src/012-adversary.h
// Adversary AI system for spawning and controlling enemy balls
// The adversary has a mirrored board below the player with reversed gravity
// Refactored to use unified Spawner system (issue 1309)

#ifndef ADVERSARY_H
#define ADVERSARY_H

#include "040-spawner.h"

// Forward declarations
typedef struct World World;
typedef struct BallManager BallManager;

// Adversary AI constants
#define ADVERSARY_MOVE_SPEED 120.0f   // Pixels per second for reticle
#define ADVERSARY_SPAWN_Y_OFFSET 40.0f // Distance below adversary_table_bottom (matches player's 100px gap from pegs)

// {{{ typedef struct Adversary
// Adversary holds the AI state for the enemy spawner.
// Uses unified Spawner for spawn mechanics (issue 1309).
// AI controller oscillates reticle back and forth.
typedef struct Adversary {
    Spawner spawner;  // Unified spawner handles credits, position, rendering
} Adversary;
// }}}

// {{{ adversary_create
// Creates and initializes an adversary AI.
// Returns NULL on allocation failure.
//
// Parameters:
//   world: World to get table bounds from
//
// Returns:
//   Adversary pointer on success, NULL on failure
Adversary* adversary_create(World* world);
// }}}

// {{{ adversary_destroy
// Destroys an adversary and frees resources.
//
// Parameters:
//   adversary: Adversary instance to destroy
void adversary_destroy(Adversary* adversary);
// }}}

// {{{ adversary_update
// Updates adversary AI state each frame.
// Moves reticle, accumulates spawn credits, attempts spawning.
//
// Parameters:
//   adversary: Adversary instance
//   world: World for bounds checking
//   ball_manager: BallManager for spawning balls
//   dt: Delta time in seconds
void adversary_update(Adversary* adversary, World* world,
                      BallManager* ball_manager, float dt);
// }}}

// {{{ adversary_render
// Renders the adversary spawn reticle and cooldown indicator.
//
// Parameters:
//   adversary: Adversary instance
void adversary_render(Adversary* adversary);
// }}}

// {{{ adversary_reset
// Resets adversary spawn position to center.
//
// Parameters:
//   adversary: Adversary instance
//   world: World for bounds
void adversary_reset(Adversary* adversary, World* world);
// }}}

#endif // ADVERSARY_H
