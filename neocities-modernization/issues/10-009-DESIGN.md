# Issue 10-009 Design Document: Incremental Centroid Updates for Dataset Expansion

**Created**: 2026-01-12
**Status**: Design Phase

## Building on Existing Infrastructure

### What Already Exists (Issue 8-027)

The diversity cache system ALREADY supports incremental extension:
- **Cache format**: Stores ordered poem ID sequences for each anchor
- **Extension algorithm**: Can extend 1000 → 1500 by reconstructing running sum
- **Running sum reconstruction**: `sum = Σ embeddings[sequence[0..N]]`
- **Continuation**: Resumes algorithm from position N+1

**File**: `/output/diversity-cache-gpu-batch.bin` (232 MB)

### What's New (Issue 10-009)

Issue 10-009 adds support for **dataset expansion** (new poems added):
- **New use case**: Not just extending sequences, but inserting new poems
- **Challenge**: New poems may belong in the MIDDLE of existing sequences
- **Solution**: "Unwind" to insertion point, insert new poems, recalculate forward

## Algorithm Design

### Phase 1: Identify Affected Anchor Poems

When new poems are added to the dataset:

```lua
function identify_affected_anchors(new_poems, similarity_threshold)
  affected_anchors = {}

  for each anchor_poem in dataset do
    for each new_poem in new_poems do
      -- Calculate similarity between anchor and new poem
      similarity = cosine_similarity(
        embeddings[anchor_poem],
        embeddings[new_poem]
      )

      -- If new poem is highly similar to anchor, it will appear early in sequence
      -- If dissimilar, it will appear late or not affect the sequence much
      if similarity > similarity_threshold then
        affected_anchors[anchor_poem] = true
        break
      end
    end
  end

  return affected_anchors
end
```

**Optimization**: Most anchors won't be affected by new poems that are dissimilar.

### Phase 2: Find Insertion Points

For each affected anchor, determine where new poems fit:

```lua
function find_insertion_points(anchor_id, existing_sequence, new_poems)
  insertion_points = {}

  -- Reconstruct centroids at each position
  running_sum = zero_vector(768)
  count = 0

  for position = 1, #existing_sequence do
    -- Update running sum with poem at this position
    poem_id = existing_sequence[position]
    running_sum = running_sum + embeddings[poem_id]
    count = count + 1

    centroid = running_sum / count

    -- Check if any new poems would be selected at this point
    for each new_poem in new_poems do
      distance = cosine_distance(embeddings[new_poem], centroid)

      -- Would this new poem be selected instead of the existing poem?
      if distance > threshold then
        -- Mark this as an insertion point
        insertion_points[position] = {new_poem}
      end
    end
  end

  return insertion_points
end
```

### Phase 3: Recalculate from Insertion Point

Once we know where new poems fit, recalculate only the affected portion:

```lua
function update_sequence_with_new_poems(anchor_id, existing_sequence, insertion_points)
  -- Find earliest insertion point
  first_insertion = min(keys(insertion_points))

  -- Keep the unaffected prefix
  updated_sequence = existing_sequence[1 .. first_insertion - 1]

  -- Reconstruct running sum up to insertion point
  running_sum = zero_vector(768)
  for i = 1, first_insertion - 1 do
    running_sum = running_sum + embeddings[existing_sequence[i]]
  end
  count = first_insertion - 1

  -- Create pool of remaining poems (old + new)
  remaining_poems = {}
  for i = first_insertion, #existing_sequence do
    remaining_poems[existing_sequence[i]] = true
  end
  for _, new_poem in ipairs(new_poems) do
    remaining_poems[new_poem] = true
  end

  -- Continue diversity algorithm from insertion point
  while count < #remaining_poems do
    centroid = running_sum / count

    -- Find poem with maximum distance from centroid
    max_distance = -1
    selected_poem = nil
    for poem_id in pairs(remaining_poems) do
      distance = cosine_distance(embeddings[poem_id], centroid)
      if distance > max_distance then
        max_distance = distance
        selected_poem = poem_id
      end
    end

    -- Add to updated sequence
    updated_sequence[#updated_sequence + 1] = selected_poem
    remaining_poems[selected_poem] = nil
    running_sum = running_sum + embeddings[selected_poem]
    count = count + 1
  end

  return updated_sequence
end
```

## Storage Design

### Option A: Implicit Memory (Current Approach)

