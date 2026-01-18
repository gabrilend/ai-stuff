# effil Library: Usage Patterns and Antipatterns

## Overview

effil is a multi-threading library for LuaJIT that enables parallel computation through thread spawning and shared data structures. However, it must be used correctly to avoid catastrophic performance degradation.

## The Critical Pattern: Copy effil.table to Local

**RULE**: Always copy `effil.table()` to a local Lua table at worker thread start.

```lua
-- CORRECT: Copy at worker start (used once)
local function worker_thread(shared_data)
    -- Copy effil.table to local table (ONE TIME)
    local local_data = {}
    for k, v in pairs(shared_data) do
        local_data[k] = v
    end

    -- Use local_data for all subsequent access (NO SYNCHRONIZATION)
    for i = 1, 1000 do
        local value = local_data[i]  -- Fast local access
        -- ... do work ...
    end
end

-- WRONG: Access effil.table directly (synchronization on every access)
local function bad_worker_thread(shared_data)
    for i = 1, 1000 do
        local value = shared_data[i]  -- Synchronization overhead! SLOW!
    end
end
```

## Use Cases

### ✅ GOOD: Immutable Data Passed to Independent Workers

**Pattern**: Producer creates data → pass to worker → worker processes independently

**Examples**:
1. **File Writing** (Issue 9-002c)
   ```lua
   for i = 1, num_files do
       local data = generate_data(i)
       local shared = effil.table(data)  -- Immutable copy
       spawn_writer(shared)              -- Worker writes file independently
   end
   ```
   - GPU computes similarities → pass to writer → writer writes JSON
   - Each file is independent (no shared state between workers)
   - Proven in `generate-html-parallel`

2. **HTML Generation** (`scripts/generate-html-parallel`)
   ```lua
   local shared_poems = effil.table(all_poems)
   local shared_colors = effil.table(poem_colors)

   for poem in poems do
       spawn_worker(shared_poems, shared_colors, poem)
   end
   ```
   - Worker copies effil.table to local at start (lines 213, 342, 556)
   - Worker generates HTML using local copies (fast)
   - No synchronization during HTML generation

**Why it works**:
- Data passed once, copied once
- Workers operate independently
- No contention, no synchronization overhead

### ❌ BAD: Constantly Mutating Shared State

**Pattern**: Multiple threads update shared data structure continuously

**Example**: Diversity cache pre-computation (Issue 9-001f)
```lua
-- BAD: Shared centroid updated 7,796 times per sequence
local shared_centroid = effil.table()
local shared_mask = effil.table()

for i = 1, 7797 do  -- Per sequence
    for iteration = 1, 7796 do  -- Per iteration
        -- Update shared centroid (SYNCHRONIZATION!)
        shared_centroid[dim] = new_value

        -- Update shared mask (SYNCHRONIZATION!)
        shared_mask[poem_idx] = 0
    end
end
-- Result: 60 million updates × synchronization overhead = ~17 billion ops
-- Time: 42+ hours (vs GPU: 58 seconds)
```

**Why it fails**:
- effil.table access requires inter-thread synchronization
- Each read/write locks the table
- 60 million updates = catastrophic overhead
- CPU-bound synchronization defeats parallelism

**Solution**: Move state to GPU (Issue 9-001g)
```lua
-- GPU maintains centroids, masks internally (no CPU synchronization)
vkd_batch_compute(embeddings, num_poems)  -- All state on GPU
-- Result: 58 seconds (996× speedup)
```

## Performance Characteristics

### effil.table() Access Cost

| Operation | Cost | When to Use |
|-----------|------|-------------|
| Create effil.table(data) | ~100 μs | Once per worker spawn |
| Copy to local table | ~50 μs per 1,000 elements | Once at worker start |
| Access effil.table directly | ~1-10 μs per access | **NEVER** (use local copy) |
| Access local table | ~10 ns per access | Always (after copy) |

**Speedup from copying**: 100-1,000× faster access after one-time copy.

### Threading Overhead

| Operation | Cost | Notes |
|-----------|------|-------|
| Spawn effil.thread() | ~500 μs | Use thread pool to amortize |
| thread:get() blocking | ~10 μs | Minimal if worker is done |
| thread:get(0) non-blocking | ~1 μs | Use for polling |
| effil.sleep(0.001) | 1 ms | Use when polling for completed threads |

## Decision Tree: Should I Use effil?

