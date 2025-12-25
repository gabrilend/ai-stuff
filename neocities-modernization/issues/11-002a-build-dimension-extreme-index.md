# Issue 11-002a: Build Dimension-Extreme Index Infrastructure

## Current Behavior

No infrastructure exists for finding poems that are "extreme" along individual embedding dimensions. The existing similarity infrastructure operates on full 768-dimensional cosine similarity.

## Intended Behavior

Create a pre-computation system that, for each poem, identifies the 768 "dimension-extreme" poems - one per embedding dimension, where each is the poem with the most different value at that specific index.

### Algorithm

```lua
-- For each poem P:
--   For each dimension d in [0, 767]:
--     Find poem Q where |Q.embedding[d] - P.embedding[d]| is maximized
--     Store Q as P's dimension-d extreme

function build_dimension_extremes(poems, embeddings)
    local result = {}

    for poem_id, poem_embedding in pairs(embeddings) do
        result[poem_id] = {}

        for dim = 1, 768 do
            local current_val = poem_embedding[dim]
            local max_diff = 0
            local extreme_id = nil

            for other_id, other_embedding in pairs(embeddings) do
                if other_id ~= poem_id then
                    local diff = math.abs(other_embedding[dim] - current_val)
                    if diff > max_diff then
                        max_diff = diff
                        extreme_id = other_id
                    end
                end
            end

            result[poem_id][dim] = extreme_id
        end
    end

    return result
end
```

### Optimization: Pre-sorted Dimension Lists

Instead of scanning all poems for each dimension lookup, pre-sort poems by each dimension value:

```lua
-- One-time pre-sort: O(768 × n log n)
local sorted_by_dim = {}
for dim = 1, 768 do
    sorted_by_dim[dim] = {}
    for poem_id, embedding in pairs(embeddings) do
        table.insert(sorted_by_dim[dim], {id = poem_id, val = embedding[dim]})
    end
    table.sort(sorted_by_dim[dim], function(a, b) return a.val < b.val end)
end

-- Lookup: O(1) per dimension
-- For poem P with embedding[dim] = v:
--   If v > median: extreme is sorted_by_dim[dim][1] (minimum)
--   If v < median: extreme is sorted_by_dim[dim][#sorted] (maximum)
```

This reduces total complexity from O(n² × 768) to O(768 × n log n + n × 768).

### Output Format

```json
{
    "metadata": {
        "algorithm": "dimension-extreme",
        "dimensions": 768,
        "poem_count": 7793,
        "generated_at": "2025-12-25 12:00:00",
        "embedding_model": "EmbeddingGemma_latest"
    },
    "sorted_dimensions": {
        "1": [4521, 2103, 847, ...],   // poem IDs sorted by dim 1 value (ascending)
        "2": [1892, 5521, 103, ...],   // poem IDs sorted by dim 2 value
        ...
    },
    "extremes": {
        "1": [4521, 1892, 3291, ...],  // poem 1's 768 dimension-extreme IDs
        "2": [847, 5521, 2103, ...],   // poem 2's 768 dimension-extreme IDs
        ...
    }
}
```

**Note**: The `sorted_dimensions` section enables O(1) extreme lookups and can be reused for other analyses.

## Suggested Implementation Steps

### Step 1: Create Dimension Sorting Script
- [ ] Load embeddings.json
- [ ] For each dimension, sort all poems by embedding value
- [ ] Store sorted lists to intermediate file

### Step 2: Create Extreme Computation Script
- [ ] For each poem, use sorted lists to find extremes
- [ ] For each dimension, select min or max based on poem's value
- [ ] Store 768 extreme IDs per poem

### Step 3: Add Progress Reporting
- [ ] Show progress during sorting phase
- [ ] Show progress during extreme computation
- [ ] Display final statistics

### Step 4: Multi-threading Support
- [ ] Parallelize sorting (one thread per dimension chunk)
- [ ] Parallelize extreme computation (one thread per poem batch)

## Computational Analysis

| Phase | Complexity | Estimated Time |
|-------|------------|----------------|
| Load embeddings | O(n × 768) | ~3 seconds |
| Sort dimensions | O(768 × n log n) | ~30 seconds |
| Compute extremes | O(n × 768) | ~10 seconds |
| Write output | O(n × 768) | ~5 seconds |
| **Total** | | **~1 minute** |

## Output File Size

```
sorted_dimensions: 768 dimensions × 7,793 IDs × 4 bytes = 24 MB
extremes: 7,793 poems × 768 IDs × 4 bytes = 24 MB
Total: ~48 MB (can be compressed to ~10 MB with gzip)
```

## Files to Create

- `scripts/precompute-dimension-extremes` (main computation script)
- `src/dimension-extreme-builder.lua` (core algorithm library)

## Dependencies

- `assets/embeddings/EmbeddingGemma_latest/embeddings.json`
- `libs/dkjson.lua`
- `libs/utils.lua`

## Related Issues

- **11-002**: Parent maze system issue
- **11-002b**: Uses output from this issue for similarity filtering

---

**Phase**: 11 (Advanced Exploration)

**Priority**: High (blocks 11-002b, 11-002c, 11-002d)

**Created**: 2025-12-25

**Status**: Open
