# 8-012: Implement Paginated Similarity Chapters

## Status
- **Phase**: 8
- **Priority**: High
- **Type**: Enhancement / Architecture
- **Blocked By**: 8-013 (TXT Export Functionality)

## Blocking Dependency

This issue **cannot be completed** until issue 8-013 (TXT Export Functionality) is resolved.

The pagination system requires:
1. `.txt` export for each page (images → alt-text only)
2. `.html` export for each page (preserves images)
3. Future: `.pdf` export

Until .txt generation is working correctly, this issue remains blocked.

---

## Current Behavior

Each poem generates a single HTML page containing **all** similar/different poems in sorted order:

```
similar/0068.html     → Contains all 6,860 poems sorted by similarity to poem 68
different/0068.html   → Contains all 6,860 poems sorted by diversity from poem 68
chronological.html    → Contains all 6,860 poems in chronological order
```

**Problems:**
1. Each page is ~8-12MB (contains entire corpus)
2. Generation time is O(n²) - every poem page requires full sorting
3. Initial deployment requires generating all ~13,720 pages upfront
4. Browser performance degrades with 6,860+ poem entries per page

## Intended Behavior

Break results into **paginated chapters** of exactly **100 poems** each (images count as poems):

```
similar/0068-01.html  → Poems 1-100 most similar to poem 68
similar/0068-02.html  → Poems 101-200 most similar to poem 68
...
similar/0068-69.html  → Poems 6801-6860 most similar to poem 68

chronological-01.html → Poems 1-100 chronologically
chronological-02.html → Poems 101-200 chronologically
...
chronological-69.html → Poems 6801-6860 chronologically
```

---

## Resolved Design Decisions

### Q1: Should page 1 always generate, with others on-demand?
**Answer**: Page 1 always generates. Other pages generate when the generator function next runs across that area - NOT on-demand/dynamic.

### Q2: JavaScript "load more" vs. traditional pagination links?
**Answer**: Traditional pagination links. Strict left-right browsing only:
- Page 1 → Page 2
- Page 2 ← → Page 3
- Page 3 ← → Page 4
- etc.

No numbered page links, no jump-to-page. Simple prev/next only.

### Q3: Optimal poems-per-page count?
**Answer**: Exactly **100 poems per page**. Images count as poems. Final page may have fewer.

### Q4: Should chronological.html also be paginated?
**Answer**: **Yes**. Same structure: `chronological-01.html`, `chronological-02.html`, etc.

---

## Export Formats

Each paginated page provides download links for **full corpus exports** (not paginated):

```
╔════════════════════════════════════════════════════════════════════════════════╗
║ Similar to Poem 68 (Page 22 of 69)                                             ║
╠════════════════════════════════════════════════════════════════════════════════╣
║ Download full collection: [.txt] [.html] [.pdf]                                ║
╚════════════════════════════════════════════════════════════════════════════════╝
```

**Key distinction:**
- **Web pages**: Paginated (100 poems each) for browsing
- **Exports**: Full corpus (~7000 poems) for archiving/downloading

| Format | Content | Images | Status |
|--------|---------|--------|--------|
| `.txt` | Full corpus | Alt-text only | **BLOCKED** - Issue 8-013 |
| `.html` | Full corpus | Full image tags | Implement with pagination |
| `.pdf` | Full corpus | Full images | Future enhancement |

### File Structure

```
similar/
├── 0068-01.html      ← Paginated web page (poems 1-100)
├── 0068-02.html      ← Paginated web page (poems 101-200)
├── 0068-03.html      ← ... etc
│
├── 0068.txt          ← EXPORT: Full corpus plain text (~7000 poems)
├── 0068-archive.html ← EXPORT: Full corpus HTML with images
└── 0068.pdf          ← EXPORT: Full corpus PDF (future)
```

The exports are the same regardless of which paginated page you're viewing - they always contain the complete similarity-sorted collection.

---

## Navigation Structure

### Strict Prev/Next Navigation (No Page Numbers)

