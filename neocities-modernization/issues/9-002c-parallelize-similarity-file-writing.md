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

### Option 1: Lua Lanes Library (Recommended)

**Why Lanes over effil:**
- Designed for producer-consumer patterns
- Stable message passing (linda channels)
- Better error handling
- No shared table issues that plagued effil

**Architecture:**
```lua
local lanes = require("lanes").configure()

-- Create writer thread pool once (8 threads)
local function writer_thread(queue_linda, output_dir)
    while true do
        local key, data = queue_linda:receive("work")
        if key == "shutdown" then break end
        utils.write_json_file(data.filepath, data.content)
        queue_linda:send("done", data.poem_index)
    end
end

local writers = {}
local work_queue = lanes.linda()
for i = 1, 8 do
    writers[i] = lanes.gen("*", writer_thread)(work_queue, output_dir)
end

-- Producer: GPU computes and queues work
for i = 0, num_poems - 1 do
    local results = vks_compute_similarities_for_poem(sim_ctx, i, output)
    local data = build_json_data(results, i)
    work_queue:send("work", {filepath=..., content=data, poem_index=i})
end

-- Shutdown
for i = 1, 8 do
    work_queue:send("work", "shutdown")
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

### Step 1: Evaluate Threading Libraries
- [ ] Test Lua Lanes installation and compatibility with LuaJIT
- [ ] Benchmark simple producer-consumer test (1,000 files)
- [ ] Verify no memory leaks or stability issues
- [ ] Compare with process-based approach

### Step 2: Implement Thread Pool Infrastructure
- [ ] Create `libs/thread-pool.lua` - Reusable thread pool library
- [ ] Implement worker spawn, work queue, shutdown protocol
- [ ] Add error propagation from workers to main thread
- [ ] Add progress tracking (completed count)

### Step 3: Integrate with GPU Similarity
- [ ] Modify `vk_similarity.lua` to use thread pool
- [ ] Refactor JSON building into worker function
- [ ] Add queue depth limiting (prevent memory bloat)
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

- Lua Lanes library (or GNU parallel for process-based approach)
- 9-002b (Validation) - Should test sequential version first

## Related Issues

- **9-001f**: Remove effil dependency (this could replace effil uses)
- **8-002**: Multi-threaded HTML generation (similar problem space)
- **9-002b**: Validation testing (should test this optimization)

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
