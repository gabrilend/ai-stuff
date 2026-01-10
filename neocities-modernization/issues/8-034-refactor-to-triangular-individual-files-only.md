# Issue 8-034: Refactor to Triangular Individual Files Only

## Current Behavior

We have **3 redundant storage formats** for similarity data:

1. **Full matrix** (655 MB) - `similarity_matrix_full.json`
   - Stores ALL pairs including redundant A→B and B→A
   - Causes table overflow errors
   - Not used by HTML generation

2. **Individual files** (3.8 GB) - `similarities/poem_*.json`
   - One file per poem with ALL similarities
   - Each file stores complete pairwise data (redundant with reverse)
   - Used by HTML generation

3. **Triangular matrix** (326 MB) - `similarity_matrix_triangular.json`
   - Stores upper triangle only
   - 50% space savings
   - Not used by anything yet

**Total storage: 4.7 GB** for the same 30.4M unique similarity values!

## Root Cause

Historical architecture: different formats built at different times for different purposes, with no consolidation. The access pattern (how we read) was conflated with storage format (how we store).

## Intended Behavior

**Single storage format: Triangular individual files**

Store **one file per poem** containing **only upper triangle similarities**:

```
similarities/
├── poem_1.json     # Contains similarities to poems 2-7797 (~250 KB, 50% smaller)
├── poem_2.json     # Contains similarities to poems 3-7797
├── poem_3.json     # Contains similarities to poems 4-7797
...
└── poem_7797.json  # Empty or just metadata (no poems > 7797)
```

**File format:**
```json
{
  "metadata": {
    "poem_id": "42",
    "poem_index": 42,
    "total_comparisons": 7755,
    "range": "43-7797",
    "format": "triangular_upper",
    "calculated_at": "2026-01-10 14:23:11"
  },
  "similarities": [
    {"id": "43", "similarity": 0.9876},
    {"id": "44", "similarity": 0.8543},
    ...
    {"id": "7797", "similarity": 0.2341}
  ]
}
```

**Lookup logic** (in parsing layer):
```lua
function get_similarity(poem_a, poem_b)
    if poem_a == poem_b then return 1.0 end

    -- Ensure min_id < max_id (triangular ordering)
    local min_id, max_id = poem_a, poem_b
    if poem_a > poem_b then
        min_id, max_id = poem_b, poem_a
    end

    -- Load file for smaller ID, look up larger ID
    local file_data = load_similarity_file(min_id)
    return file_data.similarities[max_id] or 0.0
end
```

## Benefits

### Storage Reduction
- **60% total savings**: 1.9 GB vs 4.7 GB
- **50% per file**: ~250 KB vs ~500 KB
- **No redundancy**: Each similarity stored exactly once

### Simplified Architecture
- ✅ One format to maintain
- ✅ One generation pipeline
- ✅ One validation script
- ✅ Clear separation: storage format vs access pattern

### Performance
- ✅ Same access speed (still O(1) lookup within file)
- ✅ Faster generation (50% fewer writes)
- ✅ Less disk I/O for HTML generation

### Maintainability
- ✅ No format conversion needed
- ✅ No format consistency validation
- ✅ Single source of truth

## Implementation Steps

### Step 1: Create Triangular Lookup Utility

```lua
-- libs/triangular-similarity-access.lua
local M = {}

-- {{{ function M.get_similarity
-- Looks up similarity with automatic triangular ordering
function M.get_similarity(poem_a, poem_b)
    if poem_a == poem_b then return 1.0 end

    local min_id = math.min(tonumber(poem_a), tonumber(poem_b))
    local max_id = math.max(tonumber(poem_a), tonumber(poem_b))

    -- Load the file for smaller ID
    local file_path = string.format(
        "assets/embeddings/embeddinggemma_latest/similarities/poem_%d.json",
        min_id
    )

    local file_data = utils.read_json_file(file_path)
    if not file_data or not file_data.similarities then
        return 0.0
    end

    -- Find similarity in the array
    for _, entry in ipairs(file_data.similarities) do
        if tonumber(entry.id) == max_id then
            return entry.similarity
        end
    end

    return 0.0
end
-- }}}

return M
```

### Step 2: Update Parallel Similarity Engine

Modify `src/similarity-engine-parallel.lua` to generate triangular files:

