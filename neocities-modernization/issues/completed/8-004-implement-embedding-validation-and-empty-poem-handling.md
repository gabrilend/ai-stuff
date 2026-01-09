# Issue 8-004: Implement Embedding Validation and Empty Poem Handling

## Current Behavior

The embedding generation system (`src/similarity-engine.lua`) can produce three types of non-valid embeddings:

1. **Empty poem content**: Stores `embedding = nil, error = "empty_content"`
2. **Network/API errors**: Stores `embedding = nil, error = "network_error"` (or similar)
3. **Invalid dimensions**: Stores embedding with wrong dimension count

The HTML generation scripts (`scripts/generate-html-parallel`, `scripts/precompute-diversity-sequences`) do not validate that all poems have valid embeddings before proceeding, leading to:
- Index mapping bugs when some poems lack embeddings
- Incomplete output files
- Silent failures or hangs

## Intended Behavior

### For Empty Poem Content
Generate a **random 768-dimensional embedding** for poems with empty content. This places empty poems semi-randomly throughout the similarity/diversity ordering rather than excluding them entirely.

```lua
-- Generate random embedding for empty poems
local function generate_random_embedding(dimension)
    local embedding = {}
    for i = 1, dimension do
        embedding[i] = math.random() * 2 - 1  -- Range: -1 to 1
    end
    return embedding
end
```

### For Network/API Errors
Keep the error record. The user must re-run embedding generation to resolve these. The embedding generation system already supports incremental mode which will retry error entries.

### For Invalid Dimensions
Keep the error record. The user must re-run embedding generation with the correct model.

### For HTML Generation
Add a **pre-flight validation check** that:
1. Loads poems.json and embeddings.json
2. Counts poems with content that lack valid 768-dimensional embeddings
3. If any are found (excluding empty poems which now get random embeddings), **exit with error** and prompt user to regenerate embeddings

## Implementation Steps

### Step 1: Modify embedding generation for empty poems ✅ COMPLETED
- [x] In `src/similarity-engine.lua`, function `M.generate_all_embeddings`
- [x] When `poem_text == ""`, generate random 768-dim embedding instead of storing error
- [x] Add `is_random = true` flag to metadata so it's clear this is synthetic
- [x] Seed random generator with poem ID for reproducibility
- [x] Normalize to unit vector for consistent similarity calculations

### Step 2: Add validation check to generate-html-parallel ✅ COMPLETED
- [x] After loading poems and embeddings, validate all poems with content have embeddings
- [x] Count: poems with content but no embedding, poems with wrong dimensions
- [x] If count > 0, print error message and exit with non-zero code
- [x] Suggest command to regenerate: `lua src/similarity-engine.lua -I` option 1
- [x] Report count of random embeddings (expected for empty poems)

### Step 3: Add validation check to precompute-diversity-sequences ✅ COMPLETED
- [x] Same validation as generate-html-parallel
- [x] Exit early before expensive computation if embeddings incomplete
- [x] Report count of random embeddings

### Step 4: Update embedding stats display ✅ COMPLETED
- [x] Show count of random embeddings (empty poems) vs real embeddings
- [x] Show count of error entries that need regeneration

## Quality Assurance Criteria

- [ ] Empty poems get random embeddings (reproducible with same seed)
- [ ] Poems with content but no embedding cause validation failure
- [ ] HTML generation scripts exit cleanly with helpful message when validation fails
- [ ] Incremental embedding generation retries error entries
- [ ] Random embeddings are normalized (unit vectors) for consistent similarity calculations

## Related Issues

- **Issue 8-002**: Multi-threaded HTML generation (parent issue)
- **Issue 8-001**: Pipeline integration

---

**ISSUE STATUS: COMPLETED**

**Created**: 2025-12-14

**Completed**: 2025-12-14

**Phase**: 8 (Website Completion)

**Priority**: High (blocking HTML generation)

## Summary of Changes

1. **`src/similarity-engine.lua`**: Added `generate_random_embedding()` function that creates reproducible random 768-dim unit vectors seeded by poem ID. Empty poems now get random embeddings with `is_random = true` flag instead of error records.

2. **`scripts/generate-html-parallel`**: Added pre-flight validation that checks all poems with content have valid embeddings. Exits with helpful error message if validation fails.

3. **`scripts/precompute-diversity-sequences`**: Same validation check added. Prevents expensive computation with incomplete data.
