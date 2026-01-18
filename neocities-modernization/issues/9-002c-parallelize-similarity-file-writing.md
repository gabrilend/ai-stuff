# Issue 9-002c: Parallelize Similarity File Writing with Thread Pool

## Parent Issue
9-002: Port Similarity Matrix Generation to Vulkan

## Current Behavior

GPU similarity computation in `vk_similarity.lua` processes poems sequentially:

```lua
for i = 0, num_poems - 1 do
    -- GPU computes similarities (FAST: ~2ms)
    vks_compute_similarities_for_poem(sim_ctx, i, output_similarities)

    -- Build JSON data structure (MEDIUM: ~0.5ms)
    local data = {metadata = {...}, similarities = {...}}

    -- Write JSON file (SLOW: ~5ms, I/O bound)
    utils.write_json_file(output_file, data)
end
```

**Bottleneck Analysis:**
- GPU computation: ~2ms per poem (25% of time)
- JSON building: ~0.5ms per poem (7% of time)
- File writing: ~5ms per poem (**68% of time - BOTTLENECK**)
- Total: ~7.5ms × 7,797 poems = **~58 seconds**

**Problem:** GPU sits idle 68% of the time waiting for single-threaded file I/O to complete.

## Intended Behavior

Use a thread pool to parallelize file writing while GPU continues computing:

```lua
[GPU Thread]              [Writer Thread Pool - 8 threads]
GPU Compute (2ms) ─────→  Queue → Thread 1: Write file A (5ms)
GPU Compute (2ms) ─────→  Queue → Thread 2: Write file B (5ms)
GPU Compute (2ms) ─────→  Queue → Thread 3: Write file C (5ms)
GPU Compute (2ms) ─────→  Queue → Thread 4: Write file D (5ms)
                                  ... (8 threads write in parallel)
```

**Expected Performance:**
- GPU keeps computing without waiting
- 8 parallel writers handle file I/O
- Effective file write time: ~5ms / 8 = ~0.625ms per poem
- **Total: ~2.6ms × 7,797 poems = ~20 seconds (3× speedup!)**

## Root Cause Analysis

Modern SSDs support concurrent I/O operations through:
1. **Multiple NAND chips** - Can write to different chips simultaneously
2. **Internal command queuing** - Optimizes write ordering and parallelism
3. **Write caching** - Batches and reorders small writes

Sequential file writing uses only ~10% of SSD throughput. Concurrent writes saturate the disk's internal parallelism.

## Implementation Options

### Option 1: effil Thread Pool (Recommended)

**Why effil is suitable for this use case:**

effil had catastrophic performance with diversity cache because of **constantly mutating shared state** (centroids, masks updated 60M times). File writing is fundamentally different:

✅ **Good for file writing:** Immutable data passed once to worker
- GPU produces results → copy to effil.table → worker reads once → writes file
- Each worker writes independent files (no shared state)
- Proven pattern in `generate-html-parallel` (lines 213, 342, 556)

❌ **Bad for diversity cache:** Mutable shared state accessed continuously
- effil.table synchronization on every centroid/mask update
- ~17 billion synchronization operations
- CPU-GPU data transfer already moves state to GPU

**Architecture (following generate-html-parallel pattern):**
```lua
local effil = require("effil")

-- Worker thread: Copy effil.table to local at start (CRITICAL)
local function writer_thread(poem_data_shared, output_dir)
    -- Copy effil.table to local Lua table (one-time, at worker start)
    local poem_data = {}
    for k, v in pairs(poem_data_shared) do
        poem_data[k] = v
    end

    -- Write file using local data (no effil synchronization)
    local filepath = string.format("%s/poem_index_%d.json", output_dir, poem_data.poem_index)
    utils.write_json_file(filepath, poem_data)

    return poem_data.poem_index  -- Return for progress tracking
end

-- Producer: GPU computes and spawns workers
local active_threads = {}
local max_concurrent = 8

for i = 0, num_poems - 1 do
    -- GPU computes similarities (FAST)
    local results = vks_compute_similarities_for_poem(sim_ctx, i, output)

    -- Build JSON data in local table
    local poem_data = build_json_data(results, i)

    -- Copy to effil.table (immutable, passed to worker)
    local shared_data = effil.table(poem_data)

    -- Spawn worker (or wait if pool full)
    while #active_threads >= max_concurrent do
        -- Wait for a thread to complete
        for j = #active_threads, 1, -1 do
            local status, result = active_threads[j]:get(0)  -- Non-blocking check
            if status ~= nil then
                table.remove(active_threads, j)
            end
        end
        if #active_threads >= max_concurrent then
            effil.sleep(0.001)  -- 1ms sleep
        end
    end

    -- Spawn new writer
    table.insert(active_threads, effil.thread(writer_thread)(shared_data, output_dir))
end

-- Wait for all to complete
for _, thread in ipairs(active_threads) do
    thread:get()
end
```

### Option 2: Process-Based Parallelism (No dependencies)

