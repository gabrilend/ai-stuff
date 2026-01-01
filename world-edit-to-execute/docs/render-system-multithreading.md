# Render System Multithreading Architecture

## Overview

The render system uses a 4-stage producer-consumer pipeline designed to minimize synchronization overhead and keep the GPU fed with data. The key insight is that workers produce **GPU-ready data** (transformed vertices, final colors, visibility flags) rather than GPU commands, allowing the draw stage to iterate a simple buffer without computation.

## Pipeline Stages

### Stage 1: Updater Thread

**Purpose:** Bridge between game logic and render pipeline

| Property | Value |
|----------|-------|
| Thread Count | 1 |
| Input | Game state (ECS components, Lua tables) |
| Output | Worker input queue (entity transforms, colors, flags) |
| Sleep | 5ms when input queue empty |

**Work performed:**
- Reads entity positions, rotations, scales from ECS
- Reads visibility flags, team colors, selection state
- Packages data into worker-consumable format
- Distributes work across worker input slots (round-robin or spatial partitioning)

**Why single-threaded:** Game state access must be serialized to avoid race conditions with the game loop. The updater acts as the sole reader of game state for rendering purposes.

### Stage 2: Worker Threads

**Purpose:** Transform game data into GPU-ready format

| Property | Value |
|----------|-------|
| Thread Count | 2-4 (configurable) |
| Input | Entity data from updater |
| Output | GPU-ready transforms, colors, visibility |
| Sleep | 0.1ms between work ticks |

**Work performed:**
- Matrix multiplication (model -> world -> view -> projection)
- Color computation (team color blending, selection highlights, damage flash)
- Visibility culling (frustum tests, fog of war checks)
- LOD selection based on camera distance
- Bounding box computation for picking

**Why multiple threads:** Transform computation is embarrassingly parallel - each entity's transforms are independent. Worker count scales with CPU cores.

**Current partitioning:** Each worker owns a fixed slice of entity slots (e.g., worker 0 handles slots 0-1023, worker 1 handles 1024-2047). No dynamic load balancing.

### Stage 3: Sync Thread

**Purpose:** Coordinate buffer swaps between workers and draw

| Property | Value |
|----------|-------|
| Thread Count | 1 |
| Input | Worker output ready flags |
| Output | Swapped buffer pointers |
| Sleep | 1ms when no outputs ready |

**Work performed:**
- Monitors worker completion flags (atomic reads)
- Waits for all workers to complete current frame's work
- Swaps output buffer pointers (double-buffering)
- Signals draw thread that new data is available
- Resets worker ready flags for next frame

**Why dedicated thread:** Decouples worker completion detection from draw timing. Draw thread can be blocked on vsync while sync thread prepares next frame's data.

### Stage 4: Draw Thread (Main)

**Purpose:** Issue GPU commands

| Property | Value |
|----------|-------|
| Thread Count | 1 (main thread, required by most graphics APIs) |
| Input | GPU-ready buffer from sync |
| Output | GPU commands (via Raylib) |
| Sleep | Vsync (16.67ms at 60Hz) |

**Work performed:**
- Iterates render buffer sequentially
- Issues draw calls for visible entities
- Minimal per-entity work (just buffer reads and API calls)
- Handles UI rendering (immediate mode, after world)

**Why main thread:** OpenGL/DirectX context is typically bound to the thread that created the window. Raylib requires main-thread rendering.

## Data Flow Diagram

```
+-------------+     +-------------+     +-------------+     +-------------+
|   UPDATER   |     |   WORKERS   |     |    SYNC     |     |    DRAW     |
|  (1 thread) |---->| (2-4 thrds) |---->|  (1 thread) |---->|   (main)    |
+-------------+     +-------------+     +-------------+     +-------------+
      |                   |                   |                   |
      v                   v                   v                   v
 +---------+        +----------+        +----------+        +----------+
 |  Game   |        | Transform |        |  Buffer  |        |   GPU    |
 |  State  |        |  Matrices |        |   Swap   |        |  Calls   |
 +---------+        +----------+        +----------+        +----------+
```

## Synchronization Mechanisms

### Ready Flags (Atomic Booleans)