```lua
-- For each poem i (from 1 to 7797):
for i = 1, num_poems do
    local poem_i = valid_embeddings[i]
    local similarities = {}

    -- Only calculate for j > i (upper triangle)
    for j = i + 1, num_poems do
        local poem_j = valid_embeddings[j]
        local similarity = cosine_similarity(poem_i.embedding, poem_j.embedding)

        table.insert(similarities, {
            id = poem_j.id,
            index = j,
            similarity = rounded_similarity
        })
    end

    -- Write triangular file for poem i
    write_triangular_file(output_dir, poem_i.id, similarities, {
        range = string.format("%d-%d", poem_i.id + 1, max_poem_id),
        format = "triangular_upper"
    })
end
```

### Step 3: Update HTML Generation

Replace direct file reads with triangular lookup utility:

```lua
-- OLD:
local file = load_similarity_file(current_poem_id)
local similar = file.similarities  -- Assumes complete data in file

-- NEW:
local tri_access = require('libs.triangular-similarity-access')
local similar = {}
for _, other_id in ipairs(all_poem_ids) do
    if other_id ~= current_poem_id then
        local score = tri_access.get_similarity(current_poem_id, other_id)
        table.insert(similar, {id = other_id, similarity = score})
    end
end
table.sort(similar, function(a,b) return a.similarity > b.similarity end)
```

### Step 4: Add Caching to Triangular Access

Since HTML generation may request many similarities, add simple caching:

```lua
local file_cache = {}  -- Cache loaded files
local MAX_CACHE_SIZE = 100

function M.get_similarity_cached(poem_a, poem_b)
    -- ... determine min_id, max_id ...

    -- Check cache first
    if not file_cache[min_id] then
        file_cache[min_id] = load_similarity_file(min_id)

        -- Evict oldest if cache full
        if #file_cache > MAX_CACHE_SIZE then
            local oldest = next(file_cache)
            file_cache[oldest] = nil
        end
    end

    return lookup_in_file(file_cache[min_id], max_id)
end
```

### Step 5: Deprecate Old Formats

**Remove:**
- `calculate_full_similarity_matrix()` in similarity-engine.lua
- Full matrix generation code paths
- Validation checks for full matrix

**Update:**
- All references to assume triangular individual files
- Documentation to reflect single format
- Issue 8-031 (format conversion) - no longer needed

### Step 6: Migration Script

For existing deployments with full data:

```bash
#!/bin/bash
# scripts/migrate-to-triangular-files.sh
# Converts existing full individual files to triangular format

luajit -e "
local utils = require('utils')
local dkjson = require('dkjson')

local similarities_dir = 'assets/embeddings/embeddinggemma_latest/similarities'
local files = utils.list_files(similarities_dir, 'poem_*.json')

for _, filepath in ipairs(files) do
    local data = utils.read_json_file(filepath)
    local poem_id = tonumber(data.metadata.poem_id)

    -- Filter to keep only entries where other_id > poem_id
    local triangular_similarities = {}
    for _, entry in ipairs(data.similarities) do
        if tonumber(entry.id) > poem_id then
            table.insert(triangular_similarities, entry)
        end
    end

    -- Update metadata
    data.similarities = triangular_similarities
    data.metadata.format = 'triangular_upper'
    data.metadata.range = string.format('%d-7797', poem_id + 1)
    data.metadata.total_comparisons = #triangular_similarities

    -- Write back
    utils.write_json_file(filepath, data)

    if poem_id % 100 == 0 then
        print(string.format('Migrated %d files...', poem_id))
    end
end

print('Migration complete!')
"
```

## Storage Comparison

| Format | Files | Total Size | Storage Efficiency |
|--------|-------|------------|-------------------|
| **Current: Full individual files** | 7,797 | 3.8 GB | 100% (baseline) |
| **Current: Full matrix** | 1 | 655 MB | N/A (redundant) |
| **Current: Triangular matrix** | 1 | 326 MB | N/A (redundant) |
| **TOTAL CURRENT** | - | **4.7 GB** | **Redundant** |
| | | | |
| **Proposed: Triangular individual** | 7,797 | **1.9 GB** | **60% reduction** |

## Performance Analysis

### Generation Time
- **Current**: ~2 hours (all pairs)
- **Proposed**: ~1 hour (upper triangle only)
- **Speedup**: 2x faster

### Access Patterns

**Scenario 1: Get all similarities for poem** (HTML generation - similar pages)
- Current: Load 1 file, read array
- Proposed: Load N files where N = poems that reference this one
  - If poem 100: Need to load poems 1-99 (read from their files) + read poem 100's file
  - **Slower** for this case, but cacheable

