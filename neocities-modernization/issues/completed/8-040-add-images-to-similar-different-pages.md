# Issue 8-040: Add Images to Similar/Different Pages

## Priority
Medium

## Current Behavior

Images from poem attachments are rendered in chronological pages but **not** in similar/different pages.

**Chronological pages** (images present):
```
/output/chronological-01.html: 37 <img> tags
/output/chronological-02.html: 91 <img> tags
/output/chronological-03.html: 46 <img> tags
... (all pages have images)
```

**Similar/different pages** (images missing):
```
/output/similar/0680-01.html: 0 <img> tags
/output/different/0680-01.html: 0 <img> tags
```

When viewing a poem with an image attachment on a similar/different page, the image is not displayed even though the same poem shows its image correctly on the chronological page.

## Intended Behavior

Images should be rendered consistently across all page types:
- Chronological pages: ✓ (already working)
- Similar pages: ✗ (needs fix)
- Different pages: ✗ (needs fix)

When a poem has attachments (images), they should appear in the poem's display regardless of which page type is being generated.

## Technical Analysis

### Image Rendering Function

The `render_attachment_images()` function exists at `flat-html-generator.lua:1088-1144`:
```lua
local function render_attachment_images(attachments)
    -- Render HTML for poem attachments (images)
    -- Returns empty string if no attachments or no image attachments
    ...
    local img_tag = string.format(
        '  <img src="%s" alt="%s" loading="lazy" width="%d" height="%d">',
        img_src, alt_text, attachment.width, attachment.height
    )
    ...
end
```

### Where Images ARE Rendered (Chronological)

Need to find where `render_attachment_images()` is called for chronological generation and ensure the same call is made for similar/different generation.

### Image Path Considerations

Current image paths use **relative paths** (problematic):
```html
<img src="../input/media_attachments/files/111/740/820/.../fb91427929fb8482.png" ...>
```

**Problem with relative paths:**
- Different page depths require different `../` counts
- Architecture changes break all paths
- Harder to debug and maintain

**Recommended: Use absolute paths**

For local/debug mode:
```html
<img src="file:///home/ritz/programming/ai-stuff/neocities-modernization/input/media_attachments/files/.../xyz.png" ...>
```

For production mode:
```html
<img src="/similar-different/media_attachments/files/.../xyz.png" ...>
```

This aligns with the existing URL switching architecture (`scripts/convert-urls`) which already handles absolute path conversion between local and production modes.

## Suggested Implementation Steps

1. **Find where images are rendered for chronological**:
   - Search for calls to `render_attachment_images()`
   - Identify the code path that includes images in chronological output

2. **Trace similar/different generation path**:
   - Find the poem formatting functions used for similar/different pages
   - Identify where attachment rendering should be added

3. **Add image rendering to similar/different**:
   - Call `render_attachment_images()` with poem.attachments
   - Insert returned HTML into the poem display

4. **Convert to absolute paths**:
   - Update `render_attachment_images()` to use absolute paths
   - Local: `file:///home/ritz/programming/ai-stuff/neocities-modernization/input/media_attachments/...`
   - This works uniformly regardless of which page type or depth
   - The `convert-urls` script will handle production conversion

5. **Update convert-urls script** (if needed):
   - Add pattern for media_attachments path conversion
   - Local: `file:///home/ritz/.../input/media_attachments/`
   - Production: `/similar-different/media_attachments/`

6. **Test with known image poems**:
   - Find poems with attachments in the dataset
   - Verify images appear on all three page types
   - Verify convert-urls handles image paths correctly

## Related Issues

- **Issue 9-004**: Image-Only Post Timestamp Association (depends on this issue)
  - 9-004 handles image-ONLY posts (posts with just `🖼` emoji)
  - This issue (8-040) handles poems that have BOTH text AND images
  - 8-040 should be completed first to establish basic image rendering
- Issue 8-005 (completed): Integrate images into HTML output

## Files to Investigate

| File | Purpose |
|------|---------|
| `src/flat-html-generator.lua` | Main generator, contains `render_attachment_images()` |
| `src/flat-html-generator.lua:1088` | Image rendering function |
| Lines using `format_poem_entry()` | May need to add attachment handling |
| Lines using `format_single_poem_*()` | Alternative entry point |

## Test Data

To find poems with images for testing:
```bash
# Find poems with attachments in chronological pages
grep -l "<img" output/chronological-*.html

# Sample image tag format
<img src="../input/media_attachments/files/.../original/xyz.png" alt="..." loading="lazy">
```

## Implementation Progress

### 2026-01-20: Core Implementation Complete

**Changes made:**

1. **Updated `render_attachment_images()` in `flat-html-generator.lua`** (line 1114-1118):
   - Changed from relative paths (`../input/media_attachments/`) to absolute paths
   - Now uses `file:///home/ritz/programming/ai-stuff/neocities-modernization/input/media_attachments/`
   - Works uniformly regardless of page depth

2. **Added image rendering to effil worker thread** (lines 2820-2844):
   - Worker `format_poem_entry()` function now renders attached images
   - Images appear after poem content, before navigation links
   - Inline implementation since worker can't access main scope functions

3. **Updated `scripts/convert-urls`** for multi-pattern support:
   - Added `URL_PATTERNS` array supporting multiple conversion patterns
   - Pattern 1: Output directory links (`/output` ↔ `/similar-different`)
   - Pattern 2: Media attachments (`/input/media_attachments` ↔ `/similar-different/media_attachments`)
   - Script now applies all patterns to each file

**Files modified:**
- `src/flat-html-generator.lua` - Image rendering in worker thread + absolute paths
- `scripts/convert-urls` - Multi-pattern URL conversion

**Pending:**
- [x] Full regeneration to test with real data
- [x] Visual verification that images appear on similar/different pages
- [x] Verify convert-urls handles new patterns correctly

### 2026-01-28: Validation Complete

**Validation Results:**
- Similar pages: 7334/7844 (93.5%) contain `<img>` tags
- Different pages: 7843/7843 (100%) contain `<img>` tags
- Pages without images contain poems with no attachments (e.g., `fediverse_boost` posts)
- Image paths use correct production format: `/similar-different/media/{hash}.ext`
- Image tags include `width`, `height`, and responsive styling

**Conclusion:** 8-040 implementation working correctly. Pages without images legitimately
contain poems with no image attachments.

## Metadata

- **Status**: ✅ Complete
- **Created**: 2026-01-20
- **Phase**: 8 (Website Completion / HTML Generation)
- **Estimated Complexity**: Low-Medium (function exists, needs to be called in right places)
- **Dependencies**: None
- **Affects**: All similar/*.html and different/*.html pages
