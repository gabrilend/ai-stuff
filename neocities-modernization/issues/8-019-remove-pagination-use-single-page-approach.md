# Issue 8-019: Remove Pagination - Use Truncated Single-Page Approach

## Critical Constraint: 45GB Storage Limit

**The entire project must fit within 45GB.**

Current full-corpus approach would require ~95GB:
- 15,590 files × ~8MB each (all 7,793 poems per page) = ~95GB

This is **2× over budget**. We need to reduce output size significantly.

### Solution: Truncated Pages (Top N Similar/Different)

Instead of showing all 7,793 poems on each similarity/different page, show only the **top 500** most relevant:

| Approach | Poems/Page | File Size | Total Files | Total Size |
|----------|------------|-----------|-------------|------------|
| Full corpus | 7,793 | ~8 MB | 15,590 | ~95 GB |
| **Top 500** | 500 | ~500 KB | 15,590 | **~8 GB** |
| Top 1000 | 1,000 | ~1 MB | 15,590 | ~16 GB |

With top 500 + 639MB images + indexes: **~9 GB total** (well under 45GB limit)

---

## Current Behavior

Issue 8-012 implemented a pagination system that breaks each poem's similarity/diversity index into multiple pages of 100 poems each:

```
similar/0001-01.html  → Poems 1-100
similar/0001-02.html  → Poems 101-200
...
similar/0001-78.html  → Poems 7701-7793
```

This creates approximately **1.2 million HTML files**:
- 7,793 poems × 78 pages × 2 (similar + different) + 78 chronological = ~1,215,786 files

## Intended Behavior

Use a **truncated single-page approach** where each poem has exactly one similarity page and one diversity page containing the **top 500 most relevant poems**:

```
similar/0001.html   → Top 500 poems most similar to poem 1
different/0001.html → Top 500 poems most different from poem 1
chronological.html  → All 7,793 poems in chronological order (only one of these)
```

This creates approximately **15,590 HTML files** at ~500KB each:
- 7,793 similar + 7,793 different + ~4 index pages = ~15,590 files
- Total size: ~8 GB (well under 45 GB limit)

### Why Top 500?

1. **Practical relevance**: Users rarely scroll past the first few hundred results
2. **Size reduction**: 93% smaller files (500 vs 7,793 poems)
3. **Still comprehensive**: 500 poems is enough to explore themes/connections
4. **Configurable**: Can adjust via config if needed

## Rationale for Change

### 1. File Count Explosion
The pagination approach creates 77× more files without proportional benefit:

| Approach | Files | Complexity |
|----------|-------|------------|
| Single-page | ~15,590 | Simple |
| Paginated | ~1,215,786 | Complex |

### 2. Storage Constraint
With a 45GB limit, we cannot show all 7,793 poems per page:

| Approach | Files | Per-File | Total Size | Fits? |
|----------|-------|----------|------------|-------|
| Full corpus | ~15,590 | ~8 MB | ~95 GB | ❌ No |
| Paginated | ~1.2M | ~134 KB | ~160 GB | ❌ No |
| **Top 500** | ~15,590 | ~500 KB | ~8 GB | ✅ Yes |

### 2b. Full Corpus = Massive Redundancy
With full corpus, every `similar/XXX.html` contains the **exact same 7,793 poems**, just sorted differently. That's 7,793 copies of essentially identical content:
- 7,793 files × 8MB = ~62 GB
- Actual unique content: ~8 MB
- **Redundancy: 99.99%**

With top 500 truncation, each file contains a **different subset** of poems (the 500 most similar to that specific poem), so content overlap is minimal.

### 3. Images Already Referenced Externally
The 8MB file size is pure HTML text. Images are served from `input/media_attachments/` via URL references:
```html
<img src="../input/media_attachments/path/to/image.png" loading="lazy">
```
The 639MB of images (532 files) exist once and are referenced by all pages.

### 4. Browser Performance vs. Simplicity Trade-off
While smaller pages load faster in browsers, the complexity cost is not justified for a poetry archive website where:
- Users typically browse, not search
- The corpus is static (no dynamic loading needed)
- Modern browsers handle large HTML reasonably well
- `loading="lazy"` on images already provides progressive loading

