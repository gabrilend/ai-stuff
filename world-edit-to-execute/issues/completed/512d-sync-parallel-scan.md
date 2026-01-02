# Issue 512d: Sync Parallel Scan

**Phase:** 5 - Rendering
**Type:** Implementation
**Priority:** Critical
**Dependencies:** 512a (ring buffer), 512b (load balancing)
**Parent:** 512-threading-architecture-rewrite.md

---

## Current Behavior

Sync thread iterates all workers checking for ready output:
- Loops through pool->buffers[i] checking output_ready flag
- On ready: locks output, copies to primary buffer, clears flag
- Sleeps 1ms when no outputs ready
- Blocking design: checks all workers sequentially

```c
// Current: Sequential scan with blocking
void* sync_loop(void* arg) {
    while (running) {
        for (int i = 0; i < pool->count; i++) {
            if (atomic_load(&buf->output_ready)) {
                // Lock, copy, unlock
            }
        }
        if (!any_swapped) usleep(1000);
    }
}
```

---

## Intended Behavior

Sync thread monitors a watch list of pending swaps:
- Workers add entries to watch list when output is ready
- Sync continuously iterates list (no per-worker loop)
- On ready flag: swap pointer, remove from list
- Brief yield only when list is empty

```c
// Target: Watch list with pointer swaps
typedef struct watch_entry {
    atomic_bool* ready_flag;
    void** target_ptr;
    void* source_ptr;
} WatchEntry;

void* sync_loop(void* arg) {
    while (running) {
        for (size_t i = 0; i < watch_count; ) {
            if (atomic_load(entry->ready_flag)) {
                *target_ptr = source_ptr;  // Atomic swap
                // Remove from list
            } else {
                i++;
            }
        }
        if (watch_count == 0) usleep(100);
    }
}
```

---

## Suggested Implementation Steps

1. **Define WatchEntry struct**
   ```c
   typedef struct watch_entry {
       atomic_bool* ready_flag;  // Set by worker when ready
       void** target_ptr;        // Primary buffer slot to update
       void* source_ptr;         // New pointer value
   } WatchEntry;
   ```

2. **Define SyncContext with watch list**
   ```c
   typedef struct sync_context {
       WatchEntry* watch_list;
       size_t watch_capacity;
       atomic_size_t watch_count;

       atomic_bool running;

       // Stats
       uint64_t swaps_performed;
       uint64_t idle_cycles;

       // Lock for adding entries (workers write)
       pthread_spinlock_t watch_lock;
   } SyncContext;
   ```

3. **Implement sync_add_watch**
   ```c
   bool sync_add_watch(SyncContext* ctx,
                       atomic_bool* ready,
                       void** target,
                       void* source) {
       pthread_spin_lock(&ctx->watch_lock);

       size_t count = atomic_load(&ctx->watch_count);
       if (count >= ctx->watch_capacity) {
           pthread_spin_unlock(&ctx->watch_lock);
           return false;  // Watch list full
       }

       ctx->watch_list[count].ready_flag = ready;
       ctx->watch_list[count].target_ptr = target;
       ctx->watch_list[count].source_ptr = source;
       atomic_fetch_add(&ctx->watch_count, 1);

       pthread_spin_unlock(&ctx->watch_lock);
       return true;
   }
   ```

4. **Rewrite sync_loop for watch list**
   ```c
   void* sync_loop(void* arg) {
       SyncContext* ctx = (SyncContext*)arg;

       while (atomic_load(&ctx->running)) {
           size_t count = atomic_load(&ctx->watch_count);

           for (size_t i = 0; i < count; ) {
               WatchEntry* entry = &ctx->watch_list[i];

               if (atomic_load(entry->ready_flag)) {
                   // Swap pointer atomically
                   *entry->target_ptr = entry->source_ptr;

                   // Clear ready flag
                   atomic_store(entry->ready_flag, false);

                   // Remove: swap with last, decrement count
                   pthread_spin_lock(&ctx->watch_lock);
                   ctx->watch_list[i] = ctx->watch_list[--count];
                   atomic_store(&ctx->watch_count, count);
                   pthread_spin_unlock(&ctx->watch_lock);

                   ctx->swaps_performed++;
                   // Don't increment i - check swapped entry
               } else {
                   i++;
               }
           }

           // Brief yield only when list is empty
           if (count == 0) {
               ctx->idle_cycles++;
               usleep(100);  // 0.1ms
           }
       }
       return NULL;
   }
   ```

