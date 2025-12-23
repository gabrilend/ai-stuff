# Issue 8-003: Remove Remaining CSS from HTML Generation

## Current Behavior

The `src/flat-html-generator.lua` still contains CSS that should be removed for:
1. **Performance**: Large 8-11MB HTML files with CSS parsing overhead slow browser rendering
2. **Consistency**: Project specification requires CSS-free HTML
3. **Simplicity**: Pure HTML is more maintainable and portable

### Remaining CSS Found:

**Style blocks** (2 occurrences):
```html
<style>
/* Minimal CSS for progress bars and accessibility */
.poem-separator {
    font-family: monospace;
    line-height: 1.2;
    margin: 0.2em 0;
}
</style>
```

**Inline styles** (4 occurrences):
1. Progress bar color: `style="color: #dc3c3c; font-weight: bold;"`
2. Content container: `style="text-align: left; max-width: 80ch; margin: 0 auto;"`

## Intended Behavior

Generate pure HTML without any CSS:
- No `<style>` blocks
- No `style=` attributes
- Use HTML structure and `<pre>` formatting for layout
- Use `<font color="">` for progress bar colors (HTML4 attribute, widely supported)
- Rely on `<pre>` and `<center>` for alignment (already in use)

## Implementation Steps

### Step 1: Remove style blocks from templates ✅ COMPLETED
- [x] Remove `<style>...</style>` block from `generate_flat_poem_list_html_with_progress()` template
- [x] Remove `<style>...</style>` block from `generate_chronological_index_with_navigation()` template
- [x] Remove `<style>...</style>` block from `generate_simple_discovery_instructions()` template
- [x] Removed unused `.poem-separator` class

### Step 2: Replace inline color styles with font tags ✅ COMPLETED
- [x] Changed progress bar color from:
  ```html
  <span style="color: #dc3c3c; font-weight: bold;">═══</span>
  ```
  To:
  ```html
  <font color="#dc3c3c"><b>═══</b></font>
  ```

### Step 3: Remove content container inline styles ✅ COMPLETED
- [x] Removed `style="text-align: left; max-width: 80ch; margin: 0 auto;"` from content divs
- [x] Layout relies on `<pre>` for monospace and `<center>` for alignment

### Step 4: Verify output ✅ COMPLETED
- [x] Generated HTML contains zero `<style>` tags in header
- [x] Generated HTML contains zero `style=` attributes
- [x] Progress bar colors display correctly using `<font color="">` tags
- [x] Content layout unchanged
- [x] 15,576 font color tags generated for semantic colors

## Technical Notes

### Font Tag for Colors
The `<font>` tag is deprecated in HTML5 but:
- Still universally supported by all browsers
- Requires no CSS parsing
- Perfect for this use case (simple color application)
- More performant than inline styles for repeated elements

### Layout Without CSS
Current structure already works without the removed CSS:
```html
<center>
  <h1>Title</h1>
  <div>  <!-- container div can be removed entirely -->
    <pre>
      content with 80-char line wrapping
    </pre>
  </div>
</center>
```

The `<pre>` tag provides:
- Monospace font
- Preserved whitespace
- Fixed-width character display

## Files to Modify

- `src/flat-html-generator.lua`:
  - Line 748: Remove style block from poem list template
  - Line 824: Remove style block from chronological template
  - Line 226: Change span+style to font+b tags
  - Lines 762, 839, 934: Remove inline style from container divs

## Quality Assurance Criteria

- [x] `grep -c "style=" output/*.html` returns 0
- [x] No `<style>` blocks in HTML header (content may contain text "<style>")
- [x] Progress bar colors display correctly using `<font color="">` tags
- [x] Content layout unchanged
- [x] Unicode characters (═, ─, ╔, ║, etc.) display correctly
- [ ] Large file (8MB+) renders faster in browser (to be verified)

## Related Issues

- **Issue 6-028**: Replace CSS with hard-coded HTML generation (COMPLETED - golden collection)
- **Issue 3-006**: Remove JavaScript dependencies from static HTML (COMPLETED)
- **Issue 8-001**: Integrate complete HTML generation into pipeline

## Performance Impact

For an 8MB HTML file with ~7800 poems:
- **Before**: Browser parses CSS, applies styles to thousands of elements
- **After**: Pure HTML rendering, no style computation needed

Expected improvement: Faster initial render, smoother scrolling on large pages.

---

**ISSUE STATUS: COMPLETED**

**Created**: 2025-12-14
**Reopened**: 2025-12-23 - Found 4 remaining style= attributes that were missed
**Completed**: 2025-12-23

**Phase**: 8 (Website Completion)

**Priority**: Medium (performance improvement)

## Summary

Previous work completed:
- 3 `<style>` blocks removed from templates
- Progress bar colors now use `<font color=""><b>` tags
- Semantic color functionality preserved
- Layout relies on `<pre>` and `<center>` tags

### Remaining Work (2025-12-23)

**4 inline `style=` attributes still present:**

1. **Line 764**: Image with dimensions
   ```lua
   style="max-width:100%%; height:auto;"
   ```

2. **Line 769**: Image without dimensions
   ```lua
   style="max-width:100%%; height:auto;"
   ```

3. **Line 1309**: Poem list template pre tag
   ```lua
   <pre style="text-align: left; max-width: 90ch; margin: 0 auto;">
   ```

4. **Line 1374**: Chronological template pre tag
   ```lua
   <pre style="text-align: left; max-width: 90ch; margin: 0 auto;">
   ```

### Solution Approach

**For image tags:**
- Remove `style` attribute entirely
- Images display at native size (acceptable for poetry site)
- `width` and `height` attributes already provide browser hints

**For pre tags:**
- Remove `style` attribute
- Content is already wrapped to 80 characters
- `<center>` tag wraps `<pre>`, providing natural centering
- `<pre>` default is left-aligned, monospace - exactly what we need

### Implementation Completed (2025-12-23)

**Changes made to `src/flat-html-generator.lua`:**

1. **Image tags (lines 764, 769)**:
   - Removed `style="max-width:100%%; height:auto;"` from both image format strings
   - Images now display at native size (width/height hints still provided)
   - Added comment explaining the change reason

2. **Pre tags (lines 1309, 1374)**:
   - Removed `style="text-align: left; max-width: 90ch; margin: 0 auto;"` from both templates
   - Templates now use plain `<pre>` tag
   - Added comments explaining pure HTML approach

**Verification:**
- Test generated HTML with 0 `style=` attributes
- Chronological template verified working
- Similarity/difference template verified working
- Colors still function via `<font color="">` tags
