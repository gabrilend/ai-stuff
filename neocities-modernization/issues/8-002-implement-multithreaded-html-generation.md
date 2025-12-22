# Issue 8-002: Implement Multi-threaded HTML Page Generation

## Current Behavior

The HTML page generation in `src/flat-html-generator.lua` is single-threaded. Generating all ~12,000 pages (6000+ similar + 6000+ different) takes a very long time because:

1. **Similarity pages**: Fast to generate (simple sorting), but still limited by sequential I/O
2. **Difference pages**: Slow due to O(n²) centroid-based diversity algorithm - each page requires iterating through all poems multiple times

Current generation time estimates:
- Similarity pages: ~5-10 minutes for all poems
- Difference pages: Could take hours for full generation (each page requires n iterations)

## Intended Behavior

Use the `effil` threading library (available at `/home/ritz/programming/ai-stuff/libs/lua/effil-jit` for LuaJIT) to parallelize HTML page generation:

1. **Thread-per-page model**: Each page (similar/XXX.html or different/XXX.html) generated in its own thread
2. **Configurable thread pool**: Limit concurrent threads based on CPU cores (e.g., 8-16 threads)
3. **Shared read-only data**: Poems, embeddings, and similarity data loaded once, shared across threads
4. **Independent file writes**: Each thread writes to its own unique output file

Expected speedup: 8-16x on typical multi-core systems.

## Implementation Steps

### Step 1: Set up effil library integration ✅ COMPLETED
- [x] Add effil library path to package.cpath: `/home/ritz/programming/ai-stuff/libs/lua/effil-jit/build`
- [x] Test basic effil functionality with simple parallel task
- [x] Note: effil.thread() doesn't return values directly, use file existence check instead

### Step 2: Refactor data loading for thread safety ✅ COMPLETED
- [x] Load poems.json once in main thread
- [x] Load similarity_matrix.json once in main thread
- [x] Load poem_colors.json once in main thread
- [x] Convert data structures to effil-shareable format (effil.table)

### Step 3: Implement parallel similarity page generation ✅ COMPLETED
- [x] Create worker function for single similarity page
- [x] Implement batch-based thread pool for similarity pages
- [x] Add progress reporting across batches
- [x] Verify success by checking file existence after thread completion

### Step 4: Implement parallel difference page generation ✅ COMPLETED
- [x] Create worker function for single difference page (centroid-based diversity)
- [x] Implement thread pool for difference pages
- [x] Load 62MB embeddings file and share via effil.table
- [x] Test: 10 pages generated successfully, 8.5MB each with all ~7800 poems
- [x] Note: O(n²) algorithm is slow (~25 sec/page) - optimization needed

### Step 5: Integrate into main pipeline
- [x] Add thread count argument (default 8)
- [x] Add `--test` flag for limited test runs
- [x] Add `--similar-only` and `--different-only` flags
- [ ] Integrate into run.sh or main.lua

### Step 6: Optimize difference page generation ✅ COMPLETED (Option C)
- [ ] Option A: Limit diversity sequence to first N poems (e.g., 500)
- [ ] Option B: Use inverse similarity instead of centroid-based algorithm
- [x] **Option C: Pre-compute all diversity sequences and cache to disk**
  - [x] Created `scripts/precompute-diversity-sequences` with thermal management
  - [x] Cache stored in `assets/embeddings/EmbeddingGemma_latest/diversity_cache.json`
  - [x] Batch-based threading with configurable sleep between batches
  - [x] Updated `generate-html-parallel` to use cache when available
  - [x] Estimated one-time computation: ~42 hours (but runs unattended)
  - [x] Once cached, difference pages generate at ~10 pages/sec (same as similarity)

**Cache Invalidation**: The diversity_cache.json must be regenerated when:
- Similarity algorithm changes (cosine → euclidean, etc.)
- Embedding model changes
- New poems are added to the corpus

## Technical Notes

### effil Library Usage

```lua
-- Add to package.cpath
package.cpath = "/home/ritz/programming/ai-stuff/libs/lua/effil-jit/?.so;" .. package.cpath
local effil = require("effil")

-- Create shared data
local shared_poems = effil.table(poems_data)

-- Create thread pool
local threads = {}
for i = 1, num_threads do
    threads[i] = effil.thread(worker_function)(shared_poems, poem_id)
end

-- Wait for all threads
for _, thread in ipairs(threads) do
    thread:wait()
end
```

### Thread Safety Considerations

1. **Read-only data**: Poems, embeddings, similarity matrix are read-only after loading
2. **File writes**: Each thread writes to unique file, no contention
3. **Progress tracking**: Use atomic counter for progress reporting
4. **Error handling**: Catch errors per-thread, report failures at end

### Performance Optimization for Difference Pages

The diversity algorithm is O(n²) per page. Consider:
1. **Pre-compute full diversity sequences**: Generate once, cache to disk
2. **Batch centroid calculation**: Optimize vector operations
3. **Early termination**: For test/preview, limit to first N poems

