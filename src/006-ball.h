// src/006-ball.h
// Ball state structures and ball manager for pachinko simulation
// Implements double-buffering for physics updates

#ifndef BALL_H
#define BALL_H

// Forward declaration for World struct
typedef struct World World;

// Ball constants
#define BALL_RADIUS 8.0f
#define MAX_BALLS 256

// Physics constants
#define GRAVITY 980.0f        // Pixels per second squared
#define DAMPING 0.98f         // Velocity damping factor
#define MIN_VELOCITY 1.0f     // Threshold for stopping

// Collision constants
#define RESTITUTION 0.7f      // Bounce energy retention (0-1)
#define COLLISION_BIAS 0.1f   // Separation push to prevent sticking

// Boundary constants
#define WALL_RESTITUTION 0.6f // Wall bounce retention
#define ZONE_TOP_Y 560.0f     // Top of score zone area

// Spawning constants
#define SPAWN_X 400.0f        // Default spawn x (center)
#define SPAWN_Y 50.0f         // Default spawn y (top)
#define SPAWN_VX_RANGE 100.0f // Random horizontal range
#define SPAWN_VY_INITIAL 50.0f // Initial downward velocity
#define SPAWN_COOLDOWN 0.1f   // Minimum time between spawns (seconds)

// {{{ typedef struct Ball
// Ball represents a single ball in the pachinko machine.
// Uses double-buffering: read from current, write to next.
typedef struct Ball {
    float x, y;        // Position in pixels
    float vx, vy;      // Velocity in pixels per second
    float radius;      // Collision and render radius
    int active;        // 1 if in play, 0 if inactive
} Ball;
// }}}

// {{{ typedef struct BallTaskData
// BallTaskData encapsulates all information needed for a worker thread
// to process a single ball update. Pre-allocated at startup to avoid
// malloc during gameplay.
typedef struct BallTaskData {
    int ball_index;        // Index into ball arrays (immutable)
    Ball* read_buffer;     // Current state (read-only)
    Ball* write_buffer;    // Next state (write target)
    World* world;          // World for collision detection
    float dt;              // Delta time in seconds
} BallTaskData;
// }}}

// {{{ typedef struct BallManager
// BallManager holds and manages a collection of balls.
// Maintains two buffers for double-buffered physics updates.
typedef struct BallManager {
    Ball* balls_current;     // Current frame state (read-only during update)
    Ball* balls_next;        // Next frame state (write during update)
    int capacity;            // Maximum number of balls
    int active_count;        // Number of currently active balls
    float spawn_cooldown;    // Time until next spawn allowed
    BallTaskData* task_data; // Pre-allocated task data for parallel processing
} BallManager;
// }}}

// {{{ ball_manager_create
// Creates and initializes a ball manager with the given capacity.
// Allocates both current and next ball buffers.
// Returns NULL on allocation failure.
//
// Parameters:
//   capacity: Maximum number of balls to manage
//
// Returns:
//   BallManager pointer on success, NULL on failure
BallManager* ball_manager_create(int capacity);
// }}}

// {{{ ball_manager_destroy
// Destroys a ball manager and frees all associated resources.
//
// Parameters:
//   manager: BallManager instance to destroy
void ball_manager_destroy(BallManager* manager);
// }}}

// {{{ ball_manager_spawn
// Spawns a new ball at the given position.
// Finds an inactive slot and activates it.
// Returns 0 if no slots available.
//
// Parameters:
//   manager: BallManager instance
//   x: Starting x position in pixels
//   y: Starting y position in pixels
//
// Returns:
//   1 on success, 0 if capacity reached
int ball_manager_spawn(BallManager* manager, float x, float y);
// }}}

// {{{ ball_manager_swap_buffers
// Swaps the current and next ball buffers.
// Call at end of frame after all updates complete.
//
// Parameters:
//   manager: BallManager instance
void ball_manager_swap_buffers(BallManager* manager);
// }}}

// {{{ ball_manager_deactivate
// Marks a ball as inactive, allowing the slot to be reused.
//
// Parameters:
//   manager: BallManager instance
//   index: Ball index to deactivate
void ball_manager_deactivate(BallManager* manager, int index);
// }}}

// {{{ ball_manager_update
// Updates all balls in the manager using physics simulation.
// Reads from current buffer, writes to next buffer.
// Performs collision detection with pegs in the world.
// Must call swap_buffers after to apply updates.
//
// Parameters:
//   manager: BallManager instance
//   world: World containing pegs for collision detection
//   dt: Delta time in seconds
void ball_manager_update(BallManager* manager, World* world, float dt);
// }}}

// {{{ ball_manager_render
// Renders all active balls in the manager.
// Draws each active ball as a colored circle.
//
// Parameters:
//   manager: BallManager instance
void ball_manager_render(BallManager* manager);
// }}}

// {{{ ball_manager_update_cooldown
// Updates the spawn cooldown timer.
// Decrements cooldown by delta time.
//
// Parameters:
//   manager: BallManager instance
//   dt: Delta time in seconds
void ball_manager_update_cooldown(BallManager* manager, float dt);
// }}}

// {{{ ball_manager_can_spawn
// Checks if the manager can spawn a new ball.
// Returns 1 if cooldown expired and capacity not reached.
//
// Parameters:
//   manager: BallManager instance
//
// Returns:
//   1 if can spawn, 0 otherwise
int ball_manager_can_spawn(BallManager* manager);
// }}}

// {{{ ball_manager_reset_cooldown
// Resets the spawn cooldown to the default value.
//
// Parameters:
//   manager: BallManager instance
void ball_manager_reset_cooldown(BallManager* manager);
// }}}

// {{{ ball_manager_prepare_tasks
// Prepares task data for parallel ball updates.
// Sets up read_buffer, write_buffer, world, and dt for all task entries.
// Call once per frame before submitting tasks to threadpool.
//
// Parameters:
//   manager: BallManager instance
//   world: World containing pegs for collision detection
//   dt: Delta time in seconds
void ball_manager_prepare_tasks(BallManager* manager, World* world, float dt);
// }}}

#endif // BALL_H
