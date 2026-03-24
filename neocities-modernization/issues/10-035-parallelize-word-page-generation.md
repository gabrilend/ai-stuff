# 10-035: Parallelize Word Page Generation

## Current Behavior

Word similarity pages are generated sequentially:
```
Generating word page 7135/7135: particularly
```

Each word page requires:
1. Cosine similarity calculation: word_embedding × 8,275 poem_embeddings
2. Sorting 8,275 candidates by similarity
3. Balanced color selection (optional, from top 350 candidates)
4. HTML generation

With 7,135 words, this means ~59 million similarity calculations done sequentially.

## Intended Behavior

Parallel word page generation using orchestrator pattern (like Issue 10-034):
- Expected speedup: 4-8× with multiple threads
- Memory-efficient: workers share nothing except small work slices

## Key Difference from Poem Page Parallelization

**Poem pages** (Issue 10-034):
- Work slice = 80KB (pre-computed ranking for one poem)
- Rankings are pre-cached, just need lookup

**Word pages** (this issue):
- No pre-computed cache exists
- Each word needs similarity against ALL poems
- Work = word + word_embedding, workers compute similarity on-the-fly

## Proposed Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MAIN THREAD (ORCHESTRATOR)                        │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ word_embeddings: { "word": [768 floats], ... } (~30MB)       │   │
│  │ word_colors: { "word": {color: "blue"}, ... } (~1MB)         │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                  │                                   │
│                    ┌─────────────┴─────────────┐                    │
│                    │    Request Handler Loop   │                    │
│                    │  - Send word + embedding  │                    │
│                    │  - Track completion       │                    │
│                    └─────────────┬─────────────┘                    │
└──────────────────────────────────┼──────────────────────────────────┘
                                   │ effil channels
              ┌────────────────────┼────────────────────┐
              ▼                    ▼                    ▼
┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐
│    WORKER 1       │  │    WORKER 2       │  │    WORKER 3       │
│ ┌───────────────┐ │  │ ┌───────────────┐ │  │ ┌───────────────┐ │
│ │ poems.json    │ │  │ │ poems.json    │ │  │ │ poems.json    │ │
│ │ poem_embeddings│ │  │ │ poem_embeddings│ │  │ │ poem_embeddings│ │
│ │ poem_colors   │ │  │ │ poem_colors   │ │  │ │ poem_colors   │ │
│ │   ~90MB       │ │  │ │   ~90MB       │ │  │ │   ~90MB       │ │
│ ├───────────────┤ │  │ ├───────────────┤ │  │ ├───────────────┤ │
│ │ Current Work  │ │  │ │ Current Work  │ │  │ │ Current Work  │ │
│ │ - word        │ │  │ │ - word        │ │  │ │ - word        │ │
│ │ - embedding   │ │  │ │ - embedding   │ │  │ │ - embedding   │ │
│ │   ~3KB        │ │  │ │   ~3KB        │ │  │ │   ~3KB        │ │
│ └───────────────┘ │  │ └───────────────┘ │  │ └───────────────┘ │
│  Compute similarity│  │  Compute similarity│  │  Compute similarity│
│  Sort & select     │  │  Sort & select     │  │  Sort & select     │
│  Generate HTML     │  │  Generate HTML     │  │  Generate HTML     │
└───────────────────┘  └───────────────────┘  └───────────────────┘
```

## Memory Comparison

| Component | Current | With Orchestrator (4 threads) |
|-----------|---------|-------------------------------|
| Main thread | ~90MB | ~35MB (words + word_colors only) |
| Per worker | N/A | ~90MB (poems + embeddings + colors) |
| Total | ~90MB | ~395MB |

Note: Memory increases with parallelization because workers need poem embeddings.
Trade-off is speed vs memory.

## Alternative: Pre-compute Word Rankings Cache

Could create `word_similarity_cache.json`:
```json
{
  "rankings": {
    "love": [4521, 2301, 8732, ...],  // poem indices sorted by similarity
    "time": [1234, 5678, ...],
    ...
  }
}
```

- Cache size: 7,135 words × 8,275 integers × 4 bytes ≈ 236MB
- One-time computation cost: ~5-10 minutes with GPU
- Parallelization then matches poem page approach (80KB slices)

## Implementation Steps

### Option A: On-the-fly Parallel (simpler, more memory)

1. Modify `generate_all_word_pages()` to accept `num_threads` parameter
2. Add effil thread detection (copy from flat-html-generator.lua)
3. Create work request/response channels
4. Worker loads: poems.json, embeddings.json, poem_colors.json
5. Orchestrator sends: word + word_embedding + word_color
6. Worker computes similarity, generates HTML

### Option B: Pre-compute Cache (faster, less memory per run)

1. Create `scripts/generate-word-rankings` using GPU
2. Store rankings in `word_similarity_cache.json`
3. Modify word page generator to use cache
4. Parallelize like poem pages (send ranking slice, not embeddings)

## Related Documents

- Issue 10-034: Lazy loading orchestrator for parallel HTML (completed)
- `src/generate-word-pages.lua`: Current sequential implementation
- `src/flat-html-generator.lua:3162-4231`: Orchestrator pattern reference

## Status

**OPEN** - Ready for implementation