5. **Implement sync_create / sync_destroy**
   ```c
   SyncContext* sync_create(size_t capacity) {
       SyncContext* ctx = calloc(1, sizeof(SyncContext));
       ctx->watch_list = calloc(capacity, sizeof(WatchEntry));
       ctx->watch_capacity = capacity;
       atomic_store(&ctx->watch_count, 0);
       atomic_store(&ctx->running, true);
       pthread_spin_init(&ctx->watch_lock, PTHREAD_PROCESS_PRIVATE);
       return ctx;
   }

   void sync_destroy(SyncContext* ctx) {
       pthread_spin_destroy(&ctx->watch_lock);
       free(ctx->watch_list);
       free(ctx);
   }
   ```

6. **Update worker tasks to use sync_add_watch**
   ```c
   // In render task completion:
   void render_task_execute(void* arg) {
       RenderTaskContext* ctx = (RenderTaskContext*)arg;

       // Compute output...
       ctx->output_ready = false;  // Will be set true below

       // When done, add to sync watch list
       sync_add_watch(ctx->sync_ctx,
                      &ctx->output_ready,
                      &primary_buffer->slots[ctx->slot_id],
                      ctx->computed_output);

       atomic_store(&ctx->output_ready, true);
   }
   ```

7. **Remove old per-worker output_ready checks**
   - Delete output_ready field from WorkerBuffers
   - Delete has_any_output_ready function
   - Update pool_create/destroy

8. **Unit test for parallel sync**
   - Add multiple watch entries
   - Set ready flags in random order
   - Verify swaps occur correctly
   - Verify removal from list

---

## Acceptance Criteria

- [x] WatchEntry struct defined
- [x] SyncContext has watch_list with spinlock
- [x] sync_add_watch safely adds entries (thread-safe)
- [x] sync_loop iterates watch list, not workers
- [x] Pointer swaps are atomic
- [x] Entries removed from list after swap
- [x] Brief yield only when list empty (0.1ms)
- [x] sync_create / sync_destroy manage resources
- [x] Old per-worker output_ready code removed
- [x] Unit test verifies parallel swap behavior

---

## Files to Modify

```
src/render/
├── threading.h    (WatchEntry, updated SyncContext)
├── threading.c    (sync_loop rewrite, sync_add_watch)
└── test_threading.c    (parallel sync tests)
```

---

## Notes

The watch list approach decouples sync from worker count. Sync doesn't need to
know how many workers exist - it just processes ready entries.

Spinlock is chosen over mutex because the critical section is very small
(just appending to the list). Spinlocks have lower overhead for short operations.

The swap-with-last removal keeps the list compact without needing to shift
elements. Order doesn't matter for swap processing.

Draw thread reads pointers atomically and never needs notification. Pointer
swaps by sync are invisible to draw - it just renders what pointers point to.

---

## Implementation Notes

**Completed:** 2026-01-01

Implemented as part of 512a. All sync infrastructure is in place:

| Function | Location | Description |
|----------|----------|-------------|
| sync_create | threading.c:337 | Creates SyncContext with watch list |
| sync_destroy | threading.c:364 | Frees resources |
| sync_add_watch | threading.c:375 | Thread-safe watch entry addition |
| sync_loop | threading.c:401 | Continuous watch list iteration |
| spawn_sync_thread | threading.c:452 | Spawns sync thread |

Tests:
- `test_sync_watch_list`: Single entry add/swap
- `test_sync_multiple_entries`: 10 entries with random ready order
