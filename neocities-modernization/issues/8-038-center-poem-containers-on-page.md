# Issue 8-038: Center Poem Containers on Page

## Priority
Low

## Current Behavior

Poem content is left-aligned to the browser window edge. On wide screens, this leaves significant empty space on the right side, making the content feel unbalanced and harder to read.

Current structure:
```html
<pre>
═══════════════════════════════════════════════════════════════════════════════
 Poem content here
 Left-aligned to window edge
┌─────────┐                                                          ┌───────────┐
│ similar │                      chronological                       │ different │
╘═════════╧══════════════════════════════════════════════════════════╧═══════════╛
</pre>
```

## Intended Behavior

Center the poem container on the page while maintaining left-justified text within the container. The fixed-width ASCII art (82 chars for regular poems, 84 for golden) should appear centered in the viewport.

Visual result:
```
          |<-- browser window edge
                    ═══════════════════════════════════════════════════════════════════════════════
                     Poem content here
                     Centered on page, but text still left-justified within box
                    ┌─────────┐                                                          ┌───────────┐
                    │ similar │                      chronological                       │ different │
                    ╘═════════╧══════════════════════════════════════════════════════════╧═══════════╛
                                                                                 browser window edge -->|
```

## Chosen Solution: Option 2

Based on testing in `output/test-centering.html`, **Option 2** provides the cleanest result with the simplest implementation:

```html
<table align="center"><tr><td>
<pre>
[poem content]
</pre>
</td></tr></table>
```

### Why Option 2:

1. **Simplest markup**: Single table wrapper, no nesting
2. **No CSS required**: Uses HTML `align` attribute (fits project constraint from Issue 8-003)
3. **No JavaScript required**: Pure static HTML
4. **Consistent behavior**: Works across browsers without quirks
5. **Preserves `<pre>` formatting**: Text remains monospace and left-justified inside the cell

### Alternatives Tested (in test-centering.html):

| Option | Markup | Result |
|--------|--------|--------|
| 1 | `<center><pre>` | Works but `<center>` is deprecated |
| 2 | `<table align="center"><tr><td><pre>` | **Clean, simple - CHOSEN** |
| 3 | `<div align="center"><pre>` | May center text within pre |
| 4 | `<center><table><tr><td align="left"><pre>` | Works but uses deprecated `<center>` |
| 5 | `<table width="100%"><tr><td align="center"><pre>` | May center text within pre |
| 6 | Nested tables | Works but more complex |
| 7 | `<blockquote><pre>` | Inconsistent margins across browsers |

## Suggested Implementation Steps

1. **Identify all HTML generation entry points**:
   - `src/flat-html-generator.lua` - Main generator
   - Look for where `<pre>` tags are opened/closed
   - Both chronological.html and similar/different pages need updating

2. **Create wrapper function**:
   ```lua
   -- {{{ wrap_in_centered_table
   local function wrap_in_centered_table(content)
       return '<table align="center"><tr><td>\n<pre>\n' .. content .. '</pre>\n</td></tr></table>'
   end
   -- }}}
   ```

3. **Update chronological.html generation**:
   - Find where the main content `<pre>` block is created
   - Wrap with centered table structure
   - Ensure page header/footer remain outside the centering wrapper if needed

4. **Update similar/different page generation**:
   - Same approach as chronological
   - Each poem entry should be in its own centered container
   - Or wrap the entire page content in one centered table

5. **Decide on centering scope**:
   - **Option A**: One centered table per page (wraps all poems)
   - **Option B**: One centered table per poem (allows different widths)

   Recommendation: **Option A** (simpler, single wrapper)

6. **Handle page elements outside poems**:
   - Pagination links (prev/next page)
   - Page headers/titles
   - These may need separate centering or can be inside the same wrapper

7. **Test across page types**:
   - chronological.html (single long page with all poems)
   - similar/XXXX-NN.html (paginated similarity lists)
   - different/XXXX-NN.html (paginated diversity lists)

8. **Verify golden poem handling**:
   - Golden poems have 84-char width (vs 82 for regular) - extra border on left AND right
   - Both should center correctly within the same wrapper

## Files to Modify

- `src/flat-html-generator.lua`:
  - `generate_chronological_html()` or equivalent
  - `generate_page()` for similar/different pages
  - Any function that creates the outer `<pre>` wrapper

## Test Reference

The test file `output/test-centering.html` demonstrates all options. View in browser to compare:
- Options 2, 4, 6 visually look cleanest
- Option 2 is simplest implementation

## Related Documents

- `src/flat-html-generator.lua` - Primary implementation
- `output/test-centering.html` - Visual comparison of centering options
- `issues/completed/8-003-remove-remaining-css-from-html-generation.md` - CSS removal constraint
- `issues/8-037-fix-similar-different-box-alignment.md` - Related alignment work

## Implementation Progress

### 2026-01-21: Already Implemented

Upon investigation, `<table align="center">` wrapper is already present in:
- `src/flat-html-generator.lua` - Multiple template locations (lines 1799, 1945, 2167, 2188, 2344, 2932)
- Generated output: `chronological-01.html` contains the centering table

This was likely implemented as part of Issue 9-003 (HTML rendering fixes).

**Verified**: Output pages use `<table align="center"><tr><td><pre>...</pre></td></tr></table>` structure.

## Metadata

- **Status**: ✅ Already Implemented
- **Created**: 2026-01-19
- **Last Updated**: 2026-01-21
- **Phase**: 8 (Website Completion / HTML Enhancement)
- **Estimated Complexity**: Low (simple wrapper addition)
- **Dependencies**: None
- **Affects**: chronological.html, all similar/*.html, all different/*.html

## Acceptance Criteria

- [ ] Poem containers appear centered on wide screens
- [ ] Text within poems remains left-justified (monospace preserved)
- [ ] No CSS or JavaScript added
- [ ] Both regular and golden poems center correctly
- [ ] Pagination links appropriately positioned
- [ ] Test on multiple viewport widths (mobile, tablet, desktop)
