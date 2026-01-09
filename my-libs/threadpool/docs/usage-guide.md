# Threadpool Library Usage Guide

A modular, high-performance threading library for general-purpose computation and real-time rendering.

**Version:** 1.0
**Location:** `/path/to/my-libs/threadpool/`
**Language:** C (C11 standard)
**Platform:** POSIX (Linux, macOS)

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Compute Tasks](#compute-tasks-general-purpose-threading)
4. [Visual Tasks](#visual-tasks-rendering-pipeline)
5. [Deferred Tasks](#deferred-tasks-scheduler)
6. [API Reference](#api-reference)
7. [Best Practices](#best-practices)
8. [Examples](#complete-examples)

---

## Overview

The threadpool library provides three independent modules:

| Module | Purpose | Use When |
|--------|---------|----------|
| **Core** | Worker pool with load balancing | You need parallel task execution |
| **Sync** | Non-blocking pointer coordination | You have producer-consumer patterns (e.g., rendering) |
| **Updater** | Self-evaluating task distribution | You need adaptive task scheduling |
| **Scheduler** | Time-based deferred execution | You need tasks to run at specific times |

**Pick what you need:** Each module works independently. Use just the core for simple threading, add sync for rendering, add scheduler for time-based tasks.

---

## Quick Start

### 1. Include Headers

```c
#include "threadpool.h"           // Core module (always needed)
#include "threadpool_sync.h"      // Optional: for rendering/pointer coordination
#include "threadpool_updater.h"   // Optional: for adaptive distribution
#include "threadpool_scheduler.h" // Optional: for time-based tasks
```

### 2. Link the Library

**Option A: Direct compilation**
```bash
gcc your_app.c \
    /path/to/my-libs/threadpool/src/threadpool.c \
    /path/to/my-libs/threadpool/src/threadpool_sync.c \
    /path/to/my-libs/threadpool/src/threadpool_updater.c \
    /path/to/my-libs/threadpool/src/threadpool_scheduler.c \
    -I/path/to/my-libs/threadpool/src \
    -pthread -o your_app
```

**Option B: Static library**
```bash
# Build library
cd /path/to/my-libs/threadpool
make  # (if Makefile exists)

# Link your app
gcc your_app.c -L/path/to/my-libs/threadpool -lthreadpool -pthread -o your_app
```

### 3. Basic Example

```c
#include "threadpool.h"
#include <stdio.h>

void my_task(void* context) {
    int* value = (int*)context;
    printf("Task processing value: %d\n", *value);
}

int main(void) {
    // Create pool with auto-detected CPU cores
    TpPool* pool = tp_pool_create(NULL, 0);

    // Create and submit a task
    int data = 42;
    TpTask task = {
        .execute = my_task,
        .context = &data,
        .weight = TP_WEIGHT_LIGHT,
        .repeat_count = 1
    };

    TpWorker* worker = tp_find_least_busy(pool);
    tp_task_append(worker, &task);

    // Let task complete
    sleep(1);

    // Cleanup
    tp_pool_destroy(pool);
    return 0;
}
```

---

## Compute Tasks (General-Purpose Threading)

Use the **core module** for CPU-bound tasks: data processing, physics simulation, AI pathfinding, etc.

### Pattern: Batch Processing

Process large datasets in parallel:

```c
#include "threadpool.h"
#include <stdio.h>

typedef struct {
    float* input;
    float* output;
    size_t start;
    size_t end;
} ProcessChunk;

/* {{{ process_chunk
 * Processes a chunk of data (e.g., apply filter, compute values) */
void process_chunk(void* context) {
    ProcessChunk* chunk = (ProcessChunk*)context;

    for (size_t i = chunk->start; i < chunk->end; i++) {
        // Example: square each value
        chunk->output[i] = chunk->input[i] * chunk->input[i];
    }
}
/* }}} */

int main(void) {
    const size_t DATA_SIZE = 10000;
    const size_t CHUNK_SIZE = 1000;

    float* input = malloc(DATA_SIZE * sizeof(float));
    float* output = malloc(DATA_SIZE * sizeof(float));

    // Initialize input data
    for (size_t i = 0; i < DATA_SIZE; i++) {
        input[i] = (float)i;
    }

    // Create pool
    TpPool* pool = tp_pool_create(NULL, 0);  // Auto-detect cores

    // Submit chunks
    ProcessChunk chunks[10];
    for (size_t i = 0; i < 10; i++) {
        chunks[i].input = input;
        chunks[i].output = output;
        chunks[i].start = i * CHUNK_SIZE;
        chunks[i].end = (i + 1) * CHUNK_SIZE;

        TpTask task = {
            .execute = process_chunk,
            .context = &chunks[i],
            .weight = TP_WEIGHT_MEDIUM,
            .repeat_count = 1
        };

        TpWorker* worker = tp_find_least_busy(pool);
        tp_task_append(worker, &task);
    }

    // Wait for completion
    sleep(1);

    // Cleanup
    tp_pool_destroy(pool);
    free(input);
    free(output);

    return 0;
}
```

### Pattern: Continuous Processing

For tasks that run repeatedly (e.g., game physics, network polling):

```c
void physics_tick(void* context) {
    PhysicsWorld* world = (PhysicsWorld*)context;
    // Update physics simulation
    physics_step(world, 0.016f);  // 16ms step
}

int main(void) {
    PhysicsWorld world;
    physics_init(&world);

    TpPool* pool = tp_pool_create(NULL, 0);

    TpTask task = {
        .execute = physics_tick,
        .context = &world,
        .weight = TP_WEIGHT_HEAVY,
        .repeat_count = INT16_MAX  // Run essentially forever
    };

    TpWorker* worker = tp_find_least_busy(pool);
    tp_task_append(worker, &task);

    // Run for duration of application
    // ...

    tp_pool_destroy(pool);
    return 0;
}
```

### Key Concepts

- **Weight:** Estimate task cost for load balancing (`TP_WEIGHT_LIGHT`, `TP_WEIGHT_MEDIUM`, `TP_WEIGHT_HEAVY`)
- **Repeat count:** How many times to execute (1 = once, INT16_MAX = essentially forever)
- **Load balancing:** Use `tp_find_least_busy()` to distribute work evenly

---

## Visual Tasks (Rendering Pipeline)

Use **core + sync modules** for double-buffered rendering, where workers produce frames and the main thread displays them.

### Architecture

```
[Workers]                  [Sync Thread]              [Main/Draw Thread]
  ↓                             ↓                           ↓
Render to                  Watch for                   Read from
back buffer  ────────▶     ready flag  ─────────▶     front buffer
Set ready=true            Swap pointers              Display frame
```

### Pattern: Double-Buffered Rendering

```c
#include "threadpool.h"
#include "threadpool_sync.h"

typedef struct {
    void* pixels;  // Frame data
    int width;
    int height;
} Frame;

typedef struct {
    Frame* front;      // Currently displayed
    Frame* back;       // Being rendered
    atomic_bool ready; // Signal: back buffer complete
} RenderState;

/* {{{ render_frame
 * Worker task: render to back buffer */
void render_frame(void* context) {
    RenderState* state = (RenderState*)context;
    Frame* back = state->back;

    // Render to back buffer
    for (int y = 0; y < back->height; y++) {
        for (int x = 0; x < back->width; x++) {
            // Draw pixels...
        }
    }

    // Signal completion
    atomic_store(&state->ready, true);
}
/* }}} */

int main(void) {
    // Allocate frame buffers
    Frame frame1 = { .pixels = malloc(800*600*4), .width = 800, .height = 600 };
    Frame frame2 = { .pixels = malloc(800*600*4), .width = 800, .height = 600 };

    RenderState state = {
        .front = &frame1,
        .back = &frame2,
        .ready = false
    };

    // Create pool and sync
    TpPool* pool = tp_pool_create(NULL, 0);

    TpSyncConfig sync_cfg = tp_sync_config_default();
    TpSyncContext* sync = tp_sync_create(&sync_cfg);

    // Add watch entry: when ready flag set, swap front pointer
    tp_sync_add_watch(sync, &state.ready, (void**)&state.front, state.back);

    // Spawn sync thread
    pthread_t sync_thread = tp_sync_spawn(sync);

    // Submit render task
    TpTask task = {
        .execute = render_frame,
        .context = &state,
        .weight = TP_WEIGHT_HEAVY,
        .repeat_count = INT16_MAX  // Keep rendering
    };

    TpWorker* worker = tp_find_least_busy(pool);
    tp_task_append(worker, &task);

    // Main loop: display front buffer
    while (running) {
        // Display state.front (safe to read, sync handles pointer swap)
        display_frame(state.front);

        // Swap back buffer for next frame
        state.back = (state.back == &frame1) ? &frame2 : &frame1;
    }

    // Cleanup
    tp_sync_stop(sync);
    pthread_join(sync_thread, NULL);
    tp_sync_destroy(sync);
    tp_pool_destroy(pool);

    free(frame1.pixels);
    free(frame2.pixels);

    return 0;
}
```

### Pattern: Multi-Slot Rendering

For parallel rendering of multiple objects (e.g., UI panels, sprites):

```c
#define NUM_SLOTS 64

typedef struct {
    void* pixels;
    atomic_bool ready;
    int slot_id;
} RenderSlot;

RenderSlot slots[NUM_SLOTS];
void* front_buffers[NUM_SLOTS];

// Add watch for each slot
for (int i = 0; i < NUM_SLOTS; i++) {
    tp_sync_add_watch(sync, &slots[i].ready, &front_buffers[i], slots[i].pixels);
}

// Workers render to slots, sync thread updates front_buffers
// Main thread reads from front_buffers (always safe)
```

### Key Concepts

- **Watch list:** Register pointer + ready flag pairs
- **Sync thread:** Continuously polls ready flags, swaps pointers atomically
- **Non-blocking:** Main thread never waits, always reads from safe buffer

---

## Deferred Tasks (Scheduler)

Use the **scheduler module** for time-based task execution: cooldowns, periodic events, delayed actions.

### Setup: Define Global Tick Counter

The scheduler requires a global tick counter that your application increments:

```c
#include "threadpool_scheduler.h"

// Define this once in your application
_Atomic uint64_t g_current_tick = 0;

// In your main loop, increment the tick
void game_loop(void) {
    while (running) {
        atomic_fetch_add(&g_current_tick, 1);

        // Run at 62.5Hz (16ms per tick)
        usleep(16000);
    }
}
```

### Pattern: One-Shot Delayed Task

Execute a task after a specific delay:

```c
#include "threadpool_scheduler.h"

void delayed_action(void* context) {
    printf("This runs after 100 ticks!\n");
}

int main(void) {
    // Create scheduler
    TpSchedulerConfig cfg = tp_scheduler_config_default();
    TpScheduler* sched = tp_scheduler_create(&cfg);

    // Schedule task to run in 100 ticks
    TpTask task = {
        .execute = delayed_action,
        .context = NULL,
        .weight = TP_WEIGHT_LIGHT,
        .repeat_count = 1
    };

    tp_scheduler_add(sched, &task, 100);  // Delay: 100 ticks

    // In your loop, check for ready tasks
    while (running) {
        TpTask* ready_tasks;
        size_t count;

        if (tp_scheduler_get_ready(sched, &ready_tasks, &count)) {
            // Execute ready tasks (or submit to worker pool)
            for (size_t i = 0; i < count; i++) {
                ready_tasks[i].execute(ready_tasks[i].context);
            }
        }

        atomic_fetch_add(&g_current_tick, 1);
        usleep(16000);
    }

    tp_scheduler_destroy(sched);
    return 0;
}
```

### Pattern: Periodic Tasks

For recurring events (damage-over-time, spawning, cooldowns):

```c
typedef struct {
    int target_id;
    int damage;
    int ticks_remaining;
    TpScheduler* sched;
} DotEffect;

void apply_dot(void* context) {
    DotEffect* dot = (DotEffect*)context;

    printf("Applying %d damage to target %d\n", dot->damage, dot->target_id);
    dot->ticks_remaining--;

    if (dot->ticks_remaining > 0) {
        // Re-schedule for next tick
        TpTask task = {
            .execute = apply_dot,
            .context = dot,
            .weight = TP_WEIGHT_LIGHT,
            .repeat_count = 1
        };
        tp_scheduler_add(dot->sched, &task, 1);  // Run again in 1 tick
    } else {
        // Effect expired
        free(dot);
    }
}

void start_dot_effect(TpScheduler* sched, int target_id, int damage, int duration_ticks) {
    DotEffect* dot = malloc(sizeof(DotEffect));
    dot->target_id = target_id;
    dot->damage = damage;
    dot->ticks_remaining = duration_ticks;
    dot->sched = sched;

    TpTask task = {
        .execute = apply_dot,
        .context = dot,
        .weight = TP_WEIGHT_LIGHT,
        .repeat_count = 1
    };

    tp_scheduler_add(sched, &task, 0);  // Start immediately
}
```

### Pattern: Integration with Updater

For automatic task distribution, integrate scheduler with updater:

```c
#include "threadpool_updater.h"
#include "threadpool_scheduler.h"

// Callback for updater: get tasks from scheduler
bool get_scheduled_tasks(void* user_data, TpTask** out, size_t* count) {
    TpScheduler* sched = (TpScheduler*)user_data;
    return tp_scheduler_get_ready(sched, out, count);
}

int main(void) {
    TpPool* pool = tp_pool_create(NULL, 0);

    TpSchedulerConfig sched_cfg = tp_scheduler_config_default();
    TpScheduler* sched = tp_scheduler_create(&sched_cfg);

    TpUpdaterConfig upd_cfg = tp_updater_config_default();
    TpUpdaterContext* updater = tp_updater_create(
        pool, &upd_cfg, get_scheduled_tasks, sched
    );

    // Start updater - automatically distributes scheduled tasks
    tp_updater_start(updater);

    // Now schedule tasks - updater will distribute them to workers
    // ... tp_scheduler_add() calls ...

    // Cleanup
    tp_pool_destroy(pool);
    tp_scheduler_destroy(sched);
    // Note: updater context freed by pool

    return 0;
}
```

### Key Concepts

- **Absolute time:** Tasks store `ready_at_tick`, not countdown timers
- **Tick counter:** Your application increments `g_current_tick`
- **Wake-on-add:** Adding tasks wakes sleeping updater (if using updater integration)

---

## API Reference

### Core Module (threadpool.h)

**Pool Lifecycle**
```c
TpPool* tp_pool_create(TpConfig* config, int worker_count);
void tp_pool_destroy(TpPool* pool);
unsigned int tp_pool_get_load(TpPool* pool);
```

**Task Management**
```c
bool tp_task_append(TpWorker* w, TpTask* task);
TpWorker* tp_find_least_busy(TpPool* pool);
TpWorker* tp_find_least_busy_excluding(TpPool* pool, int exclude_id);
```

**Task Structure**
```c
typedef struct tp_task {
    void (*execute)(void* context);      // Function to run
    void (*on_complete)(void* context);  // Optional: called when repeat_count reaches 0
    void* context;                       // User data
    uint16_t weight;                     // Load estimate (TP_WEIGHT_*)
    int16_t repeat_count;                // Iterations (INT16_MAX = forever)
} TpTask;
```

**Weight Constants**
```c
TP_WEIGHT_SLEEP   // 0  - No-op
TP_WEIGHT_LIGHT   // 1  - Quick operations
TP_WEIGHT_MEDIUM  // 5  - Standard tasks
TP_WEIGHT_HEAVY   // 20 - Expensive computation
TP_WEIGHT_UPDATER // 10 - Task distributor
```

### Sync Module (threadpool_sync.h)

**Lifecycle**
```c
TpSyncContext* tp_sync_create(TpSyncConfig* config);
void tp_sync_destroy(TpSyncContext* ctx);
pthread_t tp_sync_spawn(TpSyncContext* ctx);
void tp_sync_stop(TpSyncContext* ctx);
```

**Watch Management**
```c
bool tp_sync_add_watch(TpSyncContext* ctx,
                       atomic_bool* ready_flag,
                       void** target_ptr,
                       void* source_ptr);
```

**Statistics**
```c
uint64_t tp_sync_get_swaps(TpSyncContext* ctx);
uint64_t tp_sync_get_idle_cycles(TpSyncContext* ctx);
```

### Updater Module (threadpool_updater.h)

**Lifecycle**
```c
TpUpdaterContext* tp_updater_create(
    TpPool* pool,
    TpUpdaterConfig* config,
    bool (*get_pending_tasks)(void*, TpTask**, size_t*),
    void* user_data
);
void tp_updater_destroy(TpUpdaterContext* ctx);
void tp_updater_start(TpUpdaterContext* ctx);
```

**Statistics**
```c
unsigned int tp_updater_get_active_count(void);
uint64_t tp_updater_get_last_tick_us(TpUpdaterContext* ctx);
```

### Scheduler Module (threadpool_scheduler.h)

**Lifecycle**
```c
TpScheduler* tp_scheduler_create(TpSchedulerConfig* config);
void tp_scheduler_destroy(TpScheduler* sched);
```

**Task Management**
```c
bool tp_scheduler_add(TpScheduler* sched, TpTask* task, uint32_t ticks_delay);
bool tp_scheduler_get_ready(void* context, TpTask** out, size_t* count);
void tp_scheduler_remove_if(TpScheduler* sched,
                             bool (*predicate)(TpTask*, void*),
                             void* user_data);
size_t tp_scheduler_count(TpScheduler* sched);
```

**Timing**
```c
uint64_t tp_scheduler_earliest_ready_tick(TpScheduler* sched);
void tp_scheduler_sleep_ticks(TpScheduler* sched, uint64_t ticks_to_sleep);
```

**Global Requirement**
```c
// Define this once in your application
extern _Atomic uint64_t g_current_tick;
```

---

## Best Practices

### 1. Choose the Right Weight

Accurate weights improve load balancing:
- Light: < 1ms (data copy, simple math)
- Medium: 1-5ms (render single object, pathfinding)
- Heavy: > 5ms (physics step, AI evaluation)

### 2. Avoid Locks in Tasks

Thread pool is designed for lock-free operation. If you need synchronization:
- Use atomic operations where possible
- Keep critical sections minimal
- Consider splitting tasks instead of locking

### 3. Use repeat_count for Loops

Instead of creating many identical tasks:
```c
// GOOD: One task, runs 100 times
task.repeat_count = 100;

// WASTEFUL: 100 separate tasks
for (int i = 0; i < 100; i++) {
    tp_task_append(worker, &task);
}
```

### 4. Scheduler Tick Rate

Match your application's frame rate:
- 62.5 Hz (16ms) - Game loop (WC3 standard)
- 60 Hz (16.67ms) - Common game target
- 100 Hz (10ms) - High-frequency simulation

### 5. Configuration Tuning

Start with defaults, tune if needed:
```c
TpConfig cfg = tp_config_default();
cfg.task_list_size = 2048;  // Increase if workers run out of space
cfg.log_fn = my_logger;      // NULL = silent (production)
```

### 6. Memory Management

The library doesn't manage task context memory:
```c
// YOUR responsibility to free
MyData* data = malloc(sizeof(MyData));
task.context = data;

// Option 1: Free in on_complete
void cleanup(void* ctx) { free(ctx); }
task.on_complete = cleanup;

// Option 2: Keep alive until pool destroy
// (then free manually)
```

---

## Complete Examples

### Example 1: Image Processing Pipeline

```c
#include "threadpool.h"
#include <stdio.h>
#include <stdlib.h>

typedef struct {
    unsigned char* input;
    unsigned char* output;
    int width, height;
    int start_y, end_y;
} FilterTask;

void apply_grayscale(void* context) {
    FilterTask* task = (FilterTask*)context;

    for (int y = task->start_y; y < task->end_y; y++) {
        for (int x = 0; x < task->width; x++) {
            int idx = (y * task->width + x) * 3;
            unsigned char r = task->input[idx];
            unsigned char g = task->input[idx + 1];
            unsigned char b = task->input[idx + 2];

            // Simple grayscale
            unsigned char gray = (r + g + b) / 3;
            task->output[idx] = task->output[idx + 1] = task->output[idx + 2] = gray;
        }
    }
}

int main(void) {
    const int WIDTH = 1920;
    const int HEIGHT = 1080;
    const int NUM_CHUNKS = 8;

    unsigned char* input = malloc(WIDTH * HEIGHT * 3);
    unsigned char* output = malloc(WIDTH * HEIGHT * 3);

    // Load image into input...

    TpPool* pool = tp_pool_create(NULL, 0);

    FilterTask tasks[NUM_CHUNKS];
    int chunk_height = HEIGHT / NUM_CHUNKS;

    for (int i = 0; i < NUM_CHUNKS; i++) {
        tasks[i].input = input;
        tasks[i].output = output;
        tasks[i].width = WIDTH;
        tasks[i].height = HEIGHT;
        tasks[i].start_y = i * chunk_height;
        tasks[i].end_y = (i + 1) * chunk_height;

        TpTask task = {
            .execute = apply_grayscale,
            .context = &tasks[i],
            .weight = TP_WEIGHT_HEAVY,
            .repeat_count = 1
        };

        TpWorker* worker = tp_find_least_busy(pool);
        tp_task_append(worker, &task);
    }

    // Wait for completion
    sleep(1);

    // Save output...

    tp_pool_destroy(pool);
    free(input);
    free(output);

    return 0;
}
```

### Example 2: Game Loop with Physics and Rendering

```c
#include "threadpool.h"
#include "threadpool_sync.h"

typedef struct {
    float* positions;
    float* velocities;
    int entity_count;
} PhysicsState;

typedef struct {
    void* pixels;
    PhysicsState* physics;
    atomic_bool ready;
} RenderState;

void physics_step(void* context) {
    PhysicsState* state = (PhysicsState*)context;

    for (int i = 0; i < state->entity_count; i++) {
        // Update positions based on velocity
        state->positions[i * 2 + 0] += state->velocities[i * 2 + 0] * 0.016f;
        state->positions[i * 2 + 1] += state->velocities[i * 2 + 1] * 0.016f;
    }
}

void render_frame(void* context) {
    RenderState* state = (RenderState*)context;

    // Render entities from physics state
    for (int i = 0; i < state->physics->entity_count; i++) {
        float x = state->physics->positions[i * 2 + 0];
        float y = state->physics->positions[i * 2 + 1];
        // Draw at (x, y)...
    }

    atomic_store(&state->ready, true);
}

int main(void) {
    PhysicsState physics = {
        .positions = calloc(1000, sizeof(float) * 2),
        .velocities = calloc(1000, sizeof(float) * 2),
        .entity_count = 1000
    };

    RenderState render = {
        .pixels = malloc(800 * 600 * 4),
        .physics = &physics,
        .ready = false
    };

    TpPool* pool = tp_pool_create(NULL, 0);
    TpSyncContext* sync = tp_sync_create(&(TpSyncConfig){.watch_list_size = 1});

    void* front_buffer = render.pixels;
    tp_sync_add_watch(sync, &render.ready, &front_buffer, render.pixels);
    pthread_t sync_thread = tp_sync_spawn(sync);

    // Submit physics task (runs forever)
    TpTask physics_task = {
        .execute = physics_step,
        .context = &physics,
        .weight = TP_WEIGHT_HEAVY,
        .repeat_count = INT16_MAX
    };
    tp_task_append(tp_find_least_busy(pool), &physics_task);

    // Submit render task (runs forever)
    TpTask render_task = {
        .execute = render_frame,
        .context = &render,
        .weight = TP_WEIGHT_HEAVY,
        .repeat_count = INT16_MAX
    };
    tp_task_append(tp_find_least_busy(pool), &render_task);

    // Main loop: display front buffer
    while (running) {
        display(front_buffer);  // Always safe to read
        usleep(16000);  // 60 FPS
    }

    tp_sync_stop(sync);
    pthread_join(sync_thread, NULL);
    tp_sync_destroy(sync);
    tp_pool_destroy(pool);

    free(physics.positions);
    free(physics.velocities);
    free(render.pixels);

    return 0;
}
```

---

## Troubleshooting

**Q: My tasks aren't executing**
A: Check that workers are running (`pool != NULL`) and buffer isn't full. Enable logging:
```c
cfg.log_fn = printf;
```

**Q: Load balancing isn't working**
A: Ensure weights accurately reflect task duration. Use heavier weights for longer tasks.

**Q: Scheduler tasks not running**
A: Verify `g_current_tick` is being incremented in your main loop and that you're calling `tp_scheduler_get_ready()`.

**Q: Sync not swapping pointers**
A: Ensure ready flag is set to `true` after task completes and sync thread is running.

**Q: Memory leaks**
A: The library doesn't manage task context memory. Free in `on_complete` or after pool destruction.

---

## Further Reading

- **Architecture:** See `docs/render-threading-v2.md` (WETE project) for design rationale
- **Test Suite:** See `tests/*.c` for usage examples
- **Issue Tracker:** See `issues/800*.md` for implementation details

**Questions?** Check the test suite for working examples or create an issue.
