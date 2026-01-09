# Issue 800b: Sync Module (Watch List)

**Phase:** 8 (Infrastructure Libraries)
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 800a-core-threadpool-module.md
**Parent:** 800-threadpool-library-extraction.md

---

## Current Behavior

Sync functionality (SyncContext, WatchEntry, watch list iteration) is in
`src/render/threading.c` coupled with core pool code. The sync thread monitors
memory locations and performs atomic pointer swaps when ready flags are set.

## Intended Behavior

Optional sync module that users can include when they need coordinated pointer
updates (common in double-buffering, render pipelines, or any producer-consumer
pattern with pointer handoff).

```c
/* Sync-specific configuration */
typedef struct tp_sync_config {
    size_t watch_list_size;     /* Default: 2048 */
    void (*log_fn)(const char* fmt, ...);
} TpSyncConfig;

/* Public API */
TpSyncConfig tp_sync_config_default(void);
SyncContext* tp_sync_create(TpSyncConfig* config);
void tp_sync_destroy(SyncContext* ctx);
bool tp_sync_add_watch(SyncContext* ctx, atomic_bool* ready, void** target, void* source);
pthread_t tp_sync_spawn(SyncContext* ctx);
void tp_sync_stop(SyncContext* ctx);

/* Statistics */
uint64_t tp_sync_get_swaps(SyncContext* ctx);
uint64_t tp_sync_get_idle_cycles(SyncContext* ctx);
```

## Suggested Implementation Steps

1. Create sync module files:
   ```
   my-libs/threadpool/
   ├── threadpool_sync.h    # Sync public API
   └── threadpool_sync.c    # Sync implementation
   ```

2. Extract from threading.h:
   - WatchEntry struct
   - SyncContext struct (add config storage)

3. Extract from threading.c:
   - sync_create() → tp_sync_create()
   - sync_destroy() → tp_sync_destroy()
   - sync_add_watch() → tp_sync_add_watch()
   - sync_loop() (internal)
   - spawn_sync_thread() → tp_sync_spawn()

4. Add configuration handling:
   - watch_list_size configurable
   - log callback (can differ from core module)

5. Add stop function for clean shutdown:
   ```c
   void tp_sync_stop(SyncContext* ctx) {
       atomic_store(&ctx->running, false);
       /* Thread will exit on next iteration */
   }
   ```

## Acceptance Criteria

- [ ] Sync module compiles with only core module as dependency
- [ ] Sync module is optional (core works without it)
- [ ] Watch list size is configurable
- [ ] Pointer swaps occur correctly when ready flags set
- [ ] Statistics (swaps, idle cycles) are accessible
- [ ] Clean shutdown via tp_sync_stop()
- [ ] Spinlock properly initialized and destroyed

## Files to Create

- `my-libs/threadpool/threadpool_sync.h`
- `my-libs/threadpool/threadpool_sync.c`

## Notes

The sync pattern is useful beyond rendering:
- Database connection pool handoff
- Network buffer double-buffering
- Any producer-consumer with pointer ownership transfer

The watch list approach avoids blocking - the sync thread continuously polls
ready flags, which is more responsive than condition variables for high-frequency
updates (100Hz target).
