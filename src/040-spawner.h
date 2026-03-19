// src/040-spawner.h
// Unified spawner system for player and adversary ball spawning
// Uses functional style: pure functions for logic, effectful functions separated

#ifndef SPAWNER_H
#define SPAWNER_H

// Forward declarations
typedef struct BallManager BallManager;
typedef struct Ball Ball;
typedef struct World World;

// Maximum spawn credits (shared between player and adversary)
#define SPAWNER_MAX_CREDITS 3.0f

// Default spawn rate (balls per second)
#define SPAWNER_DEFAULT_RATE 1.7f

// {{{ typedef struct Spawner
// Spawner manages reticle position, credit accumulation, and ball spawning.
// Used by both player and adversary with different controller functions.
typedef struct Spawner {
    float x, y;              // Current reticle position
    float credits;           // Accumulated spawn credits (1.0 = can spawn)
    float rate;              // Credits per second (base rate)
    int owner;               // OWNER_PLAYER or OWNER_ADVERSARY
    float gravity_dir;       // +1.0 (down for player) or -1.0 (up for adversary)
    int spawn_count;         // Total spawns for progress bar color phase

    // Reticle colors (RGBA as bytes to avoid aliasing issues)
    unsigned char color_dim[4];
    unsigned char color_bright[4];

    // Track bounds for AI oscillation (used by adversary controller)
    float min_x, max_x;
    float direction;         // +1.0 (right) or -1.0 (left) for oscillation
    float move_speed;        // Pixels per second for oscillation
} Spawner;
// }}}

// {{{ typedef SpawnerController
// Controller function type - updates spawner position based on input or AI logic.
// Returns nothing; modifies spawner->x directly.
typedef void (*SpawnerController)(Spawner* spawner, void* data, float dt);
// }}}

// ============================================================================
// PURE FUNCTIONS (no side effects, same input = same output)
// ============================================================================

// {{{ spawner_accumulate
// Calculate new credits after dt seconds.
// Caps at max_credits to prevent burst spawning.
//
// Parameters:
//   current_credits: Current credit amount
//   rate: Credits per second
//   dt: Delta time in seconds
//   max_credits: Maximum allowed credits
//
// Returns:
//   New credit amount (capped at max_credits)
float spawner_accumulate(float current_credits, float rate, float dt, float max_credits);
// }}}

// {{{ spawner_is_blocked
// Check if spawn position is blocked by existing balls.
// Only checks balls matching the owner_filter to prevent same-team blocking.
//
// Parameters:
//   x, y: Spawn position to check
//   radius: Ball radius for collision check
//   balls: Array of balls to check against
//   count: Number of balls in array
//   owner_filter: Only check balls with this owner (-1 for all)
//
// Returns:
//   1 if blocked, 0 if clear
int spawner_is_blocked(float x, float y, float radius,
                       Ball* balls, int count, int owner_filter);
// }}}

// {{{ spawner_oscillate
// Calculate oscillating position for AI track movement.
// Bounces between min_x and max_x at given speed.
//
// Parameters:
//   current_x: Current X position
//   direction: Current direction (+1.0 right, -1.0 left)
//   speed: Movement speed in pixels per second
//   dt: Delta time in seconds
//   min_x: Left boundary
//   max_x: Right boundary
//   out_new_direction: Output parameter for new direction after bounce
//
// Returns:
//   New X position (clamped to bounds)
float spawner_oscillate(float current_x, float direction, float speed, float dt,
                        float min_x, float max_x, float* out_new_direction);
// }}}

// ============================================================================
// EFFECTFUL FUNCTIONS (modify state, clearly separated from pure functions)
// ============================================================================

// {{{ spawner_create
// Creates and initializes a spawner with given parameters.
//
// Parameters:
//   x, y: Initial reticle position
//   rate: Spawn rate (credits per second)
//   owner: OWNER_PLAYER or OWNER_ADVERSARY
//   gravity_dir: +1.0 (down) or -1.0 (up)
//
// Returns:
//   Initialized Spawner struct
Spawner spawner_create(float x, float y, float rate, int owner, float gravity_dir);
// }}}

// {{{ spawner_set_colors
// Sets reticle colors for the spawner.
//
// Parameters:
//   spawner: Spawner to modify
//   dim_r, dim_g, dim_b, dim_a: Dim color RGBA
//   bright_r, bright_g, bright_b, bright_a: Bright color RGBA
void spawner_set_colors(Spawner* spawner,
                        unsigned char dim_r, unsigned char dim_g,
                        unsigned char dim_b, unsigned char dim_a,
                        unsigned char bright_r, unsigned char bright_g,
                        unsigned char bright_b, unsigned char bright_a);
// }}}

// {{{ spawner_set_bounds
// Sets track bounds for AI oscillation.
//
// Parameters:
//   spawner: Spawner to modify
//   min_x: Left boundary
//   max_x: Right boundary
//   move_speed: Oscillation speed in pixels per second
void spawner_set_bounds(Spawner* spawner, float min_x, float max_x, float move_speed);
// }}}

// {{{ spawner_update
// Updates spawner state: accumulates credits and moves position via controller.
//
// Parameters:
//   spawner: Spawner instance
//   controller: Controller function (NULL for no movement)
//   controller_data: Data passed to controller function
//   dt: Delta time in seconds
void spawner_update(Spawner* spawner, SpawnerController controller,
                    void* controller_data, float dt);
// }}}

// {{{ spawner_try_spawn
// Attempts to spawn a ball if credits available and position clear.
// Consumes 1.0 credit on successful spawn.
//
// Parameters:
//   spawner: Spawner instance
//   manager: BallManager for spawning
//   ball_radius: Radius of ball to spawn
//
// Returns:
//   1 if spawned successfully, 0 if blocked or no credits
int spawner_try_spawn(Spawner* spawner, BallManager* manager, float ball_radius);
// }}}

// {{{ spawner_render
// Renders the spawner reticle with cooldown indicator.
// Uses spawn_count for color phase continuity.
//
// Parameters:
//   spawner: Spawner instance
void spawner_render(Spawner* spawner);
// }}}

// {{{ spawner_reset
// Resets spawner position to center of bounds and clears credits.
//
// Parameters:
//   spawner: Spawner instance
//   center_x: New X position
//   y: New Y position
void spawner_reset(Spawner* spawner, float center_x, float y);
// }}}

// ============================================================================
// CONTROLLER FUNCTIONS
// ============================================================================

// {{{ controller_ai_track
// AI controller that oscillates spawner position between bounds.
// Uses spawner's min_x, max_x, direction, and move_speed.
//
// Parameters:
//   spawner: Spawner to control
//   data: Unused (NULL)
//   dt: Delta time in seconds
void controller_ai_track(Spawner* spawner, void* data, float dt);
// }}}

#endif // SPAWNER_H
