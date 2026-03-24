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

- `src/generate-word-pages.lua`: All changes above

## Related Issues

- Issue 8-050e: Original chronological page mapping implementation
- Issue 8-039: Chronological pagination (created the redirect issue)

## Note: Similar Bug in flat-html-generator.lua

Line 2171 has the same hardcoded `index.html` bug for similar/different pages:
```lua
local chronological_link = string.format("<a href='%s/chronological/index.html#%s'>chronological</a>", base_path, anchor_id)
```

This is a separate bug that should be addressed in a follow-up issue if needed. The similar/different pages may also be affected.

## Status

**COMPLETED** - 2026-03-23
