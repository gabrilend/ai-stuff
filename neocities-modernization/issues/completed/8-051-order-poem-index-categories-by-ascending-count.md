# Issue 8-051: Order Poem Index Categories by Ascending Poem Count

## Priority
Low

## Current Behavior

In `src/wordcloud-generator.lua:233-250`, the poem index section of `wordcloud.html` orders categories using a hardcoded list:

```lua
-- Order categories: fediverse, notes, messages, bluesky, then others
local cat_order = {"fediverse", "notes", "messages", "bluesky"}
```

Any categories not in this list are appended in arbitrary `pairs()` iteration order. This means the category order is fixed regardless of how many poems each category contains, and adding a new data source requires a code change to maintain ordering.

## Intended Behavior

Order categories by **ascending poem count** — the category with the fewest poems appears first, and the category with the most poems appears last. This creates a natural visual progression from small to large, and lets the reader start with the most digestible section before encountering the largest one.

### Example

If the current poem counts are:
- bluesky: 42 poems
- messages: 312 poems
- notes: 1,850 poems
- fediverse: 5,593 poems

The order would be: **bluesky → messages → notes → fediverse**

### Benefits

- **No hardcoded ordering** — new data sources automatically sort into the right position
- **Progressive disclosure** — smaller categories are quick to scan, easing the reader into the index
- **Visually balanced** — the page builds from compact sections to dense ones, avoiding a wall of IDs at the top

## Suggested Implementation Steps

### 1. Replace hardcoded ordering with count-based sort

In `generate_poem_index()` (`wordcloud-generator.lua:233-250`), replace:

```lua
-- Order categories: fediverse, notes, messages, bluesky, then others
local cat_order = {"fediverse", "notes", "messages", "bluesky"}
local ordered_cats = {}
for _, cat in ipairs(cat_order) do
    if categories[cat] then
        table.insert(ordered_cats, cat)
    end
end
-- Add any remaining categories
for cat, _ in pairs(categories) do
    local found = false
    for _, c in ipairs(cat_order) do
        if c == cat then found = true; break end
    end
    if not found then
        table.insert(ordered_cats, cat)
    end
end
```

With:

```lua
-- Order categories by ascending poem count (smallest first)
-- Removes the need for a hardcoded category list — new sources auto-sort
local ordered_cats = {}
for cat, _ in pairs(categories) do
    table.insert(ordered_cats, cat)
end
table.sort(ordered_cats, function(a, b)
    return #categories[a] < #categories[b]
end)
```

This is a net reduction in code (18 lines → 6 lines) while adding flexibility.

## Validation

- The poem index should show categories ordered from fewest to most poems
- Each category header should still display the count: `BLUESKY (42 poems)`
- Verify that the counts in the headers match the actual ordering
- Adding a new data source (e.g., a new input/ subdirectory) should automatically appear in the correct sorted position without code changes

## Related Documents

- Issue 8-046: Create Menu Navigation Page (original poem index implementation)
- Issue 8-043c: Simplified poem index format
- `src/wordcloud-generator.lua:206-290` — `generate_poem_index()` function

## Completion Notes

Replaced 18-line hardcoded category ordering in `src/wordcloud-generator.lua:233-241` with a 6-line count-based sort. Categories now appear in ascending poem count order automatically, and new data sources require no code changes to sort correctly.

## Metadata

- **Status**: ✅ Complete
- **Created**: 2026-01-26
- **Completed**: 2026-01-26
- **Phase**: 8 (Website Completion)
- **Estimated Complexity**: Very Low (one sort replacement)
