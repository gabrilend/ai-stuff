# 8-016: Validate Poem Representation in Pagination

## Status
- **Phase**: 8
- **Priority**: Medium
- **Type**: Validation / Quality Assurance
- **Depends On**: 8-012 (Paginated Similarity Chapters)
- **Modified By**: 8-020 (Hybrid Pagination Strategy)
- **Created**: 2025-12-23

---

## Design Constraints (from 8-020)

**Hybrid pagination strategy** changes validation scope:
- **chronological.html**: Single file with all poems (NOT paginated) - validate completeness
- **similar/different**: Paginated up to `max_pages_per_poem` (default: 15) - validate page 1 exists
- **Storage limit**: 45 GB - cannot validate "all pages" since pages are capped

---

## Problem Statement

When generating paginated pages, there's a risk that some poems may not appear on any
generated pages due to:
1. Generation strategy only creating page 1 initially
2. Partial generation runs being interrupted
3. Configuration errors in `minimum_pages` setting
4. Edge cases in pagination calculation
5. Storage-based page limits cutting off generation

Without validation, users may browse the site without ever encountering certain poems.

---

## Current Behavior

No validation exists to verify that all poems are represented in the generated output.
Pages are generated independently without cross-checking coverage.

---

## Intended Behavior

### Post-Generation Validator

A validation script runs after pagination generation to ensure complete coverage:

```
lua scripts/validate-poem-representation.lua

=== Poem Representation Validator ===

Checking generated pages...
  Similarity pages: 7,793 poem indices found (max 15 pages each)
  Diversity pages:  7,793 poem indices found (max 15 pages each)
  Chronological:    1 file, 7,793 poems listed (full corpus)

Checking poem coverage...
  Total poems in corpus: 7,793
  Poems with similarity page-1: 7,793 (100%)
  Poems with diversity page-1: 7,793 (100%)
  Poems in chronological.html: 7,793 (100%)

Page budget usage:
  Similar: 116,895 pages (15 × 7,793)
  Different: 116,895 pages (15 × 7,793)
  Total: ~38.3 GB of 45 GB budget (85%)

Coverage gaps found: 0

✓ PASS: All poems are represented in generated output
```

### Gap Detection and Recovery

If gaps are detected:

```
Coverage gaps found: 3

Missing from similarity indices:
  - Poem 1234 (no similar/1234-01.html exists)
  - Poem 5678 (no similar/5678-01.html exists)

Missing from diversity indices:
  - Poem 9012 (no different/9012-01.html exists)

Regenerating missing pages...
  Generated: similar/1234-01.html
  Generated: similar/5678-01.html
  Generated: different/9012-01.html

✓ RECOVERED: All gaps filled
```

---

## Implementation Steps

### Phase A: Validation Logic
1. [ ] Create `/scripts/validate-poem-representation.lua`
2. [ ] Load poems.json to get full corpus list
3. [ ] Scan `output/similar/` for existing poem index files
4. [ ] Scan `output/different/` for existing poem index files
5. [ ] Scan chronological pages for poem coverage
6. [ ] Compare corpus against found pages

### Phase B: Gap Detection
7. [ ] Identify poems missing from similarity indices
8. [ ] Identify poems missing from diversity indices
9. [ ] Identify poems missing from chronological pages
10. [ ] Report gaps with clear error messages

### Phase C: Recovery (Optional)
11. [ ] Implement `--fix` flag to regenerate missing pages
12. [ ] Call appropriate generator functions for missing content
13. [ ] Re-validate after recovery

### Phase D: Pipeline Integration
14. [ ] Add validation step to `run.sh` after generation
15. [ ] Exit with error code if gaps found and not fixed
16. [ ] Log validation results to generation report

---

## File Matching Logic

### Similarity Pages
```lua
-- Poem 68 should have at least: similar/0068-01.html
-- Pattern: similar/{padded_id}-{page}.html
local pattern = "similar/%04d-01.html"
```

### Diversity Pages
```lua
-- Poem 68 should have at least: different/0068-01.html
-- Pattern: different/{padded_id}-{page}.html
local pattern = "different/%04d-01.html"
```

### Chronological Page (Single File - per 8-020)
```lua
-- All 7,793 poems should appear in chronological.html (NOT paginated)
-- Parse single file and extract poem IDs
-- Verify count matches corpus
local pattern = "chronological.html"
```

---

## Configuration Integration

Uses settings from `config/input-sources.json`:

```json
"pagination": {
    "minimum_pages": 1,
    "max_pages_per_poem": 15,
    "chronological_paginated": false
},
"storage": {
    "limit_gb": 45
}
```

Validator checks:
- Each poem has at least `minimum_pages` worth of index pages generated
- No poem has more than `max_pages_per_poem` pages (storage constraint)
- chronological.html contains all poems (since `chronological_paginated: false`)

---

## Edge Cases

1. **Poems with ID 0** - Ensure zero-padded IDs handled correctly
2. **Newly added poems** - Should trigger gap detection
3. **Removed poems** - Orphan pages are acceptable (not an error)
4. **Large gaps in ID space** - Non-sequential IDs should work
5. **Different page naming conventions** - Support both `0068-01.html` and legacy `0068.html`

---

## Success Criteria

- [ ] Validator script created and runnable
- [ ] Correctly identifies missing poem indices
- [ ] Reports coverage percentage
- [ ] Optionally regenerates missing pages
- [ ] Integrated into pipeline with error exit on failure
- [ ] Documentation updated

---

## Related Documents

- `/issues/8-012-implement-paginated-similarity-chapters.md` - Parent issue
- `/issues/8-020-hybrid-pagination-strategy.md` - Hybrid strategy (modifies this issue)
- `/config/input-sources.json` - Pagination and storage config
- `/scripts/generate-html-parallel` - Page generation script
- `/assets/poems.json` - Source of truth for poem corpus

---

## Notes

This validator serves as a safety net for the pagination system. Even with correct
implementation in 8-012, having an independent validator provides:
- Confidence in deployment
- Detection of file system issues
- Recovery from interrupted generation runs
- Audit trail for completeness

