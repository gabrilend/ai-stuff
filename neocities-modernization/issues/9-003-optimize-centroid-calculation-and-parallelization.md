# Issue 9-003: Optimize Centroid Calculation and Parallelization

## Current Behavior

The diversity sequence computation in `scripts/precompute-diversity-sequences` and `scripts/generate-html-parallel` recalculates the centroid from scratch at every iteration:

```lua
-- Current: O(N × 768) per iteration where N grows from 1 to 7,792
local function calculate_centroid(embeddings_list)
    for _, emb in ipairs(embeddings_list) do      -- O(N) loop
        for i = 1, dim do                          -- O(768) per embedding
            centroid[i] = centroid[i] + emb[i]
        end
    end
    for i = 1, dim do
        centroid[i] = centroid[i] / #embeddings_list
    end
end
```

**Total centroid calculation cost per sequence:**
- Sum of (1 + 2 + 3 + ... + 7,792) × 768 = ~23.3 billion floating-point operations

**Current parallelization model:**
- Each thread computes ONE complete sequence independently
- Threads don't share work within a sequence
- Results written to temp files on disk (SSD wear, I/O overhead)

## Intended Behavior

### Optimization 1: Incremental Running Sum (No Division)

Maintain a running sum instead of recalculating from scratch:

```lua
-- Optimized: O(768) per iteration
local running_sum = {}
for i = 1, 768 do running_sum[i] = starting_embedding[i] end

-- When finding most distant poem, use running_sum directly
-- (cosine distance is scale-invariant, so no division needed!)
local dist = cosine_distance(running_sum, candidate_embedding)

-- When adding a new poem:
for i = 1, 768 do
    running_sum[i] = running_sum[i] + selected_embedding[i]
end
```

**Why no division is needed:**
Cosine similarity: `cos(A,B) = (A·B) / (||A|| × ||B||)`
Scaling A by constant k: `cos(kA,B) = k(A·B) / (k||A|| × ||B||) = cos(A,B)`
The constant cancels out, so `sum` gives same ranking as `sum/count`.

**New cost per sequence:**
- 7,792 iterations × 768 additions = ~6 million operations
- **Speedup: ~4,000× for centroid maintenance**

### Optimization 2: Parallel Distance Comparisons Within Sequence

Instead of each thread handling a separate starting poem, parallelize the distance comparisons within a single sequence:

```lua
-- Main thread orchestrates, workers split comparison work
for iteration = 1, 7792 do
    local current_sum = running_sum  -- Shared read

    -- Split remaining poems across K workers
    local local_maxes = parallel_map(workers, function(worker_id)
        local my_start = (worker_id - 1) * chunk_size + 1
        local my_end = math.min(worker_id * chunk_size, #remaining)

        local max_dist, max_idx = -1, -1
        for i = my_start, my_end do
            local dist = cosine_distance(current_sum, remaining[i].embedding)
            if dist > max_dist then
                max_dist, max_idx = dist, i
            end
        end
        return {dist = max_dist, idx = max_idx}
    end)

    -- Main thread: find global max from local maxes
    local global_max = reduce(local_maxes, function(a, b)
        return a.dist > b.dist and a or b
    end)

    -- Update running sum (only main thread writes)
    local selected = remaining[global_max.idx]
    for i = 1, 768 do
        running_sum[i] = running_sum[i] + selected.embedding[i]
    end
    table.remove(remaining, global_max.idx)
end
```

**Benefits:**
- K threads = ~K× speedup on the O(remaining × 768) bottleneck
- Main thread is O(768) for updates, O(K) for max reduction
- With 8 threads: ~8× faster distance comparisons

### Optimization 3: Eliminate Temp Files (RAM-Only)

Store results in RAM instead of writing to disk:
- Avoid SSD write wear
- Eliminate filesystem overhead
- Use effil.channel or shared tables for result collection

## Suggested Implementation Steps

### Phase A: Incremental Running Sum (Standalone) ✅ COMPLETED

- [x] Modify `calculate_centroid()` to maintain running sum
- [x] Remove division (use sum directly for cosine distance)
- [ ] Verify correctness: same sequence output as before (pending full test run)
- [ ] Benchmark: measure time per sequence before/after

