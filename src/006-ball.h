// src/006-ball.h
// Ball state structures and ball manager for pachinko simulation
// Implements double-buffering for physics updates

#ifndef BALL_H
#define BALL_H

// Forward declarations
typedef struct World World;
typedef struct ThreadPool ThreadPool;

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
// Note: Zone position is now calculated from world->height in ball_check_zone()

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
    int capacity;          // Total ball capacity (for ball-ball collisions)
    int score_delta;       // Points scored during this task (0 if none)
    int scored;            // 1 if ball scored this frame, 0 otherwise
    float score_pos_x;     // X position where ball scored (if scored)
    float score_pos_y;     // Y position where ball scored (if scored)
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

// {{{ ball_manager_spawn_blocked
// Checks if the spawn area is blocked by any active balls.
// Returns 1 if any ball is within the spawn area, preventing spawning.
// Uses a safety margin (3x ball radius) to prevent physics issues.
//
// Parameters:
//   manager: BallManager instance
//   spawn_x: Spawn point X coordinate
//   spawn_y: Spawn point Y coordinate
//
// Returns:
//   1 if spawn blocked, 0 if area is clear
int ball_manager_spawn_blocked(BallManager* manager, float spawn_x, float spawn_y);
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

// {{{ ball_manager_submit_tasks
// Submits all active ball updates to threadpool.
// Call prepare_tasks() first to set up task data.
// Iterates through all balls and submits tasks for active ones.
//
// Parameters:
//   manager: BallManager instance
//   pool: ThreadPool to submit tasks to
void ball_manager_submit_tasks(BallManager* manager, ThreadPool* pool);
// }}}

// {{{ ball_manager_finalize_update
// Finalizes ball states after threadpool_wait_all() completes.
// Counts active balls in write buffer and updates active_count.
// Call after wait_all() and before swap_buffers().
//
// Parameters:
//   manager: BallManager instance
void ball_manager_finalize_update(BallManager* manager);
// }}}

// {{{ ball_manager_collect_scores
// Collects score deltas from all tasks after parallel phase.
// Call after threadpool_wait_all() and before finalize_update().
// Returns total points scored this frame.
//
// Parameters:
//   manager: BallManager instance
//
// Returns:
//   Total points scored this frame
int ball_manager_collect_scores(BallManager* manager);
// }}}

// {{{ ball_update_task
// Task function for parallel ball update.
// Receives BallTaskData* as void* data parameter.
// Performs physics integration, collision detection, and bounds checking
// for a single ball. Thread-safe: only writes to its own ball index.
//
// Parameters:
//   data: BallTaskData pointer (cast from void*)
void ball_update_task(void* data);
// }}}

// {{{ ball_check_zone
// Checks if a ball has entered a score zone.
// Returns zone index (0 to zone_count-1) if captured, -1 otherwise.
// Uses ball center point for detection.
//
// Parameters:
//   ball: Ball to check
//   world: World containing score zones
//
// Returns:
//   Zone index if captured, -1 if not in any zone
int ball_check_zone(Ball* ball, World* world);
// }}}

#endif // BALL_H
