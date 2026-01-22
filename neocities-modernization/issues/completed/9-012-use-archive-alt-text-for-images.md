# Issue 9-012: Use Archive Alt-Text for Image Accessibility

## Priority
Medium (Accessibility)

## Problem Statement

Images in generated HTML pages have generic alt-text ("Image attachment") instead of using the alt-text provided by the user in the original Mastodon archive. Alt-text is important for:
1. Screen reader users who rely on descriptions
2. Tooltip display when hovering over images
3. Fallback text when images fail to load
4. SEO and content indexing

## Current Behavior

Images are rendered with generic alt-text:
```html
<img src="..." alt="Image attachment" loading="lazy" style="max-width:100%; height:auto">
```

The archive's `attachment.description` field contains user-provided alt-text but it may not be properly used in all rendering paths.

## Intended Behavior

If an attachment has a `description` field (user-provided alt-text), use it:
```html
<img src="..." alt="A cat sleeping on a keyboard" loading="lazy" style="max-width:100%; height:auto">
```

The alt-text should:
1. Appear as a tooltip when hovering over the image
2. Be read by screen readers
3. Display if the image fails to load
4. Be HTML-escaped to prevent XSS

## Data Source

ActivityPub attachments have a `description` field for alt-text:
```json
{
  "type": "image/jpeg",
  "url": "...",
  "description": "A cat sleeping on a keyboard",
  "width": 1200,
  "height": 800
}
```

This is extracted during fediverse extraction and stored in `poem.attachments[].description`.

## Verification Points

Check these rendering locations for proper alt-text usage:
1. `format_single_poem_with_progress_and_color()` - chronological page
2. effil worker thread `render_attachments()` - similar/different pages
3. Any other image rendering paths

## Test Cases

1. **Image with alt-text**: Hover shows description tooltip
2. **Image without alt-text**: Falls back to "Image attachment"
3. **Alt-text with quotes**: Properly escaped (`"` → `&quot;`)
4. **Alt-text with HTML characters**: Properly escaped (`<` → `&lt;`)

## Related Documents

- `scripts/extract-fediverse.lua` - Attachment extraction
- `src/flat-html-generator.lua` - Image rendering (multiple locations)
- Issue 8-005 - Image integration

## Implementation Progress

### 2026-01-21: Fixed

**Root Cause:** Chronological page used `attachment.alt_text` but ActivityPub stores alt-text in `attachment.description`.

**Fix:** Changed line 1186 in `src/flat-html-generator.lua`:
- Before: `attachment.alt_text or "Image attachment"`
- After: `attachment.description or attachment.alt_text or "Image attachment"`

The effil worker (similar/different pages) already had the correct check on line 3200.

## Metadata

- **Status**: ✅ Complete
- **Created**: 2026-01-21
- **Completed**: 2026-01-21
- **Phase**: 9 (Accessibility Enhancement)
- **Estimated Complexity**: Low
- **Dependencies**: None
- **Affects**: All pages with images
