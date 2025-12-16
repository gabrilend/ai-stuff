# Issue 5-025: Optimize Similarity Matrix to Triangular Storage

## Current Behavior
- Similarity matrices store sparse pre-sorted lists of similarities
- Each poem stores only a subset of its similarities (e.g., top 100 most similar)
- Storage format uses JSON with sorted arrays per poem
- May store duplicate calculations (both A→B and B→A) in some implementations
- Total storage varies based on how many similarities are kept per poem

## Intended Behavior
- Switch to upper/lower triangular matrix storage
- Store each similarity exactly once (avoiding A→B and B→A duplication)
- Provide complete similarity data for all poem pairs
- Enable O(1) lookup for any poem pair similarity
- Reduce complexity while maintaining full data access
- Store as efficient triangular structure with ~27M values instead of ~54M

## Suggested Implementation Steps

### 1. **Design Triangular Storage Format**
```lua
-- Store only upper triangle (i < j)
-- For poems with IDs 1,2,3,4:
-- Store: [1,2], [1,3], [1,4], [2,3], [2,4], [3,4]
-- Skip: [2,1], [3,1], [4,1], [3,2], [4,2], [4,3] (redundant)
```

### 2. **Implement Triangular Matrix Generator**
```lua
-- {{{ function generate_triangular_similarity_matrix
local function generate_triangular_similarity_matrix(embeddings)
    local matrix = {}
    local poem_ids = get_sorted_poem_ids(embeddings)
    
    for i = 1, #poem_ids do
        local id_i = poem_ids[i]
        matrix[id_i] = {}
        
        for j = i + 1, #poem_ids do  -- Only calculate upper triangle
            local id_j = poem_ids[j]
            local similarity = calculate_cosine_similarity(
                embeddings[id_i], 
                embeddings[id_j]
            )
            matrix[id_i][id_j] = similarity
        end
    end
    
    return matrix
end
-- }}}
```

### 3. **Implement Symmetric Lookup Function**
```lua
-- {{{ function get_similarity
local function get_similarity(matrix, id1, id2)
    -- Handle diagonal (self-similarity)
    if id1 == id2 then return 1.0 end
    
    -- Ensure consistent ordering for triangle lookup
    local min_id = math.min(tonumber(id1), tonumber(id2))
    local max_id = math.max(tonumber(id1), tonumber(id2))
    
    -- Look up in upper triangle
    if matrix[tostring(min_id)] and matrix[tostring(min_id)][tostring(max_id)] then
        return matrix[tostring(min_id)][tostring(max_id)]
    end
    
    -- Fallback (should not happen with complete matrix)
    return 0.0
end
-- }}}
```

### 4. **Optimize Storage Format**
```lua
-- Consider packed binary format for ultimate efficiency
-- 27M floats × 4 bytes = 108 MB (JSON)
-- Could reduce to ~100 MB with binary storage
-- But JSON is fine for this scale and easier to debug

-- Compact JSON structure:
{
  "1": {"2": 0.875, "3": 0.234, "4": 0.567, ...},
  "2": {"3": 0.445, "4": 0.689, ...},
  "3": {"4": 0.812, ...},
  ...
}
```

### 5. **Update Similarity Retrieval Functions**
```lua
-- {{{ function get_all_similarities_for_poem
local function get_all_similarities_for_poem(matrix, poem_id, poem_ids)
    local similarities = {}
    
    for _, other_id in ipairs(poem_ids) do
        if other_id ~= poem_id then
            local score = get_similarity(matrix, poem_id, other_id)
            table.insert(similarities, {
                target_id = other_id,
                score = score
            })
        end
    end
    
    -- Sort by similarity score
    table.sort(similarities, function(a, b) 
        return a.score > b.score 
    end)
    
    return similarities
end
-- }}}
```

### 6. **Migration Path**
- Load existing sparse similarity data
- Regenerate as triangular matrix
- Validate all similarities preserved correctly
- Update all consuming code to use new lookup functions
- Performance test with full 7,355 poem dataset

## Benefits of Triangular Approach

### **Storage Efficiency**
- **Exactly 50% reduction** in redundant storage
- Store N×(N-1)/2 values instead of N×N
- For 7,355 poems: ~27M values vs ~54M

### **Completeness**
- **All similarities available** - no truncation to "top K"
- Enables any analysis requiring full similarity data
- Supports dynamic threshold-based filtering
- Future-proof for new navigation features

### **Simplicity**
- **Single source of truth** - each similarity stored exactly once
- No duplicate calculations or storage
- Cleaner conceptual model
- Easier to validate and debug

### **Performance**
- **O(1) lookup** for any poem pair
- **Memory-efficient** at 108MB (well within constraints)
- **Cache-friendly** access patterns
- No need to maintain sorted lists

## Technical Considerations

### Memory Usage
- 7,355 poems = 27,037,485 unique pairs
- 32-bit float per similarity = ~103 MB
- JSON overhead ≈ 5-10 MB
- **Total: ~108 MB** (confirmed within system constraints)

### Access Patterns
- Reading similarities for one poem requires accessing multiple matrix rows
- But avoids sorting overhead since we sort on-demand
- Better for "find all poems within similarity threshold X" queries

## Files to Modify
- `/src/similarity-calculator.lua` - Core similarity calculation
- `/src/flat-html-generator.lua` - Update similarity lookups
- `/libs/similarity-utils.lua` - New utility functions for triangular access
- Any other files consuming similarity data

## Testing Requirements
- Verify all 27M+ similarities correctly calculated
- Confirm symmetric lookup works (get_similarity(A,B) == get_similarity(B,A))
- Performance benchmark vs current approach
- Validate HTML generation still works correctly
- Ensure "similar" and "unique" navigation links function properly

## Priority
**Medium** - Optimization that improves storage efficiency and data completeness without blocking features

## Dependencies
- Existing similarity calculation infrastructure
- Embedding data must be available

**Note**: This optimization provides full similarity data access while reducing storage by 50% and maintaining O(1) lookups. The 108MB memory requirement is well within modern system constraints.