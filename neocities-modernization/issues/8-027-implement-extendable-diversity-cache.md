# Issue 8-027: Implement Extendable Diversity Cache

## Current Behavior

The diversity cache has a hardcoded `MAX_SEQUENCE_LENGTH = 1500`. To change this limit:
- Increasing requires full regeneration (~hours)
- Decreasing requires manual JSON editing or full regeneration

The precompute script does not read pagination settings from config or CLI flags.

## Intended Behavior

The diversity cache should be **updatable**:

1. **Extend sequences** (1000 → 1500): Continue algorithm from where it left off
2. **Truncate sequences** (1500 → 1000): Slice arrays without recomputation
3. **Respect CLI flags**: `--sequence-limit=N` or derive from `--pages × --poems-per-page`
4. **Track metadata**: Store limit, detect when extension/truncation is needed

### Example Usage

```bash
# Initial generation with limit of 500
./scripts/precompute-diversity-sequences . --sequence-limit=500

# Later, extend to 1500 (only computes steps 501-1500)
./scripts/precompute-diversity-sequences . --sequence-limit=1500

# Truncate to 200 (instant, just slices arrays)
./scripts/precompute-diversity-sequences . --sequence-limit=200
```

## Design Details

### Algorithm Properties (Why Extension Works)

The centroid-based diversity algorithm is **incremental**:
- Each step depends only on: running sum + remaining poems
- Running sum can be reconstructed from sequence in O(N × 768)
- Deterministic: same inputs → same outputs

### Metadata Schema

```json
{
  "metadata": {
    "generated_at": "2026-01-04 12:00:00",
    "total_sequences": 7797,
    "sequence_limit": 1500,
    "min_sequence_length": 1500,
    "algorithm_version": "centroid-v1",
    "embedding_dimension": 768,
    "source_embeddings": "embeddinggemma_latest",
    "embeddings_file_size": 62000000,
    "optimization_notes": "Incremental running sum, no division, RAM-only storage"
  },
  "sequences": { ... }
}
```

New fields:
- `sequence_limit`: Target limit when cache was generated
- `min_sequence_length`: Shortest sequence in cache (for partial generation detection)
- `algorithm_version`: For cache invalidation if algorithm changes
- `embeddings_file_size`: Quick check for embeddings modification

### Extension Workflow

```
1. Load existing cache
2. Check: existing_limit < requested_limit?
3. For each poem with sequence shorter than requested:
   a. Load sequence (e.g., 1000 entries)
   b. Load embeddings for those 1000 poems
   c. Compute running_sum = sum of all 1000 embeddings
   d. Build remaining = all_poems - sequence
   e. Continue algorithm from step 1001 → requested_limit
   f. Append new selections to sequence
4. Update metadata.sequence_limit
5. Save cache
```

### Truncation Workflow

```
1. Load existing cache
2. Check: existing_limit > requested_limit?
3. For each sequence:
   slice to first N elements
4. Update metadata.sequence_limit
5. Save cache
```

Truncation should be nearly instant (no embedding computation).

### CLI Flag Integration

Option A: Explicit flag
```bash
--sequence-limit=N    # Direct control
```

Option B: Derive from pagination
```bash
--pages=15 --poems-per-page=100  # Implies limit=1500
```

Option C: Read from config
```json
// config/input-sources.json
"pagination": {
  "max_pages_per_poem": 15,
  "poems_per_page": 100
}
// Implies sequence_limit = 15 × 100 = 1500
```

**Recommendation**: Support all three with precedence: CLI flag > derived > config > default(1500)

## Implementation Steps

### Phase A: Metadata Tracking
- [ ] Add `sequence_limit`, `min_sequence_length`, `algorithm_version` to cache metadata
- [ ] Add `embeddings_file_size` for staleness detection
- [ ] Update cache writing to include new fields

### Phase B: CLI Flag Support
- [ ] Add `--sequence-limit=N` argument parsing
- [ ] Add logic to derive from `--pages` and `--poems-per-page` if provided
- [ ] Fall back to config file, then default

### Phase C: Truncation Support
- [ ] Detect when requested_limit < existing_limit
- [ ] Implement fast array slicing (no recomputation)
- [ ] Skip embedding loading entirely for truncation

### Phase D: Extension Support
- [ ] Detect when requested_limit > existing_limit
- [ ] Implement running_sum reconstruction from existing sequence
- [ ] Continue algorithm from existing length to requested length
- [ ] Preserve thread-based parallelism for extension

### Phase E: Edge Cases
- [ ] Handle mixed-length sequences (some extended, some not)
- [ ] Warn if embeddings appear modified (file size changed)
- [ ] Handle new poems added (partial regeneration vs full)

## Edge Cases

| Scenario | Handling |
|----------|----------|
| `requested == existing` | No-op, exit early |
| `requested < existing` | Truncate (instant) |
| `requested > existing` | Extend (incremental computation) |
| Embeddings file changed | Warn user, suggest `--force` for full regen |
| Some sequences shorter | Extend only those that need it |
| New poems in corpus | Compute fresh sequences for new poems only |

## Performance Estimates

| Operation | Time |
|-----------|------|
| Truncate 1500 → 100 | < 1 second |
| Extend 100 → 1500 (all poems) | ~same as fresh generation |
| Extend 1000 → 1500 (all poems) | ~33% of fresh generation |
| Running sum reconstruction | ~1ms per poem |

## Related Issues

- **8-020**: Hybrid pagination strategy (storage constraints)
- **8-022**: Add pagination CLI flags to HTML generation
- **8-026**: Diversity cache progress display and incremental resume

## Files to Modify

| File | Changes |
|------|---------|
| `scripts/precompute-diversity-sequences` | Add extension/truncation logic, CLI flags, metadata |
| `config/input-sources.json` | Document sequence_limit option (optional) |

---

**Phase**: 8 (Website Completion)

**Priority**: Medium

**Created**: 2026-01-04

**Status**: Open

**Type**: Enhancement

**Estimated Effort**: Medium (2-4 hours)
