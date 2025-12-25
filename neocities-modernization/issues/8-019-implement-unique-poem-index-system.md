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

## Suggested Implementation Steps

### Phase A: Add poem_index to Extraction

**File: `src/poem-extractor.lua`**

1. [ ] During poem extraction, assign `poem_index = array_position`
2. [ ] Ensure poem_index is 1-indexed (Lua convention)
3. [ ] Add poem_index to each poem's metadata
4. [ ] Update poems.json schema documentation

```lua
-- In extraction loop:
for i, poem in ipairs(extracted_poems) do
    poem.poem_index = i  -- Unique, array-aligned identifier
end
```

### Phase B: Update Embedding System

**File: `src/similarity-engine.lua`**

1. [ ] Update `generate_all_embeddings()` to store by `poem_index` if available, fallback to array index
2. [ ] Update incremental loading (lines 334-346) to store by `poem_index`
3. [ ] Update lookup (line 368) to use `poem.poem_index`
4. [ ] Ensure backward compatibility with existing embeddings (migration path)

```lua
-- Incremental loading fix:
for i, emb in ipairs(existing_data.embeddings) do
    local key = emb.poem_index or i  -- Use poem_index if available
    existing_embeddings[key] = emb
end

-- Lookup fix:
local lookup_key = poem.poem_index or i
if incremental and existing_embeddings[lookup_key] and ...
```

### Phase C: Update HTML Generation

**Files: `src/flat-html-generator.lua`, `scripts/generate-html-parallel`**

1. [ ] Use `poem_index` for output filenames: `similar/{poem_index}.html`
2. [ ] Update navigation links to use `poem_index`
3. [ ] Consider keeping `id` + `category` for display (e.g., "fediverse #2")

### Phase D: Update Similarity Matrix

**Files: `src/similarity-engine.lua`, `src/similarity-engine-parallel.lua`**

1. [ ] Ensure similarity matrix uses `poem_index` as keys
2. [ ] Update similarity file naming: `similarities/poem_{poem_index}.json`

### Phase E: Migration Path

1. [ ] Create migration script to add `poem_index` to existing poems.json
2. [ ] Handle existing embeddings gracefully (regenerate or migrate)
3. [ ] Document breaking changes for any external consumers

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

**Status**: Open

**Estimated Effort**: Medium (touches multiple files but straightforward logic)
