# 8-016: Validate Poem Representation in Pagination

## Status
- **Phase**: 8
- **Priority**: Medium
- **Type**: Validation / Quality Assurance
- **Depends On**: 8-012 (Paginated Similarity Chapters)
- **Created**: 2025-12-23

---

## Problem Statement

When generating paginated pages, there's a risk that some poems may not appear on any
generated pages due to:
1. Generation strategy only creating page 1 initially
2. Partial generation runs being interrupted
3. Configuration errors in `minimum_pages` setting
4. Edge cases in pagination calculation

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
  Similarity pages: 6,860 poem indices found
  Diversity pages:  6,860 poem indices found
  Chronological:    69 pages, 6,860 poems listed

Checking poem coverage...
  Total poems in corpus: 6,860
  Poems with similarity index: 6,860 (100%)
  Poems with diversity index: 6,860 (100%)
  Poems in chronological index: 6,860 (100%)

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

### Chronological Pages
```lua
-- All poems should appear somewhere in chronological-NN.html files
-- Parse each page and extract poem IDs
-- Build coverage set
```

---

## Configuration Integration

Uses `minimum_pages` from `config/input-sources.json`:

```json
"pagination": {
    "minimum_pages": 1
}
```

Validator checks that each poem has at least `minimum_pages` worth of index pages generated.

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
- `/config/input-sources.json` - `pagination.minimum_pages` config
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

