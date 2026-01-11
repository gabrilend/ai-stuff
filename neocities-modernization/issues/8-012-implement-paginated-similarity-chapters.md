# 8-012: Implement Paginated Similarity Chapters

## Status
- **Phase**: 8
- **Priority**: High
- **Type**: Enhancement / Architecture
- **Status**: In Progress (Phases A-D complete, Phase E pending)
- **Last Updated**: 2026-01-11 (Phase D completed)
- **Previously Blocked By**: 8-013 (now completed)
- **Modified By**: 8-020 (Hybrid Pagination Strategy)

## Design Constraint (from 8-020)

**Storage limit: 45 GB** requires hybrid approach:
- **chronological.html**: Full corpus (~12 MB) - NOT paginated
- **similar/different**: Paginated with `max_pages_per_poem` limit (default: 15)

This preserves the archive's integrity while respecting storage constraints.

## Previous Blocking Dependency (RESOLVED)

~~This issue **cannot be completed** until issue 8-013 (TXT Export Functionality) is resolved.~~

**Update (2025-12-23):** Issue 8-013 is now complete. Core TXT export functionality works.
Download link integration is now part of this issue's scope (Phase C).

The pagination system requires:
1. `.txt` export for each page (images → alt-text only) ✅ 8-013 complete
2. `.html` export for each page (preserves images) ✅ to be implemented here
3. Future: `.pdf` export (deferred)

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
**Answer**: **No** (updated by 8-020). Chronological.html remains a single ~12MB file containing all 7,793 poems. This preserves the "complete archive" design requirement while similar/different pages use pagination to fit the 45GB storage limit.

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

### Phase A: Core Pagination Logic ✅ COMPLETE
1. [x] Add `POEMS_PER_PAGE = 100` constant (in PAGINATION_CONFIG)
2. [x] Create `calculate_page_count(total_poems)` utility
3. [x] Create `get_poems_for_page(sorted_poems, page_num)` slicer
4. [x] Update filename generation: `{id}-{page}.html`

### Phase B: Navigation Generation ✅ COMPLETE
5. [x] Create `generate_prev_next_nav(current_page, total_pages)` function
6. [x] Add page info display: "Page X of Y │ Showing poems A-B"
7. [x] Implement edge case handling (no prev on page 1, no next on last page)
8. [ ] Add download links header (.txt, .html) - moved to Phase C

### Phase C: Export Formats ✅ COMPLETE (2026-01-09)
9. [x] Add download links to paginated page headers
10. [x] Implement .html archive version (full corpus, with images)
11. [x] Link to existing .txt exports from 8-013

### Phase D: Generation Strategy ✅ COMPLETE (2026-01-11)
12. [x] Add `--pages` flag: `--pages=1` (default) or `--pages=all` or `--pages=1-10`
13. [x] Implement page-specific generation in `flat-html-generator.lua`
14. [x] Integrate pagination into `M.generate_complete_flat_html_collection()`
15. [x] CLI flag parsing and passthrough from run.sh → main.lua → flat-html-generator

### Phase E: Integration
16. [x] ~~Paginate chronological.html~~ → Keep as single file (per 8-020)
17. [ ] Update index.html entry points to -01.html pages for similar/different
18. [ ] Test prev/next navigation flow
19. [ ] Update documentation
20. [ ] Add `max_pages_per_poem` limit enforcement

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

## Configuration Requirements

### Pagination Settings (to be added to config/input-sources.json)

```json
"pagination": {
    "poems_per_page": 100,
    "minimum_pages": 1,
    "page_number_padding": 2,
    "generate_txt_exports": true,
    "generate_html_archives": true
}
```

**Key settings:**

| Setting | Default | Description |
|---------|---------|-------------|
| `poems_per_page` | 100 | Number of poems on each paginated page |
| `minimum_pages` | 1 | Minimum number of pages to generate per poem index |
| `page_number_padding` | 2 | Zero-padding for page numbers (01-99) |
| `generate_txt_exports` | true | Generate full-corpus .txt exports |
| `generate_html_archives` | true | Generate full-corpus .html archives |