### 5. Generation Time Similar Either Way
Whether generating 15,590 large files or 1.2M small files, the total content written is similar. The I/O overhead of creating 1.2M files may actually be worse.

## Suggested Implementation Steps

### Step 0: Add Truncation Configuration
- [ ] Add `max_poems_per_page` setting to `config/input-sources.json` (default: 500)
- [ ] Update HTML generator to respect this limit
- [ ] Add "Showing top N of M poems" message to page headers

### Step 1: Remove Pagination Code from flat-html-generator.lua
- [ ] Remove `load_pagination_config()` function
- [ ] Remove `calculate_page_count()` function
- [ ] Remove `get_poems_for_page()` function
- [ ] Remove `format_page_number()` function
- [ ] Remove `generate_page_filename()` function
- [ ] Remove `generate_prev_next_navigation()` function
- [ ] Remove `M.generate_paginated_poem_page_html()` function
- [ ] Remove `M.generate_all_paginated_pages_for_poem()` function
- [ ] Remove pagination config exposure functions

### Step 2: Remove Pagination Config
- [ ] Remove `pagination` section from `config/input-sources.json`
- [ ] Or leave it but mark as deprecated/unused

### Step 3: Update generate-html-parallel Script
- [ ] Remove pagination logic if any was added
- [ ] Ensure single-file-per-poem generation

### Step 4: Update Issue 8-012 Status
- [ ] Mark 8-012 as "Superseded by 8-019"
- [ ] Document the decision rationale

### Step 5: Close Related Issues
- [ ] Close 8-016 (Validate poem representation in pagination) - no longer needed

### Step 6: Update Documentation
- [ ] Update roadmap to reflect single-page approach
- [ ] Update 8-progress.md

## Code to Remove

From `src/flat-html-generator.lua`, remove or comment out:
- Lines related to `PAGINATION_CONFIG`
- Functions: `load_pagination_config`, `calculate_page_count`, `get_poems_for_page`, `format_page_number`, `generate_page_filename`, `generate_prev_next_navigation`
- Exported functions: `M.generate_paginated_poem_page_html`, `M.generate_all_paginated_pages_for_poem`, `M.get_pagination_config`, `M.calculate_page_count`

## Affected Files

- `src/flat-html-generator.lua` - Remove pagination functions
- `config/input-sources.json` - Remove/deprecate pagination section
- `scripts/generate-html-parallel` - Simplify if pagination was integrated
- `issues/8-012-implement-paginated-similarity-chapters.md` - Mark superseded
- `issues/8-016-validate-poem-representation-in-pagination.md` - Close
- `issues/8-progress.md` - Update status

## Related Issues

- **8-012**: Implement paginated similarity chapters → **SUPERSEDED** by this issue
- **8-016**: Validate poem representation in pagination → **CLOSED** (no longer needed)
- **8-001**: Integrate complete HTML generation → Continues with single-page approach
- **8-002**: Multi-threaded HTML generation → Simplified (fewer files to generate)

## Configuration

Add to `config/input-sources.json`:

```json
{
    "output": {
        "max_poems_per_page": 500,
        "show_truncation_message": true
    }
}
```

## Size Budget

| Component | Size | Notes |
|-----------|------|-------|
| Similar pages | ~4 GB | 7,793 × 500KB |
| Different pages | ~4 GB | 7,793 × 500KB |
| Chronological | ~8 MB | Full corpus (one file) |
| Index pages | ~25 MB | |
| Images | ~639 MB | 532 files |
| Centroid pages | ~11 MB | |
| **Total** | **~9 GB** | Well under 45GB limit |

Leaves ~36GB headroom for:
- Maze pages (Phase 11): ~31 MB (7,793 × 4KB)
- TXT exports: ~2 GB
- Future expansion

## Decision Log

**2025-12-25**: After reviewing the file count explosion (15K → 1.2M files) and realizing that images are already externally referenced (not embedded), decided to revert to the simpler single-page approach. The pagination complexity is not justified for a static poetry archive.

**2025-12-25 (Update)**: Added 45GB storage constraint. Changed from "all poems per page" to "top 500 per page" to reduce output from ~95GB to ~9GB.

---

**Phase**: 8 (Website Completion)

**Priority**: High (simplifies remaining Phase 8 work)

**Created**: 2025-12-25

**Status**: Open

**Supersedes**: 8-012, 8-016