```
Is this a multi-threaded task?
├─ NO → Use single-threaded code
└─ YES → Continue

Do threads need to share mutable state?
├─ YES → ❌ DON'T use effil
│         → Move computation to GPU (if vector ops)
│         → Use process-based parallelism (if I/O bound)
│         → Use message passing (if small updates)
└─ NO → Continue

Are threads doing independent work on immutable data?
├─ YES → ✅ USE effil
│         → Pass data via effil.table()
│         → Copy to local at worker start
│         → Workers operate independently
└─ NO → Reconsider architecture
```

## Common Patterns

### Pattern 1: Thread Pool for File I/O

```lua
local active_threads = {}
local max_concurrent = 8

for i = 1, num_tasks do
    local task_data = prepare_task(i)
    local shared_data = effil.table(task_data)

    -- Wait for slot if pool is full
    while #active_threads >= max_concurrent do
        reap_completed_threads(active_threads)
        if #active_threads >= max_concurrent then
            effil.sleep(0.001)
        end
    end

    -- Spawn worker
    table.insert(active_threads, effil.thread(worker)(shared_data))
end

-- Wait for all
for _, thread in ipairs(active_threads) do
    thread:get()
end
```

### Pattern 2: Batch Processing with Workers

```lua
local BATCH_SIZE = 100

for batch_start = 1, num_items, BATCH_SIZE do
    local batch_data = prepare_batch(batch_start, BATCH_SIZE)
    local shared_batch = effil.table(batch_data)

    -- Spawn workers for batch
    local workers = {}
    for i = 1, 8 do
        workers[i] = effil.thread(batch_worker)(shared_batch, i, 8)
    end

    -- Wait for batch completion
    for _, worker in ipairs(workers) do
        worker:get()
    end
end
```

## Antipatterns

### ❌ Antipattern 1: Direct effil.table Access in Loop

```lua
-- BAD: Synchronization on every iteration
local shared_data = effil.table(large_array)
local function bad_worker(shared)
    for i = 1, 10000 do
        local val = shared[i]  -- SLOW! (10,000 synchronizations)
    end
end

-- GOOD: Copy once, access locally
local function good_worker(shared)
    local local_data = {}
    for k, v in pairs(shared) do local_data[k] = v end

    for i = 1, 10000 do
        local val = local_data[i]  -- FAST! (no synchronization)
    end
end
```

### ❌ Antipattern 2: Shared Accumulator

```lua
-- BAD: Multiple threads updating shared counter
local shared_sum = effil.table({total = 0})

local function bad_worker(shared, start, stop)
    for i = start, stop do
        shared.total = shared.total + compute(i)  -- RACE CONDITION!
    end
end

-- GOOD: Each worker computes partial, main thread sums
local function good_worker(start, stop)
    local partial_sum = 0
    for i = start, stop do
        partial_sum = partial_sum + compute(i)
    end
    return partial_sum  -- Return via thread:get()
end

-- Main thread
local total = 0
for _, thread in ipairs(threads) do
    local partial = thread:get()
    total = total + partial  -- Single-threaded aggregation
end
```

### ❌ Antipattern 3: Shared Work Queue

```lua
-- BAD: Workers pulling from shared queue (contention)
local shared_queue = effil.table({1, 2, 3, ..., 1000})

local function bad_worker(queue)
    while #queue > 0 do
        local item = table.remove(queue, 1)  -- Lock contention!
        process(item)
    end
end

-- GOOD: Pre-assign work to workers (no sharing)
local function good_worker(items)
    local local_items = {}
    for k, v in pairs(items) do local_items[k] = v end

    for _, item in ipairs(local_items) do
        process(item)
    end
end

-- Partition work upfront
for i = 1, 8 do
    local worker_items = get_partition(all_items, i, 8)
    local shared_items = effil.table(worker_items)
    threads[i] = effil.thread(good_worker)(shared_items)
end
```

## Related Issues

- **Issue 9-001f**: Remove effil dependency (may be obsolete)
- **Issue 9-001g**: Batch parallel diversity (why effil failed, GPU succeeded)
- **Issue 9-002c**: Parallelize file writing (correct effil use case)
- **Issue 8-002**: Multi-threaded HTML generation (effil success story)

## Conclusion

effil is a **useful tool when used correctly**:
- ✅ Immutable data passed to independent workers
- ✅ One-time copy to local at worker start
- ✅ No shared mutable state

effil is **catastrophically slow when misused**:
- ❌ Constantly mutating shared state
- ❌ Direct access to effil.table in loops
- ❌ Lock contention between threads

**General principle**: If threads need to share mutable state, effil is the wrong tool. Use GPU computation, process-based parallelism, or message passing instead.
