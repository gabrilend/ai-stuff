# 001 - Architecture Overview

## System Components

### 1. Main Thread (Raylib Loop)
The main thread owns the raylib context and handles:
- Window creation and management
- Input polling (ball launching)
- Frame rendering
- Task submission to threadpool

### 2. Threadpool
A fixed-size pool of worker threads that process physics tasks:
- Workers pull tasks from a shared queue
- Each task updates one ball's physics state
- Results are written to thread-local storage, then synchronized

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
    float radius;         // Collision radius
    int active;           // Is ball in play
    uint32_t color;       // Render color
};
```

### 5. World State
```c
struct World {
    struct Peg* pegs;     // Array of pegs
    int peg_count;        // Number of pegs
    struct Ball* balls;   // Array of balls
    int ball_count;       // Number of active balls
    float gravity;        // Gravity constant
};
```

## Data Flow Per Frame

1. **Input Phase**: Main thread checks for ball launch input
2. **Submit Phase**: Main thread submits ball update tasks to pool
3. **Process Phase**: Worker threads execute physics updates
4. **Sync Phase**: Main thread waits for all tasks to complete
5. **Render Phase**: Main thread renders current ball positions

## Thread Safety Strategy

- Ball state is double-buffered: read from current, write to next
- At frame boundary, buffers are swapped
- No locks needed during physics computation
- Single mutex protects task queue operations

## Memory Layout

```
+------------------------+
| World State (shared)   |
+------------------------+
| Ball Array (current)   |  <- Read by workers
+------------------------+
| Ball Array (next)      |  <- Written by workers
+------------------------+
| Peg Array (immutable)  |  <- Read-only after init
+------------------------+
| Task Queue             |  <- Mutex protected
+------------------------+
| Worker Thread Stacks   |  <- One per worker
+------------------------+
```
