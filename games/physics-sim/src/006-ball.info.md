# src/006-ball.h - Ball State API

Ball state structures and management for pachinko simulation.

## External Functions

### ball_manager_create
```c
BallManager* ball_manager_create(int capacity);
```
Creates and initializes a ball manager with the given capacity.

**Parameters:**
- `capacity`: Maximum number of balls to manage

**Returns:**
- BallManager pointer on success, NULL on allocation failure

### ball_manager_destroy
```c
void ball_manager_destroy(BallManager* manager);
```
Destroys a ball manager and frees all associated resources.

**Parameters:**
- `manager`: BallManager instance to destroy

### ball_manager_spawn
```c
int ball_manager_spawn(BallManager* manager, float x, float y);
```
Spawns a new ball at the given position. Finds an inactive slot and activates it.

**Parameters:**
- `manager`: BallManager instance
- `x`: Starting x position in pixels
- `y`: Starting y position in pixels

**Returns:**
- 1 on success, 0 if capacity reached

### ball_manager_swap_buffers
```c
void ball_manager_swap_buffers(BallManager* manager);
```
Swaps the current and next ball buffers. Call at end of frame after all updates complete.

**Parameters:**
- `manager`: BallManager instance

### ball_manager_deactivate
```c
void ball_manager_deactivate(BallManager* manager, int index);
```
Marks a ball as inactive, allowing the slot to be reused.

**Parameters:**
- `manager`: BallManager instance
- `index`: Ball index to deactivate

### ball_manager_update
```c
void ball_manager_update(BallManager* manager, World* world, float dt);
```
Updates all balls in the manager using physics simulation and collision detection. Reads from current buffer, writes to next buffer.

**Parameters:**
- `manager`: BallManager instance
- `world`: World containing pegs for collision detection
- `dt`: Delta time in seconds

### ball_manager_render
```c
void ball_manager_render(BallManager* manager);
```
Renders all active balls in the manager as colored circles.

**Parameters:**
- `manager`: BallManager instance

### ball_manager_update_cooldown
```c
void ball_manager_update_cooldown(BallManager* manager, float dt);
```
Updates the spawn cooldown timer by decrementing it by delta time.

**Parameters:**
- `manager`: BallManager instance
- `dt`: Delta time in seconds

### ball_manager_can_spawn
```c
int ball_manager_can_spawn(BallManager* manager);
```
Checks if the manager can spawn a new ball (cooldown expired and capacity not reached).

**Parameters:**
- `manager`: BallManager instance

**Returns:**
- 1 if can spawn, 0 otherwise

### ball_manager_reset_cooldown
```c
void ball_manager_reset_cooldown(BallManager* manager);
```
Resets the spawn cooldown to the default value (SPAWN_COOLDOWN).

**Parameters:**
- `manager`: BallManager instance

### ball_manager_prepare_tasks
```c
void ball_manager_prepare_tasks(BallManager* manager, World* world, float dt);
```
Prepares task data for parallel ball updates. Sets up buffer pointers, world reference, and delta time for all task data entries. Call once per frame before submitting tasks to threadpool.

**Parameters:**
- `manager`: BallManager instance
- `world`: World containing pegs for collision detection
- `dt`: Delta time in seconds

### ball_manager_submit_tasks
```c
void ball_manager_submit_tasks(BallManager* manager, ThreadPool* pool);
```
Submits all active ball updates to threadpool. Iterates through all balls and submits tasks for active ones. Call after prepare_tasks() and before threadpool_wait_all().

**Parameters:**
- `manager`: BallManager instance
- `pool`: ThreadPool to submit tasks to

**Usage Pattern:**
```c
ball_manager_prepare_tasks(manager, world, dt);
ball_manager_submit_tasks(manager, pool);
threadpool_wait_all(pool);
ball_manager_finalize_update(manager);
ball_manager_swap_buffers(manager);
```

### ball_manager_finalize_update
```c
void ball_manager_finalize_update(BallManager* manager);
```
Finalizes ball states after parallel updates complete. Counts active balls in write buffer and updates active_count. Call after threadpool_wait_all() and before swap_buffers().

**Parameters:**
- `manager`: BallManager instance

**Synchronization:**
- Must be called after threadpool_wait_all() returns
- Safe to read balls_next because all worker threads have finished
- Memory barriers from thread synchronization ensure visibility

### ball_manager_collect_scores
```c
int ball_manager_collect_scores(BallManager* manager);
```
Collects score deltas from all tasks after parallel phase. Sums points scored by all balls during the frame and resets score_delta fields for next frame.

**Parameters:**
- `manager`: BallManager instance

**Returns:**
- Total points scored this frame (0 if no balls scored)

**Usage:**
- Call after threadpool_wait_all() (ensures all tasks complete)
- Call before finalize_update()
- Add returned value to world score

