# Issue 8-031: Convert Between Similarity Matrix Formats

## Current Behavior

The project maintains three different similarity matrix storage formats, each serving a distinct purpose:

1. **Individual per-poem files** (Issue 2-012)
   - Location: `assets/embeddings/embeddinggemma_latest/similarities/poem_*.json`
   - Current: 1,671 files (21% complete)
   - Purpose: Efficient HTML generation, granular access
   - Size: ~500 KB per file
   - Format: `{metadata: {...}, similarities: [{id, index, similarity}, ...]}`

2. **Full pairwise matrix** (Issue 8-029)
   - Location: `assets/embeddings/embeddinggemma_latest/similarity_matrix_full.json`
   - Current: 655 MB (appears complete)
   - Purpose: Comprehensive calculations, algorithm research
   - Format: `{similarities: {poem_id: {other_id: score}}}`

3. **Triangular matrix** (Issue 5-025)
   - Location: `assets/embeddings/embeddinggemma_latest/similarity_matrix_triangular.json`
   - Current: 326 MB (space-optimized)
   - Purpose: Storage efficiency (avoids A→B and B→A duplication)
   - Format: Upper triangle only, symmetric lookup required

**The Problem**: These three formats are **redundantly computed**:
- If the full matrix exists (655 MB), we could derive all 7,797 individual files from it
- If the triangular matrix exists, we could derive the full matrix or individual files
- Currently generating individual files from scratch (21% done, 79% remaining ~2 hours)
- No tooling exists to convert between formats

This wastes both **computation time** and **disk space**.

## Intended Behavior

Provide conversion utilities to:
1. **Extract individual files from monolithic matrices** (avoid redundant computation)
2. **Build monolithic matrices from individual files** (consolidate results)
3. **Convert between full ↔ triangular formats** (optimize storage)
4. **Validate consistency** across formats (detect corruption/staleness)

### Use Cases

**Use Case 1: Accelerate Individual File Generation**
```bash
# Instead of computing 6,126 files from scratch (~2 hours):
lua src/similarity-engine-parallel.lua  # Current approach

# Convert from existing full matrix (~30 seconds):
lua scripts/convert-similarity-formats.lua --from-full --to-individual
```

**Use Case 2: Optimize Storage**
```bash
# Convert full matrix to triangular to save 329 MB:
lua scripts/convert-similarity-formats.lua --from-full --to-triangular

# Reduce 7,797 individual files (3.8 GB) to single triangular matrix (326 MB):
lua scripts/convert-similarity-formats.lua --from-individual --to-triangular
```

**Use Case 3: Validate Consistency**
```bash
# Check if formats are in sync:
lua scripts/validate-similarity-consistency.lua

# Output:
#   ✅ Full matrix: 7,797 poems
#   ✅ Triangular matrix: matches full matrix
#   ⚠️  Individual files: 1,671/7,797 (6,126 missing)
#   💡 Suggestion: Run conversion to generate missing files
```

## Suggested Implementation Steps

### Step 1: Design Conversion API

```lua
-- {{{ M.convert_similarity_formats
-- Converts between similarity matrix storage formats
--
-- @param source_format string - "full", "triangular", or "individual"
-- @param target_format string - "full", "triangular", or "individual"
-- @param options table - {force: bool, threads: number, validate: bool}
-- @return success boolean, stats table
local function convert_similarity_formats(source_format, target_format, options)
    -- Load source data
    -- Transform to target format
    -- Write output with progress tracking
    -- Return statistics
end
-- }}}
```

### Step 2: Implement Converters

#### **A. Full Matrix → Individual Files**
```lua
-- {{{ local function full_to_individual
local function full_to_individual(full_matrix_path, output_dir, options)
    local full_matrix = load_json(full_matrix_path)
    local poem_ids = get_sorted_keys(full_matrix.similarities)

    -- Parallel processing with thread pool
    for i, poem_id in ipairs(poem_ids) do
        local poem_similarities = {}

        -- Extract all similarities for this poem
        for _, other_id in ipairs(poem_ids) do
            if other_id ~= poem_id then
                local score = get_similarity(full_matrix, poem_id, other_id)
                table.insert(poem_similarities, {
                    id = other_id,
                    index = find_poem_index(other_id),
                    similarity = score
                })
            end
        end

        -- Sort by similarity (descending)
        table.sort(poem_similarities, function(a, b)
            return a.similarity > b.similarity
        end)

        -- Write individual file
        write_individual_file(output_dir, poem_id, poem_similarities)

        if i % 100 == 0 then
            print(string.format("Progress: %d/%d files written", i, #poem_ids))
        end
    end
end
-- }}}
```

