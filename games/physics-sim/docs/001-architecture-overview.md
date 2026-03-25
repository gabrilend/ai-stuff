# 001 - Architecture Overview

## High-Level Structure

The physics simulator is a pachinko game with two-player competitive
gameplay. It consists of two separate applications:

- **physics-sim**: The game binary
- **board-editor**: Standalone board creation tool

Both share common data formats (JSON boards, grid system).

## System Components

### 1. Main Thread (Raylib Loop)
The main thread owns the raylib context and handles:
- Window creation and management
- Input polling (ball launching, upgrades, reticle control)
- Frame rendering (world, particles, UI)
- Task submission to threadpool
- Expansion animation sequencing

### 2. Threadpool
A fixed-size pool of worker threads that process physics tasks:
- Workers pull tasks from a shared queue
- Each task updates one ball or particle's physics state
- Results are written to next buffer, then synchronized

### 3. Task System
Each task consists of:
```c
struct Task {
    void (*func)(void* data);  // Function pointer to execute
    void* data;                 // Pointer to task-specific data
    size_t data_size;          // Size of associated data region
};
```

### 4. Ball State
```c
struct Ball {
    float x, y;           // Position
    float vx, vy;         // Velocity
    float radius;         // Collision radius (upgradeable)
    int active;           // Is ball in play
    int owner;            // OWNER_PLAYER or OWNER_ADVERSARY
    int health;           // Damage-based lifetime
    uint32_t color;       // Render color
};
```

### 5. World State
```c
struct World {
    struct Peg* pegs;           // Array of pegs
    int peg_count;
    struct Ball* balls_current; // Double-buffered ball arrays
    struct Ball* balls_next;
    int ball_count;
    float gravity;
    struct StageManager* stages; // Dynamic stage expansion
    struct Bumper* bumpers;      // Gate bumpers
    struct WrapZoneManager* wrap_zones; // Screen wrap regions
};
```

### 6. Particle System
Double-buffered particle arrays for parallel updates:
- Simple particles (gravity-affected debris)
- Ripple particles (expanding rings)
- Fragment particles (collision-detecting shrapnel)

### 7. Stage System
Purchasable board extensions:
- Each stage contains obstacles (pegs or ramps)
- Gate rows separate stages with score multipliers
- Expansion animation handles smooth transitions

### 8. Adversary System
AI-controlled opponent on mirrored board:
- Oscillating reticle movement
- Auto-spawn with configurable rate
- Shared gates allow cross-board ball passage

## Data Flow Per Frame

1. **Input Phase**: Check ball launch, reticle, upgrade input
2. **Animation Phase**: Update expansion animation if active
3. **Submit Phase**: Submit ball update tasks to threadpool
4. **Ball Physics**: Workers execute collision detection
5. **Sync Phase**: Wait for ball tasks, swap buffers
6. **Spawn Particles**: Generate particles from collision results
7. **Particle Physics**: Submit and execute particle tasks
8. **Render Phase**: Draw world, balls, particles, UI

## Thread Safety Strategy

- Ball state is double-buffered: read from current, write to next
- Particle state is double-buffered: same pattern
- At frame boundary, buffers are swapped
- No locks needed during physics computation
- Single mutex protects task queue operations
- World obstacles (pegs, ramps, bumpers) are read-only during physics

## Memory Layout

```
+------------------------+
| World State (shared)   |
+------------------------+
| Ball Array (current)   |  <- Read by workers
+------------------------+
| Ball Array (next)      |  <- Written by workers
+------------------------+
| Particle Array (curr)  |  <- Read by workers
+------------------------+
| Particle Array (next)  |  <- Written by workers
+------------------------+
| Peg Array              |  <- Read-only after load
+------------------------+
| Ramp Array             |  <- Read-only after load
+------------------------+
| Bumper Array           |  <- Read-only after load
+------------------------+
| Stage Manager          |  <- Modified only during expansion
+------------------------+
| Task Queue             |  <- Mutex protected
+------------------------+
| Worker Thread Stacks   |  <- One per worker
+------------------------+
```

## File Organization

Source files are numbered for reading order:

| Range | Purpose |
|-------|---------|
| 001 | Main entry point |
| 002-003 | Threadpool |
| 004-007 | World and ball physics |
| 008-009 | Particle system |
| 010-011 | Upgrade system |
| 012-013 | Adversary AI |
| 014-019 | Stage system, ramps, animation |
| 020-029 | Board data, grid, editor core, portals |
| 030-037 | Editor application, rendering, wrap zones |
