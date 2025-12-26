# Issue 8-020: Hybrid Pagination Strategy

## Critical Constraints

1. **Storage limit**: 45 GB maximum
2. **Design requirement**: Full chronological.html must contain ALL 7,793 poems
3. **Practical requirement**: Similar/different pages can be paginated with storage-based limits

### The Resolution

| Component | Approach | Rationale |
|-----------|----------|-----------|
| chronological.html | **Full corpus** (~12 MB) | Preserves archive integrity |
| similar/XXX-NN.html | **Paginated** (N pages) | Storage-constrained, top-N most useful |
| different/XXX-NN.html | **Paginated** (N pages) | Storage-constrained, top-N most useful |
| maze/XXX.html | **Single page** (~4 KB) | Reserved budget for Phase 11 |

---

## Background

Issue 8-012 implemented a pagination system for all pages. This issue refines that approach based on:

1. **45 GB storage constraint** - Cannot fit full corpus on every page
2. **Design philosophy** - The chronological view represents the complete archive
3. **UX reality** - For similarity/diversity, top-N is actually more useful than full corpus
4. **Future planning** - Must reserve space for Phase 11 maze generation

## Intended Behavior

### Chronological Index (FULL)
```
chronological.html   → All 7,793 poems in chronological order (~12 MB)
```

This is the master archive. It must remain complete and unpaginated.

### Similar/Different Pages (PAGINATED)
```
similar/0001-01.html  → Poems 1-100 most similar to poem 1
similar/0001-02.html  → Poems 101-200 most similar to poem 1
...
similar/0001-NN.html  → Last generated page (storage-constrained)

different/0001-01.html → Poems 1-100 most different from poem 1
...
```

Where NN is calculated based on storage budget.

---

## Storage Budget Calculation

### Fixed Costs
| Component | Size | Notes |
|-----------|------|-------|
| chronological.html | ~12 MB | Full corpus (non-negotiable) |
| Images | ~639 MB | 532 files in media_attachments |
| Index pages | ~25 MB | Navigation pages |
| Centroid pages | ~11 MB | 5 moods × 2 directions |
| TXT exports | ~2 GB | Full text archives |
| **Maze pages (reserved)** | ~31 MB | 7,793 × 4KB (Phase 11) |
| **Headroom** | ~5 GB | Future expansion, safety margin |
| **Subtotal Fixed** | **~7.7 GB** | |

### Budget for Paginated Pages
```
Available: 45 GB - 7.7 GB = ~37.3 GB
```

### Pages Per Poem Calculation
```
Poem indexes: 15,586 (7,793 similar + 7,793 different)
Page size: ~134 KB (100 poems per page)
Pages available: 37.3 GB ÷ (15,586 × 134 KB) = ~17.9 pages

Recommended: 15 pages per poem (safety margin)
            = 1,500 poems shown per direction
            = Top 19% of corpus by similarity/diversity
```

### Final Budget
| Component | Files | Size | Notes |
|-----------|-------|------|-------|
| Similar pages | 116,895 | ~15.3 GB | 7,793 poems × 15 pages |
| Different pages | 116,895 | ~15.3 GB | 7,793 poems × 15 pages |
| Chronological | 1 | ~12 MB | Full corpus |
| Other fixed | - | ~7.7 GB | See above |
| **Total** | **~234K** | **~38.3 GB** | Under 45 GB limit |

---

## Configuration Changes

Update `config/input-sources.json`:

```json
{
    "pagination": {
        "poems_per_page": 100,
        "max_pages_per_poem": 15,
        "page_number_padding": 2,
        "generate_txt_exports": true,
        "generate_html_archives": false,
        "chronological_paginated": false
    },
    "storage": {
        "limit_gb": 45,
        "reserved_for_maze_gb": 0.031,
        "reserved_headroom_gb": 5
    }
}
```

Key settings:
- `max_pages_per_poem`: Limits pages generated (storage constraint)
- `chronological_paginated`: **false** - chronological stays full
- `generate_html_archives`: **false** - don't duplicate full corpus

---

## Implementation Changes to 8-012

