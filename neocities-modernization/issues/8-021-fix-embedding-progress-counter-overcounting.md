# Issue 8-021: Fix Embedding Progress Counter Overcounting

## Current Behavior

During embedding generation, the progress counter can exceed 100% and show more completed items than total poems:

```
Progress: ██████████████████████████████████████████████████████████████████ 132% (10319/7793)
```

Observed progression:
- Started at reasonable percentages
- Crossed 100% (7793/7793)
- Continued climbing to 101%, 110%, 132%...
- Final count showed 10319 completed vs 7793 total

**Despite this**, the actual embeddings file was saved correctly with exactly 7793 entries. The bug is in the **progress counting logic**, not in the actual embedding generation.

## Root Cause Analysis

The progress counter is calculated in `src/similarity-engine.lua`:

```lua
-- Line 439
local completed = skipped_count  -- Start with existing embeddings

-- Lines 479, 495
completed = completed + 1  -- Increment for each new embedding

-- Line 502
local progress_data = string.format("%d,%d", completed, #poems)
```

### Suspected Issue: poem_index Transition

After Issue 8-019 introduced `poem_index`, there's a mismatch between:

1. **How existing embeddings are STORED**: May use old array indices or `id` values
2. **How lookups are DONE**: Now uses `poem.poem_index`

In incremental mode:
- Code loads existing embeddings and stores them by `emb.poem_index or i` (line 341)
- Code looks up by `poem.poem_index or i` (line 372)
- If these don't match, existing embeddings aren't found
- All poems get added to `poems_to_process` even though embeddings exist
- `skipped_count` may be non-zero from a partial match
- `completed = skipped_count + len(poems_to_process)` exceeds `#poems`

### Math Check

- `completed` started at `skipped_count` (let's say X)
- Then processed `#poems_to_process` poems (let's say Y)
- Final `completed` = X + Y
- If X + Y > 7793, we get overcounting

Observed: 10319 = 7793 + 2526 extra counts

This suggests either:
1. `skipped_count` was ~2526 (partial existing embeddings)
2. Plus all 7793 poems were processed (because lookup failed)
3. Total: 2526 + 7793 = 10319 ✓

## Intended Behavior

Progress counter should:
1. Never exceed 100% (or the total poem count)
2. Accurately reflect: `(skipped + newly_processed) / total_poems`
3. Handle the poem_index transition gracefully

## Suggested Implementation Steps

### Option A: Fix the Counter Logic

1. [ ] Track `newly_processed` separately from `skipped_count`
2. [ ] Calculate: `completed = min(skipped_count + newly_processed, #poems)`
3. [ ] Add sanity check: warn if `completed > #poems`

### Option B: Fix the Lookup Mismatch

1. [ ] Ensure embeddings are stored with consistent keys
2. [ ] Update incremental loading to handle both old and new formats
3. [ ] Add migration logic to update old embedding files

### Option C: Both (Recommended)

1. [ ] Fix the counter logic (immediate fix)
2. [ ] Add format detection and migration (long-term fix)
3. [ ] Add validation to detect mismatches early

## Files to Modify

| File | Changes |
|------|---------|
| `src/similarity-engine.lua` | Fix counter logic in `generate_all_embeddings()` |
| `generate-embeddings.sh` | Add validation step before processing |

## Testing Strategy

1. [ ] Run with fresh poems.json and empty embeddings → should show 0→100%
2. [ ] Run incremental with all embeddings present → should show 100% immediately
3. [ ] Run incremental with partial embeddings → should show X%→100%
4. [ ] Verify `completed` never exceeds `#poems`

## Related Issues

- **Issue 8-019**: Implement unique poem_index system (introduced the lookup change)
- **Issue 8-018**: Fix embedding directory case inconsistency

## Risk Assessment

- **Impact**: Low (cosmetic bug, data is correct)
- **Urgency**: Low (doesn't affect actual functionality)
- **Complexity**: Medium (requires understanding the incremental logic)

---

**Phase**: 8 (Website Completion)

**Priority**: Low

**Created**: 2025-12-25

**Status**: Open

**Discovered During**: Embedding generation run after Issue 8-019 implementation
