# Critical Path: Similar Pages Generation

## Overview

This document tracks the critical path for generating all **similar/** HTML pages - the similarity-based navigation system that shows poems ordered by closeness to an origin poem.

**Target Output**: 7,793 similar page sets (15 pages each = 116,895 HTML files)

---

## Current Status

| Metric | Current | Target | Progress |
|--------|---------|--------|----------|
| Embeddings | 7,793 | 7,793 | ✅ 100% |
| Similarity Matrix | 71 files | 7,793 files | 0.9% |
| Similar Pages | 6 | 116,895 | 0.005% |

**Last Updated**: 2026-01-04

**Note**: Embeddings were discovered to be complete during Issue 8-021 investigation. The "missing 1132" was outdated information caused by a counter display bug (now fixed).

---

## Critical Path Steps

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SIMILAR PAGE GENERATION PATH                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   STEP 1: Complete Embeddings                                               │
│   ├── Current: 7,793 poems embedded                                         │
│   ├── Missing: 0 poems                                                      │
│   ├── Tool: ./generate-embeddings.sh                                        │
│   ├── Requires: Ollama + EmbeddingGemma:latest                              │
│   ├── Status: ✅ COMPLETE                                                   │
│   └── Est. Time: N/A (already done)                                         │
│           │                                                                 │
│           ▼                                                                 │
│   STEP 2: Calculate Similarity Matrix                                       │
│   ├── Current: 71 individual similarity files                               │
│   ├── Required: 7,793 files (one per poem)                                  │
│   ├── Tool: lua src/similarity-engine-parallel.lua                          │
│   ├── Threads: 8 (configurable)                                             │
│   ├── Status: 🔄 READY TO RUN                                               │
│   └── Est. Time: ~2 hours                                                   │
│           │                                                                 │
│           ▼                                                                 │
│   STEP 3: Generate Similar HTML Pages                                       │
│   ├── Current: 6 pages generated                                            │
│   ├── Target: 116,895 pages (7,793 poems × 15 pages each)                   │
│   ├── Tool: ./scripts/generate-html-parallel                                │
│   ├── Page size: ~134 KB each                                               │
│   ├── Status: ⏳ WAITING (depends on Step 2)                                │
│   └── Est. Time: ~1 hour (with 8 threads)                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Step 1: Complete Embeddings

### Current Behavior
- 6,661 poems have embeddings cached
- 1,132 poems added after November 2025 network error are missing embeddings
- Embedding generation fails when Ollama network errors exceed threshold

### Commands
```bash
# 1. Ensure Ollama is running with CUDA acceleration
./scripts/start-ollama-cuda.sh

# 2. Verify Ollama is responding
OLLAMA_HOST=192.168.0.115:10265 curl http://192.168.0.115:10265/api/tags

# 3. Generate missing embeddings
./generate-embeddings.sh
```

### Validation
```bash
# Count embeddings vs poems
find input/embeddings -name "*.json" | wc -l  # Should be 7,793
```

### Blockers
- Network connectivity to Ollama server
- EmbeddingGemma:latest model availability
- Issue 8-021: Progress counter overcounting (cosmetic)

---

## Step 2: Calculate Similarity Matrix

### Current Behavior
- 71 individual similarity JSON files exist (one per poem that's been processed)
- Each file contains similarity scores to all other poems
- Files stored in `temp/similarity_matrix/`

### Commands
```bash
# Calculate similarity matrix for all poems (8 threads)
lua src/similarity-engine-parallel.lua
```

### Validation
```bash
# Count similarity files
ls temp/similarity_matrix/*.json | wc -l  # Should be 7,793
```

### Output Format
```
temp/similarity_matrix/
├── 0001.json   # Similarity scores for poem 1 to all others
├── 0002.json   # Similarity scores for poem 2 to all others
├── ...
└── 7793.json   # Similarity scores for poem 7793 to all others
```

---

## Step 3: Generate Similar HTML Pages

### Current Behavior
- 6 pages exist in `output/similar/`
- Pages are ~134 KB each (100 poems per page)
- Uses pagination with max 15 pages per poem (1,500 poems shown)

### Commands
```bash
# Generate all similar pages (8 threads)
./scripts/generate-html-parallel 8
```

### Configuration
From `config/input-sources.json`:
```json
{
  "pagination": {
    "poems_per_page": 100,
    "max_pages_per_poem": 15
  }
}
```

### Output Format
```
output/similar/
├── 0001-01.html  # Poems 1-100 most similar to poem 1
├── 0001-02.html  # Poems 101-200 most similar to poem 1
├── ...
├── 0001-15.html  # Poems 1401-1500 most similar to poem 1
├── 0002-01.html
├── ...
└── 7793-15.html
```

### Validation
```bash
# Count generated pages
ls output/similar/*.html | wc -l  # Should be ~116,895
```

---

## Algorithm: Cosine Similarity

The Similar system uses cosine similarity to rank poems:

```
similarity(A, B) = (A · B) / (|A| × |B|)

Where:
- A, B are 768-dimensional embedding vectors
- A · B is the dot product
- |A|, |B| are the magnitudes (L2 norms)
```

**Interpretation**:
- 1.0 = Identical semantic meaning
- 0.0 = Completely unrelated
- -1.0 = Opposite meaning (rare in practice)

### Ranking Logic
For each poem P:
1. Calculate cosine similarity to all other poems
2. Sort by similarity score (highest first)
3. Generate pages with top 1,500 poems (15 pages × 100 poems)

---

## Storage Budget

| Component | Size | Notes |
|-----------|------|-------|
| Similar pages | ~15.3 GB | 116,895 files × 134 KB |
| Allocation | 45 GB × 34% | Of total Neocities limit |

---

## Estimated Total Time

| Step | Time | Cumulative |
|------|------|------------|
| 1. Complete embeddings | ~1 hour | 1 hour |
| 2. Similarity matrix | ~2 hours | 3 hours |
| 3. Generate HTML | ~1 hour | 4 hours |

**Total**: ~4 hours from unblocked start to complete similar pages

---

## Quick Command Reference

```bash
# Full pipeline for Similar pages only
./scripts/start-ollama-cuda.sh
./generate-embeddings.sh
lua src/similarity-engine-parallel.lua
./scripts/generate-html-parallel 8 --similar-only

# Verification
ls output/similar/*.html | wc -l
```

---

## Related Issues

- `8-001`: Pipeline integration (Steps 1-6 complete)
- `8-002`: Multi-threaded HTML generation
- `8-012`: Pagination implementation (Phases A+B complete)
- `8-020`: Hybrid pagination strategy (45 GB constraint)
- `8-021`: Fix embedding progress counter overcounting

---

**Status**: 🔄 READY - Step 2 can begin immediately

**Next Action**: Run `lua src/similarity-engine-parallel.lua` to calculate similarity matrix

**Estimated Time to Completion**: ~3 hours (Step 2: 2 hrs + Step 3: 1 hr)