**Note:** The `minimum_pages` setting ensures every poem index gets at least N pages
generated, regardless of generation strategy. This is useful for:
- Ensuring at least page 1 exists for all poems (default)
- Pre-generating more pages for frequently accessed content
- Validation that all poems are represented (see related issue 8-016)

---

## Related Documents

- `/src/flat-html-generator.lua` - Main HTML generation
- `/scripts/generate-html-parallel` - Multi-threaded generation
- `/config/input-sources.json` - Pagination configuration
- `/issues/8-001-integrate-complete-html-generation-into-pipeline.md`
- `/issues/8-002-implement-multithreaded-html-generation.md`
- `/issues/8-013-implement-txt-export-functionality.md` - (completed, unblocked this issue)
- `/issues/8-016-validate-poem-representation-in-pagination.md` - Depends on this issue
- `/issues/8-020-hybrid-pagination-strategy.md` - **Modifies this issue** (hybrid pagination strategy)

---

## Implementation Log

### Session: 2025-12-23

**Circular Dependency Resolved:**
- Issue 8-013 (TXT Export) was marked as blocking 8-012
- 8-013's only remaining work (download links) actually depends on 8-012
- Marked 8-013 as complete, unblocking this issue
- Download link integration moved to Phase C of this issue

**Configuration Added:**
- Added `pagination` section to `config/input-sources.json`:
  - `poems_per_page: 100`
  - `minimum_pages: 1`
  - `page_number_padding: 2`
  - `generate_txt_exports: true`
  - `generate_html_archives: true`

**Core Functions Implemented in `src/flat-html-generator.lua`:**

| Function | Purpose |
|----------|---------|
| `load_pagination_config()` | Loads config from input-sources.json |
| `calculate_page_count(total)` | Returns pages needed for poem count |
| `get_poems_for_page(sorted, page_num)` | Extracts poems for specific page |
| `format_page_number(num)` | Zero-pads page numbers (01, 02, etc.) |
| `generate_page_filename(id, page, type)` | Creates filenames like `similar/0068-01.html` |
| `generate_prev_next_navigation(...)` | Creates header/footer navigation bars |
| `M.generate_paginated_poem_page_html(...)` | Generates single paginated page |
| `M.generate_all_paginated_pages_for_poem(...)` | Generates all pages for one poem |
| `M.get_pagination_config()` | Exposes config for external scripts |
| `M.calculate_page_count(total)` | Exposes calculation for external scripts |

**Test Results:**
```
Loaded pagination config: 100 poems/page, min 1 pages
Pages for 6860 poems: 69
Test page generated: 134KB for 100 poems
Navigation: [◀ Previous Page] ... [Next Page ▶]
```

**Remaining Work:**
- [ ] Phase C: Add download links for .txt/.html exports
- [ ] Phase D: Integration with generate-html-parallel
- [ ] Phase E: Integration (chronological kept as single file per 8-020)

**Created Related Issue:**
- 8-016: Validate poem representation in pagination (depends on this issue)

### Session: 2025-12-25

**Hybrid Pagination Strategy (Issue 8-020):**
- Chronological.html: Remains single file with all 7,793 poems (~12 MB)
- Similar/different: Paginated with max 15 pages per poem (storage constraint)
- Storage budget: 45 GB total, ~37 GB for paginated pages
- Reserved: ~31 MB for Phase 11 maze pages

**Key Changes:**
- Q4 answer updated: chronological NOT paginated
- Phase E Step 16 marked complete (no chrono pagination)
- Added `max_pages_per_poem` enforcement requirement
- Added reference to 8-019 in related documents

### Session: 2026-01-09

**Phase C: Export Format Integration - COMPLETED**

Implemented download links for full-corpus exports in paginated pages:

1. **Created `generate_download_links()` helper function** (lines 1595-1615)
   - Generates HTML for .txt and .html archive download links
   - Links format: `similar/0001.txt` and `similar/0001-archive.html`
   - Appears in page header below title

2. **Updated `M.generate_paginated_poem_page_html()`** (lines 1672-1673)
   - Added `download_links` variable generation
   - Integrated into HTML template in center section
   - Links appear on every paginated page

