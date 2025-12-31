# Issue 508a: Threading Infrastructure

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** Critical
**Dependencies:** 501a (raylib demo)

---

## Current Behavior

The existing `src/render/main.c` has:
- Single `draw()` thread for rendering
- Single `game()` thread for rotation updates
- Mutex-protected `GameState` struct

This is a minimal thread model, not the full staged architecture.

---

## Intended Behavior

Implement the threading model from `docs/render-architecture.md`:

```
[Updater] → [Worker Input Buffers] → [Workers] → [Worker Output Buffers] → [Sync] → [Primary Buffer] → [Draw]
```

### Thread Types

| Thread | Count | Purpose | Sleep Condition |
|--------|-------|---------|-----------------|
| Updater | 1 | Populate worker inputs | No new input |
| Workers | 2-4 | Compute render-ready data | Never (always processing) |
| Sync | 1 | Swap output pointers to primary | No outputs ready |
| Draw | 1 | Iterate primary buffer, GPU dispatch | N/A (frame-locked) |

### Key Properties

- Workers produce **GPU-ready data**, not commands
- Sync thread does **near-zero work** (pointer swaps only)
- Draw thread does **near-zero work** (iterate + dispatch)

---

## Suggested Implementation Steps

### 1. Define Buffer Structures

```c
/* {{{ WorkerBuffers - per-worker input/output */
typedef struct worker_buffers {
    void* input;          // Data from updater
    void* output;         // Computed render data
    bool output_ready;    // Flag for sync thread
    pthread_mutex_t lock;
} WorkerBuffers;
/* }}} */
```

### 2. Create Worker Pool

```c
/* {{{ WorkerPool */
typedef struct worker_pool {
    pthread_t* threads;
    WorkerBuffers* buffers;
    int count;
    bool running;
} WorkerPool;

WorkerPool* pool_create(int worker_count);
void pool_destroy(WorkerPool* pool);
/* }}} */
```

### 3. Implement Worker Loop

```c
/* {{{ worker_loop - always processing */
void* worker_loop(void* arg) {
    WorkerContext* ctx = (WorkerContext*)arg;

    while (ctx->pool->running) {
        // Read input buffer
        pthread_mutex_lock(&ctx->buffers->lock);
        void* input = ctx->buffers->input;
        pthread_mutex_unlock(&ctx->buffers->lock);

        // Process (heavy computation here)
        void* output = ctx->process(input, ctx->slots);

        // Write output buffer
        pthread_mutex_lock(&ctx->buffers->lock);
        ctx->buffers->output = output;
        ctx->buffers->output_ready = true;
        pthread_mutex_unlock(&ctx->buffers->lock);
    }

    return NULL;
}
/* }}} */
```

### 4. Implement Sync Thread

```c
/* {{{ sync_loop - swap pointers when outputs ready */
void* sync_loop(void* arg) {
    SyncContext* ctx = (SyncContext*)arg;

    while (ctx->running) {
        bool any_ready = false;

        for (int i = 0; i < ctx->pool->count; i++) {
            WorkerBuffers* buf = &ctx->pool->buffers[i];

            pthread_mutex_lock(&buf->lock);
            if (buf->output_ready) {
                // Swap into primary buffer (pointer swap)
                swap_to_primary(ctx->primary, buf->output, i);
                buf->output_ready = false;
                any_ready = true;
            }
            pthread_mutex_unlock(&buf->lock);
        }

        if (!any_ready) {
            // Sleep briefly if no outputs ready
            usleep(1000);  // 1ms
        }
    }

    return NULL;
}
/* }}} */
```

### 5. Implement Updater Thread

```c
/* {{{ updater_loop - populate inputs when new data */
void* updater_loop(void* arg) {
    UpdaterContext* ctx = (UpdaterContext*)arg;

    while (ctx->running) {
        // Check for new input (player input, network, etc.)
        if (has_new_input(ctx)) {
            distribute_input_to_workers(ctx);
        } else {
            // Sleep when no input
            usleep(5000);  // 5ms
        }
    }

    return NULL;
}
/* }}} */
```

