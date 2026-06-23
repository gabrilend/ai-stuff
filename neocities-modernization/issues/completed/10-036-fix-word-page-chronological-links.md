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

The bug appeared in two locations:

### generate-word-pages.lua
1. `chrono_page_map` used `"index"` for page 1 instead of `"01"` format
2. `format_poem_for_word_page()` hardcoded `index.html` instead of using `chrono_page_map`
3. `chrono_page_map` was not passed through the call chain

### flat-html-generator.lua
1. `format_single_poem_with_progress_and_color()` hardcoded `index.html` at line 2171
2. `chrono_mapping` was not computed or passed to formatting functions
3. Archive and interactive test paths all used incorrect links

## Fix Applied

### generate-word-pages.lua (committed earlier)
1. Changed `chrono_page_map` to use `"01"` format for page 1 (line 1010-1011)
2. Added `chrono_page_map` parameter to `generate_word_page()` (line 764)
3. Added `chrono_page_map` parameter to `format_poem_for_word_page()` (line 524)
4. Updated `chrono_link` to use `chrono_page_map[poem_idx]` (line 566)
5. Updated all call sites to pass `chrono_page_map`

### flat-html-generator.lua (full fix)
1. Added `chrono_mapping` parameter to `format_single_poem_with_progress_and_color()` (line 2144)
2. Updated chronological link generation to use `chrono_mapping[poem_index]` (lines 2173-2175):
   ```lua
   local chrono_info = chrono_mapping and chrono_mapping[poem_index]
   local chrono_page = chrono_info and string.format("%02d", chrono_info.page_number) or "01"
   local chronological_link = string.format("<a href='%s/chronological/%s.html#%s'>chronological</a>", base_path, chrono_page, anchor_id)
   ```
3. Added `chrono_mapping` parameter to `format_all_poems_with_progress_and_color()` (line 2317)
4. Added `chrono_mapping` parameter to `M.generate_flat_poem_list_html_with_progress()` (line 2378)
5. Added `chrono_mapping` parameter to `M.generate_flat_poem_list_html()` (line 2443)
6. Added `chrono_mapping` parameter to `M.generate_paginated_poem_page_html()` (line 2484)
7. Added `chrono_mapping` parameter to `generate_similarity_html_archive()` (line 3035)
8. Added `chrono_mapping` parameter to `generate_diversity_html_archive()` (line 3058)
9. Moved `chrono_mapping` computation before parallel/sequential split (lines 3170-3179)
10. Updated archive call sites to pass `chrono_mapping` (lines 3082-3085, 3103-3106)
11. Updated interactive test calls to pass `nil` (lines 4425, 4452)
12. Updated main.lua test functions to pass `nil` (test code, acceptable fallback)

## Files Modified

- `src/generate-word-pages.lua`: Full fix with chrono_page_map threading
- `src/flat-html-generator.lua`: Full fix with chrono_mapping threading through all functions
- `src/main.lua`: Updated test functions to pass nil for chrono_mapping

## Code Path Analysis

### Production Path (correct before fix)
- Parallel workers with `format_poem_entry()` compute chrono_page_map per-worker
- This path already had correct pagination logic

### Archive Path (now fixed)
- `generate_similarity_html_archive()` and `generate_diversity_html_archive()`
- Now receive `chrono_mapping` computed before parallel/sequential split
- Used for debugging/archival, disabled by default (`enable_html_archive = false`)

### Test/Interactive Path (acceptable fallback)
- Test functions in main.lua and interactive mode in flat-html-generator.lua
- Pass `nil` for chrono_mapping, which falls back to "01.html"
- Acceptable because these are development tools, not production output

## Design Decision

Rather than requiring chrono_mapping everywhere, functions accept `nil` and fall back to "01":
```lua
local chrono_info = chrono_mapping and chrono_mapping[poem_index]
local chrono_page = chrono_info and string.format("%02d", chrono_info.page_number) or "01"
```

This preserves backwards compatibility for test code while ensuring production paths work correctly.

## Follow-up: page-size must be shared, not just the mapping function

The fix above shared the mapping *function* so the sort order matched, but each
generator still chose its OWN page-size divisor: the chronological pages honor a
runtime `--chrono-per-page` override, while the wordcloud/word-page generators
(separate luajit processes) read only the compiled-in config default. When the
two differ (e.g. pages built at 88/page but consumers assuming 500/page), every
`#poem` link lands on the wrong page again — `ceil(position / size)` produces a
different page number for the same poem. "One mapping, one answer" only holds
when both the function AND its page-size argument match.

Correct design: the page size has exactly two legitimate sources — the
`--chrono-per-page` flag the build passes, or the pagination config — and
`run.sh` threads the SAME flag to every generator (main, wordcloud, word-pages)
so separate processes cannot disagree. There is no third source and no literal
fallback: if neither the flag nor the config supplies a size, the generators
hard-error rather than guess (a wrong guess silently mis-paginates every link,
which is worse than a loud stop). An earlier attempt recorded the size to a
marker file beside the pages; that was dropped in favor of the simpler
flag-or-config rule with a hard error, which needs no on-disk side channel.

Relevant pieces: `compute_chronological_mapping` and `default_chrono_per_page`
(flat-html-generator; the latter now errors on a missing config key); a small
`resolve_chrono_per_page` helper in each of wordcloud-generator and
generate-word-pages (flag → config → error); and the `--chrono-per-page`
threading in `run.sh`'s word-cloud invocations.

## Related Issues

- Issue 8-050e: Original chronological page mapping implementation
- Issue 8-039: Chronological pagination (created the redirect issue)
- Issue 10-034: Lazy loading orchestrator (parallel worker architecture)
- Issue 10-052: Self-hosted source browser (the per-page marker lives beside its
  chronological pages, outside that browser's tree)

## Status

**COMPLETED** - 2026-03-23
