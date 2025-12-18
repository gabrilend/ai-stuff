# 8-012: Implement Paginated Similarity Chapters

## Status
- **Phase**: 8
- **Priority**: High
- **Type**: Enhancement / Architecture

## Current Behavior

Each poem generates a single HTML page containing **all** similar/different poems in sorted order:

```
similar/0068.html     → Contains all 6,860 poems sorted by similarity to poem 68
different/0068.html   → Contains all 6,860 poems sorted by diversity from poem 68
```

**Problems:**
1. Each page is ~8-12MB (contains entire corpus)
2. Generation time is O(n²) - every poem page requires full sorting
3. Initial deployment requires generating all ~13,720 pages upfront
4. Browser performance degrades with 6,860+ poem entries per page

## Intended Behavior

Break results into **paginated chapters** of ~100 poems each:

```
similar/0068-01.html  → Poems 1-100 most similar to poem 68
similar/0068-02.html  → Poems 101-200 most similar to poem 68
...
similar/0068-69.html  → Poems 6801-6860 most similar to poem 68
```

**Benefits:**
1. Each page is ~100-150KB (100 poems instead of 6,860)
2. Generate page 1 for all poems in **1/69th the time** (~100x faster initial deploy)
3. Additional pages can be generated incrementally or on-demand
4. Browser loads instantly, pagination provides natural exploration flow
5. Deterministic output - results only change with embedding model or algorithm updates

## File Naming Convention

```
{category}/{poem_id}-{page_num}.html

Examples:
  similar/0068-01.html    → First page of similarity results for poem 68
  similar/0068-22.html    → 22nd page of similarity results for poem 68
  different/1234-01.html  → First page of diversity results for poem 1234
```

**Page numbering**: 01-indexed, zero-padded to 2 digits (supports up to 99 pages)

**Poem ID format**: Existing 4-digit zero-padded format preserved

## Chapter Size Calculation

```
POEMS_PER_PAGE = 100
total_poems = 6860
pages_per_poem = ceil(6860 / 100) = 69 pages

Total files (similarity only): 6860 × 69 = 473,340 files
Total files (both categories): 6860 × 69 × 2 = 946,680 files
```

**Trade-off**: More files, but each is 1/69th the size. Net storage similar, but:
- Faster initial generation (only page 1 needed)
- Better browser performance
- Incremental generation possible

## Navigation Updates

Each paginated page needs:

### Header Navigation
```
╔════════════════════════════════════════════════════════════════════════════╗
║ Poem 68: "the title or first line..."                                      ║
║ Similar poems (page 22 of 69)                                              ║
╠════════════════════════════════════════════════════════════════════════════╣
║ [◀ Prev] [1] [2] ... [21] [22] [23] ... [68] [69] [Next ▶]                 ║
║ [Jump to page: ___]                                                        ║
╚════════════════════════════════════════════════════════════════════════════╝
```

### Footer Navigation
```
─────────────────────────────────────────────────────────────────────────────
Page 22 of 69 │ Showing poems 2101-2200 of 6860
[◀ Previous Page]                                    [Next Page ▶]
─────────────────────────────────────────────────────────────────────────────
```

### Cross-links
- Each poem entry still links to its own similarity page (page 1)
- "View all" link could go to page 1 of that poem's results

## Suggested Implementation Steps

### Phase A: Core Pagination Logic
1. [ ] Add `POEMS_PER_PAGE` constant (default: 100)
2. [ ] Create `calculate_page_count(total_poems)` utility
3. [ ] Create `get_poems_for_page(sorted_poems, page_num)` slicer
4. [ ] Update filename generation: `{id}-{page}.html`

### Phase B: Navigation Generation
5. [ ] Create `generate_pagination_nav(current_page, total_pages)` function
6. [ ] Add page range display: "Showing poems X-Y of Z"
7. [ ] Implement smart page number display (ellipsis for large ranges)
8. [ ] Add "Jump to page" input field (optional, JavaScript)

### Phase C: Generation Strategy
9. [ ] Add `--pages` flag to generation script: `--pages=1` or `--pages=all` or `--pages=1-10`
10. [ ] Implement page-specific generation in `flat-html-generator.lua`
11. [ ] Update `scripts/generate-html-parallel` for paginated output
12. [ ] Add progress reporting per-page

### Phase D: Integration
13. [ ] Update chronological.html links to point to `-01.html` pages
14. [ ] Update index.html entry points
15. [ ] Test navigation flow across pages
16. [ ] Update documentation

## Determinism Guarantee

Results are deterministic and will only change when:

1. **Embedding model changes** - Requires full re-embedding (~hours)
2. **Similarity algorithm changes** - Documented in issue files
3. **Poem corpus changes** - New poems added/removed

This means:
- Pages can be generated incrementally over time
- Cache invalidation is predictable
- No need for dynamic server-side computation

## Configuration Options

```lua
-- config/pagination-settings.json
{
  "poems_per_page": 100,
  "max_page_links": 9,        -- How many page numbers to show in nav
  "generate_all_pages": false, -- false = only page 1 initially
  "page_number_padding": 2     -- Zero-pad to 2 digits (01-99)
}
```

## Performance Estimates

| Metric | Current (full pages) | Paginated (page 1 only) |
|--------|---------------------|-------------------------|
| Initial generation | ~12,000 files | ~12,000 files |
| Time per file | ~100ms | ~1.5ms (1/69th content) |
| Total initial time | ~20 minutes | ~18 seconds |
| Page size | 8-12MB | 100-150KB |
| Browser load time | 3-5 seconds | <100ms |

## Related Documents

- `/src/flat-html-generator.lua` - Main HTML generation
- `/scripts/generate-html-parallel` - Multi-threaded generation
- `/issues/8-001-integrate-complete-html-generation-into-pipeline.md`
- `/issues/8-002-implement-multithreaded-html-generation.md`

## Open Questions

1. Should page 1 always be generated, with others on-demand?
2. Should we add a "load more" JavaScript option instead of pagination links?
3. What's the optimal poems-per-page count? (50? 100? 200?)
4. Should the chronological view also be paginated?

---
