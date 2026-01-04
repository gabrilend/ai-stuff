# Critical Path: Different Pages Generation

## Overview

This document tracks the critical path for generating all **different/** HTML pages - the diversity-based navigation system that shows poems ordered by maximum difference from the running centroid.

**Target Output**: 7,793 different page sets (15 pages each = 116,895 HTML files)

---

## Current Status

| Metric | Current | Target | Progress |
|--------|---------|--------|----------|
| Embeddings | 7,793 | 7,793 | ✅ 100% |
| Similarity Matrix | 71 files | 7,793 files | 0.9% |
| Diversity Cache | 0 | 1 file | 0% |
| Different Pages | 4 | 116,895 | 0.003% |

**Last Updated**: 2026-01-04

**Note**: Embeddings were discovered to be complete during Issue 8-021 investigation. The "missing 1132" was outdated information caused by a counter display bug (now fixed).

---

## Critical Path Steps

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       DIFFERENT PAGE GENERATION PATH                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   STEP 1: Complete Embeddings                                               │
│   ├── Current: 7,793 poems embedded                                         │
│   ├── Missing: 0 poems                                                      │
│   ├── Tool: ./generate-embeddings.sh                                        │
│   ├── Status: ✅ COMPLETE                                                   │
│   └── Est. Time: N/A (already done)                                         │
│           │                                                                 │
│           ▼                                                                 │
│   STEP 2: Calculate Similarity Matrix                                       │
│   ├── Current: 71 individual files                                          │
│   ├── Required: 7,793 files                                                 │
│   ├── Tool: lua src/similarity-engine-parallel.lua                          │
│   ├── Status: 🔄 READY TO RUN                                               │
│   └── Est. Time: ~2 hours                                                   │
│           │                                                                 │
│           ▼                                                                 │
│   STEP 3: Pre-compute Diversity Cache (OPTIONAL BUT RECOMMENDED)            │
│   ├── Current: Not started                                                  │
│   ├── Target: diversity_cache.json (~500 MB)                                │
│   ├── Tool: ./scripts/precompute-diversity-sequences                        │
│   ├── Status: ⏸️ OPTIONAL (depends on Step 2)                               │
│   └── Est. Time: ~42 hours (can run unattended)                             │
│           │                                                                 │
│           ▼                                                                 │
│   STEP 4: Generate Different HTML Pages                                     │
│   ├── Current: 4 pages generated                                            │
│   ├── Target: 116,895 pages (7,793 poems × 15 pages each)                   │
│   ├── Tool: ./scripts/generate-html-parallel                                │
│   ├── Status: ⏳ WAITING (depends on Steps 2, optionally 3)                 │
│   └── Est. Time: ~1 hour WITH cache, ~72 hours WITHOUT cache                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Path Choice: Fast vs Slow

### FAST PATH (with Diversity Cache)
```
Step 1 (1 hr) → Step 2 (2 hrs) → Step 3 (42 hrs) → Step 4 (1 hr)
Total: ~46 hours
```

### SLOW PATH (without Cache)
```
Step 1 (1 hr) → Step 2 (2 hrs) → Step 4 (72 hrs)
Total: ~75 hours
```

**Recommendation**: Use FAST PATH. Step 3 runs unattended overnight and saves 29 hours of active time.

---

## Step 1: Complete Embeddings

(Same as Similar path - see CRITICAL-PATH-SIMILAR.md)

### Commands
```bash
./scripts/start-ollama-cuda.sh
./generate-embeddings.sh
```

---

## Step 2: Calculate Similarity Matrix

(Same as Similar path - see CRITICAL-PATH-SIMILAR.md)

### Commands
```bash
lua src/similarity-engine-parallel.lua
```

---

## Step 3: Pre-compute Diversity Cache (OPTIONAL)

### Why This Step Matters

The diversity algorithm (centroid-repulsion) is computationally expensive:
- For each poem, calculate a running centroid of all previously selected poems
- Select the next poem that's most different from the current centroid
- This creates O(n²) operations per sequence

**Without cache**: Each HTML page recalculates the full sequence (~25 seconds per poem)
**With cache**: Sequences are pre-computed once, HTML generation is instant

### Commands
```bash
# Start pre-computation (runs ~42 hours unattended)
./scripts/precompute-diversity-sequences &

# Monitor progress (optional)
tail -f temp/diversity_precompute.log
```

### Output
```
temp/
└── diversity_cache.json  # ~500 MB, contains all 7,793 pre-computed sequences
```

### Validation
```bash
# Check cache file exists and has content
ls -lh temp/diversity_cache.json
# Should be ~500 MB after completion
```

---

## Step 4: Generate Different HTML Pages

### With Cache (FAST)
```bash
# Uses pre-computed sequences - ~1 hour total
./scripts/generate-html-parallel 8 --different-only
```

### Without Cache (SLOW)
```bash
# Computes diversity on-the-fly - ~72 hours total
./scripts/generate-html-parallel 8 --different-only --no-cache
```

### Output Format
```
output/different/
├── 0001-01.html  # Poems 1-100 most different from poem 1's sequence
├── 0001-02.html  # Poems 101-200 most different
├── ...
├── 0001-15.html  # Poems 1401-1500 most different
├── 0002-01.html
├── ...
└── 7793-15.html
```

---

## Algorithm: Progressive Centroid Diversity

The Different system uses a **centroid-repulsion** algorithm:

```
For origin poem P₀:
  sequence = [P₀]
  centroid = embedding(P₀)

  For i = 1 to N:
    # Find poem most different from current centroid
    P_next = argmax(distance(embedding(poem), centroid))
            for all poem not in sequence

    sequence.append(P_next)

    # Update centroid (running average)
    centroid = average(embeddings of all poems in sequence)
```

**Key Insight**: Each selection pushes the centroid in a new direction, causing subsequent selections to "bounce" across the semantic space. This creates maximum diversity in the browsing experience.

### Comparison to Similar

| Aspect | Similar | Different |
|--------|---------|-----------|
| Algorithm | Closest to origin | Farthest from centroid |
| Complexity | O(n log n) sort | O(n²) iterative |
| Caching | Similarity matrix | Diversity cache |
| Path shape | Spiral outward | Bouncing across space |

---

## Storage Budget

| Component | Size | Notes |
|-----------|------|-------|
| Different pages | ~15.3 GB | 116,895 files × 134 KB |
| Diversity cache | ~500 MB | Temporary, can delete after generation |
| Allocation | 45 GB × 34% | Of total Neocities limit |

---

## Estimated Total Time

### FAST PATH (Recommended)

| Step | Time | Cumulative | Notes |
|------|------|------------|-------|
| 1. Complete embeddings | ~1 hour | 1 hour | Active |
| 2. Similarity matrix | ~2 hours | 3 hours | Active |
| 3. Diversity cache | ~42 hours | 45 hours | **Unattended** |
| 4. Generate HTML | ~1 hour | 46 hours | Active |

**Active time**: ~4 hours
**Total wall-clock**: ~46 hours

### SLOW PATH

| Step | Time | Cumulative | Notes |
|------|------|------------|-------|
| 1. Complete embeddings | ~1 hour | 1 hour | Active |
| 2. Similarity matrix | ~2 hours | 3 hours | Active |
| 4. Generate HTML | ~72 hours | 75 hours | **Active (CPU-bound)** |

**Active time**: ~75 hours
**Total wall-clock**: ~75 hours

---

## Quick Command Reference

### FAST PATH (Recommended)
```bash
# Steps 1-2 (same as Similar)
./scripts/start-ollama-cuda.sh
./generate-embeddings.sh
lua src/similarity-engine-parallel.lua

# Step 3: Start diversity pre-computation (runs overnight)
nohup ./scripts/precompute-diversity-sequences > temp/diversity_precompute.log 2>&1 &

# Step 4: Generate pages (after Step 3 completes)
./scripts/generate-html-parallel 8 --different-only

# Verification
ls output/different/*.html | wc -l  # Should be ~116,895
```

### SLOW PATH (Not Recommended)
```bash
# Steps 1-2 (same as Similar)
./scripts/start-ollama-cuda.sh
./generate-embeddings.sh
lua src/similarity-engine-parallel.lua

# Step 4: Generate without cache (72 hours)
./scripts/generate-html-parallel 8 --different-only --no-cache
```

---

## Thermal Considerations

The diversity algorithm is CPU-intensive. The generation scripts include thermal management:

```lua
-- From scripts/generate-html-parallel
BATCH_SIZE = 10
BATCH_SLEEP_MS = 500  -- Cool-down between batches
```

Monitor CPU temperatures during long runs:
```bash
watch -n 5 sensors
```

---

## Related Issues

- `8-001`: Pipeline integration
- `8-002`: Multi-threaded HTML generation (effil library)
- `8-008`: Configurable centroid embedding system
- `8-012`: Pagination implementation
- `8-020`: Hybrid pagination strategy (45 GB constraint)
- `9-003`: GPU-accelerated centroid optimization (future)
- `9-004`: GPU-accelerate maze algorithm (future)

---

## GPU Acceleration (Phase 9)

The diversity algorithm is a prime candidate for GPU acceleration:

| Metric | CPU (Current) | GPU (Phase 9) |
|--------|---------------|---------------|
| Diversity sequence | ~25 sec | ~4-8 sec |
| Full cache | ~42 hours | ~8 hours |

This is tracked in `issues/9-003-optimize-centroid-calculation-and-parallelization.md`.

---

**Status**: 🔄 READY - Step 2 can begin immediately

**Next Action**: Run `lua src/similarity-engine-parallel.lua` to calculate similarity matrix

**Secondary Constraint**: Diversity cache pre-computation takes 42 hours (optional but recommended)

**Resolution Path**:
1. ~~Complete embeddings~~ ✅ Already done!
2. Calculate similarity matrix (~2 hours)
3. Start diversity pre-computation (overnight, optional)
4. Generate HTML pages (~1 hour with cache, ~72 hours without)

**Estimated Time to Completion**:
- **Fast path** (with cache): ~45 hours (mostly unattended)
- **Slow path** (no cache): ~74 hours (CPU-bound)