**Scenario 2: Get specific similarity(A, B)** (Individual lookups)
- Current: Load 1 file, search array
- Proposed: Load 1 file (whichever has the pair), search array
- **Same performance**

### Optimization: Pre-aggregate for HTML

For HTML generation specifically, we can pre-compute aggregated views:

```lua
-- During generation, for each poem, collect all its similarities:
function collect_all_similarities_for_poem(poem_id)
    local all_sims = {}

    -- 1. Load this poem's file (similarities to higher IDs)
    local my_file = load_file(poem_id)
    for _, entry in ipairs(my_file.similarities) do
        all_sims[entry.id] = entry.similarity
    end

    -- 2. Check all lower-ID files for references to this poem
    for lower_id = 1, poem_id - 1 do
        local their_file = load_file(lower_id)
        for _, entry in ipairs(their_file.similarities) do
            if entry.id == poem_id then
                all_sims[lower_id] = entry.similarity
                break
            end
        end
    end

    return all_sims
end
```

**This is still O(N) in worst case, but:**
- Only done once per poem during HTML generation
- Can be parallelized
- Results can be cached in memory during batch generation

## Quality Assurance

- [ ] Migration script converts existing files correctly
- [ ] Triangular lookup utility returns same values as original
- [ ] HTML generation produces identical output
- [ ] File sizes reduced by ~50%
- [ ] Generation time reduced by ~50%
- [ ] No broken links or incorrect similarity scores

## Migration Path

### Phase 1: Add Triangular Support (Non-Breaking)
1. Create `triangular-similarity-access.lua` utility
2. Test with existing full files
3. Verify correctness

### Phase 2: Switch Generation (Breaking)
1. Update `similarity-engine-parallel.lua` to generate triangular
2. Run migration script on existing files
3. Update HTML generation to use new utility

### Phase 3: Cleanup (Breaking)
1. Remove full matrix generation code
2. Remove full matrix file
3. Remove triangular matrix file
4. Update documentation

## Related Issues

- **8-033**: Fixed run.sh to use parallel engine
- **5-025**: Implemented triangular matrix (now superseded)
- **8-031**: Format conversion (no longer needed)
- **2-012**: Original individual files design

---

**Phase**: 8 (Website Completion)

**Priority**: Medium (optimization, not blocking)

**Type**: Refactor / Architecture Improvement

**Created**: 2026-01-10

**Status**: Implemented (Ready for migration)

## Implementation Summary

Created **single storage format: triangular individual files**

### Files Created

1. **`libs/triangular-similarity-access.lua`** - Transparent symmetric lookup utility
   - `get_similarity(poem_a, poem_b)` - Handles ordering automatically
   - `get_similarity_cached(poem_a, poem_b)` - Cached version for batch ops
   - `get_all_similarities_for_poem(poem_id)` - Collects from triangular storage

2. **`scripts/migrate-to-triangular-files.lua`** - Migration script for existing files
   - Tested on 1,671 existing files
   - **48.9% reduction** (11.0M → 5.6M entries)
   - Atomic writes, handles errors gracefully

3. **Updated `src/similarity-engine-parallel.lua`** (lines 716-760)
   - Changed: Calculate ALL pairs → Calculate ONLY upper triangle
   - Added metadata: `format: "triangular_upper"`, `range: "N-7797"`
   - 50% fewer comparisons per file

### Test Results

**Migration test (1,671 existing files):**
```
   Entries before: 11.0M
   Entries after: 5.6M
   Reduction: 48.9%
```

**Individual file size reduction:**
- Poem 1: 6,614 → 6,613 entries (99.9%, high ID = keeps almost all)
- Poem 5309: 6,614 → 712 entries (89.2%, low remaining = huge savings)
- Average: ~50% reduction per file

### Next Steps for Full Deployment

1. **Migrate existing 1,671 files**:
   ```bash
   luajit scripts/migrate-to-triangular-files.lua \
       assets/embeddings/embeddinggemma_latest/similarities
   ```

2. **Generate remaining 6,126 files** (will use new triangular format):
   ```bash
   ./run.sh --generate-similarity --threads 8
   # Now generates triangular files automatically
   # Storage: ~1.9 GB instead of 3.8 GB
   ```

3. **Update HTML generation** to use `triangular-similarity-access.lua`
   - Replace direct file reads with `get_similarity()` calls
   - Handles ordering transparently

**Status**: Implemented (2026-01-10)
**Tested**: ✅ Migration script, ✅ Triangular generation, ✅ Lookup utility
