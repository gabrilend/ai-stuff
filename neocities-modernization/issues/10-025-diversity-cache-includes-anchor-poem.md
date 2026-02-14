# Issue 10-025: Diversity Cache Includes Anchor Poem as First Entry

## Status: COMPLETED

## Current Behavior

The diversity cache includes the anchor poem (source poem) as the first entry in each sequence:

```json
"sequences": {
    "4399": [4399, 4382, 896, 2878, ...]  // First entry is source poem itself
}
```

This causes the "different" (diversity) pages to show the anchor poem twice:
1. Once at the top as "=== ANCHOR POEM ==="
2. Again as "#1" in the "=== DIVERSITY RANKED ===" section

The user sees the same poem displayed twice, which is confusing and incorrect.

## Root Cause

In `libs/vulkan-compute/src/vk_diversity.c`, the diversity algorithm initializes the output sequence with the starting poem:

```c
/* Initialize sequence */
output_sequence[0] = start_poem;  // Line 159
```

This is algorithmically correct (the centroid is initialized from the starting poem), but for display purposes the anchor poem shouldn't be shown again.

## Intended Behavior

The diversity pages should show only poems OTHER than the anchor poem in the ranked list. The anchor poem should appear only once at the top of the page.

## Implementation

Fix in `flat-html-generator.lua`: When reading from the diversity cache, skip entries where `neighbor_index == source_poem_index`.

### In `get_diversity_sequence` function (parallel processing, lines 3329-3344)

```lua
local function get_diversity_sequence(source_poem_index)
    local cached_seq = diversity_cache.sequences[tostring(source_poem_index)]
    if not cached_seq then return {} end
    local result = {}
    for step, neighbor_index in ipairs(cached_seq) do
        -- Issue 10-025: Skip anchor poem (first entry is always the source poem)
        if neighbor_index ~= source_poem_index then
            local neighbor_poem = poem_by_index[neighbor_index]
            if neighbor_poem then
                table.insert(result, {
                    id = neighbor_index,
                    poem = neighbor_poem,
                    step = step
                })
            end
        end
    end
    return result
end
```

### Note on Similarity Cache

The similarity cache does NOT have this issue - it correctly excludes the source poem:
- Poem 4399 similarity: `[5846, 5535, 4922, ...]` (doesn't start with 4399)

## Files to Modify

- `src/flat-html-generator.lua` - Filter anchor poem in `get_diversity_sequence`

## Design Decision

**Why fix in HTML generation instead of cache generation?**

1. The cache format is algorithmically correct (diversity starts from the anchor)
2. Regenerating the cache takes ~1 minute on GPU
3. Filtering at display time is simpler and doesn't require cache regeneration
4. The step numbering in the sequence remains accurate (step 1 was the anchor selection)

## Related Issues

- 9-001g: Batch parallel diversity sequences (original GPU implementation)
- 9-005: Integrate GPU diversity cache into pipeline

## Completed

2026-02-13