**Architecture:**
```lua
-- GPU computes and writes to temp directory with raw data
for i = 0, num_poems - 1 do
    local results = vks_compute_similarities_for_poem(sim_ctx, i, output)
    -- Write raw binary to /tmp/similarity-queue/poem_<i>.bin
    write_binary_file(string.format("/tmp/similarity-queue/poem_%d.bin", i), results)
end

-- Spawn 8 parallel processes to convert binary → JSON
os.execute([[
    parallel -j 8 'lua convert_to_json.lua {} assets/embeddings/model/similarities/' ::: /tmp/similarity-queue/*.bin
]])
```

**Benefits:**
- No threading library dependency
- Simple error handling (exit codes)
- Each process is independent

**Drawbacks:**
- Requires GNU parallel or custom fork/exec
- Double I/O (write binary, read binary, write JSON)
- More disk usage

### Option 3: Batch GPU Computation (Hybrid approach)

Compute multiple poems on GPU, then write batch in parallel:

```lua
local BATCH_SIZE = 100

for batch_start = 0, num_poems, BATCH_SIZE do
    -- GPU computes batch of 100 poems
    local batch_results = vks_compute_similarities_batch(sim_ctx, batch_start, BATCH_SIZE)

    -- Distribute batch across 8 writer threads
    for i = 1, 8 do
        local thread_work = get_slice(batch_results, i, 8)
        writers[i]:send("work", thread_work)
    end

    -- Wait for batch completion before next GPU batch
    wait_for_all_threads()
end
```

**Benefits:**
- Clear synchronization points (per batch)
- Limits queue size (100 pending writes max)
- Easier error handling and progress tracking

## Implementation Steps

### Step 1: Design effil Thread Pool
- [ ] Study `generate-html-parallel` effil usage pattern
- [ ] Implement thread pool with max_concurrent limit
- [ ] Add non-blocking thread status checking
- [ ] Test with small dataset (100 poems)

### Step 2: Integrate with GPU Similarity
- [ ] Refactor `vk_similarity.lua` to use effil thread pool
- [ ] Implement critical pattern: Copy effil.table to local at worker start
- [ ] Add thread pool management (spawn, wait, reap completed)
- [ ] Add error propagation from workers to main thread

### Step 3: Optimize Thread Pool Management
- [ ] Implement efficient thread reaping (non-blocking checks)
- [ ] Add queue depth limiting (max 8 concurrent threads)
- [ ] Tune effil.sleep() duration for optimal throughput
- [ ] Implement graceful shutdown on GPU errors

### Step 4: Benchmark and Optimize
- [ ] Benchmark with 1, 2, 4, 8, 16 threads
- [ ] Find optimal thread count for your SSD
- [ ] Measure actual speedup on full dataset
- [ ] Profile for bottlenecks

### Step 5: Configuration and Documentation
- [ ] Add `--writer-threads N` flag to run.sh
- [ ] Document performance characteristics
- [ ] Update Phase 9 progress with results

## Quality Assurance Criteria

- [ ] Thread pool implementation complete
- [ ] No memory leaks under sustained load
- [ ] Error handling preserves all error messages
- [ ] Progress reporting shows accurate ETA
- [ ] Output files identical to sequential version
- [ ] At least 2× speedup over sequential writing
- [ ] Graceful shutdown on Ctrl+C or errors

## Expected Performance

### Current (Sequential)
```
GPU: 2ms  }
JSON: 0.5ms } = 7.5ms per poem
Write: 5ms  }

Total: 7.5ms × 7,797 = ~58 seconds
```

### Optimized (8-thread pool)
```
GPU: 2ms (continuous, no waiting)
JSON + Write: 8 parallel workers → ~0.625ms effective

Total: 2.6ms × 7,797 = ~20 seconds
Speedup: 2.9×
```

### Optimized (16-thread pool, if SSD supports)
```
GPU: 2ms
JSON + Write: 16 parallel workers → ~0.3ms effective

Total: 2.3ms × 7,797 = ~18 seconds
Speedup: 3.2×
```

## Dependencies

- effil library (already in project)
- 9-002b (Validation) - Should test sequential version first

## Related Issues

- **9-001f**: Remove effil dependency (OBSOLETE - effil is suitable for this pattern)
- **8-002**: Multi-threaded HTML generation (uses same effil pattern)
- **9-002b**: Validation testing (should test this optimization)

**Note on Issue 9-001f:** The "remove effil dependency" issue was created due to diversity cache performance problems. However, that was a misuse of effil (constantly mutating shared state). For immutable data passed to independent workers (like file writing), effil is appropriate and already proven in `generate-html-parallel`. Issue 9-001f should be closed or revised to "Use effil correctly."

## Related Files

- `libs/vulkan-compute/lua/vk_similarity.lua` - Current implementation
- `scripts/generate-html-parallel` - Uses effil for similar problem
- `libs/thread-pool.lua` - New file to create

---

**ISSUE STATUS: OPEN**

**Created**: 2026-01-17

**Phase**: 9 (GPU Acceleration)

**Priority**: Medium (performance optimization, not a blocker)

**Estimated Effort**: 4-6 hours (if using Lanes), 2-3 hours (if using process-based)