## Dependencies

- effil library compiled for LuaJIT at `/home/ritz/programming/ai-stuff/libs/lua/effil-jit`
- LuaJIT (not standard Lua 5.x)

## Quality Assurance Criteria

- [ ] Generation completes without thread-related crashes
- [ ] Output files identical to single-threaded generation
- [ ] Progress reporting shows parallel activity
- [ ] Memory usage reasonable (shared data, not duplicated)
- [ ] Error in one thread doesn't kill entire generation
- [ ] Speedup of at least 4x on 8-core system

## Related Issues

- **Issue 8-001**: Integrate complete HTML generation into pipeline
- **Issue 5-026**: Optimize chronological HTML generation performance

---

**ISSUE STATUS: IN PROGRESS**

**Created**: 2025-12-14

**Phase**: 8 (Website Completion)

**Priority**: High (blocking full generation)

## Progress Summary

**Completed**:
- `scripts/generate-html-parallel` created using effil library
- Similarity page generation working in parallel (10 pages/sec with 4 threads in test)
- CSS-free HTML output using `<font color="">` tags
- Batch-based thread pool with progress reporting
- Difference page generation working (centroid-based diversity algorithm)
- Embeddings loading and sharing via effil.table (5.9M values)
- **Option C optimization**: Pre-computation with `scripts/precompute-diversity-sequences`
- Thermal management with configurable sleep between batches
- Cache-based fast path in generate-html-parallel

**Performance Metrics**:
- Similarity pages: 10 pages/sec (fast)
- Difference pages (on-the-fly): ~0.04 pages/sec (~25 sec/page)
- Difference pages (cached): ~10 pages/sec (same as similarity)
- Pre-computation: ~42 hours one-time cost

**Remaining**:
- Run pre-computation to generate diversity_cache.json
- Integration into main pipeline (run.sh or main.lua)
- Full-scale testing with all ~6000+ poems

---

## Critical Issues Discovered (2025-12-14)

### Bug 1: Index Mapping Mismatch

The `precompute-diversity-sequences` script has a critical bug in how it maps poem indices to embedding positions:

```lua
-- Current (BUGGY) code:
for i, poem in ipairs(poems_data.poems) do
    if poem.id and embeddings_data.embeddings[i] and embeddings_data.embeddings[i].embedding then
        for _, val in ipairs(embeddings_data.embeddings[i].embedding) do
            table.insert(all_embeddings_flat, val)  -- Sequential flat index
        end
        poem_id_to_index[poem.id] = i  -- BUG: Uses ORIGINAL index, not flat index!
    end
end
```

**Problem**: The flat embeddings array is built sequentially (only poems WITH embeddings), but `poem_id_to_index` stores the ORIGINAL poem array index. If any poems lack embeddings, the indices don't match.

**Impact**: Worker threads read wrong embedding data or out-of-bounds memory, causing garbage results or hangs.

**Root Cause Analysis**: The embedding generation system (`src/similarity-engine.lua`) can fail to generate embeddings for poems due to:
- Empty poem content (lines 425-432)
- Network/API errors (network_error, connection_error, empty_response, parse_error)
- Invalid embedding dimensions

Current data shows ~7,355 poems but ~6,641 embeddings = ~714 poems without embeddings.

### Bug 2: Catastrophic effil.table Access Overhead

The worker function accesses the shared `effil.table` directly for every embedding lookup:

```lua
local function get_embedding(idx)
    for j = 1, embedding_dim do
        embedding[j] = all_embeddings_flat[emb_start + j - 1]  -- effil.table access!
    end
end
```

**Performance Analysis**:
- ~6,640 outer loop iterations per sequence
- Each iteration: ~3,320 average calls to `get_embedding`
- Each `get_embedding`: 768 effil.table accesses
- Plus centroid calculations accessing embeddings

**Total: ~17 BILLION effil.table accesses per sequence**

Each effil.table access involves cross-thread synchronization overhead. Even at 1 microsecond per access, this equals ~5 HOURS per sequence, not 25 seconds as originally estimated.

### Recommendation

The effil library is unsuitable for this workload due to the massive number of cross-thread data accesses. Alternative approaches should be evaluated:

1. **Fix and optimize effil approach**: Copy effil.table to local Lua table at worker start (one-time 5.9M value copy per thread)
2. **Single-threaded with progress**: Accept longer runtime, add checkpointing
3. **GPU compute shaders**: Offload vector math to GPU via Vulkan/OpenGL compute
4. **Process-based parallelism**: Spawn separate processes instead of threads (no shared memory overhead)

See: `docs/effil-vs-compute-shader-feasibility.md` for detailed comparison.

---

## Bug 2 Fix Applied (2025-12-20)

**Solution Implemented**: Option 1 - Copy effil.table to local Lua tables at worker start

All three worker functions in `scripts/generate-html-parallel` now copy effil.tables to local Lua tables at the beginning of execution:

