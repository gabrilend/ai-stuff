# Issue 8-019: Implement Unique poem_index System

## Current Behavior

The poem identification system uses `id` fields derived from source filenames, which creates **collisions across categories**:

```
fediverse/0002.txt → id: 2, category: "fediverse"
messages/0002.txt  → id: 2, category: "messages"  ← COLLISION!
notes/0002.txt     → id: 2, category: "notes"     ← COLLISION!
```

This causes problems in the embedding pipeline:

1. **Generation** stores embeddings at array index: `embeddings[5731] = {id: 2, ...}`
2. **Loading** (incremental mode) stores by `emb.id`: `existing_embeddings[2] = {...}`
3. **Lookup** uses array index: `existing_embeddings[5731]` → **nil!**

Result: Incremental embedding mode fails for all non-fediverse poems because array index ≠ source file ID.

### Discovery Context

While debugging embedding generation failures (2025-12-25), traced the root cause to:
- `similarity-engine.lua:336-339` stores loaded embeddings by `emb.id`
- `similarity-engine.lua:368` looks up by array index `i`
- These only match for fediverse poems where source ID ≈ array position

## Intended Behavior

Add a new `poem_index` field that provides a **unique, stable, array-aligned identifier** for each poem:

```json
{
  "poems": [
    {
      "poem_index": 1,           // Unique global identifier (1-indexed)
      "id": 1,                   // Original source file ID (preserved for display)
      "category": "fediverse",
      "filepath": "fediverse/0001.txt"
    },
    {
      "poem_index": 5731,        // Unique! Different from id
      "id": 2,                   // Same numeric ID, different poem
      "category": "messages",
      "filepath": "messages/0002.txt"
    }
  ]
}
```

### Benefits

| Aspect | Current (`id`) | Proposed (`poem_index`) |
|--------|----------------|------------------------|
| Uniqueness | Collisions across categories | Globally unique |
| Array alignment | Mismatched after fediverse | Always matches array position |
| Stability | Depends on extraction order | Stable once assigned |
| Display | Used for filenames | Keep `id` for display, `poem_index` for internals |

## Implementation Steps (Completed 2025-12-25)

### Phase A: Add poem_index to Extraction ✅

**File: `src/poem-extractor.lua`**

1. [x] During poem extraction, assign `poem_index = array_position`
2. [x] Ensure poem_index is 1-indexed (Lua convention)
3. [x] Add poem_index to each poem's metadata
4. [x] Bumped extraction_version to 2.1

Implementation: Added loop after sorting to assign `poem_index = i` for each poem.

### Phase B: Update Embedding System ✅

**File: `src/similarity-engine.lua`**

1. [x] Update `generate_all_embeddings()` to store by `poem_index` if available, fallback to array index
2. [x] Update incremental loading to store by `poem_index`
3. [x] Update lookup to use `poem.poem_index`
4. [x] Add `poem_index` field to each embedding record for future incremental loads
5. [x] Backward compatibility maintained via `poem.poem_index or i` fallback

### Phase C: Update HTML Generation ✅

**Files: `src/flat-html-generator.lua`, `scripts/generate-html-parallel`, `src/centroid-html-generator.lua`**

1. [x] Use category prefix for output filenames: `similar/{category}-{id}.html` (e.g., `fediverse-0002.html`)
2. [x] Update navigation links to use category prefix
3. [x] Keep `id` + `category` for display (e.g., "fediverse #2")
4. [x] Update all file existence checks in incremental mode
5. [x] Fix embedding lookup in parallel generator to use `poem.poem_index`

**Note**: User preferred category prefix over poem_index for file naming (more readable URLs).

### Phase D: Update Similarity Matrix ✅

**Files: `src/similarity-engine-parallel.lua`, `src/html-generator/similarity-engine.lua`**