**Thread Safety:**
- Each task writes only to its own score_delta
- Safe to read after threadpool_wait_all() synchronization
- Resets all score_delta values to 0

**Usage Pattern:**
```c
ball_manager_prepare_tasks(manager, world, dt);
ball_manager_submit_tasks(manager, pool);
threadpool_wait_all(pool);
int points = ball_manager_collect_scores(manager);
world->score += points;
ball_manager_finalize_update(manager);
ball_manager_swap_buffers(manager);
```

### ball_update_task
```c
void ball_update_task(void* data);
```
Task function for parallel ball update. Receives BallTaskData pointer and performs physics integration, collision detection, and bounds checking for a single ball. Thread-safe: only writes to its own ball index in write buffer.

**Parameters:**
- `data`: BallTaskData pointer (cast from void*)

**Thread Safety:**
- Reads from read_buffer (immutable during frame)
- Writes only to write_buffer[ball_index] (disjoint access)
- Reads from world (immutable during frame)

### ball_check_zone
```c
int ball_check_zone(Ball* ball, World* world);
```
Checks if a ball has entered a score zone at the bottom of the screen. Returns zone index if the ball's center point is below ZONE_TOP_Y and within a zone's x boundaries.

**Parameters:**
- `ball`: Ball to check
- `world`: World containing score zones

**Returns:**
- Zone index (0 to zone_count-1) if ball is in a zone
- -1 if ball is not in any zone (above threshold, between zones, or inactive)

**Detection Logic:**
- Checks if ball->y > ZONE_TOP_Y (560.0f)
- Uses ball center point for detection (not radius)
- Returns first matching zone index from left to right

**Thread Safety:**
- Read-only on both ball and world
- Safe to call from parallel tasks

## Data Structures

### Ball
```c
typedef struct Ball {
    float x, y;        // Position in pixels
    float vx, vy;      // Velocity in pixels per second
    float radius;      // Collision and render radius
    int active;        // 1 if in play, 0 if inactive
} Ball;
```

### BallTaskData
```c
typedef struct BallTaskData {
    int ball_index;        // Index into ball arrays (immutable)
    Ball* read_buffer;     // Current state (read-only)
    Ball* write_buffer;    // Next state (write target)
    World* world;          // World for collision detection
    float dt;              // Delta time in seconds
    int score_delta;       // Points scored during this task (0 if none)
    int scored;            // 1 if ball scored this frame, 0 otherwise
    float score_pos_x;     // X position where ball scored (if scored)
    float score_pos_y;     // Y position where ball scored (if scored)
} BallTaskData;
```

Encapsulates all information needed for a worker thread to process a single ball update. Pre-allocated at startup to avoid malloc during gameplay.

**Scoring Fields:**
- `score_delta`: Set to 0 at start of ball_update_task(), set to zone point value when ball enters a zone
- `scored`: Set to 1 when ball scores, 0 otherwise. Used by main loop to spawn particles
- `score_pos_x`, `score_pos_y`: Records ball position at moment of scoring for particle effects
- Thread-safe: each task writes only to its own fields

### BallManager
```c
typedef struct BallManager {
    Ball* balls_current;     // Current frame state (read-only during update)
    Ball* balls_next;        // Next frame state (write during update)
    int capacity;            // Maximum number of balls
    int active_count;        // Number of currently active balls
    float spawn_cooldown;    // Time until next spawn allowed
    BallTaskData* task_data; // Pre-allocated task data for parallel processing
} BallManager;
```

## Constants

### Ball Constants
- `BALL_RADIUS`: 8.0f - Default ball radius in pixels
- `MAX_BALLS`: 256 - Maximum number of balls supported

### Physics Constants
- `GRAVITY`: 980.0f - Downward acceleration in pixels per second squared
- `DAMPING`: 0.98f - Velocity damping factor (applied each frame)
- `MIN_VELOCITY`: 1.0f - Velocity threshold for stopping

### Collision Constants
- `RESTITUTION`: 0.7f - Bounce energy retention (0-1, 70% energy retained)
- `COLLISION_BIAS`: 0.1f - Small separation push to prevent sticking

### Boundary Constants
- `WALL_RESTITUTION`: 0.6f - Wall bounce energy retention (60%)
- `ZONE_TOP_Y`: 560.0f - Top of score zone area in pixels

### Spawning Constants
- `SPAWN_X`: 400.0f - Default spawn x position (screen center)
- `SPAWN_Y`: 50.0f - Default spawn y position (top of screen)
- `SPAWN_VX_RANGE`: 100.0f - Random horizontal velocity range
- `SPAWN_VY_INITIAL`: 50.0f - Initial downward velocity
- `SPAWN_COOLDOWN`: 0.1f - Minimum time between spawns in seconds
