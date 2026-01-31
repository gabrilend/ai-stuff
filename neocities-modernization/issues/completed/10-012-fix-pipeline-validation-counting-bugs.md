# Issue 10-012: Fix Pipeline Validation Script Counting Bugs

## Priority
High (blocks ability to trust validation output)

## Current Behavior

The `scripts/validate-pipeline-data` script reports incorrect counts for embeddings, similarity, and diversity cache:

```
Embeddings
  ├─ Progress: 14287 / 7844 (182.1%) ✓
  └─ Status: INCOMPLETE

Similarity Matrix
  ├─ Progress: 14287 / 7844 (182.1%) ✓
  └─ Status: INCOMPLETE

Diversity Cache
  ├─ Progress: 2 / 7844 (0.0%) ⚠
  └─ Status: INCOMPLETE
```

**Actual data (verified manually):**
- Embeddings: 7,844 entries in `embeddings.json` ✓
- Similarity rankings cache: 7,844 entries ✓
- Diversity cache: 7,844 sequences ✓

All caches are complete, but the validator reports them as incomplete.

## Root Cause Analysis

### Bug 1: `count_embeddings()` counts wrong data source (lines 101-114)

```bash
count_embeddings() {
    # ...
    # The embeddings.json is just metadata - count actual individual embedding files
    find "$similarities_dir" -name "poem_*.json" -type f 2>/dev/null | wc -l
}
```

**Problem**: Counts similarity files instead of embeddings. The comment is also incorrect - `embeddings.json` contains the actual embeddings, not just metadata.

**Fix**: Count entries in embeddings.json:
```bash
jq '.embeddings | keys | length' "$embeddings_json"
```

### Bug 2: `count_similarity_files()` counts stale individual files (lines 116-123)

```bash
count_similarity_files() {
    find "$similarities_dir" -name "poem_*.json" -type f 2>/dev/null | wc -l
}
```

**Problem**: Counts individual `.json` files in `similarities/` directory (14,287 stale files from old dataset). The HTML generator actually uses `similarity_rankings_cache.json`, not these individual files.

**Fix**: Count entries in the rankings cache:
```bash
jq '.rankings | keys | length' "$EMBEDDINGS_DIR/$MODEL/similarity_rankings_cache.json"
```

### Bug 3: `check_diversity_cache()` counts top-level keys (lines 125-140)

```bash
check_diversity_cache() {
    # ...
    count=$(jq 'length' "$cache_file" 2>/dev/null || echo "0")
    echo "EXISTS:$count"
}
```

**Problem**: `jq 'length'` on the cache file returns 2 (the count of top-level keys: `metadata` and `sequences`), not the number of sequence entries.

**Fix**: Count the sequences array:
```bash
jq '.sequences | keys | length' "$cache_file"
```

## Intended Behavior

Validation should report accurate counts by checking the actual data sources used by the HTML generator:

| Data | Source to Check | jq Query |
|------|-----------------|----------|
| Embeddings | `embeddings.json` | `.embeddings \| keys \| length` |
| Similarity | `similarity_rankings_cache.json` | `.rankings \| keys \| length` |
| Diversity | `diversity_cache.json` | `.sequences \| keys \| length` |

Expected output after fix:
```
Embeddings
  ├─ Progress: 7844 / 7844 (100.0%) ✓
  └─ Status: COMPLETE

Similarity Matrix
  ├─ Progress: 7844 / 7844 (100.0%) ✓
  └─ Status: COMPLETE

Diversity Cache
  ├─ Progress: 7844 / 7844 (100.0%) ✓
  └─ Status: COMPLETE
```

## Suggested Implementation Steps

1. **Fix `count_embeddings()` function**:
   - Remove the misleading comment about "just metadata"
   - Use jq to count `.embeddings | keys | length`
   - Handle missing file gracefully

2. **Fix `count_similarity_files()` function**:
   - Rename to `count_similarity_rankings()` for clarity
   - Check `similarity_rankings_cache.json` instead of individual files
   - Use jq to count `.rankings | keys | length`

3. **Fix `check_diversity_cache()` function**:
   - Change from `jq 'length'` to `jq '.sequences | keys | length'`

4. **Add cleanup command for stale similarity files**:
   - The `similarities/` directory contains 14,287 individual `.json` files from an older, larger dataset
   - These are no longer used (HTML generator uses `similarity_rankings_cache.json` instead)
   - Add `--cleanup-stale` flag to remove orphan files
   - Or add a separate `--cleanup` mode that removes files not matching current poem IDs

5. **Implement stale file cleanup**:
   ```bash
   # Remove all individual similarity files (they're superseded by the rankings cache)
   rm -rf "$EMBEDDINGS_DIR/$MODEL/similarities/"
   ```
   - The `similarity_rankings_cache.json` contains all pre-sorted rankings
   - Individual files were from an older architecture and waste **4.4 GB** of disk space
   - Add confirmation prompt or `--force` flag for safety

6. **Test with current data**:
   - Verify all three counts now show 7844/7844
   - Verify exit code is 0 (ready for deployment)

## Related Issues

- Issue 10-011: Implement Pipeline Data Validation Utility (original implementation)
- Issue 8-048: Flatten Media Directory (discovered this bug while testing)

## Files to Modify

| File | Change |
|------|--------|
| `scripts/validate-pipeline-data` | Fix counting logic in three functions |

## Test Commands

After fix, these should all return 7844:

```bash
# Embeddings
jq '.embeddings | keys | length' assets/embeddings/embeddinggemma_latest/embeddings.json

# Similarity rankings
jq '.rankings | keys | length' assets/embeddings/embeddinggemma_latest/similarity_rankings_cache.json

# Diversity sequences
jq '.sequences | keys | length' assets/embeddings/embeddinggemma_latest/diversity_cache.json
```

## Metadata

- **Status**: Open
- **Created**: 2026-01-23
- **Phase**: 10 (Pipeline & Tooling)
- **Estimated Complexity**: Low (straightforward jq query fixes)
- **Dependencies**: None
- **Affects**: Pipeline validation, deployment workflow confidence