**Implementation Notes (2025-12-23):**
- Worker function now maintains `running_sum` table initialized from starting poem
- Distance calculation uses raw sum: `cosine_distance(running_sum, candidate_embedding)`
- After selecting max-distance poem, running sum updated with O(768) operation:
  ```lua
  for i = 1, embedding_dim do
      running_sum[i] = running_sum[i] + selected_embedding[i]
  end
  ```

### Phase B: Parallel Distance Comparisons

- [ ] Create worker pool for distance calculations
- [ ] Implement chunk-based distribution of remaining poems
- [ ] Add synchronization for global max finding
- [ ] Benchmark: measure speedup with different thread counts

**Note:** This optimization is deferred pending GPU acceleration work (Issue 9-001).
The current model of one thread per starting poem remains effective.

### Phase C: RAM-Only Storage ✅ COMPLETED

- [x] Replace temp file writes with effil thread `:get()` return values
- [x] Collect all sequences in main thread memory
- [x] Write single output file at end
- [x] Verify no temp files created during execution

**Implementation Notes (2025-12-23):**
- Worker function returns sequence directly via `return sequence`
- Main thread collects results via `thread:get()` which blocks until thread completes
- All sequences accumulated in `all_results` table in RAM
- Single JSON write to `diversity_sequences.json` at end

### Phase D: Per-Thread File I/O ✅ COMPLETED (New Optimization)

- [x] Eliminate effil.table conversion bottleneck (was 30-60 seconds)
- [x] Each worker thread loads embeddings.json independently
- [x] OS file cache ensures subsequent reads are fast

**Implementation Notes (2025-12-23):**
- Worker signature changed: receives file path instead of effil.table
- Each thread parses 62MB JSON independently (OS caches after first read)
- Eliminated `effil.table()` conversion which was copying 5M+ values

## Complexity Analysis

| Operation | Current | Optimized |
|-----------|---------|-----------|
| Centroid update | O(N × 768) | O(768) |
| Distance comparisons | O(remaining × 768) | O(remaining × 768 / K) |
| File I/O per sequence | 1 write + 1 read | 0 |
| Total per sequence | O(N² × 768) | O(N × 768 / K) |

With K=8 threads and incremental centroid:
- Current: ~42 hours for 7,793 sequences
- Optimized: ~1-2 hours estimated

## Mathematical Proof: Scale Invariance of Cosine Distance

For vectors A and B, cosine similarity is:
```
cos(A, B) = (A · B) / (||A|| × ||B||)
```

For scaled vector kA (where k is any positive scalar):
```
cos(kA, B) = (kA · B) / (||kA|| × ||B||)
           = k(A · B) / (k||A|| × ||B||)
           = (A · B) / (||A|| × ||B||)
           = cos(A, B)
```

Therefore, dividing the running sum by the count has no effect on which poem is selected as "most distant." We can use the raw sum.

## Related Issues

- **Issue 9-001**: Implement Vulkan compute infrastructure (GPU acceleration)
- **Issue 9-002**: Port similarity matrix to Vulkan
- **Issue 9-003a**: Remove unnecessary division from source files (sub-issue)
- **Issue 8-002**: Implement multi-threaded HTML generation (current threading model)

## Sub-Issues

- **9-003a**: The original `calculate_embedding_centroid()` in `src/flat-html-generator.lua` and `calculate_ultra_centroid()` in `src/centroid-generator.lua` still contain the unnecessary division. Created 2025-12-25 to address code consistency.

## Files to Modify

- `scripts/precompute-diversity-sequences` (lines 70-141)
- `scripts/generate-html-parallel` (lines 320-410)

## Dependencies

- effil library for Lua multithreading
- No new dependencies required

---

**Phase**: 9 (GPU Acceleration) - though Phase A can be implemented independently

**Priority**: High (significant performance improvement with modest code changes)

**Created**: 2025-12-23

**Status**: In Progress (Phase A, C, D complete; Phase B deferred to GPU work)

**Last Updated**: 2025-12-23
