# Issue 800e: Render System Migration to Threadpool Library

**Phase:** 8 (Infrastructure Libraries)
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 800a, 800b, 800c, 800d
**Parent:** 800-threadpool-library-extraction.md

---

## Current Behavior

Render system uses threading infrastructure directly from `src/render/threading.h`
and `threading.c`. The demo (`demo_threading.c`) is tightly coupled with these files.

## Intended Behavior

Render system includes threadpool library from `my-libs/threadpool/` and uses the
public API. Original `threading.h` and `threading.c` are removed (or marked deprecated).

## Suggested Implementation Steps

1. Update include paths in render code:
   ```c
   /* Before */
   #include "threading.h"

   /* After */
   #include "threadpool.h"
   #include "threadpool_sync.h"
   #include "threadpool_updater.h"
   ```

2. Update function calls to new API:
   ```c
   /* Before */
   pool = pool_create(0);
   sync = sync_create(2048);

   /* After */
   pool = tp_pool_create(NULL, 0);
   TpSyncConfig sync_cfg = tp_sync_config_default();
   sync = tp_sync_create(&sync_cfg);
   ```

3. Update Makefile/build system:
   - Add include path: `-I/home/ritz/programming/ai-stuff/my-libs/threadpool`
   - Link threadpool library (or compile sources directly)

4. Verify demo_threading.c still functions:
   - All panels display correctly
   - Task injection works
   - Statistics accurate
   - No crashes or hangs

5. Remove old files (or rename to .deprecated):
   - `src/render/threading.h`
   - `src/render/threading.c`

6. Update documentation:
   - `docs/render-architecture.md` - reference library location
   - `docs/render-threading-v2.md` - note migration complete

## Acceptance Criteria

- [ ] Render system compiles with library includes
- [ ] demo_threading.c displays all panels correctly
- [ ] Task injection (T/H/S keys) works
- [ ] Load balancing visualization accurate
- [ ] Sync watch list panel shows entries
- [ ] Updater respawn behavior unchanged
- [ ] No regressions in render performance
- [ ] Old threading.* files removed or deprecated

## Files to Modify

- `src/render/main.c` - update includes, init calls
- `src/render/demo_threading.c` - update includes, function names
- `src/render/demo_threading.h` - update includes if needed
- `src/render/Makefile` (if exists) - add library path

## Files to Remove/Deprecate

- `src/render/threading.h`
- `src/render/threading.c`

## Notes

This is the validation step - if the render system works with the extracted
library, the extraction was successful. Any issues discovered here should
be fixed in the library, not worked around in the render code.

The migration also serves as documentation of library usage in a real context.