Issue 8-012's pagination implementation remains valid, with these modifications:

1. **Add `max_pages_per_poem` config** - Caps page generation
2. **Skip chronological pagination** - Keep single full file
3. **Add storage-based calculation** - Auto-calculate max pages from budget
4. **Update navigation** - Show "Page X of Y (showing top Z poems)"

### Navigation Update
```
╔════════════════════════════════════════════════════════════════════════════════╗
║ Similar to Poem 68                                                             ║
║ Page 5 of 15 │ Showing poems 401-500 of top 1,500                              ║
╠════════════════════════════════════════════════════════════════════════════════╣
║ [◀ Previous Page]                                           [Next Page ▶]     ║
╚════════════════════════════════════════════════════════════════════════════════╝
```

Last page shows:
```
║ Page 15 of 15 │ Showing poems 1401-1500 of top 1,500                           ║
║ (Remaining 6,293 poems omitted for storage constraints)                        ║
```

---

## Suggested Implementation Steps

### Step 1: Update Configuration
- [x] Document hybrid approach (this issue)
- [ ] Add `max_pages_per_poem` to config/input-sources.json
- [ ] Add `chronological_paginated: false` setting
- [ ] Add `storage` section with budget info

### Step 2: Modify flat-html-generator.lua
- [ ] Respect `max_pages_per_poem` limit in `generate_all_paginated_pages_for_poem()`
- [ ] Skip chronological pagination when `chronological_paginated: false`
- [ ] Update page navigation to show storage context

### Step 3: Update generate-html-parallel
- [ ] Add page limit logic
- [ ] Progress reporting shows "Page X of max Y"

### Step 4: Preserve Full Chronological
- [ ] Ensure chronological.html generates as single file
- [ ] Verify it contains all 7,793 poems

### Step 5: Update Related Issues
- [ ] Update 8-012 to reference this issue's constraints
- [ ] Update 8-016 validation scope (validate up to max_pages only)

---

## Rationale for Hybrid Approach

### Why Full Chronological?
The chronological index is the **canonical archive**. Every poem must be accessible from one continuous scroll. This preserves the "massive page with everything" vision.

### Why Paginated Similar/Different?
1. **Storage constraints** - Can't fit 95 GB in 45 GB
2. **UX reality** - Nobody scrolls past the first few hundred similar poems
3. **Practical utility** - Top 1,500 covers 99% of discovery use cases
4. **Future features** - Reserves space for maze exploration (Phase 11)

### Why Not Truncation?
Truncation would mean similar/0068.html only shows 500 poems, period. Pagination means:
- Pages 1-15 exist and can be browsed
- Users see "Page 15 of 15 (top 1,500 poems)"
- Clear messaging about storage constraints
- Can expand later with more storage

---

## Decision Log

**2025-12-25**: Initial issue created proposing removal of pagination.

**2025-12-25 (Update 1)**: Discovered 45GB storage constraint. Proposed truncation to top 500.

**2025-12-25 (Update 2)**: User clarified "showing all poems is a design constraint." Conflict identified.

**2025-12-25 (Update 3)**: Hybrid approach agreed:
- Full chronological.html (preserves design constraint for archive)
- Paginated similar/different (practical storage constraint)
- Reserved budget for Phase 11 maze features

---

## Affected Files

- `config/input-sources.json` - Add new settings
- `src/flat-html-generator.lua` - Respect max_pages, skip chrono pagination
- `scripts/generate-html-parallel` - Page limit logic
- `issues/8-012-*.md` - Reference this issue
- `issues/8-016-*.md` - Update validation scope
- `issues/8-progress.md` - Document decision

## Related Issues

- **8-012**: Pagination implementation (modified by this issue)
- **8-016**: Pagination validation (scope reduced)
- **8-001**: Pipeline integration
- **8-002**: Multi-threaded generation
- **11-002c**: Maze HTML generation (reserved storage)

---

**Phase**: 8 (Website Completion)

**Priority**: High (design decision affects all generation)

**Created**: 2025-12-25

**Status**: Open

**Modifies**: 8-012