3. **Created HTML archive generation functions:**
   - `generate_similarity_html_archive()` (lines 2035-2042)
   - `generate_diversity_html_archive()` (lines 2056-2063)
   - Both generate full-corpus HTML files with images (not paginated)

4. **Integrated archive generation** into `M.generate_flat_html_with_similarity_and_diversity()`
   - Added HTML archive generation after TXT export (lines 2146-2152, 2171-2177)
   - Archives saved as `{category}/{id}-archive.html`
   - Added `html_archives` results tracking
   - Updated completion log (line 2196)

**Test Results** (`tmp/test-pagination-8-012.lua`):
```
✓ Download link header present
✓ .txt link present (.similar/0001.txt)
✓ .html archive link present (similar/0001-archive.html)
✓ Next Page navigation present
✓ Generated 2 paginated pages (135KB and 141KB each)
```

**Remaining Work:**
- [ ] Phase D: Generation strategy (--pages flag, pipeline integration)
- [ ] Phase E: Integration (entry points, testing, max_pages enforcement)

### Session: 2026-01-11

**Phase D: Generation Strategy - COMPLETED**

Implemented --pages flag parsing and integrated pagination into main generation pipeline:

1. **Created `parse_pages_specification()` function** (src/flat-html-generator.lua, lines 125-179)
   - Parses --pages flag formats: nil/"default", "all", "N", "N-M"
   - nil/"default" → Uses minimum_pages from config (default: {1})
   - "all" → Generates all pages up to max_pages_per_poem limit
   - "N" (e.g., "5") → Generates single page {5}
   - "N-M" (e.g., "1-10") → Generates page range {1,2,...,10}
   - Returns: {pages = {...}, is_all = boolean}

2. **Modified `M.generate_complete_flat_html_collection()`** (src/flat-html-generator.lua, lines 2172-2309)
   - Added `pages_spec` parameter to function signature
   - Replaced non-paginated `M.generate_flat_poem_list_html()` calls with paginated `M.generate_all_paginated_pages_for_poem()`
   - Applies pagination to both similarity and diversity page generation
   - Uses `poem_index` (numeric) for pagination filenames (e.g., similar/0001-01.html)
   - Log messages indicate pagination mode and pages being generated

3. **Updated CLI argument parsing** (libs/utils.lua, lines 122-178)
   - Added `pages` field to options table
   - Supports both `--pages VALUE` and `--pages=VALUE` formats
   - VALUE stored as string for parse_pages_specification()

4. **Updated `M.generate_website_html()`** (src/main.lua, lines 525-606)
   - Added `pages_spec` parameter to function signature
   - Passes `pages_spec` through to `flat_html_generator.generate_complete_flat_html_collection()`
   - Updated all callers in M.main() to pass `options.pages`

**Test Results** (`tmp/test-pagination-phase-d.lua`):
```
✓ Loaded test poem: poem_index=1, id=1
✓ Generated 1 file(s): ./tmp/test-pagination-output/similar/0001-01.html (3387 bytes)
✓ Paginated file exists with correct naming format (0001-01.html)
✓ Page info present: "Page 1 of 1"
✓ Pagination config loaded correctly
  poems_per_page: 100
  minimum_pages: 1
  max_pages_per_poem: 15
```

**Key Implementation Notes:**
- Pagination uses `poem_index` (numeric) instead of `unique_id` (string) for filenames
- Files generated as: `similar/0001-01.html`, `different/0001-01.html`, etc.
- Replaces old format: `similar/fediverse-0001.html`
- Default behavior (no --pages flag): generates page 1 only (minimum_pages=1)
- TXT/HTML archives remain non-paginated full-corpus exports

**Usage Examples:**
```bash
# Generate only page 1 for all poems (default, fastest)
./run.sh --generate-html --pages=1

# Generate all pages up to max_pages limit (15 pages per poem)
./run.sh --generate-html --pages=all

# Generate specific page range
./run.sh --generate-html --pages=1-5

# Or use src/main.lua directly
lua src/main.lua . --html-only --pages=1
```

**Remaining Work:**
- [ ] Phase E: Integration (entry points, testing, max_pages enforcement)
