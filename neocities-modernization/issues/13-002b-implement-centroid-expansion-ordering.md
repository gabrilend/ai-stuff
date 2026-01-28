# Issue 13-002b: Implement Centroid Expansion Ordering

## Priority
High (blocks 13-002c, 13-002d)

## Parent Issue
13-002: Generate TTS Hypnotic Trance Track from Word-Cloud Flopsopoly

## Current Behavior

After 13-002a completes, a frequency-weighted word pool exists with ~700 word tokens. The pool is unordered — entries are in the order they were added (word-by-word, instances sequential).

The project has an existing diversity-chaining algorithm (`src/diversity-chaining.lua`) that orders poems by maximum diversity from a progressive centroid. This algorithm needs to be adapted for word-level ordering.

## Intended Behavior

Order the word pool using a **progressive centroid expansion** algorithm that maximizes diversity at each step:

```
Algorithm: Progressive Centroid Expansion

1. Initialize: centroid = zero vector, sequence = []
2. For each remaining word in pool:
   a. Compute distance from each unselected word to current centroid
   b. Select the word MOST DISTANT from the centroid
   c. Append to sequence
   d. Update centroid: centroid = running average of all selected word embeddings
3. Return sequence
```

### Self-Regulating Duplicates

The algorithm naturally spaces out duplicate words:
- Selecting `silence_1` shifts the centroid toward "silence"
- This makes `silence_2` through `silence_7` temporarily CLOSER to the centroid
- Other words (whose embeddings differ) become more distant
- `silence_2` won't be selected again until the centroid has drifted far enough away
- Higher-frequency words create stronger centroid shifts, requiring more drift before re-selection

### Expected Output

An ordered sequence where:
- No two adjacent words are the same (except for very small pools)
- Duplicate instances of a word are roughly evenly distributed
- Each word is maximally different from the recent semantic context
- The sequence has a natural "rhythm" driven by frequency-weighted repetition

## Technical Design

```lua
-- {{{ local function order_by_centroid_expansion
-- Orders pool items by maximum distance from progressive centroid
-- Each selection shifts the centroid, naturally spacing duplicates
local function order_by_centroid_expansion(pool)
    local dim = 768  -- Embedding dimension
    local centroid = {}
    for d = 1, dim do centroid[d] = 0 end

    local selected = {}
    local remaining = {}
    for i, item in ipairs(pool) do remaining[i] = item end

    local centroid_count = 0

    while #remaining > 0 do
        -- Find most distant word from centroid
        local best_idx = 1
        local best_dist = -1

        for i, item in ipairs(remaining) do
            local emb = item.embedding
            if emb then
                local dist = 0
                if centroid_count == 0 then
                    -- First selection: all equally distant from zero centroid
                    -- Could use deterministic seed (e.g., first alphabetically)
                    dist = 1
                else
                    -- Cosine distance (1 - similarity) for maximum diversity
                    local dot, n1, n2 = 0, 0, 0
                    for d = 1, dim do
                        dot = dot + centroid[d] * emb[d]
                        n1 = n1 + centroid[d] * centroid[d]
                        n2 = n2 + emb[d] * emb[d]
                    end
                    local sim = dot / (math.sqrt(n1) * math.sqrt(n2) + 1e-10)
                    dist = 1 - sim
                end

                if dist > best_dist then
                    best_dist = dist
                    best_idx = i
                end
            end
        end

        -- Select and update centroid
        local selected_item = table.remove(remaining, best_idx)
        table.insert(selected, selected_item)

        local emb = selected_item.embedding
        if emb then
            centroid_count = centroid_count + 1
            for d = 1, dim do
                centroid[d] = centroid[d] + (emb[d] - centroid[d]) / centroid_count
            end
        end

        -- Progress display for large pools
        if #selected % 100 == 0 then
            io.write(string.format("\rOrdering: %d/%d", #selected, #selected + #remaining))
            io.flush()
        end
    end

    return selected
end
-- }}}
```

### Performance Considerations

The algorithm is O(N²) where N = pool size:
- For N = 700: 700² / 2 = ~245,000 distance computations
- Each distance computation is O(768) for embedding dimension
- Total: ~188M FLOPs ≈ <1 second on CPU

If performance becomes an issue, consider:
- GPU acceleration (similar to diversity-chaining.lua)
- Approximate nearest neighbor (but we want farthest, so inverted)
- Batch processing with periodic centroid updates

## Suggested Implementation Steps

1. **Study existing diversity-chaining.lua** — Understand the reference implementation
2. **Implement `order_by_centroid_expansion(pool)`** — Core ordering function
3. **Handle first-word selection** — Deterministic choice (alphabetical, fixed seed, or configurable)
4. **Add progress display** — For pools >500 items
5. **Validate output**:
   - No adjacent duplicates (or minimal)
   - Even distribution of duplicate instances
   - Sequence length == pool size
6. **Test with sample data** — Small pool first, then full word cloud
7. **Save ordered sequence** — `output/flopsopoly/sequence.json`

## Deliverables

- [ ] Function `order_by_centroid_expansion(pool)` implemented
- [ ] Deterministic first-word selection strategy documented
- [ ] Progress display for large pools
- [ ] Validation: no adjacent duplicates, even distribution
- [ ] `output/flopsopoly/sequence.json` generated
- [ ] Performance benchmark: time for full pool ordering

## Testing

```lua
-- Test: no adjacent duplicates
for i = 2, #sequence do
    assert(sequence[i].word ~= sequence[i-1].word,
           "Adjacent duplicates at position " .. i)
end

-- Test: sequence length equals pool size
assert(#sequence == #pool, "Sequence length mismatch")

-- Test: all pool items present
local pool_words = {}
for _, item in ipairs(pool) do
    pool_words[item.word .. "_" .. item.instance] = true
end
for _, item in ipairs(sequence) do
    assert(pool_words[item.word .. "_" .. item.instance], "Missing item in sequence")
end
```

## Related Documents

- Issue 13-002: Generate TTS Hypnotic Trance Track (parent)
- Issue 13-002a: Build Frequency-Weighted Word Pool (provides input pool)
- Issue 13-002c: Generate Per-Word Audio Cache (uses sequence for TTS)
- `src/diversity-chaining.lua` — Reference implementation for centroid expansion
- `assets/embeddings/embeddinggemma_latest/word_embeddings.json` — Embedding source

## Metadata

- **Status**: Open
- **Created**: 2026-01-28
- **Phase**: 13 (Audio-Visual Generation)
- **Estimated Complexity**: Medium (algorithm adaptation)
- **Dependencies**: 13-002a (pool)
- **Blocks**: 13-002c, 13-002d