1. **similarity_worker**: Copies `all_poems_array`, `similarities_for_poem`, `poem_colors_table`
2. **diversity_worker**: Copies `all_poems_array`, `all_embeddings_flat`, `starting_embedding_flat`, `poem_colors_table`
3. **cached_diversity_worker**: Copies `diversity_sequence`, `all_poems_lookup`, `poem_colors_table`

**Performance Impact**:
- Before: ~17B IPC calls per diversity sequence (~5 hours each)
- After: O(n) one-time copy, then O(1) local table access

---

## Bug 3 Fix Applied (2025-12-21)

**Problem**: `effil.atomic` is nil - function doesn't exist in installed effil version

The progress display originally used `effil.atomic()` counters for real-time per-thread progress updates. However, the installed effil library (effil-jit build) doesn't include the `atomic` function - only has: `thread`, `channel`, `table`, `size`.

**Error encountered**:
```
luajit: src/similarity-engine-parallel.lua:356: attempt to call field 'atomic' (a nil value)
```

**Solution Implemented**: File-based progress polling

Instead of atomic counters, the main thread now polls the output directory for completed files:

1. Removed all `effil.atomic()` counter creation and usage
2. Added `count_output_files()` function that uses `find | wc -l` for fast file counting
3. Progress display now polls file count every 0.5 seconds
4. Simplified from per-thread progress lines to single aggregate progress bar

**Progress display format**:
```
  [██████████░░░░░░░░░░░░░░░░░░░░] 500/7000 (7.1%) │ 0.83/s │ ETA: 7819s
```

This approach is simpler and doesn't require any shared memory between threads.

---

## Per-Thread Progress Display (2025-12-21)

**Enhancement**: Per-thread progress bars using `effil.channel`

User requested individual progress bars for each thread instead of a single aggregate bar.

**Implementation**:

1. Create shared `effil.channel()` before spawning threads
2. Each thread sends `(thread_id, processed_count)` to channel after each poem
3. Main thread drains channel with `pop(0)` (non-blocking) every 0.5 seconds
4. Display one progress bar per thread, plus summary line

**Progress display format**:
```
  Thread  1: [████████████░░░░░░░░] 600/1000 ( 60.0%)
  Thread  2: [██████████░░░░░░░░░░] 500/1000 ( 50.0%)
  Thread  3: [████████░░░░░░░░░░░░] 400/1000 ( 40.0%)
  Thread  4: [██████░░░░░░░░░░░░░░] 300/1000 ( 30.0%)
  ─── Total: 1800/4000 (45.0%) │ 0.95/s │ ETA: 2316s
```

**Key insight**: `effil.channel` provides a thread-safe message queue that works across threads, unlike `effil.atomic` which isn't available in the effil-jit build.

---

## Graceful Ctrl+C Interruption (2025-12-21)

**Enhancement**: Added SIGINT (Ctrl+C) signal handling for graceful shutdown

**Implementation**:

1. Uses LuaJIT FFI to install a C signal handler for SIGINT (signal 2)
2. When Ctrl+C is pressed, sets `interrupted = true` flag
3. Main polling loop checks flag every 0.5 seconds
4. On interrupt: breaks loop, waits 5 seconds for threads to finish current poem
5. Reports partial results and reminds user they can resume

**Code pattern** (LuaJIT FFI signal handling):
```lua
local ffi = require("ffi")
ffi.cdef[[
    typedef void (*sighandler_t)(int);
    sighandler_t signal(int signum, sighandler_t handler);
]]

local SIGINT = 2
local interrupted = false

local function on_interrupt(sig)
    interrupted = true
end

-- Must keep reference to prevent garbage collection
local handler = ffi.cast("sighandler_t", on_interrupt)
ffi.C.signal(SIGINT, handler)
```

**User experience**:
```
💡 Press Ctrl+C to gracefully stop (threads will finish current poem)
  Thread  1: [████████░░░░░░░░░░░░] 400/1000 ( 40.0%)
  ...
^C
⚠️ Ctrl+C detected! Waiting for threads to finish current poem...
⏳ Giving threads 5 seconds to complete current work...
⏸️ Similarity calculation interrupted by user
💡 Run again to resume - already-completed files will be skipped
```

---

## TUI Menu Integration (2025-12-21)

**Enhancement**: Replaced simple text menu with full TUI framebuffer menu

The main menu now uses the `/home/ritz/programming/ai-stuff/scripts/libs/menu.lua` TUI library for:
- Interactive vim-style navigation (j/k, arrows)
- Checkbox toggles with keyboard shortcuts
- Flag/numeric input fields
- Dependency-based item enabling/disabling
- Graceful Ctrl+C handling built into TUI (returns "CTRL_C" key event)

**Features**:
- Action selection: Calculate vs Check Status (radio-button style)
- Options section: Force regenerate, Sleep duration, Model name
- Dependencies: Force and Sleep only enabled when Calculate is selected
- Fallback: If TUI unavailable, uses `main_text_mode()` text-based menu

**Usage**: Run with `-I` flag as before - TUI will launch automatically if available.
