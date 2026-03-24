# 10-036: Fix Word Page Chronological Links

## Current Behavior (Bug)

Per-poem chronological links in word pages point to `chronological/index.html#poem-...` instead of the correct paginated page (e.g., `chronological/11.html#poem-...`).

Since `index.html` is a redirect to `01.html`, the anchor gets lost after the redirect, causing users to land at the top of page 1 instead of the specific poem.

Evidence:
```html
<!-- Header link (CORRECT): -->
<a href="/similar-different/chronological/11.html#poem-fediverse-4298">Chronological</a>

<!-- Per-poem links (WRONG): -->
<a href='/similar-different/chronological/index.html#poem-fediverse-4255'>chronological</a>
```

## Root Cause

1. `chrono_page_map` used `"index"` for page 1 instead of `"01"` format
2. `format_poem_for_word_page()` hardcoded `index.html` instead of using `chrono_page_map`
3. `chrono_page_map` was not passed to the formatting function

## Fix Applied

1. Changed `chrono_page_map` to use `"01"` format for page 1 (line 1010-1011)
2. Added `chrono_page_map` parameter to `generate_word_page()` (line 764)
3. Added `chrono_page_map` parameter to `format_poem_for_word_page()` (line 524)
4. Updated `chrono_link` to use `chrono_page_map[poem_idx]` (line 566)
5. Updated all call sites to pass `chrono_page_map`

## Files Modified

- `src/generate-word-pages.lua`: Full fix with chrono_page_map threading
- `src/flat-html-generator.lua`: Partial fix (line 2171)

## Related Issues

- Issue 8-050e: Original chronological page mapping implementation
- Issue 8-039: Chronological pagination (created the redirect issue)

## flat-html-generator.lua Fix Details

Line 2171 in `format_single_poem_with_progress_and_color()` had the same `index.html` bug.

**Code path analysis:**
- This function is only used by test functions, HTML archives (disabled), and interactive mode
- The production path uses parallel workers with `format_poem_entry()` which already has correct pagination
- Full chrono_page_map threading not implemented for this path (low priority)

**Fix applied:** Changed `index.html` to `01.html` - preserves anchor even though it may land on wrong page. This is acceptable for non-production paths.

## Status

**COMPLETED** - 2026-03-23