```
╔════════════════════════════════════════════════════════════════════════════════╗
║ Similar to Poem 68                                                             ║
║ Page 22 of 69 │ Showing poems 2101-2200                                        ║
╠════════════════════════════════════════════════════════════════════════════════╣
║ Download: [.txt] [.html]                                                       ║
╚════════════════════════════════════════════════════════════════════════════════╝

[... 100 poems ...]

────────────────────────────────────────────────────────────────────────────────
[◀ Previous Page]                                              [Next Page ▶]
────────────────────────────────────────────────────────────────────────────────
```

### Edge Cases
- **Page 1**: No "Previous Page" link
- **Last Page**: No "Next Page" link
- **Final Page**: May have fewer than 100 poems

---

## File Naming Convention

```
{category}/{poem_id}-{page_num}.html
{category}/{poem_id}-{page_num}.txt

Examples:
  similar/0068-01.html    → First page of similarity results for poem 68
  similar/0068-01.txt     → Plain text version of above
  different/1234-22.html  → 22nd page of diversity results for poem 1234
  chronological-01.html   → First page of chronological listing
```

**Page numbering**: 01-indexed, zero-padded to 2 digits (supports up to 99 pages)

---

## Chapter Size Calculation

```
POEMS_PER_PAGE = 100 (exactly, images count as poems)
total_poems = 6860
pages_per_poem = ceil(6860 / 100) = 69 pages

Total HTML files (similarity): 6860 × 69 = 473,340 files
Total HTML files (diversity):  6860 × 69 = 473,340 files
Total HTML files (chrono):     69 files
Total TXT files:               Same as HTML

Grand total: ~947,000 HTML + ~947,000 TXT = ~1.9 million files
```

---

## Suggested Implementation Steps

### Phase A: Core Pagination Logic
1. [ ] Add `POEMS_PER_PAGE = 100` constant
2. [ ] Create `calculate_page_count(total_poems)` utility
3. [ ] Create `get_poems_for_page(sorted_poems, page_num)` slicer
4. [ ] Update filename generation: `{id}-{page}.html`

### Phase B: Navigation Generation
5. [ ] Create `generate_prev_next_nav(current_page, total_pages)` function
6. [ ] Add page info display: "Page X of Y │ Showing poems A-B"
7. [ ] Implement edge case handling (no prev on page 1, no next on last page)
8. [ ] Add download links header (.txt, .html)

### Phase C: Export Formats
9. [ ] **BLOCKED**: Implement .txt export (depends on 8-013)
10. [ ] Implement .html downloadable version (with images)
11. [ ] Generate both formats for each page

### Phase D: Generation Strategy
12. [ ] Add `--pages` flag: `--pages=1` (default) or `--pages=all` or `--pages=1-10`
13. [ ] Implement page-specific generation in `flat-html-generator.lua`
14. [ ] Update `scripts/generate-html-parallel` for paginated output
15. [ ] Progress reporting per-page

### Phase E: Integration
16. [ ] Paginate chronological.html → chronological-NN.html
17. [ ] Update index.html entry points to -01.html pages
18. [ ] Test prev/next navigation flow
19. [ ] Update documentation

---

## Determinism Guarantee

Results are deterministic and will only change when:

1. **Embedding model changes** - Requires full re-embedding (~hours)
2. **Similarity algorithm changes** - Documented in issue files
3. **Poem corpus changes** - New poems added/removed

This means:
- Page 1 generates now, pages 2-69 generate later
- No cache invalidation concerns
- No need for dynamic server-side computation

---

## Performance Estimates

| Metric | Current (full pages) | Paginated (page 1 only) |
|--------|---------------------|-------------------------|
| Initial generation | ~12,000 files | ~12,000 files |
| Time per file | ~100ms | ~1.5ms (1/69th content) |
| Total initial time | ~20 minutes | ~18 seconds |
| Page size | 8-12MB | 100-150KB |
| Browser load time | 3-5 seconds | <100ms |

---

## Related Documents

- `/src/flat-html-generator.lua` - Main HTML generation
- `/scripts/generate-html-parallel` - Multi-threaded generation
- `/issues/8-001-integrate-complete-html-generation-into-pipeline.md`
- `/issues/8-002-implement-multithreaded-html-generation.md`
- `/issues/8-013-implement-txt-export-functionality.md` - **BLOCKING DEPENDENCY**

---
