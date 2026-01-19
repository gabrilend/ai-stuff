# Issue 9-003: HTML Rendering and Performance Fixes

## Current Behavior

Multiple rendering issues and performance problems in generated HTML pages:

### A. Navigation Box Alignment Issue
The "different" link doesn't align with its containing box:
```
  ┌─────────┐                                                          ┌───────────┐
  │ similar │                     chronological                      │ different │
  ╘═════════┴──────────────────────────────────────────────────────────┴───────────┘
```
The right side is misaligned by 2 spaces.

### B. Golden Poem Border Issue
First line of poem content appears on same line as top border:
```
╔═════════════════════════════════════════════════════─────────────────────────────┐║ what if shopping malls...
```
Missing newline after `┐`.

### C. Redundant "chronological" Link
The chronological.html page has a "chronological" link that points to itself - unnecessary and confusing.

### D. Similar/Different Pages Missing Formatting
The parallel-generated similar/different pages use simplified HTML without:
- Proper progress bars (showing position in full chronological dataset)
- Navigation links (similar/chronological/different)
- Consistent formatting with chronological.html

### E. Content Not Centered
Similar/different pages should have centered content like chronological.html.

### F. Chronological.html Too Large (12.7MB)
Page takes very long to load. Needs pagination.

### G. Image Compression
Images embedded or referenced in chronological.html should be compressed.

### H. UTF-8 Box Drawing Optimization
Consider using ASCII alternatives or optimizing encoding to reduce file size.

## Intended Behavior

### A. Fix Navigation Box Alignment
Add 2 spaces between "chronological" and "│ different │":
```
  ┌─────────┐                                                            ┌───────────┐
  │ similar │                       chronological                        │ different │
  ╘═════════┴────────────────────────────────────────────────────────────┴───────────┘
```

### B. Fix Golden Poem Border
Add newline after top-right corner `┐`:
```
╔═════════════════════════════════════════════════════─────────────────────────────┐
║ what if shopping malls...
```

### C. Remove Redundant Link
On chronological.html, remove the "chronological" link entirely using a flag during HTML generation.
The navigation box on chronological.html should only show "similar" and "different" links.
On similar/different pages, all three links should appear (with "chronological" linking back to the anchor).

### D. Consistent Page Formatting
Similar/different pages should match chronological.html formatting:
- Full progress bars with semantic colors
- Navigation box with all three links
- "chronological" link should anchor to the specific poem: `chronological.html#poem-{category}-{id}`

### E. Center Content
Add `<center>` wrapper or CSS centering to similar/different pages.

### F. Paginate Chronological
Split chronological.html into multiple pages (e.g., 500-1000 poems per page) with navigation.

### G. Compress Images
Add image compression step to pipeline.

### H. Optimize Box Drawing
Consider:
- ASCII fallback mode (use `---` instead of `───`)
- Single escape sequence at line boundaries instead of per-character

## Suggested Implementation Steps

1. Fix navigation box alignment in `format_navigation_box()` function (+2 spaces)
2. Fix golden poem border - add newline after `┐` in golden poem formatting
3. Add `page_type` flag to navigation box function:
   - `page_type = "chronological"` → show only similar/different links
   - `page_type = "similar"` or `"different"` → show all three links
4. Update parallel HTML worker to use full formatting (call shared formatting functions)
5. Add centering to page templates (`<center>` or CSS)
6. Implement chronological pagination (split into 500-1000 poems per page)
7. Add image compression step (optipng, jpegoptim, or similar)
8. Consider ASCII mode flag for simpler output (optional)

## Related Documents

