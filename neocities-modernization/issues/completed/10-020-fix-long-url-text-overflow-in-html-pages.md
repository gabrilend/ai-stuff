# Issue 10-020: Fix Long URL Text Overflow in HTML Pages

## Status: COMPLETED

## Current Behavior
Long URLs in poem content (e.g., password reset links, Reddit links with query parameters)
extend horizontally beyond the visible area in chronological HTML pages, pushing content
far to the right and requiring horizontal scrolling.

The issue is in `<pre>` elements which default to `white-space: pre` that preserves all
whitespace and prevents line wrapping entirely.

## Intended Behavior
Long URLs and text should wrap within the viewport while preserving the monospace
preformatted appearance of poem content.

## Root Cause Analysis
- `<pre>` tags have `white-space: pre` by default
- This preserves whitespace but prevents line breaks
- Long URLs (100+ characters) extend indefinitely horizontally
- Chronological pages affected because they contain all poems including those with raw URLs

## Implementation
Added CSS style block to all HTML templates in `src/flat-html-generator.lua`:

```css
pre {
  white-space: pre-wrap;     /* Preserve whitespace but allow wrapping */
  word-wrap: break-word;     /* Break long words if needed */
  overflow-wrap: break-word; /* Modern version of word-wrap */
  max-width: 80ch;           /* Constrain width to 80 characters */
}
```

## Files Modified
- `src/flat-html-generator.lua`:
  - Paginated chronological template (lines 2728-2748)
  - Non-paginated chronological template (lines 2750-2768)
  - Sorted poems template (lines 2353-2370)
  - Paginated sorted poems template (lines 2500-2526)
  - Exploration guide template (lines 2920-2936)
  - Similarity/diversity pages template (lines 3996-4010)

## Testing
Regenerate site with `./run.sh --generate-index` and verify:
1. Chronological pages (01.html, etc.) wrap long URLs properly
2. Poem content still appears in monospace format
3. Whitespace and formatting within poems is preserved

## Lessons Learned
- `white-space: pre-wrap` is the key property for preserving preformatted text while
  allowing line breaks at container boundaries
- The combination of `word-wrap: break-word` and `overflow-wrap: break-word` ensures
  even very long strings without natural break points (like URLs) will wrap

## Completed
2026-01-30
