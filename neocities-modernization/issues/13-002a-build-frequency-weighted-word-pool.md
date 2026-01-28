# Issue 13-002a: Build Frequency-Weighted Word Pool

## Priority
High (blocks 13-002b)

## Parent Issue
13-002: Generate TTS Hypnotic Trance Track from Word-Cloud Flopsopoly

## Current Behavior

The word cloud generator (`src/wordcloud-generator.lua`) produces a list of words with font sizes (1-7) based on frequency normalization. This data structure contains:
- Word text
- Font size (1-7)
- Word embedding (768-dim vector)
- Frequency count

However, this data is stored as a simple list — no expanded/weighted pool exists for the flopsopoly algorithm.

## Intended Behavior

Create a frequency-weighted word pool (the "flopsopoly") where each word appears N times, where N equals its font size:

```
Word "silence" (size 7) → 7 instances: silence_1, silence_2, ..., silence_7
Word "window"  (size 2) → 2 instances: window_1, window_2
Word "fire"    (size 5) → 5 instances: fire_1, fire_2, ..., fire_5
...
```

Total pool size: sum of all word font sizes across the word cloud.

### Pool Data Structure

Each pool entry contains:
```lua
{
    word = "silence",       -- The word text
    instance = 3,           -- Instance number (1 to font_size)
    font_size = 7,          -- Original font size
    embedding = {...},      -- 768-dim embedding vector (reference, not copy)
    embedding_idx = 42,     -- Index into word_embeddings.json
}
```

### Expected Pool Statistics

Based on current word cloud data (~200 words with sizes 1-7):
- Average font size: ~3.5
- Estimated pool size: 200 × 3.5 = ~700 word tokens
- Unique words: ~200
- Max duplicates per word: 7

## Suggested Implementation Steps

1. **Read word cloud data** — Load from `src/wordcloud-generator.lua` output or regenerate
2. **Load word embeddings** — From `assets/embeddings/embeddinggemma_latest/word_embeddings.json`
3. **Build expanded pool**:
   ```lua
   local pool = {}
   for _, entry in ipairs(word_cloud_data) do
       local copies = entry.font_size or 1
       for i = 1, copies do
           table.insert(pool, {
               word = entry.word,
               instance = i,
               font_size = entry.font_size,
               embedding = word_embeddings[entry.word],
               embedding_idx = entry.embedding_idx
           })
       end
   end
   ```
4. **Validate pool** — Ensure all words have embeddings, log warnings for missing
5. **Output pool statistics** — Total size, unique words, size distribution
6. **Save pool to JSON** — `output/flopsopoly/pool.json` for inspection/debugging

### File Location

Create `src/flopsopoly-pool-builder.lua` or add as a function in `src/flopsopoly-generator.lua`.

## Deliverables

- [ ] Function `build_flopsopoly_pool(word_cloud_data, word_embeddings)` implemented
- [ ] Pool data structure with all required fields
- [ ] Validation: all pool entries have valid embeddings
- [ ] Statistics output: pool size, unique words, distribution
- [ ] `output/flopsopoly/pool.json` generated for debugging
- [ ] Unit test: verify pool size = sum of font sizes

## Edge Cases

- **Word with no embedding**: Skip from pool, log warning, continue
- **Word with font_size = 0**: Skip (shouldn't happen, but defensive)
- **Empty word cloud**: Return empty pool, log error
- **Very large word cloud** (>1000 words): May need progress display

## Testing

```lua
-- Test: pool size equals sum of font sizes
local total_expected = 0
for _, entry in ipairs(word_cloud_data) do
    total_expected = total_expected + (entry.font_size or 1)
end
assert(#pool == total_expected, "Pool size mismatch")

-- Test: all entries have embeddings
for _, entry in ipairs(pool) do
    assert(entry.embedding, "Missing embedding for: " .. entry.word)
end
```

## Related Documents

- Issue 13-002: Generate TTS Hypnotic Trance Track (parent)
- Issue 13-002b: Implement Centroid Expansion Ordering (next step, consumes pool)
- `src/wordcloud-generator.lua` — Source of word frequency data
- `assets/embeddings/embeddinggemma_latest/word_embeddings.json` — Word embeddings

## Metadata

- **Status**: Open
- **Created**: 2026-01-28
- **Phase**: 13 (Audio-Visual Generation)
- **Estimated Complexity**: Low (data transformation)
- **Dependencies**: Word cloud data, word embeddings
- **Blocks**: 13-002b
