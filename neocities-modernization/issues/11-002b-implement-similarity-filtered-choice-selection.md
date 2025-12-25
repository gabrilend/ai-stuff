# Issue 11-002b: Implement Similarity-Filtered Choice Selection

## Current Behavior

Issue 11-002a produces 768 dimension-extreme candidates per poem. These candidates are each "opposite" along one embedding dimension, but may vary widely in overall similarity to the source poem.

## Intended Behavior

From the 768 dimension-extreme candidates, select the 3-6 that are **most similar overall** to the source poem. This creates "variations on a theme" - poems that are almost the same, except for ONE thing.

### Algorithm

```lua
function select_maze_exits(poem_id, dimension_extremes, embeddings, num_exits)
    num_exits = num_exits or 6

    -- Get the 768 dimension-extreme candidates
    local candidates = dimension_extremes[poem_id]
    local source_embedding = embeddings[poem_id]

    -- Compute full cosine similarity for each candidate
    local scored = {}
    local seen = {}  -- Deduplicate (same poem may be extreme for multiple dims)

    for dim, candidate_id in ipairs(candidates) do
        if not seen[candidate_id] then
            seen[candidate_id] = true
            local candidate_embedding = embeddings[candidate_id]
            local similarity = cosine_similarity(source_embedding, candidate_embedding)
            table.insert(scored, {id = candidate_id, similarity = similarity, dim = dim})
        end
    end

    -- Sort by similarity (descending) and take top N
    table.sort(scored, function(a, b) return a.similarity > b.similarity end)

    local exits = {}
    for i = 1, math.min(num_exits, #scored) do
        table.insert(exits, scored[i].id)
    end

    return exits
end
```

### Deduplication Consideration

Multiple dimensions may point to the same extreme poem. For example, if poem Q is extreme for both dimension 47 and dimension 203, it should only appear once in the candidate pool.

Expected unique candidates: ~400-600 (some dimensions will share extremes)

### Output Format

```json
{
    "metadata": {
        "algorithm": "dimension-extreme-similarity-filtered",
        "dimensions": 768,
        "exits_per_poem": 6,
        "generated_at": "2025-12-25 12:00:00"
    },
    "exits": {
        "1": [423, 1847, 3291, 892, 5521, 2103],
        "2": [1502, 847, 4421, 3892, 721, 6103],
        ...
    }
}
```

This is the final cache used by the HTML generator.

## Suggested Implementation Steps

### Step 1: Load Dimension Extremes
- [ ] Load output from 11-002a
- [ ] Load embeddings for similarity computation

### Step 2: Implement Cosine Similarity
- [ ] Reuse existing cosine similarity function from similarity-engine
- [ ] Or implement standalone for this module

### Step 3: Filter and Select Exits
- [ ] For each poem, deduplicate 768 candidates
- [ ] Compute similarity for each unique candidate
- [ ] Sort and select top 6

### Step 4: Write Final Cache
- [ ] Output `dimension_maze_cache.json`
- [ ] Include metadata for cache invalidation

## Computational Analysis

| Operation | Complexity | Time |
|-----------|------------|------|
| Load dimension extremes | O(n × 768) | ~2s |
| Deduplicate per poem | O(768) | negligible |
| Cosine similarity (768 dims) | O(768) per candidate | |
| Total similarities | O(n × ~500 × 768) | ~2 minutes |
| Sort and select | O(n × 500 log 500) | ~5s |
| **Total** | | **~3 minutes** |

## Configurable Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `NUM_EXITS` | 6 | Choices per poem |
| `MIN_SIMILARITY` | 0.5 | Discard candidates below this threshold |

## Edge Cases

### Case 1: Fewer than 6 unique candidates
- Should not happen (768 dimensions should produce many unique extremes)
- Fallback: use all available candidates

### Case 2: Very similar poem pairs
- If top candidates are all >0.99 similar, user choices may feel identical
- Acceptable: the subtle differences are the point

### Case 3: Isolated poems
- Poems with unusual embeddings may have low similarity to all extremes
- Acceptable: these become "frontier rooms" in the maze

## Files to Create

- `src/maze-choice-selector.lua` (selection algorithm)
- Extend `scripts/precompute-dimension-extremes` to include this step

## Dependencies

- Output from 11-002a (`dimension_extremes.json` or similar)
- `assets/embeddings/EmbeddingGemma_latest/embeddings.json`

## Related Issues

- **11-002a**: Provides input (768 dimension extremes per poem)
- **11-002c**: Consumes output (6 exits per poem for HTML generation)

---

**Phase**: 11 (Advanced Exploration)

**Priority**: High (blocks 11-002c)

**Created**: 2025-12-25

**Status**: Open

**Depends On**: 11-002a
