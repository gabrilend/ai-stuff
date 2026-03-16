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
void ball_manager_update(BallManager* manager, float dt);
```
Updates all balls in the manager using physics simulation. Reads from current buffer, writes to next buffer.

**Parameters:**
- `manager`: BallManager instance
- `dt`: Delta time in seconds

### ball_manager_render
```c
void ball_manager_render(BallManager* manager);
```
Renders all active balls in the manager as colored circles.

**Parameters:**
- `manager`: BallManager instance

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

### BallManager
```c
typedef struct BallManager {
    Ball* balls_current;  // Current frame state (read-only during update)
    Ball* balls_next;     // Next frame state (write during update)
    int capacity;         // Maximum number of balls
    int active_count;     // Number of currently active balls
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
