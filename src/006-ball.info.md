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
} BallTaskData;
```

Encapsulates all information needed for a worker thread to process a single ball update. Pre-allocated at startup to avoid malloc during gameplay.

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