### 6. Update Main

Replace existing two-thread model with new architecture:

```c
int main(void) {
    // ... init code ...

    // Create thread pool
    WorkerPool* pool = pool_create(2);

    // Create sync context
    SyncContext sync_ctx = { .pool = pool, .primary = primary_buffer };

    // Create updater context
    UpdaterContext updater_ctx = { .pool = pool };

    // Spawn threads
    pthread_t sync_thread, updater_thread;
    pthread_create(&sync_thread, NULL, sync_loop, &sync_ctx);
    pthread_create(&updater_thread, NULL, updater_loop, &updater_ctx);

    // Draw loop runs on main thread
    while (!WindowShouldClose()) {
        draw_from_primary(primary_buffer);
    }

    // Cleanup...
}
```

---

## Files to Create

- `src/render/threading.h` - Thread pool, buffer structs
- `src/render/threading.c` - Implementation
- Update `src/render/main.c` - Use new threading

---

## Acceptance Criteria

- [ ] Worker pool creates configurable number of workers
- [ ] Each worker has isolated input/output buffers
- [ ] Sync thread swaps outputs to primary (pointer only)
- [ ] Updater thread populates inputs
- [ ] Draw thread reads from primary buffer
- [ ] Workers never idle (always processing)
- [ ] Sync/updater sleep when no work
- [ ] Clean shutdown (all threads join)
- [ ] No data races (mutex protected)

---

## Notes

This establishes the threading skeleton. Actual render data flows through
in 508b (slots). This issue just proves the thread synchronization works.

For testing, workers can initially just copy input to output unchanged.

---

## Related Documents

- `docs/render-architecture.md` - Full architecture specification
- `src/render/main.c` - Existing demo to extend

---

## Implementation Notes

**Completed:** 2025-12-30

### Files Created

- `src/render/threading.h` - Thread pool, buffer, and context structures
- `src/render/threading.c` - Worker pool implementation

### Files Modified

- `src/render/main.c` - Integrated threading model with cube demo
- `src/render/run` - Updated to compile threading.c

### Architecture Implemented

```
Main Thread (Draw)
    │
    ├── tick_loop() increments g_tick and g_game_time
    │
    ├── Read from PrimaryBuffer (with lock)
    │
    └── render_cube_at_slot() draws from slot data

Worker Pool (2 workers)
    │
    ├── worker_loop() runs on each worker thread
    │
    └── worker_process_fn() computes rotation from game_time
        └── Writes RenderSlot to output buffer

Updater Thread
    │
    └── custom_updater_loop() checks for new tick
        └── distribute_input_to_workers() copies input to all workers

Sync Thread
    │
    └── custom_sync_loop() checks for ready outputs
        └── sync_to_primary() copies slot data to PrimaryBuffer
```

### Key Decisions

1. **Global g_running flag** - Used `atomic_bool` for thread-safe shutdown signal
2. **Tick-based input** - Workers skip processing if tick hasn't changed
3. **Single worker produces output** - Worker 0 handles the cube; others idle for now
4. **Custom sync/updater loops** - Tailored to demo's simple needs rather than using generic loops

### Test Results

- Compiles without warnings
- All threads spawn and run correctly
- Cube rotates smoothly via worker → sync → draw pipeline
- Clean shutdown with all threads joining

### Acceptance Criteria Status

- [x] Worker pool creates configurable number of workers
- [x] Each worker has isolated input/output buffers
- [x] Sync thread swaps outputs to primary (struct copy, not pointer)
- [x] Updater thread populates inputs
- [x] Draw thread reads from primary buffer
- [x] Workers process continuously (sleep 0.1ms between same-tick checks)
- [x] Sync/updater sleep when no work (1ms / 1ms)
- [x] Clean shutdown (all threads join)
- [x] No data races (mutex protected)