```json
{
  "metadata": {
    "algorithm_version": "centroid-v1-incremental",
    "supports_unwinding": true
  },
  "sequences": {
    "123": [456, 789, 234, ...],  // Ordered poem IDs
    "456": [123, 890, 345, ...],
    ...
  }
}
```

**Advantages**:
- ✅ Already implemented (Issue 8-027)
- ✅ Minimal storage overhead (232 MB for 7,797 sequences)
- ✅ Can reconstruct running sum from sequence

**Disadvantages**:
- ❌ Must recalculate centroids to find insertion points (O(N × 768) per anchor)
- ❌ Can't skip unaffected portions without testing

### Option B: Explicit Centroid Checkpoints

```json
{
  "sequences": {
    "123": {
      "poems": [456, 789, 234, ...],
      "checkpoints": {
        "100": [0.1, 0.2, ..., 0.768],  // Centroid at position 100
        "200": [0.15, 0.22, ..., 0.7],  // Centroid at position 200
        ...
      }
    }
  }
}
```

**Advantages**:
- ✅ Faster insertion point finding (skip to nearest checkpoint)
- ✅ Reduced computation for large sequences

**Disadvantages**:
- ❌ Significant storage overhead (~50 MB per 100-poem checkpoint × 78 checkpoints × 7,797 anchors = ~30 GB)
- ❌ Complexity in maintaining checkpoints

### Option C: Hybrid Approach (Recommended)

Use **implicit memory** (Option A) with **smart filtering**:

```lua
-- Don't check all anchors - pre-filter by similarity
affected_anchors = identify_affected_anchors(new_poems, threshold=0.7)

-- Only recalculate these anchors (likely < 5% of total)
-- For 100 new poems with 0.7 similarity threshold:
--   Estimated affected: ~400 anchors (5% of 7,797)
--   Computation: 400 × 10 minutes = ~67 hours
--   vs full regeneration: 7,797 × 10 minutes = ~1,300 hours
--   Speedup: 19x
```

## Implementation Phases

### Phase 1: Proof of Concept (Single Anchor)
- [ ] Implement running sum reconstruction from sequence
- [ ] Test insertion point detection for one anchor
- [ ] Validate updated sequence matches full recalculation
- **Time estimate**: 1-2 days

### Phase 2: Batch Processing
- [ ] Implement affected anchor identification
- [ ] Parallelize updates across multiple anchors (effil or GPU batch)
- [ ] Add progress tracking and resume capability
- **Time estimate**: 3-5 days

### Phase 3: Integration with Pipeline
- [ ] Add `--incremental` flag to precompute-diversity-sequences
- [ ] Detect new poems automatically (compare embeddings directory)
- [ ] Update run.sh to use incremental mode when available
- **Time estimate**: 2-3 days

### Phase 4: Validation and Testing
- [ ] Compare incremental vs full regeneration results
- [ ] Measure actual performance improvements
- [ ] Test edge cases (many new poems, highly similar poems)
- **Time estimate**: 2-3 days

**Total estimated time**: 8-13 days

## Performance Estimates

### Scenario: 100 New Poems Added

| Metric | Full Regeneration | Incremental Update | Speedup |
|--------|------------------|-------------------|---------|
| Anchors processed | 7,797 | ~400 (5%) | 19x fewer |
| Computation time | ~54 hours | ~3 hours | 18x faster |
| Storage overhead | 0 MB | 0 MB | Same |

### Scenario: 1,000 New Poems Added

| Metric | Full Regeneration | Incremental Update | Speedup |
|--------|------------------|-------------------|---------|
| Anchors processed | 7,797 | ~2,000 (25%) | 4x fewer |
| Computation time | ~54 hours | ~14 hours | 4x faster |
| Storage overhead | 0 MB | 0 MB | Same |

**Key insight**: Speedup depends on how many anchors are affected. Dissimilar new poems → fewer affected anchors → greater speedup.

## Success Criteria

- [ ] Incremental updates produce identical results to full regeneration
- [ ] 10x+ speedup for datasets with < 100 new poems
- [ ] 3x+ speedup for datasets with < 1,000 new poems
- [ ] Zero additional storage overhead
- [ ] Automatic detection of when incremental update is possible
- [ ] Graceful fallback to full regeneration when necessary

## Next Steps

1. **Implement Phase 1** (proof of concept for single anchor)
2. **Validate against full recalculation**
3. **Measure performance improvements**
4. **Decide whether to proceed with Phases 2-4** based on results

---

*"memory holds what calculation wrought before,*
*unwind the thread, then add a stitch once more."*