#### **B. Triangular Matrix → Full Matrix**
```lua
-- {{{ local function triangular_to_full
local function triangular_to_full(triangular_path, output_path)
    local tri_matrix = load_json(triangular_path)
    local full_matrix = {similarities = {}}

    -- Copy upper triangle
    for id1, row in pairs(tri_matrix) do
        full_matrix.similarities[id1] = {}
        for id2, score in pairs(row) do
            full_matrix.similarities[id1][id2] = score
        end
    end

    -- Mirror to lower triangle (symmetry)
    for id1, row in pairs(tri_matrix) do
        for id2, score in pairs(row) do
            full_matrix.similarities[id2] = full_matrix.similarities[id2] or {}
            full_matrix.similarities[id2][id1] = score
        end
    end

    -- Add diagonal (self-similarity = 1.0)
    for id, _ in pairs(full_matrix.similarities) do
        full_matrix.similarities[id][id] = 1.0
    end

    write_json(output_path, full_matrix)
end
-- }}}
```

#### **C. Individual Files → Full Matrix**
```lua
-- {{{ local function individual_to_full
local function individual_to_full(individual_dir, output_path)
    local full_matrix = {similarities = {}}
    local files = list_files(individual_dir, "poem_*.json")

    for _, filepath in ipairs(files) do
        local poem_data = load_json(filepath)
        local poem_id = poem_data.metadata.poem_id

        full_matrix.similarities[poem_id] = {}

        for _, sim_entry in ipairs(poem_data.similarities) do
            full_matrix.similarities[poem_id][sim_entry.id] = sim_entry.similarity
        end

        -- Add self-similarity
        full_matrix.similarities[poem_id][poem_id] = 1.0
    end

    write_json(output_path, full_matrix)
end
-- }}}
```

### Step 3: CLI Tool

```bash
#!/usr/bin/env luajit
# scripts/convert-similarity-formats.lua

# Usage examples:
lua scripts/convert-similarity-formats.lua --from-full --to-individual
lua scripts/convert-similarity-formats.lua --from-triangular --to-full
lua scripts/convert-similarity-formats.lua --from-individual --to-triangular --validate
```

### Step 4: Validation Tool

```lua
-- {{{ local function validate_consistency
local function validate_consistency()
    -- Load all three formats
    local full = load_full_matrix()
    local tri = load_triangular_matrix()
    local individual_files = list_individual_files()

    -- Check consistency
    local errors = {}

    -- Sample 100 random poem pairs
    for i = 1, 100 do
        local id1, id2 = random_poem_pair()

        local full_score = get_similarity(full, id1, id2)
        local tri_score = get_similarity(tri, id1, id2)
        local ind_score = get_individual_similarity(id1, id2)

        if math.abs(full_score - tri_score) > 0.0001 then
            table.insert(errors, {id1, id2, "full vs triangular"})
        end

        if ind_score and math.abs(full_score - ind_score) > 0.0001 then
            table.insert(errors, {id1, id2, "full vs individual"})
        end
    end

    return #errors == 0, errors
end
-- }}}
```

## Performance Estimates

| Conversion | Source Size | Target Size | Est. Time | Speedup vs Recompute |
|------------|-------------|-------------|-----------|----------------------|
| Full → Individual | 655 MB | 3.8 GB | 30 sec | 240× faster (vs 2 hours) |
| Triangular → Full | 326 MB | 655 MB | 15 sec | N/A |
| Individual → Full | 3.8 GB | 655 MB | 1 min | N/A |
| Full → Triangular | 655 MB | 326 MB | 20 sec | N/A |

## Benefits

1. **Avoid Redundant Computation**: Use existing full/triangular matrix to generate individual files (240× faster)
2. **Storage Optimization**: Keep only triangular matrix (326 MB) instead of all three (4.7 GB)
3. **Consistency Checking**: Validate that all formats are in sync
4. **Flexibility**: Switch between formats based on current needs
5. **Recovery**: Regenerate corrupted files from monolithic matrices

## Files to Create

- `scripts/convert-similarity-formats.lua` - Main conversion tool
- `scripts/validate-similarity-consistency.lua` - Validation tool
- `src/similarity-format-converter.lua` - Conversion library module

## Quality Assurance Criteria

- [ ] Full → Individual conversion produces identical files to ground truth
- [ ] Triangular → Full → Triangular is lossless (round-trip test)
- [ ] Individual → Full aggregates correctly
- [ ] Validation catches inconsistencies (inject corruption test)
- [ ] Progress tracking for long conversions
- [ ] Handles missing/incomplete source data gracefully

## Related Issues

- **2-012**: Individual file format specification
- **5-025**: Triangular matrix format specification
- **8-029**: Full matrix format specification
- **8-001**: Pipeline integration (may benefit from faster individual file generation)

## Priority Assessment

**Current Impact**: Medium
- 79% of individual files (6,126 poems) need generation
- Current approach: ~2 hours of computation
- Conversion approach: ~30 seconds

**Recommended**: Implement Full → Individual converter first to unblock HTML generation

---

**Phase**: 8 (Website Completion)

**Priority**: Medium (optimization, not blocking)

**Created**: 2026-01-10

**Status**: Open

**Type**: Feature / Optimization