- Issue 8-012: Pagination implementation
- Issue 8-020: Storage constraints (45GB limit)
- Issue 9-005b: URL switching helper script (convert file:// to production paths) - COMPLETED
- Issue 9-006: Poem box format validator (character count validation)

## Priority

Medium-High - These are user-facing quality issues affecting usability.

## Implementation Notes

### Completed Fixes

**A. Navigation Box Alignment** ✓
- Fixed in `generate_regular_corner_box_nav_line()` and `generate_corner_box_nav_line()`
- Increased right_gap from 22 to 24 chars (regular) and 22 to 25 chars (golden)
- File: `src/flat-html-generator.lua`

**B. Golden Poem Border** ✓
- Fixed by always adding newline after top border (removed conditional for golden poems)
- Both occurrences updated (lines ~1509 and ~2025)
- File: `src/flat-html-generator.lua`

**C. Remove Redundant Link** ✓
- Navigation functions now accept nil for chronological_link
- When nil, functions display empty space (29+29 chars for regular, 30+30 for golden)
- Chronological.html generation passes nil for chronological_link
- File: `src/flat-html-generator.lua`

**E. Center Content** ✓
- Initial: Added `<center>` wrapper around `<pre>` content
- **Fixed (Round 2)**: Changed from `<center>` to CSS-based centering
- **Fixed (Round 3)**: CSS not allowed on neocities - reverted to pure HTML
  - Pattern: `<table align="center"><tr><td><pre>...</pre></td></tr></table>`
  - This centers the block on page while keeping text left-aligned inside
  - No CSS attributes used - pure HTML table alignment
- Updated in all templates:
  - Chronological template (paginated and non-paginated)
  - Similar/different templates (paginated and non-paginated)
  - Parallel worker template
  - Explore.html template
- File: `src/flat-html-generator.lua`

**F. Paginate Chronological** ✓
- Added config settings: `chronological_paginated: true`, `chronological_poems_per_page: 500`
- Created `generate_chronological_page_navigation()` helper function
- Modified `generate_chronological_index_with_navigation()` to support pagination
- Generates chronological-01.html, chronological-02.html, etc.
- Creates redirect at chronological.html for backward compatibility
- Navigation: First | Prev | Page X of Y | Next | Last
- Files: `src/flat-html-generator.lua`, `config/input-sources.json`

**D. Similar/Different Pages Full Formatting** ✓
- Enhanced parallel worker's `format_poem_entry()` to generate full formatting
- Added `compute_chronological_mapping()` function to pre-compute poem positions
- Parallel workers now generate:
  - Progress bars showing chronological position (colored by semantic color)
  - Navigation box with similar/chronological/different links
  - Correct chronological page links (e.g., `chronological-05.html#anchor`)
- File: `src/flat-html-generator.lua`

**CLI Enhancement: Chronological Pagination** ✓
- Added `--chrono-per-page N` CLI option to run.sh and main.lua
- Interactive mode menu item added under "Chrono per Page"
- Files: `run.sh`, `libs/utils.lua`, `src/main.lua`, `src/flat-html-generator.lua`

**Removed Redundant index.html** ✓
- Removed duplicate index.html creation (website's index.html is elsewhere)
- File: `src/flat-html-generator.lua`

**URL Structure - Absolute Paths** ✓ (Round 2, updated Round 3)
- Changed from relative paths to absolute file:// paths for local testing
- Base path: `file:///home/ritz/programming/ai-stuff/neocities-modernization/output`
- Links now use absolute paths:
  - `file://.../output/similar/XXXX-01.html`
  - `file://.../output/different/XXXX-01.html`
  - `file://.../output/chronological-XX.html#anchor`
- Updated in both `format_single_poem_with_progress_and_color` and parallel worker
- See Issue 9-005 for helper script to convert to production URLs
- File: `src/flat-html-generator.lua`

**Golden Poem Navigation Condition** ✓ (Round 2)
- Fixed condition that required ALL three links (similar AND different AND chronological)
- Now requires only similar AND different - chronological can be nil
- This fixes missing nav on chronological.html where chronological_link is nil
- File: `src/flat-html-generator.lua` (apply_golden_poem_formatting function)

**CLI chrono_per_page for Parallel Workers** ✓ (Round 2)
- Added chrono_per_page parameter to `generate_complete_flat_html_collection`
- Parallel workers now use CLI override for chronological mapping
- Fixes incorrect page numbers when using `--chrono-per-page` flag
- Files: `src/main.lua`, `src/flat-html-generator.lua`

**Parallel Worker Spacing** ✓ (Round 2, updated Round 3)
- Removed all 2-space left padding from parallel worker output
- Table centering handles alignment - no need for manual padding
- Cleaned up: top progress, content lines, nav_top, nav_mid, bottom line
- File: `src/flat-html-generator.lua` (format_poem_entry in parallel worker)

**Content Warning Support** ✓ (Round 3)
- Added detection of CW:/Content Warning: at start of fediverse posts
- Content warnings displayed in ASCII boxes above poem content
- Pattern detection: `CW:` or `Content Warning:` followed by text
- Box formatting: `┌─...─┐ │ CW: text │ └─...─┘`
- File: `src/flat-html-generator.lua` (parallel worker format_poem_entry)

**Newline Preservation** ✓ (Round 3)
- Fixed word wrapping to preserve paragraph breaks
- Split content by double-newlines first, then wrap each paragraph
- Single newlines within paragraphs preserved as line breaks
- Prevents poems from being collapsed into single blocks
- File: `src/flat-html-generator.lua` (parallel worker format_poem_entry)

**Junction Characters** ✓ (Round 3)
- Added proper junction characters at positions 10 and 69 in bottom line
- ╧ (colored) used when position is within progress section
- ┴ (plain) used when position is in remaining section
- Matches the corners of the similar/different navigation boxes
- File: `src/flat-html-generator.lua` (parallel worker format_poem_entry)

### Remaining Items

**G. Image Compression** - DEFERRED
- See Issue 9-004 for image-related enhancements

**H. UTF-8 Optimization** - DEFERRED
- Low priority, current UTF-8 box drawing works well

### Known Limitations

- None currently - chronological links now correctly point to paginated pages