Each worker has an atomic boolean indicating completion:

```c
atomic_bool worker_ready[MAX_WORKERS];

// Worker sets when done
atomic_store(&worker_ready[worker_id], true);

// Sync thread polls
while (!all_workers_ready()) {
    usleep(1000);  // 1ms
}
```

**Why atomics:** Lock-free signaling. Workers never block on each other; sync thread does cheap polling rather than condition variable waits.

### Buffer Access (Mutexes)

Double-buffered output requires mutex protection during swap:

```c
pthread_mutex_t buffer_mutex;

// Sync thread swaps
pthread_mutex_lock(&buffer_mutex);
swap_buffer_pointers();
pthread_mutex_unlock(&buffer_mutex);

// Draw thread reads
pthread_mutex_lock(&buffer_mutex);
render_from_buffer(primary_buffer);
pthread_mutex_unlock(&buffer_mutex);
```

**Why mutexes here:** Buffer pointer swap must be atomic with respect to draw reads. Mutex held very briefly (pointer swap only, not data copy).

### Data Isolation

Workers write to disjoint memory regions (their assigned slots), eliminating write-write conflicts:

```
Worker 0: slots[0..1023]      --+
Worker 1: slots[1024..2047]   --+--> No overlap, no locks needed
Worker 2: slots[2048..3071]   --+
```

## Sleep Behavior Rationale

| Stage | Sleep | Rationale |
|-------|-------|-----------|
| Updater | 5ms | Game state updates at 62.5Hz (16ms), so 5ms polling catches changes with margin |
| Workers | 0.1ms | Tight loop for responsiveness; most time spent computing, not sleeping |
| Sync | 1ms | Balance between latency and CPU usage; checking atomics is cheap |
| Draw | Vsync | Let GPU pace the rendering; prevents tearing and saves power |

## Current Limitations

### 1. No Timing Data

**Problem:** Only swap counts and idle counts are tracked, not actual timing.

**Impact:** Cannot identify bottleneck stages or measure frame time breakdown.

**Potential fix:** Add high-resolution timestamps at stage entry/exit:
```c
struct StageMetrics {
    uint64_t start_ns;
    uint64_t end_ns;
    uint64_t wait_ns;  // Time spent sleeping/blocked
};
```

### 2. Fixed Sleep Times

**Problem:** Sleep durations are hardcoded constants, not adaptive.

**Impact:**
- If workers finish fast, sync waits longer than necessary
- If workers are slow, polling burns CPU cycles
- Doesn't adapt to varying workloads (100 entities vs 10,000)

**Potential fix:** Exponential backoff or work-based sleep:
```c
// Adaptive: sleep proportional to expected work time
int sleep_us = last_work_time_us / 10;
sleep_us = clamp(sleep_us, 100, 5000);
```

### 3. No Work Stealing

**Problem:** Workers own fixed slot ranges. If one finishes early, it idles while others still work.

**Impact:** Load imbalance when entities cluster spatially (e.g., battle in one map corner).

**Potential fix:** Work queue with atomic dequeue:
```c
// Instead of fixed ranges:
while ((slot = atomic_fetch_add(&next_slot, 1)) < total_slots) {
    process_slot(slot);
}
```

### 4. No Priority System

**Problem:** All entities treated equally regardless of screen prominence.

**Impact:** Tiny distant units consume same worker time as large central units.

**Potential fix:** LOD-based work skipping or priority queues.

## Performance Characteristics

| Metric | Typical Value | Notes |
|--------|---------------|-------|
| Updater throughput | ~50,000 entities/frame | Bottleneck is ECS iteration |
| Worker throughput | ~10,000 transforms/thread/frame | Matrix math bound |
| Sync latency | <1ms | Just pointer swaps |
| Draw time | 2-8ms | Depends on draw call count |
| Overall frame budget | 16.67ms at 60fps | Currently hitting target |

## Related Issues

- **Issue 511:** Render system profiler (addresses limitation #1)
- **Issue 508a:** Threading infrastructure (current implementation)

## References

- `src/render/main.c` - Implementation
- `docs/render-architecture.md` - Higher-level render system design