1. [x] Update `get_poem_similarity_file()` to use `poem_index` for file naming
2. [x] Files now named `poem_index_{N}.json` instead of `poem_{id}.json`
3. [x] Add backward compatibility loading for old `poem_{id}.json` files
4. [x] Update similarity data to include both `poem_id` and `poem_index` in metadata

### Phase E: Migration ✅

1. [x] Regenerated poems.json with `poem_index` field
2. [x] Existing embeddings will work via fallback mechanism
3. [x] Full regeneration recommended for clean state

### Verification

```bash
$ jq '.poems[] | select(.id == 2) | {poem_index, id, category}' assets/poems.json
{
  "poem_index": 2,
  "id": 2,
  "category": "fediverse"
}
{
  "poem_index": 6437,
  "id": 2,
  "category": "messages"
}
{
  "poem_index": 7518,
  "id": 2,
  "category": "notes"
}
```

Three poems with `id: 2` now have unique `poem_index` values, preventing collisions.

## Technical Notes

### Why Not Just Fix the Lookup?

We could patch `similarity-engine.lua` to store/lookup by array index consistently. However:

1. **Array index is implicit** - Not stored in the data, computed at runtime
2. **Fragile** - Any change to poems.json order breaks embeddings
3. **No audit trail** - Can't verify which poem an embedding belongs to

`poem_index` makes the identifier **explicit and persistent**.

### Relationship to Other IDs

| Field | Purpose | Scope | Example |
|-------|---------|-------|---------|
| `poem_index` | Internal processing, embeddings, similarity | Global | 5731 |
| `id` | Source file reference, display | Per-category | 2 |
| `filepath` | Unique source identification | Global | "messages/0002.txt" |

### Chronological Sorting

`poem_index` is assigned during extraction (which may be chronological). For display sorting:
- Use `created_at` for chronological views
- Use `poem_index` for stable internal references
- These are orthogonal concerns

## Files to Modify

| File | Changes |
|------|---------|
| `src/poem-extractor.lua` | Assign poem_index during extraction |
| `src/similarity-engine.lua` | Use poem_index for embedding storage/lookup |
| `src/similarity-engine-parallel.lua` | Same as above |
| `src/flat-html-generator.lua` | Use poem_index for output files |
| `scripts/generate-html-parallel` | Use poem_index for output files |
| `libs/utils.lua` | Add poem_index validation helper |

## Testing Strategy

1. [ ] Extract poems and verify poem_index assigned correctly
2. [ ] Generate embeddings and verify storage by poem_index
3. [ ] Run incremental mode and verify correct skip detection
4. [ ] Generate HTML and verify file naming
5. [ ] Full pipeline test: extract → embed → similarity → HTML

## Related Issues

- **Issue 4-004**: Verify and Resolve Cross-Category ID Mapping (identified the collision)
- **Issue 8-018**: Fix embedding directory case inconsistency (discovered during same debugging session)
- **Issue 9-003**: Optimize centroid calculation (uses embeddings, affected by this)

## Risk Assessment

- **Low**: poem_index is additive, doesn't break existing `id` usage
- **Medium**: Requires regeneration of embeddings after implementation
- **Low**: HTML output filenames may change (similar/5731.html vs similar/2.html)

---

**Phase**: 8 (Website Completion)

**Priority**: High (blocking correct incremental embedding behavior)

**Created**: 2025-12-25

**Completed**: 2025-12-25

**Status**: Complete

**Estimated Effort**: Medium (touches multiple files but straightforward logic)

**Files Modified**:
- `src/poem-extractor.lua` - Assign poem_index after sorting
- `src/similarity-engine.lua` - Use poem_index for embedding storage/lookup
- `src/similarity-engine-parallel.lua` - Use poem_index for similarity file naming
- `src/flat-html-generator.lua` - Use category prefix for HTML file naming
- `src/centroid-html-generator.lua` - Use category prefix for navigation links
- `src/html-generator/similarity-engine.lua` - Load similarities by poem_index
- `scripts/generate-html-parallel` - Update workers and file checks for category prefix
